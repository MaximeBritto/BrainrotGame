--[[
    CodexController.module.lua
    Index-style Codex: card grid, rarity sidebar, 3D ViewportFrame previews
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local BrainrotData = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("BrainrotData.module"))

local CodexController = {}
CodexController._codexUnlocked = {}
CodexController._codexUI = nil
CodexController._initialized = false
CodexController._activeFilter = nil -- nil = all, or rarity string
CodexController._gridContainer = nil
CodexController._counterLabel = nil
CodexController._subtitleLabel = nil
CodexController._tabs = {}
CodexController._bottomText = nil
CodexController._progressFill = nil
CodexController._progressCount = nil

-- ══════════════════════════════════════════
-- Rarity display names
-- ══════════════════════════════════════════
local RARITY_DISPLAY = {
    Common = "Common",
    Rare = "Rare",
    Epic = "Epic",
    Legendary = "Legendary",
}

-- ══════════════════════════════════════════
-- Set display names
-- ══════════════════════════════════════════
local SET_DISPLAY_NAMES = {
    brrbrrPatapim = "Brr Brr Patapim",
    TralaleroTralala = "Tralalero Tralala",
    CactoHipopoTamo = "Cacto Hipopo Tamo",
    PiccioneMacchina = "Piccione Macchina",
    GirafaCelestre = "Girafa Celestre",
    LiriliLarila = "Lirilì Larilà",
    TripiTropiTropaTripa = "Tripi Tropi",
    Talpadifero = "Talpa di Fero",
    GraipusMedussi = "Graipus Medussi",
    BombardiroCrocodilo = "Bombardiro Crocodilo",
    SpioniroGolubiro = "Spioniro Golubiro",
    ZibraZubraZibralini = "Zibra Zubra Zibralini",
    TorrtuginniDragonfrutini = "Torrtuginni Dragonfrutini",
}

-- ══════════════════════════════════════════
-- Helpers
-- ══════════════════════════════════════════

local function getPartsUnlocked(unlocked, setName)
    local d = unlocked[setName]
    if d == true then return { Head = true, Body = true, Legs = true } end
    if type(d) == "table" then
        return { Head = d.Head == true, Body = d.Body == true, Legs = d.Legs == true }
    end
    return { Head = false, Body = false, Legs = false }
end

-- ══════════════════════════════════════════
-- Initialization
-- ══════════════════════════════════════════

function CodexController:Init()
    if self._initialized then return end

    local gui = player:WaitForChild("PlayerGui")
    self._codexUI = gui:WaitForChild("CodexUI")

    -- Remove old UI
    for _, child in ipairs(self._codexUI:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end

    -- Build new UI
    self:_BuildUI()

    -- Connect SyncCodex
    local Remotes = ReplicatedStorage:WaitForChild("Remotes")
    local syncCodex = Remotes:WaitForChild("SyncCodex")
    syncCodex.OnClientEvent:Connect(function(codexUnlocked)
        self:UpdateCodex(codexUnlocked or {})
    end)

    self._initialized = true
end

-- ══════════════════════════════════════════
-- UI Construction
-- ══════════════════════════════════════════

function CodexController:_BuildUI()
    local screenGui = self._codexUI

    -- ═══ MAIN FRAME ═══
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0.72, 0, 0.78, 0)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = screenGui

    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)

    -- ═══ SIDEBAR ═══
    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0.17, 0, 1, 0)
    sidebar.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
    sidebar.BorderSizePixel = 0
    sidebar.Parent = mainFrame

    self:_BuildSidebar(sidebar)

    -- ═══ CONTENT AREA ═══
    local content = Instance.new("Frame")
    content.Name = "ContentArea"
    content.Size = UDim2.new(0.83, 0, 1, 0)
    content.Position = UDim2.new(0.17, 0, 0, 0)
    content.BackgroundTransparency = 1
    content.Parent = mainFrame

    -- ── Header ──
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 60)
    header.BackgroundTransparency = 1
    header.Parent = content

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.5, 0, 0, 28)
    title.Position = UDim2.new(0, 15, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = "Index"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextSize = 24
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(0.5, 0, 0, 16)
    subtitle.Position = UDim2.new(0, 15, 0, 38)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "All Brainrots"
    subtitle.TextColor3 = Color3.fromRGB(170, 170, 180)
    subtitle.TextSize = 13
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Parent = header
    self._subtitleLabel = subtitle

    local counter = Instance.new("TextLabel")
    counter.Name = "Counter"
    counter.Size = UDim2.new(0, 80, 0, 35)
    counter.Position = UDim2.new(1, -120, 0, 10)
    counter.BackgroundTransparency = 1
    counter.Text = "0/0"
    counter.TextColor3 = Color3.new(1, 1, 1)
    counter.TextSize = 22
    counter.Font = Enum.Font.GothamBold
    counter.TextXAlignment = Enum.TextXAlignment.Right
    counter.Parent = header
    self._counterLabel = counter

    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 35, 0, 35)
    closeBtn.Position = UDim2.new(1, -42, 0, 10)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.TextSize = 18
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = header
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
    closeBtn.MouseButton1Click:Connect(function() self:Close() end)

    -- Separator
    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(1, -20, 0, 1)
    sep.Position = UDim2.new(0, 10, 0, 58)
    sep.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
    sep.BorderSizePixel = 0
    sep.Parent = content

    -- ── Grid ScrollingFrame ──
    local gridScroll = Instance.new("ScrollingFrame")
    gridScroll.Name = "GridScroll"
    gridScroll.Size = UDim2.new(1, -10, 1, -125)
    gridScroll.Position = UDim2.new(0, 5, 0, 65)
    gridScroll.BackgroundTransparency = 1
    gridScroll.BorderSizePixel = 0
    gridScroll.ScrollBarThickness = 5
    gridScroll.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 100)
    gridScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    gridScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    gridScroll.Parent = content

    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0.24, -3, 0, 200)
    gridLayout.CellPadding = UDim2.new(0, 5, 0, 6)
    gridLayout.FillDirection = Enum.FillDirection.Horizontal
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = gridScroll

    local gridPad = Instance.new("UIPadding")
    gridPad.PaddingLeft = UDim.new(0, 4)
    gridPad.PaddingTop = UDim.new(0, 4)
    gridPad.Parent = gridScroll

    self._gridContainer = gridScroll

    -- ── Bottom Bar ──
    local bottomBar = Instance.new("Frame")
    bottomBar.Name = "BottomBar"
    bottomBar.Size = UDim2.new(1, -10, 0, 50)
    bottomBar.Position = UDim2.new(0, 5, 1, -55)
    bottomBar.BackgroundColor3 = Color3.fromRGB(30, 85, 30)
    bottomBar.BorderSizePixel = 0
    bottomBar.Parent = content
    Instance.new("UICorner", bottomBar).CornerRadius = UDim.new(0, 8)

    local bottomText = Instance.new("TextLabel")
    bottomText.Size = UDim2.new(1, -20, 0, 20)
    bottomText.Position = UDim2.new(0, 10, 0, 4)
    bottomText.BackgroundTransparency = 1
    bottomText.Text = "Collect Brainrots to unlock bonuses!"
    bottomText.TextColor3 = Color3.new(1, 1, 1)
    bottomText.TextSize = 12
    bottomText.Font = Enum.Font.Gotham
    bottomText.TextXAlignment = Enum.TextXAlignment.Left
    bottomText.TextTruncate = Enum.TextTruncate.AtEnd
    bottomText.Parent = bottomBar
    self._bottomText = bottomText

    local progBg = Instance.new("Frame")
    progBg.Size = UDim2.new(1, -20, 0, 14)
    progBg.Position = UDim2.new(0, 10, 0, 28)
    progBg.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
    progBg.BorderSizePixel = 0
    progBg.Parent = bottomBar
    Instance.new("UICorner", progBg).CornerRadius = UDim.new(0, 4)

    local progFill = Instance.new("Frame")
    progFill.Size = UDim2.new(0, 0, 1, 0)
    progFill.BackgroundColor3 = Color3.fromRGB(240, 190, 70)
    progFill.BorderSizePixel = 0
    progFill.Parent = progBg
    Instance.new("UICorner", progFill).CornerRadius = UDim.new(0, 4)
    self._progressFill = progFill

    local progCount = Instance.new("TextLabel")
    progCount.Size = UDim2.new(1, 0, 1, 0)
    progCount.BackgroundTransparency = 1
    progCount.Text = "0/0"
    progCount.TextColor3 = Color3.new(1, 1, 1)
    progCount.TextSize = 10
    progCount.Font = Enum.Font.GothamBold
    progCount.Parent = progBg
    self._progressCount = progCount
end

-- ══════════════════════════════════════════
-- Sidebar (rarity tabs)
-- ══════════════════════════════════════════

function CodexController:_BuildSidebar(sidebar)
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 4)
    layout.Parent = sidebar

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 12)
    pad.PaddingLeft = UDim.new(0, 6)
    pad.PaddingRight = UDim.new(0, 6)
    pad.Parent = sidebar

    -- Sort rarities by DisplayOrder
    local rarityOrder = {}
    for rarity, info in pairs(BrainrotData.Rarities) do
        table.insert(rarityOrder, { name = rarity, order = info.DisplayOrder, color = info.Color })
    end
    table.sort(rarityOrder, function(a, b) return a.order < b.order end)

    self._tabs = {}
    for i, r in ipairs(rarityOrder) do
        local rarity = r.name
        local displayName = RARITY_DISPLAY[rarity] or rarity
        local color = r.color or Color3.new(1, 1, 1)

        local tab = Instance.new("TextButton")
        tab.Name = "Tab_" .. rarity
        tab.Size = UDim2.new(1, 0, 0, 42)
        tab.LayoutOrder = i
        tab.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        tab.BorderSizePixel = 0
        tab.Text = displayName
        tab.TextColor3 = color
        tab.TextSize = 15
        tab.Font = Enum.Font.GothamBold
        tab.AutoButtonColor = false
        tab.ZIndex = 2
        tab.Parent = sidebar
        Instance.new("UICorner", tab).CornerRadius = UDim.new(0, 8)

        tab.MouseButton1Click:Connect(function()
            if self._activeFilter == rarity then
                self:SetFilter(nil) -- toggle off -> all
            else
                self:SetFilter(rarity)
            end
        end)

        tab.MouseEnter:Connect(function()
            if self._activeFilter ~= rarity then
                tab.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
            end
        end)
        tab.MouseLeave:Connect(function()
            if self._activeFilter ~= rarity then
                tab.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
            end
        end)

        self._tabs[rarity] = tab
    end
end

function CodexController:SetFilter(rarity)
    self._activeFilter = rarity

    for r, tab in pairs(self._tabs) do
        if r == rarity then
            tab.BackgroundColor3 = Color3.fromRGB(65, 65, 80)
        else
            tab.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        end
    end

    if self._subtitleLabel then
        if rarity then
            self._subtitleLabel.Text = RARITY_DISPLAY[rarity] or rarity
        else
            self._subtitleLabel.Text = "All Brainrots"
        end
    end

    self:RefreshList()
end

-- ══════════════════════════════════════════
-- 3D Assembly for ViewportFrame
-- ══════════════════════════════════════════

function CodexController:_AssemblePreviewModel(setName)
    local setData = BrainrotData.Sets[setName]
    if not setData then return nil end

    local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
    if not assetsFolder then return nil end
    local templatesFolder = assetsFolder:FindFirstChild("BodyPartTemplates")
    if not templatesFolder then return nil end

    local headFolder = templatesFolder:FindFirstChild("HeadTemplate")
    local bodyFolder = templatesFolder:FindFirstChild("BodyTemplate")
    local legsFolder = templatesFolder:FindFirstChild("LegsTemplate")

    local headTN = setData.Head and setData.Head.TemplateName or ""
    local bodyTN = setData.Body and setData.Body.TemplateName or ""
    local legsTN = setData.Legs and setData.Legs.TemplateName or ""

    local headSrc = (headTN ~= "" and headFolder) and headFolder:FindFirstChild(headTN) or nil
    local bodySrc = (bodyTN ~= "" and bodyFolder) and bodyFolder:FindFirstChild(bodyTN) or nil
    local legsSrc = (legsTN ~= "" and legsFolder) and legsFolder:FindFirstChild(legsTN) or nil

    if not headSrc and not bodySrc and not legsSrc then return nil end

    local headModel = headSrc and headSrc:Clone() or nil
    local bodyModel = bodySrc and bodySrc:Clone() or nil
    local legsModel = legsSrc and legsSrc:Clone() or nil

    local headPart = headModel and headModel.PrimaryPart
    local bodyPart = bodyModel and bodyModel.PrimaryPart
    local legsPart = legsModel and legsModel.PrimaryPart

    -- Clean BillboardGuis and prepare parts
    local function cleanModel(m)
        if not m then return end
        for _, desc in ipairs(m:GetDescendants()) do
            if desc:IsA("BillboardGui") then
                desc:Destroy()
            elseif desc:IsA("BasePart") then
                desc.Anchored = true
                desc.CanCollide = false
            end
        end
    end

    cleanModel(headModel)
    cleanModel(bodyModel)
    cleanModel(legsModel)

    -- Reposition sub-model via direct CFrame on PrimaryPart
    -- (avoids PivotTo which can be offset by WorldPivot)
    local function repositionModel(subModel, primaryPart, targetCFrame)
        if not subModel or not primaryPart then return end
        local delta = targetCFrame * primaryPart.CFrame:Inverse()
        for _, desc in ipairs(subModel:GetDescendants()) do
            if desc:IsA("BasePart") then
                desc.CFrame = delta * desc.CFrame
            end
        end
    end

    -- Position Legs at origin
    if legsModel and legsPart then
        repositionModel(legsModel, legsPart, CFrame.new(0, legsPart.Size.Y / 2, 0))
    end

    -- Body -> Legs via Attachments
    if bodyModel and bodyPart then
        if legsPart then
            local bba = bodyPart:FindFirstChild("BottomAttachment")
            local lta = legsPart:FindFirstChild("TopAttachment")
            if bba and lta then
                local targetCF = legsPart.CFrame * lta.CFrame * bba.CFrame:Inverse()
                repositionModel(bodyModel, bodyPart, targetCF)
            else
                repositionModel(bodyModel, bodyPart, CFrame.new(0, legsPart.Size.Y + bodyPart.Size.Y / 2, 0))
            end
        else
            repositionModel(bodyModel, bodyPart, CFrame.new(0, bodyPart.Size.Y / 2, 0))
        end
    end

    -- Head -> Body via Attachments
    if headModel and headPart then
        if bodyPart then
            local hba = headPart:FindFirstChild("BottomAttachment")
            local bta = bodyPart:FindFirstChild("TopAttachment")
            if hba and bta then
                local targetCF = bodyPart.CFrame * bta.CFrame * hba.CFrame:Inverse()
                repositionModel(headModel, headPart, targetCF)
            else
                repositionModel(headModel, headPart, bodyPart.CFrame * CFrame.new(0, bodyPart.Size.Y / 2 + headPart.Size.Y / 2, 0))
            end
        elseif legsPart then
            repositionModel(headModel, headPart, CFrame.new(0, legsPart.Size.Y + headPart.Size.Y / 2, 0))
        else
            repositionModel(headModel, headPart, CFrame.new(0, headPart.Size.Y / 2, 0))
        end
    end

    -- Final container
    local model = Instance.new("Model")
    model.Name = "Preview_" .. setName

    if legsModel then legsModel.Parent = model end
    if bodyModel then bodyModel.Parent = model end
    if headModel then headModel.Parent = model end

    model.PrimaryPart = bodyPart or headPart or legsPart
    return model
end

-- ══════════════════════════════════════════
-- Card creation
-- ══════════════════════════════════════════

function CodexController:_CreateCard(setName, setData, isDiscovered, layoutOrder, unlockedParts, totalParts)
    unlockedParts = unlockedParts or 0
    totalParts = totalParts or 3
    local rarity = setData.Rarity or "Common"
    local rarityInfo = BrainrotData.Rarities[rarity] or {}
    local rarityColor = rarityInfo.Color or Color3.new(1, 1, 1)
    local rarityDisplay = RARITY_DISPLAY[rarity] or rarity
    local displayName = SET_DISPLAY_NAMES[setName] or setName

    local card = Instance.new("Frame")
    card.Name = "Card_" .. setName
    card.LayoutOrder = layoutOrder
    card.BackgroundColor3 = isDiscovered and Color3.fromRGB(42, 45, 56) or Color3.fromRGB(28, 30, 38)
    card.BorderSizePixel = 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

    -- Brainrot name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, -10, 0, 20)
    nameLabel.Position = UDim2.new(0, 5, 0, 4)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = isDiscovered and displayName or ""
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.TextSize = 13
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Parent = card

    -- 3D preview area
    local previewFrame = Instance.new("Frame")
    previewFrame.Name = "PreviewFrame"
    previewFrame.Size = UDim2.new(1, -14, 0, 110)
    previewFrame.Position = UDim2.new(0, 7, 0, 26)
    previewFrame.BackgroundColor3 = Color3.fromRGB(32, 34, 44)
    previewFrame.BorderSizePixel = 0
    previewFrame.ClipsDescendants = true
    previewFrame.Parent = card
    Instance.new("UICorner", previewFrame).CornerRadius = UDim.new(0, 6)

    -- ViewportFrame
    local viewport = Instance.new("ViewportFrame")
    viewport.Size = UDim2.new(1, 0, 1, 0)
    viewport.BackgroundTransparency = 1
    viewport.Parent = previewFrame

    local previewModel = self:_AssemblePreviewModel(setName)
    if previewModel then
        -- Black silhouette for undiscovered
        if not isDiscovered then
            for _, desc in ipairs(previewModel:GetDescendants()) do
                if desc:IsA("BasePart") then
                    desc.Color = Color3.fromRGB(12, 12, 20)
                    desc.Material = Enum.Material.SmoothPlastic
                    for _, c in ipairs(desc:GetChildren()) do
                        if c:IsA("Decal") or c:IsA("Texture") or c:IsA("SurfaceGui") then
                            c:Destroy()
                        end
                    end
                end
            end
        end

        previewModel.Parent = viewport

        local camera = Instance.new("Camera")
        viewport.CurrentCamera = camera
        camera.Parent = viewport

        camera.FieldOfView = 50

        local primary = previewModel.PrimaryPart
        if primary then
            local cf, size = previewModel:GetBoundingBox()
            local maxDim = math.max(size.X, size.Y, size.Z)
            local dist = maxDim * 1.2
            camera.CFrame = CFrame.new(
                cf.Position + Vector3.new(dist * 0.3, dist * 0.2, dist),
                cf.Position
            )
        end
    else
        -- Placeholder if no model
        local ph = Instance.new("TextLabel")
        ph.Size = UDim2.new(1, 0, 1, 0)
        ph.BackgroundTransparency = 1
        ph.Text = "?"
        ph.TextColor3 = Color3.fromRGB(55, 55, 65)
        ph.TextSize = 36
        ph.Font = Enum.Font.GothamBold
        ph.Parent = previewFrame
    end

    -- "Default"
    local variantLabel = Instance.new("TextLabel")
    variantLabel.Name = "VariantLabel"
    variantLabel.Size = UDim2.new(0.6, 0, 0, 16)
    variantLabel.Position = UDim2.new(0, 7, 1, -38)
    variantLabel.BackgroundTransparency = 1
    variantLabel.Text = "Default"
    variantLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
    variantLabel.TextSize = 11
    variantLabel.Font = Enum.Font.Gotham
    variantLabel.TextXAlignment = Enum.TextXAlignment.Left
    variantLabel.Parent = card

    -- Rarity label (colored)
    local rarityLabel = Instance.new("TextLabel")
    rarityLabel.Name = "RarityLabel"
    rarityLabel.Size = UDim2.new(0.6, 0, 0, 16)
    rarityLabel.Position = UDim2.new(0, 7, 1, -22)
    rarityLabel.BackgroundTransparency = 1
    rarityLabel.Text = rarityDisplay
    rarityLabel.TextColor3 = rarityColor
    rarityLabel.TextSize = 12
    rarityLabel.Font = Enum.Font.GothamBold
    rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
    rarityLabel.Parent = card

    -- Parts counter (x/X)
    local partsLabel = Instance.new("TextLabel")
    partsLabel.Name = "PartsLabel"
    partsLabel.Size = UDim2.new(0.4, -7, 0, 16)
    partsLabel.Position = UDim2.new(0.6, 0, 1, -22)
    partsLabel.BackgroundTransparency = 1
    partsLabel.Text = unlockedParts .. "/" .. totalParts
    partsLabel.TextColor3 = (unlockedParts >= totalParts and totalParts > 0) and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(150, 150, 160)
    partsLabel.TextSize = 12
    partsLabel.Font = Enum.Font.GothamBold
    partsLabel.TextXAlignment = Enum.TextXAlignment.Right
    partsLabel.Parent = card

    return card
end

-- ══════════════════════════════════════════
-- Refresh grid
-- ══════════════════════════════════════════

function CodexController:RefreshList()
    local grid = self._gridContainer
    if not grid then return end

    -- Clear old cards
    for _, child in ipairs(grid:GetChildren()) do
        if child:IsA("Frame") and child.Name:match("^Card_") then
            child:Destroy()
        end
    end

    local Sets = BrainrotData.Sets or {}
    local unlocked = self._codexUnlocked or {}
    local Rarities = BrainrotData.Rarities or {}

    -- Sort by rarity then alphabetical name
    local setNames = {}
    for name in pairs(Sets) do table.insert(setNames, name) end
    table.sort(setNames, function(a, b)
        local ra = Sets[a] and Sets[a].Rarity or "Common"
        local rb = Sets[b] and Sets[b].Rarity or "Common"
        local oa = Rarities[ra] and Rarities[ra].DisplayOrder or 99
        local ob = Rarities[rb] and Rarities[rb].DisplayOrder or 99
        if oa ~= ob then return oa < ob end
        return a < b
    end)

    local totalSets = 0
    local discoveredSets = 0
    local filteredTotal = 0
    local filteredDiscovered = 0
    local layoutOrder = 0

    for _, setName in ipairs(setNames) do
        local setData = Sets[setName]
        if not setData then continue end

        local parts = getPartsUnlocked(unlocked, setName)
        local hasAny = parts.Head or parts.Body or parts.Legs
        local rarity = setData.Rarity or "Common"

        totalSets = totalSets + 1
        if hasAny then discoveredSets = discoveredSets + 1 end

        -- Active filter
        if self._activeFilter and rarity ~= self._activeFilter then continue end

        filteredTotal = filteredTotal + 1
        if hasAny then filteredDiscovered = filteredDiscovered + 1 end

        -- Count existing parts (non-empty TemplateName) and unlocked parts
        local totalParts = 0
        local unlockedParts = 0
        for _, partType in ipairs({"Head", "Body", "Legs"}) do
            local partData = setData[partType]
            if partData and partData.TemplateName and partData.TemplateName ~= "" then
                totalParts = totalParts + 1
                if parts[partType] then
                    unlockedParts = unlockedParts + 1
                end
            end
        end

        layoutOrder = layoutOrder + 1
        local card = self:_CreateCard(setName, setData, hasAny, layoutOrder, unlockedParts, totalParts)
        card.Parent = grid
    end

    -- Global counter
    if self._counterLabel then
        self._counterLabel.Text = discoveredSets .. "/" .. totalSets
    end

    -- Progress bar
    if self._progressFill and self._progressCount and self._bottomText then
        local pct = filteredTotal > 0 and (filteredDiscovered / filteredTotal) or 0
        self._progressFill.Size = UDim2.new(math.clamp(pct, 0, 1), 0, 1, 0)
        self._progressCount.Text = filteredDiscovered .. "/" .. filteredTotal

        local filterName = self._activeFilter and (RARITY_DISPLAY[self._activeFilter] or self._activeFilter) or ""
        if filterName ~= "" then
            self._bottomText.Text = string.format(
                "Collect 75%% of %s Brainrots for +0.5x base multiplier",
                filterName
            )
        else
            self._bottomText.Text = "Collect Brainrots to unlock bonuses!"
        end
    end
end

-- ══════════════════════════════════════════
-- Public API (ClientMain compatibility)
-- ══════════════════════════════════════════

function CodexController:UpdateCodex(codexUnlocked)
    self._codexUnlocked = codexUnlocked or {}
    self:RefreshList()
end

function CodexController:Open()
    if self._codexUI then
        self._codexUI.Enabled = true
    end
end

function CodexController:Close()
    if self._codexUI then
        self._codexUI.Enabled = false
    end
end

function CodexController:IsOpen()
    return self._codexUI and self._codexUI.Enabled
end

return CodexController
