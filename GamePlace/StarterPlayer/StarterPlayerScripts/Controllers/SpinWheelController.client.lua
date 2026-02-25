--[[
    SpinWheelController.client.lua
    Handles client-side Spin Wheel UI:
    - ProximityPrompt on workspace.Shops.SpinWheelBase
    - Purchase and spin UI
    - Spinning wheel animation (6 sectors)
    - Free spin timer (1 per day)
    - Listens to SyncSpinWheelData and SpinWheelResult
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Config
local Config = ReplicatedStorage:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig.module"))

-- Shop products (for Robux prices)
local Data = ReplicatedStorage:WaitForChild("Data")
local ShopProducts = require(Data:WaitForChild("ShopProducts.module"))

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local buySpinWheelRemote = Remotes:WaitForChild("BuySpinWheel")
local spinWheelRemote = Remotes:WaitForChild("SpinWheel")
local syncSpinWheelData = Remotes:WaitForChild("SyncSpinWheelData")
local spinWheelResult = Remotes:WaitForChild("SpinWheelResult")

-- State
local isOpen = false
local isSpinning = false
local spinCount = 0
local freeSpinAvailable = true
local timeUntilFreeSpin = 0
local lastFreeSpinTime = 0

-- Rewards config from GameConfig
local rewards = GameConfig.SpinWheel.Rewards
local NUM_SECTORS = #rewards
local SECTOR_ANGLE = 360 / NUM_SECTORS -- 60 degrees each

-- Find Robux prices from ShopProducts
local robuxPrice1 = 49
local robuxPrice3 = 199
for _, category in ipairs(ShopProducts.Categories) do
    if category.Id == "SpinWheel" then
        for _, product in ipairs(category.Products) do
            if product.Spins == 1 then
                robuxPrice1 = product.Robux
            elseif product.Spins == 3 then
                robuxPrice3 = product.Robux
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════
-- VISUAL CONSTANTS
-- ═══════════════════════════════════════════════════════

local COLORS = {
    Overlay = Color3.fromRGB(0, 0, 0),
    OverlayTransparency = 0.4,
    PanelBg = Color3.fromRGB(20, 15, 35),
    HeaderBg = Color3.fromRGB(15, 10, 30),
    CloseBtn = Color3.fromRGB(200, 40, 40),
    CloseBtnHover = Color3.fromRGB(230, 60, 60),
    BuyBtn = Color3.fromRGB(40, 120, 200),
    BuyBtnHover = Color3.fromRGB(55, 145, 230),
    SpinBtn = Color3.fromRGB(220, 160, 0),
    SpinBtnHover = Color3.fromRGB(250, 185, 20),
    SpinBtnDisabled = Color3.fromRGB(80, 80, 80),
    SpinBtnFree = Color3.fromRGB(50, 180, 50),
    SpinBtnFreeHover = Color3.fromRGB(70, 210, 70),
    White = Color3.fromRGB(255, 255, 255),
    LightGray = Color3.fromRGB(180, 180, 180),
    Gold = Color3.fromRGB(255, 215, 0),
    Divider = Color3.fromRGB(60, 50, 90),
    PointerColor = Color3.fromRGB(255, 50, 50),
}

-- Sector colors (6 alternating colors for the wheel)
local SECTOR_COLORS = {
    Color3.fromRGB(255, 200, 50),   -- Gold (25K)
    Color3.fromRGB(50, 180, 80),    -- Green (100K)
    Color3.fromRGB(50, 120, 220),   -- Blue (1M)
    Color3.fromRGB(180, 50, 220),   -- Purple (x2 Multi)
    Color3.fromRGB(220, 100, 30),   -- Orange (1 Lucky Block)
    Color3.fromRGB(220, 50, 50),    -- Red (3 Lucky Blocks)
}

-- ═══════════════════════════════════════════════════════
-- UI REFERENCES
-- ═══════════════════════════════════════════════════════

local screenGui
local mainFrame
local overlay
local spinCountLabel
local spinButton
local spinButtonText
local wheelContainer
local resultLabel
local freeSpinBtn
local freeSpinBtnText

-- ═══════════════════════════════════════════════════════
-- WHEEL DRAWING
-- ═══════════════════════════════════════════════════════

-- Labels only (no colored sectors)
local function createWheelSectors(parent, radius)
    -- Divider lines across the full wheel (edge to edge through center)
    -- 6 boundaries but opposite ones overlap, so 3 unique lines suffice
    for i = 0, 2 do
        local angle = i * SECTOR_ANGLE -- 0, 60, 120
        local line = Instance.new("Frame")
        line.Name = "Divider_" .. i
        line.Size = UDim2.new(0, 2, 1, 0)
        line.Position = UDim2.new(0.5, 0, 0.5, 0)
        line.AnchorPoint = Vector2.new(0.5, 0.5)
        line.Rotation = angle
        line.BackgroundColor3 = Color3.fromRGB(200, 200, 220)
        line.BorderSizePixel = 0
        line.ZIndex = 3
        line.Parent = parent
    end

    -- Labels at the center of each sector
    for i = 1, NUM_SECTORS do
        local startAngle = (i - 1) * SECTOR_ANGLE
        local reward = rewards[i]
        local midAngle = startAngle + SECTOR_ANGLE / 2
        local rad = math.rad(midAngle)
        local dist = 0.32
        local xOff = dist * math.sin(rad)
        local yOff = -dist * math.cos(rad)

        local label = Instance.new("TextLabel")
        label.Name = "Label_" .. i
        label.Size = UDim2.new(0, 80, 0, 25)
        label.Position = UDim2.new(0.5 + xOff, 0, 0.5 + yOff, 0)
        label.AnchorPoint = Vector2.new(0.5, 0.5)
        label.Rotation = midAngle
        label.BackgroundTransparency = 1
        label.Text = reward.DisplayName
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextSize = 12
        label.Font = Enum.Font.GothamBold
        label.TextStrokeTransparency = 0.3
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.ZIndex = 4
        label.Parent = parent
    end
end

-- ═══════════════════════════════════════════════════════
-- UI CREATION
-- ═══════════════════════════════════════════════════════

local function createUI()
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SpinWheelUI"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 13
    screenGui.Enabled = false
    screenGui.Parent = playerGui

    -- Overlay
    overlay = Instance.new("TextButton")
    overlay.Name = "Overlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = COLORS.Overlay
    overlay.BackgroundTransparency = 1
    overlay.BorderSizePixel = 0
    overlay.Text = ""
    overlay.AutoButtonColor = false
    overlay.Parent = screenGui

    -- MainFrame
    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BackgroundColor3 = COLORS.PanelBg
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = overlay

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 12)
    mainCorner.Parent = mainFrame

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(80, 60, 140)
    mainStroke.Thickness = 2
    mainStroke.Parent = mainFrame

    -- Header
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 50)
    header.BackgroundColor3 = COLORS.HeaderBg
    header.BorderSizePixel = 0
    header.Parent = mainFrame

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -60, 1, 0)
    title.Position = UDim2.new(0, 20, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "SPIN WHEEL"
    title.TextColor3 = COLORS.Gold
    title.TextSize = 28
    title.Font = Enum.Font.GothamBlack
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 40, 0, 40)
    closeBtn.Position = UDim2.new(1, -45, 0, 5)
    closeBtn.BackgroundColor3 = COLORS.CloseBtn
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "X"
    closeBtn.TextColor3 = COLORS.White
    closeBtn.TextSize = 22
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = header

    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0, 8)
    closeBtnCorner.Parent = closeBtn

    -- ═══════════════════════════════════════
    -- WHEEL AREA (center of the panel)
    -- ═══════════════════════════════════════

    -- Wheel outer frame (holds wheel + pointer)
    local wheelArea = Instance.new("Frame")
    wheelArea.Name = "WheelArea"
    wheelArea.Size = UDim2.new(0, 260, 0, 260)
    wheelArea.Position = UDim2.new(0.5, 0, 0, 60)
    wheelArea.AnchorPoint = Vector2.new(0.5, 0)
    wheelArea.BackgroundTransparency = 1
    wheelArea.Parent = mainFrame

    -- Wheel container (this rotates)
    wheelContainer = Instance.new("Frame")
    wheelContainer.Name = "WheelContainer"
    wheelContainer.Size = UDim2.new(1, 0, 1, 0)
    wheelContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
    wheelContainer.AnchorPoint = Vector2.new(0.5, 0.5)
    wheelContainer.BackgroundColor3 = Color3.fromRGB(30, 25, 50)
    wheelContainer.BorderSizePixel = 0
    wheelContainer.ClipsDescendants = true
    wheelContainer.Rotation = 0
    wheelContainer.Parent = wheelArea

    local wheelCorner = Instance.new("UICorner")
    wheelCorner.CornerRadius = UDim.new(0.5, 0) -- Perfect circle
    wheelCorner.Parent = wheelContainer

    local wheelStroke = Instance.new("UIStroke")
    wheelStroke.Color = COLORS.Gold
    wheelStroke.Thickness = 3
    wheelStroke.Parent = wheelContainer

    -- Draw the sectors
    createWheelSectors(wheelContainer, 130)

    -- Center circle (decorative)
    local centerCircle = Instance.new("Frame")
    centerCircle.Name = "CenterCircle"
    centerCircle.Size = UDim2.new(0, 40, 0, 40)
    centerCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
    centerCircle.AnchorPoint = Vector2.new(0.5, 0.5)
    centerCircle.BackgroundColor3 = Color3.fromRGB(40, 30, 60)
    centerCircle.BorderSizePixel = 0
    centerCircle.ZIndex = 5
    centerCircle.Parent = wheelContainer

    local centerCorner = Instance.new("UICorner")
    centerCorner.CornerRadius = UDim.new(0.5, 0)
    centerCorner.Parent = centerCircle

    local centerStroke = Instance.new("UIStroke")
    centerStroke.Color = COLORS.Gold
    centerStroke.Thickness = 2
    centerStroke.Parent = centerCircle

    -- Pointer (fixed triangle at the top)
    local pointer = Instance.new("TextLabel")
    pointer.Name = "Pointer"
    pointer.Size = UDim2.new(0, 30, 0, 30)
    pointer.Position = UDim2.new(0.5, 0, 0, -5)
    pointer.AnchorPoint = Vector2.new(0.5, 0)
    pointer.BackgroundTransparency = 1
    pointer.Text = "\226\150\188" -- Down-pointing triangle
    pointer.TextColor3 = COLORS.PointerColor
    pointer.TextSize = 36
    pointer.Font = Enum.Font.GothamBold
    pointer.ZIndex = 10
    pointer.Parent = wheelArea

    -- ═══════════════════════════════════════
    -- BOTTOM CONTROLS
    -- ═══════════════════════════════════════

    -- Spin count label
    spinCountLabel = Instance.new("TextLabel")
    spinCountLabel.Name = "SpinCountLabel"
    spinCountLabel.Size = UDim2.new(1, -40, 0, 25)
    spinCountLabel.Position = UDim2.new(0, 20, 0, 330)
    spinCountLabel.BackgroundTransparency = 1
    spinCountLabel.Text = "Spins: 0"
    spinCountLabel.TextColor3 = COLORS.White
    spinCountLabel.TextSize = 16
    spinCountLabel.Font = Enum.Font.GothamBold
    spinCountLabel.TextXAlignment = Enum.TextXAlignment.Center
    spinCountLabel.Parent = mainFrame

    -- Spin button
    spinButton = Instance.new("TextButton")
    spinButton.Name = "SpinButton"
    spinButton.Size = UDim2.new(1, -40, 0, 50)
    spinButton.Position = UDim2.new(0, 20, 0, 360)
    spinButton.BackgroundColor3 = COLORS.SpinBtnDisabled
    spinButton.BorderSizePixel = 0
    spinButton.Text = ""
    spinButton.AutoButtonColor = false
    spinButton.Parent = mainFrame

    local spinCorner = Instance.new("UICorner")
    spinCorner.CornerRadius = UDim.new(0, 10)
    spinCorner.Parent = spinButton

    spinButtonText = Instance.new("TextLabel")
    spinButtonText.Name = "ButtonText"
    spinButtonText.Size = UDim2.new(1, 0, 1, 0)
    spinButtonText.BackgroundTransparency = 1
    spinButtonText.Text = "Spin!"
    spinButtonText.TextColor3 = COLORS.White
    spinButtonText.TextSize = 22
    spinButtonText.Font = Enum.Font.GothamBlack
    spinButtonText.Parent = spinButton

    -- Result label (shown after spin)
    resultLabel = Instance.new("TextLabel")
    resultLabel.Name = "ResultLabel"
    resultLabel.Size = UDim2.new(1, -40, 0, 35)
    resultLabel.Position = UDim2.new(0, 20, 0, 415)
    resultLabel.BackgroundTransparency = 1
    resultLabel.Text = ""
    resultLabel.TextColor3 = COLORS.Gold
    resultLabel.TextSize = 18
    resultLabel.Font = Enum.Font.GothamBlack
    resultLabel.TextWrapped = true
    resultLabel.Parent = mainFrame

    -- Divider
    local divider = Instance.new("Frame")
    divider.Name = "Divider"
    divider.Size = UDim2.new(1, -40, 0, 2)
    divider.Position = UDim2.new(0, 20, 0, 455)
    divider.BackgroundColor3 = COLORS.Divider
    divider.BorderSizePixel = 0
    divider.Parent = mainFrame

    -- Buy section
    local buySection = Instance.new("Frame")
    buySection.Name = "BuySection"
    buySection.Size = UDim2.new(1, -40, 0, 50)
    buySection.Position = UDim2.new(0, 20, 0, 467)
    buySection.BackgroundTransparency = 1
    buySection.Parent = mainFrame

    -- Buy 1 button
    local buyOneBtn = Instance.new("TextButton")
    buyOneBtn.Name = "BuyOneButton"
    buyOneBtn.Size = UDim2.new(0.3, 0, 0, 45)
    buyOneBtn.Position = UDim2.new(0, 0, 0, 0)
    buyOneBtn.BackgroundColor3 = COLORS.BuyBtn
    buyOneBtn.BorderSizePixel = 0
    buyOneBtn.Text = "BUY 1 - " .. utf8.char(0xE002) .. robuxPrice1
    buyOneBtn.TextColor3 = COLORS.White
    buyOneBtn.TextSize = 14
    buyOneBtn.Font = Enum.Font.GothamBold
    buyOneBtn.AutoButtonColor = false
    buyOneBtn.Parent = buySection

    local buyOneCorner = Instance.new("UICorner")
    buyOneCorner.CornerRadius = UDim.new(0, 8)
    buyOneCorner.Parent = buyOneBtn

    -- Free Spin button (center)
    freeSpinBtn = Instance.new("TextButton")
    freeSpinBtn.Name = "FreeSpinButton"
    freeSpinBtn.Size = UDim2.new(0.36, 0, 0, 45)
    freeSpinBtn.Position = UDim2.new(0.32, 0, 0, 0)
    freeSpinBtn.BackgroundColor3 = COLORS.SpinBtnDisabled
    freeSpinBtn.BorderSizePixel = 0
    freeSpinBtn.Text = ""
    freeSpinBtn.AutoButtonColor = false
    freeSpinBtn.Parent = buySection

    local freeSpinCorner = Instance.new("UICorner")
    freeSpinCorner.CornerRadius = UDim.new(0, 8)
    freeSpinCorner.Parent = freeSpinBtn

    freeSpinBtnText = Instance.new("TextLabel")
    freeSpinBtnText.Name = "ButtonText"
    freeSpinBtnText.Size = UDim2.new(1, 0, 1, 0)
    freeSpinBtnText.BackgroundTransparency = 1
    freeSpinBtnText.Text = "FREE"
    freeSpinBtnText.TextColor3 = COLORS.White
    freeSpinBtnText.TextSize = 14
    freeSpinBtnText.Font = Enum.Font.GothamBold
    freeSpinBtnText.TextWrapped = true
    freeSpinBtnText.Parent = freeSpinBtn

    -- Buy 3 button
    local buyThreeBtn = Instance.new("TextButton")
    buyThreeBtn.Name = "BuyThreeButton"
    buyThreeBtn.Size = UDim2.new(0.3, 0, 0, 45)
    buyThreeBtn.Position = UDim2.new(0.7, 0, 0, 0)
    buyThreeBtn.BackgroundColor3 = COLORS.BuyBtn
    buyThreeBtn.BorderSizePixel = 0
    buyThreeBtn.Text = "BUY 3 - " .. utf8.char(0xE002) .. robuxPrice3
    buyThreeBtn.TextColor3 = COLORS.White
    buyThreeBtn.TextSize = 14
    buyThreeBtn.Font = Enum.Font.GothamBold
    buyThreeBtn.AutoButtonColor = false
    buyThreeBtn.Parent = buySection

    local buyThreeCorner = Instance.new("UICorner")
    buyThreeCorner.CornerRadius = UDim.new(0, 8)
    buyThreeCorner.Parent = buyThreeBtn

    -- ═══════════════════════════════════════════════════════
    -- BUTTON CONNECTIONS
    -- ═══════════════════════════════════════════════════════

    overlay.MouseButton1Click:Connect(function()
        if not isSpinning then
            closeUI()
        end
    end)

    closeBtn.MouseEnter:Connect(function()
        closeBtn.BackgroundColor3 = COLORS.CloseBtnHover
    end)
    closeBtn.MouseLeave:Connect(function()
        closeBtn.BackgroundColor3 = COLORS.CloseBtn
    end)
    closeBtn.MouseButton1Click:Connect(function()
        if not isSpinning then
            closeUI()
        end
    end)

    -- Buy hover
    buyOneBtn.MouseEnter:Connect(function()
        buyOneBtn.BackgroundColor3 = COLORS.BuyBtnHover
    end)
    buyOneBtn.MouseLeave:Connect(function()
        buyOneBtn.BackgroundColor3 = COLORS.BuyBtn
    end)
    buyThreeBtn.MouseEnter:Connect(function()
        buyThreeBtn.BackgroundColor3 = COLORS.BuyBtnHover
    end)
    buyThreeBtn.MouseLeave:Connect(function()
        buyThreeBtn.BackgroundColor3 = COLORS.BuyBtn
    end)

    buyOneBtn.MouseButton1Click:Connect(function()
        buySpinWheelRemote:FireServer(1)
    end)

    buyThreeBtn.MouseButton1Click:Connect(function()
        buySpinWheelRemote:FireServer(3)
    end)

    -- Free spin button hover and click
    freeSpinBtn.MouseEnter:Connect(function()
        if freeSpinAvailable and not isSpinning then
            freeSpinBtn.BackgroundColor3 = COLORS.SpinBtnFreeHover
        end
    end)
    freeSpinBtn.MouseLeave:Connect(function()
        updateFreeSpinBtn()
    end)
    freeSpinBtn.MouseButton1Click:Connect(function()
        if freeSpinAvailable and not isSpinning then
            resultLabel.Text = ""
            spinWheelRemote:FireServer()
        end
    end)

    -- Spin hover and click
    spinButton.MouseEnter:Connect(function()
        if not isSpinning and canSpin() then
            if freeSpinAvailable then
                spinButton.BackgroundColor3 = COLORS.SpinBtnFreeHover
            else
                spinButton.BackgroundColor3 = COLORS.SpinBtnHover
            end
        end
    end)
    spinButton.MouseLeave:Connect(function()
        if not isSpinning then
            updateSpinButton()
        end
    end)
    spinButton.MouseButton1Click:Connect(function()
        if not isSpinning and canSpin() then
            resultLabel.Text = ""
            spinWheelRemote:FireServer()
        end
    end)
end

-- ═══════════════════════════════════════════════════════
-- OPEN / CLOSE UI
-- ═══════════════════════════════════════════════════════

local PANEL_SIZE = UDim2.new(0, 420, 0, 530)
local PANEL_CLOSED = UDim2.new(0, 0, 0, 0)

local function openUI()
    if isOpen then return end
    isOpen = true
    screenGui.Enabled = true
    resultLabel.Text = ""

    overlay.BackgroundTransparency = 1
    TweenService:Create(overlay, TweenInfo.new(0.25), {
        BackgroundTransparency = COLORS.OverlayTransparency
    }):Play()

    mainFrame.Size = PANEL_CLOSED
    TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = PANEL_SIZE,
    }):Play()
end

function closeUI()
    if not isOpen then return end

    TweenService:Create(overlay, TweenInfo.new(0.2), {
        BackgroundTransparency = 1
    }):Play()

    local tweenClose = TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = PANEL_CLOSED,
    })
    tweenClose:Play()

    tweenClose.Completed:Connect(function()
        screenGui.Enabled = false
        isOpen = false
        isSpinning = false
    end)
end

-- ═══════════════════════════════════════════════════════
-- STATE HELPERS
-- ═══════════════════════════════════════════════════════

function canSpin()
    return freeSpinAvailable or spinCount > 0
end

function updateSpinButton()
    if canSpin() then
        if freeSpinAvailable then
            spinButton.BackgroundColor3 = COLORS.SpinBtnFree
            spinButtonText.Text = "Free Spin!"
            spinButtonText.TextColor3 = COLORS.White
        else
            spinButton.BackgroundColor3 = COLORS.SpinBtn
            spinButtonText.Text = "Spin! (" .. spinCount .. ")"
            spinButtonText.TextColor3 = COLORS.White
        end
    else
        spinButton.BackgroundColor3 = COLORS.SpinBtnDisabled
        spinButtonText.Text = "No Spins"
        spinButtonText.TextColor3 = COLORS.LightGray
    end
end

local function formatTime(seconds)
    if seconds <= 0 then return "0s" end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then
        return string.format("%dh %02dm %02ds", h, m, s)
    elseif m > 0 then
        return string.format("%dm %02ds", m, s)
    else
        return string.format("%ds", s)
    end
end

function updateFreeSpinBtn()
    if not freeSpinBtn then return end
    if freeSpinAvailable then
        freeSpinBtn.BackgroundColor3 = COLORS.SpinBtnFree
        freeSpinBtnText.Text = "Free Spin!"
        freeSpinBtnText.TextColor3 = COLORS.White
        freeSpinBtnText.TextSize = 12
    else
        freeSpinBtn.BackgroundColor3 = COLORS.SpinBtnDisabled
        freeSpinBtnText.Text = "Free Spin\n" .. formatTime(timeUntilFreeSpin)
        freeSpinBtnText.TextColor3 = COLORS.LightGray
        freeSpinBtnText.TextSize = 10
    end
end

local function updateData(data)
    if data.Spins ~= nil then
        spinCount = data.Spins
    end
    if data.FreeSpinAvailable ~= nil then
        freeSpinAvailable = data.FreeSpinAvailable
    end
    if data.TimeUntilFreeSpin ~= nil then
        timeUntilFreeSpin = data.TimeUntilFreeSpin
    end
    if data.LastFreeSpinTime ~= nil then
        lastFreeSpinTime = data.LastFreeSpinTime
    end

    if spinCountLabel then
        spinCountLabel.Text = "Spins: " .. spinCount
    end
    updateSpinButton()
    updateFreeSpinBtn()
end

-- ═══════════════════════════════════════════════════════
-- WHEEL ANIMATION
-- ═══════════════════════════════════════════════════════

local function playSpinAnimation(rewardIndex)
    if isSpinning then return end
    isSpinning = true

    -- Calculate target angle:
    -- The pointer is at the TOP (0 degrees).
    -- Sector i occupies angles from (i-1)*60 to i*60 degrees.
    -- We want the center of sector rewardIndex to land under the pointer.
    -- Since the wheel rotates clockwise, we need to rotate so that
    -- the sector center aligns with 0 degrees (top).

    -- Center of sector i (measured from 0 clockwise):
    local sectorCenter = (rewardIndex - 1) * SECTOR_ANGLE + SECTOR_ANGLE / 2

    -- To bring this sector to the top, we rotate the wheel by (360 - sectorCenter) degrees.
    -- Add multiple full rotations for visual effect.
    local fullRotations = math.random(5, 8) * 360
    local targetAngle = fullRotations + (360 - sectorCenter)

    -- Get current rotation and add target
    local startRotation = wheelContainer.Rotation % 360
    local finalRotation = startRotation + targetAngle

    -- Animate the wheel rotation
    local spinTween = TweenService:Create(wheelContainer,
        TweenInfo.new(4.0, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        { Rotation = finalRotation }
    )
    spinTween:Play()

    spinTween.Completed:Connect(function()
        -- Normalize rotation
        wheelContainer.Rotation = finalRotation % 360

        -- Show result
        local reward = rewards[rewardIndex]
        if reward then
            resultLabel.Text = "You won: " .. reward.DisplayName .. "!"

            -- Flash effect on result
            resultLabel.TextTransparency = 1
            TweenService:Create(resultLabel, TweenInfo.new(0.3), {
                TextTransparency = 0
            }):Play()
        end

        isSpinning = false
        updateSpinButton()
    end)
end

-- ═══════════════════════════════════════════════════════
-- FREE SPIN TIMER (client-side countdown)
-- ═══════════════════════════════════════════════════════

task.spawn(function()
    while true do
        task.wait(1)
        if not freeSpinAvailable and timeUntilFreeSpin > 0 then
            timeUntilFreeSpin = timeUntilFreeSpin - 1
            if timeUntilFreeSpin <= 0 then
                freeSpinAvailable = true
                timeUntilFreeSpin = 0
            end
            if isOpen then
                updateSpinButton()
                updateFreeSpinBtn()
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════
-- PROXIMITY PROMPT ON SPINWHEELBASE
-- ═══════════════════════════════════════════════════════

local function setupProximityPrompt()
    local shops = Workspace:FindFirstChild("Shops")
    if not shops then
        warn("[SpinWheelController] workspace.Shops not found, retrying in 5s...")
        task.wait(5)
        shops = Workspace:FindFirstChild("Shops")
        if not shops then
            warn("[SpinWheelController] workspace.Shops still not found!")
            return
        end
    end

    local spinWheelBase = shops:FindFirstChild("SpinWheelBase")
    if not spinWheelBase then
        warn("[SpinWheelController] workspace.Shops.SpinWheelBase not found!")
        return
    end

    -- Find a BasePart to attach the ProximityPrompt
    local targetPart = nil
    if spinWheelBase:IsA("BasePart") then
        targetPart = spinWheelBase
    elseif spinWheelBase:IsA("Model") then
        targetPart = spinWheelBase.PrimaryPart or spinWheelBase:FindFirstChildWhichIsA("BasePart", true)
    end

    if not targetPart then
        local anchor = Instance.new("Part")
        anchor.Name = "PromptAnchor"
        anchor.Size = Vector3.new(1, 1, 1)
        anchor.Transparency = 1
        anchor.CanCollide = false
        anchor.Anchored = true
        if spinWheelBase:IsA("Model") and spinWheelBase:GetBoundingBox() then
            anchor.CFrame = spinWheelBase:GetBoundingBox()
        else
            anchor.CFrame = CFrame.new(spinWheelBase:GetPivot().Position)
        end
        anchor.Parent = spinWheelBase
        targetPart = anchor
    end

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Spin Wheel"
    prompt.ObjectText = ""
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = 8
    prompt.RequiresLineOfSight = false
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.Parent = targetPart

    prompt.Triggered:Connect(function(playerWhoTriggered)
        if playerWhoTriggered == player then
            openUI()
        end
    end)

    print("[SpinWheelController] ProximityPrompt placed on SpinWheelBase")
end

-- ═══════════════════════════════════════════════════════
-- REMOTE LISTENERS
-- ═══════════════════════════════════════════════════════

syncSpinWheelData.OnClientEvent:Connect(function(data)
    if data then
        updateData(data)
    end
end)

spinWheelResult.OnClientEvent:Connect(function(resultData)
    if resultData and resultData.RewardIndex then
        -- If the UI is not open, open it
        if not isOpen then
            openUI()
            task.wait(0.4)
        end
        playSpinAnimation(resultData.RewardIndex)
    end
end)

-- ═══════════════════════════════════════════════════════
-- INITIALIZATION
-- ═══════════════════════════════════════════════════════

createUI()
setupProximityPrompt()

print("[SpinWheelController] Initialized!")
