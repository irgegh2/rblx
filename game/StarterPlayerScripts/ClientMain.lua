--[[
	╔══════════════════════════════════════════════════════════════╗
	║  ClientMain  —  ТИП: LocalScript                               ║
	║  ПОЛОЖИТЬ В:  StarterPlayer > StarterPlayerScripts > ClientMain║
	╚══════════════════════════════════════════════════════════════╝

	Весь интерфейс + локальная часть (рисуется у каждого игрока своё, поверх
	ОБЩЕЙ локации). Переносить нужно только этот один скрипт. Делает:
	  • HUD: верхняя панель прогресса, Oof справа, гемы и кнопки слева, тулбар;
	  • доску улучшений (SurfaceGui) на общей доске в мире;
	  • ЛОКАЛЬНОГО ноба (клон рига из ReplicatedStorage) на общей кнопке-площадке;
	  • табличку над нобом с кнопкой "Upgrade";
	  • стрелку-МАРШРУТ (Beam) от тела игрока к цели туториала;
	  • туториал из 2 шагов и всплывашки "+X".

	Экономика считается на сервере (см. GameServer) — тут только отображение.
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local Workspace         = game:GetService("Workspace")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared    = ReplicatedStorage:WaitForChild("Shared")
local Config    = require(Shared:WaitForChild("Config"))
local Formulas  = require(Shared:WaitForChild("Formulas"))
local Format    = require(Shared:WaitForChild("Format"))

local Remotes     = ReplicatedStorage:WaitForChild("Remotes")
local SyncData    = Remotes:WaitForChild("SyncData")
local Notify      = Remotes:WaitForChild("Notify")
local RequestData = Remotes:WaitForChild("RequestData")
local UpgradeNoob = Remotes:WaitForChild("UpgradeNoob")
local BuyUpgrade  = Remotes:WaitForChild("BuyUpgrade")

-- ── ПАЛИТРА ──────────────────────────────────────────────────────────────
local C = {
	panel   = Color3.fromRGB(18, 18, 34),
	panel2  = Color3.fromRGB(28, 28, 52),
	oof     = Color3.fromRGB(255, 201, 41),
	gems    = Color3.fromRGB(86, 196, 255),
	buy     = Color3.fromRGB(230, 51, 64),
	max     = Color3.fromRGB(170, 58, 222),
	upgrade = Color3.fromRGB(70, 200, 92),
	white   = Color3.fromRGB(255, 255, 255),
	dim     = Color3.fromRGB(170, 170, 190),
}

-- ── ХЕЛПЕРЫ UI ───────────────────────────────────────────────────────────
local function corner(gui, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = root
	return c
end

local function stroke(gui, color, t)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.new(0, 0, 0)
	s.Thickness = t or 2
	s.Parent = root
	return s
end

local function newText(props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextColor3 = C.white
	t.TextScaled = true
	for k, v in pairs(props) do t[k] = v end
	return t
end

-- ── СОСТОЯНИЕ ────────────────────────────────────────────────────────────
local state = { profile = nil }
local ref = {}
local boardRef = nil
local noobRef = nil
local gemTimer = Config.Gems.Interval

local worldFolder, worldButton, worldBoard
local localNoob = nil

-- стрелка-маршрут (Beam)
local arrowFrom, arrowTo, beam

local refresh -- предобъявление

-- ════════════════════════════════════════════════════════════════════════
--  HUD
-- ════════════════════════════════════════════════════════════════════════
local function buildHUD()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	-- контейнер со всем HUD (панели лежат в нём; масштаб задаём каждой панели ниже)
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.new(1, 0, 1, 0)
	root.BackgroundTransparency = 1
	root.Parent = gui

	-- ВЕРХНЯЯ ПАНЕЛЬ
	local top = Instance.new("Frame")
	top.Size = UDim2.new(0, 360, 0, 64)
	top.Position = UDim2.new(0.5, 0, 0, 10)
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.BackgroundColor3 = C.panel
	top.BackgroundTransparency = 0.1
	top.Parent = root
	corner(top, 14); stroke(top, Color3.fromRGB(0, 0, 0), 2)

	ref.topTitle = newText({ Size = UDim2.new(1, -20, 0, 26), Position = UDim2.new(0, 10, 0, 6),
		Text = "0/5T Oofs", TextColor3 = C.white })
	ref.topTitle.Parent = top

	ref.topSub = newText({ Size = UDim2.new(1, -20, 0, 14), Position = UDim2.new(0, 10, 0, 32),
		Text = "Progress for Prestige 1", TextColor3 = C.dim, Font = Enum.Font.Gotham })
	ref.topSub.Parent = top

	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(1, -20, 0, 8)
	barBg.Position = UDim2.new(0, 10, 1, -12)
	barBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	barBg.Parent = top
	corner(barBg, 4)

	ref.topBar = Instance.new("Frame")
	ref.topBar.Size = UDim2.new(0, 0, 1, 0)
	ref.topBar.BackgroundColor3 = C.oof
	ref.topBar.Parent = barBg
	corner(ref.topBar, 4)

	-- OOF (справа)
	local oof = Instance.new("Frame")
	oof.Size = UDim2.new(0, 230, 0, 60)
	oof.Position = UDim2.new(1, -20, 0, 20)
	oof.AnchorPoint = Vector2.new(1, 0)
	oof.BackgroundColor3 = C.panel
	oof.BackgroundTransparency = 0.1
	oof.Parent = root
	corner(oof, 14); stroke(oof, C.oof, 2)

	newText({ Size = UDim2.new(0, 50, 1, 0), Position = UDim2.new(0, 6, 0, 0),
		Text = "🙂", TextColor3 = C.oof, Parent = oof })

	ref.oofAmount = newText({ Size = UDim2.new(1, -64, 0, 34), Position = UDim2.new(0, 58, 0, 6),
		Text = "0", TextColor3 = C.oof, TextXAlignment = Enum.TextXAlignment.Left })
	ref.oofAmount.Parent = oof

	ref.oofRate = newText({ Size = UDim2.new(1, -64, 0, 16), Position = UDim2.new(0, 58, 0, 38),
		Text = "+0 / tick", TextColor3 = C.dim, Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left })
	ref.oofRate.Parent = oof

	-- ГЕМЫ (слева)
	local gems = Instance.new("Frame")
	gems.Size = UDim2.new(0, 210, 0, 56)
	gems.Position = UDim2.new(0, 20, 0.42, 0)
	gems.BackgroundColor3 = C.panel
	gems.BackgroundTransparency = 0.1
	gems.Parent = root
	corner(gems, 14); stroke(gems, C.gems, 2)

	newText({ Size = UDim2.new(0, 46, 1, 0), Position = UDim2.new(0, 6, 0, 0),
		Text = "💎", TextColor3 = C.gems, Parent = gems })

	ref.gemAmount = newText({ Size = UDim2.new(0, 110, 0, 30), Position = UDim2.new(0, 52, 0, 4),
		Text = "0", TextColor3 = C.white, TextXAlignment = Enum.TextXAlignment.Left })
	ref.gemAmount.Parent = gems

	ref.gemRate = newText({ Size = UDim2.new(0, 110, 0, 16), Position = UDim2.new(0, 52, 0, 34),
		Text = "+0 [0s]", TextColor3 = C.gems, Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left })
	ref.gemRate.Parent = gems

	local plus = Instance.new("TextButton")
	plus.Size = UDim2.new(0, 36, 0, 36)
	plus.Position = UDim2.new(1, -42, 0.5, 0)
	plus.AnchorPoint = Vector2.new(0, 0.5)
	plus.BackgroundColor3 = C.upgrade
	plus.Text = "+"
	plus.Font = Enum.Font.GothamBold
	plus.TextScaled = true
	plus.TextColor3 = C.white
	plus.Parent = gems
	corner(plus, 10)
	plus.Activated:Connect(function() RequestData:FireServer() end)

	-- БОКОВЫЕ КНОПКИ
	local side = Instance.new("Frame")
	side.Size = UDim2.new(0, 56, 0, 120)
	side.Position = UDim2.new(0, 20, 0.42, 70)
	side.BackgroundTransparency = 1
	side.Parent = root
	local sideLayout = Instance.new("UIListLayout")
	sideLayout.Padding = UDim.new(0, 8)
	sideLayout.Parent = side

	for _, info in ipairs({ { "⚙️", "Settings" }, { "🙂", "Oof" } }) do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, 52, 0, 52)
		b.BackgroundColor3 = C.panel
		b.BackgroundTransparency = 0.1
		b.Text = info[1]
		b.TextScaled = true
		b.Parent = side
		corner(b, 12); stroke(b, Color3.fromRGB(0, 0, 0), 2)
	end

	-- НИЖНИЙ ТУЛБАР
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 360, 0, 64)
	bar.Position = UDim2.new(0.5, 0, 1, -12)
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.BackgroundTransparency = 1
	bar.Parent = root
	local barLayout = Instance.new("UIListLayout")
	barLayout.FillDirection = Enum.FillDirection.Horizontal
	barLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	barLayout.Padding = UDim.new(0, 10)
	barLayout.Parent = bar

	for _, info in ipairs({
		{ "🛒", "Shop", Color3.fromRGB(230, 51, 64) },
		{ "💠", "Tree", Color3.fromRGB(86, 196, 255) },
		{ "🎒", "Inventory", Color3.fromRGB(170, 120, 70) },
		{ "📜", "Quests", Color3.fromRGB(210, 180, 90) },
	}) do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, 76, 0, 60)
		b.BackgroundColor3 = info[3]
		b.Text = info[1] .. "\n" .. info[2]
		b.Font = Enum.Font.GothamBold
		b.TextSize = 14
		b.TextColor3 = C.white
		b.Parent = bar
		corner(b, 12); stroke(b, Color3.fromRGB(0, 0, 0), 2)
	end

	-- ТУТОРИАЛ-КАРТОЧКА
	ref.tutorial = Instance.new("Frame")
	ref.tutorial.Size = UDim2.new(0, 380, 0, 70)
	ref.tutorial.Position = UDim2.new(0.5, 0, 1, -86)
	ref.tutorial.AnchorPoint = Vector2.new(0.5, 1)
	ref.tutorial.BackgroundColor3 = Color3.fromRGB(40, 36, 30)
	ref.tutorial.Parent = root
	corner(ref.tutorial, 12); stroke(ref.tutorial, Color3.fromRGB(80, 70, 50), 2)

	newText({ Size = UDim2.new(0, 56, 0, 56), Position = UDim2.new(0, 8, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5), Text = "🙂", TextColor3 = C.oof,
		Parent = ref.tutorial })

	ref.tutTitle = newText({ Size = UDim2.new(1, -80, 0, 24), Position = UDim2.new(0, 72, 0, 8),
		Text = "Get your Noob", TextXAlignment = Enum.TextXAlignment.Left })
	ref.tutTitle.Parent = ref.tutorial

	ref.tutDesc = newText({ Size = UDim2.new(1, -80, 0, 18), Position = UDim2.new(0, 72, 0, 32),
		Text = "Step on the button", TextColor3 = C.dim, Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left })
	ref.tutDesc.Parent = ref.tutorial

	local tutBarBg = Instance.new("Frame")
	tutBarBg.Size = UDim2.new(1, -80, 0, 8)
	tutBarBg.Position = UDim2.new(0, 72, 1, -12)
	tutBarBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	tutBarBg.Parent = ref.tutorial
	corner(tutBarBg, 4)

	ref.tutBar = Instance.new("Frame")
	ref.tutBar.Size = UDim2.new(0, 0, 1, 0)
	ref.tutBar.BackgroundColor3 = C.oof
	ref.tutBar.Parent = tutBarBg
	corner(ref.tutBar, 4)

	-- ОБЩИЙ МАСШТАБ: уменьшаем каждую панель вокруг её якоря
	-- (меньше число = мельче интерфейс; поставь 1 чтобы вернуть исходный размер)
	for _, panel in ipairs(root:GetChildren()) do
		if panel:IsA("GuiObject") then
			local s = Instance.new("UIScale")
			s.Scale = 0.7
			s.Parent = panel
		end
	end
end

-- ════════════════════════════════════════════════════════════════════════
--  ДОСКА УЛУЧШЕНИЙ (SurfaceGui — локально на общей доске)
-- ════════════════════════════════════════════════════════════════════════
local function buildBoard(boardPart)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "OofUpgradesGui"
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	sg.CanvasSize = Vector2.new(800, 440)
	sg.LightInfluence = 0
	sg.Adornee = boardPart
	sg.Parent = boardPart

	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = C.panel
	bg.Parent = sg

	newText({ Size = UDim2.new(1, 0, 0, 70), Position = UDim2.new(0, 0, 0, 6),
		Text = "Oof Upgrades", TextColor3 = C.oof, Parent = bg })

	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(1, -40, 1, -100)
	holder.Position = UDim2.new(0, 20, 0, 84)
	holder.BackgroundTransparency = 1
	holder.Parent = bg
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 24)
	layout.Parent = holder

	boardRef = {}

	for _, u in ipairs(Config.Upgrades) do
		local col = Instance.new("Frame")
		col.Size = UDim2.new(0, 340, 1, 0)
		col.BackgroundColor3 = C.panel2
		col.Parent = holder
		corner(col, 12)

		newText({ Size = UDim2.new(1, 0, 0, 44), Position = UDim2.new(0, 0, 0, 8),
			Text = u.DisplayName, Parent = col })

		local levelLabel = newText({ Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0, 52),
			Text = "0 / " .. u.MaxLevel, TextColor3 = C.gems, Parent = col })

		newText({ Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 0, 84),
			Text = u.Desc, TextColor3 = C.dim, Font = Enum.Font.Gotham, Parent = col })

		local costLabel = newText({ Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 1, -96),
			Text = "0 Oof", TextColor3 = C.oof, Parent = col })

		local buyBtn = Instance.new("TextButton")
		buyBtn.Size = UDim2.new(0.5, -14, 0, 50)
		buyBtn.Position = UDim2.new(0, 10, 1, -58)
		buyBtn.BackgroundColor3 = C.buy
		buyBtn.Text = "Buy"
		buyBtn.Font = Enum.Font.GothamBold
		buyBtn.TextScaled = true
		buyBtn.TextColor3 = C.white
		buyBtn.Parent = col
		corner(buyBtn, 10)
		buyBtn.Activated:Connect(function() BuyUpgrade:FireServer(u.Id, "buy") end)

		local maxBtn = Instance.new("TextButton")
		maxBtn.Size = UDim2.new(0.5, -14, 0, 50)
		maxBtn.Position = UDim2.new(0.5, 4, 1, -58)
		maxBtn.BackgroundColor3 = C.max
		maxBtn.Text = "Max"
		maxBtn.Font = Enum.Font.GothamBold
		maxBtn.TextScaled = true
		maxBtn.TextColor3 = C.white
		maxBtn.Parent = col
		corner(maxBtn, 10)
		maxBtn.Activated:Connect(function() BuyUpgrade:FireServer(u.Id, "max") end)

		boardRef[u.Id] = { level = levelLabel, cost = costLabel, buy = buyBtn, max = maxBtn, cfg = u }
	end
end

-- ════════════════════════════════════════════════════════════════════════
--  ТАБЛИЧКА НАД НОБОМ
-- ════════════════════════════════════════════════════════════════════════
local function decorateNoob(noob)
	local head = noob:FindFirstChild("Head") or noob:FindFirstChild("HumanoidRootPart")
	if not head then return end

	local bb = Instance.new("BillboardGui")
	bb.Name = "NoobUI"
	bb.Size = UDim2.new(0, 200, 0, 130)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = head
	bb.Parent = head

	newText({ Size = UDim2.new(1, 0, 0, 26), Text = Config.Noob.DisplayName, Parent = bb })

	local levelLabel = newText({ Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 0, 26),
		Text = "Level 1", TextColor3 = C.oof, Font = Enum.Font.Gotham, Parent = bb })

	local rateLabel = newText({ Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 0, 46),
		Text = "+0 Oof / tick", TextColor3 = C.dim, Font = Enum.Font.Gotham, Parent = bb })

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 44)
	btn.Position = UDim2.new(0, 0, 0, 70)
	btn.BackgroundColor3 = C.upgrade
	btn.Text = "Upgrade"
	btn.Font = Enum.Font.GothamBold
	btn.TextScaled = true
	btn.TextColor3 = C.white
	btn.Parent = bb
	corner(btn, 10); stroke(btn, Color3.fromRGB(0, 0, 0), 2)
	btn.Activated:Connect(function() UpgradeNoob:FireServer() end)

	noobRef = { level = levelLabel, rate = rateLabel, button = btn }
end

-- ════════════════════════════════════════════════════════════════════════
--  ЛОКАЛЬНЫЙ НОБ (клон рига из ReplicatedStorage, на общей кнопке-площадке)
-- ════════════════════════════════════════════════════════════════════════
local function spawnLocalNoob()
	if localNoob or not worldButton then return end

	local rig = ReplicatedStorage:FindFirstChild(Config.Noob.RigName)
	if not rig then
		warn("[ClientMain] В ReplicatedStorage нет рига '" .. Config.Noob.RigName .. "'. Ноб не появится.")
		return
	end

	local noob = rig:Clone()
	noob.Name = "LocalNoob_" .. player.UserId

	local topY = worldButton.Position.Y + worldButton.Size.Y / 2
	local pos = Vector3.new(worldButton.Position.X, topY + 3, worldButton.Position.Z)
	noob:PivotTo(CFrame.new(pos) * CFrame.Angles(0, math.pi, 0)) -- лицом к игроку

	-- фиксируем корень, остальное держится на Motor6D и анимируется
	local hrp = noob:FindFirstChild("HumanoidRootPart") or noob:FindFirstChild("Torso")
	if hrp then hrp.Anchored = true end
	for _, d in ipairs(noob:GetDescendants()) do
		if d:IsA("BasePart") then d.CanCollide = false end
	end

	noob.Parent = Workspace

	local hum = noob:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		local animator = hum:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = hum
		end
		local anim = Instance.new("Animation")
		anim.AnimationId = Config.Noob.AnimationId
		local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
		if ok and track then
			track.Looped = true
			track:Play()
		end
	end

	decorateNoob(noob)
	localNoob = noob
end

-- ════════════════════════════════════════════════════════════════════════
--  СТРЕЛКА-МАРШРУТ (Beam от игрока к цели)
-- ════════════════════════════════════════════════════════════════════════
local function ensureArrow()
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	if not arrowFrom or arrowFrom.Parent ~= hrp then
		arrowFrom = Instance.new("Attachment")
		arrowFrom.Name = "ArrowFrom"
		arrowFrom.Parent = hrp
		beam = nil -- старый beam умер вместе со старым телом
	end
	if not arrowTo then
		arrowTo = Instance.new("Attachment")
		arrowTo.Name = "ArrowTo"
	end
	if not beam or beam.Parent == nil then
		beam = Instance.new("Beam")
		beam.Name = "TutorialArrow"
		beam.Attachment0 = arrowFrom
		beam.Attachment1 = arrowTo
		beam.Width0 = 1.2
		beam.Width1 = 1.2
		beam.FaceCamera = true
		beam.LightInfluence = 0
		beam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
		beam.Segments = 12
		beam.CurveSize0 = 0
		beam.CurveSize1 = 0
		beam.TextureMode = Enum.TextureMode.Wrap
		beam.TextureLength = 3
		beam.TextureSpeed = 1.5
		if Config.ArrowImageId ~= "rbxassetid://0" and Config.ArrowImageId ~= "" then
			beam.Texture = Config.ArrowImageId
		end
		beam.Parent = hrp
	end
end

local function setArrowTarget(part, yOffset)
	ensureArrow()
	if not arrowTo then return end
	if part then
		arrowTo.Parent = part
		arrowTo.Position = Vector3.new(0, yOffset or 0, 0)
	end
	if beam then beam.Enabled = (part ~= nil) end
end

-- ════════════════════════════════════════════════════════════════════════
--  ОБНОВЛЕНИЕ ВСЕГО ПО ДАННЫМ
-- ════════════════════════════════════════════════════════════════════════
refresh = function()
	local p = state.profile
	if not p then return end

	-- если ноб куплен — спавним локального ноба (один раз)
	if p.HasNoob and not localNoob then
		spawnLocalNoob()
	end

	-- верхняя панель
	local req = Formulas.prestigeRequirement(p.Prestige)
	ref.topTitle.Text = Format.short(p.Oof) .. "/" .. Format.short(req) .. " Oofs"
	ref.topSub.Text = "Progress for Prestige " .. (p.Prestige + 1)
	ref.topBar.Size = UDim2.new(math.clamp(p.Oof / req, 0, 1), 0, 1, 0)

	-- валюты
	ref.oofAmount.Text = Format.short(p.Oof)
	ref.gemAmount.Text = Format.short(p.Gems)
	ref.oofRate.Text = p.HasNoob and ("+" .. Format.short(Formulas.noobReward(p)) .. " / tick") or "no noob yet"

	-- доска
	if boardRef then
		for id, b in pairs(boardRef) do
			local lvl = p.Upgrades[id] or 0
			b.level.Text = lvl .. " / " .. b.cfg.MaxLevel
			if lvl >= b.cfg.MaxLevel then
				b.cost.Text = "MAX"
				b.buy.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
				b.max.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
			else
				local cost = Formulas.upgradeCost(id, lvl)
				b.cost.Text = Format.short(cost) .. " Oof"
				b.buy.BackgroundColor3 = (p.Oof >= cost) and C.buy or Color3.fromRGB(120, 40, 45)
				b.max.BackgroundColor3 = C.max
			end
		end
	end

	-- табличка над нобом
	if noobRef then
		noobRef.level.Text = "Level " .. p.NoobLevel
		noobRef.rate.Text = "+" .. Format.short(Formulas.noobReward(p)) .. " Oof / tick"
		if p.NoobLevel >= Config.Noob.MaxLevel then
			noobRef.button.Text = "MAX LEVEL"
			noobRef.button.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
		else
			local cost = Formulas.noobUpgradeCost(p.NoobLevel)
			noobRef.button.Text = "Upgrade  " .. Format.short(cost) .. " Oof"
			noobRef.button.BackgroundColor3 = (p.Oof >= cost) and C.upgrade or Color3.fromRGB(40, 110, 55)
		end
	end

	-- ТУТОРИАЛ (2 шага) + стрелка-маршрут
	if not p.HasNoob then
		-- шаг 1: купить ноба -> стрелка к кнопке
		ref.tutTitle.Text = "Get your Noob"
		ref.tutDesc.Text = "Step on the button"
		ref.tutBar.Size = UDim2.new(0, 0, 1, 0)
		ref.tutorial.Visible = true
		setArrowTarget(worldButton, (worldButton and worldButton.Size.Y / 2 + 1) or 1)
	else
		local done = math.clamp(p.NoobLevel - 1, 0, 5)
		if done >= 5 then
			-- туториал пройден
			ref.tutorial.Visible = false
			setArrowTarget(nil)
		else
			-- шаг 2: прокачать ноба 5 раз -> стрелка к нобу
			ref.tutTitle.Text = "Upgrade your Noob"
			ref.tutDesc.Text = "Upgrade it 5 times  " .. done .. "/5"
			ref.tutBar.Size = UDim2.new(done / 5, 0, 1, 0)
			ref.tutorial.Visible = true
			local target = localNoob and (localNoob:FindFirstChild("HumanoidRootPart") or localNoob:FindFirstChild("Head"))
			setArrowTarget(target or worldButton, 0)
		end
	end
end

-- ════════════════════════════════════════════════════════════════════════
--  ВСПЛЫВАШКИ "+X"
-- ════════════════════════════════════════════════════════════════════════
local popupGui = Instance.new("ScreenGui")
popupGui.Name = "Popups"
popupGui.ResetOnSpawn = false
popupGui.Parent = playerGui

Notify.OnClientEvent:Connect(function(text, kind)
	local lbl = newText({
		Size = UDim2.new(0, 180, 0, 40),
		Position = UDim2.new(1, -120, 0, 90),
		AnchorPoint = Vector2.new(1, 0),
		Text = text,
		TextColor3 = (kind == "gems") and C.gems or C.oof,
	})
	stroke(lbl, Color3.fromRGB(0, 0, 0), 2)
	lbl.Parent = popupGui

	TweenService:Create(lbl, TweenInfo.new(1.2, Enum.EasingStyle.Quad),
		{ Position = lbl.Position - UDim2.new(0, 0, 0, 60), TextTransparency = 1 }):Play()
	task.delay(1.2, function() lbl:Destroy() end)
end)

-- ════════════════════════════════════════════════════════════════════════
--  СТАРТ
-- ════════════════════════════════════════════════════════════════════════
buildHUD()

task.spawn(function()
	worldFolder = Workspace:WaitForChild(Config.World.FolderName, 30)
	if not worldFolder then return end
	worldButton = worldFolder:WaitForChild("Button", 30)
	worldBoard  = worldFolder:WaitForChild("Board", 30)
	if worldBoard then buildBoard(worldBoard) end
	ensureArrow()
	refresh()
end)

SyncData.OnClientEvent:Connect(function(profile)
	state.profile = profile
	refresh()
end)

-- пересоздаём стрелку после респавна
player.CharacterAdded:Connect(function()
	task.wait(0.4)
	arrowFrom = nil
	beam = nil
	ensureArrow()
	refresh()
end)

-- таймер гемов (косметика "[Ns]")
RunService.Heartbeat:Connect(function(dt)
	gemTimer -= dt
	if gemTimer <= 0 then gemTimer = Config.Gems.Interval end
	if ref.gemRate then
		ref.gemRate.Text = "+" .. Format.short(Config.Gems.Amount) .. " [" .. math.ceil(gemTimer) .. "s]"
	end
end)

RequestData:FireServer()
print("[ClientMain] UI готов ✔")
