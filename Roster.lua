-- RocketMount | Roster.lua
-- Which of your characters has the reputation a mount asks for.
--
-- (!) THIS EXISTS BECAUSE THE API CANNOT ANSWER IT. `C_Reputation` only ever speaks about the
-- character you are logged in on. Ask it about a faction an alt has and it returns nothing --
-- which is exactly the silence that used to be read as "no requirement" (see 0.6.0).
--
-- The player's question was literal: *"tu consegue mostrar qual personagem tem a reputacao que
-- precisa caso seja legada?"*. The only way is to write it down as each character logs in, in
-- account-wide SavedVariables, and read the ledger back later.
--
-- So this is a LEDGER, not a source of truth. Everything in it was true when that character last
-- logged in, and the row that quotes it says whose reputation it is and says it plainly -- a
-- stale entry that pretends to be live would be worse than no entry at all.
local _, ns = ...
local L = ns.L

local Roster = {}
ns.Roster = Roster

-- The key has to survive a rename and a realm transfer without merging two characters into one,
-- and "Name-Realm" is what the game itself uses everywhere for that.
local function CharKey()
    local name = UnitName("player")
    local realm = GetRealmName and GetRealmName() or ""
    if not name then return nil end
    return name .. "-" .. realm
end

-- Only the factions some mount actually asks for. Recording every faction in the game would
-- triple the saved file for data no row will ever read.
-- MCL's list AND ours (`Data/MountReputation.lua`, 25/09): the vendor's reputations MCL does not
-- know -- The Ascended for the Gilded Prowler -- were never written down, so no alt could be
-- named for them.
local function WantedFactions()
    local wanted = {}
    local rep = _G.MCL_GUIDE_REP_DATA
    if type(rep) == "table" then
        for _, entrada in pairs(rep) do
            local r = (type(entrada) == "table" and entrada[1]) or entrada
            if type(r) == "table" and r.factionId then
                wanted[r.factionId] = true
            end
        end
    end
    for _, r in pairs(ns.MountReputation or {}) do
        if type(r) == "table" and r.factionId then wanted[r.factionId] = true end
    end
    return wanted
end

---Writes down what this character has, right now.
---
---Runs on login and whenever reputation changes. It is cheap: a few dozen factions, and only
---the ones some mount asks for.
function Roster.Record()
    if not ns.db then return end
    local key = CharKey()
    if not key then return end

    ns.db.chars = ns.db.chars or {}
    local me = ns.db.chars[key] or {}
    ns.db.chars[key] = me

    me.name = UnitName("player")
    me.realm = GetRealmName and GetRealmName() or ""
    me.faction = UnitFactionGroup and UnitFactionGroup("player") or nil
    me.class = select(2, UnitClass("player"))
    me.seen = time and time() or 0
    me.reps = me.reps or {}
    -- The points inside the standing too (25/09): "who is CLOSEST" needs more than the level.
    me.standing = me.standing or {}

    if not (C_Reputation and C_Reputation.GetFactionDataByID) then return end

    for factionId in pairs(WantedFactions()) do
        local ok, data = pcall(C_Reputation.GetFactionDataByID, factionId)
        if ok and data and data.reaction then
            me.reps[factionId] = data.reaction
            me.standing[factionId] = data.currentStanding
        end
    end
end

---Who has this faction at `targetIdx` or better, besides whoever is logged in.
---
---Returns a list of `{ name, realm, faction, class, reaction }`, best standing first, so the row
---can name one and the card can list them all.
function Roster.WhoHas(factionId, targetIdx)
    if not ns.db or not ns.db.chars or not factionId then return {} end
    local eu = CharKey()
    local out = {}

    for key, c in pairs(ns.db.chars) do
        if key ~= eu and c.reps and c.reps[factionId] then
            local reaction = c.reps[factionId]
            if not targetIdx or reaction >= targetIdx then
                out[#out + 1] = {
                    name = c.name or key, realm = c.realm, faction = c.faction,
                    class = c.class, reaction = reaction,
                    standing = c.standing and c.standing[factionId] or nil,
                    seen = c.seen,
                }
            end
        end
    end

    table.sort(out, function(a, b)
        if a.reaction ~= b.reaction then return a.reaction > b.reaction end
        return (a.name or "") < (b.name or "")
    end)
    return out
end

---One short line for the row: who has it, and at what standing.
function Roster.Line(factionId, targetIdx)
    local quem = Roster.WhoHas(factionId, targetIdx)
    if #quem == 0 then return nil end

    local primeiro = quem[1]
    local nivel = _G["FACTION_STANDING_LABEL" .. primeiro.reaction] or "?"
    if #quem == 1 then
        return string.format(L["%s has it (%s)"], primeiro.name, nivel)
    end
    return string.format(L["%s has it (%s) and %d more"], primeiro.name, nivel, #quem - 1)
end

---How many characters the ledger knows. The window says it, because a ledger with one character
---in it cannot answer "which of mine has it" and should not look like it can.
function Roster.Count()
    if not ns.db or not ns.db.chars then return 0 end
    local n = 0
    for _ in pairs(ns.db.chars) do n = n + 1 end
    return n
end
