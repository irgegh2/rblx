--[[
	╔══════════════════════════════════════════════════════════════╗
	║  Formulas  —  ТИП: ModuleScript                                ║
	║  ПОЛОЖИТЬ В:  ReplicatedStorage > Shared > Formulas           ║
	╚══════════════════════════════════════════════════════════════╝

	Все расчёты цен и дохода. Используется И сервером (он главный),
	И клиентом (чтобы рисовать цены на кнопках). Так значения совпадают.
]]

local Config = require(script.Parent.Config)

local Formulas = {}

-- Найти конфиг улучшения по Id ("MoreOof" / "FasterNoobs")
function Formulas.getUpgradeConfig(id)
	for _, u in ipairs(Config.Upgrades) do
		if u.Id == id then
			return u
		end
	end
	return nil
end

-- Множитель от "More Oof": x2 за каждые 15 уровней
function Formulas.moreOofMultiplier(moreOofLevel)
	return 2 ^ math.floor((moreOofLevel or 0) / 15)
end

-- Доход ноба за один тик (геометрия: BaseReward * RewardGrowth^(level-1) * множитель)
function Formulas.noobReward(profile)
	local level = profile.NoobLevel or 1
	local base = Config.Noob.BaseReward * (Config.Noob.RewardGrowth ^ (level - 1))
	local mult = Formulas.moreOofMultiplier(profile.Upgrades.MoreOof)
	return base * mult
end

-- Интервал между тиками (секунды), ускоряется "Faster Noobs"
function Formulas.noobInterval(profile)
	local cfg = Formulas.getUpgradeConfig("FasterNoobs")
	local level = profile.Upgrades.FasterNoobs or 0
	local reduction = level * (cfg and cfg.IntervalReductionPerLevel or 0)
	return math.max(0.25, Config.Noob.BaseInterval - reduction)
end

-- Цена прокачки ноба с текущего уровня на следующий (геометрия)
function Formulas.noobUpgradeCost(currentLevel)
	return Config.Noob.UpgradeBaseCost * (Config.Noob.UpgradeCostGrowth ^ (currentLevel - 1))
end

-- Цена улучшения на доске на следующий уровень
function Formulas.upgradeCost(id, currentLevel)
	local cfg = Formulas.getUpgradeConfig(id)
	if not cfg then return math.huge end
	return math.floor(cfg.BaseCost * cfg.CostGrowth ^ currentLevel)
end

-- Сколько Oof нужно для текущего престижа (для шкалы прогресса)
function Formulas.prestigeRequirement(prestigeLevel)
	return Config.Prestige.BaseRequirement * (Config.Prestige.Growth ^ (prestigeLevel or 0))
end

return Formulas
