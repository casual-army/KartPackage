--[[
	Combi Ring: team racing by fickleheart
	SRB2MB thread: http://mb.srb2.org/showthread.php?t=44095
	
	While you're here, some tips:
	- The custom buttons operate turn signals!
	  - Custom 1: Signal left
	  - Custom 2: Signal right
	  - Custom 3 OR Custom 1+2 together: Signal center
	  Use them on path splits, or if you want to take a shortcut! It's probably curteous to
	  respond to your teammate's signal by pressing the same, as well.
	- The ideal team is similar speed class, opposite weight class. The light racer should be
	  steering HARD into everything and anchoring the heavy racer while they drift wide for
	  huge miniturbos. Taking opposite sides also lets you pull each other back in if one
	  of you goes off the track!
	- If one of you hits a fake, the other can use grow or invincibility to nullify the explosion's
	  effect. If neither of you have that, the one with the fake should blow up behind the other
	  so they can be carried forward and mitigate the time loss.
	- Don't take difficult shortcuts if you don't trust your teammate to handle them, or you'll
	  lose a lot of time.
	- ALL boost types are shared between racers. Grow and invincibility too.
	  - Stagger miniturbos so that they overlap as little as possible for maximum gain from each turn.
	  - Don't use sneakers at the same time or you'll waste one!
	  - Combine grow and invincibility for a fun time.
	- Remember to always own up to your mistakes, and congratulate your partner on what they do well!
	- It's just a game, and a wacky one at that. Getting a bad finish is okay because it usually happened
	  because of something funny.
	- If you don't like being tethered to someone else in a server hosting this, you can choose to race
	  by yourself by pressing alt+F4 and joining another server!
	- im gay
	
	------
	v3b changelog:
	- minor changes to support a few other mods
	- fixed splitscreen hud when paused
	
	------
	v3 changelog:
	- respawning now brings your teammate to you if they were still respawning, to prevent respawn loops
	- friends! say "friend <player>" or use combi_friend in the console to befriend a player and always be paired with them
	- cvars are now properly netsynced
	- if you are in the air for over three seconds longer than your partner, you will be immediately respawned
	
	------
	v2 changelog:
	- fixed triplet pair glitch
	- added failsafe for getting stuck in gargoyles
	- changed respawn behavior: respawning player now hovers over their teammate
	- teammate's roulette now colorizes and flashes like 1.0.2+ roulette does
	- added splitscreen hud support (breaks when paused, sorry)
	- added replay mode (combi_replay on): moves name labels to fit with replay hud and adds a combined camera view
	- combi can be disabled via cvar
]]

freeslot("MT_COMBILINK", "S_COMBILINK")

mobjinfo[MT_COMBILINK] = {
	spawnstate = S_COMBILINK,
	flags = MF_NOCLIP|MF_NOCLIPHEIGHT|MF_NOGRAVITY|MF_SCENERY
}
states[S_COMBILINK] = {SPR_THOK, 0}

local cv_combi = CV_RegisterVar({"combi_active", "On", CV_NETVAR, CV_OnOff})
local cv_combifriends = CV_RegisterVar({"combi_allowfriends", "On", CV_NETVAR, CV_OnOff})
local cv_combireplay = CV_RegisterVar({"combi_replay", "Off", 0, {
	Off = 0,
	On = 1,
	Partial = 2,
}})

-- A hack way to store data in replays
local cv_combifriend = {}
local MAXPLAYERS = #players
for i = 0, MAXPLAYERS-1 do
	cv_combifriend[i] = CV_RegisterVar({"storage__combi_friend_" .. i, "0", CV_NETVAR, {
		MIN = 0,
		MAX = MAXPLAYERS,
	}})
end

local combi_on = true
local combi_initscroll = 0

addHook("NetVars", function(sync)
	--print("--- NETVARS ---")

	combi_on = sync(combi_on)
	combi_initscroll = sync(combi_initscroll)
	
	--print(combi_on and "combi on" or "combi off")
	--print("initscroll: " .. combi_initscroll)
end)

local START_TIME = 5*TICRATE + 20
local BASE_DISTANCE = 450

local ring_bits = {}
local ring_bits_count = 0

local function PlaceRingBit(x, y, z, color)
	ring_bits_count = $+1
	
	if ring_bits[ring_bits_count] and ring_bits[ring_bits_count].valid then
		P_TeleportMove(ring_bits[ring_bits_count], x, y, z)
	else
		ring_bits[ring_bits_count] = P_SpawnMobj(x, y, z, MT_COMBILINK)
		ring_bits[ring_bits_count].scale = (mapheaderinfo[gamemap] and mapheaderinfo[gamemap].mobj_scale or FRACUNIT)/4
		--ring_bits[ring_bits_count].colorized = true
	end
	
	local bit = ring_bits[ring_bits_count]
	bit.fuse = 2
	bit.color = color
end

addHook("ThinkFrame", do
	--print(" --- leveltime " .. leveltime .. " ---")
	if not (leveltime & 255) then
		pcall(do COM_BufInsertText(server, "karteliminatelast off") end)
		for i = 0, MAXPLAYERS-1 do
			local friend = 0
			
			if players[i] and players[i].valid then
				local p = players[i]
				if not (p.combi_pending_friend and players[p.combi_pending_friend-1] and players[p.combi_pending_friend-1].valid) then
					p.combi_pending_friend = 0
				end
				friend = p.combi_pending_friend
			end
			
			if cv_combifriend[i].value ~= friend then
				COM_BufInsertText(server, "storage__combi_friend_" .. i .. " " .. friend)
				--print(i .. "'s combi friend is updated to " .. friend)
			end
		end
	end
	local mapscale = (mapheaderinfo[gamemap] and mapheaderinfo[gamemap].mobj_scale or FRACUNIT)
	local MAX_DISTANCE = BASE_DISTANCE * mapscale
	ring_bits_count = 0

	if leveltime == 0 then
		--print("reset goes here")
		combi_on = cv_combi.value
		combi_initscroll = -2*TICRATE
		
		for player in players.iterate do
			player.combi = nil
			player.combi_friend = cv_combifriends.value and cv_combifriend[#player].value or 0
			--print(player.name .. "'s combi friend is " .. player.combi_friend)
		end
	elseif not combi_on then
		return
	elseif leveltime <= START_TIME then
		if leveltime == START_TIME then S_StartSound(nil, sfx_token) end
		
		combi_initscroll = $ - min((START_TIME - leveltime)*2/5, TICRATE*2)
		if combi_initscroll < 0 then
			combi_initscroll = $ + TICRATE*6
		else
			return
		end

		local allPlayers = {}
		for player in players.iterate do
			if player.mo and player.mo.valid then
				player.old_combi = player.combi
				
				if player.combi_friend and players[player.combi_friend-1].valid and 
					players[player.combi_friend-1].mo and players[player.combi_friend-1].mo.valid and 
					players[player.combi_friend-1].combi_friend and players[player.combi_friend-1].combi_friend-1 == #player then
					player.combi = players[player.combi_friend-1]
				else
					table.insert(allPlayers, player)
				end
			else
				player.combi = nil
			end
		end
		
		while #allPlayers >= 2 do
			local one, two
			one = table.remove(allPlayers, P_RandomKey(#allPlayers)+1)
			two = table.remove(allPlayers, P_RandomKey(#allPlayers)+1)
			
			one.combi = two
			two.combi = one
		end
		
		if #allPlayers then
			allPlayers[1].combi = {valid = "maybe", name = "???"}
		end
		
		S_StartSound(nil, sfx_s1ba)
	end
	
	if leveltime < START_TIME then return end

	combi_initscroll = $/2
	
	for player in players.iterate do
		if player.spectator and player.combi then
			player.combi = nil
			continue
		end
	
		if not (player.mo and player.mo.valid) then continue end
		
		-- Make tugs at the start of the race less crazy
		if leveltime < START_TIME + TICRATE then
			player.mo.momx = $/3
			player.mo.momy = $/3
		end
		
		-- Turn signal
		player.turn_buttons = $ or 0
		local turn_buttons = player.cmd.buttons & (BT_CUSTOM1|BT_CUSTOM2|BT_CUSTOM3)
		
		if turn_buttons == BT_CUSTOM1 and not (player.turn_buttons & BT_CUSTOM1) then
			player.turn_signal = -3*TICRATE
		elseif turn_buttons == BT_CUSTOM2 and not (player.turn_buttons & BT_CUSTOM2) then
			player.turn_signal = 3*TICRATE
		elseif turn_buttons == BT_CUSTOM3 and player.turn_buttons ~= BT_CUSTOM3 then
			player.turn_signal = 3*TICRATE + FRACUNIT
		elseif turn_buttons == BT_CUSTOM1|BT_CUSTOM2 and player.turn_buttons ~= BT_CUSTOM1|BT_CUSTOM2 then
			player.turn_signal = 3*TICRATE + FRACUNIT
		end
		
		player.turn_buttons = turn_buttons
		
		if player.turn_signal then
			player.turn_signal = $ - (player.turn_signal > 0 and 1 or -1)
			if player.turn_signal == FRACUNIT then player.turn_signal = 0 end
		end
	
		-- combi stuff
		if not (player.combi and player.combi.valid and player.combi.valid ~= "maybe" and not player.combi.spectator) then
			player.combi = {
				valid = "uwu",
				name = "anti-loneliness \n gargoyle",
				mo = P_SpawnMobj(player.mo.x, player.mo.y, player.mo.z + 192*mapscale, MT_GARGOYLE),
			}
			player.combi.mo.flags = $ & ~MF_PUSHABLE
			player.combi.mo.partnered = true
		end
		
		if player.combi.valid == "uwu" and leveltime == START_TIME+22 then
			player.kartstuff[k_squishedtimer] = TICRATE
			player.state = S_KART_SQUISH
			P_InstaThrust(player.combi.mo, player.mo.angle, -5*mapscale)
			player.combi.mo.momz = 4*mapscale
		end
		
		--print(player.name .. " <3 " .. player.combi.name)
		
		if not (player.mo and player.mo.valid and player.combi.mo and player.combi.mo.valid) then continue end

		for i = (player.combi.valid == "uwu" and 1 or 4), 6 do
			local m = i*FRACUNIT/7
			PlaceRingBit(
				player.mo.x + FixedMul(player.combi.mo.x - player.mo.x, m),
				player.mo.y + FixedMul(player.combi.mo.y - player.mo.y, m),
				player.mo.z + FixedMul(player.combi.mo.z - player.mo.z, m) + 18*mapscale,
				player.mo.color
			)
		end
		
		local your_pull_xy = FRACUNIT
		local friend_pull_xy = FRACUNIT
		local your_pull_z = FRACUNIT
		local friend_pull_z = FRACUNIT
		
		if player.cmd.buttons & BT_ACCELERATE then
			your_pull_xy = $+FRACUNIT/2
		end
		if player.cmd.buttons & BT_BRAKE then
			your_pull_xy = $+FRACUNIT
		end
		if player.mo.z > player.mo.floorz then
			if player.combi.valid == "uwu" then
				friend_pull_z = 0
				friend_pull_xy = 0
			else
				your_pull_z = $+FRACUNIT*2
			end
			
			player.combi_airtime = (player.combi_airtime or 0) + 1
			
			if player.combi_airtime - (player.combi.combi_airtime or 0) > 3*TICRATE then
				P_TeleportMove(player.mo, player.combi.mo.x, player.combi.mo.y, player.combi.mo.z + 100*mapscale)
				player.combi_airtime = 0
				player.combi.combi_airtime = 0
			end
			
		else
			player.combi_airtime = 0
		
			if player.combi.mo.z <= player.combi.mo.floorz and player.mo.z + 200*mapscale > player.combi.mo.z then
				-- If both players are on the ground and not too far apart on the Z axis, do no vertical pulling at all.
				-- This should make driving along ramps (esp Volcanic Valley) more tolerable.
				friend_pull_z = 0
			end
		end
		
		if player.combi.valid ~= "uwu" then
			if player.combi.cmd.buttons & BT_ACCELERATE then
				friend_pull_xy = $+FRACUNIT/2
			end
			if player.combi.cmd.buttons & BT_BRAKE then
				friend_pull_xy = $+FRACUNIT
			end
			if player.combi.mo.z > player.combi.mo.floorz and friend_pull_z then
				friend_pull_z = $+FRACUNIT*2
			end
			
			-- sync some state-related stuff while we're here
			if player.kartstuff[k_growshrinktimer] < -2 and player.combi.kartstuff[k_growshrinktimer] >= -2 then
				player.kartstuff[k_growshrinktimer] = -2
			elseif player.kartstuff[k_growshrinktimer] >= 0 then
				player.kartstuff[k_growshrinktimer] = max($, player.combi.kartstuff[k_growshrinktimer])
			end
			player.mo.destscale = max($, player.combi.mo.destscale)
			player.mo.scalespeed = max($, player.combi.mo.scalespeed)
			for _,prop in ipairs({k_sneakertimer, k_invincibilitytimer, k_driftboost, k_startboost}) do
				player.kartstuff[prop] = max($, player.combi.kartstuff[prop])
			end
			player.realtime = min($, player.combi.realtime)

			if player.combi.exiting and not player.exiting then
				player.exiting = player.combi.exiting
				P_RestoreMusic(player)
			end
		end
		
		local yank_xy = FixedDiv(friend_pull_xy, your_pull_xy+friend_pull_xy)/4
		local yank_z = FixedDiv(friend_pull_z, your_pull_xy+friend_pull_z)/4
		
		if player.combi.valid == "uwu" then
			-- since I'm lazy this code block may have stuff for other players in it
			if player.kartstuff[k_respawn] then
				if (not player.combi_respawn) or (player.mo.momz > -3*mapscale and player.mo.z - player.mo.floorz > 20*mapscale) then
					local dist = FixedMul(mapscale, 60)
					
					-- Let players shift sideways while respawning if they hold drift?
					if player.cmd.buttons & BT_DRIFT then
						local speed = player.cmd.driftturn/100
						P_TryMove(player.mo, player.mo.x - sin(player.mo.angle)*speed, player.mo.y + cos(player.mo.angle)*speed, true)
					end
				
					player.combi_respawn = true
					
					P_TeleportMove(player.combi.mo, player.mo.x, player.mo.y, player.mo.z + 100*mapscale)
					player.combi.mo.momx, player.combi.mo.momy, player.combi.mo.momz = 0, 0, 0
					player.combi.mo.angle = player.mo.angle
					
					if player.combi.kartstuff then
						player.combi.kartstuff[k_respawn] = 0
					end
					
					continue
				end
			else
				player.combi_respawn = false
			end
		elseif player.kartstuff[k_respawn] > 1 and (player.kartstuff[k_respawn] < player.combi.kartstuff[k_respawn]+1 or player.combi.kartstuff[k_respawn] == 0) then
			P_TeleportMove(player.mo, player.combi.mo.x, player.combi.mo.y, player.combi.mo.z + 100*mapscale)
			player.mo.momx, player.mo.momy, player.mo.momz = 0, 0, 0
			player.mo.angle = player.combi.mo.angle
			--player.kartstuff[k_hyudorotimer] = max($, 2*TICRATE)
			
			if player.combi.kartstuff[k_respawn] > 1 then
				player.combi.mo.momx, player.combi.mo.momy, player.combi.mo.momz = 0, 0, 0
			end
			
			continue
		elseif player.combi.kartstuff[k_respawn] > 1 then
			continue
		end
		
		local distance = P_AproxDistance(P_AproxDistance(player.mo.x - player.combi.mo.x, player.mo.y - player.combi.mo.y), player.mo.z - player.combi.mo.z)
		
		if distance < MAX_DISTANCE then continue end
		distance = $-MAX_DISTANCE
		
		local angle = R_PointToAngle2(player.mo.x, player.mo.y, player.combi.mo.x, player.combi.mo.y)
		local v_angle = R_PointToAngle2(0, player.mo.z, R_PointToDist2(player.mo.x, player.mo.y, player.combi.mo.x, player.combi.mo.y), player.combi.mo.z)
		
		P_Thrust(player.mo, angle, FixedMul(FixedMul(cos(v_angle), yank_xy), distance))
		player.mo.momz = $+FixedMul(FixedMul(sin(v_angle), yank_z), distance)
		
		if player.combi.valid == "uwu" then
			P_Thrust(player.combi.mo, angle, -FixedMul(FixedMul(cos(v_angle), FRACUNIT-yank_xy), distance))
			player.combi.mo.momz = $-FixedMul(FixedMul(sin(v_angle), FRACUNIT-yank_z), distance)
		end
	end
end)

-- Make rankings display per pair instead of per individual?
addHook("ThinkFrame", do
	if not combi_on then return end

	local individual_rank = {}
	--print("---------------")
	for player in players.iterate do
		player.combi_rank = nil
		if not player.spectator then
			--print(player.real_rank)
			player.real_rank = $ or player.kartstuff[k_position]
			
			local spot = 1
			while individual_rank[spot] and individual_rank[spot].real_rank <= player.real_rank do
				spot = $+1
			end

			table.insert(individual_rank, spot, player)
		end
	end
	
	local rank = 1
	local team_rank = 0
	
	while individual_rank[rank] do
		local player = individual_rank[rank]
		player.real_rank = nil
		if player.combi and player.combi.valid and player.combi.combi_rank then
			player.combi_rank = player.combi.combi_rank
		else
			team_rank = $+1
			player.combi_rank = team_rank
		end
		
		if player.combi_rank ~= player.old_combi_rank then
			player.combi_rank_cooldown = 10
			player.old_combi_rank = player.combi_rank
		elseif player.combi_rank_cooldown > 0 then
			player.combi_rank_cooldown = $-1
		end
		
		-- This handles HUD display of the ranking, I think!
		player.kartstuff[k_position] = player.combi_rank
		player.kartstuff[k_positiondelay] = player.combi_rank_cooldown
		
		rank = $+1
	end
end)

-- Force rankings to be mostly-correct on player thinkers. This causes the distance-checking code for giving SPBs to work properly.
addHook("MobjThinker", do
	if not combi_on then return end
	
	--print("-----")
	for player in players.iterate do
		-- This "real_rank" juggling is necessary to make sure we don't break the team position display.
		if not player.real_rank then
			player.real_rank = player.kartstuff[k_position]
		end

		if player.combi_rank then
			player.kartstuff[k_position] = player.combi_rank
		end
	end
end, MT_PLAYER)

-- Shared camera for replays
addHook("ThinkFrame", do
	if not (combi_on and cv_combireplay.value == 1) then return end
	if leveltime < START_TIME then return end
	
	local skip = {}
	
	local mapscale = (mapheaderinfo[gamemap] and mapheaderinfo[gamemap].mobj_scale or FRACUNIT)
	for player in players.iterate do
		if not (player.combi and player.combi.valid and player.mo and player.mo.valid and player.combi.mo and player.combi.mo.valid) then continue end
		if skip[#player] then continue end
		skip[#player.combi] = true
		
		if not (player.combi_cam and player.combi_cam.valid) then
			player.combi_cam = P_SpawnMobj(player.mo.x, player.mo.y, player.mo.z, MT_GFZFLOWER1)
			player.combi_cam.flags = MF_NOGRAVITY|MF_NOCLIP|MF_NOCLIPHEIGHT|MF_NOTHINK
			player.combi_cam.flags2 = MF2_DONTDRAW
		end
		
		player.awayviewmobj = player.combi_cam
		player.combi.awayviewmobj = player.combi_cam
		player.awayviewtics = 2
		player.combi.awayviewtics = 2
		
		if player.exiting then continue end
		
		local x, y, z, angle
		x = player.mo.x + (player.combi.mo.x - player.mo.x)/2
		y = player.mo.y + (player.combi.mo.y - player.mo.y)/2
		z = player.mo.z + (player.combi.mo.z - player.mo.z)/2
		angle = player.mo.angle + (player.combi.mo.angle - player.mo.angle)/2
		
		local dist = BASE_DISTANCE * mapscale *3/4
		
		local targetX = x - FixedMul(cos(angle), dist)
		local targetY = y - FixedMul(sin(angle), dist)
		targetX = player.combi_cam.x + (targetX - player.combi_cam.x)/4
		targetY = player.combi_cam.y + (targetY - player.combi_cam.y)/4
		
		local camDist = R_PointToDist2(x, y, targetX, targetY)
		local multFact = FixedDiv(dist, camDist)
		targetX = x + FixedMul(targetX - x, multFact)
		targetY = y + FixedMul(targetY - y, multFact)
		
		P_TeleportMove(player.combi_cam,
			targetX,
			targetY,
			player.combi_cam.z + (z + 70*mapscale - player.combi_cam.z)/4
		)
		
		x = x+FixedMul(cos(angle), mapscale*100)
		y = y+FixedMul(sin(angle), mapscale*100)
		
		player.combi_cam.angle = R_PointToAngle2(targetX, targetY, x, y)
		player.awayviewaiming = R_PointToAngle2(0, player.combi_cam.z, dist, z + 70*mapscale)
		player.combi.awayviewaiming = player.awayviewaiming
	end
end)

-- HUD stuff
local patches
local ITEMX, ITEMY = 42, -3
local function DrawTeammateKartItem(teammate, v, itemX, itemY)
	if not patches then
		patches = {
			itembg = v.cachePatch("K_ISBG"),
			itembg2 = v.cachePatch("K_ISBGD"),
			itemtimer = v.cachePatch("K_ISIMER"),
			mulsticker = v.cachePatch("K_ISMUL"),
			sneaker = v.cachePatch("K_ISSHOE"),
			rocketsneaker = v.cachePatch("K_ISRSHE"),
			invincibility = {
				v.cachePatch("K_ISINV1"),
				v.cachePatch("K_ISINV2"),
				v.cachePatch("K_ISINV3"),
				v.cachePatch("K_ISINV4"),
				v.cachePatch("K_ISINV5"),
				v.cachePatch("K_ISINV6"),
			},
			banana = v.cachePatch("K_ISBANA"),
			eggman = v.cachePatch("K_ISEGGM"),
			orbinaut = v.cachePatch("K_ISORBN"),
			jawz = v.cachePatch("K_ISJAWZ"),
			mine = v.cachePatch("K_ISMINE"),
			ballhog = v.cachePatch("K_ISBHOG"),
			spb = v.cachePatch("K_ISSPB"),
			grow = v.cachePatch("K_ISGROW"),
			shrink = v.cachePatch("K_ISSHRK"),
			shield = v.cachePatch("K_ISTHNS"),
			ghost = v.cachePatch("K_ISHYUD"),
			pogo = v.cachePatch("K_ISPOGO"),
			sink = v.cachePatch("K_ISSINK"),
			sad = v.cachePatch("K_ISSAD"),
		}
	end
	
	local patch = nil
	local bg = patches.itembg
	local inv = patches.invincibility[(leveltime/3) % 6 + 1]
	-- @TODO splitscreen
	local numberdisplaymin = 2
	local itembar = 0
	
	if teammate.kartstuff[k_itemroulette] then
		patch = ({
			patches.sneaker,
			patches.banana,
			patches.orbinaut,
			patches.mine,
			patches.grow,
			patches.ghost,
			patches.rocketsneaker,
			patches.jawz,
			patches.spb,
			patches.shrink,
			inv,
			patches.eggman,
			patches.ballhog,
			patches.shield,
		})[(teammate.kartstuff[k_itemroulette]/3) % 13 + 1]
	elseif teammate.kartstuff[k_stolentimer] > 0 then
		patch = (leveltime & 2) and patches.ghost or nil
	elseif teammate.kartstuff[k_stealingtimer] > 0 and (leveltime & 2) then
		patch = patches.ghost
	elseif teammate.kartstuff[k_eggmanexplode] > 1 then
		patch = (leveltime & 1) and patches.eggman or nil
	elseif teammate.kartstuff[k_rocketsneakertimer] > 1 then
		itembar = teammate.kartstuff[k_rocketsneakertimer]
		patch = (leveltime & 1) and patches.rocketsneaker or nil
	elseif teammate.kartstuff[k_growshrinktimer] > 1 then
		patch = (leveltime & 1) and patches.grow or nil
	elseif teammate.kartstuff[k_sadtimer] > 0 then
		patch = (leveltime & 2) and patches.sad or nil
	elseif teammate.kartstuff[k_itemamount] == 0 then
		return
	elseif (not teammate.kartstuff[k_itemheld]) or (leveltime & 1) then
		patch = ({
			[KITEM_SNEAKER] = patches.sneaker,
			[KITEM_ROCKETSNEAKER] = patches.rocketsneaker,
			[KITEM_INVINCIBILITY] = inv,
			[KITEM_BANANA] = patches.banana,
			[KITEM_EGGMAN] = patches.eggman,
			[KITEM_ORBINAUT] = patches.orbinaut,
			[KITEM_JAWZ] = patches.jawz,
			[KITEM_MINE] = patches.mine,
			[KITEM_BALLHOG] = patches.ballhog,
			[KITEM_SPB] = patches.spb,
			[KITEM_GROW] = patches.grow,
			[KITEM_SHRINK] = patches.shrink,
			[KITEM_THUNDERSHIELD] = patches.shield,
			[KITEM_HYUDORO] = patches.ghost,
			[KITEM_POGOSPRING] = patches.pogo,
			[KITEM_KITCHENSINK] = patches.sink,
			[KITEM_SAD] = patches.sad,
		})[teammate.kartstuff[k_itemtype]]
		if patch == inv then
			bg = patches.itembg2
		end
	end
	
	local flags = V_HUDTRANS|V_SNAPTOTOP|V_SNAPTOLEFT
	
	v.draw(itemX, itemY, bg, flags)
	
	local colormap = nil
	if teammate.kartstuff[k_itemroulette] then
		colormap = v.getColormap(TC_RAINBOW, teammate.skincolor)
	elseif teammate.kartstuff[k_itemblink] and (leveltime & 1) then
		colormap = v.getColormap(TC_BLINK, ({
			[0] = SKINCOLOR_WHITE,
			SKINCOLOR_RED,
			1 + (leveltime % (MAXSKINCOLORS-1))
		})[teammate.kartstuff[k_itemblinkmode]])
	end
	
	if teammate.kartstuff[k_itemamount] >= numberdisplaymin and not teammate.kartstuff[k_itemroulette] then
		v.draw(itemX, itemY, patches.mulsticker, flags)
		if patch then
			v.draw(itemX, itemY, patch, flags, colormap)
		end
		v.drawString(itemX+24, itemY+31, "x" .. teammate.kartstuff[k_itemamount], V_ALLOWLOWERCASE|flags)
	elseif patch then
		v.draw(itemX, itemY, patch, flags, colormap)
	end
	
	if itembar then
		local itemtime = 8*TICRATE
		local barlength = 12
		local maxl = (itemtime*3) - barlength
		local fill = (itembar*barlength)/maxl
		local length = min(barlength, fill)
		local height = 1
		
		v.draw(itemX+17, itemY+27, patches.itemtimer, flags)
		v.drawFill(itemX+18, itemY+18, (length == 2 and 2 or 1), height, 12|flags)
		
		if length > 2 then
			v.drawFill(itemX+17+length, itemY+28, 1, height, 12|flags)
			v.drawFill(itemX+19, itemY+28, length-2, 1, 120|flags)
		end
	end
	
	-- draw the teammate's face too!
	if teammate.mo and teammate.mo.valid then
		v.draw(itemX+(itemX > 160 and 8 or 30), itemY+12, v.cachePatch(skins[teammate.mo.skin].facemmap), flags, v.getColormap(teammate.mo.skin, teammate.mo.color))
	end
end

local function drawHeart(v, x, y, flags)
		v.drawFill(x-160+153, y-1, 14, 6, 31|flags)
		v.drawFill(x-160+154, y-2, 12, 2, 31|flags)
		v.drawFill(x-160+154, y+5, 12, 1, 31|flags)
		v.drawFill(x-160+155, y+6, 10, 1, 31|flags)
		v.drawFill(x-160+156, y+7, 8, 1, 31|flags)
		v.drawFill(x-160+157, y+8, 6, 1, 31|flags)
		v.drawFill(x-160+158, y+9, 4, 1, 31|flags)

		v.drawFill(x-160+154, y, 12, 4, 128|flags)
		v.drawFill(x-160+155, y-1, 4, 1, 128|flags)
		v.drawFill(x-160+161, y-1, 4, 1, 128|flags)
		v.drawFill(x-160+155, y+4, 10, 1, 128|flags)
		v.drawFill(x-160+156, y+5, 8, 1, 128|flags)
		v.drawFill(x-160+157, y+6, 6, 1, 128|flags)
		v.drawFill(x-160+158, y+7, 4, 1, 128|flags)
		v.drawFill(x-160+159, y+8, 2, 1, 128|flags)
end

local splitCount, splitIndex = 1, 1
local splitLeveltime, splitViewed
hud.add(function(v, player)
	if not combi_on then return end
	if player.combi and player.combi.valid then
		if splitLeveltime == nil or splitLeveltime ~= leveltime or splitViewed[#player] then
			splitCount = splitIndex
			splitIndex = 1
			splitLeveltime = leveltime
			splitViewed = {[#player] = true}
		elseif not splitViewed[#player] then
			splitViewed[#player] = true
			splitIndex = ($%4)+1
		end
		
		local combiname = player.combi.name
		if player.combi.valid == "uwu" and (cv_combireplay.value or splitCount > 1) then
			combiname = "---"
		end
	
		-- @TODO splitscreen
		if splitCount == 1 then
			if cv_combireplay.value then
				v.drawString(160, 176, combiname, V_ALLOWLOWERCASE|(leveltime > START_TIME+TICRATE and V_HUDTRANSHALF or 0), "center")
			else
				local scroll = FixedMul(FixedDiv(combi_initscroll, 6*TICRATE), 10)
				local pos = min(max(leveltime - 100, 120), 160)
				local flags = V_SNAPTOBOTTOM | (leveltime > START_TIME+TICRATE and V_HUDTRANS or 0)
				
				if leveltime <= START_TIME then
					v.drawFill(0, pos - 3, 320, 14, 24|V_SNAPTOBOTTOM)
				end
				
				v.drawString(150, pos, player.name, V_ALLOWLOWERCASE|flags, "right")
				v.drawString(170, pos - scroll, combiname, V_ALLOWLOWERCASE|flags, "left")
				
				if player.old_combi and player.old_combi.valid and scroll > 0 then
					v.drawString(170, pos + 10 - scroll, player.old_combi.name, V_ALLOWLOWERCASE|flags, "left")
				end
				
				drawHeart(v, 160, pos, flags)
				
				if leveltime <= START_TIME then
					local color = min(leveltime & 31, 31 - (leveltime & 31)) + 160
					v.drawFill(0, pos - 9, 320, 6, color|V_SNAPTOBOTTOM)
					v.drawFill(0, pos + 11, 320, 6, color|V_SNAPTOBOTTOM)
				end
			end
		elseif splitCount == 2 then
			local pos
			local flags = V_SNAPTOTOP|V_SNAPTOLEFT| (leveltime > START_TIME+TICRATE and (cv_combireplay.value and V_HUDTRANSHALF or V_HUDTRANS) or 0)
			
			
			if cv_combireplay.value then
				pos = splitIndex == 1 and 15 or (v.height() / v.dupx() - 22)
			else
				pos = (splitIndex*2 - 1) * v.height() / v.dupx() / 4 + 12
				drawHeart(v, 10, pos, flags)
				v.drawString(20, pos-5, player.name, V_ALLOWLOWERCASE|flags, "left")
			end
			
			local shake = FixedDiv(combi_initscroll, 6*TICRATE)
			if shake > FRACUNIT/2 then
				pos = $+sin(shake<<16)*4/FRACUNIT
			end
			
			if cv_combireplay.value then
				v.drawString(v.width() / v.dupx() - 40, pos, combiname, V_ALLOWLOWERCASE|flags, "thin-right")
			else
				v.drawString(20, pos+5, combiname, V_ALLOWLOWERCASE|flags, "left")
			end
		else
			local x = ((splitIndex % 2) and 1 or 3) * v.width() / v.dupx() / 4
			local y = ((splitIndex-1)/2) * v.height() / v.dupx() / 2 + 4
			local flags = V_SNAPTOTOP|V_SNAPTOLEFT| (leveltime > START_TIME+TICRATE and (cv_combireplay.value and V_HUDTRANSHALF or V_HUDTRANS) or 0)

			if not cv_combireplay.value then
				drawHeart(v, x, y+2, flags)
			end
			
			local shake = FixedDiv(combi_initscroll, 6*TICRATE)
			if shake > FRACUNIT/2 then
				y = $+sin(shake<<16)*4/FRACUNIT
			end
			
			v.drawString(x - v.stringWidth(combiname, 0, "thin")/2, y, combiname, V_ALLOWLOWERCASE|flags, "thin")
		end
		
		if player.combi.valid ~= "uwu" and player.combi.valid ~= "maybe" then
			local x, y = ITEMX, ITEMY
			
			if (splitCount == 2 and splitIndex == 2) or splitIndex > 2 then
				y = $ + v.height() / v.dupx() / 2
			end
			
			if splitCount > 2 then
				x = (splitIndex & 1) and -9 or (v.width() / v.dupx() - 39)
				y = $ + 20
			end
		
			DrawTeammateKartItem(player.combi, v, x, y)
		end
		
		local turn_left, turn_right = v.cachePatch("MARRD0"), v.cachePatch("MARRA0")
		if player.turn_signal then
			local trans = abs(player.turn_signal / 5) % 3 + 2
			trans = $ << FF_TRANSSHIFT | V_SNAPTOTOP|V_SNAPTOLEFT
			
			local scale = FRACUNIT/8
			local basex = v.width() / v.dupx() / 2 * FRACUNIT
			local basey = v.height() / v.dupy() * FRACUNIT
			
			if splitCount > 1 then
				if splitIndex <= (splitCount+1) / 2 then
					basey = $/2
				end
				
				if splitCount > 2 then
					basex = $/2 * ((splitIndex & 1) and 1 or 3)
				end
			end
			
			if player.turn_signal < 0 then
				v.drawScaled(basex - 10*FRACUNIT, basey - 2*FRACUNIT, scale, turn_left, trans)
			elseif player.turn_signal > FRACUNIT then
				v.drawScaled(basex - 7*FRACUNIT, basey - 2*FRACUNIT, scale, turn_right, trans)
				v.drawScaled(basex + 7*FRACUNIT, basey - 2*FRACUNIT, scale, turn_left, trans)
			else
				v.drawScaled(basex + 10*FRACUNIT, basey - 2*FRACUNIT, scale, turn_right, trans)
			end
		end
		if player.combi.turn_signal then
			local trans = abs(player.combi.turn_signal / 5) % 3 + 6
			trans = $ << FF_TRANSSHIFT | V_SNAPTOTOP|V_SNAPTOLEFT
			
			local scale = FRACUNIT
			local basex = v.width() / v.dupx() / 2 * FRACUNIT
			local basey = v.height() / v.dupy() * FRACUNIT
			
			if splitCount > 1 then
				scale = $/2
				
				if splitIndex <= (splitCount+1) / 2 then
					basey = $/2
				end
				
				if splitCount > 2 then
					basex = $/2 * ((splitIndex & 1) and 1 or 3)
				end
			end
			
			local spanscale = splitCount == 2 and (scale*3/2) or scale
			
			if player.combi.turn_signal < 0 then
				v.drawScaled(basex - 80*spanscale, basey - 40*scale, scale, turn_left, trans)
			elseif player.combi.turn_signal > FRACUNIT then
				v.drawScaled(basex - 32*scale, basey - 104*scale, scale/2, turn_right, trans)
				v.drawScaled(basex + 32*scale, basey - 104*scale, scale/2, turn_left, trans)
			else
				v.drawScaled(basex + 80*spanscale, basey - 40*scale, scale, turn_right, trans)
			end
		end
	end
end)

-- Fix people getting stuck in the ALG sometimes
local function unstick(me, other)
	if not combi_on then return end
	if me.partnered and me.z < other.z+other.height and other.z < me.z+me.height then
		me.momz = $+FRACUNIT
	end
end
addHook("MobjCollide", unstick, MT_GARGOYLE)
addHook("MobjMoveCollide", unstick, MT_GARGOYLE)

-- Friend system!
local function PRINTF(p,m) CONS_Printf(p,m) end -- discard the third argument
COM_AddCommand("combi_friend", function(player, friend, in_chat)
	local printfunc = in_chat and chatprintf or PRINTF
	local color = in_chat and "\x84" or ""
	
	if not cv_combi.value then
		if not in_chat then
			printfunc(player, color .. "Combi isn't on right now.", false)
		end
		
		return
	end
	
	if not cv_combifriends.value then
		printfunc(player, color .. "The server has disabled combi friends. :(", false)
		
		return
	end

	if friend == "none" then
		if player.combi_pending_friend and players[player.combi_pending_friend-1].valid then
			chatprintf(players[player.combi_pending_friend-1], "\x84" .. player.name .. " is no longer your combi friend. :(", true)
		end
		
		player.combi_pending_friend = 0
		COM_BufInsertText(server, "storage__combi_friend_" .. #player .. " 0")
		printfunc(player, color .. "You no longer have a combi friend. :(", false)
		
		return
	end
	
	if friend == player.name then
		printfunc(player, color .. "You can't befriend yourself!", false)
		
		return
	end
	
	local friend_player
	for p in players.iterate do
		if p.name == friend then
			friend_player = p
			break
		end
	end

	if not friend_player then
		if not in_chat then
			CONS_Printf(player, "combi_friend \"<name>\": Pick someone to always be your combi partner! They must return the favor.")
		end
		
		return
	end
	
	player.combi_pending_friend = #friend_player+1
	COM_BufInsertText(server, "storage__combi_friend_" .. #player .. " " .. (#friend_player+1))
	
	local str = friend .. " will be your friend if they accept."
	if friend_player.combi_pending_friend and friend_player.combi_pending_friend-1 == #player then
		str = friend .. " will always be your combi partner."
	end
	
	printfunc(player, color .. str, false)

	str = player.name .. " wants to be combi friends. Say \"friend " .. player.name .. "\" to accept."
	if friend_player.combi_pending_friend and friend_player.combi_pending_friend-1 == #player then
		str = player.name .. " accepted your friend request, and will always be your combi partner."
	end

	chatprintf(friend_player, "\x84" .. str, true)
end)

addHook("PlayerMsg", function(player, msgtype, target, message)
	if message:sub(1, 7) == "friend " then
		COM_BufInsertText(player, "combi_friend \"" .. message:sub(8) .. "\" in_chat")
	end
end)