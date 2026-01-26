-- Game Configuration
-- Contains all game constants and settings

local GameConfig = {}

-- Player Settings
GameConfig.MAX_PLAYERS = 8
GameConfig.MIN_PLAYERS = 2
GameConfig.INVENTORY_MAX_SIZE = 3

-- Match Settings
GameConfig.MATCH_DURATION = 300 -- seconds (5 minutes)
GameConfig.MATCH_START_COUNTDOWN = 10 -- seconds

-- Cannon Settings
GameConfig.CANNON_COUNT = 6
GameConfig.CANNON_SPAWN_INTERVAL_MIN = 2 -- seconds
GameConfig.CANNON_SPAWN_INTERVAL_MAX = 5 -- seconds
GameConfig.CANNON_LAUNCH_FORCE_MIN = 10
GameConfig.CANNON_LAUNCH_FORCE_MAX = 20
GameConfig.CANNON_LAUNCH_ANGLE_MIN = 30 -- degrees
GameConfig.CANNON_LAUNCH_ANGLE_MAX = 60 -- degrees

-- Central Laser Settings
GameConfig.LASER_START_SPEED = 30 -- degrees per second
GameConfig.LASER_MAX_SPEED = 120 -- degrees per second
GameConfig.LASER_ACCELERATION_RATE = 90 -- degrees per second per minute
GameConfig.LASER_WIDTH = 2 -- studs
GameConfig.LASER_KNOCKBACK_FORCE = 15 -- studs

-- Combat Settings
GameConfig.PUNCH_COOLDOWN = 1 -- seconds
GameConfig.PUNCH_RANGE = 2 -- studs
GameConfig.PUNCH_KNOCKBACK = 5 -- studs
GameConfig.PUNCH_ARC = 60 -- degrees

-- Base Protection Settings
GameConfig.BARRIER_DURATION = 5 -- seconds
GameConfig.BARRIER_RADIUS = 5 -- studs
GameConfig.BARRIER_REPULSION_FORCE = 10 -- studs
GameConfig.PRESSURE_PLATE_RADIUS = 1 -- studs
GameConfig.PEDESTALS_PER_BASE = 3

-- Brainrot Settings
GameConfig.LOCK_TIMER_DURATION = 10 -- seconds
GameConfig.INTERACTION_RANGE = 2 -- studs

-- Collection Settings
GameConfig.COLLECTION_RADIUS = 1.5 -- studs

-- Drop Settings
GameConfig.SCATTER_DISTANCE_MIN = 2 -- studs
GameConfig.SCATTER_DISTANCE_MAX = 5 -- studs

-- Arena Settings
GameConfig.ARENA_RADIUS = 50 -- studs
GameConfig.ARENA_CENTER = Vector3.new(0, 0, 0)

-- Codex Settings
GameConfig.DISCOVERY_CURRENCY_REWARD = 100
GameConfig.MILESTONE_THRESHOLDS = {10, 25, 50, 100}
GameConfig.MILESTONE_BADGES = {
	[10] = "Collector",
	[25] = "Enthusiast",
	[50] = "Expert",
	[100] = "Master"
}

-- Visual Settings
GameConfig.NEON_COLORS = {
	HEAD = Color3.fromRGB(0, 255, 255), -- Cyan
	BODY = Color3.fromRGB(255, 0, 255), -- Pink/Magenta
	LEGS = Color3.fromRGB(255, 255, 0)  -- Yellow
}

GameConfig.BARRIER_COLOR = Color3.fromRGB(255, 0, 0) -- Red
GameConfig.BARRIER_TRANSPARENCY = 0.5

-- Network Settings
GameConfig.MAX_LATENCY = 100 -- milliseconds
GameConfig.STATE_SYNC_INTERVAL = 5 -- seconds
GameConfig.INPUT_RATE_LIMIT = 60 -- messages per second

return GameConfig
