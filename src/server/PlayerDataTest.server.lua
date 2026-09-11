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

