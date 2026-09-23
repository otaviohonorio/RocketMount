-- RocketMount | Expansion.lua
-- Which expansion a mount belongs to.
--
-- (!) THE GAME DOES NOT TELL YOU. `C_MountJournal` has no expansion field, and the Mount Journal
-- itself has no expansion filter -- so there is nothing to read.
--
-- What there is: mount IDs are handed out in order, so each expansion owns a contiguous range.
-- That is not a guess of mine; it is how MountJournalEnhanced solves the same problem, and the
-- ranges below were taken from its `Database/Database.lua` (`ADDON.DB.Expansion`), which is
-- maintained by someone who tracks every patch. Its table is private to that addon
-- (no `AllowAddOnTableAccess` in its .toc), so the numbers are copied rather than read.
--
-- WHAT THIS COSTS, said plainly: MJE's table also carries a handful of per-mount exceptions --
-- mounts added late that got an ID out of their expansion's block, like the Brutal Nether Drake.
-- Those are NOT copied here. So a few mounts land one expansion off, and the filter is a good
-- way to narrow a list, not a source of truth about when something was added.
local _, ns = ...

local Expansion = {}
ns.Expansion = Expansion

-- One mount-ID range per expansion. The last one has no ceiling on purpose: a mount shipped
-- tomorrow falls into it by itself, instead of dropping out of the filter until someone
-- remembers to bump a number.
local RANGES = {
    { id = 0,  name = "Classic",             min = 0,    max = 122 },
    { id = 1,  name = "Burning Crusade",     min = 123,  max = 226 },
    { id = 2,  name = "Wrath of the Lich King", min = 227, max = 382 },
    { id = 3,  name = "Cataclysm",           min = 383,  max = 447 },
    { id = 4,  name = "Mists of Pandaria",   min = 448,  max = 571 },
    { id = 5,  name = "Warlords of Draenor", min = 572,  max = 772 },
    { id = 6,  name = "Legion",              min = 773,  max = 991 },
    { id = 7,  name = "Battle for Azeroth",  min = 993,  max = 1329 },
    { id = 8,  name = "Shadowlands",         min = 1330, max = 1576 },
    { id = 9,  name = "Dragonflight",        min = 1577, max = 2115 },
    { id = 10, name = "The War Within",      min = 2116, max = 2732 },
    { id = 11, name = "Midnight",            min = 2733, max = math.huge },
}

Expansion.RANGES = RANGES

---@return number|nil id, string|nil name
function Expansion.Of(mountID)
    if type(mountID) ~= "number" then return nil end
    for i = 1, #RANGES do
        local r = RANGES[i]
        if mountID >= r.min and mountID <= r.max then
            return r.id, r.name
        end
    end
    return nil
end

---A lista para o menu, da mais nova para a mais velha: quem filtra por expansão quase sempre
---quer a de agora, e ela seria a última numa lista cronológica.
function Expansion.Menu()
    local out = {}
    for i = #RANGES, 1, -1 do
        out[#out + 1] = RANGES[i]
    end
    return out
end
