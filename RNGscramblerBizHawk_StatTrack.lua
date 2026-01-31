math.randomseed(os.time())
local RNGBase = 0x03000000
local lastSeenRNG = {memory.read_u16_le(RNGBase+4), memory.read_u16_le(RNGBase+2), memory.read_u16_le(RNGBase)}
local numDisplayedRNs = 20
local superRNToRNConversionDivisor = 655.36
local gameID = ""
gui.use_surface("emucore")
-- local myCanvas = gui.createcanvas(200, 200)
--     client.SetGameExtraPadding(int left, int top, int right, int bottom) 

local bufferwidth = client.bufferwidth()
local bufferheight = client.bufferheight()
local num_displayed_units = 3
local last_num_displayed = 1
local baseFontSize = 3
local width = 110
local re_draw = 1
local leveled_up = 0

local drawString = gui.drawString
local drawLine = gui.drawLine
local drawBox = gui.drawBox
local transformPoint = client.transformPoint
local RNGPosition = 0
local lastRNGPosition = 0
local userInput = input.get()
local displayRNG = false

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
-- Unit info is displayed as [ID] = {name, b_lvl, b_hp, b_str, b_skl, b_spd, b_def, b_res, b_lck, c_lvl, c_hp, c_str, c_skl, c_spd, c_def, c_res, c_lck, hp_g, str_g, skl_g, spd_g, def_g,  res_g, lck_g, pp_lvl, avg_hp, avg_str, avg_skl, avg_spd, avg_def, avg_res, avg_lck, total_lvls, promoted, ppp_lvl}
--									[01,    02,    03,    04,    05,    06,    07,    08,    09,   10,    11,    12,    13,    14,    15,    16,    17,   18,    19,    20,   21,     22,    23,    24,    25,     26,      27,      28,      29,      30,       31,      32       33,         34,       35]
-- b_* = base stat. c_* = current stat. *_g = growth. avg_* = amount +- avg
local UnitsLut = {
	['8803D64'] = {"Eirika",	01,	16,	04,	08,	09,	03,	01,	05, 0, 0, 0, 0, 0, 0, 0, 0, 0.70, 0.40, 0.60, 0.60,0.30, 0.30, 0.60, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	['8803D98'] = {"Seth",		01,	30,	14,	13,	12,	11,	08,	13, 0, 0, 0, 0, 0, 0, 0, 0, 0.90, 0.50, 0.45, 0.45,0.40, 0.30, 0.25, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	['8803E00'] = {"Franz",		01,	20,	07,	05,	07,	06,	01,	02, 0, 0, 0, 0, 0, 0, 0, 0, 0.80, 0.40, 0.40, 0.50,0.25, 0.20, 0.40, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	['8803DCC'] = {"Gilliam",	04,	25,	09,	06,	03,	09,	03,	03, 0, 0, 0, 0, 0, 0, 0, 0, 0.90, 0.45, 0.35, 0.30,0.55, 0.20, 0.30, 04, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	['8803E68'] = {"Vanessa",	01,	17,	05,	07,	11,	06,	05,	04, 0, 0, 0, 0, 0, 0, 0, 0, 0.70, 0.40, 0.50, 0.40,0.25, 0.25, 0.20, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	['8803E34'] = {"Moulder",	03,	20,	04,	06,	09,	02,	05,	01, 0, 0, 0, 0, 0, 0, 0, 0, 0.50, 0.35, 0.55, 0.60,0.20, 0.30, 0.50, 03, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	['8803E9C'] = {"Ross",		01,	15,	05,	02,	03,	03,	00,	08, 0, 0, 0, 0, 0, 0, 0, 0, 0.70, 0.50, 0.35, 0.30,0.25, 0.20, 0.40, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
	['8803F38'] = {"Garcia",	04,	28,	08,	07,	07,	05,	01,	03, 0, 0, 0, 0, 0, 0, 0, 0, 0.80, 0.65, 0.40, 0.20,0.25, 0.15, 0.40, 04, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	['8803ED0'] = {"Neimi",		01,	17,	04,	05,	06,	03,	02,	04, 0, 0, 0, 0, 0, 0, 0, 0, 0.55, 0.45, 0.50, 0.60,0.15, 0.35, 0.50, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	['8803F04'] = {"Colm",		02,	18,	04,	04,	10,	03,	01,	08, 0, 0, 0, 0, 0, 0, 0, 0, 0.75, 0.40, 0.40, 0.65,0.25, 0.20, 0.45, 02, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	['880410C'] = {"Artur",		02,	19,	06,	06,	08,	02,	06,	02, 0, 0, 0, 0, 0, 0, 0, 0, 0.55, 0.50, 0.50, 0.40,0.15, 0.55, 0.25, 02, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	['8803FA0'] = {"Lute",		01,	17,	06,	06,	07,	03,	05,	08, 0, 0, 0, 0, 0, 0, 0, 0, 0.45, 0.65, 0.30, 0.45,0.15, 0.40, 0.45, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	['8803FD4'] = {"Natasha",	01,	18,	02,	04,	08,	02,	06,	06, 0, 0, 0, 0, 0, 0, 0, 0, 0.50, 0.60, 0.25, 0.40,0.15, 0.55, 0.60, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	['88043B0'] = {"Joshua",	05,	24,	08,	13,	14,	05,	02,	07, 0, 0, 0, 0, 0, 0, 0, 0, 0.80, 0.35, 0.55, 0.55,0.20, 0.20, 0.30, 05, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	['880403C'] = {"Ephraim",	04,	23,	08,	09,	11,	07,	02,	08, 0, 0, 0, 0, 0, 0, 0, 0, 0.80, 0.55, 0.55, 0.45,0.35, 0.25, 0.50, 04, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	['8804070'] = {"Forde",		06,	24,	07,	08,	08,	08,	02,	07, 0, 0, 0, 0, 0, 0, 0, 0, 0.85, 0.40, 0.50, 0.45,0.20, 0.25, 0.35, 06, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	['88040A4'] = {"Kyle",		05,	25,	09,	06,	07,	09,	01,	06, 0, 0, 0, 0, 0, 0, 0, 0, 0.90, 0.50, 0.40, 0.40,0.25, 0.20, 0.20, 05, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	['8804A98'] = {"Orson",		03,	34,	15,	13,	11,	13,	07,	04, 0, 0, 0, 0, 0, 0, 0, 0, 0.80, 0.55, 0.45, 0.40,0.45, 0.30, 0.25, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	['8804418'] = {"Tana",		04,	20,	07,	09,	13,	06,	07,	08, 0, 0, 0, 0, 0, 0, 0, 0, 0.65, 0.45, 0.40, 0.65,0.20, 0.25, 0.60, 04, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	['88040D8'] = {"Amelia",	01,	16,	04,	03,	04,	02,	03,	06, 0, 0, 0, 0, 0, 0, 0, 0, 0.60, 0.35, 0.40, 0.40,0.30, 0.15, 0.50, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
	['8803F6C'] = {"Innes",		01,	31,	14,	13,	15,	10,	09,	14, 0, 0, 0, 0, 0, 0, 0, 0, 0.75, 0.40, 0.40, 0.45,0.20, 0.25, 0.45, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	['8804140'] = {"Gerik",		10,	32,	14,	13,	13,	10,	04,	08, 0, 0, 0, 0, 0, 0, 0, 0, 0.90, 0.45, 0.40, 0.30,0.35, 0.25, 0.30, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	['8804174'] = {"Tethys",	01,	18,	01,	02,	12,	05,	04,	10, 0, 0, 0, 0, 0, 0, 0, 0, 0.85, 0.05, 0.10, 0.70,0.30, 0.75, 0.80, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	['88041A8'] = {"Marisa",	05,	23,	07,	12,	13,	04,	03,	09, 0, 0, 0, 0, 0, 0, 0, 0, 0.75, 0.30, 0.55, 0.60,0.15, 0.25, 0.50, 05, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	['8804244'] = {"L\'Arachel",03,	18,	06,	06,	10,	05,	08,	12, 0, 0, 0, 0, 0, 0, 0, 0, 0.45, 0.50, 0.45, 0.45,0.15, 0.50, 0.65, 03, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	['8804278'] = {"Dozla",		01,	43,	16,	11,	09,	11,	06,	04, 0, 0, 0, 0, 0, 0, 0, 0, 0.85, 0.50, 0.35, 0.40,0.30, 0.25, 0.30, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	['88041DC'] = {"Saleh",		01,	30,	16,	18,	14,	08,	13,	11, 0, 0, 0, 0, 0, 0, 0, 0, 0.50, 0.30, 0.25, 0.40,0.30, 0.35, 0.40, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	['8804210'] = {"Ewan",		01,	15,	03,	02,	05,	00,	03,	05, 0, 0, 0, 0, 0, 0, 0, 0, 0.50, 0.45, 0.40, 0.35,0.15, 0.40, 0.50, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
	['8804008'] = {"Cormag",	09,	30,	14,	09,	10,	12,	02,	04, 0, 0, 0, 0, 0, 0, 0, 0, 0.85, 0.55, 0.40, 0.45,0.25, 0.15, 0.35, 09, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	['88042E0'] = {"Rennac",	01,	28,	10,	16,	17,	09,	11,	05, 0, 0, 0, 0, 0, 0, 0, 0, 0.65, 0.25, 0.45, 0.60,0.25, 0.30, 0.25, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	['8804314'] = {"Duessel",	08,	41,	17,	12,	12,	17,	09,	08, 0, 0, 0, 0, 0, 0, 0, 0, 0.85, 0.55, 0.40, 0.30,0.45, 0.30, 0.20, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	['880437C'] = {"Knoll",		10,	22,	13,	09,	08,	02,	10,	00, 0, 0, 0, 0, 0, 0, 0, 0, 0.70, 0.50, 0.40, 0.35,0.10, 0.45, 0.20, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	['8804348'] = {"Myrrh",		01,	15,	03,	01,	05,	02,	07,	03, 0, 0, 0, 0, 0, 0, 0, 0, 1.30, 0.90, 0.85, 0.65,1.50, 0.30, 0.30, 01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	['88043E4'] = {"Syrene",	01,	27,	12,	13,	15,	10,	12,	12, 0, 0, 0, 0, 0, 0, 0, 0, 0.70, 0.40, 0.50, 0.60,0.20, 0.50, 0.30, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
	['testtest'] = {"",			00,	00,	00,	00,	00,	00,	00,	00, 0, 0, 0, 0, 0, 0, 0, 0, 0.00, 0.00, 0.00, 0.00,0.00, 0.00, 0.00, 00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
}

-- print(UnitsLut['8803D64'])
-- current units
local CurrentUnits = {'testtest', 'testtest', 'testtest'}

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
		re_draw = 1
	end
	if userInput.Left and heldDown['Left'] == false then
		-- help display on/off
		num_displayed_units = math.max(num_displayed_units - 1, 1)
		re_draw = 1
	end
	for key, value in pairs(heldDown) do
		heldDown[key] = true
		if userInput[key] == nil then
			heldDown[key] = false
		end
	end
end

local ross_promo_added = 0
local amelia_promo_added = 0
local ewan_promo_added = 0
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

local baseAddress = 0x0202BE4C
function updateLUT(char_number, stage)

end

function updateLUT_stage1(char_number)
	addr = baseAddress + (char_number*0x48)
	local Rom_unit = memory.read_u32_le(addr, "System Bus")
	Cdata['lookupKey'] = string.format("%07X", Rom_unit)
	unit_arr = UnitsLut[Cdata['lookupKey']]
end

function updateLUT_stage2(char_number) 
	unit_arr = UnitsLut[Cdata['lookupKey']]
	local bytes = memory.read_bytes_as_array(addr + 0x8, 18, "System Bus")
	lvl = bytes[1]
	-- If we're not promoted and have gained a level, add it to pp_lvl
	if unit_arr[34] == 0 and unit_arr[25] ~= 0 then
		unit_arr[25] = lvl
	end
	if unit_arr[35] ~= 10 and unit_arr[35] ~= 0 then
		unit_arr[35] = lvl
	end
	unit_arr[10] = lvl
	Cdata['lvl'] = lvl
	local maxHP = bytes[11]
	Cdata['maxHP'] = maxHP
	unit_arr[11] = maxHP
	local str = bytes[13]
	Cdata['str'] = str
	unit_arr[12] = str
	local skl = bytes[14]
	Cdata['skl'] = skl
	unit_arr[13] = skl
	local spd = bytes[15]
	Cdata['spd'] = spd
	unit_arr[14] = spd
	local def = bytes[16]
	Cdata['def'] = def
	unit_arr[15] = def
	local res = bytes[17]
	Cdata['res'] = res
	unit_arr[16] = res
	local lck = bytes[18]
	Cdata['lck'] = lck
	unit_arr[17] = lck
end

function updateLUT_stage3()
	local promo_hp_gain = 0
	local promo_str_gain = 0
	local promo_skl_gain = 0
	local promo_spd_gain = 0
	local promo_def_gain = 0
	local promo_res_gain = 0
	-- if level < pp_lvl, then we're a (somewhat) freshly promoted unit
	if (unit_arr[10] < unit_arr[25]) then
		unit_arr[34] = 1
	end	

	if (unit_arr[35] ~= 0) then -- we're a trainee
		if (Cdata['lookupKey'] == '8803E9C') then -- ross
			if (ross_promo_added == 0 and lvl == 1 and unit_arr[35] == 10) then -- Ross just promoted, add growth to bases
				rom_class = memory.read_u32_le(addr+0x4, "System Bus")
				promo_gain_arr = memory.read_bytes_as_array(rom_class + 0x22, 6, "System Bus")
				promo_hp_gain = promo_gain_arr[1]
				promo_str_gain = promo_gain_arr[2]
				promo_skl_gain = promo_gain_arr[3]
				promo_spd_gain = promo_gain_arr[4]
				promo_def_gain = promo_gain_arr[5]
				promo_res_gain = promo_gain_arr[6]
				unit_arr[3] = unit_arr[3] + promo_hp_gain
				unit_arr[4] = unit_arr[4] + promo_str_gain
				unit_arr[5] = unit_arr[5] + promo_skl_gain
				unit_arr[6] = unit_arr[6] + promo_spd_gain
				unit_arr[7] = unit_arr[7] + promo_def_gain
				unit_arr[8] = unit_arr[8] + promo_res_gain
				ross_promo_added = 1
				unit_arr[25] = 1
			end
			if unit_arr[34] == 1 then -- we were promoted, so do lvl - 1 + pp_lvl - b_lvl + ppp_lvl - 1
				Cdata['lvls_gained'] = unit_arr[10] - 1 + unit_arr[25] - unit_arr[2] + unit_arr[35] - 1
			elseif (unit_arr[25] > 0) then --we're not promoted yet (still trainee class), so do lvl - b_lvl + ppp_lvl - 1
				Cdata['lvls_gained'] = unit_arr[25] - unit_arr[2] + unit_arr[35] - 1
			else
				Cdata['lvls_gained'] = unit_arr[35] - unit_arr[2]
			end
		elseif (Cdata['lookupKey'] == '88040D8') then -- amelia
			if (amelia_promo_added == 0 and lvl == 1 and unit_arr[35] == 10) then -- Amelia just promoted, add growth to bases
				rom_class = memory.read_u32_le(addr+0x4, "System Bus")
				promo_gain_arr = memory.read_bytes_as_array(rom_class + 0x22, 6, "System Bus")
				promo_hp_gain = promo_gain_arr[1]
				promo_str_gain = promo_gain_arr[2]
				promo_skl_gain = promo_gain_arr[3]
				promo_spd_gain = promo_gain_arr[4]
				promo_def_gain = promo_gain_arr[5]
				promo_res_gain = promo_gain_arr[6]
				unit_arr[3] = unit_arr[3] + promo_hp_gain
				unit_arr[4] = unit_arr[4] + promo_str_gain
				unit_arr[5] = unit_arr[5] + promo_skl_gain
				unit_arr[6] = unit_arr[6] + promo_spd_gain
				unit_arr[7] = unit_arr[7] + promo_def_gain
				unit_arr[8] = unit_arr[8] + promo_res_gain
				amelia_promo_added = 1
				unit_arr[25] = 1
			end
			if unit_arr[34] == 1 then -- we were promoted, so do lvl - 1 + pp_lvl - b_lvl + ppp_lvl - 1
				Cdata['lvls_gained'] = unit_arr[10] - 1 + unit_arr[25] - unit_arr[2] + unit_arr[35] - 1
			elseif (unit_arr[25] > 0) then --we're not promoted yet (still trainee class), so do lvl - b_lvl + ppp_lvl - 1
				Cdata['lvls_gained'] = unit_arr[25] - unit_arr[2] + unit_arr[35] - 1
			else
				Cdata['lvls_gained'] = unit_arr[35] - unit_arr[2]
			end
		else -- Ewan
			if (ewan_promo_added == 0 and lvl == 1 and unit_arr[35] == 10) then -- Ewan just promoted, add growth to bases
				rom_class = memory.read_u32_le(addr+0x4, "System Bus")
				promo_gain_arr = memory.read_bytes_as_array(rom_class + 0x22, 6, "System Bus")
				promo_hp_gain = promo_gain_arr[1]
				promo_str_gain = promo_gain_arr[2]
				promo_skl_gain = promo_gain_arr[3]
				promo_spd_gain = promo_gain_arr[4]
				promo_def_gain = promo_gain_arr[5]
				promo_res_gain = promo_gain_arr[6]
				unit_arr[3] = unit_arr[3] + promo_hp_gain
				unit_arr[4] = unit_arr[4] + promo_str_gain
				unit_arr[5] = unit_arr[5] + promo_skl_gain
				unit_arr[6] = unit_arr[6] + promo_spd_gain
				unit_arr[7] = unit_arr[7] + promo_def_gain
				unit_arr[8] = unit_arr[8] + promo_res_gain
				ewan_promo_added = 1
				unit_arr[25] = 1
			end
			if unit_arr[34] == 1 then -- we were promoted, so do lvl - 1 + pp_lvl - b_lvl + ppp_lvl - 1
				Cdata['lvls_gained'] = unit_arr[10] - 1 + unit_arr[25] - unit_arr[2] + unit_arr[35] - 1
			elseif (unit_arr[25] > 0) then --we're not promoted yet (still trainee class), so do lvl - b_lvl + ppp_lvl - 1
				Cdata['lvls_gained'] = unit_arr[25] - unit_arr[2] + unit_arr[35] - 1
			else
					Cdata['lvls_gained'] = unit_arr[35] - unit_arr[2]
			end
		end
	elseif (unit_arr[25] == 0) then -- if pp_lvl == 0 then we're a pre-premote. do lvl - base + trainee levels
		Cdata['lvls_gained'] = unit_arr[10] - unit_arr[2]
	elseif unit_arr[34] == 1 then -- we were promoted, so do lvl - 1 + pp_lvl - b_lvl
		Cdata['lvls_gained'] = unit_arr[10] - 1 + unit_arr[25] - unit_arr[2]
	else -- we're unpromoted
		Cdata['lvls_gained'] = unit_arr[25] - unit_arr[2]
	end
	if (unit_arr[33] < Cdata['lvls_gained']) then
		leveled_up = 1
		-- print("level up detected")
	end
	unit_arr[33] = Cdata['lvls_gained']
end

function updateLUT_stage4()
	local unit_arr = UnitsLut[Cdata['lookupKey']]
	local promo_hp_gain = 0
	local promo_str_gain = 0
	local promo_skl_gain = 0
	local promo_spd_gain = 0
	local promo_def_gain = 0
	local promo_res_gain = 0
	if unit_arr[34] == 1 then 
		rom_class = memory.read_u32_le(addr + 0x4, "System Bus")
		promo_gain_arr = memory.read_bytes_as_array(rom_class + 0x22, 6, "System Bus")
		promo_hp_gain = promo_gain_arr[1]
		promo_str_gain = promo_gain_arr[2]
		promo_skl_gain = promo_gain_arr[3]
		promo_spd_gain = promo_gain_arr[4]
		promo_def_gain = promo_gain_arr[5]
		promo_res_gain = promo_gain_arr[6]
	end
	local avg_hp =  unit_arr[03] + math.floor(Cdata['lvls_gained'] * unit_arr[18] + 0.5) + promo_hp_gain
	local avg_str = unit_arr[04] + math.floor(Cdata['lvls_gained'] * unit_arr[19] + 0.5) + promo_str_gain
	local avg_skl = unit_arr[05] + math.floor(Cdata['lvls_gained'] * unit_arr[20] + 0.5) + promo_skl_gain
	local avg_spd = unit_arr[06] + math.floor(Cdata['lvls_gained'] * unit_arr[21] + 0.5) + promo_spd_gain
	local avg_def = unit_arr[07] + math.floor(Cdata['lvls_gained'] * unit_arr[22] + 0.5) + promo_def_gain
	local avg_res = unit_arr[08] + math.floor(Cdata['lvls_gained'] * unit_arr[23] + 0.5) + promo_res_gain
	local avg_lck = unit_arr[09] + math.floor(Cdata['lvls_gained'] * unit_arr[24] + 0.5)
	unit_arr[26] = Cdata['maxHP']-avg_hp
	unit_arr[27] = Cdata['str']-avg_str
	unit_arr[28] = Cdata['skl']-avg_skl
	unit_arr[29] = Cdata['spd']-avg_spd
	unit_arr[30] = Cdata['def']-avg_def
	unit_arr[31] = Cdata['res']-avg_res
	unit_arr[32] = Cdata['lck']-avg_lck
end

function updateLUT_stage5()
	if (leveled_up == 1) then 
		re_draw = 1
		-- print('requested redraw')
		leveled_up = 0
	end
	if Cdata['lvls_gained'] > UnitsLut[CurrentUnits[3]][33] then
		if CurrentUnits[3] ~= Cdata['lookupKey'] then
			CurrentUnits[1] = CurrentUnits[2]
			CurrentUnits[2] = CurrentUnits[3]
			CurrentUnits[3] = Cdata['lookupKey']
		end
	elseif Cdata['lvls_gained'] > UnitsLut[CurrentUnits[2]][33] then
		if CurrentUnits[2] ~= Cdata['lookupKey'] and CurrentUnits[3] ~= Cdata['lookupKey'] then
			CurrentUnits[1] = CurrentUnits[2]
			CurrentUnits[2] = Cdata['lookupKey']
		end
	elseif Cdata['lvls_gained'] > UnitsLut[CurrentUnits[1]][33] and CurrentUnits[1] ~= Cdata['lookupKey'] and CurrentUnits[2] ~= Cdata['lookupKey'] and CurrentUnits[3] ~= Cdata['lookupKey'] then
		CurrentUnits[1] = Cdata['lookupKey']
	end
end

-- gui.drawBox(int x, int y, int x2, int y2, [luacolor line = nil], [luacolor background = nil], [string surfacename = nil]) 
-- gui.drawBox(0, 0, 110, bufferheight-1, "#A97060", "#532e21", "emucore")
local origin = client.transformPoint(0, 0)
local unit = client.transformPoint(1, 1)
local scaleX = unit.x - origin.x
local scaleY = unit.y - origin.y


while true do
	userInput = input.get()
	local origin = client.transformPoint(0, 0)
	if (emu.framecount() & 0xFF) < 0x90 then
		-- I want to do all 5 stages of updating the LUT for each character
		--        0 0 0 0 0             0 0 0
		-- 5 bits for characters  3 bits for stages
		-- emu.framecount < 2^8 (256)
		-- max_char = 10010 000 = 0x90
		-- call updateLUT with the top 5 bits
		
		-- lower bits are what state of calculations we're on
		local stage = emu.framecount() & 0x7
		-- char number effects the offset in memory we want to read for the character
		local char_number = (emu.framecount() & 0xF8) >> 3
		if (stage == 1) then
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
			if (stage == 5) then
				updateLUT_stage5()
			end
		end
		
    end
	
	if (re_draw == 1) then
		-- print("redrawing!!")
		if (num_displayed_units == 3) then
			width = 115
		elseif num_displayed_units == 2 then
			width = 82
		else
			width = 49
		end
		if (last_num_displayed ~= num_displayed_units) then
			client.SetGameExtraPadding(width, 0, 0, 0)
		end
		last_num_displayed = num_displayed_units

		drawBox(0, 0, width, bufferheight-1, "#A97060", "#532e21", "emucore")
		drawLine(15, 0, 15, bufferheight, "#A97060", "emucore") -- vertical line at -98
		
		drawLine(0, 42, width, 42, "#A97060", "emucore") -- horizontal line at 42
		drawLine(0, 52, width, 52, "#A97060", "emucore") -- horizontal line at 52
		drawLine(0, 62, width, 62, "#A97060", "emucore") -- horizontal line at 62
		drawLine(0, 72, width, 72, "#A97060", "emucore") -- horizontal line at 72
		drawLine(0, 82, width, 82, "#A97060", "emucore") -- horizontal line at 82
		drawLine(0, 92, width, 92, "#A97060", "emucore") -- horizontal line at 92
		drawLine(0, 102, width, 102, "#A97060", "emucore") -- horizontal line at 102
		drawLine(0, 112, width, 112, "#A97060", "emucore") -- horizontal line at 112
		
		-- gui.drawImage("./images/Ephraim.png", 17, 1)
		gui.drawImageRegion("./images/ref_img.png",0,0,13,6,1,45) -- lvl
		gui.drawImageRegion("./images/ref_img.png",0,6,13,6,1,55) -- hp
		gui.drawImageRegion("./images/ref_img.png",0,12,13,6,1,65) -- str
		gui.drawImageRegion("./images/ref_img.png",0,18,13,6,1,75) -- skl
		gui.drawImageRegion("./images/ref_img.png",0,24,13,6,1,85) -- spd
		gui.drawImageRegion("./images/ref_img.png",0,30,13,6,1,95) -- lck
		gui.drawImageRegion("./images/ref_img.png",0,36,13,6,1,105) -- def
		gui.drawImageRegion("./images/ref_img.png",0,42,13,6,1,115) -- res
		unitInfo = UnitsLut[CurrentUnits[3]]
		if (unitInfo[1] ~= '') then
			gui.drawImage("./images/"..unitInfo[1]..".png", width-33, 1)
			local name_index = math.floor((tonumber(CurrentUnits[3],16) - 142622000)/52)
			gui.drawImageRegion("./images/ref_img.png",37,0 + name_index*6,32,6,width-33,35) -- Name
			gui.drawImageRegion("./images/ref_img.png",13,0 + unitInfo[10]*6,9,6,width-33 + 9,45) -- lvl
			gui.drawImageRegion("./images/ref_img.png",13,0 + unitInfo[11]*6,9,6,width-33 + 4,55) -- hp
			gui.drawImageRegion("./images/ref_img.png",22,125 + (unitInfo[26])*6,15,6,width-33 + 13,55) -- hp avg
			gui.drawImageRegion("./images/ref_img.png",13,0 + unitInfo[12]*6,9,6,width-33 + 4,65) -- str
			gui.drawImageRegion("./images/ref_img.png",22,125 + (unitInfo[27])*6,15,6,width-33 + 13,65) -- str avg
			gui.drawImageRegion("./images/ref_img.png",13,0 + unitInfo[13]*6,9,6,width-33 + 4,75) -- skl
			gui.drawImageRegion("./images/ref_img.png",22,125 + (unitInfo[28])*6,15,6,width-33 + 13,75) -- skl avg
			gui.drawImageRegion("./images/ref_img.png",13,0 + unitInfo[14]*6,9,6,width-33 + 4,85) -- spd
			gui.drawImageRegion("./images/ref_img.png",22,125 + (unitInfo[29])*6,15,6,width-33 + 13,85) -- spd avg
			gui.drawImageRegion("./images/ref_img.png",13,0 + unitInfo[15]*6,9,6,width-33 + 4,95) -- lck
			gui.drawImageRegion("./images/ref_img.png",22,125 + (unitInfo[32])*6,15,6,width-33 + 13,95) -- lck avg
			gui.drawImageRegion("./images/ref_img.png",13,0 + unitInfo[16]*6,9,6,width-33 + 4,105) -- def
			gui.drawImageRegion("./images/ref_img.png",22,125 + (unitInfo[30])*6,15,6,width-33 + 13,105) -- def avg
			gui.drawImageRegion("./images/ref_img.png",13,0 + unitInfo[17]*6,9,6,width-33 + 4,115) -- res
			gui.drawImageRegion("./images/ref_img.png",22,125 + (unitInfo[31])*6,15,6,width-33 + 13,115) -- res avg
		end
		if (num_displayed_units > 1) then
			drawLine(48, 0, 48, bufferheight, "#A97060", "emucore") -- vertical line at -66
			unitInfo = UnitsLut[CurrentUnits[2]]
			if (unitInfo[1] ~= '') then
				gui.drawImage("./images/"..unitInfo[1]..".png", width-67, 1)
				local name_index = math.floor((tonumber(CurrentUnits[2],16) - 142622000)/52)
				gui.drawImageRegion("./images/ref_img.png",37,0 + name_index*6,32,6,width-65,35) -- Name
				gui.drawImageRegion("./images/ref_img.png",13,0 + unitInfo[10]*6,9,6,width-65 + 9,45) -- lvl
				gui.drawImageRegion("./images/ref_img.png",13,0 + unitInfo[11]*6,9,6,width-65 + 4,55) -- hp
				gui.drawImageRegion("./images/ref_img.png",22,125 + (unitInfo[26])*6,15,6,width-65 + 13,55) -- hp avg
				gui.drawImageRegion("./images/ref_img.png",13,0 + unitInfo[12]*6,9,6,width-65 + 4,65) -- str
				gui.drawImageRegion("./images/ref_img.png",22,125 + (unitInfo[27])*6,15,6,width-65 + 13,65) -- str avg
				gui.drawImageRegion("./images/ref_img.png",13,0 + unitInfo[13]*6,9,6,width-65 + 4,75) -- skl
				gui.drawImageRegion("./images/ref_img.png",22,125 + (unitInfo[28])*6,15,6,width-65 + 13,75) -- skl avg
				gui.drawImageRegion("./images/ref_img.png",13,0 + unitInfo[14]*6,9,6,width-65 + 4,85) -- spd
				gui.drawImageRegion("./images/ref_img.png",22,125 + (unitInfo[29])*6,15,6,width-65 + 13,85) -- spd avg
				gui.drawImageRegion("./images/ref_img.png",13,0 + unitInfo[15]*6,9,6,width-65 + 4,95) -- lck
				gui.drawImageRegion("./images/ref_img.png",22,125 + (unitInfo[32])*6,15,6,width-65 + 13,95) -- lck avg
				gui.drawImageRegion("./images/ref_img.png",13,0 + unitInfo[16]*6,9,6,width-65 + 4,105) -- def
				gui.drawImageRegion("./images/ref_img.png",22,125 + (unitInfo[30])*6,15,6,width-65 + 13,105) -- def avg
				gui.drawImageRegion("./images/ref_img.png",13,0 + unitInfo[17]*6,9,6,width-65 + 4,115) -- res
				gui.drawImageRegion("./images/ref_img.png",22,125 + (unitInfo[31])*6,15,6,width-65 + 13,115) -- res avg
			end
		end
		if (num_displayed_units > 2) then
			drawLine(81, 0, 81, bufferheight, "#A97060", "emucore") -- vertical line at -34
			unitInfo = UnitsLut[CurrentUnits[1]]
			if (unitInfo[1] ~= '') then
				gui.drawImage("./images/"..unitInfo[1]..".png", width-99, 1)
				local name_index = math.floor((tonumber(CurrentUnits[1],16) - 142622000)/52)
				gui.drawImageRegion("./images/ref_img.png",37,0 + name_index*6,32,6,width-97,35) -- Name
				gui.drawImageRegion("./images/ref_img.png",13,0 + unitInfo[10]*6,9,6,width-97 + 9,45) -- lvl
				gui.drawImageRegion("./images/ref_img.png",13,0 + unitInfo[11]*6,9,6,width-97 + 4,55) -- hp
				gui.drawImageRegion("./images/ref_img.png",22,125 + (unitInfo[26])*6,15,6,width-97 + 13,55) -- hp avg
				gui.drawImageRegion("./images/ref_img.png",13,0 + unitInfo[12]*6,9,6,width-97 + 4,65) -- str
				gui.drawImageRegion("./images/ref_img.png",22,125 + (unitInfo[27])*6,15,6,width-97 + 13,65) -- str avg
				gui.drawImageRegion("./images/ref_img.png",13,0 + unitInfo[13]*6,9,6,width-97 + 4,75) -- skl
				gui.drawImageRegion("./images/ref_img.png",22,125 + (unitInfo[28])*6,15,6,width-97 + 13,75) -- skl avg
				gui.drawImageRegion("./images/ref_img.png",13,0 + unitInfo[14]*6,9,6,width-97 + 4,85) -- spd
				gui.drawImageRegion("./images/ref_img.png",22,125 + (unitInfo[29])*6,15,6,width-97 + 13,85) -- spd avg
				gui.drawImageRegion("./images/ref_img.png",13,0 + unitInfo[15]*6,9,6,width-97 + 4,95) -- lck
				gui.drawImageRegion("./images/ref_img.png",22,125 + (unitInfo[32])*6,15,6,width-97 + 13,95) -- lck avg
				gui.drawImageRegion("./images/ref_img.png",13,0 + unitInfo[16]*6,9,6,width-97 + 4,105) -- def
				gui.drawImageRegion("./images/ref_img.png",22,125 + (unitInfo[30])*6,15,6,width-97 + 13,105) -- def avg
				gui.drawImageRegion("./images/ref_img.png",13,0 + unitInfo[17]*6,9,6,width-97 + 4,115) -- res
				gui.drawImageRegion("./images/ref_img.png",22,125 + (unitInfo[31])*6,15,6,width-97 + 13,115) -- res avg
			end
		end
		re_draw = 0
	end
	
	pos = client.transformPoint(1, bufferheight-7)
	checkForUserInput()
	if memory.readbyte(phaseMap[currentGame]) == 0 then
		advanceRNG()
		userInput = input.get()
		checkForUserInput()
		-- turn into a draw box?
		gui.text(0, pos.y, "ACTIVE", 0xFF00FF40)
		if displayRNG then
			printRNG(numDisplayedRNs)
		end
		-- emu.frameadvance()
	else
		gui.text(0, pos.y, "PAUSED", "red")
	end
	if displayRNG then
		printRNG(numDisplayedRNs)
	end
	emu.frameadvance()
end
