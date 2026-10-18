--[[
    𝒮𝒸𝓇𝒾𝓅𝓉𝒮𝓁𝑒𝑒𝓅  |  BLADE BALL
    input-based bypass + collision-course parry
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
local TITLE  = "𝒮𝒸𝓇𝒾𝓅𝓉𝒮𝓁𝑒𝑒𝓅"

--=============================================================
-- CONFIG
--=============================================================
local Config = {
	AutoParry     = true,
	InputMode     = "Auto",
	ParryKey      = "F",
	ActionsPerSec = 45,
	BatchMode     = "Fast",

	BaseRadius    = 16,
	Prediction    = 0.08,
	Horizon       = 0.45,
	PingComp      = true,
	PingRadiusCap = 22,

	FakeReject    = true,
	HitTolerance  = 9,
	MoveComp      = true,
	RequireTarget = true,
	ForceFire     = false,

	Debug         = false,

	ParryRing     = true,
	RingColor     = "Purple",
	RingThick     = 0.06,

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

	SwordMesh     = "",
	SwordTexture  = "",
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
	local b = new("Frame", {Size=UDim2.new(0,290,0,32), Position=UDim2.new(1,-310,0,12),
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
		Font=Enum.Font.GothamMedium, TextSize=12, TextColor3=T.Text,
		TextXAlignment=Enum.TextXAlignment.Left, Text=tostring(default)}, btn)
	local lh = #options*24+8
	local list = new("Frame", {Size=UDim2.new(0,130,0,lh), Position=UDim2.new(1,-130,0,32),
		BackgroundColor3=T.Panel, Visible=false, ZIndex=20, BorderSizePixel=0}, h)
	corner(list,6); stroke(list,T.Line)
	new("UIListLayout", {Padding=UDim.new(0,2), SortOrder=Enum.SortOrder.LayoutOrder}, list)
	new("UIPadding", {PaddingTop=UDim.new(0,4), PaddingBottom=UDim.new(0,4)}, list)
	local open = false
	for i,o in ipairs(options) do
		local b = new("TextButton", {Size=UDim2.new(1,0,0,22), BackgroundTransparency=1, Font=Enum.Font.GothamMedium,
			TextSize=12, TextColor3=T.Dim, Text=tostring(o), LayoutOrder=i, ZIndex=21}, list)
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
-- REMOTE + INPUT BACKEND
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
-- ENGINE STATE
--=============================================================
local E = {
	lastAction = 0, actions = 0,
	dist = 0, speed = 0, eta = 0, miss = 0, radius = 16,
	targeted = false, willHit = false, mode = "-", block = "-",
	seen = 0, blockedTarget = 0, blockedFake = 0,
}

--=============================================================
-- INPUT
--=============================================================
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
	local rate = math.clamp(Config.ActionsPerSec, 10, 100)
	local cd = 1 / rate
	if Config.BatchMode == "Safe" then cd = math.max(0.080, cd)
	elseif Config.BatchMode == "Normal" then cd = math.max(0.040, cd)
	elseif Config.BatchMode == "Fast" then cd = math.max(0.025, cd)
	elseif Config.BatchMode == "Extremely Fast" then cd = math.max(0.015, cd) end
	return math.max(0.012, cd + (math.random(-2, 4) / 1000))
end

local function sendAction(ball)
	local now = tick()
	if now - E.lastAction < actionCooldown() then return false end
	E.lastAction = now
	E.actions += 1
	E.block = "-"
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

local function ballVelocity(ball)
	local v = ball.AssemblyLinearVelocity
	local z = ball:FindFirstChild("zoomies")
	if z then
		if z:IsA("LinearVelocity") or z:IsA("VectorForce") then
			v = z.VectorVelocity
		elseif z:IsA("BodyVelocity") then
			v = z.Velocity
		end
	end
	if v.Magnitude <= 0.5 then v = ball.Velocity end
	return v
end

local function ballTargetAttr(ball)
	return ball:GetAttribute("target") or ball:GetAttribute("Target")
		or ball:GetAttribute("currentTarget") or ball:GetAttribute("targetPlayer")
		or ball:GetAttribute("to")
end

-- true / false / nil(неизвестно)
local function isTargeted(ball)
	local char = LP.Character
	if not ball or not char then return nil end

	local t = ballTargetAttr(ball)
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
			if v == LP.Name or v == char.Name or v == LP or v == LP.UserId
				or v == tostring(LP.UserId) then return true end
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

--=============================================================
-- PREDICTION
--=============================================================
local accelMap = {}

bind(RunService.Heartbeat, function()
	local folder = Workspace:FindFirstChild("Balls")
	if not folder then return end
	local now = tick()
	local live = {}
	for _, b in ipairs(folder:GetChildren()) do
		if b:IsA("BasePart") then
			live[b] = true
			local rec = accelMap[b]
			local v = ballVelocity(b)
			if rec then
				local dt = math.clamp(now - rec.t, 0.001, 0.05)
				rec.a = (v - rec.v) / dt
				rec.v = v
				rec.t = now
			else
				accelMap[b] = {v = v, t = now, a = Vector3.zero}
			end
		end
	end
	for b in pairs(accelMap) do
		if not live[b] and not b.Parent then accelMap[b] = nil end
	end
end)

local function transitTime(dt, speed)
	local pingSec = getPing() / 1000
	local horizon = (Config.Horizon or 0.45) * (Config.Prediction or 0.08)
	horizon += math.clamp((speed - 150) * 0.0003, 0, 0.12)
	return pingSec * 0.5 + math.clamp(dt or 0.016, 0.001, 0.033) * 0.5 + (1 / 60) + horizon
end

local function predictHit(ball, root, v, accel, transit)
	local speed = v.Magnitude
	if speed < 0.5 then return false, 999 end
	local dir = v / speed
	local playerVel = (Config.MoveComp and root.AssemblyLinearVelocity) or Vector3.zero
	local futurePlayer = root.Position + playerVel * transit
	local futureBall = ball.Position + v * transit + 0.5 * accel * (transit * transit)
	local toPlayer = futurePlayer - futureBall
	local proj = toPlayer.Dot(dir)
	if proj < -3 then return false, toPlayer.Magnitude end
	local closest = futureBall + dir * math.max(proj, 0)
	return (futurePlayer - closest).Magnitude <= Config.HitTolerance, (futurePlayer - closest).Magnitude
end

local function buildThreat(b, root, dt)
	local v = ballVelocity(b)
	local speed = v.Magnitude
	if speed <= 0.5 then return nil end
	local ballPos = b.Position
	local distance = (root.Position - ballPos).Magnitude
	local dirToPlayer = (root.Position - ballPos).Unit
	local rootVel = root.AssemblyLinearVelocity or Vector3.zero
	local accel = (accelMap[b] and accelMap[b].a) or Vector3.zero
	local transit = transitTime(dt, speed)
	local willHit, miss = predictHit(b, root, v, accel, transit)
	return {
		ball = b, distance = distance, speed = speed, velocity = v, accel = accel,
		dot = dirToPlayer.Dot(v.Unit),
		approachSpeed = (v - rootVel).Dot(dirToPlayer),
		miss = miss, willHit = willHit,
		eta = distance / math.max((v - rootVel).Dot(dirToPlayer), speed * 0.7, 1),
	}
end

local function pickThreat(root, dt)
	local folder = Workspace:FindFirstChild("Balls")
	if not folder then return nil, nil end
	local best, bestThreat, bestScore
	for _, b in ipairs(folder:GetChildren()) do
		if b:IsA("BasePart") then
			local t = buildThreat(b, root, dt)
			if t then
				E.seen += 1
				local tgt = isTargeted(b)
				local score = 0
				if tgt == true then score += 100000
				elseif tgt == nil then score += 30000 end
				if t.willHit then score += 50000 end
				score += math.clamp(1000 - t.distance, 0, 1000)
				if not bestScore or score > bestScore then best, bestThreat, bestScore = b, t, score end
			end
		end
	end
	return best, bestThreat
end

--=============================================================
-- MAIN STEP
--=============================================================
local function step(dt)
	if not Config.AutoParry or not inMatch() then return end
	local char = LP.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local ball, threat = pickThreat(root, dt)
	if not threat then E.block = "no ball" return end

	E.dist, E.speed, E.eta, E.miss = threat.distance, threat.speed, threat.eta, threat.miss

	local tgt = isTargeted(threat.ball)
	local heuristicTarget = threat.dot > 0.4 and threat.approachSpeed > 0
	E.targeted = (tgt == true) or (tgt == nil and heuristicTarget)
	E.willHit = threat.willHit

	-- радиус считается ДО проверок
	local pingSec = getPing() / 1000
	local radius = Config.BaseRadius
	if Config.PingComp then
		radius += math.clamp(threat.speed * (pingSec * 0.5 + 1 / 60), 0, Config.PingRadiusCap)
	end
	E.radius = radius

	if not Config.ForceFire then
		-- жёсткий запрет только если игра прямо сказала "цель — другой игрок"
		if Config.RequireTarget and tgt == false then
			E.block = "target"; E.blockedTarget += 1
			return
		end
		-- неизвестно и мяч уходит от нас
		if Config.RequireTarget and tgt == nil and not heuristicTarget then
			E.block = "target?"; E.blockedTarget += 1
			return
		end
		-- анти-фейк: только при ЯВНОМ промахе и снаружи внутренней зоны
		if Config.FakeReject and (not threat.willHit) and threat.miss > Config.HitTolerance * 1.8
			and threat.distance > radius * 0.8 then
			E.block = "fake"; E.blockedFake += 1
			return
		end
	end

	local dtStep = math.clamp(dt or 0.016, 0.001, 0.033)
	local transit = transitTime(dtStep, threat.speed)
	local playerVel = (Config.MoveComp and root.AssemblyLinearVelocity) or Vector3.zero
	local futurePlayer = root.Position + playerVel * transit
	local futureBall = threat.ball.Position + threat.velocity * transit + 0.5 * threat.accel * (transit * transit)
	local futureDist = (futurePlayer - futureBall).Magnitude

	local dirOk = threat.dot > 0.05 or threat.approachSpeed > -5

	-- 1) мяч уже в зоне
	if threat.distance <= radius and dirOk then
		sendAction(threat.ball)
		return
	end
	-- 2) предсказанный контакт в зоне
	if futureDist <= radius and dirOk then
		sendAction(threat.ball)
	end
end

--=============================================================
-- PARRY RING
--=============================================================
local ring = new("CylinderHandleAdornment", {
	Height = 0.05, Radius = Config.BaseRadius, InnerRadius = Config.BaseRadius - 0.5,
	Color3 = RingColors[Config.RingColor] or RingColors.Purple,
	Transparency = 0.3, AlwaysOnTop = true, ZIndex = 5,
	CFrame = CFrame.Angles(math.rad(90), 0, 0), Visible = false,
}, gui)

--=============================================================
-- ESP
--=============================================================
local espObjs = {}
local ballEspMap = {}

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
	o.name = new("TextLabel", {Size=UDim2.new(0,240,0,13), AnchorPoint=Vector2.new(0.5,1), BackgroundTransparency=1,
		Font=Enum.Font.GothamBold, TextSize=11, TextColor3=T.Text, TextStrokeTransparency=0,
		TextStrokeColor3=Color3.new(0,0,0), Text=label, Visible=false, ZIndex=3}, espFolder)
	o.dist = new("TextLabel", {Size=UDim2.new(0,240,0,13), AnchorPoint=Vector2.new(0.5,0), BackgroundTransparency=1,
		Font=Enum.Font.Gotham, TextSize=10, TextColor3=T.Dim, TextStrokeTransparency=0,
		TextStrokeColor3=Color3.new(0,0,0), Text="", Visible=false, ZIndex=3}, espFolder)
	o.hpBg = new("Frame", {Size=UDim2.new(0,3,1,0), BackgroundColor3=Color3.new(0,0,0), BorderSizePixel=0, Visible=false, ZIndex=3}, espFolder)
	o.hp = new("Frame", {Size=UDim2.new(1,0,1,0), AnchorPoint=Vector2.new(0,1), Position=UDim2.new(0,0,1,0),
		BackgroundColor3=T.Good, BorderSizePixel=0, ZIndex=4}, o.hpBg)
	o.tracer = new("Frame", {Size=UDim2.new(0,0,0,1), AnchorPoint=Vector2.new(0,0.5), BackgroundColor3=T.Accent,
		BackgroundTransparency=0.4, BorderSizePixel=0, Visible=false, ZIndex=1}, espFolder)
	return o
end

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

	local folder = Workspace:FindFirstChild("Balls")
	if Config.BallEsp and folder then
		local live = {}
		for _, ball in ipairs(folder:GetChildren()) do
			if ball:IsA("BasePart") then
				live[ball] = true
				local o = ballEspMap[ball]
				if not o then
					o = makeEsp("BALL")
					ballEspMap[ball] = o
				end
				local s = project(ball.Position)
				if s then
					local r = 22
					local tgt = isTargeted(ball) == true
					o.box.Visible = true
					o.box.Position = UDim2.fromOffset(s.X-r, s.Y-r)
					o.box.Size = UDim2.fromOffset(r*2, r*2)
					o.stroke.Color = tgt and Config.BallEspColor or T.Dim
					o.stroke.Thickness = tgt and 2 or 1
					o.name.Visible = true
					o.name.Text = tgt and "BALL <<" or "BALL"
					o.name.TextColor3 = tgt and Config.BallEspColor or T.Dim
					o.name.Position = UDim2.fromOffset(s.X, s.Y-r-2)
				else hideEsp(o) end
			end
		end
		for b, o in pairs(ballEspMap) do
			if not live[b] then
				for _, v in pairs(o) do if typeof(v)=="Instance" then pcall(function() v:Destroy() end) end end
				ballEspMap[b] = nil
			end
		end
	end
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
-- SKY / PARTICLES / SKIN
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
	local folder = Workspace:FindFirstChild("Balls")
	local targets = {}
	if folder then
		for _, b in ipairs(folder:GetChildren()) do
			if b:IsA("BasePart") then table.insert(targets, b) end
		end
	end
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
	local folder = Workspace:FindFirstChild("Balls")
	if not folder or not Config.BallRecolor then return end
	for _, ball in ipairs(folder:GetChildren()) do
		if ball:IsA("BasePart") then
			ball.Color = Config.BallColor
			local base = ball:GetAttribute("ScriptSleepBaseSize")
			if not base then base = ball.Size; ball:SetAttribute("ScriptSleepBaseSize", base) end
			ball.Size = base * Config.BallSize
		end
	end
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

local hud = new("Frame", {Size=UDim2.new(0,270,0,88), Position=UDim2.new(0,12,0,12),
	BackgroundColor3=T.Bg, BackgroundTransparency=0.15, BorderSizePixel=0, Visible=Config.Hud, ZIndex=10}, gui)
corner(hud,8); stroke(hud,T.Line)
new("TextLabel", {Size=UDim2.new(1,-16,0,16), Position=UDim2.new(0,10,0,5), BackgroundTransparency=1,
	Font=Enum.Font.GothamBold, TextSize=11, TextColor3=T.Text, TextXAlignment=Enum.TextXAlignment.Left, Text=TITLE}, hud)
local hudStats = new("TextLabel", {Size=UDim2.new(1,-16,0,16), Position=UDim2.new(0,10,0,21), BackgroundTransparency=1,
	Font=Enum.Font.Gotham, TextSize=11, TextColor3=T.Dim, TextXAlignment=Enum.TextXAlignment.Left, Text="FPS: --  |  PING: -- ms"}, hud)
local hudParry = new("TextLabel", {Size=UDim2.new(1,-16,0,14), Position=UDim2.new(0,10,0,38), BackgroundTransparency=1,
	Font=Enum.Font.Gotham, TextSize=10, TextColor3=T.Dim, TextXAlignment=Enum.TextXAlignment.Left, Text=""}, hud)
local hudDebug = new("TextLabel", {Size=UDim2.new(1,-16,0,14), Position=UDim2.new(0,10,0,53), BackgroundTransparency=1,
	Font=Enum.Font.Gotham, TextSize=10, TextColor3=T.Warn, TextXAlignment=Enum.TextXAlignment.Left, Text="", Visible=false}, hud)
local hudDebug2 = new("TextLabel", {Size=UDim2.new(1,-16,0,14), Position=UDim2.new(0,10,0,67), BackgroundTransparency=1,
	Font=Enum.Font.Gotham, TextSize=10, TextColor3=T.Warn, TextXAlignment=Enum.TextXAlignment.Left, Text="", Visible=false}, hud)

task.spawn(function()
	while gui.Parent do
		hud.Visible = Config.Hud
		local ping = math.floor(getPing())
		hudStats.Text = string.format("FPS: %d  |  PING: %d ms", fps, ping)
		hudStats.TextColor3 = ping < 80 and T.Good or (ping < 160 and T.Dim or T.Bad)
		hudParry.Text = string.format("in %s | acts %d | R %d | blk %s", E.mode, E.actions, math.floor(E.radius), E.block)
		hudParry.TextColor3 = (E.block == "-") and T.Good or T.Warn
		hudDebug.Visible = Config.Debug and Config.Hud
		hudDebug2.Visible = Config.Debug and Config.Hud
		if Config.Debug then
			hudDebug.Text = string.format("d %d | miss %.1f | hit %s | tgt %s",
				math.floor(E.dist), E.miss, tostring(E.willHit), tostring(E.targeted))
			hudDebug2.Text = string.format("seen %d | blkT %d | blkF %d",
				E.seen, E.blockedTarget, E.blockedFake)
			E.seen = 0
		end
		task.wait(0.3)
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

ca(section(cp, "Parry Circle"))
ca((slider(cp, "Parry Radius", 6, 45, Config.BaseRadius, 0, function(v) Config.BaseRadius = v end)))
ca((toggle(cp, "Show Circle", Config.ParryRing, function(v) Config.ParryRing = v end)))
ca((dropdown(cp, "Circle Color", {"Purple","White","Red","Cyan","Green","Gold"}, Config.RingColor, function(v)
	Config.RingColor = v
end)))
ca((slider(cp, "Circle Thickness", 0.01, 0.25, Config.RingThick, 2, function(v) Config.RingThick = v end)))
ca((toggle(cp, "Ping Compensation", Config.PingComp, function(v) Config.PingComp = v end)))
ca((slider(cp, "Ping Radius Cap", 0, 40, Config.PingRadiusCap, 0, function(v) Config.PingRadiusCap = v end)))

ca(section(cp, "Anti-Fake"))
ca((toggle(cp, "Reject Fake Trajectories", Config.FakeReject, function(v) Config.FakeReject = v end)))
ca((slider(cp, "Hit Tolerance", 2, 25, Config.HitTolerance, 0, function(v) Config.HitTolerance = v end)))
ca((toggle(cp, "Compensate My Movement", Config.MoveComp, function(v) Config.MoveComp = v end)))
ca((toggle(cp, "Require Ball Targeting Me", Config.RequireTarget, function(v) Config.RequireTarget = v end)))
ca((toggle(cp, "Force Fire (ignore checks)", Config.ForceFire, function(v) Config.ForceFire = v end)))

ca(section(cp, "Prediction"))
ca((slider(cp, "Prediction", 0.02, 0.2, Config.Prediction, 2, function(v) Config.Prediction = v end)))
ca((slider(cp, "Horizon", 0.1, 1.0, Config.Horizon, 2, function(v) Config.Horizon = v end)))

ca(section(cp, "Rate"))
ca((slider(cp, "Actions / sec", 10, 100, Config.ActionsPerSec, 0, function(v) Config.ActionsPerSec = v end)))
ca((dropdown(cp, "Batch Mode", {"Extremely Fast", "Fast", "Normal", "Safe"}, Config.BatchMode, function(v) Config.BatchMode = v end)))
ca((button(cp, "Test Parry", function()
	E.lastAction = 0
	notify("input -> " .. tostring(performParry()), T.Good)
end)))
ca((button(cp, "Reset Counters", function()
	E.actions, E.seen, E.blockedTarget, E.blockedFake = 0, 0, 0, 0
end)))

local bp, ba = newTab("Bypass")
ba(section(bp, "Input (BAC bypass)"))
ba((button(bp, "MAX STEALTH", function()
	Config.InputMode = "Keypress"
	Config.ActionsPerSec = 40
	Config.BatchMode = "Normal"
	Config.RequireTarget = true
	Config.FakeReject = true
	Config.PingComp = true
	Config.BaseRadius = 15
	Config.Headless = false
	Config.Particles = false
	Config.BallRecolor = false
	notify("stealth armed", T.Good)
end)))
ba((button(bp, "Show Input Backend", function()
	notify("keypress: " .. tostring(hasKeypress) .. " | mouse: " .. tostring(hasMouse), T.Warn)
end)))
ba((button(bp, "Find Parry Remote", function()
	findRemote()
	notify(ParryRemote and ("found: " .. ParryRemote:GetFullName()) or "not found", ParryRemote and T.Good or T.Bad)
end)))
ba((button(bp, "Dump Ball Info", function()
	local folder = Workspace:FindFirstChild("Balls")
	local ball = folder and folder:GetChildren()[1]
	if not ball then notify("no ball", T.Bad) return end
	local attrs = {}
	for _, k in ipairs({"target","Target","currentTarget","targetPlayer","to","realBall","Phantom","Infinity"}) do
		local ok, v = pcall(function() return ball:GetAttribute(k) end)
		if ok and v ~= nil then table.insert(attrs, k .. "=" .. tostring(v)) end
	end
	local kids = {}
	for _, c in ipairs(ball:GetChildren()) do table.insert(kids, c.Name) end
	notify("attrs: " .. (#attrs > 0 and table.concat(attrs, ", ") or "none"), T.Warn)
	task.delay(0.3, function()
		notify("kids: " .. (#kids > 0 and table.concat(kids, ", ") or "none"), T.Warn)
	end)
end)))
ba((toggle(bp, "Debug Readout", Config.Debug, function(v) Config.Debug = v end)))

local vp, va = newTab("Visuals")
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
va((toggle(vp, "Headless", Config.Headless, function(v) Config.Headless = v; applyHeadless() end)))
va((toggle(vp, "Fullbright", Config.Fullbright, function(v)
	Config.Fullbright = v
	if v then
		Lighting.Ambient = Color3.fromRGB(200,200,200); Lighting.OutdoorAmbient = Color3.fromRGB(200,200,200)
		Lighting.Brightness = 2; Lighting.GlobalShadows = false
	else applySky(Config.SkyPreset) end
end)))

local wp, wa = newTab("World")
wa((dropdown(wp, "Sky Preset", {"Default","Night","Blood","Black","Neon","Vapor"}, Config.SkyPreset, function(v)
	Config.SkyPreset = v; applySky(v)
end)))
wa((slider(wp, "Clock Time", 0, 24, Config.ClockTime, 0, function(v) Config.ClockTime = v; Lighting.ClockTime = v end)))
wa((slider(wp, "Brightness", 0, 5, Config.Brightness, 1, function(v) Config.Brightness = v; Lighting.Brightness = v end)))
wa((toggle(wp, "Particles", Config.Particles, function(v) Config.Particles = v; applyParticles() end)))
wa((slider(wp, "Particle Rate", 5, 200, Config.ParticleRate, 0, function(v) Config.ParticleRate = v; applyParticles() end)))

local kp, ka = newTab("Skins")
ka((textbox(kp, "Sword Mesh ID", Config.SwordMesh, "rbxassetid://...", function(v) Config.SwordMesh = v end)))
ka((textbox(kp, "Sword Texture ID", Config.SwordTexture, "rbxassetid://...", function(v) Config.SwordTexture = v end)))
ka((button(kp, "Apply Sword Skin", function()
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
	notify(found and "applied" or "sword not found", found and T.Good or T.Bad)
end)))
ka((toggle(kp, "Recolor Ball", Config.BallRecolor, function(v) Config.BallRecolor = v end)))
ka((slider(kp, "Ball Size", 0.5, 3, Config.BallSize, 2, function(v) Config.BallSize = v end)))

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
		ring.Color3 = RingColors[Config.RingColor] or RingColors.Purple
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
	if Config.FpsBoost then pcall(applyFpsBoost, true) end
	notify(TITLE .. " loaded | " .. (hasKeypress and "keypress" or "mouse"), T.Good)
end)
