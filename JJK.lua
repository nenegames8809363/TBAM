-- Script SillyCat - Expansão de Domínio V5 (__namecall Hook & Packet Duplication)
-- SillyCat / Boykisser - Interceptação Real de Combate para Sure-Hit Absoluto
​local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
​local Window = Rayfield:CreateWindow({
Name = "SillyCat Hub | Expansão de Domínio V5 ⛩️",
LoadingTitle = "Ryōiki Tenkai - Modo Hook Supremo",
LoadingSubtitle = "by Boykisser (Packet Duplication & Sure-Hit)",
ConfigurationSaving = {
Enabled = false,
FolderName = nil,
FileName = "SillyCatDomainV5"
},
Discord = {
Enabled = false,
Invite = "noinvitelink",
RememberJoins = true
},
KeySystem = false
})
​local Tab = Window:CreateTab("Expansão de Domínio ⛩️", 4483362458)
​local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
​local isDomainActive = false
local domainRadius = 35
local domainSphere = nil
local domainSound = nil
local domainToggleRef = nil
local namecallHook = nil
​-- Restauradores de iluminação
local originalAmbient = Lighting.Ambient
local originalOutdoorAmbient = Lighting.OutdoorAmbient
local colorCorrection = nil
​-- Animação de sinal de mãos JJK
local function playHandSignAnimation(character)
local humanoid = character:FindFirstChildOfClass("Humanoid")
local rootPart = character:FindFirstChild("HumanoidRootPart")
if not humanoid or not rootPart then return end
​local upperTorso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
if upperTorso then
pcall(function()
local rightShoulder = upperTorso:FindFirstChild("Right Shoulder")
local leftShoulder = upperTorso:FindFirstChild("Left Shoulder")
if rightShoulder and leftShoulder then
rightShoulder.C0 = rightShoulder.C0 * CFrame.Angles(0, math.rad(-45), math.rad(45))
leftShoulder.C0 = leftShoulder.C0 * CFrame.Angles(0, math.rad(45), math.rad(-45))
task.wait(0.6)
end
end)
end
end
​-- Criação da Redoma Visual e Atmosfera
local function createDomainVisual(character)
if domainSphere then domainSphere:Destroy() end
​local rootPart = character:FindFirstChild("HumanoidRootPart")
if not rootPart then return end
​domainSphere = Instance.new("Part")
domainSphere.Name = "SillyCat_DomainDomeV5"
domainSphere.Shape = Enum.PartType.Ball
domainSphere.Size = Vector3.new(1, 1, 1) * 4
domainSphere.Position = rootPart.Position
domainSphere.Anchored = true
domainSphere.CanCollide = false
domainSphere.Material = Enum.Material.Glass
domainSphere.Color = Color3.fromRGB(100, 0, 220)
domainSphere.Transparency = 0.6
domainSphere.Parent = workspace
​TweenService:Create(domainSphere, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
Transparency = 0.5,
Size = Vector3.new(1, 1, 1) * (domainRadius * 2)
}):Play()
​if colorCorrection then colorCorrection:Destroy() end
colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Name = "SillyCat_DomainAtmosphereV5"
colorCorrection.TintColor = Color3.fromRGB(220, 150, 255)
colorCorrection.Contrast = 0.4
colorCorrection.Saturation = -0.25
colorCorrection.Parent = Lighting
​Lighting.Ambient = Color3.fromRGB(30, 8, 50)
end
​-- Limpeza total do Domínio
local function cleanupDomain()
isDomainActive = false
​if namecallHook then
-- Desativa o hook restaurando o comportamento original se necessário (dependendo do executor, hooks globais são gerenciados por bibliotecas)
namecallHook = nil
end
​if domainSphere then
domainSphere:Destroy()
domainSphere = nil
end
​if colorCorrection then
colorCorrection:Destroy()
colorCorrection = nil
end
​Lighting.Ambient = originalAmbient
Lighting.OutdoorAmbient = originalOutdoorAmbient
​if domainSound then
pcall(function()
domainSound:Stop()
domainSound:Destroy()
end)
domainSound = nil
end
end
​LocalPlayer.CharacterRemoving:Connect(function()
cleanupDomain()
if domainToggleRef then
domainToggleRef:Set(false)
end
end)
​domainToggleRef = Tab:CreateToggle({
Name = "⛩️ Ativar Domínio Supremo V5 (__namecall Hook)",
CurrentValue = false,
Flag = "DomainToggleV5",
Callback = function(Value)
local character = LocalPlayer.Character
​if Value then
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
​cleanupDomain()
isDomainActive = true
​pcall(function()
domainSound = Instance.new("Sound")
domainSound.SoundId = "rbxassetid://9114224160"
domainSound.Volume = 1
domainSound.Parent = workspace
domainSound:Play()
end)
​task.spawn(function()
playHandSignAnimation(character)
end)
​createDomainVisual(character)
​-- Atualiza a posição da redoma em tempo real junto com o jogador
task.spawn(function()
while isDomainActive do
local currentCharacter = LocalPlayer.Character
if currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart") and domainSphere then
domainSphere.Position = currentCharacter.HumanoidRootPart.Position
end
task.wait(0.1)
end
end)
​-- A MAGIA DO SURE-HIT REAL: Interceptação de Remotes via Metamétodo (__namecall)
pcall(function()
local mt = getrawmetatable(game)
setreadonly(mt, false)
local oldNamecall = mt.__namecall
​mt.__namecall = newcclosure(function(self, ...)
local method = getnamecallmethod()
local args = {...}
​if isDomainActive and (method == "FireServer" or method == "InvokeServer") then
local currentCharacter = LocalPlayer.Character
if currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart") then
local rootPart = currentCharacter.HumanoidRootPart
​-- Verifica se o remote pertence a uma ferramenta ou ação de combate do jogador
local isPlayerCombat = false
pcall(function()
if self:IsDescendantOf(currentCharacter) or self.Name:lower():find("attack") or self.Name:lower():find("combat") or self.Name:lower():find("skill") or self.Name:lower():find("hit") or self.Name:lower():find("ability") then
isPlayerCombat = true
end
end)
​if isPlayerCombat then
-- Dispara o ataque legítimo original
task.spawn(function()
pcall(function()
oldNamecall(self, unpack(args))
end)
end)
​-- Sure-Hit Supremo: Duplica o pacote para TODOS os jogadores dentro do domínio
for _, player in ipairs(Players:GetPlayers()) do
if player ~= LocalPlayer and player.Character then
local enemyRoot = player.Character:FindFirstChild("HumanoidRootPart")
local enemyHumanoid = player.Character:FindFirstChildOfClass("Humanoid")
​if enemyRoot and enemyHumanoid and enemyHumanoid.Health > 0 then
local distance = (enemyRoot.Position - rootPart.Position).Magnitude
if distance <= domainRadius then
-- Modifica os argumentos do pacote para mirar na posição/entidade do inimigo preso
for i, v in ipairs(args) do
if typeof(v) == "Vector3" then
args[i] = enemyRoot.Position
elseif typeof(v) == "CFrame" then
args[i] = enemyRoot.CFrame
elseif typeof(v) == "Instance" and v:IsA("Model") then
args[i] = player.Character
end
end
​-- Dispara a cópia exata do pacote para o servidor processar o dano no inimigo
task.spawn(function()
pcall(function()
oldNamecall(self, unpack(args))
end)
end)
end
end
end
end
​-- Retorna para evitar o envio duplo padrão redundante na chamada principal
return
end
end
end
​return oldNamecall(self, ...)
end)
​setreadonly(mt, true)
end)
​Rayfield:Notify({
Title = "RYŌIKI TENKAI! ⛩️",
Content = "Modo Hook __namecall ativado! Pacotes duplicados com sucesso.",
Duration = 4,
Image = 4483362458
})
else
cleanupDomain()
Rayfield:Notify({
Title = "Domínio Desfeito",
Content = "Estado normal restabelecido.",
Duration = 3,
Image = 4483362458
})
end
end,
})
​Rayfield:Notify({
Title = "SillyCat Hub V5 Carregado",
Content = "Pronto para interceptar o servidor no Delta Mobile.",
Duration = 5,
Image = 4483362458
})