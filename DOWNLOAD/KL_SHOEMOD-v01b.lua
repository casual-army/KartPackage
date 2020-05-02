--SHOEMOD by yoshimo

--v0.01b: fixed rocket sneakers not applying

local COMMAND_PREFIX = "sm_"
local START_TIME = 27 * TICRATE / 4 --6.75 seconds

local cv_boostmult = {defValue = "3.0", value = 3 << FRACBITS}
local function updateBoostMultSync()
    if server then
        server.cv_boostmult = cv_boostmult.value
    end
end
cv_boostmult = CV_RegisterVar({
    COMMAND_PREFIX .. "boostmult",
    cv_boostmult.defValue,
    CV_NETVAR|CV_FLOAT|CV_CALL,
    {MIN = 0, MAX = INT32_MAX},
    updateBoostMultSync
})

local cv_timemult = {defValue = "0.5", value = FRACUNIT >> 1}
local function updateTimeMultSync()
    server.cv_timemult = cv_timemult.value
end
local function updateTimeMultData()
    if server then
        for player in players.iterate do
            if player.sneakeritemtimer then
                player.sneakeritemtimer = max(
                    $ - FixedMul(
                            player.startsneakeritemtime << FRACBITS,
                            server.cv_timemult
                        ) >> FRACBITS
                        + FixedMul(
                            player.startsneakeritemtime << FRACBITS,
                            cv_timemult.value
                        ) >> FRACBITS,
                    0
                )
                player.kartstuff[k_sneakertimer] = max(max(
                    player.sneakeritemtimer,
                    player.sneakerpaneltimer or 0),
                    player.perfectboosttimer or 0
                )
            end
        end
        updateTimeMultSync()
    end
end
cv_timemult = CV_RegisterVar({
    COMMAND_PREFIX .. "timemult",
    cv_timemult.defValue,
    CV_NETVAR|CV_FLOAT|CV_CALL,
    {MIN = 0, MAX = INT32_MAX},
    updateTimeMultData
})

local function updateCVarSync()
    updateBoostMultSync()
    updateTimeMultSync()
end

local function updateSneakerBoost(player)
    if player.kartstuff[k_sneakertimer] == 0 then
        player.sneakeritemtimer = 0
        player.sneakerpaneltimer = 0
        player.perfectboosttimer = 0
    end
    
    --Sneaker item
    --they didn't simply lose them, did they?
    if not player.attackheld and player.pflags & PF_ATTACKDOWN and (
            player.heldsneakers
                and (
                    player.kartstuff[k_itemtype] != KITEM_SNEAKER
                    or player.kartstuff[k_itemamount] < player.heldsneakers
                )
            or player.hadrocketsneakersactive
                and player.kartstuff[k_rocketsneakertimer] < player.hadrocketsneakersactive - 1
        )
    then
        player.startsneakeritemtime = FixedMul(
            player.kartstuff[k_sneakertimer] << FRACBITS,
            server.cv_timemult
        ) >> FRACBITS
        player.sneakeritemtimer = player.startsneakeritemtime
    elseif player.sneakeritemtimer then
        player.sneakeritemtimer = max($ - 1, 0)
    end
    
    --Sneaker Panel
    if P_PlayerTouchingSectorSpecial(player, 4, 6) then
        player.sneakerpaneltimer = player.kartstuff[k_sneakertimer]
    elseif player.sneakerpaneltimer then
        player.sneakerpaneltimer = max($ - 1, 0)
    end
    
    --Perfect Boost
    if player.gotperfect then
        player.perfectboosttimer =  player.kartstuff[k_sneakertimer]
        --got what we want; lock it up
        player.gotperfect = false
    elseif player.perfectboosttimer then
        player.perfectboosttimer = max($ - 1, 0)
    end
    --k_boostcharge can only be non-zero at before match start, so we don't need to check leveltime
    if player.kartstuff[k_boostcharge] == 35 or player.kartstuff[k_boostcharge] == 36 then
        --the player's about to get a perfect boost. flag to check on next frame
        player.gotperfect = true
    end
end

local function updateLatentFrameVars(player)
    --update previous held item check
    if player.kartstuff[k_itemtype] != KITEM_SNEAKER then
        player.heldsneakers = 0
    else
        player.heldsneakers = player.kartstuff[k_itemamount]
    end
    
    if player.kartstuff[k_rocketsneakertimer] <= 0 then
        player.hadrocketsneakersactive = 0
    else
        player.hadrocketsneakersactive = player.kartstuff[k_rocketsneakertimer]
    end
    
    --update attack held check
    player.attackheld = player.pflags & PF_ATTACKDOWN
end

local function adjustSneakerBoost(player)
    --borrowed from k_kart.c:1809
    local sneakerboosts = {[0] = 53740+768, 32768, 17294+768}
    
    local otherBaseBoost = 0
    
    --don't overwrite stronger boosts (borrowed from k_kart.c:1824)
    if player.sneakerpaneltimer or player.perfectboosttimer then
        otherBaseBoost = sneakerboosts[gamespeed]
    end
    if player.kartstuff[k_invincibilitytimer] then
        otherBaseBoost = max($, 3 << FRACBITS >> 3)
    elseif player.kartstuff[k_driftboost] or player.kartstuff[k_startboost] then
        otherBaseBoost = max($, FRACUNIT >> 2)
    elseif player.kartstuff[k_growshrinktimer] > 0 then
        otherBaseBoost = max($, FRACUNIT / 5)
    end
    
    player.kartstuff[k_speedboost] = max(
        otherBaseBoost,
        FixedMul(sneakerboosts[gamespeed], server.cv_boostmult)
    )
    player.kartstuff[k_sneakertimer] = max(max(
        player.sneakeritemtimer,
        player.sneakerpaneltimer or 0),
        player.perfectboosttimer or 0
    )
end

local function onThinkFrame()
    --i don't think sneaker panels activate before match start?
    if leveltime > START_TIME then
        for player in players.iterate do
            if player.valid and player.mo and player.mo.valid then
                updateSneakerBoost(player)
                updateLatentFrameVars(player)
                if player.sneakeritemtimer then
                    adjustSneakerBoost(player)
                end
            end
        end
    end
end

addHook("MapLoad", updateCVarSync)
addHook("ThinkFrame", onThinkFrame)