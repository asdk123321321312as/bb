--=============================================================
--   ScriptSleep   |   blade ball   |   bypass build
--   autoparry: keypress(0x46)
--   v11: тайминг по tti, плавное меню, korblox r6/r15, headless
--=============================================================

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local Lighting          = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local Stats             = game:GetService("Stats")
local HttpService       = game:GetService("HttpService")
local CoreGui           = game:GetService("CoreGui")

local cloneref = cloneref or function(o) return o end

local LP     = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local TITLE  = "ScriptSleep"

local CONFIG_VER = 11
local CONFIG_FILE = "ScriptSleep_BladeBall.json"

--=============================================================
-- CONFIG
--=============================================================
local Config = {
	-- combat
	AutoParry     = true,
	InputMode     = "Auto",
	ParryKey      = "F",
	BatchMode     = "Extremely Fast",
	ActionsPerSec = 60,
	MinRepressGap = 0.04,
	ExtraPresses  = 0,
	SmartTap      = true,
	OneParry      = false,
	OneParryKey   = "H",

	-- timing / radius
	AutoRadius    = true,
	LeadTime      = 0.10,
	MinRadius     = 8,
	MaxRadius     = 34,
	BaseRadius    = 16,
	PingComp      = true,
	BallPredCap   = 10,

	-- gates
	RevLock       = 0.12,
	RequireTarget = false,
	UnstableVel   = 22,
	UnstableTP    = 6,

	-- ring
	Ring          = true,
	RingColor     = "White",

	-- visuals
	EspBox        = true,
	EspName       = true,
	EspDist       = true,
	EspHealth     = true,
	EspBall       = true,
	EspHighlight  = true,
	Fullbright    = false,
	FOV           = 70,
	SkyParticles  = false,
	ParticleRate  = 60,

	-- body
	Korblox       = false,
	KorbloxMesh   = 139607718,
	KorbloxSide   = "Right",
	KorbloxColor  = "Black",
	KorbloxMethod = "Auto",
	Headless      = false,

	-- abilities
	AutoAbility   = false,
	AbilityRate   = 1.0,
	Reaction      = true,
	SpeedBoost    = false,
	WalkSpeed     = 36,
	JumpPower     = 50,

	-- misc
	HUD           = true,
	MenuKey       = "RightShift",
	MenuOffsetY   = 82,
}

local KEY_DEFAULT = {}
for k, v in pairs(Config) do KEY_DEFAULT[k] = v end

local KORBLOX_COLORS = {
	Black     = Color3.fromRGB(17, 17, 17),
	Dark      = Color3.fromRGB(35, 32, 40),
	Gray      = Color3.fromRGB(90, 90, 95),
	BoneWhite = Color3.fromRGB(235, 232, 228),
	Teal      = Color3.fromRGB(40, 120, 120),
}

--=============================================================
-- SAVE / LOAD
--=============================================================
local hasFS = pcall(function() return writefile end)

local function saveConfig()
	if not hasFS then return end
	local out = {}
	for k, v in pairs(Config) do
		if type(v) ~= "table" and type(v) ~= "userdata" then out[k] = v end
	end
	out.__ver = CONFIG_VER
	pcall(writefile, CONFIG_FILE, HttpService:JSONEncode(out))
end

local function loadConfig()
	if not hasFS then return end
	local ok, data = pcall(readfile, CONFIG_FILE)
	if not ok or not data then return end
	local ok2, dec = pcall(HttpService.JSONDecode, HttpService, data)
	if not ok2 or type(dec) ~= "table" then return end
	for k, v in pairs(dec) do
		if Config[k] ~= nil and type(v) == type(Config[k]) then Config[k] = v end
	end
	if dec.__ver ~= CONFIG_VER then
		Config.RevLock       = 0.12
		Config.MinRepressGap = 0.04
		Config.ExtraPresses  = 0
		Config.MaxRadius     = 34
		Config.LeadTime      = 0.10
		Config.SmartTap      = true
		Config.AutoRadius    = true
		Config.KorbloxMethod = "Auto"
	end
end
loadConfig()

--=============================================================
-- UI THEME + HELPERS
--=============================================================
local T = {
	Bg      = Color3.fromRGB(9, 9, 11),
	Panel   = Color3.fromRGB(15, 15, 18),
	Item    = Color3.fromRGB(20, 20, 24),
	Line    = Color3.fromRGB(38, 38, 45),
	Text    = Color3.fromRGB(238, 238, 242),
	Dim     = Color3.fromRGB(135, 135, 145),
	Accent  = Color3.fromRGB(255, 255, 255),
	AccentD = Color3.fromRGB(70, 70, 78),
	Good    = Color3.fromRGB(120, 255, 160),
	Bad     = Color3.fromRGB(255, 110, 110),
}

local function new(class, props, parent)
	local inst = Instance.new(class)
	if props then for k, v in next, props do inst[k] = v end end
	if parent then inst.Parent = parent end
	return inst
end

local function corner(inst, r)
	new("UICorner", { CornerRadius = UDim.new(0, r or 6) }, inst)
	return inst
end

local function stroke(inst, col, th)
	new("UIStroke", { Color = col or T.Line, Thickness = th or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, inst)
	return inst
end

local function getParentGui()
	if gethui then
		local ok, h = pcall(gethui)
		if ok and h then return h end
	end
	return CoreGui
end

local gui = new("ScreenGui", {
	Name = "ScriptSleep",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
gui.Parent = getParentGui()

local espFolder = new("Folder", { Name = "ESP" }, gui)

local W, H = 580, 400

-- CanvasGroup: даёт плавное появление/затухание всего меню разом
local main = new("CanvasGroup", {
	Name = "Main",
	Size = UDim2.new(0, W, 0, H),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, Config.MenuOffsetY or 82),
	BackgroundColor3 = T.Bg,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	GroupTransparency = 0,
}, gui)
corner(main, 10)
stroke(main, T.Line, 1)

local MENU_OPEN = true

local function setMenu(open)
	MENU_OPEN = open
	if open then
		main.Visible = true
		main.GroupTransparency = 1
		main.Size = UDim2.new(0, W * 0.88, 0, H * 0.88)
		TweenService:Create(main, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, W, 0, H),
			GroupTransparency = 0,
		}):Play()
	else
		local tw = TweenService:Create(main, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(0, W * 0.9, 0, H * 0.9),
			GroupTransparency = 1,
		})
		tw:Play()
		tw.Completed:Connect(function()
			if not MENU_OPEN then main.Visible = false end
		end)
	end
end

-- плавный драг
local dragTarget = nil
do
	local dragging, startPos, startMouse = false, nil, nil
	local dragBar = new("Frame", {
		Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Active = true,
	}, main)
	dragBar.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			startMouse = i.Position
			startPos = dragTarget or main.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - startMouse
			dragTarget = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
end

local sidebar = new("Frame", {
	Size = UDim2.new(0, 152, 1, 0),
	BackgroundColor3 = T.Panel,
	BorderSizePixel = 0,
}, main)

new("TextLabel", {
	Size = UDim2.new(1, -20, 0, 40),
	Position = UDim2.new(0, 14, 0, 6),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 15,
	TextColor3 = T.Text,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = TITLE,
}, sidebar)

local tabList = new("Frame", {
	Size = UDim2.new(1, -16, 1, -60),
	Position = UDim2.new(0, 8, 0, 52),
	BackgroundTransparency = 1,
}, sidebar)
new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, tabList)

local content = new("Frame", {
	Size = UDim2.new(1, -152, 1, 0),
	Position = UDim2.new(0, 152, 0, 0),
	BackgroundColor3 = T.Bg,
	BorderSizePixel = 0,
}, main)

local LO = 0
local function nextOrder() LO += 1; return LO end

local pages, tabBtns = {}, {}

local function makePage()
	local page = new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = T.Line,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, content)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14),
	}, page)
	new("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }, page)
	return page
end

local function selectTab(name)
	for n, p in pairs(pages) do
		p.Visible = (n == name)
		if n == name then
			p.Position = UDim2.new(0, 14, 0, 0)
			TweenService:Create(p, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(0, 0, 0, 0),
			}):Play()
		end
	end
	for n, b in pairs(tabBtns) do
		TweenService:Create(b.btn, TweenInfo.new(0.14), { TextColor3 = (n == name) and T.Text or T.Dim }):Play()
		TweenService:Create(b.ind, TweenInfo.new(0.14), {
			Size = (n == name) and UDim2.new(0, 2, 0, 16) or UDim2.new(0, 2, 0, 0),
		}):Play()
	end
end

local function addTab(name)
	local btn = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = T.Item,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = T.Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "   " .. name,
		AutoButtonColor = false,
		LayoutOrder = nextOrder(),
	}, tabList)
	local ind = new("Frame", {
		Size = UDim2.new(0, 2, 0, 0),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = T.Accent,
		BorderSizePixel = 0,
	}, btn)
	local page = makePage()
	pages[name] = page
	tabBtns[name] = { btn = btn, ind = ind }
	btn.MouseButton1Click:Connect(function() selectTab(name) end)
	return page
end

-- widgets
local function section(page, text)
	local holder = new("Frame", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, LayoutOrder = nextOrder() }, page)
	new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = T.Dim,
		TextXAlignment = Enum.TextXAlignment.Left, Text = string.upper(text),
	}, holder)
	new("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = T.Line, BorderSizePixel = 0 }, holder)
	return holder
end

local refreshers = {}

local function toggle(page, text, key, onChange)
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = T.Item, LayoutOrder = nextOrder() }, page)
	corner(row, 6)
	new("TextLabel", {
		Size = UDim2.new(1, -70, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1,
		Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left, Text = text,
	}, row)
	local sw = new("Frame", { Size = UDim2.new(0, 36, 0, 18), Position = UDim2.new(1, -46, 0.5, -9), BackgroundColor3 = T.Line, BorderSizePixel = 0 }, row)
	corner(sw, 9)
	local knob = new("Frame", { Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(0, 2, 0.5, -7), BackgroundColor3 = T.Dim, BorderSizePixel = 0 }, sw)
	corner(knob, 7)
	local function refresh()
		local on = Config[key] and true or false
		TweenService:Create(knob, TweenInfo.new(0.14), {
			Position = on and UDim2.new(0, 20, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
			BackgroundColor3 = on and T.Accent or T.Dim,
		}):Play()
		TweenService:Create(sw, TweenInfo.new(0.14), { BackgroundColor3 = on and T.AccentD or T.Line }):Play()
	end
	local btn = new("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "" }, row)
	btn.MouseButton1Click:Connect(function()
		Config[key] = not Config[key]
		refresh(); saveConfig()
		if onChange then pcall(onChange, Config[key]) end
	end)
	refresh()
	table.insert(refreshers, refresh)
	return refresh
end

local function slider(page, text, key, min, max, stepv, suffix, onChange)
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = T.Item, LayoutOrder = nextOrder() }, page)
	corner(row, 6)
	new("TextLabel", {
		Size = UDim2.new(1, -100, 0, 16), Position = UDim2.new(0, 10, 0, 4), BackgroundTransparency = 1,
		Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left, Text = text,
	}, row)
	local val = new("TextLabel", {
		Size = UDim2.new(0, 88, 0, 16), Position = UDim2.new(1, -98, 0, 4), BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = T.Accent,
		TextXAlignment = Enum.TextXAlignment.Right, Text = "",
	}, row)
	local track = new("Frame", { Size = UDim2.new(1, -20, 0, 4), Position = UDim2.new(0, 10, 0, 28), BackgroundColor3 = T.Line, BorderSizePixel = 0 }, row)
	corner(track, 2)
	local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = T.Accent, BorderSizePixel = 0 }, track)
	corner(fill, 2)
	local btn = new("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "" }, row)

	local function refresh()
		local a = math.clamp((Config[key] - min) / math.max(max - min, 1e-6), 0, 1)
		fill.Size = UDim2.new(a, 0, 1, 0)
		val.Text = tostring(Config[key]) .. (suffix or "")
	end
	local dragging = false
	local function set(x)
		local a = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		local v = min + (max - min) * a
		v = math.floor(v / stepv + 0.5) * stepv
		Config[key] = math.clamp(v, min, max)
		refresh()
		if onChange then pcall(onChange, Config[key]) end
	end
	btn.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true; set(i.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then set(i.Position.X) end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) and dragging then
			dragging = false; saveConfig()
		end
	end)
	refresh()
	table.insert(refreshers, refresh)
	return refresh
end

local function dropdown(page, text, key, options, onChange)
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = T.Item, LayoutOrder = nextOrder() }, page)
	corner(row, 6)
	new("TextLabel", {
		Size = UDim2.new(1, -120, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1,
		Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left, Text = text,
	}, row)
	local val = new("TextLabel", {
		Size = UDim2.new(0, 105, 1, 0), Position = UDim2.new(1, -115, 0, 0), BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = T.Accent,
		TextXAlignment = Enum.TextXAlignment.Right, Text = "",
	}, row)
	local btn = new("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "" }, row)
	local function refresh() val.Text = tostring(Config[key]) end
	btn.MouseButton1Click:Connect(function()
		local i = table.find(options, Config[key]) or 0
		Config[key] = options[(i % #options) + 1]
		refresh(); saveConfig()
		if onChange then pcall(onChange, Config[key]) end
	end)
	refresh()
	table.insert(refreshers, refresh)
	return refresh
end

local function keybind(page, text, key, onChange)
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = T.Item, LayoutOrder = nextOrder() }, page)
	corner(row, 6)
	new("TextLabel", {
		Size = UDim2.new(1, -120, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1,
		Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left, Text = text,
	}, row)
	local val = new("TextLabel", {
		Size = UDim2.new(0, 105, 1, 0), Position = UDim2.new(1, -115, 0, 0), BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = T.Accent,
		TextXAlignment = Enum.TextXAlignment.Right, Text = "",
	}, row)
	local btn = new("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "" }, row)
	local listening = false
	local function refresh() val.Text = listening and "..." or tostring(Config[key]) end
	btn.MouseButton1Click:Connect(function() listening = true; refresh() end)
	UserInputService.InputBegan:Connect(function(i, gp)
		if listening and i.UserInputType == Enum.UserInputType.Keyboard then
			Config[key] = i.KeyCode.Name
			listening = false; refresh(); saveConfig()
			if onChange then pcall(onChange, Config[key]) end
		end
	end)
	refresh()
	table.insert(refreshers, refresh)
	return refresh
end

local function button(page, text, cb)
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = T.Item, LayoutOrder = nextOrder() }, page)
	corner(row, 6)
	local btn = new("TextButton", {
		Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = T.Text, Text = text, AutoButtonColor = false,
	}, row)
	btn.MouseEnter:Connect(function() TweenService:Create(btn, TweenInfo.new(0.12), { TextColor3 = T.Accent }):Play() end)
	btn.MouseLeave:Connect(function() TweenService:Create(btn, TweenInfo.new(0.12), { TextColor3 = T.Text }):Play() end)
	btn.MouseButton1Click:Connect(function() pcall(cb) end)
	return btn
end

local function label(page, text, col)
	local l = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1,
		Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = col or T.Dim,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
		Text = text, LayoutOrder = nextOrder(),
	}, page)
	return l
end

--=============================================================
-- PAGES
--=============================================================
local pCombat = addTab("Combat")
section(pCombat, "autoparry")
toggle(pCombat, "Auto Parry", "AutoParry")
keybind(pCombat, "Parry Key", "ParryKey")
dropdown(pCombat, "Input Mode", "InputMode", { "Auto", "Keypress", "Mouse", "Remote" })
toggle(pCombat, "One Parry Per Ball", "OneParry")
keybind(pCombat, "One Parry Key", "OneParryKey")
toggle(pCombat, "Ping Compensation", "PingComp")
toggle(pCombat, "Require Target", "RequireTarget")
toggle(pCombat, "Ring", "Ring")
dropdown(pCombat, "Ring Color", "RingColor", { "White", "Green", "Red", "Cyan", "Yellow" })

section(pCombat, "тайминг (время до контакта)")
slider(pCombat, "Lead Time", "LeadTime", 0.04, 0.30, 0.005, "s")
toggle(pCombat, "Auto Radius", "AutoRadius")
slider(pCombat, "Min Radius", "MinRadius", 4, 25, 1, "")
slider(pCombat, "Max Radius", "MaxRadius", 10, 60, 1, "")

section(pCombat, "rate")
dropdown(pCombat, "Batch Mode", "BatchMode", { "Safe", "Normal", "Fast", "Extremely Fast" })
slider(pCombat, "Actions / sec", "ActionsPerSec", 10, 120, 5, "")
slider(pCombat, "Extra Presses", "ExtraPresses", 0, 3, 1, "")
slider(pCombat, "Min Repress Gap", "MinRepressGap", 0.02, 0.30, 0.01, "s")
slider(pCombat, "Rev Lock (анти-чужое отбитие)", "RevLock", 0.04, 0.30, 0.01, "s")

local pVisuals = addTab("Visuals")
section(pVisuals, "esp")
toggle(pVisuals, "Box ESP", "EspBox")
toggle(pVisuals, "Names", "EspName")
toggle(pVisuals, "Distance", "EspDist")
toggle(pVisuals, "Health Bar", "EspHealth")
toggle(pVisuals, "Ball ESP", "EspBall")
toggle(pVisuals, "Highlight", "EspHighlight")
section(pVisuals, "world")
toggle(pVisuals, "Fullbright", "Fullbright")
slider(pVisuals, "Field of View", "FOV", 50, 120, 1, "")
toggle(pVisuals, "Sky Particles", "SkyParticles")
slider(pVisuals, "Particle Rate", "ParticleRate", 10, 200, 5, "")

local pBody = addTab("Body")
section(pBody, "korblox leg")
toggle(pBody, "Enable Korblox", "Korblox", function() pcall(applyKorblox, true) end)
dropdown(pBody, "Side", "KorbloxSide", { "Right", "Left" }, function() pcall(applyKorblox, true) end)
dropdown(pBody, "Preset", "KorbloxMesh", { 139607718, 169177037, 12318225123, 12199981077, 135080259 }, function() pcall(applyKorblox, true) end)
dropdown(pBody, "Color", "KorbloxColor", { "Black", "Dark", "Gray", "BoneWhite", "Teal" }, function() pcall(applyKorblox, true) end)
dropdown(pBody, "Method", "KorbloxMethod", { "Auto", "Mesh", "Description" }, function() pcall(applyKorblox, true) end)
button(pBody, "Apply now", function() applyKorblox(true) end)
button(pBody, "Reset Korblox", function()
	Config.KorbloxMesh = 139607718
	Config.KorbloxColor = "Black"
	Config.KorbloxSide = "Right"
	Config.KorbloxMethod = "Auto"
	for _, r in ipairs(refreshers) do pcall(r) end
	saveConfig()
	applyKorblox(true)
end)
section(pBody, "headless")
toggle(pBody, "Headless", "Headless", function(v) pcall(applyHeadless, v) end)
label(pBody, "Headless прячет голову и головные аксессуары. Korblox: если не появился — нажми Apply now, метод Auto пробует оба способа.")

local pAbil = addTab("Abilities")
section(pAbil, "ability")
toggle(pAbil, "Auto Ability", "AutoAbility")
slider(pAbil, "Ability Rate", "AbilityRate", 0.2, 5, 0.1, "s")
toggle(pAbil, "Reaction (рывок мяча)", "Reaction")
section(pAbil, "movement")
toggle(pAbil, "Speed Boost", "SpeedBoost")
slider(pAbil, "Walk Speed", "WalkSpeed", 16, 120, 1, "")
slider(pAbil, "Jump Power", "JumpPower", 50, 200, 5, "")

local pMisc = addTab("Misc")
section(pMisc, "interface")
toggle(pMisc, "HUD", "HUD")
keybind(pMisc, "Menu Key", "MenuKey")
slider(pMisc, "Menu Offset Y", "MenuOffsetY", 0, 300, 2, "px", function(v)
	main.Position = UDim2.new(0.5, 0, 0.5, v)
	dragTarget = main.Position
end)
button(pMisc, "Reset all settings", function()
	for k, v in pairs(KEY_DEFAULT) do Config[k] = v end
	for _, r in ipairs(refreshers) do pcall(r) end
	saveConfig()
	main.Position = UDim2.new(0.5, 0, 0.5, Config.MenuOffsetY)
	dragTarget = main.Position
end)
button(pMisc, "Unload", function() gui:Destroy() end)
label(pMisc, "H — вкл/выкл One Parry Per Ball прямо в игре.")

selectTab("Combat")

-- кнопка-шарик для открытия меню
local orb = new("TextButton", {
	Size = UDim2.new(0, 34, 0, 34),
	Position = UDim2.new(0, 12, 0, 132),
	BackgroundColor3 = T.Bg,
	Text = "V",
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = T.Text,
	AutoButtonColor = false,
}, gui)
corner(orb, 17)
stroke(orb, T.Line, 1)
orb.MouseButton1Click:Connect(function() setMenu(not MENU_OPEN) end)

--=============================================================
-- REMOTE + INPUT
--=============================================================
local ParryRemote, AbilityRemote
local function findRemotes()
	ParryRemote, AbilityRemote = nil, nil
	for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
		if d:IsA("RemoteEvent") then
			local n = d.Name:lower()
			if not ParryRemote and n == "parry" then ParryRemote = d end
			if not AbilityRemote and n:find("ability") then AbilityRemote = d end
		end
	end
	if not ParryRemote then
		for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
			if d:IsA("RemoteEvent") and d.Name:lower():find("parry") then ParryRemote = d; break end
		end
	end
end
findRemotes()

local hasKeypress = pcall(function() return keypress end)
local hasMouse    = pcall(function() return mouse1click end)

local KeyCodes = {
	A=0x41,B=0x42,C=0x43,D=0x44,E=0x45,F=0x46,G=0x47,H=0x48,I=0x49,J=0x4A,K=0x4B,L=0x4C,M=0x4D,
	N=0x4E,O=0x4F,P=0x50,Q=0x51,R=0x52,S=0x53,T=0x54,U=0x55,V=0x56,W=0x57,X=0x58,Y=0x59,Z=0x5A,
	["0"]=0x30,["1"]=0x31,["2"]=0x32,["3"]=0x33,["4"]=0x34,["5"]=0x35,["6"]=0x36,["7"]=0x37,["8"]=0x38,["9"]=0x39,
	Space=0x20, Shift=0x10, LeftShift=0x10, RightShift=0x10, Control=0x11, LeftControl=0x11, RightControl=0x11,
	Alt=0x12, LeftAlt=0x12, RightAlt=0x12, Tab=0x09, CapsLock=0x14, Return=0x0D, Escape=0x1B,
	F1=0x70,F2=0x71,F3=0x72,F4=0x73,F5=0x74,F6=0x75,F7=0x76,F8=0x77,F9=0x78,F10=0x79,F11=0x7A,F12=0x7B,
}

--=============================================================
-- PARRY ENGINE
--=============================================================
local E = {
	lastAction = 0, actions = 0,
	lastTime = 0, lastVel = Vector3.zero,
	dist = 0, speed = 0, eta = 0, radius = 0, tti = 0,
	targeted = false, mode = "-", hot = false,
	pressBall = nil, pressCount = 0, pressAt = 0,
	ballLeft = true, emergency = false, closeNow = false,
	leftSeen = nil, revAt = -99, prevVel = nil,
	unstable = false, tpUntil = 0, lastRootPos = nil,
	boosted = false, boostAt = 0,
}

local function performParry()
	local key = KeyCodes[Config.ParryKey] or 0x46

	if Config.InputMode == "Remote" then
		if ParryRemote then pcall(function() ParryRemote:FireServer() end) end
		return "remote"
	end
	if Config.InputMode == "Mouse" then
		if hasMouse then pcall(mouse1click) end
		return "mouse"
	end
	if Config.InputMode == "Keypress" then
		if hasKeypress then
			pcall(function() keypress(key) end)
			task.delay(0.008, function() pcall(function() keyrelease(key) end) end)
		end
		return "key"
	end

	if hasKeypress then
		pcall(function() keypress(key) end)
		task.delay(0.008, function() pcall(function() keyrelease(key) end) end)
		return "key"
	elseif hasMouse then
		pcall(mouse1click)
		return "mouse"
	elseif ParryRemote then
		pcall(function() ParryRemote:FireServer() end)
		return "remote"
	end
	return "none"
end

local function actionCooldown()
	local rate = math.clamp(Config.ActionsPerSec, 10, 120)
	local cd = 1 / rate
	if Config.BatchMode == "Safe" then cd = math.max(0.060, cd)
	elseif Config.BatchMode == "Normal" then cd = math.max(0.032, cd)
	elseif Config.BatchMode == "Fast" then cd = math.max(0.018, cd)
	else cd = math.max(0.010, cd) end
	if E.boosted then cd = cd * 0.6 end
	if E.unstable then cd = cd * 0.8 end
	return math.max(0.008, cd + (math.random(-1, 2) / 1000))
end

local function extraLimit()
	if Config.OneParry then return 0 end
	return math.clamp(Config.ExtraPresses, 0, 5)
end

local function canPress(ball, now)
	if now - E.lastAction < actionCooldown() then return false end
	if not Config.SmartTap then return true end

	if ball ~= E.pressBall then
		E.pressBall = ball; E.pressCount = 0; E.ballLeft = true; E.emergency = false; E.leftSeen = nil
		E.prevVel = nil
	end

	local gap = math.clamp(Config.MinRepressGap, 0.02, 0.5)
	if E.unstable then gap = math.max(gap, 0.09) end
	if now - (E.pressAt or 0) < gap then return false end

	-- близкий бой: мяч вплотную И летит на нас
	if E.closeNow and (now - (E.pressAt or 0) > 0.06) then return true end

	if not E.ballLeft and E.pressCount > extraLimit() and not E.emergency then return false end
	return true
end

local function sendAction(ball)
	local now = tick()
	if not canPress(ball, now) then return false end
	if Config.SmartTap then
		E.pressCount += 1
		E.pressAt = now
		if E.pressCount > extraLimit() then E.ballLeft = false end
	end
	E.lastAction = now
	E.actions += 1
	E.mode = performParry()
	return true
end

-- перевзвод: только когда мяч РЕАЛЬНО ушёл и снова летит на нас
local function updateArm(ball, threat, radius)
	local now = tick()
	if ball ~= E.pressBall then
		E.pressBall = ball; E.pressCount = 0; E.ballLeft = true; E.emergency = false; E.leftSeen = nil
		E.revAt = -99
		return
	end

	local receding = (threat.approachSpeed < -1.5) or (threat.distance > radius * 1.35)
	if receding then E.leftSeen = now end

	if E.leftSeen and (now - E.leftSeen) > 0.06 and threat.approachSpeed > 0.5 and threat.dot > 0.25 then
		E.pressCount = 0; E.ballLeft = true; E.leftSeen = nil
	end

	if (now - (E.pressAt or 0) > 0.35) and threat.distance <= radius * 1.2 then
		E.pressCount = 0; E.ballLeft = true
	end

	E.emergency = (threat.distance < radius * 0.55) and (threat.approachSpeed > 0.5) and (now - (E.pressAt or 0) > 0.10)
	E.closeNow  = (threat.distance < radius * 0.60) and (threat.approachSpeed > 0.8) and (threat.dot > 0.20) and (now - (E.pressAt or 0) > 0.06)
end

--=============================================================
-- MATCH / BALL / THREAT
--=============================================================
local function inMatch()
	local char = LP.Character
	if not char then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false end
	local alive = Workspace:FindFirstChild("Alive")
	if alive then return char:IsDescendantOf(alive) end
	return true
end

local function getBall()
	local folder = Workspace:FindFirstChild("Balls")
	if not folder then return nil end
	local char = LP.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local best, bd
	for _, v in ipairs(folder:GetChildren()) do
		if v:IsA("BasePart") then
			local d = (v.Position - root.Position).Magnitude
			if d < (bd or math.huge) then best, bd = v, d end
		end
	end
	return best
end

local function ballTarget(ball)
	return ball:GetAttribute("target") or ball:GetAttribute("Target")
		or ball:GetAttribute("currentTarget") or ball:GetAttribute("targetPlayer")
		or ball:GetAttribute("to")
end

local function isTargeted(ball)
	local char = LP.Character
	if not ball or not char then return false end
	local t = ballTarget(ball)
	if t ~= nil then
		if t == LP.Name or t == LP.DisplayName or t == char.Name
			or t == LP.UserId or t == tostring(LP.UserId)
			or t == LP or t == char or t == true or t == "Training" then
			return true
		end
	end
	for _, ch in ipairs(ball:GetChildren()) do
		if ch:IsA("ValueBase") and ch.Name:lower():find("target") then
			local v = ch.Value
			if v == LP.Name or v == char.Name or v == LP or v == LP.UserId then return true end
		end
	end
	local hl = char:FindFirstChild("Highlight")
	if hl and hl:IsA("Highlight") and hl.FillColor.R > 0.6 and hl.FillColor.G < 0.5 then return true end
	return false
end

local function computeThreat(ball, root)
	local ballPos = ball.Position
	local playerPos = root.Position
	local distance = (playerPos - ballPos).Magnitude

	local velocity = ball.AssemblyLinearVelocity
	local zoomies = ball:FindFirstChild("zoomies")
	if zoomies then
		if zoomies:IsA("LinearVelocity") or zoomies:IsA("VectorForce") then
			velocity = zoomies.VectorVelocity
		elseif zoomies:IsA("BodyVelocity") then
			velocity = zoomies.Velocity
		end
	end
	local speed = velocity.Magnitude
	if speed <= 0 then
		velocity = ball.Velocity
		speed = velocity.Magnitude
	end
	if speed <= 0.5 then return nil end

	local now = tick()
	local dt = math.clamp(now - E.lastTime, 0.001, 0.05)
	E.lastTime = now
	local accel = (velocity - E.lastVel) / dt
	E.lastVel = velocity

	local dirToPlayer = (playerPos - ballPos).Unit
	local dot = dirToPlayer:Dot(velocity.Unit)
	local rootVel = root.AssemblyLinearVelocity or Vector3.zero
	local approachSpeed = (velocity - rootVel):Dot(dirToPlayer)
	local ballClosing = velocity:Dot(dirToPlayer)

	if Config.Reaction and accel.Magnitude > 400 then
		E.boosted = true; E.boostAt = now
	end
	if E.boosted and now - (E.boostAt or 0) > 0.7 then E.boosted = false end

	return {
		ball = ball, distance = distance, speed = speed, velocity = velocity,
		accel = accel, dot = dot, approachSpeed = approachSpeed, ballClosing = ballClosing,
		eta = distance / math.max(approachSpeed, speed * 0.7, 1),
	}
end

-- лид = сколько секунд до контакта должен остаться в момент нажатия
local function computeLead(pingSec)
	local net = pingSec * 0.5 + (1 / 60)
	local lead = Config.LeadTime + (Config.PingComp and net or 0)
	if E.boosted then lead = lead * 1.3 end
	if E.unstable then lead = lead * 1.15 end
	return lead
end

--=============================================================
-- RING
--=============================================================
local RingColors = {
	White  = Color3.fromRGB(255, 255, 255),
	Green  = Color3.fromRGB(120, 255, 160),
	Red    = Color3.fromRGB(255, 100, 100),
	Cyan   = Color3.fromRGB(120, 230, 255),
	Yellow = Color3.fromRGB(255, 220, 120),
}

local ring = new("CylinderHandleAdornment", {
	Height = 0.05, Radius = 16, InnerRadius = 15.6,
	Color3 = RingColors[Config.RingColor] or RingColors.White,
	Transparency = 0.45, AlwaysOnTop = true, ZIndex = 5,
	CFrame = CFrame.Angles(math.rad(90), 0, 0), Visible = false,
}, gui)

--=============================================================
-- STEP (ядро)
--=============================================================
local function getPing()
	local ok, v = pcall(function()
		return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
	end)
	if ok and v then return v end
	return 60
end

local function step(dt)
	if not Config.AutoParry or not inMatch() then return end
	local char = LP.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local ball = getBall()
	if not ball then return end

	local now = tick()

	-- нестабильное движение (рывок/прыжок/телепорт)
	local rootPos = root.Position
	local rootVel = root.AssemblyLinearVelocity
	local moved = (rootPos - (E.lastRootPos or rootPos)).Magnitude
	E.lastRootPos = rootPos
	if moved > Config.UnstableTP then E.tpUntil = now + 0.30 end
	E.unstable = (rootVel.Magnitude > Config.UnstableVel) or ((E.tpUntil or 0) > now)

	local threat = computeThreat(ball, root)
	if not threat then return end

	E.dist, E.speed, E.eta = threat.distance, threat.speed, threat.eta

	local pingSec = getPing() / 1000
	local dtStep = math.clamp(dt or 0.016, 0.001, 0.033)
	local lead = computeLead(pingSec)

	local radius
	if Config.AutoRadius then
		radius = math.clamp(threat.speed * lead, Config.MinRadius, Config.MaxRadius)
	else
		radius = Config.BaseRadius + (Config.PingComp and math.clamp(threat.speed * (pingSec * 0.5 + 1 / 60), 0, Config.BallPredCap) or 0)
	end
	E.radius = radius
	E.hot = threat.distance <= radius

	local tgt = isTargeted(ball)
	local heur = threat.dot > 0.4 and threat.approachSpeed > 0
	E.targeted = (tgt == true) or (tgt == nil and heur)

	if Config.RequireTarget then
		if tgt == false then return end
		if tgt == nil and not heur then return end
	end

	--=========================================================
	-- ТРИГГЕР ПО ВРЕМЕНИ ДО КОНТАКТА (устойчив к пропуску кадров)
	--=========================================================

	-- ловим резкий разворот мяча (другой игрок отбил / перенацел)
	if E.prevVel and E.prevVel.Magnitude > 1 and threat.velocity.Magnitude > 1 then
		if E.prevVel.Unit:Dot(threat.velocity.Unit) < 0.35 then
			E.revAt = now
		end
	end
	E.prevVel = threat.velocity

	local revLock = (now - (E.revAt or -99)) < math.clamp(Config.RevLock or 0.12, 0.04, 0.30)
	local strictClose = (threat.approachSpeed > 1.0) and (threat.dot > 0.35)

	local baseDirOk
	if E.unstable then
		baseDirOk = (threat.approachSpeed > -2) and (threat.dot > -0.05 or threat.distance <= radius * 0.6)
	else
		baseDirOk = (threat.dot > 0.12) and (threat.approachSpeed > 0.5)
	end

	local tgtBlock = revLock and (tgt == false) and not (threat.approachSpeed > 2 and threat.dot > 0.5)
	local dirOk = baseDirOk and (not tgtBlock)

	local closing = math.max(threat.approachSpeed, threat.ballClosing * 0.5, 0.5)
	if revLock then closing = math.max(threat.approachSpeed, 0.5) end

	local tti = threat.distance / math.max(closing, 0.5)
	E.tti = tti

	updateArm(ball, threat, radius)

	local fire = (tti <= lead) or (threat.distance <= radius * 0.9)
	if fire then fire = fire and dirOk end
	if revLock then fire = fire and strictClose end

	if fire then
		sendAction(ball)
		return
	end

	-- подстраховка: предсказанный контакт внутри круга
	if dirOk and (not revLock or strictClose) then
		local futurePlayer = rootPos + rootVel * lead
		local curveComp = 0.5 * threat.accel * (lead * lead)
		if curveComp.Magnitude > 15 then curveComp = curveComp.Unit * 15 end
		local futureBall = ball.Position + threat.velocity * lead + curveComp
		if (futurePlayer - futureBall).Magnitude <= radius * 0.75 then
			sendAction(ball)
		end
	end
end

--=============================================================
-- ESP
--=============================================================
local espCache = {}

local function project(v)
	local sp = Camera:WorldToViewportPoint(v)
	if sp.Z <= 0 then return nil end
	return Vector2.new(sp.X, sp.Y)
end

local function makeEsp()
	local o = {}
	o.box = new("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ZIndex = 2 }, espFolder)
	o.stroke = new("UIStroke", { Color = T.Accent, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o.box)
	o.name = new("TextLabel", {
		Size = UDim2.new(0, 200, 0, 13), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = T.Text, TextStrokeTransparency = 0.5,
	}, espFolder)
	o.dist = new("TextLabel", {
		Size = UDim2.new(0, 200, 0, 12), BackgroundTransparency = 1,
		Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = T.Dim, TextStrokeTransparency = 0.6,
	}, espFolder)
	o.hp = new("Frame", { Size = UDim2.new(0, 3, 0, 10), BackgroundColor3 = T.Good, BorderSizePixel = 0, Visible = false }, espFolder)
	o.hl = nil
	return o
end

local function updateEsp()
	local players = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl ~= LP then
			local char = pl.Character
			if char then
				local hum = char:FindFirstChildOfClass("Humanoid")
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hum and hrp and hum.Health > 0 then players[pl] = char end
			end
		end
	end

	for pl, char in pairs(players) do
		local o = espCache[pl]
		if not o then o = makeEsp(); espCache[pl] = o end

		if Config.EspHighlight then
			if not o.hl or o.hl.Parent ~= char then
				if o.hl then o.hl:Destroy() end
				o.hl = new("Highlight", { FillTransparency = 0.75, OutlineTransparency = 0.3, FillColor = T.Accent, OutlineColor = T.Accent }, char)
			end
		elseif o.hl then o.hl:Destroy(); o.hl = nil end

		local cf, size = char:GetBoundingBox()
		local center = cf.Position
		local up, right = Camera.CFrame.UpVector, Camera.CFrame.RightVector
		local top = project(center + up * (size.Y / 2))
		local bottom = project(center - up * (size.Y / 2))
		local left = project(center - right * (size.X / 2))
		local rgt = project(center + right * (size.X / 2))

		if top and bottom and left and rgt and Config.EspBox then
			local w = math.abs(rgt.X - left.X)
			local h = math.abs(bottom.Y - top.Y)
			o.box.Visible = true
			o.box.Size = UDim2.new(0, w, 0, h)
			o.box.Position = UDim2.new(0, math.min(left.X, rgt.X), 0, math.min(top.Y, bottom.Y))
			o.stroke.Color = T.Accent
		else
			o.box.Visible = false
		end

		if Config.EspName then
			o.name.Visible = true
			o.name.Text = pl.Name
			o.name.Position = UDim2.new(0, (left and rgt) and math.min(left.X, rgt.X) + (math.abs(rgt.X - left.X) / 2) - 100 or 0, 0, (top and top.Y or 0) - 16)
		else
			o.name.Visible = false
		end

		local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
		if Config.EspDist and root then
			o.dist.Visible = true
			o.dist.Text = string.format("%d studs", math.floor((char.HumanoidRootPart.Position - root.Position).Magnitude))
			o.dist.Position = UDim2.new(0, (left and rgt) and math.min(left.X, rgt.X) + (math.abs(rgt.X - left.X) / 2) - 100 or 0, 0, (bottom and bottom.Y or 0) + 2)
		else
			o.dist.Visible = false
		end

		if Config.EspHealth and top and left then
			local hum = char:FindFirstChildOfClass("Humanoid")
			o.hp.Visible = true
			o.hp.Position = UDim2.new(0, math.min(left.X, rgt.X) - 6, 0, math.min(top.Y, bottom.Y))
			o.hp.Size = UDim2.new(0, 3, 0, math.abs(bottom.Y - top.Y))
			o.hp.BackgroundColor3 = Color3.fromRGB(120, 255, 160):Lerp(Color3.fromRGB(255, 90, 90), 1 - (hum.Health / math.max(hum.MaxHealth, 1)))
		else
			o.hp.Visible = false
		end
	end

	for pl, o in pairs(espCache) do
		if not players[pl] then
			for _, f in pairs(o) do pcall(function() f:Destroy() end) end
			espCache[pl] = nil
		end
	end

	-- ball esp
	local ball = getBall()
	if ball and Config.EspBall then
		local sp = project(ball.Position)
		if sp then
			if not espCache.__ball then espCache.__ball = makeEsp() end
			local o = espCache.__ball
			o.box.Visible = true
			o.box.Size = UDim2.new(0, 26, 0, 26)
			o.box.Position = UDim2.new(0, sp.X - 13, 0, sp.Y - 13)
			o.stroke.Color = Color3.fromRGB(255, 90, 90)
			o.name.Visible = false; o.dist.Visible = false; o.hp.Visible = false
		end
	elseif espCache.__ball then
		espCache.__ball.box.Visible = false
	end
end

--=============================================================
-- BODY: KORBLOX + HEADLESS
--=============================================================
local korbloxBusy = false

local function legPartNames(side)
	if side == "Right" then
		return { "RightUpperLeg", "RightLowerLeg", "RightFoot", "Right Leg" }
	end
	return { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "Left Leg" }
end

local function lowerLegName(side)
	return (side == "Right") and "RightLowerLeg" or "LeftLowerLeg"
end

local function dressLeg(part, withMesh)
	if not part or not part.Parent then return end
	local col = KORBLOX_COLORS[Config.KorbloxColor] or KORBLOX_COLORS.Black
	pcall(function() part.Color = col end)
	if not withMesh then return end
	local id = "rbxassetid://" .. tostring(Config.KorbloxMesh)
	if part:IsA("MeshPart") then
		if part.MeshId ~= id then pcall(function() part.MeshId = id end) end
		pcall(function() if part.TextureID ~= "" then part.TextureID = "" end end)
	else
		local m = part:FindFirstChild("ScriptSleepKorblox")
		if not m then m = new("SpecialMesh", { Name = "ScriptSleepKorblox" }, part) end
		if m.MeshId ~= id then pcall(function() m.MeshId = id end) end
	end
end

function applyKorblox(full)
	if not Config.Korblox or korbloxBusy then return end
	local char = LP.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	korbloxBusy = true

	local side = Config.KorbloxSide
	local r15  = (hum.RigType == Enum.HumanoidRigType.R15)
	local method = Config.KorbloxMethod or "Auto"

	-- 1) описание (правильные пропорции ноги). Только полное применение.
	local descDone = false
	if full and (method == "Auto" or method == "Description") then
		local ok, desc = pcall(function() return hum:GetAppliedDescription() end)
		if ok and desc then
			pcall(function()
				if side == "Right" then desc.RightLeg = tonumber(Config.KorbloxMesh)
				else desc.LeftLeg = tonumber(Config.KorbloxMesh) end
				hum:ApplyDescription(desc)
			end)
			descDone = true
			task.wait(0.08)
		end
	end

	local wantId = tostring(Config.KorbloxMesh)
	local useMesh = (method == "Mesh") or (not descDone)

	-- 2) прямой меш + покраска
	if r15 then
		-- в R15 меш ставим на голень, остальное только красим
		for _, n in ipairs(legPartNames(side)) do
			local p = char:FindFirstChild(n)
			if p then dressLeg(p, useMesh and (n == lowerLegName(side))) end
		end
		if not char:FindFirstChild(lowerLegName(side)) then
			-- кастомные имена частей
			local want = (side == "Right") and "right" or "left"
			for _, d in ipairs(char:GetDescendants()) do
				local nm = d.Name:lower()
				if d:IsA("BasePart") and nm:find(want, 1, true) and nm:find("leg", 1, true) then
					dressLeg(d, useMesh)
				end
			end
		end
	else
		-- R6: одна часть ноги
		local p = char:FindFirstChild((side == "Right") and "Right Leg" or "Left Leg")
		if p then
			dressLeg(p, true)
		else
			for _, d in ipairs(char:GetDescendants()) do
				local nm = d.Name:lower()
				if d:IsA("BasePart") and nm:find((side == "Right") and "right" or "left", 1, true) and nm:find("leg", 1, true) then
					dressLeg(d, true)
				end
			end
		end
	end

	local acc = char:FindFirstChild("KorbloxLeg") or new("Folder", { Name = "KorbloxLeg" }, char)
	acc:SetAttribute("mesh", wantId)
	korbloxBusy = false
end

function applyHeadless(on)
	local char = LP.Character
	if not char then return end
	local t = on and 1 or 0
	local head = char:FindFirstChild("Head")
	if head then
		pcall(function() head.Transparency = t end)
		for _, d in ipairs(head:GetChildren()) do
			if d:IsA("Decal") then pcall(function() d.Transparency = t end) end
		end
	end
	for _, a in ipairs(char:GetChildren()) do
		local isHeadAcc = a:IsA("Hat")
			or (a:IsA("Accessory") and (a.AccessoryType == Enum.AccessoryType.Hat or a.AccessoryType == Enum.AccessoryType.Hair))
		if isHeadAcc then
			local h = a:FindFirstChild("Handle")
			if h then pcall(function() h.Transparency = t end) end
		end
	end
end

--=============================================================
-- SKY PARTICLES
--=============================================================
local skyPart = new("Part", {
	Name = "ScriptSleepSky",
	Size = Vector3.new(1, 1, 1),
	Transparency = 1,
	Anchored = true,
	CanCollide = false,
	CanQuery = false,
	CastShadow = false,
	Parent = Workspace,
})
local skyEmitter = new("ParticleEmitter", {
	Texture = "rbxasset://textures/particles/sparkles_main.dds",
	Rate = 0,
	Lifetime = NumberRange.new(8, 14),
	Speed = NumberRange.new(2, 5),
	SpreadAngle = Vector2.new(180, 180),
	Size = NumberSequence.new(0.15),
	Transparency = NumberSequence.new(0.35),
	LightEmission = 0.6,
	Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
	Parent = skyPart,
})

--=============================================================
-- LOOPS
--=============================================================
local fpsAcc, fpsFrames = 0, 0

local hud = new("Frame", {
	Size = UDim2.new(0, 200, 0, 54),
	Position = UDim2.new(0, 12, 0, 58),
	BackgroundColor3 = T.Bg,
	BackgroundTransparency = 0.25,
	BorderSizePixel = 0,
}, gui)
corner(hud, 8)
stroke(hud, T.Line, 1)
new("TextLabel", {
	Size = UDim2.new(1, -14, 0, 16), Position = UDim2.new(0, 8, 0, 4), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = T.Text,
	TextXAlignment = Enum.TextXAlignment.Left, Text = TITLE,
}, hud)
local hudInfo = new("TextLabel", {
	Size = UDim2.new(1, -14, 0, 28), Position = UDim2.new(0, 8, 0, 21), BackgroundTransparency = 1,
	Font = Enum.Font.Code, TextSize = 10, TextColor3 = T.Dim,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
	Text = "", TextWrapped = true,
}, hud)

RunService.RenderStepped:Connect(function(dt)
	fpsAcc += dt; fpsFrames += 1
	pcall(step, dt)

	-- плавный догон меню за курсором
	if dragTarget then
		main.Position = main.Position:Lerp(dragTarget, 0.30)
	end

	-- ring
	local char = LP.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and Config.Ring and E.radius > 0 then
		ring.Adornee = root
		ring.Radius = E.radius
		ring.InnerRadius = math.max(0.1, E.radius - 0.4)
		ring.Color3 = E.hot and Color3.fromRGB(120, 255, 160) or (RingColors[Config.RingColor] or RingColors.White)
		ring.Visible = true
	else
		ring.Visible = false
	end

	-- sky particles
	if Config.SkyParticles then
		skyPart.CFrame = CFrame.new(Camera.CFrame.Position)
		skyEmitter.Rate = Config.ParticleRate
	else
		skyEmitter.Rate = 0
	end

	-- fov
	pcall(function() Camera.FieldOfView = Config.FOV end)

	-- fullbright
	pcall(function()
		if Config.Fullbright then
			Lighting.Brightness = 3
			Lighting.ClockTime = 14
			Lighting.FogEnd = 100000
			Lighting.Ambient = Color3.fromRGB(140, 140, 140)
		end
	end)

	-- движение
	if Config.SpeedBoost and root then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			pcall(function() hum.WalkSpeed = Config.WalkSpeed end)
			pcall(function() hum.JumpPower = Config.JumpPower; hum.UseJumpPower = true end)
		end
	end
end)

-- HUD + ESP + ability
task.spawn(function()
	local lastAbility = 0
	while true do
		task.wait(0.1)
		pcall(function()
			if Config.HUD then
				hud.Visible = true
				if fpsAcc >= 0.5 then
					hudInfo.Text = string.format("fps %d | ping %d | dist %d | spd %d\nr %d | tti %.2f | %s%s",
						math.floor(fpsFrames / fpsAcc), math.floor(getPing()),
						math.floor(E.dist), math.floor(E.speed), math.floor(E.radius or 0),
						E.tti or 0, tostring(E.mode), Config.AutoParry and "on" or "off",
						Config.OneParry and " | one" or "")
					fpsAcc, fpsFrames = 0, 0
				end
			else
				hud.Visible = false
			end

			if tick() - lastAbility > Config.AbilityRate and Config.AutoAbility and AbilityRemote then
				lastAbility = tick()
				pcall(function() AbilityRemote:FireServer() end)
			end

			updateEsp()
		end)
	end
end)

-- body watcher: korblox + headless (без спама ApplyDescription)
task.spawn(function()
	local lastChar
	while true do
		task.wait(0.4)
		local char = LP.Character
		if char and char ~= lastChar then
			lastChar = char
			if Config.Korblox then pcall(applyKorblox, true) end
			if Config.Headless then pcall(applyHeadless, true) end
		elseif char then
			if Config.Korblox and not korbloxBusy then
				local side = Config.KorbloxSide
				local hum = char:FindFirstChildOfClass("Humanoid")
				local r15 = hum and hum.RigType == Enum.HumanoidRigType.R15
				if r15 then
					for _, n in ipairs(legPartNames(side)) do
						local p = char:FindFirstChild(n)
						if p then dressLeg(p, n == lowerLegName(side)) end
					end
				else
					dressLeg(char:FindFirstChild((side == "Right") and "Right Leg" or "Left Leg"), true)
				end
			end
			if Config.Headless then pcall(applyHeadless, true) end
		end
	end
end)

--=============================================================
-- KEYBINDS
--=============================================================
UserInputService.InputBegan:Connect(function(i, gp)
	if gp then return end
	local name = i.KeyCode and i.KeyCode.Name or ""
	if name == Config.OneParryKey then
		Config.OneParry = not Config.OneParry
		pcall(function()
			for _, r in ipairs(refreshers) do pcall(r) end
		end)
	end
	if name == Config.MenuKey then
		setMenu(not MENU_OPEN)
	end
end)

pcall(function()
	StarterGui = game:GetService("StarterGui")
	StarterGui:SetCore("SendNotification", { Title = TITLE, Text = "loaded | key " .. Config.MenuKey .. " = menu, " .. Config.OneParryKey .. " = one parry", Duration = 4 })
end)

saveConfig()
