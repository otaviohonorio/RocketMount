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
--
-- (24/10) WHERE, A CLICK, A PANEL, AND NEVER IN THE MIDDLE OF SOMETHING. The user: *"seria bom dizer qual mapa, qual
-- lugar especifico do mapa e clicar para setar a coordenada, e mais uma opção mostrar o evento como mostra quando acha
-- raro uma popup e isso tudo configuravel, ou só no chat ou no chat e popup"*; then *"o aviso dos eventos não pode
-- acontecer em combate, dentro de DGs, Raids, Imersões e conteúdos instanciados para não atrapalhar o jogador"*, and
-- *"se for adiado pode avisar tarde, então precisa de inteligencia, se o evento passou, descarta ele"*.
--   * the place: Events.Spot -- the game's own answer first, our table of the game's landmarks second;
--   * the click: the chat line carries a pin link like the rare alert's; the panel is the rare's panel;
--   * `ns.db.eventHow`: "popup" (the chat and the panel, the default) or "chat";
--   * busy (combat, or any instance: dungeon, raid, delve, scenario, battleground, arena): the alert waits. When the
--     player is free again it comes if the event has not started, or if it runs with MIN_LEFT still to go ("started
--     3 min ago, ends in 12 min"); an event that is over or nearly over is dropped.
-- (29/10) THE LATE ALERT IS AN OPTION, OFF BY DEFAULT. The user: *"quero por para desabilitar de mostrar eventos em
-- andamento quando ele não avisou o começo por conta de estar em combate ou em conteúdo instanciado (...) por padrão deixa
-- desabilitado, o unico aviso é dos 5 min antes de começar e se o usuário não viu pq estava em conteúdo ai perde o aviso"*.
-- `ns.db.eventLate` (false): an alert held back that the event's start caught is dropped; true: the late one as above.
-- An alert held back that comes free BEFORE the start still comes ("starts in 2 min"): it is the alert before the start.
local ADDON, ns = ...
local L = ns.L

local Events = {}
ns.Events = Events

Events.LEAD = { MIN = 1, MAX = 15, STEP = 1, DEFAULT = 5 }    -- minutes before the start
Events.HOW = { "popup", "chat" }                                -- ns.db.eventHow; the first is the default
Events.MIN_LEFT = 5 * 60                                        -- a late alert still worth the trip
local TICK = 15
local alerted = {}                                              -- [key .. start] = true, this session
local pending = {}                                              -- [key .. start] = true: its time came while busy

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
---@return number|nil start, number|nil finish, boolean claimed, number|nil areaPoiID
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
    return best.startTime, best.endTime, best.rewardsClaimed == true, best.areaPoiID
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

---The occurrence running now, or the next one: seconds until it starts (negative: started that long ago) and until
---it ends, by the best source there is.
---@return number|nil toStart, number|nil toEnd, string|nil source, boolean claimed, number|nil areaPoiID
function Events.Window(e, now)
    now = now or Now()
    local t = time()
    local s, f, claimed, poi = Events.Scheduled(e, t)
    if s then return s - t, f - t, "game", claimed, poi end
    s, f = Events.ClockWindow(e, now)
    if s then return s - now, f - now, "clock", false end
    if e.npc and ns.Sighting and ns.Sighting.NextWindow then
        local w = ns.Sighting.NextWindow(e.npc)
        local r = w and type(ns.RareTimers) == "table" and ns.RareTimers[e.npc]
        if w and r then
            if w.open then return w.seconds - r.lasts, w.seconds, "clock", false end
            return w.seconds, w.seconds + r.lasts, "clock", false
        end
    end
    return nil
end

---Why the player cannot be bothered now, or nil: in combat, or inside any instance.
function Events.Busy()
    if InCombatLockdown and InCombatLockdown() then return "combat" end
    if ns.Sighting and ns.Sighting.InOpenWorld and not ns.Sighting.InOpenWorld() then return "instance" end
    return nil
end

---Where the event happens: `{ m, x, y, place }` with x and y in 0-100, or nil when there is no single place.
---  1. the game: the map of the landmark (C_EventScheduler.GetEventUiMapID, what the game's Events tab opens) and its
---     position (C_AreaPoiInfo.GetAreaPOIInfo) -- the moving cave of Abundance only has this; `place` is the
---     landmark's name when it says more than the event's ("Abundance: Skinning Den" gives "Skinning Den");
---  2. our table of the game's landmarks (`spot`, tools/coletar_eventos.py);
---  3. a rare with ONE known place (Data/MobDrops). Beledar's Spawn has twenty: no single place, the map shows them.
function Events.Spot(e, poi)
    local ids = poi and { poi } or e.pois or {}
    for _, id in ipairs(ids) do
        local mapa = e.map
        if C_EventScheduler and C_EventScheduler.GetEventUiMapID then
            local ok, m = pcall(C_EventScheduler.GetEventUiMapID, id)
            if ok and type(m) == "number" then mapa = m end
        end
        if mapa and C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIInfo then
            local ok, info = pcall(C_AreaPoiInfo.GetAreaPOIInfo, mapa, id)
            local pos = ok and type(info) == "table" and info.position
            local x = type(pos) == "table" and tonumber(pos.x)
            local y = type(pos) == "table" and tonumber(pos.y)
            if x and y and (x > 0 or y > 0) then
                local place = type(info.name) == "string" and info.name ~= L[e.name] and info.name or nil
                if place then place = place:match("^.-:%s*(.+)$") or place end
                return { m = mapa, x = x * 100, y = y * 100, place = place }
            end
        end
    end
    if type(e.spot) == "table" and e.spot.m then return { m = e.spot.m, x = e.spot.x, y = e.spot.y } end
    local rec = e.npc and type(ns.MobDrops) == "table" and ns.MobDrops[e.npc]
    local pts = type(rec) == "table" and type(rec.where) == "table" and e.map and rec.where[e.map]
    if type(pts) == "table" and #pts == 2 then return { m = e.map, x = pts[1], y = pts[2] } end
    return nil
end

---A map's name, from the game.
local function MapName(m)
    if not (m and C_Map and C_Map.GetMapInfo) then return nil end
    local ok, info = pcall(C_Map.GetMapInfo, m)
    return ok and type(info) == "table" and info.name or nil
end

---"Skinning Den, Zul'Aman  45.1, 22.3" / "Voidstorm  27.3, 68.0" / "Hallowfall": where, as the chat says it.
function Events.Where(e, spot)
    local zona = MapName(spot and spot.m or e.map)
    local texto = zona
    if spot and spot.place then texto = zona and (spot.place .. ", " .. zona) or spot.place end
    if spot and spot.x and spot.y then texto = string.format("%s  %.1f, %.1f", texto or "", spot.x, spot.y) end
    return texto
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

---The chat line for an event `wait` seconds away (negative: running, `left` seconds to go): when, where, each mount
---it can give that the player lacks with what it takes, how often, and the pin link.
function Events.Line(e, wait, left, spot)
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
    local onde = Events.Where(e, spot)
    local texto, quando
    if wait > 0 then
        local hora = select(2, pcall(date, "%H:%M", time() + wait))
        quando = type(hora) == "string" and (onde and string.format("%s, %s", hora, onde) or hora) or onde
        texto = string.format(L["|cffffff00%s|r starts in %s"], L[e.name], Minutos(wait))
    else
        quando = onde
        texto = string.format(L["|cffffff00%s|r started %s ago, ends in %s"], L[e.name], Minutos(-wait), Minutos(left or 0))
    end
    if quando then texto = texto .. " (" .. quando .. ")" end
    texto = texto .. "  ·  " .. string.format(L["can give: %s"], montarias)
    if tem > 0 then texto = texto .. " " .. string.format(L["(you have %d of %d)"], tem, #e.mounts) end
    local vez = Events.RewardText(e)
    if vez then texto = texto .. "  ·  " .. vez end
    local link = ns.Sighting and ns.Sighting.EventLink and ns.Sighting.EventLink(e, spot)
    if link then texto = texto .. "  " .. link end
    return texto
end

---"Starts in 4min · Voidstorm" / "Ends in 12min · Voidstorm": the panel's last line, short enough for it.
function Events.PanelLine(e, wait, left, spot)
    local quando = wait > 0 and string.format(L["Starts in %s"], Minutos(wait)) or string.format(L["Ends in %s"], Minutos(left or 0))
    local zona = MapName(spot and spot.m or e.map)
    return zona and (quando .. "  ·  " .. zona) or quando
end

---The alert: the chat line always; the panel too unless the player chose the chat only.
function Events.Announce(e, wait, left, poi)
    local spot = Events.Spot(e, poi)
    ns.Print(Events.Line(e, wait, left, spot))
    if (ns.db.eventHow or Events.HOW[1]) == "popup" and ns.Sighting and ns.Sighting.ShowEvent then
        pcall(ns.Sighting.ShowEvent, e, Events.Missing(e), Events.PanelLine(e, wait, left, spot), spot)
    elseif ns.db.sightingSound ~= false and ns.Sighting and ns.Sighting.PlaySound then
        pcall(ns.Sighting.PlaySound, ns.db.sightingSoundKey, ns.db.sightingVolume)
    end
end

function Events.Tick()
    if not ns.db or ns.db.eventAlerts == false then return end
    local lead = 60 * (tonumber(ns.db.eventLead) or Events.LEAD.DEFAULT)
    local now = Now()
    local busy = Events.Busy()
    for _, e in ipairs(Events.List()) do
        if Events.Enabled(e) then
            local wait, left, _, claimed, poi = Events.Window(e, now)
            if wait and left and left > 0 then
                local chave = e.key .. ":" .. math.floor((now + wait) / 60)
                -- its time: up to `lead` before the start; once it runs, only an alert put off while busy, and only
                -- with MIN_LEFT to go (an event over or nearly over is dropped)
                -- (29/10) the late one only with `eventLate` (off by default): the user, *"o unico aviso é dos 5 min antes
                -- de começar e se o usuário não viu pq estava em conteúdo ai perde o aviso"*
                if wait <= 0 and pending[chave] and ns.db.eventLate ~= true then
                    pending[chave] = nil
                    if ns.Log then pcall(ns.Log.Add, "event-missed", { key = e.key }) end
                end
                local due = (wait > 0 and wait <= lead) or (wait <= 0 and pending[chave] and left >= Events.MIN_LEFT)
                if due and not alerted[chave] and not Events.Why(e, wait, claimed) then
                    if busy then
                        if not pending[chave] and ns.Log then pcall(ns.Log.Add, "event-wait", { key = e.key, why = busy }) end
                        pending[chave] = true
                    else
                        alerted[chave], pending[chave] = true, nil
                        Events.Announce(e, wait, left, poi)
                        if ns.Log then pcall(ns.Log.Add, "event", { key = e.key, wait = wait }) end
                    end
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

function Events.Reset() wipe(alerted); wipe(pending) end

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
