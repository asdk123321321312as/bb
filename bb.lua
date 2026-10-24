--=====================================================================
--   SleepScript  //  BLADE BALL   v7.0
--   Isolation build: 3 режима BAC, чистый режим, автолестница
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
local CoreGui             = game:GetService("CoreGui")
local TextChatService     = game:GetService("TextChatService")

local LocalPlayer = Players.LocalPlayer

------------------------------------------------------------------ executor
local function execFn(n)
    local ok, f = pcall(function() return rawget(getfenv(), n) end)
    if ok and type(f) == "function" then return f end
end
local gethui     = execFn("gethui") or function() return CoreGui end
local setfpscap  = execFn("setfpscap")
local writefile  = execFn("writefile")
local readfile   = execFn("readfile")
local isfile     = execFn("isfile")
local getgc      = execFn("getgc")
local keypress   = execFn("keypress")
local keyrelease = execFn("keyrelease")

------------------------------------------------------------------ config
local Config = {
    AutoParry      = false,
    Accuracy       = 65,
    AccRand        = true,
    AccRandAmt     = 10,

    TriggerbotDelay= 0.03,
    InstantSpeed   = 999,
    PredictionSpam = 999,
    DynThreshold   = false,
    DynHits        = 3,

    ParryRange     = 8,
    PingFactor     = 1.0,
    Cooldown       = 0.5,
    SpamRate       = 0.05,
    MinGap         = 0.15,
    PerpTol        = 6,
    StrictTarget   = true,
    RequireAttr    = true,
    OnlyTarget     = true,
    MinSpeed       = 15,
    Mode           = "Keypress",
    AutoMethod     = true,

    -- ЗАЩИТА
    BacBypassMode  = "full",     -- off | light | full
    WriteAttr      = true,
    Humanize       = true,
    HumanJitter    = 0.07,
    HumanAccSpread = 0.03,
    HumanPausePct  = 18,
    HumanPause     = 0.12,
    MissChance     = 10,
    HoldMin        = 0.03,
    HoldMax        = 0.07,
    MaxParryPerSec = 4,
    MaxParryPerMin = 20,
    Warmup         = 20,
    ParanoidOnKick = true,
    ParanoidTime   = 30,
    ParanoidScale  = 0.25,
    AutoTune       = true,
    Watchdog       = true,
    RejoinAttempts = 5,
    StartupDelay   = 5,
    DtSafety       = true,
    DesyncGuard    = false,
    HoldPress      = true,

    FovEnabled     = false,
    Fov            = 100,
    FpsBoost       = false,
    CutFx          = false,
    UnlockFps      = false,

    Rejoin         = true,
    AntiAfk        = true,

    Korblox        = false,
    Headless       = false,

    Accent         = Color3.fromRGB(0, 170, 255),
}

local CFG_PATH = "SleepScript.json"
local LOG_PATH = "SleepScript_kicks.json"

local function saveConfig()
    if not writefile then return end
    local t = {}
    for k, v in pairs(Config) do
        if typeof(v) == Color3 then t[k] = {r=v.R, g=v.G, b=v.B, __c=true} else t[k] = v end
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

if Config.Cooldown < 0.3 then Config.Cooldown = 0.5 end
if Config.Mode == "Remote" then Config.Mode = "Keypress" end
if Config.BacBypass == false then Config.BacBypassMode = "off" end

local Diag = { parries=0, kicks=0, status="idle", dist=0, hits=0, target=false, real=false,
               window=0, tti=0, aggr=1, rate=0, rateMin=0, latched=false, serverWin=0, perp=0,
               bypass="", att=0, landed=0, attr=false, clean=false }

local UIset = { sliders = {}, toggles = {}, refresh = function() end }

------------------------------------------------------------------ utils
local function gauss()
    local u1 = math.random()
    local u2 = math.random()
    if u1 < 1e-9 then u1 = 1e-9 end
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

local function timeToImpact(p, v, q, radius)
    local d = p - q
    local dist = d.Magnitude
    if dist <= radius then return 0 end
    local a = v:Dot(v)
    if a < 1e-6 then return nil end
    local b = 2 * v:Dot(d)
    local disc = b * b - 4 * a * (dist * dist - radius * radius)
    if disc < 0 then return nil end
    local t = (-b - math.sqrt(disc)) / (2 * a)
    if t < 0 then return nil end
    local g = Vector3.new(0, -Workspace.Gravity, 0)
    for _ = 1, 4 do
        local rel = (p + v * t + g * 0.5 * t * t) - q
        local dd = rel.Magnitude
        if dd < 1e-4 then break end
        local deriv = rel:Dot(v + g * t) / dd
        if math.abs(deriv) < 1e-4 then break end
        t = t - (dd - radius) / deriv
        if t < 0 then t = 0 break end
    end
    return t
end

local function missDistance(p, v, q)
    local rel = q - p
    local vv = v.Magnitude
    if vv < 1e-4 then return rel.Magnitude, 0 end
    local vhat = v / vv
    local along = rel:Dot(vhat)
    return (rel - vhat * along).Magnitude, along
end

local AC = {}

--=====================================================================
--  BAC BYPASS  (3 режима + периодический ре-скан)
--=====================================================================
do
    local killed, seen = {}, {}
    local newCount = 0

    local function kill(inst, tag)
        if not inst then return end
        local key = (tag or "") .. inst.Name
        if seen[key] then return end
        seen[key] = true
        killed[#killed+1] = key
        newCount = newCount + 1
        pcall(function() inst:Destroy() end)
    end

    function AC.bypassBAC(silent)
        newCount = 0
        local mode = Config.BacBypassMode
        if mode == "off" then
            Diag.bypass = "выкл"
            return 0
        end
        local rs = ReplicatedStorage

        if mode == "full" then
            local sec = rs:FindFirstChild("Security")
            if sec then
                for _, d in ipairs(sec:GetDescendants()) do
                    if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
                        kill(d, "Security.")
                    end
                end
                kill(sec, "")
            end
            for _, d in ipairs(rs:GetChildren()) do
                local n = d.Name:lower()
                if d ~= sec and (n:find("anticheat") or n:find("anti_cheat") or n:find("bac")) then
                    kill(d, "rs.")
                end
            end
        end

        local ps = LocalPlayer:FindFirstChild("PlayerScripts")
        if ps then
            for _, d in ipairs(ps:GetDescendants()) do
                local n = d.Name:lower()
                if (n:find("devicecheck") or n:find("anticheat") or n:find("anti_cheat")
                    or n:find("security") or n:find("bac") or n:find("detector"))
                   and (d:IsA("LocalScript") or d:IsA("ModuleScript")) then
                    kill(d, "ps.")
                end
            end
        end

        if mode == "full" and getgc then
            local hits = 0
            pcall(function()
                for _, v in pairs(getgc(true)) do
                    if type(v) == "table" then
                        for _, k in ipairs({"AntiCheat", "AntiCheatEnabled", "BAC", "BACEnabled"}) do
                            if rawget(v, k) == true then rawset(v, k, false) hits = hits + 1 end
                        end
                    end
                end
            end)
            if hits > 0 and not seen["gc"] then seen["gc"] = true killed[#killed+1] = "gc:" .. hits end
        end

        if not silent then
            Diag.bypass = (#killed > 0) and ("[" .. mode .. "] " .. table.concat(killed, ", ")) or ("[" .. mode .. "] не найдено")
        end
        return newCount
    end

    function AC.bypassText()
        return Diag.bypass ~= "" and Diag.bypass or "не запускался"
    end

    local ORDER = {"Keypress", "KeypressAlt", "Mouse", "Exec", "Remote"}
    function AC.nextMethod()
        local i = 1
        for k, v in ipairs(ORDER) do if v == Config.Mode then i = k end end
        Config.Mode = ORDER[(i % #ORDER) + 1]
        Diag.att, Diag.landed = 0, 0
        UIset.refresh()
        AC.logKick("auto-method -> " .. Config.Mode)
        saveConfig()
        return Config.Mode
    end
end

--=====================================================================
--  AUTO PARRY
--=====================================================================
local AutoParry = {}
do
    local bootTime   = os.clock()
    local lastFrame  = os.clock()
    local lastPress  = 0
    local trackedBall, hits, spam = nil, 0, false
    local pending, held, holdDur, parried = false, false, 0.03, false
    local ballJitter, ballFocus, ballSkip = 0, 0, false
    local pings = {}
    local posHist = {}
    local probe, attempts, landed = nil, 0, 0
    local methodTried = false

    local cachedRemote, cachedRelease
    local function getRemote()
        if cachedRemote and cachedRemote.Parent then return cachedRemote, cachedRelease end
        local rem = ReplicatedStorage:FindFirstChild("Remotes")
        if rem then
            for _, d in ipairs(rem:GetDescendants()) do
                if d:IsA("RemoteEvent") then
                    local n = d.Name:lower()
                    if n == "parrybuttonpress" then cachedRemote = d
                    elseif n == "parrybuttonrelease" then cachedRelease = d end
                end
            end
        end
        if not cachedRemote then
            for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
                if d:IsA("RemoteEvent") and d.Name:lower() == "parrybuttonpress" then cachedRemote = d end
            end
        end
        return cachedRemote, cachedRelease
    end

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

    local function ballVel(ball)
        local now = os.clock()
        local av = ball.AssemblyLinearVelocity
        local h = posHist[ball]
        local v = av
        if v.Magnitude < 1 and h then
            local dt = now - h.t
            if dt > 0.001 and dt < 0.2 then
                local d = (ball.Position - h.p) / dt
                if d.Magnitude > 1 then v = d end
            end
        end
        if v.Magnitude < 1 then
            local z = ball:FindFirstChild("zoomies")
            if z and z:IsA("LinearVelocity") then v = z.VectorVelocity end
        end
        posHist[ball] = {p = ball.Position, t = now}
        return v
    end

    local function screenCenter()
        local cam = Workspace.CurrentCamera
        local vs = cam and cam.ViewportSize or Vector2.new(1280, 720)
        return math.floor(vs.X / 2), math.floor(vs.Y / 2)
    end

    local function rawDown()
        local m = Config.Mode
        if m == "Mouse" then
            local x, y = screenCenter()
            pcall(function() VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0) end)
        elseif m == "Exec" and keypress then
            pcall(keypress, Enum.KeyCode.F)
        elseif m == "KeypressAlt" then
            pcall(function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, true, false) end)
        else
            pcall(function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, false) end)
        end
    end
    local function rawUp()
        local m = Config.Mode
        if m == "Mouse" then
            local x, y = screenCenter()
            pcall(function() VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0) end)
        elseif m == "Exec" and keyrelease then
            pcall(keyrelease, Enum.KeyCode.F)
        else
            pcall(function() VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, false) end)
        end
    end

    local function press()
        if Config.Mode == "Remote" then
            local r, rel = getRemote()
            if r then pcall(function() r:FireServer() end) end
            if rel and not Config.HoldPress then
                task.delay(holdDur, function() pcall(function() rel:FireServer() end) end)
            end
            return
        end
        if Config.HoldPress then rawDown() held = true else rawDown() rawUp() end
    end

    function AutoParry.test()
        holdDur = 0.05
        lastPress = os.clock()
        if Config.Mode == "Remote" then press() else rawDown() held = true end
    end

    local function fire(now)
        if parried then return false end
        if now - lastPress < Config.MinGap then return false end
        if not AC.allowRate(now) then return false end
        if not AC.allowMinute(now) then return false end
        lastPress = now
        parried = true
        hits = hits + 1
        Diag.parries = Diag.parries + 1
        Diag.hits = hits
        holdDur = Config.HoldMin + math.random() * (Config.HoldMax - Config.HoldMin)
        press()
        if trackedBall then probe = {b = trackedBall, t = now} end
        attempts = attempts + 1
        Diag.att, Diag.landed = attempts, landed
        return true
    end

    local function getBall(hrp)
        local folder = Workspace:FindFirstChild("Balls")
        if not folder then return nil, nil end
        local best, bestT, fb, fbT = nil, math.huge, nil, math.huge
        for _, b in ipairs(folder:GetChildren()) do
            if b:IsA("BasePart") and b:GetAttribute("realBall") == true then
                local vel = ballVel(b)
                if vel.Magnitude >= Config.MinSpeed then
                    local t = timeToImpact(b.Position, vel, hrp.Position, Config.ParryRange + 3)
                    if t then
                        local perp, along = missDistance(b.Position, vel, hrp.Position)
                        if along > 0 and perp <= Config.PerpTol and t < bestT then
                            bestT, best = t, b
                        end
                        if t < fbT then fbT, fb = t, b end
                    end
                end
            end
        end
        return (best or fb), (best and bestT or nil)
    end

    local function isTargeted(char, ball, ppos, pos, vel)
        local t = ball:GetAttribute("target")
        if t ~= nil then return (t == LocalPlayer.Name or t == LocalPlayer), true end
        local tc = char:GetAttribute("Targeted")
        if tc ~= nil then return tc == true, true end
        if char:FindFirstChild("Highlight") then return true, true end
        local tb = ball:GetAttribute("Targeted")
        if tb ~= nil then return tb == true, true end
        return ((ppos - pos).Unit):Dot(vel.Unit) > 0.3, false
    end

    function AutoParry.reset()
        if held then rawUp(); held = false end
        pending, trackedBall, hits, spam, parried = false, nil, 0, false, false
        Diag.latched = false
    end

    function AutoParry.zeroStats()
        attempts, landed = 0, 0
        Diag.att, Diag.landed = 0, 0
        methodTried = false
    end

    local function step()
        local now = os.clock()
        local dt = now - lastFrame
        lastFrame = now
        AutoParry.lastStep = now

        if held and (now - lastPress) > holdDur then rawUp(); held = false end

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        if probe then
            local pb = probe.b
            if not pb or not pb.Parent or not hrp then
                probe = nil
            else
                local rel = hrp.Position - pb.Position
                local d = rel.Magnitude
                local dir = rel.Unit:Dot(pb.AssemblyLinearVelocity.Unit)
                if d < Config.ParryRange + 20 and dir < -0.2 then
                    landed = landed + 1
                    Diag.landed = landed
                    probe = nil
                elseif now - probe.t > 0.7 then
                    probe = nil
                end
            end
            if Config.AutoMethod and not methodTried and attempts >= 12 and landed == 0 then
                methodTried = true
                AC.nextMethod()
            end
            if attempts > 40 then attempts, landed = attempts - 40, math.max(0, landed - 40) end
        end

        if not Config.AutoParry then Diag.status = "выкл" return end
        if now - bootTime < Config.StartupDelay then Diag.status = "старт" return end
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then Diag.status = "мёртв" return end

        local ball, tti = getBall(hrp)
        if not ball then Diag.status = "нет мяча" Diag.real = false Diag.tti = 0 return end
        Diag.real = true

        local pos, ppos = ball.Position, hrp.Position
        local vel = ballVel(ball)
        local speed = vel.Magnitude
        local dist = (ppos - pos).Magnitude
        Diag.dist, Diag.tti = dist, tti or -1

        if parried and dist > Config.ParryRange + 12 then parried = false end
        Diag.latched = parried

        if Config.DesyncGuard and Config.WriteAttr then
            local last = ball:GetAttribute("__ssLast")
            if last and (pos - last).Magnitude > 150 then
                ball:SetAttribute("__ssLast", pos)
                Diag.status = "десинк" return
            end
            ball:SetAttribute("__ssLast", pos)
        end

        if speed < Config.MinSpeed then Diag.status = "стоит" return end

        if ball ~= trackedBall then
            trackedBall = ball
            hits, spam, pending, parried = 0, false, false, false
            if Config.Humanize then
                ballJitter = gauss() * Config.HumanJitter
                ballFocus  = gauss() * Config.HumanAccSpread
                ballSkip   = math.random() * 100 < Config.MissChance
            else
                ballJitter, ballFocus, ballSkip = 0, 0, false
            end
        end
        Diag.hits = hits

        local targeted, known = isTargeted(char, ball, ppos, pos, vel)
        Diag.target, Diag.attr = targeted, known

        local perp, along = missDistance(pos, vel, ppos)
        Diag.perp = perp

        if Config.RequireAttr and not known then Diag.status = "нет атрибута" return end
        if Config.StrictTarget and known and not targeted then Diag.status = "не мой" return end
        if along <= 0 then Diag.status = "уже прошёл" return end
        if perp > Config.PerpTol then Diag.status = string.format("мимо %.0f", perp) return end

        local aggr = AC.aggression()
        local warm = math.max(0, 1 - (now - bootTime) / math.max(Config.Warmup, 0.1))
        if warm > 0 then aggr = math.min(aggr, 0.5 + 0.5 * (1 - warm)) end
        Diag.aggr = aggr

        if ballSkip and aggr > 0.4 then Diag.status = "пропуск" return end

        local acc = Config.Accuracy
        if Config.AccRand then acc = acc + math.random(-Config.AccRandAmt, Config.AccRandAmt) end
        acc = math.clamp(acc, 1, 100)

        local instant = speed >= Config.InstantSpeed and warm <= 0
        local delay   = (instant and aggr > 0.6) and 0 or Config.TriggerbotDelay
        local up      = (getPing() / 1000) * 0.5 * Config.PingFactor
        local inR     = (Config.ParryRange * 2) / math.max(speed, 1)
        local jit     = (ballJitter + ballFocus) * (2 - aggr)
        if math.random() * 100 < Config.HumanPausePct then
            jit = jit + Config.HumanPause * math.random()
        end

        local early  = up + delay
        local late   = math.max(early - inR * 0.7, 0.004)
        local k      = acc / 100
        local budget = early + (late - early) * k + jit
        budget = math.max(math.min(budget, early), 0.004)
        Diag.window, Diag.serverWin = budget, early

        if tti == nil then
            if dist <= Config.ParryRange and along > 0 then
                if not parried and not pending and (now - lastPress) >= Config.Cooldown then fire(now) end
            end
            Diag.status = "в зоне" return
        end

        if speed >= Config.PredictionSpam then spam = true end
        local spamNow = (spam or (Config.DynThreshold and hits >= Config.DynHits)) and aggr > 0.45

        if spamNow then
            if not parried and tti <= budget and (now - lastPress) >= Config.SpamRate then fire(now) end
            Diag.status = "спам"
            return
        end

        if parried then Diag.status = "уже отбит" return end
        if (now - lastPress) < Config.Cooldown then Diag.status = "кулдаун" return end
        if tti > budget then Diag.status = string.format("лети %0.2f", tti) return end

        if delay == 0 then
            fire(now)
            Diag.status = "ПАРРИ"
        else
            if not pending then
                pending = true
                Diag.status = "триггер"
                task.delay(delay, function()
                    pending = false
                    if Config.AutoParry and not parried then fire(os.clock()) end
                end)
            end
        end
    end

    RunService.RenderStepped:Connect(function()
        local ok, err = pcall(step)
        if not ok then Diag.status = "ошибка" warn("[SleepScript]", err) end
    end)

    UserInputService.InputBegan:Connect(function(i, gp)
        if gp then return end
        if i.KeyCode == Enum.KeyCode.F or i.UserInputType == Enum.UserInputType.MouseButton1 then
            lastPress = os.clock()
        end
    end)

    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.2)
        AutoParry.reset()
        bootTime = os.clock()
    end)
end

--=====================================================================
--  ANTI-DETECTION CORE
--=====================================================================
do
    local rate, minute = {}, {}
    local paranoidUntil = 0
    local busy, attempt = false, 0
    local lastJob = game.JobId
    local kickStamps = {}

    AC.kicks = 0
    AC.paranoid = false
    AC.log = {}
    AC.lastKickAt = 0

    if readfile and isfile then
        pcall(function()
            if isfile(LOG_PATH) then AC.log = HttpService:JSONDecode(readfile(LOG_PATH)) end
        end)
    end

    local function saveLog()
        if writefile then pcall(writefile, LOG_PATH, HttpService:JSONEncode(AC.log)) end
    end

    function AC.aggression()
        if not AC.paranoid then return 1 end
        local left = paranoidUntil - os.clock()
        if left <= 0 then AC.paranoid = false return 1 end
        local s = Config.ParanoidScale
        return s + (1 - s) * (1 - left / math.max(Config.ParanoidTime, 0.1))
    end

    function AC.allowRate(now)
        while rate[1] and now - rate[1] > 1 do table.remove(rate, 1) end
        local cap = math.max(2, math.floor(Config.MaxParryPerSec * (0.4 + 0.6 * AC.aggression())))
        if #rate >= cap then return false end
        rate[#rate+1] = now
        Diag.rate = #rate
        return true
    end

    function AC.allowMinute(now)
        while minute[1] and now - minute[1] > 60 do table.remove(minute, 1) end
        local cap = math.max(10, math.floor(Config.MaxParryPerMin * (0.5 + 0.5 * AC.aggression())))
        if #minute >= cap then return false end
        minute[#minute+1] = now
        Diag.rateMin = #minute
        return true
    end

    function AC.enterParanoid()
        if not Config.ParanoidOnKick then return end
        AC.paranoid = true
        paranoidUntil = os.clock() + Config.ParanoidTime
    end

    function AC.readReason()
        local parts = {}
        for _, root in ipairs({CoreGui, gethui()}) do
            local p = root and root:FindFirstChild("RobloxPromptGui")
            if p then
                for _, d in ipairs(p:GetDescendants()) do
                    if d:IsA("TextLabel") and d.Text ~= "" and #d.Text < 220 then
                        parts[#parts+1] = d.Text
                    end
                end
            end
        end
        local s = table.concat(parts, " | ")
        if s == "" then s = "unknown" end
        return s
    end

    function AC.logKick(reason)
        AC.log[#AC.log+1] = {
            t = os.time(), clock = os.date("%H:%M:%S"), reason = reason,
            uptime = math.floor(os.clock()), mode = Config.Mode,
            bypass = Config.BacBypassMode,
            flags = string.format("pm%d ps%d cd%.2f r%.0f tol%d h%d w%d",
                Config.MaxParryPerMin, Config.MaxParryPerSec, Config.Cooldown,
                Config.ParryRange, Config.PerpTol, Config.HoldPress and 1 or 0, Config.Warmup),
        }
        while #AC.log > 40 do table.remove(AC.log, 1) end
        saveLog()
    end

    function AC.getLogText(n)
        local out = {}
        local from = math.max(1, #AC.log - (n or 8) + 1)
        for i = #AC.log, from, -1 do
            local e = AC.log[i]
            out[#out+1] = string.format("%s %s", e.clock, tostring(e.reason):sub(1, 40))
            if e.flags then out[#out+1] = "   " .. e.flags end
        end
        if #out == 0 then return "пусто" end
        return table.concat(out, "\n")
    end

    local function looksLikeKick(r)
        r = r:lower()
        return r:find("parry") or r:find("spam") or r:find("fast")
            or r:find("auto") or r:find("cheat") or r:find("detect") or r:find("exploit")
    end

    local function tuneDown()
        if not Config.AutoTune then return end
        Config.MaxParryPerMin = math.max(12, math.floor(Config.MaxParryPerMin) - 5)
        Config.MaxParryPerSec = math.max(3, math.floor(Config.MaxParryPerSec) - 1)
        Config.Cooldown       = math.min(0.7, Config.Cooldown + 0.05)
        Config.MissChance     = math.min(25, Config.MissChance + 3)
        Config.PerpTol        = math.max(4, Config.PerpTol - 1)
        Config.Humanize       = true
        local s = UIset.sliders
        if s["Лимит парри/мин"] then s["Лимит парри/мин"](Config.MaxParryPerMin) end
        if s["Лимит парри/сек"] then s["Лимит парри/сек"](Config.MaxParryPerSec) end
        if s["Кулдаун"] then s["Кулдаун"](Config.Cooldown) end
        if s["Промах траектории"] then s["Промах траектории"](Config.PerpTol) end
        if UIset.toggles["Humanizer"] then UIset.toggles["Humanizer"](true) end
        saveConfig()
    end

    function AC.rejoin(reason)
        if busy then return end
        busy = true
        attempt = attempt + 1
        local wait = math.min(2 ^ (attempt - 1), 20)
        task.wait(1 + math.random() * 0.6)
        local ok = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, lastJob, LocalPlayer)
        end)
        if not ok then pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end) end
        task.wait(wait)
        busy = false
        if attempt >= Config.RejoinAttempts then attempt = 0 end
    end

    function AC.onKick(reason)
        AC.kicks = AC.kicks + 1
        AC.lastKickAt = os.clock()
        Diag.kicks = AC.kicks
        AC.logKick(reason)
        AutoParry.reset()
        AC.enterParanoid()
        if looksLikeKick(reason) then tuneDown() end

        kickStamps[#kickStamps+1] = os.clock()
        while kickStamps[1] and os.clock() - kickStamps[1] > 120 do table.remove(kickStamps, 1) end
        if #kickStamps >= 3 and not Diag.clean then
            kickStamps = {}
            AC.cleanMode()
        end

        if Config.Rejoin then AC.rejoin(reason) end
    end

    function AC.antiAfk()
        local cam = Workspace.CurrentCamera
        if not cam then return end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:Button2Down(Vector2.new(0,0), cam.CFrame)
            task.wait(0.35)
            VirtualUser:Button2Up(Vector2.new(0,0), cam.CFrame)
        end)
    end

    pcall(function()
        TextChatService.MessageReceived:Connect(function(msg)
            local txt = tostring(msg.Text or "")
            local l = txt:lower()
            if l:find("anticheat") or l:find("anti-cheat") or l:find("parry")
                or l:find("kicked") or l:find("detect") or l:find("exploit") then
                AC.logKick("chat: " .. txt:sub(1, 72))
            end
        end)
    end)

    LocalPlayer.AncestryChanged:Connect(function(_, parent)
        if parent == nil then AC.onKick(AC.readReason()) end
    end)
    LocalPlayer.Idled:Connect(function()
        if Config.AntiAfk then AC.antiAfk() end
    end)

    -- чистый режим: только парри, всё остальное выключено
    function AC.cleanMode()
        Diag.clean = true
        Config.BacBypassMode = "off"
        Config.FpsBoost = false
        Config.CutFx = false
        Config.UnlockFps = false
        Config.FovEnabled = false
        Config.Korblox = false
        Config.Headless = false
        Config.DesyncGuard = false
        Config.WriteAttr = false
        Config.Humanize = true
        Config.HumanJitter = 0.07
        Config.HumanPausePct = 18
        Config.MissChance = 12
        Config.MaxParryPerMin = 15
        Config.MaxParryPerSec = 3
        Config.Cooldown = 0.55
        Config.MinGap = 0.2
        Config.ParryRange = 7
        Config.PerpTol = 5
        Config.Accuracy = 70
        Config.Warmup = 25
        Config.StartupDelay = 6
        Config.PredictionSpam = 999
        Config.InstantSpeed = 999
        Config.DynThreshold = false
        Config.TriggerbotDelay = 0.04
        Config.ParanoidOnKick = true
        Fps.Set(false)
        Skin.SetKorblox(false)
        Skin.SetHeadless(false)
        UIset.refresh()
        AC.logKick("-> ЧИСТЫЙ РЕЖИМ")
        saveConfig()
    end

    task.spawn(function()
        local tick = 0
        while true do
            task.wait(0.5)
            tick = tick + 1
            if Config.Watchdog then
                local idle = os.clock() - (AutoParry.lastStep or os.clock())
                if Config.AutoParry and idle > 1.2 then
                    AutoParry.reset()
                    Diag.status = "watchdog"
                end
                if game.JobId ~= lastJob then
                    lastJob = game.JobId
                    attempt = 0
                    AutoParry.reset()
                    if Config.BacBypassMode ~= "off" then task.wait(2) AC.bypassBAC() end
                end
            end
            -- периодический ре-скан BAC
            if tick % 10 == 0 and Config.BacBypassMode ~= "off" then
                local n = AC.bypassBAC(true)
                if n and n > 0 then AC.logKick("bac: снесено ещё " .. n) end
            end
            if AC.paranoid and os.clock() > paranoidUntil then AC.paranoid = false end
            Diag.aggr = AC.aggression()
            while minute[1] and os.clock() - minute[1] > 60 do table.remove(minute, 1) end
            Diag.rateMin = #minute
        end
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

local OPEN = UDim2.fromOffset(560, 380)
local main = new("Frame", {Name="Main", Parent=gui, AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new(0.5,0,0.5,0),
    Size=UDim2.fromOffset(560, 40), BackgroundColor3=Color3.fromRGB(15,15,19), BorderSizePixel=0, ClipsDescendants=true})
new("UICorner", {CornerRadius=UDim.new(0,12), Parent=main})
reg(new("UIStroke", {Thickness=1.4, Transparency=0.25, Color=Accent, Parent=main}), "Color")

local header = new("Frame", {Parent=main, Size=UDim2.new(1,0,0,34), BackgroundColor3=Color3.new(1,1,1), BorderSizePixel=0})
regG(new("UIGradient", {Parent=header, Color=ColorSequence.new(Accent, Accent:Lerp(Color3.new(0,0,0),0.45))}))
new("TextLabel", {Parent=header, BackgroundTransparency=1, Position=UDim2.new(0,14,0,0), Size=UDim2.new(1,-240,1,0),
    Font=Enum.Font.GothamBold, Text="SleepScript", TextSize=14, TextColor3=Color3.new(1,1,1),
    TextXAlignment=Enum.TextXAlignment.Left})
local status = new("TextLabel", {Parent=header, BackgroundTransparency=1, AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,-14,0,0),
    Size=UDim2.new(0,220,1,0), Font=Enum.Font.GothamMedium, Text="", TextSize=10.5,
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
        local col = state and Accent or Color3.fromRGB(46,46,56)
        if a then tw(knob, 0.18, {Position=target}) tw(track, 0.18, {BackgroundColor3=col})
        else knob.Position = target track.BackgroundColor3 = col end
    end
    render(false)
    TL[#TL+1] = {track=track, state=function() return state end}
    btn.MouseEnter:Connect(function() tw(btn, 0.15, {BackgroundColor3=Color3.fromRGB(32,32,40)}) end)
    btn.MouseLeave:Connect(function() tw(btn, 0.15, {BackgroundColor3=Color3.fromRGB(24,24,30)}) end)
    btn.MouseButton1Click:Connect(function() state = not state render(true) cb(state) saveConfig() end)
    UIset.toggles[label] = function(v)
        if state ~= v then state = v render(true) cb(v) saveConfig() end
    end
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
    UIset.sliders[label] = function(v) apply(v, true) saveConfig() end
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
local pGuard  = makeTab("ЗАЩИТА", 2)
local pVisual = makeTab("ВИЗУАЛ", 3)
local pSkin   = makeTab("СКИН", 4)
local pMenu   = makeTab("МЕНЮ", 5)

local methGroup, bypGroup = {}, {}
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
    local entry = {mark=mark, value=value, btn=b}
    group[#group+1] = entry
    b.MouseButton1Click:Connect(function()
        for _, t in ipairs(group) do t.mark.Visible = (t.value == value) end
        onPick(value) saveConfig()
    end)
    return entry
end
UIset.refresh = function()
    for _, t in ipairs(methGroup) do
        local on = (t.value == Config.Mode)
        t.mark.Visible = on
        t.btn.TextColor3 = on and Color3.new(1,1,1) or Color3.fromRGB(216,216,226)
    end
    for _, t in ipairs(bypGroup) do
        local on = (t.value == Config.BacBypassMode)
        t.mark.Visible = on
        t.btn.TextColor3 = on and Color3.new(1,1,1) or Color3.fromRGB(216,216,226)
    end
end

-- ПАРРИ
section(pParry, "ОСНОВНОЕ")
toggle(pParry, "Auto Parry", Config.AutoParry, function(v) Config.AutoParry = v end)
slider(pParry, "Accuracy", 1, 100, Config.Accuracy, 1, "", function(v) Config.Accuracy = v end)
toggle(pParry, "Случайный разброс Accuracy", Config.AccRand, function(v) Config.AccRand = v end)
slider(pParry, "Разброс", 0, 30, Config.AccRandAmt, 1, "", function(v) Config.AccRandAmt = v end)
slider(pParry, "Triggerbot delay", 0, 0.2, Config.TriggerbotDelay, 0.005, " с", function(v) Config.TriggerbotDelay = v end)

section(pParry, "МЕТОД НАЖАТИЯ")
toggle(pParry, "Авто-подбор метода", Config.AutoMethod, function(v) Config.AutoMethod = v end)
radio(pParry, methGroup, "Keypress",    "Keypress (VIM)",      function(v) Config.Mode = v end)
radio(pParry, methGroup, "KeypressAlt", "KeypressAlt",         function(v) Config.Mode = v end)
radio(pParry, methGroup, "Mouse",       "Mouse (центр)",       function(v) Config.Mode = v end)
radio(pParry, methGroup, "Exec",        "Exec (keypress())",   function(v) Config.Mode = v end)
radio(pParry, methGroup, "Remote",      "Remote",              function(v) Config.Mode = v end)
button(pParry, "ТЕСТ НАЖАТИЯ", function() AutoParry.test() end)

section(pParry, "ФИЛЬТР ЦЕЛИ")
toggle(pParry, "Строго по атрибуту target", Config.StrictTarget, function(v) Config.StrictTarget = v end)
toggle(pParry, "Только по атрибуту (без геометрии)", Config.RequireAttr, function(v) Config.RequireAttr = v end)
slider(pParry, "Промах траектории", 3, 20, Config.PerpTol, 1, " ст", function(v) Config.PerpTol = v end)

section(pParry, "ТОНКАЯ НАСТРОЙКА")
slider(pParry, "Parry range", 5, 25, Config.ParryRange, 1, " ст", function(v) Config.ParryRange = v end)
slider(pParry, "Ping factor", 0.0, 1.5, Config.PingFactor, 0.05, "", function(v) Config.PingFactor = v end)
slider(pParry, "Кулдаун", 0.04, 0.7, Config.Cooldown, 0.01, " с", function(v) Config.Cooldown = v end)
slider(pParry, "Мин. зазор", 0.02, 0.3, Config.MinGap, 0.01, " с", function(v) Config.MinGap = v end)

section(pParry, "РЕЖИМЫ")
slider(pParry, "Instant speed", 1, 999, Config.InstantSpeed, 1, "", function(v) Config.InstantSpeed = v end)
slider(pParry, "Prediction spam", 1, 999, Config.PredictionSpam, 1, "", function(v) Config.PredictionSpam = v end)
toggle(pParry, "Dynamic threshold", Config.DynThreshold, function(v) Config.DynThreshold = v end)
slider(pParry, "Хитов до спама", 1, 10, Config.DynHits, 1, "", function(v) Config.DynHits = v end)

-- ЗАЩИТА
section(pGuard, "ИЗОЛЯЦИЯ")
button(pGuard, "ЧИСТЫЙ РЕЖИМ (только парри)", function() AC.cleanMode() end)
button(pGuard, "ВЕРНУТЬ ВСЁ", function()
    Diag.clean = false
    Config.BacBypassMode = "full"
    Config.WriteAttr = true
    Config.FpsBoost = false
    Config.FovEnabled = false
    Config.Korblox = false
    Config.Headless = false
    Config.DesyncGuard = true
    Config.MaxParryPerMin = 20
    Config.MaxParryPerSec = 4
    Config.Cooldown = 0.5
    Config.ParryRange = 8
    Config.PerpTol = 6
    Config.Warmup = 20
    Config.StartupDelay = 5
    Config.Humanize = true
    Config.MissChance = 10
    UIset.refresh()
    AC.logKick("-> ВЕРНУЛ ВСЁ")
    saveConfig()
end)

section(pGuard, "BAC BYPASS")
radio(pGuard, bypGroup, "off",   "off — не трогать BAC",     function(v) Config.BacBypassMode = v end)
radio(pGuard, bypGroup, "light", "light — только клиент.скрипты", function(v) Config.BacBypassMode = v end)
radio(pGuard, bypGroup, "full",  "full — Security + скрипты", function(v) Config.BacBypassMode = v end)
button(pGuard, "ЗАПУСТИТЬ БАЙПАС", function() AC.bypassBAC() end)
local bypassLbl = new("TextLabel", {Parent=pGuard, Size=UDim2.new(1,0,0,34), BackgroundTransparency=1,
    Font=Enum.Font.Code, Text="", TextSize=9.5, TextColor3=Color3.fromRGB(150,210,170),
    TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top, TextWrapped=true,
    LayoutOrder=nextOrd()})
UIset.refresh()

section(pGuard, "ДИАГНОСТИКА")
local diagLbl = new("TextLabel", {Parent=pGuard, Size=UDim2.new(1,0,0,150), BackgroundTransparency=1,
    Font=Enum.Font.Code, Text="", TextSize=11, TextColor3=Color3.fromRGB(180,180,195),
    TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top, LayoutOrder=nextOrd()})

section(pGuard, "ЛИМИТЫ")
slider(pGuard, "Лимит парри/мин", 8, 120, Config.MaxParryPerMin, 1, "", function(v) Config.MaxParryPerMin = v end)
slider(pGuard, "Лимит парри/сек", 1, 25, Config.MaxParryPerSec, 1, "", function(v) Config.MaxParryPerSec = v end)

section(pGuard, "HUMANIZER")
toggle(pGuard, "Humanizer", Config.Humanize, function(v) Config.Humanize = v end)
slider(pGuard, "Джиттер реакции", 0, 0.2, Config.HumanJitter, 0.005, " с", function(v) Config.HumanJitter = v end)
slider(pGuard, "Разброс фокуса", 0, 0.1, Config.HumanAccSpread, 0.005, " с", function(v) Config.HumanAccSpread = v end)
slider(pGuard, "Человеч. паузы", 0, 30, Config.HumanPausePct, 1, "%", function(v) Config.HumanPausePct = v end)
slider(pGuard, "Размер паузы", 0.02, 0.3, Config.HumanPause, 0.01, " с", function(v) Config.HumanPause = v end)
slider(pGuard, "Шанс пропуска", 0, 30, Config.MissChance, 1, "%", function(v) Config.MissChance = v end)
slider(pGuard, "Держать клавишу мин", 0.005, 0.2, Config.HoldMin, 0.005, " с", function(v) Config.HoldMin = v end)
slider(pGuard, "Держать клавишу макс", 0.01, 0.3, Config.HoldMax, 0.005, " с", function(v) Config.HoldMax = v end)

section(pGuard, "ПАРАНОЙЯ")
slider(pGuard, "Разогрев после входа", 0, 60, Config.Warmup, 1, " с", function(v) Config.Warmup = v end)
toggle(pGuard, "Паранойя после кика", Config.ParanoidOnKick, function(v) Config.ParanoidOnKick = v end)
toggle(pGuard, "Авто-ослабление (AutoTune)", Config.AutoTune, function(v) Config.AutoTune = v end)
slider(pGuard, "Длительность", 5, 90, Config.ParanoidTime, 1, " с", function(v) Config.ParanoidTime = v end)
slider(pGuard, "Уровень легита", 0, 0.8, Config.ParanoidScale, 0.05, "", function(v) Config.ParanoidScale = v end)

section(pGuard, "СЕССИЯ")
toggle(pGuard, "Watchdog", Config.Watchdog, function(v) Config.Watchdog = v end)
toggle(pGuard, "Писать атрибуты на мяч", Config.WriteAttr, function(v) Config.WriteAttr = v end)
toggle(pGuard, "Удерживать клавишу", Config.HoldPress, function(v) Config.HoldPress = v end)
toggle(pGuard, "Авто-реджойн", Config.Rejoin, function(v) Config.Rejoin = v end)
slider(pGuard, "Попыток реджойна", 1, 10, Config.RejoinAttempts, 1, "", function(v) Config.RejoinAttempts = v end)
toggle(pGuard, "Анти-АФК", Config.AntiAfk, function(v) Config.AntiAfk = v end)
button(pGuard, "РЕ-ДЖОЙН СЕЙЧАС", function() AC.rejoin("manual") end)

section(pGuard, "ЛОГ КИКОВ / ЧАТ")
local logLbl = new("TextLabel", {Parent=pGuard, Size=UDim2.new(1,0,0,130), BackgroundTransparency=1,
    Font=Enum.Font.Code, Text="", TextSize=9.5, TextColor3=Color3.fromRGB(200,170,170),
    TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top, LayoutOrder=nextOrd()})
button(pGuard, "ОЧИСТИТЬ ЛОГ", function() AC.log = {} end)

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
        task.wait(0.25)
        local flag = AC.paranoid and " | ПАРАНОЙЯ" or ""
        local cl = Diag.clean and " | ЧИСТЫЙ" or ""
        status.Text = string.format("%dms | %s | %s | hit %d/%d%s%s",
            math.floor(AutoParry.getPing()), Config.Mode, Diag.status,
            Diag.landed, Diag.att, flag, cl)
        diagLbl.Text = string.format(
            "статус    : %s\nметод     : %s\nпопаданий : %d/%d\ntarget    : %s\nатрибут   : %s\nзащёлка   : %s\nдист      : %.0f ст\nпромах тр.: %.1f ст\nпарри/мин : %d\nвсего     : %d\nкиков     : %d",
            Diag.status, Config.Mode, Diag.landed, Diag.att,
            Diag.attr and (Diag.target and "мой" or "чужой") or "нет данных",
            Diag.attr and "есть" or "НЕТ",
            Diag.latched and "закрыта" or "открыта",
            Diag.dist, Diag.perp, Diag.rateMin, Diag.parries, Diag.kicks)
        logLbl.Text = AC.getLogText(6)
        bypassLbl.Text = AC.bypassText()
    end
end)

task.spawn(function()
    task.wait(2)
    if Config.BacBypassMode ~= "off" then AC.bypassBAC() end
end)

if Config.FpsBoost then Fps.Set(true) end
if Config.Korblox then Skin.SetKorblox(true) end
if Config.Headless then Skin.SetHeadless(true) end

print("[SleepScript] v7.0 загружен. RightShift — меню.")
