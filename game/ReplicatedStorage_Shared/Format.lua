--[[
	╔══════════════════════════════════════════════════════════════╗
	║  Format  —  ТИП: ModuleScript                                  ║
	║  ПОЛОЖИТЬ В:  ReplicatedStorage > Shared > Format             ║
	╚══════════════════════════════════════════════════════════════╝

	Короткая запись больших чисел: 1500 -> "1.5K", 3.6e12 -> "3.6T".
]]

local Format = {}

local SUFFIXES = {
	"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc",
}

-- округление до 3 значащих цифр (как в оригинале: 2.29 / 27.6 / 145 / 332)
local function round3(n)
	if n <= 0 then return 0 end
	local digits = math.floor(math.log10(n)) + 1
	local mult = 10 ^ (3 - digits)
	return math.floor(n * mult + 0.5) / mult
end

function Format.short(n)
	n = tonumber(n) or 0
	if n < 1000 then
		-- мелкие числа: 3 значащих цифры, хвостовые нули убираем (2.29, 12, 27.6, 145)
		local s = string.format("%.2f", round3(n))
		s = s:gsub("%.?0+$", "")
		return s
	end

	local index = math.floor(math.log(n, 1000))
	index = math.clamp(index, 1, #SUFFIXES - 1)

	local scaled = round3(n / (1000 ^ index))
	local text = string.format("%.2f", scaled)
	text = text:gsub("%.?0+$", "") -- "5.00" -> "5", "1.50" -> "1.5"
	return text .. SUFFIXES[index + 1]
end

return Format
