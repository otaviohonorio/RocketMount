-- RocketMount | Tips.lua
-- A tip of `Data/MountTips.lua`, ready for the screen: translated, and with every name in it
-- asked from the game.
local ADDON, ns = ...
local L = ns.L

local Tips = {}
ns.Tips = Tips

-- How each kind of thing is named by the game, by id. Every one may answer nothing -- a thing
-- this client has not loaded, a faction this character never met -- and then the tip shows what
-- it carries after the bar.
local NAME = {
    item = function(id)
        return C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
    end,
    npc = function(id)
        return ns.MapPins and ns.MapPins.NpcName and ns.MapPins.NpcName(id, nil)
    end,
    achievement = function(id)
        if not GetAchievementInfo then return nil end
        local _, nome = GetAchievementInfo(id)
        return nome
    end,
    quest = function(id)
        return C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id)
    end,
    faction = function(id)
        local d = C_Reputation and C_Reputation.GetFactionDataByID and C_Reputation.GetFactionDataByID(id)
        return type(d) == "table" and d.name or nil
    end,
    currency = function(id)
        local d = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(id)
        return type(d) == "table" and d.name or nil
    end,
    map = function(id)
        local d = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(id)
        return type(d) == "table" and d.name or nil
    end,
}

---`{kind:id|fallback}` -> the game's name for it, or the fallback.
function Tips.Resolve(texto)
    if type(texto) ~= "string" then return texto end
    return (texto:gsub("{(%a+):(%d+)|([^}]*)}", function(tipo, id, reserva)
        local fn = NAME[tipo]
        if fn then
            local ok, nome = pcall(fn, tonumber(id))
            if ok and type(nome) == "string" and nome ~= ""
                and not (issecretvalue and issecretvalue(nome)) then
                return nome
            end
        end
        return reserva
    end))
end

---The tip of one mount, for the card and the map tooltip.
---@return string|nil text, string|nil note -- the note says when it was reported
function Tips.For(mountID)
    local t = mountID and type(ns.MountTips) == "table" and ns.MountTips[mountID]
    if type(t) ~= "table" or type(t.text) ~= "string" then return nil end
    -- The player's language when there is one for this mount (`Locales/ptBR_Tips.lua`, written
    -- by the same generator as the English), English otherwise.
    local local_ = type(ns.MountTipsLocal) == "table" and ns.MountTipsLocal[mountID]
    local texto = Tips.Resolve(type(local_) == "string" and local_ or t.text)
    local nota = t.year and string.format(L["Reported by players in %d. The game may have changed since."], t.year)
        or L["Reported by players. The game may have changed since."]
    return texto, nota
end

---The tip SEVERAL mounts have in common, for a place on the map that gives more than one: the two
---mounts of a zone's rares, the six a vendor trades for one saddle. Nothing when any of them has
---no tip or has another one -- a tooltip with a tip per mount is a wall, and the card has each.
---@param entries table[] -- what a marker holds in `mounts`: `{ entry = { mountID = ... } }`
---@return string|nil text, string|nil note
function Tips.Shared(entries)
    if type(entries) ~= "table" or #entries < 2 then return nil end
    local texto, nota
    for _, m in ipairs(entries) do
        local e = type(m) == "table" and m.entry
        local t, n = Tips.For(type(e) == "table" and e.mountID or nil)
        if not t or (texto and t ~= texto) then return nil end
        texto, nota = t, n
    end
    return texto, nota
end
