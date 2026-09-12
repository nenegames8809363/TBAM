--// =========================================================
--// THE BROKEN ARROW MENU
--// TBAM
--// STABLE EDITION v2.5 (CAOS EDITION)
--// UI / TEST ADMIN PANEL
--// Created by Niko x ChatGPT
--// =========================================================

--// SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

--// =========================================================
--// CONFIG
--// =========================================================

local FOV = 250
local MAX_DISTANCE = 1000
local AIM_PART = "Head"

local SPEED_VALUES = { 50, 75, 100, 150 }
local JUMP_VALUES = { 50, 75, 100, 125 }
local FLY_VALUES = { 10, 25, 75, 100, 150 }

local FALLBACK_WALK_SPEED = 16
local FALLBACK_JUMP_POWER = 50

--// =========================================================
--// STATES
--// =========================================================

local ESP_ENABLED = false
local AIM_ENABLED = false
local SPEED_ENABLED = false
local NOCLIP_ENABLED = false
local JUMP_ENABLED = false

local SPIN_ENABLED = false
local ZERO_GRAVITY_ENABLED = false
local ZG_FORCE = nil
local ZG_ATT = nil

local ANTI_KICK_ENABLED = true

-- FLY
local FLY_ENABLED = false
local FLY_INDEX = 0
local CURRENT_FLY_SPEED = 0

local FLY_UP = false
local FLY_DOWN = false

local FLY_ATTACHMENT = nil
local FLY_LINEAR_VELOCITY = nil
local FLY_ORIENTATION = nil

-- GODMODE
local GODMODE_ENABLED = false
local GODMODE_MAX_HEALTH = math.huge -- TRAVA MÁXIMA
local GODMODE_CONNECTIONS = {}

local FOV_VISIBLE = true
local GLOW_ENABLED = true

local SPEED_INDEX = 1
local CURRENT_SPEED = SPEED_VALUES[SPEED_INDEX]

local JUMP_INDEX = 1
local CURRENT_JUMP = JUMP_VALUES[JUMP_INDEX]

local currentAimTarget = nil

local minimized = true
local menuAnimating = false
local activeTab = "Combat"

local tracked = {}

local originalMovement = {}

--// =========================================================
--// ANTI-KICK HOOK
--// =========================================================

task.spawn(function()
	local rawMeta = getrawmetatable and getrawmetatable(game)
	if rawMeta and setreadonly then
		setreadonly(rawMeta, false)
		local oldNamecall = rawMeta.__namecall
		rawMeta.__namecall = newcclosure(function(self, ...)
			local method = getnamecallmethod()
			if ANTI_KICK_ENABLED and (method == "Kick" or method == "kick") and (self == LocalPlayer or self == Players) then
				return nil
			end
			return oldNamecall(self, ...)
		end)
		setreadonly(rawMeta, true)
	end

	if hookfunction and LocalPlayer.Kick then
		local oldKick
		oldKick = hookfunction(LocalPlayer.Kick, function(self, ...)
			if ANTI_KICK_ENABLED and (self == LocalPlayer or self == Players) then
				return nil
			end
			return oldKick(self, ...)
		end)
	else
		pcall(function()
			LocalPlayer.Kick = function() end
		end)
	end
end)

--// =========================================================
--// CUSTOMIZATION
--// =========================================================

local ACTIVE_COLOR = Color3.fromRGB(145, 85, 205)
local DEFAULT_ACTIVE_COLOR = ACTIVE_COLOR

local COLOR_PRESETS = {
	{ name = "PURPLE", color = Color3.fromRGB(145, 85, 205) },
	{ name = "BLUE", color = Color3.fromRGB(70, 130, 235) },
	{ name = "GREEN", color = Color3.fromRGB(60, 180, 110) },
	{ name = "RED", color = Color3.fromRGB(220, 70, 85) },
	{ name = "ORANGE", color = Color3.fromRGB(225, 125, 55) },
	{ name = "CYAN", color = Color3.fromRGB(45, 190, 210) }
}

--// =========================================================
--// COLORS
--// =========================================================

local COLORS = {
	background = Color3.fromRGB(10, 11, 16),
	panel = Color3.fromRGB(17, 18, 25),
	button = Color3.fromRGB(27, 28, 37),
	buttonHover = Color3.fromRGB(34, 35, 46),
	border = Color3.fromRGB(92, 96, 125),

	text = Color3.fromRGB(242, 242, 248),
	subtext = Color3.fromRGB(150, 153, 172),

	blue = Color3.fromRGB(71, 105, 210),
	blueBright = Color3.fromRGB(75, 145, 255),
	green = Color3.fromRGB(62, 175, 105),
	purple = Color3.fromRGB(145, 85, 205),
	red = Color3.fromRGB(220, 75, 85),
	orange = Color3.fromRGB(220, 115, 60)
}

--// =========================================================
--// CHARACTER HELPERS
--// =========================================================

local function getCharacter()
	return LocalPlayer.Character
end

local function getHumanoid(model)
	if not model then return nil end
	return model:FindFirstChildOfClass("Humanoid")
end

local function getRoot(model)
	if not model then return nil end
	return model:FindFirstChild("HumanoidRootPart")
		or model:FindFirstChild("UpperTorso")
		or model:FindFirstChild("Torso")
end

local function isTarget(model)
	if not model or not model:IsA("Model") then return false end
	if model == getCharacter() then return false end

	local humanoid = getHumanoid(model)
	local root = getRoot(model)

	if not humanoid or not root or humanoid.Health <= 0 then
		return false
	end

	return true
end

--// =========================================================
--// GODMODE (MUITO MAIS BLINDADO)
--// =========================================================

local function disconnectGodMode()
	for _, connection in ipairs(GODMODE_CONNECTIONS) do
		if connection then connection:Disconnect() end
	end
	GODMODE_CONNECTIONS = {}
end

local function setupGodMode()
	local character = getCharacter()
	if not character then return end

	local humanoid = getHumanoid(character)
	if not humanoid then return end

	disconnectGodMode()

	humanoid.MaxHealth = GODMODE_MAX_HEALTH
	humanoid.Health = GODMODE_MAX_HEALTH
	humanoid.BreakJointsOnDeath = false

	-- Trava anti-dano brusco
	table.insert(
		GODMODE_CONNECTIONS,
		humanoid.HealthChanged:Connect(function(health)
			if not GODMODE_ENABLED or not humanoid.Parent then return end
			if health < GODMODE_MAX_HEALTH then
				humanoid.Health = GODMODE_MAX_HEALTH
			end
		end)
	)

	-- Trava anti-estado de morte
	table.insert(
		GODMODE_CONNECTIONS,
		humanoid.StateChanged:Connect(function(_, newState)
			if not GODMODE_ENABLED then return end
			if newState == Enum.HumanoidStateType.Dead or newState == Enum.HumanoidStateType.Physics then
				humanoid.Health = GODMODE_MAX_HEALTH
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end)
	)

	-- Trava por pulso do jogo (Garante imortalidade constante)
	table.insert(
		GODMODE_CONNECTIONS,
		RunService.Heartbeat:Connect(function()
			if not GODMODE_ENABLED or not humanoid.Parent then return end
			if humanoid.Health < GODMODE_MAX_HEALTH then
				humanoid.Health = GODMODE_MAX_HEALTH
			end
			local state = humanoid:GetState()
			if state == Enum.HumanoidStateType.Dead then
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end)
	)
end

local function disableGodMode()
	GODMODE_ENABLED = false
	disconnectGodMode()

	local character = getCharacter()
	local humanoid = getHumanoid(character)
	if humanoid then
		humanoid.MaxHealth = 100
		humanoid.Health = 100
		humanoid.BreakJointsOnDeath = true
	end
end

--// =========================================================
--// CAMERA
--// =========================================================

local function getCamera()
	return Workspace.CurrentCamera
end

--// =========================================================
--// VISIBILITY
--// =========================================================

local function isVisible(targetPart)
	local camera = getCamera()
	local character = getCharacter()

	if not camera or not targetPart then return false end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true

	local origin = camera.CFrame.Position
	local direction = targetPart.Position - origin

	local result = Workspace:Raycast(origin, direction, params)
	if not result then return true end

	return result.Instance:IsDescendantOf(targetPart.Parent)
end

--// =========================================================
--// ESP & AIMBOT (MANTIDOS ORIGINAIS)
--// =========================================================

local function removeESP(model)
	local data = tracked[model]
	if not data then return end
	if data.highlight then data.highlight:Destroy() end
	if data.billboard then data.billboard:Destroy() end
	tracked[model] = nil
end

local function createESP(model, isPlayer)
	if not model or not model.Parent or tracked[model] or not isTarget(model) then return end
	local humanoid = getHumanoid(model)
	local root = getRoot(model)
	if not humanoid or not root then return end

	local highlight = Instance.new("Highlight")
	highlight.Name = "TBAM_ESP"
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillTransparency = 0.76
	highlight.OutlineTransparency = 0
	highlight.FillColor = isPlayer and Color3.fromRGB(45, 125, 255) or Color3.fromRGB(255, 65, 70)
	highlight.OutlineColor = isPlayer and Color3.fromRGB(110, 195, 255) or Color3.fromRGB(255, 130, 130)
	highlight.Enabled = ESP_ENABLED
	highlight.Parent = model

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TBAM_Info"
	billboard.Adornee = root
	billboard.Size = UDim2.fromOffset(210, 78)
	billboard.StudsOffset = Vector3.new(0, 3.4, 0)
	billboard.AlwaysOnTop = true
	billboard.Enabled = ESP_ENABLED
	billboard.Parent = root

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextWrapped = true
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.35
	label.Text = (isPlayer and "PLAYER" or "BOT") .. "\n" .. model.Name
	label.Parent = billboard

	tracked[model] = { model = model, highlight = highlight, billboard = billboard, label = label, isPlayer = isPlayer }
end

local function scanTargets()
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character then createESP(player.Character, true) end
	end
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("Model") and not Players:GetPlayerFromCharacter(obj) and isTarget(obj) then createESP(obj, false) end
	end
end

task.spawn(function()
	while true do
		task.wait(0.45)
		scanTargets()
		for model, data in pairs(tracked) do
			if not model or not model.Parent or not isTarget(model) then
				removeESP(model)
			else
				data.highlight.Enabled = ESP_ENABLED
				data.billboard.Enabled = ESP_ENABLED
				local humanoid = getHumanoid(model)
				local root = getRoot(model)
				local myRoot = getRoot(getCharacter())
				if humanoid and root then
					local distance = myRoot and math.floor((root.Position - myRoot.Position).Magnitude) or 0
					local visible = isVisible(root)
					data.highlight.FillTransparency = visible and 0.76 or 0.91
					data.label.Text = (data.isPlayer and "PLAYER" or "BOT") .. "\n" .. model.Name .. "\nHP: " .. math.floor(humanoid.Health) .. "  •  " .. distance .. "m"
				end
			end
		end
	end
end)

local function getTarget()
	local camera = getCamera()
	local character = getCharacter()
	local myRoot = getRoot(character)
	if not camera or not myRoot then return nil end

	local bestTarget = nil
	local bestScreenDistance = FOV
	local viewport = camera.ViewportSize
	local center = Vector2.new(viewport.X / 2, viewport.Y / 2)

	local function checkModel(model)
		if not model or model == character or not model.Parent or not isTarget(model) then return end
		local humanoid = getHumanoid(model)
		if not humanoid or humanoid.Health <= 0 then return end
		local head = model:FindFirstChild(AIM_PART)
		if not head or not head:IsA("BasePart") then return end
		if (head.Position - myRoot.Position).Magnitude > MAX_DISTANCE then return end
		local screenPos, onScreen = camera:WorldToViewportPoint(head.Position)
		if not onScreen or screenPos.Z <= 0 then return end
		local screenDistance = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
		if screenDistance > FOV or not isVisible(head) then return end
		if screenDistance < bestScreenDistance then
			bestScreenDistance = screenDistance
			bestTarget = head
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character then checkModel(player.Character) end
	end
	for model in pairs(tracked) do
		if not Players:GetPlayerFromCharacter(model) then checkModel(model) end
	end
	return bestTarget
end

RunService:BindToRenderStep("TBAM_Aimbot", Enum.RenderPriority.Camera.Value + 1, function()
	if not AIM_ENABLED then
		currentAimTarget = nil
		return
	end
	local camera = getCamera()
	if not camera then return end
	if currentAimTarget then
		local model = currentAimTarget.Parent
		local humanoid = model and getHumanoid(model)
		if not model or not model.Parent or not humanoid or humanoid.Health <= 0 or not isVisible(currentAimTarget) then
			currentAimTarget = nil
		end
	end
	if not currentAimTarget then currentAimTarget = getTarget() end
	if not currentAimTarget then return end
	camera.CFrame = CFrame.lookAt(camera.CFrame.Position, currentAimTarget.Position)
end)

--// =========================================================
--// MOVEMENT (SPEED, JUMP, NOCLIP, FLY)
--// =========================================================

local function saveOriginalMovement(character)
	if not character or originalMovement[character] then return end
	local humanoid = getHumanoid(character)
	if not humanoid then return end
	originalMovement[character] = { WalkSpeed = humanoid.WalkSpeed, UseJumpPower = humanoid.UseJumpPower, JumpPower = humanoid.JumpPower, JumpHeight = humanoid.JumpHeight }
end

local function applySpeed()
	local character = getCharacter()
	local humanoid = getHumanoid(character)
	if not humanoid then return end
	saveOriginalMovement(character)
	local original = originalMovement[character]
	humanoid.WalkSpeed = SPEED_ENABLED and CURRENT_SPEED or (original and original.WalkSpeed or FALLBACK_WALK_SPEED)
end

local function applyJump()
	local character = getCharacter()
	local humanoid = getHumanoid(character)
	if not humanoid then return end
	saveOriginalMovement(character)
	local original = originalMovement[character]
	if JUMP_ENABLED then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = CURRENT_JUMP
	else
		if original then
			humanoid.UseJumpPower = original.UseJumpPower
			humanoid.JumpPower = original.JumpPower
			humanoid.JumpHeight = original.JumpHeight
		else
			humanoid.UseJumpPower = true
			humanoid.JumpPower = FALLBACK_JUMP_POWER
		end
	end
end

local function cleanupFly()
	if FLY_LINEAR_VELOCITY then FLY_LINEAR_VELOCITY:Destroy() FLY_LINEAR_VELOCITY = nil end
	if FLY_ORIENTATION then FLY_ORIENTATION:Destroy() FLY_ORIENTATION = nil end
	if FLY_ATTACHMENT then FLY_ATTACHMENT:Destroy() FLY_ATTACHMENT = nil end
	local character = getCharacter()
	local humanoid = getHumanoid(character)
	local root = getRoot(character)
	if humanoid then humanoid.AutoRotate = true humanoid.PlatformStand = false end
	if root then root.AssemblyLinearVelocity = Vector3.zero root.AssemblyAngularVelocity = Vector3.zero end
end

local function setupFly()
	cleanupFly()
	if not FLY_ENABLED then return end
	local character = getCharacter()
	local humanoid = getHumanoid(character)
	local root = getRoot(character)
	if not humanoid or not root then return end
	FLY_ATTACHMENT = Instance.new("Attachment", root)
	FLY_LINEAR_VELOCITY = Instance.new("LinearVelocity", root)
	FLY_LINEAR_VELOCITY.Attachment0 = FLY_ATTACHMENT
	FLY_LINEAR_VELOCITY.RelativeTo = Enum.ActuatorRelativeTo.World
	FLY_LINEAR_VELOCITY.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	FLY_LINEAR_VELOCITY.VectorVelocity = Vector3.zero
	FLY_LINEAR_VELOCITY.MaxForce = math.huge
	FLY_ORIENTATION = Instance.new("AlignOrientation", root)
	FLY_ORIENTATION.Attachment0 = FLY_ATTACHMENT
	FLY_ORIENTATION.Mode = Enum.OrientationAlignmentMode.OneAttachment
	FLY_ORIENTATION.RigidityEnabled = true
	FLY_ORIENTATION.MaxTorque = math.huge
	FLY_ORIENTATION.Responsiveness = 200
	humanoid.AutoRotate = false
	humanoid.PlatformStand = true
end

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.Space then FLY_UP = true
	elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then FLY_DOWN = true end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Space then FLY_UP = false
	elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then FLY_DOWN = false end
end)

RunService.RenderStepped:Connect(function()
	if not FLY_ENABLED then return end
	local character = getCharacter()
	local humanoid = getHumanoid(character)
	local root = getRoot(character)
	local camera = getCamera()
	if not humanoid or not root or not camera then return end
	if not FLY_LINEAR_VELOCITY or not FLY_ORIENTATION then setupFly() return end
	local speed = CURRENT_FLY_SPEED
	local cameraCF = camera.CFrame
	local move = humanoid.MoveDirection
	local velocity = Vector3.zero
	if move.Magnitude > 0.001 then
		local flatLook = Vector3.new(cameraCF.LookVector.X, 0, cameraCF.LookVector.Z).Unit
		local flatRight = Vector3.new(cameraCF.RightVector.X, 0, cameraCF.RightVector.Z).Unit
		velocity = (cameraCF.LookVector * move:Dot(flatLook) + cameraCF.RightVector * move:Dot(flatRight)) * speed
	end
	if FLY_UP then velocity += Vector3.new(0, speed, 0) elseif FLY_DOWN then velocity += Vector3.new(0, -speed, 0) end
	FLY_LINEAR_VELOCITY.VectorVelocity = velocity
	FLY_ORIENTATION.CFrame = cameraCF
end)

RunService.Stepped:Connect(function()
	if not NOCLIP_ENABLED then return end
	local character = getCharacter()
	if not character then return end
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then part.CanCollide = false end
	end
end)

--// =========================================================
--// SPIN
--// =========================================================
RunService.RenderStepped:Connect(function(dt)
	if not SPIN_ENABLED then return end
	local root = getRoot(getCharacter())
	if root then root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(480) * dt, 0) end
end)

--// =========================================================
--// ZERO GRAVITY (TRUE ZERO GRAVITY)
--// =========================================================
local function cleanupZeroG()
	if ZG_FORCE then ZG_FORCE:Destroy() ZG_FORCE = nil end
	if ZG_ATT then ZG_ATT:Destroy() ZG_ATT = nil end
	local char = getCharacter()
	local hum = getHumanoid(char)
	if hum and not FLY_ENABLED then hum.PlatformStand = false end
end

local function setupZeroG()
	cleanupZeroG()
	if not ZERO_GRAVITY_ENABLED or FLY_ENABLED then return end
	local char = getCharacter()
	local root = getRoot(char)
	local hum = getHumanoid(char)
	if not root or not hum then return end

	hum.PlatformStand = true -- Deixa ragdoll/livre
	ZG_ATT = Instance.new("Attachment", root)
	ZG_FORCE = Instance.new("VectorForce", root)
	ZG_FORCE.Attachment0 = ZG_ATT
	ZG_FORCE.RelativeTo = Enum.ActuatorRelativeTo.World

	-- Cancela exatamente a gravidade do mapa baseado na massa
	local mass = 0
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") then mass += p.Mass end
	end
	ZG_FORCE.Force = Vector3.new(0, Workspace.Gravity * mass, 0)
end

RunService.Heartbeat:Connect(function()
	if not ZERO_GRAVITY_ENABLED or FLY_ENABLED then return end
	local root = getRoot(getCharacter())
	local hum = getHumanoid(getCharacter())
	local cam = getCamera()
	if not root or not hum or not cam then return end
	
	-- Garante que continue flutuando e ativa física de impulso (Thrusters)
	hum.PlatformStand = true 
	local move = hum.MoveDirection
	
	-- Propulsores WASD
	if move.Magnitude > 0 then
		local force = move * 45 -- Força do drift
		root:ApplyImpulse(force)
		root:ApplyAngularImpulse(Vector3.new(math.random(-15,15), math.random(-15,15), math.random(-15,15))) -- Gira doidão no espaço
	end
	
	-- Propulsores Cima/Baixo
	if FLY_UP then
		root:ApplyImpulse(Vector3.new(0, 45, 0))
	elseif FLY_DOWN then
		root:ApplyImpulse(Vector3.new(0, -45, 0))
	end
end)

--// =========================================================
--// GUI
--// =========================================================

local gui = Instance.new("ScreenGui")
gui.Name = "TBAM_GUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local OPEN_SIZE = UDim2.fromOffset(335, 300)
local CLOSED_SIZE = UDim2.fromOffset(54, 54)

local menu = Instance.new("Frame")
menu.Name = "TheBrokenArrowMenu"
menu.Size = CLOSED_SIZE
menu.Position = UDim2.fromScale(0.035, 0.18)
menu.BackgroundColor3 = COLORS.background
menu.BackgroundTransparency = 1
menu.BorderSizePixel = 0
menu.ClipsDescendants = true
menu.Active = true
menu.Visible = false
menu.Parent = gui

local menuCorner = Instance.new("UICorner", menu) menuCorner.CornerRadius = UDim.new(0, 20)
local menuStroke = Instance.new("UIStroke", menu) menuStroke.Color = COLORS.border menuStroke.Thickness = 1 menuStroke.Transparency = 0.55

local glowLayer = Instance.new("Frame", menu) glowLayer.Size = UDim2.fromScale(1, 1) glowLayer.BackgroundTransparency = 1 glowLayer.ClipsDescendants = true glowLayer.ZIndex = 0
local function createSoftGlow(pos, size, color)
	local glow = Instance.new("Frame", glowLayer) glow.Size = UDim2.fromOffset(size, size) glow.Position = pos glow.AnchorPoint = Vector2.new(0.5, 0.5) glow.BackgroundColor3 = color glow.BackgroundTransparency = 0.88 glow.BorderSizePixel = 0 glow.ZIndex = 0
	Instance.new("UICorner", glow).CornerRadius = UDim.new(1, 0)
	return glow
end
local glowA = createSoftGlow(UDim2.fromScale(-0.12, 0.08), 250, Color3.fromRGB(85, 65, 255))
local glowB = createSoftGlow(UDim2.fromScale(1.12, 0.43), 270, Color3.fromRGB(35, 130, 255))
local glowC = createSoftGlow(UDim2.fromScale(0.42, 1.12), 260, Color3.fromRGB(190, 55, 180))

task.spawn(function()
	while menu.Parent do
		if not GLOW_ENABLED then
			glowA.Visible = false glowB.Visible = false glowC.Visible = false task.wait(0.4)
		else
			glowA.Visible = true glowB.Visible = true glowC.Visible = true
			TweenService:Create(glowA, TweenInfo.new(8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Position = UDim2.fromScale(0.82, 0.30) }):Play()
			TweenService:Create(glowB, TweenInfo.new(9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Position = UDim2.fromScale(0.17, 0.79) }):Play()
			TweenService:Create(glowC, TweenInfo.new(8.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Position = UDim2.fromScale(0.80, 0.10) }):Play()
			task.wait(8)
			glowA.Position = UDim2.fromScale(-0.12, 0.08) glowB.Position = UDim2.fromScale(1.12, 0.43) glowC.Position = UDim2.fromScale(0.42, 1.12)
		end
	end
end)

local glass = Instance.new("Frame", menu) glass.Size = UDim2.fromScale(1, 1) glass.BackgroundColor3 = Color3.fromRGB(20, 21, 29) glass.BackgroundTransparency = 0.42 glass.BorderSizePixel = 0 glass.ZIndex = 2
Instance.new("UICorner", glass).CornerRadius = UDim.new(0, 20)

local header = Instance.new("Frame", menu) header.Position = UDim2.fromOffset(13, 8) header.Size = UDim2.new(1, -26, 0, 54) header.BackgroundTransparency = 1 header.ZIndex = 10
local title = Instance.new("TextLabel", header) title.BackgroundTransparency = 1 title.Position = UDim2.fromOffset(6, 0) title.Size = UDim2.new(1, -65, 0, 30) title.Font = Enum.Font.GothamBold title.Text = "TBAM" title.TextSize = 22 title.TextColor3 = COLORS.text title.TextXAlignment = Enum.TextXAlignment.Left title.ZIndex = 11
local subtitle = Instance.new("TextLabel", header) subtitle.BackgroundTransparency = 1 subtitle.Position = UDim2.fromOffset(7, 27) subtitle.Size = UDim2.new(1, -65, 0, 20) subtitle.Font = Enum.Font.GothamMedium subtitle.Text = "THE BROKEN ARROW  •  CONTROL PANEL" subtitle.TextSize = 9 subtitle.TextColor3 = COLORS.subtext subtitle.TextXAlignment = Enum.TextXAlignment.Left subtitle.ZIndex = 11

local closeButton = Instance.new("TextButton", header) closeButton.Size = UDim2.fromOffset(36, 36) closeButton.Position = UDim2.new(1, -36, 0, 3) closeButton.BackgroundColor3 = Color3.fromRGB(30, 31, 40) closeButton.BackgroundTransparency = 0.15 closeButton.Text = "×" closeButton.Font = Enum.Font.GothamMedium closeButton.TextSize = 23 closeButton.TextColor3 = COLORS.text closeButton.AutoButtonColor = false closeButton.BorderSizePixel = 0 closeButton.ZIndex = 20
Instance.new("UICorner", closeButton).CornerRadius = UDim.new(1, 0)

local restoreButton = Instance.new("TextButton", gui) restoreButton.Size = CLOSED_SIZE restoreButton.Position = UDim2.fromScale(0.035, 0.18) restoreButton.AnchorPoint = Vector2.new(0.5, 0.5) restoreButton.BackgroundColor3 = Color3.fromRGB(17, 18, 25) restoreButton.Text = "➜" restoreButton.TextSize = 24 restoreButton.Font = Enum.Font.GothamBold restoreButton.TextColor3 = COLORS.text restoreButton.AutoButtonColor = false restoreButton.BorderSizePixel = 0 restoreButton.Visible = true restoreButton.ZIndex = 50
Instance.new("UICorner", restoreButton).CornerRadius = UDim.new(1, 0)
local restoreStroke = Instance.new("UIStroke", restoreButton) restoreStroke.Color = ACTIVE_COLOR restoreStroke.Transparency = 0.35 restoreStroke.Thickness = 1.2

local menuAnchor = UDim2.fromScale(0.035, 0.18)
local function iconToMenuPosition() return UDim2.new(restoreButton.Position.X.Scale, restoreButton.Position.X.Offset - 27, restoreButton.Position.Y.Scale, restoreButton.Position.Y.Offset - 27) end
local function menuToIconPosition(pos) return UDim2.new(pos.X.Scale, pos.X.Offset + 27, pos.Y.Scale, pos.Y.Offset + 27) end

local miniDragging, miniMoved, miniDragStart, miniStartPos, skipNextRestore = false, false, nil, nil, false
restoreButton.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then miniDragging = true miniMoved = false miniDragStart = input.Position miniStartPos = restoreButton.Position end end)
UserInputService.InputChanged:Connect(function(input) if not miniDragging then return end if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end local delta = input.Position - miniDragStart if math.abs(delta.X) > 8 or math.abs(delta.Y) > 8 then miniMoved = true end if not miniMoved then return end restoreButton.Position = UDim2.new(miniStartPos.X.Scale, miniStartPos.X.Offset + delta.X, miniStartPos.Y.Scale, miniStartPos.Y.Offset + delta.Y) end)
UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then if miniMoved then skipNextRestore = true task.defer(function() miniMoved = false end) end miniDragging = false end end)

local function openMenu()
	if not minimized or menuAnimating then return end
	menuAnimating = true menuAnchor = iconToMenuPosition() menu.Position = menuAnchor menu.Size = CLOSED_SIZE menu.BackgroundTransparency = 1 menu.Visible = true restoreButton.Visible = false
	TweenService:Create(menu, TweenInfo.new(0.46, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = OPEN_SIZE }):Play()
	TweenService:Create(menu, TweenInfo.new(0.30, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { BackgroundTransparency = 0.04 }):Play()
	task.wait(0.46) minimized = false menuAnimating = false
end

local function closeMenu()
	if minimized or menuAnimating then return end
	menuAnimating = true menuAnchor = menu.Position
	TweenService:Create(menu, TweenInfo.new(0.34, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Size = CLOSED_SIZE }):Play()
	TweenService:Create(menu, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { BackgroundTransparency = 1 }):Play()
	task.wait(0.34) menu.Visible = false restoreButton.Position = menuToIconPosition(menuAnchor) restoreButton.Size = UDim2.fromOffset(4, 4) restoreButton.Visible = true
	TweenService:Create(restoreButton, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = CLOSED_SIZE }):Play()
	minimized = true menuAnimating = false
end
closeButton.Activated:Connect(closeMenu)
restoreButton.Activated:Connect(function() if skipNextRestore then skipNextRestore = false return end if not menuAnimating then openMenu() end end)

local dragging, dragStart, startPos = false, nil, nil
header.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true dragStart = input.Position startPos = menu.Position end end)
UserInputService.InputChanged:Connect(function(input) if not dragging then return end if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end local delta = input.Position - dragStart menu.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end)
UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end end)

local tabBar = Instance.new("Frame", menu) tabBar.Position = UDim2.fromOffset(13, 69) tabBar.Size = UDim2.new(1, -26, 0, 40) tabBar.BackgroundColor3 = Color3.fromRGB(20, 21, 29) tabBar.BackgroundTransparency = 0.15 tabBar.BorderSizePixel = 0 tabBar.ZIndex = 12
Instance.new("UICorner", tabBar).CornerRadius = UDim.new(0, 12)
local function createTab(text, pos)
	local b = Instance.new("TextButton", tabBar) b.Size = UDim2.new(1/3, -6, 1, 0) b.Position = pos b.BackgroundColor3 = COLORS.button b.BorderSizePixel = 0 b.AutoButtonColor = false b.Font = Enum.Font.GothamBold b.Text = text b.TextSize = 10 b.TextColor3 = COLORS.subtext b.ZIndex = 14
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10) return b
end
local combatTab = createTab("COMBAT", UDim2.fromOffset(4, 4))
local funTab = createTab("FUN", UDim2.new(1/3, 2, 0, 4))
local customTab = createTab("CUSTOM", UDim2.new(2/3, 0, 0, 4))

local pageArea = Instance.new("Frame", menu) pageArea.Position = UDim2.fromOffset(13, 119) pageArea.Size = UDim2.new(1, -26, 1, -128) pageArea.BackgroundTransparency = 1 pageArea.ClipsDescendants = true pageArea.ZIndex = 8
local function createPage()
	local p = Instance.new("ScrollingFrame", pageArea) p.Size = UDim2.fromScale(1, 1) p.Position = UDim2.fromScale(0, 0) p.BackgroundTransparency = 1 p.BorderSizePixel = 0 p.ScrollBarThickness = 3 p.ScrollBarImageColor3 = ACTIVE_COLOR p.ScrollBarImageTransparency = 0.65 p.CanvasSize = UDim2.new() p.AutomaticCanvasSize = Enum.AutomaticSize.Y p.ScrollingDirection = Enum.ScrollingDirection.Y p.ZIndex = 9
	local pad = Instance.new("UIPadding", p) pad.PaddingTop = UDim.new(0, 4) pad.PaddingBottom = UDim.new(0, 12) pad.PaddingLeft = UDim.new(0, 2) pad.PaddingRight = UDim.new(0, 2)
	local lay = Instance.new("UIListLayout", p) lay.Padding = UDim.new(0, 8) lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
	return p
end
local combatPage = createPage()
local funPage = createPage() funPage.Visible = false
local customPage = createPage() customPage.Visible = false

local allButtons = {}
local function createButton(page, text)
	local b = Instance.new("TextButton", page) b.Size = UDim2.new(1, -8, 0, 46) b.BackgroundColor3 = COLORS.button b.BackgroundTransparency = 0.12 b.BorderSizePixel = 0 b.AutoButtonColor = false b.Font = Enum.Font.GothamMedium b.Text = text b.TextSize = 13 b.TextColor3 = COLORS.text b.ZIndex = 12
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 12)
	local s = Instance.new("UIStroke", b) s.Color = COLORS.border s.Thickness = 1 s.Transparency = 0.82
	local sc = Instance.new("UIScale", b) sc.Scale = 1
	b.Activated:Connect(function()
		TweenService:Create(sc, TweenInfo.new(0.08, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Scale = 0.965 }):Play()
		task.delay(0.08, function() if sc.Parent then TweenService:Create(sc, TweenInfo.new(0.30, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play() end end)
	end)
	b.MouseEnter:Connect(function() TweenService:Create(b, TweenInfo.new(0.15), { BackgroundColor3 = COLORS.buttonHover }):Play() TweenService:Create(s, TweenInfo.new(0.15), { Transparency = 0.55 }):Play() end)
	b.MouseLeave:Connect(function() local en = b:GetAttribute("Enabled") TweenService:Create(b, TweenInfo.new(0.18), { BackgroundColor3 = en and ACTIVE_COLOR or COLORS.button }):Play() TweenService:Create(s, TweenInfo.new(0.18), { Transparency = en and 0.26 or 0.82 }):Play() end)
	table.insert(allButtons, b) return b
end

local function animateButton(button, enabled)
	button:SetAttribute("Enabled", enabled)
	TweenService:Create(button, TweenInfo.new(0.24, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { BackgroundColor3 = enabled and ACTIVE_COLOR or COLORS.button }):Play()
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then TweenService:Create(stroke, TweenInfo.new(0.25), { Transparency = enabled and 0.26 or 0.82 }):Play() end
end

-- BUTTONS (COMBAT)
local espButton = createButton(combatPage, "ESP  •  OFF") espButton.Activated:Connect(function() ESP_ENABLED = not ESP_ENABLED espButton.Text = "ESP  •  " .. (ESP_ENABLED and "ON" or "OFF") animateButton(espButton, ESP_ENABLED) end)
local aimButton = createButton(combatPage, "AIMBOT  •  OFF") aimButton.Activated:Connect(function() AIM_ENABLED = not AIM_ENABLED if not AIM_ENABLED then currentAimTarget = nil end aimButton.Text = "AIMBOT  •  " .. (AIM_ENABLED and "ON" or "OFF") animateButton(aimButton, AIM_ENABLED) end)
local speedButton = createButton(combatPage, "SPEED  •  OFF") speedButton.Activated:Connect(function() if not SPEED_ENABLED then SPEED_ENABLED = true SPEED_INDEX = 1 else SPEED_INDEX += 1 if SPEED_INDEX > #SPEED_VALUES then SPEED_ENABLED = false SPEED_INDEX = 1 end end CURRENT_SPEED = SPEED_VALUES[SPEED_INDEX] applySpeed() speedButton.Text = "SPEED  •  " .. (SPEED_ENABLED and tostring(CURRENT_SPEED) or "OFF") animateButton(speedButton, SPEED_ENABLED) end)
local jumpButton = createButton(combatPage, "JUMP  •  OFF") jumpButton.Activated:Connect(function() if not JUMP_ENABLED then JUMP_ENABLED = true JUMP_INDEX = 1 else JUMP_INDEX += 1 if JUMP_INDEX > #JUMP_VALUES then JUMP_ENABLED = false JUMP_INDEX = 1 end end CURRENT_JUMP = JUMP_VALUES[JUMP_INDEX] applyJump() jumpButton.Text = "JUMP  •  " .. (JUMP_ENABLED and tostring(CURRENT_JUMP) or "OFF") animateButton(jumpButton, JUMP_ENABLED) end)
local noclipButton = createButton(combatPage, "NOCLIP  •  OFF") noclipButton.Activated:Connect(function() NOCLIP_ENABLED = not NOCLIP_ENABLED noclipButton.Text = "NOCLIP  •  " .. (NOCLIP_ENABLED and "ON" or "OFF") animateButton(noclipButton, NOCLIP_ENABLED) end)
local godModeButton = createButton(combatPage, "GODMODE  •  OFF") godModeButton.Activated:Connect(function() GODMODE_ENABLED = not GODMODE_ENABLED if GODMODE_ENABLED then setupGodMode() else disableGodMode() end godModeButton.Text = "GODMODE  •  " .. (GODMODE_ENABLED and "ON" or "OFF") animateButton(godModeButton, GODMODE_ENABLED) end)
local flyButton = createButton(combatPage, "FLY  •  OFF") flyButton.Activated:Connect(function() if not FLY_ENABLED then FLY_ENABLED = true FLY_INDEX = 1 else FLY_INDEX += 1 if FLY_INDEX > #FLY_VALUES then FLY_ENABLED = false FLY_INDEX = 0 CURRENT_FLY_SPEED = 0 cleanupFly() end end if FLY_ENABLED then CURRENT_FLY_SPEED = FLY_VALUES[FLY_INDEX] flyButton.Text = "FLY  •  " .. tostring(CURRENT_FLY_SPEED) setupFly() else flyButton.Text = "FLY  •  OFF" end animateButton(flyButton, FLY_ENABLED) end)
local antiKickButton = createButton(combatPage, "ANTI-KICK  •  ON") animateButton(antiKickButton, true) antiKickButton.Activated:Connect(function() ANTI_KICK_ENABLED = not ANTI_KICK_ENABLED antiKickButton.Text = "ANTI-KICK  •  " .. (ANTI_KICK_ENABLED and "ON" or "OFF") animateButton(antiKickButton, ANTI_KICK_ENABLED) end)
local fovButton = createButton(combatPage, "FOV  •  250") fovButton.Activated:Connect(function() if FOV == 250 then FOV = 175 elseif FOV == 175 then FOV = 100 else FOV = 250 end fovButton.Text = "FOV  •  " .. tostring(FOV) end)

-- BUTTONS (FUN)
local spinButton = createButton(funPage, "SPIN  •  OFF") spinButton.Activated:Connect(function() SPIN_ENABLED = not SPIN_ENABLED spinButton.Text = "SPIN  •  " .. (SPIN_ENABLED and "ON" or "OFF") animateButton(spinButton, SPIN_ENABLED) end)
local gravityButton = createButton(funPage, "ZERO GRAVITY  •  OFF") gravityButton.Activated:Connect(function() ZERO_GRAVITY_ENABLED = not ZERO_GRAVITY_ENABLED gravityButton.Text = "ZERO GRAVITY  •  " .. (ZERO_GRAVITY_ENABLED and "ON" or "OFF") animateButton(gravityButton, ZERO_GRAVITY_ENABLED) if ZERO_GRAVITY_ENABLED then setupZeroG() else cleanupZeroG() end end)
local launchButton = createButton(funPage, "LAUNCH  UP") launchButton.Activated:Connect(function() local root = getRoot(getCharacter()) if root then root.AssemblyLinearVelocity = Vector3.new(0, 120, 0) end TweenService:Create(launchButton, TweenInfo.new(0.18), { BackgroundColor3 = ACTIVE_COLOR }):Play() task.delay(0.25, function() if launchButton.Parent then TweenService:Create(launchButton, TweenInfo.new(0.35), { BackgroundColor3 = COLORS.button }):Play() end end) end)
local resetButton = createButton(funPage, "RESET FUN EFFECTS") resetButton.Activated:Connect(function() SPIN_ENABLED = false ZERO_GRAVITY_ENABLED = false cleanupZeroG() spinButton.Text = "SPIN  •  OFF" gravityButton.Text = "ZERO GRAVITY  •  OFF" animateButton(spinButton, false) animateButton(gravityButton, false) end)

-- BUTTONS (CUSTOM)
local colorTitle = createButton(customPage, "ACTIVE BUTTON COLOR") colorTitle.TextSize = 12 colorTitle.BackgroundColor3 = COLORS.panel
for _, preset in ipairs(COLOR_PRESETS) do
	local button = createButton(customPage, preset.name) button.BackgroundColor3 = preset.color button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Activated:Connect(function() ACTIVE_COLOR = preset.color refreshButtonColors() end)
end
local fovToggle = createButton(customPage, "FOV CIRCLE  •  ON") fovToggle.Activated:Connect(function() FOV_VISIBLE = not FOV_VISIBLE fovToggle.Text = "FOV CIRCLE  •  " .. (FOV_VISIBLE and "ON" or "OFF") animateButton(fovToggle, FOV_VISIBLE) end)
local glowToggle = createButton(customPage, "BACKGROUND GLOW  •  ON") glowToggle.Activated:Connect(function() GLOW_ENABLED = not GLOW_ENABLED glowToggle.Text = "BACKGROUND GLOW  •  " .. (GLOW_ENABLED and "ON" or "OFF") animateButton(glowToggle, GLOW_ENABLED) end)
local resetCustomization = createButton(customPage, "RESET CUSTOMIZATION") resetCustomization.Activated:Connect(function() ACTIVE_COLOR = DEFAULT_ACTIVE_COLOR FOV_VISIBLE = true GLOW_ENABLED = true fovToggle.Text = "FOV CIRCLE  •  ON" glowToggle.Text = "BACKGROUND GLOW  •  ON" animateButton(fovToggle, true) animateButton(glowToggle, true) refreshButtonColors() end)

local switchingTab = false
local function styleTabs(tab) local function style(b, act, col) TweenService:Create(b, TweenInfo.new(0.22), { BackgroundColor3 = act and col or COLORS.button, TextColor3 = act and COLORS.text or COLORS.subtext }):Play() end style(combatTab, tab == "Combat", COLORS.blue) style(funTab, tab == "Fun", COLORS.purple) style(customTab, tab == "Custom", ACTIVE_COLOR) end
local function switchTab(tab)
	if switchingTab or tab == activeTab then return end switchingTab = true
	local pages = { Combat = combatPage, Fun = funPage, Custom = customPage } local order = { Combat = 1, Fun = 2, Custom = 3 }
	local oldPage, newPage = pages[activeTab], pages[tab] local dir = order[tab] > order[activeTab] and 1 or -1
	newPage.Visible = true newPage.Position = UDim2.new(dir, dir * 15, 0, 0)
	TweenService:Create(oldPage, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), { Position = UDim2.new(-dir, -dir * 15, 0, 0) }):Play()
	local inc = TweenService:Create(newPage, TweenInfo.new(0.30, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0, 0) }) inc:Play() inc.Completed:Wait()
	oldPage.Visible = false oldPage.Position = UDim2.fromScale(0, 0) activeTab = tab styleTabs(tab) switchingTab = false
end
styleTabs("Combat")
combatTab.Activated:Connect(function() switchTab("Combat") end) funTab.Activated:Connect(function() switchTab("Fun") end) customTab.Activated:Connect(function() switchTab("Custom") end)

local fovCircle = Instance.new("Frame", gui) fovCircle.Name = "TBAM_FOV" fovCircle.AnchorPoint = Vector2.new(0.5, 0.5) fovCircle.BackgroundTransparency = 1 fovCircle.BorderSizePixel = 0 fovCircle.ZIndex = 30
Instance.new("UICorner", fovCircle).CornerRadius = UDim.new(1, 0)
local fovStroke = Instance.new("UIStroke", fovCircle) fovStroke.Color = ACTIVE_COLOR fovStroke.Transparency = 0.45 fovStroke.Thickness = 1.25
local fovScale = Instance.new("UIScale", fovCircle) fovScale.Scale = 0
local lastFOVState = false
RunService.RenderStepped:Connect(function()
	local camera = getCamera() if not camera then return end
	fovCircle.Position = UDim2.fromOffset(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2) fovCircle.Size = UDim2.fromOffset(FOV * 2, FOV * 2) fovStroke.Color = ACTIVE_COLOR
	local shouldShow = AIM_ENABLED and FOV_VISIBLE
	if shouldShow ~= lastFOVState then
		lastFOVState = shouldShow
		if shouldShow then fovCircle.Visible = true TweenService:Create(fovScale, TweenInfo.new(0.20, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		else TweenService:Create(fovScale, TweenInfo.new(0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { Scale = 0 }):Play() task.delay(0.16, function() if not (AIM_ENABLED and FOV_VISIBLE) then fovCircle.Visible = false end end) end
	end
end)

function refreshButtonColors()
	for _, button in ipairs(allButtons) do if button:GetAttribute("Enabled") then button.BackgroundColor3 = ACTIVE_COLOR end end
	restoreStroke.Color = ACTIVE_COLOR fovStroke.Color = ACTIVE_COLOR
	for _, page in ipairs({ combatPage, funPage, customPage }) do page.ScrollBarImageColor3 = ACTIVE_COLOR end
end

Players.PlayerAdded:Connect(function(player) player.CharacterAdded:Connect(function(character) task.wait(0.5) saveOriginalMovement(character) createESP(character, true) end) end)
Players.PlayerRemoving:Connect(function(player) if player.Character then removeESP(player.Character) originalMovement[player.Character] = nil end end)
Workspace.DescendantAdded:Connect(function(obj) if not obj:IsA("Model") then return end task.defer(function() if Players:GetPlayerFromCharacter(obj) then return end if isTarget(obj) then createESP(obj, false) end end) end)

LocalPlayer.CharacterAdded:Connect(function(character)
	task.wait(0.5) saveOriginalMovement(character) applySpeed() applyJump()
	if GODMODE_ENABLED then task.wait(0.2) setupGodMode() end
	if FLY_ENABLED then task.wait(0.2) setupFly() end
	if ZERO_GRAVITY_ENABLED then task.wait(0.2) setupZeroG() end
	if NOCLIP_ENABLED then task.wait(0.2) for _, part in ipairs(character:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = false end end end
end)

minimized = true menuAnimating = false menu.Visible = false
restoreButton.Visible = true restoreButton.Position = UDim2.fromScale(0.035, 0.18) restoreButton.Size = CLOSED_SIZE
local initialCharacter = getCharacter() if initialCharacter then saveOriginalMovement(initialCharacter) if GODMODE_ENABLED then setupGodMode() end end
scanTargets() applySpeed() applyJump() refreshButtonColors()
