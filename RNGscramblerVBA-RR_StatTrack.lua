math.randomseed(os.time())
-- ensure bit library exists (VBA-RR uses Lua 5.1/5.2)
local bit = bit or require("bit")

-- VBA-RR specific initialization (BizHawk compatibility removed)

local RNGBase = 0x03000000
local lastSeenRNG = {memory.readword(RNGBase+4), memory.readword(RNGBase+2), memory.readword(RNGBase)}
local numDisplayedRNs = 20
local superRNToRNConversionDivisor = 655.36
local gameID = ""

-- helper to read 32-bit little endian values
local function read_u32_le(addr)
    local lo = memory.readword(addr)
    local hi = memory.readword(addr+2)
    return hi * 0x10000 + lo
end

-- helper to read bytes into an array
local function read_bytes(addr,len)
    local t = {}
    for i = 0, len-1 do t[i+1] = memory.readbyte(addr + i) end
    return t
end

function contains(tbl, value)
    if tbl == nil then return false end
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

-- screen dimensions (VBA-RR fixed)
local bufferwidth = 240
local bufferheight = 160
local num_displayed_units = 1
local last_num_displayed = 1
local baseFontSize = 3
local width = 110
local re_draw = 0

-- GUI Display state
local display_state = nil  -- nil, 'levelup', or 'l_pressed'
local display_frame_start = 0
local display_duration = 300  -- 5 seconds at 60fps
local displayed_unit_index = 0
local last_level_states = {}  -- Track previous level for each unit

local function colorWithOpacity(hex_color, opacity)
    -- Convert #RRGGBB to 0x7FBBGGRR (50% opacity)
    if type(hex_color) == 'string' and hex_color:sub(1,1) == '#' then
		opacity = math.floor(opacity * 127)  -- Convert opacity to 0-127 range
        local r = tonumber(hex_color:sub(2,3), 16)
        local g = tonumber(hex_color:sub(4,5), 16)
        local b = tonumber(hex_color:sub(6,7), 16)
        return bit.lshift(r, 24) + bit.lshift(g, 16) + bit.lshift(b, 8) + opacity
    end
    return hex_color
end

local RNGPosition = 0
local lastRNGPosition = 0
local userInput = input.get()
local displayRNG = false
local current_color = 0
local character_rotater = 0


-- Read consecutive values from the ROM to find a special string (ex/ FIREEMBLEM6.AFEJ01) used to distinguish between games
for i = 0, 18, 1 do
	gameID = gameID..memory.readbyte(0x080000A0 + i)
end

local gameIDMap = {
	['70738269697766766977540657069744849150'] = "Sealed Sword J",
	['70738269697766766977690656955694849150'] = "Blazing Sword U",
	['70738269697766766977550656955744849150'] = "Blazing Sword J",
	['707382696977667669775069666956694849150'] = "Sacred Stones U",
	['70738269697766766977560666956744849150'] = "Sacred Stones J"
}

local phaseMap = {
	['Sealed Sword J'] = 0x0202AA57,
	['Blazing Sword U'] = 0x0202BC07,
	['Blazing Sword J'] = 0x0202BC03,
	['Sacred Stones U'] = 0x0202BCFF,
	['Sacred Stones J'] = 0x0202BCFB
}

local baseAddressMap = {
	['Sealed Sword J'] = 0x202AB78,
	['Sacred Stones U'] = 0x0202BE4C,
	['Blazing Sword U'] = 0x0202BD08
}

local color_arr = {
	[0] = {"#532e21", "#A97060"},
	[1] = {"#252153", "#6660a9"},
	[2] = {"#53214f", "#a960a3"},
	[3] = {"#255321", "#66a960"},
	[4] = {"#214253", "#6091a9"},
	[5] = {"#532121", "#a96060"}
}
local background_color = color_arr[0][1]
local foreground_color = color_arr[0][2]

currentGame = gameIDMap[gameID]
print("Current game: "..currentGame)

-- ensure image drawing functions exist (some frontends don't support them)
if not gui.gdoverlay then gui.gdoverlay = function() end end
if not gui.line then gui.line = function() end end
if not gui.box then gui.box = function() end end

-- Unit info is displayed as [ID] = {name, b_lvl, b_hp, b_str, b_skl, b_spd, b_def, b_res, b_lck, c_lvl, c_hp, c_str, c_skl, c_spd, c_def, c_res, c_lck, hp_g, str_g, skl_g, spd_g, def_g,  res_g, lck_g, pp_lvl, avg_hp, avg_str, avg_skl, avg_spd, avg_def, avg_res, avg_lck, total_lvls, promoted, ppp_lvl, promo_hp, promo_str, promo_skl, promo_spd, promo_def, promo_res}
--									[01,    02,    03,    04,    05,    06,    07,    08,    09,   10,    11,    12,    13,    14,    15,    16,    17,   18,    19,    20,   21,     22,    23,    24,    25,     26,      27,      28,      29,      30,       31,      32       33,         34,       35,      36,       37,        38,       39,         40          41]
-- b_* = base stat. c_* = current stat. *_g = growth. avg_* = amount +- avg
local UnitsLut = {}
if currentGame == 'Sealed Sword J' then
	UnitsLut = {
		[0x86076D0] = {"Roy",		01, 18, 05, 05, 07, 05, 00, 07, 0, 0, 0, 0, 0, 0, 0, 0, 0.80, 0.40, 0.50, 0.40, 0.25, 0.30, 0.60, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 2, 3, 2, 2, 5},
		[0x8607700] = {"Clarine",	01, 15, 02, 05, 09, 02, 05, 08, 0, 0, 0, 0, 0, 0, 0, 0, 0.40, 0.30, 0.40, 0.50, 0.10, 0.40, 0.65, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 3, 2, 2, 2, 3},
		[0x8607730] = {"Fae",		01, 16, 02, 02, 03, 02, 06, 07, 0, 0, 0, 0, 0, 0, 0, 0, 1.30, 0.90, 0.85, 0.65, 0.30, 0.50, 1.50, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8607760] = {"Sin",		05, 24, 07, 08, 10, 07, 00, 06, 0, 0, 0, 0, 0, 0, 0, 0, 0.75, 0.45, 0.50, 0.50, 0.10, 0.15, 0.25, 05, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 2, 2, 2, 2, 3},
		[0x8607790] = {"Sue",		01, 18, 05, 07, 08, 05, 00, 04, 0, 0, 0, 0, 0, 0, 0, 0, 0.55, 0.30, 0.55, 0.65, 0.10, 0.15, 0.50, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6, 2, 1, 1, 2, 4},
		[0x86077C0] = {"Dayan",		14, 43, 14, 16, 20, 10, 12, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0.55, 0.20, 0.20, 0.15, 0.10, 0.10, 0.20, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x86077F0] = {"Dayan",		14, 43, 14, 16, 20, 10, 12, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0.55, 0.20, 0.20, 0.15, 0.10, 0.10, 0.20, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8607820] = {"Barth",		09, 25, 10, 06, 05, 14, 01, 02, 0, 0, 0, 0, 0, 0, 0, 0, 1.00, 0.60, 0.25, 0.20, 0.40, 0.02, 0.20, 09, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 3, 2, 3, 4, 3},
		[0x8607850] = {"Bors",		01, 20, 07, 04, 03, 11, 00, 04, 0, 0, 0, 0, 0, 0, 0, 0, 0.90, 0.30, 0.30, 0.40, 0.35, 0.10, 0.50, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 3, 2, 3, 4, 3},
		[0x8607880] = {"Wendy",		01, 19, 04, 03, 03, 08, 01, 06, 0, 0, 0, 0, 0, 0, 0, 0, 0.85, 0.40, 0.40, 0.40, 0.30, 0.10, 0.45, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 4, 2, 4, 3, 3},
		[0x86078B0] = {"Douglas",	08, 46, 19, 13, 08, 20, 05, 11, 0, 0, 0, 0, 0, 0, 0, 0, 0.60, 0.30, 0.30, 0.30, 0.30, 0.05, 0.20, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x86078E0] = {"Douglas",	08, 46, 19, 13, 08, 20, 05, 11, 0, 0, 0, 0, 0, 0, 0, 0, 0.60, 0.30, 0.30, 0.30, 0.30, 0.05, 0.20, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8607910] = {"Wolt",		01, 18, 04, 04, 05, 04, 00, 02, 0, 0, 0, 0, 0, 0, 0, 0, 0.80, 0.40, 0.50, 0.40, 0.20, 0.10, 0.40, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 3, 3, 2, 2, 2},
		[0x8607940] = {"Dorothy",	03, 19, 05, 06, 06, 04, 02, 03, 0, 0, 0, 0, 0, 0, 0, 0, 0.85, 0.50, 0.45, 0.45, 0.15, 0.15, 0.35, 03, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 3, 3, 3, 2, 3},
		[0x8607970] = {"Klein",		01, 27, 13, 13, 11, 08, 06, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0.60, 0.35, 0.40, 0.45, 0.15, 0.25, 0.50, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x86079A0] = {"Saul",		05, 20, 04, 06, 10, 02, 05, 02, 0, 0, 0, 0, 0, 0, 0, 0, 0.60, 0.40, 0.45, 0.45, 0.15, 0.50, 0.15, 05, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 3, 3, 2, 2, 3},
		[0x86079D0] = {"Ellen",		02, 16, 01, 06, 08, 00, 06, 08, 0, 0, 0, 0, 0, 0, 0, 0, 0.45, 0.50, 0.30, 0.20, 0.05, 0.60, 0.70, 02, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 3, 3, 2, 2, 3},
		[0x8607A00] = {"Yoder",		17, 35, 19, 18, 14, 05, 30, 11, 0, 0, 0, 0, 0, 0, 0, 0, 0.20, 0.30, 0.15, 0.10, 0.10, 0.20, 0.20, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8607A30] = {"Yoder",		20, 35, 19, 18, 14, 05, 30, 11, 0, 0, 0, 0, 0, 0, 0, 0, 0.20, 0.30, 0.15, 0.10, 0.10, 0.20, 0.20, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8607A60] = {"Chad",		01, 16, 03, 03, 10, 02, 00, 04, 0, 0, 0, 0, 0, 0, 0, 0, 0.85, 0.50, 0.50, 0.80, 0.25, 0.15, 0.60, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8607A90] = {"Karel",		19, 44, 20, 28, 23, 15, 13, 18, 0, 0, 0, 0, 0, 0, 0, 0, 2.10, 1.30, 1.40, 1.40, 1.10, 1.00, 1.20, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8607AC0] = {"Fir",		01, 19, 06, 09, 10, 03, 01, 03, 0, 0, 0, 0, 0, 0, 0, 0, 0.75, 0.25, 0.50, 0.55, 0.15, 0.20, 0.50, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 3, 2, 2, 3, 2},
		[0x8607AF0] = {"Rutger",	04, 22, 07, 12, 13, 05, 00, 02, 0, 0, 0, 0, 0, 0, 0, 0, 0.80, 0.30, 0.60, 0.50, 0.20, 0.20, 0.30, 04, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 2, 2, 1, 3, 2},
		[0x8607B20] = {"Dieck",		05, 26, 09, 12, 10, 06, 01, 05, 0, 0, 0, 0, 0, 0, 0, 0, 0.90, 0.40, 0.40, 0.30, 0.20, 0.15, 0.35, 05, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 2, 1, 2, 4, 2},
		[0x8607B50] = {"Ogier",		03, 24, 07, 10, 09, 04, 00, 06, 0, 0, 0, 0, 0, 0, 0, 0, 0.85, 0.40, 0.30, 0.45, 0.20, 0.15, 0.55, 03, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 2, 1, 2, 4, 2},
		[0x8607B80] = {"Garret",	02, 49, 17, 13, 18, 14, 11, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0.70, 0.45, 0.25, 0.25, 0.15, 0.05, 0.15, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8607BB0] = {"Alen",		01, 21, 07, 04, 06, 06, 00, 03, 0, 0, 0, 0, 0, 0, 0, 0, 0.85, 0.45, 0.40, 0.45, 0.25, 0.10, 0.40, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 2, 2, 2, 2, 3},
		[0x8607BE0] = {"Lance",		01, 20, 05, 06, 08, 06, 00, 02, 0, 0, 0, 0, 0, 0, 0, 0, 0.80, 0.40, 0.45, 0.50, 0.20, 0.15, 0.35, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 2, 2, 2, 2, 3},
		[0x8607C10] = {"Percival",	13, 43, 17, 13, 18, 14, 11, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0.75, 0.30, 0.25, 0.35, 0.20, 0.10, 0.20, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8607C40] = {"Igrene",	05, 32, 16, 18, 15, 11, 10, 09, 0, 0, 0, 0, 0, 0, 0, 0, 0.70, 0.35, 0.25, 0.35, 0.10, 0.05, 0.20, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8607C70] = {"Marcus",	01, 32, 09, 14, 11, 09, 08, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0.60, 0.25, 0.20, 0.25, 0.15, 0.20, 0.20, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8607CA0] = {"Astolfo",	10, 25, 07, 08, 15, 07, 03, 11, 0, 0, 0, 0, 0, 0, 0, 0, 0.90, 0.35, 0.40, 0.50, 0.20, 0.20, 0.15, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8607CD0] = {"Wade",		02, 28, 08, 03, 05, 03, 00, 04, 0, 0, 0, 0, 0, 0, 0, 0, 0.75, 0.50, 0.45, 0.20, 0.30, 0.05, 0.45, 02, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 3, 3, 2, 3, 0},
		[0x8607D00] = {"Lot",		03, 29, 07, 06, 07, 04, 01, 02, 0, 0, 0, 0, 0, 0, 0, 0, 0.80, 0.30, 0.30, 0.35, 0.40, 0.15, 0.30, 03, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 3, 3, 2, 3, 0},
		[0x8607D30] = {"Bartre",	01, 48, 22, 11, 10, 10, 03, 14, 0, 0, 0, 0, 0, 0, 0, 0, 0.70, 0.40, 0.20, 0.30, 0.20, 0.05, 0.20, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8607D60] = {"Bartre",	01, 48, 22, 11, 10, 10, 03, 14, 0, 0, 0, 0, 0, 0, 0, 0, 0.70, 0.40, 0.20, 0.30, 0.20, 0.05, 0.20, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8607D90] = {"Lugh",		01, 16, 04, 05, 06, 03, 05, 05, 0, 0, 0, 0, 0, 0, 0, 0, 0.50, 0.40, 0.50, 0.50, 0.15, 0.30, 0.35, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 4, 2, 1, 2, 2},
		[0x8607DC0] = {"Lilina",	01, 16, 05, 05, 04, 02, 07, 04, 0, 0, 0, 0, 0, 0, 0, 0, 0.45, 0.75, 0.20, 0.35, 0.10, 0.35, 0.50, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 3, 3, 3, 1, 2},
		[0x8607DF0] = {"Hugh",		15, 26, 13, 11, 12, 09, 09, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0.75, 0.30, 0.30, 0.45, 0.20, 0.15, 0.25, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 4, 2, 1, 2, 2},
		[0x8607E20] = {"Niime",		17, 25, 21, 20, 16, 05, 18, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0.25, 0.15, 0.15, 0.15, 0.15, 0.20, 0.05, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8607E50] = {"Niime",		20, 25, 21, 20, 16, 05, 18, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0.25, 0.15, 0.15, 0.15, 0.15, 0.20, 0.05, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8607E80] = {"Raigh",		10, 23, 12, 09, 09, 05, 10, 06, 0, 0, 0, 0, 0, 0, 0, 0, 0.55, 0.45, 0.55, 0.40, 0.15, 0.20, 0.15, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 4, 2, 2, 2, 2},
		[0x8607EB0] = {"Larum",		01, 14, 01, 02, 11, 02, 04, 09, 0, 0, 0, 0, 0, 0, 0, 0, 0.70, 0.10, 0.05, 0.70, 0.20, 0.30, 0.80, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8607EE0] = {"Juno",		09, 33, 11, 14, 16, 08, 12, 14, 0, 0, 0, 0, 0, 0, 0, 0, 0.50, 0.20, 0.35, 0.30, 0.10, 0.10, 0.45, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8607F10] = {"Juno",		09, 33, 11, 14, 16, 08, 12, 14, 0, 0, 0, 0, 0, 0, 0, 0, 0.50, 0.20, 0.35, 0.30, 0.10, 0.10, 0.45, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8607F40] = {"Thea",		08, 22, 06, 08, 11, 07, 06, 03, 0, 0, 0, 0, 0, 0, 0, 0, 0.60, 0.40, 0.45, 0.55, 0.15, 0.20, 0.40, 08, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6, 2, 2, 2, 2, 2},
		[0x8607F70] = {"Thea",		08, 22, 06, 08, 11, 07, 06, 03, 0, 0, 0, 0, 0, 0, 0, 0, 0.60, 0.40, 0.45, 0.55, 0.15, 0.20, 0.40, 08, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6, 2, 2, 2, 2, 2},
		[0x8607FA0] = {"Thea",		08, 22, 06, 08, 11, 07, 06, 03, 0, 0, 0, 0, 0, 0, 0, 0, 0.60, 0.40, 0.45, 0.55, 0.15, 0.20, 0.40, 08, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6, 2, 2, 2, 2, 2},
		[0x8607FD0] = {"Shanna",	01, 17, 04, 06, 12, 06, 05, 05, 0, 0, 0, 0, 0, 0, 0, 0, 0.45, 0.30, 0.55, 0.60, 0.10, 0.25, 0.60, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6, 2, 2, 2, 2, 2},
		[0x8608000] = {"Zeiss",		07, 28, 14, 09, 08, 12, 02, 06, 0, 0, 0, 0, 0, 0, 0, 0, 0.80, 0.60, 0.50, 0.35, 0.25, 0.05, 0.20, 07, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 2, 2, 2, 2, 1},
		[0x8608060] = {"Elphin",	01, 15, 01, 03, 10, 04, 01, 11, 0, 0, 0, 0, 0, 0, 0, 0, 0.80, 0.05, 0.05, 0.65, 0.25, 0.55, 0.65, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8608090] = {"Cath",		05, 16, 03, 07, 11, 02, 01, 08, 0, 0, 0, 0, 0, 0, 0, 0, 0.80, 0.40, 0.45, 0.85, 0.15, 0.20, 0.50, 05, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x86080C0] = {"Sophia",	01, 15, 06, 02, 04, 01, 08, 03, 0, 0, 0, 0, 0, 0, 0, 0, 0.60, 0.55, 0.40, 0.30, 0.20, 0.55, 0.20, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 4, 2, 3, 2, 2},
		[0x86080F0] = {"Miledy",	10, 30, 12, 11, 10, 13, 03, 05, 0, 0, 0, 0, 0, 0, 0, 0, 0.75, 0.50, 0.50, 0.45, 0.20, 0.05, 0.25, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 2, 2, 2, 2, 2},
		[0x8608120] = {"Gonzales",	11, 36, 12, 05, 09, 06, 00, 05, 0, 0, 0, 0, 0, 0, 0, 0, 0.90, 0.60, 0.15, 0.50, 0.25, 0.05, 0.35, 11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 2, 5, 2, 3, 0},
		[0x8608150] = {"Gonzales",	07, 36, 12, 05, 09, 06, 00, 05, 0, 0, 0, 0, 0, 0, 0, 0, 0.90, 0.60, 0.15, 0.50, 0.25, 0.05, 0.35, 07, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 2, 5, 2, 3, 0},
		[0x8608180] = {"Noah",		04, 27, 08, 07, 09, 07, 01, 06, 0, 0, 0, 0, 0, 0, 0, 0, 0.75, 0.30, 0.45, 0.30, 0.30, 0.10, 0.40, 04, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 2, 2, 2, 2, 3},
		[0x86081B0] = {"Trec",		03, 25, 08, 06, 07, 08, 00, 05, 0, 0, 0, 0, 0, 0, 0, 0, 0.85, 0.40, 0.30, 0.35, 0.30, 0.05, 0.50, 03, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 2, 2, 2, 2, 3},
		[0x86081E0] = {"Zealot",	01, 35, 10, 12, 13, 11, 07, 05, 0, 0, 0, 0, 0, 0, 0, 0, 0.75, 0.25, 0.20, 0.20, 0.30, 0.15, 0.15, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8608210] = {"Echidna",	01, 35, 13, 19, 18, 08, 07, 06, 0, 0, 0, 0, 0, 0, 0, 0, 0.75, 0.30, 0.25, 0.30, 0.15, 0.15, 0.20, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8608240] = {"Echidna",	01, 35, 13, 19, 18, 08, 07, 06, 0, 0, 0, 0, 0, 0, 0, 0, 0.75, 0.30, 0.25, 0.30, 0.15, 0.15, 0.20, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8608270] = {"Cecilia",	01, 30, 11, 07, 10, 07, 13, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0.60, 0.35, 0.45, 0.25, 0.20, 0.25, 0.25, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x86082A0] = {"Geese",		10, 33, 10, 09, 09, 08, 00, 09, 0, 0, 0, 0, 0, 0, 0, 0, 0.85, 0.50, 0.30, 0.40, 0.20, 0.10, 0.40, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 3, 4, 1, 3, 0},
		[0x86082D0] = {"Geese",		12, 33, 10, 09, 09, 08, 00, 09, 0, 0, 0, 0, 0, 0, 0, 0, 0.85, 0.50, 0.30, 0.40, 0.20, 0.10, 0.40, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 3, 4, 1, 3, 0},
		[0xbadcafe] = {"",			00,	00,	00,	00,	00,	00,	00,	00, 0, 0, 0, 0, 0, 0, 0, 0, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
	} 
elseif (currentGame == 'Blazing Sword U') then
	UnitsLut = {
		[0x8BDCE4C] = {"Eliwood",	01, 18, 05, 05, 07, 05, 00, 07, 0, 0, 0, 0, 0, 0, 0, 0, 0.80, 0.45, 0.50, 0.40, 0.30, 0.35, 0.45, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDCE80] = {"Hector",	01, 19, 07, 04, 05, 08, 00, 03, 0, 0, 0, 0, 0, 0, 0, 0, 0.90, 0.60, 0.45, 0.35, 0.50, 0.25, 0.30, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDCEB4] = {"Lyn",		04, 18, 05, 10, 11, 02, 00, 05, 0, 0, 0, 0, 0, 0, 0, 0, 0.70, 0.40, 0.60, 0.60, 0.20, 0.30, 0.55, 04, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDCEE8] = {"Raven",		05, 25, 08, 11, 13, 05, 01, 02, 0, 0, 0, 0, 0, 0, 0, 0, 0.85, 0.55, 0.40, 0.45, 0.25, 0.15, 0.35, 05, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDCF1C] = {"Geitz",		03, 40, 17, 12, 13, 11, 03, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0.85, 0.50, 0.30, 0.40, 0.20, 0.20, 0.40, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDCF50] = {"Guy",		03, 21, 06, 11, 11, 05, 00, 05, 0, 0, 0, 0, 0, 0, 0, 0, 0.75, 0.30, 0.50, 0.70, 0.15, 0.25, 0.45, 03, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDCF84] = {"Karel_fe7",	08, 31, 16, 23, 20, 13, 12, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0.70, 0.30, 0.50, 0.50, 0.10, 0.15, 0.30, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDCFB8] = {"Dorcas",	03, 30, 07, 07, 06, 03, 00, 03, 0, 0, 0, 0, 0, 0, 0, 0, 0.80, 0.60, 0.40, 0.20, 0.25, 0.15, 0.45, 03, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDCFEC] = {"Bartre_fe7",02, 29, 09, 05, 03, 04, 00, 04, 0, 0, 0, 0, 0, 0, 0, 0, 0.85, 0.50, 0.35, 0.40, 0.30, 0.25, 0.30, 02, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD020] = {"Citizen",	00, 01, 02, 03, 04, 05, 06, 07, 0, 0, 0, 0, 0, 0, 0, 0, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD054] = {"Oswin",		09, 28, 13, 09, 05, 13, 03, 03, 0, 0, 0, 0, 0, 0, 0, 0, 0.90, 0.40, 0.30, 0.30, 0.55, 0.30, 0.35, 09, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD0BC] = {"Wil",		04, 21, 06, 05, 06, 05, 01, 07, 0, 0, 0, 0, 0, 0, 0, 0, 0.75, 0.50, 0.50, 0.40, 0.20, 0.25, 0.40, 04, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD0F0] = {"Rebecca",	01, 17, 04, 05, 06, 03, 01, 04, 0, 0, 0, 0, 0, 0, 0, 0, 0.60, 0.40, 0.50, 0.60, 0.15, 0.30, 0.50, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD124] = {"Louise",	04, 28, 12, 14, 17, 09, 12, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0.60, 0.40, 0.40, 0.40, 0.20, 0.30, 0.30, 04, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD158] = {"Lucius",	03, 18, 07, 06, 10, 01, 06, 02, 0, 0, 0, 0, 0, 0, 0, 0, 0.55, 0.60, 0.50, 0.40, 0.10, 0.60, 0.20, 03, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD18C] = {"Serra",		01, 17, 02, 05, 08, 02, 05, 06, 0, 0, 0, 0, 0, 0, 0, 0, 0.50, 0.50, 0.30, 0.40, 0.15, 0.55, 0.60, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD1C0] = {"Renault",	16, 43, 12, 22, 20, 15, 18, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0.60, 0.40, 0.30, 0.35, 0.20, 0.40, 0.15, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD1F4] = {"Erk",		01, 17, 05, 06, 07, 02, 04, 03, 0, 0, 0, 0, 0, 0, 0, 0, 0.65, 0.40, 0.40, 0.50, 0.20, 0.40, 0.30, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD228] = {"Nino",		05, 19, 07, 08, 11, 04, 07, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0.55, 0.50, 0.55, 0.60, 0.15, 0.50, 0.45, 05, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD25C] = {"Pent",		06, 33, 18, 21, 17, 11, 16, 14, 0, 0, 0, 0, 0, 0, 0, 0, 0.50, 0.30, 0.20, 0.40, 0.30, 0.35, 0.40, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD290] = {"Canas",		08, 21, 10, 09, 08, 05, 08, 07, 0, 0, 0, 0, 0, 0, 0, 0, 0.70, 0.45, 0.40, 0.35, 0.25, 0.45, 0.25, 08, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD2C4] = {"Kent",		05, 23, 08, 07, 08, 06, 01, 04, 0, 0, 0, 0, 0, 0, 0, 0, 0.85, 0.40, 0.50, 0.45, 0.25, 0.25, 0.20, 05, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD2F8] = {"Sain",		04, 22, 09, 05, 07, 07, 00, 05, 0, 0, 0, 0, 0, 0, 0, 0, 0.80, 0.60, 0.35, 0.40, 0.20, 0.20, 0.35, 04, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD32C] = {"Lowen",		02, 23, 07, 05, 07, 07, 00, 03, 0, 0, 0, 0, 0, 0, 0, 0, 0.90, 0.30, 0.30, 0.30, 0.40, 0.30, 0.50, 02, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD360] = {"Marcus_fe7",01, 31, 15, 15, 11, 10, 08, 08, 0, 0, 0, 0, 0, 0, 0, 0, 0.65, 0.30, 0.50, 0.25, 0.15, 0.35, 0.30, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD394] = {"Priscilla",	03, 16, 06, 06, 08, 03, 06, 07, 0, 0, 0, 0, 0, 0, 0, 0, 0.45, 0.40, 0.50, 0.40, 0.15, 0.50, 0.65, 03, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD3C8] = {"Rath",		09, 27, 09, 10, 11, 08, 02, 05, 0, 0, 0, 0, 0, 0, 0, 0, 0.80, 0.50, 0.40, 0.50, 0.10, 0.25, 0.30, 09, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD3FC] = {"Florina",	03, 18, 06, 08, 09, 04, 05, 08, 0, 0, 0, 0, 0, 0, 0, 0, 0.60, 0.40, 0.50, 0.55, 0.15, 0.35, 0.50, 03, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD430] = {"Fiora",		07, 21, 08, 11, 13, 06, 07, 06, 0, 0, 0, 0, 0, 0, 0, 0, 0.70, 0.35, 0.60, 0.50, 0.20, 0.50, 0.30, 07, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD464] = {"Farina",	12, 24, 10, 13, 14, 10, 12, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0.75, 0.50, 0.40, 0.45, 0.25, 0.30, 0.45, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD498] = {"Heath",		07, 28, 11, 08, 07, 10, 01, 07, 0, 0, 0, 0, 0, 0, 0, 0, 0.80, 0.50, 0.50, 0.45, 0.30, 0.20, 0.20, 07, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD4CC] = {"Vaida",		09, 43, 20, 19, 13, 21, 06, 11, 0, 0, 0, 0, 0, 0, 0, 0, 0.60, 0.45, 0.25, 0.40, 0.25, 0.15, 0.30, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD500] = {"Hawkeye",	04, 50, 18, 14, 11, 14, 10, 13, 0, 0, 0, 0, 0, 0, 0, 0, 0.50, 0.40, 0.30, 0.25, 0.20, 0.35, 0.40, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD534] = {"Matthew",	02, 18, 04, 04, 11, 03, 00, 02, 0, 0, 0, 0, 0, 0, 0, 0, 0.75, 0.30, 0.40, 0.70, 0.25, 0.20, 0.50, 02, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD568] = {"Jaffar",	13, 34, 19, 25, 24, 15, 11, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0.65, 0.15, 0.40, 0.35, 0.30, 0.30, 0.20, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD59C] = {"Ninian",	01, 14, 00, 00, 12, 05, 04, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0.85, 0.05, 0.05, 0.70, 0.30, 0.70, 0.80, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD5D0] = {"Nils",		01, 14, 00, 00, 12, 05, 04, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0.85, 0.05, 0.05, 0.70, 0.30, 0.70, 0.80, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD604] = {"Athos",		20, 40, 30, 24, 20, 20, 28, 25, 0, 0, 0, 0, 0, 0, 0, 0, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 20, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD66C] = {"Nils",		01, 14, 00, 00, 12, 05, 04, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0.85, 0.05, 0.05, 0.70, 0.30, 0.70, 0.80, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD708] = {"Wallace",	01, 34, 16, 09, 08, 19, 05, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0.70, 0.45, 0.40, 0.20, 0.35, 0.35, 0.30, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD73C] = {"Lyn",		01, 16, 04, 07, 09, 02, 00, 05, 0, 0, 0, 0, 0, 0, 0, 0, 0.70, 0.40, 0.60, 0.60, 0.20, 0.30, 0.55, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD770] = {"Wil",		02, 20, 06, 05, 05, 05, 00, 06, 0, 0, 0, 0, 0, 0, 0, 0, 0.75, 0.50, 0.50, 0.40, 0.20, 0.25, 0.40, 02, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD7A4] = {"Kent",		01, 20, 06, 06, 07, 05, 01, 02, 0, 0, 0, 0, 0, 0, 0, 0, 0.85, 0.40, 0.50, 0.45, 0.25, 0.25, 0.20, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD7D8] = {"Sain",		01, 19, 08, 04, 06, 06, 00, 04, 0, 0, 0, 0, 0, 0, 0, 0, 0.80, 0.60, 0.35, 0.40, 0.20, 0.20, 0.35, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD80C] = {"Florina",	01, 17, 05, 07, 09, 04, 04, 07, 0, 0, 0, 0, 0, 0, 0, 0, 0.60, 0.40, 0.50, 0.55, 0.15, 0.35, 0.50, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD840] = {"Rath",		07, 25, 08, 09, 10, 07, 02, 05, 0, 0, 0, 0, 0, 0, 0, 0, 0.80, 0.50, 0.40, 0.50, 0.10, 0.25, 0.30, 07, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD874] = {"Dart",		08, 34, 12, 08, 08, 06, 01, 03, 0, 0, 0, 0, 0, 0, 0, 0, 0.70, 0.65, 0.20, 0.60, 0.20, 0.15, 0.35, 08, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD8A8] = {"Isadora",	01, 28, 13, 12, 16, 08, 06, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0.75, 0.30, 0.35, 0.50, 0.20, 0.25, 0.45, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD910] = {"Legault",	12, 26, 08, 11, 15, 08, 03, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0.60, 0.25, 0.45, 0.60, 0.25, 0.25, 0.60, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD944] = {"Karla",		05, 29, 14, 21, 18, 11, 12, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0.60, 0.25, 0.45, 0.55, 0.10, 0.20, 0.40, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8BDD978] = {"Harken",	08, 38, 21, 20, 17, 15, 10, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0.80, 0.35, 0.30, 0.40, 0.30, 0.25, 0.20, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0xbadcafe] = {"",			00,	00,	00,	00,	00,	00,	00,	00, 0, 0, 0, 0, 0, 0, 0, 0, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
	}
else
	UnitsLut = {
		[0x8803D64] = {"Eirika",	01,	16,	04,	08,	09,	03,	01,	05, 0, 0, 0, 0, 0, 0, 0, 0, 0.70, 0.40, 0.60, 0.60, 0.30, 0.30, 0.60, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8803D98] = {"Seth",		01,	30,	14,	13,	12,	11,	08,	13, 0, 0, 0, 0, 0, 0, 0, 0, 0.90, 0.50, 0.45, 0.45, 0.40, 0.30, 0.25, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8803E00] = {"Franz",		01,	20,	07,	05,	07,	06,	01,	02, 0, 0, 0, 0, 0, 0, 0, 0, 0.80, 0.40, 0.40, 0.50, 0.25, 0.20, 0.40, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8803DCC] = {"Gilliam",	04,	25,	09,	06,	03,	09,	03,	03, 0, 0, 0, 0, 0, 0, 0, 0, 0.90, 0.45, 0.35, 0.30, 0.55, 0.20, 0.30, 04, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8803E68] = {"Vanessa",	01,	17,	05,	07,	11,	06,	05,	04, 0, 0, 0, 0, 0, 0, 0, 0, 0.70, 0.40, 0.50, 0.40, 0.25, 0.25, 0.20, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8803E34] = {"Moulder",	03,	20,	04,	06,	09,	02,	05,	01, 0, 0, 0, 0, 0, 0, 0, 0, 0.50, 0.35, 0.55, 0.60, 0.20, 0.30, 0.50, 03, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8803E9C] = {"Ross",		01,	15,	05,	02,	03,	03,	00,	08, 0, 0, 0, 0, 0, 0, 0, 0, 0.70, 0.50, 0.35, 0.30, 0.25, 0.20, 0.40, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
		[0x8803F38] = {"Garcia",	04,	28,	08,	07,	07,	05,	01,	03, 0, 0, 0, 0, 0, 0, 0, 0, 0.80, 0.65, 0.40, 0.20, 0.25, 0.15, 0.40, 04, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8803ED0] = {"Neimi",		01,	17,	04,	05,	06,	03,	02,	04, 0, 0, 0, 0, 0, 0, 0, 0, 0.55, 0.45, 0.50, 0.60, 0.15, 0.35, 0.50, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8803F04] = {"Colm",		02,	18,	04,	04,	10,	03,	01,	08, 0, 0, 0, 0, 0, 0, 0, 0, 0.75, 0.40, 0.40, 0.65, 0.25, 0.20, 0.45, 02, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x880410C] = {"Artur",		02,	19,	06,	06,	08,	02,	06,	02, 0, 0, 0, 0, 0, 0, 0, 0, 0.55, 0.50, 0.50, 0.40, 0.15, 0.55, 0.25, 02, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8803FA0] = {"Lute",		01,	17,	06,	06,	07,	03,	05,	08, 0, 0, 0, 0, 0, 0, 0, 0, 0.45, 0.65, 0.30, 0.45, 0.15, 0.40, 0.45, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8803FD4] = {"Natasha",	01,	18,	02,	04,	08,	02,	06,	06, 0, 0, 0, 0, 0, 0, 0, 0, 0.50, 0.60, 0.25, 0.40, 0.15, 0.55, 0.60, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x88043B0] = {"Joshua",	05,	24,	08,	13,	14,	05,	02,	07, 0, 0, 0, 0, 0, 0, 0, 0, 0.80, 0.35, 0.55, 0.55, 0.20, 0.20, 0.30, 05, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x880403C] = {"Ephraim",	04,	23,	08,	09,	11,	07,	02,	08, 0, 0, 0, 0, 0, 0, 0, 0, 0.80, 0.55, 0.55, 0.45, 0.35, 0.25, 0.50, 04, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8804070] = {"Forde",		06,	24,	07,	08,	08,	08,	02,	07, 0, 0, 0, 0, 0, 0, 0, 0, 0.85, 0.40, 0.50, 0.45, 0.20, 0.25, 0.35, 06, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x88040A4] = {"Kyle",		05,	25,	09,	06,	07,	09,	01,	06, 0, 0, 0, 0, 0, 0, 0, 0, 0.90, 0.50, 0.40, 0.40, 0.25, 0.20, 0.20, 05, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8804A98] = {"Orson",		03,	34,	15,	13,	11,	13,	07,	04, 0, 0, 0, 0, 0, 0, 0, 0, 0.80, 0.55, 0.45, 0.40, 0.45, 0.30, 0.25, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8804418] = {"Tana",		04,	20,	07,	09,	13,	06,	07,	08, 0, 0, 0, 0, 0, 0, 0, 0, 0.65, 0.45, 0.40, 0.65, 0.20, 0.25, 0.60, 04, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x88040D8] = {"Amelia",	01,	16,	04,	03,	04,	02,	03,	06, 0, 0, 0, 0, 0, 0, 0, 0, 0.60, 0.35, 0.40, 0.40, 0.30, 0.15, 0.50, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
		[0x8803F6C] = {"Innes",		01,	31,	14,	13,	15,	10,	09,	14, 0, 0, 0, 0, 0, 0, 0, 0, 0.75, 0.40, 0.40, 0.45, 0.20, 0.25, 0.45, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8804140] = {"Gerik",		10,	32,	14,	13,	13,	10,	04,	08, 0, 0, 0, 0, 0, 0, 0, 0, 0.90, 0.45, 0.40, 0.30, 0.35, 0.25, 0.30, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8804174] = {"Tethys",	01,	18,	01,	02,	12,	05,	04,	10, 0, 0, 0, 0, 0, 0, 0, 0, 0.85, 0.05, 0.10, 0.70, 0.30, 0.75, 0.80, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x88041A8] = {"Marisa",	05,	23,	07,	12,	13,	04,	03,	09, 0, 0, 0, 0, 0, 0, 0, 0, 0.75, 0.30, 0.55, 0.60, 0.15, 0.25, 0.50, 05, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8804244] = {"L\'Arachel",03,	18,	06,	06,	10,	05,	08,	12, 0, 0, 0, 0, 0, 0, 0, 0, 0.45, 0.50, 0.45, 0.45, 0.15, 0.50, 0.65, 03, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8804278] = {"Dozla",		01,	43,	16,	11,	09,	11,	06,	04, 0, 0, 0, 0, 0, 0, 0, 0, 0.85, 0.50, 0.35, 0.40, 0.30, 0.25, 0.30, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x88041DC] = {"Saleh",		01,	30,	16,	18,	14,	08,	13,	11, 0, 0, 0, 0, 0, 0, 0, 0, 0.50, 0.30, 0.25, 0.40, 0.30, 0.35, 0.40, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8804210] = {"Ewan",		01,	15,	03,	02,	05,	00,	03,	05, 0, 0, 0, 0, 0, 0, 0, 0, 0.50, 0.45, 0.40, 0.35, 0.15, 0.40, 0.50, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
		[0x8804008] = {"Cormag",	09,	30,	14,	09,	10,	12,	02,	04, 0, 0, 0, 0, 0, 0, 0, 0, 0.85, 0.55, 0.40, 0.45, 0.25, 0.15, 0.35, 09, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x88042E0] = {"Rennac",	01,	28,	10,	16,	17,	09,	11,	05, 0, 0, 0, 0, 0, 0, 0, 0, 0.65, 0.25, 0.45, 0.60, 0.25, 0.30, 0.25, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8804314] = {"Duessel",	08,	41,	17,	12,	12,	17,	09,	08, 0, 0, 0, 0, 0, 0, 0, 0, 0.85, 0.55, 0.40, 0.30, 0.45, 0.30, 0.20, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x880437C] = {"Knoll",		10,	22,	13,	09,	08,	02,	10,	00, 0, 0, 0, 0, 0, 0, 0, 0, 0.70, 0.50, 0.40, 0.35, 0.10, 0.45, 0.20, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x8804348] = {"Myrrh",		01,	15,	03,	01,	05,	02,	07,	03, 0, 0, 0, 0, 0, 0, 0, 0, 1.30, 0.90, 0.85, 0.65, 1.50, 0.30, 0.30, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0x88043E4] = {"Syrene",	01,	27,	12,	13,	15,	10,	12,	12, 0, 0, 0, 0, 0, 0, 0, 0, 0.70, 0.40, 0.50, 0.60, 0.20, 0.50, 0.30, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[0xbadcafe] = {"",			00,	00,	00,	00,	00,	00,	00,	00, 0, 0, 0, 0, 0, 0, 0, 0, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
	}
end

function saveSessionData()
    local file = io.open("session_data.csv", "w")
    if file then
		file:write("KEY,NAME,PP_LVL,PROMOTED,TRAINEE_STATE\n")
		for key, unit_info in pairs(UnitsLut) do
			if (key ~= 0xbadcafe) then
				file:write(key..","..unit_info[1]..","..unit_info[25]..","..unit_info[34]..","..unit_info[35].."\n")
			end
		end
		file:write("num_displayed_units"..","..num_displayed_units)
        file:close()
    end
end

local file_r = io.open("session_data.csv", "r")

function loadSessionData()
	if file_r then
		for line in io.lines("session_data.csv") do
			local columns = {}
			for value in line:gmatch("([^,]+)") do
				table.insert(columns, value)
			end
			if(columns[1] ~= 'KEY') then
				key = tonumber(columns[1])
				if(UnitsLut[key] ~= nil) then
					UnitsLut[key][25] = tonumber(columns[3])
					UnitsLut[key][34] = tonumber(columns[4])
					UnitsLut[key][35] = tonumber(columns[5])
				end
			end
			if(columns[1] == 'num_displayed_units') then
				num_displayed_units = tonumber(columns[2])
			end
		end
	end
end

local CurrentUnits = {}

heldDown = {
	['R'] = false, 
	['slash'] = false,
	['L'] = false
}

function superRNToRN(srn)
	return math.floor(srn/superRNToRNConversionDivisor)
end

function nextSuperRN(r1, r2, r3)
    -- Given three sequential RNG values, generate a fourth
    -- use the bit library for compatibility with Lua 5.1/5.2 in VBA-RR
    return bit.band(bit.bxor(bit.bxor(bit.bxor(bit.rshift(r3,5), bit.lshift(r2,11)),bit.lshift(r1,1)),bit.rshift(r2,15)), 0xFFFF)
end

function printRNG(n)
	-- Print n entries of the RNG table
	RNGTable = RNGSimulate(n)
	-- Print each RNG value
	for i=1,n do
		gui.text(228, 8*(i-1) + 2, string.format("%3d", superRNToRN(RNGTable[i])))
	end
end

function RNGSimulate(n)
	-- Generate n entries of the RNG table (including the 3 RNs used for the RNG seed)
	local result = { memory.readword(RNGBase+4), memory.readword(RNGBase+2), memory.readword(RNGBase) }
	advanceRNGTable(result,3)
	for i = 4, n do
		result[i] = nextSuperRN(result[i-3],result[i-2],result[i-1])
	end
	return result
end

function advanceRNGTable(RNGTable,n)
	if n == 0 then
		return RNGTable
	end
	for i = 1, math.abs(n), 1 do
		local nextRN
		if n > 0 then
			nextRN = nextSuperRN(RNGTable[#RNGTable-2], RNGTable[#RNGTable-1], RNGTable[#RNGTable])
			for j = 1, #RNGTable - 1, 1 do
				RNGTable[j] = RNGTable[j+1]
			end
			RNGTable[#RNGTable] = nextRN
		else
			nextRN = previousSuperRN(RNGTable[1], RNGTable[2], RNGTable[3])
			for j = #RNGTable, 2, -1 do
				RNGTable[j] = RNGTable[j-1]
			end
			RNGTable[1] = nextRN
		end
	end
	return RNGTable
end

function advanceRNG()
	-- Identify the memory addresses of the first 4 RNG values
	local RNG1 =  memory.readword(RNGBase+4)
	local RNG2 =  memory.readword(RNGBase+2)
	local RNG3 = memory.readword(RNGBase)
	local RNG4 = nextSuperRN(RNG1, RNG2, RNG3)
	-- Swap the values in RNG Seed 1,2,3 by the RNG values 2,3,4
	memory.writeword(RNGBase + 4, RNG2)
	memory.writeword(RNGBase + 2, RNG3)
	memory.writeword(RNGBase + 0, RNG4)
end

function checkForUserInput()
	if userInput.R and heldDown['R'] == false then
		-- help display on/off
		displayRNG = not displayRNG
	end
	if userInput.slash and heldDown['slash'] == false then
		current_color = (current_color + 1) % 6
		background_color = color_arr[current_color][1]
		foreground_color = color_arr[current_color][2]
		re_draw = 1
	end
	if userInput.L and heldDown['L'] == false then
		if (isDisplayActive()) then
			displayed_unit_index = (displayed_unit_index + 1) % #CurrentUnits
			re_draw = 1
		else
			re_draw = 1
		end
		display_frame_start = emu.framecount()
	end
	for key, value in pairs(heldDown) do
		heldDown[key] = true
		if userInput[key] == nil then
			heldDown[key] = false
		end
	end
end

-- Check if display window should still be open
function isDisplayActive()
	if (emu.framecount() < display_duration) then
		display_frame_start = 0
		return false
	end
	local elapsed = emu.framecount() - display_frame_start
	return elapsed < display_duration
end

--current data of who we're working on
local Cdata = {
	['lookupKey'] = 0,
	['lvl'] = 0,
	['maxHP'] = 0,
	['str'] = 0,
	['skl'] = 0,
	['spd'] = 0,
	['def'] = 0,
	['res'] = 0,
	['lck'] = 0,
	['lvls_gained'] = 0
}
local unit_arr = {}
local addr = 0

local baseAddress = baseAddressMap[currentGame]

local stat_mem_offset = 0
local name_horiz_offset = 37
local name_vertical_offset = 0x8803D30
local memory_diff_value = 52
local class_promo_offset = 0x29
local chap_start_addr = 0x0202BCF4
local map_id_addr = 0x0202BCFE
local record_turns_initial_addr = 0x0203ECf4
if currentGame == 'Sealed Sword J' then
	stat_mem_offset = -2
	name_horiz_offset = 69
	name_vertical_offset = 0x8607688
	memory_diff_value = 48
	class_promo_offset = 0x25
	chap_start_addr = 0x0202AA4C
	map_id_addr = 0x0202AA56
	record_turns_initial_addr = 0x0203D994
elseif (currentGame == 'Blazing Sword U') then
	name_vertical_offset = 0x8BDCE18
	name_horiz_offset = 101
	chap_start_addr = 0x0202BBFC
	map_id_addr = 0x0202BC06
	record_turns_initial_addr = 0x0203EC00
end

local lastMapID = 0
local session_data_counter = 0
function updateLUT_stage1(char_number) -- ~3us on average
	addr = baseAddress + (char_number*0x48)
	local Rom_unit = read_u32_le(addr)
	Cdata['lookupKey'] = Rom_unit
	unit_arr = UnitsLut[Cdata['lookupKey']]
	local MapID = memory.readbyte(map_id_addr)
	-- I did this 10 frame wait thing to do session data stuff because sometimes the record turns doesn't load quick enough
	if (MapID ~= lastMapID) then  session_data_counter = session_data_counter + 1 end
	if (session_data_counter > 10) then
		if lastMapID == 0 then -- we loaded a save file (or I guess just finished chapter 0)
			local record_turns_data = read_u32_le(record_turns_initial_addr)
			if (record_turns_data ~= 0) then -- make sure chapter 1 has been finished before loading Session data
				-- if chapter 1 has not been finished, then we will end up saving session data before we load it, making a new file
				loadSessionData()
				print("Session data loaded")
			end
			lastMapID = MapID
		else
			saveSessionData()
			print("Session data saved to session_data.csv")
			lastMapID = MapID
		end
		session_data_counter = 0
	end
	
end

function updateLUT_stage2(char_number) -- ~7-15us on average
    unit_arr = UnitsLut[Cdata['lookupKey']]
    local bytes = read_bytes(addr + 0x8, 18)
    lvl = bytes[1]
    -- if our current level is less than pp_level, then we just promoted
    unit_arr[10] = lvl
    Cdata['lvl'] = lvl
    -- For some reason in some cutscenes characters will load with lvl 1 when their base level wasn't 1.
    -- My current solution is to only process promotions if their current class is a promoted class too (this could be flawed somewhere)
    -- I also check to see if the unit is a cutscene character (bytes[7] == 64), but they're not always marked right
    if (unit_arr[10] < unit_arr[25] and unit_arr[34] == 0) then -- if current level is less than pp_level, then we just promoted
        rom_class = read_u32_le(addr+0x4)
        promoted_class = bit.band(memory.readbyte(rom_class+class_promo_offset), 0x1)
        if (promoted_class == 1 and bytes[7] ~= 64) then
            unit_arr[34] = 1
            re_draw = 1
        else
            return
        end
    end	
	-- If we're not promoted and have gained a level, add it to pp_lvl
	if unit_arr[34] == 0 and unit_arr[25] ~= 0 then
		unit_arr[25] = lvl
	end
	local maxHP = bytes[11+stat_mem_offset]
	Cdata['maxHP'] = maxHP
	unit_arr[11] = maxHP
	local str = bytes[13+stat_mem_offset]
	Cdata['str'] = str
	unit_arr[12] = str
	local skl = bytes[14+stat_mem_offset]
	Cdata['skl'] = skl
	unit_arr[13] = skl
	local spd = bytes[15+stat_mem_offset]
	Cdata['spd'] = spd
	unit_arr[14] = spd
	local def = bytes[16+stat_mem_offset]
	Cdata['def'] = def
	unit_arr[15] = def
	local res = bytes[17+stat_mem_offset]
	Cdata['res'] = res
	unit_arr[16] = res
	local lck = bytes[18+stat_mem_offset]
	Cdata['lck'] = lck
	unit_arr[17] = lck
end

function updateLUT_stage3() -- probably 20+ us at this point
	local promo_hp_gain = 0
	local promo_str_gain = 0
	local promo_skl_gain = 0
	local promo_spd_gain = 0
	local promo_def_gain = 0
	local promo_res_gain = 0
	-- if level < pp_lvl, then we're a (somewhat) freshly promoted unit

	rom_class = read_u32_le(addr+0x4)
    if currentGame == 'Sealed Sword J' then
        class_info_arr = read_bytes(rom_class + 0x13, 6)
    else
        class_info_arr = read_bytes(rom_class + 0x13, 21)
    end
	-- arr[1:6] is max stats
	-- arr[16:21] is promotion gains (FE8)

	

	local promo_hp_gain = 0
	local promo_str_gain = 0
	local promo_skl_gain = 0
	local promo_spd_gain = 0
	local promo_def_gain = 0
	local promo_res_gain = 0
	local avg_hp = 0
	local avg_str = 0
	local avg_skl = 0
	local avg_spd = 0
	local avg_def = 0
	local avg_res = 0
	local avg_lck = 0
	local lvl_gained = 0
	-- handle the trainees first
	-- add trainee promo bonuses here
	if (unit_arr[35] > 0) then
		if (unit_arr[35] == 1 and unit_arr[10] == 10) then
			unit_arr[35] = 2 -- trainee unit is ready to promote, but not promoted yet
		end
		if (unit_arr[35] == 2 and unit_arr[10] == 1) then
			unit_arr[35] = 3 -- trainee unit is promoted out of trainee class
			unit_arr[25] = 1
			re_draw = 1
		end
		if unit_arr[34] == 1 then -- if promoted
			promo_hp_gain = class_info_arr[16]
			promo_str_gain = class_info_arr[17]
			promo_skl_gain = class_info_arr[18]
			promo_spd_gain = class_info_arr[19]
			promo_def_gain = class_info_arr[20]
			promo_res_gain = class_info_arr[21]

			avg_hp =  math.min(class_info_arr[1], math.floor(math.min(60, unit_arr[03] + (unit_arr[25] + 10 - 2) * unit_arr[18] + ppp_promo_gains[1]) + (unit_arr[10] - 1) * unit_arr[18] + 0.5) + promo_hp_gain)
			avg_str = math.min(class_info_arr[2], math.floor(math.min(20, unit_arr[04] + (unit_arr[25] + 10 - 2) * unit_arr[19] + ppp_promo_gains[2]) + (unit_arr[10] - 1) * unit_arr[19] + 0.5) + promo_str_gain)
			avg_skl = math.min(class_info_arr[3], math.floor(math.min(20, unit_arr[05] + (unit_arr[25] + 10 - 2) * unit_arr[20] + ppp_promo_gains[3]) + (unit_arr[10] - 1) * unit_arr[20] + 0.5) + promo_skl_gain)
			avg_spd = math.min(class_info_arr[4], math.floor(math.min(20, unit_arr[06] + (unit_arr[25] + 10 - 2) * unit_arr[21] + ppp_promo_gains[4]) + (unit_arr[10] - 1) * unit_arr[21] + 0.5) + promo_spd_gain)
			avg_def = math.min(class_info_arr[5], math.floor(math.min(20, unit_arr[07] + (unit_arr[25] + 10 - 2) * unit_arr[22] + ppp_promo_gains[5]) + (unit_arr[10] - 1) * unit_arr[22] + 0.5) + promo_def_gain)
			avg_res = math.min(class_info_arr[6], math.floor(math.min(20, unit_arr[08] + (unit_arr[25] + 10 - 2) * unit_arr[23] + ppp_promo_gains[6]) + (unit_arr[10] - 1) * unit_arr[23] + 0.5) + promo_res_gain)
			avg_lck = math.min(30               , math.floor(math.min(30, unit_arr[09] + (unit_arr[25] + 10 - 2) * unit_arr[24]                     ) + (unit_arr[10] - 1) * unit_arr[24] + 0.5))
			Cdata['lvls_gained'] = unit_arr[10] - 1 + unit_arr[25] - unit_arr[2] + 10 - 1
		else
			if (unit_arr[35] == 3) then
				avg_hp =  math.min(class_info_arr[1], unit_arr[03] + math.floor((unit_arr[10] + 10 - 2) * unit_arr[18] + 0.5 + ppp_promo_gains[1]))
				avg_str = math.min(class_info_arr[2], unit_arr[04] + math.floor((unit_arr[10] + 10 - 2) * unit_arr[19] + 0.5 + ppp_promo_gains[2]))
				avg_skl = math.min(class_info_arr[3], unit_arr[05] + math.floor((unit_arr[10] + 10 - 2) * unit_arr[20] + 0.5 + ppp_promo_gains[3]))
				avg_spd = math.min(class_info_arr[4], unit_arr[06] + math.floor((unit_arr[10] + 10 - 2) * unit_arr[21] + 0.5 + ppp_promo_gains[4]))
				avg_def = math.min(class_info_arr[5], unit_arr[07] + math.floor((unit_arr[10] + 10 - 2) * unit_arr[22] + 0.5 + ppp_promo_gains[5]))
				avg_res = math.min(class_info_arr[6], unit_arr[08] + math.floor((unit_arr[10] + 10 - 2) * unit_arr[23] + 0.5 + ppp_promo_gains[6]))
				avg_lck = math.min(30, 				  unit_arr[09] + math.floor((unit_arr[10] + 10 - 2) * unit_arr[24] + 0.5))
				Cdata['lvls_gained'] = unit_arr[25] - unit_arr[2] + 10 - 1
			else
				avg_hp =  math.min(class_info_arr[1], unit_arr[03] + math.floor((unit_arr[10] - 1) * unit_arr[18] + 0.5))
				avg_str = math.min(class_info_arr[2], unit_arr[04] + math.floor((unit_arr[10] - 1) * unit_arr[19] + 0.5))
				avg_skl = math.min(class_info_arr[3], unit_arr[05] + math.floor((unit_arr[10] - 1) * unit_arr[20] + 0.5))
				avg_spd = math.min(class_info_arr[4], unit_arr[06] + math.floor((unit_arr[10] - 1) * unit_arr[21] + 0.5))
				avg_def = math.min(class_info_arr[5], unit_arr[07] + math.floor((unit_arr[10] - 1) * unit_arr[22] + 0.5))
				avg_res = math.min(class_info_arr[6], unit_arr[08] + math.floor((unit_arr[10] - 1) * unit_arr[23] + 0.5))
				avg_lck = math.min(30, 				  unit_arr[09] + math.floor((unit_arr[10] - 1) * unit_arr[24] + 0.5))
				Cdata['lvls_gained'] = unit_arr[10] - unit_arr[2]
			end
		end
	else -- not a trainee (thank goodness)
		if unit_arr[34] == 1 then -- if promoted 
			if currentGame == 'Sealed Sword J' then
				promo_gains = {unit_arr[36], unit_arr[37], unit_arr[38], unit_arr[39], unit_arr[40], unit_arr[41]}
			else
				promo_gains = {class_info_arr[16], class_info_arr[17], class_info_arr[18], class_info_arr[19], class_info_arr[20], class_info_arr[21]}
			end
			-- get the min of avg pp_stats and pp_class max, and then min of promoted level stats and promoted maxes added to the previous value
			--                 promoted caps            pp_caps  bases                      pp_levels     base_lvl        growth          current_lvl          growths
			avg_hp =  math.min(class_info_arr[1], math.floor(math.min(60, unit_arr[03] + (unit_arr[25] - unit_arr[2]) * unit_arr[18]) + (unit_arr[10] - 1) * unit_arr[18] + 0.5) + promo_gains[1])
			avg_str = math.min(class_info_arr[2], math.floor(math.min(20, unit_arr[04] + (unit_arr[25] - unit_arr[2]) * unit_arr[19]) + (unit_arr[10] - 1) * unit_arr[19] + 0.5) + promo_gains[2])
			avg_skl = math.min(class_info_arr[3], math.floor(math.min(20, unit_arr[05] + (unit_arr[25] - unit_arr[2]) * unit_arr[20]) + (unit_arr[10] - 1) * unit_arr[20] + 0.5) + promo_gains[3])
			avg_spd = math.min(class_info_arr[4], math.floor(math.min(20, unit_arr[06] + (unit_arr[25] - unit_arr[2]) * unit_arr[21]) + (unit_arr[10] - 1) * unit_arr[21] + 0.5) + promo_gains[4])
			avg_def = math.min(class_info_arr[5], math.floor(math.min(20, unit_arr[07] + (unit_arr[25] - unit_arr[2]) * unit_arr[22]) + (unit_arr[10] - 1) * unit_arr[22] + 0.5) + promo_gains[5])
			avg_res = math.min(class_info_arr[6], math.floor(math.min(20, unit_arr[08] + (unit_arr[25] - unit_arr[2]) * unit_arr[23]) + (unit_arr[10] - 1) * unit_arr[23] + 0.5) + promo_gains[6])
			avg_lck = math.min(30               , math.floor(math.min(30, unit_arr[09] + (unit_arr[25] - unit_arr[2]) * unit_arr[24]) + (unit_arr[10] - 1) * unit_arr[24] + 0.5))
			if (unit_arr[25] == 0) then -- if pp_lvl == 0 then we're a pre-premote. do lvl - base
				Cdata['lvls_gained'] = unit_arr[10] - unit_arr[2]
			elseif unit_arr[34] == 1 then -- we were promoted, so do lvl - 1 + pp_lvl - b_lvl
				Cdata['lvls_gained'] = unit_arr[10] - 1 + unit_arr[25] - unit_arr[2]
			end
		else -- unpromoted unit
			avg_hp =  math.min(class_info_arr[1], unit_arr[03] + math.floor((unit_arr[10] - unit_arr[2]) * unit_arr[18] + 0.5))
			avg_str = math.min(class_info_arr[2], unit_arr[04] + math.floor((unit_arr[10] - unit_arr[2]) * unit_arr[19] + 0.5))
			avg_skl = math.min(class_info_arr[3], unit_arr[05] + math.floor((unit_arr[10] - unit_arr[2]) * unit_arr[20] + 0.5))
			avg_spd = math.min(class_info_arr[4], unit_arr[06] + math.floor((unit_arr[10] - unit_arr[2]) * unit_arr[21] + 0.5))
			avg_def = math.min(class_info_arr[5], unit_arr[07] + math.floor((unit_arr[10] - unit_arr[2]) * unit_arr[22] + 0.5))
			avg_res = math.min(class_info_arr[6], unit_arr[08] + math.floor((unit_arr[10] - unit_arr[2]) * unit_arr[23] + 0.5))
			avg_lck = math.min(30, 				  unit_arr[09] + math.floor((unit_arr[10] - unit_arr[2]) * unit_arr[24] + 0.5))
			Cdata['lvls_gained'] = unit_arr[25] - unit_arr[2]
		end
	end
	-- We just leveled up
	if (unit_arr[33] < Cdata['lvls_gained']) then
		re_draw = 1
		lvl_gained = 1
	end
	unit_arr[33] = Cdata['lvls_gained']
	unit_arr[26] = Cdata['maxHP']-avg_hp
	unit_arr[27] = Cdata['str']-avg_str
	unit_arr[28] = Cdata['skl']-avg_skl
	unit_arr[29] = Cdata['spd']-avg_spd
	unit_arr[30] = Cdata['def']-avg_def
	unit_arr[31] = Cdata['res']-avg_res
	unit_arr[32] = Cdata['lck']-avg_lck
end

function updateLUT_stage4() -- ~1.4us on average
	if (Cdata['lvls_gained'] > 0) then 
		if (unit_arr[11] > 0) then
			local i = #CurrentUnits
			local inserted = false
			while i > 0 do
				if CurrentUnits[i] == Cdata['lookupKey'] and not(inserted) then
					if (level_gained == 1) then
						displayed_unit_index = i
						lvl_gained = 0
					end
					return
				end
				if (inserted) then
					if Cdata['lookupKey'] == CurrentUnits[i] then
						table.remove(CurrentUnits,i)
						re_draw = 1
					end
				elseif (Cdata['lvls_gained'] > UnitsLut[CurrentUnits[i]][33]) then
					table.insert(CurrentUnits, i+1, Cdata['lookupKey'])
					inserted = true
					re_draw = 1
					display_frame_start = emu.framecount()
					if (level_gained == 1) then
						displayed_unit_index = i
						lvl_gained = 0
					end
					i = i + 1
				end
				i = i - 1;
			end
			if #CurrentUnits == 0 then
				table.insert(CurrentUnits, 1, Cdata['lookupKey'])
				re_draw = 1
				display_frame_start = emu.framecount()
				if (level_gained == 1) then
					displayed_unit_index = 0
					lvl_gained = 0
				end
			elseif (not(inserted) and Cdata['lvls_gained'] > 0 and not(contains(CurrentUnits, Cdata['lookupKey']))) then
				table.insert(CurrentUnits, 1, Cdata['lookupKey'])
				re_draw = 1
				display_frame_start = emu.framecount()
				if (level_gained == 1) then
					displayed_unit_index = 0
					lvl_gained = 0
				end
			end
		end
	end
end

local opened_gd_files = {}
function drawGD(x,y,path,srcx,srcy,w,h,a)
	if opened_gd_files[path] == nil then
		local f = io.open(path, "rb")
		local gd_string = f:read("*all")
		f:close()
		opened_gd_files[path] = gd_string
	end
	gui.gdoverlay(x,y, opened_gd_files[path], srcx, srcy, w, h, a)
end


function drawUnit(unitIndex)
	-- no valid unit? abort
	local opacity = math.min(((display_duration - (emu.framecount() - display_frame_start))/display_duration) * 2, .90)
	if CurrentUnits[unitIndex+1] == nil then return end
	unitAddr = CurrentUnits[unitIndex+1]
	local unitInfo = UnitsLut[unitAddr]
	if unitInfo[1] == '' then return end
	if unitIndex < 0 or unitIndex >= #CurrentUnits then return end
	local unitAddr = CurrentUnits[unitIndex+1]
	if unitAddr == 0xbadcafe then return end
	-- right side card, opacity handled by drawBoxVBA
	local width_unit = 48
	local x0 = bufferwidth - width_unit
	local fg_color = colorWithOpacity(foreground_color, opacity)
	local bg_color = colorWithOpacity(background_color, opacity)
	
	-- background and borders
	gui.box(x0, 0, x0+width_unit, 122, bg_color, fg_color)
	gui.line(x0+15, 0, x0+15, 121, fg_color)
	for stat_y = 42, 112, 10 do
		gui.line(x0, stat_y, x0+width_unit, stat_y, fg_color)
	end
	
	-- draw stat icons via gdoverlay with 50% alpha
	for i, y in ipairs({45,55,65,75,85,95,105,115}) do
		-- each icon is 13x6, srcX increments by 13 per icon
		drawGD(x0+1, y, "images/ref_img.gd", 0, (i-1)*6, 13, 6, opacity)
	end

	-- portrait still drawn as image (user didn't ask to remove)
	drawGD(x0+width_unit-32, 1,"images/"..unitInfo[1]..".gd",0,0,32,32,opacity )
	
	-- draw name region via gdoverlay
	local name_index = math.floor((CurrentUnits[unitIndex+1] - name_vertical_offset)/memory_diff_value)
	drawGD(x0+width_unit-32, 35, "images/ref_img.gd", name_horiz_offset, 0 + name_index*6, 32, 6, opacity)
	
	-- Draw lvl
	drawGD(x0+width_unit-21, 45, "images/ref_img.gd", 13, 0 + unitInfo[10]*6, 9, 6, opacity)
	-- draw stat values via gdoverlay (numbers are in second column of ref_img)
	for _, data in ipairs({
		{unitInfo[11],55},{unitInfo[12],65},{unitInfo[13],75},
		{unitInfo[14],85},{unitInfo[17],95},{unitInfo[15],105},{unitInfo[16],115}
	}) do
		local stat_val = data[1]
		local y_pos = data[2]
		drawGD(x0+width_unit-28, y_pos, "images/ref_img.gd", 13, 0 + stat_val*6, 9, 6, opacity)
	end
	for _, data in ipairs({
		{unitInfo[26],55},{unitInfo[27],65},{unitInfo[28],75},
		{unitInfo[29],85},{unitInfo[30],95},{unitInfo[31],105},{unitInfo[32],115}
	}) do
		local stat_val = data[1]
		local y_pos = data[2]
		drawGD(x0+width_unit-28+10, y_pos-1, "images/ref_img.gd", 22, 125 + stat_val*6, 15, 7, opacity)
	end
end

function draw()	
	-- Check if display window is still active
	if isDisplayActive() then
		if (CurrentUnits[displayed_unit_index+1] ~= nil) then
			drawUnit(displayed_unit_index)
		end
	end
end


while true do
	-- I want to do all 4 stages of updating the LUT for each character
	--      0 0 0 0 0 0             0 0
	-- 6 bits for characters  2 bits for stages
	-- 6 bits lets us do 64 characters (just barely enough for FE6)
	-- emu.framecount < 2^8 (256)
	-- max_char = 1111 11 00 = 0xFC
	-- 			  1111 11 00 = 0xFC (mask for character number)
	-- lower bits are what state of calculations we're on
	local stage = (bit.band(emu.framecount(), 0x3)) + 1
	-- char number effects the offset in memory we want to read for the character
	local char_number = bit.rshift(bit.band(emu.framecount(), 0xFC), 2)
	if (stage == 1) then
		-- this will populate Cdata['lookupKey']
		updateLUT_stage1(char_number)
	end
	if UnitsLut[Cdata['lookupKey']] ~= nil then
		--stage 2 is the longest stage but still takes less than ~15us which is very quick
		if (stage == 2) then
			updateLUT_stage2(char_number)
		end
		if (stage == 3) then
			updateLUT_stage3()
		end
		if (stage == 4) then
			updateLUT_stage4()
		end
	end

	if (re_draw == 1) then
		display_frame_start = emu.framecount()
		draw()
		last_num_displayed = num_displayed_units
		re_draw = 0
	end
	
	-- Always draw if display window is active
	if isDisplayActive() then
		draw()
	end
	
	userInput = input.get()
	checkForUserInput()
	if memory.readbyte(phaseMap[currentGame]) == 0 then
		advanceRNG()
		gui.text(0, 0, "ACTIVE", 0x00FF00FF)
		if displayRNG then
			printRNG(numDisplayedRNs)
		end
	else
		gui.text(2, 2, "PAUSED", "red")
	end
	if displayRNG then
		printRNG(numDisplayedRNs)
	end
	emu.frameadvance()
end
