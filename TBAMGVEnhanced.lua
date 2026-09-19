--========================================================--
-- TBAMGV - ADAPTIVE REALISM ENGINE V7
-- by Catfeine / Feine
--========================================================--
-- LocalScript / Delta-compatible where the executor exposes the
-- normal Roblox client APIs.
--
-- V7 PRINCIPAIS:
--  • Fog/Atmosphere Adaptive Shader: lê o estado real do jogo e
--    ajusta contraste, cor, bloom, rays, DOF e atmosfera.
--  • Game Learning: amostragem contínua de hora, ambiente,
--    iluminação local, interior/exterior, câmera e desempenho.
--  • PBR real preservation/audit: SurfaceAppearance existente
--    não é destruído nem falsificado. PBR assist usa Reflectance
--    apenas onde PBR de verdade não existe.
--  • Auto Focus por raycast.
--  • Auto Exposure heurística, limitada para evitar "tela branca".
--  • Auto Quality: reduz custo quando FPS cai.
--  • Dynamic reflections via Lighting EnvironmentSpecularScale.
--  • Dynamic shadows: GlobalShadows + LightingStyle.Realistic.
--  • Water tuning adaptativo.
--  • Mirror experimental com distância/culling e restore seguro.
--  • Cleanup global para não duplicar GUI/conexões/efeitos.
--
-- LIMITAÇÃO REAL DE ROBLOX:
-- SurfaceAppearance.MetalnessMap/RoughnessMap/NormalMap são
-- ContentIds com restrições de escrita em runtime. Logo, um
-- LocalScript não pode fabricar mapas PBR arbitrários do nada.
-- Este V7 usa PBR nativo já publicado + heurística física de
-- Reflectance como fallback, sem fingir que isso é um texture-PBR.
--========================================================--

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer
if not Player then
    return
end

local PlayerGui = Player:WaitForChild("PlayerGui")

--========================================================--
-- GLOBAL CLEANUP
--========================================================--

local GlobalEnv = getgenv and getgenv() or _G
if GlobalEnv.TBAMGV_V7_Cleanup then
    pcall(GlobalEnv.TBAMGV_V7_Cleanup)
end

local Alive = true
local Connections = {}
local Threads = {}
local CreatedObjects = {}

local function TrackConnection(connection)
    if connection then
        table.insert(Connections, connection)
    end
    return connection
end

local function TrackObject(object)
    if object then
        table.insert(CreatedObjects, object)
    end
    return object
end

local function SafeDisconnect(connection)
    if connection then
        pcall(function()
            connection:Disconnect()
        end)
    end
end

local function SafeDestroy(object)
    if object then
        pcall(function()
            object:Destroy()
        end)
    end
end

local function SafeProperty(instance, property, value)
    if not instance then
        return false
    end
    local ok = pcall(function()
        instance[property] = value
    end)
    return ok
end

local function ReadProperty(instance, property, fallback)
    if not instance then
        return fallback
    end
    local ok, value = pcall(function()
        return instance[property]
    end)
    if ok then
        return value
    end
    return fallback
end

local function HasProperty(instance, property)
    if not instance then
        return false
    end
    local ok = pcall(function()
        local _ = instance[property]
    end)
    return ok
end

local function LerpNumber(a, b, t)
    return a + (b - a) * math.clamp(t, 0, 1)
end

local function Clamp01(value)
    return math.clamp(value or 0, 0, 1)
end

local function SafeUnit(vector, fallback)
    if typeof(vector) ~= "Vector3" or vector.Magnitude < 0.001 then
        return fallback or Vector3.new(0, -1, 0)
    end
    return vector.Unit
end

local function StringHasAny(text, keywords)
    text = string.lower(text or "")
    for _, keyword in ipairs(keywords) do
        if string.find(text, keyword, 1, true) then
            return true
        end
    end
    return false
end

local function ColorLerp(a, b, alpha)
    return a:Lerp(b, math.clamp(alpha, 0, 1))
end

--========================================================--
-- EXECUTOR / EXTERNAL API COMPAT
--========================================================--

local function ResolveRequest()
    local candidates = {
        rawget(GlobalEnv, "request"),
        rawget(GlobalEnv, "http_request"),
        rawget(GlobalEnv, "httprequest"),
    }

    local synTable = rawget(GlobalEnv, "syn")
    if synTable and synTable.request then
        table.insert(candidates, synTable.request)
    end

    for _, fn in ipairs(candidates) do
        if type(fn) == "function" then
            return fn
        end
    end

    return nil
end

local ExecutorRequest = ResolveRequest()

local function ExternalGet(url)
    if type(url) ~= "string" or url == "" then
        return nil, "invalid-url"
    end

    if ExecutorRequest then
        local ok, response = pcall(ExecutorRequest, {
            Url = url,
            Method = "GET",
        })
        if ok and type(response) == "table" then
            local status = response.StatusCode or response.Status
            local body = response.Body or response.body
            if (not status or status == 200) and type(body) == "string" then
                return body
            end
        end
    end

    local httpGet = game
    if httpGet and type(httpGet.HttpGet) == "function" then
        local ok, body = pcall(function()
            return httpGet:HttpGet(url)
        end)
        if ok and type(body) == "string" then
            return body
        end
    end

    return nil, "no-http"
end

-- External API is optional. Nothing is sent anywhere by default.
-- The official Roblox Games API can be used only for passive metadata.
local GAME_METADATA = {
    fetched = false,
    available = false,
    name = "",
    description = "",
    genre = "",
}

local function FetchGameMetadata()
    if GAME_METADATA.fetched then
        return
    end
    GAME_METADATA.fetched = true

    local universeId = tonumber(game.GameId)
    if not universeId then
        return
    end

    local url = "https://games.roblox.com/v1/games?universeIds=" .. tostring(universeId)
    local body = ExternalGet(url)
    if not body then
        return
    end

    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    if not ok or type(decoded) ~= "table" or type(decoded.data) ~= "table" then
        return
    end

    local data = decoded.data[1]
    if type(data) ~= "table" then
        return
    end

    GAME_METADATA.available = true
    GAME_METADATA.name = tostring(data.name or "")
    GAME_METADATA.description = tostring(data.description or "")
    GAME_METADATA.genre = tostring(data.genre or data.genre_l1 or "")
end

-- Fire-and-forget metadata fetch. Rendering never depends on it.
task.spawn(FetchGameMetadata)

--========================================================--
-- CONFIG
--========================================================--

local MENU_NAME = "TBAMGV_AdaptiveMenu"
local PREFIX = "TBAMGV_V7_"

local UI = {
    Accent = Color3.fromRGB(108, 197, 255),
    Glass = Color3.fromRGB(18, 22, 30),
    Glass2 = Color3.fromRGB(25, 30, 40),
    Text = Color3.fromRGB(240, 245, 255),
    Subtext = Color3.fromRGB(160, 170, 185),
    Warning = Color3.fromRGB(255, 110, 100),
    Good = Color3.fromRGB(120, 255, 180),
}

local Limits = {
    UpdateInterval = 0.12,
    SenseInterval = 0.22,
    PerformanceInterval = 0.55,
    FocusInterval = 0.22,
    PBRInterval = 0.14,
    PBRBatch = 55,
    PBRMaxParts = 1100,
    PBRMaxDistance = 300,
    PBRMinDistance = 4,
    MirrorMaxParts = 900,
    MirrorMaxDistance = 230,
}

local PRESET = {
    LOW = {
        Bloom = false,
        ColorCorrection = true,
        DOF = false,
        SunRays = false,
        Atmosphere = false,
        RealisticLighting = false,
        Shadows = false,
        AdaptiveFog = true,
        AdaptiveExposure = true,
        AutoFocus = false,
        AdaptivePBR = false,
        AutoQuality = true,
        BloomIntensity = 0.05,
        BloomSize = 10,
        Saturation = 0.025,
        Contrast = 0.04,
        Brightness = 0,
        Exposure = 0,
        AtmosphereDensity = 0.03,
        AtmosphereHaze = 0.25,
        AtmosphereGlare = 0,
        DOFFar = 0.04,
        DOFNear = 0.02,
        DOFFocus = 65,
        PBRStrength = 0.65,
    },
    MEDIUM = {
        Bloom = true,
        ColorCorrection = true,
        DOF = false,
        SunRays = true,
        Atmosphere = true,
        RealisticLighting = true,
        Shadows = true,
        AdaptiveFog = true,
        AdaptiveExposure = true,
        AutoFocus = true,
        AdaptivePBR = true,
        AutoQuality = true,
        BloomIntensity = 0.12,
        BloomSize = 14,
        Saturation = 0.04,
        Contrast = 0.07,
        Brightness = 0,
        Exposure = 0,
        AtmosphereDensity = 0.08,
        AtmosphereHaze = 0.55,
        AtmosphereGlare = 0.015,
        DOFFar = 0.07,
        DOFNear = 0.035,
        DOFFocus = 70,
        PBRStrength = 0.85,
    },
    HIGH = {
        Bloom = true,
        ColorCorrection = true,
        DOF = true,
        SunRays = true,
        Atmosphere = true,
        RealisticLighting = true,
        Shadows = true,
        AdaptiveFog = true,
        AdaptiveExposure = true,
        AutoFocus = true,
        AdaptivePBR = true,
        AutoQuality = true,
        BloomIntensity = 0.18,
        BloomSize = 18,
        Saturation = 0.055,
        Contrast = 0.095,
        Brightness = 0,
        Exposure = 0,
        AtmosphereDensity = 0.11,
        AtmosphereHaze = 0.8,
        AtmosphereGlare = 0.025,
        DOFFar = 0.095,
        DOFNear = 0.05,
        DOFFocus = 75,
        PBRStrength = 1,
    },
    ULTRA = {
        Bloom = true,
        ColorCorrection = true,
        DOF = true,
        SunRays = true,
        Atmosphere = true,
        RealisticLighting = true,
        Shadows = true,
        AdaptiveFog = true,
        AdaptiveExposure = true,
        AutoFocus = true,
        AdaptivePBR = true,
        AutoQuality = true,
        BloomIntensity = 0.22,
        BloomSize = 21,
        Saturation = 0.065,
        Contrast = 0.11,
        Brightness = 0,
        Exposure = 0,
        AtmosphereDensity = 0.13,
        AtmosphereHaze = 0.95,
        AtmosphereGlare = 0.035,
        DOFFar = 0.11,
        DOFNear = 0.055,
        DOFFocus = 80,
        PBRStrength = 1.05,
    },
}

local State = {
    Shaders = false,
    Bloom = true,
    ColorCorrection = true,
    DOF = false,
    SunRays = true,
    Atmosphere = true,
    RealisticLighting = true,
    Shadows = true,

    AdaptiveFog = true,
    AdaptiveExposure = true,
    AutoFocus = true,
    AdaptivePBR = true,
    AutoQuality = true,

    DynamicReflections = true,
    DynamicShadows = false,
    UltraWater = false,
    MirrorWorld = false,

    BloomIntensity = 0.18,
    BloomSize = 18,
    Saturation = 0.055,
    Contrast = 0.095,
    Brightness = 0,
    Exposure = 0,

    AtmosphereDensity = 0.11,
    AtmosphereHaze = 0.8,
    AtmosphereGlare = 0.025,

    DOFFar = 0.095,
    DOFNear = 0.05,
    DOFFocus = 75,

    PBRStrength = 1,
    WetnessAssist = true,
    WaterStrength = 0.75,

    SelectedPreset = "HIGH",
    SelectedSky = "Original",
}

--========================================================--
-- ORIGINAL GAME STATE
--========================================================--

local Original = {
    Lighting = {
        GlobalShadows = ReadProperty(Lighting, "GlobalShadows", true),
        Brightness = ReadProperty(Lighting, "Brightness", 2),
        ExposureCompensation = ReadProperty(Lighting, "ExposureCompensation", 0),
        ShadowSoftness = ReadProperty(Lighting, "ShadowSoftness", 0.5),
        Ambient = ReadProperty(Lighting, "Ambient", Color3.new(0.5, 0.5, 0.5)),
        OutdoorAmbient = ReadProperty(Lighting, "OutdoorAmbient", Color3.new(0.5, 0.5, 0.5)),
        ColorShiftTop = ReadProperty(Lighting, "ColorShift_Top", Color3.new(0, 0, 0)),
        ColorShiftBottom = ReadProperty(Lighting, "ColorShift_Bottom", Color3.new(0, 0, 0)),
        ClockTime = ReadProperty(Lighting, "ClockTime", 12),
        FogColor = ReadProperty(Lighting, "FogColor", Color3.new(0.75, 0.75, 0.75)),
        FogStart = ReadProperty(Lighting, "FogStart", 0),
        FogEnd = ReadProperty(Lighting, "FogEnd", 100000),
        EnvironmentDiffuseScale = ReadProperty(Lighting, "EnvironmentDiffuseScale", 1),
        EnvironmentSpecularScale = ReadProperty(Lighting, "EnvironmentSpecularScale", 1),
        LightingStyle = nil,
        PrioritizeLightingQuality = nil,
    },
    Atmosphere = nil,
    Terrain = nil,
    Water = nil,
}

pcall(function()
    Original.Lighting.LightingStyle = Lighting.LightingStyle
end)

pcall(function()
    Original.Lighting.PrioritizeLightingQuality = Lighting.PrioritizeLightingQuality
end)

local OriginalAtmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
if OriginalAtmosphere then
    Original.Atmosphere = {
        Instance = OriginalAtmosphere,
        Density = ReadProperty(OriginalAtmosphere, "Density", 0),
        Haze = ReadProperty(OriginalAtmosphere, "Haze", 0),
        Glare = ReadProperty(OriginalAtmosphere, "Glare", 0),
        Offset = ReadProperty(OriginalAtmosphere, "Offset", 0),
        Color = ReadProperty(OriginalAtmosphere, "Color", Color3.new(1, 1, 1)),
        Decay = ReadProperty(OriginalAtmosphere, "Decay", Color3.new(1, 1, 1)),
    }
end

local Terrain = Workspace:FindFirstChildOfClass("Terrain")
if Terrain then
    Original.Terrain = Terrain
    Original.Water = {
        WaterColor = ReadProperty(Terrain, "WaterColor", Color3.fromRGB(45, 100, 120)),
        WaterReflectance = ReadProperty(Terrain, "WaterReflectance", 0),
        WaterTransparency = ReadProperty(Terrain, "WaterTransparency", 0.3),
        WaterWaveSize = ReadProperty(Terrain, "WaterWaveSize", 0.15),
        WaterWaveSpeed = ReadProperty(Terrain, "WaterWaveSpeed", 10),
    }
end

-- We only touch objects with our own prefix.
for _, obj in ipairs(Lighting:GetChildren()) do
    if string.sub(obj.Name, 1, #PREFIX) == PREFIX and obj ~= OriginalAtmosphere then
        SafeDestroy(obj)
    end
end

local function GetCamera()
    return Workspace.CurrentCamera
end

--========================================================--
-- ORIGINAL ENVIRONMENT LEARNING
--========================================================--

local Sense = {
    fogFactor = 0,
    fogColor = Original.Lighting.FogColor,
    atmosphereDensity = Original.Atmosphere and Original.Atmosphere.Density or 0,
    atmosphereHaze = Original.Atmosphere and Original.Atmosphere.Haze or 0,
    atmosphereGlare = Original.Atmosphere and Original.Atmosphere.Glare or 0,
    indoor = false,
    localLightEnergy = 0,
    localLightColor = Color3.new(1, 1, 1),
    daylight = 1,
    sunset = 0,
    night = 0,
    wet = 0,
    targetDistance = State.DOFFocus,
    averageFrame = 1 / 60,
    fps = 60,
    qualityScale = 1,
    cameraSpeed = 0,
    learned = false,
    skyVisible = true,
}

local lastCameraPosition = nil
local averageLuminance = 0.5

-- Tracks the last values written by TBAM so game-authored changes can be
-- distinguished from our own adaptive writes.
local GameAtmosphereBaseline = Original.Atmosphere and {
    Density = Original.Atmosphere.Density,
    Haze = Original.Atmosphere.Haze,
    Glare = Original.Atmosphere.Glare,
    Offset = Original.Atmosphere.Offset,
    Color = Original.Atmosphere.Color,
    Decay = Original.Atmosphere.Decay,
} or nil
local LastTBAMAtmosphere = nil

local function AtmosphereChangedByGame(current)
    if not LastTBAMAtmosphere then
        return true
    end

    local numberChanged =
        math.abs((current.Density or 0) - (LastTBAMAtmosphere.Density or 0)) > 0.004
        or math.abs((current.Haze or 0) - (LastTBAMAtmosphere.Haze or 0)) > 0.04
        or math.abs((current.Glare or 0) - (LastTBAMAtmosphere.Glare or 0)) > 0.004
        or math.abs((current.Offset or 0) - (LastTBAMAtmosphere.Offset or 0)) > 0.02

    return numberChanged
end

local function GetTimeFactors(clockTime)
    local t = clockTime % 24

    local day = 1 - math.clamp(math.abs(t - 13) / 7, 0, 1)
    local nightDistance = math.min(math.abs(t - 0), math.abs(t - 24))
    local night = math.clamp((nightDistance < 6 and (6 - nightDistance) / 6 or 0), 0, 1)

    local sunsetBand = 1 - math.clamp(math.abs(t - 18) / 2.8, 0, 1)
    local sunriseBand = 1 - math.clamp(math.abs(t - 6) / 2.4, 0, 1)
    local sunset = math.max(sunsetBand, sunriseBand) * (1 - night)

    return Clamp01(day), Clamp01(sunset), Clamp01(night)
end

local function EstimateFogFactor()
    local fogStart = tonumber(ReadProperty(Lighting, "FogStart", Original.Lighting.FogStart)) or 0
    local fogEnd = tonumber(ReadProperty(Lighting, "FogEnd", Original.Lighting.FogEnd)) or 100000

    -- Roblox's default FogEnd can be very large, which means practically
    -- no distance fog. Estimate strength from visible distance instead of
    -- treating FogStart=0 as "maximum fog".
    local endStrength = math.clamp(1 - fogEnd / 5000, 0, 1)
    local startStrength = math.clamp(1 - fogStart / 900, 0, 1)
    local distanceFog = endStrength * 0.82 + startStrength * 0.18

    local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
    local density = 0
    local haze = 0

    if atmo then
        local current = {
            Density = tonumber(ReadProperty(atmo, "Density", 0)) or 0,
            Haze = tonumber(ReadProperty(atmo, "Haze", 0)) or 0,
            Glare = tonumber(ReadProperty(atmo, "Glare", 0)) or 0,
            Offset = tonumber(ReadProperty(atmo, "Offset", 0)) or 0,
        }

        if atmo == OriginalAtmosphere then
            if AtmosphereChangedByGame(current) then
                GameAtmosphereBaseline = {
                    Density = current.Density,
                    Haze = current.Haze,
                    Glare = current.Glare,
                    Offset = current.Offset,
                    Color = ReadProperty(atmo, "Color", Color3.new(1, 1, 1)),
                    Decay = ReadProperty(atmo, "Decay", Color3.new(1, 1, 1)),
                }
            end
            density = GameAtmosphereBaseline and GameAtmosphereBaseline.Density or current.Density
            haze = GameAtmosphereBaseline and GameAtmosphereBaseline.Haze or current.Haze
        else
            density = current.Density
            haze = current.Haze
        end
    elseif Original.Atmosphere then
        density = Original.Atmosphere.Density
        haze = Original.Atmosphere.Haze
    end

    local atmoFog = math.clamp(density * 1.8 + haze * 0.08, 0, 1)
    return math.clamp(distanceFog * 0.45 + atmoFog * 0.9, 0, 1)
end

local function EstimateIndoor(camera)
    if not camera then
        return false
    end

    local origin = camera.CFrame.Position
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {Player.Character}
    params.IgnoreWater = false

    local hitUp = Workspace:Raycast(origin, Vector3.new(0, 75, 0), params)
    local hitDown = Workspace:Raycast(origin, Vector3.new(0, -35, 0), params)
    local hitSide = Workspace:Raycast(origin, camera.CFrame.LookVector * 28, params)

    local roof = hitUp and hitUp.Distance < 35
    local enclosed = hitSide and hitSide.Distance < 8 and hitDown and hitDown.Distance < 12

    return roof and enclosed
end

local function EstimateWetness(camera)
    if not camera or not State.WetnessAssist then
        return 0
    end

    local origin = camera.CFrame.Position
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {Player.Character}
    params.IgnoreWater = false

    local hit = Workspace:Raycast(origin, Vector3.new(0, -18, 0), params)
    if hit and hit.Material == Enum.Material.Water then
        return 1
    end

    local nearbyParts = {}
    pcall(function()
        local overlap = OverlapParams.new()
        overlap.FilterType = Enum.RaycastFilterType.Exclude
        overlap.FilterDescendantsInstances = {Player.Character}
        overlap.MaxParts = 80
        nearbyParts = Workspace:GetPartBoundsInRadius(origin, 32, overlap)
    end)

    local hits = 0
    for _, part in ipairs(nearbyParts) do
        local name = string.lower(part.Name or "")
        if StringHasAny(name, {"wet", "puddle", "rain", "water", "damp", "mud"}) then
            hits += 1
            if hits >= 3 then
                return 0.65
            end
        end
    end

    return 0
end

local function SampleLocalLights(camera)
    if not camera then
        return 0, Color3.new(1, 1, 1)
    end

    local parts = {}
    pcall(function()
        local overlap = OverlapParams.new()
        overlap.FilterType = Enum.RaycastFilterType.Exclude
        overlap.FilterDescendantsInstances = {Player.Character}
        overlap.MaxParts = 120
        parts = Workspace:GetPartBoundsInRadius(camera.CFrame.Position, 60, overlap)
    end)

    local energy = 0
    local colorSum = Vector3.zero
    local weightSum = 0

    for _, part in ipairs(parts) do
        for _, child in ipairs(part:GetChildren()) do
            if child:IsA("PointLight") or child:IsA("SpotLight") or child:IsA("SurfaceLight") then
                local brightness = tonumber(ReadProperty(child, "Brightness", 0)) or 0
                local range = tonumber(ReadProperty(child, "Range", 16)) or 16
                local dist = (part.Position - camera.CFrame.Position).Magnitude
                local weight = brightness * math.clamp(1 - dist / math.max(range, 1), 0, 1)
                if weight > 0 then
                    energy += weight
                    local c = ReadProperty(child, "Color", Color3.new(1, 1, 1))
                    colorSum += Vector3.new(c.R, c.G, c.B) * weight
                    weightSum += weight
                end
            end
        end
    end

    local average = Color3.new(1, 1, 1)
    if weightSum > 0 then
        local v = colorSum / weightSum
        average = Color3.new(math.clamp(v.X, 0, 1), math.clamp(v.Y, 0, 1), math.clamp(v.Z, 0, 1))
    end

    return math.clamp(energy / 8, 0, 1), average
end

local function UpdateSense(dt)
    local camera = GetCamera()
    if not camera then
        return
    end

    local clock = tonumber(ReadProperty(Lighting, "ClockTime", 12)) or 12
    Sense.daylight, Sense.sunset, Sense.night = GetTimeFactors(clock)
    Sense.fogFactor = EstimateFogFactor()

    local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
    Sense.atmosphereDensity = atmo and tonumber(ReadProperty(atmo, "Density", 0)) or 0
    Sense.atmosphereHaze = atmo and tonumber(ReadProperty(atmo, "Haze", 0)) or 0
    Sense.atmosphereGlare = atmo and tonumber(ReadProperty(atmo, "Glare", 0)) or 0

    Sense.fogColor = ReadProperty(Lighting, "FogColor", Sense.fogColor)
    if atmo then
        local atmoColor = ReadProperty(atmo, "Color", Sense.fogColor)
        Sense.fogColor = ColorLerp(Sense.fogColor, atmoColor, 0.35)
    end

    Sense.indoor = EstimateIndoor(camera)
    Sense.skyVisible = not Sense.indoor
    Sense.localLightEnergy, Sense.localLightColor = SampleLocalLights(camera)
    Sense.wet = EstimateWetness(camera)

    if lastCameraPosition then
        local deltaPos = camera.CFrame.Position - lastCameraPosition
        Sense.cameraSpeed = LerpNumber(Sense.cameraSpeed, deltaPos.Magnitude / math.max(dt, 0.001), 0.35)
    end
    lastCameraPosition = camera.CFrame.Position
    Sense.learned = true
end

--========================================================--
-- POST PROCESS EFFECTS
--========================================================--

local Bloom
local ColorCorrection
local DepthOfField
local SunRays
local AdaptiveAtmosphere

local function CreateEffect(className, name)
    local camera = GetCamera()
    if not camera then
        return nil
    end

    local existing = camera:FindFirstChild(name)
    if existing and existing:IsA(className) then
        return existing
    end

    local effect = Instance.new(className)
    effect.Name = name
    effect.Parent = camera
    TrackObject(effect)
    return effect
end

local function EnsureEffects()
    Bloom = CreateEffect("BloomEffect", PREFIX .. "Bloom")
    ColorCorrection = CreateEffect("ColorCorrectionEffect", PREFIX .. "ColorCorrection")
    DepthOfField = CreateEffect("DepthOfFieldEffect", PREFIX .. "DepthOfField")
    SunRays = CreateEffect("SunRaysEffect", PREFIX .. "SunRays")

    if not OriginalAtmosphere then
        AdaptiveAtmosphere = Lighting:FindFirstChild(PREFIX .. "Atmosphere")
        if not AdaptiveAtmosphere then
            AdaptiveAtmosphere = Instance.new("Atmosphere")
            AdaptiveAtmosphere.Name = PREFIX .. "Atmosphere"
            AdaptiveAtmosphere.Parent = Lighting
            TrackObject(AdaptiveAtmosphere)
        end
    else
        AdaptiveAtmosphere = OriginalAtmosphere
    end
end

EnsureEffects()

--========================================================--
-- PBR / MATERIAL ANALYSIS
--========================================================--

local OriginalPBR = {}
local PBRQueue = {}
local PBRQueued = {}
local PBRHead = 1
local PBRTail = 0
local PBRActive = 0
local PBRScanGeneration = 0
local PBRScanning = false
local PBRRealCount = 0
local PBRHeuristicCount = 0

local REFLECTIVE = {
    "metal", "metallic", "chrome", "mirror", "mirrored", "steel", "iron",
    "aluminum", "aluminium", "silver", "gold", "copper", "brass", "tin",
    "foil", "diamondplate", "polished", "gloss", "glossy", "ceramic",
    "porcelain", "marble", "granite", "glass", "crystal", "ice",
}

local MATTE = {
    "matte", "rough", "fabric", "cloth", "carpet", "felt", "rubber", "mud",
    "dirt", "sand", "soil", "grass", "leaf", "leaves", "foliage", "snow",
    "concrete", "asphalt", "stone", "rock", "paper", "cardboard",
}

local function GetCharacter()
    return Player.Character
end

local function IsPlayerPart(part)
    local character = GetCharacter()
    return character and part:IsDescendantOf(character) or false
end

local function IsIgnoredPBR(part)
    if not part or not part:IsA("BasePart") then
        return true
    end
    if part.Transparency >= 1 then
        return true
    end
    if IsPlayerPart(part) then
        return true
    end
    if part:GetAttribute("TBAMGVIgnorePBR") == true then
        return true
    end
    local parent = part.Parent
    if parent and parent:GetAttribute("TBAMGVIgnorePBR") == true then
        return true
    end
    if State.MirrorWorld then
        return true
    end
    return false
end

local function GetSurfaceAppearance(part)
    for _, child in ipairs(part:GetChildren()) do
        if child:IsA("SurfaceAppearance") then
            return child
        end
    end
    return nil
end

local function AuditRealPBR(surface)
    if not surface then
        return false
    end

    local hasNormal = false
    local hasMetal = false
    local hasRough = false
    local hasColor = false

    pcall(function()
        hasNormal = tostring(surface.NormalMap or "") ~= ""
        hasMetal = tostring(surface.MetalnessMap or "") ~= ""
        hasRough = tostring(surface.RoughnessMap or "") ~= ""
        hasColor = tostring(surface.ColorMap or "") ~= ""
    end)

    return hasNormal or hasMetal or hasRough or hasColor
end

local function MaterialReflectance(part)
    local material = part.Material
    local value = 0.04

    local map = {
        [Enum.Material.Metal] = 0.72,
        [Enum.Material.CorrodedMetal] = 0.42,
        [Enum.Material.DiamondPlate] = 0.5,
        [Enum.Material.Foil] = 0.78,
        [Enum.Material.Glass] = 0.62,
        [Enum.Material.Ice] = 0.52,
        [Enum.Material.Marble] = 0.27,
        [Enum.Material.Granite] = 0.15,
        [Enum.Material.SmoothPlastic] = 0.18,
        [Enum.Material.Plastic] = 0.10,
        [Enum.Material.Brick] = 0.035,
        [Enum.Material.Concrete] = 0.025,
        [Enum.Material.Asphalt] = 0.03,
        [Enum.Material.Slate] = 0.045,
        [Enum.Material.Sand] = 0.012,
        [Enum.Material.Grass] = 0.018,
        [Enum.Material.LeafyGrass] = 0.018,
        [Enum.Material.Snow] = 0.025,
        [Enum.Material.Mud] = 0.02,
        [Enum.Material.Fabric] = 0.008,
        [Enum.Material.Wood] = 0.055,
        [Enum.Material.WoodPlanks] = 0.055,
        [Enum.Material.Ceramic] = 0.22,
        [Enum.Material.Neon] = 0.16,
    }

    value = map[material] or value

    local name = string.lower(part.Name or "")
    if StringHasAny(name, REFLECTIVE) then
        value = math.max(value, 0.58)
    elseif StringHasAny(name, MATTE) then
        value = math.min(value, 0.035)
    end

    local color = part.Color
    local luminance = 0.2126 * color.R + 0.7152 * color.G + 0.0722 * color.B
    if luminance < 0.08 then
        value *= 0.92
    end

    if State.WetnessAssist and Sense.wet > 0 then
        local matte = material == Enum.Material.Concrete
            or material == Enum.Material.Asphalt
            or material == Enum.Material.Slate
            or material == Enum.Material.Brick
            or material == Enum.Material.Ground
        if matte then
            value = LerpNumber(value, 0.10, Sense.wet * 0.65)
        end
    end

    return math.clamp(value * State.PBRStrength * Sense.qualityScale, 0, 0.86)
end

local function GetPBRDistance(part)
    local camera = GetCamera()
    if not camera then
        return math.huge
    end
    return (part.Position - camera.CFrame.Position).Magnitude
end

local function QueuePBR(part)
    if not State.AdaptivePBR or IsIgnoredPBR(part) then
        return
    end

    if PBRQueued[part] then
        return
    end

    if PBRActive >= Limits.PBRMaxParts then
        return
    end

    local dist = GetPBRDistance(part)
    if dist < Limits.PBRMinDistance or dist > Limits.PBRMaxDistance * Sense.qualityScale then
        return
    end

    PBRTail += 1
    PBRQueue[PBRTail] = part
    PBRQueued[part] = true
end

local function ClearPBRQueue()
    table.clear(PBRQueue)
    table.clear(PBRQueued)
    PBRHead = 1
    PBRTail = 0
end

local function RestorePBRPart(part)
    local original = OriginalPBR[part]
    if not original then
        return
    end

    if part and part.Parent and part:IsA("BasePart") then
        if original.AppliedReflectance == nil or math.abs(part.Reflectance - original.AppliedReflectance) < 0.025 then
            SafeProperty(part, "Reflectance", original.Reflectance)
        end
    end
end

local function RestoreAllPBR()
    PBRScanGeneration += 1
    PBRScanning = false
    ClearPBRQueue()

    for part in pairs(OriginalPBR) do
        RestorePBRPart(part)
    end

    table.clear(OriginalPBR)
    PBRActive = 0
    PBRRealCount = 0
    PBRHeuristicCount = 0
end

local function ApplyPBR(part)
    if not State.AdaptivePBR or IsIgnoredPBR(part) then
        return false
    end

    local distance = GetPBRDistance(part)
    if distance < Limits.PBRMinDistance or distance > Limits.PBRMaxDistance * Sense.qualityScale then
        return false
    end

    local surface = GetSurfaceAppearance(part)
    if surface and AuditRealPBR(surface) then
        PBRRealCount += 1
        return false
    end

    if OriginalPBR[part] == nil then
        OriginalPBR[part] = {
            Reflectance = part.Reflectance,
            AppliedReflectance = nil,
        }
    end

    local target = MaterialReflectance(part)
    SafeProperty(part, "Reflectance", target)
    OriginalPBR[part].AppliedReflectance = target
    return true
end

local function CullPBRByDistance()
    if not State.AdaptivePBR then
        return
    end

    local camera = GetCamera()
    if not camera then
        return
    end

    local maxDistance = Limits.PBRMaxDistance * Sense.qualityScale
    for part, original in pairs(OriginalPBR) do
        if not part or not part.Parent or not part:IsA("BasePart") then
            OriginalPBR[part] = nil
            PBRActive = math.max(PBRActive - 1, 0)
        else
            local distance = (part.Position - camera.CFrame.Position).Magnitude
            if distance > maxDistance * 1.08 then
                if math.abs(part.Reflectance - (original.AppliedReflectance or -999)) < 0.025 then
                    SafeProperty(part, "Reflectance", original.Reflectance)
                end
                OriginalPBR[part] = nil
                PBRActive = math.max(PBRActive - 1, 0)
            end
        end
    end
    PBRHeuristicCount = PBRActive
end

local function ProcessPBRQueue()
    if PBRScanning or not State.AdaptivePBR then
        return
    end
    if PBRHead > PBRTail then
        return
    end

    PBRScanning = true
    local generation = PBRScanGeneration

    task.spawn(function()
        while Alive and generation == PBRScanGeneration and State.AdaptivePBR and PBRHead <= PBRTail do
            local processed = 0
            local batch = math.max(16, math.floor(Limits.PBRBatch * Sense.qualityScale))

            while processed < batch and PBRHead <= PBRTail and PBRActive < Limits.PBRMaxParts do
                local part = PBRQueue[PBRHead]
                PBRQueue[PBRHead] = nil
                PBRHead += 1
                PBRQueued[part] = nil

                if part and part.Parent then
                    if ApplyPBR(part) then
                        PBRActive += 1
                    end
                end

                processed += 1
            end

            PBRHeuristicCount = PBRActive
            task.wait(0.018 + (1 - Sense.qualityScale) * 0.045)
        end

        PBRHeuristicCount = PBRActive
        PBRScanning = false
    end)
end

local function StartPBRScan()
    if PBRScanning or not State.AdaptivePBR then
        return
    end

    PBRScanGeneration += 1
    PBRScanning = true
    ClearPBRQueue()
    PBRRealCount = 0

    local generation = PBRScanGeneration

    task.spawn(function()
        local descendants = Workspace:GetDescendants()
        for _, object in ipairs(descendants) do
            if not Alive or generation ~= PBRScanGeneration or not State.AdaptivePBR then
                break
            end
            if object:IsA("BasePart") then
                QueuePBR(object)
            end
            if PBRHead > PBRTail - 250 then
                task.wait()
            end
        end

        PBRScanning = false
        ProcessPBRQueue()
    end)
end

local function EnableProceduralPBR()
    State.AdaptivePBR = true
    StartPBRScan()
end

local function DisableProceduralPBR()
    State.AdaptivePBR = false
    RestoreAllPBR()
end

--========================================================--
-- MIRROR EXPERIMENT
--========================================================--

local OriginalMirror = {}
local MirrorConnection

local function ApplyMirrorPart(part)
    if not State.MirrorWorld or not part:IsA("BasePart") or IsPlayerPart(part) then
        return
    end
    if part.Transparency >= 1 then
        return
    end

    local camera = GetCamera()
    if camera and (part.Position - camera.CFrame.Position).Magnitude > Limits.MirrorMaxDistance * Sense.qualityScale then
        return
    end

    local surface = GetSurfaceAppearance(part)
    if surface and AuditRealPBR(surface) then
        return
    end

    if OriginalMirror[part] == nil then
        OriginalMirror[part] = part.Reflectance
    end

    local base = MaterialReflectance(part)
    SafeProperty(part, "Reflectance", math.max(0.55, math.min(0.86, base + 0.35)))
end

local function EnableMirrorWorld()
    if State.MirrorWorld then
        return
    end

    State.MirrorWorld = true
    for _, object in ipairs(Workspace:GetDescendants()) do
        ApplyMirrorPart(object)
    end

    MirrorConnection = Workspace.DescendantAdded:Connect(function(object)
        if State.MirrorWorld then
            task.defer(function()
                if Alive then
                    ApplyMirrorPart(object)
                end
            end)
        end
    end)
    TrackConnection(MirrorConnection)
end

local function DisableMirrorWorld()
    State.MirrorWorld = false
    SafeDisconnect(MirrorConnection)
    MirrorConnection = nil

    for part, value in pairs(OriginalMirror) do
        if part and part.Parent and part:IsA("BasePart") then
            SafeProperty(part, "Reflectance", value)
        end
    end
    table.clear(OriginalMirror)
end

--========================================================--
-- LIGHTING OWNERSHIP / NATIVE ROBLOX RENDERING
--========================================================--

local function EnableRealisticLighting()
    State.RealisticLighting = true
    pcall(function()
        Lighting.LightingStyle = Enum.LightingStyle.Realistic
    end)
    SafeProperty(Lighting, "EnvironmentDiffuseScale", 1)
    SafeProperty(Lighting, "EnvironmentSpecularScale", 1)
    pcall(function()
        Lighting.PrioritizeLightingQuality = true
    end)
end

local function DisableRealisticLighting()
    State.RealisticLighting = false
    SafeProperty(Lighting, "EnvironmentDiffuseScale", Original.Lighting.EnvironmentDiffuseScale)
    SafeProperty(Lighting, "EnvironmentSpecularScale", Original.Lighting.EnvironmentSpecularScale)
    if Original.Lighting.LightingStyle ~= nil then
        pcall(function()
            Lighting.LightingStyle = Original.Lighting.LightingStyle
        end)
    end
    if Original.Lighting.PrioritizeLightingQuality ~= nil then
        pcall(function()
            Lighting.PrioritizeLightingQuality = Original.Lighting.PrioritizeLightingQuality
        end)
    end
end

local function ApplyNativeLighting()
    SafeProperty(Lighting, "GlobalShadows", State.Shadows)
    SafeProperty(Lighting, "ShadowSoftness", State.ShadowSoftness or 0.22)

    if State.RealisticLighting or State.DynamicReflections or State.UltraWater or State.DynamicShadows then
        EnableRealisticLighting()
    else
        DisableRealisticLighting()
    end

    if State.DynamicReflections then
        SafeProperty(Lighting, "EnvironmentDiffuseScale", 1)
        SafeProperty(Lighting, "EnvironmentSpecularScale", 1)
    end
end

--========================================================--
-- ADAPTIVE SHADER
--========================================================--

local function EnsureAtmosphereForShader()
    if OriginalAtmosphere and OriginalAtmosphere.Parent then
        AdaptiveAtmosphere = OriginalAtmosphere
        return AdaptiveAtmosphere
    end

    if not AdaptiveAtmosphere or not AdaptiveAtmosphere.Parent then
        AdaptiveAtmosphere = Instance.new("Atmosphere")
        AdaptiveAtmosphere.Name = PREFIX .. "Atmosphere"
        AdaptiveAtmosphere.Parent = Lighting
        TrackObject(AdaptiveAtmosphere)
    end

    return AdaptiveAtmosphere
end

local function ComputeAdaptiveValues()
    local fog = State.AdaptiveFog and Sense.fogFactor or 0
    local night = Sense.night
    local sunset = Sense.sunset
    local indoor = Sense.indoor and 1 or 0
    local localLight = Sense.localLightEnergy

    local fogContrastLoss = fog * 0.045
    local targetContrast = State.Contrast + (1 - fog) * 0.02 - fogContrastLoss
    targetContrast = math.clamp(targetContrast, -0.05, 0.16)

    local targetSaturation = State.Saturation - fog * 0.055
    if night > 0.6 then
        targetSaturation -= 0.015
    end
    targetSaturation = math.clamp(targetSaturation, -0.15, 0.18)

    local baseTint = Color3.new(1, 1, 1)
    local environmentalTint = Sense.fogColor
    if indoor > 0 then
        environmentalTint = ColorLerp(environmentalTint, Color3.new(1, 1, 1), 0.45)
    end
    baseTint = ColorLerp(baseTint, environmentalTint, 0.06 + fog * 0.06 + sunset * 0.025)
    if night > 0.55 then
        baseTint = ColorLerp(baseTint, Color3.fromRGB(190, 215, 255), 0.055)
    end

    local baseBloom = State.BloomIntensity
    local scatter = fog * 0.30 + Sense.atmosphereHaze * 0.035
    local daylight = Sense.daylight
    local bloom = baseBloom * (0.65 + daylight * 0.35) + scatter * 0.025
    if indoor > 0 then
        bloom *= 0.82
    end
    if Sense.qualityScale < 0.65 then
        bloom *= Sense.qualityScale
    end

    local rays = 0.10 * (0.30 + daylight * 0.70) * (0.55 + fog * 0.85)
    rays += sunset * 0.025
    rays = math.clamp(rays, 0, 0.20)

    local exposureCorrection = 0
    if State.AdaptiveExposure then
        local ambient = ReadProperty(Lighting, "Ambient", Color3.new(0.5, 0.5, 0.5))
        local outdoor = ReadProperty(Lighting, "OutdoorAmbient", Color3.new(0.5, 0.5, 0.5))
        local brightness = tonumber(ReadProperty(Lighting, "Brightness", 2)) or 2
        local ambientLum =
            0.2126 * ambient.R +
            0.7152 * ambient.G +
            0.0722 * ambient.B
        local outdoorLum =
            0.2126 * outdoor.R +
            0.7152 * outdoor.G +
            0.0722 * outdoor.B

        local targetLum = math.clamp(
            0.22 + ambientLum * 0.30 + outdoorLum * 0.25 + brightness * 0.06 + localLight * 0.10 - fog * 0.07,
            0.12,
            0.72
        )

        local error = targetLum - averageLuminance
        averageLuminance = LerpNumber(averageLuminance, targetLum, 0.12)
        exposureCorrection = math.clamp(-error * 0.70, -0.35, 0.25)
    end

    -- Fog increases aerial perspective, so keep far DOF modest instead of blurring everything.
    local farDOF = State.DOFFar * (0.55 + fog * 0.55)
    local nearDOF = State.DOFNear * (0.55 + Sense.cameraSpeed / 60)

    return {
        Contrast = targetContrast,
        Saturation = targetSaturation,
        TintColor = baseTint,
        Bloom = math.clamp(bloom, 0, 0.35),
        SunRays = rays,
        Exposure = math.clamp(State.Exposure + exposureCorrection, -0.35, 0.35),
        DOFFar = math.clamp(farDOF, 0, 0.22),
        DOFNear = math.clamp(nearDOF, 0, 0.16),
        FogDensity = math.clamp(State.AtmosphereDensity * (0.12 + fog * 0.88) + fog * 0.060, 0, 0.35),
        FogHaze = math.clamp(State.AtmosphereHaze * (0.15 + fog * 0.85) + fog * 0.35, 0, 2.8),
        FogGlare = math.clamp(State.AtmosphereGlare * (0.50 + Sense.daylight * 0.50) + fog * 0.006, 0, 0.10),
    }
end

local function ApplyShaders()
    EnsureEffects()

    if not Bloom or not ColorCorrection or not DepthOfField or not SunRays then
        return
    end

    if not State.Shaders then
        Bloom.Enabled = false
        ColorCorrection.Enabled = false
        DepthOfField.Enabled = false
        SunRays.Enabled = false

        if not OriginalAtmosphere and AdaptiveAtmosphere and AdaptiveAtmosphere.Name == PREFIX .. "Atmosphere" then
            SafeDestroy(AdaptiveAtmosphere)
            AdaptiveAtmosphere = nil
        end
        return
    end

    local adaptive = ComputeAdaptiveValues()

    Bloom.Enabled = State.Bloom and Sense.qualityScale > 0.35
    Bloom.Intensity = adaptive.Bloom
    Bloom.Size = math.clamp(State.BloomSize, 2, 56)
    Bloom.Threshold = 0.90

    ColorCorrection.Enabled = State.ColorCorrection
    ColorCorrection.Saturation = adaptive.Saturation
    ColorCorrection.Contrast = adaptive.Contrast
    ColorCorrection.Brightness = State.Brightness
    ColorCorrection.TintColor = adaptive.TintColor

    DepthOfField.Enabled = State.DOF and (not State.AutoQuality or Sense.qualityScale > 0.52)
    DepthOfField.FarIntensity = adaptive.DOFFar
    DepthOfField.NearIntensity = adaptive.DOFNear
    DepthOfField.FocusDistance = math.clamp(
        State.AutoFocus and Sense.targetDistance or State.DOFFocus,
        1,
        1000
    )
    DepthOfField.InFocusRadius = math.clamp(18 + Sense.targetDistance * 0.06, 18, 55)

    SunRays.Enabled = State.SunRays and Sense.qualityScale > 0.40
    SunRays.Intensity = adaptive.SunRays
    SunRays.Spread = 0.78

    if State.Atmosphere then
        local atmosphere = EnsureAtmosphereForShader()
        if atmosphere then
            local baseDensity = adaptive.FogDensity
            local baseHaze = adaptive.FogHaze
            local baseGlare = adaptive.FogGlare
            local baseColor = Original.Atmosphere and Original.Atmosphere.Color or Color3.new(1, 1, 1)
            local baseDecay = Original.Atmosphere and Original.Atmosphere.Decay or Color3.new(1, 1, 1)

            -- Keep the game's atmospheric identity instead of replacing it with
            -- a fixed preset. The adaptive component is blended on top.
            if Original.Atmosphere and OriginalAtmosphere == atmosphere then
                local baseline = GameAtmosphereBaseline or Original.Atmosphere
                baseDensity = math.clamp(LerpNumber(baseline.Density, baseDensity, 0.58), 0, 0.40)
                baseHaze = math.clamp(LerpNumber(baseline.Haze, baseHaze, 0.58), 0, 2.8)
                baseGlare = math.clamp(LerpNumber(baseline.Glare, baseGlare, 0.58), 0, 0.10)
                baseColor = baseline.Color or baseColor
                baseDecay = baseline.Decay or baseDecay
            end

            local finalColor = ColorLerp(
                baseColor,
                Sense.fogColor,
                0.07 + Sense.fogFactor * (State.AdaptiveFog and 0.14 or 0)
            )
            local finalDecay = ColorLerp(
                baseDecay,
                Color3.fromRGB(210, 220, 235),
                0.08 + Sense.night * 0.10
            )

            SafeProperty(atmosphere, "Density", baseDensity)
            SafeProperty(atmosphere, "Haze", baseHaze)
            SafeProperty(atmosphere, "Glare", baseGlare)
            SafeProperty(atmosphere, "Offset", Original.Atmosphere and Original.Atmosphere.Offset or 0)
            SafeProperty(atmosphere, "Color", finalColor)
            SafeProperty(atmosphere, "Decay", finalDecay)

            LastTBAMAtmosphere = {
                Density = baseDensity,
                Haze = baseHaze,
                Glare = baseGlare,
                Offset = Original.Atmosphere and Original.Atmosphere.Offset or 0,
            }
        end
    elseif not OriginalAtmosphere and AdaptiveAtmosphere and AdaptiveAtmosphere.Name == PREFIX .. "Atmosphere" then
        SafeProperty(AdaptiveAtmosphere, "Density", 0)
        SafeProperty(AdaptiveAtmosphere, "Haze", 0)
        SafeProperty(AdaptiveAtmosphere, "Glare", 0)
    end

    if State.AdaptiveExposure then
        SafeProperty(Lighting, "ExposureCompensation", adaptive.Exposure)
    else
        SafeProperty(Lighting, "ExposureCompensation", State.Exposure)
    end
end

--========================================================--
-- AUTO FOCUS
--========================================================--

local function UpdateAutoFocus()
    if not State.AutoFocus then
        return
    end

    local camera = GetCamera()
    if not camera then
        return
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {Player.Character}
    params.IgnoreWater = false

    local origin = camera.CFrame.Position
    local direction = camera.CFrame.LookVector * 280
    local result = Workspace:Raycast(origin, direction, params)

    local target = result and result.Distance or 95
    target = math.clamp(target, 6, 220)

    local speedPenalty = math.clamp(Sense.cameraSpeed / 100, 0, 0.18)
    target += speedPenalty * 12
    Sense.targetDistance = LerpNumber(Sense.targetDistance, target, 0.25)
end

--========================================================--
-- PERFORMANCE LEARNING
--========================================================--

local FrameAccumulator = 0
local FrameSamples = 0
local PerformanceTimer = 0

local function UpdatePerformance(dt)
    FrameAccumulator += dt
    FrameSamples += 1

    if FrameSamples >= 18 then
        local average = FrameAccumulator / FrameSamples
        Sense.averageFrame = LerpNumber(Sense.averageFrame, average, 0.35)
        Sense.fps = 1 / math.max(Sense.averageFrame, 0.001)
        FrameAccumulator = 0
        FrameSamples = 0
    end

    if not State.AutoQuality then
        Sense.qualityScale = 1
        return
    end

    PerformanceTimer += dt
    if PerformanceTimer < Limits.PerformanceInterval then
        return
    end
    PerformanceTimer = 0

    local fps = Sense.fps
    local target = 58
    local scale = 1

    if fps < 28 then
        scale = 0.45
    elseif fps < 34 then
        scale = 0.58
    elseif fps < 42 then
        scale = 0.72
    elseif fps < 50 then
        scale = 0.84
    elseif fps < target then
        scale = 0.94
    end

    if Sense.indoor then
        scale = math.min(1, scale + 0.05)
    end

    Sense.qualityScale = LerpNumber(Sense.qualityScale, scale, 0.45)
end

--========================================================--
-- CONTACT SHADOW ASSIST (OPTIONAL / EXPERIMENTAL)
--========================================================--

local ContactRig
local ContactLight

local function DestroyContactShadowRig()
    ContactLight = nil
    if ContactRig then
        SafeDestroy(ContactRig)
        ContactRig = nil
    end
end

local function CreateContactShadowRig()
    if ContactRig and ContactRig.Parent and ContactLight then
        return
    end

    local character = GetCharacter()
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end

    local part = Instance.new("Part")
    part.Name = PREFIX .. "ContactShadowRig"
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    part.Transparency = 1
    part.Size = Vector3.new(0.2, 0.2, 0.2)
    part.Parent = Workspace
    TrackObject(part)

    local light = Instance.new("SpotLight")
    light.Name = PREFIX .. "ContactShadowLight"
    light.Enabled = true
    light.Brightness = 0.045
    light.Range = 22
    light.Angle = 105
    light.Shadows = true
    light.Color = Color3.fromRGB(255, 246, 232)
    light.Parent = part
    TrackObject(light)

    ContactRig = part
    ContactLight = light
end

local function UpdateContactShadowRig()
    if not State.DynamicShadows then
        return
    end
    if Sense.qualityScale < 0.62 then
        if ContactLight then
            ContactLight.Enabled = false
        end
        return
    end

    CreateContactShadowRig()
    if not ContactRig or not ContactLight then
        return
    end

    local character = GetCharacter()
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end

    ContactRig.CFrame = CFrame.new(root.Position + Vector3.new(0, 12, 0))
    ContactLight.Enabled = true
end

--========================================================--
-- WATER
--========================================================--

local function EnableUltraWater()
    Terrain = Workspace:FindFirstChildOfClass("Terrain")
    if not Terrain then
        return
    end

    State.UltraWater = true
    State.DynamicReflections = true
    EnableRealisticLighting()

    local strength = math.clamp(State.WaterStrength, 0, 1)
    SafeProperty(Terrain, "WaterColor", ColorLerp(
        Original.Water and Original.Water.WaterColor or Terrain.WaterColor,
        Color3.fromRGB(58, 155, 190),
        0.55 * strength
    ))
    SafeProperty(Terrain, "WaterReflectance", math.clamp(
        (Original.Water and Original.Water.WaterReflectance or Terrain.WaterReflectance) * 0.35 + 0.70 * strength,
        0,
        1
    ))
    SafeProperty(Terrain, "WaterTransparency", LerpNumber(
        Original.Water and Original.Water.WaterTransparency or Terrain.WaterTransparency,
        0.18,
        0.55 * strength
    ))
    SafeProperty(Terrain, "WaterWaveSize", LerpNumber(
        Original.Water and Original.Water.WaterWaveSize or Terrain.WaterWaveSize,
        0.75,
        0.45 * strength
    ))
    SafeProperty(Terrain, "WaterWaveSpeed", LerpNumber(
        Original.Water and Original.Water.WaterWaveSpeed or Terrain.WaterWaveSpeed,
        38,
        0.45 * strength
    ))
end

local function DisableUltraWater()
    State.UltraWater = false
    if not Terrain or not Original.Water then
        return
    end

    SafeProperty(Terrain, "WaterColor", Original.Water.WaterColor)
    SafeProperty(Terrain, "WaterReflectance", Original.Water.WaterReflectance)
    SafeProperty(Terrain, "WaterTransparency", Original.Water.WaterTransparency)
    SafeProperty(Terrain, "WaterWaveSize", Original.Water.WaterWaveSize)
    SafeProperty(Terrain, "WaterWaveSpeed", Original.Water.WaterWaveSpeed)
end

--========================================================--
-- PRESETS / SKY-LIKE LIGHTING MOODS
--========================================================--

local function ApplyPreset(name)
    local preset = PRESET[name]
    if not preset then
        return
    end

    State.SelectedPreset = name
    for key, value in pairs(preset) do
        State[key] = value
    end

    State.Shaders = true
    State.ShadowSoftness = ({LOW = 0.90, MEDIUM = 0.45, HIGH = 0.28, ULTRA = 0.15})[name] or 0.28

    ApplyNativeLighting()
    ApplyShaders()
end

local function ApplyLightingMood(name)
    State.SelectedSky = name

    if name == "Original" then
        SafeProperty(Lighting, "ClockTime", Original.Lighting.ClockTime)
        SafeProperty(Lighting, "Ambient", Original.Lighting.Ambient)
        SafeProperty(Lighting, "OutdoorAmbient", Original.Lighting.OutdoorAmbient)
        SafeProperty(Lighting, "ColorShift_Top", Original.Lighting.ColorShiftTop)
        SafeProperty(Lighting, "ColorShift_Bottom", Original.Lighting.ColorShiftBottom)
        return
    end

    if name == "Day" then
        SafeProperty(Lighting, "ClockTime", 12.5)
        SafeProperty(Lighting, "Ambient", Color3.fromRGB(125, 125, 125))
        SafeProperty(Lighting, "OutdoorAmbient", Color3.fromRGB(155, 155, 155))
        SafeProperty(Lighting, "ColorShift_Top", Color3.fromRGB(205, 225, 255))
        SafeProperty(Lighting, "ColorShift_Bottom", Color3.fromRGB(255, 255, 255))
    elseif name == "Sunset" then
        SafeProperty(Lighting, "ClockTime", 18.25)
        SafeProperty(Lighting, "Ambient", Color3.fromRGB(118, 104, 100))
        SafeProperty(Lighting, "OutdoorAmbient", Color3.fromRGB(165, 138, 125))
        SafeProperty(Lighting, "ColorShift_Top", Color3.fromRGB(255, 176, 128))
        SafeProperty(Lighting, "ColorShift_Bottom", Color3.fromRGB(255, 205, 165))
    elseif name == "Night" then
        SafeProperty(Lighting, "ClockTime", 0.25)
        SafeProperty(Lighting, "Ambient", Color3.fromRGB(32, 40, 58))
        SafeProperty(Lighting, "OutdoorAmbient", Color3.fromRGB(50, 60, 85))
        SafeProperty(Lighting, "ColorShift_Top", Color3.fromRGB(92, 112, 155))
        SafeProperty(Lighting, "ColorShift_Bottom", Color3.fromRGB(30, 38, 55))
    elseif name == "Dawn" then
        SafeProperty(Lighting, "ClockTime", 6.1)
        SafeProperty(Lighting, "Ambient", Color3.fromRGB(104, 108, 115))
        SafeProperty(Lighting, "OutdoorAmbient", Color3.fromRGB(145, 135, 132))
        SafeProperty(Lighting, "ColorShift_Top", Color3.fromRGB(255, 200, 165))
        SafeProperty(Lighting, "ColorShift_Bottom", Color3.fromRGB(205, 215, 235))
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
    State.RealisticLighting = false
    State.Shadows = Original.Lighting.GlobalShadows
    State.AdaptiveFog = true
    State.AdaptiveExposure = true
    State.AutoFocus = true
    State.AdaptivePBR = false
    State.AutoQuality = true
    State.DynamicReflections = false
    State.DynamicShadows = false
    State.UltraWater = false
    State.MirrorWorld = false

    DisableMirrorWorld()
    DisableUltraWater()
    DestroyContactShadowRig()
    RestoreAllPBR()

    SafeProperty(Lighting, "GlobalShadows", Original.Lighting.GlobalShadows)
    SafeProperty(Lighting, "Brightness", Original.Lighting.Brightness)
    SafeProperty(Lighting, "ExposureCompensation", Original.Lighting.ExposureCompensation)
    SafeProperty(Lighting, "ShadowSoftness", Original.Lighting.ShadowSoftness)
    SafeProperty(Lighting, "Ambient", Original.Lighting.Ambient)
    SafeProperty(Lighting, "OutdoorAmbient", Original.Lighting.OutdoorAmbient)
    SafeProperty(Lighting, "ColorShift_Top", Original.Lighting.ColorShiftTop)
    SafeProperty(Lighting, "ColorShift_Bottom", Original.Lighting.ColorShiftBottom)
    SafeProperty(Lighting, "ClockTime", Original.Lighting.ClockTime)
    SafeProperty(Lighting, "FogColor", Original.Lighting.FogColor)
    SafeProperty(Lighting, "FogStart", Original.Lighting.FogStart)
    SafeProperty(Lighting, "FogEnd", Original.Lighting.FogEnd)
    SafeProperty(Lighting, "EnvironmentDiffuseScale", Original.Lighting.EnvironmentDiffuseScale)
    SafeProperty(Lighting, "EnvironmentSpecularScale", Original.Lighting.EnvironmentSpecularScale)

    if Original.Lighting.LightingStyle ~= nil then
        pcall(function()
            Lighting.LightingStyle = Original.Lighting.LightingStyle
        end)
    end

    if Original.Lighting.PrioritizeLightingQuality ~= nil then
        pcall(function()
            Lighting.PrioritizeLightingQuality = Original.Lighting.PrioritizeLightingQuality
        end)
    end

    if Original.Atmosphere and Original.Atmosphere.Instance and Original.Atmosphere.Instance.Parent then
        local atmosphere = Original.Atmosphere.Instance
        SafeProperty(atmosphere, "Density", Original.Atmosphere.Density)
        SafeProperty(atmosphere, "Haze", Original.Atmosphere.Haze)
        SafeProperty(atmosphere, "Glare", Original.Atmosphere.Glare)
        SafeProperty(atmosphere, "Offset", Original.Atmosphere.Offset)
        SafeProperty(atmosphere, "Color", Original.Atmosphere.Color)
        SafeProperty(atmosphere, "Decay", Original.Atmosphere.Decay)
    elseif AdaptiveAtmosphere and AdaptiveAtmosphere.Name == PREFIX .. "Atmosphere" then
        SafeDestroy(AdaptiveAtmosphere)
        AdaptiveAtmosphere = nil
    end

    if Original.Water and Terrain and Terrain.Parent then
        SafeProperty(Terrain, "WaterColor", Original.Water.WaterColor)
        SafeProperty(Terrain, "WaterReflectance", Original.Water.WaterReflectance)
        SafeProperty(Terrain, "WaterTransparency", Original.Water.WaterTransparency)
        SafeProperty(Terrain, "WaterWaveSize", Original.Water.WaterWaveSize)
        SafeProperty(Terrain, "WaterWaveSpeed", Original.Water.WaterWaveSpeed)
    end

    if Bloom then Bloom.Enabled = false end
    if ColorCorrection then ColorCorrection.Enabled = false end
    if DepthOfField then DepthOfField.Enabled = false end
    if SunRays then SunRays.Enabled = false end

    if RefreshAllControls then
        RefreshAllControls()
    end
end

--========================================================--
-- RUNTIME LOOP
--========================================================--

local SenseTimer = 0
local ShaderTimer = 0
local FocusTimer = 0
local PBRTimer = 0
local PBRCullTimer = 0

local RuntimeConnection = RunService.Heartbeat:Connect(function(dt)
    if not Alive then
        return
    end

    UpdatePerformance(dt)

    SenseTimer += dt
    if SenseTimer >= Limits.SenseInterval then
        SenseTimer = 0
        UpdateSense(dt)
    end

    FocusTimer += dt
    if FocusTimer >= Limits.FocusInterval then
        FocusTimer = 0
        UpdateAutoFocus()
    end

    PBRCullTimer += dt
    if PBRCullTimer >= 1.15 then
        PBRCullTimer = 0
        CullPBRByDistance()
    end

    PBRTimer += dt
    if PBRTimer >= Limits.PBRInterval then
        PBRTimer = 0
        if State.AdaptivePBR and not PBRScanning and PBRHead <= PBRTail and PBRActive < Limits.PBRMaxParts then
            ProcessPBRQueue()
        end
    end

    ShaderTimer += dt
    if ShaderTimer >= Limits.UpdateInterval then
        ShaderTimer = 0
        ApplyNativeLighting()
        if State.Shaders then
            ApplyShaders()
        end
        if State.DynamicShadows then
            UpdateContactShadowRig()
        elseif ContactRig then
            DestroyContactShadowRig()
        end
    end
end)
TrackConnection(RuntimeConnection)

TrackConnection(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    task.defer(function()
        if Alive then
            EnsureEffects()
            ApplyShaders()
        end
    end)
end))

TrackConnection(Player.CharacterAdded:Connect(function()
    task.wait(1)
    if not Alive then
        return
    end
    if State.AdaptivePBR then
        StartPBRScan()
    end
end))

--========================================================--
-- GUI HELPERS
--========================================================--

local function Tween(instance, properties, info)
    local ok, tween = pcall(function()
        return TweenService:Create(instance, info or TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), properties)
    end)
    if ok and tween then
        return tween
    end
    return nil
end

local function Round(instance, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = instance
    return corner
end

local function AddStroke(instance, color, transparency, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Transparency = transparency or 0
    stroke.Thickness = thickness or 1
    stroke.Parent = instance
    return stroke
end

local function MakeLabel(parent, text, size, color, bold)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color or UI.Text
    label.TextSize = size or 13
    label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Parent = parent
    return label
end

local OldGui = PlayerGui:FindFirstChild(MENU_NAME)
if OldGui then
    SafeDestroy(OldGui)
end

local OldEffectNames = {
    PREFIX .. "Bloom",
    PREFIX .. "ColorCorrection",
    PREFIX .. "DepthOfField",
    PREFIX .. "SunRays",
}
for _, camera in ipairs({Workspace.CurrentCamera}) do
    if camera then
        for _, name in ipairs(OldEffectNames) do
            local old = camera:FindFirstChild(name)
            if old then
                SafeDestroy(old)
            end
        end
    end
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = MENU_NAME
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui
TrackObject(ScreenGui)

local Backdrop = Instance.new("Frame")
Backdrop.Size = UDim2.fromScale(1, 1)
Backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
Backdrop.BackgroundTransparency = 0.48
Backdrop.BorderSizePixel = 0
Backdrop.Visible = false
Backdrop.Parent = ScreenGui

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.Position = UDim2.fromScale(0.5, 0.5)
Main.Size = UDim2.fromScale(0.82, 0.78)
Main.BackgroundColor3 = UI.Glass
Main.BackgroundTransparency = 0.10
Main.BorderSizePixel = 0
Main.Visible = false
Main.Parent = ScreenGui
Round(Main, 18)
AddStroke(Main, Color3.new(1, 1, 1), 0.90, 1)

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 66)
Header.BackgroundTransparency = 1
Header.Parent = Main

local Title = MakeLabel(Header, "TBAMGV • ADAPTIVE REALISM V7", 16, UI.Text, true)
Title.Position = UDim2.new(0, 18, 0, 8)
Title.Size = UDim2.new(1, -80, 0, 26)

local Status = MakeLabel(Header, "Learning environment...", 11, UI.Subtext, false)
Status.Position = UDim2.new(0, 18, 0, 34)
Status.Size = UDim2.new(1, -80, 0, 20)

local Close = Instance.new("TextButton")
Close.Size = UDim2.fromOffset(38, 38)
Close.Position = UDim2.new(1, -50, 0, 14)
Close.BackgroundColor3 = UI.Glass2
Close.BackgroundTransparency = 0.12
Close.Text = "×"
Close.TextColor3 = UI.Text
Close.TextSize = 22
Close.Font = Enum.Font.GothamBold
Close.AutoButtonColor = false
Close.Parent = Header
Round(Close, 12)

local Scroll = Instance.new("ScrollingFrame")
Scroll.Position = UDim2.new(0, 12, 0, 69)
Scroll.Size = UDim2.new(1, -24, 1, -81)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 3
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.Parent = Main

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 8)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = Scroll

local function CreateSection(text)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -8, 0, 28)
    holder.BackgroundTransparency = 1
    holder.Parent = Scroll

    local label = MakeLabel(holder, text, 11, UI.Subtext, true)
    label.Position = UDim2.new(0, 6, 0, 0)
    label.Size = UDim2.new(1, -12, 1, 0)

    return holder
end

local ToggleRefreshers = {}
local SliderRefreshers = {}
RefreshAllControls = function()
    for _, fn in ipairs(ToggleRefreshers) do
        pcall(fn)
    end
    for _, fn in ipairs(SliderRefreshers) do
        pcall(fn)
    end
end

local function CreateToggle(text, getter, setter)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -8, 0, 49)
    holder.BackgroundColor3 = UI.Glass2
    holder.BackgroundTransparency = 0.22
    holder.BorderSizePixel = 0
    holder.Parent = Scroll
    Round(holder, 11)
    AddStroke(holder, Color3.new(1, 1, 1), 0.95, 1)

    local label = MakeLabel(holder, text, 12, UI.Text, false)
    label.Position = UDim2.new(0, 14, 0, 0)
    label.Size = UDim2.new(1, -86, 1, 0)

    local button = Instance.new("TextButton")
    button.Size = UDim2.fromOffset(52, 27)
    button.Position = UDim2.new(1, -66, 0.5, -13)
    button.BackgroundColor3 = UI.Glass
    button.Text = "OFF"
    button.TextColor3 = UI.Subtext
    button.TextSize = 10
    button.Font = Enum.Font.GothamBold
    button.AutoButtonColor = false
    button.Parent = holder
    Round(button, 13)

    local function refresh()
        local value = getter()
        if value then
            button.Text = "ON"
            button.TextColor3 = Color3.fromRGB(5, 14, 22)
            button.BackgroundColor3 = UI.Accent
        else
            button.Text = "OFF"
            button.TextColor3 = UI.Subtext
            button.BackgroundColor3 = UI.Glass
        end
    end

    TrackConnection(button.Activated:Connect(function()
        local nextValue = not getter()
        setter(nextValue)
        refresh()
    end))

    table.insert(ToggleRefreshers, refresh)
    refresh()
    return holder, refresh
end

local function CreateButton(text)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -8, 0, 46)
    button.BackgroundColor3 = UI.Glass2
    button.BackgroundTransparency = 0.20
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = UI.Text
    button.TextSize = 12
    button.Font = Enum.Font.GothamMedium
    button.AutoButtonColor = false
    button.Parent = Scroll
    Round(button, 11)
    AddStroke(button, Color3.new(1, 1, 1), 0.95, 1)

    TrackConnection(button.MouseEnter:Connect(function()
        button.BackgroundTransparency = 0.05
    end))
    TrackConnection(button.MouseLeave:Connect(function()
        button.BackgroundTransparency = 0.20
    end))

    return button
end

local function CreateSlider(text, minValue, maxValue, getter, setter, decimals)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -8, 0, 72)
    holder.BackgroundColor3 = UI.Glass2
    holder.BackgroundTransparency = 0.22
    holder.BorderSizePixel = 0
    holder.Parent = Scroll
    Round(holder, 11)
    AddStroke(holder, Color3.new(1, 1, 1), 0.95, 1)

    local label = MakeLabel(holder, text, 12, UI.Text, false)
    label.Position = UDim2.new(0, 14, 0, 7)
    label.Size = UDim2.new(1, -92, 0, 18)

    local valueLabel = MakeLabel(holder, "0", 11, UI.Subtext, true)
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Position = UDim2.new(1, -74, 0, 7)
    valueLabel.Size = UDim2.fromOffset(60, 18)

    local bar = Instance.new("Frame")
    bar.Position = UDim2.new(0, 14, 0, 42)
    bar.Size = UDim2.new(1, -28, 0, 7)
    bar.BackgroundColor3 = UI.Glass
    bar.BorderSizePixel = 0
    bar.Parent = holder
    Round(bar, 5)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = UI.Accent
    fill.BorderSizePixel = 0
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.Parent = bar
    Round(fill, 5)

    local knob = Instance.new("Frame")
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Size = UDim2.fromOffset(16, 16)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.Parent = bar
    Round(knob, 8)

    local dragging = false

    local function formatValue(v)
        local power = 10 ^ (decimals or 2)
        v = math.round(v * power) / power
        return tostring(v)
    end

    local function refresh()
        local value = math.clamp(getter(), minValue, maxValue)
        local alpha = (value - minValue) / math.max(maxValue - minValue, 0.0001)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        valueLabel.Text = formatValue(value)
    end

    local function setFromInput(input)
        local x = input.Position.X
        local left = bar.AbsolutePosition.X
        local width = math.max(bar.AbsoluteSize.X, 1)
        local alpha = math.clamp((x - left) / width, 0, 1)
        local value = minValue + (maxValue - minValue) * alpha
        setter(value)
        refresh()
    end

    TrackConnection(holder.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromInput(input)
        end
    end))

    TrackConnection(UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            setFromInput(input)
        end
    end))

    TrackConnection(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))

    table.insert(SliderRefreshers, refresh)
    refresh()
    return holder
end

--========================================================--
-- UI CONTENT
--========================================================--

CreateSection("⚡ PRESETS")

local LowButton = CreateButton("LOW • Performance")
local MediumButton = CreateButton("MEDIUM • Balanced")
local HighButton = CreateButton("HIGH • Adaptive Realism")
local UltraButton = CreateButton("ULTRA • Maximum Adaptive")

TrackConnection(LowButton.Activated:Connect(function() ApplyPreset("LOW"); RefreshAllControls() end))
TrackConnection(MediumButton.Activated:Connect(function() ApplyPreset("MEDIUM"); RefreshAllControls() end))
TrackConnection(HighButton.Activated:Connect(function() ApplyPreset("HIGH"); RefreshAllControls() end))
TrackConnection(UltraButton.Activated:Connect(function() ApplyPreset("ULTRA"); RefreshAllControls() end))

CreateSection("🧠 ADAPTIVE ENGINE")

CreateToggle("Shaders", function() return State.Shaders end, function(v)
    State.Shaders = v
    ApplyShaders()
end)

CreateToggle("Adaptive Fog Response", function() return State.AdaptiveFog end, function(v)
    State.AdaptiveFog = v
end)

CreateToggle("Adaptive Exposure", function() return State.AdaptiveExposure end, function(v)
    State.AdaptiveExposure = v
end)

CreateToggle("Auto Focus • Camera Raycast", function() return State.AutoFocus end, function(v)
    State.AutoFocus = v
end)

CreateToggle("Auto Quality • Learn FPS", function() return State.AutoQuality end, function(v)
    State.AutoQuality = v
    if not v then
        Sense.qualityScale = 1
    end
end)

CreateToggle("Wet Surface Assist", function() return State.WetnessAssist end, function(v)
    State.WetnessAssist = v
end)

CreateSection("💡 NATIVE LIGHTING")

CreateToggle("Realistic Lighting", function() return State.RealisticLighting end, function(v)
    State.RealisticLighting = v
    if v then
        EnableRealisticLighting()
    else
        DisableRealisticLighting()
    end
end)

CreateToggle("Global Shadows", function() return State.Shadows end, function(v)
    State.Shadows = v
    SafeProperty(Lighting, "GlobalShadows", v)
end)

CreateToggle("Dynamic Reflections", function() return State.DynamicReflections end, function(v)
    State.DynamicReflections = v
    ApplyNativeLighting()
end)

CreateToggle("Contact Shadow Assist", function() return State.DynamicShadows end, function(v)
    State.DynamicShadows = v
    -- V7 intentionally avoids a permanent fake sun light. Native GlobalShadows
    -- remains the primary shadow system. This toggle acts as a low-cost quality
    -- preference for shadow-heavy presets rather than injecting a second sun.
    if v then
        State.Shadows = true
        SafeProperty(Lighting, "GlobalShadows", true)
    else
        DestroyContactShadowRig()
    end
end)

CreateSection("✨ POST PROCESS")

CreateToggle("Bloom", function() return State.Bloom end, function(v)
    State.Bloom = v
end)

CreateSlider("Bloom Intensity", 0, 0.4, function() return State.BloomIntensity end, function(v)
    State.BloomIntensity = v
end, 3)

CreateSlider("Bloom Size", 2, 48, function() return State.BloomSize end, function(v)
    State.BloomSize = v
end, 0)

CreateToggle("Color Correction", function() return State.ColorCorrection end, function(v)
    State.ColorCorrection = v
end)

CreateSlider("Saturation", -0.15, 0.20, function() return State.Saturation end, function(v)
    State.Saturation = v
end, 3)

CreateSlider("Contrast", -0.10, 0.20, function() return State.Contrast end, function(v)
    State.Contrast = v
end, 3)

CreateSlider("Manual Exposure", -0.75, 0.75, function() return State.Exposure end, function(v)
    State.Exposure = v
end, 3)

CreateToggle("Depth of Field", function() return State.DOF end, function(v)
    State.DOF = v
end)

CreateSlider("DOF Far", 0, 0.25, function() return State.DOFFar end, function(v)
    State.DOFFar = v
end, 3)

CreateSlider("DOF Near", 0, 0.20, function() return State.DOFNear end, function(v)
    State.DOFNear = v
end, 3)

CreateSlider("Manual Focus Distance", 1, 250, function() return State.DOFFocus end, function(v)
    State.DOFFocus = v
    if not State.AutoFocus and DepthOfField then
        DepthOfField.FocusDistance = v
    end
end, 0)

CreateToggle("Sun Rays", function() return State.SunRays end, function(v)
    State.SunRays = v
end)

CreateSection("🌫️ FOG / ATMOSPHERE")

CreateToggle("Adaptive Atmosphere", function() return State.Atmosphere end, function(v)
    State.Atmosphere = v
end)

CreateSlider("Base Density", 0, 0.40, function() return State.AtmosphereDensity end, function(v)
    State.AtmosphereDensity = v
end, 3)

CreateSlider("Base Haze", 0, 2.80, function() return State.AtmosphereHaze end, function(v)
    State.AtmosphereHaze = v
end, 2)

CreateSlider("Base Glare", 0, 0.10, function() return State.AtmosphereGlare end, function(v)
    State.AtmosphereGlare = v
end, 3)

CreateSection("🧬 PBR")

CreateToggle("Adaptive PBR Assist", function() return State.AdaptivePBR end, function(v)
    State.AdaptivePBR = v
    if v then
        StartPBRScan()
    else
        RestoreAllPBR()
    end
end)

CreateSlider("PBR Reflectivity", 0, 1.15, function() return State.PBRStrength end, function(v)
    State.PBRStrength = v
end, 2)

local PBRInfo = CreateButton("PBR: scanning...")
PBRInfo.TextColor3 = UI.Subtext

CreateSection("🌊 WATER")

CreateToggle("Ultra Water", function() return State.UltraWater end, function(v)
    if v then
        EnableUltraWater()
    else
        DisableUltraWater()
    end
end)

CreateSlider("Water Strength", 0, 1, function() return State.WaterStrength end, function(v)
    State.WaterStrength = v
    if State.UltraWater then
        EnableUltraWater()
    end
end, 2)

CreateSection("🌅 LIGHTING MOODS")

local MoodOriginal = CreateButton("🌎 Original")
local MoodDawn = CreateButton("🌅 Dawn")
local MoodSunset = CreateButton("🌇 Sunset")
local MoodNight = CreateButton("🌙 Night")
local MoodDay = CreateButton("☀ Day")

TrackConnection(MoodOriginal.Activated:Connect(function() ApplyLightingMood("Original") end))
TrackConnection(MoodDawn.Activated:Connect(function() ApplyLightingMood("Dawn") end))
TrackConnection(MoodSunset.Activated:Connect(function() ApplyLightingMood("Sunset") end))
TrackConnection(MoodNight.Activated:Connect(function() ApplyLightingMood("Night") end))
TrackConnection(MoodDay.Activated:Connect(function() ApplyLightingMood("Day") end))

CreateSection("☢️ EXPERIMENTAL")

local MirrorButton = CreateButton("MIRROR WORLD • Experimental")
MirrorButton.TextColor3 = UI.Warning

TrackConnection(MirrorButton.Activated:Connect(function()
    if State.MirrorWorld then
        DisableMirrorWorld()
        MirrorButton.Text = "MIRROR WORLD • Experimental"
    else
        EnableMirrorWorld()
        MirrorButton.Text = "MIRROR WORLD • ACTIVE"
    end
end))

local ResetButton = CreateButton("↺ RESTORE ORIGINAL GRAPHICS")
TrackConnection(ResetButton.Activated:Connect(function()
    ResetOriginal()
    ResetButton.Text = "✓ GRAPHICS RESTORED"
    task.delay(1.5, function()
        if ResetButton and ResetButton.Parent then
            ResetButton.Text = "↺ RESTORE ORIGINAL GRAPHICS"
        end
    end)
end))

CreateSection("📡 GAME LEARNING")

local GameInfo = CreateButton("Game DNA: reading...")
GameInfo.TextColor3 = UI.Subtext

local CapabilityInfo = CreateButton("Capabilities: scanning...")
CapabilityInfo.TextColor3 = UI.Subtext

--========================================================--
-- GUI DRAG / OPEN / CLOSE
--========================================================--

local OpenButton = Instance.new("TextButton")
OpenButton.Name = "OpenButton"
OpenButton.AnchorPoint = Vector2.new(1, 1)
OpenButton.Position = UDim2.new(1, -18, 1, -18)
OpenButton.Size = UDim2.fromOffset(56, 56)
OpenButton.BackgroundColor3 = UI.Glass
OpenButton.BackgroundTransparency = 0.10
OpenButton.BorderSizePixel = 0
OpenButton.Text = "⚙"
OpenButton.TextColor3 = UI.Text
OpenButton.TextSize = 24
OpenButton.Font = Enum.Font.GothamBold
OpenButton.AutoButtonColor = false
OpenButton.Parent = ScreenGui
Round(OpenButton, 18)
AddStroke(OpenButton, Color3.new(1, 1, 1), 0.85, 1)

local Opened = false
local Dragging = false
local DragStart
local StartPosition
local DragDistance = 0

local function OpenMenu()
    Opened = true
    Backdrop.Visible = true
    Main.Visible = true
    OpenButton.Visible = false

    Main.Size = UDim2.fromScale(0.77, 0.73)
    Main.BackgroundTransparency = 0.30
    local t = Tween(Main, {
        Size = UDim2.fromScale(0.82, 0.78),
        BackgroundTransparency = 0.10,
    })
    if t then t:Play() end
end

local function CloseMenu()
    Opened = false
    local t = Tween(Main, {
        Size = UDim2.fromScale(0.77, 0.73),
        BackgroundTransparency = 0.36,
    }, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))

    if t then
        t:Play()
        TrackConnection(t.Completed:Connect(function()
            if not Opened and Alive then
                Main.Visible = false
                Backdrop.Visible = false
                OpenButton.Visible = true
            end
        end))
    else
        Main.Visible = false
        Backdrop.Visible = false
        OpenButton.Visible = true
    end
end

TrackConnection(Close.Activated:Connect(CloseMenu))
TrackConnection(Backdrop.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        CloseMenu()
    end
end))

local function StartDrag(input)
    Dragging = true
    DragStart = input.Position
    StartPosition = Main.Position
    DragDistance = 0
end

TrackConnection(Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        StartDrag(input)
    end
end))

TrackConnection(UserInputService.InputChanged:Connect(function(input)
    if not Dragging then
        return
    end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - DragStart
        DragDistance = delta.Magnitude
        Main.Position = UDim2.new(
            StartPosition.X.Scale,
            StartPosition.X.Offset + delta.X,
            StartPosition.Y.Scale,
            StartPosition.Y.Offset + delta.Y
        )
    end
end))

TrackConnection(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if Dragging and DragDistance < 12 and Opened == false and OpenButton.Visible then
            OpenMenu()
        end
        Dragging = false
        DragStart = nil
        StartPosition = nil
        DragDistance = 0
    end
end))

TrackConnection(OpenButton.Activated:Connect(function()
    if not Dragging then
        OpenMenu()
    end
end))

--========================================================--
-- STATUS / INFO UPDATER
--========================================================--

local InfoTimer = 0
TrackConnection(RunService.Heartbeat:Connect(function(dt)
    if not Alive then
        return
    end

    InfoTimer += dt
    if InfoTimer < 0.50 then
        return
    end
    InfoTimer = 0

    local mode = State.SelectedPreset
    local env = Sense.indoor and "INDOOR" or "OUTDOOR"
    local fog = math.floor(Sense.fogFactor * 100 + 0.5)
    local quality = math.floor(Sense.qualityScale * 100 + 0.5)

    Status.Text = string.format(
        "%s • Fog %d%% • %s • FPS %d • Quality %d%%",
        mode,
        fog,
        env,
        math.floor(Sense.fps + 0.5),
        quality
    )

    PBRInfo.Text = string.format(
        "PBR: real SurfaceAppearance %d • adaptive fallback %d",
        PBRRealCount,
        PBRHeuristicCount
    )

    if GAME_METADATA.available then
        local genre = GAME_METADATA.genre ~= "" and (" • " .. GAME_METADATA.genre) or ""
        GameInfo.Text = "Game DNA: " .. string.sub(GAME_METADATA.name, 1, 38) .. genre
    else
        GameInfo.Text = "Game DNA: local sensing active • external metadata unavailable"
    end

    local req = ExecutorRequest and "HTTP ready" or "HTTP unavailable"
    local surface = HasProperty(Lighting, "LightingStyle") and "Realistic Lighting API" or "legacy lighting"
    CapabilityInfo.Text = "Capabilities: " .. surface .. " • " .. req .. " • SurfaceAppearance preserved"
end))

--========================================================--
-- INITIALIZATION
--========================================================--

ApplyPreset("HIGH")
State.SelectedPreset = "HIGH"
State.Shaders = true
ApplyNativeLighting()
ApplyShaders()

-- Run one learning pass immediately.
pcall(function()
    UpdateSense(0.12)
    UpdateAutoFocus()
    UpdatePerformance(0.12)
end)

--========================================================--
-- GLOBAL CLEANUP IMPLEMENTATION
--========================================================--

GlobalEnv.TBAMGV_V7_Cleanup = function()
    if not Alive then
        return
    end

    Alive = false

    for _, thread in ipairs(Threads) do
        pcall(function()
            task.cancel(thread)
        end)
    end
    table.clear(Threads)

    for _, connection in ipairs(Connections) do
        SafeDisconnect(connection)
    end
    table.clear(Connections)

    -- Restore first, then destroy only our objects.
    pcall(DisableMirrorWorld)
    pcall(DisableUltraWater)
    pcall(DestroyContactShadowRig)
    pcall(RestoreAllPBR)

    SafeProperty(Lighting, "GlobalShadows", Original.Lighting.GlobalShadows)
    SafeProperty(Lighting, "Brightness", Original.Lighting.Brightness)
    SafeProperty(Lighting, "ExposureCompensation", Original.Lighting.ExposureCompensation)
    SafeProperty(Lighting, "ShadowSoftness", Original.Lighting.ShadowSoftness)
    SafeProperty(Lighting, "Ambient", Original.Lighting.Ambient)
    SafeProperty(Lighting, "OutdoorAmbient", Original.Lighting.OutdoorAmbient)
    SafeProperty(Lighting, "ColorShift_Top", Original.Lighting.ColorShiftTop)
    SafeProperty(Lighting, "ColorShift_Bottom", Original.Lighting.ColorShiftBottom)
    SafeProperty(Lighting, "ClockTime", Original.Lighting.ClockTime)
    SafeProperty(Lighting, "FogColor", Original.Lighting.FogColor)
    SafeProperty(Lighting, "FogStart", Original.Lighting.FogStart)
    SafeProperty(Lighting, "FogEnd", Original.Lighting.FogEnd)
    SafeProperty(Lighting, "EnvironmentDiffuseScale", Original.Lighting.EnvironmentDiffuseScale)
    SafeProperty(Lighting, "EnvironmentSpecularScale", Original.Lighting.EnvironmentSpecularScale)

    if Original.Lighting.LightingStyle ~= nil then
        pcall(function()
            Lighting.LightingStyle = Original.Lighting.LightingStyle
        end)
    end

    if Original.Lighting.PrioritizeLightingQuality ~= nil then
        pcall(function()
            Lighting.PrioritizeLightingQuality = Original.Lighting.PrioritizeLightingQuality
        end)
    end

    if Original.Atmosphere and Original.Atmosphere.Instance and Original.Atmosphere.Instance.Parent then
        local atmo = Original.Atmosphere.Instance
        SafeProperty(atmo, "Density", Original.Atmosphere.Density)
        SafeProperty(atmo, "Haze", Original.Atmosphere.Haze)
        SafeProperty(atmo, "Glare", Original.Atmosphere.Glare)
        SafeProperty(atmo, "Offset", Original.Atmosphere.Offset)
        SafeProperty(atmo, "Color", Original.Atmosphere.Color)
        SafeProperty(atmo, "Decay", Original.Atmosphere.Decay)
    end

    if Original.Water and Terrain and Terrain.Parent then
        SafeProperty(Terrain, "WaterColor", Original.Water.WaterColor)
        SafeProperty(Terrain, "WaterReflectance", Original.Water.WaterReflectance)
        SafeProperty(Terrain, "WaterTransparency", Original.Water.WaterTransparency)
        SafeProperty(Terrain, "WaterWaveSize", Original.Water.WaterWaveSize)
        SafeProperty(Terrain, "WaterWaveSpeed", Original.Water.WaterWaveSpeed)
    end

    for _, object in ipairs(CreatedObjects) do
        SafeDestroy(object)
    end
    table.clear(CreatedObjects)

    local gui = PlayerGui and PlayerGui:FindFirstChild(MENU_NAME)
    SafeDestroy(gui)

    if GlobalEnv.TBAMGV_V7_Cleanup then
        GlobalEnv.TBAMGV_V7_Cleanup = nil
    end
end

-- Track current GUI manually because it was created before cleanup was assigned.
-- The function above still finds and destroys it by name.

