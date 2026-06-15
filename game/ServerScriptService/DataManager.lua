--[[
	╔══════════════════════════════════════════════════════════════╗
	║  DataManager  —  ТИП: ModuleScript                             ║
	║  ПОЛОЖИТЬ В:  ServerScriptService > DataManager               ║
	╚══════════════════════════════════════════════════════════════╝

	Индивидуальное сохранение для каждого игрока через DataStore.
	Профиль хранится в памяти, периодически и при выходе пишется в стор.
]]

local DataStoreService = game:GetService("DataStoreService")

local Shared  = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config  = require(Shared:WaitForChild("Config"))

local store = DataStoreService:GetDataStore(Config.Data.StoreName)

local DataManager = {}
local profiles = {} -- [player] = profileTable

-- Профиль по умолчанию (для новых игроков и для новых полей)
local function defaultProfile()
	return {
		Oof       = Config.Start.Oof,
		Gems      = Config.Start.Gems,
		HasNoob   = false, -- true после покупки ноба по кнопке
		NoobLevel = 1,
		Upgrades  = {
			MoreOof     = 0,
			FasterNoobs = 0,
		},
		Prestige  = 0,
	}
end

-- Дополняем сохранёнку недостающими полями (на случай обновления игры)
local function reconcile(saved, template)
	for key, value in pairs(template) do
		if saved[key] == nil then
			if type(value) == "table" then
				saved[key] = reconcile({}, value)
			else
				saved[key] = value
			end
		elseif type(value) == "table" and type(saved[key]) == "table" then
			reconcile(saved[key], value)
		end
	end
	return saved
end

-- Загрузка профиля игрока (с ретраями)
function DataManager.load(player)
	local key = "Player_" .. player.UserId

	local data
	local ok, err
	for attempt = 1, 4 do
		ok, err = pcall(function()
			data = store:GetAsync(key)
		end)
		if ok then break end
		warn(("[DataManager] load fail (%d) for %s: %s"):format(attempt, player.Name, tostring(err)))
		task.wait(2 ^ attempt)
	end

	local profile
	if ok and type(data) == "table" then
		profile = reconcile(data, defaultProfile())
	else
		profile = defaultProfile()
		if not ok then
			-- НЕ перезаписываем чужую/повреждённую сохранёнку: помечаем как "не сохранять"
			profile.__doNotSave = true
			warn("[DataManager] using temp profile for " .. player.Name)
		end
	end

	profiles[player] = profile
	return profile
end

-- Получить профиль из памяти
function DataManager.get(player)
	return profiles[player]
end

-- Записать профиль в DataStore
function DataManager.save(player)
	local profile = profiles[player]
	if not profile or profile.__doNotSave then return end

	local key = "Player_" .. player.UserId
	-- копия без служебных полей
	local toSave = {}
	for k, v in pairs(profile) do
		if not tostring(k):match("^__") then
			toSave[k] = v
		end
	end

	local ok, err
	for attempt = 1, 4 do
		ok, err = pcall(function()
			store:SetAsync(key, toSave)
		end)
		if ok then break end
		warn(("[DataManager] save fail (%d) for %s: %s"):format(attempt, player.Name, tostring(err)))
		task.wait(2 ^ attempt)
	end
end

-- Сохранить и выгрузить из памяти (при выходе)
function DataManager.release(player)
	DataManager.save(player)
	profiles[player] = nil
end

return DataManager
