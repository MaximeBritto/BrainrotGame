-- Name Fragments for Brainrot Assembly
-- Contains lists of silly name fragments for each body part type

local NameFragments = {}

-- Head Fragments (20-30 options)
NameFragments.HEAD = {
	"Brr Brr",
	"Skibidi",
	"Gyatt",
	"Rizz",
	"Sigma",
	"Alpha",
	"Beta",
	"Giga",
	"Mega",
	"Ultra",
	"Hyper",
	"Super",
	"Turbo",
	"Nitro",
	"Quantum",
	"Cosmic",
	"Astral",
	"Mystic",
	"Epic",
	"Legendary",
	"Mythic",
	"Divine",
	"Celestial",
	"Ethereal",
	"Phantom",
	"Shadow",
	"Neon",
	"Cyber",
	"Digital",
	"Virtual"
}

-- Body Fragments (20-30 options)
NameFragments.BODY = {
	"Pata",
	"Dop",
	"Sigma",
	"Ohio",
	"Mewing",
	"Bussin",
	"Sheesh",
	"Slay",
	"Vibe",
	"Drip",
	"Flex",
	"Glow",
	"Sauce",
	"Wave",
	"Flow",
	"Boost",
	"Dash",
	"Rush",
	"Blast",
	"Storm",
	"Thunder",
	"Lightning",
	"Flame",
	"Frost",
	"Void",
	"Chaos",
	"Nova",
	"Pulse",
	"Echo",
	"Rift"
}

-- Legs Fragments (20-30 options)
NameFragments.LEGS = {
	"Pim",
	"Yes",
	"Mog",
	"Fanum",
	"Tax",
	"Cap",
	"Bet",
	"Lit",
	"Fire",
	"Ice",
	"Zap",
	"Boom",
	"Bang",
	"Pow",
	"Zoom",
	"Dash",
	"Sprint",
	"Leap",
	"Jump",
	"Fly",
	"Glide",
	"Slide",
	"Drift",
	"Spin",
	"Twist",
	"Turn",
	"Roll",
	"Flip",
	"Kick",
	"Stomp"
}

-- Get a random fragment for a specific body part type
function NameFragments.GetRandom(bodyPartType)
	if bodyPartType == "HEAD" then
		return NameFragments.HEAD[math.random(1, #NameFragments.HEAD)]
	elseif bodyPartType == "BODY" then
		return NameFragments.BODY[math.random(1, #NameFragments.BODY)]
	elseif bodyPartType == "LEGS" then
		return NameFragments.LEGS[math.random(1, #NameFragments.LEGS)]
	end
	return "Unknown"
end

return NameFragments
