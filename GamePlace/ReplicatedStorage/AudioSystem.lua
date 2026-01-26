-- Audio System Module
-- Manages sound effects and music
-- Requirements: 3.5, 5.5, 8.3, 8.4, 8.5

local AudioSystem = {}

-- Sound IDs (replace with actual Roblox sound IDs)
AudioSystem.Sounds = {
	completion = "rbxassetid://0", -- Victory sound
	collection = "rbxassetid://0", -- Pop/ding sound
	laserHit = "rbxassetid://0", -- Electric zap
	punchHit = "rbxassetid://0", -- Cartoon punch
	cannonFire = "rbxassetid://0", -- Whoosh
	barrierActivate = "rbxassetid://0", -- Force field hum
	theft = "rbxassetid://0" -- Sneaky sound
}

function AudioSystem.PlaySoundEffect(soundId, position, volume)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.5
	
	if position then
		-- Spatial audio
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.Transparency = 1
		part.Size = Vector3.new(1, 1, 1)
		part.Position = position
		part.Parent = workspace
		
		sound.Parent = part
		sound:Play()
		
		game:GetService("Debris"):AddItem(part, sound.TimeLength + 0.5)
	else
		-- Global audio
		sound.Parent = workspace
		sound:Play()
		
		game:GetService("Debris"):AddItem(sound, sound.TimeLength + 0.5)
	end
	
	return sound
end

return AudioSystem
