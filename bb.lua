--[[
    ╔══════════════════════════════════════════╗
    ║      S L E E P S C R I P T  v4 (GHOST)      ║
    ║      Blade Ball • AntiParry + Anti-BAC      ║
    ║   Меню: [ Z ]   •   AutoParry вкл/выкл: [L] ║
    ╚══════════════════════════════════════════╝
--]]

local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local Stats               = game:GetService("Stats")
local UserInputService    = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService        = game:GetService("TweenService")
local StarterGui          = game:GetService("StarterGui")
local Player              = Players.LocalPlayer

-- ===================== Config =====================
getgenv().Sleep = {
    AutoParry       = true,

    -- ===== STEALTH / ANTI-BAC =====
    AntiBAC         = true,    -- глушить античит (ReplicatedStorage.Security + DeviceChecker)
    AutoRekill      = true,    -- добивать, если античит вернётся
    GhostVisual     = false,   -- вообще не создавать крутилку (нулевой след)

    -- ===== ТАЙМИНГИ =====
    ExecutorInput   = true,
    Jitter          = 0.02,
    Cooldown        = 0.03,
    ClickLimit      = 10,
    LegitMode       = false,
    LegitFactor     = 0.45,

    PingBased       = true,
    PingBasedOffset = 1.95,
    DistanceToParry = 0.65,
    EmergencyRadius = 10,
    ClashDistance   = 22,

    Visuals         = true,
}
local CFG = getgenv().Sleep

-- ===================== ANTI-BAC (глушим античит) =====================
local function notify(t, txt)
    pcall(function() StarterGui:SetCore("SendNotification", {Title = t, Text = txt, Duration = 3}) end)
end

local BAC_KILLED = {}
local function KillBAC()
    local killed = 0
    local RS = game:GetService("ReplicatedStorage")

    -- 1) модуль безопасности в ReplicatedStorage
    local sec = RS:FindFirstChild("Security")
    if sec then sec:Destroy(); killed = killed + 1; BAC_KILLED.Security = true end

    -- 2) клиентские скрипты-проверяльщики
    local ps = Player:FindFirstChild("PlayerScripts")
    if ps then
        for _, obj in ipairs(ps:GetDescendants()) do
            if obj:IsA("LocalScript") or obj:IsA("Script") or obj:IsA("ModuleScript") then
                local n = obj.Name:lower()
                if n:find("security") or n:find("anticheat") or n:find("anti-cheat")
                or n:find("devicechecker") or n == "bac" or n:find("anticheater") then
                    obj:Destroy(); killed = killed + 1
                end
            end
        end
    end

    -- 3) на всякий — ReplicatedFirst
    local rf = game:GetService("ReplicatedFirst")
    local rfsec = rf:FindFirstChild("Security")
    if rfsec then rfsec:Destroy(); killed = killed + 1 end

    return killed
end

if CFG.AntiBAC then
    task.defer(function()
        task.wait(1)
        local n = KillBAC()
        notify("Sleepscript", n > 0 and ("Anti-BAC: отключено ("..n..")") or "Anti-BAC: модули не найдены")
    end)
end

if CFG.AutoRekill then
    task.spawn(function()
        while task.wait(3) do
            if CFG.AntiBAC then
                if RS_SAFE and RS_SAFE.Parent then KillBAC() end
            end
        end
    end)
end

-- ===================== Theme =====================
local Theme = {
    Bg = Color3.fromRGB(12,12,15), Bg2 = Color3.fromRGB(22,22,27),
    Stroke = Color3.fromRGB(48,48,58), Accent = Color3.fromRGB(138,100,255),
    Text = Color3.fromRGB(238,238,244), Sub = Color3.fromRGB(140,140,152),
    Off = Color3.fromRGB(46,46,54),
}

-- ===================== GUI =====================
local gui = Instance.new("ScreenGui")
gui.Name = "Sleepscript"; gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = Player:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(300, 540)
main.Position = UDim2.new(0.5, -150, 0.5, -270)
main.BackgroundColor3 = Theme.Bg
main.BackgroundTransparency = 0.12
main.BorderSizePixel = 0; main.Active = true; main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 14)
local ms = Instance.new("UIStroke", main)
ms.Color = Theme.Stroke; ms.Thickness = 1; ms.Transparency = 0.25
local scale = Instance.new("UIScale", main); scale.Scale = 1

local header = Instance.new("Frame", main)
header.Size = UDim2.new(1, 0, 0, 46)
header.BackgroundColor3 = Theme.Bg2
header.BackgroundTransparency = 0.25; header.BorderSizePixel = 0
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 14)
local hFix = Instance.new("Frame", header)
hFix.Size = UDim2.new(1, 0, 0, 14); hFix.Position = UDim2.new(0, 0, 1, -14)
hFix.BackgroundColor3 = Theme.Bg2; hFix.BackgroundTransparency = 0.25; hFix.BorderSizePixel = 0
local accent = Instance.new("Frame", header)
accent.Size = UDim2.new(1, -28, 0, 2); accent.Position = UDim2.new(0, 14, 1, -2)
accent.BackgroundColor3 = Theme.Accent; accent.BorderSizePixel = 0

local title = Instance.new("TextLabel", header)
title.Text = "Sleepscript"; title.Font = Enum.Font.GothamBold; title.TextSize = 18
title.TextColor3 = Theme.Text; title.BackgroundTransparency = 1
title.TextXAlignment = Enum.TextXAlignment.Left
title.Position = UDim2.new(0, 16, 0, 8); title.Size = UDim2.new(0.7, 0, 0, 22)
local subtitle = Instance.new("TextLabel", header)
subtitle.Text = "Blade Ball • GHOST v4"; subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 11; subtitle.TextColor3 = Theme.Sub; subtitle.BackgroundTransparency = 1
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Position = UDim2.new(0, 16, 0, 27); subtitle.Size = UDim2.new(0.7, 0, 0, 14)

local closeBtn = Instance.new("TextButton", header)
closeBtn.Text = "✕"; closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 15
closeBtn.TextColor3 = Theme.Sub; closeBtn.BackgroundColor3 = Theme.Off
closeBtn.BackgroundTransparency = 0.4; closeBtn.BorderSizePixel = 0
closeBtn.Size = UDim2.fromOffset(26, 26); closeBtn.Position = UDim2.new(1, -34, 0, 10)
closeBtn.AutoButtonColor = false
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

local body = Instance.new("ScrollingFrame", main)
body.Size = UDim2.new(1, -16, 1, -58); body.Position = UDim2.new(0, 8, 0, 52)
body.BackgroundTransparency = 1; body.BorderSizePixel = 0
body.ScrollBarThickness = 3; body.ScrollBarImageColor3 = Theme.Accent
body.CanvasSize = UDim2.new(0, 0, 0, 0)
body.AutomaticCanvasSize = Enum.AutomaticSize.Y
local layout = Instance.new("UIListLayout", body)
layout.Padding = UDim.new(0, 8); layout.SortOrder = Enum.SortOrder.LayoutOrder
local pad = Instance.new("UIPadding", body)
pad.PaddingTop = UDim.new(0, 4); pad.PaddingLeft = UDim.new(0, 4)
pad.PaddingRight = UDim.new(0, 8); pad.PaddingBottom = UDim.new(0, 6)

-- ===================== Helpers =====================
local function makeToggle(label, key)
    local row = Instance.new("Frame", body)
    row.Size = UDim2.new(1, 0, 0, 34); row.BackgroundTransparency = 1; row.LayoutOrder = 100
    local txt = Instance.new("TextLabel", row)
    txt.Text = label; txt.Font = Enum.Font.Gotham; txt.TextSize = 13
    txt.TextColor3 = Theme.Text; txt.BackgroundTransparency = 1
    txt.TextXAlignment = Enum.TextXAlignment.Left; txt.Size = UDim2.new(0.7, 0, 1, 0)
    local btn = Instance.new("TextButton", row)
    btn.Text = ""; btn.AutoButtonColor = false; btn.BorderSizePixel = 0
    btn.Size = UDim2.fromOffset(44, 22); btn.Position = UDim2.new(1, -44, 0.5, -11)
    btn.BackgroundColor3 = CFG[key] and Theme.Accent or Theme.Off
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
    local knob = Instance.new("Frame", btn)
    knob.Size = UDim2.fromOffset(18, 18)
    knob.Position = CFG[key] and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255); knob.BorderSizePixel = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    btn.MouseButton1Click:Connect(function()
        CFG[key] = not CFG[key]
        TweenService:Create(btn, TweenInfo.new(0.18),
            {BackgroundColor3 = CFG[key] and Theme.Accent or Theme.Off}):Play()
        TweenService:Create(knob, TweenInfo.new(0.18),
            {Position = CFG[key] and UDim2.new(1,-20,0.5,-9) or UDim2.new(0,2,0.5,-9)}):Play()
    end)
end

local function makeSlider(label, key, min, max, step)
    local row = Instance.new("Frame", body)
    row.Size = UDim2.new(1, 0, 0, 40); row.BackgroundTransparency = 1; row.LayoutOrder = 100
    local txt = Instance.new("TextLabel", row)
    txt.Text = label; txt.Font = Enum.Font.Gotham; txt.TextSize = 13
    txt.TextColor3 = Theme.Text; txt.BackgroundTransparency = 1
    txt.TextXAlignment = Enum.TextXAlignment.Left; txt.Size = UDim2.new(0.7, 0, 0, 16)
    local decimals = step < 1 and 2 or 0
    local val = Instance.new("TextLabel", row)
    val.Text = string.format("%."..decimals.."f", CFG[key])
    val.Font = Enum.Font.GothamMedium; val.TextSize = 12
    val.TextColor3 = Theme.Accent; val.BackgroundTransparency = 1
    val.TextXAlignment = Enum.TextXAlignment.Right
    val.Size = UDim2.new(0.3, 0, 0, 16); val.Position = UDim2.new(0.7, 0, 0, 0)
    local bar = Instance.new("TextButton", row)
    bar.Text = ""; bar.AutoButtonColor = false; bar.BackgroundColor3 = Theme.Off
    bar.BorderSizePixel = 0; bar.Size = UDim2.new(1, 0, 0, 6)
    bar.Position = UDim2.new(0, 0, 0, 26)
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
    local fill = Instance.new("Frame", bar)
    fill.BackgroundColor3 = Theme.Accent; fill.BorderSizePixel = 0
    fill.Size = UDim2.new((CFG[key]-min)/(max-min), 0, 1, 0)
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    local knob = Instance.new("Frame", bar)
    knob.Size = UDim2.fromOffset(14, 14); knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    knob.BorderSizePixel = 0; knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new((CFG[key]-min)/(max-min), 0, 0.5, 0)
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local dragging = false
    local function setFromX(x)
        local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local v = min + (max - min) * rel
        v = math.floor(v / step + 0.5) * step
        CFG[key] = v
        local rr = (v - min) / (max - min)
        fill.Size = UDim2.new(rr, 0, 1, 0); knob.Position = UDim2.new(rr, 0, 0.5, 0)
        val.Text = string.format("%."..decimals.."f", v)
    end
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then dragging = true; setFromX(i.Position.X) end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch) then setFromX(i.Position.X) end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

local function makeHeader(text)
    local l = Instance.new("TextLabel", body)
    l.Text = text; l.Font = Enum.Font.GothamBold; l.TextSize = 11
    l.TextColor3 = Theme.Sub; l.BackgroundTransparency = 1
    l.TextXAlignment = Enum.TextXAlignment.Left; l.Size = UDim2.new(1, 0, 0, 18)
    l.LayoutOrder = 90
end

-- ===================== Build =====================
makeHeader("STEALTH / ANTI-BAC")
makeToggle("Anti-BAC (глушить)", "AntiBAC")
makeToggle("Auto Re-kill", "AutoRekill")
makeToggle("Ghost Visual (без парта)", "GhostVisual")

makeHeader("ГЛАВНОЕ")
makeToggle("AutoParry", "AutoParry")
makeToggle("Visuals (радиус)", "Visuals")

makeHeader("ТАЙМИНГИ")
makeToggle("Executor Input", "ExecutorInput")
makeToggle("Legit Mode", "LegitMode")
makeSlider("Jitter", "Jitter", 0, 0.15, 0.005)
makeSlider("Cooldown", "Cooldown", 0.01, 0.2, 0.01)
makeSlider("Click Limit /сек", "ClickLimit", 4, 30, 1)

makeHeader("ПАРИ")
makeToggle("Ping Based", "PingBased")
makeSlider("Ping Based Offset", "PingBasedOffset", 0, 5, 0.05)
makeSlider("Distance to Parry", "DistanceToParry", 0.1, 5, 0.05)
makeSlider("Emergency Radius", "EmergencyRadius", 1, 40, 1)
makeSlider("Clash Distance", "ClashDistance", 5, 60, 1)

local hint = Instance.new("TextLabel", body)
hint.Text = "[ Z ] меню   •   [ L ] AutoParry"
hint.Font = Enum.Font.Gotham; hint.TextSize = 10; hint.TextColor3 = Theme.Sub
hint.BackgroundTransparency = 1; hint.TextXAlignment = Enum.TextXAlignment.Center
hint.Size = UDim2.new(1, 0, 0, 16); hint.LayoutOrder = 200

-- ===================== Drag / Menu =====================
local dragging, dragStart, startPos
header.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
    or i.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = i.Position; startPos = main.Position
        i.Changed:Connect(function()
            if i.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
    or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                  startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)

local menuOpen = true
local function setMenu(state)
    if state then
        main.Visible = true; scale.Scale = 0.85
        TweenService:Create(scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Scale = 1}):Play()
    else
        local t = TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Scale = 0.85})
        t:Play(); t.Completed:Connect(function() main.Visible = false end)
    end
end
closeBtn.MouseButton1Click:Connect(function() menuOpen = false; setMenu(false) end)
UserInputService.InputBegan:Connect(function(i, gpe)
    if gpe then return end
    if i.KeyCode == Enum.KeyCode.Z then menuOpen = not menuOpen; setMenu(menuOpen)
    elseif i.KeyCode == Enum.KeyCode.L then CFG.AutoParry = not CFG.AutoParry end
end)

-- ===================== Логика =====================
local LastClick, LastBallHit, IsParrying = 0, nil, false
local frameCounter = 0
local clickTimes = {}
local BallsFolder = workspace:FindFirstChild("Balls") or workspace:WaitForChild("Balls", 5)
local NetworkStats = Stats:FindFirstChild("Network")
    and Stats.Network:FindFirstChild("ServerStatsItem")
    and Stats.Network.ServerStatsItem:FindFirstChild("Data Ping")

-- Крутилка: в Ghost-режиме вообще не создаётся
local r, m
if not CFG.GhostVisual then
    r = Instance.new("Part")
    r.Name = "SleepCircle"; r.Parent = workspace
    r.Anchored, r.CanCollide = true, false
    r.CanQuery, r.CanTouch, r.CastShadow, r.Massless = false, false, false, true
    r.Transparency = 0.3; r.Material = Enum.Material.Neon
    r.Color = Color3.fromRGB(138,100,255)
    m = Instance.new("SpecialMesh", r); m.MeshId = "rbxassetid://3270017"
end

local function PressParry()
    if CFG.ExecutorInput then
        local ok = pcall(function()
            if type(mouse1click) == "function" then
                mouse1click()
            elseif type(mouse1press) == "function" and type(mouse1release) == "function" then
                mouse1press(); mouse1release()
            else
                error("no")
            end
        end)
        if ok then return end
    end
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
end

local function rateOK()
    local now = tick()
    for i = #clickTimes, 1, -1 do
        if now - clickTimes[i] > 1 then table.remove(clickTimes, i) end
    end
    if #clickTimes >= CFG.ClickLimit then return false end
    table.insert(clickTimes, now)
    return true
end

local function GetBall()
    if not BallsFolder then return nil end
    for _, v in ipairs(BallsFolder:GetChildren()) do
        if v:GetAttribute("realBall") == true then return v end
    end
    for _, v in ipairs(BallsFolder:GetChildren()) do
        if v:IsA("BasePart") and v.AssemblyLinearVelocity.Magnitude > 15 then return v end
    end
    return nil
end

local function IsTargeted()
    if not Player.Character then return false end
    return Player.Character:GetAttribute("Targeted") == true
        or Player.Character:FindFirstChild("Highlight") ~= nil
end

local function SendClick(isClashing, ball)
    if not CFG.AutoParry or IsParrying then return end
    local now = tick()
    local cd = CFG.Cooldown + (math.random() - 0.5) * 2 * CFG.Jitter
    if not isClashing and LastBallHit == ball and (now - LastClick) < 0.5 then return end
    if (now - LastClick) < cd then return end
    if not rateOK() then return end

    IsParrying = true; LastClick = now; LastBallHit = ball
    PressParry()
    task.delay(cd, function() IsParrying = false end)
end

local function UpdateVisuals(root, distance, state)
    r.CFrame = root.CFrame * CFrame.new(0, -2.6, 0) * CFrame.Angles(math.rad(90), 0, 0)
    local s = math.clamp(distance * 0.8, 5, 65)
    m.Scale = m.Scale:Lerp(Vector3.new(s, s, 0.5), 0.5)
    if state == "clash" then r.Color = Color3.fromRGB(255,70,70); r.Transparency = 0.05
    elseif state == "target" then r.Color = Color3.fromRGB(0,230,255); r.Transparency = 0.1
    else r.Color = Color3.fromRGB(138,100,255); r.Transparency = 0.5 end
end

RunService.PostSimulation:Connect(function()
    if not CFG.AutoParry then if r then r.Transparency = 1 end return end
    local Char = Player.Character
    local Root = Char and Char:FindFirstChild("HumanoidRootPart")
    if not Root then if r then r.Transparency = 1 end return end
    local Ball = GetBall()
    if not Ball then if r then r.Transparency = 1 end return end

    local BallPos, PlayerPos = Ball.Position, Root.Position
    local Velocity = Ball.AssemblyLinearVelocity
    local Speed = Velocity.Magnitude
    local Distance = (PlayerPos - BallPos).Magnitude
    local dot = ((PlayerPos - BallPos).Unit):Dot(Velocity.Unit)
    if dot < 0 then LastBallHit = nil end

    local Targeted = IsTargeted()
    local IsClashing = Targeted and Distance <= CFG.ClashDistance

    frameCounter = frameCounter + 1
    if r and CFG.Visuals and frameCounter % 2 == 0 then
        r.Transparency = 0.3
        UpdateVisuals(Root, Distance, IsClashing and "clash" or (Targeted and "target" or "neutral"))
    elseif r and not CFG.Visuals then
        r.Transparency = 1
    end

    if IsClashing then
        SendClick(true, Ball)
    elseif Targeted and dot > 0 then
        if CFG.LegitMode then
            local legitDist = math.clamp(Speed * CFG.LegitFactor, 6, 120)
            if Distance <= legitDist or Distance <= CFG.EmergencyRadius then
                SendClick(false, Ball)
            end
        else
            local Ping = (NetworkStats and NetworkStats.Value / 1000) or 0.04
            local TimeToHit = Distance / math.max(Speed, 1)
            local Threshold = CFG.DistanceToParry
                + (CFG.PingBased and (Ping * CFG.PingBasedOffset) or 0)
                + (math.random() - 0.5) * CFG.Jitter
            if Speed > 150 then Threshold = Threshold * 1.15 end
            if TimeToHit <= Threshold or Distance <= CFG.EmergencyRadius then
                SendClick(false, Ball)
            end
        end
    end
end)

Player.CharacterAdded:Connect(function() LastBallHit = nil; IsParrying = false end)
