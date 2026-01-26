-- Arena Property-Based Tests
-- Property tests for boundary collision with randomized inputs
-- Requirements: 12.2, 12.3

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Arena = require(script.Parent.Arena)
local GameConfig = require(ReplicatedStorage.GameConfig)

local PropertyTests = {}

-- Simple random number generator with seed support for reproducibility
local RandomGen = {}
RandomGen.__index = RandomGen

function RandomGen.new(seed)
	local self = setmetatable({}, RandomGen)
	self.seed = seed or os.time()
	self.state = self.seed
	return self
end

function RandomGen:next()
	-- Linear congruential generator
	self.state = (self.state * 1103515245 + 12345) % 2147483648
	return self.state / 2147483648
end

function RandomGen:nextInt(min, max)
	return math.floor(self:next() * (max - min + 1)) + min
end

function RandomGen:nextFloat(min, max)
	return min + self:next() * (max - min)
end

function RandomGen:nextVector3(minX, maxX, minY, maxY, minZ, maxZ)
	return Vector3.new(
		self:nextFloat(minX, maxX),
		self:nextFloat(minY, maxY),
		self:nextFloat(minZ, maxZ)
	)
end

-- Property test runner
local function runPropertyTest(testName, iterations, testFunc)
	print(string.format("\n=== Running Property Test: %s ===", testName))
	print(string.format("Iterations: %d", iterations))
	
	local passed = 0
	local failed = 0
	local failures = {}
	
	for i = 1, iterations do
		local success, err = pcall(testFunc, i)
		if success then
			passed = passed + 1
		else
			failed = failed + 1
			table.insert(failures, {
				iteration = i,
				error = tostring(err)
			})
			-- Only show first 5 failures to avoid spam
			if failed <= 5 then
				print(string.format("  ✗ Iteration %d failed: %s", i, tostring(err)))
			end
		end
	end
	
	print(string.format("\nResults: %d passed, %d failed out of %d iterations", passed, failed, iterations))
	
	if failed > 0 then
		print(string.format("✗ Property test FAILED: %s", testName))
		if failed > 5 then
			print(string.format("  (Showing first 5 of %d failures)", failed))
		end
		return false, failures
	else
		print(string.format("✓ Property test PASSED: %s", testName))
		return true, {}
	end
end

--[[
	Property 42: Boundary collision for players
	**Validates: Requirements 12.2**
	
	For any player at the arena boundary, they should be unable to move beyond the boundary.
	
	Test strategy:
	- Generate random positions both inside and outside the arena
	- For positions outside, verify ConstrainToBounds returns a position within bounds
	- For positions inside, verify ConstrainToBounds returns the same position
	- Verify that constrained positions are always within bounds
]]
function PropertyTests.testProperty42_BoundaryCollisionForPlayers()
	local ITERATIONS = 100
	local rng = RandomGen.new(42) -- Fixed seed for reproducibility
	
	local testFunc = function(iteration)
		-- Test both circular and rectangular arenas
		local arenaTypes = {
			{
				type = Arena.BoundaryType.CIRCULAR,
				center = Vector3.new(0, 0, 0),
				dimensions = { radius = 50 }
			},
			{
				type = Arena.BoundaryType.RECTANGULAR,
				center = Vector3.new(0, 0, 0),
				dimensions = { width = 100, length = 80 }
			}
		}
		
		for _, arenaConfig in ipairs(arenaTypes) do
			local arena = Arena.new(arenaConfig.type, arenaConfig.center, arenaConfig.dimensions)
			
			-- Generate random player position (can be inside or outside)
			local playerPos = rng:nextVector3(-100, 100, 0, 10, -100, 100)
			
			-- Apply boundary constraint (simulating player movement collision)
			local constrainedPos = arena:ConstrainToBounds(playerPos)
			
			-- Property: Constrained position must always be within bounds
			if not arena:IsInBounds(constrainedPos) then
				error(string.format(
					"Property 42 violated: Constrained position is outside bounds. " ..
					"Arena: %s, Original: (%.2f, %.2f, %.2f), Constrained: (%.2f, %.2f, %.2f)",
					arenaConfig.type,
					playerPos.X, playerPos.Y, playerPos.Z,
					constrainedPos.X, constrainedPos.Y, constrainedPos.Z
				))
			end
			
			-- Property: If original position was inside, it should remain unchanged
			if arena:IsInBounds(playerPos) then
				local dx = math.abs(playerPos.X - constrainedPos.X)
				local dy = math.abs(playerPos.Y - constrainedPos.Y)
				local dz = math.abs(playerPos.Z - constrainedPos.Z)
				
				if dx > 0.001 or dy > 0.001 or dz > 0.001 then
					error(string.format(
						"Property 42 violated: Position inside bounds was modified. " ..
						"Arena: %s, Original: (%.2f, %.2f, %.2f), Constrained: (%.2f, %.2f, %.2f)",
						arenaConfig.type,
						playerPos.X, playerPos.Y, playerPos.Z,
						constrainedPos.X, constrainedPos.Y, constrainedPos.Z
					))
				end
			end
			
			-- Property: Player cannot move beyond boundary
			-- Test attempting to move outside from boundary
			if not arena:IsInBounds(playerPos) then
				-- The constrained position should be closer to center than original
				local originalDist, constrainedDist
				
				if arenaConfig.type == Arena.BoundaryType.CIRCULAR then
					local dx1 = playerPos.X - arena.center.X
					local dz1 = playerPos.Z - arena.center.Z
					originalDist = math.sqrt(dx1 * dx1 + dz1 * dz1)
					
					local dx2 = constrainedPos.X - arena.center.X
					local dz2 = constrainedPos.Z - arena.center.Z
					constrainedDist = math.sqrt(dx2 * dx2 + dz2 * dz2)
					
					if constrainedDist > originalDist then
						error(string.format(
							"Property 42 violated: Constrained position is farther from center. " ..
							"Original dist: %.2f, Constrained dist: %.2f",
							originalDist, constrainedDist
						))
					end
				end
			end
		end
	end
	
	return runPropertyTest("Property 42: Boundary collision for players", ITERATIONS, testFunc)
end

--[[
	Property 43: Boundary collision for body parts
	**Validates: Requirements 12.3**
	
	For any body part that reaches the arena boundary, it should remain within the playable area.
	
	Test strategy:
	- Generate random body part positions (simulating physics trajectories)
	- Apply boundary constraint to simulate collision response
	- Verify all body parts remain within bounds after constraint
	- Test with various velocities and positions
]]
function PropertyTests.testProperty43_BoundaryCollisionForBodyParts()
	local ITERATIONS = 100
	local rng = RandomGen.new(43) -- Fixed seed for reproducibility
	
	local testFunc = function(iteration)
		-- Test both circular and rectangular arenas
		local arenaTypes = {
			{
				type = Arena.BoundaryType.CIRCULAR,
				center = Vector3.new(0, 0, 0),
				dimensions = { radius = 50 }
			},
			{
				type = Arena.BoundaryType.RECTANGULAR,
				center = Vector3.new(0, 0, 0),
				dimensions = { width = 100, length = 80 }
			}
		}
		
		for _, arenaConfig in ipairs(arenaTypes) do
			local arena = Arena.new(arenaConfig.type, arenaConfig.center, arenaConfig.dimensions)
			
			-- Simulate body part trajectory (can start inside or outside, with velocity)
			local bodyPartPos = rng:nextVector3(-150, 150, 0, 20, -150, 150)
			local velocity = rng:nextVector3(-10, 10, -5, 5, -10, 10)
			
			-- Simulate physics step (position + velocity)
			local newPos = Vector3.new(
				bodyPartPos.X + velocity.X,
				bodyPartPos.Y + velocity.Y,
				bodyPartPos.Z + velocity.Z
			)
			
			-- Apply boundary constraint (simulating collision response)
			local constrainedPos = arena:ConstrainToBounds(newPos)
			
			-- Property: Body part must remain within playable area
			if not arena:IsInBounds(constrainedPos) then
				error(string.format(
					"Property 43 violated: Body part position is outside bounds after constraint. " ..
					"Arena: %s, Original: (%.2f, %.2f, %.2f), Constrained: (%.2f, %.2f, %.2f)",
					arenaConfig.type,
					newPos.X, newPos.Y, newPos.Z,
					constrainedPos.X, constrainedPos.Y, constrainedPos.Z
				))
			end
			
			-- Property: Constrained position should be on or inside boundary
			local closestBoundary = arena:GetClosestPointOnBoundary(constrainedPos)
			local distToBoundary
			
			if arenaConfig.type == Arena.BoundaryType.CIRCULAR then
				local dx = constrainedPos.X - arena.center.X
				local dz = constrainedPos.Z - arena.center.Z
				local distFromCenter = math.sqrt(dx * dx + dz * dz)
				
				-- Should be at or inside radius
				if distFromCenter > arena.radius + 0.001 then
					error(string.format(
						"Property 43 violated: Body part is beyond circular boundary. " ..
						"Distance from center: %.2f, Radius: %.2f",
						distFromCenter, arena.radius
					))
				end
			elseif arenaConfig.type == Arena.BoundaryType.RECTANGULAR then
				local halfWidth = arena.width / 2
				local halfLength = arena.length / 2
				
				local dx = math.abs(constrainedPos.X - arena.center.X)
				local dz = math.abs(constrainedPos.Z - arena.center.Z)
				
				-- Should be within rectangular bounds
				if dx > halfWidth + 0.001 or dz > halfLength + 0.001 then
					error(string.format(
						"Property 43 violated: Body part is beyond rectangular boundary. " ..
						"dx: %.2f (max: %.2f), dz: %.2f (max: %.2f)",
						dx, halfWidth, dz, halfLength
					))
				end
			end
			
			-- Property: Y coordinate should be preserved (boundary is 2D in XZ plane)
			if math.abs(constrainedPos.Y - newPos.Y) > 0.001 then
				error(string.format(
					"Property 43 violated: Y coordinate was modified by boundary constraint. " ..
					"Original Y: %.2f, Constrained Y: %.2f",
					newPos.Y, constrainedPos.Y
				))
			end
		end
	end
	
	return runPropertyTest("Property 43: Boundary collision for body parts", ITERATIONS, testFunc)
end

--[[
	Additional property: Boundary constraint is idempotent
	
	Applying ConstrainToBounds multiple times should produce the same result.
	This ensures the constraint function is stable and doesn't drift.
]]
function PropertyTests.testProperty_ConstraintIdempotence()
	local ITERATIONS = 100
	local rng = RandomGen.new(100)
	
	local testFunc = function(iteration)
		local arena = Arena.new(Arena.BoundaryType.CIRCULAR, Vector3.new(0, 0, 0), { radius = 50 })
		
		-- Generate random position
		local pos = rng:nextVector3(-100, 100, 0, 10, -100, 100)
		
		-- Apply constraint twice
		local constrained1 = arena:ConstrainToBounds(pos)
		local constrained2 = arena:ConstrainToBounds(constrained1)
		
		-- Should be identical
		local dx = math.abs(constrained1.X - constrained2.X)
		local dy = math.abs(constrained1.Y - constrained2.Y)
		local dz = math.abs(constrained1.Z - constrained2.Z)
		
		if dx > 0.001 or dy > 0.001 or dz > 0.001 then
			error(string.format(
				"Idempotence violated: Applying constraint twice produced different results. " ..
				"First: (%.2f, %.2f, %.2f), Second: (%.2f, %.2f, %.2f)",
				constrained1.X, constrained1.Y, constrained1.Z,
				constrained2.X, constrained2.Y, constrained2.Z
			))
		end
	end
	
	return runPropertyTest("Property: Constraint idempotence", ITERATIONS, testFunc)
end

--[[
	Additional property: IsInBounds consistency with ConstrainToBounds
	
	If IsInBounds returns true, ConstrainToBounds should return the same position.
	If IsInBounds returns false, ConstrainToBounds should return a different position that is in bounds.
]]
function PropertyTests.testProperty_IsInBoundsConsistency()
	local ITERATIONS = 100
	local rng = RandomGen.new(101)
	
	local testFunc = function(iteration)
		local arenaTypes = {
			{
				type = Arena.BoundaryType.CIRCULAR,
				center = Vector3.new(0, 0, 0),
				dimensions = { radius = 50 }
			},
			{
				type = Arena.BoundaryType.RECTANGULAR,
				center = Vector3.new(0, 0, 0),
				dimensions = { width = 100, length = 80 }
			}
		}
		
		for _, arenaConfig in ipairs(arenaTypes) do
			local arena = Arena.new(arenaConfig.type, arenaConfig.center, arenaConfig.dimensions)
			local pos = rng:nextVector3(-100, 100, 0, 10, -100, 100)
			
			local isInBounds = arena:IsInBounds(pos)
			local constrained = arena:ConstrainToBounds(pos)
			
			if isInBounds then
				-- Should return same position
				local dx = math.abs(pos.X - constrained.X)
				local dy = math.abs(pos.Y - constrained.Y)
				local dz = math.abs(pos.Z - constrained.Z)
				
				if dx > 0.001 or dy > 0.001 or dz > 0.001 then
					error(string.format(
						"Consistency violated: IsInBounds=true but position was modified. " ..
						"Arena: %s, Original: (%.2f, %.2f, %.2f), Constrained: (%.2f, %.2f, %.2f)",
						arenaConfig.type,
						pos.X, pos.Y, pos.Z,
						constrained.X, constrained.Y, constrained.Z
					))
				end
			else
				-- Constrained position must be in bounds
				if not arena:IsInBounds(constrained) then
					error(string.format(
						"Consistency violated: IsInBounds=false but constrained position is still out of bounds. " ..
						"Arena: %s, Constrained: (%.2f, %.2f, %.2f)",
						arenaConfig.type,
						constrained.X, constrained.Y, constrained.Z
					))
				end
			end
		end
	end
	
	return runPropertyTest("Property: IsInBounds consistency", ITERATIONS, testFunc)
end

-- Run all property tests
function PropertyTests.runAll()
	print("\n" .. string.rep("=", 60))
	print("=== Running Arena Property-Based Tests ===")
	print(string.rep("=", 60))
	
	local allPassed = true
	local results = {}
	
	-- Run Property 42
	local p42Passed, p42Failures = PropertyTests.testProperty42_BoundaryCollisionForPlayers()
	table.insert(results, { name = "Property 42", passed = p42Passed })
	allPassed = allPassed and p42Passed
	
	-- Run Property 43
	local p43Passed, p43Failures = PropertyTests.testProperty43_BoundaryCollisionForBodyParts()
	table.insert(results, { name = "Property 43", passed = p43Passed })
	allPassed = allPassed and p43Passed
	
	-- Run additional properties
	local idempotencePassed = PropertyTests.testProperty_ConstraintIdempotence()
	table.insert(results, { name = "Constraint Idempotence", passed = idempotencePassed })
	allPassed = allPassed and idempotencePassed
	
	local consistencyPassed = PropertyTests.testProperty_IsInBoundsConsistency()
	table.insert(results, { name = "IsInBounds Consistency", passed = consistencyPassed })
	allPassed = allPassed and consistencyPassed
	
	-- Print summary
	print("\n" .. string.rep("=", 60))
	print("=== Property Test Summary ===")
	print(string.rep("=", 60))
	
	for _, result in ipairs(results) do
		local status = result.passed and "✓ PASSED" or "✗ FAILED"
		print(string.format("%s: %s", status, result.name))
	end
	
	print(string.rep("=", 60))
	
	if allPassed then
		print("\n✓ All property tests PASSED!")
		print("\n**Validates: Requirements 12.2, 12.3**")
	else
		print("\n✗ Some property tests FAILED")
	end
	
	return allPassed
end

return PropertyTests
