DynamicBandages = DynamicBandages or {}

--Minimal config
DynamicBandages.config = DynamicBandages.config or {
    debugLogs       = true,
    enableSleepHook = true,
    enableBuffs     = false,
    scholarKey      = "scholarship", -- single source of truth
    applyOnStart    = true,          -- ⬅ run once at game start
    startRetries    = 3,             -- ⬅ try a few times (soul might not be ready)
    startRetryMs    = 500,           -- ⬅ delay between retries
}

-- Scholarship → FAE tier mapping (names must match your DB)
local DB_TIERS = {
    { min = 1,  max = 5,  buff = "scholarship_bandaging_1" },
    { min = 6,  max = 11, buff = "scholarship_bandaging_2" },
    { min = 12, max = 17, buff = "scholarship_bandaging_3" },
    { min = 18, max = 23, buff = "scholarship_bandaging_4" },
    { min = 24, max = 30, buff = "scholarship_bandaging_5" },
}

local function ApplyOnceWithRetry(triesLeft)
    triesLeft = triesLeft or (DynamicBandages.config.startRetries or 0)
    local ok = pcall(DynamicBandages.ApplyOnWake)
    if ok then return end
    if triesLeft <= 0 then return end
    Script.SetTimer(DynamicBandages.config.startRetryMs or 500, function()
        ApplyOnceWithRetry(triesLeft - 1)
    end)
end

local function clearTierBuffs(soul)
    for _, t in ipairs(DB_TIERS) do
        if soul:HasBuff(t.buff) then soul:RemoveBuff(t.buff) end
    end
end

local function pickTier(s)
    if type(s) ~= "number" then return DB_TIERS[1].buff end
    local v = math.max(1, math.min(30, s))
    for _, t in ipairs(DB_TIERS) do
        if v >= t.min and v <= t.max then return t.buff end
    end
    return DB_TIERS[#DB_TIERS].buff
end

local function Log(msg)
    if DynamicBandages.config.debugLogs then
        System.LogAlways("[DynamicBandages] " .. tostring(msg))
    end
end

local function getPlayerSafe()
    -- Preferred: by name (works across builds)
    local p = System.GetEntityByName and (System.GetEntityByName("Henry") or System.GetEntityByName("dude")) or nil
    if p then return p end
    -- Fallback: by class (guarded)
    if System.GetEntityByClass then
        local ok, res = pcall(System.GetEntityByClass, "Player")
        if ok then return res end
    end
    return nil
end

local function GetScholarship(player)
    local soul = player and player.soul
    if not soul or type(soul.GetSkillLevel) ~= "function" then return nil end
    local key = (DynamicBandages.config and DynamicBandages.config.scholarKey) or "scholarship"
    local ok, val = pcall(function() return soul:GetSkillLevel(key) end)
    return (ok and type(val) == "number") and val or nil
end

--Wake handler (no buffs yet; just log scholarship) ---
function DynamicBandages.ApplyOnWake()
    System.LogAlways("[DynamicBandages] ApplyOnWake() — enter")
    local ok, err = pcall(function()
        local player = getPlayerSafe()
        if not player or not player.soul then
            System.LogAlways("[DynamicBandages] ApplyOnWake: no player/soul")
            return
        end
        local soul = player.soul

        -- 1) log Scholarship using the single configured key
        local s = GetScholarship(player)
        System.LogAlways(string.format("[DynamicBandages] Wake: Scholarship=%s (key=%s)",
            tostring(s), tostring(DynamicBandages.config.scholarKey)))

        -- 2) optionally apply tier (kept behind flag)
        if DynamicBandages.config.enableBuffs then
            local chosen = pickTier(s or 1)
            clearTierBuffs(soul)
            soul:AddBuff(chosen)
            System.LogAlways("[DynamicBandages] Applied buff: " .. chosen)
        end
    end)
    if not ok then
        System.LogAlways("[DynamicBandages] ApplyOnWake() error: " .. tostring(err))
    end
    System.LogAlways("[DynamicBandages] ApplyOnWake() — exit")
end

--SkipTime / sleep UI bridge (clean: just call ApplyOnWake on hide) ---
function DynamicBandages:onSkipTimeEvent(elementName, instanceId, eventName, args)
    if not DynamicBandages.config.enableSleepHook then return end

    if eventName == "OnHide" then
        Script.SetTimer(400, function() DynamicBandages.ApplyOnWake() end)
    end
end

--Init (register SkipTime listener once) ---
function DynamicBandages.Initialize(fullInit)
    if DynamicBandages._skipListenerRegistered then return end
    if UIAction and UIAction.RegisterElementListener then
        UIAction.RegisterElementListener(DynamicBandages, "SkipTime", -1, "", "onSkipTimeEvent")
        DynamicBandages._skipListenerRegistered = true
        Log("Registered SkipTime listener")
    else
        Log("UIAction not available for SkipTime registration")
    end
end

--System listeners (match your Provision Purge pattern) ---
function DynamicBandages.OnGameplayStarted()
    System.LogAlways("[DynamicBandages] OnGameplayStarted")
    DynamicBandages.Initialize(true)

    if DynamicBandages.config.applyOnStart then
        -- run once now + retry a couple times while player/soul finish spawning
        ApplyOnceWithRetry()
    end
end

function DynamicBandages.OnSetFaderState()
    -- keep SkipTime listener alive if UI reloads
    DynamicBandages.Initialize(false)
end

UIAction.RegisterEventSystemListener(DynamicBandages, "System", "OnGameplayStarted", "OnGameplayStarted")
UIAction.RegisterEventSystemListener(DynamicBandages, "System", "OnSetFaderState", "OnSetFaderState")
