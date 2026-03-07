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
local SECTOR_ANGLE = 360 / NUM_SECTORS

-- Find Robux prices from ShopProducts
local robuxPrice1 = 49
local robuxPrice3 = 199
for _, category in ipairs(ShopProducts.Categories) do
    for _, product in ipairs(category.Products) do
        if not product.LuckyBlocks and not product.PermanentMultiplierBonus then
            if product.Spins == 1 then
                robuxPrice1 = product.Robux
            elseif product.Spins == 3 then
                robuxPrice3 = product.Robux
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════
-- VISUAL CONSTANTS (aligned with ShopController)
-- ═══════════════════════════════════════════════════════

local COLORS = {
    Overlay = Color3.fromRGB(0, 0, 0),
    OverlayTransparency = 0.4,

    PanelBg = Color3.fromRGB(30, 40, 50),
    PanelStroke = Color3.fromRGB(50, 70, 90),
    HeaderBg = Color3.fromRGB(25, 35, 45),

    CloseBtn = Color3.fromRGB(220, 50, 50),
    CloseBtnHover = Color3.fromRGB(240, 70, 70),

    BuyBtn = Color3.fromRGB(40, 190, 170),
    BuyBtnHover = Color3.fromRGB(50, 220, 195),
    BuyBtnStroke = Color3.fromRGB(60, 210, 190),

    SpinBtn = Color3.fromRGB(255, 185, 0),
    SpinBtnHover = Color3.fromRGB(255, 210, 50),
    SpinBtnDisabled = Color3.fromRGB(60, 70, 80),
    SpinBtnFree = Color3.fromRGB(45, 170, 60),
    SpinBtnFreeHover = Color3.fromRGB(60, 200, 75),

    White = Color3.fromRGB(255, 255, 255),
    SubText = Color3.fromRGB(140, 155, 170),
    GoldText = Color3.fromRGB(255, 220, 80),

    CounterBg = Color3.fromRGB(40, 52, 65),
    CounterStroke = Color3.fromRGB(60, 80, 100),

    WheelBg = Color3.fromRGB(22, 30, 40),
    WheelStroke = Color3.fromRGB(255, 220, 80),
    WheelDivider = Color3.fromRGB(60, 80, 100),
    WheelCenter = Color3.fromRGB(35, 45, 58),
    PointerColor = Color3.fromRGB(255, 60, 60),
}

local SIZES = {
    Panel = UDim2.new(0, 460, 0, 560),
    PanelClosed = UDim2.new(0, 0, 0, 0),
    CornerRadius = UDim.new(0, 16),
    SmallCorner = UDim.new(0, 12),
    TinyCorner = UDim.new(0, 8),
    PillCorner = UDim.new(0, 18),
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
local spinButtonStroke
local wheelContainer
local resultLabel
local freeSpinBtn
local freeSpinBtnText

-- ═══════════════════════════════════════════════════════
-- WHEEL DRAWING
-- ═══════════════════════════════════════════════════════

local function createWheelSectors(parent, radius)
    -- Divider lines across the full wheel (edge to edge through center)
    for i = 0, 2 do
        local angle = i * SECTOR_ANGLE
        local line = Instance.new("Frame")
        line.Name = "Divider_" .. i
        line.Size = UDim2.new(0, 2, 1, 0)
        line.Position = UDim2.new(0.5, 0, 0.5, 0)
        line.AnchorPoint = Vector2.new(0.5, 0.5)
        line.Rotation = angle
        line.BackgroundColor3 = COLORS.WheelDivider
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
        label.TextColor3 = COLORS.White
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
    mainFrame = Instance.new("TextButton")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = SIZES.PanelClosed
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BackgroundColor3 = COLORS.PanelBg
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Text = ""
    mainFrame.AutoButtonColor = false
    mainFrame.Parent = overlay

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = SIZES.CornerRadius
    mainCorner.Parent = mainFrame

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = COLORS.PanelStroke
    mainStroke.Thickness = 2
    mainStroke.Transparency = 0.3
    mainStroke.Parent = mainFrame

    -- ── HEADER ──────────────────────────────────────────
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 60)
    header.Position = UDim2.new(0, 0, 0, 0)
    header.BackgroundColor3 = COLORS.HeaderBg
    header.BorderSizePixel = 0
    header.Parent = mainFrame

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = SIZES.CornerRadius
    headerCorner.Parent = header

    local bottomCover = Instance.new("Frame")
    bottomCover.Name = "BottomCover"
    bottomCover.Size = UDim2.new(1, 0, 0, 16)
    bottomCover.Position = UDim2.new(0, 0, 1, -16)
    bottomCover.BackgroundColor3 = COLORS.HeaderBg
    bottomCover.BorderSizePixel = 0
    bottomCover.Parent = header

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -70, 1, 0)
    title.Position = UDim2.new(0, 24, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "SPIN WHEEL"
    title.TextColor3 = COLORS.White
    title.TextSize = 28
    title.Font = Enum.Font.GothamBlack
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    -- Close button (circle)
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 38, 0, 38)
    closeBtn.Position = UDim2.new(1, -50, 0.5, 0)
    closeBtn.AnchorPoint = Vector2.new(0, 0.5)
    closeBtn.BackgroundColor3 = COLORS.CloseBtn
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "X"
    closeBtn.TextColor3 = COLORS.White
    closeBtn.TextSize = 20
    closeBtn.Font = Enum.Font.GothamBlack
    closeBtn.AutoButtonColor = false
    closeBtn.Parent = header

    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(1, 0)
    closeBtnCorner.Parent = closeBtn

    -- ── WHEEL AREA ──────────────────────────────────────
    local wheelArea = Instance.new("Frame")
    wheelArea.Name = "WheelArea"
    wheelArea.Size = UDim2.new(0, 260, 0, 260)
    wheelArea.Position = UDim2.new(0.5, 0, 0, 72)
    wheelArea.AnchorPoint = Vector2.new(0.5, 0)
    wheelArea.BackgroundTransparency = 1
    wheelArea.Parent = mainFrame

    -- Wheel container (this rotates)
    wheelContainer = Instance.new("Frame")
    wheelContainer.Name = "WheelContainer"
    wheelContainer.Size = UDim2.new(1, 0, 1, 0)
    wheelContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
    wheelContainer.AnchorPoint = Vector2.new(0.5, 0.5)
    wheelContainer.BackgroundColor3 = COLORS.WheelBg
    wheelContainer.BorderSizePixel = 0
    wheelContainer.ClipsDescendants = true
    wheelContainer.Rotation = 0
    wheelContainer.Parent = wheelArea

    local wheelCorner = Instance.new("UICorner")
    wheelCorner.CornerRadius = UDim.new(0.5, 0)
    wheelCorner.Parent = wheelContainer

    local wheelStroke = Instance.new("UIStroke")
    wheelStroke.Color = COLORS.WheelStroke
    wheelStroke.Thickness = 3
    wheelStroke.Parent = wheelContainer

    -- Draw the sectors
    createWheelSectors(wheelContainer, 130)

    -- Center circle
    local centerCircle = Instance.new("Frame")
    centerCircle.Name = "CenterCircle"
    centerCircle.Size = UDim2.new(0, 40, 0, 40)
    centerCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
    centerCircle.AnchorPoint = Vector2.new(0.5, 0.5)
    centerCircle.BackgroundColor3 = COLORS.WheelCenter
    centerCircle.BorderSizePixel = 0
    centerCircle.ZIndex = 5
    centerCircle.Parent = wheelContainer

    local centerCorner = Instance.new("UICorner")
    centerCorner.CornerRadius = UDim.new(0.5, 0)
    centerCorner.Parent = centerCircle

    local centerStroke = Instance.new("UIStroke")
    centerStroke.Color = COLORS.WheelStroke
    centerStroke.Thickness = 2
    centerStroke.Parent = centerCircle

    -- Pointer (fixed triangle at the top)
    local pointer = Instance.new("TextLabel")
    pointer.Name = "Pointer"
    pointer.Size = UDim2.new(0, 30, 0, 30)
    pointer.Position = UDim2.new(0.5, 0, 0, -5)
    pointer.AnchorPoint = Vector2.new(0.5, 0)
    pointer.BackgroundTransparency = 1
    pointer.Text = "\226\150\188"
    pointer.TextColor3 = COLORS.PointerColor
    pointer.TextSize = 36
    pointer.Font = Enum.Font.GothamBold
    pointer.ZIndex = 10
    pointer.Parent = wheelArea

    -- ── COUNTER + RESULT ────────────────────────────────
    -- Spin counter pill
    local counterFrame = Instance.new("Frame")
    counterFrame.Name = "CounterFrame"
    counterFrame.Size = UDim2.new(0, 180, 0, 34)
    counterFrame.Position = UDim2.new(0.5, 0, 0, 344)
    counterFrame.AnchorPoint = Vector2.new(0.5, 0)
    counterFrame.BackgroundColor3 = COLORS.CounterBg
    counterFrame.BorderSizePixel = 0
    counterFrame.Parent = mainFrame

    local counterCorner = Instance.new("UICorner")
    counterCorner.CornerRadius = SIZES.PillCorner
    counterCorner.Parent = counterFrame

    local counterStroke = Instance.new("UIStroke")
    counterStroke.Color = COLORS.CounterStroke
    counterStroke.Thickness = 1.5
    counterStroke.Transparency = 0.3
    counterStroke.Parent = counterFrame

    spinCountLabel = Instance.new("TextLabel")
    spinCountLabel.Name = "SpinCountLabel"
    spinCountLabel.Size = UDim2.new(1, 0, 1, 0)
    spinCountLabel.BackgroundTransparency = 1
    spinCountLabel.Text = "x0 Spins"
    spinCountLabel.TextColor3 = COLORS.White
    spinCountLabel.TextSize = 15
    spinCountLabel.Font = Enum.Font.GothamBold
    spinCountLabel.Parent = counterFrame

    -- Result label
    resultLabel = Instance.new("TextLabel")
    resultLabel.Name = "ResultLabel"
    resultLabel.Size = UDim2.new(1, -48, 0, 30)
    resultLabel.Position = UDim2.new(0, 24, 0, 384)
    resultLabel.BackgroundTransparency = 1
    resultLabel.Text = ""
    resultLabel.TextColor3 = COLORS.GoldText
    resultLabel.TextSize = 17
    resultLabel.Font = Enum.Font.GothamBlack
    resultLabel.TextWrapped = true
    resultLabel.TextStrokeTransparency = 0.5
    resultLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    resultLabel.Parent = mainFrame

    -- ── SPIN BUTTON ─────────────────────────────────────
    spinButton = Instance.new("TextButton")
    spinButton.Name = "SpinButton"
    spinButton.Size = UDim2.new(1, -48, 0, 52)
    spinButton.Position = UDim2.new(0, 24, 0, 418)
    spinButton.BackgroundColor3 = COLORS.SpinBtnDisabled
    spinButton.BorderSizePixel = 0
    spinButton.Text = ""
    spinButton.AutoButtonColor = false
    spinButton.Parent = mainFrame

    local spinCorner = Instance.new("UICorner")
    spinCorner.CornerRadius = SIZES.SmallCorner
    spinCorner.Parent = spinButton

    spinButtonStroke = Instance.new("UIStroke")
    spinButtonStroke.Name = "SpinStroke"
    spinButtonStroke.Color = Color3.fromRGB(80, 90, 100)
    spinButtonStroke.Thickness = 1.5
    spinButtonStroke.Transparency = 0.3
    spinButtonStroke.Parent = spinButton

    spinButtonText = Instance.new("TextLabel")
    spinButtonText.Name = "ButtonText"
    spinButtonText.Size = UDim2.new(1, 0, 1, 0)
    spinButtonText.BackgroundTransparency = 1
    spinButtonText.Text = "No Spins"
    spinButtonText.TextColor3 = COLORS.SubText
    spinButtonText.TextSize = 22
    spinButtonText.Font = Enum.Font.GothamBlack
    spinButtonText.TextStrokeTransparency = 0.6
    spinButtonText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    spinButtonText.Parent = spinButton

    -- ── BOTTOM: FREE SPIN + BUY BUTTONS ─────────────────
    local bottomSection = Instance.new("Frame")
    bottomSection.Name = "BottomSection"
    bottomSection.Size = UDim2.new(1, -48, 0, 48)
    bottomSection.Position = UDim2.new(0, 24, 0, 484)
    bottomSection.BackgroundTransparency = 1
    bottomSection.BorderSizePixel = 0
    bottomSection.Parent = mainFrame

    -- Free Spin button (left)
    freeSpinBtn = Instance.new("TextButton")
    freeSpinBtn.Name = "FreeSpinButton"
    freeSpinBtn.Size = UDim2.new(0.32, 0, 1, 0)
    freeSpinBtn.Position = UDim2.new(0, 0, 0, 0)
    freeSpinBtn.BackgroundColor3 = COLORS.SpinBtnDisabled
    freeSpinBtn.BorderSizePixel = 0
    freeSpinBtn.Text = ""
    freeSpinBtn.AutoButtonColor = false
    freeSpinBtn.Parent = bottomSection

    local freeSpinCorner = Instance.new("UICorner")
    freeSpinCorner.CornerRadius = SIZES.SmallCorner
    freeSpinCorner.Parent = freeSpinBtn

    local freeSpinStroke = Instance.new("UIStroke")
    freeSpinStroke.Color = Color3.fromRGB(60, 180, 75)
    freeSpinStroke.Thickness = 1.5
    freeSpinStroke.Transparency = 0.4
    freeSpinStroke.Parent = freeSpinBtn

    freeSpinBtnText = Instance.new("TextLabel")
    freeSpinBtnText.Name = "ButtonText"
    freeSpinBtnText.Size = UDim2.new(1, 0, 1, 0)
    freeSpinBtnText.BackgroundTransparency = 1
    freeSpinBtnText.Text = "FREE"
    freeSpinBtnText.TextColor3 = COLORS.White
    freeSpinBtnText.TextSize = 13
    freeSpinBtnText.Font = Enum.Font.GothamBold
    freeSpinBtnText.TextWrapped = true
    freeSpinBtnText.TextStrokeTransparency = 0.6
    freeSpinBtnText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    freeSpinBtnText.Parent = freeSpinBtn

    -- Buy 1 button (center)
    local buyOneBtn = Instance.new("TextButton")
    buyOneBtn.Name = "BuyOneButton"
    buyOneBtn.Size = UDim2.new(0.32, 0, 1, 0)
    buyOneBtn.Position = UDim2.new(0.34, 0, 0, 0)
    buyOneBtn.BackgroundColor3 = COLORS.BuyBtn
    buyOneBtn.BorderSizePixel = 0
    buyOneBtn.Text = ""
    buyOneBtn.AutoButtonColor = false
    buyOneBtn.Parent = bottomSection

    local buyOneCorner = Instance.new("UICorner")
    buyOneCorner.CornerRadius = SIZES.SmallCorner
    buyOneCorner.Parent = buyOneBtn

    local buyOneGradient = Instance.new("UIGradient")
    buyOneGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 210, 200)),
    })
    buyOneGradient.Rotation = 90
    buyOneGradient.Parent = buyOneBtn

    local buyOneStroke = Instance.new("UIStroke")
    buyOneStroke.Color = COLORS.BuyBtnStroke
    buyOneStroke.Thickness = 1.5
    buyOneStroke.Transparency = 0.3
    buyOneStroke.Parent = buyOneBtn

    local buyOneText = Instance.new("TextLabel")
    buyOneText.Name = "Label"
    buyOneText.Size = UDim2.new(1, 0, 1, 0)
    buyOneText.BackgroundTransparency = 1
    buyOneText.Text = "x1  " .. utf8.char(0xE002) .. " " .. robuxPrice1
    buyOneText.TextColor3 = COLORS.White
    buyOneText.TextSize = 14
    buyOneText.Font = Enum.Font.GothamBold
    buyOneText.TextStrokeTransparency = 0.6
    buyOneText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    buyOneText.Parent = buyOneBtn

    -- Buy 3 button (right)
    local buyThreeBtn = Instance.new("TextButton")
    buyThreeBtn.Name = "BuyThreeButton"
    buyThreeBtn.Size = UDim2.new(0.32, 0, 1, 0)
    buyThreeBtn.Position = UDim2.new(0.68, 0, 0, 0)
    buyThreeBtn.BackgroundColor3 = COLORS.BuyBtn
    buyThreeBtn.BorderSizePixel = 0
    buyThreeBtn.Text = ""
    buyThreeBtn.AutoButtonColor = false
    buyThreeBtn.Parent = bottomSection

    local buyThreeCorner = Instance.new("UICorner")
    buyThreeCorner.CornerRadius = SIZES.SmallCorner
    buyThreeCorner.Parent = buyThreeBtn

    local buyThreeGradient = Instance.new("UIGradient")
    buyThreeGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 210, 200)),
    })
    buyThreeGradient.Rotation = 90
    buyThreeGradient.Parent = buyThreeBtn

    local buyThreeStroke = Instance.new("UIStroke")
    buyThreeStroke.Color = COLORS.BuyBtnStroke
    buyThreeStroke.Thickness = 1.5
    buyThreeStroke.Transparency = 0.3
    buyThreeStroke.Parent = buyThreeBtn

    local buyThreeText = Instance.new("TextLabel")
    buyThreeText.Name = "Label"
    buyThreeText.Size = UDim2.new(1, 0, 1, 0)
    buyThreeText.BackgroundTransparency = 1
    buyThreeText.Text = "x3  " .. utf8.char(0xE002) .. " " .. robuxPrice3
    buyThreeText.TextColor3 = COLORS.White
    buyThreeText.TextSize = 14
    buyThreeText.Font = Enum.Font.GothamBold
    buyThreeText.TextStrokeTransparency = 0.6
    buyThreeText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    buyThreeText.Parent = buyThreeBtn

    -- ═══════════════════════════════════════════════════════
    -- BUTTON CONNECTIONS
    -- ═══════════════════════════════════════════════════════

    overlay.MouseButton1Click:Connect(function()
        if not isSpinning then
            closeUI()
        end
    end)

    closeBtn.MouseEnter:Connect(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = COLORS.CloseBtnHover
        }):Play()
    end)
    closeBtn.MouseLeave:Connect(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = COLORS.CloseBtn
        }):Play()
    end)
    closeBtn.MouseButton1Click:Connect(function()
        if not isSpinning then
            closeUI()
        end
    end)

    -- Buy hover effects (tweened)
    buyOneBtn.MouseEnter:Connect(function()
        TweenService:Create(buyOneBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = COLORS.BuyBtnHover
        }):Play()
        TweenService:Create(buyOneStroke, TweenInfo.new(0.15), {
            Transparency = 0
        }):Play()
    end)
    buyOneBtn.MouseLeave:Connect(function()
        TweenService:Create(buyOneBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = COLORS.BuyBtn
        }):Play()
        TweenService:Create(buyOneStroke, TweenInfo.new(0.15), {
            Transparency = 0.3
        }):Play()
    end)

    buyThreeBtn.MouseEnter:Connect(function()
        TweenService:Create(buyThreeBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = COLORS.BuyBtnHover
        }):Play()
        TweenService:Create(buyThreeStroke, TweenInfo.new(0.15), {
            Transparency = 0
        }):Play()
    end)
    buyThreeBtn.MouseLeave:Connect(function()
        TweenService:Create(buyThreeBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = COLORS.BuyBtn
        }):Play()
        TweenService:Create(buyThreeStroke, TweenInfo.new(0.15), {
            Transparency = 0.3
        }):Play()
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
            TweenService:Create(freeSpinBtn, TweenInfo.new(0.15), {
                BackgroundColor3 = COLORS.SpinBtnFreeHover
            }):Play()
            TweenService:Create(freeSpinStroke, TweenInfo.new(0.15), {
                Transparency = 0
            }):Play()
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
                TweenService:Create(spinButton, TweenInfo.new(0.15), {
                    BackgroundColor3 = COLORS.SpinBtnFreeHover
                }):Play()
            else
                TweenService:Create(spinButton, TweenInfo.new(0.15), {
                    BackgroundColor3 = COLORS.SpinBtnHover
                }):Play()
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

local function openUI()
    if isOpen then return end
    isOpen = true
    screenGui.Enabled = true
    resultLabel.Text = ""

    overlay.BackgroundTransparency = 1
    TweenService:Create(overlay, TweenInfo.new(0.25), {
        BackgroundTransparency = COLORS.OverlayTransparency
    }):Play()

    mainFrame.Size = SIZES.PanelClosed
    TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = SIZES.Panel,
    }):Play()
end

function closeUI()
    if not isOpen then return end

    TweenService:Create(overlay, TweenInfo.new(0.2), {
        BackgroundTransparency = 1
    }):Play()

    local tweenClose = TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = SIZES.PanelClosed,
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
            TweenService:Create(spinButton, TweenInfo.new(0.2), {
                BackgroundColor3 = COLORS.SpinBtnFree
            }):Play()
            spinButtonText.Text = "FREE SPIN!"
            spinButtonText.TextColor3 = COLORS.White
            spinButtonStroke.Color = Color3.fromRGB(60, 200, 75)
        else
            TweenService:Create(spinButton, TweenInfo.new(0.2), {
                BackgroundColor3 = COLORS.SpinBtn
            }):Play()
            spinButtonText.Text = "SPIN! (x" .. spinCount .. ")"
            spinButtonText.TextColor3 = COLORS.White
            spinButtonStroke.Color = Color3.fromRGB(255, 210, 50)
        end
    else
        TweenService:Create(spinButton, TweenInfo.new(0.2), {
            BackgroundColor3 = COLORS.SpinBtnDisabled
        }):Play()
        spinButtonText.Text = "No Spins"
        spinButtonText.TextColor3 = COLORS.SubText
        spinButtonStroke.Color = Color3.fromRGB(80, 90, 100)
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
        TweenService:Create(freeSpinBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = COLORS.SpinBtnFree
        }):Play()
        freeSpinBtnText.Text = "FREE!"
        freeSpinBtnText.TextColor3 = COLORS.White
        freeSpinBtnText.TextSize = 14
    else
        TweenService:Create(freeSpinBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = COLORS.SpinBtnDisabled
        }):Play()
        freeSpinBtnText.Text = "FREE\n" .. formatTime(timeUntilFreeSpin)
        freeSpinBtnText.TextColor3 = COLORS.SubText
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
        spinCountLabel.Text = "x" .. spinCount .. " Spin" .. (spinCount ~= 1 and "s" or "")
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

    local sectorCenter = (rewardIndex - 1) * SECTOR_ANGLE + SECTOR_ANGLE / 2
    local fullRotations = math.random(5, 8) * 360
    local targetAngle = fullRotations + (360 - sectorCenter)

    local startRotation = wheelContainer.Rotation % 360
    local finalRotation = startRotation + targetAngle

    local spinTween = TweenService:Create(wheelContainer,
        TweenInfo.new(4.0, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        { Rotation = finalRotation }
    )
    spinTween:Play()

    spinTween.Completed:Connect(function()
        wheelContainer.Rotation = finalRotation % 360

        local reward = rewards[rewardIndex]
        if reward then
            resultLabel.Text = "You won: " .. reward.DisplayName .. "!"
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
