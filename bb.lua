--[[
=====================================================================
   SleepScript  |  Blade Ball
   Меню: Z — свернуть / развернуть окно
   Автопарри: RightShift (быстрый тумблер)
   Работает на Real и любом executor'е с API: getgenv, gethui, protect_gui
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

local LP  = Players.LocalPlayer
local function cam() return workspace.CurrentCamera end

--=============================================================
--  КОНФИГ
--=============================================================
local SS = getgenv().SleepScript or {}
getgenv().SleepScript = SS

local DEFAULTS = {
    MenuOpen = true,
    -- AutoParry
    AutoParry = false, PingBased = true, PingBasedOffset = 1.95,
    DistanceToParry = 0.65, EmergencyRadius = 10,
    ClashDistance = 22, ClashSpeed = 0.01, NormalSpeed = 0.05,
    ParryVisuals = true,
    -- Visuals
    FOV = 70, CustomSky = false, SkyId = "rbxassetid://159454299",
    Headless = false, Korblox = false, KorbloxMesh = "rbxassetid://139607718",
    -- Perf
    Bypass = true, FPSBoost = false, NoEffects = false, NoAccessories = false, FPSCap = 240,
    -- Overlay
    Overlay = true,
    -- Skin
    SkinLock = true,
}
for k, v in pairs(DEFAULTS) do if SS[k] == nil then SS[k] = v end end

--=============================================================
--  ЦВЕТА / ХЕЛПЕРЫ
--=============================================================
local C = {
    bg      = Color3.fromRGB(11, 13, 20),
    bg2     = Color3.fromRGB(18, 21, 31),
    card    = Color3.fromRGB(22, 26, 38),
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

--=============================================================
--  СОЗДАНИЕ GUI
--=============================================================
if getgenv().SleepScriptGui then getgenv().SleepScriptGui:Destroy() end
if getgenv().SleepScriptOverlay then getgenv().SleepScriptOverlay:Destroy() end

local gui = new("ScreenGui", {
    Name = "SleepScript", ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true,
})
getgenv().SleepScriptGui = gui

pcall(function()
    if syn and syn.protect_gui then syn.protect_gui(gui) end
end)
if not gui.Parent then
    gui.Parent = (gethui and gethui()) or CoreGui
end

-- тень
local shadow = new("Frame", {
    Parent = gui, Size = UDim2.fromOffset(560, 360),
    Position = UDim2.new(0.5, -280, 0.5, -180),
    BackgroundColor3 = Color3.new(0,0,0), BackgroundTransparency = 0.55,
    BorderSizePixel = 0,
})
corner(shadow, 16)

local main = new("Frame", {
    Parent = gui, Name = "Main",
    Size = UDim2.fromOffset(560, 360),
    Position = UDim2.new(0.5, -280, 0.5, -180),
    BackgroundColor3 = C.bg, BorderSizePixel = 0,
    ClipsDescendants = true, Active = true,
})
corner(main, 14)
new("UIGradient", {Rotation = 20, Color = ColorSequence.new(C.bg, C.bg2)}, main)
new("UIStroke", {Color = C.stroke, Thickness = 1, Transparency = 0.3}, main)
makeDraggable(main)

-- хедер
local header = new("Frame", {
    Parent = main, Size = UDim2.new(1, 0, 0, 52),
    BackgroundTransparency = 1, Active = true,
})
makeDraggable(main, header)

new("TextLabel", {
    Parent = header, Size = UDim2.new(1, -120, 0, 18), Position = UDim2.fromOffset(18, 12),
    BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = "SleepScript",
    TextSize = 17, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
})
local sub = new("TextLabel", {
    Parent = header, Size = UDim2.new(1, -120, 0, 14), Position = UDim2.fromOffset(18, 30),
    BackgroundTransparency = 1, Font = Enum.Font.Gotham, Text = "Blade Ball  •  v1.0",
    TextSize = 11, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
})
new("UIGradient", {Color = ColorSequence.new(C.accent, C.accent2)}, sub)

-- кнопка свернуть
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

-- сайдбар
local sidebar = new("Frame", {
    Parent = main, Size = UDim2.new(0, 150, 1, -62), Position = UDim2.fromOffset(0, 62),
    BackgroundColor3 = C.bg, BackgroundTransparency = 0.35, BorderSizePixel = 0,
})
new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})
new("UIPadding", {
    PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 10),
    PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
})

-- контейнер страниц
local contentHolder = new("Frame", {
    Parent = main, Size = UDim2.new(1, -160, 1, -74), Position = UDim2.fromOffset(155, 64),
    BackgroundTransparency = 1,
})

local pages, tabs, currentTab = {}, {}, nil
local order = 0
local function nextOrder() order += 1; return order end

local function CreatePage()
    local p = new("ScrollingFrame", {
        Parent = contentHolder, Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent,
        Visible = false,
    })
    new("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder})
    return p
end

local function CreateTab(name, display)
    local btn = new("TextButton", {
        Parent = sidebar, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = nextOrder(),
        BackgroundColor3 = C.off, BackgroundTransparency = 0.55,
        Text = "  " .. (display or name), Font = Enum.Font.GothamMedium,
        TextSize = 13, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
    })
    corner(btn, 8)
    btn.MouseButton1Click:Connect(function()
        for n, p in pairs(pages) do p.Visible = (n == name) end
        for n, b in pairs(tabs) do
            TweenService:Create(b, TweenInfo.new(0.18), {
                BackgroundColor3 = (n == name) and C.accent or C.off,
                BackgroundTransparency = (n == name) and 0 or 0.55,
                TextColor3 = (n == name) and Color3.new(1,1,1) or C.dim,
            }):Play()
        end
        currentTab = name
    end)
    tabs[name] = btn
    pages[name] = CreatePage()
    return pages[name]
end

local function CreateSection(parent, title)
    local sec = new("Frame", {
        Parent = parent, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder(),
        BackgroundColor3 = C.card, BackgroundTransparency = 0.25, BorderSizePixel = 0,
    })
    corner(sec, 10)
    new("UIStroke", {Color = C.stroke, Transparency = 0.55, Thickness = 1}, sec)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
    })
    new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder})
    if title then
        new("TextLabel", {
            Parent = sec, Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold, Text = title, TextSize = 12,
            TextColor3 = C.accent2, TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = nextOrder(),
        })
    end
    return sec
end

local Sync = {}  -- реестр для синхронизации тумблеров с хоткеями

local function CreateToggle(parent, name, default, callback)
    local row = new("Frame", {
        Parent = parent, Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1, LayoutOrder = nextOrder(),
    })
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
        BackgroundColor3 = Color3.fromRGB(255,255,255), BorderSizePixel = 0,
    })
    corner(knob, 8)

    local state = default
    local function render(fire)
        TweenService:Create(btn, TweenInfo.new(0.2), {
            BackgroundColor3 = state and C.accent or C.off }):Play()
        TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8) }):Play()
        if fire and callback then callback(state) end
    end
    btn.MouseButton1Click:Connect(function() state = not state; render(true) end)
    local obj = { Set = function(v, fire) state = v; render(fire) end, Get = function() return state end }
    Sync[name] = obj
    return obj
end

local function CreateSlider(parent, name, min, max, default, decimals, callback)
    local holder = new("Frame", {
        Parent = parent, Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1, LayoutOrder = nextOrder(),
    })
    new("TextLabel", {
        Parent = holder, Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1,
        Font = Enum.Font.Gotham, Text = name, TextSize = 12,
        TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
    })
    local val = new("TextLabel", {
        Parent = holder, Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium, Text = tostring(default), TextSize = 12,
        TextColor3 = C.accent2, TextXAlignment = Enum.TextXAlignment.Right,
    })
    local bar = new("TextButton", {
        Parent = holder, Size = UDim2.new(1, 0, 0, 6), Position = UDim2.new(0, 0, 1, -8),
        BackgroundColor3 = C.off, Text = "", AutoButtonColor = false,
    })
    corner(bar, 3)
    local fill = new("Frame", {Parent = bar, Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = C.accent, BorderSizePixel = 0})
    corner(fill, 3)
    local knob = new("Frame", {Parent = bar, Size = UDim2.fromOffset(12, 12),
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = Color3.fromRGB(255,255,255), BorderSizePixel = 0})
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

local function CreateButton(parent, name, callback, col)
    local btn = new("TextButton", {
        Parent = parent, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = nextOrder(),
        BackgroundColor3 = col or C.off, Text = name,
        Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = C.text,
        AutoButtonColor = false,
    })
    corner(btn, 8)
    btn.MouseButton1Click:Connect(callback)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = C.accent}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = col or C.off}):Play()
    end)
    return btn
end

local function CreateTextbox(parent, placeholder, default, callback)
    local box = new("TextBox", {
        Parent = parent, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = nextOrder(),
        BackgroundColor3 = C.off, Text = default or "", PlaceholderText = placeholder,
        Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = C.text,
        PlaceholderColor3 = C.dim, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
    })
    corner(box, 8)
    new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, box)
    box.FocusLost:Connect(function() if callback then callback(box.Text) end end)
    return box
end

--=============================================================
--  СТРАНИЦЫ
--=============================================================
local pageParry  = CreateTab("AutoParry", "AutoParry")
local pageVis    = CreateTab("Visuals",   "Visuals")
local pageSkin   = CreateTab("Skin",      "Скин меча")
local pagePerf   = CreateTab("Bypass",    "Bypass / FPS")
local pageOv     = CreateTab("Overlay",   "Оверлей")

--============ AUTOPARRY ============
local s1 = CreateSection(pageParry, "PARRY")
CreateToggle(s1, "AutoParry", SS.AutoParry, function(v) SS.AutoParry = v end)
CreateToggle(s1, "ParryVisuals", SS.ParryVisuals, function(v) SS.ParryVisuals = v end)

local s2 = CreateSection(pageParry, "ТАЙМИНГ")
CreateToggle(s2, "PingBased", SS.PingBased, function(v) SS.PingBased = v end)
CreateSlider(s2, "PingBasedOffset", 0, 5, SS.PingBasedOffset, 2, function(v) SS.PingBasedOffset = v end)
CreateSlider(s2, "DistanceToParry", 0.05, 3, SS.DistanceToParry, 2, function(v) SS.DistanceToParry = v end)
CreateSlider(s2, "EmergencyRadius", 1, 30, SS.EmergencyRadius, 0, function(v) SS.EmergencyRadius = v end)

local s3 = CreateSection(pageParry, "КЛАШ")
CreateSlider(s3, "ClashDistance", 5, 60, SS.ClashDistance, 0, function(v) SS.ClashDistance = v end)
CreateSlider(s3, "ClashSpeed", 0.01, 0.2, SS.ClashSpeed, 2, function(v) SS.ClashSpeed = v end)
CreateSlider(s3, "NormalSpeed", 0.01, 0.3, SS.NormalSpeed, 2, function(v) SS.NormalSpeed = v end)

--============ VISUALS ============
local v1 = CreateSection(pageVis, "КАМЕРА")
CreateSlider(v1, "Field of View", 40, 120, SS.FOV, 0, function(v)
    SS.FOV = v
    if cam() then cam().FieldOfView = v end
end)

local v2 = CreateSection(pageVis, "НЕБО")
CreateToggle(v2, "CustomSky", SS.CustomSky, function(v)
    SS.CustomSky = v
    if v then ApplySky(SS.SkyId) else ApplySky(nil) end
end)
local skyBtns = new("Frame", {Parent = v2, Size = UDim2.new(1, 0, 0, 26),
    BackgroundTransparency = 1, LayoutOrder = nextOrder()})
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder})

local SKIES = {
    Sunset = "rbxassetid://159454299",
    Night  = "rbxassetid://57055771",
    Cloudy = "rbxassetid://271042910",
    Space  = "rbxassetid://133883647",
}
local i = 0
for nm, id in pairs(SKIES) do
    i += 1
    local b = new("TextButton", {
        Parent = skyBtns, Size = UDim2.fromOffset(62, 24), LayoutOrder = i,
        BackgroundColor3 = C.off, Text = nm, Font = Enum.Font.Gotham,
        TextSize = 11, TextColor3 = C.text, AutoButtonColor = false,
    })
    corner(b, 7)
    b.MouseButton1Click:Connect(function()
        SS.SkyId = id
        if SS.CustomSky then ApplySky(id) end
    end)
end
CreateTextbox(v2, "Свой Sky ID", SS.SkyId, function(t)
    if t ~= "" then SS.SkyId = t; if SS.CustomSky then ApplySky(t) end end
end)

local v3 = CreateSection(pageVis, "ТЕЛО")
CreateToggle(v3, "Headless", SS.Headless, function(v) SS.Headless = v; ApplyBody() end)
CreateToggle(v3, "Korblox", SS.Korblox, function(v) SS.Korblox = v; ApplyBody() end)
CreateTextbox(v3, "Korblox Mesh ID", SS.KorbloxMesh, function(t)
    SS.KorbloxMesh = t
    if SS.Korblox then ApplyBody() end
end)

--============ SKIN ============
local sk1 = CreateSection(pageSkin, "ПОИСК")
local searchBox = CreateTextbox(sk1, "Поиск скина...", "", function(t) RenderSkinList(t) end)
CreateButton(sk1, "Обновить список скинов", function() BuildSkinDatabase(); RenderSkinList(searchBox.Text) end)
CreateToggle(sk1, "SkinLock (не сбрасывать)", SS.SkinLock, function(v) SS.SkinLock = v end)
CreateButton(sk1, "Сбросить скин", function() ApplySkin(nil, nil) end, Color3.fromRGB(70, 40, 40))

local sk2 = CreateSection(pageSkin, "СПИСОК")
local listFrame = new("ScrollingFrame", {
    Parent = sk2, Size = UDim2.new(1, 0, 0, 190), LayoutOrder = nextOrder(),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent,
})
new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder})

local sk3 = CreateSection(pageSkin, "ВРУЧНУЮ")
CreateTextbox(sk3, "MeshId", "", function(t)
    SS._mMesh = t; if t ~= "" then ApplySkin(t, SS._mTex) end
end)
CreateTextbox(sk3, "TextureId", "", function(t)
    SS._mTex = t; if t ~= "" then ApplySkin(SS._mMesh, t) end
end)

--============ BYPASS / FPS ============
local p1 = CreateSection(pagePerf, "АНТИЧИТ")
CreateToggle(p1, "Bypass", SS.Bypass, function(v) SS.Bypass = v; ApplyBypass(v) end)
new("TextLabel", {
    Parent = p1, Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1,
    Font = Enum.Font.Gotham, TextWrapped = true, TextSize = 11, TextColor3 = C.dim,
    Text = "Блокирует кик, защищает GUI от античита, разрешает локальные CFrame-правки.",
    LayoutOrder = nextOrder(),
})

local p2 = CreateSection(pagePerf, "ПРОИЗВОДИТЕЛЬНОСТЬ")
CreateToggle(p2, "FPS Boost", SS.FPSBoost, function(v) SS.FPSBoost = v; ApplyFPSBoost(v) end)
CreateToggle(p2, "Убрать эффекты", SS.NoEffects, function(v) SS.NoEffects = v; ApplyEffects(v) end)
CreateToggle(p2, "Убрать аксессуары других", SS.NoAccessories, function(v) SS.NoAccessories = v; ApplyAccessories(v) end)
CreateSlider(p2, "FPS Cap", 30, 360, SS.FPSCap, 0, function(v)
    SS.FPSCap = v
    pcall(function() if setfpscap then setfpscap(v) end end)
end)

--============ OVERLAY ============
local o1 = CreateSection(pageOv, "ОТДЕЛЬНОЕ МЕНЮ")
CreateToggle(o1, "Overlay (FPS / Ping)", SS.Overlay, function(v)
    SS.Overlay = v
    if getgenv().SleepScriptOverlay then getgenv().SleepScriptOverlay.Enabled = v end
end)
CreateToggle(o1, "График", SS.OverlayGraph ~= false, function(v) SS.OverlayGraph = v end)

local o2 = CreateSection(pageOv, "КОНФИГ")
CreateButton(o2, "Сохранить конфиг", function()
    local ok = pcall(function()
        writefile("SleepScript.json", HttpService:JSONEncode(SS))
    end)
    print(ok and "[SleepScript] Конфиг сохранён" or "[SleepScript] writefile недоступен")
end)
CreateButton(o2, "Загрузить конфиг", function()
    local ok, data = pcall(function() return readfile("SleepScript.json") end)
    if ok and data then
        local t = HttpService:JSONDecode(data)
        for k, v in pairs(t) do SS[k] = v end
        print("[SleepScript] Конфиг загружен — перезапусти скрипт")
    end
end)

--=============================================================
--  ЛОГИКА: МЕНЮ / СВОРАЧИВАНИЕ
--=============================================================
local function setMenuOpen(open)
    if open then
        main.Visible = true
        main.Size = UDim2.fromOffset(46, 46)
        TweenService:Create(main, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            {Size = UDim2.fromOffset(560, 360)}):Play()
        TweenService:Create(shadow, TweenInfo.new(0.3), {Size = UDim2.fromOffset(560, 360)}):Play()
    else
        TweenService:Create(main, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
            {Size = UDim2.fromOffset(46, 46)}):Play()
        TweenService:Create(shadow, TweenInfo.new(0.22), {Size = UDim2.fromOffset(46, 46)}):Play()
    end
end

local function collapseToggle()
    SS.MenuOpen = not SS.MenuOpen
    setMenuOpen(SS.MenuOpen)
end
minBtn.MouseButton1Click:Connect(collapseToggle)
closeBtn.MouseButton1Click:Connect(collapseToggle)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.Z then
        collapseToggle()
    elseif input.KeyCode == Enum.KeyCode.RightShift then
        SS.AutoParry = not SS.AutoParry
        if Sync["AutoParry"] then Sync["AutoParry"].Set(SS.AutoParry, false) end
    end
end)

setMenuOpen(SS.MenuOpen)

--=============================================================
--  ЛОГИКА: НЕБО
--=============================================================
local function ApplySky(id)
    local old = Lighting:FindFirstChild("SleepSky")
    if old then old:Destroy() end
    local orig = Lighting:FindFirstChildOfClass("Sky")
    if orig then orig.Enabled = not (id ~= nil) end
    if not id or id == "" then return end
    local sky = new("Sky", {Name = "SleepSky", Parent = Lighting})
    for _, p in pairs({"SkyboxBk","SkyboxDn","SkyboxFt","SkyboxLf","SkyboxRt","SkyboxUp"}) do
        sky[p] = id
    end
end

--=============================================================
--  ЛОГИКА: HEADLESS / KORBLOX
--=============================================================
local function ApplyBody()
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
    else
        pcall(function() ch:FindFirstChild("Right Leg") end)
    end
end

--=============================================================
--  ЛОГИКА: FPS BOOST / ЭФФЕКТЫ
--=============================================================
local backup = {}
local function ApplyFPSBoost(on)
    if on then
        backup = {
            shadows = Lighting.GlobalShadows,
            fog = Lighting.FogEnd,
            diff = Lighting.EnvironmentDiffuseScale,
            spec = Lighting.EnvironmentSpecularScale,
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
        if backup.shadows ~= nil then
            Lighting.GlobalShadows = backup.shadows
            Lighting.FogEnd = backup.fog
            Lighting.EnvironmentDiffuseScale = backup.diff
            Lighting.EnvironmentSpecularScale = backup.spec
        end
        for _, v in pairs(Lighting:GetChildren()) do
            if v:IsA("PostEffect") then v.Enabled = true end
        end
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
    end
end

local function ApplyEffects(on)
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then
            v.Enabled = not on
        end
    end
end

local function ApplyAccessories(on)
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            for _, v in pairs(plr.Character:GetChildren()) do
                if v:IsA("Accessory") or v:IsA("Hat") then
                    v.Transparency = on and 1 or 0
                    for _, d in pairs(v:GetDescendants()) do
                        if d:IsA("BasePart") or d:IsA("Decal") then d.Transparency = on and 1 or 0 end
                    end
                end
            end
        end
    end
end

--=============================================================
--  ЛОГИКА: BYPASS
--=============================================================
local oldNamecall
local function ApplyBypass(on)
    if not (getrawmetatable and setreadonly and newcclosure) then return end
    local mt = getrawmetatable(game)
    if not oldNamecall then oldNamecall = mt.__namecall end
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == "Kick" and self == LP and SS.Bypass then return end
        if method == "SetPrimaryPartCFrame" and SS.Bypass then
            local ok, err = pcall(oldNamecall, self, ...)
            if ok then return end
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(mt, true)
end

--=============================================================
--  ЛОГИКА: СКИНЫ
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
        local nm = inst.Name:gsub("^Sword_", ""):gsub("_Sword$", ""):gsub("Sword", ""):gsub("_", " ")
        if nm == "" or nm == " " then nm = inst.Name end
        table.insert(SkinDB, {Name = nm, Mesh = mesh, Tex = tex, Ref = inst})
    end
end

local function BuildSkinDatabase()
    SkinDB = {}
    local roots = {}
    local function push(c) if c and typeof(c) == "Instance" then table.insert(roots, c) end end
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
            pcall(function() ExtractSkin(ch) end)
        end
    end
    -- сортировка
    table.sort(SkinDB, function(a, b) return a.Name < b.Name end)
    print("[SleepScript] Найдено скинов: " .. #SkinDB)
end

local function getSword()
    local ch = LP.Character
    if not ch then return nil end
    return ch:FindFirstChild("Sword") or ch:FindFirstChildOfClass("Tool")
end

local function ApplySkin(mesh, tex)
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

local listOrder = 0
function RenderSkinList(filter)
    filter = filter or ""
    for _, v in ipairs(listFrame:GetChildren()) do
        if v:IsA("TextButton") then v:Destroy() end
    end
    listOrder = 0
    for _, skin in ipairs(SkinDB) do
        if filter == "" or skin.Name:lower():find(filter:lower(), 1, true) then
            listOrder += 1
            local b = new("TextButton", {
                Parent = listFrame, Size = UDim2.new(1, -4, 0, 24), LayoutOrder = listOrder,
                BackgroundColor3 = C.off, Text = "  " .. skin.Name,
                Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.text,
                TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false,
            })
            corner(b, 6)
            b.MouseButton1Click:Connect(function()
                SS._curMesh, SS._curTex = skin.Mesh, skin.Tex
                ApplySkin(skin.Mesh, skin.Tex)
                TweenService:Create(b, TweenInfo.new(0.2), {BackgroundColor3 = C.accent}):Play()
                task.delay(0.4, function()
                    TweenService:Create(b, TweenInfo.new(0.3), {BackgroundColor3 = C.off}):Play()
                end)
            end)
        end
    end
end

BuildSkinDatabase()
RenderSkinList("")

--=============================================================
--  АВТОПАРРИ (ядро)
--=============================================================
local LastClick, LastBallHit, IsParrying, frameCounter = 0, nil, false, 0
local BallsFolder = workspace:FindFirstChild("Balls") or workspace:WaitForChild("Balls", 5)

local NetworkStats = Stats:FindFirstChild("Network")
    and Stats.Network:FindFirstChild("ServerStatsItem")
    and Stats.Network.ServerStatsItem:FindFirstChild("Data Ping")

local r, m
if SS.ParryVisuals then
    r = new("Part", {Name = "SleepParryCircle", Parent = workspace,
        Anchored = true, CanCollide = false, Transparency = 0.3,
        Material = Enum.Material.Neon, Size = Vector3.new(1,1,1)})
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

local frames, lastClock = 0, os.clock()
local hist = {}
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
            if SS.OverlayGraph ~= false then
                for i, v in ipairs(hist) do
                    new("Frame", {
                        Parent = graph, Size = UDim2.new(1/24, -1, math.clamp(v / 240, 0.05, 1), 0),
                        Position = UDim2.new((i-1)/24, 0, 1, 0), AnchorPoint = Vector2.new(0, 1),
                        BackgroundColor3 = C.accent2, BorderSizePixel = 0,
                    })
                end
            end
        end
    end
end)

--=============================================================
--  ИНИЦИАЛИЗАЦИЯ СОХРАНЁННЫХ НАСТРОЕК
--=============================================================
task.spawn(function()
    if cam() then cam().FieldOfView = SS.FOV end
    if SS.CustomSky then ApplySky(SS.SkyId) end
    if SS.Bypass then ApplyBypass(true) end
    if SS.FPSBoost then ApplyFPSBoost(true) end
    if SS.NoEffects then ApplyEffects(true) end
    if SS.NoAccessories then ApplyAccessories(true) end
end)

-- SkinLock: авто-восстановление скина (игра/античит его сбрасывает)
task.spawn(function()
    while task.wait(1.5) do
        if SS.SkinLock and (SS._curMesh or SS._curTex) then
            pcall(ApplySkin, SS._curMesh, SS._curTex)
        end
    end
end)

print("[SleepScript] Загружено. Z — меню, RightShift — AutoParry")
