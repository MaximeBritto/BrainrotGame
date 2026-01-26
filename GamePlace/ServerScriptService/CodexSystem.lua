-- Codex System Module
-- Tracks discovered Brainrot combinations and awards progression
-- Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.GameConfig)
local DataStructures = require(ReplicatedStorage.DataStructures)

local CodexSystem = {}
CodexSystem.__index = CodexSystem

function CodexSystem.new()
	local self = setmetatable({}, CodexSystem)
	
	self.playerProfiles = {} -- Map of playerId -> PlayerProfile
	
	return self
end

function CodexSystem:GetOrCreateProfile(playerId, username)
	if not self.playerProfiles[playerId] then
		self.playerProfiles[playerId] = DataStructures.CreatePlayerProfile(playerId, username)
	end
	return self.playerProfiles[playerId]
end

function CodexSystem:RecordDiscovery(playerId, brainrotName)
	local profile = self.playerProfiles[playerId]
	if not profile then
		return false
	end
	
	-- Check if already discovered
	for _, name in ipairs(profile.discoveredBrainrots) do
		if name == brainrotName then
			return false -- Already discovered
		end
	end
	
	-- Add to discovered list
	table.insert(profile.discoveredBrainrots, brainrotName)
	
	-- Award currency
	profile.currency = profile.currency + GameConfig.DISCOVERY_CURRENCY_REWARD
	
	-- Check for milestone badges
	local discoveryCount = #profile.discoveredBrainrots
	for _, threshold in ipairs(GameConfig.MILESTONE_THRESHOLDS) do
		if discoveryCount == threshold then
			local badgeName = GameConfig.MILESTONE_BADGES[threshold]
			if badgeName then
				table.insert(profile.badges, badgeName)
			end
		end
	end
	
	return true
end

function CodexSystem:AwardCurrency(playerId, amount)
	local profile = self.playerProfiles[playerId]
	if profile then
		profile.currency = profile.currency + amount
	end
end

function CodexSystem:CheckMilestones(playerId)
	local profile = self.playerProfiles[playerId]
	if not profile then
		return {}
	end
	
	return profile.badges
end

function CodexSystem:SaveProgress(playerId)
	-- In a real implementation, this would save to DataStore or file
	-- For now, just return the profile data
	return self.playerProfiles[playerId]
end

function CodexSystem:LoadProgress(playerId, profileData)
	if profileData then
		self.playerProfiles[playerId] = profileData
	end
end

return CodexSystem
