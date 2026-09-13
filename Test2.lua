--// =========================================================
--// THE BROKEN ARROW MENU
--// TBAM
--// STABLE EDITION v2.9.0
--// AERO ADMIN / TEST PANEL
--//
--// v2.9.0
--// • HOME / DASHBOARD
--// • MOVEMENT
--// • FUN
--// • VISUAL
--// • PLAYER
--// • TROLL
--// • CUSTOM
--// • SEARCH
--// • FPS / PING / MEMORY
--// • MULTI-THEME
--// • MOBILE FRIENDLY
--// • AUTO OPEN
--// • FLOATING MOBILE BUTTON
--// • RIGHT SHIFT
--// • UI SCALE
--// • COMPACT MODE
--// • TARGET LIST
--// • PLAYER / BOT TARGETS
--// • TELEPORT
--// • SPECTATE
--// • FOLLOW
--// • TARGET ESP
--// • FLING
--// • LAUNCH
--// • SPIN TARGET
--// • BRING TARGET
--// • PUSH TARGET
--// • PULL TARGET
--// • FREEZE TARGET
--// • UNFREEZE TARGET
--// • RAGDOLL TARGET
--// • UNRAGDOLL TARGET
--// • TARGET INFO
--// • TARGET DISTANCE
--// • TARGET VELOCITY
--// • TARGET HEALTH
--// • TARGET MASS
--// • SERVER FLING BRIDGE
--// • REAL 3D CAMERA FLY
--// • MOBILE FLY UP / DOWN
--// • FLY SPEED CONTROL
--//
--// Use como LocalScript no seu próprio jogo/test place.
--// =========================================================


--// =========================================================
--// SERVICES
--// =========================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Stats = game:GetService("Stats")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

if not LocalPlayer then
	warn("[TBAM] LocalPlayer não encontrado.")
	return
end


--// =========================================================
--// CONFIG
--// =========================================================

local CONFIG = {

	OpenSize = Vector2.new(520, 390),
	ClosedSize = Vector2.new(58, 58),

	DefaultScale = 0.92,
	MinScale = 0.72,
	MaxScale = 1.12,

	Hotkey = Enum.KeyCode.RightShift,

	StartOpen = true,

	SpeedValues = {
		16,
		24,
		32,
		50,
		75,
		100,
		150
	},

	JumpValues = {
		50,
		65,
		80,
		100,
		125,
		160
	},

	GravityValues = {
		196.2,
		120,
		60,
		20,
		0
	},

	FlySpeeds = {
		20,
		40,
		75,
		120,
		180,
		260,
		400
	},

	FollowDistance = 5,
	FollowHeight = 2,

	FlingPower = 350,
	FlingImpulse = 9500,
	FlingDuration = 0.55,
	FlingAngular = 120,

	LaunchPower = 180,
	PushPower = 220,
	PullPower = 140,

	SpinPower = 70,

	MobileFlyButtonSize = 56
}


--// =========================================================
--// STATE
--// =========================================================

local State = {

	MenuOpen = false,
	MenuAnimating = false,

	ActivePage = "HOME",

	SpeedEnabled = false,
	SpeedIndex = 1,

	JumpEnabled = false,
	JumpIndex = 1,

	FlyEnabled = false,
	FlyIndex = 1,

	NoclipEnabled = false,
	InfiniteJump = false,

	ZeroGravity = false,
	PlatformStand = false,

	Spin = false,
	SpinSpeed = 360,

	GravityIndex = 1,

	Rainbow = false,
	Trail = false,
	Particles = false,
	BigHead = false,

	Fullbright = false,
	NightMode = false,
	VividMode = false,

	UIScale = CONFIG.DefaultScale,
	CompactMode = false,
	Glow = true,

	Theme = "DEFAULT",

	FPS = 0,
	Ping = 0,
	Memory = 0,

	SelectedPlayer = nil,

	TrollFollow = false,
	TrollSpectate = false,
	TrollESP = false,
	TrollSpin = false,

	TrollFreeze = false,

	TrollTargetName = "",

	FlyUpHeld = false,
	FlyDownHeld = false
}


--// =========================================================
--// ORIGINAL VALUES
--// =========================================================

local Original = {

	Gravity = Workspace.Gravity,

	WalkSpeed = 16,
	JumpPower = 50,
	JumpHeight = 7.2,

	CameraFOV = 70,

	Lighting = {
		Brightness = Lighting.Brightness,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		ClockTime = Lighting.ClockTime,
		ExposureCompensation = Lighting.ExposureCompensation
	},

	HeadSize = nil
}


--// =========================================================
--// RUNTIME
--// =========================================================

local FlyVelocity = nil
local FlyAttachment = nil
local FlyOrientation = nil

local NoclipSaved = {}

local TrailObject = nil
local TrailAttachment0 = nil
local TrailAttachment1 = nil

local ParticleObject = nil

local ToastContainer = nil

local CurrentCharacter = nil

local TrollTarget = nil
local TrollHighlight = nil

local TargetList = nil
local TargetInfoLabel = nil
local TargetStatsLabel = nil
local TargetRemoteLabel = nil

local FlyMobileControls = nil
local FlyUpButton = nil
local FlyDownButton = nil


--// =========================================================
--// REGISTRIES
--// =========================================================

local Pages = {}
local Buttons = {}
local Sections = {}
local NavButtons = {}
local ThemeButtons = {}

local TargetButtons = {}

local ApplyTheme
local RefreshTargetList
local SetTrollTarget
local ClearTrollHighlight


local SpeedButton
local JumpButton
local FlyButton
local FlySpeedButton
local NoclipButton
local InfiniteJumpButton
local GravityButton
local PlatformButton

local SpinButton
local SpinSpeedButton
local ZeroGravityButton
local RainbowButton
local TrailButton
local ParticleButton
local BigHeadButton

local FOVButton
local FullbrightButton
local NightButton
local VividButton

local SpectateButton
local FollowButton
local TargetESPButton
local SpinTargetButton
local FreezeTargetButton


--// =========================================================
--// HELPERS
--// =========================================================

local function getCharacter()
	return LocalPlayer.Character
end


local function getHumanoid(character)
	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end


local function getRoot(character)
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end


local function getCamera()
	return Workspace.CurrentCamera
end


local function safeUnit(vector, fallback)
	if not vector or vector.Magnitude <= 0.0001 then
		return fallback or Vector3.zero
	end

	return vector.Unit
end


local function safeCall(callback, ...)
	if not callback then
		return true
	end

	local args = table.pack(...)

	local ok, err = pcall(function()
		callback(table.unpack(args, 1, args.n))
	end)

	if not ok then
		warn("[TBAM CALLBACK ERROR] " .. tostring(err))
	end

	return ok
end


local function tween(object, tweenInfo, properties)
	if not object or not object.Parent then
		return
	end

	local ok, err = pcall(function()
		TweenService:Create(
			object,
			tweenInfo,
			properties
		):Play()
	end)

	if not ok then
		warn("[TBAM TWEEN ERROR] " .. tostring(err))
	end
end


local function getTargetHumanoid(target)
	if not target then
		return nil
	end

	return target:FindFirstChildOfClass("Humanoid")
end


local function getTargetRoot(target)
	if not target then
		return nil
	end

	return target:FindFirstChild("HumanoidRootPart")
end


local function isValidTrollTarget(model)
	if not model then
		return false
	end

	if not model:IsA("Model") then
		return false
	end

	if model == getCharacter() then
		return false
	end

	local humanoid = getTargetHumanoid(model)
	local root = getTargetRoot(model)

	if not humanoid or not root then
		return false
	end

	if humanoid.Health <= 0 then
		return false
	end

	return true
end


local function getTargetPlayer()
	if not TrollTarget then
		return nil
	end

	return Players:GetPlayerFromCharacter(TrollTarget)
end


local function getTargetDistance()
	local myRoot = getRoot(getCharacter())
	local targetRoot = getTargetRoot(TrollTarget)

	if not myRoot or not targetRoot then
		return nil
	end

	return (targetRoot.Position - myRoot.Position).Magnitude
end


local function getTargetVelocity()
	local targetRoot = getTargetRoot(TrollTarget)

	if not targetRoot then
		return nil
	end

	return targetRoot.AssemblyLinearVelocity.Magnitude
end


local function getTargetMass()
	local targetRoot = getTargetRoot(TrollTarget)

	if not targetRoot then
		return nil
	end

	local ok, mass = pcall(function()
		return targetRoot:GetMass()
	end)

	if ok then
		return mass
	end

	return nil
end


--// =========================================================
--// OPTIONAL SERVER REMOTE
--// =========================================================

local function getTBAMRemote()
	local remote = ReplicatedStorage:FindFirstChild("TBAM_Remote")

	if remote and remote:IsA("RemoteEvent") then
		return remote
	end

	return nil
end


local function hasServerFlingBridge()
	return getTBAMRemote() ~= nil
end


local function serverAction(action, target, extra)
	local remote = getTBAMRemote()

	if not remote then
		return false
	end

	local ok = pcall(function()
		remote:FireServer(
			action,
			target,
			extra
		)
	end)

	return ok
end


--// =========================================================
--// THEMES
--// =========================================================

local THEMES = {

	DEFAULT = {
		Background = Color3.fromRGB(9, 10, 15),
		Panel = Color3.fromRGB(17, 18, 25),
		Button = Color3.fromRGB(27, 28, 37),
		ButtonHover = Color3.fromRGB(37, 38, 50),
		Accent = Color3.fromRGB(145, 85, 205),
		Text = Color3.fromRGB(242, 242, 248),
		Subtext = Color3.fromRGB(150, 153, 172),
		Border = Color3.fromRGB(92, 96, 125),
		Glow1 = Color3.fromRGB(85, 65, 255),
		Glow2 = Color3.fromRGB(35, 130, 255),
		Glow3 = Color3.fromRGB(190, 55, 180)
	},

	FRUTIGER_AERO = {
		Background = Color3.fromRGB(175, 220, 245),
		Panel = Color3.fromRGB(220, 242, 255),
		Button = Color3.fromRGB(190, 225, 245),
		ButtonHover = Color3.fromRGB(215, 240, 255),
		Accent = Color3.fromRGB(30, 135, 220),
		Text = Color3.fromRGB(18, 65, 102),
		Subtext = Color3.fromRGB(58, 112, 148),
		Border = Color3.fromRGB(70, 155, 205),
		Glow1 = Color3.fromRGB(80, 190, 255),
		Glow2 = Color3.fromRGB(130, 225, 255),
		Glow3 = Color3.fromRGB(90, 210, 180)
	},

	GLASS = {
		Background = Color3.fromRGB(12, 17, 25),
		Panel = Color3.fromRGB(27, 37, 50),
		Button = Color3.fromRGB(37, 49, 65),
		ButtonHover = Color3.fromRGB(52, 68, 87),
		Accent = Color3.fromRGB(90, 180, 255),
		Text = Color3.fromRGB(235, 245, 255),
		Subtext = Color3.fromRGB(160, 184, 205),
		Border = Color3.fromRGB(110, 150, 185),
		Glow1 = Color3.fromRGB(70, 165, 255),
		Glow2 = Color3.fromRGB(100, 220, 255),
		Glow3 = Color3.fromRGB(130, 170, 255)
	},

	CYBER = {
		Background = Color3.fromRGB(7, 6, 12),
		Panel = Color3.fromRGB(18, 11, 28),
		Button = Color3.fromRGB(35, 14, 48),
		ButtonHover = Color3.fromRGB(55, 18, 75),
		Accent = Color3.fromRGB(220, 55, 255),
		Text = Color3.fromRGB(250, 240, 255),
		Subtext = Color3.fromRGB(176, 128, 195),
		Border = Color3.fromRGB(148, 50, 205),
		Glow1 = Color3.fromRGB(220, 40, 255),
		Glow2 = Color3.fromRGB(90, 30, 255),
		Glow3 = Color3.fromRGB(255, 40, 160)
	},

	WINDOWS_XP = {
		Background = Color3.fromRGB(30, 75, 145),
		Panel = Color3.fromRGB(60, 125, 205),
		Button = Color3.fromRGB(70, 145, 220),
		ButtonHover = Color3.fromRGB(90, 165, 235),
		Accent = Color3.fromRGB(40, 165, 70),
		Text = Color3.fromRGB(255, 255, 255),
		Subtext = Color3.fromRGB(220, 240, 255),
		Border = Color3.fromRGB(160, 210, 255),
		Glow1 = Color3.fromRGB(80, 190, 255),
		Glow2 = Color3.fromRGB(80, 240, 100),
		Glow3 = Color3.fromRGB(255, 220, 80)
	},

	OLED = {
		Background = Color3.fromRGB(0, 0, 0),
		Panel = Color3.fromRGB(7, 7, 7),
		Button = Color3.fromRGB(15, 15, 15),
		ButtonHover = Color3.fromRGB(27, 27, 27),
		Accent = Color3.fromRGB(255, 255, 255),
		Text = Color3.fromRGB(255, 255, 255),
		Subtext = Color3.fromRGB(160, 160, 160),
		Border = Color3.fromRGB(85, 85, 85),
		Glow1 = Color3.fromRGB(255, 255, 255),
		Glow2 = Color3.fromRGB(120, 120, 120),
		Glow3 = Color3.fromRGB(70, 70, 70)
	},

	Y2K = {
		Background = Color3.fromRGB(235, 225, 255),
		Panel = Color3.fromRGB(245, 240, 255),
		Button = Color3.fromRGB(210, 195, 245),
		ButtonHover = Color3.fromRGB(230, 220, 255),
		Accent = Color3.fromRGB(130, 75, 205),
		Text = Color3.fromRGB(50, 30, 85),
		Subtext = Color3.fromRGB(100, 75, 130),
		Border = Color3.fromRGB(165, 130, 215),
		Glow1 = Color3.fromRGB(220, 120, 255),
		Glow2 = Color3.fromRGB(120, 180, 255),
		Glow3 = Color3.fromRGB(255, 170, 220)
	}
}

local Theme = THEMES.DEFAULT


--// =========================================================
--// PLAYER GUI
--// =========================================================

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local oldGui = PlayerGui:FindFirstChild("TBAM_GUI")

if oldGui then
	pcall(function()
		oldGui:Destroy()
	end)
end


--// =========================================================
--// SCREEN GUI
--// =========================================================

local gui = Instance.new("ScreenGui")

gui.Name = "TBAM_GUI"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 1000
gui.Enabled = true

gui.Parent = PlayerGui


--// =========================================================
--// UI SCALE
--// =========================================================

local UIScaleObject = Instance.new("UIScale")

UIScaleObject.Scale = State.UIScale

UIScaleObject.Parent = gui


--// =========================================================
--// TOAST
--// =========================================================

ToastContainer = Instance.new("Frame")

ToastContainer.Name = "TBAM_Toasts"
ToastContainer.AnchorPoint = Vector2.new(1, 0)
ToastContainer.Position = UDim2.new(1, -18, 0, 18)
ToastContainer.Size = UDim2.fromOffset(250, 300)
ToastContainer.BackgroundTransparency = 1
ToastContainer.ZIndex = 2000
ToastContainer.Parent = gui


local ToastLayout = Instance.new("UIListLayout")

ToastLayout.Padding = UDim.new(0, 8)
ToastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
ToastLayout.VerticalAlignment = Enum.VerticalAlignment.Top
ToastLayout.Parent = ToastContainer


local function CreateToast(title, message, duration)

	if not ToastContainer or not ToastContainer.Parent then
		return
	end

	local toast = Instance.new("Frame")

	toast.Size = UDim2.new(1, 0, 0, 62)
	toast.BackgroundColor3 = Color3.fromRGB(20, 21, 29)
	toast.BackgroundTransparency = 0.08
	toast.BorderSizePixel = 0
	toast.ZIndex = 2001
	toast.Parent = ToastContainer


	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = toast


	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(120, 125, 160)
	stroke.Transparency = 0.55
	stroke.Parent = toast


	local titleLabel = Instance.new("TextLabel")

	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromOffset(14, 7)
	titleLabel.Size = UDim2.new(1, -28, 0, 18)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Text = title or "TBAM"
	titleLabel.TextSize = 13
	titleLabel.TextColor3 = Color3.fromRGB(245, 245, 255)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.ZIndex = 2002
	titleLabel.Parent = toast


	local messageLabel = Instance.new("TextLabel")

	messageLabel.BackgroundTransparency = 1
	messageLabel.Position = UDim2.fromOffset(14, 27)
	messageLabel.Size = UDim2.new(1, -28, 0, 25)
	messageLabel.Font = Enum.Font.GothamMedium
	messageLabel.Text = message or ""
	messageLabel.TextSize = 10
	messageLabel.TextColor3 = Color3.fromRGB(175, 178, 195)
	messageLabel.TextXAlignment = Enum.TextXAlignment.Left
	messageLabel.TextTruncate = Enum.TextTruncate.AtEnd
	messageLabel.ZIndex = 2002
	messageLabel.Parent = toast


	toast.Position = UDim2.new(0, 0, 0, -70)

	tween(
		toast,
		TweenInfo.new(
			0.3,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out
		),
		{
			Position = UDim2.fromOffset(0, 0)
		}
	)


	task.delay(duration or 2.2, function()

		if not toast or not toast.Parent then
			return
		end

		local exitTween = TweenService:Create(
			toast,
			TweenInfo.new(
				0.25,
				Enum.EasingStyle.Quart,
				Enum.EasingDirection.In
			),
			{
				Position = UDim2.new(0, 0, 0, -70),
				BackgroundTransparency = 1
			}
		)

		exitTween:Play()

		exitTween.Completed:Wait()

		if toast.Parent then
			toast:Destroy()
		end
	end)
end


--// =========================================================
--// MAIN WINDOW
--// =========================================================

local Window = Instance.new("Frame")

Window.Name = "TBAM_Window"
Window.Size = UDim2.fromOffset(
	CONFIG.OpenSize.X,
	CONFIG.OpenSize.Y
)

Window.Position = UDim2.fromScale(0.5, 0.5)
Window.AnchorPoint = Vector2.new(0.5, 0.5)
Window.BackgroundColor3 = Theme.Background
Window.BorderSizePixel = 0
Window.Visible = false
Window.ClipsDescendants = true
Window.Active = true
Window.ZIndex = 100
Window.Parent = gui


local WindowCorner = Instance.new("UICorner")
WindowCorner.CornerRadius = UDim.new(0, 20)
WindowCorner.Parent = Window


local WindowStroke = Instance.new("UIStroke")
WindowStroke.Color = Theme.Border
WindowStroke.Transparency = 0.35
WindowStroke.Thickness = 1.2
WindowStroke.Parent = Window


--// =========================================================
--// GLOW
--// =========================================================

local GlowLayer = Instance.new("Frame")

GlowLayer.Size = UDim2.fromScale(1, 1)
GlowLayer.BackgroundTransparency = 1
GlowLayer.ClipsDescendants = true
GlowLayer.ZIndex = 101
GlowLayer.Parent = Window


local function MakeGlow(size, position, color)

	local object = Instance.new("Frame")

	object.Size = UDim2.fromOffset(size, size)
	object.Position = position
	object.AnchorPoint = Vector2.new(0.5, 0.5)
	object.BackgroundColor3 = color
	object.BackgroundTransparency = 0.9
	object.BorderSizePixel = 0
	object.ZIndex = 102
	object.Parent = GlowLayer


	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = object

	return object
end


local GlowA = MakeGlow(
	220,
	UDim2.fromScale(-0.05, 0.1),
	Theme.Glow1
)

local GlowB = MakeGlow(
	250,
	UDim2.fromScale(1.05, 0.45),
	Theme.Glow2
)

local GlowC = MakeGlow(
	230,
	UDim2.fromScale(0.5, 1.05),
	Theme.Glow3
)


task.spawn(function()

	while gui.Parent do

		if not Window.Visible or not State.Glow then

			GlowA.Visible = false
			GlowB.Visible = false
			GlowC.Visible = false

			task.wait(0.35)

		else

			GlowA.Visible = true
			GlowB.Visible = true
			GlowC.Visible = true

			tween(
				GlowA,
				TweenInfo.new(
					7,
					Enum.EasingStyle.Sine,
					Enum.EasingDirection.InOut
				),
				{
					Position = UDim2.fromScale(0.75, 0.2)
				}
			)

			tween(
				GlowB,
				TweenInfo.new(
					8,
					Enum.EasingStyle.Sine,
					Enum.EasingDirection.InOut
				),
				{
					Position = UDim2.fromScale(0.2, 0.8)
				}
			)

			tween(
				GlowC,
				TweenInfo.new(
					7.5,
					Enum.EasingStyle.Sine,
					Enum.EasingDirection.InOut
				),
				{
					Position = UDim2.fromScale(0.8, 0.12)
				}
			)

			task.wait(7)

			if GlowA.Parent then
				GlowA.Position =
					UDim2.fromScale(-0.05, 0.1)
			end

			if GlowB.Parent then
				GlowB.Position =
					UDim2.fromScale(1.05, 0.45)
			end

			if GlowC.Parent then
				GlowC.Position =
					UDim2.fromScale(0.5, 1.05)
			end
		end
	end
end)


--// =========================================================
--// HEADER
--// =========================================================

local Header = Instance.new("Frame")

Header.Position = UDim2.fromOffset(12, 10)
Header.Size = UDim2.new(1, -24, 0, 52)
Header.BackgroundTransparency = 1
Header.ZIndex = 200
Header.Parent = Window


local Title = Instance.new("TextLabel")

Title.BackgroundTransparency = 1
Title.Position = UDim2.fromOffset(8, 0)
Title.Size = UDim2.new(1, -150, 0, 28)
Title.Font = Enum.Font.GothamBold
Title.Text = "TBAM"
Title.TextSize = 22
Title.TextColor3 = Theme.Text
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 201
Title.Parent = Header


local Subtitle = Instance.new("TextLabel")

Subtitle.BackgroundTransparency = 1
Subtitle.Position = UDim2.fromOffset(9, 26)
Subtitle.Size = UDim2.new(1, -150, 0, 17)
Subtitle.Font = Enum.Font.GothamMedium
Subtitle.Text = "THE BROKEN ARROW  •  v2.9.0"
Subtitle.TextSize = 9
Subtitle.TextColor3 = Theme.Subtext
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.ZIndex = 201
Subtitle.Parent = Header


local Status = Instance.new("TextLabel")

Status.BackgroundTransparency = 1
Status.Position = UDim2.new(1, -126, 0, 8)
Status.Size = UDim2.fromOffset(92, 25)
Status.Font = Enum.Font.GothamBold
Status.TextSize = 10
Status.TextColor3 = Theme.Subtext
Status.Text = "● READY"
Status.TextXAlignment = Enum.TextXAlignment.Right
Status.ZIndex = 201
Status.Parent = Header


--// =========================================================
--// CLOSE
--// =========================================================

local CloseButton = Instance.new("TextButton")

CloseButton.Size = UDim2.fromOffset(34, 34)
CloseButton.Position = UDim2.new(1, -34, 0, 1)
CloseButton.BackgroundColor3 = Theme.Button
CloseButton.BackgroundTransparency = 0.15
CloseButton.BorderSizePixel = 0
CloseButton.Text = "×"
CloseButton.TextSize = 22
CloseButton.Font = Enum.Font.GothamMedium
CloseButton.TextColor3 = Theme.Text
CloseButton.AutoButtonColor = false
CloseButton.ZIndex = 250
CloseButton.Parent = Header


local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(1, 0)
CloseCorner.Parent = CloseButton


--// =========================================================
--// FLOATING BUTTON
--// =========================================================

local FloatingButton = Instance.new("TextButton")

FloatingButton.Name = "TBAM_FloatingButton"
FloatingButton.Size = UDim2.fromOffset(58, 58)
FloatingButton.Position = UDim2.new(0, 18, 0.5, 0)
FloatingButton.AnchorPoint = Vector2.new(0, 0.5)
FloatingButton.BackgroundColor3 = Theme.Panel
FloatingButton.BorderSizePixel = 0
FloatingButton.Text = "TB"
FloatingButton.TextSize = 20
FloatingButton.Font = Enum.Font.GothamBlack
FloatingButton.TextColor3 = Theme.Text
FloatingButton.AutoButtonColor = false
FloatingButton.Visible = true
FloatingButton.ZIndex = 900
FloatingButton.Parent = gui


local FloatingCorner = Instance.new("UICorner")
FloatingCorner.CornerRadius = UDim.new(1, 0)
FloatingCorner.Parent = FloatingButton


local FloatingStroke = Instance.new("UIStroke")
FloatingStroke.Color = Theme.Accent
FloatingStroke.Thickness = 1.5
FloatingStroke.Parent = FloatingButton


--// =========================================================
--// SEARCH
--// =========================================================

local SearchBox = Instance.new("TextBox")

SearchBox.Position = UDim2.fromOffset(190, 67)
SearchBox.Size = UDim2.new(1, -205, 0, 34)
SearchBox.BackgroundColor3 = Theme.Button
SearchBox.BackgroundTransparency = 0.12
SearchBox.BorderSizePixel = 0
SearchBox.ClearTextOnFocus = false
SearchBox.Font = Enum.Font.GothamMedium
SearchBox.PlaceholderText = "Search..."
SearchBox.PlaceholderColor3 = Theme.Subtext
SearchBox.Text = ""
SearchBox.TextColor3 = Theme.Text
SearchBox.TextSize = 11
SearchBox.TextXAlignment = Enum.TextXAlignment.Left
SearchBox.ZIndex = 250
SearchBox.Parent = Window


local SearchCorner = Instance.new("UICorner")
SearchCorner.CornerRadius = UDim.new(0, 10)
SearchCorner.Parent = SearchBox


local SearchPadding = Instance.new("UIPadding")
SearchPadding.PaddingLeft = UDim.new(0, 11)
SearchPadding.PaddingRight = UDim.new(0, 11)
SearchPadding.Parent = SearchBox


--// =========================================================
--// SIDEBAR
--// =========================================================

local Sidebar = Instance.new("ScrollingFrame")

Sidebar.Name = "TBAM_Sidebar"
Sidebar.Position = UDim2.fromOffset(12, 67)
Sidebar.Size = UDim2.fromOffset(165, 310)
Sidebar.BackgroundColor3 = Theme.Panel
Sidebar.BackgroundTransparency = 0.15
Sidebar.BorderSizePixel = 0
Sidebar.ZIndex = 220
Sidebar.ScrollBarThickness = 2
Sidebar.ScrollBarImageColor3 = Theme.Accent
Sidebar.ScrollBarImageTransparency = 0.4
Sidebar.CanvasSize = UDim2.new()
Sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
Sidebar.Parent = Window


local SidebarCorner = Instance.new("UICorner")
SidebarCorner.CornerRadius = UDim.new(0, 15)
SidebarCorner.Parent = Sidebar


local SideLayout = Instance.new("UIListLayout")
SideLayout.Padding = UDim.new(0, 5)
SideLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
SideLayout.VerticalAlignment = Enum.VerticalAlignment.Top
SideLayout.Parent = Sidebar


local SidePadding = Instance.new("UIPadding")
SidePadding.PaddingTop = UDim.new(0, 8)
SidePadding.PaddingLeft = UDim.new(0, 7)
SidePadding.PaddingRight = UDim.new(0, 7)
SidePadding.PaddingBottom = UDim.new(0, 7)
SidePadding.Parent = Sidebar


--// =========================================================
--// CONTENT
--// =========================================================

local Content = Instance.new("Frame")

Content.Position = UDim2.fromOffset(190, 108)
Content.Size = UDim2.new(1, -203, 1, -120)
Content.BackgroundTransparency = 1
Content.ClipsDescendants = true
Content.ZIndex = 210
Content.Parent = Window


--// =========================================================
--// PAGE CREATOR
--// =========================================================

local function CreatePage(name)

	local page = Instance.new("ScrollingFrame")

	page.Name = name
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 3
	page.ScrollBarImageColor3 = Theme.Accent
	page.ScrollBarImageTransparency = 0.55
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.CanvasSize = UDim2.new()
	page.Visible = false
	page.ZIndex = 215
	page.Parent = Content


	local padding = Instance.new("UIPadding")

	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 15)
	padding.PaddingLeft = UDim.new(0, 3)
	padding.PaddingRight = UDim.new(0, 3)
	padding.Parent = page


	local layout = Instance.new("UIListLayout")

	layout.Padding = UDim.new(0, 7)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = page

	Pages[name] = page

	return page
end


local HomePage = CreatePage("HOME")
local MovementPage = CreatePage("MOVEMENT")
local FunPage = CreatePage("FUN")
local VisualPage = CreatePage("VISUAL")
local PlayerPage = CreatePage("PLAYER")
local TrollPage = CreatePage("TROLL")
local CustomPage = CreatePage("CUSTOM")


--// =========================================================
--// SECTION
--// =========================================================

local function CreateSection(page, text)

	local label = Instance.new("TextLabel")

	label.Size = UDim2.new(1, -6, 0, 25)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = string.upper(text)
	label.TextSize = 10
	label.TextColor3 = Theme.Subtext
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = 225
	label.Parent = page

	table.insert(Sections, label)

	return label
end


--// =========================================================
--// BUTTON
--// =========================================================

local function CreateButton(page, text, callback)

	local button = Instance.new("TextButton")

	button.Size = UDim2.new(1, -6, 0, 43)
	button.BackgroundColor3 = Theme.Button
	button.BackgroundTransparency = 0.08
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamMedium
	button.Text = text
	button.TextSize = 12
	button.TextColor3 = Theme.Text
	button.ZIndex = 230
	button.Parent = page


	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 11)
	corner.Parent = button


	local stroke = Instance.new("UIStroke")

	stroke.Color = Theme.Border
	stroke.Transparency = 0.78
	stroke.Thickness = 1
	stroke.Parent = button


	button:SetAttribute(
		"SearchText",
		string.lower(text)
	)

	button:SetAttribute(
		"Enabled",
		false
	)


	button.MouseEnter:Connect(function()

		local enabled =
			button:GetAttribute("Enabled")

		if enabled then
			return
		end

		tween(
			button,
			TweenInfo.new(0.12),
			{
				BackgroundColor3 =
					Theme.ButtonHover
			}
		)
	end)


	button.MouseLeave:Connect(function()

		local enabled =
			button:GetAttribute("Enabled")

		tween(
			button,
			TweenInfo.new(0.15),
			{
				BackgroundColor3 =
					enabled
					and Theme.Accent
					or Theme.Button
			}
		)
	end)


	button.Activated:Connect(function()

		tween(
			button,
			TweenInfo.new(0.07),
			{
				Size = UDim2.new(
					1,
					-10,
					0,
					State.CompactMode
					and 28
					or 41
				)
			}
		)


		task.delay(0.08, function()

			if not button.Parent then
				return
			end

			tween(
				button,
				TweenInfo.new(
					0.18,
					Enum.EasingStyle.Back,
					Enum.EasingDirection.Out
				),
				{
					Size = UDim2.new(
						1,
						-6,
						0,
						State.CompactMode
						and 30
						or 43
					)
				}
			)
		end)


		safeCall(callback, button)

		CreateToast(
			"TBAM",
			button.Text,
			1.4
		)
	end)


	table.insert(
		Buttons,
		{
			Object = button,
			Stroke = stroke
		}
	)

	return button
end


--// =========================================================
--// BUTTON STATE
--// =========================================================

local function SetButtonState(button, enabled)

	if not button or not button.Parent then
		return
	end

	button:SetAttribute("Enabled", enabled)

	tween(
		button,
		TweenInfo.new(0.18),
		{
			BackgroundColor3 =
				enabled
				and Theme.Accent
				or Theme.Button
		}
	)


	for _, entry in ipairs(Buttons) do

		if entry.Object == button then

			tween(
				entry.Stroke,
				TweenInfo.new(0.18),
				{
					Transparency =
						enabled
						and 0.25
						or 0.78
				}
			)

			break
		end
	end
end


--// =========================================================
--// NAV BUTTON
--// =========================================================

local function CreateNavButton(name, icon)

	local button = Instance.new("TextButton")

	button.Size = UDim2.new(1, -2, 0, 37)
	button.BackgroundColor3 = Theme.Button
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBold

	button.Text =
		icon
		.. "  "
		.. name

	button.TextSize = 11
	button.TextColor3 = Theme.Subtext
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.ZIndex = 240
	button.Parent = Sidebar


	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button


	NavButtons[name] = button

	return button
end


CreateNavButton("HOME", "⌂")
CreateNavButton("MOVEMENT", "◆")
CreateNavButton("FUN", "✦")
CreateNavButton("VISUAL", "◉")
CreateNavButton("PLAYER", "◎")
CreateNavButton("TROLL", "☠")
CreateNavButton("CUSTOM", "⚙")


--// =========================================================
--// TROLL HELPERS
--// =========================================================

local function ClearTrollHighlightInternal()

	if TrollHighlight then

		pcall(function()
			TrollHighlight:Destroy()
		end)

		TrollHighlight = nil
	end
end

ClearTrollHighlight = ClearTrollHighlightInternal


local function SetTrollTargetInternal(target)

	if not target or not isValidTrollTarget(target) then

		TrollTarget = nil
		State.SelectedPlayer = nil
		State.TrollTargetName = ""

		if TargetInfoLabel then
			TargetInfoLabel.Text = "TARGET  •  NONE"
		end

		if TargetStatsLabel then
			TargetStatsLabel.Text = "DISTANCE • -- | SPEED • -- | HP • --"
		end

		ClearTrollHighlight()

		return
	end


	TrollTarget = target


	State.SelectedPlayer =
		Players:GetPlayerFromCharacter(target)


	State.TrollTargetName = target.Name


	local player =
		Players:GetPlayerFromCharacter(target)


	if TargetInfoLabel then

		if player then

			TargetInfoLabel.Text =
				"TARGET  •  PLAYER  •  "
				.. player.Name

		else

			TargetInfoLabel.Text =
				"TARGET  •  BOT  •  "
				.. target.Name
		end
	end


	ClearTrollHighlight()


	if State.TrollESP then

		TrollHighlight = Instance.new("Highlight")

		TrollHighlight.Name =
			"TBAM_TrollHighlight"

		TrollHighlight.Adornee =
			target

		TrollHighlight.DepthMode =
			Enum.HighlightDepthMode.AlwaysOnTop

		TrollHighlight.FillTransparency = 0.55
		TrollHighlight.OutlineTransparency = 0

		TrollHighlight.FillColor =
			Theme.Accent

		TrollHighlight.OutlineColor =
			Theme.Text

		TrollHighlight.Parent = target
	end
end

SetTrollTarget = SetTrollTargetInternal


local function GetAllTrollTargets()

	local results = {}
	local seen = {}


	for _, player in ipairs(Players:GetPlayers()) do

		local character = player.Character

		if
			player ~= LocalPlayer
			and character
			and isValidTrollTarget(character)
		then

			if not seen[character] then

				seen[character] = true

				table.insert(
					results,
					{
						Model = character,
						Name = player.Name,
						Type = "PLAYER",
						Display =
							"PLAYER  •  "
							.. player.Name
					}
				)
			end
		end
	end


	for _, object in ipairs(
		Workspace:GetDescendants()
	) do

		if
			object:IsA("Model")
			and object ~= getCharacter()
			and not Players:GetPlayerFromCharacter(object)
			and not seen[object]
			and isValidTrollTarget(object)
		then

			seen[object] = true

			table.insert(
				results,
				{
					Model = object,
					Name = object.Name,
					Type = "BOT",
					Display =
						"BOT  •  "
						.. object.Name
				}
			)
		end
	end


	table.sort(
		results,
		function(a, b)

			if a.Type == b.Type then

				return string.lower(a.Name)
					<
					string.lower(b.Name)

			end

			return a.Type == "PLAYER"
		end
	)


	return results
end


local function RefreshTargetListInternal()

	if not TargetList or not TargetList.Parent then
		return
	end


	for _, child in ipairs(TargetList:GetChildren()) do

		if
			child:IsA("TextButton")
			or child:IsA("TextLabel")
		then
			child:Destroy()
		end
	end


	TargetButtons = {}


	local targets = GetAllTrollTargets()


	if #targets == 0 then

		local empty = Instance.new("TextLabel")

		empty.Size = UDim2.new(1, -4, 0, 40)
		empty.BackgroundTransparency = 1
		empty.Text = "NO PLAYERS / BOTS FOUND"
		empty.Font = Enum.Font.GothamMedium
		empty.TextSize = 10
		empty.TextColor3 = Theme.Subtext
		empty.ZIndex = 420
		empty.Parent = TargetList

		return
	end


	for _, targetData in ipairs(targets) do

		local targetButton =
			Instance.new("TextButton")

		targetButton.Size =
			UDim2.new(1, -4, 0, 37)

		targetButton.BackgroundColor3 =
			targetData.Type == "PLAYER"
			and Theme.Button
			or Theme.Panel

		targetButton.BackgroundTransparency = 0.08
		targetButton.BorderSizePixel = 0
		targetButton.AutoButtonColor = false
		targetButton.Font = Enum.Font.GothamMedium
		targetButton.Text = targetData.Display
		targetButton.TextSize = 10
		targetButton.TextColor3 = Theme.Text
		targetButton.TextXAlignment = Enum.TextXAlignment.Left
		targetButton.ZIndex = 430
		targetButton.Parent = TargetList


		local padding = Instance.new("UIPadding")

		padding.PaddingLeft = UDim.new(0, 10)
		padding.Parent = targetButton


		local corner = Instance.new("UICorner")

		corner.CornerRadius = UDim.new(0, 9)
		corner.Parent = targetButton


		local targetModel = targetData.Model
		local targetType = targetData.Type


		TargetButtons[targetModel] =
			targetButton


		targetButton.Activated:Connect(function()

			SetTrollTarget(targetModel)

			CreateToast(
				"TROLL TARGET",
				targetData.Display
					.. " selecionado.",
				1.5
			)


			for model, btn in pairs(TargetButtons) do

				if btn.Parent then

					local isSelected =
						model == TrollTarget

					local data =
						nil

					for _, searchData in ipairs(targets) do
						if searchData.Model == model then
							data = searchData
							break
						end
					end

					local fallbackType =
						data
						and data.Type
						or "BOT"

					btn.BackgroundColor3 =
						isSelected
						and Theme.Accent
						or (
							fallbackType == "PLAYER"
							and Theme.Button
							or Theme.Panel
						)
				end
			end
		end)


		targetButton.MouseEnter:Connect(function()

			if TrollTarget == targetModel then
				return
			end

			tween(
				targetButton,
				TweenInfo.new(0.12),
				{
					BackgroundColor3 =
						Theme.ButtonHover
				}
			)
		end)


		targetButton.MouseLeave:Connect(function()

			local selected =
				TrollTarget == targetModel

			tween(
				targetButton,
				TweenInfo.new(0.12),
				{
					BackgroundColor3 =
						selected
						and Theme.Accent
						or (
							targetType == "PLAYER"
							and Theme.Button
							or Theme.Panel
						)
				}
			)
		end)
	end
end

RefreshTargetList = RefreshTargetListInternal


--// =========================================================
--// NAVIGATION
--// =========================================================

local function SwitchPage(name)

	local page = Pages[name]

	if not page then
		return
	end

	State.ActivePage = name


	for pageName, otherPage in pairs(Pages) do

		local active =
			pageName == name

		otherPage.Visible = active

		if active then

			otherPage.Position =
				UDim2.fromOffset(14, 0)

			tween(
				otherPage,
				TweenInfo.new(
					0.2,
					Enum.EasingStyle.Quart,
					Enum.EasingDirection.Out
				),
				{
					Position =
						UDim2.fromOffset(0, 0)
				}
			)
		end
	end


	for navName, navButton in pairs(NavButtons) do

		local active =
			navName == name

		navButton.BackgroundTransparency =
			active and 0 or 1

		navButton.BackgroundColor3 =
			active
			and Theme.Accent
			or Theme.Button

		navButton.TextColor3 =
			active
			and Theme.Text
			or Theme.Subtext
	end


	SearchBox.Text = ""


	if name == "TROLL" then

		task.defer(function()
			pcall(RefreshTargetList)
		end)
	end
end


for name, button in pairs(NavButtons) do

	button.Activated:Connect(function()
		SwitchPage(name)
	end)
end


--// =========================================================
--// HOME
--// =========================================================

CreateSection(
	HomePage,
	"DASHBOARD"
)


CreateButton(
	HomePage,
	"TBAM  •  AERO ADMIN / TEST PANEL",
	function()
		CreateToast(
			"TBAM",
			"Painel carregado corretamente.",
			2
		)
	end
)


local ActiveCounter =
	CreateButton(
		HomePage,
		"ACTIVE FEATURES  •  0",
		function()
			CreateToast(
				"TBAM",
				"Mostrando o estado das funções.",
				1.5
			)
		end
	)


local FPSButton =
	CreateButton(
		HomePage,
		"FPS  •  0",
		function()
			CreateToast(
				"PERFORMANCE",
				"FPS atual: "
					.. tostring(State.FPS),
				1.5
			)
		end
	)


local PingButton =
	CreateButton(
		HomePage,
		"PING  •  --",
		function()
			CreateToast(
				"NETWORK",
				"Ping: "
					.. tostring(State.Ping)
					.. " ms",
				1.5
			)
		end
	)


local MemoryButton =
	CreateButton(
		HomePage,
		"MEMORY  •  -- MB",
		function()
			CreateToast(
				"MEMORY",
				"Uso estimado: "
					.. tostring(State.Memory)
					.. " MB",
				1.5
			)
		end
	)


CreateButton(
	HomePage,
	"SERVER FLING BRIDGE  •  CHECK",
	function()
		if hasServerFlingBridge() then
			CreateToast(
				"SERVER",
				"TBAM_Remote encontrado.",
				2
			)
		else
			CreateToast(
				"SERVER",
				"TBAM_Remote não encontrado.",
				2
			)
		end
	end
)


local ResetEverythingButton =
	CreateButton(
		HomePage,
		"RESET ALL LOCAL TEST EFFECTS",
		function()

			State.SpeedEnabled = false
			State.JumpEnabled = false
			State.FlyEnabled = false
			State.NoclipEnabled = false
			State.InfiniteJump = false
			State.ZeroGravity = false
			State.PlatformStand = false
			State.Spin = false

			State.Rainbow = false
			State.Trail = false
			State.Particles = false
			State.BigHead = false

			State.Fullbright = false
			State.NightMode = false
			State.VividMode = false

			State.TrollFollow = false
			State.TrollSpectate = false
			State.TrollESP = false
			State.TrollSpin = false
			State.TrollFreeze = false


			Workspace.Gravity =
				Original.Gravity


			local character = getCharacter()

			local humanoid =
				getHumanoid(character)

			local root =
				getRoot(character)


			if humanoid then

				humanoid.WalkSpeed =
					Original.WalkSpeed

				humanoid.UseJumpPower =
					true

				humanoid.JumpPower =
					Original.JumpPower

				humanoid.JumpHeight =
					Original.JumpHeight

				humanoid.PlatformStand =
					false

				humanoid.AutoRotate =
					true
			end


			if root then

				root.AssemblyLinearVelocity =
					Vector3.zero

				root.AssemblyAngularVelocity =
					Vector3.zero
			end


			Lighting.Brightness =
				Original.Lighting.Brightness

			Lighting.Ambient =
				Original.Lighting.Ambient

			Lighting.OutdoorAmbient =
				Original.Lighting.OutdoorAmbient

			Lighting.ClockTime =
				Original.Lighting.ClockTime

			Lighting.ExposureCompensation =
				Original.Lighting.ExposureCompensation


			if TrailObject then
				TrailObject:Destroy()
				TrailObject = nil
			end

			if TrailAttachment0 then
				TrailAttachment0:Destroy()
				TrailAttachment0 = nil
			end

			if TrailAttachment1 then
				TrailAttachment1:Destroy()
				TrailAttachment1 = nil
			end

			if ParticleObject then
				ParticleObject:Destroy()
				ParticleObject = nil
			end

			if FlyVelocity then
				FlyVelocity:Destroy()
				FlyVelocity = nil
			end

			if FlyOrientation then
				FlyOrientation:Destroy()
				FlyOrientation = nil
			end

			if FlyAttachment then
				FlyAttachment:Destroy()
				FlyAttachment = nil
			end


			ClearTrollHighlight()

			TrollTarget = nil

			State.SelectedPlayer = nil
			State.TrollTargetName = ""


			SpeedButton.Text =
				"SPEED  •  OFF"

			JumpButton.Text =
				"JUMP  •  OFF"

			FlyButton.Text =
				"FLY  •  OFF"

			FlySpeedButton.Text =
				"FLY SPEED  •  20"

			NoclipButton.Text =
				"NOCLIP  •  OFF"

			InfiniteJumpButton.Text =
				"INFINITE JUMP  •  OFF"

			GravityButton.Text =
				"GRAVITY  •  196.2"

			PlatformButton.Text =
				"PLATFORM STAND  •  OFF"

			SpinButton.Text =
				"SPIN  •  OFF"

			ZeroGravityButton.Text =
				"ZERO GRAVITY  •  OFF"

			RainbowButton.Text =
				"RAINBOW CHARACTER  •  OFF"

			TrailButton.Text =
				"PLAYER TRAIL  •  OFF"

			ParticleButton.Text =
				"PARTICLE FX  •  OFF"

			BigHeadButton.Text =
				"BIG HEAD  •  OFF"

			FullbrightButton.Text =
				"FULLBRIGHT  •  OFF"

			NightButton.Text =
				"NIGHT MODE  •  OFF"

			VividButton.Text =
				"VIVID LIGHTING  •  OFF"


			if SpectateButton then
				SpectateButton.Text =
					"SPECTATE POV  •  OFF"
			end

			if FollowButton then
				FollowButton.Text =
					"FOLLOW TARGET  •  OFF"
			end

			if TargetESPButton then
				TargetESPButton.Text =
					"TARGET ESP  •  OFF"
			end

			if SpinTargetButton then
				SpinTargetButton.Text =
					"SPIN TARGET  •  OFF"
			end

			if FreezeTargetButton then
				FreezeTargetButton.Text =
					"FREEZE TARGET  •  OFF"
			end


			if TargetInfoLabel then
				TargetInfoLabel.Text =
					"TARGET  •  NONE"
			end


			if TargetStatsLabel then
				TargetStatsLabel.Text =
					"DISTANCE • -- | SPEED • -- | HP • --"
			end


			for _, entry in ipairs(Buttons) do

				entry.Object:SetAttribute(
					"Enabled",
					false
				)

				entry.Object.BackgroundColor3 =
					Theme.Button

				entry.Stroke.Transparency =
					0.78
			end


			local camera = getCamera()

			if camera then

				camera.CameraType =
					Enum.CameraType.Custom

				if humanoid then
					camera.CameraSubject =
						humanoid
				end

				camera.FieldOfView =
					Original.CameraFOV
			end


			CreateToast(
				"TBAM",
				"Todos os efeitos locais foram restaurados.",
				2.2
			)
		end
	)


--// =========================================================
--// MOVEMENT
--// =========================================================

CreateSection(
	MovementPage,
	"MOVEMENT"
)


SpeedButton =
	CreateButton(
		MovementPage,
		"SPEED  •  OFF",
		function(button)

			if not State.SpeedEnabled then

				State.SpeedEnabled = true
				State.SpeedIndex = 1

			else

				State.SpeedIndex += 1

				if State.SpeedIndex >
					#CONFIG.SpeedValues then

					State.SpeedEnabled = false
					State.SpeedIndex = 1
				end
			end


			local humanoid =
				getHumanoid(
					getCharacter()
				)


			if humanoid then

				humanoid.WalkSpeed =
					State.SpeedEnabled
					and CONFIG.SpeedValues[
						State.SpeedIndex
					]
					or Original.WalkSpeed
			end


			button.Text =
				"SPEED  •  "
				.. (
					State.SpeedEnabled
					and tostring(
						CONFIG.SpeedValues[
							State.SpeedIndex
						]
					)
					or "OFF"
				)


			SetButtonState(
				button,
				State.SpeedEnabled
			)
		end
	)


JumpButton =
	CreateButton(
		MovementPage,
		"JUMP  •  OFF",
		function(button)

			if not State.JumpEnabled then

				State.JumpEnabled = true
				State.JumpIndex = 1

			else

				State.JumpIndex += 1

				if State.JumpIndex >
					#CONFIG.JumpValues then

					State.JumpEnabled = false
					State.JumpIndex = 1
				end
			end


			local humanoid =
				getHumanoid(
					getCharacter()
				)


			if humanoid then

				humanoid.UseJumpPower = true

				humanoid.JumpPower =
					State.JumpEnabled
					and CONFIG.JumpValues[
						State.JumpIndex
					]
					or Original.JumpPower
			end


			button.Text =
				"JUMP  •  "
				.. (
					State.JumpEnabled
					and tostring(
						CONFIG.JumpValues[
							State.JumpIndex
						]
					)
					or "OFF"
				)


			SetButtonState(
				button,
				State.JumpEnabled
			)
		end
	)


FlyButton =
	CreateButton(
		MovementPage,
		"FLY  •  OFF",
		function(button)

			State.FlyEnabled =
				not State.FlyEnabled


			local character =
				getCharacter()

			local humanoid =
				getHumanoid(character)

			local root =
				getRoot(character)


			if not character
				or not humanoid
				or not root then

				State.FlyEnabled = false

				button.Text =
					"FLY  •  OFF"

				SetButtonState(
					button,
					false
				)

				return
			end


			if State.FlyEnabled then

				if FlyVelocity then
					FlyVelocity:Destroy()
					FlyVelocity = nil
				end

				if FlyOrientation then
					FlyOrientation:Destroy()
					FlyOrientation = nil
				end

				if FlyAttachment then
					FlyAttachment:Destroy()
					FlyAttachment = nil
				end


				FlyAttachment =
					Instance.new("Attachment")

				FlyAttachment.Name =
					"TBAM_FlyAttachment"

				FlyAttachment.Parent =
					root


				FlyVelocity =
					Instance.new("LinearVelocity")

				FlyVelocity.Name =
					"TBAM_FlyVelocity"

				FlyVelocity.Attachment0 =
					FlyAttachment

				FlyVelocity.RelativeTo =
					Enum.ActuatorRelativeTo.World

				FlyVelocity.VelocityConstraintMode =
					Enum.VelocityConstraintMode.Vector

				FlyVelocity.MaxForce =
					math.huge

				FlyVelocity.VectorVelocity =
					Vector3.zero

				FlyVelocity.Parent =
					root


				FlyOrientation =
					Instance.new("AlignOrientation")

				FlyOrientation.Name =
					"TBAM_FlyOrientation"

				FlyOrientation.Attachment0 =
					FlyAttachment

				FlyOrientation.Mode =
					Enum.OrientationAlignmentMode.OneAttachment

				FlyOrientation.MaxTorque =
					math.huge

				FlyOrientation.Responsiveness =
					100

				FlyOrientation.Parent =
					root


				humanoid.AutoRotate = false
				humanoid.PlatformStand = true

			else

				if FlyVelocity then
					FlyVelocity:Destroy()
					FlyVelocity = nil
				end

				if FlyOrientation then
					FlyOrientation:Destroy()
					FlyOrientation = nil
				end

				if FlyAttachment then
					FlyAttachment:Destroy()
					FlyAttachment = nil
				end


				humanoid.AutoRotate = true
				humanoid.PlatformStand = false

				root.AssemblyLinearVelocity =
					Vector3.zero
			end


			button.Text =
				"FLY  •  "
				.. (
					State.FlyEnabled
					and "ON"
					or "OFF"
				)


			SetButtonState(
				button,
				State.FlyEnabled
			)
		end
	)


FlySpeedButton =
	CreateButton(
		MovementPage,
		"FLY SPEED  •  20",
		function(button)

			State.FlyIndex += 1

			if State.FlyIndex >
				#CONFIG.FlySpeeds then

				State.FlyIndex = 1
			end


			button.Text =
				"FLY SPEED  •  "
				.. tostring(
					CONFIG.FlySpeeds[
						State.FlyIndex
					]
				)
		end
	)


NoclipButton =
	CreateButton(
		MovementPage,
		"NOCLIP  •  OFF",
		function(button)

			State.NoclipEnabled =
				not State.NoclipEnabled


			local character =
				getCharacter()


			if not character then

				State.NoclipEnabled =
					false

				return
			end


			if State.NoclipEnabled then

				NoclipSaved = {}

				for _, part in ipairs(
					character:GetDescendants()
				) do

					if part:IsA("BasePart") then

						NoclipSaved[part] =
							part.CanCollide

						part.CanCollide = false
					end
				end

			else

				for part, savedValue in pairs(
					NoclipSaved
				) do

					if part and part.Parent then
						part.CanCollide =
							savedValue
					end
				end

				NoclipSaved = {}
			end


			button.Text =
				"NOCLIP  •  "
				.. (
					State.NoclipEnabled
					and "ON"
					or "OFF"
				)


			SetButtonState(
				button,
				State.NoclipEnabled
			)
		end
	)


InfiniteJumpButton =
	CreateButton(
		MovementPage,
		"INFINITE JUMP  •  OFF",
		function(button)

			State.InfiniteJump =
				not State.InfiniteJump


			button.Text =
				"INFINITE JUMP  •  "
				.. (
					State.InfiniteJump
					and "ON"
					or "OFF"
				)


			SetButtonState(
				button,
				State.InfiniteJump
			)
		end
	)


GravityButton =
	CreateButton(
		MovementPage,
		"GRAVITY  •  196.2",
		function(button)

			State.GravityIndex += 1

			if State.GravityIndex >
				#CONFIG.GravityValues then

				State.GravityIndex = 1
			end


			local value =
				CONFIG.GravityValues[
					State.GravityIndex
				]


			Workspace.Gravity = value


			button.Text =
				"GRAVITY  •  "
				.. tostring(value)
		end
	)


PlatformButton =
	CreateButton(
		MovementPage,
		"PLATFORM STAND  •  OFF",
		function(button)

			State.PlatformStand =
				not State.PlatformStand


			local humanoid =
				getHumanoid(
					getCharacter()
				)


			if humanoid then

				humanoid.PlatformStand =
					State.PlatformStand
			end


			button.Text =
				"PLATFORM STAND  •  "
				.. (
					State.PlatformStand
					and "ON"
					or "OFF"
				)


			SetButtonState(
				button,
				State.PlatformStand
			)
		end
	)


CreateSection(
	MovementPage,
	"EXTRA"
)


CreateButton(
	MovementPage,
	"FAST RESET MOVEMENT",
	function()

		State.SpeedEnabled = false
		State.JumpEnabled = false
		State.FlyEnabled = false
		State.NoclipEnabled = false
		State.InfiniteJump = false
		State.PlatformStand = false


		local humanoid =
			getHumanoid(
				getCharacter()
			)

		local root =
			getRoot(
				getCharacter()
			)


		if humanoid then

			humanoid.WalkSpeed =
				Original.WalkSpeed

			humanoid.UseJumpPower =
				true

			humanoid.JumpPower =
				Original.JumpPower

			humanoid.PlatformStand =
				false

			humanoid.AutoRotate =
				true
		end


		if root then
			root.AssemblyLinearVelocity =
				Vector3.zero

			root.AssemblyAngularVelocity =
				Vector3.zero
		end


		if FlyVelocity then
			FlyVelocity:Destroy()
			FlyVelocity = nil
		end

		if FlyOrientation then
			FlyOrientation:Destroy()
			FlyOrientation = nil
		end

		if FlyAttachment then
			FlyAttachment:Destroy()
			FlyAttachment = nil
		end


		SpeedButton.Text = "SPEED  •  OFF"
		JumpButton.Text = "JUMP  •  OFF"
		FlyButton.Text = "FLY  •  OFF"
		NoclipButton.Text = "NOCLIP  •  OFF"
		InfiniteJumpButton.Text = "INFINITE JUMP  •  OFF"
		PlatformButton.Text = "PLATFORM STAND  •  OFF"
	end
)


--// =========================================================
--// FUN
--// =========================================================

CreateSection(
	FunPage,
	"PHYSICS"
)


SpinButton =
	CreateButton(
		FunPage,
		"SPIN  •  OFF",
		function(button)

			State.Spin =
				not State.Spin

			button.Text =
				"SPIN  •  "
				.. (
					State.Spin
					and "ON"
					or "OFF"
				)

			SetButtonState(
				button,
				State.Spin
			)
		end
	)


SpinSpeedButton =
	CreateButton(
		FunPage,
		"SPIN SPEED  •  360",
		function(button)

			State.SpinSpeed += 360

			if State.SpinSpeed > 2160 then
				State.SpinSpeed = 360
			end

			button.Text =
				"SPIN SPEED  •  "
				.. tostring(
					State.SpinSpeed
				)
		end
	)


CreateButton(
	FunPage,
	"LAUNCH UP",
	function()

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
	end
)


ZeroGravityButton =
	CreateButton(
		FunPage,
		"ZERO GRAVITY  •  OFF",
		function(button)

			State.ZeroGravity =
				not State.ZeroGravity

			Workspace.Gravity =
				State.ZeroGravity
				and 0
				or Original.Gravity


			button.Text =
				"ZERO GRAVITY  •  "
				.. (
					State.ZeroGravity
					and "ON"
					or "OFF"
				)

			SetButtonState(
				button,
				State.ZeroGravity
			)
		end
	)


CreateSection(
	FunPage,
	"CHARACTER EFFECTS"
)


RainbowButton =
	CreateButton(
		FunPage,
		"RAINBOW CHARACTER  •  OFF",
		function(button)

			State.Rainbow =
				not State.Rainbow

			button.Text =
				"RAINBOW CHARACTER  •  "
				.. (
					State.Rainbow
					and "ON"
					or "OFF"
				)

			SetButtonState(
				button,
				State.Rainbow
			)
		end
	)


TrailButton =
	CreateButton(
		FunPage,
		"PLAYER TRAIL  •  OFF",
		function(button)

			State.Trail =
				not State.Trail


			local root =
				getRoot(
					getCharacter()
				)


			if not root then

				State.Trail = false

				button.Text =
					"PLAYER TRAIL  •  OFF"

				SetButtonState(
					button,
					false
				)

				return
			end


			if State.Trail then

				if TrailObject then
					TrailObject:Destroy()
				end

				if TrailAttachment0 then
					TrailAttachment0:Destroy()
				end

				if TrailAttachment1 then
					TrailAttachment1:Destroy()
				end


				TrailAttachment0 =
					Instance.new("Attachment")

				TrailAttachment1 =
					Instance.new("Attachment")


				TrailAttachment0.Position =
					Vector3.new(0, 1, 0)

				TrailAttachment1.Position =
					Vector3.new(0, -1, 0)


				TrailAttachment0.Parent = root
				TrailAttachment1.Parent = root


				TrailObject =
					Instance.new("Trail")


				TrailObject.Attachment0 =
					TrailAttachment0

				TrailObject.Attachment1 =
					TrailAttachment1

				TrailObject.Lifetime = 0.7
				TrailObject.MinLength = 0.1
				TrailObject.Parent = root

			else

				if TrailObject then
					TrailObject:Destroy()
					TrailObject = nil
				end

				if TrailAttachment0 then
					TrailAttachment0:Destroy()
					TrailAttachment0 = nil
				end

				if TrailAttachment1 then
					TrailAttachment1:Destroy()
					TrailAttachment1 = nil
				end
			end


			button.Text =
				"PLAYER TRAIL  •  "
				.. (
					State.Trail
					and "ON"
					or "OFF"
				)

			SetButtonState(
				button,
				State.Trail
			)
		end
	)


ParticleButton =
	CreateButton(
		FunPage,
		"PARTICLE FX  •  OFF",
		function(button)

			State.Particles =
				not State.Particles


			local root =
				getRoot(
					getCharacter()
				)


			if not root then

				State.Particles =
					false

				button.Text =
					"PARTICLE FX  •  OFF"

				SetButtonState(
					button,
					false
				)

				return
			end


			if State.Particles then

				if ParticleObject then
					ParticleObject:Destroy()
				end


				ParticleObject =
					Instance.new(
						"ParticleEmitter"
					)

				ParticleObject.Rate = 12

				ParticleObject.Lifetime =
					NumberRange.new(
						0.5,
						1.2
					)

				ParticleObject.Speed =
					NumberRange.new(
						1,
						3
					)

				ParticleObject.SpreadAngle =
					Vector2.new(360, 360)

				ParticleObject.Parent =
					root

			else

				if ParticleObject then
					ParticleObject:Destroy()
					ParticleObject = nil
				end
			end


			button.Text =
				"PARTICLE FX  •  "
				.. (
					State.Particles
					and "ON"
					or "OFF"
				)

			SetButtonState(
				button,
				State.Particles
			)
		end
	)


BigHeadButton =
	CreateButton(
		FunPage,
		"BIG HEAD  •  OFF",
		function(button)

			State.BigHead =
				not State.BigHead


			local character =
				getCharacter()

			local head =
				character
				and character:FindFirstChild("Head")


			if head and head:IsA("BasePart") then

				if State.BigHead then

					Original.HeadSize =
						Original.HeadSize
						or head.Size

					head.Size =
						Original.HeadSize * 1.7

				else

					if Original.HeadSize then
						head.Size =
							Original.HeadSize
					end
				end
			end


			button.Text =
				"BIG HEAD  •  "
				.. (
					State.BigHead
					and "ON"
					or "OFF"
				)

			SetButtonState(
				button,
				State.BigHead
			)
		end
	)


--// =========================================================
--// VISUAL
--// =========================================================

CreateSection(
	VisualPage,
	"CAMERA / LIGHTING"
)


FOVButton =
	CreateButton(
		VisualPage,
		"CAMERA FOV  •  70",
		function(button)

			local camera =
				getCamera()

			if not camera then
				return
			end


			camera.FieldOfView += 15


			if camera.FieldOfView > 130 then
				camera.FieldOfView = 55
			end


			button.Text =
				"CAMERA FOV  •  "
				.. math.floor(
					camera.FieldOfView
				)
		end
	)


FullbrightButton =
	CreateButton(
		VisualPage,
		"FULLBRIGHT  •  OFF",
		function(button)

			State.Fullbright =
				not State.Fullbright


			if State.Fullbright then

				Lighting.Brightness = 3

				Lighting.Ambient =
					Color3.fromRGB(
						255,
						255,
						255
					)

				Lighting.OutdoorAmbient =
					Color3.fromRGB(
						255,
						255,
						255
					)

			else

				Lighting.Brightness =
					Original.Lighting.Brightness

				Lighting.Ambient =
					Original.Lighting.Ambient

				Lighting.OutdoorAmbient =
					Original.Lighting.OutdoorAmbient
			end


			button.Text =
				"FULLBRIGHT  •  "
				.. (
					State.Fullbright
					and "ON"
					or "OFF"
				)

			SetButtonState(
				button,
				State.Fullbright
			)
		end
	)


NightButton =
	CreateButton(
		VisualPage,
		"NIGHT MODE  •  OFF",
		function(button)

			State.NightMode =
				not State.NightMode


			Lighting.ClockTime =
				State.NightMode
				and 0
				or Original.Lighting.ClockTime


			button.Text =
				"NIGHT MODE  •  "
				.. (
					State.NightMode
					and "ON"
					or "OFF"
				)

			SetButtonState(
				button,
				State.NightMode
			)
		end
	)


VividButton =
	CreateButton(
		VisualPage,
		"VIVID LIGHTING  •  OFF",
		function(button)

			State.VividMode =
				not State.VividMode


			if State.VividMode then

				Lighting.Brightness =
					Original.Lighting.Brightness
					+ 1

				Lighting.ExposureCompensation =
					0.5

			else

				Lighting.Brightness =
					Original.Lighting.Brightness

				Lighting.ExposureCompensation =
					Original.Lighting.ExposureCompensation
			end


			button.Text =
				"VIVID LIGHTING  •  "
				.. (
					State.VividMode
					and "ON"
					or "OFF"
				)

			SetButtonState(
				button,
				State.VividMode
			)
		end
	)


CreateButton(
	VisualPage,
	"RESET VISUALS",
	function()

		State.Fullbright = false
		State.NightMode = false
		State.VividMode = false


		Lighting.Brightness =
			Original.Lighting.Brightness

		Lighting.Ambient =
			Original.Lighting.Ambient

		Lighting.OutdoorAmbient =
			Original.Lighting.OutdoorAmbient

		Lighting.ClockTime =
			Original.Lighting.ClockTime

		Lighting.ExposureCompensation =
			Original.Lighting.ExposureCompensation


		local camera =
			getCamera()

		if camera then
			camera.FieldOfView =
				Original.CameraFOV
		end


		FullbrightButton.Text =
			"FULLBRIGHT  •  OFF"

		NightButton.Text =
			"NIGHT MODE  •  OFF"

		VividButton.Text =
			"VIVID LIGHTING  •  OFF"

		FOVButton.Text =
			"CAMERA FOV  •  "
			.. tostring(
				Original.CameraFOV
			)


		SetButtonState(
			FullbrightButton,
			false
		)

		SetButtonState(
			NightButton,
			false
		)

		SetButtonState(
			VividButton,
			false
		)
	end
)


--// =========================================================
--// PLAYER
--// =========================================================

CreateSection(
	PlayerPage,
	"CHARACTER"
)


CreateButton(
	PlayerPage,
	"HEAL LOCAL CHARACTER",
	function()

		local humanoid =
			getHumanoid(
				getCharacter()
			)

		if humanoid then
			humanoid.Health =
				humanoid.MaxHealth
		end
	end
)


CreateButton(
	PlayerPage,
	"SIT / STAND",
	function()

		local humanoid =
			getHumanoid(
				getCharacter()
			)

		if humanoid then
			humanoid.Sit =
				not humanoid.Sit
		end
	end
)


CreateButton(
	PlayerPage,
	"RESET CAMERA",
	function()

		local camera =
			getCamera()

		local humanoid =
			getHumanoid(
				getCharacter()
			)

		if camera and humanoid then

			camera.CameraType =
				Enum.CameraType.Custom

			camera.CameraSubject =
				humanoid

			camera.FieldOfView =
				Original.CameraFOV
		end
	end
)


CreateButton(
	PlayerPage,
	"RESPAWN CHARACTER",
	function()

		local humanoid =
			getHumanoid(
				getCharacter()
			)

		if humanoid then
			humanoid.Health = 0
		end
	end
)


CreateSection(
	PlayerPage,
	"LOCAL INFO"
)


local PositionButton =
	CreateButton(
		PlayerPage,
		"POSITION  •  ---",
		function()

			local root =
				getRoot(
					getCharacter()
				)

			if root then

				CreateToast(
					"POSITION",
					string.format(
						"X %.1f  Y %.1f  Z %.1f",
						root.Position.X,
						root.Position.Y,
						root.Position.Z
					),
					2
				)
			end
		end
	)


local VelocityButton =
	CreateButton(
		PlayerPage,
		"VELOCITY  •  ---",
		function()

			local root =
				getRoot(
					getCharacter()
				)

			if root then

				CreateToast(
					"VELOCITY",
					string.format(
						"%.1f studs/s",
						root.AssemblyLinearVelocity.Magnitude
					),
					2
				)
			end
		end
	)


local HumanoidStateButton =
	CreateButton(
		PlayerPage,
		"HUMANOID STATE  •  ---",
		function()

			local humanoid =
				getHumanoid(
					getCharacter()
				)

			if humanoid then

				CreateToast(
					"HUMANOID",
					humanoid:GetState().Name,
					2
				)
			end
		end
	)


--// =========================================================
--// TROLL
--// =========================================================

CreateSection(
	TrollPage,
	"TARGET"
)


TargetInfoLabel =
	Instance.new("TextLabel")

TargetInfoLabel.Size =
	UDim2.new(1, -6, 0, 40)

TargetInfoLabel.BackgroundColor3 =
	Theme.Panel

TargetInfoLabel.BorderSizePixel = 0
TargetInfoLabel.Font = Enum.Font.GothamBold
TargetInfoLabel.Text = "TARGET  •  NONE"
TargetInfoLabel.TextSize = 11
TargetInfoLabel.TextColor3 = Theme.Text
TargetInfoLabel.TextXAlignment =
	Enum.TextXAlignment.Center

TargetInfoLabel.ZIndex = 250
TargetInfoLabel.Parent = TrollPage


local TargetInfoCorner =
	Instance.new("UICorner")

TargetInfoCorner.CornerRadius =
	UDim.new(0, 10)

TargetInfoCorner.Parent =
	TargetInfoLabel


TargetStatsLabel =
	Instance.new("TextLabel")

TargetStatsLabel.Size =
	UDim2.new(1, -6, 0, 34)

TargetStatsLabel.BackgroundColor3 =
	Theme.Button

TargetStatsLabel.BackgroundTransparency =
	0.15

TargetStatsLabel.BorderSizePixel = 0
TargetStatsLabel.Font = Enum.Font.GothamMedium
TargetStatsLabel.Text =
	"DISTANCE • -- | SPEED • -- | HP • --"

TargetStatsLabel.TextSize = 9
TargetStatsLabel.TextColor3 = Theme.Subtext
TargetStatsLabel.TextXAlignment =
	Enum.TextXAlignment.Center

TargetStatsLabel.ZIndex = 250
TargetStatsLabel.Parent = TrollPage


local TargetStatsCorner =
	Instance.new("UICorner")

TargetStatsCorner.CornerRadius =
	UDim.new(0, 10)

TargetStatsCorner.Parent =
	TargetStatsLabel


TargetRemoteLabel =
	Instance.new("TextLabel")

TargetRemoteLabel.Size =
	UDim2.new(1, -6, 0, 30)

TargetRemoteLabel.BackgroundTransparency =
	1

TargetRemoteLabel.Font =
	Enum.Font.GothamMedium

TargetRemoteLabel.Text =
	"SERVER FLING BRIDGE • CHECKING..."

TargetRemoteLabel.TextSize = 9
TargetRemoteLabel.TextColor3 =
	Theme.Subtext

TargetRemoteLabel.TextXAlignment =
	Enum.TextXAlignment.Left

TargetRemoteLabel.ZIndex = 250
TargetRemoteLabel.Parent = TrollPage


CreateButton(
	TrollPage,
	"REFRESH PLAYERS / BOTS",
	function()
		RefreshTargetList()
	end
)


TargetList =
	Instance.new("ScrollingFrame")

TargetList.Name =
	"TBAM_TargetList"

TargetList.Size =
	UDim2.new(1, -6, 0, 115)

TargetList.BackgroundColor3 =
	Theme.Panel

TargetList.BackgroundTransparency =
	0.1

TargetList.BorderSizePixel = 0

TargetList.ScrollBarThickness = 3
TargetList.ScrollBarImageColor3 =
	Theme.Accent

TargetList.ScrollBarImageTransparency =
	0.3

TargetList.AutomaticCanvasSize =
	Enum.AutomaticSize.Y

TargetList.CanvasSize =
	UDim2.new()

TargetList.ZIndex = 260
TargetList.Parent = TrollPage


local TargetListCorner =
	Instance.new("UICorner")

TargetListCorner.CornerRadius =
	UDim.new(0, 11)

TargetListCorner.Parent =
	TargetList


local TargetListPadding =
	Instance.new("UIPadding")

TargetListPadding.PaddingTop =
	UDim.new(0, 5)

TargetListPadding.PaddingBottom =
	UDim.new(0, 5)

TargetListPadding.PaddingLeft =
	UDim.new(0, 5)

TargetListPadding.PaddingRight =
	UDim.new(0, 5)

TargetListPadding.Parent =
	TargetList


local TargetListLayout =
	Instance.new("UIListLayout")

TargetListLayout.Padding =
	UDim.new(0, 5)

TargetListLayout.Parent =
	TargetList


CreateSection(
	TrollPage,
	"LOCAL TROLL TOOLS"
)


CreateButton(
	TrollPage,
	"TP TO TARGET",
	function()

		if not TrollTarget
			or not isValidTrollTarget(
				TrollTarget
			)
		then

			CreateToast(
				"TP",
				"Selecione um alvo válido primeiro.",
				1.5
			)

			return
		end


		local myRoot =
			getRoot(
				getCharacter()
			)

		local targetRoot =
			getTargetRoot(
				TrollTarget
			)


		if myRoot and targetRoot then

			myRoot.CFrame =
				targetRoot.CFrame
				*
				CFrame.new(
					0,
					0,
					CONFIG.FollowDistance
				)

			CreateToast(
				"TP",
				"Teleportado para "
					.. TrollTarget.Name,
				1.5
			)
		end
	end
)


CreateButton(
	TrollPage,
	"TARGET TO ME",
	function()

		if not TrollTarget
			or not isValidTrollTarget(
				TrollTarget
			)
		then

			CreateToast(
				"TP",
				"Selecione um alvo.",
				1.5
			)

			return
		end


		local myRoot =
			getRoot(
				getCharacter()
			)

		local targetRoot =
			getTargetRoot(
				TrollTarget
			)


		if myRoot and targetRoot then

			targetRoot.CFrame =
				myRoot.CFrame
				*
				CFrame.new(
					0,
					0,
					-4
				)

			CreateToast(
				"TARGET",
				"Alvo movido para você.",
				1.5
			)
		end
	end
)


SpectateButton =
	CreateButton(
		TrollPage,
		"SPECTATE POV  •  OFF",
		function(button)

			State.TrollSpectate =
				not State.TrollSpectate


			local camera =
				getCamera()


			if State.TrollSpectate then

				local targetHumanoid =
					getTargetHumanoid(
						TrollTarget
					)


				if not camera
					or not targetHumanoid
				then

					State.TrollSpectate =
						false

					button.Text =
						"SPECTATE POV  •  OFF"

					SetButtonState(
						button,
						false
					)

					CreateToast(
						"SPECTATE",
						"Selecione um alvo válido primeiro.",
						1.5
					)

					return
				end


				camera.CameraType =
					Enum.CameraType.Custom

				camera.CameraSubject =
					targetHumanoid

			else

				local humanoid =
					getHumanoid(
						getCharacter()
					)

				if camera then

					camera.CameraType =
						Enum.CameraType.Custom

					camera.CameraSubject =
						humanoid
				end
			end


			button.Text =
				"SPECTATE POV  •  "
				.. (
					State.TrollSpectate
					and "ON"
					or "OFF"
				)


			SetButtonState(
				button,
				State.TrollSpectate
			)
		end
	)


FollowButton =
	CreateButton(
		TrollPage,
		"FOLLOW TARGET  •  OFF",
		function(button)

			State.TrollFollow =
				not State.TrollFollow


			if State.TrollFollow
				and (
					not TrollTarget
					or not isValidTrollTarget(
						TrollTarget
					)
				)
			then

				State.TrollFollow =
					false

				button.Text =
					"FOLLOW TARGET  •  OFF"

				SetButtonState(
					button,
					false
				)

				CreateToast(
					"FOLLOW",
					"Selecione um alvo válido primeiro.",
					1.5
				)

				return
			end


			button.Text =
				"FOLLOW TARGET  •  "
				.. (
					State.TrollFollow
					and "ON"
					or "OFF"
				)


			SetButtonState(
				button,
				State.TrollFollow
			)
		end
	)


TargetESPButton =
	CreateButton(
		TrollPage,
		"TARGET ESP  •  OFF",
		function(button)

			if not TrollTarget then

				State.TrollESP = false

				button.Text =
					"TARGET ESP  •  OFF"

				SetButtonState(
					button,
					false
				)

				CreateToast(
					"ESP",
					"Selecione um alvo primeiro.",
					1.5
				)

				return
			end


			State.TrollESP =
				not State.TrollESP


			if State.TrollESP then

				SetTrollTarget(
					TrollTarget
				)

			else

				ClearTrollHighlight()
			end


			button.Text =
				"TARGET ESP  •  "
				.. (
					State.TrollESP
					and "ON"
					or "OFF"
				)

			SetButtonState(
				button,
				State.TrollESP
			)
		end
	)


CreateSection(
	TrollPage,
	"PHYSICS TROLL"
)


--// =========================================================
--// FLING
--// =========================================================

CreateButton(
	TrollPage,
	"FLING TARGET",
	function()

		if not TrollTarget
			or not isValidTrollTarget(
				TrollTarget
			)
		then

			CreateToast(
				"FLING",
				"Selecione um alvo válido primeiro.",
				1.5
			)

			return
		end


		-- server bridge first
		if serverAction(
			"FLING",
			TrollTarget,
			{
				Power = CONFIG.FlingPower,
				Impulse = CONFIG.FlingImpulse,
				Angular = CONFIG.FlingAngular
			}
		) then

			CreateToast(
				"FLING",
				"Pedido de fling enviado ao servidor.",
				1.5
			)

			return
		end


		-- local fallback
		local targetRoot =
			getTargetRoot(
				TrollTarget
			)

		local myRoot =
			getRoot(
				getCharacter()
			)


		if not targetRoot then
			return
		end


		local direction

		if myRoot then

			direction =
				safeUnit(
					targetRoot.Position
						- myRoot.Position,
					Vector3.new(
						1,
						0.2,
						0
					)
				)

		else

			direction =
				Vector3.new(
					1,
					0.2,
					0
				)
		end


		local horizontal =
			direction
			* CONFIG.FlingPower

		local upward =
			Vector3.new(
				0,
				CONFIG.FlingPower * 0.55,
				0
			)

		local finalVelocity =
			horizontal
			+ upward


		local successImpulse =
			pcall(function()

				targetRoot:ApplyImpulse(
					finalVelocity
					* CONFIG.FlingImpulse
				)
			end)


		pcall(function()

			targetRoot.AssemblyLinearVelocity =
				finalVelocity

			targetRoot.AssemblyAngularVelocity =
				Vector3.new(
					CONFIG.FlingAngular,
					CONFIG.FlingAngular,
					CONFIG.FlingAngular
				)
		end)


		if successImpulse then

			local startTime =
				os.clock()


			task.spawn(function()

				while
					TrollTarget
					and TrollTarget.Parent
					and targetRoot.Parent
					and os.clock()
						- startTime
						< CONFIG.FlingDuration
				do

					pcall(function()

						targetRoot:ApplyImpulse(
							finalVelocity
							* 0.18
							* CONFIG.FlingImpulse
						)

						targetRoot.AssemblyAngularVelocity =
							Vector3.new(
								CONFIG.FlingAngular,
								CONFIG.FlingAngular,
								CONFIG.FlingAngular
							)
					end)

					RunService.Heartbeat:Wait()
				end
			end)

			CreateToast(
				"FLING",
				"Impulso físico aplicado.",
				1.5
			)

		else

			CreateToast(
				"FLING",
				"Sem autoridade física local sobre o alvo.",
				2
			)
		end
	end
)


--// =========================================================
--// LAUNCH
--// =========================================================

CreateButton(
	TrollPage,
	"LAUNCH TARGET",
	function()

		if not TrollTarget
			or not isValidTrollTarget(
				TrollTarget
			)
		then

			CreateToast(
				"LAUNCH",
				"Selecione um alvo válido primeiro.",
				1.5
			)

			return
		end


		if serverAction(
			"LAUNCH",
			TrollTarget,
			{
				Power = CONFIG.LaunchPower
			}
		) then

			CreateToast(
				"LAUNCH",
				"Launch enviado ao servidor.",
				1.5
			)

			return
		end


		local targetRoot =
			getTargetRoot(
				TrollTarget
			)


		if targetRoot then

			pcall(function()

				targetRoot:ApplyImpulse(
					Vector3.new(
						0,
						CONFIG.LaunchPower
							* targetRoot:GetMass(),
						0
					)
				)

				targetRoot.AssemblyLinearVelocity =
					Vector3.new(
						0,
						CONFIG.LaunchPower,
						0
					)
			end)


			CreateToast(
				"LAUNCH",
				"Launch físico aplicado.",
				1.5
			)
		end
	end
)


--// =========================================================
--// PUSH
--// =========================================================

CreateButton(
	TrollPage,
	"PUSH TARGET",
	function()

		if not TrollTarget
			or not isValidTrollTarget(
				TrollTarget
			)
		then

			CreateToast(
				"PUSH",
				"Selecione um alvo.",
				1.5
			)

			return
		end


		local myRoot =
			getRoot(
				getCharacter()
			)

		local targetRoot =
			getTargetRoot(
				TrollTarget
			)


		if not myRoot
			or not targetRoot
		then
			return
		end


		local direction =
			safeUnit(
				targetRoot.Position
					- myRoot.Position,
				Vector3.new(
					0,
					0,
					-1
				)
			)


		if serverAction(
			"PUSH",
			TrollTarget,
			{
				Direction = direction,
				Power = CONFIG.PushPower
			}
		) then
			return
		end


		pcall(function()

			local velocity =
				direction
				* CONFIG.PushPower
				+ Vector3.new(
					0,
					25,
					0
				)


			targetRoot:ApplyImpulse(
				velocity
				* targetRoot:GetMass()
			)

			targetRoot.AssemblyLinearVelocity =
				velocity
		end)
	end
)


--// =========================================================
--// PULL
--// =========================================================

CreateButton(
	TrollPage,
	"PULL TARGET",
	function()

		if not TrollTarget
			or not isValidTrollTarget(
				TrollTarget
			)
		then

			CreateToast(
				"PULL",
				"Selecione um alvo.",
				1.5
			)

			return
		end


		local myRoot =
			getRoot(
				getCharacter()
			)

		local targetRoot =
			getTargetRoot(
				TrollTarget
			)


		if not myRoot
			or not targetRoot
		then
			return
		end


		local direction =
			safeUnit(
				myRoot.Position
					- targetRoot.Position,
				Vector3.new(
					0,
					0,
					1
				)
			)


		if serverAction(
			"PULL",
			TrollTarget,
			{
				Direction = direction,
				Power = CONFIG.PullPower
			}
		) then
			return
		end


		pcall(function()

			local velocity =
				direction
				* CONFIG.PullPower

			targetRoot:ApplyImpulse(
				velocity
				* targetRoot:GetMass()
			)

			targetRoot.AssemblyLinearVelocity =
				velocity
		end)
	end
)


--// =========================================================
--// SPIN TARGET
--// =========================================================

SpinTargetButton =
	CreateButton(
		TrollPage,
		"SPIN TARGET  •  OFF",
		function(button)

			State.TrollSpin =
				not State.TrollSpin


			if State.TrollSpin
				and (
					not TrollTarget
					or not isValidTrollTarget(
						TrollTarget
					)
				)
			then

				State.TrollSpin =
					false

				button.Text =
					"SPIN TARGET  •  OFF"

				SetButtonState(
					button,
					false
				)

				CreateToast(
					"SPIN TARGET",
					"Selecione um alvo válido primeiro.",
					1.5
				)

				return
			end


			button.Text =
				"SPIN TARGET  •  "
				.. (
					State.TrollSpin
					and "ON"
					or "OFF"
				)


			SetButtonState(
				button,
				State.TrollSpin
			)
		end
	)


--// =========================================================
--// FREEZE
--// =========================================================

FreezeTargetButton =
	CreateButton(
		TrollPage,
		"FREEZE TARGET  •  OFF",
		function(button)

			if not TrollTarget
				or not isValidTrollTarget(
					TrollTarget
				)
			then

				CreateToast(
					"FREEZE",
					"Selecione um alvo.",
					1.5
				)

				return
			end


			State.TrollFreeze =
				not State.TrollFreeze


			if serverAction(
				"FREEZE",
				TrollTarget,
				{
					Enabled =
						State.TrollFreeze
				}
			) then

				button.Text =
					"FREEZE TARGET  •  "
					.. (
						State.TrollFreeze
						and "ON"
						or "OFF"
					)

				SetButtonState(
					button,
					State.TrollFreeze
				)

				return
			end


			local targetHumanoid =
				getTargetHumanoid(
					TrollTarget
				)


			if targetHumanoid then

				targetHumanoid.PlatformStand =
					State.TrollFreeze

			end


			button.Text =
				"FREEZE TARGET  •  "
				.. (
					State.TrollFreeze
					and "ON"
					or "OFF"
				)


			SetButtonState(
				button,
				State.TrollFreeze
			)
		end
	)


--// =========================================================
--// RAGDOLL
--// =========================================================

CreateButton(
	TrollPage,
	"RAGDOLL TARGET",
	function()

		if not TrollTarget
			or not isValidTrollTarget(
				TrollTarget
			)
		then
			return
		end


		if serverAction(
			"RAGDOLL",
			TrollTarget
		) then

			CreateToast(
				"RAGDOLL",
				"Pedido enviado ao servidor.",
				1.5
			)

			return
		end


		local humanoid =
			getTargetHumanoid(
				TrollTarget
			)


		if humanoid then

			pcall(function()

				humanoid.PlatformStand =
					true

				humanoid:ChangeState(
					Enum.HumanoidStateType.Physics
				)
			end)
		end
	end
)


CreateButton(
	TrollPage,
	"UNRAGDOLL TARGET",
	function()

		if not TrollTarget then
			return
		end


		if serverAction(
			"UNRAGDOLL",
			TrollTarget
		) then

			return
		end


		local humanoid =
			getTargetHumanoid(
				TrollTarget
			)


		if humanoid then

			pcall(function()

				humanoid.PlatformStand =
					false

				humanoid:ChangeState(
					Enum.HumanoidStateType.GettingUp
				)
			end)
		end
	end
)


--// =========================================================
--// BRING
--// =========================================================

CreateButton(
	TrollPage,
	"BRING TARGET",
	function()

		if not TrollTarget
			or not isValidTrollTarget(
				TrollTarget
			)
		then

			CreateToast(
				"BRING",
				"Selecione um alvo válido.",
				1.5
			)

			return
		end


		local myRoot =
			getRoot(
				getCharacter()
			)

		local targetRoot =
			getTargetRoot(
				TrollTarget
			)


		if myRoot and targetRoot then

			if serverAction(
				"BRING",
				TrollTarget,
				{
					CFrame =
						myRoot.CFrame
							* CFrame.new(
								0,
								0,
								-4
							)
				}
			) then

				CreateToast(
					"BRING",
					"Pedido enviado ao servidor.",
					1.5
				)

				return
			end


			targetRoot.CFrame =
				myRoot.CFrame
				*
				CFrame.new(
					0,
					0,
					-4
				)


			targetRoot.AssemblyLinearVelocity =
				Vector3.zero
		end
	end
)


--// =========================================================
--// STOP
--// =========================================================

CreateButton(
	TrollPage,
	"STOP TARGET EFFECTS",
	function()

		if TrollTarget then

			if serverAction(
				"STOP",
				TrollTarget
			) then
				return
			end


			local targetRoot =
				getTargetRoot(
					TrollTarget
				)


			if targetRoot then

				pcall(function()

					targetRoot.AssemblyLinearVelocity =
						Vector3.zero

					targetRoot.AssemblyAngularVelocity =
						Vector3.zero
				end)
			end
		end


		State.TrollSpin =
			false

		State.TrollFreeze =
			false


		SpinTargetButton.Text =
			"SPIN TARGET  •  OFF"

		FreezeTargetButton.Text =
			"FREEZE TARGET  •  OFF"


		SetButtonState(
			SpinTargetButton,
			false
		)

		SetButtonState(
			FreezeTargetButton,
			false
		)
	end
)


--// =========================================================
--// TARGET INFO
--// =========================================================

CreateButton(
	TrollPage,
	"TARGET INFO",
	function()

		if not TrollTarget then

			CreateToast(
				"TARGET",
				"Nenhum alvo selecionado.",
				1.5
			)

			return
		end


		local humanoid =
			getTargetHumanoid(
				TrollTarget
			)

		local root =
			getTargetRoot(
				TrollTarget
			)


		if not humanoid or not root then
			return
		end


		local distance =
			getTargetDistance()
			or 0

		local velocity =
			getTargetVelocity()
			or 0

		local mass =
			getTargetMass()
			or 0


		CreateToast(
			"TARGET INFO",
			string.format(
				"HP %.0f | %.1f studs | %.1f u/s | %.1f kg",
				humanoid.Health,
				distance,
				velocity,
				mass
			),
			3
		)
	end
)


--// =========================================================
--// CLEAR
--// =========================================================

CreateButton(
	TrollPage,
	"CLEAR TARGET",
	function()

		TrollTarget = nil

		State.SelectedPlayer = nil
		State.TrollTargetName = ""

		State.TrollFollow = false
		State.TrollSpectate = false
		State.TrollSpin = false
		State.TrollESP = false
		State.TrollFreeze = false


		ClearTrollHighlight()


		local camera =
			getCamera()

		local humanoid =
			getHumanoid(
				getCharacter()
			)


		if camera and humanoid then

			camera.CameraType =
				Enum.CameraType.Custom

			camera.CameraSubject =
				humanoid
		end


		if TargetInfoLabel then
			TargetInfoLabel.Text =
				"TARGET  •  NONE"
		end


		if TargetStatsLabel then
			TargetStatsLabel.Text =
				"DISTANCE • -- | SPEED • -- | HP • --"
		end


		SpectateButton.Text =
			"SPECTATE POV  •  OFF"

		FollowButton.Text =
			"FOLLOW TARGET  •  OFF"

		TargetESPButton.Text =
			"TARGET ESP  •  OFF"

		SpinTargetButton.Text =
			"SPIN TARGET  •  OFF"

		FreezeTargetButton.Text =
			"FREEZE TARGET  •  OFF"


		SetButtonState(
			SpectateButton,
			false
		)

		SetButtonState(
			FollowButton,
			false
		)

		SetButtonState(
			TargetESPButton,
			false
		)

		SetButtonState(
			SpinTargetButton,
			false
		)

		SetButtonState(
			FreezeTargetButton,
			false
		)


		CreateToast(
			"TROLL",
			"Alvo removido.",
			1.5
		)
	end
)


--// =========================================================
--// CUSTOM
--// =========================================================

CreateSection(
	CustomPage,
	"THEMES"
)


local function CreateThemeButton(
	name,
	displayName
)

	local button =
		CreateButton(
			CustomPage,
			displayName,
			function()
				ApplyTheme(name)
			end
		)

	ThemeButtons[name] = button

	return button
end


CreateThemeButton(
	"DEFAULT",
	"DEFAULT"
)

CreateThemeButton(
	"FRUTIGER_AERO",
	"FRUTIGER AERO"
)

CreateThemeButton(
	"GLASS",
	"GLASS"
)

CreateThemeButton(
	"CYBER",
	"CYBER"
)

CreateThemeButton(
	"WINDOWS_XP",
	"WINDOWS XP"
)

CreateThemeButton(
	"OLED",
	"OLED"
)

CreateThemeButton(
	"Y2K",
	"Y2K"
)


CreateSection(
	CustomPage,
	"UI"
)


local ScaleButton =
	CreateButton(
		CustomPage,
		"UI SCALE  •  0.92",
		function(button)

			State.UIScale += 0.08


			if State.UIScale >
				CONFIG.MaxScale
			then
				State.UIScale =
					CONFIG.MinScale
			end


			State.UIScale =
				math.floor(
					State.UIScale * 100
				) / 100


			UIScaleObject.Scale =
				State.UIScale


			button.Text =
				"UI SCALE  •  "
				.. string.format(
					"%.2f",
					State.UIScale
				)
		end
	)


local CompactButton =
	CreateButton(
		CustomPage,
		"COMPACT MODE  •  OFF",
		function(button)

			State.CompactMode =
				not State.CompactMode


			local height =
				State.CompactMode
				and 30
				or 43


			for _, entry in ipairs(Buttons) do

				tween(
					entry.Object,
					TweenInfo.new(0.18),
					{
						Size =
							UDim2.new(
								1,
								-6,
								0,
								height
							)
					}
				)
			end


			button.Text =
				"COMPACT MODE  •  "
				.. (
					State.CompactMode
					and "ON"
					or "OFF"
				)


			SetButtonState(
				button,
				State.CompactMode
			)
		end
	)


local GlowButton =
	CreateButton(
		CustomPage,
		"BACKGROUND GLOW  •  ON",
		function(button)

			State.Glow =
				not State.Glow


			button.Text =
				"BACKGROUND GLOW  •  "
				.. (
					State.Glow
					and "ON"
					or "OFF"
				)


			SetButtonState(
				button,
				State.Glow
			)
		end
	)


CreateButton(
	CustomPage,
	"REPOSITION MENU CENTER",
	function()

		Window.Position =
			UDim2.fromScale(
				0.5,
				0.5
			)
	end
)


--// =========================================================
--// APPLY THEME
--// =========================================================

ApplyTheme =
	function(name)

		local theme =
			THEMES[name]


		if not theme then
			return
		end


		State.Theme = name

		Theme = theme


		Window.BackgroundColor3 =
			theme.Background

		WindowStroke.Color =
			theme.Border


		Title.TextColor3 =
			theme.Text

		Subtitle.TextColor3 =
			theme.Subtext

		Status.TextColor3 =
			theme.Subtext


		CloseButton.BackgroundColor3 =
			theme.Button

		CloseButton.TextColor3 =
			theme.Text


		SearchBox.BackgroundColor3 =
			theme.Button

		SearchBox.TextColor3 =
			theme.Text

		SearchBox.PlaceholderColor3 =
			theme.Subtext


		Sidebar.BackgroundColor3 =
			theme.Panel


		FloatingButton.BackgroundColor3 =
			theme.Panel

		FloatingButton.TextColor3 =
			theme.Text

		FloatingStroke.Color =
			theme.Accent


		for _, entry in ipairs(Buttons) do

			local enabled =
				entry.Object:GetAttribute(
					"Enabled"
				)


			entry.Object.TextColor3 =
				theme.Text

			entry.Object.BackgroundColor3 =
				enabled
				and theme.Accent
				or theme.Button

			entry.Stroke.Color =
				theme.Border
		end


		for _, section in ipairs(Sections) do
			section.TextColor3 =
				theme.Subtext
		end


		for _, page in pairs(Pages) do
			page.ScrollBarImageColor3 =
				theme.Accent
		end


		for navName, nav in pairs(NavButtons) do

			local active =
				navName ==
				State.ActivePage


			nav.BackgroundColor3 =
				active
				and theme.Accent
				or theme.Button

			nav.TextColor3 =
				active
				and theme.Text
				or theme.Subtext
		end


		for themeName, button in pairs(
			ThemeButtons
		) do

			local selected =
				themeName ==
				State.Theme

			button.BackgroundColor3 =
				selected
				and theme.Accent
				or theme.Button
		end


		GlowA.BackgroundColor3 =
			theme.Glow1

		GlowB.BackgroundColor3 =
			theme.Glow2

		GlowC.BackgroundColor3 =
			theme.Glow3


		if TargetInfoLabel then

			TargetInfoLabel.BackgroundColor3 =
				theme.Panel

			TargetInfoLabel.TextColor3 =
				theme.Text
		end


		if TargetStatsLabel then

			TargetStatsLabel.BackgroundColor3 =
				theme.Button

			TargetStatsLabel.TextColor3 =
				theme.Subtext
		end


		if TargetRemoteLabel then

			TargetRemoteLabel.TextColor3 =
				theme.Subtext
		end


		if TrollTarget
			and State.TrollESP
		then

			SetTrollTarget(
				TrollTarget
			)
		end


		if TargetList then
			RefreshTargetList()
		end


		SwitchPage(
			State.ActivePage
		)
	end


--// =========================================================
--// SEARCH
--// =========================================================

SearchBox:GetPropertyChangedSignal(
	"Text"
):Connect(function()

	local query =
		string.lower(
			SearchBox.Text
		)


	local page =
		Pages[
			State.ActivePage
		]


	if not page then
		return
	end


	for _, child in ipairs(page:GetChildren()) do

		if child:IsA("TextButton") then

			local searchText =
				child:GetAttribute(
					"SearchText"
				)


			if searchText then

				child.Visible =
					query == ""
					or string.find(
						searchText,
						query,
						1,
						true
					)
					~= nil
			end
		end
	end
end)


--// =========================================================
--// OPEN / CLOSE
--// =========================================================

local function OpenMenu(animated)

	if State.MenuOpen then
		return
	end

	if State.MenuAnimating then
		return
	end


	State.MenuAnimating = true
	State.MenuOpen = true


	if not animated then

		Window.Size =
			UDim2.fromOffset(
				CONFIG.OpenSize.X,
				CONFIG.OpenSize.Y
			)

		Window.Visible = true

		State.MenuAnimating = false

		return
	end


	Window.Visible = true

	Window.Size =
		UDim2.fromOffset(
			CONFIG.ClosedSize.X,
			CONFIG.ClosedSize.Y
		)


	tween(
		Window,
		TweenInfo.new(
			0.35,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out
		),
		{
			Size =
				UDim2.fromOffset(
					CONFIG.OpenSize.X,
					CONFIG.OpenSize.Y
				)
		}
	)


	task.delay(0.35, function()
		State.MenuAnimating = false
	end)
end


local function CloseMenu(animated)

	if not State.MenuOpen then
		return
	end

	if State.MenuAnimating then
		return
	end


	State.MenuAnimating = true


	if not animated then

		Window.Visible = false

		Window.Size =
			UDim2.fromOffset(
				CONFIG.OpenSize.X,
				CONFIG.OpenSize.Y
			)

		State.MenuOpen = false

		State.MenuAnimating = false

		return
	end


	tween(
		Window,
		TweenInfo.new(
			0.25,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.In
		),
		{
			Size =
				UDim2.fromOffset(
					CONFIG.ClosedSize.X,
					CONFIG.ClosedSize.Y
				)
		}
	)


	task.delay(0.25, function()

		Window.Visible = false

		Window.Size =
			UDim2.fromOffset(
				CONFIG.OpenSize.X,
				CONFIG.OpenSize.Y
			)

		State.MenuOpen = false
		State.MenuAnimating = false
	end)
end


CloseButton.Activated:Connect(function()
	CloseMenu(true)
end)


FloatingButton.Activated:Connect(function()

	if State.MenuOpen then
		CloseMenu(true)
	else
		OpenMenu(true)
	end
end)


--// =========================================================
--// RIGHT SHIFT
--// =========================================================

UserInputService.InputBegan:Connect(
	function(input, processed)

		if processed then
			return
		end

		if UserInputService:GetFocusedTextBox() then
			return
		end

		if input.KeyCode ==
			CONFIG.Hotkey
		then

			if State.MenuOpen then
				CloseMenu(true)
			else
				OpenMenu(true)
			end
		end
	end
)


--// =========================================================
--// OUTSIDE INPUT
--// =========================================================

UserInputService.InputBegan:Connect(
	function(input, processed)

		if processed then
			return
		end

		if not State.MenuOpen then
			return
		end

		if UserInputService:GetFocusedTextBox() then
			return
		end

		if
			input.UserInputType ~=
				Enum.UserInputType.MouseButton1
			and input.UserInputType ~=
				Enum.UserInputType.Touch
		then
			return
		end


		local point =
			Vector2.new(
				input.Position.X,
				input.Position.Y
			)


		local windowPosition =
			Window.AbsolutePosition

		local windowSize =
			Window.AbsoluteSize


		local inside =
			point.X >= windowPosition.X
			and point.X <=
				windowPosition.X
				+ windowSize.X
			and point.Y >=
				windowPosition.Y
			and point.Y <=
				windowPosition.Y
				+ windowSize.Y


		if not inside then
			CloseMenu(true)
		end
	end
)


--// =========================================================
--// INFINITE JUMP
--// =========================================================

UserInputService.JumpRequest:Connect(function()

	if not State.InfiniteJump then
		return
	end


	local humanoid =
		getHumanoid(
			getCharacter()
		)


	if humanoid then

		humanoid:ChangeState(
			Enum.HumanoidStateType.Jumping
		)
	end
end)


--// =========================================================
--// MOBILE FLY CONTROLS
--// =========================================================

local function DestroyFlyMobileControls()

	if FlyMobileControls then

		pcall(function()
			FlyMobileControls:Destroy()
		end)

		FlyMobileControls = nil
		FlyUpButton = nil
		FlyDownButton = nil
	end
end


local function CreateFlyMobileControls()

	DestroyFlyMobileControls()


	FlyMobileControls =
		Instance.new("Frame")

	FlyMobileControls.Name =
		"TBAM_FlyMobileControls"

	FlyMobileControls.Size =
		UDim2.fromScale(
			1,
			1
		)

	FlyMobileControls.BackgroundTransparency =
		1

	FlyMobileControls.ZIndex =
		1800

	FlyMobileControls.Parent =
		gui


	local function makeControl(
		text,
		position
	)

		local button =
			Instance.new(
				"TextButton"
			)

		button.Size =
			UDim2.fromOffset(
				CONFIG.MobileFlyButtonSize,
				CONFIG.MobileFlyButtonSize
			)

		button.Position =
			position

		button.AnchorPoint =
			Vector2.new(
				0.5,
				0.5
			)

		button.BackgroundColor3 =
			Theme.Panel

		button.BackgroundTransparency =
			0.12

		button.BorderSizePixel =
			0

		button.Text =
			text

		button.TextColor3 =
			Theme.Text

		button.TextSize =
			18

		button.Font =
			Enum.Font.GothamBlack

		button.AutoButtonColor =
			false

		button.ZIndex =
			1801

		button.Parent =
			FlyMobileControls


		local corner =
			Instance.new("UICorner")

		corner.CornerRadius =
			UDim.new(
				1,
				0
			)

		corner.Parent =
			button


		local stroke =
			Instance.new("UIStroke")

		stroke.Color =
			Theme.Accent

		stroke.Transparency =
			0.25

		stroke.Parent =
			button


		return button
	end


	FlyUpButton =
		makeControl(
			"▲",
			UDim2.new(
				1,
				-80,
				1,
				-170
			)
		)


	FlyDownButton =
		makeControl(
			"▼",
			UDim2.new(
				1,
				-80,
				1,
				-90
			)
		)


	FlyUpButton.InputBegan:Connect(
		function(input)

			if
				input.UserInputType ==
					Enum.UserInputType.Touch
				or input.UserInputType ==
					Enum.UserInputType.MouseButton1
			then

				State.FlyUpHeld =
					true
			end
		end
	)


	FlyUpButton.InputEnded:Connect(
		function(input)

			if
				input.UserInputType ==
					Enum.UserInputType.Touch
				or input.UserInputType ==
					Enum.UserInputType.MouseButton1
			then

				State.FlyUpHeld =
					false
			end
		end
	)


	FlyDownButton.InputBegan:Connect(
		function(input)

			if
				input.UserInputType ==
					Enum.UserInputType.Touch
				or input.UserInputType ==
					Enum.UserInputType.MouseButton1
			then

				State.FlyDownHeld =
					true
			end
		end
	)


	FlyDownButton.InputEnded:Connect(
		function(input)

			if
				input.UserInputType ==
					Enum.UserInputType.Touch
				or input.UserInputType ==
					Enum.UserInputType.MouseButton1
			then

				State.FlyDownHeld =
					false
			end
		end
	)
end


--// =========================================================
--// FLY LOOP - REAL 3D
--// =========================================================

RunService.RenderStepped:Connect(function()

	if not State.FlyEnabled then
		return
	end

	if not FlyVelocity then
		return
	end


	local character =
		getCharacter()

	local humanoid =
		getHumanoid(character)

	local root =
		getRoot(character)

	local camera =
		getCamera()


	if not character
		or not humanoid
		or not root
		or not camera
	then

		return
	end


	local speed =
		CONFIG.FlySpeeds[
			State.FlyIndex
		]
		or CONFIG.FlySpeeds[1]


	local movement =
		humanoid.MoveDirection


	-- CAMERA FORWARD COMPLETO.
	-- NÃO ZERA O Y.
	local look =
		safeUnit(
			camera.CFrame.LookVector,
			Vector3.new(
				0,
				0,
				-1
			)
		)


	-- RIGHT VETOR DA CÂMERA
	local right =
		safeUnit(
			camera.CFrame.RightVector,
			Vector3.new(
				1,
				0,
				0
			)
		)


	local velocity =
		Vector3.zero


	if movement.Magnitude > 0.001 then

		-- MoveDirection contém o input do player.
		-- Calculamos quanto o jogador está indo para frente
		-- e quanto está indo para a lateral.

		local forwardAmount =
			movement:Dot(
				Vector3.new(
					look.X,
					0,
					look.Z
				).Magnitude > 0.001
					and safeUnit(
						Vector3.new(
							look.X,
							0,
							look.Z
						),
						Vector3.new(
							0,
							0,
							-1
						)
					)
					or Vector3.new(
						0,
						0,
						-1
					)
			)


		local rightAmount =
			movement:Dot(
				safeUnit(
					Vector3.new(
						right.X,
						0,
						right.Z
					),
					Vector3.new(
						1,
						0,
						0
					)
				)
			)


		-- Direção frontal usa PITCH da câmera.
		local forwardDirection =
			look * forwardAmount


		-- Strafe continua lateral.
		local rightDirection =
			Vector3.new(
				right.X,
				0,
				right.Z
			)
			* rightAmount


		velocity =
			forwardDirection
			+ rightDirection


		if velocity.Magnitude > 0.001 then

			velocity =
				velocity.Unit
				* speed
		end
	end


	-- CONTROLE VERTICAL PC
	if UserInputService:IsKeyDown(
		Enum.KeyCode.Space
	) then

		velocity +=
			Vector3.new(
				0,
				speed,
				0
			)

	elseif
		UserInputService:IsKeyDown(
			Enum.KeyCode.LeftShift
		)
		or
		UserInputService:IsKeyDown(
			Enum.KeyCode.RightShift
		)
	then

		velocity +=
			Vector3.new(
				0,
				-speed,
				0
			)
	end


	-- CONTROLE VERTICAL MOBILE
	if State.FlyUpHeld then

		velocity +=
			Vector3.new(
				0,
				speed,
				0
			)
	end


	if State.FlyDownHeld then

		velocity +=
			Vector3.new(
				0,
				-speed,
				0
			)
	end


	-- limita velocidade total
	if velocity.Magnitude > speed then

		velocity =
			velocity.Unit
			* speed
	end


	FlyVelocity.VectorVelocity =
		velocity


	if FlyOrientation then

		-- AGORA O CORPO ACOMPANHA:
		-- • esquerda / direita
		-- • cima / baixo
		-- • direção completa da câmera

		local orientationLook =
			safeUnit(
				Vector3.new(
					look.X,
					look.Y,
					look.Z
				),
				Vector3.new(
					0,
					0,
					-1
				)
			)


		FlyOrientation.CFrame =
			CFrame.lookAt(
				Vector3.zero,
				orientationLook
			)
	end
end)


--// =========================================================
--// NOCLIP LOOP
--// =========================================================

RunService.Stepped:Connect(function()

	if not State.NoclipEnabled then
		return
	end


	local character =
		getCharacter()


	if not character then
		return
	end


	for _, part in ipairs(
		character:GetDescendants()
	) do

		if part:IsA("BasePart") then

			part.CanCollide =
				false
		end
	end
end)


--// =========================================================
--// SPIN LOOP
--// =========================================================

RunService.RenderStepped:Connect(
	function(delta)

		if not State.Spin then
			return
		end


		local root =
			getRoot(
				getCharacter()
			)


		if root then

			root.CFrame =
				root.CFrame
				*
				CFrame.Angles(
					0,
					math.rad(
						State.SpinSpeed
					)
					* delta,
					0
				)
		end
	end
)


--// =========================================================
--// RAINBOW LOOP
--// =========================================================

RunService.RenderStepped:Connect(function()

	if not State.Rainbow then
		return
	end


	local character =
		getCharacter()


	if not character then
		return
	end


	local color =
		Color3.fromHSV(
			(tick() % 5) / 5,
			0.8,
			1
		)


	for _, object in ipairs(
		character:GetDescendants()
	) do

		if
			object:IsA("BasePart")
			and object.Name ~=
				"HumanoidRootPart"
		then

			object.Color =
				color
		end
	end
end)


--// =========================================================
--// FOLLOW TARGET
--// =========================================================

RunService.RenderStepped:Connect(function()

	if not State.TrollFollow then
		return
	end


	if not TrollTarget
		or not isValidTrollTarget(
			TrollTarget
		)
	then

		State.TrollFollow = false

		if FollowButton then

			FollowButton.Text =
				"FOLLOW TARGET  •  OFF"

			SetButtonState(
				FollowButton,
				false
			)
		end

		return
	end


	local myRoot =
		getRoot(
			getCharacter()
		)

	local targetRoot =
		getTargetRoot(
			TrollTarget
		)


	if not myRoot
		or not targetRoot
	then
		return
	end


	local offset =
		targetRoot.CFrame.LookVector
		* -CONFIG.FollowDistance


	local destination =
		targetRoot.Position
		+ offset
		+ Vector3.new(
			0,
			CONFIG.FollowHeight,
			0
		)


	myRoot.CFrame =
		CFrame.lookAt(
			destination,
			targetRoot.Position
		)
end)


--// =========================================================
--// TROLL SPIN LOOP
--// =========================================================

RunService.Heartbeat:Connect(function()

	if not State.TrollSpin then
		return
	end


	if not TrollTarget
		or not isValidTrollTarget(
			TrollTarget
		)
	then
		return
	end


	local targetRoot =
		getTargetRoot(
			TrollTarget
		)


	if targetRoot then

		if not serverAction(
			"SPIN",
			TrollTarget,
			{
				Power =
					CONFIG.SpinPower
			}
		) then

			pcall(function()

				targetRoot.AssemblyAngularVelocity =
					Vector3.new(
						CONFIG.SpinPower,
						CONFIG.SpinPower,
						CONFIG.SpinPower
					)
			end)
		end
	end
end)


--// =========================================================
--// ESP WATCHDOG
--// =========================================================

RunService.Heartbeat:Connect(function()

	if TrollHighlight then

		if
			not TrollTarget
			or not TrollTarget.Parent
			or not State.TrollESP
		then

			ClearTrollHighlight()
		end
	end
end)


--// =========================================================
--// TARGET STATS LOOP
--// =========================================================

task.spawn(function()

	while gui.Parent do

		if
			TrollTarget
			and isValidTrollTarget(
				TrollTarget
			)
		then

			local humanoid =
				getTargetHumanoid(
					TrollTarget
				)


			local distance =
				getTargetDistance()

			local velocity =
				getTargetVelocity()


			if TargetStatsLabel then

				TargetStatsLabel.Text =
					string.format(
						"DIST %.1f | SPD %.1f | HP %.0f",
						distance or 0,
						velocity or 0,
						humanoid
							and humanoid.Health
							or 0
					)
			end

		else

			if TargetStatsLabel then

				TargetStatsLabel.Text =
					"DISTANCE • -- | SPEED • -- | HP • --"
			end
		end


		if TargetRemoteLabel then

			TargetRemoteLabel.Text =
				hasServerFlingBridge()
				and
				"SERVER FLING BRIDGE • READY"
				or
				"SERVER FLING BRIDGE • NOT FOUND"
		end


		task.wait(0.2)
	end
end)


--// =========================================================
--// TARGET AUTO REFRESH
--// =========================================================

task.spawn(function()

	while gui.Parent do

		if State.ActivePage ==
			"TROLL"
		then

			pcall(
				RefreshTargetList
			)
		end


		task.wait(2)
	end
end)


--// =========================================================
--// PERFORMANCE
--// =========================================================

local fpsClock =
	os.clock()

local frameCounter = 0


RunService.RenderStepped:Connect(function()

	frameCounter += 1


	local now =
		os.clock()


	if now - fpsClock >= 0.5 then

		State.FPS =
			math.floor(
				frameCounter
				/
				(
					now
					-
					fpsClock
				)
			)


		frameCounter = 0
		fpsClock = now


		FPSButton.Text =
			"FPS  •  "
			.. tostring(
				State.FPS
			)


		Status.Text =
			"● "
			.. tostring(
				State.FPS
			)
			.. " FPS"
	end
end)


task.spawn(function()

	while gui.Parent do

		local successPing, ping =
			pcall(function()

				local item =
					Stats.Network
					.ServerStatsItem[
						"Data Ping"
					]


				if item then
					return item:GetValue()
				end

				return nil
			end)


		if successPing and ping then

			State.Ping =
				math.floor(ping)


			PingButton.Text =
				"PING  •  "
				.. tostring(
					State.Ping
				)
				.. " ms"
		end


		local successMemory, memory =
			pcall(function()

				return Stats:
					GetTotalMemoryUsageMb()
			end)


		if successMemory and memory then

			State.Memory =
				math.floor(memory)


			MemoryButton.Text =
				"MEMORY  •  "
				.. tostring(
					State.Memory
				)
				.. " MB"
		end


		local character =
			getCharacter()

		local root =
			getRoot(character)

		local humanoid =
			getHumanoid(character)


		if root then

			PositionButton.Text =
				string.format(
					"POSITION  •  %.0f %.0f %.0f",
					root.Position.X,
					root.Position.Y,
					root.Position.Z
				)

			VelocityButton.Text =
				string.format(
					"VELOCITY  •  %.0f",
					root.AssemblyLinearVelocity.Magnitude
				)
		end


		if humanoid then

			HumanoidStateButton.Text =
				"HUMANOID STATE  •  "
				.. humanoid:GetState().Name
		end


		task.wait(1)
	end
end)


--// =========================================================
--// ACTIVE COUNTER
--// =========================================================

local function UpdateActiveCounter()

	local amount = 0


	for key, value in pairs(State) do

		if
			typeof(value) ==
				"boolean"
			and value
		then

			if
				key ~= "MenuOpen"
				and key ~= "MenuAnimating"
			then

				amount += 1
			end
		end
	end


	ActiveCounter.Text =
		"ACTIVE FEATURES  •  "
		.. tostring(amount)
end


task.spawn(function()

	while gui.Parent do

		UpdateActiveCounter()

		task.wait(0.35)
	end
end)


--// =========================================================
--// CHARACTER RESPawn
--// =========================================================

LocalPlayer.CharacterAdded:Connect(function(character)

	CurrentCharacter =
		character


	DestroyFlyMobileControls()


	task.wait(0.5)


	local humanoid =
		getHumanoid(character)


	if humanoid then

		Original.WalkSpeed =
			humanoid.WalkSpeed

		Original.JumpPower =
			humanoid.JumpPower

		Original.JumpHeight =
			humanoid.JumpHeight


		if State.SpeedEnabled then

			humanoid.WalkSpeed =
				CONFIG.SpeedValues[
					State.SpeedIndex
				]
				or Original.WalkSpeed
		end


		if State.JumpEnabled then

			humanoid.UseJumpPower =
				true

			humanoid.JumpPower =
				CONFIG.JumpValues[
					State.JumpIndex
				]
				or Original.JumpPower
		end


		if State.PlatformStand then
			humanoid.PlatformStand =
				true
		end
	end


	local root =
		getRoot(character)


	if State.NoclipEnabled then

		for _, part in ipairs(
			character:GetDescendants()
		) do

			if part:IsA("BasePart") then
				part.CanCollide = false
			end
		end
	end


	if State.Trail and root then

		TrailAttachment0 =
			Instance.new("Attachment")

		TrailAttachment1 =
			Instance.new("Attachment")


		TrailAttachment0.Position =
			Vector3.new(
				0,
				1,
				0
			)

		TrailAttachment1.Position =
			Vector3.new(
				0,
				-1,
				0
			)


		TrailAttachment0.Parent =
			root

		TrailAttachment1.Parent =
			root


		TrailObject =
			Instance.new("Trail")


		TrailObject.Attachment0 =
			TrailAttachment0

		TrailObject.Attachment1 =
			TrailAttachment1

		TrailObject.Lifetime =
			0.7

		TrailObject.MinLength =
			0.1

		TrailObject.Parent =
			root
	end


	if State.Particles and root then

		ParticleObject =
			Instance.new(
				"ParticleEmitter"
			)

		ParticleObject.Rate =
			12

		ParticleObject.Lifetime =
			NumberRange.new(
				0.5,
				1.2
			)

		ParticleObject.Speed =
			NumberRange.new(
				1,
				3
			)

		ParticleObject.SpreadAngle =
			Vector2.new(
				360,
				360
			)

		ParticleObject.Parent =
			root
	end


	if State.BigHead then

		local head =
			character:FindFirstChild(
				"Head"
			)


		if head
			and head:IsA("BasePart")
		then

			Original.HeadSize =
				head.Size

			head.Size =
				Original.HeadSize * 1.7
		end
	end


	if State.FlyEnabled then

		task.wait(0.15)

		if FlyButton then

			State.FlyEnabled = false
			FlyButton.Text =
				"FLY  •  OFF"

			SetButtonState(
				FlyButton,
				false
			)
		end
	end
end)


--// =========================================================
--// PLAYER EVENTS
--// =========================================================

Players.PlayerAdded:Connect(function()

	if State.ActivePage ==
		"TROLL"
	then

		task.delay(
			0.5,
			function()

				pcall(
					RefreshTargetList
				)
			end
		)
	end
end)


Players.PlayerRemoving:Connect(
	function(player)

		if not TrollTarget then
			return
		end


		local targetPlayer =
			Players:GetPlayerFromCharacter(
				TrollTarget
			)


		if targetPlayer ~= player then
			return
		end


		TrollTarget = nil

		State.SelectedPlayer = nil
		State.TrollTargetName = ""

		State.TrollFollow = false
		State.TrollSpectate = false
		State.TrollESP = false
		State.TrollSpin = false
		State.TrollFreeze = false


		ClearTrollHighlight()


		if TargetInfoLabel then
			TargetInfoLabel.Text =
				"TARGET  •  NONE"
		end


		if TargetStatsLabel then
			TargetStatsLabel.Text =
				"DISTANCE • -- | SPEED • -- | HP • --"
		end


		if FollowButton then

			FollowButton.Text =
				"FOLLOW TARGET  •  OFF"

			SetButtonState(
				FollowButton,
				false
			)
		end


		if SpectateButton then

			SpectateButton.Text =
				"SPECTATE POV  •  OFF"

			SetButtonState(
				SpectateButton,
				false
			)
		end


		if TargetESPButton then

			TargetESPButton.Text =
				"TARGET ESP  •  OFF"

			SetButtonState(
				TargetESPButton,
				false
			)
		end


		if SpinTargetButton then

			SpinTargetButton.Text =
				"SPIN TARGET  •  OFF"

			SetButtonState(
				SpinTargetButton,
				false
			)
		end


		if FreezeTargetButton then

			FreezeTargetButton.Text =
				"FREEZE TARGET  •  OFF"

			SetButtonState(
				FreezeTargetButton,
				false
			)
		end


		local camera =
			getCamera()

		local humanoid =
			getHumanoid(
				getCharacter()
			)


		if camera and humanoid then

			camera.CameraType =
				Enum.CameraType.Custom

			camera.CameraSubject =
				humanoid
		end
	end
)


--// =========================================================
--// INITIAL SNAPSHOT
--// =========================================================

CurrentCharacter =
	getCharacter()


do

	local humanoid =
		getHumanoid(
			CurrentCharacter
		)


	if humanoid then

		Original.WalkSpeed =
			humanoid.WalkSpeed

		Original.JumpPower =
			humanoid.JumpPower

		Original.JumpHeight =
			humanoid.JumpHeight
	end


	local camera =
		getCamera()


	if camera then

		Original.CameraFOV =
			camera.FieldOfView
	end


	local head =
		CurrentCharacter
		and CurrentCharacter:FindFirstChild(
			"Head"
		)


	if head
		and head:IsA("BasePart")
	then

		Original.HeadSize =
			head.Size
	end
end


--// =========================================================
--// INITIAL THEME
--// =========================================================

ApplyTheme(
	"DEFAULT"
)


SwitchPage(
	"HOME"
)


task.defer(function()

	pcall(
		RefreshTargetList
	)
end)


--// =========================================================
--// START MENU
--// =========================================================

if CONFIG.StartOpen then

	OpenMenu(false)

else

	Window.Visible =
		false

	State.MenuOpen =
		false
end


FloatingButton.Visible =
	true


--// =========================================================
--// FLOATING BUTTON ANIMATION
--// =========================================================

task.spawn(function()

	while gui.Parent do

		tween(
			FloatingButton,
			TweenInfo.new(
				1.4,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.InOut
			),
			{
				Rotation = 4
			}
		)


		task.wait(1.4)


		tween(
			FloatingButton,
			TweenInfo.new(
				1.4,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.InOut
			),
			{
				Rotation = -4
			}
		)


		task.wait(1.4)
	end
end)


--// =========================================================
--// FLY MOBILE UI STATE
--// =========================================================

task.spawn(function()

	while gui.Parent do

		if State.FlyEnabled then

			if not FlyMobileControls then
				CreateFlyMobileControls()
			end

			if FlyMobileControls then
				FlyMobileControls.Visible = true
			end

		else

			if FlyMobileControls then
				FlyMobileControls.Visible = false
			end

			State.FlyUpHeld = false
			State.FlyDownHeld = false
		end

		task.wait(0.15)
	end
end)


--// =========================================================
--// FINAL TOAST
--// =========================================================

CreateToast(
	"TBAM v2.9.0",
	"AERO ADMIN / TEST PANEL pronto.",
	2.5
)


warn(
	"[TBAM] v2.9.0 LOADED | PlayerGui"
)