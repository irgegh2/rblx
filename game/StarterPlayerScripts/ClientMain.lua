--[[
	╔══════════════════════════════════════════════════════════════╗
	║  ClientMain  —  ТИП: LocalScript                               ║
	║  ПОЛОЖИТЬ В:  StarterPlayer > StarterPlayerScripts > ClientMain║
	╚══════════════════════════════════════════════════════════════╝

	Весь интерфейс. Строится кодом, поэтому переносить нужно только
	этот один скрипт. Делает:
	  • верхнюю панель (прогресс к престижу);
	  • счётчик Oof (справа) и гемов (слева) + боковые/нижние кнопки;
	  • доску улучшений (SurfaceGui) на твоей доске в мире;
	  • стрелку-подсказку над кнопкой (картинку вставишь в Config.ArrowImageId);
	  • табличку над нобом с кнопкой "Upgrade";
	  • туториал и всплывающие "+X".
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

-- ── МЕЛКИЕ ХЕЛПЕРЫ UI ────────────────────────────────────────────────────
local function corner(gui, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = gui
	return c
end

local function stroke(gui, color, t)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.new(0, 0, 0)
	s.Thickness = t or 2
	s.Parent = gui
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
local ref = {}            -- ссылки на элементы HUD для обновления
local boardRef = nil      -- ссылки на доску
local noobRef = nil       -- ссылки на табличку над нобом
local gemTimer = Config.Gems.Interval
local refresh             -- предобъявление (определяется ниже)

-- ════════════════════════════════════════════════════════════════════════
--  HUD (ScreenGui)
-- ════════════════════════════════════════════════════════════════════════
local function buildHUD()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	-- ВЕРХНЯЯ ПАНЕЛЬ: прогресс к престижу --------------------------------
	local top = Instance.new("Frame")
	top.Size = UDim2.new(0, 360, 0, 64)
	top.Position = UDim2.new(0.5, 0, 0, 10)
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.BackgroundColor3 = C.panel
	top.BackgroundTransparency = 0.1
	top.Parent = gui
	corner(top, 14); stroke(top, Color3.fromRGB(0, 0, 0), 2)

	ref.topTitle = newText({
		Size = UDim2.new(1, -20, 0, 26), Position = UDim2.new(0, 10, 0, 6),
		Text = "0/5T Oofs", TextColor3 = C.white,
	})
	ref.topTitle.Parent = top

	ref.topSub = newText({
		Size = UDim2.new(1, -20, 0, 14), Position = UDim2.new(0, 10, 0, 32),
		Text = "Progress for Prestige 1", TextColor3 = C.dim, Font = Enum.Font.Gotham,
	})
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

	-- СЧЁТЧИК OOF (справа) ----------------------------------------------
	local oof = Instance.new("Frame")
	oof.Size = UDim2.new(0, 230, 0, 60)
	oof.Position = UDim2.new(1, -20, 0, 20)
	oof.AnchorPoint = Vector2.new(1, 0)
	oof.BackgroundColor3 = C.panel
	oof.BackgroundTransparency = 0.1
	oof.Parent = gui
	corner(oof, 14); stroke(oof, C.oof, 2)

	-- иконка-смайлик (можешь заменить на ImageLabel со своей картинкой)
	newText({ Size = UDim2.new(0, 50, 1, 0), Position = UDim2.new(0, 6, 0, 0),
		Text = "🙂", TextColor3 = C.oof, Parent = oof })

	ref.oofAmount = newText({
		Size = UDim2.new(1, -64, 0, 34), Position = UDim2.new(0, 58, 0, 6),
		Text = "0", TextColor3 = C.oof, TextXAlignment = Enum.TextXAlignment.Left,
	})
	ref.oofAmount.Parent = oof

	ref.oofRate = newText({
		Size = UDim2.new(1, -64, 0, 16), Position = UDim2.new(0, 58, 0, 38),
		Text = "+0 / tick", TextColor3 = C.dim, Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	ref.oofRate.Parent = oof

	-- СЧЁТЧИК ГЕМОВ (слева) ---------------------------------------------
	local gems = Instance.new("Frame")
	gems.Size = UDim2.new(0, 210, 0, 56)
	gems.Position = UDim2.new(0, 20, 0.42, 0)
	gems.BackgroundColor3 = C.panel
	gems.BackgroundTransparency = 0.1
	gems.Parent = gui
	corner(gems, 14); stroke(gems, C.gems, 2)

	newText({ Size = UDim2.new(0, 46, 1, 0), Position = UDim2.new(0, 6, 0, 0),
		Text = "💎", TextColor3 = C.gems, Parent = gems })

	ref.gemAmount = newText({
		Size = UDim2.new(0, 110, 0, 30), Position = UDim2.new(0, 52, 0, 4),
		Text = "0", TextColor3 = C.white, TextXAlignment = Enum.TextXAlignment.Left,
	})
	ref.gemAmount.Parent = gems

	ref.gemRate = newText({
		Size = UDim2.new(0, 110, 0, 16), Position = UDim2.new(0, 52, 0, 34),
		Text = "+0 [0s]", TextColor3 = C.gems, Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
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
	plus.Activated:Connect(function()
		-- сюда позже повесишь магазин гемов; пока просто перезапросим данные
		RequestData:FireServer()
	end)

	-- БОКОВЫЕ КВАДРАТНЫЕ КНОПКИ (слева снизу) ---------------------------
	local side = Instance.new("Frame")
	side.Size = UDim2.new(0, 56, 0, 120)
	side.Position = UDim2.new(0, 20, 0.42, 70)
	side.BackgroundTransparency = 1
	side.Parent = gui
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

	-- НИЖНИЙ ТУЛБАР -----------------------------------------------------
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 360, 0, 64)
	bar.Position = UDim2.new(0.5, 0, 1, -12)
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.BackgroundTransparency = 1
	bar.Parent = gui
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

	-- ТУТОРИАЛ-КАРТОЧКА (снизу по центру, над тулбаром) -----------------
	ref.tutorial = Instance.new("Frame")
	ref.tutorial.Size = UDim2.new(0, 380, 0, 70)
	ref.tutorial.Position = UDim2.new(0.5, 0, 1, -86)
	ref.tutorial.AnchorPoint = Vector2.new(0.5, 1)
	ref.tutorial.BackgroundColor3 = Color3.fromRGB(40, 36, 30)
	ref.tutorial.Parent = gui
	corner(ref.tutorial, 12); stroke(ref.tutorial, Color3.fromRGB(80, 70, 50), 2)

	newText({ Size = UDim2.new(0, 56, 0, 56), Position = UDim2.new(0, 8, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5), Text = "🙂", TextColor3 = C.oof,
		Parent = ref.tutorial })

	ref.tutTitle = newText({
		Size = UDim2.new(1, -80, 0, 24), Position = UDim2.new(0, 72, 0, 8),
		Text = "Get your Noob", TextXAlignment = Enum.TextXAlignment.Left,
	})
	ref.tutTitle.Parent = ref.tutorial

	ref.tutDesc = newText({
		Size = UDim2.new(1, -80, 0, 18), Position = UDim2.new(0, 72, 0, 32),
		Text = "Press the button to spawn it", TextColor3 = C.dim,
		Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
	})
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
end

-- ════════════════════════════════════════════════════════════════════════
--  ДОСКА УЛУЧШЕНИЙ (SurfaceGui на твоей доске в мире)
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

		local levelLabel = newText({ Size = UDim2.new(1, 0, 0, 30),
			Position = UDim2.new(0, 0, 0, 52), Text = "0 / " .. u.MaxLevel,
			TextColor3 = C.gems, Parent = col })

		newText({ Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 0, 84),
			Text = u.Desc, TextColor3 = C.dim, Font = Enum.Font.Gotham, Parent = col })

		local costLabel = newText({ Size = UDim2.new(1, 0, 0, 34),
			Position = UDim2.new(0, 0, 1, -96), Text = "0 Oof",
			TextColor3 = C.oof, Parent = col })

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
--  СТРЕЛКА-ПОДСКАЗКА над кнопкой
-- ════════════════════════════════════════════════════════════════════════
local function buildArrow(buttonPart)
	local bb = Instance.new("BillboardGui")
	bb.Name = "ArrowHint"
	bb.Size = UDim2.new(0, 120, 0, 120)
	bb.StudsOffset = Vector3.new(0, 6, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = buttonPart
	bb.Parent = buttonPart

	local img = Instance.new("ImageLabel")
	img.Size = UDim2.new(1, 0, 1, 0)
	img.BackgroundTransparency = 1
	img.Image = Config.ArrowImageId -- сюда твоя картинка-стрелка
	img.Parent = bb

	-- если картинку ещё не вставил — покажем текстовую стрелку, чтобы было видно
	if Config.ArrowImageId == "rbxassetid://0" or Config.ArrowImageId == "" then
		img.Image = ""
		local t = newText({ Size = UDim2.new(1, 0, 1, 0), Text = "⬇️", Parent = img })
		t.TextColor3 = C.oof
	end

	-- лёгкая анимация "подпрыгивания" (один зацикленный твин)
	ref.arrow = bb
	TweenService:Create(bb, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ StudsOffset = Vector3.new(0, 7.5, 0) }):Play()
	return bb
end

-- ════════════════════════════════════════════════════════════════════════
--  ТАБЛИЧКА НАД НОБОМ + кнопка "Upgrade"
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

	local nameLabel = newText({ Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 0, 0),
		Text = Config.Noob.DisplayName, Parent = bb })

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

	noobRef = { name = nameLabel, level = levelLabel, rate = rateLabel, button = btn }
end

-- Ждём появления ноба на нашем плоту (он спавнится после покупки)
local function watchNoob(folder)
	local existing = folder:FindFirstChild("Noob")
	if existing then decorateNoob(existing) end
	folder.ChildAdded:Connect(function(child)
		if child.Name == "Noob" then
			task.wait(0.2) -- дать частям прогрузиться
			decorateNoob(child)
			refresh()
		end
	end)
end

-- ════════════════════════════════════════════════════════════════════════
--  ОБНОВЛЕНИЕ ВСЕГО ИНТЕРФЕЙСА ПО ДАННЫМ
-- ════════════════════════════════════════════════════════════════════════
refresh = function()
	local p = state.profile
	if not p then return end

	-- верхняя панель (престиж)
	local req = Formulas.prestigeRequirement(p.Prestige)
	ref.topTitle.Text = Format.short(p.Oof) .. "/" .. Format.short(req) .. " Oofs"
	ref.topSub.Text = "Progress for Prestige " .. (p.Prestige + 1)
	ref.topBar.Size = UDim2.new(math.clamp(p.Oof / req, 0, 1), 0, 1, 0)

	-- валюты
	ref.oofAmount.Text = Format.short(p.Oof)
	ref.gemAmount.Text = Format.short(p.Gems)
	if p.HasNoob then
		ref.oofRate.Text = "+" .. Format.short(Formulas.noobReward(p)) .. " / tick"
	else
		ref.oofRate.Text = "no noob yet"
	end

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

	-- стрелка-подсказка видна, пока нет ноба
	if ref.arrow then ref.arrow.Enabled = not p.HasNoob end

	-- туториал
	if not p.HasNoob then
		ref.tutTitle.Text = "Get your Noob"
		ref.tutDesc.Text = "Press the button to spawn it"
		ref.tutBar.Size = UDim2.new(0, 0, 1, 0)
		ref.tutorial.Visible = true
	else
		local done = math.clamp(p.NoobLevel - 1, 0, 5)
		if done >= 5 then
			ref.tutorial.Visible = false
		else
			ref.tutTitle.Text = "Upgrade " .. Config.Noob.DisplayName
			ref.tutDesc.Text = "Upgrade your noob 5 times  " .. done .. "/5"
			ref.tutBar.Size = UDim2.new(done / 5, 0, 1, 0)
			ref.tutorial.Visible = true
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
		Size = UDim2.new(0, 160, 0, 40),
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
--  ПОИСК СВОЕГО ПЛОТА И ЗАПУСК
-- ════════════════════════════════════════════════════════════════════════
local function findMyPlot()
	local plots = Workspace:WaitForChild("Plots")
	while true do
		for _, folder in ipairs(plots:GetChildren()) do
			local owner = folder:FindFirstChild("Owner")
			if owner and owner.Value == player then
				return folder
			end
		end
		task.wait(0.2)
	end
end

buildHUD()

task.spawn(function()
	local folder = findMyPlot()
	local board  = folder:WaitForChild("Board", 10)
	local button = folder:WaitForChild("Button", 10)
	if board then buildBoard(board) end
	if button then buildArrow(button) end
	watchNoob(folder)
	refresh()
end)

SyncData.OnClientEvent:Connect(function(profile)
	state.profile = profile
	refresh()
end)

-- локальный таймер гемов (косметика "[Ns]"): свободно крутится Interval -> 0 -> Interval
RunService.Heartbeat:Connect(function(dt)
	gemTimer -= dt
	if gemTimer <= 0 then
		gemTimer = Config.Gems.Interval
	end
	if ref.gemRate then
		ref.gemRate.Text = "+" .. Format.short(Config.Gems.Amount) .. " [" .. math.ceil(gemTimer) .. "s]"
	end
end)

RequestData:FireServer()
print("[ClientMain] UI готов ✔")
