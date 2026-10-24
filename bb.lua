--=====================================================================
--   VENICE // BLADE BALL          Injector: Real
--   Модули: AutoParry | FOV+FPS | Bypass | Skin | UI
--   Хоткей меню: RightShift
--=====================================================================

local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local UserInputService    = game:GetService("UserInputService")
local TweenService        = game:GetService("TweenService")
local Lighting            = game:GetService("Lighting")
local Workspace           = game:GetService("Workspace")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local Stats               = game:GetService("Stats")
local HttpService         = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer

------------------------------------------------------------------ executor
local function execFn(name)
    local ok, f = pcall(function() return rawget(getfenv(), name) end)
    if ok and type(f) == "function" then return f end
    return nil
end

local gethui    = execFn("gethui") or function() return game:GetService("CoreGui") end
local setfpscap = execFn("setfpscap") or function() end
local sethidden = execFn("sethiddenproperty") or function() end
local writefile = execFn("writefile")
local readfile  = execFn("readfile")
local isfile    = execFn("isfile")

------------------------------------------------------------------ config
local Config = {
    AutoParry  = false,
    Radius     = 18,
    Reaction   = 0.045,
    Cooldown   = 0.10,
    PingComp   = true,
    Humanize   = true,
    Method     = "Auto",     -- Auto | Remote | Key
    MinSpeed   = 25,

    FovEnabled = false,
    Fov        = 100,
    FpsBoost   = false,

    Bypass     = false,

    Korblox    = false,
    Headless   = false,

    Accent     = Color3.fromRGB(0, 170, 255),
}

local CFG_PATH = "VeniceBladeBall.json"
local function saveConfig()
    if not writefile then return end
    local t = {}
    for k, v in pairs(Config) do
        if typeof(v) == "Color3" then
            t[k] = {r = v.R, g = v.G, b = v.B, __c = true}
        else
            t[k] = v
        end
    end
    pcall(writefile, CFG_PATH, HttpService:JSONEncode(t))
end
local function loadConfig()
    if not (readfile and isfile) then return end
    pcall(function()
        if not isfile(CFG_PATH) then return end
        for k, v in pairs(HttpService:JSONDecode(readfile(CFG_PATH))) do
            if type(v) == "table" and v.__c then
                Config[k] = Color3.new(v.r, v.g, v.b)
            elseif Config[k] ~= nil then
                Config[k] = v
            end
        end
    end)
end
loadConfig()

--=====================================================================
--  МОДУЛЬ 1: AUTO PARRY
--=====================================================================
local AutoParry = {}
do
    local ball, lastPos, lastClock
    local parried, lastFire = false, 0

    local function refresh()
        local c = Workspace:FindFirstChild("Ball")
        if c and c:IsA("BasePart") then ball = c return end
        ball = nil
        for _, d in ipairs(Workspace:GetChildren()) do
            if d:IsA("BasePart") and d.Name:lower():find("ball") then ball = d return end
        end
    end
    refresh()

    Workspace.DescendantAdded:Connect(function(d)
        if d:IsA("BasePart") and d.Name:lower():find("ball") then ball = d end
    end)
    Workspace.DescendantRemoving:Connect(function(d)
        if d == ball then ball = nil end
    end)

    local remotes = {}
    local function scanRemotes()
        remotes = {}
        for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
            if d:IsA("RemoteEvent") then
                local n = d.Name:lower()
                if n:find("parry") or n:find("deflect") or n:find("block") then
                    remotes[#remotes+1] = d
                end
            end
        end
    end
    scanRemotes()
    ReplicatedStorage.DescendantAdded:Connect(function(d)
        if d:IsA("RemoteEvent") then scanRemotes() end
    end)

    local function getPing()
        local ok, v = pcall(function()
            return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        if ok and typeof(v) == "number" then return v end
        return 60
    end

    local function fire()
        local used = false
        if Config.Method == "Auto" or Config.Method == "Remote" then
            if remotes[1] then
                pcall(function() remotes[1]:FireServer() end)
                used = true
            end
        end
        if Config.Method == "Key" or (Config.Method == "Auto" and not used) then
            pcall(function()
                VirtualInputManager:SendKeyEvent(true,  Enum.KeyCode.F, false, false)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, false)
            end)
        end
    end

    local function step()
        if not Config.AutoParry then return end
        local char = LocalPlayer.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if not ball or not ball.Parent then refresh() end
        if not ball then return end

        local now = os.clock()
        local pos = ball.Position

        -- скорость: берём из физики, если мяч двигают через CFrame — считаем дельту
        local vel = ball.AssemblyLinearVelocity
        if vel.Magnitude < 2 and lastPos and lastClock and now > lastClock then
            vel = (pos - lastPos) / (now - lastClock)
        end
        lastPos, lastClock = pos, now

        local speed = vel.Magnitude
        if speed < Config.MinSpeed then parried = false return end
        if now - lastFire < Config.Cooldown then return end

        -- компенсация пинга (односторонняя задержка) + человеческая реакция
        local pingSec = Config.PingComp and (getPing() / 1000) * 0.5 or 0
        local press = Config.Radius + speed * (pingSec + Config.Reaction)
        if Config.Humanize then press = press + math.random(-2, 2) end
        if press > 140 then press = 140 end

        -- предсказание точки максимального сближения (ловит мяч, летящий в бок/назад)
        local r  = pos - hrp.Position
        local vv = vel:Dot(vel)
        if vv < 1 then return end

        local tClose = -(r:Dot(vel)) / vv
        if tClose <= 0 then parried = false return end          -- мяч уходит
        if parried and (now - lastFire) > 0.3 then parried = false end

        local closest = (r + vel * tClose).Magnitude
        if closest > press then return end                       -- пройдёт мимо

        -- момент, когда мяч войдёт в радиус срабатывания
        local dtPress = math.sqrt(math.max(press * press - closest * closest, 0)) / math.sqrt(vv)
        local tPress  = tClose - dtPress

        if tPress <= 0 and not parried then
            parried   = true
            lastFire  = now
            fire()
        end
    end

    RunService.RenderStepped:Connect(step)
end

--=====================================================================
--  МОДУЛЬ 2: FOV + FPS BOOST
--=====================================================================
RunService.RenderStepped:Connect(function()
    if not Config.FovEnabled then return end
    local cam = Workspace.CurrentCamera
    if cam and cam.FieldOfView ~= Config.Fov then
        cam.FieldOfView = Config.Fov
    end
end)

local Fps = {}
do
    local saved = {}
    local hooked = false

    local function hide(o)
        if saved[o] == nil then saved[o] = o.Enabled end
        o.Enabled = false
    end
    local function isEffect(o)
        return o:IsA("ParticleEmitter") or o:IsA("Trail") or o:IsA("Beam")
            or o:IsA("Smoke") or o:IsA("Fire") or o:IsA("Sparkles")
    end

    function Fps.Set(on)
        if on then
            pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
            pcall(function() setfpscap(240) end)
            Lighting.GlobalShadows = false
            Lighting.FogEnd        = 1e5
            Lighting.Brightness    = 1
            pcall(function() Workspace.Terrain.Decoration = false end)

            for _, d in ipairs(Workspace:GetDescendants()) do
                if isEffect(d) then hide(d) end
            end
            if not hooked then
                hooked = true
                Workspace.DescendantAdded:Connect(function(d)
                    if Config.FpsBoost and isEffect(d) then hide(d) end
                end)
            end
        else
            for d, v in pairs(saved) do
                pcall(function() if d.Parent then d.Enabled = v end end)
            end
            saved = {}
            pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
            pcall(function() setfpscap(60) end)
            Lighting.GlobalShadows = true
            pcall(function() Workspace.Terrain.Decoration = true end)
        end
    end
end

--=====================================================================
--  МОДУЛЬ 3: ОБХОД АНТИЧИТА
--=====================================================================
local Bypass = {}
do
    local running = false

    local function apply()
        pcall(function() sethidden(LocalPlayer, "MaxSimulationRadius", 1000) end)
        pcall(function() sethidden(LocalPlayer, "SimulationRadius", 1000) end)
        pcall(function() sethidden(Workspace, "FallenPartsDestroyHeight", -1000) end)
    end

    function Bypass.Set(on)
        if on then
            apply()
            if not running then
                running = true
                task.spawn(function()
                    while true do
                        task.wait(2)
                        if Config.Bypass then apply() end
                    end
                end)
            end
        end
    end
end

--=====================================================================
--  МОДУЛЬ 4: СКИНЫ (KORBLOX / HEADLESS)
--=====================================================================
local Skin = {}
do
    local KORBLOX_MESH = "rbxassetid://139607718"
    local origHead, origAcc, origColor = {}, {}, {}

    local function isHeadAccessory(acc, head)
        local h = acc:FindFirstChild("Handle")
        local w = h and h:FindFirstChildOfClass("Weld")
        return w and w.Part1 == head
    end

    function Skin.SetHeadless(on)
        local char = LocalPlayer.Character
        local head = char and char:FindFirstChild("Head")
        if not head then return end
        if on then
            origHead[head] = origHead[head] or head.Transparency
            head.Transparency = 1
            for _, d in ipairs(head:GetChildren()) do
                if d:IsA("BasePart") or d:IsA("Decal") or d:IsA("SpecialMesh") then
                    origHead[d] = origHead[d] or d.Transparency
                    d.Transparency = 1
                end
            end
            for _, a in ipairs(char:GetChildren()) do
                if a:IsA("Accessory") and isHeadAccessory(a, head) then
                    local h = a:FindFirstChild("Handle")
                    if h then origAcc[h] = origAcc[h] or h.Transparency h.Transparency = 1 end
                end
            end
        else
            for o, v in pairs(origHead) do pcall(function() o.Transparency = v end) end
            for o, v in pairs(origAcc)  do pcall(function() o.Transparency = v end) end
            origHead, origAcc = {}, {}
        end
    end

    local function legParts(char)
        local out = {}
        for _, n in ipairs({"Right Leg", "RightLeg", "RightUpperLeg", "RightLowerLeg"}) do
            local p = char:FindFirstChild(n)
            if p then out[#out+1] = p end
        end
        return out
    end

    function Skin.SetKorblox(on)
        local char = LocalPlayer.Character
        if not char then return end
        for _, leg in ipairs(legParts(char)) do
            if on then
                local mesh = leg:FindFirstChild("VeniceKorblox")
                if not mesh then
                    mesh = Instance.new("SpecialMesh")
                    mesh.Name = "VeniceKorblox"
                    mesh.Parent = leg
                end
                mesh.MeshId    = KORBLOX_MESH
                mesh.TextureId = ""
                mesh.Scale     = Vector3.new(1, 1, 1)
                origColor[leg] = origColor[leg] or leg.Color
                leg.Color = Color3.fromRGB(27, 27, 30)
            else
                local mesh = leg:FindFirstChild("VeniceKorblox")
                if mesh then mesh:Destroy() end
                if origColor[leg] then leg.Color = origColor[leg] end
            end
        end
    end

    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.6)
        if Config.Korblox  then Skin.SetKorblox(true)  end
        if Config.Headless then Skin.SetHeadless(true) end
    end)
end

--=====================================================================
--  UI
--=====================================================================
local Accent = Config.Accent
local AccentParts, AccentTexts, AccentGrads, ToggleList = {}, {}, {}, {}

local function new(class, props)
    local i = Instance.new(class)
    if props then
        for k, v in pairs(props) do
            if k ~= "Parent" then i[k] = v end
        end
        if props.Parent then i.Parent = props.Parent end
    end
    return i
end
local function tw(obj, t, props)
    local a = TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
    a:Play() return a
end
local function reg(o, p) AccentParts[#AccentParts+1] = {o = o, p = p or "BackgroundColor3"} end
local function regText(o) AccentTexts[#AccentTexts+1] = o end
local function regGrad(g) AccentGrads[#AccentGrads+1] = g end

local function setAccent(col)
    Accent = col
    Config.Accent = col
    local info = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    for _, e in ipairs(AccentParts) do
        if e.o and e.o.Parent then TweenService:Create(e.o, info, {[e.p] = col}):Play() end
    end
    for _, o in ipairs(AccentTexts) do
        if o and o.Parent then TweenService:Create(o, info, {TextColor3 = col}):Play() end
    end
    for _, g in ipairs(AccentGrads) do
        if g and g.Parent then g.Color = ColorSequence.new(col, col:Lerp(Color3.new(0,0,0), 0.45)) end
    end
    for _, t in ipairs(ToggleList) do
        if t.state() then t.track.BackgroundColor3 = col end
    end
    saveConfig()
end

local gui = new("ScreenGui", {
    Name = "VeniceBB", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999,
    Parent = gethui(),
})

local OPEN = UDim2.fromOffset(252, 404)
local main = new("Frame", {
    Name = "Main", Parent = gui,
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.fromOffset(252, 40),
    BackgroundColor3 = Color3.fromRGB(15, 15, 19),
    BorderSizePixel = 0, ClipsDescendants = true,
})
new("UICorner", {CornerRadius = UDim.new(0, 12), Parent = main})
reg(new("UIStroke", {Thickness = 1.4, Transparency = 0.25, Color = Accent, Parent = main}), "Color")

local header = new("Frame", {Parent = main, Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0})
regGrad(new("UIGradient", {Parent = header, Color = ColorSequence.new(Accent, Accent:Lerp(Color3.new(0,0,0), 0.45))}))
new("TextLabel", {Parent = header, BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 0),
    Size = UDim2.new(1, -84, 1, 0), Font = Enum.Font.GothamBold, Text = "VENICE  •  BLADE BALL",
    TextSize = 13, TextColor3 = Color3.new(1,1,1), TextXAlignment = Enum.TextXAlignment.Left})

local content = new("ScrollingFrame", {
    Parent = main, Position = UDim2.new(0, 0, 0, 42), Size = UDim2.new(1, 0, 1, -46),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
})
reg(content, "ScrollBarImageColor3")
new("UIListLayout", {Parent = content, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})
new("UIPadding", {Parent = content, PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
    PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 10)})

local ord = 0
local function nextOrd() ord = ord + 1 return ord end

local function section(text)
    new("TextLabel", {Parent = content, Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold, Text = text, TextSize = 11, LayoutOrder = nextOrd(),
        TextColor3 = Color3.fromRGB(125, 125, 142), TextXAlignment = Enum.TextXAlignment.Left})
end

local function toggle(label, default, cb)
    local btn = new("TextButton", {Parent = content, Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Color3.fromRGB(24, 24, 30), BorderSizePixel = 0,
        Text = "", AutoButtonColor = false, LayoutOrder = nextOrd()})
    new("UICorner", {CornerRadius = UDim.new(0, 8), Parent = btn})
    new("UIStroke", {Thickness = 1, Color = Color3.fromRGB(46, 46, 56), Transparency = 0.35, Parent = btn})
    new("TextLabel", {Parent = btn, BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(0.65, 0, 1, 0), Font = Enum.Font.GothamMedium, Text = label, TextSize = 12,
        TextColor3 = Color3.fromRGB(216, 216, 226), TextXAlignment = Enum.TextXAlignment.Left})
    local track = new("Frame", {Parent = btn, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(36, 18), BackgroundColor3 = Color3.fromRGB(46, 46, 56), BorderSizePixel = 0})
    new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = track})
    local knob = new("Frame", {Parent = track, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0),
        Size = UDim2.fromOffset(14, 14), BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0})
    new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = knob})

    local state = default
    local function render(anim)
        local target = state and UDim2.new(0, 20, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
        if anim then
            tw(knob, 0.18, {Position = target})
            tw(track, 0.18, {BackgroundColor3 = state and Accent or Color3.fromRGB(46, 46, 56)})
        else
            knob.Position = target
            track.BackgroundColor3 = state and Accent or Color3.fromRGB(46, 46, 56)
        end
    end
    render(false)
    ToggleList[#ToggleList+1] = {track = track, state = function() return state end}

    btn.MouseEnter:Connect(function() tw(btn, 0.15, {BackgroundColor3 = Color3.fromRGB(32, 32, 40)}) end)
    btn.MouseLeave:Connect(function() tw(btn, 0.15, {BackgroundColor3 = Color3.fromRGB(24, 24, 30)}) end)
    btn.MouseButton1Click:Connect(function()
        state = not state
        render(true)
        cb(state)
        saveConfig()
    end)
end

local function slider(label, min, max, default, step, suffix, cb)
    local holder = new("Frame", {Parent = content, Size = UDim2.new(1, 0, 0, 38),
        BackgroundTransparency = 1, LayoutOrder = nextOrd()})
    new("TextLabel", {Parent = holder, BackgroundTransparency = 1, Size = UDim2.new(0.7, 0, 0, 16),
        Font = Enum.Font.GothamMedium, Text = label, TextSize = 12,
        TextColor3 = Color3.fromRGB(216, 216, 226), TextXAlignment = Enum.TextXAlignment.Left})
    local val = new("TextLabel", {Parent = holder, BackgroundTransparency = 1, Position = UDim2.new(0.7, 0, 0, 0),
        Size = UDim2.new(0.3, 0, 0, 16), Font = Enum.Font.GothamBold, Text = tostring(default)..(suffix or ""),
        TextSize = 12, TextColor3 = Accent, TextXAlignment = Enum.TextXAlignment.Right})
    regText(val)
    local track = new("Frame", {Parent = holder, Position = UDim2.new(0, 0, 0, 24), Size = UDim2.new(1, 0, 0, 5),
        BackgroundColor3 = Color3.fromRGB(40, 40, 48), BorderSizePixel = 0})
    new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = track})
    local fill = new("Frame", {Parent = track, Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Accent, BorderSizePixel = 0})
    reg(fill)
    new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = fill})
    local knob = new("Frame", {Parent = track, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(11, 11), BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, ZIndex = 3})
    new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = knob})
    local hit = new("TextButton", {Parent = holder, Position = UDim2.new(0, 0, 0, 16), Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1, Text = ""})

    local value = default
    local function apply(v, fire)
        value = math.clamp(v, min, max)
        if step then value = math.floor(value / step + 0.5) * step end
        local rel = (value - min) / (max - min)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, 0, 0.5, 0)
        local shown = (step and step >= 1) and math.floor(value) or value
        val.Text = tostring(shown) .. (suffix or "")
        if fire then cb(value) end
    end
    apply(default, false)

    local dragging = false
    local function fromX(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        apply(min + (max - min) * rel, true)
    end
    hit.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true fromX(i.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            fromX(i.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false saveConfig()
        end
    end)
end

local function colorPicker()
    local holder = new("Frame", {Parent = content, Size = UDim2.new(1, 0, 0, 54),
        BackgroundTransparency = 1, LayoutOrder = nextOrd()})
    new("TextLabel", {Parent = holder, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16),
        Font = Enum.Font.GothamMedium, Text = "Цвет интерфейса", TextSize = 12,
        TextColor3 = Color3.fromRGB(216, 216, 226), TextXAlignment = Enum.TextXAlignment.Left})

    local swatches = new("Frame", {Parent = holder, Position = UDim2.new(0, 0, 0, 18),
        Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1})
    new("UIListLayout", {Parent = swatches, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6)})
    for _, c in ipairs({
        Color3.fromRGB(0,170,255), Color3.fromRGB(140,80,255), Color3.fromRGB(255,70,120),
        Color3.fromRGB(0,220,150), Color3.fromRGB(255,180,40), Color3.fromRGB(255,90,60),
        Color3.fromRGB(240,240,245), Color3.fromRGB(120,120,135)}) do
        local s = new("TextButton", {Parent = swatches, Size = UDim2.fromOffset(16, 16),
            BackgroundColor3 = c, BorderSizePixel = 0, Text = "", AutoButtonColor = false})
        new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = s})
        s.MouseButton1Click:Connect(function() setAccent(c) end)
        s.MouseEnter:Connect(function() tw(s, 0.12, {Size = UDim2.fromOffset(18, 18)}) end)
        s.MouseLeave:Connect(function() tw(s, 0.12, {Size = UDim2.fromOffset(16, 16)}) end)
    end

    local hue = new("TextButton", {Parent = holder, Position = UDim2.new(0, 0, 0, 40),
        Size = UDim2.new(1, 0, 0, 9), BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, Text = ""})
    new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = hue})
    new("UIGradient", {Parent = hue, Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255,0,0)),
        ColorSequenceKeypoint.new(1/6, Color3.fromRGB(255,255,0)),
        ColorSequenceKeypoint.new(2/6, Color3.fromRGB(0,255,0)),
        ColorSequenceKeypoint.new(3/6, Color3.fromRGB(0,255,255)),
        ColorSequenceKeypoint.new(4/6, Color3.fromRGB(0,0,255)),
        ColorSequenceKeypoint.new(5/6, Color3.fromRGB(255,0,255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255,0,0))}})

    local dragging = false
    local function fromX(x)
        local rel = math.clamp((x - hue.AbsolutePosition.X) / math.max(hue.AbsoluteSize.X, 1), 0, 1)
        setAccent(Color3.fromHSV(rel, 1, 1))
    end
    hue.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true fromX(i.Position.X) end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then fromX(i.Position.X) end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
end

section("AUTO PARRY")
toggle("Auto Parry", Config.AutoParry, function(v) Config.AutoParry = v end)
slider("Радиус срабатывания", 6, 60, Config.Radius, 1, " ст", function(v) Config.Radius = v end)
slider("Реакция", 0.0, 0.2, Config.Reaction, 0.005, " с", function(v) Config.Reaction = v end)
slider("Кулдаун парри", 0.05, 0.4, Config.Cooldown, 0.01, " с", function(v) Config.Cooldown = v end)
toggle("Компенсация пинга", Config.PingComp, function(v) Config.PingComp = v end)
toggle("Хуманизация (джиттер)", Config.Humanize, function(v) Config.Humanize = v end)

section("ВИЗУАЛ")
toggle("FOV", Config.FovEnabled, function(v) Config.FovEnabled = v end)
slider("Значение FOV", 70, 120, Config.Fov, 1, "", function(v) Config.Fov = v end)
toggle("FPS Boost", Config.FpsBoost, function(v) Config.FpsBoost = v Fps.Set(v) end)

section("АНТИЧИТ")
toggle("Обход античита", Config.Bypass, function(v) Config.Bypass = v Bypass.Set(v) end)

section("СКИН")
toggle("Korblox (нога)", Config.Korblox, function(v) Config.Korblox = v Skin.SetKorblox(v) end)
toggle("Headless (без головы)", Config.Headless, function(v) Config.Headless = v Skin.SetHeadless(v) end)

section("ИНТЕРФЕЙС")
colorPicker()

------------------------------------------------------------------ window logic
local visible = true
local bubble = new("TextButton", {Parent = gui, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.5, 0),
    Size = UDim2.fromOffset(34, 34), BackgroundColor3 = Accent, Text = "V", Font = Enum.Font.GothamBold,
    TextSize = 15, TextColor3 = Color3.new(1,1,1), BorderSizePixel = 0, AutoButtonColor = false, Visible = false})
new("UICorner", {CornerRadius = UDim.new(1, 0), Parent = bubble})
reg(bubble)
bubble.MouseButton1Click:Connect(function()
    visible = true
    bubble.Visible = false
    main.Visible = true
    main.Size = UDim2.fromOffset(252, 40)
    tw(main, 0.35, {Size = OPEN})
end)

-- drag
local dragging, dragStart, startPos
header.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging, dragStart, startPos = true, i.Position, main.Position
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
        local d = i.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

-- open animation
main.Visible = true
task.defer(function() tw(main, 0.4, {Size = OPEN}) end)

-- hotkey
UserInputService.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.RightShift then
        if visible then
            visible = false
            tw(main, 0.25, {Size = UDim2.fromOffset(252, 40)})
            task.delay(0.26, function()
                if not visible then
                    main.Visible = false
                    bubble.Visible = true
                end
            end)
        else
            visible = true
            bubble.Visible = false
            main.Visible = true
            main.Size = UDim2.fromOffset(252, 40)
            tw(main, 0.35, {Size = OPEN})
        end
    end
end)

-- применить сохранённые настройки
if Config.FpsBoost then Fps.Set(true) end
if Config.Bypass   then Bypass.Set(true) end
if Config.Korblox  then Skin.SetKorblox(true) end
if Config.Headless then Skin.SetHeadless(true) end

print("[VENICE] Blade Ball загружен. RightShift — меню.")
