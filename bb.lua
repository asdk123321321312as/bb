--[[
    𝒮𝒸𝓇𝒾𝓅𝓉𝒮𝓁𝑒𝑒𝓅  |  BLADE BALL
    input-based bypass (keypress) + adaptive-radius parry
    + korblox leg + ability guard
    menu: RightShift
--]]

local cloneref = cloneref or function(o) return o end

local Players          = cloneref(game:GetService("Players"))
local RunService       = cloneref(game:GetService("RunService"))
local Workspace        = cloneref(game:GetService("Workspace"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local TweenService     = cloneref(game:GetService("TweenService"))
local Lighting         = cloneref(game:GetService("Lighting"))
local ReplicatedStorage= cloneref(game:GetService("ReplicatedStorage"))
local Stats            = cloneref(game:GetService("Stats"))
local HttpService      = cloneref(game:GetService("HttpService"))

local LP     = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local TITLE  = "ScriptSleep"

--=============================================================
-- CONFIG
--=============================================================
local Config = {
	AutoParry     = true,
	InputMode     = "Auto",
	ParryKey      = "F",
	ActionsPerSec = 60,
	BatchMode     = "Extremely Fast",
	Prediction    = 0.07,
	Horizon       = 0.5,

	AutoRadius    = true,
	LeadTime      = 0.11,
	MinRadius     = 9,
	MaxRadius     = 50,
	BaseRadius    = 16,
	CrossTrigger  = true,
	PingComp      = true,
	BallPredCap   = 22,

	SpeedAssist   = true,
	FastBoost     = 0.6,

	AbilityGuard  = true,
	BoostDetect   = true,
	BoostMult     = 1.7,
	BoostHold     = 0.7,
	ShowAbility   = true,

	RequireTarget = true,
	OnePerBall    = false,
	Debug         = false,

	ParryRing     = true,
	RingColor     = "Purple",
	RingThick     = 0.06,
	RingOpacity   = 0.3,

	-- korblox
	Korblox        = false,
	KorbloxSide    = "Right",
	KorbloxMesh    = "rbxassetid://169177037",
	KorbloxTexture = "",
	KorbloxThin    = 1.0,      -- 1.0 = не утоньшать
	KorbloxScale   = 1.0,
	KorbloxFullLeg = true,     -- бедро + голень
	KorbloxBone    = true,     -- светлая кость
	KorbloxHideFoot= true,

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
	Headless      = false,
	Fullbright    = false,

	SkyPreset     = "Default",
	ClockTime     = 14,
	Brightness    = 2,
	Particles     = false,
	ParticleRate  = 40,
	ParticleColor = Color3.fromRGB(255, 255, 255),

	BallRecolor   = false,
	BallColor     = Color3.fromRGB(255, 255, 255),
	BallSize      = 1,

	Fov           = 70,
	FpsBoost      = false,
	Hud           = true,
	AntiAfk       = true,
	MenuOpen      = true,
	MenuKey       = Enum.KeyCode.RightShift,
}

local KeyCodes = {F = 0x46, E = 0x45, Q = 0x51, R = 0x52, V = 0x56, Space = 0x20, C = 0x43}
local RingColors = {
	Purple = Color3.fromRGB(190, 140, 255),
	White  = Color3.fromRGB(255, 255, 255),
	Red    = Color3.fromRGB(255, 90, 90),
	Cyan   = Color3.fromRGB(90, 230, 255),
	Green  = Color3.fromRGB(120, 255, 160),
	Gold   = Color3.fromRGB(255, 210, 90),
}
local RingHot = Color3.fromRGB(120, 255, 160)
local RingBoost = Color3.fromRGB(255, 170, 60)
local BONE_WHITE = Color3.fromRGB(242, 242, 242)

--=============================================================
-- SAVE / LOAD
--=============================================================
local FILE  = "ScriptSleep_BladeBall.json"
local hasFS = pcall(function() return writefile end)

local function ser(v)
	if typeof(v) == "Color3" then return {__t="c", r=v.R, g=v.G, b=v.B} end
	if typeof(v) == "EnumItem" then return {__t="e", a=tostring(v.EnumType), b=v.Name} end
	return v
end
local function deser(v)
	if type(v) == "table" and v.__t then
		if v.__t == "c" then return Color3.new(v.r, v.g, v.b) end
		if v.__t == "e" then local ok,e = pcall(function() return Enum[v.a][v.b] end); if ok then return e end end
	end
	return v
end
local function saveConfig()
	if not hasFS then return end
	local out = {}
	for k,v in pairs(Config) do out[k] = ser(v) end
	pcall(function() writefile(FILE, HttpService:JSONEncode(out)) end)
end
local function loadConfig()
	if not hasFS then return end
	local ok, data = pcall(readfile, FILE)
	if not ok or not data then return end
	local ok2, dec = pcall(function() return HttpService:JSONDecode(data) end)
	if not ok2 or type(dec) ~= "table" then return end
	for k,v in pairs(dec) do
		if Config[k] ~= nil then local d = deser(v); if d ~= nil then Config[k] = d end end
	end
end
local sq = false
local function queueSave()
	if sq then return end
	sq = true
	task.delay(1, function() sq = false; saveConfig() end)
end
loadConfig()

--=============================================================
-- THEME
--=============================================================
local T = {
	Bg=Color3.fromRGB(9,9,11), Panel=Color3.fromRGB(15,15,18), Item=Color3.fromRGB(21,21,25),
	ItemHi=Color3.fromRGB(31,31,37), Line=Color3.fromRGB(40,40,47), Text=Color3.fromRGB(238,238,243),
	Dim=Color3.fromRGB(140,140,150), Accent=Color3.fromRGB(255,255,255),
	Bad=Color3.fromRGB(255,105,105), Good=Color3.fromRGB(120,255,165), Warn=Color3.fromRGB(255,205,90),
	Purple=Color3.fromRGB(190,140,255),
}

local gui

--=============================================================
-- HELPERS
--=============================================================
local function new(c, p, parent)
	local i = Instance.new(c)
	for k,v in next,p do i[k] = v end
	if parent then i.Parent = parent end
	return i
end
local function corner(i, r) new("UICorner", {CornerRadius = UDim.new(0, r or 8)}, i) end
local function stroke(i, c, t) new("UIStroke", {Color=c or T.Line, Thickness=t or 1, ApplyStrokeMode=Enum.ApplyStrokeMode.Border}, i) end
local function getPing()
	local ok, v = pcall(function()
		if LP.GetNetworkPing then
			local np = LP:GetNetworkPing()
			if np and np > 0 then return np * 1000 end
		end
		return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
	end)
	return math.clamp(ok and v or 60, 5, 500)
end
local conns = {}
local function bind(s, f) table.insert(conns, s:Connect(f)) end
local function notify(text, col)
	if not gui then return end
	local b = new("Frame", {Size=UDim2.new(0,280,0,32), Position=UDim2.new(1,-300,0,12),
		BackgroundColor3=T.Bg, BackgroundTransparency=0.1, BorderSizePixel=0, ZIndex=60}, gui)
	corner(b,8); stroke(b, col or T.Line)
	new("TextLabel", {Size=UDim2.new(1,-20,1,0), Position=UDim2.new(0,10,0,0), BackgroundTransparency=1,
		Font=Enum.Font.GothamMedium, TextSize=12, TextColor3=col or T.Text,
		TextXAlignment=Enum.TextXAlignment.Left, Text=text}, b)
	task.delay(3.5, function()
		TweenService:Create(b, TweenInfo.new(0.4), {BackgroundTransparency=1}):Play()
		task.wait(0.45); pcall(function() b:Destroy() end)
	end)
end

local function safeParent()
	if gethui then local h = gethui(); if h then return h end end
	return LP:WaitForChild("PlayerGui")
end

gui = new("ScreenGui", {Name="ScriptSleep", ResetOnSpawn=false,
	ZIndexBehavior=Enum.ZIndexBehavior.Sibling, IgnoreGuiInset=true, DisplayOrder=999})
if syn and syn.protect_gui then pcall(syn.protect_gui, gui) end
gui.Parent = safeParent()

local espFolder = new("Frame", {Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, ZIndex=1}, gui)

--=============================================================
-- WIDGETS
--=============================================================
local function section(p, t)
	return new("TextLabel", {Size=UDim2.new(1,0,0,24), BackgroundTransparency=1, Font=Enum.Font.GothamBold,
		TextSize=11, TextColor3=T.Accent, TextXAlignment=Enum.TextXAlignment.Left, Text=string.upper(t)}, p)
end

local function toggle(p, label, state, cb)
	local row = new("Frame", {Size=UDim2.new(1,0,0,28), BackgroundTransparency=1}, p)
	new("TextLabel", {Size=UDim2.new(1,-50,1,0), BackgroundTransparency=1, Font=Enum.Font.GothamMedium,
		TextSize=13, TextColor3=T.Text, TextXAlignment=Enum.TextXAlignment.Left, Text=label}, row)
	local btn = new("TextButton", {Size=UDim2.new(0,36,0,18), Position=UDim2.new(1,-36,0.5,-9),
		BackgroundColor3=T.Item, Text="", AutoButtonColor=false}, row)
	corner(btn,9); stroke(btn,T.Line)
	local knob = new("Frame", {Size=UDim2.new(0,14,0,14), Position=UDim2.new(0,2,0.5,-7),
		BackgroundColor3=T.Dim, BorderSizePixel=0}, btn)
	corner(knob,7)
	local on = state
	local function render()
		TweenService:Create(knob, TweenInfo.new(0.15), {
			Position = on and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7),
			BackgroundColor3 = on and T.Accent or T.Dim}):Play()
		TweenService:Create(btn, TweenInfo.new(0.15), {
			BackgroundColor3 = on and Color3.fromRGB(45,45,52) or T.Item}):Play()
	end
	render()
	btn.MouseButton1Click:Connect(function()
		on = not on; render(); if cb then cb(on) end; queueSave()
	end)
	return row, function(v) on = v; render() end
end

local function slider(p, label, minV, maxV, default, dec, cb)
	local h = new("Frame", {Size=UDim2.new(1,0,0,40), BackgroundTransparency=1}, p)
	new("TextLabel", {Size=UDim2.new(1,-70,0,18), BackgroundTransparency=1, Font=Enum.Font.GothamMedium,
		TextSize=13, TextColor3=T.Text, TextXAlignment=Enum.TextXAlignment.Left, Text=label}, h)
	local vl = new("TextLabel", {Size=UDim2.new(0,70,0,18), Position=UDim2.new(1,-70,0,0), BackgroundTransparency=1,
		Font=Enum.Font.GothamBold, TextSize=13, TextColor3=T.Dim, TextXAlignment=Enum.TextXAlignment.Right, Text=""}, h)
	local bar = new("Frame", {Size=UDim2.new(1,0,0,6), Position=UDim2.new(0,0,0,26), BackgroundColor3=T.Item, BorderSizePixel=0}, h)
	corner(bar,3)
	local fill = new("Frame", {Size=UDim2.new(0,0,1,0), BackgroundColor3=T.Accent, BorderSizePixel=0}, bar)
	corner(fill,3)
	local knob = new("Frame", {Size=UDim2.new(0,10,0,10), AnchorPoint=Vector2.new(0.5,0.5),
		Position=UDim2.new(0,0,0.5,0), BackgroundColor3=T.Accent, BorderSizePixel=0}, bar)
	corner(knob,5)
	local function set(v, fire)
		v = math.clamp(v, minV, maxV)
		local a = (v-minV)/(maxV-minV)
		fill.Size = UDim2.new(a,0,1,0); knob.Position = UDim2.new(a,0,0.5,0)
		vl.Text = dec > 0 and string.format("%."..dec.."f", v) or tostring(math.floor(v))
		if fire and cb then cb(v) end
	end
	set(default, false)
	local drag = false
	local function upd(i)
		set(minV + (maxV-minV) * ((i.Position.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X,1)), true)
	end
	bar.InputBegan:Connect(function(i)
		if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=true; upd(i) end
	end)
	bind(UserInputService.InputChanged, function(i)
		if drag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then upd(i) end
	end)
	bind(UserInputService.InputEnded, function(i)
		if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=false; queueSave() end
	end)
	return h, set
end

local function dropdown(p, label, options, default, cb)
	local h = new("Frame", {Size=UDim2.new(1,0,0,30), BackgroundTransparency=1, ZIndex=5, ClipsDescendants=false}, p)
	new("TextLabel", {Size=UDim2.new(1,-140,0,30), BackgroundTransparency=1, Font=Enum.Font.GothamMedium,
		TextSize=13, TextColor3=T.Text, TextXAlignment=Enum.TextXAlignment.Left, Text=label}, h)
	local btn = new("TextButton", {Size=UDim2.new(0,130,0,24), Position=UDim2.new(1,-130,0,3),
		BackgroundColor3=T.Item, Text="", AutoButtonColor=false, ZIndex=6}, h)
	corner(btn,6); stroke(btn,T.Line)
	local txt = new("TextLabel", {Size=UDim2.new(1,-24,1,0), Position=UDim2.new(0,10,0,0), BackgroundTransparency=1,
		Font=Enum.Font.GothamMedium, TextSize=12, TextColor3=T.Text, TextTruncate=Enum.TextTruncate.AtEnd,
		TextXAlignment=Enum.TextXAlignment.Left, Text=tostring(default)}, btn)
	local lh = math.min(#options, 10)*24+8
	local list = new("Frame", {Size=UDim2.new(0,130,0,lh), Position=UDim2.new(1,-130,0,32),
		BackgroundColor3=T.Panel, Visible=false, ZIndex=20, BorderSizePixel=0}, h)
	corner(list,6); stroke(list,T.Line)
	local inner = new("ScrollingFrame", {Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, BorderSizePixel=0,
		ScrollBarThickness=2, ScrollBarImageColor3=T.Line, CanvasSize=UDim2.new(0,0,0,#options*24+8),
		ScrollingDirection=Enum.ScrollingDirection.Y}, list)
	new("UIListLayout", {Padding=UDim.new(0,2), SortOrder=Enum.SortOrder.LayoutOrder}, inner)
	new("UIPadding", {PaddingTop=UDim.new(0,4), PaddingBottom=UDim.new(0,4)}, inner)
	local open = false
	for i,o in ipairs(options) do
		local b = new("TextButton", {Size=UDim2.new(1,0,0,22), BackgroundTransparency=1, Font=Enum.Font.GothamMedium,
			TextSize=12, TextColor3=T.Dim, Text=tostring(o), LayoutOrder=i, ZIndex=21,
			TextTruncate=Enum.TextTruncate.AtEnd}, inner)
		b.MouseEnter:Connect(function() b.TextColor3=T.Text end)
		b.MouseLeave:Connect(function() b.TextColor3=T.Dim end)
		b.MouseButton1Click:Connect(function()
			txt.Text=tostring(o); list.Visible=false; open=false; h.Size=UDim2.new(1,0,0,30)
			if cb then cb(o) end; queueSave()
		end)
	end
	btn.MouseButton1Click:Connect(function()
		open = not open; list.Visible = open
		h.Size = open and UDim2.new(1,0,0,30+lh+6) or UDim2.new(1,0,0,30)
	end)
	return h, function(v) txt.Text = tostring(v) end
end

local function textbox(p, label, default, ph, cb)
	local h = new("Frame", {Size=UDim2.new(1,0,0,30), BackgroundTransparency=1}, p)
	new("TextLabel", {Size=UDim2.new(1,-160,1,0), BackgroundTransparency=1, Font=Enum.Font.GothamMedium,
		TextSize=13, TextColor3=T.Text, TextXAlignment=Enum.TextXAlignment.Left, Text=label}, h)
	local box = new("TextBox", {Size=UDim2.new(0,150,0,24), Position=UDim2.new(1,-150,0,3),
		BackgroundColor3=T.Item, Text=default or "", PlaceholderText=ph or "", Font=Enum.Font.Gotham,
		TextSize=12, TextColor3=T.Text, PlaceholderColor3=T.Dim, ClearTextOnFocus=false, BorderSizePixel=0}, h)
	corner(box,6); stroke(box,T.Line)
	box.FocusLost:Connect(function() if cb then cb(box.Text) end; queueSave() end)
	return h, box
end

local function button(p, label, cb)
	local b = new("TextButton", {Size=UDim2.new(1,0,0,28), BackgroundColor3=T.Item, Font=Enum.Font.GothamBold,
		TextSize=12, TextColor3=T.Text, Text=label, AutoButtonColor=false, BorderSizePixel=0}, p)
	corner(b,6); stroke(b,T.Line)
	b.MouseEnter:Connect(function() TweenService:Create(b,TweenInfo.new(0.15),{BackgroundColor3=T.ItemHi}):Play() end)
	b.MouseLeave:Connect(function() TweenService:Create(b,TweenInfo.new(0.15),{BackgroundColor3=T.Item}):Play() end)
	b.MouseButton1Click:Connect(function() if cb then cb() end end)
	return b
end

--=============================================================
-- WINDOW
--=============================================================
local window = new("Frame", {Size=UDim2.new(0,660,0,450), Position=UDim2.new(0.5,-330,0.5,-225),
	BackgroundColor3=T.Bg, BorderSizePixel=0, Visible=Config.MenuOpen}, gui)
corner(window,12); stroke(window,T.Line,1)
local topbar = new("Frame", {Size=UDim2.new(1,0,0,38), BackgroundColor3=T.Panel, BorderSizePixel=0}, window)
corner(topbar,12)
new("Frame", {Size=UDim2.new(1,0,0,12), Position=UDim2.new(0,0,1,-12), BackgroundColor3=T.Panel, BorderSizePixel=0}, topbar)
new("TextLabel", {Size=UDim2.new(0,420,1,0), Position=UDim2.new(0,16,0,0), BackgroundTransparency=1,
	Font=Enum.Font.GothamBold, TextSize=16, TextColor3=T.Text, TextXAlignment=Enum.TextXAlignment.Left, Text=TITLE}, topbar)
local closeBtn = new("TextButton", {Size=UDim2.new(0,22,0,22), Position=UDim2.new(1,-32,0,8), BackgroundColor3=T.Item,
	Text="x", Font=Enum.Font.GothamBold, TextSize=13, TextColor3=T.Dim, AutoButtonColor=false, BorderSizePixel=0}, topbar)
corner(closeBtn,6)
local minBtn = new("TextButton", {Size=UDim2.new(0,22,0,22), Position=UDim2.new(1,-60,0,8), BackgroundColor3=T.Item,
	Text="-", Font=Enum.Font.GothamBold, TextSize=14, TextColor3=T.Dim, AutoButtonColor=false, BorderSizePixel=0}, topbar)
corner(minBtn,6)

local sidebar = new("Frame", {Size=UDim2.new(0,148,1,-38), Position=UDim2.new(0,0,0,38), BackgroundColor3=T.Panel, BorderSizePixel=0}, window)
new("UIListLayout", {Padding=UDim.new(0,3), SortOrder=Enum.SortOrder.LayoutOrder}, sidebar)
new("UIPadding", {PaddingTop=UDim.new(0,10), PaddingLeft=UDim.new(0,12), PaddingRight=UDim.new(0,12)}, sidebar)

local scroll = new("ScrollingFrame", {Size=UDim2.new(1,-180,1,-60), Position=UDim2.new(0,160,0,50),
	BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=3, ScrollBarImageColor3=T.Line,
	CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollingDirection=Enum.ScrollingDirection.Y}, window)

local tabs = {}
local function newTab(name)
	local btn = new("TextButton", {Size=UDim2.new(1,0,0,28), BackgroundTransparency=1, Font=Enum.Font.GothamMedium,
		TextSize=13, TextColor3=T.Dim, TextXAlignment=Enum.TextXAlignment.Left, Text="   "..name, AutoButtonColor=false}, sidebar)
	local ind = new("Frame", {Size=UDim2.new(0,2,0,0), Position=UDim2.new(0,0,0.5,0), AnchorPoint=Vector2.new(0,0.5),
		BackgroundColor3=T.Accent, BorderSizePixel=0}, btn)
	local page = new("Frame", {Size=UDim2.new(1,-6,0,0), BackgroundTransparency=1, Visible=false,
		AutomaticSize=Enum.AutomaticSize.Y}, scroll)
	new("UIListLayout", {Padding=UDim.new(0,6), SortOrder=Enum.SortOrder.LayoutOrder}, page)
	local n = 0
	local function add(o) n = n+1; o.LayoutOrder = n; o.Parent = page; return o end
	tabs[name] = {btn=btn, page=page, ind=ind}
	btn.MouseButton1Click:Connect(function()
		for k,t in pairs(tabs) do
			local on = (k==name)
			t.page.Visible = on
			TweenService:Create(t.btn,TweenInfo.new(0.15),{TextColor3 = on and T.Text or T.Dim}):Play()
			TweenService:Create(t.ind,TweenInfo.new(0.15),{Size = on and UDim2.new(0,2,0,16) or UDim2.new(0,2,0,0)}):Play()
		end
		scroll.CanvasPosition = Vector2.new(0,0)
	end)
	return page, add
end

local drag, ds, sp = false, nil, nil
topbar.InputBegan:Connect(function(i)
	if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
		drag=true; ds=i.Position; sp=window.Position
	end
end)
bind(UserInputService.InputChanged, function(i)
	if drag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
		local d = i.Position - ds
		window.Position = UDim2.new(sp.X.Scale, sp.X.Offset+d.X, sp.Y.Scale, sp.Y.Offset+d.Y)
	end
end)
bind(UserInputService.InputEnded, function(i)
	if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=false end
end)

--=============================================================
-- PARRY REMOTE (фолбэк)
--=============================================================
local ParryRemote
local function findRemote()
	ParryRemote = nil
	for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
		if d:IsA("RemoteEvent") and d.Name:lower() == "parry" then ParryRemote = d; return end
	end
	for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
		if d:IsA("RemoteEvent") and d.Name:lower():find("parry") then ParryRemote = d; return end
	end
end
findRemote()

local hasKeypress = pcall(function() return keypress end)
local hasMouse    = pcall(function() return mouse1click end)

--=============================================================
-- PARRY ENGINE
--=============================================================
local E = {
	lastAction = 0, actions = 0, lastBall = nil, lastTime = 0,
	lastVel = Vector3.zero, accel = Vector3.zero,
	dist = 0, speed = 0, eta = 0, radius = 16, lead = 0,
	targeted = false, hot = false, mode = "-",
	prevSpeed = nil, prevSpeedT = 0, boostUntil = 0, boosted = false,
	ability = "-", seenAbility = {}, seenCount = 0,
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
	elseif Config.BatchMode == "Extremely Fast" then cd = math.max(0.010, cd) end
	if Config.SpeedAssist and E.speed > 120 then
		cd = cd * (1 - 0.6 * math.clamp(Config.FastBoost, 0, 1))
	end
	if E.boosted then cd = cd * 0.5 end
	return math.max(0.008, cd + (math.random(-1, 2) / 1000))
end

local function sendAction(ball)
	local now = tick()
	if now - E.lastAction < actionCooldown() then return false end
	if Config.OnePerBall and E.lastBall == ball and not E.released then return false end
	E.lastAction = now; E.actions += 1; E.lastBall = ball; E.released = false
	E.mode = performParry()
	return true
end

--=============================================================
-- MATCH / BALL
--=============================================================
local function inMatch()
	local char = LP.Character
	if not char then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false end
	local alive = Workspace:FindFirstChild("Alive")
	if alive then return char:IsDescendantOf(alive) end
	local dead = Workspace:FindFirstChild("Dead")
	if dead and char:IsDescendantOf(dead) then return false end
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

local function isTargeted(ball)
	local char = LP.Character
	if not ball or not char then return nil end
	local t = ball:GetAttribute("target") or ball:GetAttribute("Target")
		or ball:GetAttribute("currentTarget") or ball:GetAttribute("targetPlayer") or ball:GetAttribute("to")
	if t ~= nil then
		if t == LP.Name or t == LP.DisplayName or t == char.Name
			or t == LP.UserId or t == tostring(LP.UserId)
			or t == LP or t == char or t == true or t == "Training" then return true end
		if typeof(t) == "Instance" then
			if t:IsA("Player") then return t == LP end
			if t:IsA("Model") then return t == char end
		end
		if typeof(t) == "string" or typeof(t) == "number" then return false end
	end
	for _, ch in ipairs(ball:GetChildren()) do
		if ch:IsA("ValueBase") and ch.Name:lower():find("target") then
			local v = ch.Value
			if v == LP.Name or v == char.Name or v == LP or v == LP.UserId or v == tostring(LP.UserId) then return true end
			if v ~= nil then return false end
		end
	end
	if char:GetAttribute("Targeted") == true then return true end
	if char:FindFirstChild("TargetHighlight") then return true end
	local hl = char:FindFirstChild("Highlight")
	if hl and hl:IsA("Highlight") then
		if hl:GetAttribute("Target") == true then return true end
		if hl.FillColor.R > 0.6 and hl.FillColor.G < 0.5 and hl.FillColor.B < 0.5 then return true end
	end
	return nil
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
	if speed <= 0 then velocity = ball.Velocity; speed = velocity.Magnitude end
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
	return {ball=ball, distance=distance, speed=speed, velocity=velocity, accel=accel,
		dot=dot, approachSpeed=approachSpeed,
		eta = distance / math.max(approachSpeed, speed * 0.7, 1)}
end

--=============================================================
-- ABILITY GUARD
--=============================================================
local BALL_ABILITIES = {
	"curve ball","curved ball","raging deflect","pull","pull in","push","time stop","time freeze",
	"reaper","freeze","ice","ice spike","gravity","void","storm","tornado","black hole","lightning",
	"thunder","magnet","reflect","shockwave","shock","telekinesis","slow motion","absorb","speed",
	"boost","power shot","launch","slam","uppercut","explosion","meteor","fireball","blast","impact",
	"wave","force","quake","rocket","dash","shadow step","blink","teleport","clone","giant","phase",
}
local ALL_ABILITIES = {
	"Curve Ball","Raging Deflect","Thunder Dash","Blink","Force Field","Infinity","Pull","Time Stop",
	"Shadow Step","Sword Throw","Clone","Giant","Reaper","Freeze","Fire","Uppercut","Phase","Punch",
	"Gravity","Void","Storm","Tornado","Meteor","Explosion","Absorb","Heal","Speed","Super Jump",
	"Dash","Rocket","Black Hole","Lightning","Magnet","Reflect","Shockwave","Portal","Telekinesis",
	"Slow Motion","Double Jump","Hover","Ground Pound","Spin","Slam","Barrier","Ghost","Ice","Thunder",
	"Shock","Blast","Impact","Push","Power Shot","Launch","Quake",
}
local abilitySet = {}
for _, n in ipairs(BALL_ABILITIES) do abilitySet[n:lower()] = true end
local abilityKnown = {}
for _, n in ipairs(ALL_ABILITIES) do abilityKnown[n:lower()] = true end

local function registerAbilityName(name)
	if not name or name == "" then return end
	local k = name:lower()
	abilityKnown[k] = true
	if abilitySet[k] == nil then abilitySet[k] = true end
end

local function scanGameAbilities()
	local names = {}
	local function harvest(root)
		if not root then return end
		for _, c in ipairs(root:GetChildren()) do names[c.Name] = true end
	end
	for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
		local n = d.Name:lower()
		if n:match("abilit") and (d:IsA("Folder") or d:IsA("Model") or d:IsA("Configuration")) then harvest(d) end
		if n:match("abilit") and (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) then names[d.Name] = true end
	end
	local out = {}
	for n in pairs(names) do
		if #n > 1 and #n < 24 and not n:lower():match("remote") then table.insert(out, n) end
	end
	table.sort(out)
	for _, n in ipairs(out) do registerAbilityName(n) end
	return out
end

local discovered = scanGameAbilities()

local function detectBoost(threat)
	local now = tick()
	local hit = nil

	if Config.BoostDetect and E.prevSpeed then
		local dt = now - E.prevSpeedT
		if dt < 0.30 then
			local dv = threat.speed - E.prevSpeed
			if dv > 55 then hit = "speed +" .. math.floor(dv) end
		end
	end
	E.prevSpeed, E.prevSpeedT = threat.speed, now

	if not hit and Config.AbilityGuard then
		local ball = threat.ball
		for _, a in ipairs({"ability","Ability","effect","Effect","boost","Boost","speed","Speed","power","Power","multiplier","Multiplier"}) do
			local v = ball:GetAttribute(a)
			if v ~= nil then
				if typeof(v) == "string" and abilitySet[v:lower()] then hit = v
				elseif typeof(v) == "boolean" and v and a:lower():match("boost") then hit = a
				elseif typeof(v) == "number" and v > 1.4 and a:lower():match("speed") then hit = a end
			end
		end
		if not hit then
			for _, d in ipairs(ball:GetChildren()) do
				local n = d.Name:lower()
				if abilitySet[n] and not E.seenAbility[d] then
					E.seenAbility[d] = true; E.seenCount += 1; hit = d.Name
				end
			end
		end
		if not hit then
			for _, d in ipairs(Workspace:GetChildren()) do
				local n = d.Name:lower()
				if abilitySet[n] and not E.seenAbility[d] then
					E.seenAbility[d] = true; E.seenCount += 1; hit = d.Name
				end
			end
		end
		if not hit then
			for _, p in ipairs(Players:GetPlayers()) do
				local ch = p.Character
				if ch then
					for _, d in ipairs(ch:GetChildren()) do
						local n = d.Name:lower()
						if abilitySet[n] and not E.seenAbility[d] then
							E.seenAbility[d] = true; E.seenCount += 1; hit = d.Name
						end
					end
				end
			end
		end
	end

	if hit then
		E.boostUntil = now + math.clamp(Config.BoostHold, 0.15, 2)
		E.ability = hit
		return true
	end
	return now < E.boostUntil
end

local function computeRadius(threat, pingSec)
	local net = pingSec * 0.5 + (1 / 60)
	local boost = 0
	if Config.SpeedAssist then
		boost = math.clamp((threat.speed - 120) / 800, 0, 0.20) * math.clamp(Config.FastBoost, 0, 1)
	end
	if Config.AutoRadius then
		local lead = Config.LeadTime + boost + (Config.PingComp and net or 0)
		return math.clamp(threat.speed * lead, Config.MinRadius, Config.MaxRadius)
	end
	local r = Config.BaseRadius
	if Config.PingComp then r = r + math.clamp(threat.speed * net, 0, Config.BallPredCap) end
	if Config.SpeedAssist then
		r = r + math.clamp((threat.speed - 120) * 0.06, 0, 16) * math.clamp(Config.FastBoost, 0, 1)
	end
	return r
end

local function step(dt)
	if not Config.AutoParry or not inMatch() then E.boosted = false; return end
	local char = LP.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local ball = getBall()
	if not ball then E.boosted = false; return end
	local threat = computeThreat(ball, root)
	if not threat then return end

	E.dist, E.speed, E.eta = threat.distance, threat.speed, threat.eta

	local pingSec = getPing() / 1000
	local radius = computeRadius(threat, pingSec)

	local boosted = false
	if Config.AbilityGuard then boosted = detectBoost(threat) end
	E.boosted = boosted
	if boosted then
		radius = math.min(radius * math.clamp(Config.BoostMult, 1, 3), Config.MaxRadius * 1.6)
	end

	E.radius = radius
	E.hot = threat.distance <= radius

	local tgt = isTargeted(ball)
	local heur = threat.dot > 0.4 and threat.approachSpeed > 0
	E.targeted = (tgt == true) or (tgt == nil and heur)
	if Config.RequireTarget and not boosted then
		if tgt == false then return end
		if tgt == nil and not heur then return end
	end

	local dtStep = math.clamp(dt or 0.016, 0.001, 0.033)
	local horizon = (Config.Horizon or 0.5) * (Config.Prediction or 0.07)
	horizon = horizon + math.clamp((threat.speed - 150) * 0.00035, 0, 0.14)
	if boosted then horizon = horizon + 0.10 end
	local transit = pingSec * 0.5 + dtStep * 0.5 + (1 / 60) + horizon

	local dirOk = threat.dot > 0.05 or threat.approachSpeed > -5
	if boosted then dirOk = true end

	if Config.CrossTrigger then
		local closing = math.max(threat.approachSpeed, threat.speed * 0.5, 1)
		local tCross = (threat.distance - radius) / closing
		E.lead = tCross
		if tCross <= transit and dirOk then sendAction(ball); return end
	else
		if threat.distance <= radius and dirOk then sendAction(ball); return end
	end

	local futurePlayer = root.Position + root.AssemblyLinearVelocity * transit
	local curveComp = 0.5 * threat.accel * (transit * transit)
	if curveComp.Magnitude > 15 then curveComp = curveComp.Unit * 15 end
	local futureBall = ball.Position + threat.velocity * transit + curveComp
	if (futurePlayer - futureBall).Magnitude <= radius and dirOk then sendAction(ball) end
end

bind(RunService.Heartbeat, function()
	if E.lastBall and E.lastBall.Parent then
		local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local d = (E.lastBall.Position - root.Position).Magnitude
			local v = E.lastBall.AssemblyLinearVelocity
			if d > 32 and v.Magnitude > 1 and v.Unit:Dot((root.Position - E.lastBall.Position).Unit) < -0.2 then
				E.released = true
			end
		end
	end
end)

--=============================================================
-- PARRY RING
--=============================================================
local ring = new("CylinderHandleAdornment", {
	Height = 0.05, Radius = Config.BaseRadius,
	InnerRadius = Config.BaseRadius * (1 - Config.RingThick),
	Color3 = RingColors[Config.RingColor] or RingColors.Purple,
	Transparency = Config.RingOpacity, AlwaysOnTop = true, ZIndex = 5,
	CFrame = CFrame.Angles(math.rad(90), 0, 0), Visible = false,
}, gui)

--=============================================================
-- ESP
--=============================================================
local espObjs = {}
local function project(v)
	local sp = Camera:WorldToViewportPoint(v)
	if sp.Z <= 0 then return nil end
	return Vector2.new(sp.X, sp.Y)
end
local function makeEsp(label)
	local o = {}
	o.box = new("Frame", {BackgroundTransparency=1, BorderSizePixel=0, Visible=false, ZIndex=2}, espFolder)
	o.stroke = new("UIStroke", {Color=T.Accent, Thickness=1, ApplyStrokeMode=Enum.ApplyStrokeMode.Border}, o.box)
	o.fill = new("Frame", {Size=UDim2.new(1,0,1,0), BackgroundColor3=T.Accent, BackgroundTransparency=1, BorderSizePixel=0, ZIndex=1}, o.box)
	o.name = new("TextLabel", {Size=UDim2.new(0,220,0,13), AnchorPoint=Vector2.new(0.5,1), BackgroundTransparency=1,
		Font=Enum.Font.GothamBold, TextSize=11, TextColor3=T.Text, TextStrokeTransparency=0,
		TextStrokeColor3=Color3.new(0,0,0), Text=label, Visible=false, ZIndex=3}, espFolder)
	o.dist = new("TextLabel", {Size=UDim2.new(0,220,0,13), AnchorPoint=Vector2.new(0.5,0), BackgroundTransparency=1,
		Font=Enum.Font.Gotham, TextSize=10, TextColor3=T.Dim, TextStrokeTransparency=0,
		TextStrokeColor3=Color3.new(0,0,0), Text="", Visible=false, ZIndex=3}, espFolder)
	o.hpBg = new("Frame", {Size=UDim2.new(0,3,1,0), BackgroundColor3=Color3.new(0,0,0), BorderSizePixel=0, Visible=false, ZIndex=3}, espFolder)
	o.hp = new("Frame", {Size=UDim2.new(1,0,1,0), AnchorPoint=Vector2.new(0,1), Position=UDim2.new(0,0,1,0),
		BackgroundColor3=T.Good, BorderSizePixel=0, ZIndex=4}, o.hpBg)
	o.tracer = new("Frame", {Size=UDim2.new(0,0,0,1), AnchorPoint=Vector2.new(0,0.5), BackgroundColor3=T.Accent,
		BackgroundTransparency=0.4, BorderSizePixel=0, Visible=false, ZIndex=1}, espFolder)
	return o
end
local ballEsp = makeEsp("BALL")
local function hideEsp(o)
	o.box.Visible=false; o.name.Visible=false; o.dist.Visible=false; o.hpBg.Visible=false; o.tracer.Visible=false
end

local function updateEsp()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP then
			local o = espObjs[p]
			if not o then o = makeEsp(p.DisplayName); espObjs[p] = o end
			local char = p.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if Config.BoxEsp and char and hrp and hum and hum.Health > 0 then
				local cf, size = char:GetBoundingBox()
				local minX, minY, maxX, maxY
				for xi=-1,1,2 do for yi=-1,1,2 do for zi=-1,1,2 do
					local s = project(cf * Vector3.new(size.X/2*xi, size.Y/2*yi, size.Z/2*zi))
					if s then
						minX = minX and math.min(minX,s.X) or s.X
						minY = minY and math.min(minY,s.Y) or s.Y
						maxX = maxX and math.max(maxX,s.X) or s.X
						maxY = maxY and math.max(maxY,s.Y) or s.Y
					end
				end end end
				if minX then
					local w, h = maxX-minX, maxY-minY
					o.box.Visible = true
					o.box.Position = UDim2.fromOffset(minX, minY)
					o.box.Size = UDim2.fromOffset(w, h)
					o.stroke.Color = Config.EspColor
					o.fill.BackgroundColor3 = Config.EspColor
					o.fill.BackgroundTransparency = Config.EspFill and Config.EspFillAlpha or 1
					o.name.Visible = Config.NameEsp
					if Config.NameEsp then
						o.name.Text = p.DisplayName
						o.name.Position = UDim2.fromOffset(minX+w/2, minY-2)
					end
					o.dist.Visible = Config.DistEsp
					if Config.DistEsp then
						o.dist.Text = string.format("%d studs", math.floor((hrp.Position - Camera.CFrame.Position).Magnitude))
						o.dist.Position = UDim2.fromOffset(minX+w/2, maxY+2)
					end
					o.hpBg.Visible = Config.HealthEsp
					if Config.HealthEsp then
						o.hpBg.Position = UDim2.fromOffset(minX-6, minY)
						o.hpBg.Size = UDim2.fromOffset(3, h)
						local r = math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1)
						o.hp.Size = UDim2.new(1,0,r,0)
						o.hp.BackgroundColor3 = Color3.fromRGB(255,105,105):Lerp(Color3.fromRGB(120,255,165), r)
					end
					o.tracer.Visible = Config.Tracers
					if Config.Tracers then
						local from = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
						local to = Vector2.new(minX+w/2, maxY)
						local d = to - from
						local len = d.Magnitude
						o.tracer.Position = UDim2.fromOffset((from.X+to.X)/2-len/2, (from.Y+to.Y)/2)
						o.tracer.Size = UDim2.fromOffset(len, 1)
						o.tracer.Rotation = math.deg(math.atan2(d.Y, d.X))
						o.tracer.BackgroundColor3 = Config.EspColor
					end
				else hideEsp(o) end
			else hideEsp(o) end
		end
	end
	local ball = getBall()
	if Config.BallEsp and ball then
		local s = project(ball.Position)
		if s then
			local r = 22
			ballEsp.box.Visible = true
			ballEsp.box.Position = UDim2.fromOffset(s.X-r, s.Y-r)
			ballEsp.box.Size = UDim2.fromOffset(r*2, r*2)
			ballEsp.stroke.Color = Config.BallEspColor
			ballEsp.name.Visible = true
			ballEsp.name.Text = "BALL"
			ballEsp.name.TextColor3 = Config.BallEspColor
			ballEsp.name.Position = UDim2.fromOffset(s.X, s.Y-r-2)
		else hideEsp(ballEsp) end
	else hideEsp(ballEsp) end
end
bind(RunService.RenderStepped, function() pcall(updateEsp) end)
bind(Players.PlayerRemoving, function(p)
	local o = espObjs[p]
	if o then for _, v in pairs(o) do if typeof(v)=="Instance" then pcall(function() v:Destroy() end) end end; espObjs[p]=nil end
end)

--=============================================================
-- EXTRAS
--=============================================================
local function updateExtras()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP then
			local char = p.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if char then
				local h = char:FindFirstChild("ScriptSleepHL")
				if Config.Highlights then
					if not h then
						h = Instance.new("Highlight")
						h.Name = "ScriptSleepHL"
						h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
						h.FillTransparency = 0.72; h.OutlineTransparency = 0
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
						ad.Name = "ScriptSleepHitbox"; ad.Adornee = hrp
						ad.Size = Vector3.new(4,6,2.5); ad.AlwaysOnTop = true
						ad.ZIndex = 5; ad.Transparency = 0.65; ad.Parent = hrp
					end
					ad.Color3 = Config.EspColor
				elseif ad then ad:Destroy() end
			end
		end
	end
end

local function applyHeadless()
	local head = LP.Character and LP.Character:FindFirstChild("Head")
	if not head then return end
	local a = Config.Headless and 1 or 0
	if head:IsA("BasePart") then head.Transparency = a end
	for _, d in ipairs(head:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then d.Transparency = a end
	end
end
bind(LP.CharacterAdded, function() task.wait(0.6); pcall(applyHeadless) end)

--=============================================================
-- KORBLOX LEG
--=============================================================
local KORBLOX_TAG = "SSKorblox"
local korbloxSaved = {}    -- part -> {mesh, tex, size, trans, color}
local korbloxHidden = {}   -- part -> origTransparency

local KORBLOX_PRESETS = {
	{name = "Korblox A", mesh = "rbxassetid://169177037", tex = ""},
	{name = "Korblox B", mesh = "rbxassetid://139607718", tex = ""},
	{name = "Korblox C", mesh = "rbxassetid://169177045", tex = ""},
	{name = "Korblox D", mesh = "rbxassetid://135080259", tex = ""},
}

local function korbloxWantMesh()
	return (Config.KorbloxMesh ~= "" and Config.KorbloxMesh) or "rbxassetid://169177037"
end

local function findSideParts(side)
	local char = LP.Character
	if not char then return {} end
	local want = side:lower()
	local out = {}
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			local n = d.Name:lower()
			if n:find(want, 1, true) and (n:find("leg", 1, true) or n:find("foot", 1, true) or n:find("thigh", 1, true) or n:find("shin", 1, true)) then
				table.insert(out, d)
			end
		end
	end
	return out
end

local function restoreKorblox()
	for part, data in pairs(korbloxSaved) do
		if part.Parent then
			pcall(function()
				if part:IsA("MeshPart") then
					if data.mesh and data.mesh ~= "" then part.MeshId = data.mesh end
					if data.tex then part.TextureID = data.tex end
					if data.size then part.Size = data.size end
					if data.trans then part.Transparency = data.trans end
					if data.color then part.Color = data.color end
				else
					if data.size then part.Size = data.size end
					if data.trans then part.Transparency = data.trans end
					if data.color then part.Color = data.color end
					local m = part:FindFirstChild(KORBLOX_TAG)
					if m then m:Destroy() end
				end
			end)
		end
	end
	korbloxSaved = {}
	for part, orig in pairs(korbloxHidden) do
		if part.Parent then pcall(function() part.Transparency = orig end) end
	end
	korbloxHidden = {}
	local char = LP.Character
	if char then
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("SpecialMesh") and d.Name == KORBLOX_TAG then d:Destroy() end
		end
	end
end

local function hidePart(part)
	if not part then return end
	if korbloxHidden[part] == nil then korbloxHidden[part] = part.Transparency end
	part.Transparency = 1
end

local function applyKorblox()
	local char = LP.Character
	if not char then return end
	restoreKorblox()
	if not Config.Korblox then return end

	local th = math.clamp(Config.KorbloxThin, 0.05, 1.6)
	local sc = math.clamp(Config.KorbloxScale, 0.4, 2.5)
	local meshId = korbloxWantMesh()

	local parts = findSideParts(Config.KorbloxSide)
	local legs, feet = {}, {}
	for _, d in ipairs(parts) do
		if d.Name:lower():find("foot", 1, true) then table.insert(feet, d) else table.insert(legs, d) end
	end
	if #legs == 0 then
		local hum = char:FindFirstChildOfClass("Humanoid")
		notify("korblox: leg not found (rig=" .. tostring(hum and hum.RigType) .. ")", T.Warn)
		return
	end

	-- какие части получают меш
	local useLegs = legs
	if not Config.KorbloxFullLeg then useLegs = {legs[1]} end

	for _, leg in ipairs(useLegs) do
		if leg:IsA("MeshPart") then
			korbloxSaved[leg] = {mesh = leg.MeshId, tex = leg.TextureID, size = leg.Size,
				trans = leg.Transparency, color = leg.Color}
			leg.MeshId = meshId
			if Config.KorbloxTexture ~= "" then leg.TextureID = Config.KorbloxTexture end
			leg.Size = Vector3.new(leg.Size.X * th, leg.Size.Y * sc, leg.Size.Z * th)
			leg.Transparency = 0
			if Config.KorbloxBone then leg.Color = BONE_WHITE end
		else
			korbloxSaved[leg] = {size = leg.Size, trans = leg.Transparency, color = leg.Color}
			local m = leg:FindFirstChild(KORBLOX_TAG)
			if not m then
				m = Instance.new("SpecialMesh")
				m.Name = KORBLOX_TAG
				m.MeshType = Enum.MeshType.FileMesh
				m.Parent = leg
			end
			m.MeshId = meshId
			if Config.KorbloxTexture ~= "" then m.TextureId = Config.KorbloxTexture end
			m.Scale = Vector3.new(th * sc, sc, th * sc)
			leg.Transparency = 0
			if Config.KorbloxBone then leg.Color = BONE_WHITE end
		end
	end

	-- спрятать всё, что не получило меш
	for _, leg in ipairs(legs) do
		if not table.find(useLegs, leg) then hidePart(leg) end
	end
	if Config.KorbloxHideFoot then
		for _, f in ipairs(feet) do hidePart(f) end
	end
end

local function korbloxOk()
	local char = LP.Character
	if not char then return true end
	local parts = findSideParts(Config.KorbloxSide)
	if #parts == 0 then return true end
	local leg
	for _, p in ipairs(parts) do
		if not p.Name:lower():find("foot", 1, true) then leg = p; break end
	end
	if not leg then return true end
	local applied = korbloxSaved[leg] ~= nil or leg:FindFirstChild(KORBLOX_TAG) ~= nil
	if Config.Korblox ~= applied then return false end
	if not Config.Korblox then return true end
	local want = korbloxWantMesh()
	if leg:IsA("MeshPart") then
		if leg.MeshId ~= want then return false end
		if Config.KorbloxBone and leg.Color ~= BONE_WHITE then return false end
		return true
	end
	local m = leg:FindFirstChild(KORBLOX_TAG)
	return m ~= nil and m.MeshId == want
end

bind(LP.CharacterAdded, function() task.wait(0.9); pcall(applyKorblox) end)

--=============================================================
-- SKY / PARTICLES / BALL
--=============================================================
local SkyPresets = {
	Default = {ClockTime=14, Brightness=2, Ambient=Color3.fromRGB(70,70,70), Outdoor=Color3.fromRGB(128,128,128), Sky=true},
	Night   = {ClockTime=0, Brightness=1, Ambient=Color3.fromRGB(28,28,45), Outdoor=Color3.fromRGB(40,40,70), Sky=true},
	Blood   = {ClockTime=17, Brightness=1.5, Ambient=Color3.fromRGB(80,20,20), Outdoor=Color3.fromRGB(120,40,40), Sky=true},
	Black   = {ClockTime=12, Brightness=0.25, Ambient=Color3.new(0,0,0), Outdoor=Color3.new(0,0,0), Sky=false},
	Neon    = {ClockTime=2, Brightness=1, Ambient=Color3.fromRGB(40,20,90), Outdoor=Color3.fromRGB(70,35,140), Sky=true},
	Vapor   = {ClockTime=6, Brightness=2, Ambient=Color3.fromRGB(95,55,115), Outdoor=Color3.fromRGB(160,95,180), Sky=true},
}
local function applySky(name)
	local pr = SkyPresets[name] or SkyPresets.Default
	Lighting.ClockTime = pr.ClockTime; Lighting.Brightness = pr.Brightness
	Lighting.Ambient = pr.Ambient; Lighting.OutdoorAmbient = pr.Outdoor
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if pr.Sky then
		if not sky then
			sky = Instance.new("Sky")
			sky.SkyboxUp="rbxassetid://159454299"; sky.SkyboxDn="rbxassetid://159454296"
			sky.SkyboxLf="rbxassetid://159454293"; sky.SkyboxRt="rbxassetid://159454286"
			sky.SkyboxFt="rbxassetid://159454300"; sky.SkyboxBk="rbxassetid://159454288"
			sky.Parent = Lighting
		end
	elseif sky then sky:Destroy() end
end
local function applyParticles()
	local targets = {}
	local ball = getBall(); if ball then table.insert(targets, ball) end
	local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
	if hrp then table.insert(targets, hrp) end
	for _, part in ipairs(targets) do
		local p = part:FindFirstChild("ScriptSleepParticles")
		if Config.Particles then
			if not p then
				p = Instance.new("ParticleEmitter")
				p.Name = "ScriptSleepParticles"; p.Texture = "rbxassetid://243660364"
				p.Lifetime = NumberRange.new(0.6); p.Speed = NumberRange.new(1.5)
				p.SpreadAngle = Vector2.new(180,180); p.LightEmission = 1
				p.Size = NumberSequence.new(0.6,0); p.Parent = part
			end
			p.Rate = Config.ParticleRate; p.Color = ColorSequence.new(Config.ParticleColor)
		elseif p then p:Destroy() end
	end
end
local function applyBallSkin()
	local ball = getBall()
	if not ball or not ball:IsA("BasePart") or not Config.BallRecolor then return end
	ball.Color = Config.BallColor
	local base = ball:GetAttribute("ScriptSleepBaseSize")
	if not base then base = ball.Size; ball:SetAttribute("ScriptSleepBaseSize", base) end
	ball.Size = base * Config.BallSize
end

--=============================================================
-- HUD
--=============================================================
local fps, frames, timer = 0, 0, tick()
bind(RunService.RenderStepped, function()
	frames += 1
	if tick() - timer >= 1 then fps, frames, timer = frames, 0, tick() end
end)

local function applyFpsBoost(on)
	if on then
		pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
		Lighting.GlobalShadows = false
		Lighting.ShadowSoftness = 0
		pcall(function() setfpscap(240) end)
	else Lighting.GlobalShadows = true end
end

local hud = new("Frame", {Size=UDim2.new(0,275,0,88), Position=UDim2.new(0,12,0,12),
	BackgroundColor3=T.Bg, BackgroundTransparency=0.15, BorderSizePixel=0, Visible=Config.Hud, ZIndex=10}, gui)
corner(hud,8); stroke(hud,T.Line)
new("TextLabel", {Size=UDim2.new(1,-16,0,16), Position=UDim2.new(0,10,0,5), BackgroundTransparency=1,
	Font=Enum.Font.GothamBold, TextSize=11, TextColor3=T.Text, TextXAlignment=Enum.TextXAlignment.Left, Text=TITLE}, hud)
local hudStats = new("TextLabel", {Size=UDim2.new(1,-16,0,16), Position=UDim2.new(0,10,0,21), BackgroundTransparency=1,
	Font=Enum.Font.Gotham, TextSize=11, TextColor3=T.Dim, TextXAlignment=Enum.TextXAlignment.Left, Text="FPS: --  |  PING: -- ms"}, hud)
local hudParry = new("TextLabel", {Size=UDim2.new(1,-16,0,14), Position=UDim2.new(0,10,0,38), BackgroundTransparency=1,
	Font=Enum.Font.Gotham, TextSize=10, TextColor3=T.Dim, TextXAlignment=Enum.TextXAlignment.Left, Text=""}, hud)
local hudAbility = new("TextLabel", {Size=UDim2.new(1,-16,0,14), Position=UDim2.new(0,10,0,52), BackgroundTransparency=1,
	Font=Enum.Font.GothamBold, TextSize=10, TextColor3=T.Warn, TextXAlignment=Enum.TextXAlignment.Left, Text="", Visible=false}, hud)
local hudDebug = new("TextLabel", {Size=UDim2.new(1,-16,0,14), Position=UDim2.new(0,10,0,66), BackgroundTransparency=1,
	Font=Enum.Font.Gotham, TextSize=10, TextColor3=T.Warn, TextXAlignment=Enum.TextXAlignment.Left, Text="", Visible=false}, hud)

task.spawn(function()
	while gui.Parent do
		hud.Visible = Config.Hud
		local ping = math.floor(getPing())
		hudStats.Text = string.format("FPS: %d  |  PING: %d ms", fps, ping)
		hudStats.TextColor3 = ping < 80 and T.Good or (ping < 160 and T.Dim or T.Bad)
		hudParry.Text = string.format("in %s | acts %d | spd %d | R %d", E.mode, E.actions, math.floor(E.speed), math.floor(E.radius))
		hudParry.TextColor3 = E.boosted and RingBoost or (E.hot and T.Good or (hasKeypress and T.Dim or T.Bad))
		hudAbility.Visible = Config.ShowAbility and E.boosted
		if hudAbility.Visible then hudAbility.Text = "ABILITY >> " .. tostring(E.ability) end
		hudDebug.Visible = Config.Debug and Config.Hud
		if Config.Debug then
			hudDebug.Text = string.format("d %d | cross %.3f | tgt %s | %s",
				math.floor(E.dist), E.lead, tostring(E.targeted), Config.InputMode)
		end
		task.wait(0.25)
	end
end)

--=============================================================
-- TABS
--=============================================================
local cp, ca = newTab("Combat")
ca(section(cp, "Auto Parry"))
ca((toggle(cp, "Auto Parry", Config.AutoParry, function(v) Config.AutoParry = v end)))
ca((dropdown(cp, "Input Mode", {"Auto", "Keypress", "Mouse", "Remote"}, Config.InputMode, function(v) Config.InputMode = v end)))
ca((dropdown(cp, "Parry Key", {"F", "E", "Q", "R", "V", "C", "Space"}, Config.ParryKey, function(v) Config.ParryKey = v end)))
ca((toggle(cp, "Require Ball Targeting Me", Config.RequireTarget, function(v) Config.RequireTarget = v end)))
ca((toggle(cp, "One Parry Per Ball", Config.OnePerBall, function(v) Config.OnePerBall = v end)))

ca(section(cp, "Abilities"))
ca((toggle(cp, "Ability Guard", Config.AbilityGuard, function(v) Config.AbilityGuard = v end)))
ca((toggle(cp, "Detect Speed Spike", Config.BoostDetect, function(v) Config.BoostDetect = v end)))
ca((slider(cp, "Boost Radius Mult", 1.0, 3.0, Config.BoostMult, 2, function(v) Config.BoostMult = v end)))
ca((slider(cp, "Boost Hold (s)", 0.15, 2.0, Config.BoostHold, 2, function(v) Config.BoostHold = v end)))
ca((toggle(cp, "Show Ability In HUD", Config.ShowAbility, function(v) Config.ShowAbility = v end)))
ca((button(cp, "Scan Game Abilities", function()
	local out = scanGameAbilities()
	notify("abilities found: " .. #out, #out > 0 and T.Good or T.Warn)
	if #out > 0 then print("[" .. TITLE .. "] abilities: " .. table.concat(out, ", ")) end
end)))
ca((button(cp, "Show Known Abilities", function()
	local out = {}
	for n in pairs(abilityKnown) do table.insert(out, n) end
	table.sort(out)
	print("[" .. TITLE .. "] known abilities (" .. #out .. "): " .. table.concat(out, ", "))
	notify("known abilities: " .. #out .. " (см. консоль)", T.Dim)
end)))

ca(section(cp, "Adaptive Radius"))
ca((toggle(cp, "Auto Radius (follow ball speed)", Config.AutoRadius, function(v) Config.AutoRadius = v end)))
ca((slider(cp, "Lead Time (s)", 0.03, 0.35, Config.LeadTime, 3, function(v) Config.LeadTime = v end)))
ca((slider(cp, "Min Radius", 4, 30, Config.MinRadius, 0, function(v) Config.MinRadius = v end)))
ca((slider(cp, "Max Radius", 10, 90, Config.MaxRadius, 0, function(v) Config.MaxRadius = v end)))
ca((toggle(cp, "Cross Trigger (exact edge)", Config.CrossTrigger, function(v) Config.CrossTrigger = v end)))
ca((toggle(cp, "Ping Compensation", Config.PingComp, function(v) Config.PingComp = v end)))
ca((slider(cp, "Fixed Radius (manual)", 4, 60, Config.BaseRadius, 0, function(v) Config.BaseRadius = v end)))

ca(section(cp, "Parry Circle"))
ca((toggle(cp, "Show Circle", Config.ParryRing, function(v) Config.ParryRing = v end)))
ca((dropdown(cp, "Circle Color", {"Purple","White","Red","Cyan","Green","Gold"}, Config.RingColor, function(v) Config.RingColor = v end)))
ca((slider(cp, "Circle Thickness", 0.01, 0.30, Config.RingThick, 2, function(v) Config.RingThick = v end)))
ca((slider(cp, "Circle Opacity", 0, 0.9, Config.RingOpacity, 2, function(v) Config.RingOpacity = v end)))

ca(section(cp, "Reaction Speed"))
ca((toggle(cp, "Speed Assist (fast ball)", Config.SpeedAssist, function(v) Config.SpeedAssist = v end)))
ca((slider(cp, "Fast Boost", 0, 1, Config.FastBoost, 2, function(v) Config.FastBoost = v end)))
ca((slider(cp, "Actions / sec", 10, 120, Config.ActionsPerSec, 0, function(v) Config.ActionsPerSec = v end)))
ca((dropdown(cp, "Batch Mode", {"Extremely Fast", "Fast", "Normal", "Safe"}, Config.BatchMode, function(v) Config.BatchMode = v end)))
ca((button(cp, "Test Parry", function()
	E.lastAction = 0
	local m = performParry()
	notify("input -> " .. tostring(m), T.Good)
end)))

local bp, ba = newTab("Bypass")
ba(section(bp, "Input (BAC bypass)"))
ba((button(bp, "MAX STEALTH", function()
	Config.InputMode = "Keypress"; Config.ActionsPerSec = 45; Config.BatchMode = "Normal"
	Config.RequireTarget = true; Config.AutoRadius = true; Config.LeadTime = 0.13
	Config.SpeedAssist = true; Config.AbilityGuard = true
	Config.Headless = false; Config.Particles = false; Config.BallRecolor = false
	notify("stealth armed", T.Good)
end)))
ba((button(bp, "MAX SPEED", function()
	Config.InputMode = "Keypress"; Config.ActionsPerSec = 90; Config.BatchMode = "Extremely Fast"
	Config.RequireTarget = true; Config.AutoRadius = true; Config.LeadTime = 0.11
	Config.SpeedAssist = true; Config.FastBoost = 0.8; Config.AbilityGuard = true; Config.BoostMult = 2.0
	notify("speed armed", T.Good)
end)))
ba((button(bp, "Show Input Backend", function()
	notify("keypress: " .. tostring(hasKeypress) .. " | mouse: " .. tostring(hasMouse), T.Warn)
end)))
ba((button(bp, "Find Parry Remote", function()
	findRemote()
	notify(ParryRemote and ("found: " .. ParryRemote:GetFullName()) or "not found", ParryRemote and T.Good or T.Bad)
end)))
ba((toggle(bp, "Debug Readout", Config.Debug, function(v) Config.Debug = v end)))

local vp, va = newTab("Visuals")
va(section(vp, "ESP"))
va((toggle(vp, "Box ESP", Config.BoxEsp, function(v) Config.BoxEsp = v end)))
va((toggle(vp, "Box Fill", Config.EspFill, function(v) Config.EspFill = v end)))
va((toggle(vp, "Name ESP", Config.NameEsp, function(v) Config.NameEsp = v end)))
va((toggle(vp, "Distance ESP", Config.DistEsp, function(v) Config.DistEsp = v end)))
va((toggle(vp, "Health Bar", Config.HealthEsp, function(v) Config.HealthEsp = v end)))
va((toggle(vp, "Tracers", Config.Tracers, function(v) Config.Tracers = v end)))
va((toggle(vp, "Highlights", Config.Highlights, function(v) Config.Highlights = v end)))
va((toggle(vp, "Hitboxes 3D", Config.Hitboxes, function(v) Config.Hitboxes = v end)))
va((dropdown(vp, "ESP Color", {"White","Red","Cyan","Lime","Purple","Gold"}, "White", function(v)
	local m = {White=Color3.fromRGB(255,255,255),Red=Color3.fromRGB(255,80,80),Cyan=Color3.fromRGB(80,230,255),
		Lime=Color3.fromRGB(140,255,140),Purple=Color3.fromRGB(190,130,255),Gold=Color3.fromRGB(255,210,90)}
	Config.EspColor = m[v] or Color3.new(1,1,1)
end)))
va((toggle(vp, "Ball ESP", Config.BallEsp, function(v) Config.BallEsp = v end)))
va((dropdown(vp, "Ball ESP Color", {"Red","White","Cyan","Gold","Magenta"}, "Red", function(v)
	local m = {Red=Color3.fromRGB(255,90,90),White=Color3.fromRGB(255,255,255),Cyan=Color3.fromRGB(90,230,255),
		Gold=Color3.fromRGB(255,210,90),Magenta=Color3.fromRGB(255,110,240)}
	Config.BallEspColor = m[v] or Color3.fromRGB(255,90,90)
end)))

va(section(vp, "Character"))
va((toggle(vp, "Headless", Config.Headless, function(v) Config.Headless = v; applyHeadless() end)))
va((toggle(vp, "Fullbright", Config.Fullbright, function(v)
	Config.Fullbright = v
	if v then
		Lighting.Ambient = Color3.fromRGB(200,200,200); Lighting.OutdoorAmbient = Color3.fromRGB(200,200,200)
		Lighting.Brightness = 2; Lighting.GlobalShadows = false
	else applySky(Config.SkyPreset) end
end)))

va(section(vp, "Korblox Leg"))
va((toggle(vp, "Wear Korblox Leg", Config.Korblox, function(v) Config.Korblox = v; applyKorblox() end)))
va((dropdown(vp, "Side", {"Right", "Left"}, Config.KorbloxSide, function(v) Config.KorbloxSide = v; applyKorblox() end)))
local presetNames = {}
for _, p in ipairs(KORBLOX_PRESETS) do table.insert(presetNames, p.name) end
table.insert(presetNames, "Custom")
va((dropdown(vp, "Mesh Preset", presetNames, "Korblox A", function(v)
	for _, p in ipairs(KORBLOX_PRESETS) do
		if p.name == v then
			Config.KorbloxMesh = p.mesh
			Config.KorbloxTexture = p.tex
			applyKorblox()
			notify("preset: " .. v, T.Good)
			return
		end
	end
end)))
va((textbox(vp, "Mesh ID", Config.KorbloxMesh, "rbxassetid://...", function(v) Config.KorbloxMesh = v; applyKorblox() end)))
va((textbox(vp, "Texture ID", Config.KorbloxTexture, "rbxassetid://...", function(v) Config.KorbloxTexture = v; applyKorblox() end)))
va((toggle(vp, "Bone White", Config.KorbloxBone, function(v) Config.KorbloxBone = v; applyKorblox() end)))
va((toggle(vp, "Full Leg (бедро+голень)", Config.KorbloxFullLeg, function(v) Config.KorbloxFullLeg = v; applyKorblox() end)))
va((slider(vp, "Thinness", 0.05, 1.6, Config.KorbloxThin, 2, function(v) Config.KorbloxThin = v; applyKorblox() end)))
va((slider(vp, "Scale (длина)", 0.4, 2.5, Config.KorbloxScale, 2, function(v) Config.KorbloxScale = v; applyKorblox() end)))
va((toggle(vp, "Hide Foot", Config.KorbloxHideFoot, function(v) Config.KorbloxHideFoot = v; applyKorblox() end)))
va((button(vp, "Korblox: Reapply", function() applyKorblox(); notify("korblox reapplied", T.Good) end)))
va((button(vp, "Korblox: Remove", function() restoreKorblox(); notify("korblox removed", T.Good) end)))

va(section(vp, "Ball Look"))
va((toggle(vp, "Recolor Ball", Config.BallRecolor, function(v) Config.BallRecolor = v end)))
va((slider(vp, "Ball Size", 0.5, 3, Config.BallSize, 2, function(v) Config.BallSize = v end)))

local wp, wa = newTab("World")
wa((dropdown(wp, "Sky Preset", {"Default","Night","Blood","Black","Neon","Vapor"}, Config.SkyPreset, function(v)
	Config.SkyPreset = v; applySky(v)
end)))
wa((slider(wp, "Clock Time", 0, 24, Config.ClockTime, 0, function(v) Config.ClockTime = v; Lighting.ClockTime = v end)))
wa((slider(wp, "Brightness", 0, 5, Config.Brightness, 1, function(v) Config.Brightness = v; Lighting.Brightness = v end)))
wa((toggle(wp, "Particles", Config.Particles, function(v) Config.Particles = v; applyParticles() end)))
wa((slider(wp, "Particle Rate", 5, 200, Config.ParticleRate, 0, function(v) Config.ParticleRate = v; applyParticles() end)))

local mp, ma = newTab("Misc")
ma((slider(mp, "Field of View", 40, 120, Config.Fov, 0, function(v) Config.Fov = v end)))
ma((toggle(mp, "FPS Booster", Config.FpsBoost, function(v) Config.FpsBoost = v; applyFpsBoost(v) end)))
ma((toggle(mp, "FPS / Ping HUD", Config.Hud, function(v) Config.Hud = v end)))
ma((toggle(mp, "Anti AFK", Config.AntiAfk, function(v) Config.AntiAfk = v end)))
local keyBtn
keyBtn = ma((button(mp, "Menu Key: "..Config.MenuKey.Name, function()
	local c
	c = UserInputService.InputBegan:Connect(function(i, gp)
		if gp then return end
		if i.UserInputType == Enum.UserInputType.Keyboard then
			Config.MenuKey = i.KeyCode
			keyBtn.Text = "Menu Key: "..i.KeyCode.Name
			c:Disconnect(); queueSave()
		end
	end)
end)))
ma((button(mp, "Save Config", function() saveConfig(); notify("saved", T.Good) end)))
ma((button(mp, "Unload Script", function()
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	pcall(restoreKorblox)
	pcall(function() gui:Destroy() end)
	pcall(function()
		Lighting.ClockTime = 14; Lighting.Brightness = 2
		Lighting.Ambient = Color3.fromRGB(70,70,70); Lighting.OutdoorAmbient = Color3.fromRGB(128,128,128)
		Lighting.GlobalShadows = true
		if Workspace.CurrentCamera then Workspace.CurrentCamera.FieldOfView = 70 end
	end)
end)))

--=============================================================
-- OPEN / CLOSE + LOOPS
--=============================================================
local function setMenu(o) Config.MenuOpen = o; window.Visible = o; queueSave() end
closeBtn.MouseButton1Click:Connect(function() setMenu(false) end)
minBtn.MouseButton1Click:Connect(function() setMenu(false) end)
bind(UserInputService.InputBegan, function(i, gp)
	if gp then return end
	if i.KeyCode == Config.MenuKey then setMenu(not window.Visible) end
end)

local fb = new("TextButton", {Size=UDim2.new(0,36,0,36), Position=UDim2.new(0,12,0,110),
	BackgroundColor3=T.Bg, Text="𝒮", Font=Enum.Font.GothamBold, TextSize=17,
	TextColor3=T.Text, AutoButtonColor=false, BorderSizePixel=0, ZIndex=11}, gui)
corner(fb,18); stroke(fb,T.Line)
fb.MouseButton1Click:Connect(function() setMenu(not window.Visible) end)

for n, t in pairs(tabs) do
	local on = (n == "Combat")
	t.page.Visible = on
	t.btn.TextColor3 = on and T.Text or T.Dim
	t.ind.Size = on and UDim2.new(0,2,0,16) or UDim2.new(0,2,0,0)
end

task.spawn(function() while gui.Parent do pcall(updateExtras); task.wait(0.35) end end)
task.spawn(function() while gui.Parent do pcall(applyParticles); pcall(applyBallSkin); task.wait(0.5) end end)
task.spawn(function() while gui.Parent do findRemote(); task.wait(5) end end)

task.spawn(function()
	while gui.Parent do
		pcall(function() if not korbloxOk() then applyKorblox() end end)
		task.wait(0.8)
	end
end)

task.spawn(function()
	while gui.Parent do
		if E.seenCount > 400 then E.seenAbility = {}; E.seenCount = 0 end
		task.wait(10)
	end
end)

bind(RunService.RenderStepped, function()
	local cam = Workspace.CurrentCamera
	if cam and math.abs(cam.FieldOfView - Config.Fov) > 0.1 then cam.FieldOfView = Config.Fov end
	local char = LP.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if Config.ParryRing and root and inMatch() then
		local r = E.radius or Config.BaseRadius
		ring.Adornee = root
		ring.Radius = r
		ring.InnerRadius = math.max(0.05, r * (1 - Config.RingThick))
		ring.Color3 = E.boosted and RingBoost or (E.hot and RingHot or (RingColors[Config.RingColor] or RingColors.Purple))
		ring.Transparency = (E.hot or E.boosted) and math.max(0.05, Config.RingOpacity - 0.15) or Config.RingOpacity
		ring.Visible = true
	else
		ring.Visible = false
	end
end)

bind(LP.Idled, function()
	if Config.AntiAfk then
		pcall(function()
			game:GetService("VirtualUser"):CaptureController()
			game:GetService("VirtualUser"):ClickButton2(Vector2.new())
		end)
	end
end)

local function cycle(dt) pcall(step, dt) end
if RunService.PreSimulation then bind(RunService.PreSimulation, cycle) end
bind(RunService.RenderStepped, cycle)
bind(RunService.Heartbeat, cycle)

task.spawn(function()
	task.wait(0.5)
	pcall(applySky, Config.SkyPreset)
	pcall(applyHeadless)
	pcall(applyKorblox)
	if Config.FpsBoost then pcall(applyFpsBoost, true) end
	notify(TITLE .. " loaded | abilities: " .. #discovered .. " | input: " .. (hasKeypress and "keypress" or (hasMouse and "mouse" or "remote")), T.Good)
	print("[" .. TITLE .. "] discovered abilities=" .. #discovered .. " keypress=" .. tostring(hasKeypress))
end)
