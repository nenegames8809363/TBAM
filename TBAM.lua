--// =========================================================
--// THE BROKEN ARROW MENU
--// TBAM
--// STABLE EDITION v2.4
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

local SPEED_VALUES = {
	50,
	75,
	100,
	150
}

local JUMP_VALUES = {
	50,
	75,
	100,
	125
}

-- Valores usados SOMENTE como fallback
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

-- Guarda os valores originais de cada personagem
local originalMovement = {}

--// =========================================================
--// CUSTOMIZATION
--// =========================================================

local ACTIVE_COLOR = Color3.fromRGB(
	145,
	85,
	205
)

local DEFAULT_ACTIVE_COLOR = ACTIVE_COLOR

local COLOR_PRESETS = {
	{
		name = "PURPLE",
		color = Color3.fromRGB(145,85,205)
	},
	{
		name = "BLUE",
		color = Color3.fromRGB(70,130,235)
	},
	{
		name = "GREEN",
		color = Color3.fromRGB(60,180,110)
	},
	{
		name = "RED",
		color = Color3.fromRGB(220,70,85)
	},
	{
		name = "ORANGE",
		color = Color3.fromRGB(225,125,55)
	},
	{
		name = "CYAN",
		color = Color3.fromRGB(45,190,210)
	}
}

--// =========================================================
--// COLORS
--// =========================================================

local COLORS = {
	background = Color3.fromRGB(10,11,16),
	panel = Color3.fromRGB(17,18,25),
	button = Color3.fromRGB(27,28,37),
	buttonHover = Color3.fromRGB(34,35,46),
	border = Color3.fromRGB(92,96,125),

	text = Color3.fromRGB(242,242,248),
	subtext = Color3.fromRGB(150,153,172),

	blue = Color3.fromRGB(71,105,210),
	blueBright = Color3.fromRGB(75,145,255),
	green = Color3.fromRGB(62,175,105),
	purple = Color3.fromRGB(145,85,205),
	red = Color3.fromRGB(220,75,85),
	orange = Color3.fromRGB(220,115,60)
}

--// =========================================================
--// CHARACTER HELPERS
--// =========================================================

local function getCharacter()
	return LocalPlayer.Character
end

local function getHumanoid(model)
	if not model then
		return nil
	end

	return model:FindFirstChildOfClass("Humanoid")
end

local function getRoot(model)
	if not model then
		return nil
	end

	return model:FindFirstChild("HumanoidRootPart")
		or model:FindFirstChild("UpperTorso")
		or model:FindFirstChild("Torso")
end

local function isTarget(model)
	if not model then
		return false
	end

	if not model:IsA("Model") then
		return false
	end

	if model == getCharacter() then
		return false
	end

	local humanoid = getHumanoid(model)
	local root = getRoot(model)

	if not humanoid or not root then
		return false
	end

	if humanoid.Health <= 0 then
		return false
	end

	return true
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

	if not camera or not targetPart then
		return false
	end

	local params = RaycastParams.new()

	params.FilterType =
		Enum.RaycastFilterType.Exclude

	params.FilterDescendantsInstances = {
		character
	}

	params.IgnoreWater = true

	local origin = camera.CFrame.Position
	local direction = targetPart.Position - origin

	local result = Workspace:Raycast(
		origin,
		direction,
		params
	)

	if not result then
		return true
	end

	return result.Instance:IsDescendantOf(
		targetPart.Parent
	)
end

--// =========================================================
--// ESP REMOVE
--// =========================================================

local function removeESP(model)

	local data = tracked[model]

	if not data then
		return
	end

	if data.highlight then
		data.highlight:Destroy()
	end

	if data.billboard then
		data.billboard:Destroy()
	end

	tracked[model] = nil
end

--// =========================================================
--// ESP CREATE
--// =========================================================

local function createESP(model,isPlayer)

	if not model
		or not model.Parent
		or tracked[model]
		or not isTarget(model) then

		return
	end

	local humanoid = getHumanoid(model)
	local root = getRoot(model)

	if not humanoid or not root then
		return
	end

	local highlight = Instance.new("Highlight")

	highlight.Name = "TBAM_ESP"
	highlight.Adornee = model

	highlight.DepthMode =
		Enum.HighlightDepthMode.AlwaysOnTop

	highlight.FillTransparency = 0.76
	highlight.OutlineTransparency = 0

	highlight.FillColor =
		isPlayer
		and Color3.fromRGB(45,125,255)
		or Color3.fromRGB(255,65,70)

	highlight.OutlineColor =
		isPlayer
		and Color3.fromRGB(110,195,255)
		or Color3.fromRGB(255,130,130)

	highlight.Enabled = ESP_ENABLED
	highlight.Parent = model

	----------------------------------------------------------

	local billboard = Instance.new("BillboardGui")

	billboard.Name = "TBAM_Info"
	billboard.Adornee = root

	billboard.Size =
		UDim2.fromOffset(210,78)

	billboard.StudsOffset =
		Vector3.new(0,3.4,0)

	billboard.AlwaysOnTop = true
	billboard.Enabled = ESP_ENABLED
	billboard.Parent = root

	----------------------------------------------------------

	local label = Instance.new("TextLabel")

	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1,1)

	label.Font = Enum.Font.GothamBold
	label.TextSize = 13

	label.TextWrapped = true
	label.TextYAlignment =
		Enum.TextYAlignment.Center

	label.TextColor3 =
		Color3.fromRGB(255,255,255)

	label.TextStrokeTransparency = 0.35

	label.Text =
		(isPlayer and "PLAYER" or "BOT")
		.. "\n"
		.. model.Name

	label.Parent = billboard

	----------------------------------------------------------

	tracked[model] = {
		model = model,
		highlight = highlight,
		billboard = billboard,
		label = label,
		isPlayer = isPlayer
	}
end

--// =========================================================
--// ESP SCAN
--// =========================================================

local function scanTargets()

	for _,player in ipairs(Players:GetPlayers()) do

		if player ~= LocalPlayer
			and player.Character then

			createESP(
				player.Character,
				true
			)

		end
	end

	for _,obj in ipairs(Workspace:GetDescendants()) do

		if obj:IsA("Model")
			and not Players:GetPlayerFromCharacter(obj)
			and isTarget(obj) then

			createESP(
				obj,
				false
			)

		end
	end
end

--// =========================================================
--// ESP UPDATE
--// =========================================================

task.spawn(function()

	while true do

		task.wait(0.45)

		scanTargets()

		for model,data in pairs(tracked) do

			if not model
				or not model.Parent
				or not isTarget(model) then

				removeESP(model)

			else

				data.highlight.Enabled =
					ESP_ENABLED

				data.billboard.Enabled =
					ESP_ENABLED

				local humanoid =
					getHumanoid(model)

				local root =
					getRoot(model)

				local myRoot =
					getRoot(getCharacter())

				if humanoid and root then

					local distance = 0

					if myRoot then
						distance = math.floor(
							(
								root.Position
								- myRoot.Position
							).Magnitude
						)
					end

					local visible =
						isVisible(root)

					data.highlight.FillTransparency =
						visible
						and 0.76
						or 0.91

					data.label.Text =
						(
							data.isPlayer
							and "PLAYER"
							or "BOT"
						)
						.. "\n"
						.. model.Name
						.. "\nHP: "
						.. math.floor(
							humanoid.Health
						)
						.. "  •  "
						.. distance
						.. "m"
				end
			end
		end
	end
end)

--// =========================================================
--// AIMBOT
--// =========================================================

local function getTarget()

	local camera = getCamera()
	local character = getCharacter()
	local myRoot = getRoot(character)

	if not camera or not myRoot then
		return nil
	end

	local bestTarget = nil
	local bestScreenDistance = FOV

	local viewport = camera.ViewportSize

	local center =
		Vector2.new(
			viewport.X / 2,
			viewport.Y / 2
		)

	local function checkModel(model)

		if not model
			or model == character
			or not model.Parent
			or not isTarget(model) then

			return
		end

		local humanoid =
			getHumanoid(model)

		if not humanoid
			or humanoid.Health <= 0 then

			return
		end

		local head =
			model:FindFirstChild(AIM_PART)

		if not head
			or not head:IsA("BasePart") then

			return
		end

		local worldDistance =
			(
				head.Position
				- myRoot.Position
			).Magnitude

		if worldDistance >
			MAX_DISTANCE then

			return
		end

		local screenPos,onScreen =
			camera:WorldToViewportPoint(
				head.Position
			)

		if not onScreen
			or screenPos.Z <= 0 then

			return
		end

		local screenDistance =
			(
				Vector2.new(
					screenPos.X,
					screenPos.Y
				)
				- center
			).Magnitude

		if screenDistance > FOV then
			return
		end

		if not isVisible(head) then
			return
		end

		if screenDistance <
			bestScreenDistance then

			bestScreenDistance =
				screenDistance

			bestTarget =
				head
		end
	end

	-- Players
	for _,player in ipairs(Players:GetPlayers()) do

		if player ~= LocalPlayer
			and player.Character then

			checkModel(
				player.Character
			)

		end
	end

	-- Bots
	for model in pairs(tracked) do

		if not Players:GetPlayerFromCharacter(model) then
			checkModel(model)
		end

	end

	return bestTarget
end

RunService:BindToRenderStep(
	"TBAM_Aimbot",
	Enum.RenderPriority.Camera.Value + 1,
	function()

		if not AIM_ENABLED then

			currentAimTarget = nil
			return

		end

		local camera = getCamera()

		if not camera then
			return
		end

		-- Mantém o alvo enquanto ele continuar válido
		if currentAimTarget then

			local model =
				currentAimTarget.Parent

			local humanoid =
				model and getHumanoid(model)

			if not model
				or not model.Parent
				or not humanoid
				or humanoid.Health <= 0
				or not isVisible(currentAimTarget) then

				currentAimTarget = nil
			end
		end

		if not currentAimTarget then
			currentAimTarget = getTarget()
		end

		if not currentAimTarget then
			return
		end

		camera.CFrame =
			CFrame.lookAt(
				camera.CFrame.Position,
				currentAimTarget.Position
			)
	end
)

--// =========================================================
--// ORIGINAL MOVEMENT STORAGE
--// =========================================================

local function saveOriginalMovement(character)

	if not character then
		return
	end

	if originalMovement[character] then
		return
	end

	local humanoid =
		getHumanoid(character)

	if not humanoid then
		return
	end

	originalMovement[character] = {
		WalkSpeed = humanoid.WalkSpeed,
		UseJumpPower = humanoid.UseJumpPower,
		JumpPower = humanoid.JumpPower,
		JumpHeight = humanoid.JumpHeight
	}
end

--// =========================================================
--// SPEED
--// =========================================================

local function applySpeed()

	local character =
		getCharacter()

	if not character then
		return
	end

	local humanoid =
		getHumanoid(character)

	if not humanoid then
		return
	end

	saveOriginalMovement(character)

	local original =
		originalMovement[character]

	if SPEED_ENABLED then

		humanoid.WalkSpeed =
			CURRENT_SPEED

	else

		humanoid.WalkSpeed =
			(
				original
				and original.WalkSpeed
			)
			or FALLBACK_WALK_SPEED
	end
end

--// =========================================================
--// JUMP
--// =========================================================

local function applyJump()

	local character =
		getCharacter()

	if not character then
		return
	end

	local humanoid =
		getHumanoid(character)

	if not humanoid then
		return
	end

	saveOriginalMovement(character)

	local original =
		originalMovement[character]

	if JUMP_ENABLED then

		-- TBAM usa JumpPower enquanto ativado
		humanoid.UseJumpPower = true
		humanoid.JumpPower = CURRENT_JUMP

	else

		-- RESTAURA EXATAMENTE O SISTEMA DO JOGO
		if original then

			humanoid.UseJumpPower =
				original.UseJumpPower

			humanoid.JumpPower =
				original.JumpPower

			humanoid.JumpHeight =
				original.JumpHeight

		else

			humanoid.UseJumpPower = true
			humanoid.JumpPower =
				FALLBACK_JUMP_POWER

		end
	end
end

--// =========================================================
--// NOCLIP
--// =========================================================

RunService.Stepped:Connect(function()

	if not NOCLIP_ENABLED then
		return
	end

	local character =
		getCharacter()

	if not character then
		return
	end

	for _,part in ipairs(
		character:GetDescendants()
	) do

		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end
end)

--// =========================================================
--// SPIN
--// =========================================================

RunService.RenderStepped:Connect(function(dt)

	if not SPIN_ENABLED then
		return
	end

	local root =
		getRoot(getCharacter())

	if not root then
		return
	end

	root.CFrame =
		root.CFrame
		* CFrame.Angles(
			0,
			math.rad(480) * dt,
			0
		)
end)

--// =========================================================
--// ZERO GRAVITY
--// =========================================================

RunService.Heartbeat:Connect(function()

	if not ZERO_GRAVITY_ENABLED then
		return
	end

	local root =
		getRoot(getCharacter())

	if not root then
		return
	end

	root.AssemblyLinearVelocity =
		Vector3.new(
			root.AssemblyLinearVelocity.X,
			0,
			root.AssemblyLinearVelocity.Z
		)
end)

--// =========================================================
--// GUI
--// =========================================================

local gui =
	Instance.new("ScreenGui")

gui.Name = "TBAM_GUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior =
	Enum.ZIndexBehavior.Sibling

gui.Parent =
	LocalPlayer:WaitForChild("PlayerGui")

--// =========================================================
--// MENU SIZES
--// =========================================================

local OPEN_SIZE =
	UDim2.fromOffset(335,300)

local CLOSED_SIZE =
	UDim2.fromOffset(54,54)

--// =========================================================
--// MAIN MENU
--// =========================================================

local menu =
	Instance.new("Frame")

menu.Name =
	"TheBrokenArrowMenu"

menu.Size =
	CLOSED_SIZE

menu.Position =
	UDim2.fromScale(
		0.035,
		0.18
	)

menu.BackgroundColor3 =
	COLORS.background

menu.BackgroundTransparency = 1
menu.BorderSizePixel = 0
menu.ClipsDescendants = true
menu.Active = true
menu.Visible = false
menu.Parent = gui

local menuCorner =
	Instance.new("UICorner")

menuCorner.CornerRadius =
	UDim.new(0,20)

menuCorner.Parent =
	menu

local menuStroke =
	Instance.new("UIStroke")

menuStroke.Color =
	COLORS.border

menuStroke.Thickness = 1
menuStroke.Transparency = 0.55
menuStroke.Parent = menu

--// =========================================================
--// GLOW
--// =========================================================

local glowLayer =
	Instance.new("Frame")

glowLayer.Size =
	UDim2.fromScale(1,1)

glowLayer.BackgroundTransparency = 1
glowLayer.ClipsDescendants = true
glowLayer.ZIndex = 0
glowLayer.Parent = menu

local function createSoftGlow(
	position,
	size,
	color
)

	local glow =
		Instance.new("Frame")

	glow.Size =
		UDim2.fromOffset(
			size,
			size
		)

	glow.Position =
		position

	glow.AnchorPoint =
		Vector2.new(0.5,0.5)

	glow.BackgroundColor3 =
		color

	glow.BackgroundTransparency =
		0.88

	glow.BorderSizePixel = 0
	glow.ZIndex = 0
	glow.Parent = glowLayer

	local corner =
		Instance.new("UICorner")

	corner.CornerRadius =
		UDim.new(1,0)

	corner.Parent =
		glow

	return glow
end

local glowA =
	createSoftGlow(
		UDim2.fromScale(-0.12,0.08),
		250,
		Color3.fromRGB(85,65,255)
	)

local glowB =
	createSoftGlow(
		UDim2.fromScale(1.12,0.43),
		270,
		Color3.fromRGB(35,130,255)
	)

local glowC =
	createSoftGlow(
		UDim2.fromScale(0.42,1.12),
		260,
		Color3.fromRGB(190,55,180)
	)

task.spawn(function()

	while menu.Parent do

		if not GLOW_ENABLED then

			glowA.Visible = false
			glowB.Visible = false
			glowC.Visible = false

			task.wait(0.4)

		else

			glowA.Visible = true
			glowB.Visible = true
			glowC.Visible = true

			local t1 =
				TweenService:Create(
					glowA,
					TweenInfo.new(
						8,
						Enum.EasingStyle.Sine,
						Enum.EasingDirection.InOut
					),
					{
						Position =
							UDim2.fromScale(
								0.82,
								0.30
							)
					}
				)

			local t2 =
				TweenService:Create(
					glowB,
					TweenInfo.new(
						9,
						Enum.EasingStyle.Sine,
						Enum.EasingDirection.InOut
					),
					{
						Position =
							UDim2.fromScale(
								0.17,
								0.79
							)
					}
				)

			local t3 =
				TweenService:Create(
					glowC,
					TweenInfo.new(
						8.5,
						Enum.EasingStyle.Sine,
						Enum.EasingDirection.InOut
					),
					{
						Position =
							UDim2.fromScale(
								0.80,
								0.10
							)
					}
				)

			t1:Play()
			t2:Play()
			t3:Play()

			task.wait(8)

			glowA.Position =
				UDim2.fromScale(-0.12,0.08)

			glowB.Position =
				UDim2.fromScale(1.12,0.43)

			glowC.Position =
				UDim2.fromScale(0.42,1.12)
		end
	end
end)

--// =========================================================
--// GLASS
--// =========================================================

local glass =
	Instance.new("Frame")

glass.Size =
	UDim2.fromScale(1,1)

glass.BackgroundColor3 =
	Color3.fromRGB(20,21,29)

glass.BackgroundTransparency = 0.42
glass.BorderSizePixel = 0
glass.ZIndex = 2
glass.Parent = menu

local glassCorner =
	Instance.new("UICorner")

glassCorner.CornerRadius =
	UDim.new(0,20)

glassCorner.Parent =
	glass

--// =========================================================
--// HEADER
--// =========================================================

local header =
	Instance.new("Frame")

header.Position =
	UDim2.fromOffset(13,8)

header.Size =
	UDim2.new(1,-26,0,54)

header.BackgroundTransparency = 1
header.ZIndex = 10
header.Parent = menu

local title =
	Instance.new("TextLabel")

title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(6,0)
title.Size = UDim2.new(1,-65,0,30)

title.Font =
	Enum.Font.GothamBold

title.Text = "TBAM"
title.TextSize = 22
title.TextColor3 = COLORS.text
title.TextXAlignment =
	Enum.TextXAlignment.Left

title.ZIndex = 11
title.Parent = header

local subtitle =
	Instance.new("TextLabel")

subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(7,27)
subtitle.Size = UDim2.new(1,-65,0,20)

subtitle.Font =
	Enum.Font.GothamMedium

subtitle.Text =
	"THE BROKEN ARROW  •  CONTROL PANEL"

subtitle.TextSize = 9
subtitle.TextColor3 = COLORS.subtext
subtitle.TextXAlignment =
	Enum.TextXAlignment.Left

subtitle.ZIndex = 11
subtitle.Parent = header

--// =========================================================
--// CLOSE
--// =========================================================

local closeButton =
	Instance.new("TextButton")

closeButton.Size =
	UDim2.fromOffset(36,36)

closeButton.Position =
	UDim2.new(1,-36,0,3)

closeButton.BackgroundColor3 =
	Color3.fromRGB(30,31,40)

closeButton.BackgroundTransparency = 0.15
closeButton.Text = "×"

closeButton.Font =
	Enum.Font.GothamMedium

closeButton.TextSize = 23
closeButton.TextColor3 = COLORS.text
closeButton.AutoButtonColor = false
closeButton.BorderSizePixel = 0
closeButton.ZIndex = 20
closeButton.Parent = header

local closeCorner =
	Instance.new("UICorner")

closeCorner.CornerRadius =
	UDim.new(1,0)

closeCorner.Parent =
	closeButton

--// =========================================================
--// RESTORE ICON
--// =========================================================

local restoreButton =
	Instance.new("TextButton")

restoreButton.Size =
	CLOSED_SIZE

restoreButton.Position =
	UDim2.fromScale(0.035,0.18)

restoreButton.AnchorPoint =
	Vector2.new(0.5,0.5)

restoreButton.BackgroundColor3 =
	Color3.fromRGB(17,18,25)

restoreButton.Text = "➜"
restoreButton.TextSize = 24

restoreButton.Font =
	Enum.Font.GothamBold

restoreButton.TextColor3 =
	COLORS.text

restoreButton.AutoButtonColor = false
restoreButton.BorderSizePixel = 0
restoreButton.Visible = true
restoreButton.ZIndex = 50
restoreButton.Parent = gui

local restoreCorner =
	Instance.new("UICorner")

restoreCorner.CornerRadius =
	UDim.new(1,0)

restoreCorner.Parent =
	restoreButton

local restoreStroke =
	Instance.new("UIStroke")

restoreStroke.Color =
	ACTIVE_COLOR

restoreStroke.Transparency = 0.35
restoreStroke.Thickness = 1.2
restoreStroke.Parent = restoreButton

--// =========================================================
--// MENU POSITION HELPERS
--// =========================================================

local menuAnchor =
	UDim2.fromScale(0.035,0.18)

local function iconToMenuPosition()

	return UDim2.new(
		restoreButton.Position.X.Scale,
		restoreButton.Position.X.Offset - 27,

		restoreButton.Position.Y.Scale,
		restoreButton.Position.Y.Offset - 27
	)
end

local function menuToIconPosition(position)

	return UDim2.new(
		position.X.Scale,
		position.X.Offset + 27,

		position.Y.Scale,
		position.Y.Offset + 27
	)
end

--// =========================================================
--// MINIMIZED ICON DRAGGING
--// =========================================================

local miniDragging = false
local miniDragStart = nil
local miniStartPos = nil
local miniMoved = false
local skipNextRestore = false

restoreButton.InputBegan:Connect(function(input)

	if input.UserInputType ==
		Enum.UserInputType.MouseButton1
		or input.UserInputType ==
		Enum.UserInputType.Touch then

		miniDragging = true
		miniMoved = false

		miniDragStart =
			input.Position

		miniStartPos =
			restoreButton.Position
	end
end)

UserInputService.InputChanged:Connect(function(input)

	if not miniDragging then
		return
	end

	if input.UserInputType ~=
		Enum.UserInputType.MouseMovement
		and input.UserInputType ~=
		Enum.UserInputType.Touch then

		return
	end

	local delta =
		input.Position
		- miniDragStart

	if math.abs(delta.X) > 8
		or math.abs(delta.Y) > 8 then

		miniMoved = true
	end

	if not miniMoved then
		return
	end

	restoreButton.Position =
		UDim2.new(
			miniStartPos.X.Scale,
			miniStartPos.X.Offset + delta.X,

			miniStartPos.Y.Scale,
			miniStartPos.Y.Offset + delta.Y
		)
end)

UserInputService.InputEnded:Connect(function(input)

	if input.UserInputType ==
		Enum.UserInputType.MouseButton1
		or input.UserInputType ==
		Enum.UserInputType.Touch then

		if miniMoved then
			skipNextRestore = true

			task.defer(function()
				miniMoved = false
			end)
		end

		miniDragging = false
	end
end)

--// =========================================================
--// OPEN / CLOSE
--// =========================================================

local function openMenu()

	if not minimized or menuAnimating then
		return
	end

	menuAnimating = true

	-- Abre exatamente na posição atual do ícone
	menuAnchor =
		iconToMenuPosition()

	menu.Position =
		menuAnchor

	menu.Size =
		CLOSED_SIZE

	menu.BackgroundTransparency = 1
	menu.Visible = true

	restoreButton.Visible = false

	local sizeTween =
		TweenService:Create(
			menu,
			TweenInfo.new(
				0.46,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.Out
			),
			{
				Size = OPEN_SIZE
			}
		)

	local fadeTween =
		TweenService:Create(
			menu,
			TweenInfo.new(
				0.30,
				Enum.EasingStyle.Quart,
				Enum.EasingDirection.Out
			),
			{
				BackgroundTransparency = 0.04
			}
		)

	sizeTween:Play()
	fadeTween:Play()

	sizeTween.Completed:Wait()

	minimized = false
	menuAnimating = false
end

local function closeMenu()

	if minimized or menuAnimating then
		return
	end

	menuAnimating = true

	menuAnchor =
		menu.Position

	local sizeTween =
		TweenService:Create(
			menu,
			TweenInfo.new(
				0.34,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.In
			),
			{
				Size = CLOSED_SIZE
			}
		)

	local fadeTween =
		TweenService:Create(
			menu,
			TweenInfo.new(
				0.24,
				Enum.EasingStyle.Quart,
				Enum.EasingDirection.In
			),
			{
				BackgroundTransparency = 1
			}
		)

	sizeTween:Play()
	fadeTween:Play()

	sizeTween.Completed:Wait()

	menu.Visible = false

	restoreButton.Position =
		menuToIconPosition(menuAnchor)

	restoreButton.Size =
		UDim2.fromOffset(4,4)

	restoreButton.Visible = true

	TweenService:Create(
		restoreButton,
		TweenInfo.new(
			0.42,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out
		),
		{
			Size = CLOSED_SIZE
		}
	):Play()

	minimized = true
	menuAnimating = false
end

closeButton.Activated:Connect(closeMenu)

restoreButton.Activated:Connect(function()

	if skipNextRestore then
		skipNextRestore = false
		return
	end

	if menuAnimating then
		return
	end

	openMenu()
end)

--// =========================================================
--// OPEN MENU DRAGGING
--// =========================================================

local dragging = false
local dragStart = nil
local startPos = nil

header.InputBegan:Connect(function(input)

	if input.UserInputType ==
		Enum.UserInputType.MouseButton1
		or input.UserInputType ==
		Enum.UserInputType.Touch then

		dragging = true

		dragStart =
			input.Position

		startPos =
			menu.Position
	end
end)

UserInputService.InputChanged:Connect(function(input)

	if not dragging then
		return
	end

	if input.UserInputType ~=
		Enum.UserInputType.MouseMovement
		and input.UserInputType ~=
		Enum.UserInputType.Touch then

		return
	end

	local delta =
		input.Position
		- dragStart

	menu.Position =
		UDim2.new(
			startPos.X.Scale,
			startPos.X.Offset + delta.X,

			startPos.Y.Scale,
			startPos.Y.Offset + delta.Y
		)
end)

UserInputService.InputEnded:Connect(function(input)

	if input.UserInputType ==
		Enum.UserInputType.MouseButton1
		or input.UserInputType ==
		Enum.UserInputType.Touch then

		dragging = false
	end
end)

--// =========================================================
--// WELCOME POPUP
--// =========================================================

local welcome =
	Instance.new("Frame")

welcome.Name =
	"TBAM_Welcome"

-- MAIOR
welcome.Size =
	UDim2.fromOffset(360,115)

welcome.Position =
	UDim2.new(
		1,
		390,
		1,
		-25
	)

welcome.AnchorPoint =
	Vector2.new(1,1)

welcome.BackgroundColor3 =
	COLORS.background

welcome.BackgroundTransparency = 0.04
welcome.BorderSizePixel = 0
welcome.ZIndex = 100
welcome.Parent = gui

local welcomeCorner =
	Instance.new("UICorner")

welcomeCorner.CornerRadius =
	UDim.new(0,18)

welcomeCorner.Parent =
	welcome

local welcomeStroke =
	Instance.new("UIStroke")

welcomeStroke.Color =
	ACTIVE_COLOR

welcomeStroke.Thickness = 1.4
welcomeStroke.Transparency = 0.30
welcomeStroke.Parent = welcome

local welcomeTitle =
	Instance.new("TextLabel")

welcomeTitle.BackgroundTransparency = 1
welcomeTitle.Position =
	UDim2.fromOffset(18,12)

welcomeTitle.Size =
	UDim2.new(1,-36,0,30)

welcomeTitle.Font =
	Enum.Font.GothamBold

welcomeTitle.Text =
	"THE BROKEN ARROW MENU"

welcomeTitle.TextSize = 17
welcomeTitle.TextColor3 = COLORS.text
welcomeTitle.TextXAlignment =
	Enum.TextXAlignment.Left

welcomeTitle.ZIndex = 101
welcomeTitle.Parent = welcome

local welcomeText =
	Instance.new("TextLabel")

welcomeText.BackgroundTransparency = 1
welcomeText.Position =
	UDim2.fromOffset(18,45)

welcomeText.Size =
	UDim2.new(1,-36,0,55)

welcomeText.Font =
	Enum.Font.GothamMedium

welcomeText.Text =
	"Obrigado por usar o TBAM!\nCriado por: Niko  ×  ChatGPT\nv2.4 • Stable Edition"

welcomeText.TextSize = 12
welcomeText.TextColor3 = COLORS.subtext
welcomeText.TextWrapped = true
welcomeText.TextXAlignment =
	Enum.TextXAlignment.Left

welcomeText.ZIndex = 101
welcomeText.Parent = welcome

TweenService:Create(
	welcome,
	TweenInfo.new(
		0.70,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.Out
	),
	{
		Position =
			UDim2.new(
				1,
				-20,
				1,
				-25
			)
	}
):Play()

task.delay(6,function()

	if not welcome.Parent then
		return
	end

	local outTween =
		TweenService:Create(
			welcome,
			TweenInfo.new(
				0.48,
				Enum.EasingStyle.Quart,
				Enum.EasingDirection.In
			),
			{
				Position =
					UDim2.new(
						1,
						390,
						1,
						-25
					),

				BackgroundTransparency = 1
			}
		)

	outTween:Play()

	task.wait(0.5)

	if welcome
		and welcome.Parent then

		welcome:Destroy()
	end
end)

--// =========================================================
--// TAB BAR
--// =========================================================

local tabBar =
	Instance.new("Frame")

tabBar.Position =
	UDim2.fromOffset(13,69)

tabBar.Size =
	UDim2.new(1,-26,0,40)

tabBar.BackgroundColor3 =
	Color3.fromRGB(20,21,29)

tabBar.BackgroundTransparency = 0.15
tabBar.BorderSizePixel = 0
tabBar.ZIndex = 12
tabBar.Parent = menu

local tabCorner =
	Instance.new("UICorner")

tabCorner.CornerRadius =
	UDim.new(0,12)

tabCorner.Parent =
	tabBar

local function createTab(text,position)

	local button =
		Instance.new("TextButton")

	button.Size =
		UDim2.new(1/3,-6,1,0)

	button.Position =
		position

	button.BackgroundColor3 =
		COLORS.button

	button.BorderSizePixel = 0
	button.AutoButtonColor = false

	button.Font =
		Enum.Font.GothamBold

	button.Text = text
	button.TextSize = 10
	button.TextColor3 = COLORS.subtext
	button.ZIndex = 14
	button.Parent = tabBar

	local corner =
		Instance.new("UICorner")

	corner.CornerRadius =
		UDim.new(0,10)

	corner.Parent = button

	return button
end

local combatTab =
	createTab(
		"COMBAT",
		UDim2.fromOffset(4,4)
	)

local funTab =
	createTab(
		"FUN",
		UDim2.new(1/3,2,0,4)
	)

local customTab =
	createTab(
		"CUSTOM",
		UDim2.new(2/3,0,0,4)
	)

--// =========================================================
--// PAGE AREA
--// =========================================================

local pageArea =
	Instance.new("Frame")

pageArea.Position =
	UDim2.fromOffset(13,119)

pageArea.Size =
	UDim2.new(1,-26,1,-128)

pageArea.BackgroundTransparency = 1
pageArea.ClipsDescendants = true
pageArea.ZIndex = 8
pageArea.Parent = menu

local function createPage()

	local page =
		Instance.new("ScrollingFrame")

	page.Size =
		UDim2.fromScale(1,1)

	page.Position =
		UDim2.fromScale(0,0)

	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0

	page.ScrollBarThickness = 3
	page.ScrollBarImageColor3 =
		ACTIVE_COLOR

	page.ScrollBarImageTransparency = 0.65

	page.CanvasSize = UDim2.new()

	page.AutomaticCanvasSize =
		Enum.AutomaticSize.Y

	page.ScrollingDirection =
		Enum.ScrollingDirection.Y

	page.ZIndex = 9
	page.Parent = pageArea

	local padding =
		Instance.new("UIPadding")

	padding.PaddingTop =
		UDim.new(0,4)

	padding.PaddingBottom =
		UDim.new(0,12)

	padding.PaddingLeft =
		UDim.new(0,2)

	padding.PaddingRight =
		UDim.new(0,2)

	padding.Parent = page

	local layout =
		Instance.new("UIListLayout")

	layout.Padding =
		UDim.new(0,8)

	layout.HorizontalAlignment =
		Enum.HorizontalAlignment.Center

	layout.Parent = page

	return page
end

local combatPage = createPage()
local funPage = createPage()
local customPage = createPage()

funPage.Visible = false
customPage.Visible = false

--// =========================================================
--// BUTTON CREATOR
--// =========================================================

local allButtons = {}

local function createButton(page,text)

	local button =
		Instance.new("TextButton")

	button.Size =
		UDim2.new(1,-8,0,46)

	button.BackgroundColor3 =
		COLORS.button

	button.BackgroundTransparency = 0.12
	button.BorderSizePixel = 0
	button.AutoButtonColor = false

	button.Font =
		Enum.Font.GothamMedium

	button.Text = text
	button.TextSize = 13
	button.TextColor3 = COLORS.text
	button.ZIndex = 12
	button.Parent = page

	local corner =
		Instance.new("UICorner")

	corner.CornerRadius =
		UDim.new(0,12)

	corner.Parent = button

	local stroke =
		Instance.new("UIStroke")

	stroke.Color =
		COLORS.border

	stroke.Thickness = 1
	stroke.Transparency = 0.82
	stroke.Parent = button

	local scale =
		Instance.new("UIScale")

	scale.Name = "ButtonScale"
	scale.Scale = 1
	scale.Parent = button

	button.Activated:Connect(function()

		TweenService:Create(
			scale,
			TweenInfo.new(
				0.08,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.Out
			),
			{
				Scale = 0.965
			}
		):Play()

		task.delay(0.08,function()

			if not scale.Parent then
				return
			end

			TweenService:Create(
				scale,
				TweenInfo.new(
					0.30,
					Enum.EasingStyle.Back,
					Enum.EasingDirection.Out
				),
				{
					Scale = 1
				}
			):Play()
		end)
	end)

	button.MouseEnter:Connect(function()

		TweenService:Create(
			button,
			TweenInfo.new(
				0.15,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.Out
			),
			{
				BackgroundColor3 =
					COLORS.buttonHover
			}
		):Play()

		TweenService:Create(
			stroke,
			TweenInfo.new(0.15),
			{
				Transparency = 0.55
			}
		):Play()
	end)

	button.MouseLeave:Connect(function()

		local enabled =
			button:GetAttribute("Enabled")

		TweenService:Create(
			button,
			TweenInfo.new(
				0.18,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.Out
			),
			{
				BackgroundColor3 =
					enabled
					and ACTIVE_COLOR
					or COLORS.button
			}
		):Play()

		TweenService:Create(
			stroke,
			TweenInfo.new(0.18),
			{
				Transparency =
					enabled
					and 0.26
					or 0.82
			}
		):Play()
	end)

	table.insert(
		allButtons,
		button
	)

	return button
end

--// =========================================================
--// BUTTON STATE
--// =========================================================

local function animateButton(
	button,
	enabled
)

	button:SetAttribute(
		"Enabled",
		enabled
	)

	local targetColor =
		enabled
		and ACTIVE_COLOR
		or COLORS.button

	local stroke =
		button:FindFirstChildOfClass(
			"UIStroke"
		)

	TweenService:Create(
		button,
		TweenInfo.new(
			0.24,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.Out
		),
		{
			BackgroundColor3 =
				targetColor
		}
	):Play()

	if stroke then

		TweenService:Create(
			stroke,
			TweenInfo.new(0.25),
			{
				Transparency =
					enabled
					and 0.26
					or 0.82
			}
		):Play()
	end
end

--// =========================================================
--// COMBAT BUTTONS
--// =========================================================

local espButton =
	createButton(
		combatPage,
		"ESP  •  OFF"
	)

espButton.Activated:Connect(function()

	ESP_ENABLED =
		not ESP_ENABLED

	espButton.Text =
		"ESP  •  "
		.. (
			ESP_ENABLED
			and "ON"
			or "OFF"
		)

	animateButton(
		espButton,
		ESP_ENABLED
	)
end)

local aimButton =
	createButton(
		combatPage,
		"AIMBOT  •  OFF"
	)

aimButton.Activated:Connect(function()

	AIM_ENABLED =
		not AIM_ENABLED

	if not AIM_ENABLED then
		currentAimTarget = nil
	end

	aimButton.Text =
		"AIMBOT  •  "
		.. (
			AIM_ENABLED
			and "ON"
			or "OFF"
		)

	animateButton(
		aimButton,
		AIM_ENABLED
	)
end)

local speedButton =
	createButton(
		combatPage,
		"SPEED  •  OFF"
	)

speedButton.Activated:Connect(function()

	if not SPEED_ENABLED then

		SPEED_ENABLED = true
		SPEED_INDEX = 1

	else

		SPEED_INDEX += 1

		if SPEED_INDEX >
			#SPEED_VALUES then

			SPEED_ENABLED = false
			SPEED_INDEX = 1

		end
	end

	CURRENT_SPEED =
		SPEED_VALUES[SPEED_INDEX]

	applySpeed()

	speedButton.Text =
		"SPEED  •  "
		.. (
			SPEED_ENABLED
			and tostring(CURRENT_SPEED)
			or "OFF"
		)

	animateButton(
		speedButton,
		SPEED_ENABLED
	)
end)

local jumpButton =
	createButton(
		combatPage,
		"JUMP  •  OFF"
	)

jumpButton.Activated:Connect(function()

	if not JUMP_ENABLED then

		JUMP_ENABLED = true
		JUMP_INDEX = 1

	else

		JUMP_INDEX += 1

		if JUMP_INDEX >
			#JUMP_VALUES then

			JUMP_ENABLED = false
			JUMP_INDEX = 1

		end
	end

	CURRENT_JUMP =
		JUMP_VALUES[JUMP_INDEX]

	applyJump()

	jumpButton.Text =
		"JUMP  •  "
		.. (
			JUMP_ENABLED
			and tostring(CURRENT_JUMP)
			or "OFF"
		)

	animateButton(
		jumpButton,
		JUMP_ENABLED
	)
end)

local noclipButton =
	createButton(
		combatPage,
		"NOCLIP  •  OFF"
	)

noclipButton.Activated:Connect(function()

	NOCLIP_ENABLED =
		not NOCLIP_ENABLED

	noclipButton.Text =
		"NOCLIP  •  "
		.. (
			NOCLIP_ENABLED
			and "ON"
			or "OFF"
		)

	animateButton(
		noclipButton,
		NOCLIP_ENABLED
	)
end)

local fovButton =
	createButton(
		combatPage,
		"FOV  •  250"
	)

fovButton.Activated:Connect(function()

	if FOV == 250 then
		FOV = 175
	elseif FOV == 175 then
		FOV = 100
	else
		FOV = 250
	end

	fovButton.Text =
		"FOV  •  "
		.. tostring(FOV)
end)

--// =========================================================
--// FUN BUTTONS
--// =========================================================

local spinButton =
	createButton(
		funPage,
		"SPIN  •  OFF"
	)

spinButton.Activated:Connect(function()

	SPIN_ENABLED =
		not SPIN_ENABLED

	spinButton.Text =
		"SPIN  •  "
		.. (
			SPIN_ENABLED
			and "ON"
			or "OFF"
		)

	animateButton(
		spinButton,
		SPIN_ENABLED
	)
end)

local gravityButton =
	createButton(
		funPage,
		"ZERO GRAVITY  •  OFF"
	)

gravityButton.Activated:Connect(function()

	ZERO_GRAVITY_ENABLED =
		not ZERO_GRAVITY_ENABLED

	gravityButton.Text =
		"ZERO GRAVITY  •  "
		.. (
			ZERO_GRAVITY_ENABLED
			and "ON"
			or "OFF"
		)

	animateButton(
		gravityButton,
		ZERO_GRAVITY_ENABLED
	)
end)

local launchButton =
	createButton(
		funPage,
		"LAUNCH  UP"
	)

launchButton.Activated:Connect(function()

	local root =
		getRoot(
			getCharacter()
		)

	if root then

		root.AssemblyLinearVelocity =
			Vector3.new(
				0,
				120,
				0
			)
	end

	TweenService:Create(
		launchButton,
		TweenInfo.new(
			0.18,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.Out
		),
		{
			BackgroundColor3 =
				ACTIVE_COLOR
		}
	):Play()

	task.delay(0.25,function()

		if not launchButton.Parent then
			return
		end

		TweenService:Create(
			launchButton,
			TweenInfo.new(
				0.35,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.Out
			),
			{
				BackgroundColor3 =
					COLORS.button
			}
		):Play()
	end)
end)

local resetButton =
	createButton(
		funPage,
		"RESET FUN EFFECTS"
	)

resetButton.Activated:Connect(function()

	SPIN_ENABLED = false
	ZERO_GRAVITY_ENABLED = false

	spinButton.Text =
		"SPIN  •  OFF"

	gravityButton.Text =
		"ZERO GRAVITY  •  OFF"

	animateButton(
		spinButton,
		false
	)

	animateButton(
		gravityButton,
		false
	)
end)

--// =========================================================
--// CUSTOM PAGE
--// =========================================================

local colorTitle =
	createButton(
		customPage,
		"ACTIVE BUTTON COLOR"
	)

colorTitle.TextSize = 12
colorTitle.BackgroundColor3 =
	COLORS.panel

local colorButtons = {}

for _,preset in ipairs(
	COLOR_PRESETS
) do

	local button =
		createButton(
			customPage,
			preset.name
		)

	button.BackgroundColor3 =
		preset.color

	button.TextColor3 =
		Color3.fromRGB(
			255,255,255
		)

	table.insert(
		colorButtons,
		{
			button = button,
			color = preset.color
		}
	)

	button.Activated:Connect(function()

		ACTIVE_COLOR =
			preset.color

		refreshButtonColors()
	end)
end

local fovToggle =
	createButton(
		customPage,
		"FOV CIRCLE  •  ON"
	)

fovToggle.Activated:Connect(function()

	FOV_VISIBLE =
		not FOV_VISIBLE

	fovToggle.Text =
		"FOV CIRCLE  •  "
		.. (
			FOV_VISIBLE
			and "ON"
			or "OFF"
		)

	animateButton(
		fovToggle,
		FOV_VISIBLE
	)
end)

local glowToggle =
	createButton(
		customPage,
		"BACKGROUND GLOW  •  ON"
	)

glowToggle.Activated:Connect(function()

	GLOW_ENABLED =
		not GLOW_ENABLED

	glowToggle.Text =
		"BACKGROUND GLOW  •  "
		.. (
			GLOW_ENABLED
			and "ON"
			or "OFF"
		)

	animateButton(
		glowToggle,
		GLOW_ENABLED
	)
end)

local resetCustomization =
	createButton(
		customPage,
		"RESET CUSTOMIZATION"
	)

resetCustomization.Activated:Connect(function()

	ACTIVE_COLOR =
		DEFAULT_ACTIVE_COLOR

	FOV_VISIBLE = true
	GLOW_ENABLED = true

	fovToggle.Text =
		"FOV CIRCLE  •  ON"

	glowToggle.Text =
		"BACKGROUND GLOW  •  ON"

	animateButton(
		fovToggle,
		true
	)

	animateButton(
		glowToggle,
		true
	)

	refreshButtonColors()
end)

--// =========================================================
--// TAB SWITCHING
--// =========================================================

local switchingTab = false

local function styleTabs(tab)

	local function style(
		button,
		active,
		color
	)

		TweenService:Create(
			button,
			TweenInfo.new(
				0.22,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.Out
			),
			{
				BackgroundColor3 =
					active
					and color
					or COLORS.button,

				TextColor3 =
					active
					and COLORS.text
					or COLORS.subtext
			}
		):Play()
	end

	style(
		combatTab,
		tab == "Combat",
		COLORS.blue
	)

	style(
		funTab,
		tab == "Fun",
		COLORS.purple
	)

	style(
		customTab,
		tab == "Custom",
		ACTIVE_COLOR
	)
end

local function switchTab(tab)

	if switchingTab
		or tab == activeTab then

		return
	end

	switchingTab = true

	local pages = {
		Combat = combatPage,
		Fun = funPage,
		Custom = customPage
	}

	local order = {
		Combat = 1,
		Fun = 2,
		Custom = 3
	}

	local oldPage =
		pages[activeTab]

	local newPage =
		pages[tab]

	local direction =
		order[tab] > order[activeTab]
		and 1
		or -1

	newPage.Visible = true

	newPage.Position =
		UDim2.new(
			direction,
			direction * 15,
			0,
			0
		)

	TweenService:Create(
		oldPage,
		TweenInfo.new(
			0.24,
			Enum.EasingStyle.Quart,
			Enum.EasingDirection.InOut
		),
		{
			Position =
				UDim2.new(
					-direction,
					-direction * 15,
					0,
					0
				)
		}
	):Play()

	local incoming =
		TweenService:Create(
			newPage,
			TweenInfo.new(
				0.30,
				Enum.EasingStyle.Quart,
				Enum.EasingDirection.Out
			),
			{
				Position =
					UDim2.fromScale(0,0)
			}
		)

	incoming:Play()
	incoming.Completed:Wait()

	oldPage.Visible = false

	oldPage.Position =
		UDim2.fromScale(0,0)

	activeTab = tab

	styleTabs(tab)

	switchingTab = false
end

styleTabs("Combat")

combatTab.Activated:Connect(function()
	switchTab("Combat")
end)

funTab.Activated:Connect(function()
	switchTab("Fun")
end)

customTab.Activated:Connect(function()
	switchTab("Custom")
end)

--// =========================================================
--// FOV CIRCLE
--// =========================================================

local fovCircle =
	Instance.new("Frame")

fovCircle.Name =
	"TBAM_FOV"

fovCircle.AnchorPoint =
	Vector2.new(0.5,0.5)

fovCircle.BackgroundTransparency = 1
fovCircle.BorderSizePixel = 0
fovCircle.ZIndex = 30
fovCircle.Parent = gui

local fovCorner =
	Instance.new("UICorner")

fovCorner.CornerRadius =
	UDim.new(1,0)

fovCorner.Parent =
	fovCircle

local fovStroke =
	Instance.new("UIStroke")

fovStroke.Color =
	ACTIVE_COLOR

fovStroke.Transparency = 0.45
fovStroke.Thickness = 1.25
fovStroke.Parent = fovCircle

local fovScale =
	Instance.new("UIScale")

fovScale.Scale = 0
fovScale.Parent = fovCircle

local lastFOVState = false

RunService.RenderStepped:Connect(function()

	local camera =
		getCamera()

	if not camera then
		return
	end

	local viewport =
		camera.ViewportSize

	fovCircle.Position =
		UDim2.fromOffset(
			viewport.X / 2,
			viewport.Y / 2
		)

	fovCircle.Size =
		UDim2.fromOffset(
			FOV * 2,
			FOV * 2
		)

	fovStroke.Color =
		ACTIVE_COLOR

	local shouldShow =
		AIM_ENABLED
		and FOV_VISIBLE

	if shouldShow ~= lastFOVState then

		lastFOVState =
			shouldShow

		if shouldShow then

			fovCircle.Visible = true

			TweenService:Create(
				fovScale,
				TweenInfo.new(
					0.20,
					Enum.EasingStyle.Back,
					Enum.EasingDirection.Out
				),
				{
					Scale = 1
				}
			):Play()

		else

			TweenService:Create(
				fovScale,
				TweenInfo.new(
					0.16,
					Enum.EasingStyle.Quart,
					Enum.EasingDirection.In
				),
				{
					Scale = 0
				}
			):Play()

			task.delay(0.16,function()

				if not (
					AIM_ENABLED
					and FOV_VISIBLE
				) then

					fovCircle.Visible = false
				end
			end)
		end
	end
end)

--// =========================================================
--// REFRESH COLORS
--// =========================================================

function refreshButtonColors()

	for _,button in ipairs(allButtons) do

		local enabled =
			button:GetAttribute("Enabled")

		if enabled then

			button.BackgroundColor3 =
				ACTIVE_COLOR

		end
	end

	restoreStroke.Color =
		ACTIVE_COLOR

	fovStroke.Color =
		ACTIVE_COLOR

	for _,page in ipairs({
		combatPage,
		funPage,
		customPage
	}) do

		page.ScrollBarImageColor3 =
			ACTIVE_COLOR
	end

	if welcomeStroke
		and welcomeStroke.Parent then

		welcomeStroke.Color =
			ACTIVE_COLOR
	end
end

--// =========================================================
--// PLAYER EVENTS
--// =========================================================

Players.PlayerAdded:Connect(function(player)

	player.CharacterAdded:Connect(function(character)

		task.wait(0.5)

		saveOriginalMovement(character)

		createESP(
			character,
			true
		)
	end)
end)

Players.PlayerRemoving:Connect(function(player)

	if player.Character then
		removeESP(
			player.Character
		)

		originalMovement[
			player.Character
		] = nil
	end
end)

--// =========================================================
--// WORKSPACE EVENTS
--// =========================================================

Workspace.DescendantAdded:Connect(function(obj)

	if not obj:IsA("Model") then
		return
	end

	task.defer(function()

		if Players:GetPlayerFromCharacter(obj) then
			return
		end

		if isTarget(obj) then

			createESP(
				obj,
				false
			)
		end
	end)
end)

--// =========================================================
--// RESPAWN
--// =========================================================

LocalPlayer.CharacterAdded:Connect(function(character)

	-- Limpa eventual estado antigo
	task.wait(0.5)

	saveOriginalMovement(character)

	applySpeed()
	applyJump()

	if NOCLIP_ENABLED then

		task.wait(0.2)

		for _,part in ipairs(
			character:GetDescendants()
		) do

			if part:IsA("BasePart") then
				part.CanCollide = false
			end
		end
	end
end)

--// =========================================================
--// INITIALIZE
--// =========================================================

-- COMEÇA MINIMIZADO
minimized = true
menuAnimating = false

menu.Visible = false

restoreButton.Visible = true

restoreButton.Position =
	UDim2.fromScale(
		0.035,
		0.18
	)

restoreButton.Size =
	CLOSED_SIZE

-- Salva movimento original ANTES de aplicar qualquer coisa
local initialCharacter =
	getCharacter()

if initialCharacter then
	saveOriginalMovement(
		initialCharacter
	)
end

scanTargets()

applySpeed()
applyJump()

refreshButtonColors()

--// =========================================================
--// DONE
--// =========================================================