-- luacheck --config .luacheckrc .
std = "lua51"
max_line_length = 120

-- Ignora: variável não usada com _, campo global do addon.
ignore = {
    "212/self",   -- argumento self não usado em handlers
    "212/frame",
}

-- Globais que o WoW define. Acrescente conforme usar novas APIs.
read_globals = {
    "CreateFrame", "UIParent", "GameTooltip", "InCombatLockdown", "IsInInstance",
    "UnitName", "UnitClass", "UnitGUID", "UnitExists", "UnitIsUnit", "UnitAffectingCombat",
    "UnitHealth", "UnitHealthMax", "UnitHealthPercent", "UnitPower", "UnitPowerMax",
    "GetTime", "wipe", "hooksecurefunc", "issecretvalue", "hasanysecretvalues",
    "scrubsecretvalues", "securecallfunction", "SlashCmdList", "print", "format",
    "strsplit", "strjoin", "tContains", "CopyTable", "Mixin", "CreateColor",
    "C_Timer", "C_Spell", "C_Item", "C_AddOns", "C_Secrets", "C_CurveUtil",
    "C_DurationUtil", "C_RestrictedActions", "C_UnitAuras", "C_ChatInfo",
    "Settings", "EventRegistry", "LibStub",
    -- The window, on Blizzard's list parts (23/09).
    "CreateDataProvider", "ScrollBoxConstants", "CreateScrollBoxListLinearView", "ScrollUtil",
    "CreateAnchor", "NOT_COLLECTED", "UISpecialFrames", "tinsert",
}

globals = {
    "SLASH_ROCKETMOUNT1", "SLASH_ROCKETMOUNT2",
    "RocketMountDB", "RocketMount_OnCompartmentClick",
}
