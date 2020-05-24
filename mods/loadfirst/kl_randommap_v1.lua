// Script by SteelT
// Pick a random valid map and warp to it.

COM_AddCommand("randommap", function(p)
	local validmaps = {}
	local tolflags

	if not (server) then return end

	if gametype == GT_RACE then
		tolflags = TOL_RACE
	else
		tolflags = TOL_MATCH // Battle
	end

	for i=1,#mapheaderinfo // Build validmaps table
		if not (mapheaderinfo[i]) then // Check if the map exist using mapheaderinfo, as there is no way to check for map lump.
			continue
		end

		if (mapheaderinfo[i].menuflags & LF2_HIDEINMENU) // Don't include hell maps
			continue
		end

		if (mapheaderinfo[i].typeoflevel & tolflags) then // Make sure the maps match the current gametype
			table.insert(validmaps, G_BuildMapName(i))
		end
	end

	if #validmaps > 0 then
		COM_BufInsertText(server, "map "..validmaps[P_RandomRange(1, #validmaps)]) // Finally pick a random map
	end
end, 1)