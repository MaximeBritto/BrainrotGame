-- Arena Module
-- Manages arena boundaries and collision detection
-- Requirements: 12.1, 12.2, 12.3

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.GameConfig)

local Arena = {}
Arena.__index = Arena

-- Arena boundary types
Arena.BoundaryType = {
	CIRCULAR = "CIRCULAR",
	RECTANGULAR = "RECTANGULAR"
}

--[[
	Creates a new Arena instance
	
	@param boundaryType string - Either "CIRCULAR" or "RECTANGULAR"
	@param center Vector3 - The center point of the arena
	@param dimensions table - For CIRCULAR: {radius = number}, For RECTANGULAR: {width = number, length = number}
	@return Arena - New Arena instance
]]
function Arena.new(boundaryType, center, dimensions)
	local self = setmetatable({}, Arena)
	
	-- Validate boundary type
	assert(
		boundaryType == Arena.BoundaryType.CIRCULAR or boundaryType == Arena.BoundaryType.RECTANGULAR,
		"Invalid boundary type. Must be CIRCULAR or RECTANGULAR"
	)
	
	self.boundaryType = boundaryType
	self.center = center or GameConfig.ARENA_CENTER
	
	-- Set dimensions based on boundary type
	if boundaryType == Arena.BoundaryType.CIRCULAR then
		assert(dimensions and dimensions.radius, "Circular arena requires radius dimension")
		self.radius = dimensions.radius
	elseif boundaryType == Arena.BoundaryType.RECTANGULAR then
		assert(dimensions and dimensions.width and dimensions.length, "Rectangular arena requires width and length dimensions")
		self.width = dimensions.width
		self.length = dimensions.length
	end
	
	return self
end

--[[
	Creates a circular arena with default configuration
	
	@return Arena - New circular Arena instance
]]
function Arena.createDefault()
	return Arena.new(
		Arena.BoundaryType.CIRCULAR,
		GameConfig.ARENA_CENTER,
		{ radius = GameConfig.ARENA_RADIUS }
	)
end

--[[
	Checks if a position is within the arena boundaries
	
	@param position Vector3 - The position to check
	@return boolean - True if position is within bounds, false otherwise
]]
function Arena:IsInBounds(position)
	if self.boundaryType == Arena.BoundaryType.CIRCULAR then
		-- Calculate distance from center (ignoring Y axis for 2D circular boundary)
		local dx = position.X - self.center.X
		local dz = position.Z - self.center.Z
		local distanceFromCenter = math.sqrt(dx * dx + dz * dz)
		
		return distanceFromCenter <= self.radius
		
	elseif self.boundaryType == Arena.BoundaryType.RECTANGULAR then
		-- Check if position is within rectangular bounds
		local halfWidth = self.width / 2
		local halfLength = self.length / 2
		
		local withinX = math.abs(position.X - self.center.X) <= halfWidth
		local withinZ = math.abs(position.Z - self.center.Z) <= halfLength
		
		return withinX and withinZ
	end
	
	return false
end

--[[
	Gets the closest point on the boundary to a given position
	Useful for collision response and keeping objects within bounds
	
	@param position Vector3 - The position to find the closest boundary point for
	@return Vector3 - The closest point on the boundary
]]
function Arena:GetClosestPointOnBoundary(position)
	if self.boundaryType == Arena.BoundaryType.CIRCULAR then
		-- Calculate direction from center to position (2D, ignoring Y)
		local dx = position.X - self.center.X
		local dz = position.Z - self.center.Z
		local distanceFromCenter = math.sqrt(dx * dx + dz * dz)
		
		-- If position is at center, return arbitrary point on boundary
		if distanceFromCenter < 0.001 then
			return Vector3.new(self.center.X + self.radius, position.Y, self.center.Z)
		end
		
		-- Normalize direction and scale to radius
		local normalizedX = dx / distanceFromCenter
		local normalizedZ = dz / distanceFromCenter
		
		return Vector3.new(
			self.center.X + normalizedX * self.radius,
			position.Y, -- Preserve Y coordinate
			self.center.Z + normalizedZ * self.radius
		)
		
	elseif self.boundaryType == Arena.BoundaryType.RECTANGULAR then
		-- Clamp position to rectangular bounds
		local halfWidth = self.width / 2
		local halfLength = self.length / 2
		
		local clampedX = math.clamp(
			position.X,
			self.center.X - halfWidth,
			self.center.X + halfWidth
		)
		
		local clampedZ = math.clamp(
			position.Z,
			self.center.Z - halfLength,
			self.center.Z + halfLength
		)
		
		-- If position is inside bounds, find closest edge
		local dx = position.X - self.center.X
		local dz = position.Z - self.center.Z
		
		-- Calculate distances to each edge
		local distToLeft = math.abs(dx + halfWidth)
		local distToRight = math.abs(dx - halfWidth)
		local distToFront = math.abs(dz + halfLength)
		local distToBack = math.abs(dz - halfLength)
		
		-- Find minimum distance to determine which edge is closest
		local minDist = math.min(distToLeft, distToRight, distToFront, distToBack)
		
		if minDist == distToLeft then
			clampedX = self.center.X - halfWidth
		elseif minDist == distToRight then
			clampedX = self.center.X + halfWidth
		elseif minDist == distToFront then
			clampedZ = self.center.Z - halfLength
		else -- distToBack
			clampedZ = self.center.Z + halfLength
		end
		
		return Vector3.new(clampedX, position.Y, clampedZ)
	end
	
	return position
end

--[[
	Constrains a position to be within arena bounds
	If position is outside, returns the closest point on boundary
	
	@param position Vector3 - The position to constrain
	@return Vector3 - The constrained position
]]
function Arena:ConstrainToBounds(position)
	if self:IsInBounds(position) then
		return position
	else
		return self:GetClosestPointOnBoundary(position)
	end
end

--[[
	Gets the arena dimensions for external use
	
	@return table - Dimensions based on boundary type
]]
function Arena:GetDimensions()
	if self.boundaryType == Arena.BoundaryType.CIRCULAR then
		return {
			type = "CIRCULAR",
			center = self.center,
			radius = self.radius
		}
	elseif self.boundaryType == Arena.BoundaryType.RECTANGULAR then
		return {
			type = "RECTANGULAR",
			center = self.center,
			width = self.width,
			length = self.length
		}
	end
	
	-- Should never reach here due to validation in constructor
	return nil
end

return Arena
