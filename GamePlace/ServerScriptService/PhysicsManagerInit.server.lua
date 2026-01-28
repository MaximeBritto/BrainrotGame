-- Physics Manager Initialization Script
-- Initializes the PhysicsManager and sets up RemoteEvent for client collection requests

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsManager = require(script.Parent.PhysicsManager)
local GameEvents = require(script.Parent.GameEvents)

-- Create PhysicsManager instance
local physicsManager = PhysicsManager.new()

-- Setup collection handler for GameEvents
GameEvents:SetCollectionHandler(function(userId)
	return physicsManager:CollectNearbyPart(userId)
end)

-- Listen for body part registration events
GameEvents.BodyPartRegistered.Event:Connect(function(bodyPartModel, bodyPartId)
	physicsManager:RegisterBodyPart(bodyPartModel, bodyPartId)
end)

-- Listen for collection callback setup
GameEvents:SetCollectionCallback(function(callback)
	physicsManager:SetCollectionCallback(callback)
end)

-- Setup RemoteEvent for client collection requests (E key press)
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local collectNearbyEvent = Instance.new("RemoteEvent")
collectNearbyEvent.Name = "CollectNearbyEvent"
collectNearbyEvent.Parent = remoteEvents

collectNearbyEvent.OnServerEvent:Connect(function(player)
	physicsManager:CollectNearbyPart(player.UserId)
end)

print("✓ Physics Manager initialized (E to collect)")
