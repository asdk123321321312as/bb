-- ============================================================
--   𝒮𝒸𝓇𝒾𝓅𝓉𝒮𝓁𝑒𝑒𝓅   |   blade ball   |   bypass build
--   CONFIG_VER 10  (strict-flight gate)
-- ============================================================

local CONFIG_VER = 10

local cloneref = cloneref or function(o) return o end
local Players      = cloneref(game:GetService("Players"))
local RunService   = cloneref(game:GetService("RunService"))
local UIS          = cloneref(game:GetService("UserInputService"))
local VIM          = cloneref(game:GetService("VirtualInputManager"))
local Stats        = cloneref(game:GetService("Stats"))
local Lighting     = cloneref(game:GetService("Lighting"))
local TweenService = cloneref(game:GetService("TweenService"))
local HttpService  = cloneref(game:GetService("HttpService"))

local LP = Players.LocalPlayer
local gethui = gethui or function() return game:GetService("CoreGui") end
local protect_gui = (syn and syn.protect_gui) or function() end

local FILE = "ScriptSleep_BladeBall.json"

-- ============================================================
--  CONFIG
-- ============================================================
local Config = {
    VER = CONFIG_VER,

    AutoParry   = true,
    OneParry    = true,          -- жать только один раз на подход
    OneParryKey = "H",           -- бинд вкл/выкл One-Parry

    -- строгая геометрия
    MinDot        = 0.50,        -- мяч должен лететь в тебя
    MinApproach   = 10,          -- мин. скорость сближения
    CpaFactor     = 0.95,        -- предсказанное сближение внутри радиуса
    DeflectSuppress = 0.05,      -- окно строгости после смены направления

    -- радиус (адаптивный к скорости)
    RadiusPerSpeed = 0.05,
    MinRadius      = 8,
    MaxRadius      = 34,
    PressWindow    = 0.085,      -- доп. окно для очень быстрых мячей

    -- движение
    MoveSpeed     = 8,
    UnstableSpeed = 22,
    MoveAssist    = 1.18,

    MinRepressGap = 0.05,
    MouseFallback = true,

    EspEnabled  = true,
    ParryRing   = true,
    Debug       = false,

    Korblox     = false,
    SpeedBoost  = false,
    SpeedValue  = 26,
    SkyParticles = false,
    AbilityGuard = true,
}

local TUNING_KEYS = {
    "MinDot","MinApproach","CpaFactor","DeflectSuppress",
    "RadiusPerSpeed","MinRadius","MaxRadius","PressWindow",
    "MoveSpeed","UnstableSpeed","MoveAssist","MinRepressGap",
}
local function resetTuning()
    local defaults = {
        MinDot=0.50, MinApproach=10, CpaFactor=0.95, DeflectSuppress=0.05,
        RadiusPerSpeed=0.05, MinRadius=8, MaxRadius=34, PressWindow=0.085,
        MoveSpeed=8, UnstableSpeed=22, MoveAssist=1.18, MinRepressGap=0.05,
    }
    for _,k in ipairs(TUNING_KEYS) do Config[k] = defaults[k] end
end

-- ============================================================
--  SAVE / LOAD
-- ============================================================
local function readJSON(p, default)
    local ok, d = pcall(function() return HttpService:JSONDecode(readfile(p)) end)
    if ok and type(d) == "table" then return d end
    return default
end
local function writeJSON(p, t)
    pcall(function() writefile(p, HttpService:JSONEncode(t)) end)
end

do
    local saved = readJSON(FILE, {})
    for k,v in pairs(saved) do if Config[k] ~= nil then Config[k] = v end end
    if saved.VER ~= CONFIG_VER then
        resetTuning()
        Config.VER = CONFIG_VER
        writeJSON(FILE, Config)
    end
end

local function queueSave()
    task.spawn(function() writeJSON(FILE, Config) end)
end

-- ============================================================
--  STATE
-- ============================================================
local E = {
    ball = nil, pressAt = 0, lastPress = 0, onePressed = false,
    prevDot = 0, deflectAt = 0, moving = false, unstable = false,
    lastPos = nil, redBall = false, redChar = false, redAt = 0,
    tgt = nil, cpa = math.huge, dist = math.huge,
}

local function notify(txt)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "𝒮𝒸𝓇𝒾𝓅𝓉𝒮𝓁𝑒𝑒𝓅", Text = txt, Duration = 3,
        })
    end)
end

-- ============================================================
--  PING
-- ============================================================
local _ping, _pingAt = 60, 0
local function ping()
    local now = os.clock()
    if now - _pingAt > 1 then
        _pingAt = now
        local ok, p = pcall(function() return LP:GetNetworkPing() end)
        if ok and type(p) == "number" then _ping = p * 1000 end
    end
    return _ping
end

-- ============================================================
--  RED DETECTION
-- ============================================================
local function isRedColor(c)
    return c.R > 0.55 and c.G < 0.50 and c.B < 0.50
end

local function scanRed(obj)
    for _, d in ipairs(obj:GetDescendants()) do
        if d:IsA("BasePart") then
            if isRedColor(d.Color) then return true end
        elseif d:IsA("PointLight") then
            if isRedColor(d.Color) then return true end
        elseif d:IsA("Highlight") then
            if d.Enabled and (isRedColor(d.FillColor) or isRedColor(d.OutlineColor)) then return true end
        elseif d:IsA("SelectionBox") then
            if isRedColor(d.Color) then return true end
        elseif d:IsA("ParticleEmitter") then
            local ok, c = pcall(function() return d.Color end)
            if ok and typeof(c) == "ColorSequence" and isRedColor(c.Keypoints[1].Value) then return true end
        end
    end
    return false
end

local function ballIsRed(ball)
    if not ball then return false end
    local ok, r = pcall(function()
        if ball:IsA("BasePart") and isRedColor(ball.Color) then return true end
        return scanRed(ball)
    end)
    return ok and r or false
end

local function charIsRed(char)
    if not char then return false end
    local ok, r = pcall(function() return scanRed(char) end)
    return ok and r or false
end

-- ============================================================
--  BALL / GEOMETRY
-- ============================================================
local function ballVelocity(ball)
    local v = ball.AssemblyLinearVelocity
    if not v or v.Magnitude < 0.1 then v = ball.Velocity end
    return v or Vector3.zero
end

local function getBallFolder()
    return workspace:FindFirstChild("Balls")
end

-- возвращает таблицу с геометрией относительно игрока
local function evalBall(ball, root)
    local ok, ev = pcall(function()
        local pos = ball.Position
        local rel = pos - root.Position           -- мяч относительно игрока
        local dist = rel.Magnitude
        if dist > 300 then return nil end
        local dirToMe = dist > 0.01 and (-rel) / dist or Vector3.zero
        local bv  = ballVelocity(ball)
        local rv  = root.AssemblyLinearVelocity
        local relVel = bv - rv
        local speed  = bv.Magnitude
        local dot    = speed > 0.1 and bv.Unit:Dot(dirToMe) or 0
        local approach = relVel:Dot(dirToMe)

        -- closest point of approach
        local vv = relVel:Dot(relVel)
        local t = 0
        if vv > 1e-6 then t = math.clamp(-rel:Dot(relVel) / vv, 0, 2) end
        local cpa = (rel + relVel * t).Magnitude

        return {
            ball = ball, dist = dist, dir = dirToMe, speed = speed,
            dot = dot, approach = approach, cpa = cpa,
            eta = approach > 0.5 and (dist / math.max(approach, 1)) or dist / math.max(speed, 1),
        }
    end)
    return ok and ev or nil
end

local function isTargeted(ev)
    -- эвристика: летит в игрока и предсказание сближения близко
    return ev.dot > 0.7 and ev.cpa < 25 and ev.approach > 0
end

local function computeRadius(speed)
    local r = speed * Config.RadiusPerSpeed
    r = r + math.min(ping() * 0.04, 4)          -- пинг-комп
    r = math.clamp(r, Config.MinRadius, Config.MaxRadius)
    if E.unstable then r = r * Config.MoveAssist end
    return r
end

-- ============================================================
--  PARRY
-- ============================================================
local function doParry()
    local now = os.clock()
    if now - E.lastPress < Config.MinRepressGap then return end
    E.lastPress = now
    E.pressAt   = now

    pcall(function() keypress(0x46) end)
    task.delay(0.02, function() pcall(function() keyrelease(0x46) end) end)

    if Config.MouseFallback then
        task.spawn(function()
            pcall(function()
                VIM:SendMouseButtonEvent(0, 0, 0, true,  game, 0)
                task.wait(0.01)
                VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
            end)
        end)
    end
end

-- ============================================================
--  CORE STEP
-- ============================================================
local function step()
    if not Config.AutoParry then E.ball = nil return end

    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then E.ball = nil return end

    local now = os.clock()
    local rv  = root.AssemblyLinearVelocity
    E.moving   = rv.Magnitude > Config.MoveSpeed
    E.unstable = rv.Magnitude > Config.UnstableSpeed or math.abs(rv.Y) > 12
    if E.lastPos and (root.Position - E.lastPos).Magnitude > 8 then E.unstable = true end
    E.lastPos = root.Position

    local folder = getBallFolder()
    if not folder then E.ball = nil return end

    -- выбрать лучший мяч (цель в приоритете, затем наименьший eta)
    local best, bestScore
    for _, ball in ipairs(folder:GetChildren()) do
        if ball:IsA("BasePart") then
            local ev = evalBall(ball, root)
            if ev then
                local score = (isTargeted(ev) and 0 or 1000) + ev.eta * 10 + ev.cpa
                if not bestScore or score < bestScore then best, bestScore = ev, score end
            end
        end
    end
    if not best then E.ball = nil return end

    local ev = best
    E.tgt, E.cpa, E.dist = ev.ball, ev.cpa, ev.dist
    local radius = computeRadius(ev.speed)

    -- красное (троттлинг)
    if now - E.redAt > 0.05 then
        E.redAt = now
        E.redBall = ballIsRed(ev.ball)
        E.redChar = charIsRed(char)
    end

    -- детект смены направления (deflect)
    if E.prevDot > 0.25 and ev.dot < -0.15 then E.deflectAt = now end
    E.prevDot = ev.dot

    -- перезарядка One-Parry (только на реальный уход мяча)
    if ev.ball ~= E.ball then E.onePressed = false end
    if ev.dist > radius * 1.5 or ev.speed < 3 or ev.dot < -0.20 then E.onePressed = false end
    if now - E.pressAt > 0.6 then E.onePressed = false end
    E.ball = ev.ball

    -- ослабление при движении/прыжке
    local dotMin = E.unstable and (Config.MinDot * 0.6) or Config.MinDot
    local appMin = E.unstable and (Config.MinApproach * 0.5) or Config.MinApproach
    local cpaFac = E.unstable and (Config.CpaFactor * 1.25) or Config.CpaFactor

    local suppress = (now - E.deflectAt) < Config.DeflectSuppress

    local dotOk  = ev.dot >= dotMin
    local appOk  = ev.approach >= appMin
    local cpaOk  = ev.cpa <= radius * cpaFac
    local rangeOk = ev.dist <= radius or (ev.eta <= Config.PressWindow and ev.approach > 0)

    local geo = rangeOk and dotOk and appOk and cpaOk
    if suppress then geo = geo and ev.dot > 0.2 and ev.approach > 0 end

    -- красный путь: ОБА красных + летит на тебя
    local redOk = E.redBall and E.redChar and ev.dist <= radius * 1.1
                  and ev.approach > 0 and ev.dot > 0.35

    local wantPress = geo or redOk
    if wantPress and ((not Config.OneParry) or (not E.onePressed)) then
        doParry()
        E.onePressed = true
    end
end

-- ============================================================
--  UI
-- ============================================================
local function newInst(cls, props, parent)
    local o = Instance.new(cls)
    for k,v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local gui = newInst("ScreenGui", { Name = "ScriptSleep", ResetOnSpawn = false })
protect_gui(gui)
gui.Parent = gethui()

local main = newInst("Frame", {
    Parent = gui, Size = UDim2.new(0, 430, 0, 300),
    Position = UDim2.new(0, 20, 0, 100),
    BackgroundColor3 = Color3.fromRGB(12,12,12), BorderSizePixel = 0,
    Active = true, Draggable = true,
}, gui)
newInst("UICorner", { CornerRadius = UDim.new(0,10) }, main)
newInst("UIStroke", { Color = Color3.fromRGB(255,255,255), Thickness = 1, Transparency = 0.7 }, main)

local header = newInst("Frame", {
    Parent = main, Size = UDim2.new(1,0,0,34),
    BackgroundColor3 = Color3.fromRGB(18,18,18), BorderSizePixel = 0,
}, main)
newInst("UICorner", { CornerRadius = UDim.new(0,10) }, header)
newInst("TextLabel", {
    Parent = header, Size = UDim2.new(1,-10,1,0), Position = UDim2.new(0,10,0,0),
    BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 15,
    TextColor3 = Color3.fromRGB(255,255,255), TextXAlignment = Enum.TextXAlignment.Left,
    Text = "𝒮𝒸𝓇𝒾𝓅𝓉𝒮𝓁𝑒𝑒𝓅",
}, header)

local tabBar = newInst("Frame", {
    Parent = main, Size = UDim2.new(1,-16,0,26), Position = UDim2.new(0,8,0,40),
    BackgroundTransparency = 1,
}, main)
newInst("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0,6) }, tabBar)

local pageHolder = newInst("Frame", {
    Parent = main, Size = UDim2.new(1,-16,1,-76), Position = UDim2.new(0,8,0,70),
    BackgroundTransparency = 1,
}, main)

local pages, tabButtons = {}, {}
local function makeTab(name)
    local page = newInst("ScrollingFrame", {
        Parent = pageHolder, Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1,
        ScrollBarThickness = 3, CanvasSize = UDim2.new(0,0,0,400), Visible = false,
        BorderSizePixel = 0,
    })
    newInst("UIListLayout", { Padding = UDim.new(0,6) }, page)
    pages[name] = page
    local btn = newInst("TextButton", {
        Parent = tabBar, Size = UDim2.new(0,90,1,0), BackgroundColor3 = Color3.fromRGB(25,25,25),
        BorderSizePixel = 0, Font = Enum.Font.Gotham, TextSize = 12,
        TextColor3 = Color3.fromRGB(200,200,200), Text = name,
    })
    newInst("UICorner", { CornerRadius = UDim.new(0,6) }, btn)
    btn.MouseButton1Click:Connect(function()
        for n,p in pairs(pages) do p.Visible = (n == name) end
    end)
    tabButtons[name] = btn
    return page
end

local function sectionTitle(page, txt)
    newInst("TextLabel", {
        Parent = page, Size = UDim2.new(1,0,0,20), BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.fromRGB(255,255,255),
        TextXAlignment = Enum.TextXAlignment.Left, Text = txt,
    }, page)
end

local function makeToggle(page, label, key, cb)
    local row = newInst("Frame", { Parent = page, Size = UDim2.new(1,0,0,26), BackgroundTransparency = 1 }, page)
    newInst("TextLabel", {
        Parent = row, Size = UDim2.new(0.65,0,1,0), BackgroundTransparency = 1,
        Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Color3.fromRGB(210,210,210),
        TextXAlignment = Enum.TextXAlignment.Left, Text = label,
    })
    local btn = newInst("TextButton", {
        Parent = row, Size = UDim2.new(0,60,0,22), Position = UDim2.new(1,-60,0,2),
        BackgroundColor3 = Config[key] and Color3.fromRGB(255,255,255) or Color3.fromRGB(35,35,35),
        BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextSize = 11,
        TextColor3 = Config[key] and Color3.fromRGB(0,0,0) or Color3.fromRGB(200,200,200),
        Text = Config[key] and "ON" or "OFF",
    })
    newInst("UICorner", { CornerRadius = UDim.new(0,6) }, btn)
    btn.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        btn.BackgroundColor3 = Config[key] and Color3.fromRGB(255,255,255) or Color3.fromRGB(35,35,35)
        btn.TextColor3 = Config[key] and Color3.fromRGB(0,0,0) or Color3.fromRGB(200,200,200)
        btn.Text = Config[key] and "ON" or "OFF"
        queueSave()
        if cb then cb(Config[key]) end
    end)
end

local function makeSlider(page, label, key, min, max, step, cb)
    local row = newInst("Frame", { Parent = page, Size = UDim2.new(1,0,0,34), BackgroundTransparency = 1 }, page)
    local lbl = newInst("TextLabel", {
        Parent = row, Size = UDim2.new(1,0,0,14), BackgroundTransparency = 1,
        Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Color3.fromRGB(200,200,200),
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = label .. ": " .. tostring(Config[key]),
    })
    local bar = newInst("Frame", {
        Parent = row, Size = UDim2.new(1,-10,0,6), Position = UDim2.new(0,0,0,20),
        BackgroundColor3 = Color3.fromRGB(35,35,35), BorderSizePixel = 0,
    })
    newInst("UICorner", { CornerRadius = UDim.new(0,3) }, bar)
    local fill = newInst("Frame", {
        Parent = bar, Size = UDim2.new((Config[key]-min)/(max-min),0,1,0),
        BackgroundColor3 = Color3.fromRGB(255,255,255), BorderSizePixel = 0,
    })
    newInst("UICorner", { CornerRadius = UDim.new(0,3) }, fill)
    local dragging = false
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local rel = math.clamp((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            local val = min + (max - min) * rel
            val = math.floor(val / step + 0.5) * step
            Config[key] = val
            fill.Size = UDim2.new(rel, 0, 1, 0)
            lbl.Text = label .. ": " .. tostring(val)
            if cb then cb(val) end
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then queueSave() end
    end)
end

-- ---- COMBAT ----
local combat = makeTab("Combat")
sectionTitle(combat, "AUTOPARRY")
makeToggle(combat, "Auto Parry", "AutoParry")
makeToggle(combat, "Parry Only Once (" .. Config.OneParryKey .. ")", "OneParry")
sectionTitle(combat, "FLIGHT GATE")
makeSlider(combat, "Min Dot (летит в тебя)", "MinDot", 0.2, 0.95, 0.05)
makeSlider(combat, "Min Approach", "MinApproach", 0, 40, 1)
makeSlider(combat, "CPA Factor", "CpaFactor", 0.5, 1.3, 0.05)
sectionTitle(combat, "RADIUS")
makeSlider(combat, "Radius per Speed", "RadiusPerSpeed", 0.01, 0.15, 0.005)
makeSlider(combat, "Min Radius", "MinRadius", 4, 30, 1)
makeSlider(combat, "Max Radius", "MaxRadius", 10, 60, 1)
makeSlider(combat, "Press Window", "PressWindow", 0.02, 0.2, 0.005)
sectionTitle(combat, "MOVEMENT")
makeSlider(combat, "Unstable Speed", "UnstableSpeed", 10, 50, 1)
makeSlider(combat, "Move Assist", "MoveAssist", 1, 1.5, 0.02)

-- ---- VISUALS ----
local visuals = makeTab("Visuals")
sectionTitle(visuals, "VISUALS")
makeToggle(visuals, "ESP", "EspEnabled")
makeToggle(visuals, "Parry Ring", "ParryRing")
makeToggle(visuals, "Sky Particles", "SkyParticles")
makeToggle(visuals, "Debug HUD", "Debug")

-- ---- CHARACTER ----
local character = makeTab("Character")
sectionTitle(character, "CHARACTER")
makeToggle(character, "Korblox Leg", "Korblox", function(on) if on then applyKorblox() end end)
makeToggle(character, "Speed Boost", "SpeedBoost")
makeSlider(character, "WalkSpeed", "SpeedValue", 16, 80, 1)

-- ---- MISC ----
local misc = makeTab("Misc")
sectionTitle(misc, "MISC")
makeToggle(misc, "Ability Guard", "AbilityGuard")
makeToggle(misc, "Mouse Fallback", "MouseFallback")
local resetBtn = newInst("TextButton", {
    Parent = misc, Size = UDim2.new(1,0,0,26), BackgroundColor3 = Color3.fromRGB(25,25,25),
    BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextSize = 12,
    TextColor3 = Color3.fromRGB(255,255,255), Text = "Reset Tuning",
})
newInst("UICorner", { CornerRadius = UDim.new(0,6) }, resetBtn)
resetBtn.MouseButton1Click:Connect(function()
    resetTuning(); queueSave(); notify("Tuning reset — перезапусти скрипт")
end)

pages["Combat"].Visible = true

-- ============================================================
--  KEYBIND (One-Parry toggle)
-- ============================================================
UIS.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode[Config.OneParryKey] then
        Config.OneParry = not Config.OneParry
        notify("One-Parry: " .. (Config.OneParry and "ON" or "OFF"))
        queueSave()
    end
end)

-- ============================================================
--  ESP
-- ============================================================
local function updateESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local hl = plr.Character:FindFirstChild("SS_ESP")
            if Config.EspEnabled then
                if not hl then
                    hl = newInst("Highlight", { Name = "SS_ESP", Parent = plr.Character,
                        FillColor = Color3.fromRGB(255,255,255),
                        OutlineColor = Color3.fromRGB(0,0,0),
                        FillTransparency = 0.6, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop })
                end
            elseif hl then hl:Destroy() end
        end
    end
end

-- ============================================================
--  PARRY RING
-- ============================================================
local ring
local function updateRing(root, radius)
    if not Config.ParryRing then
        if ring then ring.Adornee = nil end
        return
    end
    if not ring then
        ring = newInst("CylinderHandleAdornment", {
            Adornee = root, Parent = root, Height = 0.1,
            Radius = radius, Color3 = Color3.fromRGB(255,255,255),
            Transparency = 0.7, AlwaysOnTop = true,
        })
    end
    ring.Adornee = root
    ring.Radius = radius
end

-- ============================================================
--  KORBLOX
-- ============================================================
local KORBLOX_BUNDLE = 139607718
function applyKorblox()
    local char = LP.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local ok = pcall(function()
        local desc = hum:GetAppliedDescription()
        desc.RightLeg = KORBLOX_BUNDLE
        hum:ApplyDescription(desc)
    end)
    if not ok then
        -- fallback: тёмный тонкий меш на R6
        local leg = char:FindFirstChild("Right Leg")
        if leg and leg:IsA("BasePart") then
            leg.Color = Color3.fromRGB(20,20,20)
        end
    end
end

-- ============================================================
--  SKY PARTICLES
-- ============================================================
local skyPart
local function setSky(on)
    if on and not skyPart then
        skyPart = newInst("Part", { Anchored = true, CanCollide = false, Size = Vector3.new(1,1,1),
            Transparency = 1, Position = Vector3.new(0,140,0), Parent = workspace })
        local pe = newInst("ParticleEmitter", { Parent = skyPart, Rate = 60,
            Lifetime = NumberRange.new(6,10), Speed = NumberRange.new(0,2),
            SpreadAngle = Vector2.new(180,180), Size = NumberSequence.new(0.7),
            Color = ColorSequence.new(Color3.fromRGB(255,255,255)),
            Texture = "rbxasset://textures/particles/sparkles_main.dds", LightEmission = 1 })
        pe.Enabled = true
    end
    if skyPart then skyPart.ParticleEmitter.Enabled = on end
end

-- ============================================================
--  SPEED / ABILITY GUARD
-- ============================================================
local function updateChar()
    local char = LP.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = Config.SpeedBoost and Config.SpeedValue or 16
    end
end

-- ============================================================
--  DEBUG HUD
-- ============================================================
local hud = newInst("TextLabel", {
    Parent = gui, Size = UDim2.new(0,260,0,80), Position = UDim2.new(0,20,0,410),
    BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 13,
    TextColor3 = Color3.fromRGB(255,255,255), TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top, Text = "",
})
local function updateHUD(radius)
    if not Config.Debug then hud.Text = "" return end
    hud.Text = string.format(
        "dist %.1f | cpa %.1f | dot %.2f\napp %.1f | r %.1f | red %s/%s\nmoving %s | one %s",
        E.dist, E.cpa, E.prevDot, 0, radius or 0,
        tostring(E.redBall), tostring(E.redChar), tostring(E.unstable), tostring(E.onePressed))
end

-- ============================================================
--  MAIN LOOP
-- ============================================================
RunService.Heartbeat:Connect(function()
    pcall(step)
    local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local radius = 0
    if root and E.ball then radius = computeRadius(E.ball.AssemblyLinearVelocity.Magnitude) end
    pcall(updateRing, root, radius)
    pcall(updateHUD, radius)
end)

task.spawn(function()
    while task.wait(0.5) do
        pcall(updateESP)
        pcall(updateChar)
        pcall(setSky, Config.SkyParticles)
    end
end)

if Config.Korblox then task.spawn(applyKorblox) end

notify("𝒮𝒸𝓇𝒾𝓅𝓉𝒮𝓁𝑒𝑒𝓅 загружен | strict-flight gate")
