-- ==========================================
-- TBAM - ENHANCED (THE CHAOS EDITION V2.0)
-- by Catfeine (A gata mais braba do Luau)
-- ==========================================

if _G.TBAM_Enhanced_Cleanup then pcall(_G.TBAM_Enhanced_Cleanup) end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local Camera = Workspace.CurrentCamera
local function GetCamera()
    Camera = Workspace.CurrentCamera
    return Camera
end

-- 🧠 SISTEMA CENTRAL (Estado, Conexões e Cache)
local TBAM = {
    Destroyed = false,
    State = {
        Aimbot = false, LockPlayers = true, LockBots = true, ShowFOV = false, FOVSize = 150,
        ESP = false, RGB = false, Chaos = false, Noclip = false, Bounce = false,
        Follow = false, AntiFling = false, Spinning = false, SpinSpeed = 50, Invisible = false,
        DesiredWalkSpeed = 16, DesiredJumpHeight = 7.2
    },
    Connections = {},
    Cache = { 
        Targets = {}, 
        OriginalProps = {
            Transparencies = {},
            Lighting = {
                Ambient = Lighting.Ambient,
                ClockTime = Lighting.ClockTime,
                Brightness = Lighting.Brightness,
                FogColor = Lighting.FogColor,
                FogEnd = Lighting.FogEnd,
                ExposureCompensation = Lighting.ExposureCompensation
            }
        } 
    }
}

-- 🧹 CLEANUP ABSOLUTO
_G.TBAM_Enhanced_Cleanup = function()
    TBAM.Destroyed = true
    for _, conn in pairs(TBAM.Connections) do conn:Disconnect() end
    
    -- Limpa ESP
    for _, target in ipairs(TBAM.Cache.Targets) do
        if target.Highlight then target.Highlight:Destroy() end
    end
    
    if TBAM.Cache.FOVCircle then TBAM.Cache.FOVCircle:Remove() end
    
    -- Restaura Iluminação
    for prop, val in pairs(TBAM.Cache.OriginalProps.Lighting) do
        pcall(function() Lighting[prop] = val end)
    end
    
    -- Restaura Personagem
    local char = LocalPlayer.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root and TBAM.Cache.OriginalProps.Physical then
            root.CustomPhysicalProperties = TBAM.Cache.OriginalProps.Physical
        end
        for part, trans in pairs(TBAM.Cache.OriginalProps.Transparencies) do
            if part and part.Parent then part.Transparency = trans end
        end
    end
end

local function AddConn(name, conn)
    if TBAM.Connections[name] then TBAM.Connections[name]:Disconnect() end
    TBAM.Connections[name] = conn
end

-- 🎯 CACHE DE ALVOS (Mais inteligente, menos fritura de CPU)
local function GetTargetData(obj)
    local hum = obj:FindFirstChildOfClass("Humanoid")
    local root = obj:FindFirstChild("HumanoidRootPart")
    if hum and root and hum.Health > 0 and obj ~= LocalPlayer.Character then
        return { Character = obj, Humanoid = hum, RootPart = root, Highlight = nil }
    end
    return nil
end

local function UpdateTargets()
    if TBAM.Destroyed then return end
    
    -- Salva highlights antigos
    local oldHighlights = {}
    for _, t in ipairs(TBAM.Cache.Targets) do
        if t.Highlight then oldHighlights[t.Character] = t.Highlight end
    end
    
    table.clear(TBAM.Cache.Targets)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        local data = GetTargetData(obj)
        if data then
            data.Highlight = oldHighlights[obj]
            table.insert(TBAM.Cache.Targets, data)
        end
    end
    
    if TBAM.State.ESP then _G.RefreshESP() end
end

-- Fallback de 2s e eventos dinâmicos
task.spawn(function()
    while not TBAM.Destroyed do 
        task.wait(2) 
        UpdateTargets() 
    end
end)
AddConn("TargetAdded", Workspace.DescendantAdded:Connect(function(obj)
    task.wait(0.1) -- Espera carregar os componentes
    if obj:IsA("Model") and GetTargetData(obj) then UpdateTargets() end
end))
AddConn("TargetRemoved", Workspace.DescendantRemoving:Connect(function(obj)
    if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then UpdateTargets() end
end))

-- 🛠️ INVISIBILIDADE (Função reutilizável)
local function ApplyInvisibility(char)
    TBAM.Cache.OriginalProps.Transparencies = TBAM.Cache.OriginalProps.Transparencies or {}
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") or part:IsA("Decal") then
            if not TBAM.Cache.OriginalProps.Transparencies[part] then
                TBAM.Cache.OriginalProps.Transparencies[part] = part.Transparency
            end
            part.Transparency = 1
        end
    end
end

-- 🛠️ RESPAWN HANDLER (Mantém o caos rodando pós-morte)
AddConn("RespawnHandler", LocalPlayer.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid", 5)
    local root = char:WaitForChild("HumanoidRootPart", 5)
    
    if hum then
        hum.UseJumpPower = false
        hum.WalkSpeed = TBAM.State.DesiredWalkSpeed
        hum.JumpHeight = TBAM.State.DesiredJumpHeight
    end
    
    if root and TBAM.State.Bounce then
        root.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 1, 1, 1)
    end
    
    if TBAM.State.Invisible then
        task.wait(0.1)
        ApplyInvisibility(char)
    end
end))

-- UI RAYFIELD
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
   Name = "TBAM - Enhanced 🐈‍⬛",
   LoadingTitle = "TBAM - O Caos Reinante",
   LoadingSubtitle = "Preparando a terceira mão pra bater em NPC...",
   ConfigurationSaving = { Enabled = false },
   KeySystem = false
})

-- ⭕ FOV
TBAM.Cache.FOVCircle = Drawing.new("Circle")
local FOVCircle = TBAM.Cache.FOVCircle
FOVCircle.Color = Color3.fromRGB(255, 0, 0)
FOVCircle.Thickness = 1.5
FOVCircle.Filled = false
FOVCircle.Visible = false

-- ================== ABA PVP ==================
local PVPTab = Window:CreateTab("PVP/FPS", 4483362458)

PVPTab:CreateToggle({ Name = "Aimbot Lock", CurrentValue = false, Flag = "Aimbot", Callback = function(v) TBAM.State.Aimbot = v end })

_G.RefreshESP = function()
    if TBAM.Destroyed then return end
    for _, target in ipairs(TBAM.Cache.Targets) do
        local isPlayer = Players:GetPlayerFromCharacter(target.Character) ~= nil
        local shouldShow = TBAM.State.ESP and ((isPlayer and TBAM.State.LockPlayers) or (not isPlayer and TBAM.State.LockBots))
        
        if shouldShow then
            if not target.Highlight then
                local h = Instance.new("Highlight")
                h.Name = "TBAM_ESP"
                h.FillColor = isPlayer and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(255, 255, 0)
                h.Parent = target.Character
                target.Highlight = h
            end
        else
            if target.Highlight then
                target.Highlight:Destroy()
                target.Highlight = nil
            end
        end
    end
end

PVPTab:CreateToggle({ Name = "Lock Players", CurrentValue = true, Flag = "LockP", Callback = function(v) 
    TBAM.State.LockPlayers = v; _G.RefreshESP() 
end })
PVPTab:CreateToggle({ Name = "Lock Bots / NPCs", CurrentValue = true, Flag = "LockB", Callback = function(v) 
    TBAM.State.LockBots = v; _G.RefreshESP() 
end })
PVPTab:CreateToggle({ Name = "Exibir FOV do Aimbot", CurrentValue = false, Flag = "FOV", Callback = function(v) 
    TBAM.State.ShowFOV = v; FOVCircle.Visible = v 
end })
PVPTab:CreateSlider({ Name = "Tamanho do FOV", Range = {50, 500}, Increment = 5, CurrentValue = 150, Flag = "FOVSize", Callback = function(v) 
    TBAM.State.FOVSize = v; FOVCircle.Radius = v 
end })
PVPTab:CreateToggle({ Name = "ESP (Players & Bots)", CurrentValue = false, Flag = "ESP", Callback = function(v)
    TBAM.State.ESP = v; _G.RefreshESP()
end})

-- MASTER LOOP DE RENDER
AddConn("MasterRender", RunService.RenderStepped:Connect(function(dt)
    local cam = GetCamera()
    
    if TBAM.State.ShowFOV then
        FOVCircle.Position = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
        FOVCircle.Radius = TBAM.State.FOVSize
    end

    -- SPIN FIXO (Usando dt certinho pra não depender de FPS)
    if TBAM.State.Spinning and LocalPlayer.Character then
        local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then
            root.CFrame *= CFrame.Angles(0, math.rad(TBAM.State.SpinSpeed) * dt, 0)
        end
    end

    -- AIMBOT (Com Raycast pra não varar parede)
    if TBAM.State.Aimbot then
        local NearestTarget = nil
        local ShortestDistance = TBAM.State.FOVSize
        local myChar = LocalPlayer.Character

        for _, target in ipairs(TBAM.Cache.Targets) do
            local obj = target.Character
            if obj and obj.Parent then
                local isPlayer = Players:GetPlayerFromCharacter(obj) ~= nil
                if (isPlayer and TBAM.State.LockPlayers) or (not isPlayer and TBAM.State.LockBots) then
                    local hrp = target.RootPart
                    local pos, onScreen = cam:WorldToViewportPoint(hrp.Position)
                    
                    if onScreen then
                        local mousePos = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
                        local dist = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
                        
                        if dist < ShortestDistance then
                            -- Raycast pra ver se tem parede no meio
                            local rayParams = RaycastParams.new()
                            rayParams.FilterType = Enum.RaycastFilterType.Exclude
                            rayParams.FilterDescendantsInstances = {myChar, cam}
                            
                            local direction = (hrp.Position - cam.CFrame.Position).Unit
                            local distanceToTarget = (hrp.Position - cam.CFrame.Position).Magnitude
                            local result = Workspace:Raycast(cam.CFrame.Position, direction * distanceToTarget, rayParams)
                            
                            if not result or result.Instance:IsDescendantOf(obj) then
                                ShortestDistance = dist
                                NearestTarget = hrp
                            end
                        end
                    end
                end
            end
        end

        if NearestTarget then
            cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, NearestTarget.Position), dt * 10)
        end
    end
end))


-- ================== ABA VISUALS ==================
local VisualsTab = Window:CreateTab("Visuals", 4483362458)

VisualsTab:CreateButton({ Name = "Morning Mode", Callback = function() Lighting.ClockTime = 6 end })
VisualsTab:CreateButton({ Name = "Day Mode", Callback = function() Lighting.ClockTime = 12 end })
VisualsTab:CreateButton({ Name = "Afternoon Mode", Callback = function() Lighting.ClockTime = 17 end })
VisualsTab:CreateButton({ Name = "Night Mode", Callback = function() Lighting.ClockTime = 0 end })

VisualsTab:CreateToggle({ Name = "Visual Chaos Mode", CurrentValue = false, Flag = "VChaos", Callback = function(v)
    TBAM.State.Chaos = v
    if not v then
        for prop, val in pairs(TBAM.Cache.OriginalProps.Lighting) do
            pcall(function() Lighting[prop] = val end)
        end
    end
end})

AddConn("LightingLoop", RunService.Heartbeat:Connect(function()
    if TBAM.State.Chaos then
        Lighting.ClockTime = math.random(0, 24)
        Lighting.Ambient = Color3.fromHSV(math.random(), 1, 1)
        Lighting.FogColor = Color3.fromHSV(math.random(), 1, 1)
    end
end))

-- ================== ABA MOVIMENT ==================
local MovimentTab = Window:CreateTab("Moviment", 4483362458)
MovimentTab:CreateSlider({ Name = "WalkSpeed", Range = {16, 500}, Increment = 1, CurrentValue = 16, Flag = "WS", Callback = function(v)
    TBAM.State.DesiredWalkSpeed = v
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then LocalPlayer.Character.Humanoid.WalkSpeed = v end
end})

MovimentTab:CreateSlider({ Name = "JumpHeight", Range = {7.2, 500}, Increment = 1, CurrentValue = 7.2, Flag = "JH", Callback = function(v)
    TBAM.State.DesiredJumpHeight = v
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then 
        LocalPlayer.Character.Humanoid.UseJumpPower = false
        LocalPlayer.Character.Humanoid.JumpHeight = v 
    end
end})

AddConn("PhysicsLoop", RunService.Stepped:Connect(function()
    if TBAM.State.Noclip and LocalPlayer.Character then
        for _, v in pairs(LocalPlayer.Character:GetDescendants()) do
            if v:IsA("BasePart") then v.CanCollide = false end
        end
    end

    if TBAM.State.AntiFling then
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                for _, v in pairs(p.Character:GetDescendants()) do
                    if v:IsA("BasePart") then 
                        v.CanCollide = false 
                        v.Velocity = Vector3.new(0,0,0)
                        v.RotVelocity = Vector3.new(0,0,0)
                    end
                end
            end
        end
    end
end))

MovimentTab:CreateToggle({ Name = "Noclip", CurrentValue = false, Flag = "Noclip", Callback = function(v) TBAM.State.Noclip = v end })
MovimentTab:CreateToggle({ Name = "Anti-Fling", CurrentValue = false, Flag = "AntiF", Callback = function(v) TBAM.State.AntiFling = v end })
MovimentTab:CreateToggle({ Name = "Bounce Mode", CurrentValue = false, Flag = "Bounce", Callback = function(v)
    TBAM.State.Bounce = v
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if root then
        if v then
            TBAM.Cache.OriginalProps.Physical = root.CustomPhysicalProperties
            root.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 1, 1, 1)
        elseif TBAM.Cache.OriginalProps.Physical then
            root.CustomPhysicalProperties = TBAM.Cache.OriginalProps.Physical
        end
    end
end})

-- ================== ABA TOOLS ==================
local ToolsTab = Window:CreateTab("Tools", 4483362458)

ToolsTab:CreateButton({ Name = "Fly Gui V3", Callback = function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/XNEQUAL/FlyGuiV3/main/FlyGuiV3.txt"))()
end})

-- TP TOOL 100% Moderno com UserInputService (Tchau GetMouse)
ToolsTab:CreateButton({ Name = "Obter TP Tool", Callback = function()
    local Tool = Instance.new("Tool")
    Tool.Name = "TP Tool"
    Tool.RequiresHandle = false
    Tool.Parent = LocalPlayer.Backpack
    
    local equipConn
    Tool.Equipped:Connect(function()
        equipConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                local char = LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then
                    local inputPos = input.Position
                    local ray = GetCamera():ScreenPointToRay(inputPos.X, inputPos.Y)
                    local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000)
                    if result then
                        root.CFrame = CFrame.new(result.Position + Vector3.new(0, 3, 0))
                    end
                end
            end
        end)
    end)
    Tool.Unequipped:Connect(function()
        if equipConn then equipConn:Disconnect() end
    end)
end})

ToolsTab:CreateSlider({ Name = "Spin Speed (Graus/s)", Range = {10, 2000}, Increment = 10, CurrentValue = 360, Flag = "SS", Callback = function(v) TBAM.State.SpinSpeed = v end })
ToolsTab:CreateToggle({ Name = "Spin (Girar)", CurrentValue = false, Flag = "Spin", Callback = function(v) TBAM.State.Spinning = v end })

ToolsTab:CreateToggle({ Name = "Invisibilidade", CurrentValue = false, Flag = "Invis", Callback = function(v)
    TBAM.State.Invisible = v
    local char = LocalPlayer.Character
    if not char then return end

    if v then
        ApplyInvisibility(char)
    else
        for part, trans in pairs(TBAM.Cache.OriginalProps.Transparencies) do
            if part and part.Parent then part.Transparency = trans end
        end
        table.clear(TBAM.Cache.OriginalProps.Transparencies)
    end
end})

ToolsTab:CreateButton({ Name = "Forçar Sentar", Callback = function()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") then
        local seat = Instance.new("Seat")
        seat.Transparency = 1
        seat.CFrame = char.HumanoidRootPart.CFrame
        seat.Parent = Workspace
        seat:Sit(char.Humanoid)
        task.delay(0.5, function() seat:Destroy() end) -- Limpa depois de sentar
    end
end})

ToolsTab:CreateButton({ Name = "Ativar Ragdoll", Callback = function()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    end
end})

-- ================== ABA CONFIG ==================
local ConfigTab = Window:CreateTab("Config", 4483362458)

ConfigTab:CreateDropdown({
   Name = "Language / Idioma",
   Options = {"Pt-BR (Óbvio)", "EN-US (Gringo fedido)"},
   CurrentOption = "Pt-BR (Óbvio)",
   Flag = "LangSelect",
   Callback = function(Option)
       Rayfield:Notify({Title = "Aviso do Sistema", Content = "Nem tentei fazer o multi-idioma funcionar. Fica no português mesmo e para de chorar kkkkk", Duration = 5})
   end
})

Rayfield:Notify({
   Title = "TBAM Consertado!",
   Content = "Fidget toys de stress guardados na gaveta. Vai lá tocar o terror no server!",
   Duration = 5,
   Image = 4483362458,
})
