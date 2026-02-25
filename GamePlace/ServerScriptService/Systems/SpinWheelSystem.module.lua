--[[
    SpinWheelSystem.module.lua
    Spin Wheel (Roue de la Chance) management: Robux purchase, free daily spin, rewards

    Responsibilities:
    - Add Spins to a player (after Robux purchase)
    - Validate and process spin (free or paid)
    - Roll a weighted random reward (6 sectors)
    - Distribute rewards: Cash, Lucky Blocks, Temporary Multiplier

    Purchase flow:
    1. Client fires BuySpinWheel(amount)
    2. SpinWheelSystem:RequestBuy -> PromptProductPurchase
    3. ShopSystem.ProcessReceipt detects Spins > 0
    4. ShopSystem calls SpinWheelSystem:AddSpins

    Spin flow:
    1. Client fires SpinWheel
    2. SpinWheelSystem:TrySpin -> validation + roll + reward
    3. Fires SpinWheelResult (client animation)
    4. Fires SyncSpinWheelData
]]

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Services (injected in Init)
local PlayerService = nil
local DataService = nil
local EconomySystem = nil
local LuckyBlockSystem = nil
local NetworkSetup = nil

-- Config (loaded in Init)
local GameConfig = nil
local ShopProducts = nil

local SpinWheelSystem = {}
SpinWheelSystem._initialized = false

--[[
    Initialize the Spin Wheel system
    @param services: table - {PlayerService, DataService, EconomySystem, LuckyBlockSystem, NetworkSetup}
]]
function SpinWheelSystem:Init(services)
    if self._initialized then
        warn("[SpinWheelSystem] Already initialized!")
        return
    end

    print("[SpinWheelSystem] Initializing...")

    PlayerService = services.PlayerService
    DataService = services.DataService
    EconomySystem = services.EconomySystem
    LuckyBlockSystem = services.LuckyBlockSystem
    NetworkSetup = services.NetworkSetup

    if not PlayerService or not DataService then
        error("[SpinWheelSystem] Missing services (PlayerService, DataService)!")
    end

    -- Load config
    local Config = ReplicatedStorage:WaitForChild("Config")
    GameConfig = require(Config:WaitForChild("GameConfig.module"))

    local Data = ReplicatedStorage:WaitForChild("Data")
    ShopProducts = require(Data:WaitForChild("ShopProducts.module"))

    self._initialized = true
    print("[SpinWheelSystem] Initialized!")
end

-- ═══════════════════════════════════════════════════════
-- PURCHASE
-- ═══════════════════════════════════════════════════════

--[[
    Request Spin Wheel purchase (triggers native Robux purchase window)
    @param player: Player
    @param amount: number - 1 or 3
]]
function SpinWheelSystem:RequestBuy(player, amount)
    if type(amount) ~= "number" or (amount ~= 1 and amount ~= 3) then
        self:_SendNotification(player, "Error", "Invalid amount.")
        return
    end

    local productId = self:_FindProductId(amount)
    if not productId or productId == 0 then
        warn("[SpinWheelSystem] ProductId not configured for amount=" .. amount)
        self:_SendNotification(player, "Error", "Product not available yet.")
        return
    end

    local success, err = pcall(function()
        MarketplaceService:PromptProductPurchase(player, productId)
    end)

    if not success then
        warn("[SpinWheelSystem] PromptProductPurchase error: " .. tostring(err))
        self:_SendNotification(player, "Error", "Purchase error. Try again.")
    else
        print(string.format("[SpinWheelSystem] Purchase window opened for %s (%d Spins)",
            player.Name, amount))
    end
end

--[[
    Add Spins to a player (called by ShopSystem.ProcessReceipt)
    @param player: Player
    @param amount: number
]]
function SpinWheelSystem:AddSpins(player, amount)
    if not player or type(amount) ~= "number" or amount <= 0 then
        return
    end

    local playerData = DataService:GetPlayerData(player)
    if not playerData then
        warn("[SpinWheelSystem] Player data not found for " .. player.Name)
        return
    end

    local currentCount = playerData.SpinWheelSpins or 0
    local newCount = currentCount + amount
    DataService:UpdateValue(player, "SpinWheelSpins", newCount)

    print(string.format("[SpinWheelSystem] +%d Spins for %s (total: %d)",
        amount, player.Name, newCount))

    self:_SyncSpinWheelData(player)
end

-- ═══════════════════════════════════════════════════════
-- SPIN
-- ═══════════════════════════════════════════════════════

--[[
    Try to spin the wheel
    @param player: Player
]]
function SpinWheelSystem:TrySpin(player)
    local playerData = DataService:GetPlayerData(player)
    if not playerData then
        self:_SendNotification(player, "Error", "Data not loaded.")
        return
    end

    -- Determine if free spin or paid spin
    local usedFreeSpin = false
    local lastFreeTime = playerData.LastFreeSpinTime or 0
    local cooldown = GameConfig.SpinWheel.FreeCooldown
    local now = os.time()

    if (now - lastFreeTime) >= cooldown then
        -- Free spin available
        usedFreeSpin = true
    else
        -- Check paid spins
        local spins = playerData.SpinWheelSpins or 0
        if spins <= 0 then
            self:_SendNotification(player, "Error", "No spins available!")
            return
        end
    end

    -- Consume the spin
    if usedFreeSpin then
        DataService:UpdateValue(player, "LastFreeSpinTime", now)
    else
        local currentSpins = playerData.SpinWheelSpins or 0
        DataService:UpdateValue(player, "SpinWheelSpins", currentSpins - 1)
    end

    -- Roll a reward
    local rewardIndex = self:_RollReward()
    if not rewardIndex then
        warn("[SpinWheelSystem] Roll failed for " .. player.Name)
        -- Refund
        if usedFreeSpin then
            DataService:UpdateValue(player, "LastFreeSpinTime", lastFreeTime)
        else
            DataService:UpdateValue(player, "SpinWheelSpins", (playerData.SpinWheelSpins or 0))
        end
        self:_SendNotification(player, "Error", "Spin error. Try again.")
        return
    end

    local rewards = GameConfig.SpinWheel.Rewards
    local reward = rewards[rewardIndex]

    -- Distribute the reward
    self:_DistributeReward(player, reward)

    print(string.format("[SpinWheelSystem] %s spun the wheel -> %s (%s)",
        player.Name, reward.DisplayName, usedFreeSpin and "free" or "paid"))

    -- Fire result to client for animation
    local remotes = NetworkSetup:GetAllRemotes()
    if remotes.SpinWheelResult then
        remotes.SpinWheelResult:FireClient(player, {
            RewardIndex = rewardIndex,
            RewardType = reward.Type,
            RewardValue = reward.Value,
            RewardDisplayName = reward.DisplayName,
        })
    end

    -- Sync data
    self:_SyncSpinWheelData(player)
end

-- ═══════════════════════════════════════════════════════
-- REWARD DISTRIBUTION
-- ═══════════════════════════════════════════════════════

--[[
    Distribute a reward to the player
    @param player: Player
    @param reward: table - {Type, Value, DisplayName}
]]
function SpinWheelSystem:_DistributeReward(player, reward)
    if reward.Type == "Cash" then
        if EconomySystem then
            EconomySystem:AddCash(player, reward.Value)
        end
        self:_SendNotification(player, "Success", "You won $" .. reward.Value .. "!", 4)

    elseif reward.Type == "LuckyBlock" then
        if LuckyBlockSystem then
            LuckyBlockSystem:AddLuckyBlocks(player, reward.Value)
        end
        local msg = reward.Value == 1 and "You won 1 Lucky Block!" or "You won " .. reward.Value .. " Lucky Blocks!"
        self:_SendNotification(player, "Success", msg, 4)

    elseif reward.Type == "Multiplier" then
        -- Set temporary multiplier in runtime data
        local runtimeData = PlayerService:GetRuntimeData(player)
        if runtimeData then
            local duration = GameConfig.SpinWheel.MultiplierDuration
            runtimeData.TemporaryMultiplier = GameConfig.SpinWheel.MultiplierBoost
            runtimeData.TemporaryMultiplierExpiry = os.time() + duration
        end
        self:_SendNotification(player, "Success", "x2 Multiplier activated for 15 minutes!", 5)
    end
end

-- ═══════════════════════════════════════════════════════
-- ROLL (weighted random)
-- ═══════════════════════════════════════════════════════

--[[
    Roll a weighted random reward index
    @return number | nil - 1-based index into GameConfig.SpinWheel.Rewards
]]
function SpinWheelSystem:_RollReward()
    local rewards = GameConfig.SpinWheel.Rewards
    if not rewards or #rewards == 0 then
        warn("[SpinWheelSystem] No rewards configured!")
        return nil
    end

    local totalWeight = 0
    for _, reward in ipairs(rewards) do
        totalWeight = totalWeight + reward.Weight
    end

    local roll = math.random() * totalWeight
    local cumulative = 0

    for i, reward in ipairs(rewards) do
        cumulative = cumulative + reward.Weight
        if roll <= cumulative then
            return i
        end
    end

    -- Fallback
    return #rewards
end

-- ═══════════════════════════════════════════════════════
-- UTILITIES
-- ═══════════════════════════════════════════════════════

--[[
    Find the ProductId for a given Spins amount
    @param amount: number - 1 or 3
    @return number | nil
]]
function SpinWheelSystem:_FindProductId(amount)
    if not ShopProducts or not ShopProducts.Categories then
        return nil
    end

    for _, category in ipairs(ShopProducts.Categories) do
        if category.Id == "SpinWheel" then
            for _, product in ipairs(category.Products) do
                if product.Spins == amount then
                    return product.ProductId
                end
            end
        end
    end

    return nil
end

--[[
    Sync the Spin Wheel data with the client
    @param player: Player
]]
function SpinWheelSystem:_SyncSpinWheelData(player)
    local remotes = NetworkSetup:GetAllRemotes()
    if not remotes or not remotes.SyncSpinWheelData then return end

    local playerData = DataService:GetPlayerData(player)
    local spins = playerData and playerData.SpinWheelSpins or 0
    local lastFreeTime = playerData and playerData.LastFreeSpinTime or 0
    local cooldown = GameConfig.SpinWheel.FreeCooldown
    local now = os.time()
    local freeSpinAvailable = (now - lastFreeTime) >= cooldown
    local timeUntilFree = freeSpinAvailable and 0 or (cooldown - (now - lastFreeTime))

    remotes.SyncSpinWheelData:FireClient(player, {
        Spins = spins,
        FreeSpinAvailable = freeSpinAvailable,
        TimeUntilFreeSpin = timeUntilFree,
        LastFreeSpinTime = lastFreeTime,
    })
end

--[[
    Send a notification to the client
    @param player: Player
    @param notifType: string
    @param message: string
    @param duration: number (optional)
]]
function SpinWheelSystem:_SendNotification(player, notifType, message, duration)
    if not NetworkSetup then return end

    local remotes = NetworkSetup:GetAllRemotes()
    if remotes and remotes.Notification then
        remotes.Notification:FireClient(player, {
            Type = notifType,
            Message = message,
            Duration = duration or 4,
        })
    end
end

return SpinWheelSystem
