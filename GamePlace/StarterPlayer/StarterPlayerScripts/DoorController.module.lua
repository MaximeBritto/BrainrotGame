--[[
    DoorController.module.lua
    Contrôleur client pour l'UI BASE STATUS (porte)

    Responsabilités:
    - Créer le panneau BASE STATUS programmatiquement (haut-centre)
    - Afficher le statut de la porte (Open/Closed)
    - Afficher le timer de réouverture
    - Mettre à jour l'UI en temps réel
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared["Constants.module"])

local DoorController = {}
DoorController._initialized = false
DoorController._doorState = Constants.DoorState.Open
DoorController._reopenTime = 0

-- Références UI
local baseStatusFrame = nil
local statusCircle = nil
local statusText = nil
local statusIcon = nil

-- ═══════════════════════════════════════════════════════
-- CONSTANTES VISUELLES
-- ═══════════════════════════════════════════════════════

local COLORS = {
    PanelBg = Color3.fromRGB(30, 30, 40),
    PanelStroke = Color3.fromRGB(60, 60, 75),
    TitleText = Color3.fromRGB(200, 200, 210),
    OpenGreen = Color3.fromRGB(80, 220, 80),
    ClosedRed = Color3.fromRGB(220, 80, 80),
    White = Color3.fromRGB(255, 255, 255),
    IconColor = Color3.fromRGB(160, 220, 255),
}

-- ═══════════════════════════════════════════════════════
-- INITIALISATION
-- ═══════════════════════════════════════════════════════

function DoorController:Init()
    if self._initialized then
        return
    end

    self:_CreateBaseStatusUI()
    self:_StartUpdateLoop()

    self._initialized = true
end

function DoorController:_CreateBaseStatusUI()
    -- Chercher le ScreenGui du HUD principal ou en créer un
    local screenGui = playerGui:FindFirstChild("GameHUD")
    if not screenGui then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "GameHUD"
        screenGui.ResetOnSpawn = false
        screenGui.IgnoreGuiInset = true
        screenGui.DisplayOrder = 5
        screenGui.Parent = playerGui
    end

    -- Panneau principal BASE STATUS
    baseStatusFrame = Instance.new("Frame")
    baseStatusFrame.Name = "BaseStatusPanel"
    baseStatusFrame.Size = UDim2.new(0, 200, 0, 65)
    baseStatusFrame.Position = UDim2.new(0.5, 0, 0, 8)
    baseStatusFrame.AnchorPoint = Vector2.new(0.5, 0)
    baseStatusFrame.BackgroundColor3 = COLORS.PanelBg
    baseStatusFrame.BackgroundTransparency = 0.2
    baseStatusFrame.BorderSizePixel = 0
    baseStatusFrame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = baseStatusFrame

    local stroke = Instance.new("UIStroke")
    stroke.Color = COLORS.PanelStroke
    stroke.Thickness = 1.5
    stroke.Transparency = 0.3
    stroke.Parent = baseStatusFrame

    -- Titre "BASE STATUS"
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, 0, 0, 20)
    titleLabel.Position = UDim2.new(0, 0, 0, 6)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "BASE STATUS"
    titleLabel.TextColor3 = COLORS.TitleText
    titleLabel.TextSize = 12
    titleLabel.Font = Enum.Font.GothamBlack
    titleLabel.Parent = baseStatusFrame

    -- Container pour l'indicateur (centré en bas)
    local indicatorContainer = Instance.new("Frame")
    indicatorContainer.Name = "Indicator"
    indicatorContainer.Size = UDim2.new(1, 0, 0, 30)
    indicatorContainer.Position = UDim2.new(0, 0, 0, 28)
    indicatorContainer.BackgroundTransparency = 1
    indicatorContainer.Parent = baseStatusFrame

    -- Cercle indicateur vert/rouge
    statusCircle = Instance.new("Frame")
    statusCircle.Name = "StatusCircle"
    statusCircle.Size = UDim2.new(0, 18, 0, 18)
    statusCircle.Position = UDim2.new(0.5, -50, 0.5, 0)
    statusCircle.AnchorPoint = Vector2.new(0, 0.5)
    statusCircle.BackgroundColor3 = COLORS.OpenGreen
    statusCircle.BorderSizePixel = 0
    statusCircle.Parent = indicatorContainer

    local circleCorner = Instance.new("UICorner")
    circleCorner.CornerRadius = UDim.new(1, 0)
    circleCorner.Parent = statusCircle

    -- Glow effect sur le cercle
    local circleGlow = Instance.new("UIStroke")
    circleGlow.Color = COLORS.OpenGreen
    circleGlow.Thickness = 2
    circleGlow.Transparency = 0.5
    circleGlow.Parent = statusCircle

    -- Texte "OPEN" / countdown
    statusText = Instance.new("TextLabel")
    statusText.Name = "StatusText"
    statusText.Size = UDim2.new(0, 80, 0, 24)
    statusText.Position = UDim2.new(0.5, -26, 0.5, 0)
    statusText.AnchorPoint = Vector2.new(0, 0.5)
    statusText.BackgroundTransparency = 1
    statusText.Text = "OPEN"
    statusText.TextColor3 = COLORS.OpenGreen
    statusText.TextSize = 18
    statusText.Font = Enum.Font.GothamBlack
    statusText.TextXAlignment = Enum.TextXAlignment.Left
    statusText.Parent = indicatorContainer

    -- Icône bouclier/diamant décorative
    statusIcon = Instance.new("TextLabel")
    statusIcon.Name = "StatusIcon"
    statusIcon.Size = UDim2.new(0, 22, 0, 22)
    statusIcon.Position = UDim2.new(0.5, 48, 0.5, 0)
    statusIcon.AnchorPoint = Vector2.new(0, 0.5)
    statusIcon.BackgroundTransparency = 1
    statusIcon.Text = "\xE2\x97\x87" -- ◇ diamant
    statusIcon.TextColor3 = COLORS.IconColor
    statusIcon.TextSize = 16
    statusIcon.Font = Enum.Font.GothamBold
    statusIcon.Parent = indicatorContainer
end

-- ═══════════════════════════════════════════════════════
-- MISE À JOUR
-- ═══════════════════════════════════════════════════════

function DoorController:UpdateDoorState(state, reopenTime)
    self._doorState = state
    self._reopenTime = reopenTime or 0

    self:_UpdateUI()
end

function DoorController:_UpdateUI()
    if not statusCircle or not statusText then
        return
    end

    if self._doorState == Constants.DoorState.Open then
        -- Porte ouverte
        statusCircle.BackgroundColor3 = COLORS.OpenGreen
        -- Mettre à jour le glow
        local glow = statusCircle:FindFirstChildOfClass("UIStroke")
        if glow then glow.Color = COLORS.OpenGreen end

        statusText.Text = "OPEN"
        statusText.TextColor3 = COLORS.OpenGreen

    elseif self._doorState == Constants.DoorState.Closed then
        -- Porte fermée - calculer le temps restant
        local currentTime = os.time()
        local remainingTime = math.max(0, self._reopenTime - currentTime)

        if remainingTime > 0 then
            statusCircle.BackgroundColor3 = COLORS.ClosedRed
            local glow = statusCircle:FindFirstChildOfClass("UIStroke")
            if glow then glow.Color = COLORS.ClosedRed end

            statusText.Text = remainingTime .. "s"
            statusText.TextColor3 = COLORS.ClosedRed
        else
            -- Timer fini
            statusCircle.BackgroundColor3 = COLORS.OpenGreen
            local glow = statusCircle:FindFirstChildOfClass("UIStroke")
            if glow then glow.Color = COLORS.OpenGreen end

            statusText.Text = "OPEN"
            statusText.TextColor3 = COLORS.OpenGreen
            self._doorState = Constants.DoorState.Open
        end
    end
end

function DoorController:_StartUpdateLoop()
    task.spawn(function()
        while true do
            task.wait(1)
            if self._doorState == Constants.DoorState.Closed then
                self:_UpdateUI()
            end
        end
    end)
end

return DoorController
