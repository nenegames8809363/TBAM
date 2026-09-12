--// =========================================================
--// FPS DESTROYER - GLASS ULTIMATE (AERO ZOMBIE EDITION 🥔)
--// Mobile FPS Optimizer
--// Players + Render + Extras + Culling + Auto Optimizer + NUKE
--// =========================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--============================================================
-- CONFIG (AERO GLASS AESTHETIC)
--============================================================

local GUI_NAME = "FPSDestroyerGlassUltimate"

local PLAYER_CULL_DISTANCE = 70
local PLAYER_CULL_CHECK_RATE = 0.15

local COLORS = {
    Background = Color3.fromRGB(15, 20, 30),
    Card = Color3.fromRGB(255, 255, 255),
    Card2 = Color3.fromRGB(255, 255, 255),
    Accent = Color3.fromRGB(0, 170, 255),
    Accent2 = Color3.fromRGB(120, 200, 255),

    Text = Color3.fromRGB(255, 255, 255),
    SubText = Color3.fromRGB(200, 210, 220),

    Green = Color3.fromRGB(70, 225, 140),
    Yellow = Color3.fromRGB(255, 205, 80),
    Red = Color3.fromRGB(255, 90, 95)
}

local TWEEN_FAST = TweenInfo.new(0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TWEEN_SMOOTH = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TWEEN_SPRING = TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

--============================================================
-- REMOVE OLD GUI
--============================================================
pcall(function()
    local Old = PlayerGui:FindFirstChild(GUI_NAME)
    if Old then Old:Destroy() end
end)

--============================================================
-- GUI BASE (VIDRO PURO)
--============================================================
local GUI = Instance.new("ScreenGui")
GUI.Name = GUI_NAME
GUI.ResetOnSpawn = false
GUI.IgnoreGuiInset = true
GUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
GUI.Parent = PlayerGui

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.fromOffset(350, 510)
Main.Position = UDim2.new(0.5, -175, 0.5, -255)
Main.BackgroundColor3 = COLORS.Background
Main.BackgroundTransparency = 0.45 -- Efeito de Vidro
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = GUI

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 20)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(255, 255, 255)
MainStroke.Transparency = 0.7
MainStroke.Thickness = 1.5
MainStroke.Parent = Main

local MainGradient = Instance.new("UIGradient")
MainGradient.Rotation = 125
MainGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 150, 150))
})
MainGradient.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.8),
    NumberSequenceKeypoint.new(1, 0.95)
})
MainGradient.Parent = Main

local Scale = Instance.new("UIScale")
Scale.Scale = 0.88
Scale.Parent = Main
TweenService:Create(Scale, TWEEN_SPRING, {Scale = 1}):Play()

--============================================================
-- HEADER
--============================================================
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 72)
Header.BackgroundTransparency = 1
Header.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -125, 0, 30)
Title.Position = UDim2.fromOffset(18, 8)
Title.BackgroundTransparency = 1
Title.Text = "FPS DESTROYER"
Title.TextColor3 = COLORS.Text
Title.TextSize = 21
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header
local TS = Instance.new("UIStroke", Title) TS.Transparency = 0.5 TS.Thickness = 1

local Subtitle = Instance.new("TextLabel")
Subtitle.Size = UDim2.new(1, -125, 0, 20)
Subtitle.Position = UDim2.fromOffset(19, 37)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "AERO GLASS • ZOMBIE MODE"
Subtitle.TextColor3 = COLORS.SubText
Subtitle.TextSize = 9
Subtitle.Font = Enum.Font.GothamMedium
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.Parent = Header

local FPSLabel = Instance.new("TextLabel")
FPSLabel.Size = UDim2.fromOffset(72, 28)
FPSLabel.Position = UDim2.new(1, -118, 0, 18)
FPSLabel.BackgroundColor3 = COLORS.Card2
FPSLabel.BackgroundTransparency = 0.85
FPSLabel.Text = "FPS: --"
FPSLabel.TextColor3 = COLORS.Green
FPSLabel.TextSize = 10
FPSLabel.Font = Enum.Font.GothamBold
FPSLabel.Parent = Header
Instance.new("UIStroke", FPSLabel).Transparency = 0.8

local FPSCorner = Instance.new("UICorner")
FPSCorner.CornerRadius = UDim.new(0, 10)
FPSCorner.Parent = FPSLabel

local Minimize = Instance.new("TextButton")
Minimize.Size = UDim2.fromOffset(32, 32)
Minimize.Position = UDim2.new(1, -43, 0, 17)
Minimize.BackgroundColor3 = COLORS.Card2
Minimize.BackgroundTransparency = 0.85
Minimize.Text = "—"
Minimize.TextColor3 = COLORS.Text
Minimize.TextSize = 17
Minimize.Font = Enum.Font.GothamBold
Minimize.AutoButtonColor = false
Minimize.Parent = Header
Instance.new("UIStroke", Minimize).Transparency = 0.8

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 10)
MinCorner.Parent = Minimize

local Scroll = Instance.new("ScrollingFrame")
Scroll.Name = "Options"
Scroll.Size = UDim2.new(1, -20, 1, -84)
Scroll.Position = UDim2.fromOffset(10, 75)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 2
Scroll.ScrollBarImageColor3 = COLORS.Accent
Scroll.CanvasSize = UDim2.new()
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.Parent = Main

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 8)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = Scroll

local Padding = Instance.new("UIPadding")
Padding.PaddingLeft = UDim.new(0, 2)
Padding.PaddingRight = UDim.new(0, 2)
Padding.PaddingTop = UDim.new(0, 2)
Padding.PaddingBottom = UDim.new(0, 15)
Padding.Parent = Scroll

--============================================================
-- DRAG
--============================================================
local Dragging, DragStart, StartPosition
local function UpdateDrag(Input)
    local Delta = Input.Position - DragStart
    Main.Position = UDim2.new(StartPosition.X.Scale, StartPosition.X.Offset + Delta.X, StartPosition.Y.Scale, StartPosition.Y.Offset + Delta.Y)
end
Header.InputBegan:Connect(function(Input)
    if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
        Dragging = true
        DragStart = Input.Position
        StartPosition = Main.Position
        Input.Changed:Connect(function()
            if Input.UserInputState == Enum.UserInputState.End then Dragging = false end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(Input)
    if Dragging and (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch) then
        UpdateDrag(Input)
    end
end)

--============================================================
-- STATE STORAGE
--============================================================
local Original = {}
local function Save(Object, Property)
    if not Object then return end
    if not Original[Object] then Original[Object] = {} end
    if Original[Object][Property] ~= nil then return end
    pcall(function() Original[Object][Property] = Object[Property] end)
end

local function RestoreAll()
    for Object, Properties in pairs(Original) do
        if Object and Object.Parent then
            for Property, Value in pairs(Properties) do
                pcall(function() Object[Property] = Value end)
            end
        end
    end
end

--============================================================
-- BUTTON CREATOR
--============================================================
local function CreateButton(Name, Description)
    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(1, -4, 0, 60)
    Button.BackgroundColor3 = COLORS.Card
    Button.BackgroundTransparency = 0.9 -- Botões transparentinhos
    Button.BorderSizePixel = 0
    Button.AutoButtonColor = false
    Button.Text = ""
    Button.Parent = Scroll

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 14)
    Corner.Parent = Button

    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(255, 255, 255)
    Stroke.Transparency = 0.8
    Stroke.Thickness = 1
    Stroke.Parent = Button

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -72, 0, 23)
    Label.Position = UDim2.fromOffset(14, 8)
    Label.BackgroundTransparency = 1
    Label.Text = Name
    Label.TextColor3 = COLORS.Text
    Label.TextSize = 13
    Label.Font = Enum.Font.GothamBold
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Button

    local Desc = Instance.new("TextLabel")
    Desc.Size = UDim2.new(1, -72, 0, 20)
    Desc.Position = UDim2.fromOffset(14, 31)
    Desc.BackgroundTransparency = 1
    Desc.Text = Description
    Desc.TextColor3 = COLORS.SubText
    Desc.TextSize = 9
    Desc.Font = Enum.Font.Gotham
    Desc.TextXAlignment = Enum.TextXAlignment.Left
    Desc.Parent = Button

    local Status = Instance.new("TextLabel")
    Status.Size = UDim2.fromOffset(47, 25)
    Status.Position = UDim2.new(1, -58, 0.5, -12)
    Status.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Status.BackgroundTransparency = 0.9
    Status.Text = "OFF"
    Status.TextColor3 = COLORS.SubText
    Status.TextSize = 9
    Status.Font = Enum.Font.GothamBold
    Status.Parent = Button

    local StatusCorner = Instance.new("UICorner")
    StatusCorner.CornerRadius = UDim.new(1, 0)
    StatusCorner.Parent = Status
    Instance.new("UIStroke", Status).Transparency = 0.8

    Button.MouseEnter:Connect(function()
        TweenService:Create(Button, TWEEN_FAST, {BackgroundTransparency = 0.8}):Play()
        TweenService:Create(Stroke, TWEEN_FAST, {Transparency = 0.5}):Play()
    end)
    Button.MouseLeave:Connect(function()
        TweenService:Create(Button, TWEEN_FAST, {BackgroundTransparency = 0.9}):Play()
        TweenService:Create(Stroke, TWEEN_FAST, {Transparency = 0.8}):Play()
    end)
    Button.MouseButton1Down:Connect(function()
        TweenService:Create(Button, TweenInfo.new(0.06, Enum.EasingStyle.Quad), {Size = UDim2.new(1, -9, 0, 56)}):Play()
    end)
    Button.MouseButton1Up:Connect(function()
        TweenService:Create(Button, TWEEN_FAST, {Size = UDim2.new(1, -4, 0, 60)}):Play()
    end)

    return Button, Status
end

local function SetStatus(Status, Enabled)
    if Enabled then
        Status.Text = "ON"
        Status.TextColor3 = COLORS.Green
        TweenService:Create(Status, TWEEN_FAST, {BackgroundTransparency = 0.7, BackgroundColor3 = Color3.fromRGB(25, 75, 52)}):Play()
    else
        Status.Text = "OFF"
        Status.TextColor3 = COLORS.SubText
        TweenService:Create(Status, TWEEN_FAST, {BackgroundTransparency = 0.9, BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
    end
end

--============================================================
-- OPTIMIZATION FUNCTIONS
--============================================================
local function DisableFog()
    Save(Lighting, "FogStart")
    Save(Lighting, "FogEnd")
    Lighting.FogStart = 9e9
    Lighting.FogEnd = 9e9
    for _, Object in ipairs(Lighting:GetChildren()) do
        if Object:IsA("Atmosphere") then
            Save(Object, "Density")
            Save(Object, "Haze")
            Save(Object, "Glare")
            Object.Density = 0
            Object.Haze = 0
            Object.Glare = 0
        end
    end
end

local function DisableShadows()
    Save(Lighting, "GlobalShadows")
    Lighting.GlobalShadows = false
    for _, Object in ipairs(Workspace:GetDescendants()) do
        if Object:IsA("BasePart") then
            Save(Object, "CastShadow")
            Object.CastShadow = false
        end
    end
end

local function DisableLightShadows()
    for _, Object in ipairs(Lighting:GetChildren()) do
        if Object:IsA("PointLight") or Object:IsA("SpotLight") or Object:IsA("SurfaceLight") then
            Save(Object, "Shadows")
            pcall(function() Object.Shadows = false end)
        end
    end
end

local function DisablePostFX()
    for _, Object in ipairs(Lighting:GetChildren()) do
        if Object:IsA("PostEffect") then
            Save(Object, "Enabled")
            Object.Enabled = false
        end
    end
end

local function OptimizeParticles()
    for _, Object in ipairs(Workspace:GetDescendants()) do
        if Object:IsA("ParticleEmitter") or Object:IsA("Trail") or Object:IsA("Beam") or Object:IsA("Smoke") or Object:IsA("Fire") or Object:IsA("Sparkles") then
            Save(Object, "Enabled")
            Object.Enabled = false
        end
    end
end

local function OptimizeMeshes()
    for _, Object in ipairs(Workspace:GetDescendants()) do
        if Object:IsA("MeshPart") then
            Save(Object, "RenderFidelity")
            pcall(function() Object.RenderFidelity = Enum.RenderFidelity.Performance end)
        end
    end
end

local function PlasticMode()
    for _, Object in ipairs(Workspace:GetDescendants()) do
        if Object:IsA("BasePart") then
            Save(Object, "Material")
            Save(Object, "Reflectance")
            Object.Material = Enum.Material.SmoothPlastic
            Object.Reflectance = 0
        end
    end
end

local function TerrainLow()
    local Terrain = Workspace:FindFirstChildOfClass("Terrain")
    if not Terrain then return end
    Save(Terrain, "Decoration")
    Save(Terrain, "GrassLength")
    pcall(function() Terrain.Decoration = false end)
    pcall(function() Terrain.GrassLength = 0 end)
end

--============================================================
-- SUPER NUKE (CINZA DEPRESSÃO)
--============================================================
local NukeAtivo = false

local function TransformarEmArgila(Char)
    if not Char then return end
    for _, v in pairs(Char:GetDescendants()) do
        if v:IsA("Shirt") or v:IsA("Pants") or v:IsA("ShirtGraphic") or v:IsA("CharacterMesh") or v:IsA("Accessory") or v:IsA("Decal") then
            pcall(function() v:Destroy() end)
        elseif v:IsA("BasePart") then
            pcall(function()
                v.Material = Enum.Material.SmoothPlastic
                v.Color = Color3.fromRGB(150, 150, 150) -- Fica tudo cinza kkkkkk
            end)
        end
    end
end

local function NukeTexturesAndClothes()
    NukeAtivo = true
    -- Texturas do mundo
    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("Texture") or v:IsA("Decal") or v:IsA("SurfaceAppearance") then
            pcall(function() v:Destroy() end)
        end
    end
    -- Players atuais
    for _, p in pairs(Players:GetPlayers()) do
        TransformarEmArgila(p.Character)
    end
end

--============================================================
-- PLAYERS CULLING & ANIMATIONS
--============================================================
local PlayersOptimizationEnabled = false
local PlayerOriginal = {}

local function SavePlayerObject(Object, Property)
    if not PlayerOriginal[Object] then PlayerOriginal[Object] = {} end
    if PlayerOriginal[Object][Property] ~= nil then return end
    pcall(function() PlayerOriginal[Object][Property] = Object[Property] end)
end

local function DisablePlayerAnimations(Character)
    if not Character then return end
    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    if Humanoid then
        local Animator = Humanoid:FindFirstChildOfClass("Animator")
        if Animator then pcall(function() Animator:Destroy() end) end
    end
    local Animate = Character:FindFirstChild("Animate")
    if Animate then pcall(function() Animate:Destroy() end) end
end

local function HidePlayerCharacter(Character, Hidden)
    if not Character then return end
    for _, Object in ipairs(Character:GetDescendants()) do
        if Object:IsA("BasePart") then
            if PlayerOriginal[Object] == nil then PlayerOriginal[Object] = {} end
            if PlayerOriginal[Object].LocalTransparencyModifier == nil then
                PlayerOriginal[Object].LocalTransparencyModifier = Object.LocalTransparencyModifier
            end
            Object.LocalTransparencyModifier = Hidden and 1 or (PlayerOriginal[Object].LocalTransparencyModifier or 0)
        end
    end
end

local function OptimizePlayers()
    for _, OtherPlayer in ipairs(Players:GetPlayers()) do
        if OtherPlayer ~= LocalPlayer and OtherPlayer.Character then
            DisablePlayerAnimations(OtherPlayer.Character)
        end
    end
end

local function RenderCulling()
    -- Render loop for culling done safely later if needed, script structure kept intact
end

local function DestroyGraphics()
    Lighting.GlobalShadows = false
    Lighting.FogStart = 9e9
    Lighting.FogEnd = 9e9
    DisablePostFX()
    DisableShadows()
    OptimizeParticles()
    OptimizeMeshes()
    TerrainLow()
    PlasticMode()
    DisableLightShadows()
end

local function UltraFPS()
    DestroyGraphics()
    OptimizePlayers()
    NukeTexturesAndClothes()
    PlayersOptimizationEnabled = true
end

--============================================================
-- NEW PLAYERS OVERRIDE (CORREÇÃO DE RESPAWN E ENTRADAS)
--============================================================
-- Aplica o efeito assim que os desgraçados nascerem ou renascerem
for _, p in pairs(Players:GetPlayers()) do
    p.CharacterAdded:Connect(function(Character)
        task.wait(0.3) -- Espera carregar a merda toda
        if PlayersOptimizationEnabled then DisablePlayerAnimations(Character) end
        if NukeAtivo then TransformarEmArgila(Character) end
    end)
end

Players.PlayerAdded:Connect(function(NewPlayer)
    NewPlayer.CharacterAdded:Connect(function(Character)
        task.wait(0.3)
        if PlayersOptimizationEnabled then DisablePlayerAnimations(Character) end
        if NukeAtivo then TransformarEmArgila(Character) end
    end)
end)

--============================================================
-- BUTTONS SETUP
--============================================================
local B1,S1 = CreateButton("🔥 DESTRUIR GRÁFICOS", "Modo agressivo sem apagar iluminação")
local B2,S2 = CreateButton("🌫️ DESATIVAR FOG", "Remove neblina e mantém o mapa")
local B3,S3 = CreateButton("✨ DELETAR EFEITOS", "Partículas, beams, trails, fumaça...")
local B4,S4 = CreateButton("🧱 MODO PLÁSTICO", "SmoothPlastic + reflectance 0")
local B5,S5 = CreateButton("🌑 SOMBRAS OFF", "Desativa sombras das peças")
local B6,S6 = CreateButton("🎞️ POST FX OFF", "Bloom, DOF, SunRays, ColorCorrection...")
local B7,S7 = CreateButton("🧩 MESH PERFORMANCE", "RenderFidelity no modo Performance")
local B8,S8 = CreateButton("🌱 TERRAIN LOW", "Reduz grama e decoração")
local B10,S10 = CreateButton("👤 PLAYERS ESTATUAS", "Desativa animações de geral")
local B18,S18 = CreateButton("☢️ ARGILA NUKE", "Arranca texturas e pinta de cinza PRA SEMPRE")
local B15,S15 = CreateButton("💀 ULTRA FPS", "ATIVA TUDO DE UMA VEZ")

B1.MouseButton1Click:Connect(function() DestroyGraphics() SetStatus(S1,true) end)
B2.MouseButton1Click:Connect(function() DisableFog() SetStatus(S2,true) end)
B3.MouseButton1Click:Connect(function() OptimizeParticles() SetStatus(S3,true) end)
B4.MouseButton1Click:Connect(function() PlasticMode() SetStatus(S4,true) end)
B5.MouseButton1Click:Connect(function() DisableShadows() SetStatus(S5,true) end)
B6.MouseButton1Click:Connect(function() DisablePostFX() SetStatus(S6,true) end)
B7.MouseButton1Click:Connect(function() OptimizeMeshes() SetStatus(S7,true) end)
B8.MouseButton1Click:Connect(function() TerrainLow() SetStatus(S8,true) end)
B10.MouseButton1Click:Connect(function() PlayersOptimizationEnabled = true OptimizePlayers() SetStatus(S10,true) end)
B18.MouseButton1Click:Connect(function() NukeTexturesAndClothes() SetStatus(S18,true) end)
B15.MouseButton1Click:Connect(function() 
    UltraFPS() 
    SetStatus(S1,true) SetStatus(S5,true) SetStatus(S6,true) SetStatus(S7,true) 
    SetStatus(S8,true) SetStatus(S10,true) SetStatus(S15,true) SetStatus(S18,true)
end)

--============================================================
-- AUTO OPTIMIZER REAL-TIME
--============================================================
local AutoOptimizer = false
Workspace.DescendantAdded:Connect(function(Object)
    if not AutoOptimizer then return end
    task.wait()
    if Object:IsA("ParticleEmitter") or Object:IsA("Trail") or Object:IsA("Smoke") or Object:IsA("Fire") then
        Object.Enabled = false
    elseif Object:IsA("BasePart") then
        Object.CastShadow = false
    elseif Object:IsA("Texture") or Object:IsA("Decal") then
        pcall(function() Object:Destroy() end)
    end
end)

local B17,S17 = CreateButton("⚡ AUTO OPTIMIZER", "Apaga lixo novo gerado em tempo real")
B17.MouseButton1Click:Connect(function()
    AutoOptimizer = not AutoOptimizer
    SetStatus(S17,AutoOptimizer)
end)

--============================================================
-- WINDOW MINIMIZE & FPS
--============================================================
local Minimized = false
local ExpandedSize = UDim2.fromOffset(350,510)
local MinimizedSize = UDim2.fromOffset(350,72)

Minimize.MouseButton1Click:Connect(function()
    Minimized = not Minimized
    if Minimized then
        TweenService:Create(Main, TWEEN_SMOOTH, {Size = MinimizedSize}):Play()
        Minimize.Text = "+"
    else
        TweenService:Create(Main, TWEEN_SMOOTH, {Size = ExpandedSize}):Play()
        Minimize.Text = "—"
    end
end)

local Frames, LastTime = 0, os.clock()
RunService.RenderStepped:Connect(function()
    Frames += 1
    local Now = os.clock()
    if Now - LastTime >= 0.5 then
        local FPS = math.floor(Frames / (Now - LastTime))
        FPSLabel.Text = "FPS: " .. FPS
        if FPS >= 55 then FPSLabel.TextColor3 = COLORS.Green
        elseif FPS >= 30 then FPSLabel.TextColor3 = COLORS.Yellow
        else FPSLabel.TextColor3 = COLORS.Red end
        Frames = 0; LastTime = Now
    end
end)
