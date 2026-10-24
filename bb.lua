--=====================================================================
--   SleepScript  //  BLADE BALL   v5
--   Autoparry: Accuracy / Triggerbot / Instant / PredictionSpam / Dynamic
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
local VirtualUser         = game:GetService("VirtualUser")
local TeleportService     = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer

------------------------------------------------------------------ executor
local function execFn(n)
    local ok, f = pcall(function() return rawget(getfenv(), n) end)
    if ok and type(f) == "function" then return f end
end
local gethui    = execFn("gethui") or function() return game:GetService("CoreGui") end
local setfpscap = execFn("setfpscap")
local writefile = execFn("writefile")
local readfile  = execFn("readfile")
local isfile    = execFn("isfile")

------------------------------------------------------------------ config
local Config = {
    AutoParry      = false,
    Accuracy       = 53,       -- 1-100, выше = позже парри
    AccRand        = true,
    AccRandAmt     = 8,

    TriggerbotDelay= 0.03,     -- 0-1 c
    InstantSpeed   = 200,      -- 1-350, скорость, при которой парри мгновенный
    PredictionSpam = 260,      -- 1-350, скорость, при которой включается спам
    DynThreshold   = true,     -- считать хиты до автоспама
    DynHits        = 3,        -- сколько парри по мячу до спама

    ParryRange     = 12,
    PingFactor     = 0.5,
    Reaction       = 0.04,
    Cooldown       = 0.10,
    SpamRate       = 0.05,
    OnlyTarget     = true,
    MinSpeed       = 15,
    Mode           = "Keypress",

    StartupDelay   = 3,        -- пауза после инжекта
    DtSafety       = true,     -- защита от лаг-спайков
    DesyncGuard    = true,     -- защита от телепорта мяча
    HoldPress      = false,    -- держать клавишу кадр

    FovEnabled     = false,
    Fov            = 100,
    FpsBoost       = false,
    CutFx          = true,
    UnlockFps      = false,

    Rejoin         = true,
    AntiAfk        = false,

    Korblox        = false,
    Headless       = false,

    Accent         = Color3.fromRGB(0, 170, 255),
}

local CFG_PATH = "SleepScript.json"
local function saveConfig()
    if not writefile then return end
    local t = {}
    for k, v in pairs(Config) do
        if typeof(v) == "Color3" then t[k] = {r=v.R, g=v.G, b=v.B, __c=true} else t[k] = v end
    end
    pcall(writefile, CFG_PATH, HttpService:JSONEncode(t))
end
local function loadConfig()
    if not (readfile and isfile) then return end
    pcall(function()
        if not isfile(CFG_PATH) then return end
        for k, v in pairs(HttpService:JSONDecode(readfile(CFG_PATH))) do
            if type(v) == "table" and v.__c then Config[k] = Color3.new(v.r, v.g, v.b)
            elseif Config[k] ~= nil then Config[k] = v end
        end
    end)
end
loadConfig()

local Diag = { parries=0, kicks=0, status="idle", dist=0, hits=0, target=false, real=false, window=0 }

--=====================================================================
--  BALL / TARGET
--=====================================================================
local BallsFolder
local function GetBall()
    if BallsFolder and not BallsFolder.Parent then BallsFolder = nil end
    if not BallsFolder then BallsFolder = Workspace:FindFirstChild("Balls") end
    if BallsFolder then
        for _, v in ipairs(BallsFolder:GetChildren()) do
            if v:IsA("BasePart") and v:GetAttribute("realBall") == true then return v end
        end
        for _, v in ipairs(BallsFolder:GetChildren()) do
            if v:IsA("BasePart") and v.AssemblyLinearVelocity.Magnitude > 15 then return v end
        end
        return nil
    end
    for _, v in ipairs(Workspace:GetChildren()) do
        if v:IsA("BasePart") and v:GetAttribute("realBall") == true then return v end
    end
    return nil
end

local function IsTargeted(char)
    if not char then return false, false end
    local a = char:GetAttribute("Targeted")
    if a ~= nil then return a == true, true end
    if char:FindFirstChild("Highlight") then return true, true end
    return false, false
end

--=====================================================================
--  AUTO PARRY
--=====================================================================
local AutoParry = {}
do
    local bootTime   = os.clock()
    local lastFrame  = os.clock()
    local lastPress  = 0
    local lastBallPos, trackedBall, hits, spam = nil, nil, 0, false
    local pending, held = false, false
    local pings = {}

    local function getPing()
        local ok, v = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
        v = (ok and typeof(v) == "number") and v or 60
        pings[#pings+1] = v
        if #pings > 12 then table.remove(pings, 1) end
        local s = 0
        for _, p in ipairs(pings) do s = s + p end
        return s / #pings
    end
    AutoParry.getPing = getPing

    local function down()
        if Config.Mode == "Mouse" then
            pcall(function() VirtualInputManager:SendMouseButtonEvent(0,0,0,true, game, 0) end)
        else
            pcall(function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, false) end)
        end
    end
    local function up()
        if Config.Mode == "Mouse" then
            pcall(function() VirtualInputManager:SendMouseButtonEvent(0,0,0,false, game, 0) end)
        else
            pcall(function() VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, false) end)
        end
    end

    local function press()
        if Config.Mode == "Remote" then
            local r = ReplicatedStorage:FindFirstChild("Parry", true)
            if r and r:IsA("RemoteEvent") then pcall(function() r:FireServer() end) end
            return
        end
        if Config.HoldPress then
            down() held = true
        else
            down() up()
        end
    end

    local function fire()
        lastPress = os.clock()
        hits = hits + 1
        Diag.parries = Diag.parries + 1
        Diag.hits = hits
        press()
    end

    local function step()
        local now = os.clock()
        local dt = now - lastFrame
        lastFrame = now

        if held and (now - lastPress) > 0.03 then up() held = false end

        if not Config.AutoParry then Diag.status = "выкл" return end
        if now - bootTime < Config.StartupDelay then Diag.status = "старт" return end

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then Diag.status = "мёртв" return end

        local ball = GetBall()
        if not ball then Diag.status = "нет мяча" Diag.real = false return end
        Diag.real = true

        local pos, ppos = ball.Position, hrp.Position
        local vel = ball.AssemblyLinearVelocity
        local speed = vel.Magnitude
        local dist = (ppos - pos).Magnitude
        Diag.dist = dist

        if Config.DesyncGuard and lastBallPos then
            if (pos - lastBallPos).Magnitude > 150 then
                lastBallPos = pos Diag.status = "десинк" return
            end
        end
        lastBallPos = pos

        if speed < Config.MinSpeed then Diag.status = "стоит" return end

        if ball ~= trackedBall then trackedBall = ball hits = 0 spam = false pending = false end
        Diag.hits = hits

        local targeted, known = IsTargeted(char)
        if not known then targeted = ((ppos - pos).Unit):Dot(vel.Unit) > 0.3 end
        Diag.target = targeted
        if Config.OnlyTarget and not targeted then Diag.status = "не мой" return end

        local pingSec = (getPing() / 1000) * Config.PingFactor
        local window = Config.ParryRange + speed * (pingSec + Config.Reaction)
        if Config.DtSafety and dt > 0.04 then window = window + speed * dt end

        local acc = Config.Accuracy
        if Config.AccRand then
            acc = acc + math.random(-Config.AccRandAmt, Config.AccRandAmt)
        end
        acc = math.clamp(acc, 1, 100)
        window = window * (1 - (acc / 100) * 0.55)
        if window < 3 then window = 3 end
        Diag.window = window

        if speed >= Config.PredictionSpam then spam = true end
        local instant = speed >= Config.InstantSpeed
        local dynOn = Config.DynThreshold and hits >= Config.DynHits

        -- СПАМ
        if spam or dynOn then
            if dist <= window and (now - lastPress) >= Config.SpamRate then fire() end
            Diag.status = spam and "спам(скор)" or "спам(дин)"
            return
        end

        if dist > window then Diag.status = "летит" return end
        if ((ppos - pos).Unit):Dot(vel.Unit) <= 0 then Diag.status = "уходит" return end

        -- ИНСТАНТ
        if instant then
            if (now - lastPress) >= Config.Cooldown then fire() end
            Diag.status = "инстант"
            return
        end

        if (now - lastPress) < Config.Cooldown then Diag.status = "кулдаун" return end

        -- ТРИГГЕРБОТ
        if Config.TriggerbotDelay > 0 then
            if not pending then
                pending = true
                Diag.status = "триггер"
                task.delay(Config.TriggerbotDelay, function()
                    pending = false
                    fire()
                end)
            end
        else
            Diag.status = "ПАРРИ"
            fire()
        end
    end

    RunService.RenderStepped:Connect(function()
        local ok, err = pcall(step)
        if not ok then Diag.status = "ошибка" warn("[SleepScript]", err) end
    end)

    -- если юзер сам жмёт F/ЛКМ — не даблкликаем
    UserInputService.InputBegan:Connect(function(i, gp)
        if gp then return end
        if i.KeyCode == Enum.KeyCode.F or i.UserInputType == Enum.UserInputType.MouseButton1 then
            lastPress = os.clock()
        end
    end)

    LocalPlayer.CharacterAdded:Connect(function()
        trackedBall = nil hits = 0 spam = false pending = false
    end)
end

--=====================================================================
--  FOV + FPS
--=====================================================================
RunService.RenderStepped:Connect(function()
    if not Config.FovEnabled then return end
    local cam = Workspace.CurrentCamera
    if cam and cam.FieldOfView ~= Config.Fov then cam.FieldOfView = Config.Fov end
end)

local Fps = {}
do
    local saved, hooked = {}, false
    local function hide(o) if saved[o] == nil then saved[o] = o.Enabled end o.Enabled = false end
    local function fx(o)
        return o:IsA("ParticleEmitter") or o:IsA("Trail") or o:IsA("Beam")
            or o:IsA("Smoke") or o:IsA("Fire") or o:IsA("Sparkles")
    end
    function Fps.Set(on)
        if on then
            pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
            if Config.UnlockFps then pcall(function() setfpscap(240) end) end
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 1e5
            pcall(function() Workspace.Terrain.Decoration = false end)
            if Config.CutFx then
                for _, d in ipairs(Workspace:GetDescendants()) do if fx(d) then hide(d) end end
                if not hooked then
                    hooked = true
                    Workspace.DescendantAdded:Connect(function(d)
                        if Config.FpsBoost and Config.CutFx and fx(d) then hide(d) end
                    end)
                end
            end
        else
            for d, v in pairs(saved) do pcall(function() if d.Parent then d.Enabled = v end end) end
            saved = {}
            pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
            pcall(function() setfpscap(60) end)
            Lighting.GlobalShadows = true
            pcall(function() Workspace.Terrain.Decoration = true end)
        end
    end
end

--=====================================================================
--  SESSION
--=====================================================================
local Session = {}
do
    local busy = false
    function Session.rejoin()
        if busy then return end
        busy = true
        task.wait(1.5)
        local ok = pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
        if not ok then pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end) end
        busy = false
    end
    LocalPlayer.AncestryChanged:Connect(function(_, parent)
        if parent == nil then
            Diag.kicks = Diag.kicks + 1
            warn("[SleepScript] кик. Всего: " .. Diag.kicks)
            if Config.Rejoin then Session.rejoin() end
        end
    end)
    LocalPlayer.Idled:Connect(function()
        if not Config.AntiAfk then return end
        pcall(function()
            VirtualUser:Button2Down(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
            task.wait(1)
            VirtualUser:Button2Up(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
        end)
    end)
end

--=====================================================================
--  SKIN
--=====================================================================
local Skin = {}
do
    local KORBLOX_MESH = "rbxassetid://139607718"
    local origHead, origAcc, origColor = {}, {}, {}
    local function headAcc(a, head)
        local h = a:FindFirstChild("Handle")
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
                    origHead[d] = origHead[d] or d.Transparency d.Transparency = 1
                end
            end
            for _, a in ipairs(char:GetChildren()) do
                if a:IsA("Accessory") and headAcc(a, head) then
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
    local function legs(char)
        local t = {}
        for _, n in ipairs({"Right Leg","RightLeg","RightUpperLeg","RightLowerLeg"}) do
            local p = char:FindFirstChild(n)
            if p then t[#t+1] = p end
        end
        return t
    end
    function Skin.SetKorblox(on)
        local char = LocalPlayer.Character
        if not char then return end
        for _, leg in ipairs(legs(char)) do
            if on then
                local mesh = leg:FindFirstChild("SleepKorblox")
                if not mesh then
                    mesh = Instance.new("SpecialMesh") mesh.Name = "SleepKorblox" mesh.Parent = leg
                end
                mesh.MeshId, mesh.TextureId, mesh.Scale = KORBLOX_MESH, "", Vector3.new(1,1,1)
                origColor[leg] = origColor[leg] or leg.Color
                leg.Color = Color3.fromRGB(27,27,30)
            else
                local mesh = leg:FindFirstChild("SleepKorblox")
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
local AP, AT, AG, TL = {}, {}, {}, {}

local function new(class, props)
    local i = Instance.new(class)
    if props then
        for k, v in pairs(props) do if k ~= "Parent" then i[k] = v end end
        if props.Parent then i.Parent = props.Parent end
    end
    return i
end
local function tw(o, t, p)
    local a = TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), p)
    a:Play() return a
end
local function reg(o, p) AP[#AP+1] = {o=o, p=p or "BackgroundColor3"} end
local function regT(o) AT[#AT+1] = o end
local function regG(g) AG[#AG+1] = g end

local function setAccent(col)
    Accent, Config.Accent = col, col
    local info = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    for _, e in ipairs(AP) do if e.o and e.o.Parent then TweenService:Create(e.o, info, {[e.p]=col}):Play() end end
    for _, o in ipairs(AT) do if o and o.Parent then TweenService:Create(o, info, {TextColor3=col}):Play() end end
    for _, g in ipairs(AG) do if g and g.Parent then g.Color = ColorSequence.new(col, col:Lerp(Color3.new(0,0,0),0.45)) end end
    for _, t in ipairs(TL) do if t.state() then t.track.BackgroundColor3 = col end end
    saveConfig()
end

local gui = new("ScreenGui", {Name="SleepScript", ResetOnSpawn=false, IgnoreGuiInset=true,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling, DisplayOrder=999, Parent=gethui()})

local OPEN = UDim2.fromOffset(560, 350)
local main = new("Frame", {Name="Main", Parent=gui, AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new(0.5,0,0.5,0),
    Size=UDim2.fromOffset(560, 40), BackgroundColor3=Color3.fromRGB(15,15,19), BorderSizePixel=0, ClipsDescendants=true})
new("UICorner", {CornerRadius=UDim.new(0,12), Parent=main})
reg(new("UIStroke", {Thickness=1.4, Transparency=0.25, Color=Accent, Parent=main}), "Color")

local header = new("Frame", {Parent=main, Size=UDim2.new(1,0,0,34), BackgroundColor3=Color3.new(1,1,1), BorderSizePixel=0})
regG(new("UIGradient", {Parent=header, Color=ColorSequence.new(Accent, Accent:Lerp(Color3.new(0,0,0),0.45))}))
new("TextLabel", {Parent=header, BackgroundTransparency=1, Position=UDim2.new(0,14,0,0), Size=UDim2.new(1,-200,1,0),
    Font=Enum.Font.GothamBold, Text="SleepScript", TextSize=14, TextColor3=Color3.new(1,1,1),
    TextXAlignment=Enum.TextXAlignment.Left})
local status = new("TextLabel", {Parent=header, BackgroundTransparency=1, AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,-14,0,0),
    Size=UDim2.new(0,180,1,0), Font=Enum.Font.GothamMedium, Text="", TextSize=10.5,
    TextColor3=Color3.fromRGB(235,235,245), TextXAlignment=Enum.TextXAlignment.Right})

local body = new("Frame", {Parent=main, Position=UDim2.new(0,0,0,34), Size=UDim2.new(1,0,1,-34), BackgroundTransparency=1})
local sidebar = new("Frame", {Parent=body, Size=UDim2.new(0,130,1,0), BackgroundColor3=Color3.fromRGB(18,18,23), BorderSizePixel=0})
local pages = new("Frame", {Parent=body, Position=UDim2.new(0,130,0,0), Size=UDim2.new(1,-130,1,0),
    BackgroundTransparency=1, ClipsDescendants=true})
local indicator = new("Frame", {Parent=sidebar, Size=UDim2.new(0,3,0,20), BackgroundColor3=Accent, BorderSizePixel=0, ZIndex=3})
reg(indicator)

local ord, tabs = 0, {}
local function nextOrd() ord = ord + 1 return ord end
local function makePage()
    local p = new("ScrollingFrame", {Parent=pages, Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
        BorderSizePixel=0, ScrollBarThickness=3, CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y, Visible=false})
    reg(p, "ScrollBarImageColor3")
    new("UIListLayout", {Parent=p, Padding=UDim.new(0,5), SortOrder=Enum.SortOrder.LayoutOrder})
    new("UIPadding", {Parent=p, PaddingLeft=UDim.new(0,12), PaddingRight=UDim.new(0,12),
        PaddingTop=UDim.new(0,10), PaddingBottom=UDim.new(0,12)})
    return p
end
local function makeTab(name, i)
    local y = (i-1) * 32 + 12
    local btn = new("TextButton", {Parent=sidebar, Position=UDim2.new(0,0,0,y), Size=UDim2.new(1,0,0,28),
        BackgroundColor3=Color3.fromRGB(24,24,30), BorderSizePixel=0, Text="   "..name,
        Font=Enum.Font.GothamMedium, TextSize=12, TextColor3=Color3.fromRGB(120,120,135),
        TextXAlignment=Enum.TextXAlignment.Left, AutoButtonColor=false})
    new("UICorner", {CornerRadius=UDim.new(0,7), Parent=btn})
    local page = makePage()
    tabs[name] = {btn=btn, page=page}
    btn.MouseEnter:Connect(function() if not btn:GetAttribute("active") then tw(btn, 0.15, {BackgroundColor3=Color3.fromRGB(30,30,38)}) end end)
    btn.MouseLeave:Connect(function() if not btn:GetAttribute("active") then tw(btn, 0.15, {BackgroundColor3=Color3.fromRGB(24,24,30)}) end end)
    btn.MouseButton1Click:Connect(function()
        for k, t in pairs(tabs) do
            local on = (k == name)
            t.btn:SetAttribute("active", on)
            t.btn.TextColor3 = on and Color3.new(1,1,1) or Color3.fromRGB(120,120,135)
            t.btn.BackgroundColor3 = on and Color3.fromRGB(30,30,38) or Color3.fromRGB(24,24,30)
            t.page.Visible = on
            if on then t.page.Position = UDim2.new(0,10,0,0) tw(t.page, 0.18, {Position=UDim2.new(0,0,0,0)}) end
        end
        tw(indicator, 0.2, {Position=UDim2.new(0,0,0, y + 4)})
    end)
    return page
end

local function section(parent, text)
    new("TextLabel", {Parent=parent, Size=UDim2.new(1,0,0,18), BackgroundTransparency=1, Font=Enum.Font.GothamBold,
        Text=text, TextSize=10.5, LayoutOrder=nextOrd(), TextColor3=Color3.fromRGB(125,125,142),
        TextXAlignment=Enum.TextXAlignment.Left})
end
local function note(parent, text, h)
    new("TextLabel", {Parent=parent, Size=UDim2.new(1,0,0,h or 15), BackgroundTransparency=1, Font=Enum.Font.GothamMedium,
        Text=text, TextSize=9.5, LayoutOrder=nextOrd(), TextColor3=Color3.fromRGB(138,138,152),
        TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=true})
end
local function toggle(parent, label, default, cb)
    local btn = new("TextButton", {Parent=parent, Size=UDim2.new(1,0,0,30), BackgroundColor3=Color3.fromRGB(24,24,30),
        BorderSizePixel=0, Text="", AutoButtonColor=false, LayoutOrder=nextOrd()})
    new("UICorner", {CornerRadius=UDim.new(0,8), Parent=btn})
    new("UIStroke", {Thickness=1, Color=Color3.fromRGB(46,46,56), Transparency=0.35, Parent=btn})
    new("TextLabel", {Parent=btn, BackgroundTransparency=1, Position=UDim2.new(0,12,0,0), Size=UDim2.new(0.7,0,1,0),
        Font=Enum.Font.GothamMedium, Text=label, TextSize=12, TextColor3=Color3.fromRGB(216,216,226),
        TextXAlignment=Enum.TextXAlignment.Left})
    local track = new("Frame", {Parent=btn, AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,-12,0.5,0),
        Size=UDim2.fromOffset(36,18), BackgroundColor3=Color3.fromRGB(46,46,56), BorderSizePixel=0})
    new("UICorner", {CornerRadius=UDim.new(1,0), Parent=track})
    local knob = new("Frame", {Parent=track, AnchorPoint=Vector2.new(0,0.5), Position=UDim2.new(0,2,0.5,0),
        Size=UDim2.fromOffset(14,14), BackgroundColor3=Color3.new(1,1,1), BorderSizePixel=0})
    new("UICorner", {CornerRadius=UDim.new(1,0), Parent=knob})
    local state = default
    local function render(a)
        local target = state and UDim2.new(0,20,0.5,0) or UDim2.new(0,2,0.5,0)
        if a then tw(knob, 0.18, {Position=target}) tw(track, 0.18, {BackgroundColor3 = state and Accent or Color3.fromRGB(46,46,56)})
        else knob.Position = target track.BackgroundColor3 = state and Accent or Color3.fromRGB(46,46,56) end
    end
    render(false)
    TL[#TL+1] = {track=track, state=function() return state end}
    btn.MouseEnter:Connect(function() tw(btn, 0.15, {BackgroundColor3=Color3.fromRGB(32,32,40)}) end)
    btn.MouseLeave:Connect(function() tw(btn, 0.15, {BackgroundColor3=Color3.fromRGB(24,24,30)}) end)
    btn.MouseButton1Click:Connect(function() state = not state render(true) cb(state) saveConfig() end)
end
local function slider(parent, label, min, max, default, step, suffix, cb)
    local holder = new("Frame", {Parent=parent, Size=UDim2.new(1,0,0,34), BackgroundTransparency=1, LayoutOrder=nextOrd()})
    new("TextLabel", {Parent=holder, BackgroundTransparency=1, Size=UDim2.new(0.72,0,0,15), Font=Enum.Font.GothamMedium,
        Text=label, TextSize=12, TextColor3=Color3.fromRGB(216,216,226), TextXAlignment=Enum.TextXAlignment.Left})
    local val = new("TextLabel", {Parent=holder, BackgroundTransparency=1, Position=UDim2.new(0.72,0,0,0), Size=UDim2.new(0.28,0,0,15),
        Font=Enum.Font.GothamBold, Text=tostring(default)..(suffix or ""), TextSize=12, TextColor3=Accent,
        TextXAlignment=Enum.TextXAlignment.Right})
    regT(val)
    local track = new("Frame", {Parent=holder, Position=UDim2.new(0,0,0,21), Size=UDim2.new(1,0,0,5),
        BackgroundColor3=Color3.fromRGB(40,40,48), BorderSizePixel=0})
    new("UICorner", {CornerRadius=UDim.new(1,0), Parent=track})
    local fill = new("Frame", {Parent=track, Size=UDim2.new(0,0,1,0), BackgroundColor3=Accent, BorderSizePixel=0})
    reg(fill)
    new("UICorner", {CornerRadius=UDim.new(1,0), Parent=fill})
    local knob = new("Frame", {Parent=track, AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new(0,0,0.5,0),
        Size=UDim2.fromOffset(11,11), BackgroundColor3=Color3.new(1,1,1), BorderSizePixel=0, ZIndex=3})
    new("UICorner", {CornerRadius=UDim.new(1,0), Parent=knob})
    local hit = new("TextButton", {Parent=holder, Position=UDim2.new(0,0,0,13), Size=UDim2.new(1,0,0,20),
        BackgroundTransparency=1, Text=""})
    local value = default
    local function apply(v, f)
        value = math.clamp(v, min, max)
        if step then value = math.floor(value/step + 0.5)*step end
        local rel = (value-min)/(max-min)
        fill.Size = UDim2.new(rel,0,1,0)
        knob.Position = UDim2.new(rel,0,0.5,0)
        local shown = (step and step >= 1) and math.floor(value) or string.format("%.3g", value)
        val.Text = shown..(suffix or "")
        if f then cb(value) end
    end
    apply(default, false)
    local dragging = false
    local function fromX(x)
        local rel = math.clamp((x - track.AbsolutePosition.X)/math.max(track.AbsoluteSize.X,1), 0, 1)
        apply(min + (max-min)*rel, true)
    end
    hit.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true fromX(i.Position.X) end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then fromX(i.Position.X) end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false saveConfig() end
    end)
end
local function button(parent, text, cb)
    local b = new("TextButton", {Parent=parent, Size=UDim2.new(1,0,0,28), BackgroundColor3=Accent,
        BorderSizePixel=0, Text=text, Font=Enum.Font.GothamMedium, TextSize=12, TextColor3=Color3.new(1,1,1),
        AutoButtonColor=false, LayoutOrder=nextOrd()})
    new("UICorner", {CornerRadius=UDim.new(0,7), Parent=b})
    reg(b)
    b.MouseEnter:Connect(function() tw(b, 0.15, {BackgroundColor3 = Accent:Lerp(Color3.new(0,0,0),0.25)}) end)
    b.MouseLeave:Connect(function() tw(b, 0.15, {BackgroundColor3 = Accent}) end)
    b.MouseButton1Click:Connect(cb)
end
local function colorPicker(parent)
    local holder = new("Frame", {Parent=parent, Size=UDim2.new(1,0,0,52), BackgroundTransparency=1, LayoutOrder=nextOrd()})
    local sw = new("Frame", {Parent=holder, Position=UDim2.new(0,0,0,16), Size=UDim2.new(1,0,0,16), BackgroundTransparency=1})
    new("UIListLayout", {Parent=sw, FillDirection=Enum.FillDirection.Horizontal, Padding=UDim.new(0,6)})
    for _, c in ipairs({Color3.fromRGB(0,170,255), Color3.fromRGB(140,80,255), Color3.fromRGB(255,70,120),
        Color3.fromRGB(0,220,150), Color3.fromRGB(255,180,40), Color3.fromRGB(255,90,60),
        Color3.fromRGB(240,240,245), Color3.fromRGB(120,120,135)}) do
        local s = new("TextButton", {Parent=sw, Size=UDim2.fromOffset(16,16), BackgroundColor3=c, BorderSizePixel=0, Text="", AutoButtonColor=false})
        new("UICorner", {CornerRadius=UDim.new(1,0), Parent=s})
        s.MouseButton1Click:Connect(function() setAccent(c) end)
    end
    local hue = new("TextButton", {Parent=holder, Position=UDim2.new(0,0,0,38), Size=UDim2.new(1,0,0,9),
        BackgroundColor3=Color3.new(1,1,1), BorderSizePixel=0, Text=""})
    new("UICorner", {CornerRadius=UDim.new(1,0), Parent=hue})
    new("UIGradient", {Parent=hue, Color=ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255,0,0)), ColorSequenceKeypoint.new(1/6, Color3.fromRGB(255,255,0)),
        ColorSequenceKeypoint.new(2/6, Color3.fromRGB(0,255,0)), ColorSequenceKeypoint.new(3/6, Color3.fromRGB(0,255,255)),
        ColorSequenceKeypoint.new(4/6, Color3.fromRGB(0,0,255)), ColorSequenceKeypoint.new(5/6, Color3.fromRGB(255,0,255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255,0,0))}})
    local dragging = false
    local function fromX(x)
        local rel = math.clamp((x - hue.AbsolutePosition.X)/math.max(hue.AbsoluteSize.X,1), 0, 1)
        setAccent(Color3.fromHSV(rel, 1, 1))
    end
    hue.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true fromX(i.Position.X) end end)
    UserInputService.InputChanged:Connect(function(i) if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then fromX(i.Position.X) end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
end

local pParry  = makeTab("ПАРРИ", 1)
local pAnti   = makeTab("АНТИЧИТ", 2)
local pVisual = makeTab("ВИЗУАЛ", 3)
local pSkin   = makeTab("СКИН", 4)
local pMenu   = makeTab("МЕНЮ", 5)

local function radio(parent, group, value, label, onPick)
    local b = new("TextButton", {Parent=parent, Size=UDim2.new(1,0,0,26), BackgroundColor3=Color3.fromRGB(24,24,30),
        BorderSizePixel=0, Text="  "..label, Font=Enum.Font.GothamMedium, TextSize=11,
        TextColor3=Color3.fromRGB(216,216,226), TextXAlignment=Enum.TextXAlignment.Left,
        AutoButtonColor=false, LayoutOrder=nextOrd()})
    new("UICorner", {CornerRadius=UDim.new(0,6), Parent=b})
    local mark = new("Frame", {Parent=b, AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,-10,0.5,0),
        Size=UDim2.fromOffset(8,8), BackgroundColor3=Accent, BorderSizePixel=0, Visible=false})
    new("UICorner", {CornerRadius=UDim.new(1,0), Parent=mark})
    reg(mark)
    local entry = {mark=mark, value=value}
    group[#group+1] = entry
    b.MouseButton1Click:Connect(function()
        for _, t in ipairs(group) do t.mark.Visible = (t.value == value) end
        onPick(value) saveConfig()
    end)
    return entry
end

-- ПАРРИ
section(pParry, "ОСНОВНОЕ")
toggle(pParry, "Auto Parry", Config.AutoParry, function(v) Config.AutoParry = v end)
slider(pParry, "Accuracy", 1, 100, Config.Accuracy, 1, "", function(v) Config.Accuracy = v end)
note(pParry, "Выше = позже парри (ближе к мячу). 50-60 — оптимально.")
toggle(pParry, "Случайный разброс Accuracy", Config.AccRand, function(v) Config.AccRand = v end)
slider(pParry, "Разброс", 0, 30, Config.AccRandAmt, 1, "", function(v) Config.AccRandAmt = v end)
slider(pParry, "Triggerbot delay", 0, 1, Config.TriggerbotDelay, 0.01, " с", function(v) Config.TriggerbotDelay = v end)
note(pParry, "Задержка перед нажатием — имитация человеческой реакции.")

section(pParry, "СКОРОСТНЫЕ РЕЖИМЫ")
slider(pParry, "Instant speed", 1, 350, Config.InstantSpeed, 1, "", function(v) Config.InstantSpeed = v end)
note(pParry, "При скорости мяча выше — парри мгновенно, без задержки и предсказания.")
slider(pParry, "Prediction spam", 1, 350, Config.PredictionSpam, 1, "", function(v) Config.PredictionSpam = v end)
note(pParry, "При скорости выше — спам предсказаний (серия нажатий по мячу).")

section(pParry, "DYNAMIC THRESHOLD")
toggle(pParry, "Включить", Config.DynThreshold, function(v) Config.DynThreshold = v end)
slider(pParry, "Хитов до спама", 1, 10, Config.DynHits, 1, "", function(v) Config.DynHits = v end)
note(pParry, "Считает парри по одному мячу; после N попаданий включает автоспам.")

section(pParry, "ТОНКАЯ НАСТРОЙКА")
slider(pParry, "Parry range", 5, 40, Config.ParryRange, 1, " ст", function(v) Config.ParryRange = v end)
slider(pParry, "Ping factor", 0.0, 0.8, Config.PingFactor, 0.05, "", function(v) Config.PingFactor = v end)
slider(pParry, "Реакция", 0.0, 0.2, Config.Reaction, 0.005, " с", function(v) Config.Reaction = v end)
slider(pParry, "Кулдаун", 0.04, 0.3, Config.Cooldown, 0.01, " с", function(v) Config.Cooldown = v end)
slider(pParry, "Частота спама", 0.02, 0.2, Config.SpamRate, 0.01, " с", function(v) Config.SpamRate = v end)
toggle(pParry, "Только когда целятся в меня", Config.OnlyTarget, function(v) Config.OnlyTarget = v end)

section(pParry, "МЕТОД")
local methGroup = {}
radio(pParry, methGroup, "Keypress", "Keypress — F (безопасно)", function(v) Config.Mode = v end)
radio(pParry, methGroup, "Mouse",    "Mouse — ЛКМ",              function(v) Config.Mode = v end)
radio(pParry, methGroup, "Remote",   "Remote — прямой",          function(v) Config.Mode = v end)
for _, t in ipairs(methGroup) do t.mark.Visible = (t.value == Config.Mode) end

-- АНТИЧИТ
section(pAnti, "ДИАГНОСТИКА")
local diagLbl = new("TextLabel", {Parent=pAnti, Size=UDim2.new(1,0,0,100), BackgroundTransparency=1,
    Font=Enum.Font.Code, Text="", TextSize=11, TextColor3=Color3.fromRGB(180,180,195),
    TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top, LayoutOrder=nextOrd()})
section(pAnti, "ОБХОД BAC")
toggle(pAnti, "Задержка после инжекта", true, function(v) Config.StartupDelay = v and 3 or 0 end)
toggle(pAnti, "Защита от лаг-спайков", Config.DtSafety, function(v) Config.DtSafety = v end)
toggle(pAnti, "Защита от десинка мяча", Config.DesyncGuard, function(v) Config.DesyncGuard = v end)
toggle(pAnti, "Удерживать клавишу", Config.HoldPress, function(v) Config.HoldPress = v end)
note(pAnti, "Никаких хуков, ремоут не трогаем, один парри на мяч, ручной F не даблкликается.", 26)
button(pAnti, "СТЕЛС-РЕЖИМ", function()
    Config.Mode = "Keypress" Config.OnlyTarget = true Config.DynThreshold = false
    Config.InstantSpeed = 350 Config.PredictionSpam = 350
    Config.ParryRange = 12 Config.Accuracy = 50 Config.AccRand = true
    Config.TriggerbotDelay = 0.03 Config.FpsBoost = false Config.UnlockFps = false
    Fps.Set(false) saveConfig()
end)
section(pAnti, "СЕССИЯ")
toggle(pAnti, "Авто-реджойн", Config.Rejoin, function(v) Config.Rejoin = v end)
toggle(pAnti, "Анти-АФК", Config.AntiAfk, function(v) Config.AntiAfk = v end)
button(pAnti, "РЕ-ДЖОЙН СЕЙЧАС", function() Session.rejoin() end)

-- ВИЗУАЛ
section(pVisual, "КАМЕРА")
toggle(pVisual, "FOV", Config.FovEnabled, function(v) Config.FovEnabled = v end)
slider(pVisual, "Значение FOV", 70, 120, Config.Fov, 1, "", function(v) Config.Fov = v end)
section(pVisual, "ПРОИЗВОДИТЕЛЬНОСТЬ")
toggle(pVisual, "FPS Boost", Config.FpsBoost, function(v) Config.FpsBoost = v Fps.Set(v) end)
toggle(pVisual, "Убирать эффекты", Config.CutFx, function(v) Config.CutFx = v if Config.FpsBoost then Fps.Set(true) end end)
toggle(pVisual, "Разблокировать FPS", Config.UnlockFps, function(v) Config.UnlockFps = v if Config.FpsBoost then Fps.Set(true) end end)

-- СКИН
section(pSkin, "АВАТАР")
toggle(pSkin, "Korblox (нога)", Config.Korblox, function(v) Config.Korblox = v Skin.SetKorblox(v) end)
toggle(pSkin, "Headless (без головы)", Config.Headless, function(v) Config.Headless = v Skin.SetHeadless(v) end)

-- МЕНЮ
section(pMenu, "ЦВЕТ")
colorPicker(pMenu)
section(pMenu, "ИНФО")
note(pMenu, "RightShift — скрыть/показать меню.")
note(pMenu, "Тестируй в обычном матче, не в Training Mode.")

--=====================================================================
--  WINDOW
--=====================================================================
local visible = true
local bubble = new("TextButton", {Parent=gui, AnchorPoint=Vector2.new(0,0.5), Position=UDim2.new(0,16,0.5,0),
    Size=UDim2.fromOffset(34,34), BackgroundColor3=Accent, Text="S", Font=Enum.Font.GothamBold,
    TextSize=15, TextColor3=Color3.new(1,1,1), BorderSizePixel=0, AutoButtonColor=false, Visible=false})
new("UICorner", {CornerRadius=UDim.new(1,0), Parent=bubble})
reg(bubble)

local function openMenu()
    visible = true bubble.Visible = false main.Visible = true
    main.Size = UDim2.fromOffset(560,40) tw(main, 0.35, {Size=OPEN})
end
local function closeMenu()
    visible = false
    tw(main, 0.25, {Size=UDim2.fromOffset(560,40)})
    task.delay(0.26, function() if not visible then main.Visible = false bubble.Visible = true end end)
end
bubble.MouseButton1Click:Connect(openMenu)

local dragging, dragStart, startPos
header.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging, dragStart, startPos = true, i.Position, main.Position end
end)
UserInputService.InputChanged:Connect(function(i)
    if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
        local d = i.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y)
    end
end)
UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
UserInputService.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.RightShift then if visible then closeMenu() else openMenu() end end
end)

task.defer(function()
    tw(main, 0.4, {Size=OPEN})
    task.wait(0.05)
    local t = tabs["ПАРРИ"]
    t.btn:SetAttribute("active", true)
    t.btn.TextColor3 = Color3.new(1,1,1)
    t.btn.BackgroundColor3 = Color3.fromRGB(30,30,38)
    t.page.Visible = true
    indicator.Position = UDim2.new(0,0,0,16)
end)

task.spawn(function()
    while true do
        task.wait(0.3)
        status.Text = string.format("%dms | %s | кик %d", math.floor(AutoParry.getPing()), Diag.status, Diag.kicks)
        diagLbl.Text = string.format(
            "статус : %s\nмяч    : %s\nнаведён: %s\nдист   : %.0f ст\nокно   : %.0f ст\nхиты   : %d\nпарри  : %d\nкиков  : %d",
            Diag.status, Diag.real and "да" or "нет", Diag.target and "да" or "нет",
            Diag.dist, Diag.window, Diag.hits, Diag.parries, Diag.kicks)
    end
end)

if Config.FpsBoost then Fps.Set(true) end
if Config.Korblox then Skin.SetKorblox(true) end
if Config.Headless then Skin.SetHeadless(true) end

print("[SleepScript] v5 загружен. RightShift — меню.")
