-- Ensure global table exists
Leechcraft = Leechcraft or {}

-- Bootstrap: load the main logic
Script.ReloadScript("Scripts/Leechcraft/Leechcraft.lua")

if Leechcraft and Leechcraft.config and Leechcraft.config.debugLogs then
    System.LogAlways("[Leechcraft] init: main reloaded")
end
