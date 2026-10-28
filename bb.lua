--[[
    ╔══════════════════════════════════════════════╗
    ║   Sleepscript  |  Blade Ball  |  Real        ║
    ║   Меню: Z   |   Автопари вкл/выкл: L         ║
    ╚══════════════════════════════════════════════╝
]]

-- ==================== НАСТРОЙКИ ====================
getgenv().Sleepscript = {
    ["AutoParry"] = true,
    ["PingBased"] = true,
    ["PingBasedOffset"] = 1.95,
    ["DistanceToParry"] = 0.65,
    ["EmergencyRadius"] = 10,
    ["ClashDistance"] = 22,
    ["ClashSpeed"] = 0.01,
    ["NormalSpeed"] = 0.05,
    ["Visuals"] = true,
    ["ShowRadius"] = true,
    ["AntiCheat"] = true,
    ["AntiKick"] = true,
}

local SETTINGS = getgenv().Sleepscript

-- ==================== СЕРВИСЫ ====================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer

-- ==================== ОПОЗНАВАНИЕ BAC ====================
local BAD_TAGS = {
    ["CHECKER"] = true, ["CHECKER_1"] = true, ["OneMoreTime"] = true,
    ["checkingSPEED"] = true, ["PERMAIDBAN"] = true, ["BANREMOTE"] = true,
    ["KICKREMOTE"] = true, ["TeleportDetect"] = true, ["GUI_CHECK"] = true,
    ["FORCEFIELD"] = true, ["BAC"] = true, ["AntiCheat"] = true, ["AC"] = true,
}

local HOOK_LOG = {}

local function IsBACName(name)
    name = string.lower(tostring(name))
    return string.find(name, "security", 1, true) ~= nil
        or string.find(name, "anticheat", 1, true) ~= nil
        or string.find(name, "anti_cheat", 1, true) ~= nil
        or string.find(name, "anti-cheat", 1, true) ~= nil
        or string.find(name, "checker", 1, true) ~= nil
        or name == "bac" or name == "ac"
end

local function IsBACCall(self, args)
    local a1, a2 = args[1], args[2]
    if type(a1) == "string" and BAD_TAGS[a1] then return true end
    if type(a2) == "string" and BAD_TAGS[a2] then return true end

    local n = self.Name
    if BAD_TAGS[n] or IsBACName(n) then return true end

    local p = self.Parent
    local depth = 0
    while p and depth < 8 do
        if IsBACName(p.Name) then return true end
        p = p.Parent
        depth = depth + 1
    end
    return false
end

-- Security оставляем живым, иначе его RemoteEvent умирает вместе с папкой
local function KillBAC()
    local found = {}
    local ps = Player:FindFirstChild("PlayerScripts")
    local client = ps and ps:FindFirstChild("Client")
    if client then
        for _, name in ipairs({ "DeviceChecker", "ClientChecker" }) do
            local d = client:FindFirstChild(name)
            if d then
                table.insert(found, "Client." .. name)
                pcall(function() d:Destroy() end)
            end
        end
    end
    if ReplicatedStorage:FindFirstChild("Security") then
        table.insert(found, "Security (kept alive)")
    end
    return found
end

-- ==================== ГЛАВНЫЙ ХУК ====================
local function Handler(self, ...)
    local method = getnamecallmethod()

    if method == "Kick" then
        if SETTINGS.AntiKick then
            local msg = string.lower(tostring((...)))
            if string.find(msg, "bac", 1, true) or string.find(msg, "exploit", 1, true) then
                return true
            end
        end
    elseif method == "FireServer" or method == "InvokeServer" then
        if SETTINGS.AntiCheat then
            local args = { ... }
            local full = self:GetFullName()

            if not HOOK_LOG[full] then
                HOOK_LOG[full] = true
                print("[Sleepscript][FS]", full)
            end

            if IsBACCall(self, args) then
                print("[Sleepscript] BLOCKED", full)
                return true
            end
        end
    end

    return false
end

local function InstallHook()
    if hookmetamethod then
        local old
        old = hookmetamethod(game, "__namecall", function(self, ...)
            if Handler(self, ...) then return end
            return old(self, ...)
        end)
        return true
    end

    if getrawmetatable then
        local mt = getrawmetatable(game)
        local old = mt.__namecall
        setreadonly(mt, false)
        local wrap = newcclosure or function(f) return f end
        mt.__namecall = wrap(function(self, ...)
            if Handler(self, ...) then return end
            return old(self, ...)
        end)
        setreadonly(mt, true)
        return true
    end

    return false
end

local hookOk, hookRes = pcall(InstallHook)
print("[Sleepscript] hook:", (hookOk and hookRes) and "installed" or "FAILED")
print("[Sleepscript] BAC killed:", table.concat(KillBAC(), " | "))

-- ==================== ТЕМА ====================
local THEME = {
    BG     = Color3.fromRGB(10, 10, 13),
    PANEL  = Color3.fromRGB(17, 17, 22),
    TRACK  = Color3.fromRGB(38, 38, 48),
    STROKE = Color3.fromRGB(38, 38, 48),
    TEXT   = Color3.fromRGB(235, 235, 242),
    SUB    = Color3.fromRGB(125, 125, 140),
    ACCENT = Color3.fromRGB(0, 200, 255),
}

local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function corner(o, r)
    return new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o)
end

local function stroke(o, c, t)
    return new("UIStroke", {
        Color = c or THEME.STROKE,
        Thickness = t or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    }, o)
end

-- ==================== GUI ====================
local parentGui = (gethui and gethui()) or game:GetService("CoreGui")

local Gui = new("ScreenGui", {
    Name = "Sleepscript",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,
}, parentGui)

if protect_gui then pcall(protect_gui, Gui) end
if syn and syn.protect_gui then pcall(syn.protect_gui, Gui) end

local Main = new("Frame", {
    Name = "Main",
    Size = UDim2.fromOffset(310, 120),
    Position = UDim2.new(0.5, -155, 0.5, -280),
    BackgroundColor3 = THEME.BG,
    BorderSizePixel = 0,
}, Gui)
corner(Main, 12)
stroke(Main, THEME.STROKE, 1)

-- ---------- Шапка ----------
local Header = new("Frame", {
    Size = UDim2.new(1, 0, 0, 50),
    BackgroundColor3 = THEME.PANEL,
    BorderSizePixel = 0,
    ZIndex = 1,
}, Main)
corner(Header, 12)

new("Frame", {
    Size = UDim2.new(1, 0, 0, 12),
    Position = UDim2.new(0, 0, 1, -12),
    BackgroundColor3 = THEME.PANEL,
    BorderSizePixel = 0,
    ZIndex = 2,
}, Header)

new("Frame", {
    Size = UDim2.new(1, 0, 0, 1),
    Position = UDim2.new(0, 0, 1, -1),
    BackgroundColor3 = THEME.STROKE,
    BorderSizePixel = 0,
    ZIndex = 3,
}, Header)

local Dot = new("Frame", {
    Size = UDim2.fromOffset(8, 8),
    Position = UDim2.new(0, 16, 0, 13),
    BackgroundColor3 = THEME.ACCENT,
    BorderSizePixel = 0,
    ZIndex = 3,
}, Header)
corner(Dot, 4)

new("TextLabel", {
    Size = UDim2.new(1, -80, 0, 18),
    Position = UDim2.new(0, 32, 0, 8),
    BackgroundTransparency = 1,
    Text = "Sleepscript",
    TextColor3 = THEME.TEXT,
    Font = Enum.Font.GothamBold,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 3,
}, Header)

new("TextLabel", {
    Size = UDim2.new(1, -80, 0, 14),
    Position = UDim2.new(0, 32, 0, 26),
    BackgroundTransparency = 1,
    Text = "Blade Ball  •  AutoParry",
    TextColor3 = THEME.SUB,
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 3,
}, Header)

local Close = new("TextButton", {
    Size = UDim2.fromOffset(22, 22),
    Position = UDim2.new(1, -30, 0, 14),
    BackgroundColor3 = THEME.TRACK,
    Text = "x",
    TextColor3 = THEME.SUB,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    AutoButtonColor = false,
    ZIndex = 3,
}, Header)
corner(Close, 6)

-- ---------- Контент ----------
local Content = new("Frame", {
    Size = UDim2.new(1, 0, 0, 0),
    Position = UDim2.new(0, 0, 0, 50),
    BackgroundTransparency = 1,
    ZIndex = 1,
}, Main)

local CURSOR = 6

local function place(obj, height)
    obj.Size = UDim2.new(1, -24, 0, height)
    obj.Position = UDim2.new(0, 12, 0, CURSOR)
    obj.Parent = Content
    CURSOR = CURSOR + height + 5
    return obj
end

-- ---------- Элементы ----------
local function Section(text)
    place(new("TextLabel", {
        BackgroundTransparency = 1,
        Text = string.upper(text),
        TextColor3 = THEME.SUB,
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
    }), 18)
end

local function Toggle(text, default, callback)
    local Row = new("Frame", { BackgroundTransparency = 1 })

    new("TextLabel", {
        Size = UDim2.new(1, -50, 1, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = THEME.TEXT,
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, Row)

    local Bg = new("Frame", {
        Size = UDim2.fromOffset(36, 20),
        Position = UDim2.new(1, -36, 0.5, -10),
        BackgroundColor3 = default and THEME.ACCENT or THEME.TRACK,
        BorderSizePixel = 0,
    }, Row)
    corner(Bg, 10)

    local Knob = new("Frame", {
        Size = UDim2.fromOffset(14, 14),
        Position = default and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
    }, Bg)
    corner(Knob, 7)

    local Btn = new("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
    }, Row)

    local state = default
    local function set(v)
        state = v
        TweenService:Create(Bg, TweenInfo.new(0.15), {
            BackgroundColor3 = v and THEME.ACCENT or THEME.TRACK
        }):Play()
        TweenService:Create(Knob, TweenInfo.new(0.15), {
            Position = v and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
        }):Play()
        if callback then callback(v) end
    end

    Btn.MouseButton1Click:Connect(function() set(not state) end)
    place(Row, 26)
    return set
end

local function Slider(text, min, max, default, decimals, callback)
    local Row = new("Frame", { BackgroundTransparency = 1 })

    new("TextLabel", {
        Size = UDim2.new(0.6, 0, 0, 14),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = THEME.TEXT,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, Row)

    local ValueLbl = new("TextLabel", {
        Size = UDim2.new(0.4, 0, 0, 14),
        Position = UDim2.new(0.6, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = tostring(default),
        TextColor3 = THEME.ACCENT,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, Row)

    local Bar = new("Frame", {
        Size = UDim2.new(1, 0, 0, 5),
        Position = UDim2.new(0, 0, 0, 22),
        BackgroundColor3 = THEME.TRACK,
        BorderSizePixel = 0,
    }, Row)
    corner(Bar, 3)

    local Fill = new("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = THEME.ACCENT,
        BorderSizePixel = 0,
    }, Bar)
    corner(Fill, 3)

    local Hit = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 16),
        Position = UDim2.new(0, 0, 0, 17),
        BackgroundTransparency = 1,
        Text = "",
    }, Row)

    local value = default
    local function apply(v, fire)
        value = math.clamp(v, min, max)
        local alpha = (max - min) == 0 and 0 or (value - min) / (max - min)
        Fill.Size = UDim2.new(alpha, 0, 1, 0)
        ValueLbl.Text = string.format("%." .. decimals .. "f", value)
        if fire and callback then callback(value) end
    end

    local dragging = false
    local function fromX(x)
        local rel = (x - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X
        apply(min + rel * (max - min), true)
    end

    Hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            fromX(input.Position.X)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            fromX(input.Position.X)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    apply(default, false)
    place(Row, 34)
    return function(v) apply(v, false) end
end

-- ==================== НАПОЛНЕНИЕ МЕНЮ ====================
Section("Основное")
Toggle("AutoParry", SETTINGS.AutoParry, function(v) SETTINGS.AutoParry = v end)
Toggle("PingBased", SETTINGS.PingBased, function(v) SETTINGS.PingBased = v end)

Section("Предсказание")
Slider("DistanceToParry", 0, 3, SETTINGS.DistanceToParry, 2, function(v) SETTINGS.DistanceToParry = v end)
Slider("PingBasedOffset", 0, 5, SETTINGS.PingBasedOffset, 2, function(v) SETTINGS.PingBasedOffset = v end)
Slider("EmergencyRadius", 0, 30, SETTINGS.EmergencyRadius, 0, function(v) SETTINGS.EmergencyRadius = v end)

Section("Клэш")
Slider("ClashDistance", 0, 50, SETTINGS.ClashDistance, 0, function(v) SETTINGS.ClashDistance = v end)
Slider("ClashSpeed", 0, 0.2, SETTINGS.ClashSpeed, 3, function(v) SETTINGS.ClashSpeed = v end)
Slider("NormalSpeed", 0, 0.3, SETTINGS.NormalSpeed, 3, function(v) SETTINGS.NormalSpeed = v end)

Section("Визуал")
Toggle("Visuals", SETTINGS.Visuals, function(v)
    SETTINGS.Visuals = v
    SyncPart()
end)
Toggle("ShowRadius", SETTINGS.ShowRadius, function(v)
    SETTINGS.ShowRadius = v
    SyncPart()
end)

Section("Защита")
Toggle("AntiCheat (kill BAC)", SETTINGS.AntiCheat, function(v)
    SETTINGS.AntiCheat = v
    if v then print("[Sleepscript] BAC killed:", table.concat(KillBAC(), " | ")) end
end)
Toggle("AntiKick", SETTINGS.AntiKick, function(v) SETTINGS.AntiKick = v end)

local FINAL_H = 50 + CURSOR + 10
Content.Size = UDim2.new(1, 0, 0, CURSOR + 6)
Main.Size = UDim2.fromOffset(310, FINAL_H)
Main.Position = UDim2.new(0.5, -155, 0.5, -math.floor(FINAL_H / 2))

-- ==================== ПЕРЕТАСКИВАНИЕ ОКНА ====================
local dragging, dragStart, startPos

Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Main.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        Main.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- ==================== ХОТКЕИ ====================
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Z then
        Main.Visible = not Main.Visible
    elseif input.KeyCode == Enum.KeyCode.L then
        SETTINGS.AutoParry = not SETTINGS.AutoParry
    end
end)

-- ==================== ЛОГИКА AUTOPARRY ====================
local LastClick = 0
local LastBallHit = nil
local IsParrying = false
local frameCounter = 0

local BallsFolder = workspace:FindFirstChild("Balls") or workspace:WaitForChild("Balls", 5)

local NetworkStats = Stats:FindFirstChild("Network")
    and Stats.Network:FindFirstChild("ServerStatsItem")
    and Stats.Network.ServerStatsItem:FindFirstChild("Data Ping")

local r = Instance.new("Part")
r.Name = "Circle"
r.Anchored = true
r.CanCollide = false
r.CanQuery = false
r.CanTouch = false
r.CastShadow = false
r.Locked = true
r.Massless = true
r.Transparency = 1
r.Material = Enum.Material.Neon
r.Size = Vector3.new(1, 1, 1)
r.Parent = nil

local m = Instance.new("SpecialMesh", r)
m.MeshId = "rbxassetid://3270017"
m.Scale = Vector3.new(1, 1, 0.5)

function SyncPart()
    if SETTINGS.Visuals and SETTINGS.ShowRadius then
        if not r.Parent then r.Parent = workspace.CurrentCamera or workspace end
    else
        r.Parent = nil
    end
end

local function GetBall()
    if not BallsFolder then return nil end
    local children = BallsFolder:GetChildren()
    for i = 1, #children do
        local v = children[i]
        if v:GetAttribute("realBall") == true then return v end
    end
    for i = 1, #children do
        local v = children[i]
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
    if not SETTINGS.AutoParry or IsParrying then return end
    local now = tick()
    local cd = isClashing and SETTINGS.ClashSpeed or SETTINGS.NormalSpeed

    if not isClashing and LastBallHit == ball and (now - LastClick) < 0.5 then return end
    if (now - LastClick) < cd then return end

    IsParrying = true
    LastClick = now
    LastBallHit = ball

    local pos = UserInputService:GetMouseLocation()
    VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
    VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)

    task.delay(cd, function() IsParrying = false end)
end

local function UpdateVisuals(root, distance, state)
    if not r.Parent then return end

    r.CFrame = root.CFrame * CFrame.new(0, -2.6, 0) * CFrame.Angles(math.rad(90), 0, 0)
    local targetSize = math.clamp(distance * 0.8, 5, 65)
    m.Scale = m.Scale:Lerp(Vector3.new(targetSize, targetSize, 0.5), 0.5)

    if state == "clash" then
        r.Color = Color3.fromRGB(255, 0, 0)
        r.Transparency = 0.05
    elseif state == "target" then
        r.Color = Color3.fromRGB(0, 255, 255)
        r.Transparency = 0.1
    else
        r.Color = Color3.fromRGB(150, 240, 255)
        r.Transparency = 0.5
    end
end

SyncPart()

RunService.PostSimulation:Connect(function()
    if not SETTINGS.AutoParry then return end

    local Char = Player.Character
    local Root = Char and Char:FindFirstChild("HumanoidRootPart")
    if not Root then return end

    local Ball = GetBall()
    if not Ball then return end

    local BallPos, PlayerPos = Ball.Position, Root.Position
    local Velocity = Ball.AssemblyLinearVelocity
    local Speed = Velocity.Magnitude
    local Distance = (PlayerPos - BallPos).Magnitude

    local directionToPlayer = (PlayerPos - BallPos).Unit
    local velocityDirection = Velocity.Unit
    local dot = directionToPlayer:Dot(velocityDirection)

    if dot < 0 then LastBallHit = nil end

    local Targeted = IsTargeted()
    local IsClashing = Targeted and Distance <= SETTINGS.ClashDistance

    frameCounter = frameCounter + 1
    if frameCounter % 2 == 0 then
        UpdateVisuals(Root, Distance, IsClashing and "clash" or (Targeted and "target" or "neutral"))
    end

    if IsClashing then
        SendClick(true, Ball)
    elseif Targeted and dot > 0 then
        local Ping = SETTINGS.PingBased and ((NetworkStats and NetworkStats.Value / 1000) or 0.04) or 0
        local TimeToHit = Distance / math.max(Speed, 1)
        local PredictionThreshold = SETTINGS.DistanceToParry + (Ping * SETTINGS.PingBasedOffset)

        if Speed > 150 then
            PredictionThreshold = PredictionThreshold * 1.15
        end

        if TimeToHit <= PredictionThreshold or Distance <= SETTINGS.EmergencyRadius then
            SendClick(false, Ball)
        end
    end
end)

Player.CharacterAdded:Connect(function()
    LastBallHit = nil
    IsParrying = false
end)
