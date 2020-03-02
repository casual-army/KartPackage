-- Author: Ashnal
-- Adds slipstreaming aka drafting like the later Mario Kart games
-- Youll see small gray speed lines when you're charging a slipstream boost
-- Theres a subtle woosh sound when it activates, and the gray speed lines will become normal size and more frequent
-- You need to have another racer within the maxangle of your heading, and be within the maxdistiance range to charge it
-- the closer you are to them, the faster it will charge
-- KNOWN BUG: the fast lines have some wierd angles on OpenGL rendering. No idea why.

local cv_slipstream = CV_RegisterVar({
    name = "slipstream_enabled",
    defaultvalue = "On",
    flags = CV_NETVAR,
    PossibleValue = CV_OnOff
})

local cv_reminder = CV_RegisterVar({
    name = "slipstream_reminder",
    defaultvalue = "On",
    flags = NULL,
    PossibleValue = CV_OnOff
})

local cv_maxdistance = CV_RegisterVar({
    name = "slipstream_maxdistance",
    defaultvalue = 1400, -- enough room to charge slowly, and dodge
    flags = CV_NETVAR,
    PossibleValue = CV_Unsigned
})

local cv_t2chargedist = CV_RegisterVar({
    name = "slipstream_t2chargedist",
    defaultvalue = 1050,
    flags = CV_NETVAR,
    PossibleValue = CV_Unsigned
})

local cv_t3chargedist = CV_RegisterVar({
    name = "slipstream_t3chargedist",
    defaultvalue = 300, -- danger close, woudln't be able to dodge an aimed item
    flags = CV_NETVAR,
    PossibleValue = CV_Unsigned
})

local cv_maxangle = CV_RegisterVar({
    name = "slipstream_maxangle",
    defaultvalue = ANG15,
    flags = CV_NETVAR,
    PossibleValue = CV_Unsigned
})

local cv_chargetoboost = CV_RegisterVar({
    name = "slipstream_chargetoboost",
    defaultvalue = 4*TICRATE,
    flags = CV_NETVAR,
    PossibleValue = CV_Unsigned
})

local cv_minimumspeed = CV_RegisterVar({
    name = "slipstream_minimumspeed",
    defaultvalue = 28,
    flags = CV_NETVAR,
    PossibleValue = CV_Unsigned
})

local cv_speedboost = CV_RegisterVar({
    name = "slipstream_speedboost",
    defaultvalue = FRACUNIT/2, -- 50%
    flags = CV_NETVAR,
    PossibleValue = CV_Unsigned
})

local cv_accelboost = CV_RegisterVar({
    name = "slipstream_accelboost",
    defaultvalue = FRACUNIT/10, -- 10%
    flags = CV_NETVAR,
    PossibleValue = CV_Unsigned
})

local soundcooldown = 3*TICRATE
local starttime = 6*TICRATE + (3*TICRATE/4)

local angletotarget = nil
local disttotarget = nil
local slipstreamtarget = nil
local charge = 0
local speedboost = 0
local accelboost = 0
local tier = 0


local function SpawnFastLines(p, tier, color)
    if p.fastlinestimer == 1 or tier == 1 then
        local fast = P_SpawnMobj(p.mo.x + (P_RandomRange(-36,36) * p.mo.scale),
            p.mo.y + (P_RandomRange(-36,36) * p.mo.scale),
            p.mo.z + (p.mo.height/2) + (P_RandomRange(-20,20) * p.mo.scale),
            MT_FASTLINE)
        fast.angle = R_PointToAngle2(0, 0, p.mo.momx, p.mo.momy)
        fast.momx = 3*p.mo.momx/4
        fast.momy = 3*p.mo.momy/4
        fast.momz = 3*p.mo.momz/4
        fast.color = color
        fast.colorized = true
        K_MatchGenericExtraFlags(fast, p.mo)

        fast.scale = $/tier
        p.fastlinestimer = tier
    end
    p.fastlinestimer = max($-1, 1)
end

addHook("ThinkFrame", do

    if not cv_slipstream.value then return end -- Has to be turned on

    local mapscale = (mapheaderinfo[gamemap] and mapheaderinfo[gamemap].mobj_scale or FRACUNIT)
    local T3_DISTANCE = cv_t3chargedist.value * mapscale
    local T2_DISTANCE = cv_t2chargedist.value * mapscale
    local MAX_DISTANCE = cv_maxdistance.value * mapscale

    for p in players.iterate do

        if(leveltime == 3*TICRATE and cv_reminder.value) then 
            chatprintf(p, "\131* Don't forget you can \130draft\131 behind another player to charge a \130slipstream speed boost!", true)
        end

        if p.mo then  -- must have valid player mapobject

            if p.kartstuff[k_spinouttimer] and p.kartstuff[k_wipeoutslow] == 1 then -- no slipstreaming if you've bumped or spun out
                p.slipstreamboost = 0
                p.slipstreamcharge = 0
            else

                if p.slipstreamcharge == nil then
                    p.slipstreamcharge = 0
                    p.slipstreamboost = 0
                    p.fastlinestimer = 0
                    p.slipstreamsoundtimer = 0
                end

                -- reset until we find a valid slipstreamtarget this frame
                slipstreamtarget = nil
                angletotarget = nil
                disttotarget = nil
                charge = 0
                speedboost = p.kartstuff[k_speedboost]
                accelboost = p.kartstuff[k_accelboost]

                if (P_IsObjectOnGround(p.mo)
                and not p.kartstuff[k_drift]
                -- and FixedDiv(p.speed, mapobjectscale)/FRACUNIT >= cv_minimumspeed.value -- must be moving decently on the ground, not drifting
                ) then
                    for potentialtarget in players.iterate do                      
                        if (potentialtarget.mo -- must have valid player mapobject
                        and potentialtarget.mo ~= p.mo -- Can't splipstream off yourself
                        and not potentialtarget.kartstuff[k_hyudorotimer] -- or ghosts
                        and P_IsObjectOnGround(potentialtarget.mo) -- or airbourne karts
                        -- and FixedDiv(potentialtarget.speed, mapobjectscale)/FRACUNIT >= cv_minimumspeed.value) -- or slowpokes
                        ) then 

                            angletotarget = abs(p.mo.angle - R_PointToAngle2(p.mo.x, p.mo.y, potentialtarget.mo.x, potentialtarget.mo.y))
                            if angletotarget > cv_maxangle.value then continue end -- Narrow angle for following to slipstream
                            disttotarget = P_AproxDistance(p.mo.x - potentialtarget.mo.x, p.mo.y - potentialtarget.mo.y)
                            if disttotarget > MAX_DISTANCE then continue end -- max slipstream distance

                            --  print(p.mo.skin + " " + potentialtarget.mo.skin + " angletotarget: " + angletotarget + " disttotarget: " + disttotarget + " slipstreamtarget: " + p.slipstreamtarget)

                            slipstreamtarget = potentialtarget
                            break

                        end
                    end
                end

                -- add/remove slipstream charge
                if slipstreamtarget then

                    if disttotarget > T2_DISTANCE then
                        charge = 1
                    elseif disttotarget > T3_DISTANCE then
                        charge = 2
                    else
                        charge = 3
                    end

                    p.slipstreamcharge = min($+charge, cv_chargetoboost.value)
                    print(p.mo.skin + " " +slipstreamtarget.mo.skin + " angletotarget: " + angletotarget + " disttotarget: " + disttotarget + " charging slipstream: " + p.slipstreamcharge)

                    -- also spawn mini lines if charging to teach/show player the charging area
                    if p.slipstreamboost == 0 then
                        SpawnFastLines(p, 2, SKINCOLOR_WHITE)
                    end

                else
                    if p.slipstreamcharge then print(p.mo.skin + " losing  slipstream " + p.slipstreamcharge) end
                    p.slipstreamcharge = max($-1, 0)
                end

                if p.slipstreamcharge >= cv_chargetoboost.value then
                    print(p.mo.skin + " slipstreaming!")
                    p.slipstreamboost = 50

                    if p.slipstreamsoundtimer == 0 then
                        S_StartSoundAtVolume(p.mo, sfx_s3k82, INT32_MAX)
                        p.slipstreamsoundtimer = soundcooldown
                    end
                end

                if p.slipstreamboost then
                    -- same as miniturbo
                    speedboost = max(speedboost, cv_speedboost.value)
                    accelboost = max(accelboost, cv_accelboost.value)

                    SpawnFastLines(p, 1, p.skincolor)
					if leveltime % 3 then
						p.mo.colorized = true
					else
						p.mo.colorized = false
					end 
                end

                -- value smoothing
                if (speedboost > p.kartstuff[k_speedboost]) then
                    p.kartstuff[k_speedboost] = speedboost
                else
                    p.kartstuff[k_speedboost] = p.kartstuff[k_speedboost] + (speedboost - p.kartstuff[k_speedboost])/(TICRATE/2)
                end

                p.kartstuff[k_accelboost] = accelboost

                -- if p.slipstreamboost then print(p.mo.skin + " slipstreamboost: " + p.slipstreamboost) end
                p.slipstreamboost = max($-1, 0)
                p.slipstreamsoundtimer = max($-1, 0)
            end
        end
    end
end)