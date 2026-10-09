-- SillyCat Hub | Real Desync V10 (Za Warudo Edition)
-- by Boykisser / SillyCat

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "SillyCat Hub | Real Desync V10",
    LoadingTitle = "SillyCat - Sistema Za Warudo",
    LoadingSubtitle = "by Boykisser",
    ConfigurationSaving = { Enabled = false },
    Discord = { Enabled = false, Invite = "noinvitelink", RememberJoins = true },
    KeySystem = false
})

local Tab = Window:CreateTab("Real Desync 👻", 4483362458)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local ICON = 4483362458

-- Se o tic-tac não tocar, troca por qualquer rbxassetid de tic-tac
local TICK_SOUND_ID = "rbxassetid://8966275754"

-- Estado do desync
local active = false
local originalCFrame = nil
local clone, cloneHum, cloneRoot = nil, nil, nil
local moveConn, jumpConn = nil, nil

-- Efeitos visuais/sonoros
local fx = { gui = nil, tint = nil, cc = nil, tick = nil }

-- Módulo de controle oficial (joystick/teclado/touch)
local controls = nil
pcall(function()
    local ps = LocalPlayer:WaitForChild("PlayerScripts", 5)
    local pm = ps:WaitForChild("PlayerModule", 5)
    controls = require(pm):GetControls()
end)

local function notify(title, content, duration)
    Rayfield:Notify({
        Title = title,
        Content = content,
        Duration = duration or 3,
        Image = ICON
    })
end

local function tween(obj, time, props, style, dir)
    local t = TweenService:Create(
        obj,
        TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
        props
    )
    t:Play()
    return t
end

local function getGuiParent()
    local ok, hui = pcall(function() return gethui() end)
    if ok and typeof(hui) == "Instance" then
        return hui
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

-- Remove todos os efeitos visuais e sonoros
local function stopEffects(fade)
    local gui, cc, tick = fx.gui, fx.cc, fx.tick
    fx.gui, fx.cc, fx.tick, fx.tint = nil, nil, nil, nil

    if tick then
        if fade then
            tween(tick, 0.6, { Volume = 0 }).Completed:Connect(function()
                tick:Destroy()
            end)
        else
            tick:Destroy()
        end
    end

    if cc then
        if fade then
            tween(cc, 0.6, { Saturation = 0, TintColor = Color3.new(1, 1, 1) }).Completed:Connect(function()
                cc:Destroy()
            end)
        else
            cc:Destroy()
        end
    end

    if gui then
        if fade then
            task.delay(0.7, function()
                gui:Destroy()
            end)
        else
            gui:Destroy()
        end
    end
end

-- Efeito Za Warudo: círculo preto expande, cobre a tela, depois vira amarelo + tic-tac
local function playZaWarudoEffect()
    stopEffects(false)

    local camera = workspace.CurrentCamera
    local vp = camera.ViewportSize

    local gui = Instance.new("ScreenGui")
    gui.Name = "SillyCat_ZaWarudo"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999
    gui.Parent = getGuiParent()

    -- Camada amarela (começa invisível)
    local tint = Instance.new("Frame")
    tint.Size = UDim2.fromScale(1, 1)
    tint.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
    tint.BackgroundTransparency = 1
    tint.BorderSizePixel = 0
    tint.Parent = gui

    -- Círculo preto que expande (Iris-Out)
    local circle = Instance.new("Frame")
    circle.AnchorPoint = Vector2.new(0.5, 0.5)
    circle.Position = UDim2.fromScale(0.5, 0.5)
    circle.Size = UDim2.fromOffset(0, 0)
    circle.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
    circle.BorderSizePixel = 0
    circle.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = circle

    -- Filtro de cor no mundo (amarelado e um pouco sem saturação)
    local cc = Instance.new("ColorCorrectionEffect")
    cc.TintColor = Color3.fromRGB(255, 225, 120)
    cc.Saturation = 0
    cc.Contrast = 0.1
    cc.Parent = Lighting

    -- Tic-tac de fundo
    local tick = Instance.new("Sound")
    tick.Name = "SillyCat_Tick"
    tick.SoundId = TICK_SOUND_ID
    tick.Volume = 0
    tick.Looped = true
    tick.PlaybackSpeed = 0.9
    tick.Parent = SoundService
    tick:Play()
    tween(tick, 0.8, { Volume = 0.35 })

    fx.gui, fx.tint, fx.cc, fx.tick = gui, tint, cc, tick

    -- Diagonal da tela para o círculo cobrir tudo
    local diag = math.sqrt(vp.X ^ 2 + vp.Y ^ 2) * 1.1

    local expand = tween(circle, 0.9, {
        Size = UDim2.fromOffset(diag, diag)
    }, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

    -- Quando a tela estiver preta, o círculo some e fica o amarelo
    expand.Completed:Connect(function()
        if not circle.Parent then return end
        tween(circle, 0.5, { BackgroundTransparency = 1 })
        tween(tint, 0.6, { BackgroundTransparency = 0.45 })
        if fx.cc then
            tween(fx.cc, 0.6, { Saturation = -0.35 })
        end
    end)
end

-- Cria o clone móvel (local, só você vê)
local function createClone(char)
    char.Archivable = true
    local ok, c = pcall(function()
        return char:Clone()
    end)
    if not ok or not c then return nil end

    c.Name = "SillyCat_ZaWarudoController"

    for _, obj in ipairs(c:GetDescendants()) do
        if obj:IsA("Script") or obj:IsA("LocalScript") then
            obj:Destroy()
        elseif obj:IsA("BasePart") then
            obj.Anchored = false
            obj.CanCollide = true
            obj.Transparency = (obj.Name == "HumanoidRootPart") and 1 or 0
            obj.LocalTransparencyModifier = 0
        end
    end

    c.Parent = workspace
    return c
end

-- Deixa o corpo real translúcido só pra você
local function setRealBodyGhost(char, on)
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.LocalTransparencyModifier = on and 0.5 or 0
        end
    end
end

local function startDesync()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if not root or not hum or hum.Health <= 0 then
        notify("Erro de Estado", "Personagem não encontrado!")
        return false
    end

    -- Cria o clone ANTES de deixar o corpo real translúcido (senão o clone herdava a transparência)
    local newClone = createClone(char)
    if not newClone then
        notify("Erro", "Não consegui clonar o personagem.")
        return false
    end

    clone = newClone
    cloneHum = clone:FindFirstChildOfClass("Humanoid")
    cloneRoot = clone:FindFirstChild("HumanoidRootPart")

    if not cloneHum or not cloneRoot then
        clone:Destroy()
        clone = nil
        notify("Erro", "Clone sem Humanoid/HumanoidRootPart.")
        return false
    end

    clone:PivotTo(root.CFrame)

    active = true
    originalCFrame = root.CFrame

    -- Congela o corpo real
    root.Anchored = true
    setRealBodyGhost(char, true)

    -- Câmera segue o clone
    workspace.CurrentCamera.CameraSubject = cloneHum

    playZaWarudoEffect()

    -- Movimento via joystick/teclado/touch
    moveConn = RunService.RenderStepped:Connect(function()
        if not active or not cloneHum or not cloneHum.Parent then return end
        local move = controls and controls:GetMoveVector() or Vector3.zero
        cloneHum:Move(move, true)
    end)

    -- Pulo (mobile e teclado)
    jumpConn = UserInputService.JumpRequest:Connect(function()
        if active and cloneHum and cloneHum.Parent then
            cloneHum.Jump = true
        end
    end)

    notify("ZA WARUDO!", "O tempo parou. Vá pegar os desavisados!", 4)
    return true
end

-- Encerra o desync
-- snapToClone = true -> teleporta o corpo real pra posição do clone (Snap Back)
-- snapToClone = false -> volta pro lugar onde o tempo parou
local function stopDesync(snapToClone)
    if not active then return end
    active = false

    if moveConn then moveConn:Disconnect() moveConn = nil end
    if jumpConn then jumpConn:Disconnect() jumpConn = nil end

    local targetCFrame = nil
    if snapToClone and clone and clone.Parent then
        targetCFrame = clone:GetPivot()
    end

    if clone then
        clone:Destroy()
        clone = nil
        cloneHum = nil
        cloneRoot = nil
    end

    local char = LocalPlayer.Character
    if char then
        setRealBodyGhost(char, false)

        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            root.Anchored = false
            if targetCFrame then
                char:PivotTo(targetCFrame)
            elseif originalCFrame then
                char:PivotTo(originalCFrame)
            end
        end

        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            workspace.CurrentCamera.CameraSubject = hum
        end
    end

    originalCFrame = nil
    stopEffects(true)
end

-- Morreu ou resetou: limpa tudo e desliga o toggle
LocalPlayer.CharacterRemoving:Connect(function()
    stopDesync(false)
end)

local DesyncToggle
DesyncToggle = Tab:CreateToggle({
    Name = "Ativar Za Warudo Desync (V10)",
    CurrentValue = false,
    Flag = "DesyncToggle",
    Callback = function(value)
        if value then
            if active then return end
            if not startDesync() then
                pcall(function() DesyncToggle:Set(false) end)
            end
        else
            if active then
                stopDesync(false)
                notify("Tempo Retomado", "Você voltou pro ponto onde o tempo parou.", 3)
            end
        end
    end,
})

Tab:CreateButton({
    Name = "⚡ Snap Back (Teleporta pro clone)",
    Callback = function()
        if active then
            stopDesync(true)
            pcall(function() DesyncToggle:Set(false) end)
            notify("Snap Back!", "Tempo retomado na sua nova posição!", 3)
        else
            notify("Aviso", "Ative o Za Warudo primeiro!", 3)
        end
    end,
})

notify("SillyCat Hub V10 Carregado", "Modo Cinematográfico pronto pro Delta.", 5)