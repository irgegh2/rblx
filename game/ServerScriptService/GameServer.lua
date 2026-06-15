--[[
	╔══════════════════════════════════════════════════════════════╗
	║  GameServer  —  ТИП: Script (обычный серверный скрипт)         ║
	║  ПОЛОЖИТЬ В:  ServerScriptService > GameServer                ║
	╚══════════════════════════════════════════════════════════════╝

	Главный серверный скрипт. Делает:
	  • создаёт RemoteEvents (папка ReplicatedStorage > Remotes);
	  • на вход игрока: грузит сейв, строит личный плот, телепортит туда;
	  • кнопка (ProximityPrompt) -> покупка ноба -> спавн ноба с анимацией;
	  • раз в N секунд ноб приносит Oof (начисляется на баланс автоматически);
	  • гемы капают по таймеру;
	  • прокачка ноба и покупка улучшений на доске;
	  • автосейв + сохранение при выходе.
]]

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage    = game:GetService("ServerStorage")
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

-- ── ПЛОТЫ ────────────────────────────────────────────────────────────────
local Plots = Instance.new("Folder")
Plots.Name = "Plots"
Plots.Parent = Workspace

local plotData = {}     -- [player] = {folder, button, pad, board, index, spawnCFrame}
local usedIndices = {}  -- [index] = true

local function allocIndex()
	local i = 0
	while usedIndices[i] do i += 1 end
	usedIndices[i] = true
	return i
end

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

-- Строим простой рабочий плот. Геометрию потом легко заменить своими моделями
-- (главное — сохранить имена детей: "Button", "Pad", "Board" и Owner).
local function buildPlot(player)
	local index = allocIndex()
	local base = Config.Plot.Origin + Vector3.new(index * Config.Plot.Spacing, 0, 0)

	local folder = Instance.new("Folder")
	folder.Name = "Plot_" .. player.UserId
	folder.Parent = Plots

	local owner = Instance.new("ObjectValue")
	owner.Name = "Owner"
	owner.Value = player
	owner.Parent = folder

	-- пол
	makePart("Floor", Vector3.new(60, 1, 60), CFrame.new(base), Color3.fromRGB(120, 200, 120), folder)

	-- площадка под ноба
	local pad = makePart("Pad", Vector3.new(10, 1, 10),
		CFrame.new(base + Vector3.new(6, 1, -4)), Color3.fromRGB(235, 220, 90), folder)

	-- кнопка-пьедестал (к ней ведёт стрелка-туториал)
	local button = makePart("Button", Vector3.new(6, 4, 6),
		CFrame.new(base + Vector3.new(-8, 2.5, -2)), Color3.fromRGB(85, 170, 255), folder)
	button.Material = Enum.Material.Neon

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ActionText = "Get your Noob"
	prompt.ObjectText = "Free!"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = button

	-- доска улучшений (SurfaceGui построит клиент). Front-грань смотрит к игроку.
	local boardPos = base + Vector3.new(-12, 8, -16)
	local board = makePart("Board", Vector3.new(26, 14, 1),
		CFrame.lookAt(boardPos, boardPos + Vector3.new(0, 0, 1)), Color3.fromRGB(20, 18, 40), folder)
	board.Material = Enum.Material.SmoothPlastic

	local spawnCFrame = CFrame.new(base + Vector3.new(0, 4, 14),
		base + Vector3.new(0, 4, -10)) -- лицом к доске/нобу

	plotData[player] = {
		folder = folder, button = button, pad = pad, board = board,
		index = index, prompt = prompt, spawnCFrame = spawnCFrame,
	}
	return plotData[player]
end

-- ── СПАВН НОБА ───────────────────────────────────────────────────────────
local function spawnNoob(player)
	local pd = plotData[player]
	if not pd or pd.folder:FindFirstChild("Noob") then return end

	local rig = ServerStorage:FindFirstChild(Config.Noob.RigName)
	if not rig then
		warn("[GameServer] В ServerStorage нет рига '" .. Config.Noob.RigName .. "'. Ноб не появится визуально.")
		return
	end

	local noob = rig:Clone()
	noob.Name = "Noob"

	-- ставим на площадку, лицом к игроку (+Z), поэтому поворот на 180°
	local pad = pd.pad
	local topY = pad.Position.Y + pad.Size.Y / 2
	local standPos = Vector3.new(pad.Position.X, topY + 3, pad.Position.Z)
	noob:PivotTo(CFrame.new(standPos) * CFrame.Angles(0, math.pi, 0))

	-- фиксируем, чтобы не падал/не уходил
	local hrp = noob:FindFirstChild("HumanoidRootPart") or noob:FindFirstChild("Torso")
	if hrp then hrp.Anchored = true end

	local ownerVal = Instance.new("ObjectValue")
	ownerVal.Name = "Owner"
	ownerVal.Value = player
	ownerVal.Parent = noob

	noob.Parent = pd.folder

	-- анимация
	local hum = noob:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- своё имя нарисуем сами
		local animator = hum:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = hum
		end
		local anim = Instance.new("Animation")
		anim.AnimationId = Config.Noob.AnimationId
		local ok, track = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if ok and track then
			track.Looped = true
			track:Play()
		end
	end
end

-- ── СИНХРОНИЗАЦИЯ КЛИЕНТУ ───────────────────────────────────────────────
local function snapshot(profile)
	-- чистая копия профиля без служебных полей
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

-- ── ВХОД ИГРОКА ──────────────────────────────────────────────────────────
local function onPlayerAdded(player)
	local profile = DataManager.load(player)
	local pd = buildPlot(player)

	-- если ноб уже куплен в прошлой сессии — сразу ставим его
	if profile.HasNoob then
		pd.prompt.Enabled = false
		spawnNoob(player)
	end

	-- кнопка: покупка ноба (только владелец плота)
	pd.prompt.Triggered:Connect(function(triggerPlayer)
		if triggerPlayer ~= player then return end
		local p = DataManager.get(player)
		if not p or p.HasNoob then return end
		if p.Oof >= Config.Noob.BuyCost then
			p.Oof -= Config.Noob.BuyCost
			p.HasNoob = true
			pd.prompt.Enabled = false
			spawnNoob(player)
			sync(player)
		end
	end)

	-- телепорт на свой плот при каждом респавне
	local function onCharacter(char)
		local hrpPart = char:WaitForChild("HumanoidRootPart", 10)
		if hrpPart and plotData[player] then
			char:PivotTo(plotData[player].spawnCFrame)
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then onCharacter(player.Character) end

	-- ДОХОД ОТ НОБА: отдельный цикл на игрока
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

	-- ГЕМЫ: пассивный доход по таймеру
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

-- ── ВЫХОД ИГРОКА ─────────────────────────────────────────────────────────
local function onPlayerRemoving(player)
	DataManager.release(player)
	local pd = plotData[player]
	if pd then
		usedIndices[pd.index] = nil
		if pd.folder then pd.folder:Destroy() end
		plotData[player] = nil
	end
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
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player) -- на случай горячей перезагрузки скрипта
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

-- сохранение при закрытии сервера
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		DataManager.save(player)
	end
	task.wait(2)
end)

print("[GameServer] запущен ✔")
