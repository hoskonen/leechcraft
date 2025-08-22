DynamicBandages = DynamicBandages or {}

--Minimal config
DynamicBandages.config = DynamicBandages.config or {
    debugLogs       = true,
    enableSleepHook = true,
    enableBuffs     = true,
    scholarKey      = "scholarship", -- single source of truth
    applyOnStart    = true,          -- ⬅ run once at game start
    startRetries    = 3,             -- ⬅ try a few times (soul might not be ready)
    startRetryMs    = 500,           -- ⬅ delay between retries
}

-- Scholarship → FAE mapping (levels, name, UUID)
local LEECH = {
    baseline = { name = "perk_leechcraft_reset", id = "8f2f3a2d-0c3c-4c7a-9e62-7e3e1db9c1c5" }, -- reset fae*0.3/0.4
    tiers = {
        { min = 1,  max = 5,  name = "scholarship_bandaging_1", id = "a8a0e967-184e-4185-b26d-63fc766e55da" },
        { min = 6,  max = 11, name = "scholarship_bandaging_2", id = "6837c164-2e18-43aa-9051-6dc582abf77a" },
        { min = 12, max = 17, name = "scholarship_bandaging_3", id = "9605692c-a4b1-4089-a8fb-8f46120e1534" },
        { min = 18, max = 23, name = "scholarship_bandaging_4", id = "f42e79ba-ab3f-40ac-89f6-4db9f8a48740" },
        { min = 24, max = 30, name = "scholarship_bandaging_5", id = "196fe75b-4a59-4f54-a243-535cc0e14505" },
    }
}

local function ApplyOnceWithRetry(triesLeft)
    triesLeft = triesLeft or (DynamicBandages.config.startRetries or 0)
    local ok = pcall(function() DynamicBandages.Apply("boot") end)
    if ok then return end
    if triesLeft <= 0 then return end
    Script.SetTimer(DynamicBandages.config.startRetryMs or 500, function()
        ApplyOnceWithRetry(triesLeft - 1)
    end)
end


local function Log(msg)
    if DynamicBandages.config.debugLogs then
        System.LogAlways("[LeechCraft] " .. tostring(msg))
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

local function pickTierEntry(s)
    local v = math.max(1, math.min(30, tonumber(s) or 1))
    for _, t in ipairs(LEECH.tiers) do
        if v >= t.min and v <= t.max then return t end
    end
    return LEECH.tiers[#LEECH.tiers]
end

-- Remove baseline + all tiers (idempotent, UUID-only)
local function ClearBuffs(soul)
    pcall(function() soul:RemoveBuff(LEECH.baseline.id) end)
    for _, t in ipairs(LEECH.tiers) do
        pcall(function() soul:RemoveBuff(t.id) end)
    end
end

local function AddById(soul, id, label)
    local ok, err = pcall(function() return soul:AddBuff(id) end)
    System.LogAlways(ok and ("[Leechcraft] Add: " .. (label or id))
        or ("[Leechcraft] Add FAILED: " .. tostring(err)))
    return ok
end


-- usage: lua DynamicBandages.DebugSetTier(2)
function DynamicBandages.DebugSetTier(i)
    local p = System.GetEntityByName("Henry") or System.GetEntityByName("dude")
    local s = p and p.soul
    if not s then
        System.LogAlways("[Leechcraft] DebugSetTier: no soul"); return
    end
    ClearBuffs(s)
    local idx = math.max(1, math.min(#LEECH.tiers, tonumber(i) or 1))
    AddById(s, LEECH.tiers[idx].id, LEECH.tiers[idx].name)
    System.LogAlways("[Leechcraft] DebugSetTier → " .. LEECH.tiers[idx].name)
end

-- call with a stage label so logs are clear
-- unified apply (boot/wake)
function DynamicBandages.Apply(stage)
    System.LogAlways("[LeechCraft] Apply(" .. (stage or "?") .. ") — enter")
    local ok, err = pcall(function()
        local player = getPlayerSafe()
        local soul   = player and player.soul
        if not soul then
            System.LogAlways("[LeechCraft] no soul"); return
        end

        local s = GetScholarship(player)
        System.LogAlways(string.format("[LeechCraft] %s: Scholarship=%s (key=%s)",
            stage or "?", tostring(s), tostring(DynamicBandages.config.scholarKey)))

        if not DynamicBandages.config.enableBuffs then return end

        -- pick tier entry (levels + name + UUID)
        local entry = pickTierEntry(s or 1)
        System.LogAlways(("[LeechCraft] enableBuffs=true, chosen=%s (lvl %d–%d)")
            :format(entry.name, entry.min, entry.max))

        ClearBuffs(soul)                                 -- remove baseline + all tiers by UUID
        if not AddById(soul, entry.id, entry.name) then  -- add chosen tier by UUID
            AddById(soul, LEECH.baseline.id, "baseline") -- fallback so we never leave player “empty”
        end
    end)
    if not ok then System.LogAlways("[LeechCraft] Apply error: " .. tostring(err)) end
    System.LogAlways("[LeechCraft] Apply(" .. (stage or "?") .. ") — exit")
end

--Wake handler (no buffs yet; just log scholarship) ---
function DynamicBandages.ApplyOnWake()
    System.LogAlways("[LeechCraft] ApplyOnWake() — enter")
    local ok, err = pcall(function()
        local player = getPlayerSafe()
        if not player or not player.soul then
            System.LogAlways("[LeechCraft] ApplyOnWake: no player/soul")
            return
        end
        local soul = player.soul

        -- 1) log Scholarship using the single configured key
        local s = GetScholarship(player)
        System.LogAlways(string.format("[LeechCraft] Wake: Scholarship=%s (key=%s)",
            tostring(s), tostring(DynamicBandages.config.scholarKey)))

        -- 2) optionally apply tier (kept behind flag)
        if DynamicBandages.config.enableBuffs then
            local entry = pickTierEntry(s or 1) -- has .name and .id
            System.LogAlways(("[Leechcraft] enableBuffs=true, chosen=%s (lvl %d–%d)")
                :format(entry.name, entry.min, entry.max))

            ClearBuffs(soul) -- <-- correct function name

            if not AddById(soul, entry.id, entry.name) then
                -- fallback so player is never left "empty"
                AddById(soul, LEECH.baseline.id, "baseline")
            end
        end
    end)
    if not ok then
        System.LogAlways("[LeechCraft] ApplyOnWake() error: " .. tostring(err))
    end
    System.LogAlways("[LeechCraft] ApplyOnWake() — exit")
end

--SkipTime / sleep UI bridge (clean: just call ApplyOnWake on hide) ---
function DynamicBandages:onSkipTimeEvent(_, _, eventName)
    if not DynamicBandages.config.enableSleepHook then return end
    if eventName == "OnHide" then
        Script.SetTimer(400, function() DynamicBandages.Apply("wake") end)
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
    System.LogAlways("[LeechCraft] OnGameplayStarted")
    DynamicBandages.Initialize(true)
    if DynamicBandages.config.applyOnStart then
        ApplyOnceWithRetry()
    end
end

function DynamicBandages.OnSetFaderState()
    -- keep SkipTime listener alive if UI reloads
    DynamicBandages.Initialize(false)
end

UIAction.RegisterEventSystemListener(DynamicBandages, "System", "OnGameplayStarted", "OnGameplayStarted")
UIAction.RegisterEventSystemListener(DynamicBandages, "System", "OnSetFaderState", "OnSetFaderState")
