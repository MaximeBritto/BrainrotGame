--[[
    CodexController.module.lua
    Phase 6 - Gère l'affichage du Codex (sets débloqués / verrouillés)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local BrainrotData = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("BrainrotData.module"))

local CodexController = {}
CodexController._codexUnlocked = {}
CodexController._codexUI = nil
CodexController._initialized = false

function CodexController:Init()
    if self._initialized then return end

    local gui = player:WaitForChild("PlayerGui")
    self._codexUI = gui:WaitForChild("CodexUI")
    local Remotes = ReplicatedStorage:WaitForChild("Remotes")
    local syncCodex = Remotes:WaitForChild("SyncCodex")
    syncCodex.OnClientEvent:Connect(function(codexUnlocked)
        self:UpdateCodex(codexUnlocked or {})
    end)

    -- Bouton Fermer
    local closeBtn = self._codexUI:FindFirstChild("Background") and self._codexUI.Background:FindFirstChild("CloseButton")
    if closeBtn then
        closeBtn.MouseButton1Click:Connect(function()
            self:Close()
        end)
    end

    self._initialized = true
    -- print("[CodexController] Initialized")
end

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

-- Récupère les parties débloquées pour un set (compatibilité ancien format)
local function getPartsUnlocked(unlocked, setName)
    local setData = unlocked[setName]
    if setData == true then
        return {Head = true, Body = true, Legs = true}
    end
    if type(setData) == "table" then
        return {
            Head = setData.Head == true,
            Body = setData.Body == true,
            Legs = setData.Legs == true,
        }
    end
    return {Head = false, Body = false, Legs = false}
end

function CodexController:RefreshList()
    local container = self._codexUI and self._codexUI:FindFirstChild("Background")
    if not container then return end
    local listContainer = container:FindFirstChild("ListContainer") or container:FindFirstChild("ScrollFrame")
    if not listContainer then return end

    for _, child in ipairs(listContainer:GetChildren()) do
        if child:IsA("Frame") and child.Name == "SetEntry" then
            child:Destroy()
        end
    end

    local Sets = BrainrotData.Sets or {}
    local Rarities = BrainrotData.Rarities or {}
    local unlocked = self._codexUnlocked or {}
    local entryHeight = 56
    local layoutOrder = 0
    local slotSize = 28

    local setNames = {}
    for setName in pairs(Sets) do
        table.insert(setNames, setName)
    end
    table.sort(setNames, function(a, b)
        local rarityA = (Sets[a] and Sets[a].Rarity) or "Common"
        local rarityB = (Sets[b] and Sets[b].Rarity) or "Common"
        local orderA = (Rarities[rarityA] and Rarities[rarityA].DisplayOrder) or 99
        local orderB = (Rarities[rarityB] and Rarities[rarityB].DisplayOrder) or 99
        if orderA ~= orderB then return orderA < orderB end
        return a < b
    end)

    for _, setName in ipairs(setNames) do
        local setData = Sets[setName]
        if not setData then continue end

        layoutOrder = layoutOrder + 1
        local parts = getPartsUnlocked(unlocked, setName)
        local countUnlocked = (parts.Head and 1 or 0) + (parts.Body and 1 or 0) + (parts.Legs and 1 or 0)
        local hasAny = countUnlocked > 0
        local rarity = setData.Rarity or "Common"
        local rarityInfo = Rarities[rarity] or {}
        local color = rarityInfo.Color or Color3.new(1, 1, 1)

        local entry = Instance.new("Frame")
        entry.Name = "SetEntry"
        entry.Size = UDim2.new(1, 0, 0, entryHeight)
        entry.LayoutOrder = layoutOrder
        entry.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        entry.BorderSizePixel = 0
        entry.Parent = listContainer

        -- Nom du set
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(0.28, -8, 1, -4)
        nameLabel.Position = UDim2.new(0, 6, 0, 2)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = hasAny and setName or "???"
        nameLabel.TextColor3 = hasAny and color or Color3.new(0.6, 0.6, 0.6)
        nameLabel.TextSize = 13
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.Parent = entry

        -- 3 slots : Head, Body, Legs
        local partTypes = {"Head", "Body", "Legs"}
        for i, partType in ipairs(partTypes) do
            local isPartUnlocked = parts[partType]
            local slot = Instance.new("Frame")
            slot.Name = "Slot_" .. partType
            slot.Size = UDim2.new(0, slotSize, 0, slotSize)
            slot.Position = UDim2.new(0.28, 6 + (i - 1) * (slotSize + 4), 0.5, -slotSize / 2)
            slot.BackgroundColor3 = isPartUnlocked and color or Color3.fromRGB(35, 35, 40)
            slot.BorderSizePixel = 0
            slot.Parent = entry

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 4)
            corner.Parent = slot

            local icon = Instance.new("TextLabel")
            icon.Size = UDim2.new(1, 0, 1, 0)
            icon.BackgroundTransparency = 1
            icon.Text = isPartUnlocked and "✓" or "?"
            -- Texte contrasté : fond clair (Common) = texte sombre, sinon blanc
            local checkColor = isPartUnlocked and (color.R > 0.8 and color.G > 0.8 and color.B > 0.8 and Color3.new(0.15, 0.15, 0.15) or Color3.new(1, 1, 1)) or Color3.new(0.5, 0.5, 0.5)
            icon.TextColor3 = checkColor
            icon.TextSize = 16
            icon.Font = Enum.Font.GothamBold
            icon.Parent = slot

            -- Image optionnelle : si BrainrotData a ImageId pour cette partie
            local partInfo = setData[partType]
            if partInfo and partInfo.ImageId and partInfo.ImageId ~= "" then
                icon.Visible = false
                local img = Instance.new("ImageLabel")
                img.Size = UDim2.new(0.8, 0, 0.8, 0)
                img.Position = UDim2.new(0.1, 0, 0.1, 0)
                img.BackgroundTransparency = 1
                img.Image = partInfo.ImageId
                img.ImageTransparency = isPartUnlocked and 0 or 0.7
                img.Parent = slot
            end
        end

        -- Compteur X/3
        local countLabel = Instance.new("TextLabel")
        countLabel.Size = UDim2.new(0.15, -6, 1, -4)
        countLabel.Position = UDim2.new(0.85, 0, 0, 2)
        countLabel.BackgroundTransparency = 1
        countLabel.Text = countUnlocked .. "/3"
        countLabel.TextColor3 = Color3.new(0.9, 0.9, 0.9)
        countLabel.TextSize = 12
        countLabel.TextXAlignment = Enum.TextXAlignment.Right
        countLabel.Parent = entry

        if countUnlocked == 0 then
            local overlay = Instance.new("Frame")
            overlay.Name = "LockedOverlay"
            overlay.Size = UDim2.new(1, 0, 1, 0)
            overlay.Position = UDim2.new(0, 0, 0, 0)
            overlay.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
            overlay.BackgroundTransparency = 0.5
            overlay.BorderSizePixel = 0
            overlay.ZIndex = 0
            overlay.Parent = entry
        end
    end

    -- Sous-titre : total parties débloquées
    local subtitle = container:FindFirstChild("Subtitle")
    if subtitle then
        local totalParts = 0
        local unlockedParts = 0
        for _, setName in ipairs(setNames) do
            local setData = Sets[setName]
            if setData then
                totalParts = totalParts + 3
                local parts = getPartsUnlocked(unlocked, setName)
                if parts.Head then unlockedParts = unlockedParts + 1 end
                if parts.Body then unlockedParts = unlockedParts + 1 end
                if parts.Legs then unlockedParts = unlockedParts + 1 end
            end
        end
        subtitle.Text = string.format("%d / %d parts unlocked", unlockedParts, totalParts)
    end

    if listContainer:IsA("ScrollingFrame") then
        local layout = listContainer:FindFirstChildOfClass("UIGridLayout")
        if layout then
            listContainer.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
        end
    end
end

return CodexController
