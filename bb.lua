--[[
    𝒮𝒸𝓇𝒾𝓅𝓉𝒮𝓁𝑒𝑒𝑝  |  BLADE BALL  |  BAC v3
    menu: RightShift
--]]

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
local TITLE  = "𝒮𝒸𝓇𝒾𝓅𝓉𝒮𝓁𝑒𝑒𝑝"

--=============================================================
-- CONFIG
--=============================================================
local Config = {
	AutoParry     = true,
	RequireTarget = true,
	TargetTol     = 8,
	OnePerBall    = true,
	DoubleFire    = false,
	AutoTune      = true,
	ReactMin      = 0.14,
	ReactMax      = 0.26,
	SafetyRange   = 6,
	HumanError    = 10,
	LockTimeout   = 2.0,
	GateDistance  = true,
	GateApproach  = true,
	GateSpeed     = true,
	SendBall      = false,
	AutoAbility   = false,
	AbilityDelay  = 1.2,
	DebugParry    = false,
	RemotePath    = "",

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
	Particles     = false,
	ParticleRate  = 40,
	ParticleColor = Color3.fromRGB(255, 255, 255),
	BallRecolor   = false,
	BallColor     = Color3.fromRGB(255, 255, 255),
	BallMaterial  = "Plastic",
	BallSize      = 1,

	SkyPreset     = "Default",
	ClockTime     = 14,
	Brightness    = 2,
	FogEnd        = 100000,

	SwordMesh     = "",
	SwordTexture  = "",

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
	for k,v in pairs(dec) do if Config[k] ~= nil then local d = deser(v); if d ~= nil then Config[k] = d end end end
end
local saveQueued = false
local function queueSave()
	if saveQueued then return end
	saveQueued = true
	task.delay(1, function() saveQueued = false; saveConfig() end)
end
loadConfig()

--=============================================================
-- THEME / HELPERS
--=============================================================
local T = {
	Bg=Color3.fromRGB(9,9,11), Panel=Color3.fromRGB(15,15,18), Item=Color3.fromRGB(21,21,25),
	ItemHi=Color3.fromRGB(31,31,37), Line=Color3.fromRGB(40,40,47), Text=Color3.fromRGB(238,238,243),
	Dim=Color3.fromRGB(140,140,150), Accent=Color3.fromRGB(255,255,255),
	Bad=Color3.fromRGB(255,105,105), Good=Color3.fromRGB(120,255,165), Warn=Color3.fromRGB(255,205,90),
}
local gui

local function new(c, p, parent)
	local i = Instance.new(c)
	for k,v in next,p do i[k] = v end
	if parent then i.Parent = parent end
	return i
end
local function corner(i, r) new("UICorner", {CornerRadius = UDim.new(0, r or 8)}, i) end
local function stroke(i, c, t) new("UIStroke", {Color=c or T.Line, Thickness=t or 1, ApplyStrokeMode=Enum.ApplyStrokeMode.Border}, i) end
local function getPing()
	local ok, v = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
	return ok and v or 0
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

gui = new("ScreenGui", {Name="ScriptSleep", ResetOnSpawn=false,
	ZIndexBehavior=Enum.ZIndexBehavior.Sibling, IgnoreGuiInset=true, DisplayOrder=999})
pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
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
-- REMOTE
--=============================================================
local ParryRemote, AbilityRemote, ParryPath = nil, nil, ""
local function collectRemotes()
	local out = {}
	for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
		if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) and d.Name:lower():find("parry") then table.insert(out, d) end
	end
	table.sort(out, function(a,b)
		local function sc(x) local n = x.Name:lower()
			if n=="parry" then return 1 elseif n=="parrybuttonpress" then return 2 else return 3 end end
		return sc(a) < sc(b)
	end)
	return out
end
local function findRemotes()
	if Config.RemotePath ~= "" then
		local ok, inst = pcall(function()
			local node = game
			for part in string.gmatch(Config.RemotePath, "[^%.]+") do node = node[part] end
			return node
		end)
		if ok and inst and (inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction")) then
			ParryRemote, ParryPath = inst, inst:GetFullName(); return true
		end
	end
	local c = collectRemotes()
	if #c > 0 then ParryRemote, ParryPath = c[1], c[1]:GetFullName(); return true end
	return false
end
local function findAbility()
	AbilityRemote = nil
	for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
		if d:IsA("RemoteEvent") and d.Name:lower():find("abilit") then AbilityRemote = d; return end
	end
end
findRemotes(); findAbility()

--=============================================================
-- BALL + TARGET
--=============================================================
local function getBall()
	local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
	local list = {}
	local f = workspace:FindFirstChild("Balls")
	if f then for _, b in ipairs(f:GetChildren()) do
		if b:IsA("BasePart") and b.Name:lower():find("ball") then table.insert(list, b) end
	end end
	if #list == 0 then
		for _, d in ipairs(workspace:GetChildren()) do
			if d:IsA("BasePart") and d.Name:lower():find("ball") then table.insert(list, d) end
		end
	end
	if #list == 0 then return nil end
	if not hrp then return list[1] end
	local best, bd
	for _, b in ipairs(list) do
		local d = (b.Position - hrp.Position).Magnitude
		if not bd or d < bd then best, bd = b, d end
	end
	return best
end

local function targetsMe(ball, hrp, vel)
	for _, key in ipairs({"Target","TargetPlayer","TargetUserId","UserId","Owner"}) do
		local ok, val = pcall(function() return ball:GetAttribute(key) end)
		if ok and val ~= nil then
			if typeof(val) == "Instance" then
				if val == LP or val == LP.Character then return true end
				if val:IsA("Player") then return false end
			elseif type(val) == "string" then
				if val == LP.Name or val == LP.DisplayName or val == tostring(LP.UserId) then return true end
			elseif type(val) == "number" and val == LP.UserId then return true end
		end
	end
	for _, ch in ipairs(ball:GetChildren()) do
		if ch.Name:lower():find("target") then
			local v = ch.Value
			if typeof(v) == "Instance" then
				if v == LP or v == LP.Character then return true end
				if v:IsA("Player") then return false end
			end
		end
	end
	local speed = vel.Magnitude
	if speed < 1 then return nil end
	local dir = vel / speed
	local toMe = hrp.Position - ball.Position
	local proj = toMe:Dot(dir)
	if proj <= 0 then return false end
	local closest = ball.Position + dir * proj
	return (hrp.Position - closest).Magnitude <= Config.TargetTol
end

--=============================================================
-- STATE + AUTOTUNE
--=============================================================
local state = {
	fired=0, success=0, failed=0,
	locked=false, lockBall=nil, lastFire=0,
	pending=nil, fireDist=0, fireEta=0,
	reactBase=0.18, tune=0,
	dist=0, eta=0, speed=0, targeting="-",
}

local function rollReact()
	local base = (Config.ReactMin + Config.ReactMax) / 2
	local spread = (Config.ReactMax - Config.ReactMin) / 2
	local r = base + math.random() * spread - spread / 2
	if math.random(100) <= Config.HumanError then r = r + math.random(30, 110) / 1000 end
	state.reactBase = math.clamp(r, 0.05, 0.5)
end

local function reaction()
	return math.clamp(state.reactBase + state.tune, 0.05, 0.45)
end

local function fire(ball, dist, eta)
	if not ParryRemote then return false end
	if state.locked and Config.OnePerBall then return false end
	if tick() - state.lastFire < 0.1 then return false end

	state.lastFire = tick()
	state.fired += 1
	state.locked = true
	state.lockBall = ball
	state.fireDist = dist
	state.fireEta = eta

	if ParryRemote:IsA("RemoteFunction") then
		pcall(function() ParryRemote:InvokeServer() end)
	elseif Config.SendBall and ball then
		pcall(function() ParryRemote:FireServer(ball) end)
	else
		pcall(function() ParryRemote:FireServer() end)
	end
	state.pending = {t = tick(), ball = ball}
	return true
end

--=============================================================
-- COMBAT
--=============================================================
local warnShown = false

bind(RunService.Heartbeat, function()
	local now = tick()
	local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")

	-- проверка результата + автотюн
	if state.pending and now - state.pending.t > 0.45 then
		local b = state.pending.ball
		if b and b.Parent and hrp then
			local v = b.AssemblyLinearVelocity
			if v.Magnitude > 1 then
				if v.Unit:Dot((hrp.Position - b.Position).Unit) < 0 then
					state.success += 1
				else
					state.failed += 1
					if Config.AutoTune then
						if state.fireDist > 18 then
							state.tune = math.clamp(state.tune - 0.015, -0.14, 0.14)
						elseif state.fireDist < 9 then
							state.tune = math.clamp(state.tune + 0.015, -0.14, 0.14)
						end
					end
				end
			end
		end
		state.pending = nil
		if state.fired >= 8 and state.success == 0 and not warnShown then
			warnShown = true
			notify("parry not landing - check remote", T.Bad)
		end
	end

	if Config.AutoAbility and AbilityRemote then
		if now - (state.lastAbility or 0) > Config.AbilityDelay then
			state.lastAbility = now
			pcall(function() AbilityRemote:FireServer() end)
		end
	end

	if not Config.AutoParry or not hrp then return end

	local ball = getBall()
	if not ball then state.dist = 0; return end

	local vel = ball.AssemblyLinearVelocity
	if state.lastPos and state.lastTime then
		local dt = now - state.lastTime
		if dt > 0 then
			local p = (ball.Position - state.lastPos) / dt
			if p.Magnitude > vel.Magnitude then vel = p end
		end
	end
	state.lastPos, state.lastTime = ball.Position, now

	local speed = vel.Magnitude
	local moving = speed > 1.5
	local toMe = hrp.Position - ball.Position
	local dist = toMe.Magnitude
	local eta = dist / math.max(speed, 1)
	state.dist, state.eta, state.speed = dist, eta, speed

	if moving and not state.wasMoving then rollReact() end
	state.wasMoving = moving

	if state.locked then
		local receding = speed > 1 and (vel.Unit:Dot(toMe.Unit) < -0.2)
		if (dist > 30 and receding) or now - state.lastFire > Config.LockTimeout or state.lockBall ~= ball then
			state.locked = false
		end
	end

	if Config.GateDistance and dist > 90 then return end
	if Config.GateSpeed and not moving and dist > 25 then return end

	local tgt = targetsMe(ball, hrp, vel)
	state.targeting = tgt == true and "yes" or (tgt == false and "no" or "?")
	if Config.RequireTarget and tgt == false then return end
	if Config.GateApproach and speed > 0.5 and dist > 0.5 and (vel/speed):Dot(toMe.Unit) < 0.05 then return end

	local ping = getPing() / 1000
	local react = reaction()

	-- стреляем за react секунд до контакта (человеческое окно реакции)
	if eta <= ping + react then
		fire(ball, dist, eta)
	elseif dist <= Config.SafetyRange then
		fire(ball, dist, eta)
	end

	if Config.DoubleFire and state.locked and state.lockBall == ball
		and eta <= 0.05 and not state.doubled then
		state.doubled = true
		state.locked = false
		fire(ball, dist, eta)
	end
	if not state.locked then state.doubled = false end
end)

--=============================================================
-- ESP
--=============================================================
local espObjs = {}
local function project(v)
	local sp = CAMERA:WorldToViewportPoint(v)
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
						o.dist.Text = string.format("%d studs", math.floor((hrp.Position - CAMERA.CFrame.Position).Magnitude))
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
						local from = Vector2.new(CAMERA.ViewportSize.X/2, CAMERA.ViewportSize.Y)
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
	ball.Material = Enum.Material[Config.BallMaterial] or Enum.Material.Plastic
	local base = ball:GetAttribute("ScriptSleepBaseSize")
	if not base then base = ball.Size; ball:SetAttribute("ScriptSleepBaseSize", base) end
	ball.Size = base * Config.BallSize
end

--=============================================================
-- DIAGNOSTIC
--=============================================================
local function diagnose()
	local lines = {}
	table.insert(lines, "=== SCRIPT SLEEP DIAG ===")
	table.insert(lines, "executor: " .. tostring(identifyexecutor and select(1, pcall(identifyexecutor)) or "?"))
	table.insert(lines, "getgenv: " .. tostring(getgenv ~= nil))
	table.insert(lines, "parry remote: " .. (ParryRemote and ParryPath or "NOT FOUND"))
	table.insert(lines, "ability remote: " .. (AbilityRemote and AbilityRemote:GetFullName() or "NOT FOUND"))
	table.insert(lines, "--- all parry remotes ---")
	for _, d in ipairs(collectRemotes()) do table.insert(lines, "  " .. d:GetFullName() .. " (" .. d.ClassName .. ")") end
	local ball = getBall()
	if ball then
		table.insert(lines, "--- ball: " .. ball:GetFullName() .. " ---")
		for _, ch in ipairs(ball:GetChildren()) do
			table.insert(lines, "  child: " .. ch.Name .. " (" .. ch.ClassName .. ")")
		end
		local ok, attrs = pcall(function() return ball:GetAttributes() end)
		if ok and attrs then
			for k, v in pairs(attrs) do table.insert(lines, "  attr: " .. k .. " = " .. tostring(v)) end
		end
	else
		table.insert(lines, "ball: NOT FOUND")
	end
	table.insert(lines, "--- workspace ---")
	for _, d in ipairs(workspace:GetChildren()) do table.insert(lines, "  " .. d.Name .. " (" .. d.ClassName .. ")") end
	local txt = table.concat(lines, "\n")
	print(txt)
	if hasFS then pcall(function() writefile("ScriptSleep_diag.txt", txt) end) end
	notify("diag -> ScriptSleep_diag.txt", T.Warn)
end

--=============================================================
-- HUD
--=============================================================
local fps, frames, timer = 0, 0, tick()
bind(RunService.RenderStepped, function()
	frames = frames + 1
	if tick() - timer >= 1 then fps, frames, timer = frames, 0, tick() end
end)

local function applyFpsBoost(on)
	if on then
		pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
		Lighting.GlobalShadows = false; Lighting.ShadowSoftness = 0
		Lighting.EnvironmentDiffuseScale = 0; Lighting.EnvironmentSpecularScale = 0
		for _, e in ipairs(Lighting:GetChildren()) do if e:IsA("PostEffect") then e.Enabled = false end end
		pcall(function() setfpscap(240) end)
	else Lighting.GlobalShadows = true end
end

local hud = new("Frame", {Size=UDim2.new(0,250,0,74), Position=UDim2.new(0,12,0,12),
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

task.spawn(function()
	while gui.Parent do
		hud.Visible = Config.Hud
		local ping = math.floor(getPing())
		hudStats.Text = string.format("FPS: %d  |  PING: %d ms", fps, ping)
		hudStats.TextColor3 = ping < 80 and T.Good or (ping < 160 and T.Dim or T.Bad)
		hudParry.Text = string.format("fire %d | ok %d | miss %d | r=%.0fms", state.fired, state.success, state.failed, reaction()*1000)
		hudParry.TextColor3 = state.failed > state.success and T.Warn or T.Good
		hudDebug.Visible = Config.DebugParry and Config.Hud
		if Config.DebugParry then
			hudDebug.Text = string.format("d %d | eta %.2f | tgt %s | tune %+.0fms | %s",
				math.floor(state.dist), state.eta, state.targeting, state.tune*1000,
				ParryRemote and ParryRemote.Name or "NO REMOTE")
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
ca(section(cp, "Human Reaction Window"))
ca((slider(cp, "React Min (s)", 0.05, 0.4, Config.ReactMin, 2, function(v) Config.ReactMin = v end)))
ca((slider(cp, "React Max (s)", 0.05, 0.4, Config.ReactMax, 2, function(v) Config.ReactMax = v end)))
ca((slider(cp, "Human Error (%)", 0, 30, Config.HumanError, 0, function(v) Config.HumanError = v end)))
ca((slider(cp, "Safety Range", 3, 20, Config.SafetyRange, 0, function(v) Config.SafetyRange = v end)))
ca((toggle(cp, "Auto Tune", Config.AutoTune, function(v) Config.AutoTune = v end)))
ca(section(cp, "Target"))
ca((toggle(cp, "Require Ball Targeting Me", Config.RequireTarget, function(v) Config.RequireTarget = v end)))
ca((slider(cp, "Trajectory Tolerance", 3, 20, Config.TargetTol, 0, function(v) Config.TargetTol = v end)))
ca(section(cp, "Limits"))
ca((toggle(cp, "One Parry Per Ball", Config.OnePerBall, function(v) Config.OnePerBall = v end)))
ca((toggle(cp, "Double Fire", Config.DoubleFire, function(v) Config.DoubleFire = v end)))
ca((slider(cp, "Lock Timeout", 0.6, 4, Config.LockTimeout, 1, function(v) Config.LockTimeout = v end)))
ca((button(cp, "Reset Counters + Tune", function()
	state.fired, state.success, state.failed, state.tune = 0,0,0,0
end)))

local bp, ba = newTab("Bypass")
ba(section(bp, "BAC"))
ba((button(bp, "MAX STEALTH", function()
	Config.RequireTarget = true; Config.OnePerBall = true; Config.DoubleFire = false
	Config.ReactMin = 0.18; Config.ReactMax = 0.32; Config.HumanError = 15
	Config.AutoAbility = false; Config.Headless = false
	Config.Particles = false; Config.BallRecolor = false; Config.FpsBoost = false
	notify("stealth armed", T.Good)
end)))
ba((toggle(bp, "Distance Gate", Config.GateDistance, function(v) Config.GateDistance = v end)))
ba((toggle(bp, "Approach Gate", Config.GateApproach, function(v) Config.GateApproach = v end)))
ba((toggle(bp, "Speed Gate", Config.GateSpeed, function(v) Config.GateSpeed = v end)))
ba(section(bp, "Remote"))
ba((textbox(bp, "Manual Path", Config.RemotePath, "ReplicatedStorage.Remotes.Parry", function(v)
	Config.RemotePath = v
	if v ~= "" then notify(findRemotes() and ("bound: "..ParryPath) or "not resolved", ParryRemote and T.Good or T.Bad) end
end)))
ba((button(bp, "Auto Detect Remote", function()
	Config.RemotePath = ""; findRemotes(); findAbility()
	notify(ParryRemote and ("found: "..ParryPath) or "nothing found", ParryRemote and T.Good or T.Bad)
end)))
ba((button(bp, "Diagnostic Dump", diagnose)))
ba((toggle(bp, "Send Ball As Argument", Config.SendBall, function(v) Config.SendBall = v end)))
ba((toggle(bp, "Debug Readout", Config.DebugParry, function(v) Config.DebugParry = v end)))

local vp, va = newTab("Visuals")
va((toggle(vp, "Box ESP", Config.BoxEsp, function(v) Config.BoxEsp = v end)))
va((toggle(vp, "Box Fill", Config.EspFill, function(v) Config.EspFill = v end)))
va((toggle(vp, "Name ESP", Config.NameEsp, function(v) Config.NameEsp = v end)))
va((toggle(vp, "Distance ESP", Config.DistEsp, function(v) Config.DistEsp = v end)))
va((toggle(vp, "Health Bar", Config.HealthEsp, function(v) Config.HealthEsp = v end)))
va((toggle(vp, "Tracers", Config.Tracers, function(v) Config.Tracers = v end)))
va((toggle(vp, "Highlights", Config.Highlights, function(v) Config.Highlights = v end)))
va((toggle(vp, "Hitboxes 3D", Config.Hitboxes, function(v) Config.Hitboxes = v end)))
va((toggle(vp, "Ball ESP", Config.BallEsp, function(v) Config.BallEsp = v end)))
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
ma((toggle(mp, "Custom Speed", Config.UseSpeed, function(v) Config.UseSpeed = v end)))
ma((slider(mp, "Walk Speed", 8, 120, Config.WalkSpeed, 0, function(v) Config.WalkSpeed = v end)))
ma((slider(mp, "Jump Power", 20, 200, Config.JumpPower, 0, function(v) Config.JumpPower = v end)))
ma((toggle(mp, "Anti AFK", Config.AntiAfk, function(v) Config.AntiAfk = v end)))
ma((toggle(mp, "Auto Ability", Config.AutoAbility, function(v) Config.AutoAbility = v end)))
local keyBtn
keyBtn = ma((button(mp, "Menu Key: "..Config.MenuKey.Name, function()
	local conn
	conn = UserInputService.InputBegan:Connect(function(i, gp)
		if gp then return end
		if i.UserInputType == Enum.UserInputType.Keyboard then
			Config.MenuKey = i.KeyCode
			keyBtn.Text = "Menu Key: "..i.KeyCode.Name
			conn:Disconnect(); queueSave()
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
		Lighting.GlobalShadows = true; workspace.CurrentCamera.FieldOfView = 70
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
local fb = new("TextButton", {Size=UDim2.new(0,36,0,36), Position=UDim2.new(0,12,0,96),
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
task.spawn(function()
	while gui.Parent do
		if not ParryRemote or not ParryRemote:IsDescendantOf(game) then findRemotes(); findAbility() end
		task.wait(3)
	end
end)

bind(RunService.RenderStepped, function()
	local cam = workspace.CurrentCamera
	if cam and math.abs(cam.FieldOfView - Config.Fov) > 0.1 then cam.FieldOfView = Config.Fov end
	local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
	if hum and Config.UseSpeed then
		if hum.WalkSpeed ~= Config.WalkSpeed then hum.WalkSpeed = Config.WalkSpeed end
		if hum.UseJumpPower and hum.JumpPower ~= Config.JumpPower then hum.JumpPower = Config.JumpPower end
	end
end)
bind(LP.Idled, function()
	if Config.AntiAfk then VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end
end)

task.spawn(function()
	task.wait(0.5)
	pcall(applySky, Config.SkyPreset)
	pcall(applyHeadless)
	notify(TITLE.." | BAC v3", T.Good)
	print("["..TITLE.."] loaded | remote: "..(ParryRemote and ParryPath or "NOT FOUND"))
end)
