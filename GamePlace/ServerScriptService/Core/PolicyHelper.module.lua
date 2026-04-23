--[[
    PolicyHelper.module.lua
    Wrapper around PolicyService:GetPolicyInfoForPlayerAsync with per-player cache.

    Used to respect the `ArePaidRandomItemsRestricted` policy, required for
    publishing an experience that sells paid random items (Lucky Blocks, Spin
    Wheel) to regulated regions (Belgium, Netherlands, South Korea, etc).

    Reference: https://create.roblox.com/docs/reference/engine/classes/PolicyService#GetPolicyInfoForPlayerAsync

    Safety:
    - On API failure we assume the player IS restricted (fail-closed) — never
      sell a random item when policy is unknown.
    - Cache is populated once per session per player and cleared on leave.
]]

local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")

local PolicyHelper = {}
PolicyHelper._initialized = false
PolicyHelper._cache = {} -- [userId] = { PaidRandomItemsRestricted = bool, Raw = table, FetchedAt = number }

--[[
    Initialize the helper. Sets up PlayerRemoving cleanup.
]]
function PolicyHelper:Init()
    if self._initialized then
        warn("[PolicyHelper] Already initialized!")
        return
    end

    Players.PlayerRemoving:Connect(function(player)
        PolicyHelper._cache[player.UserId] = nil
    end)

    self._initialized = true
    print("[PolicyHelper] Initialized!")
end

--[[
    Fetch (or return from cache) the policy info for a player.
    @param player: Player
    @return table | nil - raw PolicyInfo table as returned by Roblox, or nil on failure
]]
function PolicyHelper:_Fetch(player)
    if not player or not player.Parent then return nil end

    local cached = self._cache[player.UserId]
    if cached then return cached.Raw end

    local ok, info = pcall(function()
        return PolicyService:GetPolicyInfoForPlayerAsync(player)
    end)

    if not ok or type(info) ~= "table" then
        warn(string.format("[PolicyHelper] GetPolicyInfoForPlayerAsync failed for %s: %s",
            player.Name, tostring(info)))
        return nil
    end

    self._cache[player.UserId] = {
        Raw = info,
        PaidRandomItemsRestricted = info.ArePaidRandomItemsRestricted == true,
        FetchedAt = os.time(),
    }

    return info
end

--[[
    Check if paid random items are restricted for this player.
    Returns true (restricted) when policy is unknown — fail-closed for safety.
    @param player: Player
    @return boolean - true if the player CANNOT purchase paid random items
]]
function PolicyHelper:IsPaidRandomItemsRestricted(player)
    if not player then return true end

    local info = self:_Fetch(player)
    if not info then
        return true
    end

    return info.ArePaidRandomItemsRestricted == true
end

return PolicyHelper
