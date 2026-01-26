-- Theft System Module
-- Manages Brainrot theft from other players' bases
-- Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.GameConfig)

local TheftSystem = {}
TheftSystem.__index = TheftSystem

function TheftSystem.new()
	local self = setmetatable({}, TheftSystem)
	return self
end

function TheftSystem:CheckInteraction(thief, bases, brainrots)
	-- Check if thief is in another player's base
	for id, baseOwner in pairs(bases) do
		if baseOwner.id ~= thief.id then
			local distanceToBase = (thief.position - baseOwner.baseLocation).Magnitude
			
			if distanceToBase <= GameConfig.INTERACTION_RANGE then
				-- Find stealable Brainrots in this base
				for brainrotId, brainrot in pairs(brainrots) do
					if brainrot.ownerId == baseOwner.id and not brainrot.isLocked then
						return brainrot
					end
				end
			end
		end
	end
	
	return nil
end

function TheftSystem:CanSteal(brainrot, currentTime)
	return not brainrot.isLocked or currentTime >= brainrot.lockEndTime
end

function TheftSystem:StealBrainrot(brainrot, thief, brainrots, currentTime)
	-- Find available pedestal in thief's base
	local AssemblySystem = require(script.Parent.AssemblySystem)
	local assemblySystem = AssemblySystem.new()
	
	local pedestalIndex = assemblySystem:FindAvailablePedestal(thief, brainrots)
	
	if pedestalIndex < 0 then
		return false -- No available pedestals
	end
	
	-- Transfer ownership
	brainrot.ownerId = thief.id
	brainrot.pedestalIndex = pedestalIndex
	
	-- Reactivate lock timer
	brainrot.isLocked = true
	brainrot.lockEndTime = currentTime + GameConfig.LOCK_TIMER_DURATION
	
	-- Increment thief's score
	thief.score = thief.score + 1
	
	return true
end

return TheftSystem
