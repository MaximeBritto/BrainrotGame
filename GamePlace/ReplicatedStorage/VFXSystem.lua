-- VFX System Module
-- Creates visual effects for game events
-- Requirements: 3.5, 8.1, 8.2, 8.6, 8.7

local VFXSystem = {}

-- Particle effect pooling
local particlePool = {}

function VFXSystem.CreateCompletionEffect(position)
	-- Neon burst particles
	local attachment = Instance.new("Attachment")
	attachment.Position = position
	attachment.Parent = workspace.Terrain
	
	local particle = Instance.new("ParticleEmitter")
	particle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particle.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 0))
	})
	particle.Size = NumberSequence.new(2, 0)
	particle.Lifetime = NumberRange.new(1, 2)
	particle.Rate = 100
	particle.Speed = NumberRange.new(10, 20)
	particle.SpreadAngle = Vector2.new(180, 180)
	particle.Parent = attachment
	
	particle:Emit(50)
	
	game:GetService("Debris"):AddItem(attachment, 3)
	
	return particle
end

function VFXSystem.CreateCollectionEffect(position, bodyPartType)
	local attachment = Instance.new("Attachment")
	attachment.Position = position
	attachment.Parent = workspace.Terrain
	
	local particle = Instance.new("ParticleEmitter")
	particle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	
	-- Color based on body part type
	local color
	if bodyPartType == "HEAD" then
		color = Color3.fromRGB(0, 255, 255) -- Cyan
	elseif bodyPartType == "BODY" then
		color = Color3.fromRGB(255, 0, 255) -- Pink
	else -- LEGS
		color = Color3.fromRGB(255, 255, 0) -- Yellow
	end
	
	particle.Color = ColorSequence.new(color)
	particle.Size = NumberSequence.new(1, 0)
	particle.Lifetime = NumberRange.new(0.3, 0.5)
	particle.Rate = 50
	particle.Speed = NumberRange.new(5, 10)
	particle.SpreadAngle = Vector2.new(90, 90)
	particle.Parent = attachment
	
	particle:Emit(20)
	
	game:GetService("Debris"):AddItem(attachment, 1)
	
	return particle
end

function VFXSystem.CreateHitEffect(position, hitType)
	local attachment = Instance.new("Attachment")
	attachment.Position = position
	attachment.Parent = workspace.Terrain
	
	local particle = Instance.new("ParticleEmitter")
	particle.Texture = "rbxasset://textures/particles/smoke_main.dds"
	
	if hitType == "LASER" then
		-- Red electric effect
		particle.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0))
		particle.Size = NumberSequence.new(2, 0)
		particle.Lifetime = NumberRange.new(0.5, 1)
		particle.Rate = 80
	else -- PUNCH
		-- Yellow star burst
		particle.Color = ColorSequence.new(Color3.fromRGB(255, 255, 0))
		particle.Size = NumberSequence.new(1.5, 0)
		particle.Lifetime = NumberRange.new(0.3, 0.5)
		particle.Rate = 60
	end
	
	particle.Speed = NumberRange.new(8, 15)
	particle.SpreadAngle = Vector2.new(180, 180)
	particle.Parent = attachment
	
	particle:Emit(30)
	
	game:GetService("Debris"):AddItem(attachment, 2)
	
	return particle
end

function VFXSystem.ApplyScreenShake(player, intensity, duration)
	-- This would be called on the client
	local camera = workspace.CurrentCamera
	if not camera then return end
	
	local originalCFrame = camera.CFrame
	local shakeAmount = intensity or 0.5
	local shakeDuration = duration or 0.3
	
	local startTime = tick()
	
	game:GetService("RunService").RenderStepped:Connect(function()
		local elapsed = tick() - startTime
		if elapsed >= shakeDuration then
			camera.CFrame = originalCFrame
			return
		end
		
		local progress = elapsed / shakeDuration
		local currentShake = shakeAmount * (1 - progress)
		
		local offsetX = (math.random() - 0.5) * currentShake
		local offsetY = (math.random() - 0.5) * currentShake
		
		camera.CFrame = originalCFrame * CFrame.new(offsetX, offsetY, 0)
	end)
end

function VFXSystem.ApplyNeonGlow(part, bodyPartType)
	part.Material = Enum.Material.Neon
	
	if bodyPartType == "HEAD" then
		part.Color = Color3.fromRGB(0, 255, 255) -- Cyan
	elseif bodyPartType == "BODY" then
		part.Color = Color3.fromRGB(255, 0, 255) -- Pink
	else -- LEGS
		part.Color = Color3.fromRGB(255, 255, 0) -- Yellow
	end
	
	-- Add point light for extra glow
	local light = Instance.new("PointLight")
	light.Color = part.Color
	light.Brightness = 2
	light.Range = 10
	light.Parent = part
	
	return light
end

return VFXSystem
