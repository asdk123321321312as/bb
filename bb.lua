--[[
    𝒮𝒸𝓇𝒾𝓅𝓉𝒮𝓁𝑒𝑒𝑝  |  BLADE BALL  |  BAC-safe
    menu: RightShift
--]]

--=============================================================
-- SERVICES
--=============================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Lighting         = game:GetService("Lighting")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local Stats            = game:GetService("Stats")
local HttpService      = game:GetService("HttpService")
local VirtualUser      = game:GetService("VirtualUser")

local LP     = Players.LocalPlayer
local CAMERA = workspace.CurrentCamera

local TITLE = "𝒮𝒸𝓇𝒾𝓅𝓉𝒮𝓁𝑒𝑒𝑝"

--=============================================================
-- CONFIG
--=============================================================
local Config = {
	-- combat
	AutoParry     = true,
	ParryMode     = "Both",
	BypassMode    = "Safe",
	OnePerThrow   = true,
	ReactionJitter= 70,
	TriggerJitter = 5,
	Humanize      = true,
	SmartOffset   = true,
	BaseOffset    = 0.14,
	CloseRange    = 12,
	RateLimit     = true,
	GateDistance  = true,
	GateApproach  = true,
	GateSpeed     = true,
	AutoAbility   = false,
	AbilityDelay  = 1.2,
	SendBall      = false,
	DebugParry    = false,
	RemotePath    = "",

	-- visuals (всё клиентское, BAC не видит)
	BoxEsp        = true,
	EspColor      = Color3.fromRGB(255, 255, 255),
	EspFill       = false,
	EspFillAlpha  = 0.85,
	NameEsp       = true,
	DistEsp       = true,
	HealthEsp     = true,
	Tracers       = false,
	BallEsp       = true,
	BallEspColor  = Color3.fromRGB(255, 90, 90),
	Highlights    = true,
	Hitboxes      = false,

	-- реплицируемое (может триггерить BAC)
	Headless      = false,
	Fullbright    = false,
	Particles     = false,
	ParticleRate  = 40,
	ParticleColor = Color3.fromRGB(255, 255, 255),
	BallRecolor   = false,
	BallColor     = Color3.fromRGB(255, 255, 255),
	BallMaterial  = "Plastic",
	BallSize      = 1,

	-- world
	SkyPreset     = "Default",
	ClockTime     = 14,
	Brightness    = 2,
	FogEnd        = 100000,

	-- skins
	SwordMesh     = "",
	SwordTexture  = "",

	-- misc
	Fov           = 70,
	FpsBoost      = false,
	Hud           = true,
	AntiAfk       = true,
	UseSpeed      = false,
	WalkSpeed     = 16,
	JumpPower     = 50,
	MenuOpen      = true,
	MenuKey       = Enum.KeyCode.RightShift,
}

--=============================================================
-- BYPASS PROFILES  (cooldown = мин. пауза между выстрелами)
--=============================================================
local Bypass = {
	Off      = {cooldown = 0.05, offMin = 0.08, offMax = 0.09, maxDist = 250, maxRate = 30, onePerThrow = false},
	Light    = {cooldown = 0.20, offMin = 0.10, offMax = 0.16, maxDist = 80,  maxRate = 8,  onePerThrow = false},
	Medium   = {cooldown = 0.30, offMin = 0.12, offMax = 0.20, maxDist = 50,  maxRate = 6,  onePerThrow = true},
	Safe     = {cooldown = 0.40, offMin = 0.14, offMax = 0.24, maxDist = 35,  maxRate = 3,  onePerThrow = true},
	Paranoid = {cooldown = 0.55, offMin = 0.16, offMax = 0.30, maxDist = 28,  maxRate = 2,  onePerThrow = true},
}

local function profile() return Bypass[Config.BypassMode] or Bypass.Safe end

--=============================================================
-- SAVE / LOAD
--=============================================================
local FILE  = "ScriptSleep_BladeBall.json"
local hasFS = pcall(function() return writefile end)

local function ser(v)
	if typeof(v) == "Color3"  then return {__t = "c", r = v.R, g = v.G, b = v.B} end
	if typeof(v) == "EnumItem" then return {__t = "e", a = tostring(v.EnumType), b = v.Name} end
	if typeof(v) == "Vector3" then return {__t = "v", x = v.X, y = v.Y, z = v.Z} end
	return v
end

local function deser(v)
	if type(v) == "table" and v.__t then
		if v.__t == "c" then return Color3.new(v.r, v.g, v.b) end
		if v.__t == "v" then return Vector3.new(v.x, v.y, v.z) end
		if v.__t == "e" then
			local ok, e = pcall(function() return Enum[v.a][v.b] end)
			if ok then return e end
		end
	end
	return v
end

local function saveConfig()
	if not hasFS then return end
	local out = {}
	for k, v in pairs(Config) do out[k] = ser(v) end
	pcall(function() writefile(FILE, HttpService:JSONEncode(out)) end)
end

local function loadConfig()
	if not hasFS then return end
	local ok, data = pcall(readfile, FILE)
	if not ok or not data then return end
	local ok2, dec = pcall(function() return HttpService:JSONDecode(data) end)
	if not ok2 or type(dec) ~= "table" then return end
	for k, v in pairs(dec) do
		if Config[k] ~= nil then
			local val = deser(v)
			if val ~= nil then Config[k] = val end
		end
	end
end

local saveQueued = false
local function queueSave()
	if saveQueued then return end
	saveQueued = true
	task.delay(1, function() saveQueued = false; saveConfig() end)
end

loadConfig()

--=============================================================
-- THEME
--=============================================================
local T = {
	Bg     = Color3.fromRGB(9, 9, 11),
	Panel  = Color3.fromRGB(15, 15, 18),
	Item   = Color3.fromRGB(21, 21, 25),
	ItemHi = Color3.fromRGB(31, 31, 37),
	Line   = Color3.fromRGB(40, 40, 47),
	Text   = Color3.fromRGB(238, 238, 243),
	Dim    = Color3.fromRGB(140, 140, 150),
	Accent = Color3.fromRGB(255, 255, 255),
	Bad    = Color3.fromRGB(255, 105, 105),
	Good   = Color3.fromRGB(120, 255, 165),
	Warn   = Color3.fromRGB(255, 205, 90),
}

local gui

--=============================================================
-- HELPERS
--=============================================================
local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in next, props do inst[k] = v end
	if parent then inst.Parent = parent end
	return inst
end

local function corner(inst, r) new("UICorner", {CornerRadius = UDim.new(0, r or 8)}, inst) end
local function stroke(inst, col, th)
	new("UIStroke", {Color = col or T.Line, Thickness = th or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, inst)
end

local function getPing()
	local ok, v = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
	return ok and v or 0
end

local conns = {}
local function bind(sig, fn) table.insert(conns, sig:Connect(fn)) end

local function notify(text, col)
	if not gui then return end
	local box = new("Frame", {
		Size = UDim2.new(0, 260, 0, 32), Position = UDim2.new(1, -280, 0, 12),
		BackgroundColor3 = T.Bg, BackgroundTransparency = 0.1, BorderSizePixel = 0, ZIndex = 60,
	}, gui)
	corner(box, 8); stroke(box, col or T.Line)
	new("TextLabel", {
		Size = UDim2.new(1, -20, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = col or T.Text,
		TextXAlignment = Enum.TextXAlignment.Left, Text = text,
	}, box)
	task.delay(3, function()
		TweenService:Create(box, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
		task.wait(0.45)
		pcall(function() box:Destroy() end)
	end)
end

--=============================================================
-- GUI ROOT
--=============================================================
gui = new("ScreenGui", {
	Name = "ScriptSleep", ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	IgnoreGuiInset = true, DisplayOrder = 999,
})
pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end

local espFolder = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ZIndex = 1}, gui)

--=============================================================
-- WIDGETS
--=============================================================
local function section(parent, title)
	return new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = T.Accent,
		TextXAlignment = Enum.TextXAlignment.Left, Text = string.upper(title),
	}, parent)
end

local function toggle(parent, label, state, onChange)
	local row = new("Frame", {Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1}, parent)
	new("TextLabel", {
		Size = UDim2.new(1, -50, 1, 0), BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left, Text = label,
	}, row)
	local btn = new("TextButton", {
		Size = UDim2.new(0, 36, 0, 18), Position = UDim2.new(1, -36, 0.5, -9),
		BackgroundColor3 = T.Item, Text = "", AutoButtonColor = false,
	}, row)
	corner(btn, 9); stroke(btn, T.Line)
	local knob = new("Frame", {
		Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(0, 2, 0.5, -7),
		BackgroundColor3 = T.Dim, BorderSizePixel = 0,
	}, btn)
	corner(knob, 7)

	local on = state
	local function render()
		TweenService:Create(knob, TweenInfo.new(0.15), {
			Position = on and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
			BackgroundColor3 = on and T.Accent or T.Dim,
		}):Play()
		TweenService:Create(btn, TweenInfo.new(0.15), {
			BackgroundColor3 = on and Color3.fromRGB(45, 45, 52) or T.Item,
		}):Play()
	end
	render()
	btn.MouseButton1Click:Connect(function()
		on = not on; render()
		if onChange then onChange(on) end
		queueSave()
	end)
	return row, function(v) on = v; render() end
end

local function slider(parent, label, minV, maxV, default, decimals, onChange)
	local holder = new("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1}, parent)
	new("TextLabel", {
		Size = UDim2.new(1, -70, 0, 18), BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left, Text = label,
	}, holder)
	local valLbl = new("TextLabel", {
		Size = UDim2.new(0, 70, 0, 18), Position = UDim2.new(1, -70, 0, 0),
		BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13,
		TextColor3 = T.Dim, TextXAlignment = Enum.TextXAlignment.Right, Text = "",
	}, holder)
	local bar = new("Frame", {
		Size = UDim2.new(1, 0, 0, 6), Position = UDim2.new(0, 0, 0, 26),
		BackgroundColor3 = T.Item, BorderSizePixel = 0,
	}, holder)
	corner(bar, 3)
	local fill = new("Frame", {Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = T.Accent, BorderSizePixel = 0}, bar)
	corner(fill, 3)
	local knob = new("Frame", {
		Size = UDim2.new(0, 10, 0, 10), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = T.Accent, BorderSizePixel = 0,
	}, bar)
	corner(knob, 5)

	local function set(v, fire)
		v = math.clamp(v, minV, maxV)
		local a = (v - minV) / (maxV - minV)
		fill.Size = UDim2.new(a, 0, 1, 0)
		knob.Position = UDim2.new(a, 0, 0.5, 0)
		valLbl.Text = decimals > 0 and string.format("%." .. decimals .. "f", v) or tostring(math.floor(v))
		if fire and onChange then onChange(v) end
	end
	set(default, false)

	local dragging = false
	local function upd(i)
		local rel = (i.Position.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1)
		set(minV + (maxV - minV) * rel, true)
	end
	bar.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true; upd(i)
		end
	end)
	bind(UserInputService.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then upd(i) end
	end)
	bind(UserInputService.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false; queueSave()
		end
	end)
	return holder, set
end

local function dropdown(parent, label, options, default, onChange)
	local holder = new("Frame", {Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, ZIndex = 5, ClipsDescendants = false}, parent)
	new("TextLabel", {
		Size = UDim2.new(1, -140, 0, 30), BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left, Text = label,
	}, holder)
	local btn = new("TextButton", {
		Size = UDim2.new(0, 130, 0, 24), Position = UDim2.new(1, -130, 0, 3),
		BackgroundColor3 = T.Item, Text = "", AutoButtonColor = false, ZIndex = 6,
	}, holder)
	corner(btn, 6); stroke(btn, T.Line)
	local txt = new("TextLabel", {
		Size = UDim2.new(1, -24, 1, 0), Position = UDim2.new(0, 10, 0, 0),
		BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12,
		TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = tostring(default),
	}, btn)
	new("TextLabel", {
		Size = UDim2.new(0, 12, 0, 12), Position = UDim2.new(1, -16, 0.5, -6),
		BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 10,
		TextColor3 = T.Dim, Text = "v",
	}, btn)

	local listH = #options * 24 + 8
	local list = new("Frame", {
		Size = UDim2.new(0, 130, 0, listH), Position = UDim2.new(1, -130, 0, 32),
		BackgroundColor3 = T.Panel, Visible = false, ZIndex = 20, BorderSizePixel = 0,
	}, holder)
	corner(list, 6); stroke(list, T.Line)
	new("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, list)
	new("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4)}, list)

	local opened = false
	local function setOpen(v)
		opened = v
		list.Visible = v
		TweenService:Create(holder, TweenInfo.new(0.12), {
			Size = v and UDim2.new(1, 0, 0, 30 + listH + 6) or UDim2.new(1, 0, 0, 30),
		}):Play()
	end

	for i, opt in ipairs(options) do
		local b = new("TextButton", {
			Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = T.Dim,
			Text = tostring(opt), LayoutOrder = i, ZIndex = 21,
		}, list)
		b.MouseEnter:Connect(function() b.TextColor3 = T.Text end)
		b.MouseLeave:Connect(function() b.TextColor3 = T.Dim end)
		b.MouseButton1Click:Connect(function()
			txt.Text = tostring(opt)
			setOpen(false)
			if onChange then onChange(opt) end
			queueSave()
		end)
	end

	btn.MouseButton1Click:Connect(function() setOpen(not opened) end)
	return holder, function(v) txt.Text = tostring(v) end
end

local function textbox(parent, label, default, placeholder, onEnter)
	local holder = new("Frame", {Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1}, parent)
	new("TextLabel", {
		Size = UDim2.new(1, -160, 1, 0), BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left, Text = label,
	}, holder)
	local box = new("TextBox", {
		Size = UDim2.new(0, 150, 0, 24), Position = UDim2.new(1, -150, 0, 3),
		BackgroundColor3 = T.Item, Text = default or "", PlaceholderText = placeholder or "",
		Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = T.Text,
		PlaceholderColor3 = T.Dim, ClearTextOnFocus = false, BorderSizePixel = 0,
	}, holder)
	corner(box, 6); stroke(box, T.Line)
	box.FocusLost:Connect(function()
		if onEnter then onEnter(box.Text) end
		queueSave()
	end)
	return holder, box
end

local function button(parent, label, onClick)
	local b = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = T.Item,
		Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = T.Text,
		Text = label, AutoButtonColor = false, BorderSizePixel = 0,
	}, parent)
	corner(b, 6); stroke(b, T.Line)
	b.MouseEnter:Connect(function() TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = T.ItemHi}):Play() end)
	b.MouseLeave:Connect(function() TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = T.Item}):Play() end)
	b.MouseButton1Click:Connect(function() if onClick then onClick() end end)
	return b
end

--=============================================================
-- WINDOW
--=============================================================
local window = new("Frame", {
	Name = "Window", Size = UDim2.new(0, 660, 0, 450),
	Position = UDim2.new(0.5, -330, 0.5, -225),
	BackgroundColor3 = T.Bg, BorderSizePixel = 0, Visible = Config.MenuOpen,
}, gui)
corner(window, 12); stroke(window, T.Line, 1)

local topbar = new("Frame", {Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = T.Panel, BorderSizePixel = 0}, window)
corner(topbar, 12)
new("Frame", {Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 1, -12), BackgroundColor3 = T.Panel, BorderSizePixel = 0}, topbar)

new("TextLabel", {
	Size = UDim2.new(0, 420, 1, 0), Position = UDim2.new(0, 16, 0, 0), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = T.Text,
	TextXAlignment = Enum.TextXAlignment.Left, Text = TITLE,
}, topbar)

local closeBtn = new("TextButton", {
	Size = UDim2.new(0, 22, 0, 22), Position = UDim2.new(1, -32, 0, 8),
	BackgroundColor3 = T.Item, Text = "x", Font = Enum.Font.GothamBold, TextSize = 13,
	TextColor3 = T.Dim, AutoButtonColor = false, BorderSizePixel = 0,
}, topbar)
corner(closeBtn, 6)
local minBtn = new("TextButton", {
	Size = UDim2.new(0, 22, 0, 22), Position = UDim2.new(1, -60, 0, 8),
	BackgroundColor3 = T.Item, Text = "-", Font = Enum.Font.GothamBold, TextSize = 14,
	TextColor3 = T.Dim, AutoButtonColor = false, BorderSizePixel = 0,
}, topbar)
corner(minBtn, 6)

local sidebar = new("Frame", {
	Size = UDim2.new(0, 148, 1, -38), Position = UDim2.new(0, 0, 0, 38),
	BackgroundColor3 = T.Panel, BorderSizePixel = 0,
}, window)
new("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, sidebar)
new("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12)}, sidebar)

local scroll = new("ScrollingFrame", {
	Size = UDim2.new(1, -180, 1, -60), Position = UDim2.new(0, 160, 0, 50),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
	ScrollBarImageColor3 = T.Line, CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
}, window)

local tabs = {}
local function createPage()
	local page = new("Frame", {
		Size = UDim2.new(1, -6, 0, 0), BackgroundTransparency = 1,
		Visible = false, AutomaticSize = Enum.AutomaticSize.Y,
	}, scroll)
	new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, page)
	local n = 0
	local function add(obj)
		n = n + 1
		obj.LayoutOrder = n
		obj.Parent = page
		return obj
	end
	return page, add
end

local function newTab(name)
	local btn = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = T.Dim,
		TextXAlignment = Enum.TextXAlignment.Left, Text = "   " .. name,
		AutoButtonColor = false,
	}, sidebar)
	local ind = new("Frame", {
		Size = UDim2.new(0, 2, 0, 0), Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = T.Accent, BorderSizePixel = 0,
	}, btn)
	local page, add = createPage()
	tabs[name] = {btn = btn, page = page, ind = ind}
	btn.MouseButton1Click:Connect(function()
		for n, t in pairs(tabs) do
			local on = (n == name)
			t.page.Visible = on
			TweenService:Create(t.btn, TweenInfo.new(0.15), {TextColor3 = on and T.Text or T.Dim}):Play()
			TweenService:Create(t.ind, TweenInfo.new(0.15), {Size = on and UDim2.new(0, 2, 0, 16) or UDim2.new(0, 2, 0, 0)}):Play()
		end
		scroll.CanvasPosition = Vector2.new(0, 0)
	end)
	return page, add
end

local dragging, dragStart, startPos = false, nil, nil
topbar.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		dragging = true; dragStart = i.Position; startPos = window.Position
	end
end)
bind(UserInputService.InputChanged, function(i)
	if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
		local d = i.Position - dragStart
		window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end)
bind(UserInputService.InputEnded, function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)

--=============================================================
-- REMOTE FINDER
--=============================================================
local ParryRemote, AbilityRemote, ParryPath = nil, nil, ""

local function scoreRemote(inst)
	local n = inst.Name:lower()
	if n == "parry" then return 1 end
	if n == "parrybuttonpress" then return 2 end
	if n == "parryevent" then return 3 end
	if n:find("parry") then return 4 end
	return 99
end

local function collectRemotes()
	local out = {}
	for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
		if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) and d.Name:lower():find("parry") then
			table.insert(out, d)
		end
	end
	table.sort(out, function(a, b) return scoreRemote(a) < scoreRemote(b) end)
	return out
end

local function setRemote(inst)
	if not inst then return false end
	ParryRemote = inst
	ParryPath = inst:GetFullName()
	return true
end

local function findRemotes()
	if Config.RemotePath ~= "" then
		local ok, inst = pcall(function()
			local node = game
			for part in string.gmatch(Config.RemotePath, "[^%.]+") do node = node[part] end
			return node
		end)
		if ok and inst and (inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction")) then
			return setRemote(inst)
		end
	end

	local candidates = collectRemotes()
	if #candidates > 0 then return setRemote(candidates[1]) end

	for _, path in ipairs({{"Remotes","Parry"},{"Remotes","ParryButtonPress"},{"RemoteEvents","Parry"},{"Packets","Parry"}}) do
		local node = ReplicatedStorage
		for _, seg in ipairs(path) do node = node and node:FindFirstChild(seg) end
		if node and (node:IsA("RemoteEvent") or node:IsA("RemoteFunction")) then return setRemote(node) end
	end
	return false
end

local function fireRemote(inst, ball)
	if not inst then return end
	if inst:IsA("RemoteFunction") then
		pcall(function() inst:InvokeServer() end)
	else
		if Config.SendBall and ball then
			pcall(function() inst:FireServer(ball) end)
		else
			pcall(function() inst:FireServer() end)
		end
	end
end

local function findAbility()
	AbilityRemote = nil
	for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
		if d:IsA("RemoteEvent") and d.Name:lower():find("abilit") then
			AbilityRemote = d
			return
		end
	end
end

findRemotes()
findAbility()

--=============================================================
-- BALL
--=============================================================
local function getBall()
	local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")

	local function pick(container)
		local best, bestD
		for _, b in ipairs(container:GetChildren()) do
			if b:IsA("BasePart") and b.Name:lower():find("ball") then
				if not hrp then return b end
				local d = (b.Position - hrp.Position).Magnitude
				if not bestD or d < bestD then best, bestD = b, d end
			end
		end
		return best
	end

	local folder = workspace:FindFirstChild("Balls")
	if folder then
		local b = pick(folder)
		if b then return b end
	end
	for _, d in ipairs(workspace:GetChildren()) do
		if d:IsA("BasePart") and d.Name:lower():find("ball") then return d end
	end
	return nil
end

--=============================================================
-- STATE
--=============================================================
local state = {
	lastFire    = 0,
	lastSoft    = 0,
	offset      = Config.BaseOffset,
	parries     = 0,
	fails       = 0,
	rateCount   = 0,
	rateWindow  = tick(),
	wasMoving   = false,
	throwOffset = Config.BaseOffset,
	triggerDist = Config.CloseRange,
	reactAt     = nil,
	armed       = true,
	lastDist    = 999,
	pendingFail = nil,
	eta         = 0,
	dist        = 0,
	speed       = 0,
}

local function newThrow()
	local pr = profile()
	state.armed = true
	state.reactAt = nil
	state.triggerDist = Config.CloseRange + math.random(-2, Config.TriggerJitter)
	if Config.Humanize then
		state.throwOffset = pr.offMin + math.random() * (pr.offMax - pr.offMin)
	else
		state.throwOffset = Config.BaseOffset
	end
end

local function doParry(ball, critical)
	local pr = profile()
	local now = tick()

	if Config.OnePerThrow and pr.onePerThrow and not state.armed then return false end
	if now - state.lastFire < 0.06 then return false end

	local softOk = (now - state.lastSoft) >= pr.cooldown
	if not softOk and not critical then return false end

	if Config.RateLimit and not critical then
		if now - state.rateWindow >= 1 then
			state.rateCount = 0
			state.rateWindow = now
		end
		if state.rateCount >= pr.maxRate then return false end
		state.rateCount += 1
	end

	state.lastFire = now
	state.lastSoft = now
	state.parries += 1
	state.armed = false

	if ParryRemote then fireRemote(ParryRemote, ball) end

	local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
	if hum then state.pendingFail = {t = now, hp = hum.Health} end
	return true
end

local lastAbility = 0
local function doAbility()
	if tick() - lastAbility < Config.AbilityDelay then return end
	lastAbility = tick()
	if AbilityRemote then pcall(function() AbilityRemote:FireServer() end) end
end

--=============================================================
-- COMBAT LOOP
--=============================================================
local lastBallPos, lastBallTime

bind(RunService.Heartbeat, function()
	local char = LP.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	local pr   = profile()

	if state.pendingFail and hum and tick() - state.pendingFail.t > 0.55 then
		if hum.Health < state.pendingFail.hp then
			state.fails += 1
			if Config.SmartOffset then
				state.offset = math.clamp(state.offset + 0.008, 0.05, 0.35)
			end
		end
		state.pendingFail = nil
	end

	if Config.AutoAbility then doAbility() end
	if not Config.AutoParry or not hrp then return end

	local ball = getBall()
	if not ball then
		state.dist, state.eta, state.speed = 0, 0, 0
		return
	end

	local now = tick()
	local vel = ball.AssemblyLinearVelocity
	if lastBallPos and lastBallTime then
		local dt = now - lastBallTime
		if dt > 0 then
			local predicted = (ball.Position - lastBallPos) / dt
			if predicted.Magnitude > vel.Magnitude then vel = predicted end
		end
	end
	lastBallPos, lastBallTime = ball.Position, now

	local speed = vel.Magnitude
	local moving = speed > 1.5
	local toMe = hrp.Position - ball.Position
	local dist = toMe.Magnitude

	-- новый бросок -> перезаряжаемся и рандомизируем тайминг
	if moving and not state.wasMoving then newThrow() end
	state.wasMoving = moving

	-- мяч уходит от нас -> снова можно парить (клэш/рикошет)
	if dist > state.lastDist + 0.6 and now - state.lastFire > 0.2 then
		state.armed = true
		state.reactAt = nil
	end
	state.lastDist = dist

	if Config.GateSpeed and not moving and dist > 25 then return end
	if Config.GateDistance and dist > pr.maxDist then return end

	if Config.GateApproach and dist > 0.5 and speed > 0.5 then
		if (vel / speed):Dot(toMe.Unit) < 0.05 then return end
	end

	local ping = getPing() / 1000
	local baseOff = Config.Humanize and state.throwOffset or Config.BaseOffset
	if Config.SmartOffset then baseOff = baseOff * (state.offset / math.max(Config.BaseOffset, 0.01)) end
	local eta = dist / math.max(speed, 1)

	state.dist, state.eta, state.speed = dist, eta, speed

	local critical = dist <= math.max(5, Config.CloseRange * 0.45)

	local want = false
	if Config.ParryMode == "Distance" then
		want = dist <= state.triggerDist
	elseif Config.ParryMode == "Prediction" then
		want = eta <= ping + baseOff
	else
		want = (dist <= state.triggerDist) or (eta <= ping + baseOff)
	end
	if critical then want = true end

	if want and state.armed then
		if not state.reactAt then
			state.reactAt = now + (Config.ReactionJitter / 1000) * math.random()
		end
		if now >= state.reactAt or critical then
			doParry(ball, critical)
		end
	elseif not want then
		state.reactAt = nil
	end
end)

--=============================================================
-- ESP
--=============================================================
local espObjs = {}

local function project(v3)
	local sp = CAMERA:WorldToViewportPoint(v3)
	if sp.Z <= 0 then return nil end
	return Vector2.new(sp.X, sp.Y)
end

local function makeEsp(label)
	local o = {}
	o.box = new("Frame", {BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ZIndex = 2}, espFolder)
	o.stroke = new("UIStroke", {Color = T.Accent, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, o.box)
	o.fill = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = T.Accent, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1}, o.box)
	o.name = new("TextLabel", {
		Size = UDim2.new(0, 220, 0, 13), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = T.Text,
		TextStrokeTransparency = 0, TextStrokeColor3 = Color3.new(0, 0, 0), Text = label, Visible = false, ZIndex = 3,
	}, espFolder)
	o.dist = new("TextLabel", {
		Size = UDim2.new(0, 220, 0, 13), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1,
		Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = T.Dim,
		TextStrokeTransparency = 0, TextStrokeColor3 = Color3.new(0, 0, 0), Text = "", Visible = false, ZIndex = 3,
	}, espFolder)
	o.hpBg = new("Frame", {Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Visible = false, ZIndex = 3}, espFolder)
	o.hp = new("Frame", {Size = UDim2.new(1, 0, 1, 0), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), BackgroundColor3 = T.Good, BorderSizePixel = 0, ZIndex = 4}, o.hpBg)
	o.tracer = new("Frame", {Size = UDim2.new(0, 0, 0, 1), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = T.Accent, BackgroundTransparency = 0.4, BorderSizePixel = 0, Visible = false, ZIndex = 1}, espFolder)
	return o
end

local ballEsp = makeEsp("BALL")

local function hideEsp(o)
	o.box.Visible = false; o.name.Visible = false; o.dist.Visible = false
	o.hpBg.Visible = false; o.tracer.Visible = false
end

local function updateEsp()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP then
			local o = espObjs[p]
			if not o then o = makeEsp(p.DisplayName); espObjs[p] = o end
			local char = p.Character
			local hrp  = char and char:FindFirstChild("HumanoidRootPart")
			local hum  = char and char:FindFirstChildOfClass("Humanoid")

			if Config.BoxEsp and char and hrp and hum and hum.Health > 0 then
				local cf, size = char:GetBoundingBox()
				local minX, minY, maxX, maxY
				for xi = -1, 1, 2 do
					for yi = -1, 1, 2 do
						for zi = -1, 1, 2 do
							local sp = project(cf * Vector3.new(size.X / 2 * xi, size.Y / 2 * yi, size.Z / 2 * zi))
							if sp then
								minX = minX and math.min(minX, sp.X) or sp.X
								minY = minY and math.min(minY, sp.Y) or sp.Y
								maxX = maxX and math.max(maxX, sp.X) or sp.X
								maxY = maxY and math.max(maxY, sp.Y) or sp.Y
							end
						end
					end
				end

				if minX then
					local w, h = maxX - minX, maxY - minY
					o.box.Visible = true
					o.box.Position = UDim2.fromOffset(minX, minY)
					o.box.Size = UDim2.fromOffset(w, h)
					o.stroke.Color = Config.EspColor
					o.fill.BackgroundColor3 = Config.EspColor
					o.fill.BackgroundTransparency = Config.EspFill and Config.EspFillAlpha or 1

					o.name.Visible = Config.NameEsp
					if Config.NameEsp then
						o.name.Text = p.DisplayName
						o.name.Position = UDim2.fromOffset(minX + w / 2, minY - 2)
					end

					o.dist.Visible = Config.DistEsp
					if Config.DistEsp then
						o.dist.Text = string.format("%d studs", math.floor((hrp.Position - CAMERA.CFrame.Position).Magnitude))
						o.dist.Position = UDim2.fromOffset(minX + w / 2, maxY + 2)
					end

					o.hpBg.Visible = Config.HealthEsp
					if Config.HealthEsp then
						o.hpBg.Position = UDim2.fromOffset(minX - 6, minY)
						o.hpBg.Size = UDim2.fromOffset(3, h)
						local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
						o.hp.Size = UDim2.new(1, 0, ratio, 0)
						o.hp.BackgroundColor3 = Color3.fromRGB(255, 105, 105):Lerp(Color3.fromRGB(120, 255, 165), ratio)
					end

					o.tracer.Visible = Config.Tracers
					if Config.Tracers then
						local from = Vector2.new(CAMERA.ViewportSize.X / 2, CAMERA.ViewportSize.Y)
						local to = Vector2.new(minX + w / 2, maxY)
						local delta = to - from
						local len = delta.Magnitude
						o.tracer.Position = UDim2.fromOffset((from.X + to.X) / 2 - len / 2, (from.Y + to.Y) / 2)
						o.tracer.Size = UDim2.fromOffset(len, 1)
						o.tracer.Rotation = math.deg(math.atan2(delta.Y, delta.X))
						o.tracer.BackgroundColor3 = Config.EspColor
					end
				else hideEsp(o) end
			else hideEsp(o) end
		end
	end

	local ball = getBall()
	if Config.BallEsp and ball then
		local sp = project(ball.Position)
		if sp then
			local r = 22
			ballEsp.box.Visible = true
			ballEsp.box.Position = UDim2.fromOffset(sp.X - r, sp.Y - r)
			ballEsp.box.Size = UDim2.fromOffset(r * 2, r * 2)
			ballEsp.stroke.Color = Config.BallEspColor
			ballEsp.name.Visible = true
			ballEsp.name.Text = "BALL"
			ballEsp.name.TextColor3 = Config.BallEspColor
			ballEsp.name.Position = UDim2.fromOffset(sp.X, sp.Y - r - 2)
		else hideEsp(ballEsp) end
	else hideEsp(ballEsp) end
end

bind(RunService.RenderStepped, function() pcall(updateEsp) end)

bind(Players.PlayerRemoving, function(p)
	local o = espObjs[p]
	if o then
		for _, v in pairs(o) do
			if typeof(v) == "Instance" then pcall(function() v:Destroy() end) end
		end
		espObjs[p] = nil
	end
end)

--=============================================================
-- HIGHLIGHTS / HITBOXES
--=============================================================
local function updateExtras()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP then
			local char = p.Character
			local hrp  = char and char:FindFirstChild("HumanoidRootPart")
			if char then
				local h = char:FindFirstChild("ScriptSleepHL")
				if Config.Highlights then
					if not h then
						h = Instance.new("Highlight")
						h.Name = "ScriptSleepHL"
						h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
						h.FillTransparency = 0.72
						h.OutlineTransparency = 0
						h.Parent = char
					end
					h.FillColor, h.OutlineColor = Config.EspColor, Config.EspColor
				elseif h then h:Destroy() end
			end
			if hrp then
				local ad = hrp:FindFirstChild("ScriptSleepHitbox")
				if Config.Hitboxes then
					if not ad then
						ad = Instance.new("BoxHandleAdornment")
						ad.Name = "ScriptSleepHitbox"
						ad.Adornee = hrp
						ad.Size = Vector3.new(4, 6, 2.5)
						ad.AlwaysOnTop = true
						ad.ZIndex = 5
						ad.Transparency = 0.65
						ad.Parent = hrp
					end
					ad.Color3 = Config.EspColor
				elseif ad then ad:Destroy() end
			end
		end
	end
end

--=============================================================
-- HEADLESS
--=============================================================
local function applyHeadless()
	local char = LP.Character
	local head = char and char:FindFirstChild("Head")
	if not head then return end
	local alpha = Config.Headless and 1 or 0
	if head:IsA("BasePart") then head.Transparency = alpha end
	for _, d in ipairs(head:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then d.Transparency = alpha end
	end
end

bind(LP.CharacterAdded, function()
	task.wait(0.6)
	pcall(applyHeadless)
end)

--=============================================================
-- SKY / PARTICLES / BALL SKIN
--=============================================================
local SkyPresets = {
	Default = {ClockTime = 14, Brightness = 2,    Ambient = Color3.fromRGB(70, 70, 70),  Outdoor = Color3.fromRGB(128, 128, 128), Sky = true},
	Night   = {ClockTime = 0,  Brightness = 1,    Ambient = Color3.fromRGB(28, 28, 45),  Outdoor = Color3.fromRGB(40, 40, 70),    Sky = true},
	Blood   = {ClockTime = 17, Brightness = 1.5,  Ambient = Color3.fromRGB(80, 20, 20),  Outdoor = Color3.fromRGB(120, 40, 40),   Sky = true},
	Black   = {ClockTime = 12, Brightness = 0.25, Ambient = Color3.new(0, 0, 0),        Outdoor = Color3.new(0, 0, 0),           Sky = false},
	Neon    = {ClockTime = 2,  Brightness = 1,    Ambient = Color3.fromRGB(40, 20, 90),  Outdoor = Color3.fromRGB(70, 35, 140),   Sky = true},
	Vapor   = {ClockTime = 6,  Brightness = 2,    Ambient = Color3.fromRGB(95, 55, 115), Outdoor = Color3.fromRGB(160, 95, 180),  Sky = true},
}

local function applySky(name)
	local pr = SkyPresets[name] or SkyPresets.Default
	Lighting.ClockTime = pr.ClockTime
	Lighting.Brightness = pr.Brightness
	Lighting.Ambient = pr.Ambient
	Lighting.OutdoorAmbient = pr.Outdoor
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if pr.Sky then
		if not sky then
			sky = Instance.new("Sky")
			sky.SkyboxUp = "rbxassetid://159454299"
			sky.SkyboxDn = "rbxassetid://159454296"
			sky.SkyboxLf = "rbxassetid://159454293"
			sky.SkyboxRt = "rbxassetid://159454286"
			sky.SkyboxFt = "rbxassetid://159454300"
			sky.SkyboxBk = "rbxassetid://159454288"
			sky.Parent = Lighting
		end
	elseif sky then sky:Destroy() end
end

local function applyParticles()
	local targets = {}
	local ball = getBall()
	if ball then table.insert(targets, ball) end
	local char = LP.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then table.insert(targets, hrp) end

	for _, part in ipairs(targets) do
		local p = part:FindFirstChild("ScriptSleepParticles")
		if Config.Particles then
			if not p then
				p = Instance.new("ParticleEmitter")
				p.Name = "ScriptSleepParticles"
				p.Texture = "rbxassetid://243660364"
				p.Lifetime = NumberRange.new(0.6)
				p.Speed = NumberRange.new(1.5)
				p.SpreadAngle = Vector2.new(180, 180)
				p.LightEmission = 1
				p.Size = NumberSequence.new(0.6, 0)
				p.Parent = part
			end
			p.Rate = Config.ParticleRate
			p.Color = ColorSequence.new(Config.ParticleColor)
		elseif p then p:Destroy() end
	end
end

local function applyBallSkin()
	local ball = getBall()
	if not ball or not ball:IsA("BasePart") or not Config.BallRecolor then return end
	ball.Color = Config.BallColor
	ball.Material = Enum.Material[Config.BallMaterial] or Enum.Material.Plastic
	local base = ball:GetAttribute("ScriptSleepBaseSize")
	if not base then
		base = ball.Size
		ball:SetAttribute("ScriptSleepBaseSize", base)
	end
	ball.Size = base * Config.BallSize
end

--=============================================================
-- FPS / FOV / HUD
--=============================================================
local fps, frames, fpsTimer = 0, 0, tick()
bind(RunService.RenderStepped, function()
	frames = frames + 1
	if tick() - fpsTimer >= 1 then
		fps, frames, fpsTimer = frames, 0, tick()
	end
end)

local function applyFpsBoost(on)
	if on then
		pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
		pcall(function() UserSettings():GetService("UserGameSettings").SavedQualityLevel = 1 end)
		Lighting.GlobalShadows = false
		Lighting.ShadowSoftness = 0
		Lighting.FogEnd = Config.FogEnd
		Lighting.EnvironmentDiffuseScale = 0
		Lighting.EnvironmentSpecularScale = 0
		for _, e in ipairs(Lighting:GetChildren()) do
			if e:IsA("PostEffect") then e.Enabled = false end
		end
		for _, d in ipairs(workspace:GetDescendants()) do
			if d.Name ~= "ScriptSleepParticles" and d.Name ~= "ScriptSleepHitbox" then
				if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1
				elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") then d.Enabled = false
				elseif d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") then d.Enabled = false end
			end
		end
		pcall(function() setfpscap(240) end)
	else
		Lighting.GlobalShadows = true
	end
end

local hud = new("Frame", {
	Size = UDim2.new(0, 240, 0, 74), Position = UDim2.new(0, 12, 0, 12),
	BackgroundColor3 = T.Bg, BackgroundTransparency = 0.15, BorderSizePixel = 0,
	Visible = Config.Hud, ZIndex = 10,
}, gui)
corner(hud, 8); stroke(hud, T.Line)
new("TextLabel", {
	Size = UDim2.new(1, -16, 0, 16), Position = UDim2.new(0, 10, 0, 5), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = T.Text,
	TextXAlignment = Enum.TextXAlignment.Left, Text = TITLE,
}, hud)
local hudStats = new("TextLabel", {
	Size = UDim2.new(1, -16, 0, 16), Position = UDim2.new(0, 10, 0, 21), BackgroundTransparency = 1,
	Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = T.Dim,
	TextXAlignment = Enum.TextXAlignment.Left, Text = "FPS: --  |  PING: -- ms",
}, hud)
local hudParry = new("TextLabel", {
	Size = UDim2.new(1, -16, 0, 14), Position = UDim2.new(0, 10, 0, 38), BackgroundTransparency = 1,
	Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = T.Dim,
	TextXAlignment = Enum.TextXAlignment.Left, Text = "parries: 0  |  fails: 0",
}, hud)
local hudDebug = new("TextLabel", {
	Size = UDim2.new(1, -16, 0, 14), Position = UDim2.new(0, 10, 0, 53), BackgroundTransparency = 1,
	Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = T.Warn,
	TextXAlignment = Enum.TextXAlignment.Left, Text = "", Visible = false,
}, hud)

task.spawn(function()
	while gui.Parent do
		hud.Visible = Config.Hud
		local ping = math.floor(getPing())
		hudStats.Text = string.format("FPS: %d  |  PING: %d ms", fps, ping)
		hudStats.TextColor3 = ping < 80 and T.Good or (ping < 160 and T.Dim or T.Bad)
		hudParry.Text = string.format("parries: %d  |  fails: %d  |  %s", state.parries, state.fails, Config.BypassMode)
		hudParry.TextColor3 = ParryRemote and T.Good or T.Bad
		hudDebug.Visible = Config.DebugParry and Config.Hud
		if Config.DebugParry then
			hudDebug.Text = string.format("dist %d | eta %.3f | armed %s | %s",
				math.floor(state.dist), state.eta, tostring(state.armed),
				ParryRemote and ParryRemote.Name or "NO REMOTE")
		end
		task.wait(0.35)
	end
end)

--=============================================================
-- TABS
--=============================================================
local combatPage, combatAdd = newTab("Combat")
combatAdd(section(combatPage, "Auto Parry"))
combatAdd((toggle(combatPage, "Auto Parry", Config.AutoParry, function(v) Config.AutoParry = v end)))
combatAdd((dropdown(combatPage, "Trigger Mode", {"Both", "Distance", "Prediction"}, Config.ParryMode, function(v) Config.ParryMode = v end)))
combatAdd((slider(combatPage, "Close Range", 5, 40, Config.CloseRange, 0, function(v) Config.CloseRange = v end)))
combatAdd((slider(combatPage, "Base Offset", 0.05, 0.4, Config.BaseOffset, 2, function(v) Config.BaseOffset = v end)))
combatAdd(section(combatPage, "Humanizer"))
combatAdd((toggle(combatPage, "One Parry Per Throw", Config.OnePerThrow, function(v) Config.OnePerThrow = v end)))
combatAdd((slider(combatPage, "Reaction Jitter (ms)", 0, 200, Config.ReactionJitter, 0, function(v) Config.ReactionJitter = v end)))
combatAdd((slider(combatPage, "Trigger Jitter (studs)", 0, 12, Config.TriggerJitter, 0, function(v) Config.TriggerJitter = v end)))
combatAdd((toggle(combatPage, "Humanize Offset", Config.Humanize, function(v) Config.Humanize = v end)))
combatAdd(section(combatPage, "Abilities"))
combatAdd((toggle(combatPage, "Auto Ability", Config.AutoAbility, function(v) Config.AutoAbility = v end)))
combatAdd((slider(combatPage, "Ability Delay", 0.3, 4, Config.AbilityDelay, 1, function(v) Config.AbilityDelay = v end)))
combatAdd((button(combatPage, "Test Parry Now", function()
	state.armed, state.lastFire, state.lastSoft = true, 0, 0
	doParry(getBall(), true)
	notify(ParryRemote and ("fired -> " .. ParryRemote.Name) or "no remote found", ParryRemote and T.Good or T.Bad)
end)))

local byPage, byAdd = newTab("Bypass")
byAdd(section(byPage, "BAC"))
byAdd((dropdown(byPage, "Profile", {"Off", "Light", "Medium", "Safe", "Paranoid"}, Config.BypassMode, function(v)
	Config.BypassMode = v
	notify("BAC profile: " .. v, T.Warn)
end)))
byAdd((button(byPage, "MAX STEALTH (Paranoid)", function()
	Config.BypassMode = "Paranoid"
	Config.OnePerThrow = true
	Config.Humanize = true
	Config.ReactionJitter = 120
	Config.TriggerJitter = 7
	Config.GateApproach = true
	Config.GateDistance = true
	Config.GateSpeed = true
	Config.AutoAbility = false
	Config.Headless = false
	Config.Particles = false
	Config.BallRecolor = false
	notify("stealth mode armed", T.Good)
end)))
byAdd(section(byPage, "Gates"))
byAdd((toggle(byPage, "Distance Gate", Config.GateDistance, function(v) Config.GateDistance = v end)))
byAdd((toggle(byPage, "Approach Gate", Config.GateApproach, function(v) Config.GateApproach = v end)))
byAdd((toggle(byPage, "Speed Gate", Config.GateSpeed, function(v) Config.GateSpeed = v end)))
byAdd((toggle(byPage, "Rate Limit", Config.RateLimit, function(v) Config.RateLimit = v end)))
byAdd((toggle(byPage, "Smart Offset", Config.SmartOffset, function(v) Config.SmartOffset = v end)))
byAdd(section(byPage, "Remote"))
byAdd((textbox(byPage, "Manual Path", Config.RemotePath, "ReplicatedStorage.Remotes.Parry", function(v)
	Config.RemotePath = v
	if v ~= "" then
		notify(findRemotes() and ("bound: " .. ParryPath) or "path not resolved", ParryRemote and T.Good or T.Bad)
	else
		findRemotes()
	end
end)))
byAdd((button(byPage, "Auto Detect Remote", function()
	Config.RemotePath = ""
	findRemotes(); findAbility()
	notify(ParryRemote and ("found: " .. ParryPath) or "nothing found", ParryRemote and T.Good or T.Bad)
end)))
byAdd((button(byPage, "List Candidates", function()
	local c = collectRemotes()
	if #c == 0 then notify("no parry remotes found", T.Bad) return end
	for i = 1, math.min(#c, 4) do
		task.delay(i * 0.25, function() notify(i .. ") " .. c[i]:GetFullName(), T.Warn) end)
	end
end)))
byAdd((toggle(byPage, "Send Ball As Argument", Config.SendBall, function(v) Config.SendBall = v end)))
byAdd((toggle(byPage, "Debug Readout", Config.DebugParry, function(v) Config.DebugParry = v end)))
byAdd((button(byPage, "Reset Counters", function()
	state.parries, state.fails = 0, 0
	state.offset = Config.BaseOffset
end)))

local visPage, visAdd = newTab("Visuals")
visAdd(section(visPage, "Players"))
visAdd((toggle(visPage, "Box ESP", Config.BoxEsp, function(v) Config.BoxEsp = v end)))
visAdd((toggle(visPage, "Box Fill", Config.EspFill, function(v) Config.EspFill = v end)))
visAdd((toggle(visPage, "Name ESP", Config.NameEsp, function(v) Config.NameEsp = v end)))
visAdd((toggle(visPage, "Distance ESP", Config.DistEsp, function(v) Config.DistEsp = v end)))
visAdd((toggle(visPage, "Health Bar", Config.HealthEsp, function(v) Config.HealthEsp = v end)))
visAdd((toggle(visPage, "Tracers", Config.Tracers, function(v) Config.Tracers = v end)))
visAdd((toggle(visPage, "Highlights", Config.Highlights, function(v) Config.Highlights = v end)))
visAdd((toggle(visPage, "Hitboxes 3D", Config.Hitboxes, function(v) Config.Hitboxes = v end)))
visAdd((dropdown(visPage, "ESP Color", {"White", "Red", "Cyan", "Lime", "Purple", "Gold"}, "White", function(v)
	local map = {
		White = Color3.fromRGB(255,255,255), Red = Color3.fromRGB(255,80,80),
		Cyan = Color3.fromRGB(80,230,255), Lime = Color3.fromRGB(140,255,140),
		Purple = Color3.fromRGB(190,130,255), Gold = Color3.fromRGB(255,210,90),
	}
	Config.EspColor = map[v] or Color3.new(1, 1, 1)
end)))
visAdd(section(visPage, "Ball"))
visAdd((toggle(visPage, "Ball ESP", Config.BallEsp, function(v) Config.BallEsp = v end)))
visAdd((dropdown(visPage, "Ball ESP Color", {"Red", "White", "Cyan", "Gold", "Magenta"}, "Red", function(v)
	local map = {
		Red = Color3.fromRGB(255,90,90), White = Color3.fromRGB(255,255,255),
		Cyan = Color3.fromRGB(90,230,255), Gold = Color3.fromRGB(255,210,90),
		Magenta = Color3.fromRGB(255,110,240),
	}
	Config.BallEspColor = map[v] or Color3.fromRGB(255, 90, 90)
end)))
visAdd(section(visPage, "Character"))
visAdd((toggle(visPage, "Headless", Config.Headless, function(v) Config.Headless = v; applyHeadless() end)))
visAdd((toggle(visPage, "Fullbright", Config.Fullbright, function(v)
	Config.Fullbright = v
	if v then
		Lighting.Ambient = Color3.fromRGB(200, 200, 200)
		Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
		Lighting.Brightness = 2
		Lighting.GlobalShadows = false
	else
		applySky(Config.SkyPreset)
	end
end)))

local worldPage, worldAdd = newTab("World")
worldAdd(section(worldPage, "Sky"))
worldAdd((dropdown(worldPage, "Preset", {"Default", "Night", "Blood", "Black", "Neon", "Vapor"}, Config.SkyPreset, function(v)
	Config.SkyPreset = v
	applySky(v)
end)))
worldAdd((slider(worldPage, "Clock Time", 0, 24, Config.ClockTime, 0, function(v) Config.ClockTime = v; Lighting.ClockTime = v end)))
worldAdd((slider(worldPage, "Brightness", 0, 5, Config.Brightness, 1, function(v) Config.Brightness = v; Lighting.Brightness = v end)))
worldAdd((slider(worldPage, "Fog End", 100, 100000, Config.FogEnd, 0, function(v) Config.FogEnd = v; Lighting.FogEnd = v end)))
worldAdd(section(worldPage, "Particles"))
worldAdd((toggle(worldPage, "Ball / Self Particles", Config.Particles, function(v) Config.Particles = v; applyParticles() end)))
worldAdd((slider(worldPage, "Particle Rate", 5, 200, Config.ParticleRate, 0, function(v) Config.ParticleRate = v; applyParticles() end)))
worldAdd((dropdown(worldPage, "Particle Color", {"White", "Red", "Cyan", "Gold", "Purple"}, "White", function(v)
	local map = {
		White = Color3.fromRGB(255,255,255), Red = Color3.fromRGB(255,90,90),
		Cyan = Color3.fromRGB(90,230,255), Gold = Color3.fromRGB(255,210,90),
		Purple = Color3.fromRGB(190,130,255),
	}
	Config.ParticleColor = map[v] or Color3.new(1, 1, 1)
	applyParticles()
end)))

local skinPage, skinAdd = newTab("Skins")
skinAdd(section(skinPage, "Sword"))
skinAdd((textbox(skinPage, "Mesh ID", Config.SwordMesh, "rbxassetid://...", function(v) Config.SwordMesh = v end)))
skinAdd((textbox(skinPage, "Texture ID", Config.SwordTexture, "rbxassetid://...", function(v) Config.SwordTexture = v end)))
skinAdd((button(skinPage, "Apply Sword Skin", function()
	local char = LP.Character
	if not char then return end
	local found = false
	for _, d in ipairs(char:GetDescendants()) do
		local n = d.Name:lower()
		if (n:find("sword") or n:find("blade") or n:find("weapon")) and (d:IsA("MeshPart") or d:IsA("SpecialMesh")) then
			found = true
			pcall(function()
				if Config.SwordMesh ~= "" then d.MeshId = Config.SwordMesh end
				if Config.SwordTexture ~= "" then
					if d:IsA("MeshPart") then d.TextureID = Config.SwordTexture else d.TextureId = Config.SwordTexture end
				end
			end)
		end
	end
	notify(found and "sword skin applied" or "sword not found", found and T.Good or T.Bad)
end)))
skinAdd(section(skinPage, "Ball (может триггерить BAC)"))
skinAdd((toggle(skinPage, "Recolor Ball", Config.BallRecolor, function(v) Config.BallRecolor = v end)))
skinAdd((dropdown(skinPage, "Ball Color", {"White", "Red", "Cyan", "Gold", "Purple", "Neon Green"}, "White", function(v)
	local map = {
		White = Color3.fromRGB(255,255,255), Red = Color3.fromRGB(255,70,70),
		Cyan = Color3.fromRGB(80,230,255), Gold = Color3.fromRGB(255,205,80),
		Purple = Color3.fromRGB(185,120,255), ["Neon Green"] = Color3.fromRGB(120,255,120),
	}
	Config.BallColor = map[v] or Color3.new(1, 1, 1)
end)))
skinAdd((dropdown(skinPage, "Ball Material", {"Plastic", "Neon", "ForceField", "Glass", "Metal", "Ice"}, Config.BallMaterial, function(v) Config.BallMaterial = v end)))
skinAdd((slider(skinPage, "Ball Size", 0.5, 3, Config.BallSize, 2, function(v) Config.BallSize = v end)))

local miscPage, miscAdd = newTab("Misc")
miscAdd(section(miscPage, "Camera"))
miscAdd((slider(miscPage, "Field of View", 40, 120, Config.Fov, 0, function(v) Config.Fov = v end)))
miscAdd(section(miscPage, "Performance"))
miscAdd((toggle(miscPage, "FPS Booster", Config.FpsBoost, function(v) Config.FpsBoost = v; applyFpsBoost(v) end)))
miscAdd((toggle(miscPage, "FPS / Ping HUD", Config.Hud, function(v) Config.Hud = v end)))
miscAdd(section(miscPage, "Character"))
miscAdd((toggle(miscPage, "Custom Speed", Config.UseSpeed, function(v) Config.UseSpeed = v end)))
miscAdd((slider(miscPage, "Walk Speed", 8, 120, Config.WalkSpeed, 0, function(v) Config.WalkSpeed = v end)))
miscAdd((slider(miscPage, "Jump Power", 20, 200, Config.JumpPower, 0, function(v) Config.JumpPower = v end)))
miscAdd((toggle(miscPage, "Anti AFK", Config.AntiAfk, function(v) Config.AntiAfk = v end)))
miscAdd(section(miscPage, "Menu"))
local keyBtn
keyBtn = miscAdd((button(miscPage, "Menu Key: " .. Config.MenuKey.Name, function()
	local conn
	conn = UserInputService.InputBegan:Connect(function(i, gp)
		if gp then return end
		if i.UserInputType == Enum.UserInputType.Keyboard then
			Config.MenuKey = i.KeyCode
			keyBtn.Text = "Menu Key: " .. i.KeyCode.Name
			conn:Disconnect()
			queueSave()
		end
	end)
end)))
miscAdd(section(miscPage, "Config"))
miscAdd((button(miscPage, "Save Config", function() saveConfig(); notify("saved", T.Good) end)))
miscAdd((button(miscPage, "Reload Config", function() loadConfig(); notify("reloaded", T.Good) end)))
miscAdd((button(miscPage, "Delete Config File", function()
	if hasFS then pcall(function() delfile(FILE) end) end
end)))
miscAdd((button(miscPage, "Rejoin Server", function()
	pcall(function() game:GetService("TeleportService"):Teleport(game.PlaceId, LP) end)
end)))
miscAdd((button(miscPage, "Unload Script", function()
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	pcall(function() gui:Destroy() end)
	pcall(function()
		Lighting.ClockTime = 14
		Lighting.Brightness = 2
		Lighting.Ambient = Color3.fromRGB(70, 70, 70)
		Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
		Lighting.GlobalShadows = true
		workspace.CurrentCamera.FieldOfView = 70
	end)
end)))

--=============================================================
-- OPEN / CLOSE
--=============================================================
local function setMenu(open)
	Config.MenuOpen = open
	window.Visible = open
	queueSave()
end

closeBtn.MouseButton1Click:Connect(function() setMenu(false) end)
minBtn.MouseButton1Click:Connect(function() setMenu(false) end)

bind(UserInputService.InputBegan, function(i, gp)
	if gp then return end
	if i.KeyCode == Config.MenuKey then setMenu(not window.Visible) end
end)

local floatBtn = new("TextButton", {
	Size = UDim2.new(0, 36, 0, 36), Position = UDim2.new(0, 12, 0, 96),
	BackgroundColor3 = T.Bg, Text = "𝒮", Font = Enum.Font.GothamBold, TextSize = 17,
	TextColor3 = T.Text, AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 11,
}, gui)
corner(floatBtn, 18); stroke(floatBtn, T.Line)
floatBtn.MouseButton1Click:Connect(function() setMenu(not window.Visible) end)

for n, t in pairs(tabs) do
	local on = (n == "Combat")
	t.page.Visible = on
	t.btn.TextColor3 = on and T.Text or T.Dim
	t.ind.Size = on and UDim2.new(0, 2, 0, 16) or UDim2.new(0, 2, 0, 0)
end

--=============================================================
-- LOOPS
--=============================================================
task.spawn(function()
	while gui.Parent do
		pcall(updateExtras)
		task.wait(0.35)
	end
end)

task.spawn(function()
	while gui.Parent do
		pcall(applyParticles)
		pcall(applyBallSkin)
		task.wait(0.5)
	end
end)

task.spawn(function()
	while gui.Parent do
		if not ParryRemote or not ParryRemote:IsDescendantOf(game) then
			findRemotes(); findAbility()
		end
		task.wait(3)
	end
end)

bind(RunService.RenderStepped, function()
	local cam = workspace.CurrentCamera
	if cam and math.abs(cam.FieldOfView - Config.Fov) > 0.1 then cam.FieldOfView = Config.Fov end
	local char = LP.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and Config.UseSpeed then
		if hum.WalkSpeed ~= Config.WalkSpeed then hum.WalkSpeed = Config.WalkSpeed end
		if hum.UseJumpPower and hum.JumpPower ~= Config.JumpPower then hum.JumpPower = Config.JumpPower end
	end
end)

bind(LP.Idled, function()
	if Config.AntiAfk then
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end
end)

--=============================================================
-- STARTUP
--=============================================================
task.spawn(function()
	task.wait(0.5)
	pcall(applySky, Config.SkyPreset)
	pcall(applyHeadless)
	if Config.FpsBoost then pcall(applyFpsBoost, true) end
	pcall(function() Lighting.FogEnd = Config.FogEnd end)
	print("[" .. TITLE .. "] loaded | BAC profile: " .. Config.BypassMode)
	notify(TITLE .. " | BAC: " .. Config.BypassMode, T.Good)
end)
