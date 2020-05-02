-- Haste, by Tyron
-- Makes accel characters marginally happier.

local haste = CV_RegisterVar({
	name = "haste",
	defaultvalue = "130",
	flags = CV_NETVAR,
	possiblevalue = CV_Unsigned
})
local haste_debug = CV_RegisterVar({
	name = "haste_debug",
	defaultvalue = "Off",
	flags = 0,
	possiblevalue = CV_OnOff
})

local version = "5"

-- Remember, kids, do your expensive string operations only after you've verified the string is actually displayed
local function dprint(p, ...)
	if not haste_debug.value then return end
	CONS_Printf(p, "Haste: "..table.concat({...}, " "))
end

addHook("ThinkFrame", function()
    for p in players.iterate
        if p.spectator then continue end
        if p.NAlastdriftboost == nil then continue end -- Need to initialize "last tic" vars to avoid nil shenanigans.
        if not p.NAwarned then
            p.NAwarned = true
            chatprintf(p, "\141*Server running \130Haste V"..version.."\141. Lower speed stat = longer miniturbos.")
        end
        -- Lawnmowering is already effective enough in a few edge cases, let's not let Omega get away with murder.
        -- This only activates if you spend too long offroad; no need to punish grazes on MKSC Sky Garden or something.
        if p.kartstuff[k_offroad] >= (FRACUNIT / 2) and p.kartstuff[k_driftboost] and p.NAlastadjust
            local mowdrop = max(p.kartstuff[k_driftboost] - p.NAlastadjust, 0)
            dprint(p, "Deducting", p.NAlastadjust, "for offroad penalty! Was", p.kartstuff[k_driftboost], "F, is", mowdrop, "F")
            p.kartstuff[k_driftboost] = mowdrop
            p.NAlastadjust = 0
        end
        -- This is a sort of roundabout way of detecting drifts, but we can't rely on adjustments to k_driftboost alone...
        -- If we're a 1 speed character, a blue MT should boost us from 20F to 26F by default.
        -- However, if we chain a red into a blue with 23F left on the timer, the game will ignore it!
        -- This is because the base value of a blue MT, 20F, is less than the value we currently have...
        -- ...so in the base game, applying that MT would actually slow us down, even though Haste would boost it up again!
        if p.NAlastdriftcharge > p.kartstuff[k_driftcharge] then
            -- Our goal is to detect an MT one frame after it's happened, then retroactively apply the bonus time.
            local accel = 9 - p.kartspeed
            local target = (26*4 + p.kartspeed*2 + (9 - p.kartweight))*8 -- Taken from source.
            local LDC = p.NAlastdriftcharge
            local fakecharge = 20 -- Taken from source.
            local fakename = "blue"
            -- This is a bunch of redundant safety conditions because I'm kinda paranoid.
            -- At least the most common ones are at the top.
            if p.NAlastbounced then
                dprint(p, "No adjustment: wallbonk")
                continue
            elseif p.kartstuff[k_driftboost] < 19 then
                dprint(p, "No adjustment: no existing MT timer")
                continue
            elseif p.speed <= 10*FRACUNIT then
                dprint(p, "No adjustment: you're too slow")
                continue
            elseif p.kartstuff[k_spinouttimer] then
                dprint(p, "No adjustment: you're spun out")
                continue
            elseif p.kartstuff[k_squishedtimer] then
                dprint(p, "No adjustment: you're squished")
                continue
            elseif LDC < target then
                dprint(p, "No adjustment: didn't charge enough")
                continue
            elseif p.NAlastbuttons then
                dprint(p, "No adjustment: Drift not released")
                continue
            elseif LDC >= target*4 then -- Rainbow and red MT values taken from source.
                fakecharge = 125
                fakename = "rainbow"
                -- fallthrough
            elseif LDC >= target*2 then
                fakecharge = 50
                fakename = "red"
                -- fallthrough
            end
            -- Figure out how strong we're proportionally boosting MTs.
            local bonusfactor = FixedDiv((haste.value - 100)*FRACUNIT, 100*FRACUNIT)
            -- Figure out how much of that bonus a character is eligible for, based on their stats.
            -- 1 speed gets full bonus: 9 speed gets none! (In practice, 7+ speed gets 0F bonuses.)
            local diefactor = FRACUNIT + FixedMul(FixedDiv(bonusfactor, FRACUNIT*8), accel*FRACUNIT)
            -- Calculate the length of the target type of MT with bonus applied...
            -- ...minus 1 for the frame it's already been going.
            local holding = FixedInt(FixedMul(fakecharge*FRACUNIT, diefactor)) - 1
            -- Fixed point math is terrible.
            dprint(p, "Correcting", fakename.." MT to", holding, "F, would be", p.kartstuff[k_driftboost], "F (scaled by", diefactor, ")")
            p.NAlastadjust = holding - p.kartstuff[k_driftboost]
            p.kartstuff[k_driftboost] = max(holding, $)
        end
    end
    -- Since we're working with old state, we need to have copies of these variables from the last tic.
    for p in players.iterate
        if p.spectator then continue end
        p.NAlastdriftboost = p.kartstuff[k_driftboost]
        p.NAlastdriftcharge = p.kartstuff[k_driftcharge]
        p.NAlastdrift = p.kartstuff[k_drift]
        p.NAlastbuttons = p.cmd.buttons & BT_DRIFT
        p.NAlastbounced = p.mo.eflags & MFE_JUSTBOUNCEDWALL
        p.NAlastadjust = $ or 0
    end
end)