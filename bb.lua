--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║   BLADE BALL  •  VENICE EDITION  v3                          ║
    ║   Executor : Real                                            ║
    ║   Фикс кика "exploits detected"                              ║
    ╚══════════════════════════════════════════════════════════════╝
]]

if getgenv and getgenv().VeniceBB then pcall(getgenv().VeniceBB) end

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
    for k, v in pairs(props or {}) do if k ~= "Parent" then o[k] = v end end
    for _, c in ipairs(kids or {}) do c.Parent = o end
    if props and props.Parent then o.Parent = props.Parent end
    return o
end
local function tw(o, t, p, s, d)
    local a = TweenService:Create(o, TweenInfo.new(t, s or Enum.EasingStyle.Quart, d or Enum.EasingDirection.Out), p)
    a:Play(); return a
end
local function round(n, d) local m = 10^(d or 0); return math.floor(n*m+0.5)/m end

local T = {
    BG=Color3.fromRGB(10,10,13), BG2=Color3.fromRGB(16,16,21), Sidebar=Color3.fromRGB(13,13,17),
    Card=Color3.fromRGB(20,20,26), CardHover=Color3.fromRGB(27,27,35), Stroke=Color3.fromRGB(37,37,46),
    Accent=Color3.fromRGB(140,100,255), Text=Color3.fromRGB(240,240,246), Dim=Color3.fromRGB(132,132,148),
}

local Flags = {
    AutoParry=false, InnerRadius=14, OuterRadius=45, Adapt=0.80, PingOffset=0.00,
    OnlyTargeted=true, SpamParry=true, ShowRings=true, ParryMethod="Remote (точнее)",
    Bypass=false, WalkSpeed=16, JumpPower=50, CustomPhys=false,
    Headless=false, Korblox=false,
    Sky="Default", Particles=false, ParticleColor=Color3.fromRGB(140,100,255),
    FOVEnabled=false, FOV=90, FPSBoost=false, Fullbright=false,
    HookInstances=true, HookProps=true,
}

--============================================================
--  ANTI-CHEAT BYPASS CORE
--============================================================
local PROTECT = setmetatable({}, { __mode = "k" })   -- объекты, скрытые от античита
local PROPS   = {}                                   -- оригинальные значения свойств Lighting
local Bypass  = { enabled = true, installed = false }

local function protect(inst)   if inst then PROTECT[inst] = true end end
local function unprotect(inst) if inst then PROTECT[inst] = nil end end

-- записываем свойство Lighting, сохраняя оригинал для подмены
local function bset(prop, value)
    if PROPS[prop] == nil then PROPS[prop] = Lighting[prop] end
    Lighting[prop] = value
end

local function rawMT(obj)
    if getrawmetatable then
        local ok, r = pcall(getrawmetatable, obj)
        if ok and r then return r end
    end
    if debug and debug.getmetatable then return debug.getmetatable(obj) end
    return getmetatable(obj)
end
local function writable(mt, state)
    if setreadonly then pcall(setreadonly, mt, state)
    elseif make_writeable then pcall(make_writeable, mt, state) end
end

local function installBypass()
    if Bypass.installed then return true end
    local ok, err = pcall(function()
        local mt = rawMT(game)
        if not mt then error("no rawmetatable") end

        -- снимаем предыдущий хук если скрипт перезапущен
        local prev = getgenv and getgenv().VBB_prev
        if prev and prev.mt == mt then
            writable(mt, false)
            mt.__namecall = prev.namecall
            mt.__index    = prev.index
            writable(mt, true)
        end

        local oldNC = mt.__namecall
        local oldIX = mt.__index
        if getgenv then getgenv().VBB_prev = { mt = mt, namecall = oldNC, index = oldIX } end

        writable(mt, false)

        --=== прячем наши объекты ===
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if Bypass.enabled and Flags.HookInstances and (self == Lighting or self == LP.Character) then
                if method == "GetChildren" or method == "GetDescendants" then
                    local res = oldNC(self, ...)
                    local out, n = {}, 0
                    for i = 1, #res do
                        local v = res[i]
                        if not PROTECT[v] then n = n + 1; out[n] = v end
                    end
                    return out
                elseif method == "FindFirstChild" then
                    local res = oldNC(self, ...)
                    if res ~= nil and PROTECT[res] then
                        local name = select(1, ...)
                        local alt = oldNC(self, name, true)
                        if alt ~= nil and not PROTECT[alt] then return alt end
                        return nil
                    end
                    return res
                end
            end
            return oldNC(self, ...)
        end)

        --=== подмена чтения свойств Lighting ===
        mt.__index = newcclosure(function(self, key)
            if Bypass.enabled and Flags.HookProps and self == Lighting then
                local ov = PROPS[key]
                if ov ~= nil then return ov end
            end
            return oldIX(self, key)
        end)

        writable(mt, true)
    end)
    Bypass.installed = ok
    return ok
end

local function removeBypass()
    local ok = pcall(function()
        local mt = rawMT(game)
        local prev = getgenv and getgenv().VBB_prev
        if prev and prev.mt == mt then
            writable(mt, false)
            mt.__namecall = prev.namecall
            mt.__index    = prev.index
            writable(mt, true)
        end
    end)
    Bypass.installed = false
    return ok
end

--==================== NOTIFICATIONS ====================
local NotifyGui = mk("ScreenGui", { Name="VeniceNotify", ResetOnSpawn=false, IgnoreGuiInset=true,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling, DisplayOrder=9999, Parent=guiParent() })
local NotifyList = mk("Frame", { BackgroundTransparency=1, Size=UDim2.fromOffset(280,500),
    Position=UDim2.new(1,-18,1,-18), AnchorPoint=Vector2.new(1,1), Parent=NotifyGui })
mk("UIListLayout", { Padding=UDim.new(0,8), VerticalAlignment=Enum.VerticalAlignment.Bottom,
    HorizontalAlignment=Enum.HorizontalAlignment.Right, SortOrder=Enum.SortOrder.LayoutOrder, Parent=NotifyList })

local function Notify(title, text, dur)
    dur = dur or 3
    local card = mk("Frame", { Size=UDim2.fromOffset(260,58), BackgroundColor3=T.Card,
        BackgroundTransparency=1, BorderSizePixel=0, Parent=NotifyList })
    mk("UICorner", { CornerRadius=UDim.new(0,10), Parent=card })
    local stroke = mk("UIStroke", { Color=T.Stroke, Thickness=1, Transparency=1, Parent=card })
    local bar = mk("Frame", { Size=UDim2.new(0,3,1,-18), Position=UDim2.new(0,0,0.5,-0.5),
        BackgroundColor3=T.Accent, BorderSizePixel=0, BackgroundTransparency=1, Parent=card })
    local tl = mk("TextLabel", { Text=title, Font=Enum.Font.GothamBold, TextSize=13, TextColor3=T.Text,
        BackgroundTransparency=1, Position=UDim2.new(0,14,0,10), Size=UDim2.new(1,-24,0,15),
        TextXAlignment=Enum.TextXAlignment.Left, TextTransparency=1, Parent=card })
    local sl = mk("TextLabel", { Text=text, Font=Enum.Font.Gotham, TextSize=11, TextColor3=T.Dim,
        BackgroundTransparency=1, Position=UDim2.new(0,14,0,28), Size=UDim2.new(1,-24,0,14),
        TextXAlignment=Enum.TextXAlignment.Left, TextTransparency=1, Parent=card })
    tw(card,0.28,{BackgroundTransparency=0}); tw(stroke,0.28,{Transparency=0})
    tw(bar,0.28,{BackgroundTransparency=0}); tw(tl,0.28,{TextTransparency=0}); tw(sl,0.28,{TextTransparency=0})
    task.delay(dur, function()
        tw(card,0.25,{BackgroundTransparency=1}); tw(stroke,0.25,{Transparency=1})
        tw(bar,0.25,{BackgroundTransparency=1}); tw(tl,0.25,{TextTransparency=1}); tw(sl,0.25,{TextTransparency=1})
        task.wait(0.3); card:Destroy()
    end)
end

--============================================================
--  UI
--============================================================
local Gui = mk("ScreenGui", { Name="VeniceBladeBall", ResetOnSpawn=false, IgnoreGuiInset=true,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling, DisplayOrder=999, Parent=guiParent() })

local Root = mk("Frame", { Size=UDim2.fromOffset(680,440), Position=UDim2.fromScale(0.5,0.5),
    AnchorPoint=Vector2.new(0.5,0.5), BackgroundTransparency=1, Parent=Gui })
mk("Frame", { Name="Shadow", Size=UDim2.new(1,0,1,0), Position=UDim2.new(0,0,0,7),
    BackgroundColor3=Color3.new(0,0,0), BackgroundTransparency=0.6, BorderSizePixel=0, Parent=Root })
mk("UICorner", { CornerRadius=UDim.new(0,16), Parent=Root.Shadow })
local Window = mk("Frame", { Size=UDim2.new(1,0,1,0), BackgroundColor3=T.BG, BorderSizePixel=0,
    ClipsDescendants=true, Parent=Root })
mk("UICorner", { CornerRadius=UDim.new(0,14), Parent=Window })
mk("UIGradient", { Rotation=90, Color=ColorSequence.new(T.BG2,T.BG), Parent=Window })
mk("UIStroke", { Color=T.Stroke, Thickness=1.4, Parent=Window })
Root.Size = UDim2.fromOffset(612,396)
tw(Root, 0.4, { Size=UDim2.fromOffset(680,440) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local Header = mk("Frame", { Size=UDim2.new(1,0,0,48), BackgroundTransparency=1, Parent=Window })
mk("TextLabel", { Text="BLADE BALL", Font=Enum.Font.GothamBold, TextSize=15, TextColor3=T.Text,
    BackgroundTransparency=1, Position=UDim2.new(0,18,0,9), Size=UDim2.new(0,220,0,18),
    TextXAlignment=Enum.TextXAlignment.Left, Parent=Header })
mk("TextLabel", { Text="venice edition  •  v3", Font=Enum.Font.GothamMedium, TextSize=11,
    TextColor3=T.Accent, BackgroundTransparency=1, Position=UDim2.new(0,18,0,26),
    Size=UDim2.new(0,220,0,14), TextXAlignment=Enum.TextXAlignment.Left, Parent=Header })
mk("Frame", { Size=UDim2.new(1,0,0,1), Position=UDim2.new(0,0,1,-1), BackgroundColor3=T.Stroke,
    BorderSizePixel=0, Parent=Header })

local MinBtn = mk("TextButton", { Text="—", Font=Enum.Font.GothamBold, TextSize=15, TextColor3=T.Dim,
    BackgroundColor3=T.Card, BorderSizePixel=0, AutoButtonColor=false, Size=UDim2.fromOffset(26,26),
    Position=UDim2.new(1,-74,0.5,-13), Parent=Header })
mk("UICorner", { CornerRadius=UDim.new(0,7), Parent=MinBtn })
mk("UIStroke", { Color=T.Stroke, Thickness=1, Parent=MinBtn })
local CloseBtn = mk("TextButton", { Text="✕", Font=Enum.Font.GothamBold, TextSize=13, TextColor3=T.Dim,
    BackgroundColor3=T.Card, BorderSizePixel=0, AutoButtonColor=false, Size=UDim2.fromOffset(26,26),
    Position=UDim2.new(1,-42,0.5,-13), Parent=Header })
mk("UICorner", { CornerRadius=UDim.new(0,7), Parent=CloseBtn })
mk("UIStroke", { Color=T.Stroke, Thickness=1, Parent=CloseBtn })

do
    local dragging, dragStart, startPos
    Header.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=true; dragStart=i.Position; startPos=Root.Position end end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            local d=i.Position-dragStart
            Root.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y) end end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
end

local Sidebar = mk("Frame", { Size=UDim2.new(0,158,1,-48), Position=UDim2.new(0,0,0,48),
    BackgroundColor3=T.Sidebar, BorderSizePixel=0, Parent=Window })
mk("Frame", { Size=UDim2.new(0,1,1,0), Position=UDim2.new(1,-1,0,0), BackgroundColor3=T.Stroke, BorderSizePixel=0, Parent=Sidebar })
local SideList = mk("Frame", { Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, Parent=Sidebar })
mk("UIPadding", { PaddingTop=UDim.new(0,12), PaddingLeft=UDim.new(0,10), PaddingRight=UDim.new(0,10), Parent=SideList })
mk("UIListLayout", { Padding=UDim.new(0,4), SortOrder=Enum.SortOrder.LayoutOrder, Parent=SideList })
local Content = mk("Frame", { Size=UDim2.new(1,-158,1,-48), Position=UDim2.new(0,158,0,48),
    BackgroundTransparency=1, Parent=Window })

local Pages, TabButtons, CurrentTab = {}, {}, nil
local function SelectTab(name)
    for n,p in pairs(Pages) do p.Visible=(n==name) end
    for n,b in pairs(TabButtons) do
        tw(b:FindFirstChild("Bar"),0.2,{BackgroundColor3=(n==name) and T.Accent or T.Stroke})
        tw(b:FindFirstChild("Label"),0.2,{TextColor3=(n==name) and T.Text or T.Dim})
        tw(b,0.2,{BackgroundTransparency=(n==name) and 0 or 1})
    end
    CurrentTab=name
end
local function CreateTab(name, icon)
    local btn = mk("TextButton", { Text="", BackgroundColor3=T.Card, BackgroundTransparency=1,
        AutoButtonColor=false, Size=UDim2.new(1,0,0,34), Parent=SideList })
    mk("UICorner", { CornerRadius=UDim.new(0,8), Parent=btn })
    local bar = mk("Frame", { Name="Bar", Size=UDim2.new(0,3,0,16), Position=UDim2.new(0,0,0.5,-8),
        BackgroundColor3=T.Stroke, BorderSizePixel=0, Parent=btn })
    mk("UICorner", { CornerRadius=UDim.new(1,0), Parent=bar })
    local lbl = mk("TextLabel", { Name="Label", Text=icon.."  "..name, Font=Enum.Font.GothamMedium, TextSize=13,
        TextColor3=T.Dim, BackgroundTransparency=1, Position=UDim2.new(0,14,0,0),
        Size=UDim2.new(1,-14,1,0), TextXAlignment=Enum.TextXAlignment.Left, Parent=btn })
    btn.MouseEnter:Connect(function() if CurrentTab~=name then tw(btn,0.15,{BackgroundTransparency=0.5}) end end)
    btn.MouseLeave:Connect(function() if CurrentTab~=name then tw(btn,0.15,{BackgroundTransparency=1}) end end)
    btn.MouseButton1Click:Connect(function() SelectTab(name) end)
    local page = mk("ScrollingFrame", { Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, BorderSizePixel=0,
        ScrollBarThickness=3, ScrollBarImageColor3=T.Stroke, CanvasSize=UDim2.new(0,0,0,0),
        AutomaticCanvasSize=Enum.AutomaticSize.Y, Visible=false, Parent=Content })
    mk("UIPadding", { PaddingTop=UDim.new(0,14), PaddingBottom=UDim.new(0,14),
        PaddingLeft=UDim.new(0,16), PaddingRight=UDim.new(0,12), Parent=page })
    mk("UIListLayout", { Padding=UDim.new(0,9), SortOrder=Enum.SortOrder.LayoutOrder, Parent=page })
    Pages[name]=page; TabButtons[name]=btn
    return page
end

local function Section(parent, text)
    local f = mk("Frame", { Size=UDim2.new(1,0,0,22), BackgroundTransparency=1, Parent=parent })
    mk("TextLabel", { Text=text:upper(), Font=Enum.Font.GothamBold, TextSize=10, TextColor3=T.Accent,
        BackgroundTransparency=1, Position=UDim2.new(0,2,0,4), Size=UDim2.new(1,0,0,14),
        TextXAlignment=Enum.TextXAlignment.Left, Parent=f })
    return f
end

local function Toggle(parent, text, flag, default, cb)
    Flags[flag] = (default~=nil) and default or Flags[flag]
    local state = Flags[flag]
    local row = mk("Frame", { Size=UDim2.new(1,0,0,38), BackgroundColor3=T.Card, BorderSizePixel=0, Parent=parent })
    mk("UICorner", { CornerRadius=UDim.new(0,8), Parent=row })
    mk("UIStroke", { Color=T.Stroke, Thickness=1, Parent=row })
    mk("TextLabel", { Text=text, Font=Enum.Font.Gotham, TextSize=13, TextColor3=T.Text,
        BackgroundTransparency=1, Position=UDim2.new(0,14,0,0), Size=UDim2.new(1,-72,1,0),
        TextXAlignment=Enum.TextXAlignment.Left, Parent=row })
    local pill = mk("Frame", { Size=UDim2.new(0,38,0,20), Position=UDim2.new(1,-52,0.5,-10),
        BackgroundColor3=T.Stroke, BorderSizePixel=0, Parent=row })
    mk("UICorner", { CornerRadius=UDim.new(1,0), Parent=pill })
    local knob = mk("Frame", { Size=UDim2.new(0,14,0,14), Position=UDim2.new(0,3,0.5,-7),
        BackgroundColor3=Color3.fromRGB(190,190,200), BorderSizePixel=0, Parent=pill })
    mk("UICorner", { CornerRadius=UDim.new(1,0), Parent=knob })
    local click = mk("TextButton", { Text="", BackgroundTransparency=1, Size=UDim2.new(1,0,1,0), Parent=row })
    local function render()
        tw(pill,0.2,{BackgroundColor3=state and T.Accent or T.Stroke})
        tw(knob,0.2,{Position=state and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7)})
    end
    render()
    click.MouseButton1Click:Connect(function()
        state=not state; Flags[flag]=state; render(); if cb then pcall(cb,state) end end)
    click.MouseEnter:Connect(function() tw(row,0.15,{BackgroundColor3=T.CardHover}) end)
    click.MouseLeave:Connect(function() tw(row,0.15,{BackgroundColor3=T.Card}) end)
    return row
end

local function Slider(parent, text, flag, min, max, default, decimals, cb)
    Flags[flag]=default
    local row = mk("Frame", { Size=UDim2.new(1,0,0,52), BackgroundColor3=T.Card, BorderSizePixel=0, Parent=parent })
    mk("UICorner", { CornerRadius=UDim.new(0,8), Parent=row })
    mk("UIStroke", { Color=T.Stroke, Thickness=1, Parent=row })
    mk("TextLabel", { Text=text, Font=Enum.Font.Gotham, TextSize=13, TextColor3=T.Text,
        BackgroundTransparency=1, Position=UDim2.new(0,14,0,8), Size=UDim2.new(1,-90,0,16),
        TextXAlignment=Enum.TextXAlignment.Left, Parent=row })
    local valLbl = mk("TextLabel", { Text=tostring(round(default,decimals)), Font=Enum.Font.GothamBold,
        TextSize=13, TextColor3=T.Accent, BackgroundTransparency=1, Position=UDim2.new(1,-70,0,8),
        Size=UDim2.new(0,56,0,16), TextXAlignment=Enum.TextXAlignment.Right, Parent=row })
    local barBg = mk("Frame", { Size=UDim2.new(1,-28,0,6), Position=UDim2.new(0,14,1,-20),
        BackgroundColor3=T.Stroke, BorderSizePixel=0, Parent=row })
    mk("UICorner", { CornerRadius=UDim.new(1,0), Parent=barBg })
    local fill = mk("Frame", { Size=UDim2.new(0,0,1,0), BackgroundColor3=T.Accent, BorderSizePixel=0, Parent=barBg })
    mk("UICorner", { CornerRadius=UDim.new(1,0), Parent=fill })
    local knob = mk("Frame", { Size=UDim2.new(0,14,0,14), AnchorPoint=Vector2.new(0.5,0.5),
        Position=UDim2.new(0,0,0.5,0), BackgroundColor3=Color3.new(1,1,1), BorderSizePixel=0, Parent=barBg })
    mk("UICorner", { CornerRadius=UDim.new(1,0), Parent=knob })
    local dragging=false
    local function setValue(v, silent)
        v=math.clamp(v,min,max); Flags[flag]=v
        local rel=(v-min)/(max-min)
        tw(fill,0.08,{Size=UDim2.new(rel,0,1,0)},Enum.EasingStyle.Linear)
        tw(knob,0.08,{Position=UDim2.new(rel,0,0.5,0)},Enum.EasingStyle.Linear)
        valLbl.Text=tostring(round(v,decimals))
        if not silent and cb then pcall(cb,v) end
    end
    setValue(default,true)
    local hit = mk("TextButton", { Text="", BackgroundTransparency=1, Size=UDim2.new(1,0,1,0), Parent=row })
    local function fromX(x)
        local rel=math.clamp((x-barBg.AbsolutePosition.X)/barBg.AbsoluteSize.X,0,1)
        setValue(min+(max-min)*rel)
    end
    hit.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=true; fromX(i.Position.X) end end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            fromX(i.Position.X) end end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
    return row
end

local function Button(parent, text, cb)
    local btn = mk("TextButton", { Text=text, Font=Enum.Font.GothamMedium, TextSize=13, TextColor3=T.Text,
        BackgroundColor3=T.Card, BorderSizePixel=0, AutoButtonColor=false,
        Size=UDim2.new(1,0,0,34), Parent=parent })
    mk("UICorner", { CornerRadius=UDim.new(0,8), Parent=btn })
    mk("UIStroke", { Color=T.Stroke, Thickness=1, Parent=btn })
    btn.MouseEnter:Connect(function() tw(btn,0.15,{BackgroundColor3=T.CardHover}) end)
    btn.MouseLeave:Connect(function() tw(btn,0.15,{BackgroundColor3=T.Card}) end)
    btn.MouseButton1Click:Connect(function()
        tw(btn,0.08,{BackgroundColor3=T.Accent})
        tw(btn,0.2,{BackgroundColor3=T.Card},Enum.EasingStyle.Quart,Enum.EasingDirection.Out)
        if cb then pcall(cb) end end)
    return btn
end

local function Dropdown(parent, text, flag, options, default, cb)
    Flags[flag]=default
    local row = mk("Frame", { Size=UDim2.new(1,0,0,38), BackgroundColor3=T.Card,
        BorderSizePixel=0, Parent=parent, ClipsDescendants=true })
    mk("UICorner", { CornerRadius=UDim.new(0,8), Parent=row })
    mk("UIStroke", { Color=T.Stroke, Thickness=1, Parent=row })
    mk("TextLabel", { Text=text, Font=Enum.Font.Gotham, TextSize=13, TextColor3=T.Text,
        BackgroundTransparency=1, Position=UDim2.new(0,14,0,0), Size=UDim2.new(1,-110,1,0),
        TextXAlignment=Enum.TextXAlignment.Left, Parent=row })
    local sel = mk("TextLabel", { Text=tostring(default).."  ▾", Font=Enum.Font.GothamMedium, TextSize=12,
        TextColor3=T.Accent, BackgroundTransparency=1, Position=UDim2.new(1,-110,0,0),
        Size=UDim2.new(0,96,1,0), TextXAlignment=Enum.TextXAlignment.Right, Parent=row })
    local holder = mk("Frame", { Size=UDim2.new(1,-16,0,0), Position=UDim2.new(0,8,0,42),
        BackgroundColor3=T.BG2, BorderSizePixel=0, Parent=row })
    mk("UICorner", { CornerRadius=UDim.new(0,8), Parent=holder })
    mk("UIListLayout", { Padding=UDim.new(0,2), Parent=holder })
    mk("UIPadding", { PaddingTop=UDim.new(0,4), PaddingBottom=UDim.new(0,4), Parent=holder })
    local open=false
    for _, opt in ipairs(options) do
        local b = mk("TextButton", { Text=opt, Font=Enum.Font.Gotham, TextSize=12, TextColor3=T.Dim,
            BackgroundColor3=T.BG2, BorderSizePixel=0, AutoButtonColor=false,
            Size=UDim2.new(1,0,0,26), Parent=holder })
        b.MouseEnter:Connect(function() tw(b,0.12,{TextColor3=T.Text}) end)
        b.MouseLeave:Connect(function() tw(b,0.12,{TextColor3=T.Dim}) end)
        b.MouseButton1Click:Connect(function()
            Flags[flag]=opt; sel.Text=opt.."  ▾"; open=false
            tw(row,0.2,{Size=UDim2.new(1,0,0,38)}); tw(holder,0.2,{Size=UDim2.new(1,-16,0,0)})
            if cb then pcall(cb,opt) end end)
    end
    sel.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            open=not open
            local h = open and (#options*28+8) or 0
            tw(row,0.25,{Size=UDim2.new(1,0,0,38+h)}); tw(holder,0.25,{Size=UDim2.new(1,-16,0,h)})
        end end)
    return row
end

local function Label(parent, text)
    return mk("TextLabel", { Text=text, Font=Enum.Font.Gotham, TextSize=11, TextColor3=T.Dim,
        BackgroundTransparency=1, Size=UDim2.new(1,0,0,18), TextXAlignment=Enum.TextXAlignment.Left,
        TextWrapped=true, Parent=parent })
end

local CombatTab = CreateTab("Combat","⚔")
local VisualTab = CreateTab("Visual","✦")
local PerfTab   = CreateTab("Perf","⚡")
local MiscTab   = CreateTab("Misc","⚙")

--============================================================
--  AUTO PARRY  (два адаптивных радиуса + Remote)
--============================================================
local ParryRemotes = {}
local function scanParry()
    ParryRemotes = {}
    pcall(function()
        for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
            if v:IsA("RemoteEvent") and v.Name:lower():find("parry") then
                table.insert(ParryRemotes, v)
            end
        end
    end)
    table.sort(ParryRemotes, function(a,b) return #a:GetFullName() < #b:GetFullName() end)
end
scanParry()

local function fireParry()
    local m = Flags.ParryMethod
    local fired = false
    if (m == "Remote (точнее)" or m == "Оба") and #ParryRemotes > 0 then
        local r = ParryRemotes[1]
        if r and r.Parent then pcall(function() r:FireServer() end); fired = true end
    end
    if m == "Клик мышью" or m == "Оба" or not fired then
        if mouse1click then pcall(mouse1click)
        else pcall(function()
            VirtualUser:Button1Down(Vector2.new(0,0)); VirtualUser:Button1Up(Vector2.new(0,0))
        end) end
    end
end

local ballCache, lastScan = nil, 0
local function getBall()
    if ballCache and ballCache.Parent then return ballCache end
    ballCache = nil
    if os.clock() - lastScan < 0.4 then return nil end
    lastScan = os.clock()
    local direct = Workspace:FindFirstChild("Ball")
    if direct then
        ballCache = direct:IsA("BasePart") and direct or direct:FindFirstChildWhichIsA("BasePart")
        if ballCache then return ballCache end
    end
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") and v.Name:lower():sub(1,4) == "ball" then ballCache = v; return v end
    end
    return nil
end

-- кольца радиусов (внутри персонажа — прячутся хуком)
local function makeRing(color)
    local p = Instance.new("Part")
    p.Shape = Enum.PartType.Cylinder
    p.Size = Vector3.new(0.12, 2, 2)
    p.Color = color; p.Material = Enum.Material.Neon
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
    p.Transparency = 0.65; p.CastShadow = false
    return p
end
local ringInner, ringOuter
local function ensureRings()
    local char = LP.Character
    if not char then return end
    if not ringInner or not ringInner.Parent then
        ringInner = makeRing(Color3.fromRGB(80,255,120)); ringInner.Name="VBB_RingIn"
        ringInner.Parent = char; protect(ringInner)
    end
    if not ringOuter or not ringOuter.Parent then
        ringOuter = makeRing(Color3.fromRGB(255,80,80)); ringOuter.Name="VBB_RingOut"
        ringOuter.Parent = char; protect(ringOuter)
    end
end

local lastParry = 0
local dbgBall, dbgDist, dbgSpeed = false, 0, 0

RunService.RenderStepped:Connect(function()
    if not Flags.AutoParry then
        if ringInner then ringInner.Transparency = 1 end
        if ringOuter then ringOuter.Transparency = 1 end
        return
    end
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    ensureRings()
    local ball = getBall()
    dbgBall = ball ~= nil
    if not ball then
        ringInner.Transparency=1; ringOuter.Transparency=1; return
    end

    local myPos, bPos = root.Position, ball.Position
    local delta = bPos - myPos
    local dist  = delta.Magnitude
    local vel   = ball.AssemblyLinearVelocity
    local speed = vel.Magnitude
    dbgDist, dbgSpeed = dist, speed

    local ping = 0
    pcall(function() ping = LP:GetNetworkPing() end)
    ping = math.max(ping, 0) + Flags.PingOffset

    local k = math.clamp(speed / 120, 0, 2)
    local mul = 1 + k * Flags.Adapt
    local outerR = Flags.OuterRadius * mul
    local innerR = Flags.InnerRadius * mul + speed * ping
    if innerR > outerR then innerR = outerR * 0.95 end

    if Flags.ShowRings then
        local feet = myPos - Vector3.new(0, root.Size.Y/2 - 0.2, 0)
        ringOuter.Transparency = 0.78
        ringOuter.Size = Vector3.new(0.1, outerR*2, outerR*2)
        ringOuter.CFrame = CFrame.new(feet) * CFrame.Angles(0,0,math.rad(90))
        ringInner.Transparency = 0.55
        ringInner.Size = Vector3.new(0.12, innerR*2, innerR*2)
        ringInner.CFrame = CFrame.new(feet + Vector3.new(0,0.05,0)) * CFrame.Angles(0,0,math.rad(90))
    else
        ringInner.Transparency=1; ringOuter.Transparency=1
    end

    if Flags.OnlyTargeted and speed > 1 then
        if vel.Unit:Dot((-delta).Unit) < 0.30 then return end
    end

    local now = os.clock()
    if dist <= innerR and (now - lastParry) > 0.10 then
        lastParry = now
        fireParry()
        if Flags.SpamParry then
            task.delay(0.025, fireParry); task.delay(0.05, fireParry)
        end
    end
end)

Section(CombatTab, "Auto Parry")
Toggle(CombatTab, "Auto Parry", "AutoParry", false, function(s) Notify("Auto Parry", s and "вкл" or "выкл", 2) end)
Toggle(CombatTab, "Только когда мяч летит в меня", "OnlyTargeted", true)
Toggle(CombatTab, "Спам-парри", "SpamParry", true)
Toggle(CombatTab, "Показывать радиусы", "ShowRings", true)
Dropdown(CombatTab, "Способ отбивания", "ParryMethod", { "Remote (точнее)", "Клик мышью", "Оба" }, "Remote (точнее)")
Section(CombatTab, "Радиусы (адаптивные)")
Slider(CombatTab, "Внутренний радиус (удар)", "InnerRadius", 4, 40, 14, 0)
Slider(CombatTab, "Внешний радиус (детект)", "OuterRadius", 20, 120, 45, 0)
Slider(CombatTab, "Влияние скорости мяча", "Adapt", 0.0, 2.0, 0.80, 2)
Slider(CombatTab, "Компенсация пинга", "PingOffset", -0.05, 0.15, 0.00, 3)
Button(CombatTab, "Тест парри", function()
    Notify("Тест", "Remote найдено: "..#ParryRemotes, 3); fireParry()
end)
local dbgLabel = Label(CombatTab, "…")
task.spawn(function()
    while true do
        task.wait(0.25)
        dbgLabel.Text = string.format("Мяч: %s | Дист: %.0f | Скор: %.0f | Remote: %d",
            dbgBall and "да" or "нет", dbgDist, dbgSpeed, #ParryRemotes)
    end
end)

--============================================================
--  HEADLESS / KORBLOX
--============================================================
local KORB = "VBB_Korblox_"
local korbloxMap = {}

local function isRightLegPart(n)
    return n=="Right Leg" or n=="RightLeg" or n=="RightUpperLeg" or n=="RightLowerLeg" or n=="RightFoot"
end
local function clearKorblox(char)
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("BasePart") and v.Name:sub(1,#KORB)==KORB then
            unprotect(v); v:Destroy()
        end
    end
    korbloxMap = {}
end
local function applyKorblox(state)
    local char = LP.Character
    if not char then return end
    clearKorblox(char)
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("BasePart") and isRightLegPart(v.Name) then
            if state then
                v.Transparency = 1
                local fake = mk("Part", {
                    Name = KORB..v.Name, Size = v.Size * Vector3.new(0.62,1,0.62),
                    Color = Color3.fromRGB(14,14,14), Material = Enum.Material.SmoothPlastic,
                    CanCollide=false, Massless=true, CastShadow=false, CFrame=v.CFrame, Parent=char,
                })
                protect(fake)
                korbloxMap[v] = fake
            else
                v.Transparency = 0
            end
        end
    end
    for _, acc in ipairs(char:GetChildren()) do
        if acc:IsA("Accessory") then
            local handle = acc:FindFirstChild("Handle")
            if handle then
                local att = handle:FindFirstChild("HatAttachment")
                local p = att and att.Parent
                if p and isRightLegPart(p.Name) then handle.Transparency = state and 1 or 0 end
            end
        end
    end
end
local function applyHeadless(state)
    local char = LP.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end
    head.Transparency = state and 1 or 0
    for _, d in ipairs(head:GetChildren()) do
        if d:IsA("Decal") then d.Transparency = state and 1 or 0 end
    end
    for _, acc in ipairs(char:GetChildren()) do
        if acc:IsA("Accessory") then
            local handle = acc:FindFirstChild("Handle")
            local att = handle and handle:FindFirstChild("HatAttachment")
            if att and att.Parent and att.Parent.Parent == head then
                handle.Transparency = state and 1 or 0
            end
        end
    end
end

RunService.RenderStepped:Connect(function()
    if not Flags.Korblox then return end
    for real, fake in pairs(korbloxMap) do
        if real.Parent and fake.Parent then fake.CFrame = real.CFrame end
    end
end)

Section(VisualTab, "Персонаж")
Toggle(VisualTab, "Headless", "Headless", false, function(s)
    applyHeadless(s); Notify("Headless", s and "вкл" or "выкл", 2) end)
Toggle(VisualTab, "Korblox (R6/R15)", "Korblox", false, function(s)
    applyKorblox(s); Notify("Korblox", s and "вкл" or "выкл", 2) end)

--============================================================
--  НЕБО (защищённое) + ПАРТИКЛЫ
--============================================================
local SPACE = {
    Bk="rbxassetid://1454877", Dn="rbxassetid://1454879", Ft="rbxassetid://1454878",
    Lf="rbxassetid://1454881", Rt="rbxassetid://1454880", Up="rbxassetid://1454882",
}
local skyObj, atmosObj, ccObj

local function clearSky()
    for _, o in ipairs({skyObj, atmosObj, ccObj}) do
        if o then unprotect(o); pcall(function() o:Destroy() end) end
    end
    skyObj, atmosObj, ccObj = nil, nil, nil
end

local function restoreLighting()
    for k, v in pairs(PROPS) do pcall(function() Lighting[k] = v end) end
end

local function buildSky(name)
    clearSky()
    if name == "Default" then restoreLighting(); return end

    skyObj = mk("Sky", { Name="VBB_Sky",
        SkyboxBk=SPACE.Bk, SkyboxDn=SPACE.Dn, SkyboxFt=SPACE.Ft,
        SkyboxLf=SPACE.Lf, SkyboxRt=SPACE.Rt, SkyboxUp=SPACE.Up,
        StarCount=6000, SunAngularSize=12, MoonAngularSize=12,
        CelestialBodiesShown=true, Parent=Lighting })
    atmosObj = mk("Atmosphere", { Name="VBB_Atmosphere", Density=0.35, Offset=0.2,
        Glare=0.4, Haze=1.2, Parent=Lighting })
    ccObj = mk("ColorCorrectionEffect", { Name="VBB_CC", Parent=Lighting })

    bset("ClockTime", 0)
    if name == "Deep Space" then
        bset("Ambient", Color3.fromRGB(24,26,45))
        atmosObj.Color=Color3.fromRGB(20,24,60); atmosObj.Decay=Color3.fromRGB(30,40,90)
        ccObj.TintColor=Color3.fromRGB(210,220,255)
    elseif name == "Purple Nebula" then
        bset("Ambient", Color3.fromRGB(40,25,70))
        atmosObj.Color=Color3.fromRGB(60,30,110); atmosObj.Decay=Color3.fromRGB(120,60,200)
        ccObj.TintColor=Color3.fromRGB(200,170,255); ccObj.Saturation=0.3
    elseif name == "Blood Moon" then
        bset("Ambient", Color3.fromRGB(50,22,22))
        atmosObj.Color=Color3.fromRGB(90,20,20); atmosObj.Decay=Color3.fromRGB(180,50,40)
        ccObj.TintColor=Color3.fromRGB(255,190,180)
    elseif name == "Midnight" then
        bset("Ambient", Color3.fromRGB(18,18,30))
        atmosObj.Color=Color3.fromRGB(10,10,20); atmosObj.Decay=Color3.fromRGB(15,15,35)
        ccObj.TintColor=Color3.fromRGB(190,200,230)
    end

    protect(skyObj); protect(atmosObj); protect(ccObj)
end

-- guard: вернуть небо если античит снёс
task.spawn(function()
    while true do
        task.wait(1.5)
        if Bypass.enabled and Flags.Sky ~= "Default" then
            if not skyObj or not skyObj.Parent then buildSky(Flags.Sky) end
        end
    end
end)

local auraEmitter
local function applyParticles(state)
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if state then
        if auraEmitter then unprotect(auraEmitter); auraEmitter:Destroy() end
        auraEmitter = mk("ParticleEmitter", { Name="VBB_Aura", Texture="rbxassetid://243098098",
            Color=ColorSequence.new(Flags.ParticleColor), Size=NumberSequence.new(0.5,0),
            Transparency=NumberSequence.new(0.2,1), Lifetime=NumberRange.new(0.6,1.1),
            Rate=40, Speed=NumberRange.new(0,3), SpreadAngle=Vector2.new(180,180),
            LightEmission=1, LightInfluence=0, ZOffset=1, Parent=root })
        protect(auraEmitter)
    else
        if auraEmitter then unprotect(auraEmitter); auraEmitter:Destroy(); auraEmitter=nil end
    end
end

Dropdown(VisualTab, "Небо", "Sky", { "Default","Deep Space","Purple Nebula","Blood Moon","Midnight" }, "Default",
    function(v) buildSky(v); Notify("Небо", v, 2) end)
Section(VisualTab, "Партиклы")
Toggle(VisualTab, "Аура персонажа", "Particles", false, function(s) applyParticles(s) end)

--============================================================
--  FOV / FPS / FULLBRIGHT
--============================================================
local function applyFPS(state)
    if state then
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
        bset("GlobalShadows", false)
        bset("FogEnd", 1e6)
        for _, v in ipairs(Workspace:GetDescendants()) do
            if v:IsA("ParticleEmitter") and v.Name ~= "VBB_Aura" then v.Enabled = false
            elseif v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then v.Enabled = false end
        end
        for _, v in ipairs(Lighting:GetChildren()) do
            if v:IsA("BlurEffect") or v:IsA("BloomEffect") or v:IsA("SunRaysEffect") or v:IsA("DepthOfFieldEffect") then
                v.Enabled = false end
        end
    else
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
        Lighting.GlobalShadows = PROPS.GlobalShadows ~= nil and PROPS.GlobalShadows or true
        Lighting.FogEnd = PROPS.FogEnd or 1e6
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
        bset("Ambient", Color3.fromRGB(178,178,178))
        bset("OutdoorAmbient", Color3.fromRGB(178,178,178))
        bset("Brightness", 3)
        bset("ClockTime", 14)
        if not fbCC then
            fbCC = mk("ColorCorrectionEffect", { Name="VBB_FB", Brightness=0.08, Contrast=0.05, Parent=Lighting })
            protect(fbCC)
        end
    else
        if fbCC then unprotect(fbCC); fbCC:Destroy(); fbCC=nil end
    end
end

RunService.RenderStepped:Connect(function()
    if Flags.FOVEnabled and Camera then Camera.FieldOfView = Flags.FOV end
end)

Section(PerfTab, "Камера")
Toggle(PerfTab, "Кастомный FOV", "FOVEnabled", false)
Slider(PerfTab, "Значение FOV", "FOV", 40, 130, 90, 0)
Section(PerfTab, "Производительность")
Toggle(PerfTab, "FPS Boost", "FPSBoost", false, function(s) applyFPS(s); Notify("FPS Boost", s and "вкл" or "выкл", 2) end)
Toggle(PerfTab, "Fullbright", "Fullbright", false, function(s) applyFullbright(s) end)

--============================================================
--  MISC / BYPASS
--============================================================
Section(MiscTab, "Anti-Cheat Bypass")
Toggle(MiscTab, "Bypass (античит)", "Bypass", false, function(s) Notify("Bypass", s and "активен" or "выкл", 2) end)
Toggle(MiscTab, "Прятать объекты (Lighting/персонаж)", "HookInstances", true)
Toggle(MiscTab, "Подменять свойства Lighting", "HookProps", true)
Slider(MiscTab, "WalkSpeed", "WalkSpeed", 16, 200, 16, 0)
Slider(MiscTab, "JumpPower", "JumpPower", 50, 300, 50, 0)
Button(MiscTab, "Переустановить хук", function()
    removeBypass()
    if installBypass() then Notify("Хук", "переустановлен", 2) else Notify("Хук", "ошибка установки", 3) end
end)
Button(MiscTab, "Сбросить небо (panic)", function()
    clearSky(); restoreLighting(); Notify("Panic", "небо сброшено", 2) end)

local statLabel = Label(MiscTab, "…")
task.spawn(function()
    while true do
        task.wait(0.5)
        local n = 0; for _ in pairs(PROTECT) do n = n + 1 end
        statLabel.Text = string.format("Хук: %s | Защищено: %d | Свойств: %d",
            Bypass.installed and "активен" or "нет", n, (function() local c=0; for _ in pairs(PROPS) do c=c+1 end; return c end)())
    end
end)

-- движение (bypass)
RunService.Heartbeat:Connect(function()
    if not Flags.Bypass then return end
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if math.abs(hum.WalkSpeed - Flags.WalkSpeed) > 0.5 then hum.WalkSpeed = Flags.WalkSpeed end
    if math.abs(hum.JumpPower - Flags.JumpPower) > 0.5 then hum.JumpPower = Flags.JumpPower end
    hum.UseJumpPower = true
    if Flags.CustomPhys then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then root.CustomPhysicalProperties = PhysicalProperties.new(0.7,0.3,0.5,1,1) end
    end
end)

LP.Idled:Connect(function()
    pcall(function()
        VirtualUser:Button2Down(Vector2.new(0,0)); task.wait(0.05); VirtualUser:Button2Up(Vector2.new(0,0)) end)
end)

--============================================================
--  RESPAWN / MIN / CLOSE / KEYBIND
--============================================================
LP.CharacterAdded:Connect(function()
    task.wait(0.7)
    if Flags.Headless then applyHeadless(true) end
    if Flags.Korblox then applyKorblox(true) end
    if Flags.Particles then applyParticles(true) end
end)

local minimized = false
local Icon = mk("TextButton", { Text="VB", Font=Enum.Font.GothamBold, TextSize=12, TextColor3=T.Text,
    BackgroundColor3=T.BG, BorderSizePixel=0, AutoButtonColor=false, Size=UDim2.fromOffset(44,44),
    Position=UDim2.new(0,20,0,20), Visible=false, Parent=Gui })
mk("UICorner", { CornerRadius=UDim.new(1,0), Parent=Icon })
mk("UIStroke", { Color=T.Accent, Thickness=1.5, Parent=Icon })

local function setMinimize(state)
    minimized = state
    if state then
        tw(Root,0.25,{Size=UDim2.fromOffset(0,0)},Enum.EasingStyle.Quart,Enum.EasingDirection.In)
        task.wait(0.1); Root.Visible=false; Icon.Visible=true
        tw(Icon,0.25,{Size=UDim2.fromOffset(44,44)},Enum.EasingStyle.Back,Enum.EasingDirection.Out)
    else
        Icon.Visible=false; Root.Visible=true; Root.Size=UDim2.fromOffset(0,0)
        tw(Root,0.35,{Size=UDim2.fromOffset(680,440)},Enum.EasingStyle.Back,Enum.EasingDirection.Out)
    end
end

MinBtn.MouseButton1Click:Connect(function() setMinimize(true) end)
Icon.MouseButton1Click:Connect(function() setMinimize(false) end)
CloseBtn.MouseButton1Click:Connect(function()
    tw(Root,0.25,{Size=UDim2.fromOffset(0,0)},Enum.EasingStyle.Back,Enum.EasingDirection.In)
    task.wait(0.28)
    Gui.Enabled=false; NotifyGui.Enabled=false
end)

UserInputService.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.RightShift then
        if Gui.Enabled then setMinimize(not minimized)
        else Gui.Enabled=true; NotifyGui.Enabled=true; setMinimize(false) end
    end
end)

--========== INIT ==========
local okHook = installBypass()
SelectTab("Combat")
Notify("Venice • Blade Ball", "v3 загружено. Хук: "..(okHook and "OK" or "ОШИБКА"), 4)

if getgenv then
    getgenv().VeniceBB = function()
        pcall(function()
            removeBypass()
            Gui:Destroy(); NotifyGui:Destroy()
            if ringInner then ringInner:Destroy() end
            if ringOuter then ringOuter:Destroy() end
            clearSky(); restoreLighting()
            if fbCC then fbCC:Destroy() end
            if auraEmitter then auraEmitter:Destroy() end
        end)
        getgenv().VeniceBB = nil
    end
end
