-- RocketMount | Expansion.lua
-- Which expansion a mount belongs to.
--
-- (!) THE GAME DOES NOT TELL YOU. `C_MountJournal` has no expansion field, and the Mount Journal
-- itself has no expansion filter -- so there is nothing to read at run time.
--
-- What there is: mount ids are handed out in order, as the mounts are made, so each expansion
-- owns a stretch of ids. WHERE each stretch begins is in `Data/MountExpansion.lua`, which
-- tools/coletar_expansao.py writes from the game's own tables: the instance of the boss that
-- drops the mount, the faction it asks for, the map of who sells it, the item that teaches it
-- and what the journal itself writes of it. The cut is the first mount known to be of the new
-- expansion.
--
-- (!) OURS SINCE 29/09/2026. The ranges used to be copied from another addon's table. The user,
-- before the first publication: *"falamos para criar o nosso sem precisar de dados terceiros,
-- certo?"*.
--
-- WHAT THIS COSTS, said plainly: a stretch of ids is an approximation. The game made some
-- mounts long before it released them, and a few with an id of an older block. The ones whose
-- instance, item or journal says another expansion are written one by one (`late`); a mount
-- with nothing to say for itself (the shop, a promotion) is of the stretch its id falls in. The
-- filter is a good way to narrow a list, not a source of truth about when something was added.
local _, ns = ...

local Expansion = {}
ns.Expansion = Expansion

-- One stretch per expansion, from the table. The last one has no ceiling on purpose: a mount
-- shipped tomorrow falls into it by itself, instead of dropping out of the filter until the
-- table is made again.
local RANGES, LATE = {}, {}
do
    local T = type(ns.MountExpansion) == "table" and ns.MountExpansion or {}
    for i, r in ipairs(T) do
        local depois = T[i + 1]
        RANGES[i] = {
            id = r.id, name = r.name, min = r.min,
            max = type(depois) == "table" and type(depois.min) == "number" and depois.min - 1 or math.huge,
        }
    end
    LATE = type(T.late) == "table" and T.late or {}
end

Expansion.RANGES = RANGES

local function ById(id)
    for i = 1, #RANGES do
        if RANGES[i].id == id then return RANGES[i] end
    end
end

---@return number|nil id, string|nil name
function Expansion.Of(mountID)
    if type(mountID) ~= "number" then return nil end
    -- The one that came late says so itself.
    local tarde = LATE[mountID] and ById(LATE[mountID])
    if tarde then return tarde.id, tarde.name end
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
