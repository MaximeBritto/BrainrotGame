-- Combat System Module
-- Manages player combat (punching)
-- Requirements: 5.1, 5.2, 5.3, 5.4

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.GameConfig)

local CombatSystem = {}
CombatSystem.__index = CombatSystem

function CombatSystem.new()
	local self = setmetatable({}, CombatSystem)
	return self
end

function CombatSystem:CanPunch(player, currentTime)
	return currentTime - player.lastPunchTime >= GameConfig.PUNCH_COOLDOWN
end

function CombatSystem:ExecutePunch(attacker, players, currentTime)
	-- Check cooldown
	if not self:CanPunch(attacker, currentTime) then
		return nil
	end
	
	-- Calculate punch direction from attacker's rotation
	local punchDir = attacker.rotation.LookVector
	
	-- Find targets in punch range
	local closestTarget = nil
	local closestDistance = GameConfig.PUNCH_RANGE
	
	for id, target in pairs(players) do
		if target.id ~= attacker.id then
			-- Check distance
			local distance = (target.position - attacker.position).Magnitude
			
			if distance <= GameConfig.PUNCH_RANGE then
				-- Check if target is in front (within punch arc)
				local toTarget = (target.position - attacker.position).Unit
				local dot = punchDir.X * toTarget.X + punchDir.Z * toTarget.Z
				local angle = math.deg(math.acos(dot))
				
				if angle <= GameConfig.PUNCH_ARC / 2 then
					if distance < closestDistance then
						closestDistance = distance
						closestTarget = target
					end
				end
			end
		end
	end
	
	-- Update punch time
	attacker.lastPunchTime = currentTime
	
	return closestTarget
end

function CombatSystem:DropLastItem(target, punchDirection)
	if #target.inventory == 0 then
		return nil
	end
	
	-- Remove last item
	local droppedPart = table.remove(target.inventory)
	droppedPart.isCollected = false
	
	-- Eject in punch direction
	droppedPart.position = target.position + punchDirection * 2
	droppedPart.velocity = punchDirection * GameConfig.PUNCH_KNOCKBACK
	
	-- Update target's displayed name
	local CollectionSystem = require(script.Parent.CollectionSystem)
	local collectionSystem = CollectionSystem.new()
	collectionSystem:UpdatePlayerName(target)
	
	return droppedPart
end

return CombatSystem
