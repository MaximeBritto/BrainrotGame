--[[
    ResponsiveScale.module.lua (ModuleScript)
    Ajoute un UIScale automatique aux ScreenGuis pour s'adapter
    à toutes les résolutions d'écran (mobile, tablette, desktop).

    Usage:
        local ResponsiveScale = require(...)
        ResponsiveScale.Apply(screenGui)
]]

local Camera = game:GetService("Workspace").CurrentCamera

local ResponsiveScale = {}

-- Résolution de référence (design fait pour 1920x1080)
local REFERENCE_WIDTH = 1920
local REFERENCE_HEIGHT = 1080
local MIN_SCALE = 0.45  -- mobile très petit
local MAX_SCALE = 1.2   -- grand écran

local function calculateScale()
    local viewportSize = Camera.ViewportSize
    local scaleX = viewportSize.X / REFERENCE_WIDTH
    local scaleY = viewportSize.Y / REFERENCE_HEIGHT
    -- Prendre le plus petit pour que tout rentre à l'écran
    local scale = math.min(scaleX, scaleY)
    return math.clamp(scale, MIN_SCALE, MAX_SCALE)
end

-- Applique un UIScale responsive à un ScreenGui
function ResponsiveScale.Apply(screenGui)
    if not screenGui then return end

    -- Vérifier si déjà appliqué
    local existing = screenGui:FindFirstChild("_ResponsiveScale")
    if existing then return existing end

    local uiScale = Instance.new("UIScale")
    uiScale.Name = "_ResponsiveScale"
    uiScale.Scale = calculateScale()
    uiScale.Parent = screenGui

    -- Mettre à jour quand la taille du viewport change
    Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        uiScale.Scale = calculateScale()
    end)

    return uiScale
end

return ResponsiveScale
