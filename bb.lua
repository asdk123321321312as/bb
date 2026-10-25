--[[
=====================================================================
   SleepScript  |  Blade Ball  (v1.4 + BAC stealth)
   Z        — свернуть / развернуть (полное скрытие)
   Крестик  — полностью закрыть меню (вернуть: Z)
   RightShift — быстрый тумблер AutoParry
   Вёрстка на ручном позиционировании — не зависит от UIListLayout
=====================================================================
]]

local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local UserInputService    = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService        = game:GetService("TweenService")
local Lighting            = game:GetService("Lighting")
local Stats               = game:GetService("Stats")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local CoreGui             = game:GetService("CoreGui")
local HttpService         = game:GetService("HttpService")

local LP = Players.LocalPlayer
local function cam() return workspace.CurrentCamera end

--=============================================================
--  КОНФИГ
--=============================================================
local SS = getgenv().SleepScript or {}
getgenv().SleepScript = SS

local DEFAULTS = {
    MenuState = "open",
    AutoParry = false, PingBased = true, PingBasedOffset = 1.95,
    DistanceToParry = 0.65, EmergencyRadius = 10,
    ClashDistance = 22, ClashSpeed = 0.01, NormalSpeed = 0.05,
    ParryVisuals = true,
    FOV = 70, CustomSky = false, SkyId = "rbxassetid://159454299",
    Headless = false, Korblox = false, KorbloxMesh = "rbxassetid://139607718",
    Bypass = true, DestroySecurity = true,
    BypassHard = true, BypassBlockFire = true, BypassWatch = true,
    BypassNuke = false, BypassVerbose = false, BypassRetries = 6,
    BypassHide = true, Stealth = true, StealthDelay = 12, OnKick = "swallow",
    FPSBoost = false, NoEffects = false, NoAccessories = false, FPSCap = 240,
    Overlay = true, OverlayGraph = true,
    SkinLock = true,
}
for k, v in pairs(DEFAULTS) do if SS[k] == nil then SS[k] = v end end

--=============================================================
--  ПАЛИТРА / ХЕЛПЕРЫ
--=============================================================
local C = {
    bg      = Color3.fromRGB(11, 13, 20),
    bg2     = Color3.fromRGB(18, 21, 31),
    card    = Color3.fromRGB(23, 27, 39),
    accent  = Color3.fromRGB(124, 92, 255),
    accent2 = Color3.fromRGB(0, 229, 192),
    text    = Color3.fromRGB(236, 239, 250),
    dim     = Color3.fromRGB(132, 140, 162),
    off     = Color3.fromRGB(38, 43, 58),
    stroke  = Color3.fromRGB(48, 54, 74),
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
        if not ok then warn("[SleepScript] " .. tostring(err)) end
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

-- forward-декларации (чтобы колбэки видели их, а не nil)
local ApplySky, ApplyBody, ApplyFPSBoost, ApplyEffects, ApplyAccessories
local ApplyBypass, DestroySecurity, ApplySkin, RenderSkinList, BuildSkinDatabase

--=============================================================
--  [БАЙПАС] СОСТОЯНИЕ
--=============================================================
local Bypass = {
    active    = false,
    looping   = false,
    hooked    = false,
    old       = nil,
    blocked   = setmetatable({}, {__mode = "k"}),
    mine      = setmetatable({}, {__mode = "k"}),
    conns     = {},
    statusLbl = nil,
    kicks     = 0,
    killed    = 0,
    recreated = 0,
    spoofed   = 0,
    scripted  = 0,
    log       = {},
}

--=============================================================
--  КАРКАС ОКНА
--=============================================================
if getgenv().SleepScriptGui then getgenv().SleepScriptGui:Destroy() end
if getgenv().SleepScriptOverlay then getgenv().SleepScriptOverlay:Destroy() end

local GUI_NAMES = {"GamepadService", "HapticService", "VRService", "ContentProvider"}
local gui = new("ScreenGui", {
    Name = GUI_NAMES[math.random(#GUI_NAMES)] .. math.random(100, 999),
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true,
})
getgenv().SleepScriptGui = gui
pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
if not gui.Parent then gui.Parent = (gethui and gethui()) or CoreGui end

local WIN_W, WIN_H = 560, 360

local shadow = new("Frame", {
    Parent = gui, Name = "Shadow",
    Size = UDim2.fromOffset(WIN_W + 8, WIN_H + 8),
    Position = UDim2.fromScale(0.5, 0.5),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55,
    BorderSizePixel = 0,
})
corner(shadow, 18)

local main = new("Frame", {
    Parent = gui, Name = "Main",
    Size = UDim2.fromOffset(WIN_W, WIN_H),
    Position = UDim2.fromScale(0.5, 0.5),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = C.bg, BorderSizePixel = 0,
    ClipsDescendants = true, Active = true,
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
    Parent = main, Size = UDim2.new(1, 0, 0, 52),
    BackgroundTransparency = 1, Active = true,
})
makeDraggable(main, header)

new("TextLabel", {
    Parent = header, Size = UDim2.new(1, -140, 0, 18), Position = UDim2.fromOffset(18, 12),
    BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = "SleepScript",
    TextSize = 17, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
})
local subLbl = new("TextLabel", {
    Parent = header, Size = UDim2.new(1, -140, 0, 14), Position = UDim2.fromOffset(18, 30),
    BackgroundTransparency = 1, Font = Enum.Font.Gotham, Text = "Blade Ball  •  v1.4 + stealth",
    TextSize = 11, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
})
new("UIGradient", {Color = ColorSequence.new(C.accent, C.accent2)}, subLbl)

local minBtn = new("TextButton", {
    Parent = header, Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -76, 0, 12),
    BackgroundColor3 = C.off, Text = "—", Font = Enum.Font.GothamBold,
    TextSize = 15, TextColor3 = C.text, AutoButtonColor = false,
})
corner(minBtn, 8)

local closeBtn = new("TextButton", {
    Parent = header, Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -42, 0, 12),
    BackgroundColor3 = C.off, Text = "×", Font = Enum.Font.GothamBold,
    TextSize = 17, TextColor3 = C.text, AutoButtonColor = false,
})
corner(closeBtn, 8)

local sidebar = new("Frame", {
    Parent = main, Size = UDim2.new(0, 150, 1, -62), Position = UDim2.fromOffset(0, 62),
    BackgroundColor3 = C.bg, BackgroundTransparency = 0.35, BorderSizePixel = 0,
})

new("TextLabel", {
    Parent = sidebar, Size = UDim2.new(1, -20, 0, 14), Position = UDim2.new(0, 10, 1, -22),
    BackgroundTransparency = 1, Font = Enum.Font.Gotham, Text = "Z — свернуть меню",
    TextSize = 10, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
})

local contentHolder = new("Frame", {
    Parent = main, Size = UDim2.new(1, -160, 1, -74), Position = UDim2.fromOffset(155, 64),
    BackgroundTransparency = 1,
})

--=============================================================
--  ВКЛАДКИ (ручные позиции)
--=============================================================
local pages, tabs, currentTab = {}, {}, nil

local TABS = {
    { key = "AutoParry", label = "AutoParry" },
    { key = "Visuals",   label = "Visuals" },
    { key = "Skin",      label = "Скин меча" },
    { key = "Bypass",    label = "Bypass / FPS" },
    { key = "Overlay",   label = "Оверлей" },
}

local function CreatePage()
    return new("ScrollingFrame", {
        Parent = contentHolder, Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        CanvasSize = UDim2.new(), ScrollBarThickness = 3,
        ScrollBarImageColor3 = C.accent, Visible = false,
        AutomaticCanvasSize = Enum.AutomaticSize.None,
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
    currentTab = key
end

for i, t in ipairs(TABS) do
    local btn = new("TextButton", {
        Parent = sidebar, Size = UDim2.new(1, -20, 0, 30),
        Position = UDim2.fromOffset(10, 6 + (i - 1) * 36),
        BackgroundColor3 = C.off, BackgroundTransparency = 0.55,
        Text = "   " .. t.label, Font = Enum.Font.GothamMedium,
        TextSize = 13, TextColor3 = C.dim,
        TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false,
    })
    corner(btn, 8)
    btn.MouseButton1Click:Connect(function() selectTab(t.key) end)
    tabs[t.key] = btn
    pages[t.key] = CreatePage()
end

--=============================================================
--  РУЧНОЙ ЛЕЙАУТ СТРАНИЦЫ
--=============================================================
local function NewLayout(page)
    local L = { page = page, y = 8, sec = nil, secTop = 0, sy = 0 }

    function L:Section(title)
        local sec = new("Frame", {
            Parent = self.page, Size = UDim2.new(1, 0, 0, 40),
            Position = UDim2.new(0, 0, 0, self.y),
            BackgroundColor3 = C.card, BackgroundTransparency = 0.2, BorderSizePixel = 0,
        })
        corner(sec, 10)
        new("UIStroke", {Color = C.stroke, Transparency = 0.55, Thickness = 1}, sec)
        self.sec, self.secTop, self.sy = sec, self.y, 10
        if title then
            new("TextLabel", {
                Parent = sec, Size = UDim2.new(1, -20, 0, 16),
                Position = UDim2.fromOffset(10, 10), BackgroundTransparency = 1,
                Font = Enum.Font.GothamBold, Text = title, TextSize = 12,
                TextColor3 = C.accent2, TextXAlignment = Enum.TextXAlignment.Left,
            })
            self.sy = 32
        end
        return sec
    end

    function L:Row(h)
        local row = new("Frame", {
            Parent = self.sec, Size = UDim2.new(1, -20, 0, h),
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

--=============================================================
--  КОМПОНЕНТЫ
--=============================================================
local Sync = {}

local function AddToggle(row, name, default, callback)
    new("TextLabel", {
        Parent = row, Size = UDim2.new(1, -50, 1, 0), BackgroundTransparency = 1,
        Font = Enum.Font.Gotham, Text = name, TextSize = 12,
        TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
    })
    local btn = new("TextButton", {
        Parent = row, Size = UDim2.fromOffset(38, 20),
        Position = UDim2.new(1, -38, 0.5, -10),
        BackgroundColor3 = default and C.accent or C.off,
        Text = "", AutoButtonColor = false,
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
        Font = Enum.Font.Gotham, Text = name, TextSize = 12,
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
        Parent = row, Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = col or C.off, Text = name,
        Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = C.text,
        AutoButtonColor = false,
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
        Parent = row, Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = C.off, Text = default or "", PlaceholderText = placeholder,
        Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = C.text,
        PlaceholderColor3 = C.dim, ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    corner(box, 8)
    new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, box)
    box.FocusLost:Connect(function() if callback then safe(callback)(box.Text) end end)
    return box
end

local function AddHint(row, text, h)
    new("TextLabel", {
        Parent = row, Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
        Font = Enum.Font.Gotham, TextWrapped = true, TextSize = 11,
        TextColor3 = C.dim, Text = text, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
    })
end

--=============================================================
--  СТРАНИЦА: AUTOPARRY
--=============================================================
local L = NewLayout(pages.AutoParry)
L:Section("PARRY")
AddToggle(L:Row(24), "AutoParry", SS.AutoParry, function(v) SS.AutoParry = v end)
AddToggle(L:Row(24), "ParryVisuals", SS.ParryVisuals, function(v) SS.ParryVisuals = v end)
L:EndSection()

L:Section("ТАЙМИНГ")
AddToggle(L:Row(24), "PingBased", SS.PingBased, function(v) SS.PingBased = v end)
AddSlider(L:Row(36), "PingBasedOffset", 0, 5, SS.PingBasedOffset, 2, function(v) SS.PingBasedOffset = v end)
AddSlider(L:Row(36), "DistanceToParry", 0.05, 3, SS.DistanceToParry, 2, function(v) SS.DistanceToParry = v end)
AddSlider(L:Row(36), "EmergencyRadius", 1, 30, SS.EmergencyRadius, 0, function(v) SS.EmergencyRadius = v end)
L:EndSection()

L:Section("КЛАШ")
AddSlider(L:Row(36), "ClashDistance", 5, 60, SS.ClashDistance, 0, function(v) SS.ClashDistance = v end)
AddSlider(L:Row(36), "ClashSpeed", 0.01, 0.2, SS.ClashSpeed, 2, function(v) SS.ClashSpeed = v end)
AddSlider(L:Row(36), "NormalSpeed", 0.01, 0.3, SS.NormalSpeed, 2, function(v) SS.NormalSpeed = v end)
L:EndSection()

--=============================================================
--  СТРАНИЦА: VISUALS
--=============================================================
L = NewLayout(pages.Visuals)
L:Section("КАМЕРА")
AddSlider(L:Row(36), "Field of View", 40, 120, SS.FOV, 0, function(v)
    SS.FOV = v
    if cam() then cam().FieldOfView = v end
end)
L:EndSection()

L:Section("НЕБО")
AddToggle(L:Row(24), "CustomSky", SS.CustomSky, function(v)
    SS.CustomSky = v
    if v then ApplySky(SS.SkyId) else ApplySky(nil) end
end)
do
    local row = L:Row(26)
    local names = {"Sunset", "Night", "Cloudy", "Space"}
    local ids = {
        ["Sunset"] = "rbxassetid://159454299",
        ["Night"]  = "rbxassetid://57055771",
        ["Cloudy"] = "rbxassetid://271042910",
        ["Space"]  = "rbxassetid://133883647",
    }
    for i, nm in ipairs(names) do
        local b = new("TextButton", {
            Parent = row,
            Size = UDim2.new(0.25, -5, 1, 0),
            Position = UDim2.new((i - 1) * 0.25, 0, 0, 0),
            BackgroundColor3 = C.off, Text = nm, Font = Enum.Font.Gotham,
            TextSize = 11, TextColor3 = C.text, AutoButtonColor = false,
        })
        corner(b, 7)
        b.MouseButton1Click:Connect(safe(function()
            SS.SkyId = ids[nm]
            if SS.CustomSky then ApplySky(ids[nm]) end
        end))
    end
end
AddTextbox(L:Row(26), "Свой Sky ID", SS.SkyId, function(t)
    if t ~= "" then
        SS.SkyId = t
        if SS.CustomSky then ApplySky(t) end
    end
end)
L:EndSection()

L:Section("ТЕЛО")
AddToggle(L:Row(24), "Headless", SS.Headless, function(v) SS.Headless = v; ApplyBody() end)
AddToggle(L:Row(24), "Korblox", SS.Korblox, function(v) SS.Korblox = v; ApplyBody() end)
AddTextbox(L:Row(26), "Korblox Mesh ID", SS.KorbloxMesh, function(t)
    SS.KorbloxMesh = t
    if SS.Korblox then ApplyBody() end
end)
L:EndSection()

--=============================================================
--  СТРАНИЦА: СКИН
--=============================================================
local skinListFrame
L = NewLayout(pages.Skin)
L:Section("ПОИСК")
local searchBox = AddTextbox(L:Row(26), "Поиск скина...", "", function(t) RenderSkinList(t) end)
AddButton(L:Row(26), "Обновить список скинов", function()
    BuildSkinDatabase()
    RenderSkinList(searchBox.Text)
end)
AddToggle(L:Row(24), "SkinLock (не сбрасывать)", SS.SkinLock, function(v) SS.SkinLock = v end)
AddButton(L:Row(26), "Сбросить скин", function() ApplySkin(nil, nil) end, Color3.fromRGB(72, 42, 42))
L:EndSection()

L:Section("СПИСОК")
do
    local row = L:Row(200)
    skinListFrame = new("ScrollingFrame", {
        Parent = row, Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        CanvasSize = UDim2.new(), ScrollBarThickness = 3,
        ScrollBarImageColor3 = C.accent,
    })
end
L:EndSection()

L:Section("ВРУЧНУЮ")
AddTextbox(L:Row(26), "MeshId", "", function(t)
    SS._mMesh = t
    if t ~= "" then ApplySkin(t, SS._mTex) end
end)
AddTextbox(L:Row(26), "TextureId", "", function(t)
    SS._mTex = t
    if t ~= "" then ApplySkin(SS._mMesh, t) end
end)
L:EndSection()

--=============================================================
--  СТРАНИЦА: BYPASS / FPS
--=============================================================
L = NewLayout(pages.Bypass)

L:Section("АНТИЧИТ (BAC)")
AddToggle(L:Row(24), "Bypass", SS.Bypass, function(v) SS.Bypass = v; ApplyBypass(v) end)
AddToggle(L:Row(24), "Скрывать исполнителя", SS.BypassHide, function(v)
    SS.BypassHide = v
    if v then Bypass.HideExecutor() end
end)
AddToggle(L:Row(24), "Глушить Kick (жёстко)", SS.BypassHard, function(v) SS.BypassHard = v end)
AddToggle(L:Row(24), "Блокировать FireServer античита", SS.BypassBlockFire, function(v) SS.BypassBlockFire = v end)
AddToggle(L:Row(24), "Сторож пересоздания", SS.BypassWatch, function(v) SS.BypassWatch = v end)
AddToggle(L:Row(24), "Сносить папку Security", SS.BypassNuke, function(v) SS.BypassNuke = v end)
AddSlider(L:Row(36), "Попыток сноса", 1, 20, SS.BypassRetries, 0, function(v) SS.BypassRetries = v end)
AddButton(L:Row(26), "ПРИМЕНИТЬ БАЙПАС СЕЙЧАС", function() DestroySecurity() end, Color3.fromRGB(52, 40, 82))
do
    local row = L:Row(18)
    Bypass.statusLbl = new("TextLabel", {
        Parent = row, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Font = Enum.Font.Code, Text = "ожидание", TextSize = 11,
        TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
    })
end
do
    local row = L:Row(26)
    local modes = {{"swallow", "Глушить Kick"}, {"rejoin", "Автовозврат"}, {"pass", "Пропускать"}}
    for i, mm in ipairs(modes) do
        local b = new("TextButton", {
            Parent = row, Size = UDim2.new(1/3, -4, 1, 0),
            Position = UDim2.new((i - 1)/3, 0, 0, 0),
            BackgroundColor3 = (SS.OnKick == mm[1]) and C.accent or C.off,
            Text = mm[2], Font = Enum.Font.Gotham, TextSize = 11,
            TextColor3 = C.text, AutoButtonColor = false,
        })
        corner(b, 7)
        b.MouseButton1Click:Connect(function()
            SS.OnKick = mm[1]
            for _, c in ipairs(row:GetChildren()) do
                if c:IsA("TextButton") then
                    c.BackgroundColor3 = (c.Text == mm[2]) and C.accent or C.off
                end
            end
        end)
    end
end
AddToggle(L:Row(24), "Тихий старт", SS.Stealth, function(v) SS.Stealth = v end)
AddSlider(L:Row(36), "Задержка изменений, с", 0, 30, SS.StealthDelay, 0, function(v) SS.StealthDelay = v end)
AddToggle(L:Row(24), "Логировать в консоль", SS.BypassVerbose, function(v) SS.BypassVerbose = v end)
AddHint(L:Row(72),
    "Подменяет Security.RemoteEvent локальной приманкой, рвёт коннекты, глушит Kick " ..
    "и BAC-скрипты, спуфит identifyexecutor. Код 267 — серверный кик: если он всё " ..
    "равно приходит, ставь «Автовозврат» и поднимай задержку изменений.")
L:EndSection()

L:Section("ПРОИЗВОДИТЕЛЬНОСТЬ")
AddToggle(L:Row(24), "FPS Boost", SS.FPSBoost, function(v) SS.FPSBoost = v; ApplyFPSBoost(v) end)
AddToggle(L:Row(24), "Убрать эффекты", SS.NoEffects, function(v) SS.NoEffects = v; ApplyEffects(v) end)
AddToggle(L:Row(24), "Убрать аксессуары других", SS.NoAccessories, function(v)
    SS.NoAccessories = v
    ApplyAccessories(v)
end)
AddSlider(L:Row(36), "FPS Cap", 30, 360, SS.FPSCap, 0, function(v)
    SS.FPSCap = v
    pcall(function() if setfpscap then setfpscap(v) end end)
end)
L:EndSection()

--=============================================================
--  СТРАНИЦА: ОВЕРЛЕЙ
--=============================================================
L = NewLayout(pages.Overlay)
L:Section("ОТДЕЛЬНОЕ МЕНЮ")
AddToggle(L:Row(24), "Overlay (FPS / Ping)", SS.Overlay, function(v)
    SS.Overlay = v
    if getgenv().SleepScriptOverlay then getgenv().SleepScriptOverlay.Enabled = v end
end)
AddToggle(L:Row(24), "График", SS.OverlayGraph, function(v) SS.OverlayGraph = v end)
L:EndSection()

L:Section("КОНФИГ")
AddButton(L:Row(26), "Сохранить конфиг", function()
    local ok = pcall(function() writefile("SleepScript.json", HttpService:JSONEncode(SS)) end)
    print(ok and "[SleepScript] Конфиг сохранён" or "[SleepScript] writefile недоступен")
end)
AddButton(L:Row(26), "Загрузить конфиг", function()
    local ok, data = pcall(function() return readfile("SleepScript.json") end)
    if ok and data then
        local t = HttpService:JSONDecode(data)
        for k, v in pairs(t) do SS[k] = v end
        print("[SleepScript] Конфиг загружен")
    end
end)
L:EndSection()

selectTab("AutoParry")

--=============================================================
--  СОСТОЯНИЯ МЕНЮ
--=============================================================
local pill = new("TextButton", {
    Parent = gui, Name = "Pill", Size = UDim2.fromOffset(46, 46),
    Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = C.bg, Text = "S", Font = Enum.Font.GothamBold,
    TextSize = 18, TextColor3 = C.accent, AutoButtonColor = false, Visible = false,
})
corner(pill, 23)
new("UIStroke", {Color = C.accent, Transparency = 0.35, Thickness = 1}, pill)
makeDraggable(pill)

local menuState = "open"
local busy = false

local function SetState(s)
    if busy or s == menuState then return end
    busy = true
    if s == "open" then
        main.Visible = true
        shadow.Visible = true
        pill.Visible = false
        main.Size = UDim2.fromOffset(46, 46)
        local t = TweenService:Create(main, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            {Size = UDim2.fromOffset(WIN_W, WIN_H)})
        t:Play()
        task.delay(0.3, function() busy = false end)
    elseif s == "closed" or s == "minimized" then
        local t = TweenService:Create(main, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
            {Size = UDim2.fromOffset(46, 46)})
        t:Play()
        t.Completed:Wait()
        main.Visible = false
        shadow.Visible = false
        pill.Visible = (s == "minimized")
        busy = false
    end
    menuState = s
    SS.MenuState = s
end

local function ToggleMenu()
    if menuState == "open" then SetState("closed") else SetState("open") end
end

minBtn.MouseButton1Click:Connect(function() SetState("minimized") end)
closeBtn.MouseButton1Click:Connect(function() SetState("closed") end)
pill.MouseButton1Click:Connect(function() SetState("open") end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.Z then
        ToggleMenu()
    elseif input.KeyCode == Enum.KeyCode.RightShift then
        SS.AutoParry = not SS.AutoParry
        if Sync["AutoParry"] then Sync["AutoParry"].Set(SS.AutoParry, false) end
    end
end)

if SS.MenuState == "closed" or SS.MenuState == "minimized" then
    main.Size = UDim2.fromOffset(46, 46)
    main.Visible = false
    shadow.Visible = false
    pill.Visible = (SS.MenuState == "minimized")
    menuState = SS.MenuState
end

--=============================================================
--  РЕАЛИЗАЦИЯ: НЕБО / ТЕЛО / ПЕРФ
--=============================================================
ApplySky = function(id)
    local old = Lighting:FindFirstChild("SleepSky")
    if old then old:Destroy() end
    local orig = Lighting:FindFirstChildOfClass("Sky")
    if orig then orig.Enabled = (id == nil) end
    if not id or id == "" then return end
    local sky = new("Sky", {Name = "SleepSky", Parent = Lighting})
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
                    pcall(function()
                        part.MeshId = SS.KorbloxMesh
                        part.TextureID = ""
                    end)
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
        pcall(function() if setfpscap then setfpscap(SS.FPSCap) end end)
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

ApplyAccessories = function(on)
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            for _, v in pairs(plr.Character:GetChildren()) do
                if v:IsA("Accessory") or v:IsA("Hat") then
                    for _, d in pairs(v:GetDescendants()) do
                        if d:IsA("BasePart") or d:IsA("Decal") then
                            d.Transparency = on and 1 or 0
                        end
                    end
                end
            end
        end
    end
end

--=============================================================
--  [БАЙПАС] ЯДРО
--  Заменяет разовый снос:
--    ReplicatedStorage.Security.RemoteEvent:Destroy()
--    ReplicatedStorage.Security[""]:Destroy()
--    ReplicatedStorage.Security:Destroy()
--    LP.PlayerScripts.Client.DeviceChecker:Destroy()
--  Destroy() не рвёт коннекты, поэтому канал не умирает от простого
--  сноса. Здесь реальный RemoteEvent подменяется локальной приманкой:
--  сервер держит ссылку на свой экземпляр и FireClient уходит в пустоту.
--  Плюс слой сокрытия — спуф исполнителя и выпил BAC-скриптов.
--=============================================================
Bypass.Log = function(t)
    if SS.BypassVerbose then print("[SleepScript][BAC] " .. tostring(t)) end
end

Bypass.Status = function(text, col)
    if not Bypass.statusLbl then return end
    Bypass.statusLbl.Text = text
    Bypass.statusLbl.TextColor3 = col or C.dim
end

Bypass.RefreshStatus = function()
    local hookTxt = Bypass.hooked and "хук:да" or "хук:нет"
    local spoofTxt = Bypass.spoofed > 0 and "спуф:да" or "спуф:нет"
    local col = (Bypass.hooked and Bypass.spoofed > 0) and C.accent2
        or Color3.fromRGB(255, 200, 60)
    Bypass.Status(("%s %s • kick %d • скриптов %d • снос %d")
        :format(hookTxt, spoofTxt, Bypass.kicks, Bypass.scripted, Bypass.killed), col)
end

local function waitFor(getter, timeout)
    local t0 = os.clock()
    while os.clock() - t0 < (timeout or 6) do
        local v = getter()
        if v then return v end
        task.wait(0.08)
    end
    return getter()
end

local function isOurDummy(inst)
    return inst and Bypass.mine[inst] == true
end

local function getGlobal(name)
    local ok, v = pcall(function() return getfenv(0)[name] end)
    if ok and v ~= nil then return v end
    return _G[name]
end

-- разрыв всех клиентских подписок на объект
Bypass.SeverConnections = function(remote)
    Bypass.blocked[remote] = true
    if not getconnections then return end
    local ok, list = pcall(getconnections, remote.OnClientEvent)
    if not ok or type(list) ~= "table" then return end
    for _, c in ipairs(list) do
        pcall(function() c:Disconnect() end)
    end
end

-- снос/нейтрализация содержимого Security + установка приманки
Bypass.Poison = function()
    if not SS.Bypass then return end
    local sec = ReplicatedStorage:FindFirstChild("Security")

    if not sec then
        sec = new("Folder", {Name = "Security", Parent = ReplicatedStorage})
        Bypass.mine[sec] = true
        Bypass.recreated += 1
    elseif not isOurDummy(sec) then
        Bypass.recreated += 1
    end

    -- 1) глушим исполняемое внутри, чтобы не успело дёрнуться
    for _, d in ipairs(sec:GetDescendants()) do
        if d:IsA("LuaSourceContainer") then
            pcall(function() d.Disabled = true end)
        end
    end

    -- 2) чужие remote-объекты: рвём коннекты и сносим
    for _, d in ipairs(sec:GetChildren()) do
        if isOurDummy(d) then continue end
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
            Bypass.SeverConnections(d)
            pcall(function() d:Destroy() end)
            Bypass.killed += 1
        elseif d.Name == "" then
            pcall(function() d:Destroy() end)
            Bypass.killed += 1
        end
    end

    -- 3) держим приманку с именем RemoteEvent
    local hasDummy = false
    for _, d in ipairs(sec:GetChildren()) do
        if isOurDummy(d) and d.Name == "RemoteEvent" then hasDummy = true break end
    end
    if not hasDummy then
        local dummy = new("RemoteEvent", {Name = "RemoteEvent", Parent = sec})
        Bypass.mine[dummy] = true
        dummy.OnClientEvent:Connect(function() end)
    end

    -- 4) опционально сносим саму папку (жёсткий режим оригинала)
    if SS.BypassNuke then
        for _, d in ipairs(sec:GetChildren()) do
            if not isOurDummy(d) then pcall(function() d:Destroy() end) end
        end
    end
end

-- DeviceChecker: Disabled до Destroy, поиск по всему PlayerScripts
Bypass.KillDeviceChecker = function(attempts)
    attempts = math.max(1, attempts or 1)
    local ps = LP:FindFirstChild("PlayerScripts")
    if not ps then return 0 end
    local found = 0

    for i = 1, attempts do
        local targets = {}
        local client = ps:FindFirstChild("Client")
        local dc = client and client:FindFirstChild("DeviceChecker")
        if dc then table.insert(targets, dc) end
        if #targets == 0 then
            for _, v in ipairs(ps:GetDescendants()) do
                if v.Name:lower():find("devicechecker", 1, true) then
                    table.insert(targets, v)
                end
            end
        end
        for _, t in ipairs(targets) do
            if t:IsA("LuaSourceContainer") then
                pcall(function() t.Disabled = true end)
            end
            pcall(function() t:Destroy() end)
            found += 1
        end
        if found > 0 then break end
        task.wait(0.3)
    end
    return found
end

-- маска BAC-скриптов; "bac" проверяется отдельно, чтобы не ловить Feedback
local function matchesBac(nm)
    if nm == "bac" or nm:match("^bac[_%-]") or nm:match("[_%-]bac$") then return true end
    for _, p in ipairs({"security", "anticheat", "anti_cheat", "anti cheat", "devicechecker", "exploit"}) do
        if nm:find(p, 1, true) then return true end
    end
    return false
end

Bypass.KillBacScripts = function()
    local ps = LP:FindFirstChild("PlayerScripts")
    if not ps then return 0 end
    local n = 0
    for _, v in ipairs(ps:GetDescendants()) do
        if not (v:IsA("LocalScript") or v:IsA("Script") or v:IsA("ModuleScript")) then continue end
        if matchesBac(v.Name:lower()) then
            pcall(function() v.Disabled = true end)
            pcall(function() v:Destroy() end)
            n += 1
        end
    end
    return n
end

-- сокрытие исполнителя от DeviceChecker
Bypass.HideExecutor = function()
    if not SS.BypassHide then return end
    if not hookfunction then
        Bypass.Log("hookfunction недоступен — спуф не встал")
        Bypass.RefreshStatus()
        return
    end

    local done = 0
    local function cloak(name, fake)
        local fn = getGlobal(name)
        if not fn then return end
        if pcall(hookfunction, fn, fake) then done += 1 end
    end

    cloak("identifyexecutor", function() return "Roblox", "1.0.0" end)
    cloak("getexecutorname",  function() return "Roblox" end)
    cloak("getexploit",       function() return "Roblox" end)

    Bypass.spoofed = done
    Bypass.Log("спуф исполнителя: " .. done .. " функций")
    Bypass.RefreshStatus()
end

Bypass.Rejoin = function()
    local ts = game:GetService("TeleportService")
    local ok = pcall(function() ts:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end)
    if not ok then pcall(function() ts:Teleport(game.PlaceId) end) end
end

-- хук метатаблицы: Kick глушится, FireServer в канал античита режется
Bypass.Hook = function()
    if Bypass.hooked then return true end
    if not getnamecallmethod then return false end

    local function handler(self, ...)
        local method = getnamecallmethod()
        if SS.Bypass then
            if method == "Kick" and (self == LP or self == Players) then
                Bypass.kicks += 1
                local msg = tostring((...))
                table.insert(Bypass.log, ("%s  %s"):format(os.date("%H:%M:%S"), msg))
                if #Bypass.log > 4 then table.remove(Bypass.log, 1) end
                print("[SleepScript][BAC] Kick перехвачен: " .. msg)
                Bypass.RefreshStatus()
                if SS.OnKick == "rejoin" then
                    task.spawn(Bypass.Rejoin)
                end
                if SS.OnKick ~= "pass" then return end
            elseif (method == "FireServer" or method == "InvokeServer") and SS.BypassBlockFire then
                local parent = self.Parent
                if Bypass.blocked[self]
                or (parent and (parent.Name == "Security"
                    or (parent.Parent and parent.Parent.Name == "Security"))) then
                    return
                end
            end
        end
        return Bypass.old(self, ...)
    end

    local ok = pcall(function()
        if getrawmetatable and setreadonly and newcclosure then
            local mt = getrawmetatable(game)
            Bypass.old = mt.__namecall
            setreadonly(mt, false)
            mt.__namecall = newcclosure(handler)
            setreadonly(mt, true)
        elseif hookmetamethod then
            Bypass.old = hookmetamethod(game, "__namecall", handler)
        else
            error("нет доступа к метатаблице")
        end
    end)

    if ok and Bypass.old then
        Bypass.hooked = true
        Bypass.Log("хук __namecall установлен")
        Bypass.RefreshStatus()
        return true
    end

    Bypass.old = nil
    Bypass.Log("хук не установлен")
    Bypass.RefreshStatus()
    return false
end

Bypass.Unhook = function()
    if not Bypass.hooked or not Bypass.old then return end
    pcall(function()
        if getrawmetatable and setreadonly then
            local mt = getrawmetatable(game)
            setreadonly(mt, false)
            mt.__namecall = Bypass.old
            setreadonly(mt, true)
        end
    end)
    Bypass.hooked = false
    Bypass.old = nil
end

Bypass.DisconnectWatch = function()
    for _, c in ipairs(Bypass.conns) do pcall(function() c:Disconnect() end) end
    table.clear(Bypass.conns)
end

Bypass.Watch = function()
    local function add(conn)
        if conn then table.insert(Bypass.conns, conn) end
    end

    add(ReplicatedStorage.ChildAdded:Connect(function(inst)
        if inst.Name == "Security" and SS.Bypass then
            task.delay(0.1, function() Bypass.Poison() end)
        end
    end))

    local sec = ReplicatedStorage:FindFirstChild("Security")
    if sec then
        add(sec.ChildAdded:Connect(function()
            if SS.Bypass then task.delay(0.05, function() Bypass.Poison() end) end
        end))
    end

    local ps = LP:FindFirstChild("PlayerScripts")
    local client = ps and ps:FindFirstChild("Client")
    if client then
        add(client.ChildAdded:Connect(function(inst)
            if matchesBac(inst.Name:lower()) and SS.Bypass then
                task.delay(0.05, function()
                    pcall(function() inst.Disabled = true end)
                    pcall(function() inst:Destroy() end)
                end)
            end
        end))
    end
end

-- сторож: постоянное поддержание канала в мёртвом состоянии
Bypass.Loop = function()
    if Bypass.looping then return end
    Bypass.looping = true
    task.spawn(function()
        local tick = 0
        while Bypass.active and SS.Bypass do
            tick += 1
            pcall(function()
                if SS.BypassWatch then Bypass.Poison() end
                Bypass.KillDeviceChecker(1)
                if tick % 4 == 0 then
                    local n = Bypass.KillBacScripts()
                    if n > 0 then Bypass.scripted += n end
                end
                if not Bypass.hooked then Bypass.Hook() end
            end)
            task.wait(0.25)
        end
        Bypass.looping = false
    end)
end

Bypass.Start = function()
    if Bypass.active then return end
    Bypass.active = true
    Bypass.Hook()
    Bypass.HideExecutor()
    local scripts = Bypass.KillBacScripts()
    Bypass.scripted += scripts
    Bypass.Log("BAC-скриптов выпилено: " .. scripts)
    Bypass.Status("инициализация...", C.accent2)

    task.spawn(function()
        waitFor(function() return ReplicatedStorage:FindFirstChild("Security") end, 8)
        for i = 1, math.max(1, SS.BypassRetries) do
            Bypass.Poison()
            if Bypass.KillDeviceChecker(1) > 0 then break end
            task.wait(0.2)
        end
        Bypass.Log(("приманка %d, снос %d, kick %d")
            :format(Bypass.recreated, Bypass.killed, Bypass.kicks))
        Bypass.RefreshStatus()
        if SS.BypassWatch then Bypass.Watch() end
        Bypass.Loop()
    end)
end

Bypass.Stop = function()
    Bypass.active = false
    Bypass.DisconnectWatch()
    Bypass.Unhook()
    Bypass.Status("выключен", C.dim)
    Bypass.Log("байпас снят")
end

DestroySecurity = function()
    Bypass.Poison()
    Bypass.KillDeviceChecker(SS.BypassRetries)
    Bypass.scripted += Bypass.KillBacScripts()
    Bypass.RefreshStatus()
    Bypass.Log("ручной снос")
end

ApplyBypass = function(on)
    if on then Bypass.Start() else Bypass.Stop() end
end

--=============================================================
--  РЕАЛИЗАЦИЯ: СКИНЫ
--=============================================================
local SkinDB = {}

local function ExtractSkin(inst)
    local mesh, tex
    for _, d in pairs(inst:GetDescendants()) do
        if not mesh and d:IsA("SpecialMesh") and d.MeshId ~= "" then mesh = d.MeshId end
        if not mesh and d:IsA("MeshPart") and d.MeshId ~= "" then mesh = d.MeshId end
        if not tex and d:IsA("Decal") and d.Texture ~= "" then tex = d.Texture end
        if not tex and d:IsA("Texture") and d.Texture ~= "" then tex = d.Texture end
        if not tex and d:IsA("SpecialMesh") and d.TextureId ~= "" then tex = d.TextureId end
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
    if assets then
        push(assets:FindFirstChild("Swords"))
        push(assets:FindFirstChild("Skins"))
        push(assets:FindFirstChild("SwordSkins"))
    end
    for _, root in ipairs(roots) do
        for _, ch in ipairs(root:GetChildren()) do
            pcall(ExtractSkin, ch)
        end
    end
    table.sort(SkinDB, function(a, b) return a.Name < b.Name end)
    print("[SleepScript] Найдено скинов: " .. #SkinDB)
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
                Parent = skinListFrame,
                Size = UDim2.new(1, -8, 0, 24),
                Position = UDim2.new(0, 0, 0, (n - 1) * 28),
                BackgroundColor3 = C.off, Text = "   " .. skin.Name,
                Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.text,
                TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false,
            })
            corner(b, 6)
            b.MouseButton1Click:Connect(safe(function()
                SS._curMesh, SS._curTex = skin.Mesh, skin.Tex
                ApplySkin(skin.Mesh, skin.Tex)
                TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = C.accent}):Play()
                task.delay(0.35, function()
                    TweenService:Create(b, TweenInfo.new(0.3), {BackgroundColor3 = C.off}):Play()
                end)
            end))
        end
    end
    skinListFrame.CanvasSize = UDim2.new(0, 0, 0, n * 28 + 6)
end

BuildSkinDatabase()
RenderSkinList("")

--=============================================================
--  АВТОПАРРИ
--=============================================================
local LastClick, LastBallHit, IsParrying, frameCounter = 0, nil, false, 0
local BallsFolder = workspace:FindFirstChild("Balls") or workspace:WaitForChild("Balls", 5)

local NetworkStats = Stats:FindFirstChild("Network")
    and Stats.Network:FindFirstChild("ServerStatsItem")
    and Stats.Network.ServerStatsItem:FindFirstChild("Data Ping")

local r, m
if SS.ParryVisuals then
    r = new("Part", {Name = "FX", Parent = cam() or workspace,
        Anchored = true, CanCollide = false, Transparency = 1,
        Material = Enum.Material.Neon, Size = Vector3.new(1, 1, 1)})
    m = new("SpecialMesh", {MeshId = "rbxassetid://3270017"}, r)
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
    if not LP.Character then return false end
    return LP.Character:GetAttribute("Targeted") == true
        or LP.Character:FindFirstChild("Highlight") ~= nil
end

local function SendClick(isClashing, ball)
    if not SS.AutoParry or IsParrying then return end
    local now = tick()
    local cd = isClashing and SS.ClashSpeed or SS.NormalSpeed
    if not isClashing and LastBallHit == ball and (now - LastClick) < 0.5 then return end
    if (now - LastClick) < cd then return end
    IsParrying, LastClick, LastBallHit = true, now, ball
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    task.delay(cd, function() IsParrying = false end)
end

local function UpdateVisuals(root, distance, state)
    if not SS.ParryVisuals or not r then return end
    r.CFrame = root.CFrame * CFrame.new(0, -2.6, 0) * CFrame.Angles(math.rad(90), 0, 0)
    local targetSize = math.clamp(distance * 0.8, 5, 65)
    m.Scale = m.Scale:Lerp(Vector3.new(targetSize, targetSize, 0.5), 0.5)
    if state == "clash" then
        r.Color, r.Transparency = Color3.fromRGB(255, 0, 0), 0.05
    elseif state == "target" then
        r.Color, r.Transparency = Color3.fromRGB(0, 255, 255), 0.1
    else
        r.Color, r.Transparency = Color3.fromRGB(150, 240, 255), 0.5
    end
end

RunService.PostSimulation:Connect(function()
    if not SS.AutoParry then
        if r then r.Transparency = 1 end
        return
    end
    local Char = LP.Character
    local Root = Char and Char:FindFirstChild("HumanoidRootPart")
    if not Root then if r then r.Transparency = 1 end return end

    local Ball = GetBall()
    if not Ball then if r then r.Transparency = 1 end return end

    local BallPos, PlayerPos = Ball.Position, Root.Position
    local Velocity = Ball.AssemblyLinearVelocity
    local Speed = Velocity.Magnitude
    local Distance = (PlayerPos - BallPos).Magnitude
    local dot = (PlayerPos - BallPos).Unit:Dot(Velocity.Unit)

    if dot < 0 then LastBallHit = nil end

    local Targeted = IsTargeted()
    local IsClashing = Targeted and Distance <= SS.ClashDistance

    frameCounter += 1
    if r and frameCounter % 2 == 0 then
        r.Transparency = 0.3
        UpdateVisuals(Root, Distance, IsClashing and "clash" or (Targeted and "target" or "neutral"))
    end

    if IsClashing then
        SendClick(true, Ball)
    elseif Targeted and dot > 0 then
        local Ping = (NetworkStats and NetworkStats.Value / 1000) or 0.04
        local TimeToHit = Distance / math.max(Speed, 1)
        local Threshold = SS.DistanceToParry + (SS.PingBased and Ping * SS.PingBasedOffset or 0)
        if Speed > 150 then Threshold *= 1.15 end
        if TimeToHit <= Threshold or Distance <= SS.EmergencyRadius then
            SendClick(false, Ball)
        end
    end
end)

LP.CharacterAdded:Connect(function()
    LastBallHit, IsParrying = nil, false
    task.wait(1)
    ApplyBody()
    if SS._curMesh or SS._curTex then
        task.wait(0.5)
        ApplySkin(SS._curMesh, SS._curTex)
    end
    if SS.Bypass then
        task.wait(0.4)
        pcall(Bypass.Poison)
        pcall(Bypass.KillDeviceChecker, SS.BypassRetries)
    end
end)

--=============================================================
--  ОВЕРЛЕЙ FPS / PING
--=============================================================
local ov = new("ScreenGui", {
    Name = "SleepScriptOverlay", ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true,
    Enabled = SS.Overlay,
})
getgenv().SleepScriptOverlay = ov
pcall(function() if syn and syn.protect_gui then syn.protect_gui(ov) end end)
if not ov.Parent then ov.Parent = (gethui and gethui()) or CoreGui end

local panel = new("Frame", {
    Parent = ov, Size = UDim2.fromOffset(170, 74), Position = UDim2.new(0, 20, 0, 90),
    BackgroundColor3 = C.bg, BackgroundTransparency = 0.15, BorderSizePixel = 0,
})
corner(panel, 10)
new("UIStroke", {Color = C.accent, Transparency = 0.5, Thickness = 1}, panel)
new("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10),
    PaddingRight = UDim.new(0, 10)}, panel)
makeDraggable(panel)

new("TextLabel", {
    Parent = panel, Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold, Text = "SleepScript", TextSize = 11,
    TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
})
local fpsLbl = new("TextLabel", {
    Parent = panel, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 16),
    BackgroundTransparency = 1, Font = Enum.Font.Code, Text = "FPS  0",
    TextSize = 15, TextColor3 = C.accent2, TextXAlignment = Enum.TextXAlignment.Left,
})
local pingLbl = new("TextLabel", {
    Parent = panel, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 36),
    BackgroundTransparency = 1, Font = Enum.Font.Code, Text = "PING  0 ms",
    TextSize = 15, TextColor3 = C.accent, TextXAlignment = Enum.TextXAlignment.Left,
})
local graph = new("Frame", {
    Parent = panel, Size = UDim2.new(1, 0, 0, 8), Position = UDim2.new(0, 0, 1, -10),
    BackgroundColor3 = C.off, BorderSizePixel = 0, ClipsDescendants = true,
})
corner(graph, 4)

local frames, lastClock, hist = 0, os.clock(), {}
RunService.RenderStepped:Connect(function()
    frames += 1
    if os.clock() - lastClock >= 0.5 then
        local fps = math.floor(frames / (os.clock() - lastClock) + 0.5)
        frames, lastClock = 0, os.clock()
        if ov.Enabled then
            fpsLbl.Text = "FPS  " .. fps
            fpsLbl.TextColor3 = fps >= 60 and C.accent2
                or (fps >= 30 and Color3.fromRGB(255, 200, 60) or Color3.fromRGB(255, 90, 90))
            local ping = NetworkStats and math.floor(NetworkStats.Value) or 0
            pingLbl.Text = "PING  " .. ping .. " ms"
            pingLbl.TextColor3 = ping < 80 and C.accent2
                or (ping < 150 and Color3.fromRGB(255, 200, 60) or Color3.fromRGB(255, 90, 90))

            table.insert(hist, fps)
            if #hist > 24 then table.remove(hist, 1) end
            for _, v in ipairs(graph:GetChildren()) do
                if v:IsA("Frame") then v:Destroy() end
            end
            if SS.OverlayGraph then
                for i, v in ipairs(hist) do
                    new("Frame", {
                        Parent = graph,
                        Size = UDim2.new(1 / 24, -1, math.clamp(v / 240, 0.05, 1), 0),
                        Position = UDim2.new((i - 1) / 24, 0, 1, 0),
                        AnchorPoint = Vector2.new(0, 1),
                        BackgroundColor3 = C.accent2, BorderSizePixel = 0,
                    })
                end
            end
        end
    end
end)

--=============================================================
--  ИНИЦИАЛИЗАЦИЯ
--=============================================================
task.spawn(function()
    if SS.Bypass then ApplyBypass(true) end

    -- тихий период: BAC снимает слепок профиля на входе,
    -- поэтому FOV/небо/тело/кап трогаем только после задержки
    if SS.Stealth then task.wait(SS.StealthDelay) end

    if cam() then cam().FieldOfView = SS.FOV end
    if SS.CustomSky then ApplySky(SS.SkyId) end
    if SS.FPSBoost then ApplyFPSBoost(true) end
    if SS.NoEffects then ApplyEffects(true) end
    if SS.NoAccessories then ApplyAccessories(true) end
end)

task.spawn(function()
    while task.wait(1.5) do
        if SS.SkinLock and (SS._curMesh or SS._curTex) then
            pcall(ApplySkin, SS._curMesh, SS._curTex)
        end
    end
end)

print("[SleepScript] Загружено. Z — меню, RightShift — AutoParry")
