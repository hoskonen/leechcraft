-- ================================
-- File: Scripts/DynamicBandages/DynamicBandages.lua
-- ================================

DynamicBandages = DynamicBandages or {}

-- --------------------------------
-- Config (defaults) — overridden by DynamicBandagesConfig.lua if present
-- --------------------------------
DynamicBandages.config = {
    debugLogs        = true,
    enableSleepHook  = true, -- master switch for SkipTime-based updates
    requireRealSleep = true, -- gate on actual exhaust gain
    minExhaustGain   = 3,    -- minimum exhaust delta to count as sleep
    wakeDebounceMs   = 1200, -- avoid duplicate OnHide bursts
}

-- --------------------------------
-- Runtime state
-- --------------------------------
DynamicBandages._sleepSession = { startExhaust = nil }
DynamicBandages._skipListenerRegistered = false
DynamicBandages._wakeGuard = { lastRunMs = 0 }

-- --------------------------------
-- Utilities
-- --------------------------------
local function Log(msg)
    if DynamicBandages.config and DynamicBandages.config.debugLogs then
        System.LogAlways("[DynamicBandages] " .. tostring(msg))
    end
end

local function Info(msg)
    System.LogAlways("[DynamicBandages] " .. tostring(msg))
end

local function nowMillis()
    if System.GetCurrTime then
        local ok, t = pcall(System.GetCurrTime)
        if ok and type(t) == "number" then return math.floor(t * 1000) end
    end
    if System.GetFrameID then
        local ok, f = pcall(System.GetFrameID)
        if ok and type(f) == "number" then return f * 16 end
    end
    return 0
end

local function shouldRunOnce()
    local t = nowMillis()
    local last = DynamicBandages._wakeGuard.lastRunMs or 0
    if (t - last) < (DynamicBandages.config.wakeDebounceMs or 1200) then
        return false
    end
    DynamicBandages._wakeGuard.lastRunMs = t
    return true
end

local function getPlayer()
    return System.GetEntityByName("Henry") or System.GetEntityByName("dude")
end

-- Exhaust is a STATE (0..100), not the stat. Keep using soul:GetState("exhaust")
local function getExhaust(player)
    local soul = player and player.soul
    if soul and soul.GetState then
        local ok, val = pcall(function() return soul:GetState("exhaust") end)
        if ok and type(val) == "number" then return val end
    end
    return nil
end

-- --------------------------------
-- Config override (safe load)
-- --------------------------------
local ok, err = pcall(function()
    Script.ReloadScript("Scripts/DynamicBandages/DynamicBandagesConfig.lua")
end)

if not ok then
    Info("⚠ Failed to load DynamicBandagesConfig.lua: " .. tostring(err))
elseif DynamicBandages_Config then
    for k, v in pairs(DynamicBandages_Config) do
        DynamicBandages.config[k] = v
    end
    Info("Loaded config from DynamicBandagesConfig.lua")
else
    Info("DynamicBandagesConfig.lua not found or missing DynamicBandages_Config — using defaults")
end

function DynamicBandages.DumpConfig()
    Log("Active config:")
    for k, v in pairs(DynamicBandages.config) do
        Log(string.format("  %s = %s", k, tostring(v)))
    end
end

-- --------------------------------
-- Public: called when SkipTime finishes (after confirmed sleep)
-- --------------------------------
function DynamicBandages.ApplyOnWake()
    -- ⚠ Placeholder: this is where we’ll compute Scholarship → pick buff tier → apply buff
    -- Keep minimal logging so we can verify the hook without gameplay side-effects.
    Log("ApplyOnWake(): stub — ready to plug Scholarship → bandage-buff logic")
end

-- --------------------------------
-- SkipTime / sleep UI bridge
-- --------------------------------
function DynamicBandages:onSkipTimeEvent(elementName, instanceId, eventName, args)
    if not DynamicBandages.config.enableSleepHook then return end

    if eventName == "OnSetFaderState" and args and args[1] == "sleep" then
        Log("Sleep start detected (OnSetFaderState: sleep)")
        if DynamicBandages.config.requireRealSleep then
            local p = getPlayer()
            DynamicBandages._sleepSession.startExhaust = getExhaust(p)
            Log("Captured start exhaust: " .. tostring(DynamicBandages._sleepSession.startExhaust))
        end
        return
    end

    if eventName == "OnHide" then
        if not shouldRunOnce() then
            Log("Debounced duplicate wake trigger")
            return
        end

        local okToRun = true
        if DynamicBandages.config.requireRealSleep then
            local p        = getPlayer()
            local startExh = DynamicBandages._sleepSession.startExhaust
            local endExh   = getExhaust(p)
            local gain     = 0

            if type(startExh) == "number" and type(endExh) == "number" then
                gain = endExh - startExh
                if gain < 0 then gain = 0 end
            else
                okToRun = false
            end

            if okToRun then
                okToRun = gain >= (DynamicBandages.config.minExhaustGain or 3)
            end

            Log(string.format("Sleep gain check: start=%s end=%s Δ=%.1f → %s",
                tostring(startExh), tostring(endExh), gain, okToRun and "ALLOW" or "BLOCK"))

            -- reset session either way
            DynamicBandages._sleepSession.startExhaust = nil
        end

        if not okToRun then
            Log("Sleep canceled/too short — skipping ApplyOnWake")
            return
        end

        -- Small delay lets stats settle after SkipTime fade-out
        Script.SetTimer(500, function()
            DynamicBandages.ApplyOnWake()
        end)
    end
end

-- --------------------------------
-- Initialize once per session
-- --------------------------------
function DynamicBandages.Initialize(fullInit)
    if fullInit and DynamicBandages._initialized then
        return
    end
    if fullInit then
        DynamicBandages._initialized = true
        DynamicBandages.DumpConfig()
    end

    if DynamicBandages.config.enableSleepHook and not DynamicBandages._skipListenerRegistered then
        if UIAction and UIAction.RegisterElementListener then
            UIAction.RegisterElementListener(DynamicBandages, "SkipTime", -1, "", "onSkipTimeEvent")
            DynamicBandages._skipListenerRegistered = true
            Log("Registered SkipTime listener (sleep/wake)")
        else
            Info("⚠ UIAction.RegisterElementListener not available — sleep hook inactive")
        end
    end
end
