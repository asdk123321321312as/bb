--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║   BLADE BALL  •  VENICE EDITION                              ║
    ║   Executor : Real                                            ║
    ║   Все данные берутся из игры динамически                     ║
    ╚══════════════════════════════════════════════════════════════╝
    Пункты:
      1) Меню (чёрное, плавное, перетаскиваемое)
      2) AutoParry (2 радиуса + компенсация пинга и скорости)
      3) Bypass античита
      4) Headless / Korblox
      5) Кастомное небо + партиклы
      6) FOV + FPS Boost
]]

--==================== SERVICES ====================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local Lighting          = game:GetService("Lighting")
local Workspace         = game:GetService("Workspace")
local CoreGui           = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser       = game:GetService("VirtualUser")
local Stats             = game:GetService("Stats")

local LP     = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--==================== UTILS ====================
local function guiParent()
    local ok, hui = pcall(function() return gethui() end)
    if ok and hui then return hui end
    return CoreGui
end

local function mk(class, props, kids)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then o[k] = v end
    end
    for _, c in ipairs(kids or {}) do c.Parent = o end
    if props and props.Parent then o.Parent = props.Parent end
    return o
end

local function tw(o, t, p, s, d)
    local a = TweenService:Create(o, TweenInfo.new(t, s or Enum.EasingStyle.Quart, d or Enum.EasingDirection.Out), p)
    a:Play()
    return a
end

local function round(n, d)
    local m = 10 ^ (d or 0)
    return math.floor(n * m + 0.5) / m
end

--==================== THEME ====================
local T = {
    BG        = Color3.fromRGB(10, 10, 13),
    BG2       = Color3.fromRGB(16, 16, 21),
    Sidebar   = Color3.fromRGB(13, 13, 17),
    Card      = Color3.fromRGB(20, 20, 26),
    CardHover = Color3.fromRGB(27, 27, 35),
    Stroke    = Color3.fromRGB(37, 37, 46),
    Accent    = Color3.fromRGB(140, 100, 255),
    Text      = Color3.fromRGB(240, 240, 246),
    Dim       = Color3.fromRGB(132, 132, 148),
}

--==================== FLAGS ====================
local Flags = {
    AutoParry      = false,
    ParryRadius    = 16,
    DetectRadius   = 45,
    PingOffset     = 0.00,
    SpeedScale     = 1.00,
    SpamParry      = true,
    OnlyTargeted   = true,
    UseRemote      = true,

    Bypass         = false,
    WalkSpeed      = 16,
    JumpPower      = 50,

    Headless       = false,
    Korblox        = false,

    Sky            = "Default",
    Particles      = false,
    ParticleColor  = Color3.fromRGB(140, 100, 255),

    FOVEnabled     = false,
    FOV            = 90,
    FPSBoost       = false,
    Fullbright     = false,
}

--==================== NOTIFICATIONS ====================
local NotifyGui = mk("ScreenGui", {
    Name = "VeniceNotify", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 9999, Parent = guiParent()
})
local NotifyList = mk("Frame", {
    Name = "List", BackgroundTransparency = 1, Size = UDim2.fromOffset(280, 500),
    Position = UDim2.new(1, -18, 1, -18), AnchorPoint = Vector2.new(1, 1), Parent = NotifyGui
})
mk("UIListLayout", {
    Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Bottom,
    HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder, Parent = NotifyList
})

local function Notify(title, text, dur)
    dur = dur or 3
    local card = mk("Frame", {
        Size = UDim2.fromOffset(260, 58), BackgroundColor3 = T.Card,
        BackgroundTransparency = 1, BorderSizePixel = 0, Parent = NotifyList
    })
    mk("UICorner", { CornerRadius = UDim.new(0, 10), Parent = card })
    local stroke = mk("UIStroke", { Color = T.Stroke, Thickness = 1, Transparency = 1, Parent = card })
    mk("Frame", {
        Size = UDim2.new(0, 3, 1, -18), Position = UDim2.new(0, 0, 0.5, -0.5),
        BackgroundColor3 = T.Accent, BorderSizePixel = 0, BackgroundTransparency = 1, Parent = card
    })
    local tl = mk("TextLabel", {
        Text = title, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = T.Text,
        BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 10), Size = UDim2.new(1, -24, 0, 15),
        TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1, Parent = card
    })
    local sl = mk("TextLabel", {
        Text = text, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = T.Dim,
        BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 28), Size = UDim2.new(1, -24, 0, 14),
        TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1, Parent = card
    })
    for _, o in ipairs({ card, stroke, tl, sl }) do
        tw(o, 0.28, o:IsA("Frame") and { BackgroundTransparency = 0 } or (o:IsA("UIStroke") and { Transparency = 0 } or { TextTransparency = 0 }))
    end
    card:FindFirstChildOfClass("Frame").BackgroundTransparency = 1
    local bar = card:FindFirstChildOfClass("Frame")
    tw(bar, 0.28, { BackgroundTransparency = 0 })

    task.delay(dur, function()
        tw(card, 0.25, { BackgroundTransparency = 1 })
        tw(tl, 0.25, { TextTransparency = 1 })
        tw(sl, 0.25, { TextTransparency = 1 })
        tw(bar, 0.25, { BackgroundTransparency = 1 })
        task.wait(0.3)
        card:Destroy()
    end)
end

--==================== UI CORE ====================
local Gui = mk("ScreenGui", {
    Name = "VeniceBladeBall", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999, Parent = guiParent()
})

local Root = mk("Frame", {
    Name = "Root", Size = UDim2.fromOffset(680, 440), Position = UDim2.fromScale(0.5, 0.5),
    AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = Gui
})

mk("Frame", {
    Name = "Shadow", Size = UDim2.new(1, 0, 1, 0), Position = UDim2.new(0, 0, 0, 7),
    BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6, BorderSizePixel = 0, Parent = Root,
})
mk("UICorner", { CornerRadius = UDim.new(0, 16), Parent = Root.Shadow })

local Window = mk("Frame", {
    Name = "Window", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = T.BG,
    BorderSizePixel = 0, ClipsDescendants = true, Parent = Root
})
mk("UICorner", { CornerRadius = UDim.new(0, 14), Parent = Window })
mk("UIGradient", { Rotation = 90, Color = ColorSequence.new(T.BG2, T.BG), Parent = Window })
local winStroke = mk("UIStroke", { Color = T.Stroke, Thickness = 1.4, Parent = Window })

-- открытие
Root.Size = UDim2.fromOffset(612, 396)
tw(Root, 0.4, { Size = UDim2.fromOffset(680, 440), Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

--====== HEADER ======
local Header = mk("Frame", { Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, Parent = Window })
mk("TextLabel", {
    Text = "BLADE BALL", Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = T.Text,
    BackgroundTransparency = 1, Position = UDim2.new(0, 18, 0, 9), Size = UDim2.new(0, 220, 0, 18),
    TextXAlignment = Enum.TextXAlignment.Left, Parent = Header
})
mk("TextLabel", {
    Text = "venice edition", Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = T.Accent,
    BackgroundTransparency = 1, Position = UDim2.new(0, 18, 0, 26), Size = UDim2.new(0, 220, 0, 14),
    TextXAlignment = Enum.TextXAlignment.Left, Parent = Header
})
mk("Frame", {
    Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1),
    BackgroundColor3 = T.Stroke, BorderSizePixel = 0, Parent = Header
})

-- кнопка свернуть
local MinBtn = mk("TextButton", {
    Text = "—", Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = T.Dim,
    BackgroundColor3 = T.Card, BorderSizePixel = 0, AutoButtonColor = false,
    Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -74, 0.5, -13), Parent = Header
})
mk("UICorner", { CornerRadius = UDim.new(0, 7), Parent = MinBtn })
local MinStroke = mk("UIStroke", { Color = T.Stroke, Thickness = 1, Parent = MinBtn })

-- кнопка закрыть
local CloseBtn = mk("TextButton", {
    Text = "✕", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = T.Dim,
    BackgroundColor3 = T.Card, BorderSizePixel = 0, AutoButtonColor = false,
    Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -42, 0.5, -13), Parent = Header
})
mk("UICorner", { CornerRadius = UDim.new(0, 7), Parent = CloseBtn })
mk("UIStroke", { Color = T.Stroke, Thickness = 1, Parent = CloseBtn })

--====== DRAG ======
do
    local dragging, dragStart, startPos
    Header.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = i.Position; startPos = Root.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            Root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

--====== SIDEBAR ======
local Sidebar = mk("Frame", {
    Size = UDim2.new(0, 158, 1, -48), Position = UDim2.new(0, 0, 0, 48),
    BackgroundColor3 = T.Sidebar, BorderSizePixel = 0, Parent = Window
})
mk("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), BackgroundColor3 = T.Stroke, BorderSizePixel = 0, Parent = Sidebar })
local SideList = mk("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Parent = Sidebar })
mk("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = SideList })
mk("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = SideList })

local Content = mk("Frame", {
    Size = UDim2.new(1, -158, 1, -48), Position = UDim2.new(0, 158, 0, 48),
    BackgroundTransparency = 1, Parent = Window
})

--====== TABS ======
local Pages, TabButtons = {}, {}
local CurrentTab
local function SelectTab(name)
    for n, p in pairs(Pages) do p.Visible = (n == name) end
    for n, b in pairs(TabButtons) do
        local bar = b:FindFirstChild("Bar")
        local lbl = b:FindFirstChild("Label")
        tw(bar, 0.2, { BackgroundColor3 = (n == name) and T.Accent or T.Stroke })
        tw(lbl, 0.2, { TextColor3 = (n == name) and T.Text or T.Dim })
        tw(b, 0.2, { BackgroundTransparency = (n == name) and 0 or 1 })
    end
    CurrentTab = name
end

local function CreateTab(name, icon)
    local btn = mk("TextButton", {
        Text = "", BackgroundColor3 = T.Card, BackgroundTransparency = 1,
        AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 34), Parent = SideList
    })
    mk("UICorner", { CornerRadius = UDim.new(0, 8), Parent = btn })
    local bar = mk("Frame", {
        Name = "Bar", Size = UDim2.new(0, 3, 0, 16), Position = UDim2.new(0, 0, 0.5, -8),
        BackgroundColor3 = T.Stroke, BorderSizePixel = 0, Parent = btn
    })
    mk("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bar })
    local lbl = mk("TextLabel", {
        Name = "Label", Text = icon .. "  " .. name, Font = Enum.Font.GothamMedium, TextSize = 13,
        TextColor3 = T.Dim, BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 0),
        Size = UDim2.new(1, -14, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = btn
    })
    btn.MouseEnter:Connect(function() if CurrentTab ~= name then tw(btn, 0.15, { BackgroundTransparency = 0.5 }) end end)
    btn.MouseLeave:Connect(function() if CurrentTab ~= name then tw(btn, 0.15, { BackgroundTransparency = 1 }) end end)
    btn.MouseButton1Click:Connect(function() SelectTab(name) end)

    local page = mk("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = T.Stroke,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false, Parent = Content
    })
    mk("UIPadding", {
        PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14),
        PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 12), Parent = page
    })
    mk("UIListLayout", { Padding = UDim.new(0, 9), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page })

    Pages[name] = page
    TabButtons[name] = btn
    return page
end

--====== ELEMENTS ======
local function Section(parent, text)
    local f = mk("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Parent = parent })
    mk("TextLabel", {
        Text = text:upper(), Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = T.Accent,
        BackgroundTransparency = 1, Position = UDim2.new(0, 2, 0, 4), Size = UDim2.new(1, 0, 0, 14),
        TextXAlignment = Enum.TextXAlignment.Left, Parent = f
    })
    return f
end

local function Toggle(parent, text, flag, default, cb)
    Flags[flag] = (default ~= nil) and default or Flags[flag]
    local state = Flags[flag]
    local row = mk("Frame", { Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = T.Card, BorderSizePixel = 0, Parent = parent })
    mk("UICorner", { CornerRadius = UDim.new(0, 8), Parent = row })
    mk("UIStroke", { Color = T.Stroke, Thickness = 1, Parent = row })
    mk("TextLabel", {
        Text = text, Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = T.Text,
        BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -72, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left, Parent = row
    })
    local pill = mk("Frame", {
        Size = UDim2.new(0, 38, 0, 20), Position = UDim2.new(1, -52, 0.5, -10),
        BackgroundColor3 = T.Stroke, BorderSizePixel = 0, Parent = row
    })
    mk("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pill })
    local knob = mk("Frame", {
        Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(0, 3, 0.5, -7),
        BackgroundColor3 = Color3.fromRGB(190, 190, 200), BorderSizePixel = 0, Parent = pill
    })
    mk("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })

    local click = mk("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = row })

    local function render()
        tw(pill, 0.2, { BackgroundColor3 = state and T.Accent or T.Stroke })
        tw(knob, 0.2, { Position = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7) })
    end
    render()

    click.MouseButton1Click:Connect(function()
        state = not state
        Flags[flag] = state
        render()
        if cb then pcall(cb, state) end
    end)
    click.MouseEnter:Connect(function() tw(row, 0.15, { BackgroundColor3 = T.CardHover }) end)
    click.MouseLeave:Connect(function() tw(row, 0.15, { BackgroundColor3 = T.Card }) end)
    return row
end

local function Slider(parent, text, flag, min, max, default, decimals, cb)
    Flags[flag] = default
    local row = mk("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = T.Card, BorderSizePixel = 0, Parent = parent })
    mk("UICorner", { CornerRadius = UDim.new(0, 8), Parent = row })
    mk("UIStroke", { Color = T.Stroke, Thickness = 1, Parent = row })
    mk("TextLabel", {
        Text = text, Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = T.Text,
        BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 8), Size = UDim2.new(1, -90, 0, 16),
        TextXAlignment = Enum.TextXAlignment.Left, Parent = row
    })
    local valLbl = mk("TextLabel", {
        Text = tostring(round(default, decimals)), Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = T.Accent,
        BackgroundTransparency = 1, Position = UDim2.new(1, -70, 0, 8), Size = UDim2.new(0, 56, 0, 16),
        TextXAlignment = Enum.TextXAlignment.Right, Parent = row
    })
    local barBg = mk("Frame", {
        Size = UDim2.new(1, -28, 0, 6), Position = UDim2.new(0, 14, 1, -20),
        BackgroundColor3 = T.Stroke, BorderSizePixel = 0, Parent = row
    })
    mk("UICorner", { CornerRadius = UDim.new(1, 0), Parent = barBg })
    local fill = mk("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = T.Accent, BorderSizePixel = 0, Parent = barBg })
    mk("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })
    local knob = mk("Frame", {
        Size = UDim2.new(0, 14, 0, 14), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = barBg
    })
    mk("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })

    local dragging = false
    local function setValue(v, silent)
        v = math.clamp(v, min, max)
        Flags[flag] = v
        local rel = (v - min) / (max - min)
        tw(fill, 0.08, { Size = UDim2.new(rel, 0, 1, 0) }, Enum.EasingStyle.Linear)
        tw(knob, 0.08, { Position = UDim2.new(rel, 0, 0.5, 0) }, Enum.EasingStyle.Linear)
        valLbl.Text = tostring(round(v, decimals))
        if not silent and cb then pcall(cb, v) end
    end
    setValue(default, true)

    local hit = mk("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = row })
    local function fromX(x)
        local rel = math.clamp((x - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
        setValue(min + (max - min) * rel)
    end
    hit.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; fromX(i.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            fromX(i.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    return row
end

local function Button(parent, text, cb)
    local btn = mk("TextButton", {
        Text = text, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = T.Text,
        BackgroundColor3 = T.Card, BorderSizePixel = 0, AutoButtonColor = false,
        Size = UDim2.new(1, 0, 0, 34), Parent = parent
    })
    mk("UICorner", { CornerRadius = UDim.new(0, 8), Parent = btn })
    mk("UIStroke", { Color = T.Stroke, Thickness = 1, Parent = btn })
    btn.MouseEnter:Connect(function() tw(btn, 0.15, { BackgroundColor3 = T.CardHover }) end)
    btn.MouseLeave:Connect(function() tw(btn, 0.15, { BackgroundColor3 = T.Card }) end)
    btn.MouseButton1Click:Connect(function()
        tw(btn, 0.08, { BackgroundColor3 = T.Accent })
        tw(btn, 0.2, { BackgroundColor3 = T.Card }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        if cb then pcall(cb) end
    end)
    return btn
end

local function Dropdown(parent, text, flag, options, default, cb)
    Flags[flag] = default
    local row = mk("Frame", { Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = T.Card, BorderSizePixel = 0, Parent = parent, ClipsDescendants = true })
    mk("UICorner", { CornerRadius = UDim.new(0, 8), Parent = row })
    mk("UIStroke", { Color = T.Stroke, Thickness = 1, Parent = row })
    mk("TextLabel", {
        Text = text, Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = T.Text,
        BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -110, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left, Parent = row
    })
    local sel = mk("TextLabel", {
        Text = tostring(default) .. "  ▾", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = T.Accent,
        BackgroundTransparency = 1, Position = UDim2.new(1, -110, 0, 0), Size = UDim2.new(0, 96, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Right, Parent = row
    })
    local holder = mk("Frame", { Size = UDim2.new(1, -16, 0, 0), Position = UDim2.new(0, 8, 0, 42), BackgroundColor3 = T.BG2, BorderSizePixel = 0, Parent = row })
    mk("UICorner", { CornerRadius = UDim.new(0, 8), Parent = holder })
    mk("UIListLayout", { Padding = UDim.new(0, 2), Parent = holder })
    mk("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = holder })

    local open = false
    local function build()
        for _, c in ipairs(holder:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        for _, opt in ipairs(options) do
            local b = mk("TextButton", {
                Text = opt, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = T.Dim,
                BackgroundColor3 = T.BG2, BorderSizePixel = 0, AutoButtonColor = false,
                Size = UDim2.new(1, 0, 0, 26), Parent = holder
            })
            b.MouseEnter:Connect(function() tw(b, 0.12, { TextColor3 = T.Text }) end)
            b.MouseLeave:Connect(function() tw(b, 0.12, { TextColor3 = T.Dim }) end)
            b.MouseButton1Click:Connect(function()
                Flags[flag] = opt
                sel.Text = opt .. "  ▾"
                open = false
                tw(row, 0.2, { Size = UDim2.new(1, 0, 0, 38) })
                tw(holder, 0.2, { Size = UDim2.new(1, -16, 0, 0) })
                if cb then pcall(cb, opt) end
            end)
        end
    end
    build()
    sel.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            open = not open
            if open then
                local h = #options * 28 + 8
                tw(row, 0.25, { Size = UDim2.new(1, 0, 0, 38 + h) })
                tw(holder, 0.25, { Size = UDim2.new(1, -16, 0, h) })
            else
                tw(row, 0.25, { Size = UDim2.new(1, 0, 0, 38) })
                tw(holder, 0.25, { Size = UDim2.new(1, -16, 0, 0) })
            end
        end
    end)
    return row
end

local function Label(parent, text)
    local l = mk("TextLabel", {
        Text = text, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = T.Dim,
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18),
        TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Parent = parent
    })
    return l
end

--==================== TAB PAGES ====================
local CombatTab = CreateTab("Combat", "⚔")
local VisualTab = CreateTab("Visual", "✦")
local PerfTab   = CreateTab("Perf", "⚡")
local MiscTab   = CreateTab("Misc", "⚙")

--============================================================
--  2. AUTO PARRY  (два радиуса + пинг + скорость)
--============================================================
local ParryRemotes = {}
local function scanParry()
    ParryRemotes = {}
    local ok = pcall(function()
        for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
            if v:IsA("RemoteEvent") then
                local n = v.Name:lower()
                if n:find("parry") then table.insert(ParryRemotes, v) end
            end
        end
    end)
    if ok then
        table.sort(ParryRemotes, function(a, b)
            return #a:GetFullName() < #b:GetFullName()
        end)
    end
end
scanParry()

local function fireParry()
    local fired = false
    if Flags.UseRemote and #ParryRemotes > 0 then
        local r = ParryRemotes[1]
        if r and r.Parent then
            pcall(function() r:FireServer() end)
            fired = true
        end
    end
    if not fired then
        if mouse1click then
            pcall(mouse1click)
        else
            pcall(function()
                VirtualUser:Button1Down(Vector2.new(0, 0))
                VirtualUser:Button1Up(Vector2.new(0, 0))
            end)
        end
    end
end

local function getBall()
    local b = Workspace:FindFirstChild("Ball")
    if b then
        if b:IsA("BasePart") then return b end
        local p = b:FindFirstChildWhichIsA("BasePart")
        if p then return p end
    end
    for _, v in ipairs(Workspace:GetChildren()) do
        if v:IsA("BasePart") and v.Name:lower():find("ball") then return v end
    end
    return nil
end

local lastParry = 0
local function ParryLoop()
    if not Flags.AutoParry then return end
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local ball = getBall()
    if not ball then return end

    local myPos  = root.Position
    local bPos   = ball.Position
    local delta  = bPos - myPos
    local dist   = delta.Magnitude
    if dist > Flags.DetectRadius * 1.8 then return end

    local vel   = ball.AssemblyLinearVelocity
    local speed = vel.Magnitude

    -- летит ли мяч в мою сторону
    if Flags.OnlyTargeted and speed > 1 then
        local toward = (-delta).Unit
        if vel.Unit:Dot(toward) < 0.35 then return end
    end

    local ping = 0
    pcall(function() ping = LP:GetNetworkPing() end)
    ping = math.max(ping, 0) + Flags.PingOffset

    -- эффективный радиус: внутренний + путь мяча за время пинга
    local effR = Flags.ParryRadius + (speed * ping) * Flags.SpeedScale
    effR = math.min(effR, Flags.DetectRadius)

    local now = os.clock()
    if dist <= effR and (now - lastParry) > 0.11 then
        lastParry = now
        fireParry()
        if Flags.SpamParry then
            task.delay(0.03, fireParry)
            task.delay(0.06, fireParry)
        end
    end
end

RunService.Heartbeat:Connect(function()
    pcall(ParryLoop)
end)

-- страница Combat
Section(CombatTab, "Auto Parry")
Toggle(CombatTab, "Auto Parry", "AutoParry", false, function(s)
    Notify("Auto Parry", s and "включён" or "выключен", 2)
end)
Toggle(CombatTab, "Только когда мяч летит в меня", "OnlyTargeted", true)
Toggle(CombatTab, "Спам-парри (мульти удар)", "SpamParry", true)
Toggle(CombatTab, "Через Remote (точнее)", "UseRemote", true)
Section(CombatTab, "Настройка")
Slider(CombatTab, "Внутренний радиус (парри)", "ParryRadius", 4, 40, 16, 0)
Slider(CombatTab, "Внешний радиус (детект)", "DetectRadius", 20, 120, 45, 0)
Slider(CombatTab, "Компенсация пинга (сек)", "PingOffset", -0.05, 0.15, 0.00, 3)
Slider(CombatTab, "Множитель скорости", "SpeedScale", 0.0, 3.0, 1.00, 2)
Label(CombatTab, "Эффективный радиус = внутренний + скорость × пинг × множитель. Медленный мяч → парри позже, быстрый → раньше.")

--============================================================
--  3. BYPASS ANTICHEAT
--============================================================
local function BypassLoop()
    if not Flags.Bypass then return end
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if math.abs(hum.WalkSpeed - Flags.WalkSpeed) > 0.01 then hum.WalkSpeed = Flags.WalkSpeed end
    if math.abs(hum.JumpPower - Flags.JumpPower) > 0.01 then hum.JumpPower = Flags.JumpPower end
    if not hum.UseJumpPower then hum.UseJumpPower = true end
    if hum.MaxSlopeAngle ~= 89 then hum.MaxSlopeAngle = 89 end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then
        root.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5, 1, 1)
    end
end
RunService.Heartbeat:Connect(function() pcall(BypassLoop) end)

-- анти-АФК
LP.Idled:Connect(function()
    pcall(function()
        VirtualUser:Button2Down(Vector2.new(0, 0))
        task.wait(0.05)
        VirtualUser:Button2Up(Vector2.new(0, 0))
    end)
end)

Section(MiscTab, "Anti-Cheat Bypass")
Toggle(MiscTab, "Bypass (античит)", "Bypass", false, function(s)
    Notify("Bypass", s and "активен" or "выключен", 2)
end)
Slider(MiscTab, "WalkSpeed", "WalkSpeed", 16, 200, 16, 0)
Slider(MiscTab, "JumpPower", "JumpPower", 50, 300, 50, 0)

--============================================================
--  4. HEADLESS / KORBLOX
--============================================================
local korbloxParts = {}

local function applyHeadless(state)
    local char = LP.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end
    head.Transparency = state and 1 or 0
    local face = head:FindFirstChildOfClass("Decal")
    if face then face.Transparency = state and 1 or 0 end
    for _, acc in ipairs(char:GetChildren()) do
        if acc:IsA("Accessory") then
            local handle = acc:FindFirstChild("Handle")
            local attach = handle and handle:FindFirstChild("AccessoryWeld") or handle and handle:FindFirstChildOfClass("Weld")
            if handle and handle:FindFirstChild("HatAttachment") then
                handle.Transparency = state and 1 or 0
            end
            -- скрываем всё, что висит на голове
            if handle then
                local hAtt = handle:FindFirstChild("HatAttachment")
                if hAtt and hAtt.Parent and hAtt.Parent.Parent == head then
                    handle.Transparency = state and 1 or 0
                end
            end
        end
    end
end

local function applyKorblox(state)
    local char = LP.Character
    if not char then return end
    local leg = char:FindFirstChild("Right Leg") or char:FindFirstChild("RightLeg")
    if not leg then return end

    if state then
        leg.Transparency = 1
        local existing = char:FindFirstChild("VeniceKorbloxLeg")
        if not existing then
            local p = mk("Part", {
                Name = "VeniceKorbloxLeg",
                Size = Vector3.new(0.72, leg.Size.Y, 0.72),
                Color = Color3.fromRGB(18, 18, 18),
                Material = Enum.Material.SmoothPlastic,
                CanCollide = false, Massless = true, CastShadow = false,
                CFrame = leg.CFrame, Parent = char
            })
            korbloxParts[char] = p
        end
    else
        leg.Transparency = 0
        local p = char:FindFirstChild("VeniceKorbloxLeg")
        if p then p:Destroy() end
        korbloxParts[char] = nil
    end
end

RunService.RenderStepped:Connect(function()
    if not Flags.Korblox then return end
    local char = LP.Character
    local leg = char and (char:FindFirstChild("Right Leg") or char:FindFirstChild("RightLeg"))
    local p = char and char:FindFirstChild("VeniceKorbloxLeg")
    if leg and p then
        p.CFrame = leg.CFrame
    end
end)

Section(VisualTab, "Персонаж")
Toggle(VisualTab, "Headless", "Headless", false, function(s)
    applyHeadless(s); Notify("Headless", s and "включён" or "выключен", 2)
end)
Toggle(VisualTab, "Korblox", "Korblox", false, function(s)
    applyKorblox(s); Notify("Korblox", s and "включён" or "выключен", 2)
end)

--============================================================
--  5. КАСТОМНОЕ НЕБО + ПАРТИКЛЫ
--============================================================
local SkyData, Atmos, CC

local SPACE = {
    Bk = "rbxassetid://1454877", Dn = "rbxassetid://1454879", Ft = "rbxassetid://1454878",
    Lf = "rbxassetid://1454881", Rt = "rbxassetid://1454880", Up = "rbxassetid://1454882",
}

local function clearSky()
    if SkyData then SkyData:Destroy(); SkyData = nil end
    if Atmos then Atmos:Destroy(); Atmos = nil end
    if CC then CC:Destroy(); CC = nil end
end

local function applySky(name)
    clearSky()
    if name == "Default" then
        Lighting.ClockTime = 14; Lighting.Ambient = Color3.fromRGB(70, 70, 70)
        return
    end
    SkyData = mk("Sky", {
        SkyboxBk = SPACE.Bk, SkyboxDn = SPACE.Dn, SkyboxFt = SPACE.Ft,
        SkyboxLf = SPACE.Lf, SkyboxRt = SPACE.Rt, SkyboxUp = SPACE.Up,
        StarCount = 6000, SunAngularSize = 12, MoonAngularSize = 12,
        CelestialBodiesShown = true, Parent = Lighting
    })
    Atmos = mk("Atmosphere", {
        Density = 0.35, Offset = 0.2, Glare = 0.4, Haze = 1.2, Parent = Lighting
    })
    CC = mk("ColorCorrectionEffect", { Parent = Lighting })

    if name == "Deep Space" then
        Lighting.ClockTime = 0
        Atmos.Color = Color3.fromRGB(20, 24, 60)
        Atmos.Decay = Color3.fromRGB(30, 40, 90)
        CC.TintColor = Color3.fromRGB(210, 220, 255)
        Lighting.Ambient = Color3.fromRGB(24, 26, 45)
    elseif name == "Purple Nebula" then
        Lighting.ClockTime = 0
        Atmos.Color = Color3.fromRGB(60, 30, 110)
        Atmos.Decay = Color3.fromRGB(120, 60, 200)
        CC.TintColor = Color3.fromRGB(200, 170, 255)
        CC.Saturation = 0.3
        Lighting.Ambient = Color3.fromRGB(40, 25, 70)
    elseif name == "Blood Moon" then
        Lighting.ClockTime = 0
        Atmos.Color = Color3.fromRGB(90, 20, 20)
        Atmos.Decay = Color3.fromRGB(180, 50, 40)
        CC.TintColor = Color3.fromRGB(255, 190, 180)
        Lighting.Ambient = Color3.fromRGB(50, 22, 22)
    elseif name == "Midnight" then
        Lighting.ClockTime = 0
        Atmos.Color = Color3.fromRGB(10, 10, 20)
        Atmos.Decay = Color3.fromRGB(15, 15, 35)
        CC.TintColor = Color3.fromRGB(190, 200, 230)
        Lighting.Ambient = Color3.fromRGB(18, 18, 30)
    end
end

local auraEmitter
local function applyParticles(state)
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if state then
        if auraEmitter then auraEmitter:Destroy() end
        auraEmitter = mk("ParticleEmitter", {
            Name = "VeniceAura",
            Texture = "rbxassetid://243098098",
            Color = ColorSequence.new(Flags.ParticleColor),
            Size = NumberSequence.new(0.5, 0),
            Transparency = NumberSequence.new(0.2, 1),
            Lifetime = NumberRange.new(0.6, 1.1),
            Rate = 40, Speed = NumberRange.new(0, 3),
            SpreadAngle = Vector2.new(180, 180),
            LightEmission = 1, LightInfluence = 0,
            ZOffset = 1, Parent = root
        })
    else
        if auraEmitter then auraEmitter:Destroy(); auraEmitter = nil end
    end
end

Dropdown(VisualTab, "Небо", "Sky", { "Default", "Deep Space", "Purple Nebula", "Blood Moon", "Midnight" }, "Default", function(v)
    applySky(v)
    Notify("Небо", v, 2)
end)

Section(VisualTab, "Партиклы")
Toggle(VisualTab, "Аура персонажа", "Particles", false, function(s) applyParticles(s) end)

--============================================================
--  6. FOV + FPS BOOST + FULLBRIGHT
--============================================================
local function applyFPS(state)
    if state then
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 1e6
        for _, v in ipairs(Workspace:GetDescendants()) do
            if v:IsA("ParticleEmitter") and v.Name ~= "VeniceAura" then v.Enabled = false
            elseif v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then v.Enabled = false end
        end
        for _, v in ipairs(Lighting:GetChildren()) do
            if v:IsA("BlurEffect") or v:IsA("BloomEffect") or v:IsA("SunRaysEffect") or v:IsA("DepthOfFieldEffect") then v.Enabled = false end
        end
    else
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
        Lighting.GlobalShadows = true
        for _, v in ipairs(Workspace:GetDescendants()) do
            if v:IsA("ParticleEmitter") then v.Enabled = true
            elseif v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then v.Enabled = true end
        end
        for _, v in ipairs(Lighting:GetChildren()) do
            if v:IsA("BlurEffect") or v:IsA("BloomEffect") or v:IsA("SunRaysEffect") then v.Enabled = true end
        end
    end
end

local fbCC
local function applyFullbright(state)
    if state then
        Lighting.Ambient = Color3.fromRGB(178, 178, 178)
        Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
        Lighting.Brightness = 3
        Lighting.ClockTime = 14
        if not fbCC then fbCC = mk("ColorCorrectionEffect", { Brightness = 0.08, Contrast = 0.05, Parent = Lighting }) end
    else
        if fbCC then fbCC:Destroy(); fbCC = nil end
    end
end

RunService.RenderStepped:Connect(function()
    if Flags.FOVEnabled and Camera then
        Camera.FieldOfView = Flags.FOV
    end
end)

Section(PerfTab, "Камера")
Toggle(PerfTab, "Кастомный FOV", "FOVEnabled", false)
Slider(PerfTab, "Значение FOV", "FOV", 40, 130, 90, 0)

Section(PerfTab, "Производительность")
Toggle(PerfTab, "FPS Boost", "FPSBoost", false, function(s)
    applyFPS(s); Notify("FPS Boost", s and "включён" or "выключен", 2)
end)
Toggle(PerfTab, "Fullbright", "Fullbright", false, function(s) applyFullbright(s) end)

--============================================================
--  RESPAWN HANDLER
--============================================================
LP.CharacterAdded:Connect(function(char)
    task.wait(0.6)
    if Flags.Headless then applyHeadless(true) end
    if Flags.Korblox then applyKorblox(true) end
    if Flags.Particles then applyParticles(true) end
end)

--============================================================
--  МИНИМИЗАЦИЯ / ЗАКРЫТИЕ / КЕЙБИНД
--============================================================
local minimized = false
local Icon = mk("TextButton", {
    Text = "VB", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = T.Text,
    BackgroundColor3 = T.BG, BorderSizePixel = 0, AutoButtonColor = false,
    Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0, 20, 0, 20),
    Visible = false, Parent = Gui
})
mk("UICorner", { CornerRadius = UDim.new(1, 0), Parent = Icon })
mk("UIStroke", { Color = T.Accent, Thickness = 1.5, Parent = Icon })

local function setMinimize(state)
    minimized = state
    if state then
        tw(Root, 0.25, { Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1 }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
        task.wait(0.1)
        Root.Visible = false
        Icon.Visible = true
        tw(Icon, 0.25, { Size = UDim2.fromOffset(44, 44) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    else
        Icon.Visible = false
        Root.Visible = true
        Root.Size = UDim2.fromOffset(0, 0)
        tw(Root, 0.35, { Size = UDim2.fromOffset(680, 440) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    end
end

MinBtn.MouseButton1Click:Connect(function() setMinimize(true) end)
Icon.MouseButton1Click:Connect(function() setMinimize(false) end)
CloseBtn.MouseButton1Click:Connect(function()
    tw(Root, 0.25, { Size = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
    task.wait(0.28)
    Gui.Enabled = false
    NotifyGui.Enabled = false
end)

UserInputService.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.RightShift then
        if Gui.Enabled then
            setMinimize(not minimized)
        else
            Gui.Enabled = true; NotifyGui.Enabled = true; setMinimize(false)
        end
    end
end)

SelectTab("Combat")
Notify("Venice • Blade Ball", "Загружено. RightShift — меню.", 4)
