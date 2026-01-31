math.randomseed(os.time())
RNGBase = 0x03000000
lastSeenRNG = {memory.read_u16_le(RNGBase+4), memory.read_u16_le(RNGBase+2), memory.read_u16_le(RNGBase)}
numDisplayedRNs = 20
superRNToRNConversionDivisor = 655.36
gameID = ""
gui.use_surface("emucore")
-- local myCanvas = gui.createcanvas(200, 200)
--     client.SetGameExtraPadding(int left, int top, int right, int bottom) 

local bufferwidth = client.bufferwidth()
local bufferheight = client.bufferheight()
RNGPosition = 0
lastRNGPosition = 0
userInput = input.get()
displayRNG = false

-- Read consecutive values from the ROM to find a special string (ex/ FIREEMBLEM6.AFEJ01) used to distinguish between games
for i = 0, 18, 1 do
	gameID = gameID..memory.readbyte(0x080000A0 + i)
end

gameIDMap = {
	['70738269697766766977540657069744849150'] = "Sealed Sword J",
	['70738269697766766977690656955694849150'] = "Blazing Sword U",
	['70738269697766766977550656955744849150'] = "Blazing Sword J",
	['707382696977667669775069666956694849150'] = "Sacred Stones U",
	['70738269697766766977560666956744849150'] = "Sacred Stones J"
}

phaseMap = {
	['Sealed Sword J'] = 0x0202AA57,
	['Blazing Sword U'] = 0x0202BC07,
	['Blazing Sword J'] = 0x0202BC03,
	['Sacred Stones U'] = 0x0202BCFF,
	['Sacred Stones J'] = 0x0202BCFB
}
-- Unit info is displayed as [ID] = {name, b_lvl, b_hp, b_str, b_skl, b_spd, b_def, b_res, b_lck, c_lvl, c_hp, c_str, c_skl, c_spd, c_def, c_res, c_lck, hp_g, str_g, skl_g, spd_g, def_g,  res_g, lck_g, pp_lvl, avg_hp, avg_str, avg_skl, avg_spd, avg_def, avg_res, avg_lck, total_lvls, promoted, ppp_lvl}
--									[01,    02,    03,    04,    05,    06,    07,    08,    09,   10,    11,    12,    13,    14,    15,    16,    17,   18,    19,    20,   21,     22,    23,    24,    25,     26,      27,      28,      29,      30,       31,      32       33,         34,       35]
-- b_* = base stat. c_* = current stat. *_g = growth. avg_* = amount +- avg
UnitsLut = {
	['8803D64'] = {"Eirika",	01,	16,	04,	08,	09,	03,	01,	05, 0, 0, 0, 0, 0, 0, 0, 0, 0.70, 0.40, 0.60, 0.60,0.30, 0.30, 0.60, 01, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 0},
	['8803D98'] = {"Seth",		01,	30,	14,	13,	12,	11,	08,	13, 0, 0, 0, 0, 0, 0, 0, 0, 0.90, 0.50, 0.45, 0.45,0.40, 0.30, 0.25, 00, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 0},
	['8803E00'] = {"Franz",		01,	20,	07,	05,	07,	06,	01,	02, 0, 0, 0, 0, 0, 0, 0, 0, 0.80, 0.40, 0.40, 0.50,0.25, 0.20, 0.40, 01, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 0},
	['8803DCC'] = {"Gilliam",	04,	25,	09,	06,	03,	09,	03,	03, 0, 0, 0, 0, 0, 0, 0, 0, 0.90, 0.45, 0.35, 0.30,0.55, 0.20, 0.30, 04, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 0},
	['8803E68'] = {"Vanessa",	01,	17,	05,	07,	11,	06,	05,	04, 0, 0, 0, 0, 0, 0, 0, 0, 0.70, 0.40, 0.50, 0.40,0.25, 0.25, 0.20, 01, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 0},
	['8803E34'] = {"Moulder",	03,	20,	04,	06,	09,	02,	05,	01, 0, 0, 0, 0, 0, 0, 0, 0, 0.50, 0.35, 0.55, 0.60,0.20, 0.30, 0.50, 03, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 0},
	['8803E9C'] = {"Ross",		01,	15,	05,	02,	03,	03,	00,	08, 0, 0, 0, 0, 0, 0, 0, 0, 0.70, 0.50, 0.35, 0.30,0.25, 0.20, 0.40, 00, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 1},
	['8803F38'] = {"Garcia",	04,	28,	08,	07,	07,	05,	01,	03, 0, 0, 0, 0, 0, 0, 0, 0, 0.80, 0.65, 0.40, 0.20,0.25, 0.15, 0.40, 04, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 0},
	['8803ED0'] = {"Neimi",		01,	17,	04,	05,	06,	03,	02,	04, 0, 0, 0, 0, 0, 0, 0, 0, 0.55, 0.45, 0.50, 0.60,0.15, 0.35, 0.50, 01, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 0},
	['8803F04'] = {"Colm",		02,	18,	04,	04,	10,	03,	01,	08, 0, 0, 0, 0, 0, 0, 0, 0, 0.75, 0.40, 0.40, 0.65,0.25, 0.20, 0.45, 02, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 0},
	['880410C'] = {"Artur",		02,	19,	06,	06,	08,	02,	06,	02, 0, 0, 0, 0, 0, 0, 0, 0, 0.55, 0.50, 0.50, 0.40,0.15, 0.55, 0.25, 02, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 0},
	['8803FA0'] = {"Lute",		01,	17,	06,	06,	07,	03,	05,	08, 0, 0, 0, 0, 0, 0, 0, 0, 0.45, 0.65, 0.30, 0.45,0.15, 0.40, 0.45, 01, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 0},
	['8803FD4'] = {"Natasha",	01,	18,	02,	04,	08,	02,	06,	06, 0, 0, 0, 0, 0, 0, 0, 0, 0.50, 0.60, 0.25, 0.40,0.15, 0.55, 0.60, 01, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 0},
	['88043B0'] = {"Joshua",	05,	24,	08,	13,	14,	05,	02,	07, 0, 0, 0, 0, 0, 0, 0, 0, 0.80, 0.35, 0.55, 0.55,0.20, 0.20, 0.30, 05, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 0},
	['880403C'] = {"Ephraim",	04,	23,	08,	09,	11,	07,	02,	08, 0, 0, 0, 0, 0, 0, 0, 0, 0.80, 0.55, 0.55, 0.45,0.35, 0.25, 0.50, 04, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 0},
	['8804070'] = {"Forde",		06,	24,	07,	08,	08,	08,	02,	07, 0, 0, 0, 0, 0, 0, 0, 0, 0.85, 0.40, 0.50, 0.45,0.20, 0.25, 0.35, 06, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 0},
	['88040A4'] = {"Kyle",		05,	25,	09,	06,	07,	09,	01,	06, 0, 0, 0, 0, 0, 0, 0, 0, 0.90, 0.50, 0.40, 0.40,0.25, 0.20, 0.20, 05, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 0},
	['8804480'] = {"Orson",		03,	34,	15,	13,	11,	13,	07,	04, 0, 0, 0, 0, 0, 0, 0, 0, 0.80, 0.55, 0.45, 0.40,0.45, 0.30, 0.25, 00, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 0},
	['8804418'] = {"Tana",		04,	20,	07,	09,	13,	06,	07,	08, 0, 0, 0, 0, 0, 0, 0, 0, 0.65, 0.45, 0.40, 0.65,0.20, 0.25, 0.60, 04, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 0},
	['88040D8'] = {"Amelia",	01,	16,	04,	03,	04,	02,	03,	06, 0, 0, 0, 0, 0, 0, 0, 0, 0.60, 0.35, 0.40, 0.40,0.30, 0.15, 0.50, 00, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 1},
	['8803F6C'] = {"Innes",		01,	31,	14,	13,	15,	10,	09,	14, 0, 0, 0, 0, 0, 0, 0, 0, 0.75, 0.40, 0.40, 0.45,0.20, 0.25, 0.45, 00, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 0},
	['8804140'] = {"Gerik",		10,	32,	14,	13,	13,	10,	04,	08, 0, 0, 0, 0, 0, 0, 0, 0, 0.90, 0.45, 0.40, 0.30,0.35, 0.25, 0.30, 10, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 0},
	['8804174'] = {"Tethys",	01,	18,	01,	02,	12,	05,	04,	10, 0, 0, 0, 0, 0, 0, 0, 0, 0.85, 0.05, 0.10, 0.70,0.30, 0.75, 0.80, 01, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 0},
	['88041A8'] = {"Marisa",	05,	23,	07,	12,	13,	04,	03,	09, 0, 0, 0, 0, 0, 0, 0, 0, 0.75, 0.30, 0.55, 0.60,0.15, 0.25, 0.50, 05, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 0},
	['8804244'] = {"L\'Arachel",03,	18,	06,	06,	10,	05,	08,	12, 0, 0, 0, 0, 0, 0, 0, 0, 0.45, 0.50, 0.45, 0.45,0.15, 0.50, 0.65, 03, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 0},
	['8804278'] = {"Dozla",		01,	43,	16,	11,	09,	11,	06,	04, 0, 0, 0, 0, 0, 0, 0, 0, 0.85, 0.50, 0.35, 0.40,0.30, 0.25, 0.30, 00, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 0},
	['88041DC'] = {"Saleh",		01,	30,	16,	18,	14,	08,	13,	11, 0, 0, 0, 0, 0, 0, 0, 0, 0.50, 0.30, 0.25, 0.40,0.30, 0.35, 0.40, 00, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 0},
	['8804210'] = {"Ewan",		01,	15,	03,	02,	05,	00,	03,	05, 0, 0, 0, 0, 0, 0, 0, 0, 0.50, 0.45, 0.40, 0.35,0.15, 0.40, 0.50, 00, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 1},
	['8804008'] = {"Cormag",	09,	30,	14,	09,	10,	12,	02,	04, 0, 0, 0, 0, 0, 0, 0, 0, 0.85, 0.55, 0.40, 0.45,0.25, 0.15, 0.35, 09, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 0},
	['88042E0'] = {"Rennac",	01,	28,	10,	16,	17,	09,	11,	05, 0, 0, 0, 0, 0, 0, 0, 0, 0.65, 0.25, 0.45, 0.60,0.25, 0.30, 0.25, 00, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 0},
	['8804314'] = {"Duessel",	08,	41,	17,	12,	12,	17,	09,	08, 0, 0, 0, 0, 0, 0, 0, 0, 0.85, 0.55, 0.40, 0.30,0.45, 0.30, 0.20, 00, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 0},
	['880437C'] = {"Knoll",		10,	22,	13,	09,	08,	02,	10,	00, 0, 0, 0, 0, 0, 0, 0, 0, 0.70, 0.50, 0.40, 0.35,0.10, 0.45, 0.20, 10, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 0},
	['8804348'] = {"Myrrh",		01,	15,	03,	01,	05,	02,	07,	03, 0, 0, 0, 0, 0, 0, 0, 0, 1.30, 0.90, 0.85, 0.65,1.50, 0.30, 0.30, 01, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 0},
	['88043E4'] = {"Syrene",	01,	27,	12,	13,	15,	10,	12,	12, 0, 0, 0, 0, 0, 0, 0, 0, 0.70, 0.40, 0.50, 0.60,0.20, 0.50, 0.30, 00, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 0},
	['testtest'] = {"",			00,	00,	00,	00,	00,	00,	00,	00, 0, 0, 0, 0, 0, 0, 0, 0, 0.00, 0.00, 0.00, 0.00,0.00, 0.00, 0.00, 00, "+0", "+0", "+0", "+0", "+0", "+0", "+0", 0, 0, 0}
}

-- print(UnitsLut['8803D64'])
-- current units
CurrentUnits = {'testtest', 'testtest', 'testtest'}

heldDown = {
	['R'] = false, 
	['Right'] = false,
	['Left'] = false
}

currentGame = gameIDMap[gameID]
print("Current game: "..currentGame)

function superRNToRN(srn)
	return math.floor(srn/superRNToRNConversionDivisor)
end

function nextSuperRN(r1, r2, r3)
	-- Given three sequential RNG values, generate a fourth
	return (((((r3 >> 5) ~ (r2 << 11)) ~ (r1 << 1)) ~ (r2 >> 15)) & 0xFFFF)
end

function printRNG(n)
	-- Print n entries of the RNG table
	RNGTable = RNGSimulate(n)
	-- Print each RNG value
	for i=1,n do
		gui.text(client.screenwidth() - 21, 16*(i-1), superRNToRN(RNGTable[i]), "white")
	end
end

function RNGSimulate(n)
	-- Generate n entries of the RNG table (including the 3 RNs used for the RNG seed)
	local result = { memory.read_u16_le(RNGBase+4), memory.read_u16_le(RNGBase+2), memory.read_u16_le(RNGBase) }
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
	local RNG1 =  memory.read_u16_le(RNGBase+4)
	local RNG2 =  memory.read_u16_le(RNGBase+2)
	local RNG3 = memory.read_u16_le(RNGBase)
	local RNG4 = nextSuperRN(RNG1, RNG2, RNG3)
	-- Swap the values in RNG Seed 1,2,3 by the RNG values 2,3,4
	memory.write_u16_le(RNGBase + 4, RNG2)
	memory.write_u16_le(RNGBase + 2, RNG3)
	memory.write_u16_le(RNGBase + 0, RNG4)
end

function checkForUserInput()
	if userInput.R and heldDown['R'] == false then
		-- help display on/off
		displayRNG = not displayRNG
	end
	if userInput.Right and heldDown['Right'] == false then
		-- help display on/off
		num_displayed_units = math.min(num_displayed_units + 1, 3)
	end
	if userInput.Left and heldDown['Left'] == false then
		-- help display on/off
		num_displayed_units = math.max(num_displayed_units - 1, 1)
	end
	for key, value in pairs(heldDown) do
		heldDown[key] = true
		if userInput[key] == nil then
			heldDown[key] = false
		end
	end
end

ross_promo_added = 0
amelia_promo_added = 0
ewan_promo_added = 0

local baseAddress = 0x0202BE4C
function updateLUT(i)
	-- for i = 0,33,1 do
		addr = baseAddress + (i*0x48)
		Rom_unit = memory.read_u32_le(addr, "System Bus")
		-- print(string.format("%x", Rom_unit))
		lookupKey = string.format("%07X", Rom_unit)
		if UnitsLut[lookupKey] == nil then
			-- print("returning")
			return
		end
		lvl    = memory.readbyte(addr + 0x8, "System Bus")
		-- print(lvl)
		-- If we're not promoted and have gained a level, add it to pp_lvl
		if UnitsLut[lookupKey][34] == 0 and UnitsLut[lookupKey][25] ~= 0 then
			UnitsLut[lookupKey][25] = lvl
		end
		if UnitsLut[lookupKey][35] ~= 10 and UnitsLut[lookupKey][35] ~= 0 then
			UnitsLut[lookupKey][35] = lvl
		end
		UnitsLut[lookupKey][10] = lvl
		maxHP  = memory.readbyte(addr + 0x12, "System Bus")
		-- print(maxHP)
		UnitsLut[lookupKey][11] = maxHP
		str    = memory.readbyte(addr + 0x14, "System Bus")
		UnitsLut[lookupKey][12] = str
		-- print(str)
		skl    = memory.readbyte(addr + 0x15, "System Bus")
		UnitsLut[lookupKey][13] = skl
		-- print(skl)
		spd    = memory.readbyte(addr + 0x16, "System Bus")
		UnitsLut[lookupKey][14] = spd
		-- print(spd)
		def    = memory.readbyte(addr + 0x17, "System Bus")
		UnitsLut[lookupKey][15] = def
		-- print(def)
		res    = memory.readbyte(addr + 0x18, "System Bus")
		UnitsLut[lookupKey][16] = res
		-- print(res)
		lck    = memory.readbyte(addr + 0x19, "System Bus")
		UnitsLut[lookupKey][17] = lck
		-- print(lck)
		
		promo_hp_gain = 0
		promo_str_gain = 0
		promo_skl_gain = 0
		promo_spd_gain = 0
		promo_def_gain = 0
		promo_res_gain = 0
		-- if level < pp_lvl, then we're a (somewhat) freshly promoted unit
		if (UnitsLut[lookupKey][10] < UnitsLut[lookupKey][25]) then
			UnitsLut[lookupKey][34] = 1
		end

		
		-- print(rom_class)

		if (UnitsLut[lookupKey][35] ~= 0) then -- we're a trainee
			if (lookupKey == '8803E9C') then -- ross
				if (ross_promo_added == 0 and lvl == 1 and UnitsLut[lookupKey][35] == 10) then -- Ross just promoted, add growth to bases
					rom_class = memory.read_u32_le(addr+0x4, "System Bus")
					promo_hp_gain = memory.readbyte(rom_class + 0x22, "System Bus")
					promo_str_gain = memory.readbyte(rom_class + 0x23, "System Bus")
					promo_skl_gain = memory.readbyte(rom_class + 0x24, "System Bus")
					promo_spd_gain = memory.readbyte(rom_class + 0x25, "System Bus")
					promo_def_gain = memory.readbyte(rom_class + 0x26, "System Bus")
					promo_res_gain = memory.readbyte(rom_class + 0x27, "System Bus")
					UnitsLut[lookupKey][3] = UnitsLut[lookupKey][3] + promo_hp_gain
					UnitsLut[lookupKey][4] = UnitsLut[lookupKey][4] + promo_str_gain
					UnitsLut[lookupKey][5] = UnitsLut[lookupKey][5] + promo_skl_gain
					UnitsLut[lookupKey][6] = UnitsLut[lookupKey][6] + promo_spd_gain
					UnitsLut[lookupKey][7] = UnitsLut[lookupKey][7] + promo_def_gain
					UnitsLut[lookupKey][8] = UnitsLut[lookupKey][8] + promo_res_gain
					ross_promo_added = 1
					UnitsLut[lookupKey][25] = 1
				end
				if UnitsLut[lookupKey][34] == 1 then -- we were promoted, so do lvl - 1 + pp_lvl - b_lvl + ppp_lvl - 1
					lvls_gained = UnitsLut[lookupKey][10] - 1 + UnitsLut[lookupKey][25] - UnitsLut[lookupKey][2] + UnitsLut[lookupKey][35] - 1
				elseif (UnitsLut[lookupKey][25] > 0) then --we're not promoted yet (still trainee class), so do lvl - b_lvl + ppp_lvl - 1
					lvls_gained = UnitsLut[lookupKey][25] - UnitsLut[lookupKey][2] + UnitsLut[lookupKey][35] - 1
				else
					 lvls_gained = UnitsLut[lookupKey][35] - UnitsLut[lookupKey][2]
				end
			elseif (lookupKey == '88040D8') then -- amelia
				if (amelia_promo_added == 0 and lvl == 1 and UnitsLut[lookupKey][35] == 10) then -- Amelia just promoted, add growth to bases
					rom_class = memory.read_u32_le(addr+0x4, "System Bus")
					promo_hp_gain = memory.readbyte(rom_class + 0x22, "System Bus")
					promo_str_gain = memory.readbyte(rom_class + 0x23, "System Bus")
					promo_skl_gain = memory.readbyte(rom_class + 0x24, "System Bus")
					promo_spd_gain = memory.readbyte(rom_class + 0x25, "System Bus")
					promo_def_gain = memory.readbyte(rom_class + 0x26, "System Bus")
					promo_res_gain = memory.readbyte(rom_class + 0x27, "System Bus")
					UnitsLut[lookupKey][3] = UnitsLut[lookupKey][3] + promo_hp_gain
					UnitsLut[lookupKey][4] = UnitsLut[lookupKey][4] + promo_str_gain
					UnitsLut[lookupKey][5] = UnitsLut[lookupKey][5] + promo_skl_gain
					UnitsLut[lookupKey][6] = UnitsLut[lookupKey][6] + promo_spd_gain
					UnitsLut[lookupKey][7] = UnitsLut[lookupKey][7] + promo_def_gain
					UnitsLut[lookupKey][8] = UnitsLut[lookupKey][8] + promo_res_gain
					amelia_promo_added = 1
					UnitsLut[lookupKey][25] = 1
				end
				if UnitsLut[lookupKey][34] == 1 then -- we were promoted, so do lvl - 1 + pp_lvl - b_lvl + ppp_lvl - 1
					lvls_gained = UnitsLut[lookupKey][10] - 1 + UnitsLut[lookupKey][25] - UnitsLut[lookupKey][2] + UnitsLut[lookupKey][35] - 1
				elseif (UnitsLut[lookupKey][25] > 0) then --we're not promoted yet (still trainee class), so do lvl - b_lvl + ppp_lvl - 1
					lvls_gained = UnitsLut[lookupKey][25] - UnitsLut[lookupKey][2] + UnitsLut[lookupKey][35] - 1
				else
					 lvls_gained = UnitsLut[lookupKey][35] - UnitsLut[lookupKey][2]
				end
			else -- Ewan
				if (ewan_promo_added == 0 and lvl == 1 and UnitsLut[lookupKey][35] == 10) then -- Ewan just promoted, add growth to bases
					rom_class = memory.read_u32_le(addr+0x4, "System Bus")
					promo_hp_gain = memory.readbyte(rom_class + 0x22, "System Bus")
					promo_str_gain = memory.readbyte(rom_class + 0x23, "System Bus")
					promo_skl_gain = memory.readbyte(rom_class + 0x24, "System Bus")
					promo_spd_gain = memory.readbyte(rom_class + 0x25, "System Bus")
					promo_def_gain = memory.readbyte(rom_class + 0x26, "System Bus")
					promo_res_gain = memory.readbyte(rom_class + 0x27, "System Bus")
					UnitsLut[lookupKey][3] = UnitsLut[lookupKey][3] + promo_hp_gain
					UnitsLut[lookupKey][4] = UnitsLut[lookupKey][4] + promo_str_gain
					UnitsLut[lookupKey][5] = UnitsLut[lookupKey][5] + promo_skl_gain
					UnitsLut[lookupKey][6] = UnitsLut[lookupKey][6] + promo_spd_gain
					UnitsLut[lookupKey][7] = UnitsLut[lookupKey][7] + promo_def_gain
					UnitsLut[lookupKey][8] = UnitsLut[lookupKey][8] + promo_res_gain
					ewan_promo_added = 1
					UnitsLut[lookupKey][25] = 1
				end
				if UnitsLut[lookupKey][34] == 1 then -- we were promoted, so do lvl - 1 + pp_lvl - b_lvl + ppp_lvl - 1
					lvls_gained = UnitsLut[lookupKey][10] - 1 + UnitsLut[lookupKey][25] - UnitsLut[lookupKey][2] + UnitsLut[lookupKey][35] - 1
				elseif (UnitsLut[lookupKey][25] > 0) then --we're not promoted yet (still trainee class), so do lvl - b_lvl + ppp_lvl - 1
					lvls_gained = UnitsLut[lookupKey][25] - UnitsLut[lookupKey][2] + UnitsLut[lookupKey][35] - 1
				else
					 lvls_gained = UnitsLut[lookupKey][35] - UnitsLut[lookupKey][2]
				end
			end
		elseif (UnitsLut[lookupKey][25] == 0) then -- if pp_lvl == 0 then we're a pre-premote. do lvl - base + trainee levels
			lvls_gained = UnitsLut[lookupKey][10] - UnitsLut[lookupKey][2]
		elseif UnitsLut[lookupKey][34] == 1 then -- we were promoted, so do lvl - 1 + pp_lvl - b_lvl
			lvls_gained = UnitsLut[lookupKey][10] - 1 + UnitsLut[lookupKey][25] - UnitsLut[lookupKey][2]
			rom_class = memory.read_u32_le(addr + 0x4, "System Bus")
			promo_hp_gain = memory.readbyte(rom_class + 0x22, "System Bus")
			promo_str_gain = memory.readbyte(rom_class + 0x23, "System Bus")
			promo_skl_gain = memory.readbyte(rom_class + 0x24, "System Bus")
			promo_spd_gain = memory.readbyte(rom_class + 0x25, "System Bus")
			promo_def_gain = memory.readbyte(rom_class + 0x26, "System Bus")
			promo_res_gain = memory.readbyte(rom_class + 0x27, "System Bus")
		else -- we're unpromoted
			lvls_gained = UnitsLut[lookupKey][25] - UnitsLut[lookupKey][2]
		end
		UnitsLut[lookupKey][33] = lvls_gained

		avg_hp =  UnitsLut[lookupKey][03] + math.floor(lvls_gained * UnitsLut[lookupKey][18] + 0.5) + promo_hp_gain
		avg_str = UnitsLut[lookupKey][04] + math.floor(lvls_gained * UnitsLut[lookupKey][19] + 0.5) + promo_str_gain
		avg_skl = UnitsLut[lookupKey][05] + math.floor(lvls_gained * UnitsLut[lookupKey][20] + 0.5) + promo_skl_gain
		avg_spd = UnitsLut[lookupKey][06] + math.floor(lvls_gained * UnitsLut[lookupKey][21] + 0.5) + promo_spd_gain
		avg_def = UnitsLut[lookupKey][07] + math.floor(lvls_gained * UnitsLut[lookupKey][22] + 0.5) + promo_def_gain
		avg_res = UnitsLut[lookupKey][08] + math.floor(lvls_gained * UnitsLut[lookupKey][23] + 0.5) + promo_res_gain
		avg_lck = UnitsLut[lookupKey][09] + math.floor(lvls_gained * UnitsLut[lookupKey][24] + 0.5)
		if (maxHP - avg_hp < 0) then
			UnitsLut[lookupKey][26] = ""..maxHP-avg_hp
		else
			UnitsLut[lookupKey][26] = "+"..maxHP-avg_hp
		end
		if (str - avg_str < 0) then
			UnitsLut[lookupKey][27] = ""..str-avg_str
		else
			UnitsLut[lookupKey][27] = "+"..str-avg_str
		end
		if (skl - avg_skl < 0) then
			UnitsLut[lookupKey][28] = ""..skl-avg_skl
		else
			UnitsLut[lookupKey][28] = "+"..skl-avg_skl
		end
		if (spd - avg_spd < 0) then
			UnitsLut[lookupKey][29] = ""..spd-avg_spd
		else
			UnitsLut[lookupKey][29] = "+"..spd-avg_spd
		end
		if (def - avg_def < 0) then
			UnitsLut[lookupKey][30] = ""..def-avg_def
		else
			UnitsLut[lookupKey][30] = "+"..def-avg_def
		end
		if (res - avg_res < 0) then
			UnitsLut[lookupKey][31] = ""..res-avg_res
		else
			UnitsLut[lookupKey][31] = "+"..res-avg_res
		end
		if (lck - avg_lck < 0) then
			UnitsLut[lookupKey][32] = ""..lck-avg_lck
		else
			UnitsLut[lookupKey][32] = "+"..lck-avg_lck
		end
		--if unit is not in CurrentUnits then add them
		if lvls_gained > UnitsLut[CurrentUnits[3]][33] then
			if CurrentUnits[3] ~= lookupKey then
				CurrentUnits[1] = CurrentUnits[2]
				CurrentUnits[2] = CurrentUnits[3]
				CurrentUnits[3] = lookupKey
			end
		elseif lvls_gained > UnitsLut[CurrentUnits[2]][33] then
			if CurrentUnits[2] ~= lookupKey and CurrentUnits[3] ~= lookupKey then
				CurrentUnits[1] = CurrentUnits[2]
				CurrentUnits[2] = lookupKey
			end
		elseif lvls_gained > UnitsLut[CurrentUnits[1]][33] and CurrentUnits[1] ~= lookupKey and CurrentUnits[2] ~= lookupKey and CurrentUnits[3] ~= lookupKey then
			CurrentUnits[1] = lookupKey
		end
	-- end
end

-- gui.drawBox(int x, int y, int x2, int y2, [luacolor line = nil], [luacolor background = nil], [string surfacename = nil]) 
-- gui.drawBox(0, 0, 110, bufferheight-1, "#A97060", "#532e21", "emucore")


num_displayed_units = 3
last_num_displayed = 1
local baseFontSize = 3
width = 110

local drawString = gui.drawString
local drawLine = gui.drawLine
local drawBox = gui.drawBox
local transformPoint = client.transformPoint

while true do
	userInput = input.get()
	local scale = client.screenwidth() / client.bufferwidth()
    local currentFontSize = math.floor(baseFontSize * scale)
	-- updateLUT()
	
	if (num_displayed_units == 3) then
		width = 110
	elseif num_displayed_units == 2 then
		width = 78
	else
		width = 46
	end
	drawBox(0, 0, width, bufferheight-1, "#A97060", "#532e21", "emucore")
	drawLine(12, 0, 12, bufferheight, "#A97060", "emucore") -- vertical line at -98
	drawLine(44, 0, 44, bufferheight, "#A97060", "emucore") -- vertical line at -66
	drawLine(76, 0, 76, bufferheight, "#A97060", "emucore") -- vertical line at -34
	drawLine(0, 42, width, 42, "#A97060", "emucore") -- horizontal line at 42
	drawLine(0, 52, width, 52, "#A97060", "emucore") -- horizontal line at 52
	drawLine(0, 62, width, 62, "#A97060", "emucore") -- horizontal line at 62
	drawLine(0, 72, width, 72, "#A97060", "emucore") -- horizontal line at 72
	drawLine(0, 82, width, 82, "#A97060", "emucore") -- horizontal line at 82
	drawLine(0, 92, width, 92, "#A97060", "emucore") -- horizontal line at 92
	drawLine(0, 102, width, 102, "#A97060", "emucore") -- horizontal line at 102
	

	if (last_num_displayed ~= num_displayed_units) then
		client.SetGameExtraPadding(width, 0, 0, 0)
	end
	last_num_displayed = num_displayed_units

	if (emu.framecount() & 0x7f) < 0x21 then -- the value is less than 33 (I.E. the max number of characters)
		-- updateLUT(emu.framecount() & 0x2f)
    end
	-- test     = memory.read_u32_le(0x0203A4E9, "System Bus")
	-- print(test)
	
	pos = transformPoint(1-width, 40)
	drawString(pos.x, pos.y,  "LVL: ", "White", "Black", currentFontSize, "Consolas", "bold", "left", "bottom", "client")
	pos = transformPoint(1-width, 50)
	drawString(pos.x, pos.y,  "HP: ", "White", "Black", currentFontSize, "Consolas", "bold", "left", "bottom", "client")
	pos = transformPoint(1-width, 60)
	drawString(pos.x, pos.y,  "STR:", "White", "Black", currentFontSize, "Consolas", "bold", "left", "bottom", "client")
	pos = transformPoint(1-width, 70)
	drawString(pos.x, pos.y,  "SKL:", "White", "Black", currentFontSize, "Consolas", "bold", "left", "bottom", "client")
	pos = transformPoint(1-width, 80)
	drawString(pos.x, pos.y,  "SPD:", "White", "Black", currentFontSize, "Consolas", "bold", "left", "bottom", "client")
	pos = transformPoint(1-width, 90)
	drawString(pos.x, pos.y,  "LCK:", "White", "Black", currentFontSize, "Consolas", "bold", "left", "bottom", "client")
	pos = transformPoint(1-width, 100)
	drawString(pos.x, pos.y, "DEF:", "White", "Black", currentFontSize, "Consolas", "bold", "left", "bottom", "client")
	pos = transformPoint(1-width, 110)
	drawString(pos.x, pos.y, "RES:", "White", "Black", currentFontSize, "Consolas", "bold", "left", "bottom", "client")
	unitInfo = UnitsLut[CurrentUnits[3]]
	if (unitInfo[1] ~= '') then
		pos = transformPoint(28-width + 32*(num_displayed_units-1), 30)
		drawString(pos.x, pos.y,  unitInfo[1], "White", "Black", currentFontSize, "Consolas", "bold", "center", "bottom", "client")
		pos = transformPoint(28-width + 32*(num_displayed_units-1), 40)
		drawString(pos.x, pos.y,  string.format("%2d",unitInfo[10]), "White", "Black", currentFontSize, "Consolas", "bold", "center", "bottom", "client")
		pos = transformPoint(28-width + 32*(num_displayed_units-1), 50)
		drawString(pos.x, pos.y,  string.format("%2d | %s",unitInfo[11],unitInfo[26]), "White", "Black", currentFontSize, "Consolas", "bold", "center", "bottom", "client")
		pos = transformPoint(28-width + 32*(num_displayed_units-1), 60)
		drawString(pos.x, pos.y,  string.format("%2d | %s",unitInfo[12],unitInfo[27]), "White", "Black", currentFontSize, "Consolas", "bold", "center", "bottom", "client")
		pos = transformPoint(28-width + 32*(num_displayed_units-1), 70)
		drawString(pos.x, pos.y,  string.format("%2d | %s",unitInfo[13],unitInfo[28]), "White", "Black", currentFontSize, "Consolas", "bold", "center", "bottom", "client")
		pos = transformPoint(28-width + 32*(num_displayed_units-1), 80)
		drawString(pos.x, pos.y,  string.format("%2d | %s",unitInfo[14],unitInfo[29]), "White", "Black", currentFontSize, "Consolas", "bold", "center", "bottom", "client")
		pos = transformPoint(28-width + 32*(num_displayed_units-1), 90)
		drawString(pos.x, pos.y,  string.format("%2d | %s",unitInfo[17],unitInfo[32]), "White", "Black", currentFontSize, "Consolas", "bold", "center", "bottom", "client")
		pos = transformPoint(28-width + 32*(num_displayed_units-1), 100)
		drawString(pos.x, pos.y, string.format("%2d | %s",unitInfo[15],unitInfo[30]), "White", "Black", currentFontSize, "Consolas", "bold", "center", "bottom", "client")
		pos = transformPoint(28-width + 32*(num_displayed_units-1), 110)
		drawString(pos.x, pos.y, string.format("%2d | %s",unitInfo[16],unitInfo[31]), "White", "Black", currentFontSize, "Consolas", "bold", "center", "bottom", "client")
	end
	if (num_displayed_units > 1) then
		unitInfo = UnitsLut[CurrentUnits[2]]
		if (unitInfo[1] ~= '') then
			pos = transformPoint(60-width - 32*(3-num_displayed_units), 30)
			drawString(pos.x, pos.y,  unitInfo[1], "White", "Black", currentFontSize, "Consolas", "bold", "center", "bottom", "client")
			pos = transformPoint(60-width - 32*(3-num_displayed_units), 40)
			drawString(pos.x, pos.y,  string.format("%2d",unitInfo[10]), "White", "Black", currentFontSize, "Consolas", "bold", "center", "bottom", "client")
			pos = transformPoint(60-width - 32*(3-num_displayed_units), 50)
			drawString(pos.x, pos.y,  string.format("%2d | %s",unitInfo[11],unitInfo[26]), "White", "Black", currentFontSize, "Consolas", "bold", "center", "bottom", "client")
			pos = transformPoint(60-width - 32*(3-num_displayed_units), 60)
			drawString(pos.x, pos.y,  string.format("%2d | %s",unitInfo[12],unitInfo[27]), "White", "Black", currentFontSize, "Consolas", "bold", "center", "bottom", "client")
			pos = transformPoint(60-width - 32*(3-num_displayed_units), 70)
			drawString(pos.x, pos.y,  string.format("%2d | %s",unitInfo[13],unitInfo[28]), "White", "Black", currentFontSize, "Consolas", "bold", "center", "bottom", "client")
			pos = transformPoint(60-width - 32*(3-num_displayed_units), 80)
			drawString(pos.x, pos.y,  string.format("%2d | %s",unitInfo[14],unitInfo[29]), "White", "Black", currentFontSize, "Consolas", "bold", "center", "bottom", "client")
			pos = transformPoint(60-width - 32*(3-num_displayed_units), 90)
			drawString(pos.x, pos.y,  string.format("%2d | %s",unitInfo[17],unitInfo[32]), "White", "Black", currentFontSize, "Consolas", "bold", "center", "bottom", "client")
			pos = transformPoint(60-width - 32*(3-num_displayed_units), 100)
			drawString(pos.x, pos.y, string.format("%2d | %s",unitInfo[15],unitInfo[30]), "White", "Black", currentFontSize, "Consolas", "bold", "center", "bottom", "client")
			pos = transformPoint(60-width - 32*(3-num_displayed_units), 110)
			drawString(pos.x, pos.y, string.format("%2d | %s",unitInfo[16],unitInfo[31]), "White", "Black", currentFontSize, "Consolas", "bold", "center", "bottom", "client")
		end
	end
	if (num_displayed_units > 2) then
		unitInfo = UnitsLut[CurrentUnits[1]]
		if (unitInfo[1] ~= '') then
			pos = transformPoint(28-width, 30)
			drawString(pos.x, pos.y,  unitInfo[1], "White", "Black", currentFontSize, "Consolas", "bold", "center", "bottom", "client")
			pos = transformPoint(28-width, 40)
			drawString(pos.x, pos.y,  string.format("%2d",unitInfo[10]), "White", "Black", currentFontSize, "Consolas", "bold", "center", "bottom", "client")
			pos = transformPoint(28-width, 50)
			drawString(pos.x, pos.y,  string.format("%2d | %s",unitInfo[11],unitInfo[26]), "White", "Black", currentFontSize, "Consolas", "bold", "center", "bottom", "client")
			pos = transformPoint(28-width, 60)
			drawString(pos.x, pos.y,  string.format("%2d | %s",unitInfo[12],unitInfo[27]), "White", "Black", currentFontSize, "Consolas", "bold", "center", "bottom", "client")
			pos = transformPoint(28-width, 70)
			drawString(pos.x, pos.y,  string.format("%2d | %s",unitInfo[13],unitInfo[28]), "White", "Black", currentFontSize, "Consolas", "bold", "center", "bottom", "client")
			pos = transformPoint(28-width, 80)
			drawString(pos.x, pos.y,  string.format("%2d | %s",unitInfo[14],unitInfo[29]), "White", "Black", currentFontSize, "Consolas", "bold", "center", "bottom", "client")
			pos = transformPoint(28-width, 90)
			drawString(pos.x, pos.y,  string.format("%2d | %s",unitInfo[17],unitInfo[32]), "White", "Black", currentFontSize, "Consolas", "bold", "center", "bottom", "client")
			pos = transformPoint(28-width, 100)
			drawString(pos.x, pos.y, string.format("%2d | %s",unitInfo[15],unitInfo[30]), "White", "Black", currentFontSize, "Consolas", "bold", "center", "bottom", "client")
			pos = transformPoint(28-width, 110)
			drawString(pos.x, pos.y, string.format("%2d | %s",unitInfo[16],unitInfo[31]), "White", "Black", currentFontSize, "Consolas", "bold", "center", "bottom", "client")
		end
	end
	
	
	checkForUserInput()
	if memory.readbyte(phaseMap[currentGame]) == 0 then
		advanceRNG()
		userInput = input.get()
		checkForUserInput()
		pos = transformPoint(-2, bufferheight-1)
		drawString(pos.x, pos.y, "ACTIVE", 0xFF00FF40, "Black", currentFontSize, "Consolas", "bold", "right", "bottom", "client")
		if displayRNG then
			printRNG(numDisplayedRNs)
		end
		-- emu.frameadvance()
	else
		pos = transformPoint(-2, bufferheight-1)
		drawString(pos.x, pos.y, "PAUSED", "Red", "Black", currentFontSize, "Consolas", "bold", "right", "bottom", "client")
	end
	if displayRNG then
		printRNG(numDisplayedRNs)
	end
	emu.frameadvance()
end
