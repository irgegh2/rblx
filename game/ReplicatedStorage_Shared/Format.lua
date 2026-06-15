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

function Format.short(n)
	n = tonumber(n) or 0
	if n < 1000 then
		-- мелкие числа — с дробью: 2.29, 5.25, 33.6, 144 (хвостовые нули убираем)
		local s = string.format("%.2f", n)
		s = s:gsub("%.?0+$", "")
		return s
	end
	n = math.floor(n)

	local index = math.floor(math.log(n, 1000))
	index = math.clamp(index, 1, #SUFFIXES - 1)

	local scaled = n / (1000 ^ index)
	local text = string.format("%.1f", scaled)
	text = text:gsub("%.0$", "") -- "5.0" -> "5"
	return text .. SUFFIXES[index + 1]
end

return Format
