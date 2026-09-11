--[[
	PlayerDataTest.server.lua
	Temporary script to sanity-check that PlayerDataManager actually
	persists data. Delete this once you've confirmed it works, or
	leave it commented out for future reference.

	What it does:
		- On join, waits for the profile to be ready, then bumps
		  Currency by 10 and prints the new total.
		- If saving/loading works, rejoining should show the number
		  keep climbing (10, 20, 30...). If it resets to 10 every
		  time, saves aren't persisting.
]]


local Players = game:GetService("Players")
local PlayerDataManager = require(script.Parent.Modules.PlayerDataManager)
 
local function waitForProfile(player)
	local profile = PlayerDataManager.Get(player)
	local attempts = 0
	while not profile and attempts < 50 do -- ~5 second timeout
		task.wait(0.1)
		profile = PlayerDataManager.Get(player)
		attempts += 1
	end
	return profile
end
 
Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		local profile = waitForProfile(player)
		if not profile then
			warn(("PlayerDataTest: profile never loaded for %s"):format(player.Name))
			return
		end
 
		profile.Data.Currency += 10

		local CreatureService = require(script.Parent.Modules.CreatureService)
		CreatureService.HatchEgg(player, "EmberFox")
 
		print(("PlayerDataTest: %s Currency = %d | ExpeditionLevel = %d | Creatures = %d")
			:format(player.Name, profile.Data.Currency, profile.Data.ExpeditionLevel, #profile.Data.Creatures))
	end)
end)


