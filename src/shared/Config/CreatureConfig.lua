--[[
	CreatureConfig.lua
	Static data for every creature species in the game. This is the
	"design table" - HatchEgg (in CreatureService) reads from here to
	build an actual creature instance for a player.

	Lives in ReplicatedStorage.Shared because both server (hatching,
	stat calculations) and client (UI showing creature info) need to
	read it. It's read-only data, not player-owned state, so there's
	no security concern exposing it to the client.

	Adding a 4th creature later = add one more entry below. Nothing
	else needs to change structurally.
]]

local CreatureConfig = {}

-- ============================================================
-- CREATURES
-- ============================================================
-- BaseStats are the level-1 / unmutated starting point. Actual
-- in-battle stats will later be BaseStats + growth-from-training,
-- capped per your stat-cap-by-rarity-and-species design.
--
-- MutationTable is intentionally an empty stub per creature until
-- the mutation system is designed. Expected future shape (not
-- implemented yet, just documenting the intent):
--   MutationTable = {
--       [MutationId] = { StatBonus = {...}, UnlockCondition = ... }
--   }

CreatureConfig.Creatures = {

	EmberFox = {
		Id = "EmberFox",
		Name = "Ember Fox",
		Family = "Beast",          -- discovery method: tracking & taming (Sunveil Meadow)
		Rarity = "Common",
		BaseStats = {
			Health = 100,
			Attack = 12,
			Defense = 8,
			Speed = 14,
		},
		MutationTable = {},
	},

	LeafStag = {
		Id = "LeafStag",
		Name = "Leaf Stag",
		Family = "Beast",
		Rarity = "Common",
		BaseStats = {
			Health = 130,
			Attack = 9,
			Defense = 13,
			Speed = 8,
		},
		MutationTable = {},
	},

	PuffHare = {
		Id = "PuffHare",
		Name = "Puff Hare",
		Family = "Beast",
		Rarity = "Uncommon",
		BaseStats = {
			Health = 80,
			Attack = 10,
			Defense = 7,
			Speed = 20,
		},
		MutationTable = {},
	},
}

-- ============================================================
-- PUBLIC API
-- ============================================================

-- Returns the config table for a creature species, or nil if the
-- id doesn't exist (e.g. typo, or content not shipped yet).
function CreatureConfig.Get(creatureId)
	return CreatureConfig.Creatures[creatureId]
end

return CreatureConfig
