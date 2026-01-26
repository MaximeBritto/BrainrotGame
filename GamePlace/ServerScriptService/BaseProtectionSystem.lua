-- Base Protection System Module
-- Manages player base barriers and pressure plates
-- Requirements: 6.1, 6.2, 6.3, 6.4, 6.6

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.GameConfig)

local BaseProtectionSystem = {}
BaseProtectionSystem.__index = BaseProtectionSystem

function BaseProtectionSystem.new()
	local self = setmetatable({}, BaseProtectionSystem)
	return self
end

function BaseProtectionSystem:CheckPressurePlate(player)
	-- Check if player is on their own pressure plate
	local distanceToBase = (player.position - player.baseLocation).Magnitude
	return distanceToBase <= GameConfig.PRESSURE_PLATE_RADIUS
end

function BaseProtectionSystem:ActivateBarrier(player, currentTime)
	player.isBarrierActive = true
	player.barrierEndTime = currentTime + GameConfig.BARRIER_DURATION
end

function BaseProtectionSystem:UpdateBarriers(players, currentTime)
	for id, player in pairs(players) do
		-- Check if barrier should deactivate
		if player.isBarrierActive and currentTime >= player.barrierEndTime then
			player.isBarrierActive = false
		end
		
		-- Check if player is on their pressure plate
		if self:CheckPressurePlate(player) and not player.isBarrierActive then
			self:ActivateBarrier(player, currentTime)
		end
	end
end

function BaseProtectionSystem:CheckBarrierCollision(player, bases)
	for id, baseOwner in pairs(bases) do
		if baseOwner.id ~= player.id and baseOwner.isBarrierActive then
			-- Check if player is inside this base
			local distanceToBase = (player.position - baseOwner.baseLocation).Magnitude
			
			if distanceToBase < GameConfig.BARRIER_RADIUS then
				-- Apply repulsion
				local repulsionDir = (player.position - baseOwner.baseLocation).Unit
				player.position = player.position + repulsionDir * GameConfig.BARRIER_REPULSION_FORCE * 0.016 -- Per frame
				return true
			end
		end
	end
	
	return false
end

return BaseProtectionSystem
