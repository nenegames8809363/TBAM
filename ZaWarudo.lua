-- SillyCat Hub | Real Desync V16 (Za Warudo Edition + Air Walk no Clone)
-- by Boykisser / SillyCat

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "SillyCat Hub | Real Desync V16",
    LoadingTitle = "SillyCat - Sistema Za Warudo",
    LoadingSubtitle = "by Boykisser",
    ShowText = "SillyCat",
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
local Debris = game:GetService("Debris")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local ICON = 4483362458

-- ===== CONFIG =====
local TICK_SOUND_ID = "rbxassetid://8966275754"   -- tic-tac do Za Warudo
local ZA_WARUDO_VOICE_ID = ""                     -- COLOCA AQUI o ID da voz (ex: "rbxassetid://123456")
local CHAT_MESSAGE = "ZA WARUDO!"                 -- o que o player fala no chat
local AIRWALK_SIZE = Vector3.new(10, 1, 10)
local MINIMIZE_MENU_ON_TOGGLE = true              -- minimiza o menu ao ligar/desligar o Za Warudo

-- ===== ESTADO =====
local active = false
local originalCFrame = nil
local clone, cloneHum, cloneRoot = nil, nil, nil
local lastClonePivot = nil   -- última posição conhecida do clone (usada no renascimento)
local moveConn, jumpConn = nil, nil
local menuMinimized = false
local pendingSnap = nil      -- CFrame onde o próximo personagem real deve renascer

-- Air Walk
local airWalkPart = nil
local airWalkConn = nil
local platformTopY = nil
local lastMoverRoot = nil
local footOffset = 3

-- Efeitos visuais/sonoros
local fx = { gui = nil, tint = nil, cc = nil, tick = nil }

-- Módulo de controle oficial (joystick/teclado/touch)
local controls = nil
pcall(function()
    local ps = LocalPlayer:WaitForChild("PlayerScripts", 5)
    local pm = ps:WaitForChild("PlayerModule", 5)
    controls = require(pm):GetControls()
end)

-- ===== UTILIDADES =====
local function notify(title, content, duration)
    pcall(function()
        Rayfield:Notify({
            Title = title,
            Content = content,
            Duration = duration or 3,
            Image = ICON
        })
    end)
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

-- Acha o ScreenGui do Rayfield
local function findRayfieldGui()
    local containers = { CoreGui, LocalPlayer:FindFirstChild("PlayerGui") }
    local ok, hui = pcall(function() return gethui() end)
    if ok and typeof(hui) == "Instance" then
        table.insert(containers, hui)
    end
    for _, container in ipairs(containers) do
        if container then
            for _, gui in ipairs(container:GetChildren()) do
                if gui:IsA("ScreenGui") and gui.Name == "Rayfield" then
                    return gui
                end
            end
        end
    end
    return nil
end

-- Procura o botão de minimizar da barra do Rayfield pelo nome
local function findMinimizeButton()
    local rf = findRayfieldGui()
    if not rf then return nil end
    for _, obj in ipairs(rf:GetDescendants()) do
        if obj:IsA("GuiButton") then
            local n = string.lower(obj.Name)
            if string.find(n, "minim") or string.find(n, "hide") then
                return obj
            end
        end
    end
    return nil
end

-- Minimiza o menu usando o próprio botão do Rayfield (sem destruir nada)
local function minimizeMenu()
    if not MINIMIZE_MENU_ON_TOGGLE or menuMinimized then return end

    local btn = findMinimizeButton()
    if btn then
        local ok = pcall(function()
            firesignal(btn.MouseButton1Click)
        end)
        if ok then
            menuMinimized = true
            return
        end
    end

    -- Fallback: esconde só o frame principal, se o botão não for encontrado
    local rf = findRayfieldGui()
    local main = rf and rf:FindFirstChild("Main")
    if main then
        main.Visible = false
        menuMinimized = true
    else
        notify("Aviso", "Não achei o botão de minimizar do Rayfield. Use o RightControl.", 4)
    end
end

-- Toca a voz "ZA WARUDO!" (se tiver ID)
local function playVoice()
    if ZA_WARUDO_VOICE_ID == "" then return end
    local s = Instance.new("Sound")
    s.Name = "SillyCat_Voice"
    s.SoundId = ZA_WARUDO_VOICE_ID
    s.Volume = 2
    s.Parent = SoundService
    s:Play()
    Debris:AddItem(s, 8)
end

-- Manda mensagem no chat (TextChatService ou chat antigo)
local function sayInChat(msg)
    pcall(function()
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            local channels = TextChatService:FindFirstChild("TextChannels")
            local channel = channels and channels:FindFirstChild("RBXGeneral")
            if channel then
                channel:SendAsync(msg)
            end
        else
            local events = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
            local say = events and events:FindFirstChild("SayMessageRequest")
            if say then
                say:FireServer(msg, "All")
            end
        end
    end)
end

-- Remove efeitos visuais e sonoros
local function stopEffects(fade)
    local gui, cc, tick = fx.gui, fx.cc, fx.tick
    fx.gui, fx.cc, fx.tick, fx.tint = nil, nil, nil, nil

    if tick then
        if fade then
            local t = tween(tick, 0.6, { Volume = 0 })
            t.Completed:Connect(function() tick:Destroy() end)
        else
            tick:Destroy()
        end
    end

    if cc then
        if fade then
            local t = tween(cc, 0.6, { Saturation = 0, TintColor = Color3.new(1, 1, 1) })
            t.Completed:Connect(function() cc:Destroy() end)
        else
            cc:Destroy()
        end
    end

    if gui then
        if fade then
            task.delay(0.7, function() gui:Destroy() end)
        else
            gui:Destroy()
        end
    end
end

-- Efeito Za Warudo
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

    local tint = Instance.new("Frame")
    tint.Size = UDim2.fromScale(1, 1)
    tint.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
    tint.BackgroundTransparency = 1
    tint.BorderSizePixel = 0
    tint.Parent = gui

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

    local cc = Instance.new("ColorCorrectionEffect")
    cc.TintColor = Color3.fromRGB(255, 225, 120)
    cc.Saturation = 0
    cc.Contrast = 0.1
    cc.Parent = Lighting

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

    local diag = math.sqrt(vp.X ^ 2 + vp.Y ^ 2) * 1.1

    local expand = tween(circle, 0.9, {
        Size = UDim2.fromOffset(diag, diag)
    }, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

    expand.Completed:Connect(function()
        if fx.gui ~= gui then return end
        tween(circle, 0.5, { BackgroundTransparency = 1 })
        tween(tint, 0.6, { BackgroundTransparency = 0.45 })
        if fx.cc then
            tween(fx.cc, 0.6, { Saturation = -0.35 })
        end
    end)
end

-- Cria o clone móvel
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

-- Deixa o corpo real translúcido
local function setRealBodyGhost(char, on)
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.LocalTransparencyModifier = on and 0.5 or 0
        end
    end
end

-- Retorna o corpo que está se movendo agora: clone (se desync ativo) ou personagem real
local function getMover()
    if active and cloneRoot and cloneRoot.Parent and cloneHum and cloneHum.Health > 0 then
        return cloneRoot, cloneHum
    end
    local c = LocalPlayer.Character
    local r = c and c:FindFirstChild("HumanoidRootPart")
    local h = c and c:FindFirstChildOfClass("Humanoid")
    return r, h
end

local stopDesync -- forward declaration

local function startDesync()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if not root or not hum or hum.Health <= 0 then
        notify("Erro de Estado", "Personagem não encontrado!")
        return false
    end

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
        clone, cloneHum, cloneRoot = nil, nil, nil
        notify("Erro", "Clone sem Humanoid/HumanoidRootPart.")
        return false
    end

    clone:PivotTo(root.CFrame)
    lastClonePivot = clone:GetPivot()

    active = true
    originalCFrame = root.CFrame
    lastMoverRoot = nil

    root.Anchored = true
    setRealBodyGhost(char, true)

    workspace.CurrentCamera.CameraSubject = cloneHum

    playZaWarudoEffect()
    playVoice()
    sayInChat(CHAT_MESSAGE)

    moveConn = RunService.RenderStepped:Connect(function()
        if not active or not cloneHum or not cloneHum.Parent then return end
        -- guarda a posição do clone a cada frame (usada se o real renascer)
        if cloneRoot and cloneRoot.Parent then
            lastClonePivot = clone:GetPivot()
        end
        local move = controls and controls:GetMoveVector() or Vector3.zero
        cloneHum:Move(move, true)
    end)

    jumpConn = UserInputService.JumpRequest:Connect(function()
        if active and cloneHum and cloneHum.Parent and cloneHum.Health > 0 then
            cloneHum.Jump = true
        end
    end)

    -- Se o clone morrer, o desync termina normalmente
    cloneHum.Died:Connect(function()
        if active then
            stopDesync(false)
        end
    end)

    notify("ZA WARUDO!", "O tempo parou. Vá pegar os desavisados!", 4)
    return true
end

stopDesync = function(snapToClone)
    if not active then return end
    active = false

    if moveConn then moveConn:Disconnect() moveConn = nil end
    if jumpConn then jumpConn:Disconnect() jumpConn = nil end

    -- Onde o player deve voltar: no clone (snap, ou se o real morreu) ou no ponto original
    local targetCFrame = nil
    local realDead = true
    local curChar = LocalPlayer.Character
    local curHum = curChar and curChar:FindFirstChildOfClass("Humanoid")
    if curHum and curHum.Health > 0 then realDead = false end

    if clone and clone.Parent and (snapToClone or realDead) then
        targetCFrame = clone:GetPivot()
    elseif originalCFrame then
        targetCFrame = originalCFrame
    end

    if clone then clone:Destroy() end
    clone, cloneHum, cloneRoot = nil, nil, nil

    if not realDead and curChar then
        -- personagem real vivo: restaura normalmente
        setRealBodyGhost(curChar, false)
        local root = curChar:FindFirstChild("HumanoidRootPart")
        if root then
            root.Anchored = false
            if targetCFrame then
                curChar:PivotTo(targetCFrame)
            end
        end
        workspace.CurrentCamera.CameraSubject = curHum
    else
        -- personagem real morto/ausente: ele renasce na posição do clone
        pendingSnap = targetCFrame
    end

    originalCFrame = nil
    lastMoverRoot = nil
    stopEffects(true)
end

-- Antes do corpo real sumir, salva a posição do clone (ela não pode mudar por causa do renascimento)
LocalPlayer.CharacterRemoving:Connect(function()
    if ac