-- Core Data Structures
-- Defines the main data types used throughout the game

local DataStructures = {}

-- Enums
DataStructures.BodyPartType = {
	HEAD = "HEAD",
	BODY = "BODY",
	LEGS = "LEGS"
}

DataStructures.HitType = {
	LASER = "LASER",
	PUNCH = "PUNCH"
}

DataStructures.MessageType = {
	PLAYER_INPUT = "PLAYER_INPUT",
	STATE_UPDATE = "STATE_UPDATE",
	BODY_PART_SPAWNED = "BODY_PART_SPAWNED",
	BODY_PART_COLLECTED = "BODY_PART_COLLECTED",
	BRAINROT_COMPLETED = "BRAINROT_COMPLETED",
	PLAYER_HIT = "PLAYER_HIT",
	BRAINROT_STOLEN = "BRAINROT_STOLEN",
	BARRIER_ACTIVATED = "BARRIER_ACTIVATED",
	PUNCH_EXECUTED = "PUNCH_EXECUTED"
}

-- BodyPart Class
function DataStructures.CreateBodyPart(id, bodyPartType, nameFragment, position, velocity)
	return {
		id = id or game:GetService("HttpService"):GenerateGUID(false),
		type = bodyPartType,
		nameFragment = nameFragment,
		position = position or Vector3.new(0, 0, 0),
		velocity = velocity or Vector3.new(0, 0, 0),
		rotation = CFrame.new(),
		isCollected = false,
		instance = nil -- Will hold the actual Part instance
	}
end

-- Player Data Structure
function DataStructures.CreatePlayer(userId, username, baseLocation)
	return {
		id = userId,
		username = username,
		position = baseLocation or Vector3.new(0, 5, 0),
		rotation = CFrame.new(),
		inventory = {}, -- Array of BodyPart objects (max 3)
		baseLocation = baseLocation or Vector3.new(0, 5, 0),
		score = 0,
		lastPunchTime = 0,
		isBarrierActive = false,
		barrierEndTime = 0,
		character = nil, -- Will hold the Character model
		displayName = username
	}
end

-- Brainrot Class
function DataStructures.CreateBrainrot(headPart, bodyPart, legsPart, ownerId)
	local name = headPart.nameFragment .. " " .. bodyPart.nameFragment .. " " .. legsPart.nameFragment
	
	return {
		id = game:GetService("HttpService"):GenerateGUID(false),
		name = name,
		headPart = headPart,
		bodyPart = bodyPart,
		legsPart = legsPart,
		ownerId = ownerId,
		pedestalIndex = -1,
		lockEndTime = 0,
		isLocked = true,
		instance = nil -- Will hold the visual representation
	}
end

-- Cannon Structure
function DataStructures.CreateCannon(position, direction)
	return {
		position = position,
		direction = direction,
		launchForce = 0, -- Will be randomized on each spawn
		launchAngle = 0, -- Will be randomized on each spawn
		instance = nil -- Will hold the Part instance
	}
end

-- GameState Structure
function DataStructures.CreateGameState()
	return {
		sessionId = game:GetService("HttpService"):GenerateGUID(false),
		players = {}, -- Map of userId -> Player
		bodyParts = {}, -- Map of id -> BodyPart
		brainrots = {}, -- Map of id -> Brainrot
		centralLaser = {
			position = Vector3.new(0, 0, 0),
			currentAngle = 0,
			rotationSpeed = 30,
			instance = nil
		},
		matchStartTime = 0,
		matchDuration = 300,
		isMatchActive = false,
		cannons = {} -- Array of Cannon objects
	}
end

-- Network Message Structure
function DataStructures.CreateNetworkMessage(messageType, senderId, payload)
	return {
		messageType = messageType,
		timestamp = tick(),
		senderId = senderId,
		payload = payload
	}
end

-- Player Profile (for persistence)
function DataStructures.CreatePlayerProfile(userId, username)
	return {
		playerId = userId,
		username = username,
		discoveredBrainrots = {}, -- Array of Brainrot names
		currency = 0,
		badges = {}, -- Array of badge names
		totalMatches = 0,
		totalBrainrotsCompleted = 0,
		totalBrainrotsStolen = 0,
		createdAt = os.time(),
		lastPlayedAt = os.time()
	}
end

return DataStructures
