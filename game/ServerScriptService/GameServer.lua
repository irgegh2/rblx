--[[
	╔══════════════════════════════════════════════════════════════╗
	║  GameServer  —  ТИП: Script (обычный серверный скрипт)         ║
	║  ПОЛОЖИТЬ В:  ServerScriptService > GameServer                ║
	╚══════════════════════════════════════════════════════════════╝

	Главный серверный скрипт (он же — анти-чит: вся экономика тут).
	  • создаёт RemoteEvents (ReplicatedStorage > Remotes);
	  • строит ОДНУ общую локацию (Workspace > GameLocation): кнопку-площадку,
	    доску, точку спавна — один раз для всех;
	  • игрок НАСТУПАЕТ на кнопку (Touched) -> если ноба нет, покупает его;
	  • раз в N секунд начисляет Oof (если у игрока есть ноб) + гемы по таймеру;
	  • прокачка ноба и покупка улучшений (с проверкой на сервере);
	  • автосейв + сохранение при выходе.

	Ноб и доска РИСУЮТСЯ ЛОКАЛЬНО на клиенте (см. ClientMain) — сервер хранит
	только данные (HasNoob, уровни, валюту).
]]

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace        = game:GetService("Workspace")

local Shared    = ReplicatedStorage:WaitForChild("Shared")
local Config    = require(Shared:WaitForChild("Config"))
local Formulas  = require(Shared:WaitForChild("Formulas"))
local Format    = require(Shared:WaitForChild("Format"))

local DataManager = require(script.Parent:WaitForChild("DataManager"))

-- ── РЕМОУТЫ ──────────────────────────────────────────────────────────────
local Remotes = Instance.new("Folder")
Remotes.Name = "Remotes"
Remotes.Parent = ReplicatedStorage

local function makeRemote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = Remotes
	return r
end

local SyncData    = makeRemote("SyncData")    -- server -> client (весь профиль)
local Notify      = makeRemote("Notify")      -- server -> client (всплывашка "+X")
local RequestData = makeRemote("RequestData") -- client -> server (дай данные)
local UpgradeNoob = makeRemote("UpgradeNoob") -- client -> server
local BuyUpgrade  = makeRemote("BuyUpgrade")  -- client -> server (id, mode)

-- ── ОБЩАЯ ЛОКАЦИЯ (строим один раз) ──────────────────────────────────────
local function makePart(name, size, cframe, color, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Anchored = true
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local buttonPart -- площадка-кнопка (общая)

local function buildWorld()
	local folder = Workspace:FindFirstChild(Config.World.FolderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = Config.World.FolderName
		folder.Parent = Workspace
	end

	-- пол
	if not folder:FindFirstChild("Floor") then
		makePart("Floor", Vector3.new(120, 1, 120), CFrame.new(0, 0, 0),
			Color3.fromRGB(120, 200, 120), folder)
	end

	-- кнопка-площадка (на неё наступают; на ней стоит ноб)
	buttonPart = folder:FindFirstChild("Button")
	if not buttonPart then
		buttonPart = makePart("Button", Config.World.ButtonSize,
			CFrame.new(Config.World.ButtonPos), Color3.fromRGB(85, 170, 255), folder)
		buttonPart.Material = Enum.Material.Neon
	end

	-- доска (SurfaceGui повесит клиент). Front-грань смотрит к игроку (+Z).
	if not folder:FindFirstChild("Board") then
		local board = makePart("Board", Config.World.BoardSize,
			CFrame.lookAt(Config.World.BoardPos, Config.World.BoardPos + Vector3.new(0, 0, 1)),
			Color3.fromRGB(20, 18, 40), folder)
		board.Material = Enum.Material.SmoothPlastic
	end

	-- точка спавна
	if not folder:FindFirstChild("Spawn") then
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn"
		spawn.Size = Vector3.new(8, 1, 8)
		spawn.CFrame = CFrame.new(Config.World.SpawnPos)
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Color = Color3.fromRGB(60, 60, 70)
		spawn.Parent = folder
	end

	return folder
end

-- ── СИНХРОНИЗАЦИЯ КЛИЕНТУ ───────────────────────────────────────────────
local function snapshot(profile)
	return {
		Oof       = profile.Oof,
		Gems      = profile.Gems,
		HasNoob   = profile.HasNoob,
		NoobLevel = profile.NoobLevel,
		Upgrades  = { MoreOof = profile.Upgrades.MoreOof, FasterNoobs = profile.Upgrades.FasterNoobs },
		Prestige  = profile.Prestige,
	}
end

local function sync(player)
	local profile = DataManager.get(player)
	if profile then
		SyncData:FireClient(player, snapshot(profile))
	end
end

-- ── ПОКУПКА НОБА ПО НАСТУПАНИЮ ───────────────────────────────────────────
local buyDebounce = {} -- [player] = true (чтобы Touched не сработал сто раз)

local function tryBuyNoob(player)
	local p = DataManager.get(player)
	if not p or p.HasNoob then return end
	if p.Oof < Config.Noob.BuyCost then return end
	p.Oof -= Config.Noob.BuyCost
	p.HasNoob = true
	sync(player)
	Notify:FireClient(player, "Noob unlocked!", "oof")
end

local function onButtonTouched(hit)
	local character = hit and hit.Parent
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end
	if buyDebounce[player] then return end

	local p = DataManager.get(player)
	if not p or p.HasNoob then return end

	buyDebounce[player] = true
	tryBuyNoob(player)
	task.delay(1, function() buyDebounce[player] = nil end)
end

-- ── ВХОД ИГРОКА ──────────────────────────────────────────────────────────
local function onPlayerAdded(player)
	DataManager.load(player)

	-- ДОХОД ОТ НОБА
	task.spawn(function()
		while DataManager.get(player) do
			local p = DataManager.get(player)
			local interval = p and p.HasNoob and Formulas.noobInterval(p) or Config.Noob.BaseInterval
			task.wait(interval)
			p = DataManager.get(player)
			if not p then break end
			if p.HasNoob then
				local reward = Formulas.noobReward(p)
				p.Oof += reward
				sync(player)
				Notify:FireClient(player, "+" .. Format.short(reward) .. " Oof", "oof")
			end
		end
	end)

	-- ГЕМЫ
	task.spawn(function()
		while DataManager.get(player) do
			task.wait(Config.Gems.Interval)
			local p = DataManager.get(player)
			if not p then break end
			p.Gems += Config.Gems.Amount
			sync(player)
			Notify:FireClient(player, "+" .. Format.short(Config.Gems.Amount) .. " Gems", "gems")
		end
	end)

	sync(player)
end

local function onPlayerRemoving(player)
	DataManager.release(player)
	buyDebounce[player] = nil
end

-- ── ОБРАБОТКА ПОКУПОК ────────────────────────────────────────────────────
UpgradeNoob.OnServerEvent:Connect(function(player)
	local p = DataManager.get(player)
	if not p or not p.HasNoob then return end
	if p.NoobLevel >= Config.Noob.MaxLevel then return end
	local cost = Formulas.noobUpgradeCost(p.NoobLevel)
	if p.Oof >= cost then
		p.Oof -= cost
		p.NoobLevel += 1
		sync(player)
	end
end)

BuyUpgrade.OnServerEvent:Connect(function(player, id, mode)
	if type(id) ~= "string" then return end
	local p = DataManager.get(player)
	if not p then return end
	local cfg = Formulas.getUpgradeConfig(id)
	if not cfg or type(p.Upgrades[id]) ~= "number" then return end

	local function buyOne()
		local lvl = p.Upgrades[id]
		if lvl >= cfg.MaxLevel then return false end
		local cost = Formulas.upgradeCost(id, lvl)
		if p.Oof >= cost then
			p.Oof -= cost
			p.Upgrades[id] = lvl + 1
			return true
		end
		return false
	end

	if mode == "max" then
		local guard = 0
		while buyOne() do
			guard += 1
			if guard >= 100000 then break end
		end
	else
		buyOne()
	end
	sync(player)
end)

RequestData.OnServerEvent:Connect(function(player)
	sync(player)
end)

-- ── СТАРТ ────────────────────────────────────────────────────────────────
local world = buildWorld()
buttonPart.Touched:Connect(onButtonTouched)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- автосейв
task.spawn(function()
	while true do
		task.wait(Config.Data.AutoSaveInterval)
		for _, player in ipairs(Players:GetPlayers()) do
			DataManager.save(player)
		end
	end
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		DataManager.save(player)
	end
	task.wait(2)
end)

print("[GameServer] запущен ✔ (локация: " .. world.Name .. ")")
