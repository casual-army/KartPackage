local function DropHnextList(player)
    local work,nextwork,dropwork,flip,type
    local dropall = true
    local orbit,ponground

	if not (player.mo and player.mo.hnext) then return end
    work = player.mo.hnext

    flip = P_MobjFlip(player.mo)
	ponground = P_IsObjectOnGround(player.mo)

	if (player.kartstuff[k_itemtype] == KITEM_THUNDERSHIELD and player.kartstuff[k_itemamount]) then
		K_DoThunderShield(player)
		player.kartstuff[k_itemamount] = 0
		player.kartstuff[k_itemtype] = KITEM_NONE
		player.kartstuff[k_curshield] = 0
	end

	while (work) do
		if (work.type == MT_ORBINAUT_SHIELD) then
            -- Kart orbit items
            orbit = true
            type = MT_ORBINAUT
        elseif (work.type == MT_JAWZ_SHIELD) then
            orbit = true;
            type = MT_JAWZ_DUD
        elseif (work.type == MT_BANANA_SHIELD) then
			-- Kart trailing items
            orbit = false
            type = MT_BANANA
		elseif (work.type == MT_SSMINE_SHIELD) then
            orbit = false
            dropall = false
            type = MT_SSMINE
        elseif (work.type == MT_EGGMANITEM_SHIELD) then
            orbit = false
            type = MT_EGGMANITEM
        else
            continue
		end

		dropwork = P_SpawnMobj(work.x, work.y, work.z, type)
		dropwork.target = player.mo
		dropwork.angle = work.angle
		dropwork.flags2 = work.flags2
        dropwork.flags = $ | MF_NOCLIPTHING

		--dropwork.floorz = work.floorz
		--dropwork.ceilingz = work.ceilingz

		if (ponground) then
			-- floorz and ceilingz aren't properly set to account for FOFs and Polyobjects on spawn
			-- This should set it for FOFs
			P_TeleportMove(dropwork, dropwork.x, dropwork.y, dropwork.z) -- handled better by above floorz/ceilingz passing
		end

		if (orbit) then -- splay out 
			dropwork.flags2 = $ | MF2_AMBUSH
			dropwork.z = $ + flip
			dropwork.momx = player.mo.momx>>1
			dropwork.momy = player.mo.momy>>1
			dropwork.momz = 3*flip*mapobjectscale
			if (dropwork.eflags & MFE_UNDERWATER) then
                dropwork.momz = (117 * dropwork.momz) / 200
            end
			P_Thrust(dropwork, work.angle - ANGLE_90, 6*mapobjectscale)
			dropwork.movecount = 2
			dropwork.movedir = work.angle - ANGLE_90
			dropwork.state = dropwork.info.deathstate
			dropwork.tics = -1
			if (type == MT_JAWZ_DUD) then
				dropwork.z = $ + 20*flip*dropwork.scale
			else
				dropwork.color = work.color
				dropwork.angle = $ - ANGLE_90
			end
		else -- plop on the ground
			dropwork.flags = $ & ~MF_NOCLIPTHING
			dropwork.threshold = 10
		end

        nextwork = work.hnext
        P_RemoveMobj(work)
        work = nextwork
	end


    -- we need this here too because this is done in afterthink - pointers are cleaned up at the START of each tic...
    -- player.mo.hnext.target = nil
    player.kartstuff[k_bananadrag] = 0

    if (player.kartstuff[k_eggmanheld]) then
        player.kartstuff[k_eggmanheld] = 0
    elseif (player.kartstuff[k_itemheld]) then
        player.kartstuff[k_itemamount] = $ - 1
        if (dropall or (player.kartstuff[k_itemamount] <= 0)) then
            player.kartstuff[k_itemamount] = 0
            player.kartstuff[k_itemheld] = 0
            player.kartstuff[k_itemtype] = KITEM_NONE
        end
    end

end

local function DropItems(player)

	local thunderhack = (player.kartstuff[k_curshield] and player.kartstuff[k_itemtype] == KITEM_THUNDERSHIELD)

	if (thunderhack) then
		player.kartstuff[k_itemtype] = KITEM_NONE
    end

	DropHnextList(player)

	if (player.mo and player.kartstuff[k_itemamount]) then
		local drop = P_SpawnMobj(player.mo.x, player.mo.y, player.mo.z + player.mo.height/2, MT_FLOATINGITEM)
		drop.scale = drop.scale>>4
		drop.destscale = (3*drop.destscale)/2

		drop.angle = player.mo.angle + ANGLE_90
		P_Thrust(drop,
			player.mo.angle + ANGLE_90*2,
            16*mapobjectscale)

		drop.momz = P_MobjFlip(player.mo)*3*mapobjectscale;
		if (drop.eflags & MFE_UNDERWATER) then
            drop.momz = (117 * drop.momz) / 200;
        end

        local threshold
        if thunderhack then
            threshold = KITEM_THUNDERSHIELD
        else
            threshold = player.kartstuff[k_itemtype]
        end

		drop.threshold = threshold
		drop.movecount = player.kartstuff[k_itemamount]

		drop.flags = $ | MF_NOCLIPTHING
    end

	K_StripItems(player)
end

local function Explode(player, inflictor, source)

	local scoremultiply = 1
	if (G_BattleGametype()) then
		if (K_IsPlayerWanted(player)) then
			scoremultiply = 3
		elseif (player.kartstuff[k_bumper] == 1)
			scoremultiply = 2
		end
	end

	if (source and source ~= player.mo and source.player) then
		K_PlayHitEmSound(source)
	end

	player.mo.momz = 18*mapobjectscale*P_MobjFlip(player.mo)	-- please stop forgetting mobjflip checks!!!!
    player.mo.momx = 0
    player.mo.momy = 0

	player.kartstuff[k_sneakertimer] = 0
	player.kartstuff[k_driftboost] = 0

	player.kartstuff[k_drift] = 0
	player.kartstuff[k_driftcharge] = 0
	player.kartstuff[k_pogospring] = 0

	-- This is the only part that SHOULDN'T combo :VVVVV
	if (G_BattleGametype() and not (player.powers[pw_flashing] > 0 or player.kartstuff[k_squishedtimer] > 0 or player.kartstuff[k_spinouttimer] > 0)) then

		if (source and source.player and player ~= source.player) then
			P_AddPlayerScore(source.player, scoremultiply)
			K_SpawnBattlePoints(source.player, player, scoremultiply)
			source.player.kartstuff[k_wanted] = $ - wantedreduce
			player.kartstuff[k_wanted] = $ - (wantedreduce/2);
		end

		if (player.kartstuff[k_bumper] > 0) then
			if (player.kartstuff[k_bumper] == 1) then
				local karmahitbox = P_SpawnMobj(player.mo.x, player.mo.y, player.mo.z, MT_KARMAHITBOX) -- Player hitbox is too small!!
				karmahitbox.target = player.mo
				karmahitbox.destscale = player.mo.scale
				karmahitbox.scale = player.mo.scale
				CONS_Printf(player_names[player] .. " lost all of their bumpers!")
			end
			player.kartstuff[k_bumper] = $ - 1
			if (K_IsPlayerWanted(player)) then
				K_CalculateBattleWanted()
			end
		end

		if ( not player.kartstuff[k_bumper]) then

			player.kartstuff[k_comebacktimer] = comebacktime
			if (player.kartstuff[k_comebackmode] == 2) then
				local poof = P_SpawnMobj(player.mo.x, player.mo.y, player.mo.z, MT_EXPLODE)
				S_StartSound(poof, mobjinfo[MT_KARMAHITBOX].seesound)
				player.kartstuff[k_comebackmode] = 0
            end

		end

		K_CheckBumpers()
	end

	player.kartstuff[k_spinouttype] = 1
	player.kartstuff[k_spinouttimer] = (3*TICRATE/2)+2

	player.powers[pw_flashing] = K_GetKartFlashing(player)

	if (inflictor and inflictor.type == MT_SPBEXPLOSION and inflictor.extravalue1) then
		player.kartstuff[k_spinouttimer] = ((5*player.kartstuff[k_spinouttimer])/2)+1
		player.mo.momz = $ * 2
	end

	if (player.mo.eflags & MFE_UNDERWATER) then
		player.mo.momz = (117 * player.mo.momz) / 200
	end

	if (player.mo.state ~= S_KART_SPIN) then
		player.mo.state = S_KART_SPIN
	end

	P_PlayRinglossSound(player.mo)

	if (player == displayplayers[0]) then
		P_StartQuake(64<<FRACBITS, 5)
	end

	player.kartstuff[k_instashield] = 15
	DropItems(player)

	return false

end

addHook("PlayerExplode", Explode)