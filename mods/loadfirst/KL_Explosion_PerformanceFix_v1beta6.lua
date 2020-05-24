-- Author: Ashnal
-- Fixes the terrible performance of the 1.1 A_MineExplode
-- Rewrites it to not use the nights hoops style object spawning
-- Instead we mka e a new explosion object, and that object uses P_RadiusAttack every tic to Explode

local cv_debugprint = CV_RegisterVar({
    name = "explosion_debug",
    defaultvalue = "Off",
    flags = nil,
    PossibleValue = CV_OnOff
})

freeslot(
	"MT_NEWEXPLOSION",
	"S_NEWEXPLOSION_EXPLODE",
	"S_NEWEXPLOSION_SPINOUT"
)

mobjinfo[MT_NEWEXPLOSION] =
{
	spawnstate = S_NEWEXPLOSION_EXPLODE,
	spawnhealth = 1,
	painchance = 336*FRACUNIT, -- accounts for original code
	speed = 0,
	radius = 1*FRACUNIT, --dynamic
	height = 1*FRACUNIT, --dynamic
	flags = MF_NOGRAVITY|MF_DONTENCOREMAP|MF_NOBLOCKMAP,
}

states[S_NEWEXPLOSION_EXPLODE] =
{
	sprite = SPR_NULL,
	frame = 0,
	tics = 6,
	action = nil,
	var1 = 0,
	var2 = 0,
	nextstate = S_NEWEXPLOSION_SPINOUT
}

states[S_NEWEXPLOSION_SPINOUT] =
{
	sprite = SPR_NULL,
	frame = 0,
	tics = 22,
	action = nil,
	var1 = 0,
	var2 = 0,
	nextstate = S_NULL
}

local function DebugPrint(s)
	if cv_debugprint.value then
		print(s)
	end
end

local mapscale = (mapheaderinfo[gamemap] and mapheaderinfo[gamemap].mobj_scale or FRACUNIT)

local function SpawnMineExplosion(source, color)
	local smoldering = P_SpawnMobj(source.x, source.y, source.z, MT_SMOLDERING);
	K_MatchGenericExtraFlags(smoldering, source);

	smoldering.tics = TICRATE*3;
	local radius = source.radius>>FRACBITS;
	local height = source.height>>FRACBITS;

	if not color then
        color = SKINCOLOR_KETCHUP;
    end

	for i=0,15 do
		local dust = P_SpawnMobj(source.x, source.y, source.z, MT_SMOKE);
		dust.state = S_OPAQUESMOKE1;
		dust.angle = (ANGLE_180/16) * i;
		dust.scale = source.scale;
		dust.destscale = source.scale*10;
		dust.scalespeed = source.scale/12;
		P_InstaThrust(dust, dust.angle, FixedMul(20*FRACUNIT, source.scale));

		local truc = P_SpawnMobj(source.x + P_RandomRange(-radius, radius)*FRACUNIT,
			source.y + P_RandomRange(-radius, radius)*FRACUNIT,
			source.z + P_RandomRange(0, height)*FRACUNIT, MT_BOOMEXPLODE);
		K_MatchGenericExtraFlags(truc, source);
		truc.scale = source.scale;
		truc.destscale = source.scale*6;
		truc.scalespeed = source.scale/12;
		local speed = FixedMul(10*FRACUNIT, source.scale)>>FRACBITS;
		truc.momx = P_RandomRange(-speed, speed)*FRACUNIT;
		truc.momy = P_RandomRange(-speed, speed)*FRACUNIT;
		speed = FixedMul(20*FRACUNIT, source.scale)>>FRACBITS;
		truc.momz = P_RandomRange(-speed, speed)*FRACUNIT*P_MobjFlip(truc);
		if (truc.eflags & MFE_UNDERWATER) then
            truc.momz = (117 * truc.momz) / 200;
        end
		truc.color = color;
    end

	for i=0,7 do
		local dust = P_SpawnMobj(source.x + P_RandomRange(-radius, radius)*FRACUNIT,
			source.y + P_RandomRange(-radius, radius)*FRACUNIT,
			source.z + P_RandomRange(0, height)*FRACUNIT, MT_SMOKE);
		dust.state = S_OPAQUESMOKE1;
		dust.scale = source.scale;
		dust.destscale = source.scale*10;
		dust.scalespeed = source.scale/12;
		dust.tics = 30;
		dust.momz = P_RandomRange(FixedMul(3*FRACUNIT, source.scale)>>FRACBITS, FixedMul(7*FRACUNIT, source.scale)>>FRACBITS)*FRACUNIT;

		local truc = P_SpawnMobj(source.x + P_RandomRange(-radius, radius)*FRACUNIT,
			source.y + P_RandomRange(-radius, radius)*FRACUNIT,
			source.z + P_RandomRange(0, height)*FRACUNIT, MT_BOOMPARTICLE);
		K_MatchGenericExtraFlags(truc, source);
		truc.scale = source.scale;
		truc.destscale = source.scale*5;
		truc.scalespeed = source.scale/12;
		local speed = FixedMul(20*FRACUNIT, source.scale)>>FRACBITS;
		truc.momx = P_RandomRange(-speed, speed)*FRACUNIT;
		truc.momy = P_RandomRange(-speed, speed)*FRACUNIT;
		speed = FixedMul(15*FRACUNIT, source.scale)>>FRACBITS;
		local speed2 = FixedMul(45*FRACUNIT, source.scale)>>FRACBITS;
		truc.momz = P_RandomRange(speed, speed2)*FRACUNIT*P_MobjFlip(truc);
		if (P_RandomChance(FRACUNIT/2)) then
			truc.momz = -truc.momz;
		end
		if (truc.eflags & MFE_UNDERWATER) then
            truc.momz = (117 * truc.momz) / 200;
        end
		truc.tics = TICRATE*2;
		truc.color = color;
    end
end

function A_MineExplode(actor, var1, var2)
	local mo
	local zoffset

	if actor.flags2 & MF2_OBJECTFLIP then
		zoffset = -24*FRACUNIT
	else
		zoffset = 24*FRACUNIT
	end

	mo = P_SpawnMobj(actor.x, actor.y, actor.z + zoffset, MT_NEWEXPLOSION)
	mo.target = actor.target

	if (actor.type == MT_SPBEXPLOSION and actor.extravalue1 == 1) then
		DebugPrint("SPB called A_MineExplode")
		mo.extravalue1 = 1
	else
		DebugPrint("Non-spb called A_MineExplode")
	end
	mo.extravalue2 = actor.type -- lets use this to help out hitfeed
	mo.affectedplayers = {}

	local skincolor
	if actor.target and actor.target.player and actor.target.player.skincolor then
		skincolor = actor.target.player.skincolor
	else
		skincolor = SKINCOLOR_KETCHUP
	end
    K_SpawnMineExplosion(actor, skincolor)
    P_SpawnMobj(actor.x, actor.y, actor.z, MT_MINEEXPLOSIONSOUND)
end

local function checkSphereCollision(originMobj,radius,mobj)
	if (P_AproxDistance(P_AproxDistance(originMobj.x - mobj.x, originMobj.y - mobj.y), originMobj.z - mobj.z) <= FixedMul(radius, originMobj.scale)) then
		return true
	else
		return false
	end
end

local function ExplosionCollide(thing, tmthing)

	if (not thing.affectedplayers[tmthing]) then
		if (thing.state == S_NEWEXPLOSION_EXPLODE) then
			DebugPrint("ExplosionCollide with " .. tmthing.player.name)
			if (thing.extravalue1) then
				--print("MobjCollideHook SPB calling K_ExplodePlayer starting hacks")
				-- Warning extreme hacks. K_ExplodePlayer requires the thing type to be MT_SPBEXPLOSION, and the thinker for that automatically sets the deathstate in hardcode after 1 tic
				-- So we spawn a new MT_SPBEXPLOSION whose only function is to be passed to K_ExplodePlayer, then we remove it before the next tic can set it to deathstate
				local spbexplode = P_SpawnMobj(thing.x, thing.y, thing.z, MT_SPBEXPLOSION)
				spbexplode.state = S_INVISIBLE
				spbexplode.extravalue2 = 0  -- Tell the thinker to not remove it right away
				spbexplode.extravalue1 = 1  -- Tell K_ExplodePlayer to use extra knockback

				K_ExplodePlayer(tmthing.player, thing.target, spbexplode) -- ensure inflictor is MT_SPBEXPLOSION so K_ExplodePlayer applies extra effects
				P_RemoveMobj(spbexplode)
			else
				--print("MobjCollideHook calling K_ExplodePlayer normally")
				K_ExplodePlayer(tmthing.player, thing.target, thing);
			end
		else
			--print("MobjCollideHook calling K_SpinPlayer")
			K_SpinPlayer(tmthing.player, thing.target, 0, thing, false);
		end

		if hitfeed then
			if thing.extravalue2 == MT_SPBEXPLOSION then
				if thing.extravalue1 then
					HF_SendHitMessage(thing.target.player, tmthing.player, "K_HMSPB")
				else
					HF_SendHitMessage(thing.target.player, tmthing.player, "K_HMEGG")
				end
			else
				HF_SendHitMessage(thing.target.player, tmthing.player, "K_HMMNE")
			end
		end

        thing.affectedplayers[tmthing] = true -- Ensure any given explosion only affects each player once
    else
        DebugPrint("Explosion already affected " .. tmthing.player.name)
	end

	return false -- This doesn't collide with anything, but we want it to effect the player anyway.

end

addHook("MobjThinker", function(mo)
	P_RadiusAttack(mo, mo, mo.info.painchance)
end, MT_NEWEXPLOSION)

addHook("ShouldDamage", function(target, inflictor, source, damage)
	if inflictor then
		DebugPrint("ShouldDamage inflictor: " .. inflictor.type)
	else
		DebugPrint("ShouldDamage no inflictor")
	end
	if inflictor and inflictor.type == MT_NEWEXPLOSION then
		ExplosionCollide(inflictor, target)
		return false
    end
end, MT_PLAYER)