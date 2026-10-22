-- RocketMount | Events.lua
--
-- (22/10) THE ALERT BEFORE A MOUNT'S EVENT. The user: *"seria legal ter a opção de ser avisado por
-- padrão mas editável 5 min antes de iniciar o evento"*, then: *"o funcionamento do aviso é para todos
-- que ainda tem montaria para pegar, mas vamos por em algum canto a opção do usuário desativar os
-- avisos, por padrão vem habilitado e apenas para os eventos das montarias que ele ainda não tem (...)
-- e no addon tem que ter a lista desses eventos por que ele pode querer desativar algum"*.
--
-- What it does: every TICK seconds, for each event of Data/MountEvents.lua the player did not turn off,
-- when the next start is at most `ns.db.eventLead` minutes away, the event still leads to a mount this
-- character lacks and its reward is not taken yet, ONE line in the chat and the chime -- the way the
-- game's own reminder of its Events tab does it (EventScheduler.lua, `AnnounceEvent`: a system line and
-- a chime, 300 s before; Constants.EventScheduler.SCHEDULED_EVENT_REMINDER_WARNING_SECONDS).
--
-- WHEN, in this order -- never a guessed hour:
--   1. the game's own schedule (C_EventScheduler.GetScheduledEvents, 11.1+): start, end and
--      `rewardsClaimed`, for the events it lists;
--   2. the event's fixed clock (period, duration and an anchor in server time, per region);
--   3. a rare's clock (Data/RareTimers.lua, through Sighting.NextWindow).
local ADDON, ns = ...
local L = ns.L

local Events = {}
ns.Events = Events

Events.LEAD = { MIN = 1, MAX = 15, STEP = 1, DEFAULT = 5 }    -- minutes before the start
local TICK = 15
local alerted = {}                                              -- [key .. start] = true, this session

local function Now()
    local ok, t = pcall(GetServerTime or error)
    if ok and type(t) == "number" then return t end
    return time()
end

local function Region()
    local ok, r = pcall(GetCurrentRegion or error)
    return ok and type(r) == "number" and r or nil
end

function Events.List() return type(ns.MountEvents) == "table" and ns.MountEvents or {} end

function Events.Enabled(e)
    if not ns.db or ns.db.eventAlerts == false then return false end
    return not (type(ns.db.eventOff) == "table" and ns.db.eventOff[e.key])
end

---The window of the event by its fixed clock: the start and end of the one running, or of the next.
---@return number|nil start, number|nil finish (server time)
function Events.ClockWindow(e, now)
    local c = e.clock
    if not c then return nil end
    local anchor = c.anchor
    if type(anchor) == "table" then anchor = anchor[Region() or 0] end
    if type(anchor) ~= "number" then return nil end           -- a region we have no clock for: say nothing
    local since = (now - anchor) % c.period
    local start = now - since
    if since >= c.lasts then start = start + c.period end
    return start, start + c.lasts
end

---The game's schedule for the event: the next (or running) occurrence it lists.
---@return number|nil start, number|nil finish, boolean claimed
function Events.Scheduled(e, now)
    if not (e.pois and C_EventScheduler and C_EventScheduler.GetScheduledEvents) then return nil end
    local ok, list = pcall(C_EventScheduler.GetScheduledEvents)
    if not ok or type(list) ~= "table" then return nil end
    local poi = {}
    for _, id in ipairs(e.pois) do poi[id] = true end
    local best
    for _, info in ipairs(list) do
        if type(info) == "table" and poi[info.areaPoiID] and type(info.startTime) == "number"
            and type(info.endTime) == "number" and info.endTime > now
            and (not best or info.startTime < best.startTime) then
            best = info
        end
    end
    if not best then return nil end
    return best.startTime, best.endTime, best.rewardsClaimed == true
end

---The next START still ahead (the running one does not count: its alert time is gone), by the best
---source there is. `claimed` when the game says the reward of it is already taken.
---@return number|nil seconds until it starts, string|nil source, boolean claimed
function Events.NextStart(e, now)
    now = now or Now()
    local s, f, claimed = Events.Scheduled(e, time())
    if s then
        local wait = s - time()
        if wait > 0 then return wait, "game", claimed end
        -- running: the game lists the next one too when it has it; otherwise fall to the clock
    end
    s = Events.ClockWindow(e, now)
    if s then
        if s <= now then s = s + e.clock.period end
        return s - now, "clock", false
    end
    if e.npc and ns.Sighting and ns.Sighting.NextWindow then
        local w = ns.Sighting.NextWindow(e.npc)
        local t = w and type(ns.RareTimers) == "table" and ns.RareTimers[e.npc]
        if w and t then
            if w.open then return w.seconds + (t.period - t.lasts), "clock", false end
            return w.seconds, "clock", false
        end
    end
    return nil
end

---The event's mounts this character lacks: `{ { id, name, icon } }`. A mount the game hides from
---this character (the other faction) does not count while "Only what I can get" is on.
function Events.Missing(e)
    local out = {}
    if not (C_MountJournal and C_MountJournal.GetMountInfoByID) then return out end
    for _, id in ipairs(e.mounts or {}) do
        local ok, name, _, icon, _, _, _, _, _, _, hide, collected = pcall(C_MountJournal.GetMountInfoByID, id)
        if ok and type(name) == "string" and not collected
            and not (hide and ns.db and ns.db.hideUnavailable ~= false) then
            out[#out + 1] = { id = id, name = name, icon = icon }
        end
    end
    return out
end

---The reward of this week is already taken (the event's hidden quest).
function Events.Done(e)
    if not (e.quest and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) then return false end
    local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, e.quest)
    return ok and done == true
end

---The zone's name, from the game.
function Events.Zone(e)
    if not (e.map and C_Map and C_Map.GetMapInfo) then return nil end
    local ok, info = pcall(C_Map.GetMapInfo, e.map)
    return ok and type(info) == "table" and info.name or nil
end

local function Minutos(segundos)
    return string.format(L["%dmin"], math.max(1, math.floor((segundos + 59) / 60)))
end

---Why an event would not alert now, or nil when it would (for the tick, `/rmt events` and the tests).
function Events.Why(e, wait, claimed)
    if not Events.Enabled(e) then return "off" end
    if #Events.Missing(e) == 0 then return "no-missing-mount" end
    if claimed or Events.Done(e) then return "claimed" end
    if not wait then return "no-clock" end
    return nil
end

-- (22/10) WHAT THE EVENT CAN GIVE, AND HOW OFTEN. The user: *"e no aviso mostra o percental de chance e se é diario,
-- semanal, se pode repetir e etc"* and *"e quais montarias podem dar também"*. Per mount the player lacks: the chance
-- (a drop: our data, the same `ns.FormatChance` as the list), the price and what the player holds (a currency: our
-- price table and the game's count), or the renown it asks and the one reached (renown: the game's). Then how often the
-- event gives it: once a week, once a day, or again at every event.

---How often the event gives what leads to its mounts, as the line says it, or nil when not known.
function Events.RewardText(e)
    local f = e.reward
    if not f and e.npc and ns.Sighting and ns.Sighting.LootFrequency then f = ns.Sighting.LootFrequency(e.npc) end
    if f == "weekly" then return L["once a week"] end
    if f == "daily" then return L["once a day"] end
    if f == "repeat" or f == "unlimited" then return L["again at every event"] end
    return nil
end

---The chance of a dropped mount: `{ count, outof, itemID }` from our tables (the chest of MountPlaces, a rare's loot).
local function Drop(e, id)
    local T = ns.MountPlaces
    local m = type(T) == "table" and type(T.mount) == "table" and T.mount[id]
    local box = type(m) == "table" and m.box
    if type(box) == "table" and box.count and box.outof then return box.count, box.outof, box.kind == "item" and box.id end
    local rec = e.npc and type(ns.MobDrops) == "table" and ns.MobDrops[e.npc]
    local item = type(ns.MountItems) == "table" and ns.MountItems[id]
    for _, d in ipairs(type(rec) == "table" and rec or {}) do
        if type(d) == "table" and d.item == item and d.count and d.outof then return d.count, d.outof end
    end
    return nil
end

---What one mount of the event takes: "3.8% per <chest>", "3,000 Paracausal Flakes, you have 1,250", "renown 18,
---you are at 12" -- or nil when nothing is known.
function Events.MountDetail(e, id)
    if e.how == "drop" then
        local count, outof, item = Drop(e, id)
        local chance = count and count > 0 and ns.FormatChance and ns.FormatChance(outof / count, count < 10)
        if not chance then return nil end
        local nome = item and C_Item and C_Item.GetItemNameByID and select(2, pcall(C_Item.GetItemNameByID, item))
        return type(nome) == "string" and string.format(L["%s per %s"], chance, nome) or chance
    elseif e.how == "currency" then
        local lista = ns.OwnCost and ns.OwnCost(id)
        for _, c in ipairs(lista and lista[1] or {}) do
            if c.type == "currency" and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
                local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, c.id)
                if ok and type(info) == "table" and info.name then
                    local num = BreakUpLargeNumbers or tostring
                    return string.format(L["%s %s, you have %s"], num(c.amount), info.name, num(info.quantity or 0))
                end
            end
        end
    elseif e.how == "renown" then
        local rep = type(ns.MountReputation) == "table" and ns.MountReputation[id]
        if type(rep) == "table" and rep.level then
            local tenho = C_MajorFactions and C_MajorFactions.GetMajorFactionRenownInfo
                and select(2, pcall(C_MajorFactions.GetMajorFactionRenownInfo, rep.factionId))
            local nivel = type(tenho) == "table" and tenho.renownLevel
            return type(nivel) == "number" and string.format(L["renown %d, you are at %d"], rep.level, nivel)
                or string.format(L["renown %d"], rep.level)
        end
    end
    return nil
end

local SHOWN = 3      -- mounts named on the line; the rest counted

---The chat line for an event `wait` seconds away: when, where, each mount it can give that the player lacks with
---what it takes, and how often.
function Events.Line(e, wait)
    local faltam = Events.Missing(e)
    local partes = {}
    -- the same detail for every mount (one price, one renown): said once, after the names
    local detalhes, iguais = {}, true
    for i, m in ipairs(faltam) do
        detalhes[i] = Events.MountDetail(e, m.id)
        if detalhes[i] ~= detalhes[1] then iguais = false end
    end
    for i, m in ipairs(faltam) do
        if i > SHOWN then
            partes[#partes + 1] = string.format(L["and %d more"], #faltam - SHOWN)
            break
        end
        partes[i] = (detalhes[i] and not (iguais and #faltam > 1)) and string.format("%s (%s)", m.name, detalhes[i]) or m.name
    end
    local montarias = table.concat(partes, ", ")
    if iguais and #faltam > 1 and detalhes[1] then montarias = montarias .. " — " .. string.format(L["%s each"], detalhes[1]) end
    local tem = #(e.mounts or {}) - #faltam
    local hora = select(2, pcall(date, "%H:%M", time() + wait))
    local onde = Events.Zone(e)
    local quando = type(hora) == "string" and (onde and string.format("%s, %s", hora, onde) or hora) or onde
    local texto = string.format(L["|cffffff00%s|r starts in %s"], L[e.name], Minutos(wait))
    if quando then texto = texto .. " (" .. quando .. ")" end
    texto = texto .. "  ·  " .. string.format(L["can give: %s"], montarias)
    if tem > 0 then texto = texto .. " " .. string.format(L["(you have %d of %d)"], tem, #e.mounts) end
    local vez = Events.RewardText(e)
    if vez then texto = texto .. "  ·  " .. vez end
    return texto
end

function Events.Tick()
    if not ns.db or ns.db.eventAlerts == false then return end
    local lead = 60 * (tonumber(ns.db.eventLead) or Events.LEAD.DEFAULT)
    local now = Now()
    for _, e in ipairs(Events.List()) do
        if Events.Enabled(e) then
            local wait, _, claimed = Events.NextStart(e, now)
            if wait and wait <= lead then
                local chave = e.key .. ":" .. math.floor((now + wait) / 60)
                if not alerted[chave] and not Events.Why(e, wait, claimed) then
                    alerted[chave] = true
                    ns.Print(Events.Line(e, wait))
                    if ns.db.sightingSound ~= false and ns.Sighting and ns.Sighting.PlaySound then
                        pcall(ns.Sighting.PlaySound, ns.db.sightingSoundKey, ns.db.sightingVolume)
                    end
                    if ns.Log then pcall(ns.Log.Add, "event", { key = e.key, wait = wait }) end
                end
            end
        end
    end
end

---`/rmt events`: every event, when it starts and why it would or would not alert.
function Events.Report()
    ns.Print(string.format(L["event alerts %s, %d min before:"], ns.db and ns.db.eventAlerts == false and L["OFF"] or L["on"],
        tonumber(ns.db and ns.db.eventLead) or Events.LEAD.DEFAULT))
    local now = Now()
    for _, e in ipairs(Events.List()) do
        local wait, fonte, claimed = Events.NextStart(e, now)
        local porque = Events.Why(e, wait, claimed)
        local estado = ({ off = L["turned off"], ["no-missing-mount"] = L["you have its mounts"],
                          claimed = L["reward taken this week"], ["no-clock"] = L["no known start"] })[porque] or L["will alert"]
        print(string.format("    %s: %s  ·  %s", L[e.name], wait and string.format(L["in %s"], Minutos(wait)) or "-", estado))
        -- every mount the event can give, the ones this character has marked, each with what it takes
        local nomes = {}
        for _, id in ipairs(e.mounts or {}) do
            local ok, nome, _, _, _, _, _, _, _, _, _, tem = pcall(C_MountJournal and C_MountJournal.GetMountInfoByID or error, id)
            if ok and type(nome) == "string" then
                local d = not tem and Events.MountDetail(e, id)
                nomes[#nomes + 1] = tem and string.format(L["%s (you have it)"], nome) or (d and string.format("%s (%s)", nome, d) or nome)
            end
        end
        local vez = Events.RewardText(e)
        print("        " .. string.format(L["can give: %s"], table.concat(nomes, ", ")) .. (vez and ("  ·  " .. vez) or ""))
    end
end

function Events.Reset() wipe(alerted) end

function Events.Enable()
    if Events.__on then return end
    Events.__on = true
    if C_EventScheduler and C_EventScheduler.RequestEvents then pcall(C_EventScheduler.RequestEvents) end
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(TICK, function() pcall(Events.Tick) end)
        -- the game's schedule is asked again now and then (its own tab does it when shown)
        C_Timer.NewTicker(600, function()
            if C_EventScheduler and C_EventScheduler.RequestEvents then pcall(C_EventScheduler.RequestEvents) end
        end)
    end
end
