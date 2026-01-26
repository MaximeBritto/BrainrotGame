-- Network Manager Server Script
-- Creates RemoteEvents for client-server communication

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create RemoteEvents folder
local remoteEvents = Instance.new("Folder")
remoteEvents.Name = "RemoteEvents"
remoteEvents.Parent = ReplicatedStorage

-- Player Input Events
local punchEvent = Instance.new("RemoteEvent")
punchEvent.Name = "PunchEvent"
punchEvent.Parent = remoteEvents

local interactEvent = Instance.new("RemoteEvent")
interactEvent.Name = "InteractEvent"
interactEvent.Parent = remoteEvents

local collectEvent = Instance.new("RemoteEvent")
collectEvent.Name = "CollectEvent"
collectEvent.Parent = remoteEvents

local placeBrainrotEvent = Instance.new("RemoteEvent")
placeBrainrotEvent.Name = "PlaceBrainrotEvent"
placeBrainrotEvent.Parent = remoteEvents

local bodyPartCollectedEvent = Instance.new("RemoteEvent")
bodyPartCollectedEvent.Name = "BodyPartCollected"
bodyPartCollectedEvent.Parent = remoteEvents

-- UI Update Events
local updateInventory = Instance.new("RemoteEvent")
updateInventory.Name = "UpdateInventory"
updateInventory.Parent = remoteEvents

local updateTimer = Instance.new("RemoteEvent")
updateTimer.Name = "UpdateTimer"
updateTimer.Parent = remoteEvents

local updateScore = Instance.new("RemoteEvent")
updateScore.Name = "UpdateScore"
updateScore.Parent = remoteEvents

local updatePlayerName = Instance.new("RemoteEvent")
updatePlayerName.Name = "UpdatePlayerName"
updatePlayerName.Parent = remoteEvents

local updateCodex = Instance.new("RemoteEvent")
updateCodex.Name = "UpdateCodex"
updateCodex.Parent = remoteEvents

-- VFX Events
local playVFX = Instance.new("RemoteEvent")
playVFX.Name = "PlayVFX"
playVFX.Parent = remoteEvents

-- Audio Events
local playSound = Instance.new("RemoteEvent")
playSound.Name = "PlaySound"
playSound.Parent = remoteEvents

print("✓ Network Manager initialized - RemoteEvents created")

return remoteEvents
