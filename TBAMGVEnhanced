--========================================================--
--              TBAMGV - GRAPHICS EDITION
--                V6 - STABLE / EXTREME
--========================================================--
-- LocalScript
-- StarterPlayer > StarterPlayerScripts
--
-- V6 mantém os recursos do V5 e adiciona:
-- • PBR procedural heurístico baseado em Material + textura/nome do objeto
-- • Preservação de SurfaceAppearance/PBR real já existente
-- • Reflexos dinâmicos via EnvironmentSpecularScale + Reflectance
-- • Sombras dinâmicas nativas via GlobalShadows + Realistic
-- • Shadow helper local com SpotLight/Shadows
-- • Processamento PBR em lotes, limitado e com culling
-- • Fila incremental para peças novas
-- • Menos risco de conexões de câmera duplicadas
--
-- NOTA SOBRE PBR:
-- Um LocalScript comum não consegue analisar pixels de uma Texture/Decal
-- nem criar livremente mapas MetalnessMap/RoughnessMap de um
-- SurfaceAppearance publicado. O modo procedural usa heurísticas para
-- estimar refletividade. SurfaceAppearance existente é preservado.
--========================================================--

--========================================================--
-- SERVICES
--========================================================--

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

--========================================================--
-- PLAYER
--========================================================--

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

--========================================================--
-- CONFIG
--========================================================--

local MENU_NAME = "TBAMGV_GraphicsMenu"

local ACCENT = Color3.fromRGB(110,190,255)
local GLASS = Color3.fromRGB(18,22,30)
local GLASS2 = Color3.fromRGB(25,30,40)
local TEXT = Color3.fromRGB(240,245,255)
local SUBTEXT = Color3.fromRGB(160,170,185)
local WARNING = Color3.fromRGB(255,100,100)
local WATER_ACCENT = Color3.fromRGB(80,210,255)

local TWEEN_FAST = TweenInfo.new(0.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
local TWEEN_MED = TweenInfo.new(0.30,Enum.EasingStyle.Quart,Enum.EasingDirection.Out)

--========================================================--
-- V6 PERFORMANCE / PBR CONFIG
--========================================================--

local PBR_MAX_ACTIVE_PARTS = 1400
local PBR_SCAN_BATCH = 90
local PBR_SCAN_YIELD = 0.025
local PBR_MAX_DISTANCE = 360
local V6_UPDATE_INTERVAL = 0.12

local DYNAMIC_SHADOW_HEIGHT = 36
local DYNAMIC_SHADOW_RANGE = 72
local DYNAMIC_SHADOW_ANGLE = 118
local DYNAMIC_SHADOW_BRIGHTNESS = 0.11

local PBR_MAX_REFLECTANCE = 0.92

--========================================================--
-- DESTROY OLD GUI
--========================================================--

local OldGui = PlayerGui:FindFirstChild(MENU_NAME)
if OldGui then
	OldGui:Destroy()
end

--========================================================--
-- REMOVE OLD TBAMGV EFFECTS
--========================================================--

local OLD_EFFECT_NAMES = {
	"TBAMGV_Bloom",
	"TBAMGV_ColorCorrection",
	"TBAMGV_DepthOfField",
	"TBAMGV_SunRays",
	"TBAMGV_Atmosphere"
}

for _,name in ipairs(OLD_EFFECT_NAMES) do
	local LightingObject = Lighting:FindFirstChild(name)
	if LightingObject then
		LightingObject:Destroy()
	end

	local Camera = Workspace.CurrentCamera
	if Camera then
		local CameraObject = Camera:FindFirstChild(name)
		if CameraObject then
			CameraObject:Destroy()
		end
	end
end

--========================================================--
-- GUI
--========================================================--

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = MENU_NAME
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = PlayerGui

--========================================================--
-- UTILITY
--========================================================--

local function Tween(object,properties,info)
	return TweenService:Create(object,info or TWEEN_MED,properties)
end

local function Round(instance,radius)
	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0,radius)
	Corner.Parent = instance
	return Corner
end

local function Stroke(instance,color,transparency,thickness)
	local UIStroke = Instance.new("UIStroke")
	UIStroke.Color = color
	UIStroke.Transparency = transparency or 0
	UIStroke.Thickness = thickness or 1
	UIStroke.Parent = instance
	return UIStroke
end

local function Padding(instance,amount)
	local UIPadding = Instance.new("UIPadding")
	UIPadding.PaddingLeft = UDim.new(0,amount)
	UIPadding.PaddingRight = UDim.new(0,amount)
	UIPadding.PaddingTop = UDim.new(0,amount)
	UIPadding.PaddingBottom = UDim.new(0,amount)
	UIPadding.Parent = instance
	return UIPadding
end

local function CreateText(parent,text,size,font,color)
	local Label = Instance.new("TextLabel")
	Label.BackgroundTransparency = 1
	Label.Text = text
	Label.TextColor3 = color or TEXT
	Label.Font = font or Enum.Font.Gotham
	Label.TextSize = size or 14
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.TextYAlignment = Enum.TextYAlignment.Center
	Label.Parent = parent
	return Label
end

--========================================================--
-- ORIGINAL LIGHTING
--========================================================--

local Original = {
	GlobalShadows = Lighting.GlobalShadows,
	Brightness = Lighting.Brightness,
	ExposureCompensation = Lighting.ExposureCompensation,
	ShadowSoftness = Lighting.ShadowSoftness,
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	ColorShiftTop = Lighting.ColorShift_Top,
	ColorShiftBottom = Lighting.ColorShift_Bottom,
	ClockTime = Lighting.ClockTime,
	EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
	EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
	LightingStyle = nil,
	PrioritizeLightingQuality = nil
}

pcall(function()
	Original.LightingStyle = Lighting.LightingStyle
end)

pcall(function()
	Original.PrioritizeLightingQuality = Lighting.PrioritizeLightingQuality
end)

--========================================================--
-- SKY ORIGINAL STATE
--========================================================--

local OriginalSky = {
	ClockTime = Lighting.ClockTime,
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	ColorShiftTop = Lighting.ColorShift_Top,
	ColorShiftBottom = Lighting.ColorShift_Bottom,
	Brightness = Lighting.Brightness,
	Exposure = Lighting.ExposureCompensation
}

--========================================================--
-- WATER ORIGINAL
--========================================================--

local Terrain = Workspace:FindFirstChildOfClass("Terrain")
local OriginalWater = nil

if Terrain then
	OriginalWater = {
		WaterColor = Terrain.WaterColor,
		WaterReflectance = Terrain.WaterReflectance,
		WaterTransparency = Terrain.WaterTransparency,
		WaterWaveSize = Terrain.WaterWaveSize,
		WaterWaveSpeed = Terrain.WaterWaveSpeed
	}
end

--========================================================--
-- STATE
--========================================================--

local State = {
	Shaders = false,
	Bloom = false,
	ColorCorrection = false,
	DOF = false,
	SunRays = false,
	Atmosphere = false,

	Shadows = Original.GlobalShadows,
	Brightness = Original.Brightness,
	Exposure = Original.ExposureCompensation,
	ShadowSoftness = Original.ShadowSoftness,

	RealisticReflections = false,

	BloomIntensity = 0.25,
	BloomSize = 18,

	Saturation = 0.08,
	Contrast = 0.08,
	ColorBrightness = 0,

	AtmosphereDensity = 0.15,
	AtmosphereHaze = 1,
	AtmosphereGlare = 0,

	DOFFar = 0,
	DOFNear = 0,
	DOFFocus = 50,

	SelectedSky = "Original",
	MirrorWorld = false,
	UltraWater = false,

	-- V6
	ProceduralPBR = false,
	PBRStrength = 1,
	DynamicShadows = false,
	DynamicReflections = false
}

--========================================================--
-- CONTROL REFRESH REGISTRIES
--========================================================--

local ToggleRefreshers = {}
local SliderRefreshers = {}
local RefreshAllControls

--========================================================--
-- TBAMGV CAMERA EFFECTS
--========================================================--

local Bloom = nil
local ColorCorrection = nil
local DepthOfField = nil
local SunRays = nil
local ApplyShaders

local function CreateCameraEffects()
	local Camera = Workspace.CurrentCamera
	if not Camera then
		return
	end

	if Bloom then Bloom:Destroy() end
	if ColorCorrection then ColorCorrection:Destroy() end
	if DepthOfField then DepthOfField:Destroy() end
	if SunRays then SunRays:Destroy() end

	Bloom = Instance.new("BloomEffect")
	Bloom.Name = "TBAMGV_Bloom"
	Bloom.Parent = Camera

	ColorCorrection = Instance.new("ColorCorrectionEffect")
	ColorCorrection.Name = "TBAMGV_ColorCorrection"
	ColorCorrection.Parent = Camera

	DepthOfField = Instance.new("DepthOfFieldEffect")
	DepthOfField.Name = "TBAMGV_DepthOfField"
	DepthOfField.Parent = Camera

	SunRays = Instance.new("SunRaysEffect")
	SunRays.Name = "TBAMGV_SunRays"
	SunRays.Parent = Camera
end

CreateCameraEffects()

--========================================================--
-- ATMOSPHERE
--========================================================--

local Atmosphere = Lighting:FindFirstChild("TBAMGV_Atmosphere")
if Atmosphere then
	Atmosphere:Destroy()
end
Atmosphere = nil

local function CreateAtmosphere()
	if Atmosphere then
		return
	end

	Atmosphere = Instance.new("Atmosphere")
	Atmosphere.Name = "TBAMGV_Atmosphere"
	Atmosphere.Density = 0
	Atmosphere.Haze = 0
	Atmosphere.Glare = 0
	Atmosphere.Parent = Lighting
end

--========================================================--
-- REALISTIC ENVIRONMENT REFLECTIONS
--========================================================--

local function EnableRealisticReflections()
	State.RealisticReflections = true

	pcall(function()
		Lighting.LightingStyle = Enum.LightingStyle.Realistic
	end)

	pcall(function()
		Lighting.EnvironmentDiffuseScale = 1
	end)

	pcall(function()
		Lighting.EnvironmentSpecularScale = 1
	end)

	pcall(function()
		Lighting.PrioritizeLightingQuality = true
	end)

	Lighting.GlobalShadows = true
	State.Shadows = true
end

local function DisableRealisticReflections()
	State.RealisticReflections = false

	pcall(function()
		Lighting.EnvironmentDiffuseScale = Original.EnvironmentDiffuseScale
	end)

	pcall(function()
		Lighting.EnvironmentSpecularScale = Original.EnvironmentSpecularScale
	end)

	pcall(function()
		if Original.LightingStyle ~= nil then
			Lighting.LightingStyle = Original.LightingStyle
		end
	end)

	pcall(function()
		if Original.PrioritizeLightingQuality ~= nil then
			Lighting.PrioritizeLightingQuality = Original.PrioritizeLightingQuality
		end
	end)
end

--========================================================--
-- REFLECTION SYSTEM / MIRROR WORLD
--========================================================--

local OriginalReflectance = {}
local MirrorConnection = nil

local function IsPlayerCharacter(part)
	local Character = Player.Character
	if not Character then
		return false
	end
	return part:IsDescendantOf(Character)
end

local function ApplyMirrorToPart(part)
	if not State.MirrorWorld then
		return
	end

	if not part:IsA("BasePart") then
		return
	end

	if IsPlayerCharacter(part) then
		return
	end

	if part.Transparency >= 1 then
		return
	end

	if OriginalReflectance[part] == nil then
		OriginalReflectance[part] = part.Reflectance
	end

	part.Reflectance = 0.85
end

local function EnableMirrorWorld()
	if State.MirrorWorld then
		return
	end

	State.MirrorWorld = true
	EnableRealisticReflections()

	for _,object in ipairs(Workspace:GetDescendants()) do
		ApplyMirrorToPart(object)
	end

	MirrorConnection = Workspace.DescendantAdded:Connect(function(object)
		if not State.MirrorWorld then
			return
		end

		task.defer(function()
			ApplyMirrorToPart(object)
		end)
	end)
end

local function DisableMirrorWorld()
	State.MirrorWorld = false

	if MirrorConnection then
		MirrorConnection:Disconnect()
		MirrorConnection = nil
	end

	for part,value in pairs(OriginalReflectance) do
		if part and part.Parent and part:IsA("BasePart") then
			pcall(function()
				part.Reflectance = value
			end)
		end
	end

	table.clear(OriginalReflectance)
end

--========================================================--
-- WATER
--========================================================--

local function EnableUltraWater()
	Terrain = Workspace:FindFirstChildOfClass("Terrain")
	if not Terrain then
		return
	end

	if not OriginalWater then
		OriginalWater = {
			WaterColor = Terrain.WaterColor,
			WaterReflectance = Terrain.WaterReflectance,
			WaterTransparency = Terrain.WaterTransparency,
			WaterWaveSize = Terrain.WaterWaveSize,
			WaterWaveSpeed = Terrain.WaterWaveSpeed
		}
	end

	State.UltraWater = true
	EnableRealisticReflections()

	Terrain.WaterColor = Color3.fromRGB(65,170,205)
	Terrain.WaterReflectance = 1
	Terrain.WaterTransparency = 0.18
	Terrain.WaterWaveSize = 1
	Terrain.WaterWaveSpeed = 70
end

local function DisableUltraWater()
	State.UltraWater = false

	if not Terrain or not OriginalWater then
		return
	end

	Terrain.WaterColor = OriginalWater.WaterColor
	Terrain.WaterReflectance = OriginalWater.WaterReflectance
	Terrain.WaterTransparency = OriginalWater.WaterTransparency
	Terrain.WaterWaveSize = OriginalWater.WaterWaveSize
	Terrain.WaterWaveSpeed = OriginalWater.WaterWaveSpeed
end

--========================================================--
-- V6 - PROCEDURAL PBR
--========================================================--

local OriginalProceduralPBR = {}

local PBRQueue = {}
local PBRQueueHead = 1
local PBRQueueTail = 0
local PBRQueued = {}
local PBRRegistry = {}

local PBRActiveParts = 0
local PBRGeneration = 0
local PBRScanRunning = false
local PBRDescendantConnection = nil

local REFLECTIVE_KEYWORDS = {
	"metal","metallic","chrome","mirror","mirrored",
	"steel","iron","aluminum","aluminium","silver",
	"gold","copper","brass","tin","foil","diamondplate",
	"diamond_plate","polished","gloss","glossy","wet",
	"ceramic","porcelain","marble","granite","glass","crystal",
	"ice","frozen"
}

local MATTE_KEYWORDS = {
	"matte","rough","fabric","cloth","carpet","felt","rubber",
	"mud","dirt","sand","soil","grass","leaf","leaves","foliage",
	"snow","concrete","asphalt","stone","rock","paper","cardboard"
}

local MIRROR_KEYWORDS = {
	"mirror","mirrored","chrome","polished","reflection","reflective"
}

local function StringHasAny(text,keywords)
	text = string.lower(text or "")

	for _,keyword in ipairs(keywords) do
		if string.find(text,keyword,1,true) then
			return true
		end
	end

	return false
end

local function IsIgnoredByV6(part)
	if not part or not part:IsA("BasePart") then
		return true
	end

	if part.Transparency >= 1 then
		return true
	end

	if IsPlayerCharacter(part) then
		return true
	end

	if part:GetAttribute("TBAMGVIgnorePBR") == true then
		return true
	end

	if part.Name == "TBAMGV_DynamicShadowRig" then
		return true
	end

	local parent = part.Parent
	if parent and parent:GetAttribute("TBAMGVIgnorePBR") == true then
		return true
	end

	return false
end

local function GetTextureHints(part)
	local names = {string.lower(part.Name or "")}
	local hasTextureObject = false
	local hasSurfaceAppearance = part:FindFirstChildOfClass("SurfaceAppearance") ~= nil

	for _,child in ipairs(part:GetChildren()) do
		if child:IsA("Texture") or child:IsA("Decal") then
			hasTextureObject = true
			table.insert(names,string.lower(child.Name or ""))

			-- ContentId vazio também é ignorado.
			pcall(function()
				if child:IsA("Texture") and child.Texture and child.Texture ~= "" then
					table.insert(names,string.lower(child.Texture))
				elseif child:IsA("Decal") and child.Texture and child.Texture ~= "" then
					table.insert(names,string.lower(child.Texture))
				end
			end)
		end
	end

	return table.concat(names," "),hasTextureObject,hasSurfaceAppearance
end

local function GetMaterialProfile(part)
	local material = part.Material
	local reflectance = 0.05

	if material == Enum.Material.Metal then
		reflectance = 0.72
	elseif material == Enum.Material.CorrodedMetal then
		reflectance = 0.40
	elseif material == Enum.Material.DiamondPlate then
		reflectance = 0.52
	elseif material == Enum.Material.Foil then
		reflectance = 0.78
	elseif material == Enum.Material.Glass then
		reflectance = 0.70
	elseif material == Enum.Material.Ice then
		reflectance = 0.58
	elseif material == Enum.Material.Marble then
		reflectance = 0.28
	elseif material == Enum.Material.Granite then
		reflectance = 0.17
	elseif material == Enum.Material.SmoothPlastic then
		reflectance = 0.20
	elseif material == Enum.Material.Plastic then
		reflectance = 0.11
	elseif material == Enum.Material.Brick then
		reflectance = 0.035
	elseif material == Enum.Material.Concrete then
		reflectance = 0.025
	elseif material == Enum.Material.Asphalt then
		reflectance = 0.035
	elseif material == Enum.Material.Slate then
		reflectance = 0.045
	elseif material == Enum.Material.Sand then
		reflectance = 0.012
	elseif material == Enum.Material.Grass then
		reflectance = 0.018
	elseif material == Enum.Material.LeafyGrass then
		reflectance = 0.018
	elseif material == Enum.Material.Snow then
		reflectance = 0.025
	elseif material == Enum.Material.Mud then
		reflectance = 0.020
	elseif material == Enum.Material.Fabric then
		reflectance = 0.008
	elseif material == Enum.Material.Wood then
		reflectance = 0.055
	elseif material == Enum.Material.WoodPlanks then
		reflectance = 0.060
	elseif material == Enum.Material.Rock then
		reflectance = 0.040
	elseif material == Enum.Material.Cobblestone then
		reflectance = 0.035
	elseif material == Enum.Material.Neon then
		reflectance = 0.035
	end

	local hints,hasTextureObject,hasSurfaceAppearance = GetTextureHints(part)

	if hasSurfaceAppearance then
		return nil,hasTextureObject,true
	end

	if StringHasAny(hints,MIRROR_KEYWORDS) then
		reflectance = 0.86
	elseif StringHasAny(hints,REFLECTIVE_KEYWORDS) then
		reflectance = math.max(reflectance,0.62)
	elseif StringHasAny(hints,MATTE_KEYWORDS) then
		reflectance = math.min(reflectance,0.035)
	elseif hasTextureObject then
		reflectance = math.max(reflectance,0.06)
	end

	local color = part.Color
	local luminance =
		0.2126 * color.R +
		0.7152 * color.G +
		0.0722 * color.B

	if luminance < 0.08 then
		reflectance *= 0.90
	elseif luminance > 0.90 and reflectance > 0.05 then
		reflectance *= 1.04
	end

	reflectance = math.clamp(
		reflectance * State.PBRStrength,
		0,
		PBR_MAX_REFLECTANCE
	)

	return reflectance,hasTextureObject,false
end

local function GetPBROriginalValue(part)
	if OriginalProceduralPBR[part] == nil then
		OriginalProceduralPBR[part] = {
			Reflectance = part.Reflectance
		}
	end

	return OriginalProceduralPBR[part]
end

local function RestorePBRPart(part)
	local original = OriginalProceduralPBR[part]
	if not original then
		return
	end

	if part and part.Parent and part:IsA("BasePart") then
		pcall(function()
			part.Reflectance = original.Reflectance
		end)
	end
end

local function ApplyProceduralPBRToPart(part)
	if not State.ProceduralPBR then
		return false
	end

	if IsIgnoredByV6(part) then
		return false
	end

	if State.MirrorWorld then
		return false
	end

	local reflectance,_,hasSurfaceAppearance = GetMaterialProfile(part)

	if hasSurfaceAppearance or reflectance == nil then
		return false
	end

	local camera = Workspace.CurrentCamera
	local origin = camera and camera.CFrame.Position

	if not origin then
		local character = Player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		origin = root and root.Position
	end

	if origin then
		local delta = part.Position - origin
		if delta:Dot(delta) > PBR_MAX_DISTANCE * PBR_MAX_DISTANCE then
			return false
		end
	end

	if not OriginalProceduralPBR[part] then
		GetPBROriginalValue(part)
	end

	part.Reflectance = reflectance
	PBRRegistry[part] = true

	return true
end

local function QueuePBRPart(part)
	if not State.ProceduralPBR then
		return
	end

	if IsIgnoredByV6(part) then
		return
	end

	if PBRQueued[part] then
		return
	end

	if PBRActiveParts >= PBR_MAX_ACTIVE_PARTS then
		return
	end

	PBRQueueTail += 1
	PBRQueue[PBRQueueTail] = part
	PBRQueued[part] = true
end

local function ClearPBRQueue()
	table.clear(PBRQueue)
	table.clear(PBRQueued)
	PBRQueueHead = 1
	PBRQueueTail = 0
end

local function RestoreAllPBR()
	PBRGeneration += 1
	PBRScanRunning = false
	ClearPBRQueue()

	for part in pairs(OriginalProceduralPBR) do
		RestorePBRPart(part)
	end

	table.clear(OriginalProceduralPBR)
	table.clear(PBRRegistry)
	PBRActiveParts = 0
end

local function StartPBRScan()
	if PBRScanRunning then
		return
	end

	PBRScanRunning = true
	PBRGeneration += 1

	local generation = PBRGeneration
	ClearPBRQueue()

	local descendants = Workspace:GetDescendants()

	task.spawn(function()
		for _,object in ipairs(descendants) do
			if generation ~= PBRGeneration or not State.ProceduralPBR then
				break
			end

			if object:IsA("BasePart") then
				QueuePBRPart(object)
			end
		end

		while
			generation == PBRGeneration
			and State.ProceduralPBR
			and PBRQueueHead <= PBRQueueTail
			and PBRActiveParts < PBR_MAX_ACTIVE_PARTS
		do
			local processed = 0

			while
				processed < PBR_SCAN_BATCH
				and PBRQueueHead <= PBRQueueTail
				and PBRActiveParts < PBR_MAX_ACTIVE_PARTS
			do
				local part = PBRQueue[PBRQueueHead]
				PBRQueue[PBRQueueHead] = nil
				PBRQueueHead += 1
				PBRQueued[part] = nil

				if part and part.Parent then
					if ApplyProceduralPBRToPart(part) then
						PBRActiveParts += 1
					end
				end

				processed += 1
			end

			task.wait(PBR_SCAN_YIELD)
		end

		if PBRActiveParts >= PBR_MAX_ACTIVE_PARTS then
			ClearPBRQueue()
		end

		PBRScanRunning = false
	end)
end

local function EnableProceduralPBR()
	if State.ProceduralPBR then
		return
	end

	State.ProceduralPBR = true
	StartPBRScan()
end

local function DisableProceduralPBR()
	State.ProceduralPBR = false
	RestoreAllPBR()
end

--========================================================--
-- V6 - DYNAMIC SHADOWS
--========================================================--

local DynamicShadowRig = nil
local DynamicShadowLight = nil
local DynamicShadowOwnsGlobalShadows = false

local function DestroyDynamicShadowRig()
	DynamicShadowLight = nil

	if DynamicShadowRig then
		pcall(function()
			DynamicShadowRig:Destroy()
		end)
		DynamicShadowRig = nil
	end
end

local function CreateDynamicShadowRig()
	if DynamicShadowRig and DynamicShadowRig.Parent then
		return
	end

	local character = Player.Character
	if not character then
		return
	end

	DynamicShadowRig = Instance.new("Part")
	DynamicShadowRig.Name = "TBAMGV_DynamicShadowRig"
	DynamicShadowRig.Size = Vector3.new(1,1,1)
	DynamicShadowRig.Anchored = true
	DynamicShadowRig.CanCollide = false
	DynamicShadowRig.CanTouch = false
	DynamicShadowRig.CanQuery = false
	DynamicShadowRig.CastShadow = false
	DynamicShadowRig.Transparency = 1
	DynamicShadowRig.Locked = true
	DynamicShadowRig:SetAttribute("TBAMGVIgnorePBR",true)
	DynamicShadowRig.Parent = Workspace

	DynamicShadowLight = Instance.new("SpotLight")
	DynamicShadowLight.Name = "TBAMGV_DynamicShadowLight"
	DynamicShadowLight.Angle = DYNAMIC_SHADOW_ANGLE
	DynamicShadowLight.Brightness = DYNAMIC_SHADOW_BRIGHTNESS
	DynamicShadowLight.Range = DYNAMIC_SHADOW_RANGE
	DynamicShadowLight.Color = Color3.new(1,1,1)
	DynamicShadowLight.Face = Enum.NormalId.Bottom
	DynamicShadowLight.Shadows = true
	DynamicShadowLight.Parent = DynamicShadowRig
end

local function UpdateDynamicShadowRig()
	if not State.DynamicShadows then
		return
	end

	if not DynamicShadowRig or not DynamicShadowRig.Parent then
		CreateDynamicShadowRig()
	end

	if not DynamicShadowRig or not DynamicShadowLight then
		return
	end

	local character = Player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	DynamicShadowRig.CFrame =
		CFrame.new(root.Position + Vector3.new(0,DYNAMIC_SHADOW_HEIGHT,0))

	pcall(function()
		DynamicShadowLight.Enabled = true
	end)
end

local function EnableDynamicShadows()
	if State.DynamicShadows then
		return
	end

	State.DynamicShadows = true

	if not Lighting.GlobalShadows then
		DynamicShadowOwnsGlobalShadows = true
	end

	State.Shadows = true
	Lighting.GlobalShadows = true

	pcall(function()
		Lighting.LightingStyle = Enum.LightingStyle.Realistic
	end)

	pcall(function()
		Lighting.PrioritizeLightingQuality = true
	end)

	CreateDynamicShadowRig()
	UpdateDynamicShadowRig()
end

local function DisableDynamicShadows()
	State.DynamicShadows = false
	DestroyDynamicShadowRig()

	if DynamicShadowOwnsGlobalShadows then
		DynamicShadowOwnsGlobalShadows = false

		if
			not State.RealisticReflections
			and not State.MirrorWorld
			and not State.UltraWater
		then
			Lighting.GlobalShadows = Original.GlobalShadows
			State.Shadows = Original.GlobalShadows
		end
	end
end

--========================================================--
-- V6 - DYNAMIC REFLECTIONS
--========================================================--

local DynamicReflectionOwnsRealistic = false

local function EnableDynamicReflections()
	if State.DynamicReflections then
		return
	end

	State.DynamicReflections = true
	DynamicReflectionOwnsRealistic = not State.RealisticReflections

	EnableRealisticReflections()
end

local function DisableDynamicReflections()
	State.DynamicReflections = false

	if not DynamicReflectionOwnsRealistic then
		return
	end

	DynamicReflectionOwnsRealistic = false

	if State.MirrorWorld or State.UltraWater or State.DynamicShadows then
		return
	end

	DisableRealisticReflections()

	if not State.DynamicShadows then
		Lighting.GlobalShadows = Original.GlobalShadows
		State.Shadows = Original.GlobalShadows
	end
end

--========================================================--
-- V6 - EVENTS / QUEUE
--========================================================--

PBRDescendantConnection = Workspace.DescendantAdded:Connect(function(object)
	if State.ProceduralPBR and object:IsA("BasePart") then
		QueuePBRPart(object)
	end
end)

local V6RuntimeAccumulator = 0

local V6RuntimeConnection = RunService.Heartbeat:Connect(function(deltaTime)
	V6RuntimeAccumulator += deltaTime

	if V6RuntimeAccumulator < V6_UPDATE_INTERVAL then
		return
	end

	V6RuntimeAccumulator = 0

	if State.DynamicShadows then
		UpdateDynamicShadowRig()
	end

	if
		State.ProceduralPBR
		and not PBRScanRunning
		and PBRActiveParts < PBR_MAX_ACTIVE_PARTS
		and PBRQueueHead <= PBRQueueTail
	then
		StartPBRScan()
	end
end)

--========================================================--
-- SHADERS
--========================================================--

ApplyShaders = function()
	if not Bloom then
		CreateCameraEffects()
	end

	if not State.Shaders then
		Bloom.Enabled = false
		ColorCorrection.Enabled = false
		DepthOfField.Enabled = false
		SunRays.Enabled = false

		if Atmosphere then
			Atmosphere:Destroy()
			Atmosphere = nil
		end

		return
	end

	Bloom.Enabled = State.Bloom
	Bloom.Intensity = State.BloomIntensity
	Bloom.Size = State.BloomSize
	Bloom.Threshold = 0.85

	ColorCorrection.Enabled = State.ColorCorrection
	ColorCorrection.Saturation = State.Saturation
	ColorCorrection.Contrast = State.Contrast
	ColorCorrection.Brightness = State.ColorBrightness
	ColorCorrection.TintColor = Color3.new(1,1,1)

	DepthOfField.Enabled = State.DOF
	DepthOfField.FarIntensity = State.DOFFar
	DepthOfField.NearIntensity = State.DOFNear
	DepthOfField.FocusDistance = State.DOFFocus
	DepthOfField.InFocusRadius = 40

	SunRays.Enabled = State.SunRays
	SunRays.Intensity = 0.12
	SunRays.Spread = 0.8

	if State.Atmosphere then
		CreateAtmosphere()
		Atmosphere.Density = State.AtmosphereDensity
		Atmosphere.Haze = State.AtmosphereHaze
		Atmosphere.Glare = State.AtmosphereGlare
	elseif Atmosphere then
		Atmosphere:Destroy()
		Atmosphere = nil
	end
end

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	task.wait()
	CreateCameraEffects()
	ApplyShaders()
end)

--========================================================--
-- LIGHTING
--========================================================--

local function ApplyLighting()
	Lighting.GlobalShadows = State.Shadows
	Lighting.Brightness = State.Brightness
	Lighting.ExposureCompensation = State.Exposure
	Lighting.ShadowSoftness = State.ShadowSoftness

	if State.RealisticReflections then
		pcall(function()
			Lighting.LightingStyle = Enum.LightingStyle.Realistic
		end)

		pcall(function()
			Lighting.EnvironmentDiffuseScale = 1
		end)

		pcall(function()
			Lighting.EnvironmentSpecularScale = 1
		end)

		pcall(function()
			Lighting.PrioritizeLightingQuality = true
		end)
	else
		pcall(function()
			Lighting.EnvironmentDiffuseScale = Original.EnvironmentDiffuseScale
		end)

		pcall(function()
			Lighting.EnvironmentSpecularScale = Original.EnvironmentSpecularScale
		end)

		pcall(function()
			if Original.LightingStyle ~= nil then
				Lighting.LightingStyle = Original.LightingStyle
			end
		end)

		pcall(function()
			if Original.PrioritizeLightingQuality ~= nil then
				Lighting.PrioritizeLightingQuality = Original.PrioritizeLightingQuality
			end
		end)
	end
end

local function ApplyState()
	ApplyLighting()
	ApplyShaders()
end

--========================================================--
-- PRESETS
--========================================================--

local function ApplyPreset(name)
	State.Shaders = true

	if name == "LOW" then
		State.Bloom = false
		State.ColorCorrection = true
		State.DOF = false
		State.SunRays = false
		State.Atmosphere = false
		State.RealisticReflections = false
		State.Shadows = false
		State.Brightness = 2
		State.Exposure = 0
		State.ShadowSoftness = 1
		State.BloomIntensity = 0
		State.BloomSize = 0
		State.Saturation = 0.05
		State.Contrast = 0.02
		State.ColorBrightness = 0
		State.AtmosphereDensity = 0
		State.AtmosphereHaze = 0
		State.AtmosphereGlare = 0
		State.DOFFar = 0
		State.DOFNear = 0
		State.DOFFocus = 50

	elseif name == "MEDIUM" then
		State.Bloom = true
		State.ColorCorrection = true
		State.DOF = false
		State.SunRays = true
		State.Atmosphere = true
		State.RealisticReflections = true
		State.Shadows = true
		State.Brightness = 2
		State.Exposure = 0
		State.ShadowSoftness = 0.35
		State.BloomIntensity = 0.25
		State.BloomSize = 18
		State.Saturation = 0.08
		State.Contrast = 0.08
		State.ColorBrightness = 0
		State.AtmosphereDensity = 0.15
		State.AtmosphereHaze = 1
		State.AtmosphereGlare = 0
		State.DOFFar = 0
		State.DOFNear = 0
		State.DOFFocus = 50

	elseif name == "HIGH" then
		State.Bloom = true
		State.ColorCorrection = true
		State.DOF = true
		State.SunRays = true
		State.Atmosphere = true
		State.RealisticReflections = true
		State.Shadows = true
		State.Brightness = 2
		State.Exposure = 0.1
		State.ShadowSoftness = 0.2
		State.BloomIntensity = 0.4
		State.BloomSize = 24
		State.Saturation = 0.12
		State.Contrast = 0.12
		State.ColorBrightness = 0
		State.AtmosphereDensity = 0.18
		State.AtmosphereHaze = 1.5
		State.AtmosphereGlare = 0.05
		State.DOFFar = 0.12
		State.DOFNear = 0.08
		State.DOFFocus = 55

	elseif name == "ULTRA" then
		State.Bloom = true
		State.ColorCorrection = true
		State.DOF = true
		State.SunRays = true
		State.Atmosphere = true
		State.RealisticReflections = true
		State.Shadows = true
		State.Brightness = 2
		State.Exposure = 0.2
		State.ShadowSoftness = 0.08
		State.BloomIntensity = 0.65
		State.BloomSize = 32
		State.Saturation = 0.18
		State.Contrast = 0.16
		State.ColorBrightness = 0
		State.AtmosphereDensity = 0.22
		State.AtmosphereHaze = 2
		State.AtmosphereGlare = 0.15
		State.DOFFar = 0.20
		State.DOFNear = 0.12
		State.DOFFocus = 60
	end

	ApplyState()
end

--========================================================--
-- SKY PRESETS
--========================================================--

local function ApplySkyPreset(name)
	State.SelectedSky = name

	if name == "Original" then
		Lighting.ClockTime = OriginalSky.ClockTime
		Lighting.Ambient = OriginalSky.Ambient
		Lighting.OutdoorAmbient = OriginalSky.OutdoorAmbient
		Lighting.ColorShift_Top = OriginalSky.ColorShiftTop
		Lighting.ColorShift_Bottom = OriginalSky.ColorShiftBottom
		Lighting.Brightness = OriginalSky.Brightness
		Lighting.ExposureCompensation = OriginalSky.Exposure

	elseif name == "Dawn" then
		Lighting.ClockTime = 6.2
		Lighting.Ambient = Color3.fromRGB(110,100,115)
		Lighting.OutdoorAmbient = Color3.fromRGB(145,125,110)
		Lighting.ColorShift_Top = Color3.fromRGB(255,175,120)
		Lighting.ColorShift_Bottom = Color3.fromRGB(130,90,120)
		Lighting.Brightness = 2
		Lighting.ExposureCompensation = 0

	elseif name == "Sunset" then
		Lighting.ClockTime = 17.8
		Lighting.Ambient = Color3.fromRGB(120,80,100)
		Lighting.OutdoorAmbient = Color3.fromRGB(180,105,70)
		Lighting.ColorShift_Top = Color3.fromRGB(255,120,70)
		Lighting.ColorShift_Bottom = Color3.fromRGB(110,65,130)
		Lighting.Brightness = 2
		Lighting.ExposureCompensation = 0.1

	elseif name == "Night" then
		Lighting.ClockTime = 0
		Lighting.Ambient = Color3.fromRGB(20,25,55)
		Lighting.OutdoorAmbient = Color3.fromRGB(35,40,75)
		Lighting.ColorShift_Top = Color3.fromRGB(30,40,100)
		Lighting.ColorShift_Bottom = Color3.fromRGB(10,15,45)
		Lighting.Brightness = 1.2
		Lighting.ExposureCompensation = -0.25

	elseif name == "Day" then
		Lighting.ClockTime = 12
		Lighting.Ambient = Color3.fromRGB(130,130,130)
		Lighting.OutdoorAmbient = Color3.fromRGB(160,160,160)
		Lighting.ColorShift_Top = Color3.fromRGB(210,230,255)
		Lighting.ColorShift_Bottom = Color3.fromRGB(255,255,255)
		Lighting.Brightness = 2
		Lighting.ExposureCompensation = 0
	end

	State.Brightness = Lighting.Brightness
	State.Exposure = Lighting.ExposureCompensation

	if RefreshAllControls then
		RefreshAllControls()
	end
end

--========================================================--
-- SAFE RESET
--========================================================--

local function ResetOriginal()
	State.Shaders = false
	State.Bloom = false
	State.ColorCorrection = false
	State.DOF = false
	State.SunRays = false
	State.Atmosphere = false

	if Bloom then Bloom.Enabled = false end
	if ColorCorrection then ColorCorrection.Enabled = false end
	if DepthOfField then DepthOfField.Enabled = false end
	if SunRays then SunRays.Enabled = false end

	if Atmosphere then
		Atmosphere:Destroy()
		Atmosphere = nil
	end

	if State.MirrorWorld then
		DisableMirrorWorld()
	else
		for part,value in pairs(OriginalReflectance) do
			if part and part.Parent and part:IsA("BasePart") then
				pcall(function()
					part.Reflectance = value
				end)
			end
		end
		table.clear(OriginalReflectance)
	end

	DisableProceduralPBR()
	DisableDynamicShadows()
	State.DynamicReflections = false
	DynamicReflectionOwnsRealistic = false

	if State.RealisticReflections then
		DisableRealisticReflections()
	end

	if State.UltraWater then
		DisableUltraWater()
	end

	Lighting.GlobalShadows = Original.GlobalShadows
	Lighting.Brightness = Original.Brightness
	Lighting.ExposureCompensation = Original.ExposureCompensation
	Lighting.ShadowSoftness = Original.ShadowSoftness
	Lighting.Ambient = Original.Ambient
	Lighting.OutdoorAmbient = Original.OutdoorAmbient
	Lighting.ColorShift_Top = Original.ColorShiftTop
	Lighting.ColorShift_Bottom = Original.ColorShiftBottom
	Lighting.ClockTime = Original.ClockTime

	pcall(function()
		Lighting.EnvironmentDiffuseScale = Original.EnvironmentDiffuseScale
	end)

	pcall(function()
		Lighting.EnvironmentSpecularScale = Original.EnvironmentSpecularScale
	end)

	pcall(function()
		if Original.LightingStyle ~= nil then
			Lighting.LightingStyle = Original.LightingStyle
		end
	end)

	pcall(function()
		if Original.PrioritizeLightingQuality ~= nil then
			Lighting.PrioritizeLightingQuality = Original.PrioritizeLightingQuality
		end
	end)

	State.Shadows = Original.GlobalShadows
	State.Brightness = Original.Brightness
	State.Exposure = Original.ExposureCompensation
	State.ShadowSoftness = Original.ShadowSoftness
	State.RealisticReflections = false
	State.SelectedSky = "Original"
	State.UltraWater = false
	State.MirrorWorld = false
	State.ProceduralPBR = false
	State.DynamicShadows = false
	State.DynamicReflections = false

	if RefreshAllControls then
		RefreshAllControls()
	end
end

--========================================================--
-- BACKDROP
--========================================================--

local Backdrop = Instance.new("Frame")
Backdrop.Name = "Backdrop"
Backdrop.Size = UDim2.fromScale(1,1)
Backdrop.BackgroundColor3 = Color3.fromRGB(0,0,0)
Backdrop.BackgroundTransparency = 0.45
Backdrop.BorderSizePixel = 0
Backdrop.Visible = false
Backdrop.Parent = ScreenGui

--========================================================--
-- OUTSIDE CLOSE
--========================================================--

local OutsideButton = Instance.new("TextButton")
OutsideButton.Name = "OutsideClose"
OutsideButton.Text = ""
OutsideButton.BackgroundTransparency = 1
OutsideButton.BorderSizePixel = 0
OutsideButton.Size = UDim2.fromScale(1,1)
OutsideButton.ZIndex = 1
OutsideButton.Visible = false
OutsideButton.Parent = ScreenGui

--========================================================--
-- MAIN WINDOW
--========================================================--

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.AnchorPoint = Vector2.new(0.5,0.5)
Main.Position = UDim2.fromScale(0.5,0.5)
Main.Size = UDim2.new(0.82,0,0.78,0)
Main.BackgroundColor3 = GLASS
Main.BackgroundTransparency = 0.16
Main.BorderSizePixel = 0
Main.Visible = false
Main.ZIndex = 5
Main.Parent = ScreenGui

Round(Main,18)
Stroke(Main,Color3.fromRGB(255,255,255),0.86,1)

local MainGradient = Instance.new("UIGradient")
MainGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0,Color3.fromRGB(30,38,52)),
	ColorSequenceKeypoint.new(1,Color3.fromRGB(12,16,23))
})
MainGradient.Rotation = 135
MainGradient.Parent = Main

--========================================================--
-- HEADER
--========================================================--

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1,0,0,66)
Header.BackgroundTransparency = 1
Header.ZIndex = 6
Header.Parent = Main

local Title = CreateText(Header,"TBAMGV",24,Enum.Font.GothamBold,TEXT)
Title.Position = UDim2.new(0,22,0,7)
Title.Size = UDim2.new(0.5,0,0,28)

local Subtitle = CreateText(Header,"GRAPHICS EDITION • EXTREME",11,Enum.Font.GothamMedium,SUBTEXT)
Subtitle.Position = UDim2.new(0,23,0,35)
Subtitle.Size = UDim2.new(0.7,0,0,18)

--========================================================--
-- CLOSE
--========================================================--

local Close = Instance.new("TextButton")
Close.Name = "Close"
Close.AnchorPoint = Vector2.new(1,0.5)
Close.Position = UDim2.new(1,-18,0.5,0)
Close.Size = UDim2.fromOffset(38,38)
Close.BackgroundColor3 = Color3.fromRGB(255,255,255)
Close.BackgroundTransparency = 0.92
Close.Text = "×"
Close.TextColor3 = TEXT
Close.TextSize = 25
Close.Font = Enum.Font.GothamMedium
Close.BorderSizePixel = 0
Close.AutoButtonColor = false
Close.ZIndex = 10
Close.Parent = Header
Round(Close,12)

--========================================================--
-- SCROLL
--========================================================--

local Scroll = Instance.new("ScrollingFrame")
Scroll.Name = "Scroll"
Scroll.Position = UDim2.new(0,12,0,70)
Scroll.Size = UDim2.new(1,-24,1,-84)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 3
Scroll.ScrollBarImageTransparency = 0.4
Scroll.CanvasSize = UDim2.fromOffset(0,0)
Scroll.ZIndex = 7
Scroll.Parent = Main

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0,10)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = Scroll

Padding(Scroll,6)

local function UpdateCanvas()
	Scroll.CanvasSize = UDim2.fromOffset(0,Layout.AbsoluteContentSize.Y + 30)
end

Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvas)

--========================================================--
-- SECTION
--========================================================--

local function CreateSection(title)
	local Holder = Instance.new("Frame")
	Holder.Size = UDim2.new(1,-12,0,38)
	Holder.BackgroundColor3 = Color3.fromRGB(255,255,255)
	Holder.BackgroundTransparency = 0.96
	Holder.BorderSizePixel = 0
	Holder.ZIndex = 8
	Holder.Parent = Scroll
	Round(Holder,10)

	local Text = CreateText(Holder,title,12,Enum.Font.GothamBold,SUBTEXT)
	Text.Position = UDim2.new(0,12,0,0)
	Text.Size = UDim2.new(1,-24,1,0)

	return Holder
end

--========================================================--
-- BUTTON
--========================================================--

local function CreateButton(text)
	local Button = Instance.new("TextButton")
	Button.Size = UDim2.new(1,-12,0,46)
	Button.BackgroundColor3 = GLASS2
	Button.BackgroundTransparency = 0.25
	Button.BorderSizePixel = 0
	Button.Text = text
	Button.TextColor3 = TEXT
	Button.TextSize = 13
	Button.Font = Enum.Font.GothamSemibold
	Button.AutoButtonColor = false
	Button.ZIndex = 8
	Button.Parent = Scroll
	Round(Button,11)
	Stroke(Button,Color3.fromRGB(255,255,255),0.93,1)

	Button.MouseEnter:Connect(function()
		Tween(Button,{BackgroundTransparency=0.08}):Play()
	end)

	Button.MouseLeave:Connect(function()
		Tween(Button,{BackgroundTransparency=0.25}):Play()
	end)

	return Button
end

--========================================================--
-- TOGGLE
--========================================================--

local function CreateToggle(text,getValue,setValue)
	local Holder = Instance.new("Frame")
	Holder.Size = UDim2.new(1,-12,0,52)
	Holder.BackgroundColor3 = GLASS2
	Holder.BackgroundTransparency = 0.25
	Holder.BorderSizePixel = 0
	Holder.ZIndex = 8
	Holder.Parent = Scroll
	Round(Holder,11)
	Stroke(Holder,Color3.fromRGB(255,255,255),0.94,1)

	local Label = CreateText(Holder,text,13,Enum.Font.GothamMedium,TEXT)
	Label.Position = UDim2.new(0,14,0,0)
	Label.Size = UDim2.new(1,-90,1,0)

	local Button = Instance.new("TextButton")
	Button.Size = UDim2.fromOffset(54,28)
	Button.Position = UDim2.new(1,-66,0.5,-14)
	Button.BackgroundColor3 = Color3.fromRGB(45,50,60)
	Button.BorderSizePixel = 0
	Button.Text = ""
	Button.AutoButtonColor = false
	Button.ZIndex = 10
	Button.Parent = Holder
	Round(Button,14)

	local Knob = Instance.new("Frame")
	Knob.Size = UDim2.fromOffset(20,20)
	Knob.AnchorPoint = Vector2.new(0,0.5)
	Knob.Position = UDim2.new(0,4,0.5,0)
	Knob.BackgroundColor3 = Color3.fromRGB(230,235,240)
	Knob.BorderSizePixel = 0
	Knob.ZIndex = 11
	Knob.Parent = Button
	Round(Knob,10)

	local function Refresh()
		local Enabled = getValue()

		if Enabled then
			Tween(Button,{BackgroundColor3=ACCENT},TWEEN_FAST):Play()
			Tween(Knob,{Position=UDim2.new(1,-24,0.5,0)},TWEEN_FAST):Play()
		else
			Tween(Button,{BackgroundColor3=Color3.fromRGB(45,50,60)},TWEEN_FAST):Play()
			Tween(Knob,{Position=UDim2.new(0,4,0.5,0)},TWEEN_FAST):Play()
		end
	end

	table.insert(ToggleRefreshers,Refresh)

	Button.Activated:Connect(function()
		setValue(not getValue())
		Refresh()
	end)

	Refresh()
	return Holder,Refresh
end

--========================================================--
-- SLIDER
--========================================================--

local function CreateSlider(text,min,max,getter,setter,decimals)
	local Holder = Instance.new("Frame")
	Holder.Size = UDim2.new(1,-12,0,76)
	Holder.BackgroundColor3 = GLASS2
	Holder.BackgroundTransparency = 0.25
	Holder.BorderSizePixel = 0
	Holder.ZIndex = 8
	Holder.Parent = Scroll
	Round(Holder,11)
	Stroke(Holder,Color3.fromRGB(255,255,255),0.94,1)

	local Label = CreateText(Holder,text,12,Enum.Font.GothamSemibold,TEXT)
	Label.Position = UDim2.new(0,14,0,8)
	Label.Size = UDim2.new(0.65,0,0,20)

	local Value = CreateText(Holder,"",12,Enum.Font.GothamMedium,ACCENT)
	Value.TextXAlignment = Enum.TextXAlignment.Right
	Value.Position = UDim2.new(0.65,0,0,8)
	Value.Size = UDim2.new(0.30,-10,0,20)

	local Bar = Instance.new("Frame")
	Bar.Size = UDim2.new(1,-28,0,5)
	Bar.Position = UDim2.new(0,14,0,48)
	Bar.BackgroundColor3 = Color3.fromRGB(55,60,72)
	Bar.BorderSizePixel = 0
	Bar.ZIndex = 9
	Bar.Parent = Holder
	Round(Bar,3)

	local Fill = Instance.new("Frame")
	Fill.Size = UDim2.new(0,0,1,0)
	Fill.BackgroundColor3 = ACCENT
	Fill.BorderSizePixel = 0
	Fill.ZIndex = 10
	Fill.Parent = Bar
	Round(Fill,3)

	local Dragging = false
	local DragInput = nil

	local function Format(v)
		if decimals == 0 then
			return string.format("%d",math.floor(v+0.5))
		end
		return string.format("%."..decimals.."f",v)
	end

	local function SetFromX(x)
		if Bar.AbsoluteSize.X <= 0 then
			return
		end

		local relative = math.clamp(
			(x-Bar.AbsolutePosition.X)/Bar.AbsoluteSize.X,
			0,1
		)

		local value = min + (max-min)*relative

		if decimals == 0 then
			value = math.floor(value+0.5)
		else
			local mult = 10^decimals
			value = math.floor(value*mult+0.5)/mult
		end

		setter(value)
	end

	local function Refresh()
		local current = math.clamp(getter(),min,max)
		local percent = 0

		if max ~= min then
			percent = (current-min)/(max-min)
		end

		Fill.Size = UDim2.new(percent,0,1,0)
		Value.Text = Format(current)
	end

	table.insert(SliderRefreshers,Refresh)

	Bar.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			Dragging = true
			SetFromX(input.Position.X)
			Refresh()
		end
	end)

	Bar.InputChanged:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			DragInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not Dragging or not DragInput then
			return
		end

		if input == DragInput then
			SetFromX(input.Position.X)
			Refresh()
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			Dragging = false
			DragInput = nil
		end
	end)

	Refresh()
	return Holder,Refresh
end

--========================================================--
-- REFRESH ALL CONTROLS
--========================================================--

RefreshAllControls = function()
	for _,Refresh in ipairs(ToggleRefreshers) do
		pcall(Refresh)
	end

	for _,Refresh in ipairs(SliderRefreshers) do
		pcall(Refresh)
	end
end

--========================================================--
-- PRESETS
--========================================================--

CreateSection("⚡ PRESETS")

local LowButton = CreateButton("LOW  •  Performance")
local MediumButton = CreateButton("MEDIUM  •  Balanced")
local HighButton = CreateButton("HIGH  •  Visual Quality")
local UltraButton = CreateButton("ULTRA  •  Maximum Effects")

LowButton.Activated:Connect(function()
	ApplyPreset("LOW")
	RefreshAllControls()
end)

MediumButton.Activated:Connect(function()
	ApplyPreset("MEDIUM")
	RefreshAllControls()
end)

HighButton.Activated:Connect(function()
	ApplyPreset("HIGH")
	RefreshAllControls()
end)

UltraButton.Activated:Connect(function()
	ApplyPreset("ULTRA")
	RefreshAllControls()
end)

--========================================================--
-- SHADERS
--========================================================--

CreateSection("🧩 SHADERS")

local ShaderButton = CreateButton("Shaders: OFF  •  Click to enable")

local function RefreshShaderButton()
	if State.Shaders then
		ShaderButton.Text = "Shaders: ON  •  Click to disable"
		ShaderButton.TextColor3 = ACCENT
	else
		ShaderButton.Text = "Shaders: OFF  •  Click to enable"
		ShaderButton.TextColor3 = TEXT
	end
end

ShaderButton.Activated:Connect(function()
	State.Shaders = not State.Shaders
	ApplyShaders()
	RefreshShaderButton()
end)

--========================================================--
-- LIGHTING
--========================================================--

CreateSection("💡 LIGHTING")

CreateToggle(
	"Global Shadows",
	function()
		return State.Shadows
	end,
	function(value)
		State.Shadows = value
		Lighting.GlobalShadows = value
	end
)

local RealisticButton = CreateButton("Realistic Lighting + Reflections: OFF")

local function RefreshRealisticButton()
	if State.RealisticReflections then
		RealisticButton.Text = "Realistic Lighting + Reflections: ON"
		RealisticButton.TextColor3 = ACCENT
	else
		RealisticButton.Text = "Realistic Lighting + Reflections: OFF"
		RealisticButton.TextColor3 = TEXT
	end
end

RealisticButton.Activated:Connect(function()
	if State.RealisticReflections then
		DisableRealisticReflections()
	else
		EnableRealisticReflections()
	end

	RefreshRealisticButton()
end)

CreateSlider(
	"Brightness",0,5,
	function() return State.Brightness end,
	function(value)
		State.Brightness = value
		Lighting.Brightness = value
	end,
	2
)

CreateSlider(
	"Exposure",-2,2,
	function() return State.Exposure end,
	function(value)
		State.Exposure = value
		Lighting.ExposureCompensation = value
	end,
	2
)

CreateSlider(
	"Shadow Softness",0,1,
	function() return State.ShadowSoftness end,
	function(value)
		State.ShadowSoftness = value
		Lighting.ShadowSoftness = value
	end,
	2
)

--========================================================--
-- BLOOM
--========================================================--

CreateSection("✨ BLOOM")

CreateToggle(
	"Bloom",
	function() return State.Bloom end,
	function(value)
		State.Bloom = value
		Bloom.Enabled = State.Shaders and value
	end
)

CreateSlider(
	"Intensity",0,1,
	function() return State.BloomIntensity end,
	function(value)
		State.BloomIntensity = value
		Bloom.Intensity = value
	end,
	2
)

CreateSlider(
	"Size",0,56,
	function() return State.BloomSize end,
	function(value)
		State.BloomSize = value
		Bloom.Size = value
	end,
	0
)

--========================================================--
-- COLOR
--========================================================--

CreateSection("🎨 COLOR")

CreateToggle(
	"Color Correction",
	function() return State.ColorCorrection end,
	function(value)
		State.ColorCorrection = value
		ColorCorrection.Enabled = State.Shaders and value
	end
)

CreateSlider(
	"Saturation",-1,1,
	function() return State.Saturation end,
	function(value)
		State.Saturation = value
		ColorCorrection.Saturation = value
	end,
	2
)

CreateSlider(
	"Contrast",-1,1,
	function() return State.Contrast end,
	function(value)
		State.Contrast = value
		ColorCorrection.Contrast = value
	end,
	2
)

CreateSlider(
	"Color Brightness",-1,1,
	function() return State.ColorBrightness end,
	function(value)
		State.ColorBrightness = value
		ColorCorrection.Brightness = value
	end,
	2
)

--========================================================--
-- ATMOSPHERE
--========================================================--

CreateSection("🌫️ ATMOSPHERE")

CreateToggle(
	"Atmosphere",
	function() return State.Atmosphere end,
	function(value)
		State.Atmosphere = value
		ApplyShaders()
	end
)

CreateSlider(
	"Density",0,0.6,
	function() return State.AtmosphereDensity end,
	function(value)
		State.AtmosphereDensity = value
		if State.Shaders and State.Atmosphere then
			CreateAtmosphere()
			Atmosphere.Density = value
		end
	end,
	2
)

CreateSlider(
	"Haze",0,3,
	function() return State.AtmosphereHaze end,
	function(value)
		State.AtmosphereHaze = value
		if State.Shaders and State.Atmosphere then
			CreateAtmosphere()
			Atmosphere.Haze = value
		end
	end,
	2
)

CreateSlider(
	"Glare",0,3,
	function() return State.AtmosphereGlare end,
	function(value)
		State.AtmosphereGlare = value
		if State.Shaders and State.Atmosphere then
			CreateAtmosphere()
			Atmosphere.Glare = value
		end
	end,
	2
)

--========================================================--
-- DOF
--========================================================--

CreateSection("👁️ DEPTH OF FIELD")

CreateToggle(
	"Depth Of Field",
	function() return State.DOF end,
	function(value)
		State.DOF = value
		DepthOfField.Enabled = State.Shaders and value
	end
)

CreateSlider(
	"Far Blur",0,1,
	function() return State.DOFFar end,
	function(value)
		State.DOFFar = value
		DepthOfField.FarIntensity = value
	end,
	2
)

CreateSlider(
	"Near Blur",0,1,
	function() return State.DOFNear end,
	function(value)
		State.DOFNear = value
		DepthOfField.NearIntensity = value
	end,
	2
)

CreateSlider(
	"Focus Distance",1,250,
	function() return State.DOFFocus end,
	function(value)
		State.DOFFocus = value
		DepthOfField.FocusDistance = value
	end,
	0
)

--========================================================--
-- SUN RAYS
--========================================================--

CreateSection("☀️ SUN RAYS")

CreateToggle(
	"Sun Rays",
	function() return State.SunRays end,
	function(value)
		State.SunRays = value
		SunRays.Enabled = State.Shaders and value
	end
)

--========================================================--
-- SKY
--========================================================--

CreateSection("🌌 LOCAL SKY")

local SkyOriginal = CreateButton("🌎 Original")
local SkyDawn = CreateButton("🌅 Amanhecer")
local SkySunset = CreateButton("🌇 Pôr do Sol")
local SkyNight = CreateButton("🌙 Noite")
local SkyDay = CreateButton("☀️ Dia")

SkyOriginal.Activated:Connect(function()
	ApplySkyPreset("Original")
end)

SkyDawn.Activated:Connect(function()
	ApplySkyPreset("Dawn")
end)

SkySunset.Activated:Connect(function()
	ApplySkyPreset("Sunset")
end)

SkyNight.Activated:Connect(function()
	ApplySkyPreset("Night")
end)

SkyDay.Activated:Connect(function()
	ApplySkyPreset("Day")
end)

--========================================================--
-- WATER
--========================================================--

CreateSection("🌊 WATER")

local WaterButton = CreateButton("🌊 ULTRA WATER: OFF")

local function RefreshWaterButton()
	if State.UltraWater then
		WaterButton.Text = "🌊 ULTRA WATER: ON"
		WaterButton.TextColor3 = WATER_ACCENT
	else
		WaterButton.Text = "🌊 ULTRA WATER: OFF"
		WaterButton.TextColor3 = TEXT
	end
end

WaterButton.Activated:Connect(function()
	if State.UltraWater then
		DisableUltraWater()
	else
		EnableUltraWater()
	end

	RefreshWaterButton()
	RefreshRealisticButton()
end)

--========================================================--
-- V6 - PROCEDURAL PBR / DYNAMIC SYSTEMS UI
--========================================================--

CreateSection("🧬 PROCEDURAL PBR")

local PBRButton = CreateButton(
	"🧬 Procedural PBR: OFF  •  Material + Texture Heuristics"
)

local function RefreshPBRButton()
	if State.ProceduralPBR then
		PBRButton.Text = "🧬 Procedural PBR: ON  •  Local Heuristic"
		PBRButton.TextColor3 = ACCENT
	else
		PBRButton.Text = "🧬 Procedural PBR: OFF  •  Material + Texture Heuristics"
		PBRButton.TextColor3 = TEXT
	end
end

PBRButton.Activated:Connect(function()
	if State.ProceduralPBR then
		DisableProceduralPBR()
	else
		EnableProceduralPBR()
	end

	RefreshPBRButton()
end)

CreateSlider(
	"PBR Reflectivity",0,1.2,
	function() return State.PBRStrength end,
	function(value)
		State.PBRStrength = value

		if State.ProceduralPBR then
			local changed = 0

			for part in pairs(PBRRegistry) do
				if part and part.Parent and part:IsA("BasePart") then
					local reflectance = GetMaterialProfile(part)

					if reflectance then
						part.Reflectance = reflectance
					end

					changed += 1

					if changed >= PBR_MAX_ACTIVE_PARTS then
						break
					end
				end
			end
		end
	end,
	2
)

CreateSection("🌗 DYNAMIC SHADOWS / REFLECTIONS")

local DynamicShadowButton = CreateButton(
	"🌗 Dynamic Shadows: OFF  •  Engine + Local Shadow Helper"
)

local function RefreshDynamicShadowButton()
	if State.DynamicShadows then
		DynamicShadowButton.Text = "🌗 Dynamic Shadows: ON  •  Shadows Active"
		DynamicShadowButton.TextColor3 = ACCENT
	else
		DynamicShadowButton.Text = "🌗 Dynamic Shadows: OFF  •  Engine + Local Shadow Helper"
		DynamicShadowButton.TextColor3 = TEXT
	end
end

DynamicShadowButton.Activated:Connect(function()
	if State.DynamicShadows then
		DisableDynamicShadows()
	else
		EnableDynamicShadows()
	end

	RefreshDynamicShadowButton()
end)

local DynamicReflectionButton = CreateButton(
	"🪞 Dynamic Reflections: OFF  •  Environment Specular"
)

local function RefreshDynamicReflectionButton()
	if State.DynamicReflections then
		DynamicReflectionButton.Text = "🪞 Dynamic Reflections: ON  •  Environment Specular"
		DynamicReflectionButton.TextColor3 = ACCENT
	else
		DynamicReflectionButton.Text = "🪞 Dynamic Reflections: OFF  •  Environment Specular"
		DynamicReflectionButton.TextColor3 = TEXT
	end
end

DynamicReflectionButton.Activated:Connect(function()
	if State.DynamicReflections then
		DisableDynamicReflections()
	else
		EnableDynamicReflections()
	end

	RefreshDynamicReflectionButton()
	RefreshRealisticButton()
end)

--========================================================--
-- DANGER / REFLECTION
--========================================================--

CreateSection("☢️ DANGER ZONE")

local MirrorButton = CreateButton(
	"⚠ MIRROR WORLD • Reflect Everything"
)
MirrorButton.TextColor3 = WARNING

local Confirm = Instance.new("Frame")
Confirm.Name = "MirrorConfirm"
Confirm.AnchorPoint = Vector2.new(0.5,0.5)
Confirm.Position = UDim2.fromScale(0.5,0.5)
Confirm.Size = UDim2.fromOffset(340,210)
Confirm.BackgroundColor3 = GLASS
Confirm.BackgroundTransparency = 0.03
Confirm.BorderSizePixel = 0
Confirm.Visible = false
Confirm.ZIndex = 100
Confirm.Parent = ScreenGui
Round(Confirm,18)
Stroke(Confirm,WARNING,0.55,1.5)

local ConfirmTitle = CreateText(
	Confirm,
	"☢️ MIRROR WORLD",
	20,
	Enum.Font.GothamBold,
	WARNING
)
ConfirmTitle.Position = UDim2.new(0,20,0,18)
ConfirmTitle.Size = UDim2.new(1,-40,0,30)
ConfirmTitle.TextXAlignment = Enum.TextXAlignment.Center

local ConfirmText = CreateText(
	Confirm,
	"Isso vai colocar reflexo em praticamente\n"..
	"todas as peças do mapa.\n\n"..
	"Pode destruir o FPS em mapas gigantes.\n"..
	"Quer realmente fazer essa desgraça?",
	12,
	Enum.Font.GothamMedium,
	SUBTEXT
)
ConfirmText.Position = UDim2.new(0,20,0,58)
ConfirmText.Size = UDim2.new(1,-40,0,80)
ConfirmText.TextWrapped = true
ConfirmText.TextXAlignment = Enum.TextXAlignment.Center

local CancelMirror = Instance.new("TextButton")
CancelMirror.Size = UDim2.new(0.43,0,0,40)
CancelMirror.Position = UDim2.new(0.05,0,1,-55)
CancelMirror.BackgroundColor3 = Color3.fromRGB(50,55,65)
CancelMirror.BorderSizePixel = 0
CancelMirror.Text = "CANCELAR"
CancelMirror.TextColor3 = TEXT
CancelMirror.Font = Enum.Font.GothamBold
CancelMirror.TextSize = 12
CancelMirror.ZIndex = 101
CancelMirror.Parent = Confirm
Round(CancelMirror,10)

local ConfirmMirror = Instance.new("TextButton")
ConfirmMirror.Size = UDim2.new(0.43,0,0,40)
ConfirmMirror.Position = UDim2.new(0.52,0,1,-55)
ConfirmMirror.BackgroundColor3 = WARNING
ConfirmMirror.BorderSizePixel = 0
ConfirmMirror.Text = "FAZER MERDA"
ConfirmMirror.TextColor3 = Color3.fromRGB(30,10,10)
ConfirmMirror.Font = Enum.Font.GothamBold
ConfirmMirror.TextSize = 12
ConfirmMirror.ZIndex = 101
ConfirmMirror.Parent = Confirm
Round(ConfirmMirror,10)

MirrorButton.Activated:Connect(function()
	if State.MirrorWorld then
		DisableMirrorWorld()

		if State.ProceduralPBR then
			for part in pairs(PBRRegistry) do
				if part and part.Parent then
					ApplyProceduralPBRToPart(part)
				end
			end
		end

		MirrorButton.Text = "⚠ MIRROR WORLD • Reflect Everything"
		RefreshRealisticButton()
		return
	end

	Confirm.Visible = true
end)

CancelMirror.Activated:Connect(function()
	Confirm.Visible = false
end)

ConfirmMirror.Activated:Connect(function()
	Confirm.Visible = false
	EnableMirrorWorld()
	MirrorButton.Text = "☢ MIRROR WORLD: ACTIVE • CLICK TO DISABLE"
	RefreshRealisticButton()
end)

--========================================================--
-- SYSTEM
--========================================================--

CreateSection("🛠️ SYSTEM")

local ResetButton = CreateButton(
	"↺  RESTORE ORIGINAL GRAPHICS"
)

ResetButton.Activated:Connect(function()
	ResetOriginal()

	RefreshShaderButton()
	RefreshWaterButton()
	RefreshRealisticButton()
	RefreshPBRButton()
	RefreshDynamicShadowButton()
	RefreshDynamicReflectionButton()

	MirrorButton.Text = "⚠ MIRROR WORLD • Reflect Everything"

	ResetButton.Text = "✓ GRAPHICS RESTORED"

	task.delay(1.5,function()
		if ResetButton and ResetButton.Parent then
			ResetButton.Text = "↺  RESTORE ORIGINAL GRAPHICS"
		end
	end)
end)

--========================================================--
-- WELCOME POPUP
--========================================================--

local Welcome = Instance.new("Frame")
Welcome.Name = "Welcome"
Welcome.AnchorPoint = Vector2.new(0.5,0.5)
Welcome.Position = UDim2.fromScale(0.5,0.5)
Welcome.Size = UDim2.fromOffset(320,190)
Welcome.BackgroundColor3 = GLASS
Welcome.BackgroundTransparency = 0.08
Welcome.BorderSizePixel = 0
Welcome.Visible = false
Welcome.ZIndex = 50
Welcome.Parent = ScreenGui
Round(Welcome,18)
Stroke(Welcome,Color3.fromRGB(255,255,255),0.84,1)

local WelcomeTitle = CreateText(
	Welcome,
	"✨ OBRIGADO POR USAR O TBAMGV",
	17,
	Enum.Font.GothamBold,
	TEXT
)
WelcomeTitle.Position = UDim2.new(0,20,0,24)
WelcomeTitle.Size = UDim2.new(1,-40,0,30)
WelcomeTitle.TextXAlignment = Enum.TextXAlignment.Center

local WelcomeDesc = CreateText(
	Welcome,
	"Graphics Edition carregado.\n\n"..
	"Agora você pode transformar o Roblox\n"..
	"num forno nuclear visual. 🔥",
	12,
	Enum.Font.GothamMedium,
	SUBTEXT
)
WelcomeDesc.Position = UDim2.new(0,20,0,62)
WelcomeDesc.Size = UDim2.new(1,-40,0,66)
WelcomeDesc.TextWrapped = true
WelcomeDesc.TextXAlignment = Enum.TextXAlignment.Center

local Continue = Instance.new("TextButton")
Continue.Size = UDim2.new(1,-40,0,42)
Continue.Position = UDim2.new(0,20,1,-60)
Continue.BackgroundColor3 = ACCENT
Continue.BackgroundTransparency = 0.06
Continue.BorderSizePixel = 0
Continue.Text = "ENTENDI"
Continue.TextColor3 = Color3.fromRGB(10,15,22)
Continue.Font = Enum.Font.GothamBold
Continue.TextSize = 12
Continue.AutoButtonColor = false
Continue.ZIndex = 51
Continue.Parent = Welcome
Round(Continue,11)

--========================================================--
-- OPEN BUTTON
--========================================================--

local OpenButton = Instance.new("TextButton")
OpenButton.Name = "OpenButton"
OpenButton.AnchorPoint = Vector2.new(1,1)
OpenButton.Position = UDim2.new(1,-18,1,-18)
OpenButton.Size = UDim2.fromOffset(56,56)
OpenButton.BackgroundColor3 = GLASS
OpenButton.BackgroundTransparency = 0.1
OpenButton.BorderSizePixel = 0
OpenButton.Text = "⚙"
OpenButton.TextColor3 = TEXT
OpenButton.TextSize = 24
OpenButton.Font = Enum.Font.GothamBold
OpenButton.AutoButtonColor = false
OpenButton.Active = true
OpenButton.ZIndex = 20
OpenButton.Parent = ScreenGui
Round(OpenButton,18)
Stroke(OpenButton,Color3.fromRGB(255,255,255),0.85,1)

--========================================================--
-- DRAGGING SYSTEM - FIXED
--========================================================--

local Dragging = false
local DragStart = nil
local StartPosition = nil
local DragInput = nil
local DragDistance = 0
local DRAG_THRESHOLD = 8

OpenButton.InputBegan:Connect(function(input)
	if
		input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
	then
		Dragging = true
		DragStart = input.Position
		StartPosition = OpenButton.Position
		DragDistance = 0
	end
end)

OpenButton.InputChanged:Connect(function(input)
	if
		input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch
	then
		DragInput = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if
		not Dragging
		or not DragInput
		or not DragStart
		or not StartPosition
	then
		return
	end

	if input ~= DragInput then
		return
	end

	local delta = input.Position - DragStart
	DragDistance = delta.Magnitude

	local newX = StartPosition.X.Offset + delta.X
	local newY = StartPosition.Y.Offset + delta.Y

	local Camera = Workspace.CurrentCamera
	if Camera then
		local viewport = Camera.ViewportSize
		local buttonSize = OpenButton.AbsoluteSize
		local margin = 8

		local minX = -viewport.X + buttonSize.X + margin
		local maxX = -margin
		local minY = -viewport.Y + buttonSize.Y + margin
		local maxY = -margin

		newX = math.clamp(newX,minX,maxX)
		newY = math.clamp(newY,minY,maxY)
	end

	OpenButton.Position = UDim2.new(1,newX,1,newY)
end)

--========================================================--
-- OPEN/CLOSE
--========================================================--

local Opened = false

function OpenMenu()
	Opened = true

	Backdrop.Visible = true
	OutsideButton.Visible = true
	Main.Visible = true
	OpenButton.Visible = false

	Main.Size = UDim2.new(0.76,0,0.70,0)
	Main.BackgroundTransparency = 0.35

	Tween(Main,{
		Size = UDim2.new(0.82,0,0.78,0),
		BackgroundTransparency = 0.16
	}):Play()
end

local function CloseMenu()
	Opened = false

	local TweenOut = Tween(
		Main,
		{
			Size = UDim2.new(0.76,0,0.70,0),
			BackgroundTransparency = 0.4
		},
		TWEEN_FAST
	)

	TweenOut:Play()

	TweenOut.Completed:Connect(function()
		if not Opened then
			Main.Visible = false
			Backdrop.Visible = false
			OutsideButton.Visible = false
			OpenButton.Visible = true
		end
	end)
end

UserInputService.InputEnded:Connect(function(input)
	if
		input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
	then
		local WasClick =
			Dragging
			and DragDistance < DRAG_THRESHOLD

		Dragging = false
		DragInput = nil
		DragStart = nil
		StartPosition = nil
		DragDistance = 0

		if WasClick and OpenButton.Visible then
			OpenMenu()
		end
	end
end)

Close.Activated:Connect(CloseMenu)
OutsideButton.Activated:Connect(CloseMenu)

Continue.Activated:Connect(function()
	Tween(
		Welcome,
		{
			Size = UDim2.fromOffset(300,175),
			BackgroundTransparency = 0.4
		},
		TWEEN_FAST
	):Play()

	task.wait(0.15)

	Welcome.Visible = false
	OpenMenu()
end)

--========================================================--
-- RESPONSIVE
--========================================================--

local ResponsiveViewportConnection = nil

local function UpdateResponsive()
	local Camera = Workspace.CurrentCamera
	if not Camera then
		return
	end

	local viewport = Camera.ViewportSize

	if viewport.X < 600 then
		Main.Size = UDim2.new(0.94,0,0.84,0)
		Welcome.Size = UDim2.new(0.86,0,0,190)
	else
		Main.Size = UDim2.new(0.82,0,0.78,0)
		Welcome.Size = UDim2.fromOffset(320,190)
	end
end

local function ConnectCameraResponsive()
	local Camera = Workspace.CurrentCamera
	if not Camera then
		return
	end

	if ResponsiveViewportConnection then
		ResponsiveViewportConnection:Disconnect()
		ResponsiveViewportConnection = nil
	end

	ResponsiveViewportConnection =
		Camera:GetPropertyChangedSignal("ViewportSize"):Connect(
			UpdateResponsive
		)
end

ConnectCameraResponsive()
UpdateResponsive()

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	task.wait()
	UpdateResponsive()
	ConnectCameraResponsive()
end)

--========================================================--
-- STARTUP - TOTALMENTE OFF
--========================================================--

State.Shaders = false
State.Bloom = false
State.ColorCorrection = false
State.DOF = false
State.SunRays = false
State.Atmosphere = false
State.RealisticReflections = false
State.MirrorWorld = false
State.UltraWater = false
State.ProceduralPBR = false
State.DynamicShadows = false
State.DynamicReflections = false

State.Shadows = Original.GlobalShadows
State.Brightness = Original.Brightness
State.Exposure = Original.ExposureCompensation
State.ShadowSoftness = Original.ShadowSoftness

ApplyShaders()
DisableRealisticReflections()

Lighting.GlobalShadows = Original.GlobalShadows
Lighting.Brightness = Original.Brightness
Lighting.ExposureCompensation = Original.ExposureCompensation
Lighting.ShadowSoftness = Original.ShadowSoftness

RefreshAllControls()
RefreshShaderButton()
RefreshWaterButton()
RefreshRealisticButton()
RefreshPBRButton()
RefreshDynamicShadowButton()
RefreshDynamicReflectionButton()

OpenButton.Visible = false
Backdrop.Visible = true
Welcome.Visible = true

Welcome.Size = UDim2.fromOffset(280,160)
Welcome.BackgroundTransparency = 0.5

Tween(
	Welcome,
	{
		Size = UDim2.fromOffset(320,190),
		BackgroundTransparency = 0.08
	},
	TWEEN_MED
):Play()

--========================================================--
-- V6 CLEANUP / SAFETY
--========================================================--

ScreenGui.Destroying:Connect(function()
	pcall(function()
		if PBRDescendantConnection then
			PBRDescendantConnection:Disconnect()
			PBRDescendantConnection = nil
		end
	end)

	pcall(function()
		if V6RuntimeConnection then
			V6RuntimeConnection:Disconnect()
		end
	end)

	pcall(function()
		RestoreAllPBR()
	end)

	pcall(function()
		DestroyDynamicShadowRig()
	end)
end)

--========================================================--
-- DONE
--========================================================--
