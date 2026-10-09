-- Script SillyCat - Expansão de Domínio V6 (JJK Master Edition)
-- SillyCat / Boykisser - Hook __namecall, Animação JJK Real e Redoma Cinematográfica

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "SillyCat Hub | Expansão de Domínio V6 ⛩️",
    LoadingTitle = "Ryōiki Tenkai - JJK Master Edition",
    LoadingSubtitle = "by Boykisser (Clean Syntax & Sure-Hit)",
    ConfigurationSaving = {
        Enabled = false,
        FolderName = nil,
        FileName = "SillyCatDomainV6"
    },
    Discord = {
        Enabled = false,
        Invite = "noinvitelink",
        RememberJoins = true
    },
    KeySystem = false
})

local Tab = Window:CreateTab("Expansão de Domínio ⛩️", 4483362458)

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local isDomainActive = false
local domainRadius = 35
local domainDomeOuter = nil
local domainDomeInner = nil
local domainSound = nil
local domainToggleRef = nil

-- Restauradores de ambiente
local originalAmbient = Lighting.Ambient
local originalOutdoorAmbient = Lighting.OutdoorAmbient
local colorCorrection = nil
local bloomEffect = nil

-- Animação de sinal de mãos JJK Real (Compatível com R15 e R6)
local function playHandSignAnimation(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then return end

    local isR15 = character:FindFirstChild("UpperTorso") ~= nil

    pcall(function()
        if isR15 then
            for _, joint in ipairs(character:GetDescendants()) do
                if joint:IsA("Motor6D") and (joint.Name == "RightShoulder" or joint.Name == "LeftShoulder") then
                    local origC0 = joint.C0
                    if joint.Name == "RightShoulder" then
                        joint.C0 = origC0 * CFrame.Angles(math.rad(35), math.rad(-55), math.rad(35))
                    else
                        joint.C0 = origC0 * CFrame.Angles(math.rad(35), math.rad(55), math.rad(-35))
                    end
                end
            end
        else
            local torso = character:FindFirstChild("Torso")
            if torso then
                for _, joint in ipairs(torso:GetChildren()) do
                    if joint:IsA("Motor6D") and (joint.Name == "Right Shoulder" or joint.Name == "Left Shoulder") then
                        local origC0 = joint.C0
                        if joint.Name == "Right Shoulder" then
                            joint.C0 = origC0 * CFrame.Angles(0, math.rad(-45), math.rad(45))
                        else
                            joint.C0 = origC0 * CFrame.Angles(0, math.rad(45), math.rad(-45))
                        end
                    end
                end
            end
        end
        task.wait(0.7)
    end)
end

-- Criação da Redoma Visual Cinematográfica (Camada Dupla)
local function createDomainVisual(character)
    if domainDomeOuter then domainDomeOuter:Destroy() end
    if domainDomeInner then domainDomeInner:Destroy() end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    -- Redoma Externa (Vidro Roxo Místico)
    domainDomeOuter = Instance.new("Part")
    domainDomeOuter.Name = "SillyCat_OuterDome"
    domainDomeOuter.Shape = Enum.PartType.Ball
    domainDomeOuter.Size = Vector3.new(1, 1, 1) * 4
    domainDomeOuter.Position = rootPart.Position
    domainDomeOuter.Anchored = true
    domainDomeOuter.CanCollide = false
    domainDomeOuter.Material = Enum.Material.Glass
    domainDomeOuter.Color = Color3.fromRGB(110, 0, 240)
    domainDomeOuter.Transparency = 0.55
    domainDomeOuter.Parent = workspace

    -- Redoma Interna (Núcleo Brilhante)
    domainDomeInner = Instance.new("Part")
    domainDomeInner.Name = "SillyCat_InnerDome"
    domainDomeInner.Shape = Enum.PartType.Ball
    domainDomeInner.Size = Vector3.new(1, 1, 1) * 2
    domainDomeInner.Position = rootPart.Position
    domainDomeInner.Anchored = true
    domainDomeInner.CanCollide = false
    domainDomeInner.Material = Enum.Material.Neon
    domainDomeInner.Color = Color3.fromRGB(180, 50, 255)
    domainDomeInner.Transparency = 0.8
    domainDomeInner.Parent = workspace

    -- Animações de expansão suaves (Efeito Expansão de Domínio JJK)
    TweenService:Create(domainDomeOuter, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Transparency = 0.5,
        Size = Vector3.new(1, 1, 1) * (domainRadius * 2)
    }):Play()

    TweenService:Create(domainDomeInner, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
        Transparency = 0.85,
        Size = Vector3.new(1, 1, 1) * (domainRadius * 1.9)
    }):Play()

    -- Atmosfera e Iluminação Estilo Domínio
    if colorCorrection then colorCorrection:Destroy() end
    colorCorrection = Instance.new("ColorCorrectionEffect")
    colorCorrection.Name = "SillyCat_Atmosphere"
    colorCorrection.TintColor = Color3.fromRGB(230, 160, 255)
    colorCorrection.Contrast = 0.45
    colorCorrection.Saturation = -0.3
    colorCorrection.Parent = Lighting

    if bloomEffect then bloomEffect:Destroy() end
    bloomEffect = Instance.new("BloomEffect")
    bloomEffect.Name = "SillyCat_Bloom"
    bloomEffect.Intensity = 0.6
    bloomEffect.Threshold = 0.2
    bloomEffect.Parent = Lighting

    Lighting.Ambient = Color3.fromRGB(25, 5, 45)
end

-- Limpeza total do Domínio
local function cleanupDomain()
    isDomainActive = false

    if domainDomeOuter then
        domainDomeOuter:Destroy()
        domainDomeOuter = nil
    end

    if domainDomeInner then
        domainDomeInner:Destroy()
        domainDomeInner = nil
    end

    if colorCorrection then
        colorCorrection:Destroy()
        colorCorrection = nil
    end

    if bloomEffect then
        bloomEffect:Destroy()
        bloomEffect = nil
    end

    Lighting.Ambient = originalAmbient
    Lighting.OutdoorAmbient = originalOutdoorAmbient

    if domainSound then
        pcall(function()
            domainSound:Stop()
            domainSound:Destroy()
        end)
        domainSound = nil
    end
end

LocalPlayer.CharacterRemoving:Connect(function()
    cleanupDomain()
    if domainToggleRef then
        domainToggleRef:Set(false)
    end
end)

domainToggleRef = Tab:CreateToggle({
    Name = "⛩️ Ativar Domínio Supremo V6 (Sure-Hit + Hook)",
    CurrentValue = false,
    Flag = "DomainToggleV6",
    Callback = function(Value)
        local character = LocalPlayer.Character

        if Value then
            if not character or not character:FindFirstChild("HumanoidRootPart") then
                Rayfield:Notify({
                    Title = "Erro de Estado",
                    Content = "Personagem não encontrado!",
                    Duration = 3,
                    Image = 4483362458
                })
                if domainToggleRef then domainToggleRef:Set(false) end
                return
            end

            cleanupDomain()
            isDomainActive = true

            pcall(function()
                domainSound = Instance.new("Sound")
                domainSound.SoundId = "rbxassetid://9114224160"
                domainSound.Volume = 1
                domainSound.Parent = workspace
                domainSound:Play()
            end)

            task.spawn(function()
                playHandSignAnimation(character)
            end)

            createDomainVisual(character)

            -- Seguir o jogador em tempo real
            task.spawn(function()
                while isDomainActive do
                    local currentCharacter = LocalPlayer.Character
                    if currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart") then
                        local pos = currentCharacter.HumanoidRootPart.Position
                        if domainDomeOuter then domainDomeOuter.Position = pos end
                        if domainDomeInner then domainDomeInner.Position = pos end
                    end
                    task.wait(0.1)
                end
            end)

            -- Hook __namecall para duplicação de pacotes (Sure-Hit Real)
            pcall(function()
                local mt = getrawmetatable(game)
                setreadonly(mt, false)
                local oldNamecall = mt.__namecall

                mt.__namecall = newcclosure(function(self, ...)
                    local method = getnamecallmethod()
                    local args = {...}

                    if isDomainActive and (method == "FireServer" or method == "InvokeServer") then
                        local currentCharacter = LocalPlayer.Character
                        if currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart") then
                            local rootPart = currentCharacter.HumanoidRootPart

                            local isPlayerCombat = false
                            pcall(function()
                                if self:IsDescendantOf(currentCharacter) or self.Name:lower():find("attack") or self.Name:lower():find("combat") or self.Name:lower():find("skill") or self.Name:lower():find("hit") or self.Name:lower():find("ability") then
                                    isPlayerCombat = true
                                end
                            end)

                            if isPlayerCombat then
                                task.spawn(function()
                                    pcall(function()
                                        oldNamecall(self, unpack(args))
                                    end)
                                end)

                                for _, player in ipairs(Players:GetPlayers()) do
                                    if player ~= LocalPlayer and player.Character then
                                        local enemyRoot = player.Character:FindFirstChild("HumanoidRootPart")
                                        local enemyHumanoid = player.Character:FindFirstChildOfClass("Humanoid")

                                        if enemyRoot and enemyHumanoid and enemyHumanoid.Health > 0 then
                                            local distance = (enemyRoot.Position - rootPart.Position).Magnitude
                                            if distance <= domainRadius then
                                                for i, v in ipairs(args) do
                                                    if typeof(v) == "Vector3" then
                                                        args[i] = enemyRoot.Position
                                                    elseif typeof(v) == "CFrame" then
                                                        args[i] = enemyRoot.CFrame
                                                    elseif typeof(v) == "Instance" and v:IsA("Model") then
                                                        args[i] = player.Character
                                                    end
                                                end

                                                task.spawn(function()
                                                    pcall(function()
                                                        oldNamecall(self, unpack(args))
                                                    end)
                                                end)
                                            end
                                        end
                                    end
                                end
                                return
                            end
                        end
                    end

                    return oldNamecall(self, ...)
                end)

                setreadonly(mt, true)
            end)

            Rayfield:Notify({
                Title = "RYŌIKI TENKAI! ⛩️",
                Content = "Domínio Supremo V6 ativado com sucesso!",
                Duration = 4,
                Image = 4483362458
            })
        else
            cleanupDomain()
            Rayfield:Notify({
                Title = "Domínio Desfeito",
                Content = "Ambiente normal restabelecido.",
                Duration = 3,
                Image = 4483362458
            })
        end
    end,
})

Rayfield:Notify({
    Title = "SillyCat Hub V6 Carregado",
    Content = "Sintaxe limpa e pronta para uso no Delta.",
    Duration = 5,
    Image = 4483362458
})
