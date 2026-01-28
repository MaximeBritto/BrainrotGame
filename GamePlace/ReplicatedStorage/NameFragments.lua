-- Name Fragments for Brainrot Assembly
-- This module dynamically loads all available body part models from ReplicatedStorage
-- No need to manually update lists - just add Models to BodyPartTemplates folder!

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NameFragments = {}

-- Cache for loaded fragments
NameFragments.HEAD = {}
NameFragments.BODY = {}
NameFragments.LEGS = {}

--[[
	Loads all available body part models from BodyPartTemplates folder
	Automatically categorizes them based on their parent folder name or attribute
]]
local function LoadFragmentsFromTemplates()
	local templates = ReplicatedStorage:FindFirstChild("BodyPartTemplates")
	if not templates then
		warn("❌ BodyPartTemplates folder not found in ReplicatedStorage!")
		return
	end
	
	-- Clear existing lists
	NameFragments.HEAD = {}
	NameFragments.BODY = {}
	NameFragments.LEGS = {}
	
	-- Scan through all children in BodyPartTemplates (including subfolders)
	for _, folder in ipairs(templates:GetChildren()) do
		-- Determine type from folder name
		local folderType = nil
		if folder.Name:lower():find("head") then
			folderType = "HEAD"
		elseif folder.Name:lower():find("body") then
			folderType = "BODY"
		elseif folder.Name:lower():find("leg") then
			folderType = "LEGS"
		end
		
		-- If it's a folder with a recognized type, scan its children
		if folderType and (folder:IsA("Folder") or folder:IsA("Model")) then
			for _, child in ipairs(folder:GetChildren()) do
				if child:IsA("Model") then
					-- Add the model name to the appropriate list
					if folderType == "HEAD" then
						table.insert(NameFragments.HEAD, child.Name)
						print(string.format("  ✓ Added HEAD: %s", child.Name))
					elseif folderType == "BODY" then
						table.insert(NameFragments.BODY, child.Name)
						print(string.format("  ✓ Added BODY: %s", child.Name))
					elseif folderType == "LEGS" then
						table.insert(NameFragments.LEGS, child.Name)
						print(string.format("  ✓ Added LEGS: %s", child.Name))
					end
				end
			end
		-- If it's a direct Model in BodyPartTemplates, check for attribute
		elseif folder:IsA("Model") then
			local partType = folder:GetAttribute("BodyPartType")
			if partType == "HEAD" then
				table.insert(NameFragments.HEAD, folder.Name)
				print(string.format("  ✓ Added HEAD: %s", folder.Name))
			elseif partType == "BODY" then
				table.insert(NameFragments.BODY, folder.Name)
				print(string.format("  ✓ Added BODY: %s", folder.Name))
			elseif partType == "LEGS" then
				table.insert(NameFragments.LEGS, folder.Name)
				print(string.format("  ✓ Added LEGS: %s", folder.Name))
			end
		end
	end
	
	print(string.format("✓ Loaded fragments: %d HEAD, %d BODY, %d LEGS", 
		#NameFragments.HEAD, #NameFragments.BODY, #NameFragments.LEGS))
end

-- Load fragments on module initialization
LoadFragmentsFromTemplates()

-- Get a random fragment for a specific body part type
function NameFragments.GetRandom(bodyPartType)
	local list
	if bodyPartType == "HEAD" then
		list = NameFragments.HEAD
	elseif bodyPartType == "BODY" then
		list = NameFragments.BODY
	elseif bodyPartType == "LEGS" then
		list = NameFragments.LEGS
	end
	
	if list and #list > 0 then
		return list[math.random(1, #list)]
	end
	
	warn(string.format("❌ No fragments available for type: %s", tostring(bodyPartType)))
	return "Unknown"
end

-- Reload fragments (useful if models are added at runtime)
function NameFragments.Reload()
	LoadFragmentsFromTemplates()
end

return NameFragments
