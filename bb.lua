--==================================================================
--  BLOX STRIKE — ENEMY WH v11
--  Без оверрайдов внешности (Korblox/скины не ломаются)
--  + поиск способностей + авто-отбив мяча
--  E — WH | F — инфа | :Diag() | :Abilities() | :Watch() | :BallDebug()
--==================================================================

if _G.BloxStrikeESP then pcall(function() _G.BloxStrikeESP:Destroy() end) end

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")
local VIM              = game:GetService("VirtualInputManager")
local RS               = game:GetService("ReplicatedStorage")
local LP               = Players.LocalPlayer
local Camera           = workspace.CurrentCamera

local CFG = {
    Enabled            = true,
    ShowAllies         = false,
    OnlyAlive          = true,
    MaxDistance        = 0,
    ThroughWalls       = true,
    Pulse              = true,
    PulseSpeed         = 4,
    PulseMin           = 0.28,
    PulseMax           = 0.58,
    OutlineTransparency= 0,
    EnemyFill          = Color3.fromRGB(255, 45, 45),
    EnemyOutline       = Color3.fromRGB(255, 255, 255),
    AllyFill           = Color3.fromRGB(60, 220, 120),
    AllyOutline        = Color3.fromRGB(255, 255, 255),

    Box                = true,
    TryReparentRig     = true,
    PoseOverride       = true,
    ForceLoadRigs      = true,
    KillGameHighlight  = true,
    RestoreOnUnload    = true,

    ShowInfo           = true,
    InfoMaxDistance    = 100000,
    InfoOffset         = 3.4,
    ShowHealthArmor    = true,
    ShowWeapon         = true,
    ShowKit            = true,

    -- мяч / способности
    Ball               = true,
    BallRange          = 26,      -- с какой дистанции бить
    BallCooldown       = 0.12,
    BallApproachOnly   = true,    -- только если мяч летит на нас
    BallAim            = false,   -- доворачивать прицел на мяч
    BallAimGain        = 0.6,
    BallAimDeadzone    = 3,
    BallKey            = nil,     -- например Enum.KeyCode.F, иначе мышь
    BallWords          = {"ball","orb","sphere","projectile","disc","puck","core","energy","blast"},

    ToggleKey          = Enum.KeyCode.E,
    InfoKey            = Enum.KeyCode.F,
    UpdateRate         = 0.1,
    TeamRefresh        = 2,
    ForceSource        = nil,
}

local TEAM_ATTR  = "Team"
local OWNER_ATTR = "PresentationOwnerUserId"
local VIS_ATTR   = "ClientCharacterPresentationVisible"
local POSE_ATTR  = "PresentationSpawnPosition"
local YAW_ATTR   = "PresentationSpawnYaw"

local boxes, billboards, rigHL, fallbackRigs, tracked, poseState = {}, {}, {}, {}, {}, {}
local balls, ballWatch = {}, {}
local origParent, conns = {}, {}
local running = true
local resolver, resolverName = nil, "none"

local rootFolder = workspace:FindFirstChild("VeniceESP")
if not rootFolder then
    rootFolder = Instance.new("Folder")
    rootFolder.Name = "VeniceESP"
    rootFolder.Parent = workspace
end

local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function jdecode(s)
    if typeof(s) ~= "string" or s == "" then return nil end
    local ok, t = pcall(HttpService.JSONDecode, HttpService, s)
    if ok and typeof(t) == "table" then return t end
    return nil
end

local function charFolder() return workspace:FindFirstChild("Characters") or workspace end
local function culledFolder() return RS:FindFirstChild("_PVS_CulledCharacters") end

--=========================== КОМАНДА ==============================
local function getTeam(p)
    local v = p:GetAttribute(TEAM_ATTR)
    if typeof(v) == "string" and v ~= "" then return v end
    return nil
end

local function isEnemy(plr)
    if not resolver then return true end
    local a, b = resolver(plr), resolver(LP)
    if a == nil or b == nil then return true end
    return a ~= b
end

local function validate(fn)
    if fn(LP) == nil then return false end
    local seen, n = {}, 0
    for _, p in ipairs(Players:GetPlayers()) do
        local v = fn(p)
        if v ~= nil and not seen[v] then seen[v] = true; n += 1 end
    end
    return n >= 2
end

local function refreshResolver()
    local fn = getTeam
    if validate(fn) then resolver, resolverName = fn, "playerAttr:Team" return end
    fn = function(p)
        local c = p.Character
        return (c and c:GetAttribute("CharacterName")) or p:GetAttribute("PresentationCharacterName")
    end
    if validate(fn) then resolver, resolverName = fn, "CharacterName" else
        resolver, resolverName = nil, "none"
    end
end

--=========================== РИГ ==================================
local function findGameRig(plr)
    local c = plr.Character
    if c and c:IsA("Model") and c:FindFirstChild("HumanoidRootPart") then return c end
    local cf = culledFolder()
    if cf then
        local m = cf:FindFirstChild(plr.Name)
        if m and m:IsA("Model") then return m end
        for _, ch in ipairs(cf:GetChildren()) do
            if ch:IsA("Model") and ch:GetAttribute(OWNER_ATTR) == plr.UserId then return ch end
        end
    end
    local wc = workspace:FindFirstChild("Characters")
    if wc then
        for _, ch in ipairs(wc:GetChildren()) do
            if ch:IsA("Model") and ch:GetAttribute(OWNER_ATTR) == plr.UserId then return ch end
        end
    end
    return nil
end

local function buildFallbackRig(plr)
    if not CFG.ForceLoadRigs then return nil end
    local assets = RS:FindFirstChild("Assets")
    local templates = assets and assets:FindFirstChild("Characters")
    if not templates then return nil end
    local name = plr:GetAttribute("PresentationCharacterName")
    if typeof(name) ~= "string" then return nil end
    local tmpl = templates:FindFirstChild(name)
    if not tmpl or not tmpl:IsA("Model") then return nil end
    local rig = tmpl:Clone()
    rig.Name = "F_"..plr.Name
    for _, d in ipairs(rig:GetDescendants()) do
        if d:IsA("Humanoid") then d:Destroy()
        elseif d:IsA("BasePart") then
            d.CanCollide = false
            d.CanQuery = false
            d.CanTouch = false
        elseif d:IsA("Highlight") or d:IsA("BillboardGui") then d:Destroy() end
    end
    local root = rig:FindFirstChild("HumanoidRootPart") or rig.PrimaryPart
    if root then rig.PrimaryPart = root root.Anchored = true end
    rig:SetAttribute(OWNER_ATTR, plr.UserId)
    rig.Parent = rootFolder
    return rig
end

local function getRoot(rig)
    return rig and (rig:FindFirstChild("HumanoidRootPart") or rig.PrimaryPart)
end
local function getOrigin()
    local root = getRoot(LP.Character)
    return root and root.Position or Camera.CFrame.Position
end
local function isAlive(rig, plr)
    if plr and plr:GetAttribute("Dead") == true then return false end
    if rig and rig:GetAttribute("Dead") == true then return false end
    local h = (rig and rig:GetAttribute("Health")) or (plr and plr:GetAttribute("Health"))
    if typeof(h) == "number" and h <= 0 then return false end
    return true
end

--=========================== ПОЗА =================================
local function resolvePose(plr, rig)
    local st = poseState[plr]
    if not st then st = {ok = 0, bad = 0, live = nil} poseState[plr] = st end
    local attrPos = plr:GetAttribute(POSE_ATTR)
    local attrYaw = plr:GetAttribute(YAW_ATTR)
    local root = rig and getRoot(rig)
    local rigPos = root and root.Position

    if rigPos and typeof(attrPos) == "Vector3" and rig:GetAttribute(VIS_ATTR) == true then
        local d = (rigPos - attrPos).Magnitude
        if d < 2 then st.ok += 1 elseif d > 4 then st.bad += 1 end
        if st.ok + st.bad >= 6 then st.live = st.ok >= st.bad end
    end

    if typeof(attrPos) == "Vector3" and (st.live == true or rigPos == nil) then
        return CFrame.new(attrPos) * CFrame.Angles(0, typeof(attrYaw) == "number" and attrYaw or 0, 0)
    end
    if root then return root.CFrame end
    return nil
end

--=========================== ВИЗУАЛ ===============================
local function ensureBox(plr)
    local rec = boxes[plr]
    if rec and rec.part.Parent then return rec end
    if rec then pcall(function() rec.part:Destroy() end) end
    local part = new("Part", {
        Name = "V_"..plr.Name, Size = Vector3.new(2.4, 5.6, 2.4),
        Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
        CastShadow = false, Material = Enum.Material.SmoothPlastic,
        Color = Color3.new(1, 1, 1), Transparency = 1,
    }, rootFolder)
    local hl = new("Highlight", {
        Name = "VeniceESP", Adornee = part,
        DepthMode = CFG.ThroughWalls and Enum.HighlightDepthMode.AlwaysOnTop
                                        or Enum.HighlightDepthMode.Occluded,
        OutlineTransparency = CFG.OutlineTransparency,
    }, rootFolder)
    rec = { part = part, hl = hl }
    boxes[plr] = rec
    return rec
end

local function getInfoGui(plr, adornee)
    local bb = billboards[plr]
    if bb and bb.Adornee == adornee then return bb end
    if bb then bb:Destroy() end
    bb = new("BillboardGui", {
        Name = "VeniceESP_Info", Size = UDim2.new(0, 320, 0, 84),
        StudsOffset = Vector3.new(0, CFG.InfoOffset, 0), AlwaysOnTop = true,
        MaxDistance = CFG.InfoMaxDistance, ClipsDescendants = false, Adornee = adornee,
    }, workspace)
    new("TextLabel", {
        Name = "Text", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold, TextSize = 13, TextStrokeTransparency = 0.25,
        TextStrokeColor3 = Color3.new(0, 0, 0), TextColor3 = Color3.new(1, 1, 1),
    }, bb)
    billboards[plr] = bb
    return bb
end

local function buildInfo(plr, rig, dist)
    local lines = { plr.Name }
    lines[2] = string.format("[%s]  %dm", tostring(resolver and resolver(plr) or "?"), math.floor(dist))
    local extra = {}
    if CFG.ShowHealthArmor then
        local hp = (rig and rig:GetAttribute("Health")) or plr:GetAttribute("Health") or "?"
        local arm = jdecode(plr:GetAttribute("Armor"))
        local ar = "нет"
        if arm and arm.Type and (tonumber(arm.Health) or 0) > 0 then ar = tostring(arm.Type) end
        table.insert(extra, string.format("HP %s | AR %s", tostring(hp), ar))
    end
    if CFG.ShowWeapon then
        local eq = jdecode(plr:GetAttribute("CurrentEquipped"))
        local w = eq and eq.Name
        if not w then
            for i = 1, 5 do
                local s = jdecode(plr:GetAttribute("Slot"..i))
                if s and s.Weapon and s.Weapon ~= "" then w = s.Weapon break end
            end
        end
        if w then table.insert(extra, tostring(w)) end
    end
    if CFG.ShowKit then
        local kit = {}
        if plr:GetAttribute("HasDefuseKit") == true then table.insert(kit, "Defuse Kit") end
        if plr:GetAttribute("HasRescueKit") == true then table.insert(kit, "Rescue Kit") end
        local s5 = jdecode(plr:GetAttribute("Slot5"))
        if s5 and s5.Weapon == "C4" then table.insert(kit, "C4") end
        if #kit > 0 then table.insert(extra, table.concat(kit, " + ")) end
    end
    if #extra > 0 then lines[#lines+1] = table.concat(extra, "  |  ") end
    return table.concat(lines, "\n")
end

--=========================== CORE =================================
local function cleanup(plr)
    for _, t in ipairs({boxes, billboards, rigHL, fallbackRigs}) do
        local v = t[plr]
        if v then pcall(function() (v.part or v.hl or v):Destroy() end) end
        t[plr] = nil
    end
    tracked[plr] = nil
end

local function processPlayer(plr)
    local rig = findGameRig(plr)
    if not rig then
        rig = fallbackRigs[plr]
        if not (rig and rig.Parent) then
            if rig then pcall(function() rig:Destroy() end) end
            rig = buildFallbackRig(plr)
            fallbackRigs[plr] = rig
        end
    elseif fallbackRigs[plr] then
        pcall(function() fallbackRigs[plr]:Destroy() end)
        fallbackRigs[plr] = nil
    end

    local pose = resolvePose(plr, rig)
    if not pose then cleanup(plr) return end

    if plr ~= LP and rig and CFG.KillGameHighlight then
        for _, inst in ipairs(rig:GetChildren()) do
            if inst:IsA("Highlight") and inst.Name ~= "VeniceESP" then
                pcall(function() inst:Destroy() end)
            end
        end
    end

    local enemy = isEnemy(plr)
    local visible = CFG.Enabled and (enemy or CFG.ShowAllies)
        and (not CFG.OnlyAlive or isAlive(rig, plr))
    if plr == LP and not CFG.ShowAllies then visible = false end

    local dist = (pose.Position - getOrigin()).Magnitude
    if visible and CFG.MaxDistance > 0 and dist > CFG.MaxDistance then visible = false end

    local color   = enemy and CFG.EnemyFill   or CFG.AllyFill
    local outline = enemy and CFG.EnemyOutline or CFG.AllyOutline

    local rec = boxes[plr]
    if CFG.Box and visible then
        rec = ensureBox(plr)
        if rig then
            local ok, size = pcall(function() return rig:GetExtentsSize() end)
            if ok and size then
                rec.part.Size = Vector3.new(math.max(size.X, 1.5), math.max(size.Y, 4), math.max(size.Z, 1.5))
            end
        end
        rec.part.CFrame = pose
        rec.hl.Enabled = true
        rec.hl.FillColor, rec.hl.OutlineColor = color, outline
    elseif rec then
        rec.hl.Enabled = false
    end

    local hl = rigHL[plr]
    if hl and hl.Adornee ~= rig then hl:Destroy() hl = nil rigHL[plr] = nil end
    if visible and rig and not fallbackRigs[plr] then
        if not hl then
            hl = new("Highlight", {
                Name = "VeniceESP_Rig", Adornee = rig,
                DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
                OutlineTransparency = CFG.OutlineTransparency,
            }, rootFolder)
            rigHL[plr] = hl
        end
        hl.Enabled = true
        hl.FillColor, hl.OutlineColor = color, outline
    elseif hl then
        hl.Enabled = false
    end

    tracked[plr] = visible and pose or nil

    if CFG.ShowInfo then
        if visible then
            local adornee = (rec and rec.part) or (rig and (rig:FindFirstChild("Head") or rig.PrimaryPart))
            if adornee then
                local bb = getInfoGui(plr, adornee)
                bb.Enabled = true
                bb.Text.Text = buildInfo(plr, rig, dist)
                bb.Text.TextColor3 = outline
            end
        else
            local bb = billboards[plr]
            if bb then bb.Enabled = false end
        end
    end
end

--=========================== МЯЧ ==================================
local function isBallPart(d)
    if not d:IsA("BasePart") then return false end
    if d:IsDescendantOf(rootFolder) then return false end
    local n = d.Name:lower()
    for _, w in ipairs(CFG.BallWords) do
        if n:find(w, 1, true) then return true end
    end
    if d.Anchored then return false end
    local s = d.Size
    return s.X <= 5 and s.Y <= 5 and s.Z <= 5
end

local function scanBalls()
    if not CFG.Ball then balls = {} return end
    local found = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        if isBallPart(d) then found[d] = true end
    end
    for d in pairs(balls) do
        if not found[d] then balls[d] = nil end
    end
    for d in pairs(found) do
        if not balls[d] then balls[d] = {part = d} end
    end
end

local lastFire = 0
local function mouse1()
    local vp = Camera.ViewportSize
    VIM:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, 0, true, game, 1)
    VIM:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, 0, false, game, 1)
end

local function fireDeflect()
    if CFG.BallKey then
        VIM:SendKeyEvent(true, CFG.BallKey, false, game)
        VIM:SendKeyEvent(false, CFG.BallKey, false, game)
    else
        mouse1()
    end
end

local function aimAt(pos)
    local sp, onScreen = Camera:WorldToViewportPoint(pos)
    if not onScreen then return end
    local vp = Camera.ViewportSize
    local dx = (sp.X - vp.X / 2) * CFG.BallAimGain
    local dy = (sp.Y - vp.Y / 2) * CFG.BallAimGain
    if math.abs(dx) < CFG.BallAimDeadzone and math.abs(dy) < CFG.BallAimDeadzone then return end
    if mousemoverel then
        pcall(mousemoverel, dx, dy)
    else
        VIM:SendMouseMoveEvent(vp.X / 2 + dx, vp.Y / 2 + dy, game)
    end
end

local function ballTick()
    if not CFG.Ball or not CFG.Enabled then return end
    local myPos = getOrigin()
    local now = os.clock()
    local best, bestDist = nil, CFG.BallRange
    for _, rec in pairs(balls) do
        local p = rec.part
        if p.Parent then
            local d = (p.Position - myPos).Magnitude
            if d < bestDist then
                if CFG.BallApproachOnly then
                    local vel = p.AssemblyLinearVelocity
                    if vel.Magnitude > 0.5 then
                        local toMe = (myPos - p.Position).Unit
                        if vel.Unit:Dot(toMe) > 0.15 then best, bestDist = p, d end
                    end
                else
                    best, bestDist = p, d
                end
            end
        end
    end
    if not best then return end
    if CFG.BallAim then aimAt(best.Position) end
    if now - lastFire >= CFG.BallCooldown then
        lastFire = now
        pcall(fireDeflect)
    end
end

--=========================== RUN ==================================
refreshResolver()

local lastRefresh, lastBall = 0, 0
local thread = task.spawn(function()
    while running do
        local now = os.clock()
        if now - lastRefresh >= CFG.TeamRefresh then lastRefresh = now; pcall(refreshResolver) end
        pcall(function()
            for _, plr in ipairs(Players:GetPlayers()) do processPlayer(plr) end
        end)
        if now - lastBall >= 0.25 then lastBall = now; pcall(scanBalls) end
        task.wait(CFG.UpdateRate)
    end
end)

local function fastTick()
    if CFG.TryReparentRig then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP then
                local rig = plr.Character
                if rig and rig:IsA("Model") and rig.Parent and not rig:IsDescendantOf(workspace) then
                    if not origParent[rig] then origParent[rig] = rig.Parent end
                    pcall(function() rig.Parent = charFolder() end)
                end
            end
        end
    end

    if CFG.PoseOverride then
        for plr, fb in pairs(fallbackRigs) do
            if fb and fb.Parent then
                local pose = resolvePose(plr, findGameRig(plr))
                if pose then fb:PivotTo(pose) end
            end
        end
    end

    if CFG.Pulse then
        local a = (math.sin(os.clock() * CFG.PulseSpeed) + 1) / 2
        local tr = CFG.PulseMin + (CFG.PulseMax - CFG.PulseMin) * a
        for _, rec in pairs(boxes) do if rec.hl.Enabled then rec.hl.FillTransparency = tr end end
        for _, hl in pairs(rigHL) do if hl.Enabled then hl.FillTransparency = tr end end
    end

    pcall(ballTick)
end
RunService:BindToRenderStep("VeniceESP_FastTick", 3001, fastTick)

conns[#conns+1] = UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == CFG.ToggleKey then
        CFG.Enabled = not CFG.Enabled
        if not CFG.Enabled then
            for _, rec in pairs(boxes) do rec.hl.Enabled = false end
            for _, hl in pairs(rigHL) do hl.Enabled = false end
            for _, bb in pairs(billboards) do bb.Enabled = false end
        end
    elseif input.KeyCode == CFG.InfoKey then
        CFG.ShowInfo = not CFG.ShowInfo
        if not CFG.ShowInfo then for _, bb in pairs(billboards) do bb.Enabled = false end end
    end
end)

conns[#conns+1] = Players.PlayerRemoving:Connect(function(plr) task.defer(cleanup, plr) end)

--=========================== API ==================================
local api = { CFG = CFG }

function api:Diag()
    print("=== Venice ESP v11 diag ===")
    print("команда: "..resolverName)
    local cf = culledFolder()
    print("culled: "..(cf and #cf:GetChildren() or "нет").." | workspace.Characters: "
        ..tostring(workspace:FindFirstChild("Characters") and #workspace.Characters:GetChildren() or "нет"))
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local rig = findGameRig(p)
            local st = poseState[p] or {}
            print(string.format("  %s | enemy=%s | rig=%s | parent=%s | attrLive=%s",
                p.Name, tostring(isEnemy(p)), rig and "yes" or "NIL",
                rig and (rig.Parent and rig.Parent:GetFullName() or "NIL") or "-",
                tostring(st.live)))
        end
    end
end

function api:BallDebug()
    print("=== мячи/снаряды в workspace ===")
    local n = 0
    for _, d in ipairs(workspace:GetDescendants()) do
        if isBallPart(d) then
            n += 1
            print(string.format("  %s | class=%s | size=%.1f,%.1f,%.1f | anchored=%s | speed=%.1f | parent=%s",
                d:GetFullName(), d.ClassName, d.Size.X, d.Size.Y, d.Size.Z,
                tostring(d.Anchored), d.AssemblyLinearVelocity.Magnitude,
                d.Parent and d.Parent.Name or "-"))
        end
    end
    print("итого: "..n)
end

function api:Abilities()
    print("=== инвентарь способностей ===")
    local KEY = {"ability","skill","ult","charge","cooldown","spell","power","dash","boost","ball","orb","kick"}
    local function match(s)
        local l = s:lower()
        for _, w in ipairs(KEY) do if l:find(w, 1, true) then return true end end
        return false
    end
    print("-- атрибуты игроков --")
    for _, p in ipairs(Players:GetPlayers()) do
        for name, v in pairs(p:GetAttributes()) do
            if match(name) then print("  "..p.Name.."."..name.." = "..tostring(v)) end
        end
        local c = p.Character
        if c then
            for name, v in pairs(c:GetAttributes()) do
                if match(name) then print("  [char]"..p.Name.."."..name.." = "..tostring(v)) end
            end
        end
    end
    print("-- модули/ремоуты --")
    for _, d in ipairs(RS:GetDescendants()) do
        if (d:IsA("ModuleScript") or d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) and match(d.Name) then
            print("  "..d:GetFullName())
        end
    end
    print("-- объекты в workspace --")
    for _, d in ipairs(workspace:GetDescendants()) do
        if match(d.Name) and not d:IsDescendantOf(rootFolder) then print("  "..d:GetFullName()) end
    end
end

function api:Watch()
    print("=== живой лог: изменения атрибутов игроков и новые объекты ===")
    local hooked = {}
    local function hook(p)
        for name in pairs(p:GetAttributes()) do
            local key = p.Name.."."..name
            if not hooked[key] then
                hooked[key] = true
                p:GetAttributeChangedSignal(name):Connect(function()
                    print(string.format("[attr] %s.%s = %s", p.Name, name, tostring(p:GetAttribute(name))))
                end)
            end
        end
    end
    conns[#conns+1] = workspace.DescendantAdded:Connect(function(d)
        local l = d.Name:lower()
        if l:find("ball", 1, true) or l:find("orb", 1, true)
            or l:find("projectile", 1, true) or l:find("ability", 1, true) then
            print("[new] "..d:GetFullName().." ("..d.ClassName..")")
        end
    end)
    conns[#conns+1] = task.spawn(function()
        while running do
            for _, p in ipairs(Players:GetPlayers()) do pcall(hook, p) end
            task.wait(1)
        end
    end)
    for _, p in ipairs(Players:GetPlayers()) do pcall(hook, p) end
end

function api:Destroy()
    running = false
    pcall(function() RunService:UnbindFromRenderStep("VeniceESP_FastTick") end)
    for _, c in pairs(conns) do pcall(function() c:Disconnect() end) end
    conns = {}
    for _, rec in pairs(boxes) do pcall(function() rec.part:Destroy() rec.hl:Destroy() end) end
    for _, bb in pairs(billboards) do pcall(function() bb:Destroy() end) end
    for _, hl in pairs(rigHL) do pcall(function() hl:Destroy() end) end
    for _, fb in pairs(fallbackRigs) do pcall(function() fb:Destroy() end) end
    if CFG.RestoreOnUnload then
        for rig, parent in pairs(origParent) do
            if rig.Parent and parent then pcall(function() rig.Parent = parent end) end
        end
    end
    boxes, billboards, rigHL, fallbackRigs, tracked, origParent, balls = {}, {}, {}, {}, {}, {}, {}
    if rootFolder then pcall(function() rootFolder:Destroy() end) end
    if thread then pcall(task.cancel, thread) end
    if _G.BloxStrikeESP == api then _G.BloxStrikeESP = nil end
end

_G.BloxStrikeESP = api
print("[Venice] Blox Strike v11 загружен. E — WH, F — инфа.")
