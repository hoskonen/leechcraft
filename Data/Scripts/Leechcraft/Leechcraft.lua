Leechcraft = Leechcraft or {}

-- Minimal config
Leechcraft.config = Leechcraft.config or {
    debugLogs       = false,
    enableSleepHook = true,
    enableBuffs     = true,
    applyOnStart    = true,          -- run once at game start
    startRetries    = 3,             -- try a few times (soul might not be ready)
    startRetryMs    = 500,           -- delay between retries
    scholarKey      = "scholarship", -- single source of truth
}

-- ---------- Logging helpers MUST come before any use ----------
local function Log(msg)
    if Leechcraft.config.debugLogs then
        System.LogAlways("[Leechcraft] " .. tostring(msg))
    end
end

local function Warn(msg)
    System.LogAlways("[Leechcraft] " .. tostring(msg))
end

-- Session flags
Leechcraft._skipListenerRegistered = Leechcraft._skipListenerRegistered or false
Leechcraft._bootLogged             = Leechcraft._bootLogged or false

-- ---------- Config override (safe) ----------
do
    local ok, err = pcall(function()
        Script.ReloadScript("Scripts/Leechcraft/LeechcraftConfig.lua")
    end)
    if ok and Leechcraft_Config then
        for k, v in pairs(Leechcraft_Config) do Leechcraft.config[k] = v end
        Log("Loaded config override from LeechcraftConfig.lua")
    elseif not ok then
        Warn("Config override load failed: " .. tostring(err))
    else
        Log("No Leechcraft_Config table found; using defaults")
    end
end

-- ---------- Scholarship → FAE mapping ----------
local LEECH = {
    tiers = {
        { min = 1,  max = 5,  name = "scholarship_bandaging_1", id = "a8a0e967-184e-4185-b26d-63fc766e55da" },
        { min = 6,  max = 11, name = "scholarship_bandaging_2", id = "6837c164-2e18-43aa-9051-6dc582abf77a" },
        { min = 12, max = 17, name = "scholarship_bandaging_3", id = "9605692c-a4b1-4089-a8fb-8f46120e1534" },
        { min = 18, max = 23, name = "scholarship_bandaging_4", id = "f42e79ba-ab3f-40ac-89f6-4db9f8a48740" },
        { min = 24, max = 30, name = "scholarship_bandaging_5", id = "196fe75b-4a59-4f54-a243-535cc0e14505" },
    }
}

-- ---------- Retry wrapper ----------
local function ApplyOnceWithRetry(triesLeft)
    triesLeft = triesLeft or (Leechcraft.config.startRetries or 0)
    local ok, applied = pcall(function() return Leechcraft.Apply("boot") end)
    if ok and applied then return end
    if triesLeft <= 0 then return end
    Script.SetTimer(Leechcraft.config.startRetryMs or 500, function()
        ApplyOnceWithRetry(triesLeft - 1)
    end)
end

-- ---------- Utils ----------
local function getPlayerSafe()
    local p = System.GetEntityByName and (System.GetEntityByName("Henry") or System.GetEntityByName("dude")) or nil
    if p then return p end
    if System.GetEntityByClass then
        local ok, res = pcall(System.GetEntityByClass, "Player")
        if ok then return res end
    end
    return nil
end

local function GetScholarship(player)
    local soul = player and player.soul
    if not soul or type(soul.GetSkillLevel) ~= "function" then return nil end
    local key = (Leechcraft.config and Leechcraft.config.scholarKey) or "scholarship"
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

-- ---------- Buff ops ----------
local function ClearBuffs(soul)
    if not soul then return end
    pcall(function() soul:RemoveAllBuffsByGuid("barbora") end) -- best-effort DB wipe
    for _, t in ipairs(LEECH.tiers) do
        pcall(function() soul:RemoveBuff(t.id) end)            -- current UUIDs
    end
end

local function AddById(soul, id, label)
    local ok, err = pcall(function() return soul:AddBuff(id) end)
    if ok then Log("Add: " .. (label or id)) else Warn("Add FAILED: " .. tostring(err)) end
    return ok
end

-- ---------- Debug helper ----------
function Leechcraft.DebugSetTier(i)
    local p = System.GetEntityByName("Henry") or System.GetEntityByName("dude")
    local s = p and p.soul
    if not s then
        Warn("DebugSetTier: no soul"); return
    end
    ClearBuffs(s)
    local idx = math.max(1, math.min(#LEECH.tiers, tonumber(i) or 1))
    AddById(s, LEECH.tiers[idx].id, LEECH.tiers[idx].name)
    Warn("DebugSetTier → " .. LEECH.tiers[idx].name)
end

-- ---------- Apply (boot/wake) ----------
function Leechcraft.Apply(stage)
    Log("Apply(" .. (stage or "?") .. ") — enter")
    local applied = false
    local ok, err = pcall(function()
        local player = getPlayerSafe()
        local soul   = player and player.soul
        if not soul then
            Log("no soul"); return
        end

        local s = GetScholarship(player)
        Log(string.format("%s: Scholarship=%s (key=%s)", stage or "?", tostring(s),
            tostring(Leechcraft.config.scholarKey)))

        if not Leechcraft.config.enableBuffs then return end

        local entry = pickTierEntry(s or 1)
        Log(("enableBuffs=true, chosen=%s (lvl %d–%d)"):format(entry.name, entry.min, entry.max))

        ClearBuffs(soul)
        applied = AddById(soul, entry.id, entry.name)
    end)
    if not ok then Warn("Apply error: " .. tostring(err)) end
    Log("Apply(" .. (stage or "?") .. ") — exit")
    return applied
end

-- ---------- Sleep UI bridge ----------
function Leechcraft:onSkipTimeEvent(_, _, eventName)
    if not Leechcraft.config.enableSleepHook then return end
    if eventName == "OnHide" then
        Script.SetTimer(400, function() Leechcraft.Apply("wake") end)
    end
end

-- ---------- Init / System listeners ----------
function Leechcraft.Initialize(fullInit)
    if Leechcraft._skipListenerRegistered then return end
    if UIAction and UIAction.RegisterElementListener then
        UIAction.RegisterElementListener(Leechcraft, "SkipTime", -1, "", "onSkipTimeEvent")
        Leechcraft._skipListenerRegistered = true
        Log("Registered SkipTime listener")
    else
        Log("UIAction not available for SkipTime registration")
    end
end

function Leechcraft.OnGameplayStarted()
    Leechcraft.Initialize(true)                       -- register SkipTime
    if not Leechcraft._bootLogged then
        System.LogAlways("[Leechcraft] Initialized.") -- one tidy line
        Leechcraft._bootLogged = true
    end
    if Leechcraft.config.applyOnStart then
        ApplyOnceWithRetry()
        -- Script.SetTimer(2000, function() Leechcraft.Apply("post-boot") end) -- optional
    end
end

function Leechcraft.OnSetFaderState()
    Leechcraft.Initialize(false)
end

UIAction.RegisterEventSystemListener(Leechcraft, "System", "OnGameplayStarted", "OnGameplayStarted")
UIAction.RegisterEventSystemListener(Leechcraft, "System", "OnSetFaderState", "OnSetFaderState")
