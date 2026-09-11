--[[
	PlayerDataManager.lua
	Wraps ProfileService with our game's data schema and exposes a
	small API for the rest of the server codebase to use.

	USAGE (from another server script):
		local PlayerDataManager = require(path.to.PlayerDataManager)

		local profile = PlayerDataManager.Get(player)
		if profile then
			profile.Data.Currency += 50
		end

	Design notes:
		- ProfileService already auto-saves every ~30s for all loaded
		  profiles (AutoSaveProfiles setting inside ProfileService.lua
		  itself) AND saves immediately when a profile is released.
		  That covers "don't lose progress on crash" already - you do
		  not need to hand-roll a save loop.
		- We still expose PlayerDataManager.ForceSaveAll() so you can
		  call it manually (e.g. bound to a Studio test button, or
		  before a scheduled server shutdown) without waiting on the
		  interval.
		- DEFAULT_DATA is the schema. Add fields here as the game
		  grows - Profile:Reconcile() (called in Get) will backfill
		  any new fields onto existing players' saves automatically,
		  so you never have to write a manual migration for additive
		  changes.
]]

local Players = game:GetService("Players")

local ProfileService = require(script.Parent.ProfileService)

local PlayerDataManager = {}

-- ============================================================
-- SCHEMA — the shape of one player's save data.
-- Keep this minimal and additive; Reconcile() fills in new keys
-- for existing players automatically, it just won't remove or
-- restructure old ones for you.
-- ============================================================

local DEFAULT_DATA = {
	Creatures = {},        -- array of { Id, Species, Rarity, Stats = {...}, MutationLevel }
	Currency = 0,
	ExpeditionLevel = 1,
}

local PROFILE_STORE_NAME = "PlayerData_v1" -- bump the suffix (v2, v3...) only if you
											 -- deliberately want a full data reset

local ProfileStore = ProfileService.GetProfileStore(PROFILE_STORE_NAME, DEFAULT_DATA)

-- player.UserId -> Profile object
local Profiles = {}

-- ============================================================
-- INTERNAL: load / release
-- ============================================================

local function onPlayerAdded(player)
	local profile = ProfileStore:LoadProfileAsync(tostring(player.UserId))

	if profile == nil then
		-- Couldn't load (DataStore outage, etc.) - kick rather than
		-- let them play on data that won't save.
		player:Kick("Failed to load your data. Please rejoin in a moment.")
		return
	end

	profile:AddUserId(player.UserId) -- GDPR-related tagging, standard ProfileService practice
	profile:Reconcile()              -- backfill any new DEFAULT_DATA keys

	profile:ListenToRelease(function()
		-- Fires if the session lock is stolen or profile is released.
		Profiles[player.UserId] = nil
		player:Kick("Your data was loaded on another server. Please rejoin.")
	end)

	if player.Parent == Players then
		-- Player is still here (didn't leave while we were loading)
		Profiles[player.UserId] = profile
		print(("PlayerDataManager: profile loaded for %s"):format(player.Name))
	else
		-- Player left mid-load; release immediately so we don't hold
		-- the session lock open for nothing.
		profile:Release()
	end
end

local function onPlayerRemoving(player)
	local profile = Profiles[player.UserId]
	if profile then
		profile:Release() -- saves immediately, then unlocks the session
		Profiles[player.UserId] = nil
	end
end

-- ============================================================
-- PUBLIC API
-- ============================================================

-- Returns the live Profile object for a player, or nil if not
-- loaded yet (e.g. called too early in PlayerAdded) or load failed.
-- profile.Data is the table you read/write.
function PlayerDataManager.Get(player)
	return Profiles[player.UserId]
end

-- Manually flush every currently-loaded profile to the DataStore
-- right now, without waiting for ProfileService's own ~30s interval.
-- Useful before a scheduled shutdown or for manual testing.
function PlayerDataManager.ForceSaveAll()
	local count = 0
	for _, profile in pairs(Profiles) do
		profile:Save()
		count += 1
	end
	print(("PlayerDataManager: force-saved %d profile(s)."):format(count))
end

-- ============================================================
-- WIRE UP
-- ============================================================

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Catch players already in-game if this module is required after
-- the server starts (shouldn't normally happen, but cheap insurance)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

return PlayerDataManager
