--[[
=====================================================================
   SleepScript | Blade Ball (v2.0 STEALTH)
   Байпас: cloneref + случайные имена GUI + ZWS в тексте + gethui
           + кольцо через HandleAdornment (workspace не трогаем)
   Z — свернуть, Крестик — закрыть, RightShift — AutoParry
=====================================================================
]]

local cloneref = cloneref or function(o) return o end
local Players             = cloneref(game:GetService("Players"))
local RunService          = cloneref(game:GetService("RunService"))
local UserInputService    = cloneref(game:GetService("UserInputService"))
local VirtualInputManager = cloneref(game:GetService("VirtualInputManager"))
local TweenService        = cloneref(game:GetService("TweenService"))
local Lighting            = cloneref(game:GetService("Lighting"))
local Stats               = cloneref(game:GetService("Stats"))
local ReplicatedStorage   = cloneref(game:GetService("ReplicatedStorage"))
local CoreGui             = cloneref(game:GetService("CoreGui"))
local HttpService         = cloneref(game:GetService("HttpService"))
local TeleportService     = cloneref(game:GetService("TeleportService"))

local LP = Players.LocalPlayer
local PG = LP:FindFirstChildOfClass("PlayerGui")
local function cam() return workspace.CurrentCamera end

--=============================================================
--  STEALTH-ХЕЛПЕРЫ (ядро байпаса)
--=============================================================
local ZWS = utf8.char(0x200B)
local function S(str)
    if typeof(str) ~= "string" or str == "" then return str end
    local chars = {}
    local ok = pcall(function()
        for _, code in utf8.codes(str) do table.insert(chars, utf8.char(code)) end
    end)
    if not ok or #chars == 0 then
        for i = 1, #str do table.insert(chars, str:sub(i, i)) end
    end
    return table.concat(chars, ZWS)
end
local function RandName() return "R_" .. tostring(math.random(100000, 999999)) end

local function SafeParent()
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    if syn and syn.protect_gui then return CoreGui end
    return PG or CoreGui
end

--=============================================================
--  SINGLETON
--=============================================================
local Conns = {}
local function track(c) table.insert(Conns, c); return c end

local KilledPrevious = false
if getgenv().SleepScriptCleanup then
    pcall(getgenv().SleepScriptCleanup)
    KilledPrevious = true
end
for _, ref in ipairs({ "SleepScriptGui", "SleepScriptOverlay" }) do
    local g = getgenv()[ref]
    if g then pcall(function() g:Destroy() end) end
end
do
    local oc = workspace:FindFirstChild("SleepParryCircle")
    if oc then oc:Destroy() end
end
getgenv().SleepScriptCleanup = function()
    for _, c in ipairs(Conns) do pcall(function() c:Disconnect() end) end
    Conns = {}
end

--=============================================================
--  КОНФИГ
--=============================================================
local SS = getgenv().SleepScript or {}
getgenv().SleepScript = SS

local DEFAULTS = {
    MenuState = "open",
    AutoParry = true, PingBased = true, PingBasedOffset = 1.95,
    DistanceToParry = 0.65, EmergencyRadius = 10, EmergencyClick = false,
    ClashDistance = 22, ClashSpeed = 0.05, NormalSpeed = 0.10,
    OneClickPerBall = true, MaxCPS = 9, ClickJitter = 0.012,
    InputMethod = "key",
    ShowRadius = true, RadiusScale = 1,
    UsePreSim = true, ClickDownOnly = true,
    AutoRejoin = true,
    FOV = 70, CustomSky = false, SkyId = "rbxassetid://159454299",
    Headless = false, Korblox = false, KorbloxMesh = "rbxassetid://139607718",
    FPSBoost = false, NoEffects = false, FPSCap = 240, PhysicsRate = false,
    Overlay = true, SkinLock = false,
}
for k, v in pairs(DEFAULTS) do if SS[k] == nil then SS[k] = v end end

local C = {
    bg = Color3.fromRGB(11, 13, 20), bg2 = Color3.fromRGB(18, 21, 31),
    card = Color3.fromRGB(23, 27, 39), accent = Color3.fromRGB(124, 92, 255),
    accent2 = Color3.fromRGB(0, 229, 192), text = Color3.fromRGB(236, 239, 250),
    dim = Color3.fromRGB(132, 140, 162), off = Color3.fromRGB(38, 43, 58),
    stroke = Color3.fromRGB(48, 54, 74), bad = Color3.fromRGB(255, 92, 92),
}

local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end
local function corner(o, r) new("UICorner", {CornerRadius = UDim.new(0, r or 10)}, o) end
local function safe(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then warn("[SS] " .. tostring(err)) end
    end
end
local function makeDraggable(frame, handle)
    handle = handle or frame
    local dragging, dragInput, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local d = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                       startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

local ApplySky, ApplyBody, ApplyFPSBoost, ApplyEffects
local ApplySkin, RenderSkinList, BuildSkinDatabase
local statusLbl, kickLbl, reportLbl, Snapshot

--=============================================================
--  ЛОГ КИКОВ + АВТО-ВОЗВРАТ
--=============================================================
local KickLog = getgenv().SleepScriptKickLog or {}
getgenv().SleepScriptKickLog = KickLog

local function Rejoin()
    if game.JobId and game.JobId ~= "" then
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
    else
        TeleportService:Teleport(game.PlaceId, LP)
    end
end

Snapshot = function()
    local f = {}
    if SS.AutoParry then f[#f + 1] = "PARRY" end
    if SS.ShowRadius then f[#f + 1] = "RING" end
    if SS.Overlay then f[#f + 1] = "HUD" end
    if SS.CustomSky then f[#f + 1] = "SKY" end
    if SS.Headless then f[#f + 1] = "HEADLESS" end
    if SS.Korblox then f[#f + 1] = "KORBLOX" end
    if SS.FPSBoost then f[#f + 1] = "FPSBOOST" end
    if SS.PhysicsRate then f[#f + 1] = "PHYSRATE" end
    return #f > 0 and table.concat(f, ", ") or "только меню"
end

local function logKick(src)
    table.insert(KickLog, os.date("%H:%M:%S") .. " [" .. src .. "] актив: " .. Snapshot())
    if #KickLog > 20 then table.remove(KickLog, 1) end
    if kickLbl then
        kickLbl.Text = S("Киков: " .. #KickLog .. " • " .. KickLog[#KickLog])
    end
end

--=============================================================
--  GUI (случайное имя + gethui)
--=============================================================
local gui = new("ScreenGui", {
    Name = RandName(), ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true,
})
getgenv().SleepScriptGui = gui
pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
if not gui.Parent then gui.Parent = SafeParent() end

local WIN_W, WIN_H = 560, 360

local shadow = new("Frame", {
    Parent = gui, Name = RandName(), Size = UDim2.fromOffset(WIN_W + 8, WIN_H + 8),
    Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55, BorderSizePixel = 0,
})
corner(shadow, 18)

local main = new("Frame", {
    Parent = gui, Name = RandName(), Size = UDim2.fromOffset(WIN_W, WIN_H),
    Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = C.bg, BorderSizePixel = 0, ClipsDescendants = true, Active = true,
})
corner(main, 14)
new("UIGradient", {Rotation = 20, Color = ColorSequence.new(C.bg, C.bg2)}, main)
new("UIStroke", {Color = C.stroke, Thickness = 1, Transparency = 0.3}, main)
makeDraggable(main)

local function syncShadow()
    local p, s = main.Position, main.Size
    shadow.Position = UDim2.new(p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset + 6)
    shadow.Size = UDim2.new(s.X.Scale, s.X.Offset + 8, s.Y.Scale, s.Y.Offset + 8)
end
main:GetPropertyChangedSignal("Position"):Connect(syncShadow)
main:GetPropertyChangedSignal("Size"):Connect(syncShadow)
syncShadow()

local header = new("Frame", {
    Parent = main, Name = RandName(), Size = UDim2.new(1, 0, 0, 52),
    BackgroundTransparency = 1, Active = true,
})
makeDraggable(main, header)

new("TextLabel", {
    Parent = header, Size = UDim2.new(1, -140, 0, 18), Position = UDim2.fromOffset(18, 12),
    BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = S("SleepScript"),
    TextSize = 17, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
})
new("TextLabel", {
    Parent = header, Size = UDim2.new(1, -140, 0, 14), Position = UDim2.fromOffset(18, 30),
    BackgroundTransparency = 1, Font = Enum.Font.Gotham,
    Text = S("Blade Ball • v2.0 stealth" .. (KilledPrevious and " • старый убит" or "")),
    TextSize = 11, TextColor3 = KilledPrevious and C.accent2 or C.dim,
    TextXAlignment = Enum.TextXAlignment.Left,
})

local minBtn = new("TextButton", {
    Parent = header, Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -76, 0, 12),
    BackgroundColor3 = C.off, Text = S("—"), Font = Enum.Font.GothamBold,
    TextSize = 15, TextColor3 = C.text, AutoButtonColor = false,
})
corner(minBtn, 8)
local closeBtn = new("TextButton", {
    Parent = header, Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -42, 0, 12),
    BackgroundColor3 = C.off, Text = S("×"), Font = Enum.Font.GothamBold,
    TextSize = 17, TextColor3 = C.text, AutoButtonColor = false,
})
corner(closeBtn, 8)

local sidebar = new("Frame", {
    Parent = main, Size = UDim2.new(0, 150, 1, -62), Position = UDim2.fromOffset(0, 62),
    BackgroundColor3 = C.bg, BackgroundTransparency = 0.35, BorderSizePixel = 0,
})
new("TextLabel", {
    Parent = sidebar, Size = UDim2.new(1, -20, 0, 14), Position = UDim2.new(0, 10, 1, -22),
    BackgroundTransparency = 1, Font = Enum.Font.Gotham, Text = S("Z — свернуть меню"),
    TextSize = 10, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
})

local contentHolder = new("Frame", {
    Parent = main, Size = UDim2.new(1, -160, 1, -74), Position = UDim2.fromOffset(155, 64),
    BackgroundTransparency = 1,
})

local pages, tabs = {}, {}
local TABS = {
    { key = "Start",   label = "СТАРТ" },
    { key = "AutoParry", label = "AutoParry" },
    { key = "Stealth",   label = "Стелс" },
    { key = "Visuals",   label = "Visuals" },
    { key = "Skin",      label = "Скин" },
    { key = "Perf",      label = "FPS" },
}

local function CreatePage()
    return new("ScrollingFrame", {
        Parent = contentHolder, Name = RandName(), Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        CanvasSize = UDim2.new(), ScrollBarThickness = 3,
        ScrollBarImageColor3 = C.accent, Visible = false,
    })
end

local function selectTab(key)
    for k, p in pairs(pages) do p.Visible = (k == key) end
    for k, b in pairs(tabs) do
        local on = (k == key)
        TweenService:Create(b, TweenInfo.new(0.15), {
            BackgroundColor3 = on and C.accent or C.off,
            BackgroundTransparency = on and 0 or 0.55,
            TextColor3 = on and Color3.new(1, 1, 1) or C.dim,
        }):Play()
    end
end

for i, t in ipairs(TABS) do
    local btn = new("TextButton", {
        Parent = sidebar, Name = RandName(), Size = UDim2.new(1, -20, 0, 28),
        Position = UDim2.fromOffset(10, 4 + (i - 1) * 31),
        BackgroundColor3 = C.off, BackgroundTransparency = 0.55,
        Text = S("   " .. t.label), Font = Enum.Font.GothamMedium,
        TextSize = 12, TextColor3 = C.dim,
        TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false,
    })
    corner(btn, 8)
    btn.MouseButton1Click:Connect(function() selectTab(t.key) end)
    tabs[t.key] = btn
    pages[t.key] = CreatePage()
end

local function NewLayout(page)
    local L = { page = page, y = 8, sec = nil, secTop = 0, sy = 0 }
    function L:Section(title)
        local sec = new("Frame", {
            Parent = self.page, Name = RandName(), Size = UDim2.new(1, 0, 0, 40),
            Position = UDim2.new(0, 0, 0, self.y),
            BackgroundColor3 = C.card, BackgroundTransparency = 0.2, BorderSizePixel = 0,
        })
        corner(sec, 10)
        new("UIStroke", {Color = C.stroke, Transparency = 0.55, Thickness = 1}, sec)
        self.sec, self.secTop, self.sy = sec, self.y, 10
        if title then
            new("TextLabel", {
                Parent = sec, Size = UDim2.new(1, -20, 0, 16), Position = UDim2.fromOffset(10, 10),
                BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = S(title),
                TextSize = 12, TextColor3 = C.accent2, TextXAlignment = Enum.TextXAlignment.Left,
            })
            self.sy = 32
        end
        return sec
    end
    function L:Row(h)
        local row = new("Frame", {
            Parent = self.sec, Name = RandName(), Size = UDim2.new(1, -20, 0, h),
            Position = UDim2.fromOffset(10, self.sy), BackgroundTransparency = 1,
        })
        self.sy = self.sy + h + 8
        return row
    end
    function L:EndSection()
        local h = self.sy + 4
        self.sec.Size = UDim2.new(1, 0, 0, h)
        self.y = self.secTop + h + 10
        self.sec = nil
        self.page.CanvasSize = UDim2.new(0, 0, 0, self.y + 8)
    end
    return L
end

local Sync = {}

local function AddToggle(row, name, default, callback)
    new("TextLabel", {
        Parent = row, Size = UDim2.new(1, -50, 1, 0), BackgroundTransparency = 1,
        Font = Enum.Font.Gotham, Text = S(name), TextSize = 12,
        TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
    })
    local btn = new("TextButton", {
        Parent = row, Size = UDim2.fromOffset(38, 20), Position = UDim2.new(1, -38, 0.5, -10),
        BackgroundColor3 = default and C.accent or C.off, Text = "", AutoButtonColor = false,
    })
    corner(btn, 10)
    local knob = new("Frame", {
        Parent = btn, Size = UDim2.fromOffset(16, 16),
        Position = default and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0,
    })
    corner(knob, 8)
    local state = default
    local function render(fire)
        TweenService:Create(btn, TweenInfo.new(0.18),
            {BackgroundColor3 = state and C.accent or C.off}):Play()
        TweenService:Create(knob, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)}):Play()
        if fire and callback then callback(state) end
    end
    btn.MouseButton1Click:Connect(function() state = not state; render(true) end)
    local obj = { Set = function(v, fire) state = v; render(fire) end, Get = function() return state end }
    Sync[name] = obj
    return obj
end

local function AddSlider(row, name, min, max, default, decimals, callback)
    new("TextLabel", {
        Parent = row, Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1,
        Font = Enum.Font.Gotham, Text = S(name), TextSize = 12,
        TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
    })
    local val = new("TextLabel", {
        Parent = row, Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium, Text = tostring(default), TextSize = 12,
        TextColor3 = C.accent2, TextXAlignment = Enum.TextXAlignment.Right,
    })
    local bar = new("TextButton", {
        Parent = row, Size = UDim2.new(1, 0, 0, 6), Position = UDim2.new(0, 0, 1, -8),
        BackgroundColor3 = C.off, Text = "", AutoButtonColor = false,
    })
    corner(bar, 3)
    local fill = new("Frame", {Parent = bar, Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = C.accent, BorderSizePixel = 0})
    corner(fill, 3)
    local knob = new("Frame", {Parent = bar, Size = UDim2.fromOffset(12, 12),
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0})
    corner(knob, 6)
    local value = default
    local function set(v, fire)
        value = math.clamp(v, min, max)
        local a = (value - min) / (max - min)
        fill.Size = UDim2.new(a, 0, 1, 0)
        knob.Position = UDim2.new(a, 0, 0.5, 0)
        local m = 10 ^ (decimals or 0)
        val.Text = tostring(math.floor(value * m + 0.5) / m)
        if fire and callback then callback(value) end
    end
    local dragging = false
    local function update(input)
        local a = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        set(min + (max - min) * a, true)
    end
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then dragging = true; update(i) end
    end)
    bar.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch) then update(i) end
    end)
    set(default, false)
    return { Set = function(v) set(v, false) end, Get = function() return value end }
end

local function AddButton(row, name, callback, col)
    local btn = new("TextButton", {
        Parent = row, Size = UDim2.fromScale(1, 1), BackgroundColor3 = col or C.off,
        Text = S(name), Font = Enum.Font.GothamMedium, TextSize = 12,
        TextColor3 = C.text, AutoButtonColor = false,
    })
    corner(btn, 8)
    btn.MouseButton1Click:Connect(safe(callback))
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = C.accent}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = col or C.off}):Play()
    end)
    return btn
end

local function AddTextbox(row, placeholder, default, callback)
    local box = new("TextBox", {
        Parent = row, Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.off,
        Text = default or "", PlaceholderText = S(placeholder), Font = Enum.Font.Gotham,
        TextSize = 12, TextColor3 = C.text, PlaceholderColor3 = C.dim,
        ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
    })
    corner(box, 8)
    new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, box)
    box.FocusLost:Connect(function() if callback then safe(callback)(box.Text) end end)
    return box
end

local function AddHint(row, text, color)
    new("TextLabel", {
        Parent = row, Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
        Font = Enum.Font.Gotham, TextWrapped = true, TextSize = 11,
        TextColor3 = color or C.dim, Text = S(text), TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
    })
end

local function AddChoices(row, options, current, callback)
    local n = #options
    local btns = {}
    for i, opt in ipairs(options) do
        local b = new("TextButton", {
            Parent = row, Size = UDim2.new(1 / n, -4, 1, 0),
            Position = UDim2.new((i - 1) / n, 2, 0, 0),
            BackgroundColor3 = (opt.value == current) and C.accent or C.off,
            Text = S(opt.label), Font = Enum.Font.Gotham, TextSize = 11,
            TextColor3 = C.text, AutoButtonColor = false,
        })
        corner(b, 7)
        b.MouseButton1Click:Connect(safe(function()
            for _, x in ipairs(btns) do
                TweenService:Create(x, TweenInfo.new(0.12), {BackgroundColor3 = C.off}):Play()
            end
            TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = C.accent}):Play()
            callback(opt.value)
        end))
        table.insert(btns, b)
    end
end

--=============================================================
--  СТРАНИЦА СТАРТ
--=============================================================
L = NewLayout(pages.Start)
L:Section("ЧТО ИЗМЕНИЛОСЬ")
AddHint(L:Row(92),
    "Байпас теперь как в рабочем Identical: случайное имя окна, " ..
    "невидимые разделители в тексте, gethui, кольцо-адорнмент вместо " ..
    "Part в workspace. Хук Kick и снос Security убраны — они не помогали.")
L:EndSection()
L:Section("БЫСТРОЕ")
AddButton(L:Row(26), "Включить ВСЁ", function()
    for n, v in pairs({
        ["AutoParry"] = true, ["Кольцо парри"] = true,
        ["FPS / Ping HUD"] = true,
    }) do if Sync[n] then Sync[n].Set(v, true) end end
end)
AddButton(L:Row(26), "Выключить ВСЁ", function()
    for n, v in pairs({
        ["AutoParry"] = false, ["Кольцо парри"] = false, ["FPS / Ping HUD"] = false,
        ["CustomSky"] = false, ["Headless"] = false, ["Korblox"] = false,
        ["FPS Boost"] = false, ["Убрать эффекты"] = false,
    }) do if Sync[n] then Sync[n].Set(v, true) end end
end, Color3.fromRGB(60, 44, 44))
L:EndSection()

--============ AUTOPARRY ============
L = NewLayout(pages.AutoParry)
L:Section("PARRY")
AddToggle(L:Row(24), "AutoParry", SS.AutoParry, function(v) SS.AutoParry = v end)
AddToggle(L:Row(24), "Кольцо парри", SS.ShowRadius, function(v) SS.ShowRadius = v end)
AddSlider(L:Row(36), "Размер кольца", 0.2, 3, SS.RadiusScale, 1, function(v) SS.RadiusScale = v end)
L:EndSection()
L:Section("СПОСОБ ВВОДА")
do
    local row = L:Row(28)
    AddChoices(row, {
        { label = "keypress F",  value = "key" },
        { label = "VirtualInput", value = "vim" },
        { label = "mouse1click",  value = "mouse" },
    }, SS.InputMethod, function(v) SS.InputMethod = v end)
end
AddHint(L:Row(28), "keypress F — как в Identical, если BAC палит клики мышью.", C.dim)
L:EndSection()
L:Section("ЧЕЛОВЕЧНОСТЬ")
AddToggle(L:Row(24), "Один клик на шар", SS.OneClickPerBall, function(v) SS.OneClickPerBall = v end)
AddSlider(L:Row(36), "Max CPS", 1, 20, SS.MaxCPS, 0, function(v) SS.MaxCPS = v end)
AddToggle(L:Row(24), "Emergency click", SS.EmergencyClick, function(v) SS.EmergencyClick = v end)
AddSlider(L:Row(36), "Jitter клика", 0, 0.05, SS.ClickJitter, 3, function(v) SS.ClickJitter = v end)
L:EndSection()
L:Section("ТАЙМИНГ")
AddToggle(L:Row(24), "PingBased", SS.PingBased, function(v) SS.PingBased = v end)
AddSlider(L:Row(36), "PingBasedOffset", 0, 5, SS.PingBasedOffset, 2, function(v) SS.PingBasedOffset = v end)
AddSlider(L:Row(36), "DistanceToParry", 0.05, 3, SS.DistanceToParry, 2, function(v) SS.DistanceToParry = v end)
AddSlider(L:Row(36), "EmergencyRadius", 1, 30, SS.EmergencyRadius, 0, function(v) SS.EmergencyRadius = v end)
AddSlider(L:Row(36), "ClashDistance", 5, 60, SS.ClashDistance, 0, function(v) SS.ClashDistance = v end)
AddSlider(L:Row(36), "ClashSpeed", 0.01, 0.2, SS.ClashSpeed, 2, function(v) SS.ClashSpeed = v end)
AddSlider(L:Row(36), "NormalSpeed", 0.01, 0.3, SS.NormalSpeed, 2, function(v) SS.NormalSpeed = v end)
L:EndSection()
L:Section("ПРОЧЕЕ")
AddToggle(L:Row(24), "PreSimulation", SS.UsePreSim, function(v) SS.UsePreSim = v end)
AddToggle(L:Row(24), "Клик только вниз", SS.ClickDownOnly, function(v) SS.ClickDownOnly = v end)
L:EndSection()

--============ СТЕЛС ==============
L = NewLayout(pages.Stealth)
L:Section("БАЙПАС (всегда включён)")
AddHint(L:Row(96),
    "• Случайное имя ScreenGui (R_xxxxxx)\n" ..
    "• ZWS между буквами во всём тексте\n" ..
    "• gethui() — окно в скрытой папке\n" ..
    "• cloneref на сервисах\n" ..
    "• Кольцо = CylinderHandleAdornment, workspace чистый\n" ..
    "• Никаких хуков метаметодов")
L:EndSection()
L:Section("АВТО-ВОЗВРАТ")
AddToggle(L:Row(24), "Rejoin при кике", SS.AutoRejoin, function(v) SS.AutoRejoin = v end)
statusLbl = new("TextLabel", {
    Parent = L:Row(16), Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
    Font = Enum.Font.Gotham, Text = S("Хуков нет — только stealth"), TextSize = 11,
    TextColor3 = C.accent2, TextXAlignment = Enum.TextXAlignment.Left,
})
kickLbl = new("TextLabel", {
    Parent = L:Row(30), Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
    Font = Enum.Font.Gotham, Text = S("Киков: 0"), TextSize = 10,
    TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
})
AddButton(L:Row(26), "Вернуться на этот сервер", function() pcall(Rejoin) end)
AddButton(L:Row(26), "Очистить лог киков", function()
    for i = #KickLog, 1, -1 do table.remove(KickLog, i) end
    if kickLbl then kickLbl.Text = S("Киков: 0") end
end)
L:EndSection()

--============ ДИАГНОСТИКА ============
local function BuildReport()
    local t = {}
    local function add(k, v) table.insert(t, k .. ": " .. tostring(v)) end
    add("== СЕЙЧАС АКТИВНО ==", "")
    add("функции", Snapshot())
    add("GUI имя", gui.Name)
    add("GUI parent", gui.Parent and gui.Parent:GetFullName() or "nil")
    add("ZWS работает", S("AB") == "A" .. ZWS .. "B")
    add("предыдущий убит", KilledPrevious)
    add("коннектов", #Conns)
    add("== EXECUTOR ==", "")
    add("name", (identifyexecutor and (select(1, identifyexecutor()))) or "?")
    add("gethui", gethui ~= nil)
    add("keypress", keypress ~= nil)
    add("mouse1click", mouse1click ~= nil)
    add("cloneref", cloneref ~= nil)
    add("TouchEnabled", UserInputService.TouchEnabled)
    add("== ИГРА ==", "")
    add("PlaceId", game.PlaceId)
    add("PlaceVersion", game.PlaceVersion)
    add("workspace частей добавлено", workspace:FindFirstChild("SleepParryCircle") and "да" or "нет")
    add("== RS security-like ==", "")
    local found = {}
    for _, v in pairs(ReplicatedStorage:GetChildren()) do
        local n = v.Name:lower()
        if n:find("secur") or n:find("bac") or n:find("anti") then
            table.insert(found, v.Name .. " [" .. v.ClassName .. "]")
        end
    end
    add("найдено", #found > 0 and table.concat(found, " | ") or "НЕТ")
    add("== ЛОГ КИКОВ ==", "")
    for _, l in ipairs(KickLog) do table.insert(t, "  " .. l) end
    local txt = table.concat(t, "\n")
    if reportLbl then reportLbl.Text = txt end
    print("[SS] ОТЧЁТ:\n" .. txt)
end

L = NewLayout(pages.Visuals)
L:Section("КАМЕРА")
AddSlider(L:Row(36), "Field of View", 40, 120, SS.FOV, 0, function(v)
    SS.FOV = v; if cam() then cam().FieldOfView = v end
end)
L:EndSection()
L:Section("НЕБО")
AddToggle(L:Row(24), "CustomSky", SS.CustomSky, function(v)
    SS.CustomSky = v; if v then ApplySky(SS.SkyId) else ApplySky(nil) end
end)
do
    local row = L:Row(26)
    local list = {
        { "Sunset", "rbxassetid://159454299" }, { "Night", "rbxassetid://57055771" },
        { "Cloudy", "rbxassetid://271042910" }, { "Space", "rbxassetid://133883647" },
    }
    for i, tx in ipairs(list) do
        local b = new("TextButton", {
            Parent = row, Size = UDim2.new(0.25, -5, 1, 0),
            Position = UDim2.new((i - 1) * 0.25, 0, 0, 0),
            BackgroundColor3 = C.off, Text = S(tx[1]), Font = Enum.Font.Gotham,
            TextSize = 11, TextColor3 = C.text, AutoButtonColor = false,
        })
        corner(b, 7)
        b.MouseButton1Click:Connect(safe(function()
            SS.SkyId = tx[2]; if SS.CustomSky then ApplySky(tx[2]) end
        end))
    end
end
AddTextbox(L:Row(26), "Свой Sky ID", SS.SkyId, function(t)
    if t ~= "" then SS.SkyId = t; if SS.CustomSky then ApplySky(t) end end
end)
L:EndSection()
L:Section("ТЕЛО")
AddToggle(L:Row(24), "Headless", SS.Headless, function(v) SS.Headless = v; ApplyBody() end)
AddToggle(L:Row(24), "Korblox", SS.Korblox, function(v) SS.Korblox = v; ApplyBody() end)
AddTextbox(L:Row(26), "Korblox Mesh ID", SS.KorbloxMesh, function(t)
    SS.KorbloxMesh = t; if SS.Korblox then ApplyBody() end
end)
L:EndSection()

local skinListFrame
L = NewLayout(pages.Skin)
L:Section("ПОИСК")
local searchBox = AddTextbox(L:Row(26), "Поиск скина...", "", function(t) RenderSkinList(t) end)
AddButton(L:Row(26), "Обновить список", function() BuildSkinDatabase(); RenderSkinList(searchBox.Text) end)
AddToggle(L:Row(24), "SkinLock", SS.SkinLock, function(v) SS.SkinLock = v end)
AddButton(L:Row(26), "Сбросить скин", function() ApplySkin(nil, nil) end, Color3.fromRGB(72, 42, 42))
L:EndSection()
L:Section("СПИСОК")
do
    local row = L:Row(170)
    skinListFrame = new("ScrollingFrame", {
        Parent = row, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        BorderSizePixel = 0, CanvasSize = UDim2.new(),
        ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent,
    })
end
L:EndSection()
L:Section("ВРУЧНУЮ")
AddTextbox(L:Row(26), "MeshId", "", function(t) SS._mMesh = t; if t ~= "" then ApplySkin(t, SS._mTex) end end)
AddTextbox(L:Row(26), "TextureId", "", function(t) SS._mTex = t; if t ~= "" then ApplySkin(SS._mMesh, t) end end)
L:EndSection()

L = NewLayout(pages.Perf)
L:Section("ПРОИЗВОДИТЕЛЬНОСТЬ")
AddToggle(L:Row(24), "FPS Boost", SS.FPSBoost, function(v) SS.FPSBoost = v; ApplyFPSBoost(v) end)
AddToggle(L:Row(24), "Убрать эффекты", SS.NoEffects, function(v) SS.NoEffects = v; ApplyEffects(v) end)
AddToggle(L:Row(24), "Physics SendRate", SS.PhysicsRate, function(v)
    SS.PhysicsRate = v
    pcall(function()
        if settings and settings().Physics then
            settings().Physics.PhysicsSendRate = v and 60 or 20
        end
    end)
end)
AddSlider(L:Row(36), "FPS Cap", 30, 360, SS.FPSCap, 0, function(v)
    SS.FPSCap = v; pcall(function() if setfpscap then setfpscap(v) end end)
end)
L:EndSection()
L:Section("HUD")
AddToggle(L:Row(24), "FPS / Ping HUD", SS.Overlay, function(v)
    SS.Overlay = v
    if getgenv().SleepScriptOverlay then getgenv().SleepScriptOverlay.Enabled = v end
end)
L:EndSection()

selectTab("Start")

--=============================================================
--  МЕНЮ
--=============================================================
local pill = new("TextButton", {
    Parent = gui, Name = RandName(), Size = UDim2.fromOffset(46, 46),
    Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = C.bg, Text = S("S"), Font = Enum.Font.GothamBold,
    TextSize = 18, TextColor3 = C.accent, AutoButtonColor = false, Visible = false,
})
corner(pill, 23)
new("UIStroke", {Color = C.accent, Transparency = 0.35, Thickness = 1}, pill)
makeDraggable(pill)

local menuState, busy = "open", false

local function SetState(s)
    if busy or s == menuState then return end
    busy = true
    if s == "open" then
        main.Visible, shadow.Visible, pill.Visible = true, true, false
        main.Size = UDim2.fromOffset(46, 46)
        TweenService:Create(main, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            {Size = UDim2.fromOffset(WIN_W, WIN_H)}):Play()
        task.delay(0.3, function() busy = false end)
    else
        local t = TweenService:Create(main, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
            {Size = UDim2.fromOffset(46, 46)})
        t:Play(); t.Completed:Wait()
        main.Visible, shadow.Visible = false, false
        pill.Visible = (s == "minimized")
        busy = false
    end
    menuState = s; SS.MenuState = s
end

minBtn.MouseButton1Click:Connect(function() SetState("minimized") end)
closeBtn.MouseButton1Click:Connect(function() SetState("closed") end)
pill.MouseButton1Click:Connect(function() SetState("open") end)

track(UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.Z then
        SetState(menuState == "open" and "closed" or "open")
    elseif input.KeyCode == Enum.KeyCode.RightShift then
        SS.AutoParry = not SS.AutoParry
        if Sync["AutoParry"] then Sync["AutoParry"].Set(SS.AutoParry, false) end
    end
end))

if SS.MenuState ~= "open" then
    main.Size = UDim2.fromOffset(46, 46)
    main.Visible, shadow.Visible = false, false
    pill.Visible = (SS.MenuState == "minimized")
    menuState = SS.MenuState
end

--=============================================================
--  РЕАЛИЗАЦИЯ
--=============================================================
ApplySky = function(id)
    local old = Lighting:FindFirstChild("SleepSky")
    if old then old:Destroy() end
    local orig = Lighting:FindFirstChildOfClass("Sky")
    if orig then orig.Enabled = (id == nil) end
    if not id or id == "" then return end
    local sky = new("Sky", {Name = RandName(), Parent = Lighting})
    for _, p in pairs({"SkyboxBk","SkyboxDn","SkyboxFt","SkyboxLf","SkyboxRt","SkyboxUp"}) do
        sky[p] = id
    end
end

ApplyBody = function()
    local ch = LP.Character
    if not ch then return end
    local head = ch:FindFirstChild("Head")
    if head then
        head.Transparency = SS.Headless and 1 or 0
        for _, d in pairs(head:GetDescendants()) do
            if d:IsA("Decal") or d:IsA("Texture") then
                d.Transparency = SS.Headless and 1 or 0
            end
        end
    end
    if SS.Korblox then
        local leg = ch:FindFirstChild("Right Leg")
        if leg then
            local mesh = leg:FindFirstChildOfClass("SpecialMesh")
            if mesh then mesh.MeshId = SS.KorbloxMesh; mesh.TextureId = "" end
            local dec = leg:FindFirstChildOfClass("Decal")
            if dec then dec.Transparency = 1 end
        else
            for _, n in ipairs({"RightUpperLeg", "RightLowerLeg", "RightFoot"}) do
                local part = ch:FindFirstChild(n)
                if part and part:IsA("MeshPart") then
                    pcall(function() part.MeshId = SS.KorbloxMesh; part.TextureID = "" end)
                end
            end
        end
    end
end

local lightBackup = {}
ApplyFPSBoost = function(on)
    if on then
        lightBackup = {
            shadows = Lighting.GlobalShadows, fog = Lighting.FogEnd,
            diff = Lighting.EnvironmentDiffuseScale, spec = Lighting.EnvironmentSpecularScale,
        }
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
        Lighting.EnvironmentDiffuseScale = 0
        Lighting.EnvironmentSpecularScale = 0
        for _, v in pairs(Lighting:GetChildren()) do
            if v:IsA("PostEffect") then v.Enabled = false end
        end
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
    else
        if lightBackup.shadows ~= nil then
            Lighting.GlobalShadows = lightBackup.shadows
            Lighting.FogEnd = lightBackup.fog
            Lighting.EnvironmentDiffuseScale = lightBackup.diff
            Lighting.EnvironmentSpecularScale = lightBackup.spec
        end
        for _, v in pairs(Lighting:GetChildren()) do
            if v:IsA("PostEffect") then v.Enabled = true end
        end
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
    end
end

ApplyEffects = function(on)
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then
            v.Enabled = not on
        end
    end
end

local SkinDB = {}
local function ExtractSkin(inst)
    local mesh, tex
    for _, d in pairs(inst:GetDescendants()) do
        if not mesh and d:IsA("SpecialMesh") and d.MeshId ~= "" then mesh = d.MeshId end
        if not mesh and d:IsA("MeshPart") and d.MeshId ~= "" then mesh = d.MeshId end
        if not tex and d:IsA("Decal") and d.Texture ~= "" then tex = d.Texture end
        if not tex and d:IsA("Texture") and d.Texture ~= "" then tex = d.Texture end
        if mesh and tex then break end
    end
    if mesh or tex then
        local nm = inst.Name:gsub("^Sword_", ""):gsub("_Sword$", ""):gsub("_", " ")
        if nm == "" or nm == " " then nm = inst.Name end
        table.insert(SkinDB, {Name = nm, Mesh = mesh, Tex = tex})
    end
end
BuildSkinDatabase = function()
    SkinDB = {}
    local roots = {}
    local function push(c) if c then table.insert(roots, c) end end
    push(ReplicatedStorage:FindFirstChild("Swords"))
    push(ReplicatedStorage:FindFirstChild("SwordSkins"))
    push(ReplicatedStorage:FindFirstChild("Skins"))
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    if assets then push(assets:FindFirstChild("Swords")); push(assets:FindFirstChild("Skins")) end
    for _, root in ipairs(roots) do
        for _, ch in ipairs(root:GetChildren()) do pcall(ExtractSkin, ch) end
    end
    table.sort(SkinDB, function(a, b) return a.Name < b.Name end)
end
local function getSword()
    local ch = LP.Character
    if not ch then return nil end
    return ch:FindFirstChild("Sword") or ch:FindFirstChildOfClass("Tool")
end
ApplySkin = function(mesh, tex)
    local sword = getSword()
    if not sword then return end
    for _, d in pairs(sword:GetDescendants()) do
        if d:IsA("SpecialMesh") then
            if mesh then d.MeshId = mesh end
            if tex then d.TextureId = tex end
        elseif d:IsA("MeshPart") then
            if mesh then pcall(function() d.MeshId = mesh end) end
        elseif d:IsA("Decal") or d:IsA("Texture") then
            if tex then d.Texture = tex end
        end
    end
end
RenderSkinList = function(filter)
    if not skinListFrame then return end
    filter = filter or ""
    for _, v in ipairs(skinListFrame:GetChildren()) do
        if v:IsA("TextButton") then v:Destroy() end
    end
    local n = 0
    for _, skin in ipairs(SkinDB) do
        if filter == "" or skin.Name:lower():find(filter:lower(), 1, true) then
            n += 1
            local b = new("TextButton", {
                Parent = skinListFrame, Size = UDim2.new(1, -8, 0, 24),
                Position = UDim2.new(0, 0, 0, (n - 1) * 28),
                BackgroundColor3 = C.off, Text = S("   " .. skin.Name),
                Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.text,
                TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false,
            })
            corner(b, 6)
            b.MouseButton1Click:Connect(safe(function()
                SS._curMesh, SS._curTex = skin.Mesh, skin.Tex
                ApplySkin(skin.Mesh, skin.Tex)
            end))
        end
    end
    skinListFrame.CanvasSize = UDim2.new(0, 0, 0, n * 28 + 6)
end
BuildSkinDatabase()
RenderSkinList("")

--=============================================================
--  КОЛЬЦО ЧЕРЕЗ ADORNMENT (workspace не трогаем)
--=============================================================
local ring = new("CylinderHandleAdornment", {
    Name = RandName(), Parent = gui,
    Height = 0.05, Radius = 16, InnerRadius = 15.6,
    Color3 = C.accent, Transparency = 0.35, AlwaysOnTop = true, ZIndex = 5,
    CFrame = CFrame.Angles(math.rad(90), 0, 0) * CFrame.new(0, 0, 2.7),
    Visible = false,
})

--=============================================================
--  АВТОПАРРИ
--=============================================================
local LastClick, LastBallHit, IsParrying, frameCounter = 0, nil, false, 0
local clickTimes = {}
local BallsFolder = workspace:FindFirstChild("Balls") or workspace:WaitForChild("Balls", 5)

local NetworkStats = Stats:FindFirstChild("Network")
    and Stats.Network:FindFirstChild("ServerStatsItem")
    and Stats.Network.ServerStatsItem:FindFirstChild("Data Ping")

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

local function BallSpeed(ball)
    local z = ball:FindFirstChild("zoomies")
    if z and (z:IsA("LinearVelocity") or z:IsA("VectorForce")) then
        local ok, v = pcall(function() return z.VectorVelocity.Magnitude end)
        if ok and v then return v end
    end
    return ball.AssemblyLinearVelocity.Magnitude
end

local function IsTargeted(ball)
    if ball then
        local t = ball:GetAttribute("target")
        if t ~= nil then return t == LP.Name or t == LP.DisplayName end
    end
    if not LP.Character then return false end
    return LP.Character:GetAttribute("Targeted") == true
        or LP.Character:FindFirstChild("Highlight") ~= nil
end

local function CanClick()
    local now = tick()
    while #clickTimes > 0 and now - clickTimes[1] > 1 do table.remove(clickTimes, 1) end
    if SS.MaxCPS > 0 and #clickTimes >= SS.MaxCPS then return false end
    table.insert(clickTimes, now)
    return true
end

local function DoInput()
    local m = SS.InputMethod
    if m == "key" and keypress then
        pcall(function()
            keypress(0x46)
            task.delay(0.012, function() pcall(function() if keyrelease then keyrelease(0x46) end end) end)
        end)
    elseif m == "mouse" and mouse1click then
        pcall(function()
            if SS.ClickDownOnly and mouse1press then
                mouse1press()
                task.delay(0.012, function() if mouse1release then mouse1release() end end)
            else
                mouse1click()
            end
        end)
    else
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        if not SS.ClickDownOnly then
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        end
    end
end

local function SendClick(isClashing, ball)
    if not SS.AutoParry or IsParrying then return end
    local now = tick()
    local cd = (isClashing and SS.ClashSpeed or SS.NormalSpeed)
    if SS.ClickJitter > 0 then cd = cd + math.random() * SS.ClickJitter end
    if (now - LastClick) < cd then return end
    if not isClashing and SS.OneClickPerBall and LastBallHit == ball then return end
    if not CanClick() then return end

    IsParrying, LastClick, LastBallHit = true, now, ball
    DoInput()
    task.delay(cd, function() IsParrying = false end)
end

local function ParryStep()
    if not SS.AutoParry then
        if ring.Visible then ring.Visible = false end
        return
    end
    local Char = LP.Character
    local Root = Char and Char:FindFirstChild("HumanoidRootPart")
    if not Root then if ring.Visible then ring.Visible = false end return end

    local Ball = GetBall()
    if not Ball then if ring.Visible then ring.Visible = false end return end

    local BallPos, PlayerPos = Ball.Position, Root.Position
    local Speed = BallSpeed(Ball)
    local Distance = (PlayerPos - BallPos).Magnitude
    local vel = Ball.AssemblyLinearVelocity
    local dot = 1
    if vel.Magnitude > 0.01 then dot = (PlayerPos - BallPos).Unit:Dot(vel.Unit) end
    if dot < 0 then LastBallHit = nil end

    local Targeted = IsTargeted(Ball)
    local IsClashing = Targeted and Distance <= SS.ClashDistance

    frameCounter += 1
    if SS.ShowRadius then
        ring.Adornee = Root
        ring.Radius = 16 * (SS.RadiusScale or 1)
        ring.InnerRadius = math.max(0.1, ring.Radius - 0.4)
        ring.Visible = true
        if frameCounter % 3 == 0 then
            ring.Color3 = IsClashing and Color3.fromRGB(255, 70, 70)
                or (Targeted and Color3.fromRGB(0, 220, 255) or C.accent)
        end
    elseif ring.Visible then
        ring.Visible = false
    end

    if IsClashing then
        SendClick(true, Ball)
    elseif Targeted and dot > 0 then
        local Ping = (NetworkStats and NetworkStats.Value / 1000) or 0.04
        local TimeToHit = Distance / math.max(Speed, 1)
        local Threshold = SS.DistanceToParry + (SS.PingBased and Ping * SS.PingBasedOffset or 0)
        if Speed > 150 then Threshold *= 1.15 end
        if TimeToHit <= Threshold then
            SendClick(false, Ball)
        elseif SS.EmergencyClick and Distance <= SS.EmergencyRadius then
            SendClick(false, Ball)
        end
    end
end

track(RunService.PreSimulation:Connect(function() if SS.UsePreSim then ParryStep() end end))
track(RunService.PostSimulation:Connect(function() if not SS.UsePreSim then ParryStep() end end))

track(LP.CharacterAdded:Connect(function()
    LastBallHit, IsParrying = nil, false
    task.wait(1)
    ApplyBody()
    if SS._curMesh or SS._curTex then
        task.wait(0.5); ApplySkin(SS._curMesh, SS._curTex)
    end
end))

-- авто-возврат
task.spawn(function()
    local ok = pcall(function()
        local prompt = CoreGui:WaitForChild("RobloxPromptGui", 25)
        if not prompt then return end
        local overlay = prompt:WaitForChild("promptOverlay", 25)
        if not overlay then return end
        track(overlay:GetPropertyChangedSignal("Visible"):Connect(function()
            if overlay.Visible and SS.AutoRejoin then
                logKick("promptOverlay")
                task.wait(0.6)
                pcall(Rejoin)
            end
        end))
    end)
    if not ok then print("[SS] promptOverlay недоступен") end
end)

track(LP.AncestryChanged:Connect(function(_, parent)
    if not parent and SS.AutoRejoin then
        task.wait(0.4); pcall(Rejoin)
    end
end))

--=============================================================
--  HUD FPS / PING
--=============================================================
local ov = new("ScreenGui", {
    Name = RandName(), ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true, Enabled = SS.Overlay,
})
getgenv().SleepScriptOverlay = ov
if not ov.Parent then ov.Parent = SafeParent() end

local panel = new("Frame", {
    Parent = ov, Name = RandName(), Size = UDim2.fromOffset(170, 62),
    Position = UDim2.new(0, 20, 0, 90),
    BackgroundColor3 = C.bg, BackgroundTransparency = 0.15, BorderSizePixel = 0,
})
corner(panel, 10)
new("UIStroke", {Color = C.accent, Transparency = 0.5, Thickness = 1}, panel)
makeDraggable(panel)
local fpsLbl = new("TextLabel", {
    Parent = panel, Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(10, 10),
    BackgroundTransparency = 1, Font = Enum.Font.Code, Text = S("FPS  0"),
    TextSize = 15, TextColor3 = C.accent2, TextXAlignment = Enum.TextXAlignment.Left,
})
local pingLbl = new("TextLabel", {
    Parent = panel, Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(10, 32),
    BackgroundTransparency = 1, Font = Enum.Font.Code, Text = S("PING  0 ms"),
    TextSize = 15, TextColor3 = C.accent, TextXAlignment = Enum.TextXAlignment.Left,
})

local frames, lastClock = 0, os.clock()
track(RunService.RenderStepped:Connect(function()
    frames += 1
    if os.clock() - lastClock >= 0.5 then
        local fps = math.floor(frames / (os.clock() - lastClock) + 0.5)
        frames, lastClock = 0, os.clock()
        if ov.Enabled then
            fpsLbl.Text = S("FPS  " .. fps)
            fpsLbl.TextColor3 = fps >= 60 and C.accent2
                or (fps >= 30 and Color3.fromRGB(255, 200, 60) or C.bad)
            local ping = NetworkStats and math.floor(NetworkStats.Value) or 0
            pingLbl.Text = S("PING  " .. ping .. " ms")
            pingLbl.TextColor3 = ping < 80 and C.accent2
                or (ping < 150 and Color3.fromRGB(255, 200, 60) or C.bad)
        end
    end
end))

--=============================================================
--  ИНИЦИАЛИЗАЦИЯ
--=============================================================
task.spawn(function()
    if SS.CustomSky then ApplySky(SS.SkyId) end
    if SS.FPSBoost then ApplyFPSBoost(true) end
    if SS.NoEffects then ApplyEffects(true) end
    ApplyBody()
end)

task.spawn(function()
    while task.wait(1.5) do
        if SS.SkinLock and (SS._curMesh or SS._curTex) then
            pcall(ApplySkin, SS._curMesh, SS._curTex)
        end
    end
end)

print("[SS] v2.0 stealth загружено. GUI имя: " .. gui.Name .. " | активно: " .. Snapshot())
