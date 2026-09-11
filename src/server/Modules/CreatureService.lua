--[[
	CreatureService.lua
	Turns static CreatureConfig data into an actual owned creature
	inside a player's save data.

	USAGE (from another server script, e.g. an egg-hatching prompt):
		local CreatureService = require(path.to.CreatureService)
		local newCreature = CreatureService.HatchEgg(player, "EmberFox")

	Depends on:
		- CreatureConfig (ReplicatedStorage.Shared.Config.CreatureConfig)
		  for species data
		- PlayerDataManager (sibling module in this same folder) for
		  reading/writing the player's profile
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreatureConfig = require(ReplicatedStorage.Shared.Config.CreatureConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

local CreatureService = {}

-- ============================================================
-- INTERNAL HELPERS
-- ============================================================

local function deepCopy(original)
	local copy = {}
	for key, value in pairs(original) do
		if type(value) == "table" then
			copy[key] = deepCopy(value)
		else
			copy[key] = value
		end
	end
	return copy
end

-- ============================================================
-- PUBLIC API
-- ============================================================

-- Creates a new creature instance of `creatureId` for `player`,
-- appends it to their save data, and saves immediately.
-- Returns the new creature instance table, or nil (+ a warn) if
-- something was invalid (bad creatureId, no loaded profile).
function CreatureService.HatchEgg(player, creatureId)
	local config = CreatureConfig.Get(creatureId)
	if not config then
		warn(("CreatureService.HatchEgg: unknown creatureId '%s'"):format(tostring(creatureId)))
		return nil
	end

	local profile = PlayerDataManager.Get(player)
	if not profile then
		warn(("CreatureService.HatchEgg: no loaded profile for %s (too early / not loaded?)"):format(player.Name))
		return nil
	end

	local creatureInstance = {
		InstanceId = HttpService:GenerateGUID(false), -- unique per-creature, not per-species
		Species = config.Id,
		Rarity = config.Rarity,
		Stats = deepCopy(config.BaseStats),            -- player's own copy, safe to grow via training later
		MutationLevel = 0,
		HatchedAt = os.time(),
	}

	table.insert(profile.Data.Creatures, creatureInstance)

	-- Explicit save on top of ProfileService's ~30s autosave - a
	-- hatch is a meaningful, low-frequency event worth flushing
	-- immediately rather than waiting on the interval.
	profile:Save()

	print(("CreatureService: %s hatched a %s (%s)"):format(
		player.Name, config.Name, creatureInstance.InstanceId
	))

	return creatureInstance
end

return CreatureService
