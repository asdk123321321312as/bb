--[[
    𝒮𝒸𝓇𝒾𝓅𝓉𝒮𝓁𝑒𝑒𝓅  |  BLADE BALL
    keypress bypass + smart one-tap + move-assist + strict flight gate
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

local CONFIG_VER = 10

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

	SmartTap      = true,
	OneParry      = true,
	OneParryKey   = "H",
	ExtraPresses  = 0,
	MinRepressGap = 0.10,

	MoveAssist    = true,

	-- === строгий полётный фильтр ===
	MinDot          = 0.55,
	MinApproach     = 12,
	CpaFactor       = 0.95,
	DeflectSuppress = 0.05,

	AutoRadius    = true,
	LeadTime      = 0.11,
	MinRadius     = 9,
	MaxRadius     = 34,
	BaseRadius    = 16,
	CrossTrigger  = true,
	PingComp      = true,
	BallPredCap   = 22,

	FastAssist    = true,
	SpeedAssist   = true,
	FastBoost     = 0.6,

	AbilityGuard  = true,
	BoostDetect   = true,
	BoostMult     = 1.7,
	BoostHold     = 0.7,
	ShowAbility   = true,

	RequireTarget = true,
	Debug         = false,

	ParryRing     = true,
	RingColor     = "Purple",
	RingThick     = 0.06,
	RingOpacity   = 0.3,

	Korblox        = false,
	KorbloxMethod  = "Bundle",
	KorbloxSide    = "Right",
	KorbloxColor   = "Dark",
	KorbloxThin    = 0.55,
	KorbloxScale   = 1.00,
	KorbloxFullLeg = true,
	KorbloxHideFoot= true,
	KorbloxMesh    = "rbxassetid://169177037",
	KorbloxTexture = "",

	EspEnabled    = true,
	SkyParticles  = false,
	SpeedBoost    = false,
	SpeedValue    = 26,

	MenuKey       = Enum.KeyCode.RightShift,
}

local KeyCodes = {
	F = 0x46, E = 0x45, Q = 0x51, R = 0x52, G = 0x47, H = 0x48,
	Space = 0x20, LeftShift = 0xA0,
}

local RingColors = {
	Purple = Color3.fromRGB(180, 120, 255),
	White  = Color3.fromRGB(255, 255, 255),
	Red    = Color3.fromRGB(255, 90, 90),
	Green  = Color3.fromRGB(120, 255, 165),
	Blue   = Color3.fromRGB(120, 180, 255),
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
	out.__ver = CONFIG_VER
	pcall(function() writefile(FILE, HttpService:JSONEncode(out)) end)
end

local function resetTuning()
	Config.MinDot = 0.55
	Config.MinApproach = 12
	Config.CpaFactor = 0.95
	Config.DeflectSuppress = 0.05
	Config.LeadTime = 0.11
	Config.MinRadius = 9
	Config.MaxRadius = 34
	Config.ExtraPresses = 0
	Config.MinRepressGap = 0.10
end

local function resetKorbloxConfig()
	Config.KorbloxMesh    = "rbxassetid://169177037"
	Config.KorbloxTexture = ""
	Config.KorbloxThin    = 0.55
	Config.KorbloxScale   = 1.00
	Config.KorbloxColor   = "Dark"
	Config.KorbloxFullLeg = true
	Config.KorbloxHideFoot= true
	Config.KorbloxSide    = "Right"
end

local function loadConfig()
	if not hasFS then return end
	local ok, data = pcall(readfile, FILE)
	if not ok or not data then return end
	local ok2, dec = pcall(function() return HttpService:JSONDecode(data) end)
	if not ok2 or type(dec) ~= "table" then return end
	local ver = tonumber(dec.__ver) or 0
	for k, v in pairs(dec) do
		if k ~= "__ver" and Config[k] ~= nil then
			local d = deser(v); if d ~= nil then Config[k] = d end
		end
	end
	if ver < CONFIG_VER then
		resetTuning()
		resetKorbloxConfig()
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
}

--=============================================================
-- HELPERS
--=============================================================
local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in next, props do inst[k] = v end
	if parent then inst.Parent = parent end
	return inst
end

local function corner(inst, r)
	new("UICorner", {CornerRadius = UDim.new(0, r or 8)}, inst)
end

local function stroke(inst, col, th)
	new("UIStroke", {Color = col or T.Line, Thickness = th or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, inst)
end

local function notify(text, good)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = TITLE, Text = text, Duration = 3,
		})
	end)
end

--=============================================================
-- GUI
--=============================================================
local gui = new("ScreenGui", {
	Name = "ScriptSleep", ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true,
})
pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end

local win = new("Frame", {
	Size = UDim2.new(0, 620, 0, 400), Position = UDim2.new(0.5, -310, 0.5, -200),
	BackgroundColor3 = T.Bg, BorderSizePixel = 0, Active = true,
}, gui)
corner(win, 12); stroke(win, T.Line, 1)

local bar = new("Frame", {Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = T.Panel,
	BorderSizePixel = 0}, win)
corner(bar, 12)
new("Frame", {Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 1, -12),
	BackgroundColor3 = T.Panel, BorderSizePixel = 0}, bar)
new("TextLabel", {Size = UDim2.new(1, -100, 1, 0), Position = UDim2.new(0, 14, 0, 0),
	BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 15,
	TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = TITLE}, bar)

local side = new("Frame", {Size = UDim2.new(0, 128, 1, -36), Position = UDim2.new(0, 0, 0, 36),
	BackgroundColor3 = T.Bg, BorderSizePixel = 0}, win)
new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, side)
new("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8),
	PaddingRight = UDim.new(0, 8)}, side)

local content = new("Frame", {Size = UDim2.new(1, -128, 1, -36), Position = UDim2.new(0, 128, 0, 36),
	BackgroundTransparency = 1}, win)

local pages = {}
local function page(name, order)
	local p = new("ScrollingFrame", {Size = UDim2.new(1, -16, 1, -16), Position = UDim2.new(0, 8, 0, 8),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
		CanvasSize = UDim2.new(0, 0, 0, 800), Visible = false}, content)
	new("UIListLayout", {Padding = UDim.new(0, 6)}, p)
	pages[name] = p

	local btn = new("TextButton", {Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = T.Item,
		BorderSizePixel = 0, Font = Enum.Font.GothamMedium, TextSize = 13,
		TextColor3 = T.Dim, Text = name, AutoButtonColor = false,
		LayoutOrder = order or 0}, side)
	corner(btn, 7)
	btn.MouseButton1Click:Connect(function()
		for n, pg in pairs(pages) do pg.Visible = (n == name) end
		for n, b in pairs(side:GetChildren()) do
			if b:IsA("TextButton") then
				b.BackgroundColor3 = (b.Text == name) and T.ItemHi or T.Item
				b.TextColor3 = (b.Text == name) and T.Text or T.Dim
			end
		end
	end)
	return p
end

local function section(p, txt)
	new("TextLabel", {Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left, Text = txt}, p)
end

local function toggle(p, label, key, cb)
	local row = new("Frame", {Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1}, p)
	new("TextLabel", {Size = UDim2.new(1, -60, 1, 0), BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = T.Text,
		TextXAlignment = Enum.TextXAlignment.Left, Text = label}, row)
	local btn = new("TextButton", {Size = UDim2.new(0, 46, 0, 22), Position = UDim2.new(1, -46, 0.5, -11),
		BackgroundColor3 = Config[key] and T.Accent or T.Item, BorderSizePixel = 0,
		Font = Enum.Font.GothamBold, TextSize = 11,
		TextColor3 = Config[key] and Color3.fromRGB(0,0,0) or T.Dim,
		Text = Config[key] and "ON" or "OFF", AutoButtonColor = false}, row)
	corner(btn, 6)
	btn.MouseButton1Click:Connect(function()
		Config[key] = not Config[key]
		btn.BackgroundColor3 = Config[key] and T.Accent or T.Item
		btn.TextColor3 = Config[key] and Color3.fromRGB(0,0,0) or T.Dim
		btn.Text = Config[key] and "ON" or "OFF"
		queueSave()
		if cb then cb(Config[key]) end
	end)
end

local function slider(p, label, key, min, max, dec, cb)
	local row = new("Frame", {Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1}, p)
	local lbl = new("TextLabel", {Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = T.Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = label .. ": " .. string.format("%." .. (dec or 2) .. "f", Config[key])}, row)
	local track = new("Frame", {Size = UDim2.new(1, -8, 0, 6), Position = UDim2.new(0, 0, 0, 24),
		BackgroundColor3 = T.Item, BorderSizePixel = 0}, row)
	corner(track, 3)
	local fill = new("Frame", {Size = UDim2.new((Config[key]-min)/(max-min), 0, 1, 0),
		BackgroundColor3 = T.Accent, BorderSizePixel = 0}, track)
	corner(fill, 3)
	local dragging = false
	local function apply(px)
		local rel = math.clamp((px - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		local val = min + (max - min) * rel
		local mult = 10 ^ (dec or 2)
		val = math.floor(val * mult + 0.5) / mult
		Config[key] = val
		fill.Size = UDim2.new(rel, 0, 1, 0)
		lbl.Text = label .. ": " .. string.format("%." .. (dec or 2) .. "f", val)
		if cb then cb(val) end
	end
	track.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true; apply(i.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
			or i.UserInputType == Enum.UserInputType.Touch) then
			apply(i.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1
			or i.UserInputType == Enum.UserInputType.Touch then
			if dragging then queueSave() end
			dragging = false
		end
	end)
end

local function button(p, label, cb)
	local b = new("TextButton", {Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = T.Item,
		BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextSize = 12,
		TextColor3 = T.Text, Text = label, AutoButtonColor = false}, p)
	corner(b, 7)
	b.MouseButton1Click:Connect(cb)
	return b
end

--=============================================================
-- PAGES
--=============================================================
local combat = page("Combat", 1)
section(combat, "AUTOPARRY")
toggle(combat, "Auto Parry", "AutoParry")
toggle(combat, "Parry Only Once (" .. Config.OneParryKey .. ")", "OneParry")
toggle(combat, "Require Target", "RequireTarget")
toggle(combat, "Cross Trigger", "CrossTrigger")
section(combat, "STRICT FLIGHT GATE")
slider(combat, "Min Dot", "MinDot", 0.2, 0.95, 2)
slider(combat, "Min Approach", "MinApproach", 0, 40, 0)
slider(combat, "CPA Factor", "CpaFactor", 0.5, 1.3, 2)
section(combat, "RADIUS")
slider(combat, "Lead Time", "LeadTime", 0.03, 0.25, 3)
slider(combat, "Min Radius", "MinRadius", 4, 30, 0)
slider(combat, "Max Radius", "MaxRadius", 10, 60, 0)
section(combat, "SPAM")
slider(combat, "Actions / sec", "ActionsPerSec", 10, 100, 0)
slider(combat, "Min Repress Gap", "MinRepressGap", 0.02, 0.3, 2)

local visual = page("Visuals", 2)
section(visual, "VISUALS")
toggle(visual, "ESP", "EspEnabled")
toggle(visual, "Parry Ring", "ParryRing")
toggle(visual, "Debug HUD", "Debug")

local charPage = page("Character", 3)
section(charPage, "CHARACTER")
toggle(charPage, "Korblox Leg", "Korblox", function(on) if on then applyKorblox() end end)
toggle(charPage, "Speed Boost", "SpeedBoost")
slider(charPage, "WalkSpeed", "SpeedValue", 16, 80, 0)
button(charPage, "Re-apply Korblox", function() applyKorblox() end)

local world = page("World", 4)
section(world, "WORLD")
toggle(world, "Sky Particles", "SkyParticles")
toggle(world, "Ability Guard", "AbilityGuard")

local misc = page("Misc", 5)
section(misc, "MISC")
button(misc, "Reset Tuning", function()
	resetTuning(); queueSave(); notify("Tuning reset — перезапусти скрипт")
end)
button(misc, "Unload", function() unload() end)

pages["Combat"].Visible = true
for _, b in pairs(side:GetChildren()) do
	if b:IsA("TextButton") and b.Text == "Combat" then
		b.BackgroundColor3 = T.ItemHi; b.TextColor3 = T.Text
	end
end

-- drag window
do
	local dragging, start, origin
	bar.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true; start = i.Position; origin = win.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
			local d = i.Position - start
			win.Position = UDim2.new(origin.X.Scale, origin.X.Offset + d.X,
				origin.Y.Scale, origin.Y.Offset + d.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)
end

--=============================================================
-- PARRY ENGINE
--=============================================================
local ParryRemote
do
	for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
		if d:IsA("RemoteEvent") and d.Name:lower():find("parry") then ParryRemote = d; break end
	end
end

local hasKeypress = pcall(function() return keypress end)
local hasMouse    = pcall(function() return mouse1click end)

local E = {
	lastAction = 0, actions = 0, lastBall = nil,
	lastTime = 0, lastVel = Vector3.zero, accel = Vector3.zero,
	dist = 0, speed = 0, eta = 0, targeted = false, mode = "-",
	pressCount = 0, onePressed = false, ballLeft = true,
	prevDot = 0, deflectAt = 0, cpa = math.huge, pressAt = 0, unstable = false,
}

local function getPing()
	local ok, v = pcall(function()
		return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
	end)
	return (ok and v) or 0
end

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
	if Config.OneParry and E.onePressed and ball == E.lastBall then return false end
	E.lastAction = now
	E.actions += 1
	E.pressAt = now
	E.lastBall = ball
	E.onePressed = true
	E.mode = performParry()
	return true
end

--=============================================================
-- BALL / TARGET / THREAT
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

	return {
		ball = ball, distance = distance, speed = speed, velocity = velocity,
		accel = accel, dot = dot, approachSpeed = approachSpeed,
		eta = distance / math.max(approachSpeed, speed * 0.7, 1),
	}
end

-- ближайшая точка сближения (пролетит ли мяч реально в нас)
local function closestApproach(ball, root)
	local rel = ball.Position - root.Position
	local rv  = ball.AssemblyLinearVelocity - root.AssemblyLinearVelocity
	local vv  = rv:Dot(rv)
	local t   = vv > 1e-6 and math.clamp(-rel:Dot(rv) / vv, 0, 2) or 0
	return (rel + rv * t).Magnitude
end

--=============================================================
-- RED DETECTION
--=============================================================
local function isRed(c)
	if not c or typeof(c) ~= "Color3" then return false end
	return c.R > 0.55 and c.G < 0.55 and c.B < 0.55 and (c.R - math.max(c.G, c.B)) > 0.15
end

local function scanRed(obj)
	for _, d in ipairs(obj:GetDescendants()) do
		if d:IsA("BasePart") then
			if isRed(d.Color) then return true end
		elseif d:IsA("PointLight") then
			if isRed(d.Color) then return true end
		elseif d:IsA("Highlight") then
			if d.Enabled and (isRed(d.FillColor) or isRed(d.OutlineColor)) then return true end
		elseif d:IsA("SelectionBox") then
			if isRed(d.Color) then return true end
		end
	end
	return false
end

local function ballIsRed(ball)
	if not ball then return false end
	local ok, r = pcall(function()
		if ball:IsA("BasePart") and isRed(ball.Color) then return true end
		return scanRed(ball)
	end)
	return ok and r or false
end

local function charIsRed(char)
	if not char then return false end
	local ok, r = pcall(function() return scanRed(char) end)
	return ok and r or false
end

--=============================================================
-- RADIUS (адаптивный к скорости мяча)
--=============================================================
local function computeRadius(threat, pingSec, speedBoost)
	local net = pingSec * 0.5 + (1 / 60)
	if Config.AutoRadius then
		local lead = Config.LeadTime + (Config.PingComp and net or 0)
			+ (Config.FastAssist and speedBoost * 0.05 or 0)
		return math.clamp(threat.speed * lead, Config.MinRadius, Config.MaxRadius)
	end
	local r = Config.BaseRadius
	if Config.PingComp then
		r = r + math.clamp(threat.speed * net, 0, Config.BallPredCap)
	end
	return r
end

--=============================================================
-- MAIN LOGIC
--=============================================================
local function step(dt)
	if not Config.AutoParry or not inMatch() then return end
	local char = LP.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local ball = getBall()
	if not ball then return end

	local threat = computeThreat(ball, root)
	if not threat then return end

	E.dist, E.speed, E.eta = threat.distance, threat.speed, threat.eta

	local targeted = isTargeted(ball)
	E.targeted = targeted

	local rv = root.AssemblyLinearVelocity
	E.unstable = rv.Magnitude > 22 or math.abs(rv.Y) > 12
	local moving = rv.Magnitude > 8

	if Config.RequireTarget and not targeted and not (E.unstable and moving) then return end

	local pingSec = getPing() / 1000
	local dtStep = math.clamp(dt or 0.016, 0.001, 0.033)
	local speedBoost = Config.FastAssist and math.clamp((threat.speed - 130) / 250, 0, 1) or 0
	local radius = computeRadius(threat, pingSec, speedBoost)
	if E.unstable then radius = radius * 1.15 end
	E.radius = radius

	-- предсказание точки контакта
	local horizon = (Config.Horizon or 0.45) * (Config.Prediction or 0.08)
	horizon = horizon + math.clamp((threat.speed - 150) * 0.0003, 0, 0.12)
	local transit = pingSec * 0.5 + dtStep * 0.5 + (1 / 60) + horizon

	local futurePlayer = root.Position + root.AssemblyLinearVelocity * transit
	local curveComp = 0.5 * threat.accel * (transit * transit)
	if curveComp.Magnitude > 15 then curveComp = curveComp.Unit * 15 end
	local futureBall = ball.Position + threat.velocity * transit + curveComp
	local futureDist = (futurePlayer - futureBall).Magnitude

	-- === STRICT FLIGHT GATE =====================================
	local cpa = closestApproach(ball, root)
	E.cpa = cpa

	-- смена направления (мяч увели/отбили чужим) -> короткое подавление
	if E.prevDot > 0.25 and threat.dot < -0.15 then E.deflectAt = tick() end
	E.prevDot = threat.dot

	-- перезарядка One-Parry только на реальный уход мяча
	if ball ~= E.lastBall then E.onePressed = false end
	if threat.distance > radius * 1.5 or threat.speed < 3 or threat.dot < -0.20 then E.onePressed = false end
	if tick() - E.pressAt > 0.6 then E.onePressed = false end

	local dotMin = E.unstable and 0.30 or Config.MinDot
	local appMin = E.unstable and 5   or Config.MinApproach

	-- красный путь: ОБА красных (мяч И ты). При отбитии чужим краснеет только мяч
	local bothRed = ballIsRed(ball) and charIsRed(char)
		and threat.approachSpeed > 0 and threat.dot > 0.3
	-- обычный путь: строгая геометрия — реально летит в нас
	local strictGeo = threat.dot >= dotMin and threat.approachSpeed >= appMin
		and cpa <= radius * Config.CpaFactor
	local suppress = (tick() - E.deflectAt) < Config.DeflectSuppress

	local dirOk = (bothRed or strictGeo) and not suppress
	-- ============================================================

	if Config.CrossTrigger then
		local closing = math.max(threat.approachSpeed, threat.speed * 0.5, 1)
		local tCross = (threat.distance - radius) / closing
		E.lead = tCross
		if tCross <= transit and dirOk then sendAction(ball); return end
	else
		if threat.distance <= radius and dirOk then sendAction(ball); return end
	end
	if futureDist <= radius and dirOk then sendAction(ball) end
end

-- освобождение лока
local connections = {}
local function bind(sig, fn) table.insert(connections, sig:Connect(fn)) end

bind(RunService.Heartbeat, function(dt) pcall(step, dt) end)

bind(RunService.Heartbeat, function()
	if E.lastBall and E.lastBall.Parent then
		local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local d = (E.lastBall.Position - root.Position).Magnitude
			local v = E.lastBall.AssemblyLinearVelocity
			if d > 32 and v.Magnitude > 1 and v.Unit:Dot((root.Position - E.lastBall.Position).Unit) < -0.2 then
				E.onePressed = false
			end
		end
	end
end)

--=============================================================
-- PARRY RING
--=============================================================
local ring = new("CylinderHandleAdornment", {
	Height = 0.05, Radius = Config.BaseRadius, InnerRadius = Config.BaseRadius - 0.4,
	Color3 = RingColors[Config.RingColor] or RingColors.Purple,
	Transparency = Config.RingOpacity, AlwaysOnTop = true, ZIndex = 5,
	CFrame = CFrame.Angles(math.rad(90), 0, 0), Visible = false,
}, gui)

bind(RunService.Heartbeat, function()
	local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
	if root and Config.ParryRing and Config.AutoParry and E.radius then
		ring.Adornee = root
		ring.Radius = E.radius
		ring.InnerRadius = math.max(0.2, E.radius - 0.4)
		ring.Visible = true
	else
		ring.Visible = false
	end
end)

--=============================================================
-- ESP
--=============================================================
local espFolder = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ZIndex = 1}, gui)
local espObjs = {}

local function project(v)
	local sp, on = Camera:WorldToViewportPoint(v)
	if not on then return nil end
	return Vector2.new(sp.X, sp.Y)
end

local function makeEsp()
	local o = {}
	o.box = new("Frame", {BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ZIndex = 2}, espFolder)
	o.st = new("UIStroke", {Color = T.Accent, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, o.box)
	return o
end

bind(RunService.RenderStepped, function()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LP then
			local o = espObjs[plr] or makeEsp()
			espObjs[plr] = o
			local char = plr.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if Config.EspEnabled and hrp then
				local top = project(hrp.Position + Vector3.new(0, 3, 0))
				local bot = project(hrp.Position - Vector3.new(0, 3, 0))
				if top and bot then
					local h = math.abs(bot.Y - top.Y)
					local w = h * 0.55
					o.box.Visible = true
					o.box.Size = UDim2.new(0, w, 0, h)
					o.box.Position = UDim2.new(0, top.X - w / 2, 0, math.min(top.Y, bot.Y))
				else
					o.box.Visible = false
				end
			else
				o.box.Visible = false
			end
		end
	end
end)

--=============================================================
-- KORBLOX
--=============================================================
local KORBLOX_BUNDLE = 139607718
function applyKorblox()
	local char = LP.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	if Config.KorbloxMethod == "Bundle" then
		local ok = pcall(function()
			local desc = hum:GetAppliedDescription()
			desc.RightLeg = KORBLOX_BUNDLE
			hum:ApplyDescription(desc)
		end)
		if ok then return end
	end

	local leg = char:FindFirstChild("Right Leg") or char:FindFirstChild("RightLeg")
	if not leg or not leg:IsA("BasePart") then return end
	leg.Color = Color3.fromRGB(25, 25, 28)
	local mesh = leg:FindFirstChild("KorbloxMesh")
	if not mesh then
		mesh = new("SpecialMesh", {Name = "KorbloxMesh", MeshType = Enum.MeshType.FileMesh,
			MeshId = Config.KorbloxMesh, Scale = Vector3.new(Config.KorbloxThin, 1, Config.KorbloxThin)}, leg)
	end
end

bind(LP.CharacterAdded, function()
	task.wait(1)
	if Config.Korblox then applyKorblox() end
end)

--=============================================================
-- SPEED BOOST / SKY
--=============================================================
local skyPart
local function setSky(on)
	if on and not skyPart then
		skyPart = new("Part", {Anchored = true, CanCollide = false, Size = Vector3.new(1,1,1),
			Transparency = 1, Position = Vector3.new(0, 140, 0), Parent = Workspace})
		new("ParticleEmitter", {Parent = skyPart, Rate = 60, Lifetime = NumberRange.new(6, 10),
			Speed = NumberRange.new(0, 2), SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new(0.7), Color = ColorSequence.new(Color3.fromRGB(255,255,255)),
			Texture = "rbxassetid://241784099", LightEmission = 1})
	end
	if skyPart then skyPart.ParticleEmitter.Enabled = on end
end

bind(RunService.Heartbeat, function()
	local char = LP.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = Config.SpeedBoost and Config.SpeedValue or 16
	end
end)

--=============================================================
-- HUD
--=============================================================
local hud = new("TextLabel", {
	Size = UDim2.new(0, 260, 0, 70), Position = UDim2.new(0, 20, 0, 120),
	BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 13,
	TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top, Text = "",
}, gui)

bind(RunService.Heartbeat, function()
	if not Config.Debug then hud.Text = "" return end
	hud.Text = string.format(
		"dist %.1f  cpa %.1f  dot %.2f\napp %.1f  r %.1f  tgt %s\none %s  unstable %s  mode %s",
		E.dist, E.cpa, E.prevDot, 0, E.radius or 0, tostring(E.targeted),
		tostring(E.onePressed), tostring(E.unstable), tostring(E.mode))
end)

--=============================================================
-- KEYBINDS
--=============================================================
bind(UserInputService.InputBegan, function(i, gp)
	if gp then return end
	if i.KeyCode == Config.MenuKey then
		win.Visible = not win.Visible
	elseif i.KeyCode == Enum.KeyCode[Config.OneParryKey] then
		Config.OneParry = not Config.OneParry
		notify("One-Parry: " .. (Config.OneParry and "ON" or "OFF"))
		queueSave()
	end
end)

--=============================================================
-- UNLOAD
--=============================================================
function unload()
	for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
	pcall(function() gui:Destroy() end)
	pcall(function()
		if skyPart then skyPart:Destroy() end
		Lighting.ClockTime = 14
		Lighting.Brightness = 2
		Camera.FieldOfView = 70
	end)
end

--=============================================================
if Config.Korblox then task.spawn(function() task.wait(1); applyKorblox() end) end
notify("𝒮𝒸𝓇𝒾𝓅𝓉𝒮𝓁𝑒𝑒𝓅 загружен  |  strict flight gate")
