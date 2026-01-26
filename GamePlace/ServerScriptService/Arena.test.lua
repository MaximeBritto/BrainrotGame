-- Arena Unit Tests
-- Tests for Arena boundary collision detection
-- Requirements: 12.1, 12.2, 12.3

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Arena = require(script.Parent.Arena)
local GameConfig = require(ReplicatedStorage.GameConfig)

local Tests = {}

-- Helper function to compare Vector3 with tolerance
local function vectorsEqual(v1, v2, tolerance)
	tolerance = tolerance or 0.001
	return math.abs(v1.X - v2.X) < tolerance
		and math.abs(v1.Y - v2.Y) < tolerance
		and math.abs(v1.Z - v2.Z) < tolerance
end

-- Test: Create circular arena with default configuration
function Tests.testCreateDefaultArena()
	local arena = Arena.createDefault()
	
	assert(arena ~= nil, "Arena should be created")
	assert(arena.boundaryType == Arena.BoundaryType.CIRCULAR, "Default arena should be circular")
	assert(arena.radius == GameConfig.ARENA_RADIUS, "Arena should use config radius")
	assert(vectorsEqual(arena.center, GameConfig.ARENA_CENTER), "Arena should use config center")
	
	print("✓ testCreateDefaultArena passed")
end

-- Test: Create circular arena with custom dimensions
function Tests.testCreateCircularArena()
	local center = Vector3.new(10, 0, 10)
	local radius = 25
	
	local arena = Arena.new(Arena.BoundaryType.CIRCULAR, center, { radius = radius })
	
	assert(arena.boundaryType == Arena.BoundaryType.CIRCULAR, "Arena should be circular")
	assert(arena.radius == radius, "Arena should have specified radius")
	assert(vectorsEqual(arena.center, center), "Arena should have specified center")
	
	print("✓ testCreateCircularArena passed")
end

-- Test: Create rectangular arena
function Tests.testCreateRectangularArena()
	local center = Vector3.new(0, 0, 0)
	local width = 100
	local length = 80
	
	local arena = Arena.new(Arena.BoundaryType.RECTANGULAR, center, { width = width, length = length })
	
	assert(arena.boundaryType == Arena.BoundaryType.RECTANGULAR, "Arena should be rectangular")
	assert(arena.width == width, "Arena should have specified width")
	assert(arena.length == length, "Arena should have specified length")
	assert(vectorsEqual(arena.center, center), "Arena should have specified center")
	
	print("✓ testCreateRectangularArena passed")
end

-- Test: IsInBounds for circular arena - center point
function Tests.testCircularIsInBounds_Center()
	local arena = Arena.new(Arena.BoundaryType.CIRCULAR, Vector3.new(0, 0, 0), { radius = 50 })
	
	local centerPoint = Vector3.new(0, 0, 0)
	assert(arena:IsInBounds(centerPoint), "Center point should be in bounds")
	
	print("✓ testCircularIsInBounds_Center passed")
end

-- Test: IsInBounds for circular arena - point inside
function Tests.testCircularIsInBounds_Inside()
	local arena = Arena.new(Arena.BoundaryType.CIRCULAR, Vector3.new(0, 0, 0), { radius = 50 })
	
	local insidePoint = Vector3.new(10, 0, 10)
	assert(arena:IsInBounds(insidePoint), "Point inside radius should be in bounds")
	
	print("✓ testCircularIsInBounds_Inside passed")
end

-- Test: IsInBounds for circular arena - point on boundary
function Tests.testCircularIsInBounds_OnBoundary()
	local arena = Arena.new(Arena.BoundaryType.CIRCULAR, Vector3.new(0, 0, 0), { radius = 50 })
	
	local boundaryPoint = Vector3.new(50, 0, 0)
	assert(arena:IsInBounds(boundaryPoint), "Point on boundary should be in bounds")
	
	print("✓ testCircularIsInBounds_OnBoundary passed")
end

-- Test: IsInBounds for circular arena - point outside
function Tests.testCircularIsInBounds_Outside()
	local arena = Arena.new(Arena.BoundaryType.CIRCULAR, Vector3.new(0, 0, 0), { radius = 50 })
	
	local outsidePoint = Vector3.new(60, 0, 0)
	assert(not arena:IsInBounds(outsidePoint), "Point outside radius should not be in bounds")
	
	print("✓ testCircularIsInBounds_Outside passed")
end

-- Test: IsInBounds for circular arena - ignores Y axis
function Tests.testCircularIsInBounds_IgnoresY()
	local arena = Arena.new(Arena.BoundaryType.CIRCULAR, Vector3.new(0, 0, 0), { radius = 50 })
	
	local highPoint = Vector3.new(10, 100, 10)
	assert(arena:IsInBounds(highPoint), "Y coordinate should not affect circular boundary check")
	
	print("✓ testCircularIsInBounds_IgnoresY passed")
end

-- Test: IsInBounds for rectangular arena - center point
function Tests.testRectangularIsInBounds_Center()
	local arena = Arena.new(Arena.BoundaryType.RECTANGULAR, Vector3.new(0, 0, 0), { width = 100, length = 80 })
	
	local centerPoint = Vector3.new(0, 0, 0)
	assert(arena:IsInBounds(centerPoint), "Center point should be in bounds")
	
	print("✓ testRectangularIsInBounds_Center passed")
end

-- Test: IsInBounds for rectangular arena - point inside
function Tests.testRectangularIsInBounds_Inside()
	local arena = Arena.new(Arena.BoundaryType.RECTANGULAR, Vector3.new(0, 0, 0), { width = 100, length = 80 })
	
	local insidePoint = Vector3.new(20, 0, 15)
	assert(arena:IsInBounds(insidePoint), "Point inside bounds should be in bounds")
	
	print("✓ testRectangularIsInBounds_Inside passed")
end

-- Test: IsInBounds for rectangular arena - point on boundary
function Tests.testRectangularIsInBounds_OnBoundary()
	local arena = Arena.new(Arena.BoundaryType.RECTANGULAR, Vector3.new(0, 0, 0), { width = 100, length = 80 })
	
	local boundaryPoint = Vector3.new(50, 0, 0) -- On right edge
	assert(arena:IsInBounds(boundaryPoint), "Point on boundary should be in bounds")
	
	print("✓ testRectangularIsInBounds_OnBoundary passed")
end

-- Test: IsInBounds for rectangular arena - point outside
function Tests.testRectangularIsInBounds_Outside()
	local arena = Arena.new(Arena.BoundaryType.RECTANGULAR, Vector3.new(0, 0, 0), { width = 100, length = 80 })
	
	local outsidePoint = Vector3.new(60, 0, 0)
	assert(not arena:IsInBounds(outsidePoint), "Point outside bounds should not be in bounds")
	
	print("✓ testRectangularIsInBounds_Outside passed")
end

-- Test: GetClosestPointOnBoundary for circular arena - point inside
function Tests.testCircularGetClosestPoint_Inside()
	local arena = Arena.new(Arena.BoundaryType.CIRCULAR, Vector3.new(0, 0, 0), { radius = 50 })
	
	local insidePoint = Vector3.new(25, 5, 0)
	local closestPoint = arena:GetClosestPointOnBoundary(insidePoint)
	
	-- Closest point should be at radius 50 in the same direction
	local expected = Vector3.new(50, 5, 0)
	assert(vectorsEqual(closestPoint, expected, 0.1), "Closest point should be on boundary in same direction")
	
	print("✓ testCircularGetClosestPoint_Inside passed")
end

-- Test: GetClosestPointOnBoundary for circular arena - point outside
function Tests.testCircularGetClosestPoint_Outside()
	local arena = Arena.new(Arena.BoundaryType.CIRCULAR, Vector3.new(0, 0, 0), { radius = 50 })
	
	local outsidePoint = Vector3.new(100, 10, 0)
	local closestPoint = arena:GetClosestPointOnBoundary(outsidePoint)
	
	-- Closest point should be at radius 50 in the same direction
	local expected = Vector3.new(50, 10, 0)
	assert(vectorsEqual(closestPoint, expected, 0.1), "Closest point should be on boundary")
	
	print("✓ testCircularGetClosestPoint_Outside passed")
end

-- Test: GetClosestPointOnBoundary for circular arena - point at center
function Tests.testCircularGetClosestPoint_AtCenter()
	local arena = Arena.new(Arena.BoundaryType.CIRCULAR, Vector3.new(0, 0, 0), { radius = 50 })
	
	local centerPoint = Vector3.new(0, 0, 0)
	local closestPoint = arena:GetClosestPointOnBoundary(centerPoint)
	
	-- Should return some point on the boundary (arbitrary direction)
	local distanceFromCenter = math.sqrt(closestPoint.X * closestPoint.X + closestPoint.Z * closestPoint.Z)
	assert(math.abs(distanceFromCenter - 50) < 0.1, "Closest point should be on boundary")
	
	print("✓ testCircularGetClosestPoint_AtCenter passed")
end

-- Test: GetClosestPointOnBoundary for rectangular arena - point inside
function Tests.testRectangularGetClosestPoint_Inside()
	local arena = Arena.new(Arena.BoundaryType.RECTANGULAR, Vector3.new(0, 0, 0), { width = 100, length = 80 })
	
	local insidePoint = Vector3.new(20, 5, 10)
	local closestPoint = arena:GetClosestPointOnBoundary(insidePoint)
	
	-- Should snap to nearest edge (right edge at X=50)
	assert(closestPoint.Y == 5, "Y coordinate should be preserved")
	assert(closestPoint.X == 50 or closestPoint.Z == 40 or closestPoint.X == -50 or closestPoint.Z == -40,
		"Should snap to one of the edges")
	
	print("✓ testRectangularGetClosestPoint_Inside passed")
end

-- Test: GetClosestPointOnBoundary for rectangular arena - point outside
function Tests.testRectangularGetClosestPoint_Outside()
	local arena = Arena.new(Arena.BoundaryType.RECTANGULAR, Vector3.new(0, 0, 0), { width = 100, length = 80 })
	
	local outsidePoint = Vector3.new(60, 10, 50)
	local closestPoint = arena:GetClosestPointOnBoundary(outsidePoint)
	
	-- Should clamp to boundary
	assert(closestPoint.X <= 50 and closestPoint.X >= -50, "X should be within bounds")
	assert(closestPoint.Z <= 40 and closestPoint.Z >= -40, "Z should be within bounds")
	assert(closestPoint.Y == 10, "Y coordinate should be preserved")
	
	print("✓ testRectangularGetClosestPoint_Outside passed")
end

-- Test: ConstrainToBounds - point inside stays same
function Tests.testConstrainToBounds_Inside()
	local arena = Arena.new(Arena.BoundaryType.CIRCULAR, Vector3.new(0, 0, 0), { radius = 50 })
	
	local insidePoint = Vector3.new(10, 5, 10)
	local constrained = arena:ConstrainToBounds(insidePoint)
	
	assert(vectorsEqual(constrained, insidePoint), "Point inside should remain unchanged")
	
	print("✓ testConstrainToBounds_Inside passed")
end

-- Test: ConstrainToBounds - point outside gets constrained
function Tests.testConstrainToBounds_Outside()
	local arena = Arena.new(Arena.BoundaryType.CIRCULAR, Vector3.new(0, 0, 0), { radius = 50 })
	
	local outsidePoint = Vector3.new(100, 5, 0)
	local constrained = arena:ConstrainToBounds(outsidePoint)
	
	assert(arena:IsInBounds(constrained), "Constrained point should be in bounds")
	assert(not vectorsEqual(constrained, outsidePoint), "Point should be moved")
	
	print("✓ testConstrainToBounds_Outside passed")
end

-- Test: GetDimensions returns correct info for circular arena
function Tests.testGetDimensions_Circular()
	local arena = Arena.new(Arena.BoundaryType.CIRCULAR, Vector3.new(5, 0, 5), { radius = 30 })
	
	local dims = arena:GetDimensions()
	
	assert(dims.type == "CIRCULAR", "Type should be CIRCULAR")
	assert(dims.radius == 30, "Radius should match")
	assert(vectorsEqual(dims.center, Vector3.new(5, 0, 5)), "Center should match")
	
	print("✓ testGetDimensions_Circular passed")
end

-- Test: GetDimensions returns correct info for rectangular arena
function Tests.testGetDimensions_Rectangular()
	local arena = Arena.new(Arena.BoundaryType.RECTANGULAR, Vector3.new(0, 0, 0), { width = 100, length = 80 })
	
	local dims = arena:GetDimensions()
	
	assert(dims.type == "RECTANGULAR", "Type should be RECTANGULAR")
	assert(dims.width == 100, "Width should match")
	assert(dims.length == 80, "Length should match")
	assert(vectorsEqual(dims.center, Vector3.new(0, 0, 0)), "Center should match")
	
	print("✓ testGetDimensions_Rectangular passed")
end

-- Test: Invalid boundary type throws error
function Tests.testInvalidBoundaryType()
	local success, err = pcall(function()
		Arena.new("INVALID_TYPE", Vector3.new(0, 0, 0), { radius = 50 })
	end)
	
	assert(not success, "Should throw error for invalid boundary type")
	assert(string.find(err, "Invalid boundary type"), "Error message should mention invalid boundary type")
	
	print("✓ testInvalidBoundaryType passed")
end

-- Test: Missing dimensions throws error
function Tests.testMissingDimensions()
	local success, err = pcall(function()
		Arena.new(Arena.BoundaryType.CIRCULAR, Vector3.new(0, 0, 0), {})
	end)
	
	assert(not success, "Should throw error for missing dimensions")
	
	print("✓ testMissingDimensions passed")
end

-- Run all tests
function Tests.runAll()
	print("\n=== Running Arena Unit Tests ===\n")
	
	local testFunctions = {
		Tests.testCreateDefaultArena,
		Tests.testCreateCircularArena,
		Tests.testCreateRectangularArena,
		Tests.testCircularIsInBounds_Center,
		Tests.testCircularIsInBounds_Inside,
		Tests.testCircularIsInBounds_OnBoundary,
		Tests.testCircularIsInBounds_Outside,
		Tests.testCircularIsInBounds_IgnoresY,
		Tests.testRectangularIsInBounds_Center,
		Tests.testRectangularIsInBounds_Inside,
		Tests.testRectangularIsInBounds_OnBoundary,
		Tests.testRectangularIsInBounds_Outside,
		Tests.testCircularGetClosestPoint_Inside,
		Tests.testCircularGetClosestPoint_Outside,
		Tests.testCircularGetClosestPoint_AtCenter,
		Tests.testRectangularGetClosestPoint_Inside,
		Tests.testRectangularGetClosestPoint_Outside,
		Tests.testConstrainToBounds_Inside,
		Tests.testConstrainToBounds_Outside,
		Tests.testGetDimensions_Circular,
		Tests.testGetDimensions_Rectangular,
		Tests.testInvalidBoundaryType,
		Tests.testMissingDimensions,
	}
	
	local passed = 0
	local failed = 0
	
	for _, testFunc in ipairs(testFunctions) do
		local success, err = pcall(testFunc)
		if success then
			passed = passed + 1
		else
			failed = failed + 1
			print("✗ Test failed: " .. tostring(err))
		end
	end
	
	print("\n=== Test Results ===")
	print(string.format("Passed: %d", passed))
	print(string.format("Failed: %d", failed))
	print(string.format("Total: %d", passed + failed))
	
	if failed == 0 then
		print("\n✓ All tests passed!")
	else
		print("\n✗ Some tests failed")
	end
	
	return failed == 0
end

return Tests
