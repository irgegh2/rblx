--[[
	╔══════════════════════════════════════════════════════════════╗
	║  Config  —  ТИП: ModuleScript                                  ║
	║  ПОЛОЖИТЬ В:  ReplicatedStorage > Shared > Config              ║
	╚══════════════════════════════════════════════════════════════╝

	Единственное место для настройки баланса. И сервер, и клиент
	читают эти значения, поэтому всё всегда совпадает.
]]

local Config = {}

-- ВАЛЮТЫ -------------------------------------------------------------------
Config.Currency = {
	OofName  = "Oof",
	GemsName = "Gems",
}

-- НАЧАЛЬНЫЕ ЗНАЧЕНИЯ НОВОГО ИГРОКА -----------------------------------------
Config.Start = {
	Oof  = 0,
	Gems = 0,
}

-- DATASTORE ----------------------------------------------------------------
Config.Data = {
	StoreName = "OofIncremental_v1", -- смени _v1 -> _v2 чтобы обнулить ВСЕ сейвы
	AutoSaveInterval = 60,
}

-- NPC ("Noob") -------------------------------------------------------------
Config.Noob = {
	BuyCost = 0,        -- цена первого ноба (0 = бесплатно при наступании на кнопку)

	BaseInterval = 3,   -- раз в сколько секунд ноб приносит Oof
	BaseReward   = 1,   -- ДОХОД на 1 уровне (база, без множителя More Oof)
	RewardGrowth = 1.626, -- доход растёт В РАЗ за каждый уровень (геометрия)

	MaxLevel          = 1000,
	UpgradeBaseCost   = 2.29, -- цена прокачки 1 -> 2
	UpgradeCostGrowth = 2.29, -- цена растёт В РАЗ за каждый уровень

	-- ВАЖНО: риг теперь лежит в ReplicatedStorage (его клонирует КЛИЕНТ локально).
	RigName     = "NoobRig",
	AnimationId = "rbxassetid://507770677", -- анимация ноба (стандартный "Cheer")
	DisplayName = "Starter Noob",
}

-- УЛУЧШЕНИЯ НА ДОСКЕ (SurfaceGui). Порядок = порядок кнопок слева направо --
Config.Upgrades = {
	{
		Id = "MoreOof",
		DisplayName = "More Oof",
		Desc = "[x2 every 15 upgrades]",
		MaxLevel = 50,
		BaseCost = 75,
		CostGrowth = 1.6,
	},
	{
		Id = "FasterNoobs",
		DisplayName = "Faster Noobs",
		Desc = "Speeds up your noob",
		MaxLevel = 5,
		BaseCost = 10000,
		CostGrowth = 4,
		IntervalReductionPerLevel = 0.1,
	},
}

-- ГЕМЫ: пассивный доход по таймеру -----------------------------------------
Config.Gems = {
	Interval = 35,
	Amount   = 2,
}

-- ПРЕСТИЖ (для шкалы прогресса вверху) -------------------------------------
Config.Prestige = {
	BaseRequirement = 5e12, -- 5T Oof для Prestige 1
	Growth = 10,
}

-- ОБЩАЯ ЛОКАЦИЯ (одна на всех; ноб и доска рисуются локально у каждого) -----
-- Сервер строит эти части один раз при старте, если их ещё нет в Workspace.
-- Хочешь свою красивую локацию — просто создай части с такими же ИМЕНАМИ
-- (Button, Board) в Workspace > GameLocation, и сервер их не будет дублировать.
Config.World = {
	FolderName = "GameLocation",

	-- "Кнопка" = площадка, на которую игрок НАСТУПАЕТ (Touched). На ней же стоит ноб.
	ButtonPos  = Vector3.new(0, 0.5, 0),
	ButtonSize = Vector3.new(10, 1, 10),

	-- Доска улучшений (на неё клиент вешает SurfaceGui).
	BoardPos  = Vector3.new(-14, 8, -14),
	BoardSize = Vector3.new(26, 14, 1),

	-- Где появляется игрок.
	SpawnPos = Vector3.new(0, 4, 24),
}

-- СТРЕЛКА-МАРШРУТ (Beam от игрока к цели) ----------------------------------
-- Вставь сюда ID своей картинки-пунктира/стрелки (она будет текстурой луча).
-- Оставь "rbxassetid://0" — будет просто белая линия без текстуры.
Config.ArrowImageId = "rbxassetid://0"

return Config
