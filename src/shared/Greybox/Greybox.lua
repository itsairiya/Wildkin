--[[
	MeadowGreybox.lua
	Data-driven gray-box generator for the Sunveil Meadow biome.

	USAGE (Studio Command Bar, after Rojo has synced this file in):
		local Meadow = require(path.to.MeadowGreybox)
		Meadow.Build()   -- (re)builds the greybox layout
		Meadow.Clear()   -- removes it

	Design:
		- Everything lives under workspace.MeadowGreybox so it can be
		  wiped and rebuilt instantly as the layout changes.
		- The layout is a plain Lua table (MARKERS below), so changes
		  show up as clean diffs in git instead of opaque binary model
		  changes.
		- Each marker becomes a colored, labeled Part with Attributes
		  (Category, Notes) so your friend can filter by type in
		  Studio and know exactly what to build/replace at each spot.
		- Re-running Build() is idempotent - it clears the old folder
		  first, so you can iterate on the marker table freely.
]]

local MeadowGreybox = {}

-- ============================================================
-- CONFIG — edit these to reshape the biome
-- ============================================================

local BIOME_ORIGIN = Vector3.new(0, 0, 0)      -- where Meadow meets the hub
local BIOME_RADIUS = 200                        -- rough play-area radius (studs)
local GROUND_Y = 0

local CATEGORY_COLORS = {
	HubLink        = Color3.fromRGB(80, 160, 255),
	SpawnPoint     = Color3.fromRGB(255, 255, 120),
	CreatureSpawn  = Color3.fromRGB(90, 200, 90),
	TamingStation  = Color3.fromRGB(60, 150, 60),
	ResourceNode   = Color3.fromRGB(200, 160, 90),
	POI            = Color3.fromRGB(200, 90, 200),
	BoundaryPost   = Color3.fromRGB(220, 60, 60),
}

-- ============================================================
-- MARKERS — the actual layout. This is the part you'll edit
-- most as you iterate on the biome. Positions are relative to
-- BIOME_ORIGIN so you can shift the whole biome by changing one
-- number above.
-- ============================================================

local MARKERS = {
	{ name = "HubLink_Main", category = "HubLink",
		position = BIOME_ORIGIN, notes = "Connects to central hub base" },

	{ name = "PlayerSpawn_1", category = "SpawnPoint",
		position = BIOME_ORIGIN + Vector3.new(0, 0, 20), notes = "Default spawn" },

	{ name = "TamingStation_1", category = "TamingStation",
		position = BIOME_ORIGIN + Vector3.new(-60, 0, 80), notes = "Beast taming - tier 1" },
	{ name = "TamingStation_2", category = "TamingStation",
		position = BIOME_ORIGIN + Vector3.new(90, 0, 130), notes = "Beast taming - tier 2" },

	{ name = "CreatureSpawn_Grove", category = "CreatureSpawn",
		position = BIOME_ORIGIN + Vector3.new(-100, 0, 40), radius = 25,
		notes = "Ground beast family - low tier" },
	{ name = "CreatureSpawn_Ridge", category = "CreatureSpawn",
		position = BIOME_ORIGIN + Vector3.new(120, 0, 20), radius = 25,
		notes = "Ground beast family - low tier" },
	{ name = "CreatureSpawn_RiverBank", category = "CreatureSpawn",
		position = BIOME_ORIGIN + Vector3.new(20, 0, 160), radius = 30,
		notes = "Ground beast family - mid tier, tracking-heavy" },

	{ name = "ResourceNode_1", category = "ResourceNode",
		position = BIOME_ORIGIN + Vector3.new(-40, 0, 60), notes = "Basic building resource" },
	{ name = "ResourceNode_2", category = "ResourceNode",
		position = BIOME_ORIGIN + Vector3.new(60, 0, 90), notes = "Basic building resource" },
	{ name = "ResourceNode_3", category = "ResourceNode",
		position = BIOME_ORIGIN + Vector3.new(-20, 0, 140), notes = "Basic building resource" },

	{ name = "POI_OldWatchtower", category = "POI",
		position = BIOME_ORIGIN + Vector3.new(150, 0, 150), notes = "Landmark - visible from spawn" },
	{ name = "POI_QuietLake", category = "POI",
		position = BIOME_ORIGIN + Vector3.new(-140, 0, 170), notes = "Landmark - scenic, fishing hook later" },
}

-- ============================================================
-- INTERNAL HELPERS
-- ============================================================

local function getOrCreateRoot()
	local existing = workspace:FindFirstChild("MeadowGreybox")
	if existing then
		existing:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "MeadowGreybox"
	root.Parent = workspace
	return root
end

local function addLabel(part, text, color)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.new(0, 160, 0, 36)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.TextColor3 = color
	textLabel.TextStrokeTransparency = 0
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextScaled = true
	textLabel.Text = text
	textLabel.Parent = billboard
end

local function makeMarkerPart(def, parent)
	local color = CATEGORY_COLORS[def.category] or Color3.fromRGB(200, 200, 200)
	local part = Instance.new("Part")
	part.Name = def.name
	part.Anchored = true
	part.CanCollide = false
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic

	if def.radius then
		-- Flat translucent disc marking an area (e.g. a spawn zone)
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(1, def.radius * 2, def.radius * 2)
		part.Transparency = 0.55
		part.CFrame = CFrame.new(def.position + Vector3.new(0, 0.5, 0))
			* CFrame.Angles(0, 0, math.rad(90))
	else
		-- Simple point marker post
		part.Size = Vector3.new(4, 6, 4)
		part.CFrame = CFrame.new(def.position + Vector3.new(0, 3, 0))
	end

	part:SetAttribute("Category", def.category)
	part:SetAttribute("Notes", def.notes or "")

	addLabel(part, string.format("%s\n[%s]", def.name, def.category), color)
	part.Parent = parent
	return part
end

local function makeBaseplate(root)
	local plate = Instance.new("Part")
	plate.Name = "GreyboxGround"
	plate.Anchored = true
	plate.CanCollide = true
	plate.Size = Vector3.new(BIOME_RADIUS * 2.4, 4, BIOME_RADIUS * 2.4)
	plate.CFrame = CFrame.new(BIOME_ORIGIN + Vector3.new(0, GROUND_Y - 2, BIOME_RADIUS * 0.6))
	plate.Color = Color3.fromRGB(140, 140, 140)
	plate.Material = Enum.Material.SmoothPlastic
	plate.Parent = root
	return plate
end

local function makeBoundaryRing(root)
	local postCount = 16
	for i = 1, postCount do
		local angle = (i / postCount) * math.pi * 2
		local pos = BIOME_ORIGIN + Vector3.new(
			math.cos(angle) * BIOME_RADIUS,
			0,
			math.sin(angle) * BIOME_RADIUS + BIOME_RADIUS * 0.6
		)
		makeMarkerPart({
			name = "BoundaryPost_" .. i,
			category = "BoundaryPost",
			position = pos,
			notes = "Biome edge - not final geometry, just a play-area cue",
		}, root)
	end
end

-- ============================================================
-- PUBLIC API
-- ============================================================

function MeadowGreybox.Build()
	local root = getOrCreateRoot()
	makeBaseplate(root)
	makeBoundaryRing(root)

	local markersFolder = Instance.new("Folder")
	markersFolder.Name = "Markers"
	markersFolder.Parent = root

	for _, def in ipairs(MARKERS) do
		makeMarkerPart(def, markersFolder)
	end

	print(("MeadowGreybox: built %d markers + boundary ring."):format(#MARKERS))
end

function MeadowGreybox.Clear()
	local root = workspace:FindFirstChild("MeadowGreybox")
	if root then
		root:Destroy()
		print("MeadowGreybox: cleared.")
	end
end

return MeadowGreybox
