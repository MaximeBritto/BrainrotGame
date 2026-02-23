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

-- Data
local Data = ReplicatedStorage:WaitForChild("Data")
local BrainrotData = require(Data:WaitForChild("BrainrotData.module"))
local ShopProducts = require(Data:WaitForChild("ShopProducts.module"))

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local buyLuckyBlockRemote = Remotes:WaitForChild("BuyLuckyBlock")
local openLuckyBlockRemote = Remotes:WaitForChild("OpenLuckyBlock")
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
    if category.Id == "LuckyBlocks" then
        for _, product in ipairs(category.Products) do
            if product.LuckyBlocks == 1 then
                robuxPrice1 = product.Robux
            elseif product.LuckyBlocks == 3 then
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
    OpenBtn = Color3.fromRGB(220, 160, 0),
    OpenBtnHover = Color3.fromRGB(250, 185, 20),
    OpenBtnDisabled = Color3.fromRGB(80, 80, 80),
    White = Color3.fromRGB(255, 255, 255),
    LightGray = Color3.fromRGB(180, 180, 180),
    Gold = Color3.fromRGB(255, 215, 0),
    SlotBg = Color3.fromRGB(30, 25, 50),
    SlotColumnBg = Color3.fromRGB(15, 10, 30),
    Divider = Color3.fromRGB(60, 50, 90),
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
    title.Text = "LUCKY BLOCK"
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

    -- Lucky Blocks counter
    countLabel = Instance.new("TextLabel")
    countLabel.Name = "CountLabel"
    countLabel.Size = UDim2.new(1, -40, 0, 35)
    countLabel.Position = UDim2.new(0, 20, 0, 60)
    countLabel.BackgroundTransparency = 1
    countLabel.Text = "You have: 0 Lucky Block(s)"
    countLabel.TextColor3 = COLORS.White
    countLabel.TextSize = 20
    countLabel.Font = Enum.Font.GothamBold
    countLabel.TextXAlignment = Enum.TextXAlignment.Center
    countLabel.Parent = mainFrame

    -- Buy section
    local buySection = Instance.new("Frame")
    buySection.Name = "BuySection"
    buySection.Size = UDim2.new(1, -40, 0, 50)
    buySection.Position = UDim2.new(0, 20, 0, 105)
    buySection.BackgroundTransparency = 1
    buySection.Parent = mainFrame

    -- Buy 1 button
    local buyOneBtn = Instance.new("TextButton")
    buyOneBtn.Name = "BuyOneButton"
    buyOneBtn.Size = UDim2.new(0.48, 0, 0, 45)
    buyOneBtn.Position = UDim2.new(0, 0, 0, 0)
    buyOneBtn.BackgroundColor3 = COLORS.BuyBtn
    buyOneBtn.BorderSizePixel = 0
    buyOneBtn.Text = "Buy 1 - " .. utf8.char(0xE002) .. robuxPrice1
    buyOneBtn.TextColor3 = COLORS.White
    buyOneBtn.TextSize = 16
    buyOneBtn.Font = Enum.Font.GothamBold
    buyOneBtn.AutoButtonColor = false
    buyOneBtn.Parent = buySection

    local buyOneCorner = Instance.new("UICorner")
    buyOneCorner.CornerRadius = UDim.new(0, 8)
    buyOneCorner.Parent = buyOneBtn

    -- Buy 3 button
    local buyThreeBtn = Instance.new("TextButton")
    buyThreeBtn.Name = "BuyThreeButton"
    buyThreeBtn.Size = UDim2.new(0.48, 0, 0, 45)
    buyThreeBtn.Position = UDim2.new(0.52, 0, 0, 0)
    buyThreeBtn.BackgroundColor3 = COLORS.BuyBtn
    buyThreeBtn.BorderSizePixel = 0
    buyThreeBtn.Text = "Buy 3 - " .. utf8.char(0xE002) .. robuxPrice3
    buyThreeBtn.TextColor3 = COLORS.White
    buyThreeBtn.TextSize = 16
    buyThreeBtn.Font = Enum.Font.GothamBold
    buyThreeBtn.AutoButtonColor = false
    buyThreeBtn.Parent = buySection

    local buyThreeCorner = Instance.new("UICorner")
    buyThreeCorner.CornerRadius = UDim.new(0, 8)
    buyThreeCorner.Parent = buyThreeBtn

    -- Divider
    local divider = Instance.new("Frame")
    divider.Name = "Divider"
    divider.Size = UDim2.new(1, -40, 0, 2)
    divider.Position = UDim2.new(0, 20, 0, 170)
    divider.BackgroundColor3 = COLORS.Divider
    divider.BorderSizePixel = 0
    divider.Parent = mainFrame

    -- Open button
    openButton = Instance.new("TextButton")
    openButton.Name = "OpenButton"
    openButton.Size = UDim2.new(1, -40, 0, 55)
    openButton.Position = UDim2.new(0, 20, 0, 185)
    openButton.BackgroundColor3 = COLORS.OpenBtnDisabled
    openButton.BorderSizePixel = 0
    openButton.Text = ""
    openButton.AutoButtonColor = false
    openButton.Parent = mainFrame

    local openCorner = Instance.new("UICorner")
    openCorner.CornerRadius = UDim.new(0, 10)
    openCorner.Parent = openButton

    openButtonText = Instance.new("TextLabel")
    openButtonText.Name = "ButtonText"
    openButtonText.Size = UDim2.new(1, 0, 1, 0)
    openButtonText.BackgroundTransparency = 1
    openButtonText.Text = "Open a Lucky Block!"
    openButtonText.TextColor3 = COLORS.LightGray
    openButtonText.TextSize = 22
    openButtonText.Font = Enum.Font.GothamBlack
    openButtonText.Parent = openButton

    -- Slot Machine Frame (hidden by default, overlaid on MainFrame)
    slotMachineFrame = Instance.new("Frame")
    slotMachineFrame.Name = "SlotMachineFrame"
    slotMachineFrame.Size = UDim2.new(1, 0, 1, -50) -- below the header
    slotMachineFrame.Position = UDim2.new(0, 0, 0, 50)
    slotMachineFrame.BackgroundColor3 = COLORS.SlotBg
    slotMachineFrame.BorderSizePixel = 0
    slotMachineFrame.Visible = false
    slotMachineFrame.Parent = mainFrame

    -- ═══════════════════════════════════════════════════════
    -- BUTTON CONNECTIONS
    -- ═══════════════════════════════════════════════════════

    overlay.MouseButton1Click:Connect(function()
        if not isAnimating then
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
        if not isAnimating then
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
        buyLuckyBlockRemote:FireServer(1)
    end)

    buyThreeBtn.MouseButton1Click:Connect(function()
        buyLuckyBlockRemote:FireServer(3)
    end)

    -- Open hover and click
    openButton.MouseEnter:Connect(function()
        if luckyBlockCount > 0 and not isAnimating then
            openButton.BackgroundColor3 = COLORS.OpenBtnHover
        end
    end)
    openButton.MouseLeave:Connect(function()
        if luckyBlockCount > 0 and not isAnimating then
            openButton.BackgroundColor3 = COLORS.OpenBtn
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

local PANEL_SIZE = UDim2.new(0, 400, 0, 260)
local PANEL_CLOSED = UDim2.new(0, 0, 0, 0)

local function openUI()
    if isOpen then return end
    isOpen = true
    screenGui.Enabled = true
    slotMachineFrame.Visible = false

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
        isAnimating = false
        slotMachineFrame.Visible = false
    end)
end

-- ═══════════════════════════════════════════════════════
-- COUNTER UPDATE AND BUTTON STATE
-- ═══════════════════════════════════════════════════════

local function updateOpenButton()
    if luckyBlockCount > 0 then
        openButton.BackgroundColor3 = COLORS.OpenBtn
        openButtonText.Text = "Open a Lucky Block!"
        openButtonText.TextColor3 = COLORS.White
    else
        openButton.BackgroundColor3 = COLORS.OpenBtnDisabled
        openButtonText.Text = "No Lucky Blocks"
        openButtonText.TextColor3 = COLORS.LightGray
    end
end

local function updateCount(count)
    luckyBlockCount = count
    if countLabel then
        countLabel.Text = "You have: " .. count .. " Lucky Block(s)"
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
    local SLOT_PANEL_SIZE = UDim2.new(0, 420, 0, 350)
    TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
        Size = SLOT_PANEL_SIZE,
    }):Play()

    -- Clear slot machine frame
    for _, child in ipairs(slotMachineFrame:GetChildren()) do
        child:Destroy()
    end
    slotMachineFrame.Visible = true

    -- Column labels
    local columnNames = {"HEAD", "BODY", "LEGS"}
    local resultSets = {revealData.HeadSet, revealData.BodySet, revealData.LegsSet}
    local partTypes = {"Head", "Body", "Legs"}
    local stopDelays = {0, 0.5, 1.0} -- stop delay offset between columns

    local columnWidth = math.floor(380 / 3)
    local columns = {}

    for i = 1, 3 do
        -- Column container
        local colFrame = Instance.new("Frame")
        colFrame.Name = "Col_" .. columnNames[i]
        colFrame.Size = UDim2.new(0, columnWidth - 8, 0, 140)
        colFrame.Position = UDim2.new(0, 10 + (i - 1) * columnWidth, 0, 15)
        colFrame.BackgroundColor3 = COLORS.SlotColumnBg
        colFrame.BorderSizePixel = 0
        colFrame.ClipsDescendants = true
        colFrame.Parent = slotMachineFrame

        local colCorner = Instance.new("UICorner")
        colCorner.CornerRadius = UDim.new(0, 8)
        colCorner.Parent = colFrame

        local colStroke = Instance.new("UIStroke")
        colStroke.Color = Color3.fromRGB(80, 60, 140)
        colStroke.Thickness = 1
        colStroke.Parent = colFrame

        -- Title label (HEAD/BODY/LEGS)
        local colTitle = Instance.new("TextLabel")
        colTitle.Name = "Title"
        colTitle.Size = UDim2.new(1, 0, 0, 25)
        colTitle.Position = UDim2.new(0, 0, 0, 5)
        colTitle.BackgroundTransparency = 1
        colTitle.Text = columnNames[i]
        colTitle.TextColor3 = COLORS.Gold
        colTitle.TextSize = 14
        colTitle.Font = Enum.Font.GothamBold
        colTitle.Parent = colFrame

        -- Name label
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "NameLabel"
        nameLabel.Size = UDim2.new(1, -10, 0, 40)
        nameLabel.Position = UDim2.new(0, 5, 0, 35)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = "..."
        nameLabel.TextColor3 = COLORS.White
        nameLabel.TextSize = 15
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextWrapped = true
        nameLabel.Parent = colFrame

        -- Rarity label
        local rarityLabel = Instance.new("TextLabel")
        rarityLabel.Name = "RarityLabel"
        rarityLabel.Size = UDim2.new(1, -10, 0, 22)
        rarityLabel.Position = UDim2.new(0, 5, 0, 80)
        rarityLabel.BackgroundTransparency = 1
        rarityLabel.Text = ""
        rarityLabel.TextColor3 = COLORS.LightGray
        rarityLabel.TextSize = 13
        rarityLabel.Font = Enum.Font.GothamBold
        rarityLabel.Parent = colFrame

        -- Price label
        local priceLabel = Instance.new("TextLabel")
        priceLabel.Name = "PriceLabel"
        priceLabel.Size = UDim2.new(1, -10, 0, 22)
        priceLabel.Position = UDim2.new(0, 5, 0, 105)
        priceLabel.BackgroundTransparency = 1
        priceLabel.Text = ""
        priceLabel.TextColor3 = COLORS.Gold
        priceLabel.TextSize = 13
        priceLabel.Font = Enum.Font.GothamBold
        priceLabel.Parent = colFrame

        columns[i] = {
            frame = colFrame,
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
    resultLabel.Size = UDim2.new(1, -20, 0, 40)
    resultLabel.Position = UDim2.new(0, 10, 0, 185)
    resultLabel.BackgroundTransparency = 1
    resultLabel.Text = ""
    resultLabel.TextColor3 = COLORS.Gold
    resultLabel.TextSize = 18
    resultLabel.Font = Enum.Font.GothamBlack
    resultLabel.TextWrapped = true
    resultLabel.Parent = slotMachineFrame

    -- OK button (appears at the end)
    local okButton = Instance.new("TextButton")
    okButton.Name = "OkButton"
    okButton.Size = UDim2.new(0.5, 0, 0, 40)
    okButton.Position = UDim2.new(0.25, 0, 0, 235)
    okButton.BackgroundColor3 = COLORS.OpenBtn
    okButton.BorderSizePixel = 0
    okButton.Text = "OK"
    okButton.TextColor3 = COLORS.White
    okButton.TextSize = 20
    okButton.Font = Enum.Font.GothamBold
    okButton.Visible = false
    okButton.Parent = slotMachineFrame

    local okCorner = Instance.new("UICorner")
    okCorner.CornerRadius = UDim.new(0, 8)
    okCorner.Parent = okButton

    okButton.MouseButton1Click:Connect(function()
        slotMachineFrame.Visible = false
        isAnimating = false
        -- Return to normal size
        TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
            Size = PANEL_SIZE,
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
                col.rarityLabel.Text = randomEntry.Rarity
                col.rarityLabel.TextColor3 = RARITY_COLORS[randomEntry.Rarity] or COLORS.White
                col.priceLabel.Text = "$" .. randomEntry.Price

                task.wait(interval)
            end

            -- Final result
            col.nameLabel.Text = resultDisplayName
            col.nameLabel.TextColor3 = RARITY_COLORS[resultRarity] or COLORS.Gold
            col.rarityLabel.Text = resultRarity
            col.rarityLabel.TextColor3 = RARITY_COLORS[resultRarity] or COLORS.White
            col.priceLabel.Text = "$" .. resultPrice
            col.priceLabel.TextColor3 = COLORS.Gold

            -- Confirmation flash
            TweenService:Create(col.frame, TweenInfo.new(0.15), {
                BackgroundColor3 = Color3.fromRGB(50, 40, 80),
            }):Play()
            task.wait(0.15)
            TweenService:Create(col.frame, TweenInfo.new(0.3), {
                BackgroundColor3 = COLORS.SlotColumnBg,
            }):Play()
        end)
    end

    -- Show result after all columns stop
    task.spawn(function()
        task.wait(3.5)
        resultLabel.Text = "Brainrot placed in Slot " .. revealData.SlotIndex .. "!"
        okButton.Visible = true
    end)
end

-- ═══════════════════════════════════════════════════════
-- PROXIMITY PROMPT ON LUCKYBLOCKBASE
-- ═══════════════════════════════════════════════════════

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

    local luckyBlockBase = shops:FindFirstChild("LuckyBlockBase")
    if not luckyBlockBase then
        warn("[LuckyBlockController] workspace.Shops.LuckyBlockBase not found!")
        return
    end

    -- Find a BasePart to attach the ProximityPrompt
    -- If the model has no BasePart, create an invisible one at its position
    local targetPart = nil
    if luckyBlockBase:IsA("BasePart") then
        targetPart = luckyBlockBase
    elseif luckyBlockBase:IsA("Model") then
        targetPart = luckyBlockBase.PrimaryPart or luckyBlockBase:FindFirstChildWhichIsA("BasePart", true)
    end

    if not targetPart then
        -- Create an invisible anchored Part at the model center
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
        print("[LuckyBlockController] Invisible part created as ProximityPrompt anchor")
    end

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Lucky Block"
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

    print("[LuckyBlockController] ProximityPrompt placed on LuckyBlockBase")
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
