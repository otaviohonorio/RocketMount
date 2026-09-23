-- RocketMount | Locales/enUS.lua
-- Localization base. This file ALWAYS loads, whatever the client language is.
--
-- Same structure as RocketMeter and RocketSwap (standardized on 05/09/2026), in two layers:
--
--   1. THE KEY IS THE ENGLISH TEXT. With no translation the key itself shows on screen, so
--      English is the automatic fallback for every language that has no file here yet.
--
--   2. `FROM_GAME` pulls from the client the labels Blizzard already translated, which covers
--      ~11 languages at once and uses **the word the player already reads in the interface**.
--
-- The language file (ptBR.lua) loads after this one and overrides whatever it wants. Final
-- precedence: our explicit choice > the game's word > the English key.
local ADDON, ns = ...

local L = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})

ns.L = L

--------------------------------------------------------------------------------
-- Labels the game already translated
--------------------------------------------------------------------------------
-- This table is short ON PURPOSE. Almost everything this addon writes is a sentence of ours
-- ("the list shows every missing mount", "guild vendor. These ask for reputation..."), and a
-- global only earns a place here when it is a bare label AND the evidence says it exists.
--
-- What this addon was already doing right before this table existed, and keeps doing directly
-- because those globals are indexed by number rather than named here:
--
--   `BATTLE_PET_SOURCE_<n>`      the source names (Sources.lua) -- drop, vendor, achievement...
--   `FACTION_STANDING_LABEL<n>`  the reputation standings (Sources.lua, Roster.lua, Window.lua)
--
-- Those two already came out translated in every language, and the tables next to them are
-- only the plan B for a client where one of them is missing.
local FROM_GAME = {
    ["Close"] = "CLOSE",
    ["All"]   = "ALL",
}

-- What did NOT get in, and why. Checked against the addons installed on this machine on
-- 22/09/2026 -- and the check came back INCONCLUSIVE for all of them, which is the reason:
--
--   "Expansion"   `EXPANSION_FILTER_TEXT` is the obvious candidate and no installed addon
--                 uses it, so there is no evidence it exists in 12.1.0. The English key plus
--                 a ptBR line is the honest version; the day the global is confirmed, one
--                 line here replaces eleven translations.
--   "Faction"     same, for `FACTION`.
--   "Sources"     `SOURCES` did not turn up either, and the plural is ours anyway: the
--                 button opens OUR source filter, not the game's.
--   "Search"      the search box uses `SearchBoxTemplate`, which already brings its own
--                 translated placeholder; what we write into it is a list of what can be
--                 searched ("name, boss, zone, vendor"), not the word "Search".

ns.FROM_GAME = FROM_GAME

---Does this global work as a label?
---
---Three guards, each against a different failure:
---
---  * **not a string** -> the global does not exist on this client. This guard **cannot** be
---    simplified: without it `text:find` gets `nil` and **raises while the file loads**. Since
---    this is where `ns.L` is born, the whole addon dies with it.
---  * **empty string** -> it exists but has no text; it would become a blank label.
---  * **has `%s`/`%d`** -> it is a sentence template, not a label, and would show up raw.
---
---In all three the key is left alone and English keeps working.
---@return string|nil text, string|nil reason for the refusal
local function Usable(tag)
    local text = _G[tag]
    if type(text) ~= "string" then return nil, "missing" end
    if text == "" then return nil, "empty" end
    if text:find("%%") then return nil, "sentence template" end
    return text
end

---Writes the game labels into `L`. Runs **once**, as this file loads, before the language
---file -- which overrides whatever it wants afterwards.
function ns.ApplyGameStrings()
    for key, tag in pairs(FROM_GAME) do
        local text = Usable(tag)
        if text then
            rawset(L, key, text)
        end
    end
end

---The report behind `/rmt i18n`. **Read only** -- re-applying here would paint over whatever
---the language file wrote, with nobody able to work out why.
---@return table list of { key, tag, text, why }, sorted by global
function ns.CheckGameStrings()
    local report = {}
    for key, tag in pairs(FROM_GAME) do
        local text, why = Usable(tag)
        report[#report + 1] = { key = key, tag = tag, text = text, why = why }
    end
    table.sort(report, function(a, b) return a.tag < b.tag end)
    return report
end

ns.ApplyGameStrings()
