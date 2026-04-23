--[[
    LuckyBlockSystem.module.lua
    Lucky Blocks management: Robux purchase, opening, random roll

    Responsibilities:
    - Add Lucky Blocks to a player (after Robux purchase)
    - Validate and process Lucky Block opening
    - Roll a random Brainrot (Head/Body/Legs independent, weighted)
    - Place the rolled Brainrot into an available slot

    Purchase flow:
    1. Client fires BuyLuckyBlock(amount)
    2. LuckyBlockSystem:RequestBuy -> PromptProductPurchase
    3. ShopSystem.ProcessReceipt detects LuckyBlocks > 0
    4. ShopSystem calls LuckyBlockSystem:AddLuckyBlocks

    Opening flow:
    1. Client fires OpenLuckyBlock
    2. LuckyBlockSystem:TryOpen -> validation + roll + placement
    3. Fires LuckyBlockReveal (client animation)
    4. Fires SyncPlacedBrainrots, SyncLuckyBlockData, SyncPlayerData
]]

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Services (injected in Init)
local PlayerService = nil
local DataService = nil
local PlacementSystem = nil
local BrainrotModelSystem = nil
local NetworkSetup = nil
local ArenaSystem = nil
local PolicyHelper = nil

-- Data (loaded in Init)
local BrainrotData = nil
local ShopProducts = nil

-- Weight cache per piece type: { Head = {{setName, weight}, ...}, Body = ..., Legs = ... }
local _weightCache = nil

local LuckyBlockSystem = {}
LuckyBlockSystem._initialized = false
LuckyBlockSystem._pendingRolls = {} -- [userId] = {HeadSet, BodySet, LegsSet}

--[[
    Initialize the Lucky Block system
    @param services: table - {PlayerService, DataService, PlacementSystem, BrainrotModelSystem, NetworkSetup}
]]
function LuckyBlockSystem:Init(services)
    if self._initialized then
        warn("[LuckyBlockSystem] Already initialized!")
        return
    end

    print("[LuckyBlockSystem] Initializing...")

    PlayerService = services.PlayerService
    DataService = services.DataService
    PlacementSystem = services.PlacementSystem
    BrainrotModelSystem = services.BrainrotModelSystem
    NetworkSetup = services.NetworkSetup
    ArenaSystem = services.ArenaSystem
    PolicyHelper = services.PolicyHelper

    if not PlayerService or not DataService then
        error("[LuckyBlockSystem] Missing services (PlayerService, DataService)!")
    end

    if not PlacementSystem then
        error("[LuckyBlockSystem] PlacementSystem missing!")
    end

    -- Load BrainrotData
    local Data = ReplicatedStorage:WaitForChild("Data")
    BrainrotData = require(Data:WaitForChild("BrainrotData.module"))

    -- Load ShopProducts (for amount -> ProductId mapping)
    ShopProducts = require(Data:WaitForChild("ShopProducts.module"))

    -- Build the weight cache
    self:_BuildWeightCache()

    self._initialized = true
    print("[LuckyBlockSystem] Initialized!")
end

-- ═══════════════════════════════════════════════════════
-- PURCHASE
-- ═══════════════════════════════════════════════════════

--[[
    Request Lucky Blocks purchase (triggers native Robux purchase window)
    Called by NetworkHandler when client fires BuyLuckyBlock
    @param player: Player
    @param amount: number - 1 or 3
]]
function LuckyBlockSystem:RequestBuy(player, amount)
    -- Validate amount
    if type(amount) ~= "number" or (amount ~= 1 and amount ~= 3) then
        self:_SendNotification(player, "Error", "Invalid amount.")
        return
    end

    -- Respect ArePaidRandomItemsRestricted policy (required for publishing
    -- in regulated regions). Fail-closed if the policy lookup fails.
    if PolicyHelper and PolicyHelper:IsPaidRandomItemsRestricted(player) then
        self:_SendNotification(player, "Error", "Lucky Blocks are not available in your region.")
        return
    end

    -- Find the matching ProductId in ShopProducts
    local productId = self:_FindProductId(amount)
    if not productId or productId == 0 then
        warn("[LuckyBlockSystem] ProductId not configured for amount=" .. amount)
        self:_SendNotification(player, "Error", "Product not available yet.")
        return
    end

    -- Trigger the native Roblox purchase window
    local success, err = pcall(function()
        MarketplaceService:PromptProductPurchase(player, productId)
    end)

    if not success then
        warn("[LuckyBlockSystem] PromptProductPurchase error: " .. tostring(err))
        self:_SendNotification(player, "Error", "Purchase error. Try again.")
    else
        print(string.format("[LuckyBlockSystem] Purchase window opened for %s (%d Lucky Blocks)",
            player.Name, amount))
    end
end

--[[
    Add Lucky Blocks to a player (called by ShopSystem.ProcessReceipt)
    @param player: Player
    @param amount: number
]]
function LuckyBlockSystem:AddLuckyBlocks(player, amount)
    if not player or type(amount) ~= "number" or amount <= 0 then
        return
    end

    local playerData = DataService:GetPlayerData(player)
    if not playerData then
        warn("[LuckyBlockSystem] Player data not found for " .. player.Name)
        return
    end

    local currentCount = playerData.LuckyBlocks or 0
    local newCount = currentCount + amount
    DataService:UpdateValue(player, "LuckyBlocks", newCount)

    print(string.format("[LuckyBlockSystem] +%d Lucky Blocks for %s (total: %d)",
        amount, player.Name, newCount))

    -- Sync counter with client
    self:_SyncLuckyBlockData(player)
end

-- ═══════════════════════════════════════════════════════
-- OPENING
-- ═══════════════════════════════════════════════════════

--[[
    Try to open a Lucky Block
    Called by NetworkHandler when client fires OpenLuckyBlock
    @param player: Player
]]
function LuckyBlockSystem:TryOpen(player)
    -- 1. Check that the player has Lucky Blocks
    local playerData = DataService:GetPlayerData(player)
    if not playerData then
        self:_SendNotification(player, "Error", "Data not loaded.")
        return
    end

    local count = playerData.LuckyBlocks or 0
    if count <= 0 then
        self:_SendNotification(player, "Error", "No Lucky Blocks!")
        return
    end

    -- 2. Check that the player doesn't already have a pending roll
    if self._pendingRolls[player.UserId] then
        self:_SendNotification(player, "Error", "Choose Take or Throw first!")
        return
    end

    -- 3. Check that the player is not stunned or carrying a stolen brainrot
    local runtimeData = PlayerService:GetRuntimeData(player)
    if runtimeData then
        if runtimeData.CarriedBrainrot then
            self:_SendNotification(player, "Error", "Place your stolen Brainrot first!")
            return
        end
    end

    -- 4. Roll a random Brainrot
    local rolled = self:_RollBrainrot()
    if not rolled then
        warn("[LuckyBlockSystem] Roll failed for " .. player.Name)
        self:_SendNotification(player, "Error", "Roll error. Try again.")
        return
    end

    -- 5. Decrement Lucky Blocks counter
    local newCount = count - 1
    DataService:UpdateValue(player, "LuckyBlocks", newCount)

    -- 6. Store pending roll (player must choose Take or Throw)
    self._pendingRolls[player.UserId] = rolled

    print(string.format("[LuckyBlockSystem] %s opened a Lucky Block -> Head=%s, Body=%s, Legs=%s (pending)",
        player.Name, rolled.HeadSet, rolled.BodySet, rolled.LegsSet))

    -- 7. Fire reveal animation to client
    local remotes = NetworkSetup:GetAllRemotes()

    if remotes.LuckyBlockReveal then
        remotes.LuckyBlockReveal:FireClient(player, {
            HeadSet = rolled.HeadSet,
            BodySet = rolled.BodySet,
            LegsSet = rolled.LegsSet,
        })
    end

    -- Sync Lucky Blocks counter
    self:_SyncLuckyBlockData(player)

    if remotes.SyncPlayerData then
        remotes.SyncPlayerData:FireClient(player, {
            Cash = playerData.Cash,
            LuckyBlocks = newCount,
        })
    end
end

--[[
    Take the pending Lucky Block result: add pieces to inventory
    If inventory has pieces, they are replaced and respawned in the arena
    @param player: Player
]]
function LuckyBlockSystem:TakeResult(player)
    local rolled = self._pendingRolls[player.UserId]
    if not rolled then
        self:_SendNotification(player, "Error", "No pending Lucky Block!")
        return
    end

    -- Clear pending roll
    self._pendingRolls[player.UserId] = nil

    -- Clear existing pieces in hand and respawn them in the arena
    local oldPieces = PlayerService:ClearPiecesInHand(player)

    if ArenaSystem and #oldPieces > 0 then
        local character = player.Character
        local dropPos = nil
        if character then
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            if rootPart then
                dropPos = rootPart.Position
            end
        end

        for i, pieceData in ipairs(oldPieces) do
            local offset = Vector3.new((i - 1) * 3 - (#oldPieces - 1) * 1.5, 0, -3)
            local spawnPos = dropPos and (dropPos + offset) or nil
            if spawnPos then
                ArenaSystem:SpawnPieceFromData(pieceData, spawnPos)
            end
        end
    end

    -- Add the 3 new pieces from the lucky block roll
    local partTypes = {"Head", "Body", "Legs"}
    local setKeys = {"HeadSet", "BodySet", "LegsSet"}

    for i, partType in ipairs(partTypes) do
        local setName = rolled[setKeys[i]]
        local setData = BrainrotData.Sets[setName]
        if setData and setData[partType] then
            local partData = setData[partType]
            PlayerService:AddPieceToHand(player, {
                SetName = setName,
                PieceType = partType,
                Price = partData.Price or 0,
                DisplayName = partData.DisplayName or setName,
            })
        end
    end

    print(string.format("[LuckyBlockSystem] %s took Lucky Block pieces: Head=%s, Body=%s, Legs=%s",
        player.Name, rolled.HeadSet, rolled.BodySet, rolled.LegsSet))

    -- Sync inventory with client
    local remotes = NetworkSetup:GetAllRemotes()
    local newPieces = PlayerService:GetPiecesInHand(player)

    if remotes.SyncInventory then
        remotes.SyncInventory:FireClient(player, newPieces)
    end

    self:_SendNotification(player, "Success", "Pieces added to inventory!")
end

--[[
    Throw the pending Lucky Block result: discard the pieces
    @param player: Player
]]
function LuckyBlockSystem:ThrowResult(player)
    local rolled = self._pendingRolls[player.UserId]
    if not rolled then
        self:_SendNotification(player, "Error", "No pending Lucky Block!")
        return
    end

    -- Clear pending roll
    self._pendingRolls[player.UserId] = nil

    print(string.format("[LuckyBlockSystem] %s threw away Lucky Block pieces: Head=%s, Body=%s, Legs=%s",
        player.Name, rolled.HeadSet, rolled.BodySet, rolled.LegsSet))

    self:_SendNotification(player, "Info", "Brainrot discarded.")
end

-- ═══════════════════════════════════════════════════════
-- ROLL (weighted random logic)
-- ═══════════════════════════════════════════════════════

--[[
    Roll a complete Brainrot (Head, Body, Legs independent)
    @return table | nil - {HeadSet, BodySet, LegsSet}
]]
function LuckyBlockSystem:_RollBrainrot()
    local headSet = self:_GetWeightedRandom("Head")
    local bodySet = self:_GetWeightedRandom("Body")
    local legsSet = self:_GetWeightedRandom("Legs")

    if not headSet or not bodySet or not legsSet then
        warn("[LuckyBlockSystem] Incomplete roll: Head=" .. tostring(headSet)
            .. ", Body=" .. tostring(bodySet) .. ", Legs=" .. tostring(legsSet))
        return nil
    end

    return {
        HeadSet = headSet,
        BodySet = bodySet,
        LegsSet = legsSet,
    }
end

--[[
    Weighted random selection of a set for a piece type
    @param partType: string - "Head" | "Body" | "Legs"
    @return string | nil - Set name
]]
function LuckyBlockSystem:_GetWeightedRandom(partType)
    if not _weightCache or not _weightCache[partType] then
        warn("[LuckyBlockSystem] Weight cache missing for " .. partType)
        return nil
    end

    local entries = _weightCache[partType]
    if #entries == 0 then
        warn("[LuckyBlockSystem] No set with SpawnWeight > 0 for " .. partType)
        return nil
    end

    -- Calculate total weight
    local totalWeight = 0
    for _, entry in ipairs(entries) do
        totalWeight = totalWeight + entry.weight
    end

    -- Roll a random number
    local roll = math.random() * totalWeight
    local cumulative = 0

    for _, entry in ipairs(entries) do
        cumulative = cumulative + entry.weight
        if roll <= cumulative then
            return entry.setName
        end
    end

    -- Fallback (should not happen)
    return entries[#entries].setName
end

--[[
    Build the weight cache from BrainrotData.Sets
    Filters sets with SpawnWeight > 0 and non-empty TemplateName
]]
function LuckyBlockSystem:_BuildWeightCache()
    _weightCache = {
        Head = {},
        Body = {},
        Legs = {},
    }

    for setName, setData in pairs(BrainrotData.Sets) do
        for _, partType in ipairs({"Head", "Body", "Legs"}) do
            local partData = setData[partType]
            if partData and partData.SpawnWeight and partData.SpawnWeight > 0
                and partData.TemplateName and partData.TemplateName ~= "" then
                table.insert(_weightCache[partType], {
                    setName = setName,
                    weight = partData.SpawnWeight,
                })
            end
        end
    end

    print(string.format("[LuckyBlockSystem] Weight cache: Head=%d, Body=%d, Legs=%d",
        #_weightCache.Head, #_weightCache.Body, #_weightCache.Legs))
end

-- ═══════════════════════════════════════════════════════
-- UTILITIES
-- ═══════════════════════════════════════════════════════

--[[
    Find the ProductId for a given Lucky Blocks amount
    @param amount: number - 1 or 3
    @return number | nil - ProductId
]]
function LuckyBlockSystem:_FindProductId(amount)
    if not ShopProducts or not ShopProducts.Categories then
        return nil
    end

    for _, category in ipairs(ShopProducts.Categories) do
        for _, product in ipairs(category.Products) do
            if product.LuckyBlocks == amount and not product.Spins and not product.PermanentMultiplierBonus then
                return product.ProductId
            end
        end
    end

    return nil
end

--[[
    Sync the Lucky Blocks counter with the client
    @param player: Player
]]
function LuckyBlockSystem:_SyncLuckyBlockData(player)
    local remotes = NetworkSetup:GetAllRemotes()
    if not remotes or not remotes.SyncLuckyBlockData then return end

    local playerData = DataService:GetPlayerData(player)
    local count = playerData and playerData.LuckyBlocks or 0

    remotes.SyncLuckyBlockData:FireClient(player, {
        Count = count,
    })
end

--[[
    Send a notification to the client
    @param player: Player
    @param notifType: string - "Success" | "Error" | "Info" | "Warning"
    @param message: string
]]
function LuckyBlockSystem:_SendNotification(player, notifType, message)
    if not NetworkSetup then return end

    local remotes = NetworkSetup:GetAllRemotes()
    if remotes and remotes.Notification then
        remotes.Notification:FireClient(player, {
            Type = notifType,
            Message = message,
            Duration = 4,
        })
    end
end

return LuckyBlockSystem
