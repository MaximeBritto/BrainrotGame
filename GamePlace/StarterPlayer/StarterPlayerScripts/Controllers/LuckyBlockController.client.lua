--[[
    LuckyBlockController.client.lua
    Handles client-side Lucky Block UI:
    - ProximityPrompt on workspace.Shops.LuckyBlockBase
    - Purchase and opening UI
    - Slot machine animation (3 columns: Head, Body, Legs)
    - Listens to SyncLuckyBlockData and LuckyBlockReveal
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Responsive
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ResponsiveScale = require(Shared["ResponsiveScale.module"])

-- Data
local Data = ReplicatedStorage:WaitForChild("Data")
local BrainrotData = require(Data:WaitForChild("BrainrotData.module"))
local ShopProducts = require(Data:WaitForChild("ShopProducts.module"))

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local buyLuckyBlockRemote = Remotes:WaitForChild("BuyLuckyBlock")
local openLuckyBlockRemote = Remotes:WaitForChild("OpenLuckyBlock")
local luckyBlockTakeRemote = Remotes:WaitForChild("LuckyBlockTake")
local luckyBlockThrowRemote = Remotes:WaitForChild("LuckyBlockThrow")
local syncLuckyBlockData = Remotes:WaitForChild("SyncLuckyBlockData")
local luckyBlockReveal = Remotes:WaitForChild("LuckyBlockReveal")

-- State
local isOpen = false
local isAnimating = false
local luckyBlockCount = 0

-- Collect display info for slot machine animation (only those with a template)
local displayInfoByPart = { Head = {}, Body = {}, Legs = {} }
for setName, setData in pairs(BrainrotData.Sets) do
    local rarity = setData.Rarity or "Common"
    for _, partType in ipairs({"Head", "Body", "Legs"}) do
        local partData = setData[partType]
        if partData and partData.TemplateName and partData.TemplateName ~= ""
            and partData.SpawnWeight and partData.SpawnWeight > 0 then
            table.insert(displayInfoByPart[partType], {
                Name = partData.DisplayName or setName,
                Rarity = rarity,
                Price = partData.Price or 0,
            })
        end
    end
end

-- Find Robux prices from ShopProducts
local robuxPrice1 = 49
local robuxPrice3 = 99
for _, category in ipairs(ShopProducts.Categories) do
    for _, product in ipairs(category.Products) do
        if not product.Spins and not product.PermanentMultiplierBonus then
            if product.LuckyBlocks == 1 then
                robuxPrice1 = product.Robux
            elseif product.LuckyBlocks == 3 then
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

    OpenBtn = Color3.fromRGB(255, 185, 0),
    OpenBtnHover = Color3.fromRGB(255, 210, 50),
    OpenBtnDisabled = Color3.fromRGB(60, 70, 80),

    White = Color3.fromRGB(255, 255, 255),
    LightGray = Color3.fromRGB(180, 190, 200),
    SubText = Color3.fromRGB(140, 155, 170),
    GoldText = Color3.fromRGB(255, 220, 80),

    CounterBg = Color3.fromRGB(40, 52, 65),
    CounterStroke = Color3.fromRGB(60, 80, 100),

    SlotColumnBg = Color3.fromRGB(22, 30, 40),
    SlotColumnStroke = Color3.fromRGB(50, 70, 90),
    SlotColumnFlash = Color3.fromRGB(45, 65, 85),
}

local SIZES = {
    Panel = UDim2.new(0, 460, 0, 340),
    PanelSlot = UDim2.new(0, 480, 0, 400),
    PanelClosed = UDim2.new(0, 0, 0, 0),
    CornerRadius = UDim.new(0, 16),
    SmallCorner = UDim.new(0, 12),
    TinyCorner = UDim.new(0, 8),
    PillCorner = UDim.new(0, 18),
}

-- Rarity colors (matching BrainrotData.Rarities)
local RARITY_COLORS = {
    Common = Color3.fromRGB(255, 255, 255),
    Rare = Color3.fromRGB(0, 112, 221),
    Epic = Color3.fromRGB(163, 53, 238),
    Legendary = Color3.fromRGB(255, 185, 0),
}

-- ═══════════════════════════════════════════════════════
-- UI REFERENCES
-- ═══════════════════════════════════════════════════════

local screenGui
local mainFrame
local overlay
local countLabel
local openButton
local openButtonText
local slotMachineFrame
local contentFrame

-- ═══════════════════════════════════════════════════════
-- UI CREATION
-- ═══════════════════════════════════════════════════════

local function createUI()
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "LuckyBlockUI"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 12
    screenGui.Enabled = false
    screenGui.Parent = playerGui
    ResponsiveScale.Apply(screenGui)

    -- Overlay (click to close)
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

    -- Cover bottom corners of header
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
    title.Text = "LUCKY BLOCK"
    title.TextColor3 = COLORS.White
    title.TextSize = 28
    title.Font = Enum.Font.GothamBlack
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    -- Close button (circle, like Shop)
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

    -- ── CONTENT AREA (below header) ─────────────────────
    contentFrame = Instance.new("Frame")
    contentFrame.Name = "ContentFrame"
    contentFrame.Size = UDim2.new(1, 0, 1, -60)
    contentFrame.Position = UDim2.new(0, 0, 0, 60)
    contentFrame.BackgroundTransparency = 1
    contentFrame.BorderSizePixel = 0
    contentFrame.Parent = mainFrame

    -- Counter pill badge
    local counterFrame = Instance.new("Frame")
    counterFrame.Name = "CounterFrame"
    counterFrame.Size = UDim2.new(0, 220, 0, 36)
    counterFrame.Position = UDim2.new(0.5, 0, 0, 16)
    counterFrame.AnchorPoint = Vector2.new(0.5, 0)
    counterFrame.BackgroundColor3 = COLORS.CounterBg
    counterFrame.BorderSizePixel = 0
    counterFrame.Parent = contentFrame

    local counterCorner = Instance.new("UICorner")
    counterCorner.CornerRadius = SIZES.PillCorner
    counterCorner.Parent = counterFrame

    local counterStroke = Instance.new("UIStroke")
    counterStroke.Color = COLORS.CounterStroke
    counterStroke.Thickness = 1.5
    counterStroke.Transparency = 0.3
    counterStroke.Parent = counterFrame

    countLabel = Instance.new("TextLabel")
    countLabel.Name = "CountLabel"
    countLabel.Size = UDim2.new(1, 0, 1, 0)
    countLabel.BackgroundTransparency = 1
    countLabel.Text = "x0 Lucky Blocks"
    countLabel.TextColor3 = COLORS.White
    countLabel.TextSize = 16
    countLabel.Font = Enum.Font.GothamBold
    countLabel.Parent = counterFrame

    -- ── BUY BUTTONS ─────────────────────────────────────
    local buySection = Instance.new("Frame")
    buySection.Name = "BuySection"
    buySection.Size = UDim2.new(1, -48, 0, 48)
    buySection.Position = UDim2.new(0, 24, 0, 68)
    buySection.BackgroundTransparency = 1
    buySection.BorderSizePixel = 0
    buySection.Parent = contentFrame

    -- Buy 1 button
    local buyOneBtn = Instance.new("TextButton")
    buyOneBtn.Name = "BuyOneButton"
    buyOneBtn.Size = UDim2.new(0.48, 0, 1, 0)
    buyOneBtn.Position = UDim2.new(0, 0, 0, 0)
    buyOneBtn.BackgroundColor3 = COLORS.BuyBtn
    buyOneBtn.BorderSizePixel = 0
    buyOneBtn.Text = ""
    buyOneBtn.AutoButtonColor = false
    buyOneBtn.Parent = buySection

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
    buyOneStroke.Color = Color3.fromRGB(60, 210, 190)
    buyOneStroke.Thickness = 1.5
    buyOneStroke.Transparency = 0.3
    buyOneStroke.Parent = buyOneBtn

    local buyOneText = Instance.new("TextLabel")
    buyOneText.Name = "Label"
    buyOneText.Size = UDim2.new(1, 0, 1, 0)
    buyOneText.BackgroundTransparency = 1
    buyOneText.Text = "Buy 1  " .. utf8.char(0xE002) .. " " .. robuxPrice1
    buyOneText.TextColor3 = COLORS.White
    buyOneText.TextSize = 16
    buyOneText.Font = Enum.Font.GothamBold
    buyOneText.TextStrokeTransparency = 0.6
    buyOneText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    buyOneText.Parent = buyOneBtn

    -- Buy 3 button
    local buyThreeBtn = Instance.new("TextButton")
    buyThreeBtn.Name = "BuyThreeButton"
    buyThreeBtn.Size = UDim2.new(0.48, 0, 1, 0)
    buyThreeBtn.Position = UDim2.new(0.52, 0, 0, 0)
    buyThreeBtn.BackgroundColor3 = COLORS.BuyBtn
    buyThreeBtn.BorderSizePixel = 0
    buyThreeBtn.Text = ""
    buyThreeBtn.AutoButtonColor = false
    buyThreeBtn.Parent = buySection

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
    buyThreeStroke.Color = Color3.fromRGB(60, 210, 190)
    buyThreeStroke.Thickness = 1.5
    buyThreeStroke.Transparency = 0.3
    buyThreeStroke.Parent = buyThreeBtn

    local buyThreeText = Instance.new("TextLabel")
    buyThreeText.Name = "Label"
    buyThreeText.Size = UDim2.new(1, 0, 1, 0)
    buyThreeText.BackgroundTransparency = 1
    buyThreeText.Text = "Buy 3  " .. utf8.char(0xE002) .. " " .. robuxPrice3
    buyThreeText.TextColor3 = COLORS.White
    buyThreeText.TextSize = 16
    buyThreeText.Font = Enum.Font.GothamBold
    buyThreeText.TextStrokeTransparency = 0.6
    buyThreeText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    buyThreeText.Parent = buyThreeBtn

    -- ── OPEN BUTTON ─────────────────────────────────────
    openButton = Instance.new("TextButton")
    openButton.Name = "OpenButton"
    openButton.Size = UDim2.new(1, -48, 0, 56)
    openButton.Position = UDim2.new(0, 24, 0, 132)
    openButton.BackgroundColor3 = COLORS.OpenBtnDisabled
    openButton.BorderSizePixel = 0
    openButton.Text = ""
    openButton.AutoButtonColor = false
    openButton.Parent = contentFrame

    local openCorner = Instance.new("UICorner")
    openCorner.CornerRadius = SIZES.SmallCorner
    openCorner.Parent = openButton

    local openStroke = Instance.new("UIStroke")
    openStroke.Name = "OpenStroke"
    openStroke.Color = Color3.fromRGB(80, 90, 100)
    openStroke.Thickness = 1.5
    openStroke.Transparency = 0.3
    openStroke.Parent = openButton

    openButtonText = Instance.new("TextLabel")
    openButtonText.Name = "ButtonText"
    openButtonText.Size = UDim2.new(1, 0, 1, 0)
    openButtonText.BackgroundTransparency = 1
    openButtonText.Text = "No Lucky Blocks"
    openButtonText.TextColor3 = COLORS.SubText
    openButtonText.TextSize = 22
    openButtonText.Font = Enum.Font.GothamBlack
    openButtonText.TextStrokeTransparency = 0.6
    openButtonText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    openButtonText.Parent = openButton

    -- ── SLOT MACHINE FRAME (hidden by default) ──────────
    slotMachineFrame = Instance.new("Frame")
    slotMachineFrame.Name = "SlotMachineFrame"
    slotMachineFrame.Size = UDim2.new(1, 0, 1, 0)
    slotMachineFrame.Position = UDim2.new(0, 0, 0, 0)
    slotMachineFrame.BackgroundColor3 = COLORS.PanelBg
    slotMachineFrame.BorderSizePixel = 0
    slotMachineFrame.Visible = false
    slotMachineFrame.Parent = contentFrame

    -- ═══════════════════════════════════════════════════════
    -- BUTTON CONNECTIONS
    -- ═══════════════════════════════════════════════════════

    overlay.MouseButton1Click:Connect(function()
        if not isAnimating then
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
        if not isAnimating then
            closeUI()
        end
    end)

    -- Buy hover effects (tweened like Shop)
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
        buyLuckyBlockRemote:FireServer(1)
    end)

    buyThreeBtn.MouseButton1Click:Connect(function()
        buyLuckyBlockRemote:FireServer(3)
    end)

    -- Open hover and click
    openButton.MouseEnter:Connect(function()
        if luckyBlockCount > 0 and not isAnimating then
            TweenService:Create(openButton, TweenInfo.new(0.15), {
                BackgroundColor3 = COLORS.OpenBtnHover
            }):Play()
        end
    end)
    openButton.MouseLeave:Connect(function()
        if luckyBlockCount > 0 and not isAnimating then
            TweenService:Create(openButton, TweenInfo.new(0.15), {
                BackgroundColor3 = COLORS.OpenBtn
            }):Play()
        end
    end)
    openButton.MouseButton1Click:Connect(function()
        if luckyBlockCount > 0 and not isAnimating then
            openLuckyBlockRemote:FireServer()
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
    slotMachineFrame.Visible = false
    contentFrame.Visible = true

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
        isAnimating = false
        slotMachineFrame.Visible = false
    end)
end

-- ═══════════════════════════════════════════════════════
-- COUNTER UPDATE AND BUTTON STATE
-- ═══════════════════════════════════════════════════════

local function updateOpenButton()
    local openStroke = openButton:FindFirstChild("OpenStroke")
    if luckyBlockCount > 0 then
        TweenService:Create(openButton, TweenInfo.new(0.2), {
            BackgroundColor3 = COLORS.OpenBtn
        }):Play()
        openButtonText.Text = "OPEN!"
        openButtonText.TextColor3 = COLORS.White
        if openStroke then
            openStroke.Color = Color3.fromRGB(255, 210, 50)
        end
    else
        TweenService:Create(openButton, TweenInfo.new(0.2), {
            BackgroundColor3 = COLORS.OpenBtnDisabled
        }):Play()
        openButtonText.Text = "No Lucky Blocks"
        openButtonText.TextColor3 = COLORS.SubText
        if openStroke then
            openStroke.Color = Color3.fromRGB(80, 90, 100)
        end
    end
end

local function updateCount(count)
    luckyBlockCount = count
    if countLabel then
        countLabel.Text = "x" .. count .. " Lucky Block" .. (count ~= 1 and "s" or "")
    end
    updateOpenButton()
end

-- ═══════════════════════════════════════════════════════
-- SLOT MACHINE ANIMATION
-- ═══════════════════════════════════════════════════════

local function playSlotMachineAnimation(revealData)
    if isAnimating then return end
    isAnimating = true

    -- Expand panel for slot machine
    TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = SIZES.PanelSlot,
    }):Play()

    -- Clear and show slot machine frame
    for _, child in ipairs(slotMachineFrame:GetChildren()) do
        child:Destroy()
    end
    slotMachineFrame.Visible = true

    -- Column labels
    local columnNames = {"HEAD", "BODY", "LEGS"}
    local resultSets = {revealData.HeadSet, revealData.BodySet, revealData.LegsSet}
    local partTypes = {"Head", "Body", "Legs"}
    local stopDelays = {0, 0.5, 1.0}

    local contentWidth = 432  -- 480 - 48 padding
    local spacing = 12
    local columnWidth = math.floor((contentWidth - spacing * 2) / 3)
    local columns = {}

    for i = 1, 3 do
        -- Column card
        local colFrame = Instance.new("Frame")
        colFrame.Name = "Col_" .. columnNames[i]
        colFrame.Size = UDim2.new(0, columnWidth, 0, 180)
        colFrame.Position = UDim2.new(0, 24 + (i - 1) * (columnWidth + spacing), 0, 16)
        colFrame.BackgroundColor3 = COLORS.SlotColumnBg
        colFrame.BorderSizePixel = 0
        colFrame.ClipsDescendants = true
        colFrame.Parent = slotMachineFrame

        local colCorner = Instance.new("UICorner")
        colCorner.CornerRadius = SIZES.SmallCorner
        colCorner.Parent = colFrame

        local colStroke = Instance.new("UIStroke")
        colStroke.Color = COLORS.SlotColumnStroke
        colStroke.Thickness = 1.5
        colStroke.Transparency = 0.3
        colStroke.Parent = colFrame

        -- Column gradient
        local colGradient = Instance.new("UIGradient")
        colGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 200, 210)),
        })
        colGradient.Rotation = 90
        colGradient.Parent = colFrame

        -- Title label (HEAD/BODY/LEGS)
        local colTitle = Instance.new("TextLabel")
        colTitle.Name = "Title"
        colTitle.Size = UDim2.new(1, 0, 0, 28)
        colTitle.Position = UDim2.new(0, 0, 0, 8)
        colTitle.BackgroundTransparency = 1
        colTitle.Text = columnNames[i]
        colTitle.TextColor3 = COLORS.SubText
        colTitle.TextSize = 13
        colTitle.Font = Enum.Font.GothamBold
        colTitle.Parent = colFrame

        -- Name label
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "NameLabel"
        nameLabel.Size = UDim2.new(1, -16, 0, 50)
        nameLabel.Position = UDim2.new(0, 8, 0, 40)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = "..."
        nameLabel.TextColor3 = COLORS.White
        nameLabel.TextSize = 16
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextWrapped = true
        nameLabel.TextStrokeTransparency = 0.6
        nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        nameLabel.Parent = colFrame

        -- Rarity label
        local rarityLabel = Instance.new("TextLabel")
        rarityLabel.Name = "RarityLabel"
        rarityLabel.Size = UDim2.new(1, -16, 0, 24)
        rarityLabel.Position = UDim2.new(0, 8, 0, 100)
        rarityLabel.BackgroundTransparency = 1
        rarityLabel.Text = ""
        rarityLabel.TextColor3 = COLORS.SubText
        rarityLabel.TextSize = 14
        rarityLabel.Font = Enum.Font.GothamBold
        rarityLabel.Parent = colFrame

        -- Price label
        local priceLabel = Instance.new("TextLabel")
        priceLabel.Name = "PriceLabel"
        priceLabel.Size = UDim2.new(1, -16, 0, 24)
        priceLabel.Position = UDim2.new(0, 8, 0, 130)
        priceLabel.BackgroundTransparency = 1
        priceLabel.Text = ""
        priceLabel.TextColor3 = COLORS.GoldText
        priceLabel.TextSize = 15
        priceLabel.Font = Enum.Font.GothamBlack
        priceLabel.Parent = colFrame

        columns[i] = {
            frame = colFrame,
            stroke = colStroke,
            nameLabel = nameLabel,
            rarityLabel = rarityLabel,
            priceLabel = priceLabel,
            partType = partTypes[i],
            resultSet = resultSets[i],
            stopDelay = stopDelays[i],
        }
    end

    -- Result label (bottom)
    local resultLabel = Instance.new("TextLabel")
    resultLabel.Name = "ResultLabel"
    resultLabel.Size = UDim2.new(1, -48, 0, 36)
    resultLabel.Position = UDim2.new(0, 24, 0, 210)
    resultLabel.BackgroundTransparency = 1
    resultLabel.Text = ""
    resultLabel.TextColor3 = COLORS.GoldText
    resultLabel.TextSize = 18
    resultLabel.Font = Enum.Font.GothamBlack
    resultLabel.TextWrapped = true
    resultLabel.TextStrokeTransparency = 0.5
    resultLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    resultLabel.Parent = slotMachineFrame

    -- TAKE button (green)
    local takeButton = Instance.new("TextButton")
    takeButton.Name = "TakeButton"
    takeButton.Size = UDim2.new(0, 180, 0, 44)
    takeButton.Position = UDim2.new(0.5, -5, 0, 255)
    takeButton.AnchorPoint = Vector2.new(1, 0)
    takeButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
    takeButton.BorderSizePixel = 0
    takeButton.Text = ""
    takeButton.AutoButtonColor = false
    takeButton.Visible = false
    takeButton.Parent = slotMachineFrame

    local takeCorner = Instance.new("UICorner")
    takeCorner.CornerRadius = SIZES.SmallCorner
    takeCorner.Parent = takeButton

    local takeGradient = Instance.new("UIGradient")
    takeGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 220, 200)),
    })
    takeGradient.Rotation = 90
    takeGradient.Parent = takeButton

    local takeStroke = Instance.new("UIStroke")
    takeStroke.Color = Color3.fromRGB(0, 220, 0)
    takeStroke.Thickness = 1.5
    takeStroke.Transparency = 0.3
    takeStroke.Parent = takeButton

    local takeText = Instance.new("TextLabel")
    takeText.Name = "Label"
    takeText.Size = UDim2.new(1, 0, 1, 0)
    takeText.BackgroundTransparency = 1
    takeText.Text = "TAKE"
    takeText.TextColor3 = COLORS.White
    takeText.TextSize = 18
    takeText.Font = Enum.Font.GothamBlack
    takeText.TextStrokeTransparency = 0.6
    takeText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    takeText.Parent = takeButton

    takeButton.MouseEnter:Connect(function()
        TweenService:Create(takeButton, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(0, 200, 0)
        }):Play()
    end)
    takeButton.MouseLeave:Connect(function()
        TweenService:Create(takeButton, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(0, 170, 0)
        }):Play()
    end)

    takeButton.MouseButton1Click:Connect(function()
        luckyBlockTakeRemote:FireServer()
        slotMachineFrame.Visible = false
        isAnimating = false
        TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = SIZES.Panel,
        }):Play()
    end)

    -- THROW button (red)
    local throwButton = Instance.new("TextButton")
    throwButton.Name = "ThrowButton"
    throwButton.Size = UDim2.new(0, 180, 0, 44)
    throwButton.Position = UDim2.new(0.5, 5, 0, 255)
    throwButton.AnchorPoint = Vector2.new(0, 0)
    throwButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
    throwButton.BorderSizePixel = 0
    throwButton.Text = ""
    throwButton.AutoButtonColor = false
    throwButton.Visible = false
    throwButton.Parent = slotMachineFrame

    local throwCorner = Instance.new("UICorner")
    throwCorner.CornerRadius = SIZES.SmallCorner
    throwCorner.Parent = throwButton

    local throwGradient = Instance.new("UIGradient")
    throwGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 200, 200)),
    })
    throwGradient.Rotation = 90
    throwGradient.Parent = throwButton

    local throwStroke = Instance.new("UIStroke")
    throwStroke.Color = Color3.fromRGB(220, 60, 60)
    throwStroke.Thickness = 1.5
    throwStroke.Transparency = 0.3
    throwStroke.Parent = throwButton

    local throwText = Instance.new("TextLabel")
    throwText.Name = "Label"
    throwText.Size = UDim2.new(1, 0, 1, 0)
    throwText.BackgroundTransparency = 1
    throwText.Text = "THROW"
    throwText.TextColor3 = COLORS.White
    throwText.TextSize = 18
    throwText.Font = Enum.Font.GothamBlack
    throwText.TextStrokeTransparency = 0.6
    throwText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    throwText.Parent = throwButton

    throwButton.MouseEnter:Connect(function()
        TweenService:Create(throwButton, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(210, 50, 50)
        }):Play()
    end)
    throwButton.MouseLeave:Connect(function()
        TweenService:Create(throwButton, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(180, 40, 40)
        }):Play()
    end)

    throwButton.MouseButton1Click:Connect(function()
        luckyBlockThrowRemote:FireServer()
        slotMachineFrame.Visible = false
        isAnimating = false
        TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = SIZES.Panel,
        }):Play()
    end)

    -- Animate each column
    for i, col in ipairs(columns) do
        task.spawn(function()
            local availableInfo = displayInfoByPart[col.partType]
            if #availableInfo == 0 then
                col.nameLabel.Text = col.resultSet
                return
            end

            -- Resolve the final result info
            local resultDisplayName = col.resultSet
            local resultRarity = "Common"
            local resultPrice = 0
            local resultSetData = BrainrotData.Sets[col.resultSet]
            if resultSetData then
                resultRarity = resultSetData.Rarity or "Common"
                if resultSetData[col.partType] then
                    resultDisplayName = resultSetData[col.partType].DisplayName or col.resultSet
                    resultPrice = resultSetData[col.partType].Price or 0
                end
            end

            -- Fast scrolling phase (2s + stopDelay)
            local totalDuration = 2.0 + col.stopDelay
            local startTime = tick()
            local minInterval = 0.05
            local maxInterval = 0.35

            while true do
                local elapsed = tick() - startTime
                if elapsed >= totalDuration then break end

                -- Lerp: interval slows from minInterval to maxInterval
                local progress = elapsed / totalDuration
                local interval = minInterval + (maxInterval - minInterval) * (progress * progress)

                -- Display a random entry with name, rarity, price
                local randomEntry = availableInfo[math.random(1, #availableInfo)]
                col.nameLabel.Text = randomEntry.Name
                col.nameLabel.TextColor3 = COLORS.White
                col.rarityLabel.Text = randomEntry.Rarity
                col.rarityLabel.TextColor3 = RARITY_COLORS[randomEntry.Rarity] or COLORS.White
                col.priceLabel.Text = "$" .. randomEntry.Price

                task.wait(interval)
            end

            -- Final result
            local rarityColor = RARITY_COLORS[resultRarity] or COLORS.GoldText
            col.nameLabel.Text = resultDisplayName
            col.nameLabel.TextColor3 = rarityColor
            col.rarityLabel.Text = resultRarity
            col.rarityLabel.TextColor3 = rarityColor
            col.priceLabel.Text = "$" .. resultPrice
            col.priceLabel.TextColor3 = COLORS.GoldText

            -- Confirmation flash on column
            TweenService:Create(col.frame, TweenInfo.new(0.15), {
                BackgroundColor3 = COLORS.SlotColumnFlash,
            }):Play()
            TweenService:Create(col.stroke, TweenInfo.new(0.15), {
                Color = rarityColor,
                Transparency = 0,
            }):Play()
            task.wait(0.2)
            TweenService:Create(col.frame, TweenInfo.new(0.3), {
                BackgroundColor3 = COLORS.SlotColumnBg,
            }):Play()
            TweenService:Create(col.stroke, TweenInfo.new(0.3), {
                Transparency = 0.3,
            }):Play()
        end)
    end

    -- Show result after all columns stop
    task.spawn(function()
        task.wait(3.5)
        resultLabel.Text = "Take or throw?"
        takeButton.Visible = true
        throwButton.Visible = true
    end)
end

-- ═══════════════════════════════════════════════════════
-- PROXIMITY PROMPT ON LUCKYBLOCKBASE
-- ═══════════════════════════════════════════════════════

local function attachPromptToMachine(luckyBlockBase)
    -- Find a BasePart to attach the ProximityPrompt
    local targetPart = nil
    if luckyBlockBase:IsA("BasePart") then
        targetPart = luckyBlockBase
    elseif luckyBlockBase:IsA("Model") then
        targetPart = luckyBlockBase.PrimaryPart or luckyBlockBase:FindFirstChildWhichIsA("BasePart", true)
    end

    if not targetPart then
        local anchor = Instance.new("Part")
        anchor.Name = "PromptAnchor"
        anchor.Size = Vector3.new(1, 1, 1)
        anchor.Transparency = 1
        anchor.CanCollide = false
        anchor.Anchored = true
        if luckyBlockBase:IsA("Model") and luckyBlockBase:GetBoundingBox() then
            anchor.CFrame = luckyBlockBase:GetBoundingBox()
        else
            anchor.CFrame = CFrame.new(luckyBlockBase:GetPivot().Position)
        end
        anchor.Parent = luckyBlockBase
        targetPart = anchor
    end

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Lucky Block"
    prompt.ObjectText = ""
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = 15
    prompt.RequiresLineOfSight = false
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.Parent = targetPart

    prompt.Triggered:Connect(function(playerWhoTriggered)
        if playerWhoTriggered == player then
            openUI()
        end
    end)
end

local function setupProximityPrompt()
    local shops = Workspace:FindFirstChild("Shops")
    if not shops then
        warn("[LuckyBlockController] workspace.Shops not found, retrying in 5s...")
        task.wait(5)
        shops = Workspace:FindFirstChild("Shops")
        if not shops then
            warn("[LuckyBlockController] workspace.Shops still not found!")
            return
        end
    end

    -- Attach a ProximityPrompt to ALL LuckyBlockBase instances (supports duplicates with any name suffix)
    local count = 0
    for _, desc in ipairs(shops:GetDescendants()) do
        if string.sub(desc.Name, 1, 14) == "LuckyBlockBase" and (desc:IsA("BasePart") or desc:IsA("Model")) then
            -- Skip if it's a BasePart inside a Model that was already processed
            local parent = desc.Parent
            local alreadyCovered = false
            if desc:IsA("BasePart") and parent and string.sub(parent.Name, 1, 14) == "LuckyBlockBase" then
                alreadyCovered = true
            end
            if not alreadyCovered then
                attachPromptToMachine(desc)
                count = count + 1
            end
        end
    end

    if count == 0 then
        warn("[LuckyBlockController] workspace.Shops.LuckyBlockBase not found!")
    else
        print("[LuckyBlockController] ProximityPrompt placed on " .. count .. " LuckyBlockBase(s)")
    end
end

-- ═══════════════════════════════════════════════════════
-- REMOTE LISTENERS
-- ═══════════════════════════════════════════════════════

syncLuckyBlockData.OnClientEvent:Connect(function(data)
    if data and data.Count ~= nil then
        updateCount(data.Count)
    end
end)

luckyBlockReveal.OnClientEvent:Connect(function(revealData)
    if revealData then
        -- If the UI is not open, open it
        if not isOpen then
            openUI()
            task.wait(0.4) -- let the open animation play
        end
        playSlotMachineAnimation(revealData)
    end
end)

-- ═══════════════════════════════════════════════════════
-- INITIALIZATION
-- ═══════════════════════════════════════════════════════

createUI()
setupProximityPrompt()

print("[LuckyBlockController] Initialized!")
