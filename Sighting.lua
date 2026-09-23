-- RocketMount | Sighting.lua
-- Tells you when something in front of you can drop a mount you are missing.
--
-- (!) THIS FILE WAS REWRITTEN ON 22/09 AFTER FOUR DEFECTS IN ONE SINGLE REPORT.
--
-- The player stood in Silvermoon, at the login loading screen, and got:
--
--     Rocket Mount: Rhazul pode largar: Petalasa Vibrante, Malevolince Espreitarraiz
--     Rocket Mount: seta apontada para onde você viu.
--
-- Rhazul is a real rare, and the catalogue was right about it -- it drops Rootstalker Grimlynx,
-- in map 2413. Everything else was wrong:
--
--   1. the match was made on the NAME alone, with no check that the unit was a creature, that
--      it was classified rare, or that the player was even in the right zone;
--   2. it fired during login, when nothing is in front of you;
--   3. the waypoint was dropped on the PLAYER'S OWN FEET, in the capital -- while the rare's
--      real coordinates sat unused in the very record the alert was built from;
--   4. the panel held for 12 seconds, which is not long enough to read while playing.
--
-- What the rewrite takes from addons that already solve this:
--
--   SILVERDRAGON identifies a mob by the **npcID parsed out of its GUID**, never by name, and
--   requires `UnitClassification` to be rare/rareelite. A player's pet has a `Pet` GUID, so it
--   stops being a candidate structurally rather than by a name blocklist.
--
--   MCL's own `GuideRareAlert.lua` keys on the **vignette ID** (`wp.v` in the catalogue), and
--   its comment says why: "the same number on every locale". It also documents the exact trap
--   that bit us, with another example -- matching "Lockjaw" against "Lockjaw the Snapper".
--
-- So: vignette ID first, because it is a number and cannot be confused. Name only as a
-- fallback, and only when the player is standing in a zone where that rare actually lives.
local ADDON, ns = ...
local L = ns.L

local Sighting = {}
ns.Sighting = Sighting

-- One alert per rare every ten minutes. Without it, a rare standing in front of you fires on
-- every nameplate that appears and disappears -- and a repeated alert becomes an ignored one.
local REPEAT_AFTER = 600

local byVignette     -- vignette id      -> { points }
local byName         -- folded name      -> { points }
local byNpc          -- npc id           -> { points }, from Data/MobDrops.lua
local lastSeen = {}  -- key              -> when we announced it
local mountOfItem = {} -- item id -> mount id (false when the item is not a mount); never changes
-- What the GAME called each creature this session. A world boss gives loot once a week, and
-- the game says "worldboss" -- Wowhead does not help here: it files the Lich King, Kael'thas and
-- every other boss as plain elite.
local classeVista = {}
local frame

-- THE DIARY (`Log.lua`). One line per decision about a CANDIDATE -- a creature the drop table
-- knows, a rare, a vignette or a name the catalogue has -- never per nameplate: a city fires
-- hundreds. The same decision about the same creature is written once a minute at most; the
-- nameplate of a rare standing still re-fires the whole time, and without this the ring would
-- be swept by one creature and lose the line that explains it.
local TRACE_EVERY = 60
local lastTraced = {}
local function Trace(event, chave, data)
    if not (ns.Log and ns.Log.Add) then return end
    local motivo = data and data.reason or ""
    local k = event .. "|" .. tostring(chave) .. "|" .. tostring(motivo)
    local agora = GetTime and GetTime() or 0
    if lastTraced[k] and agora - lastTraced[k] < TRACE_EVERY then return end
    lastTraced[k] = agora
    pcall(ns.Log.Add, event, data)
end

-- A point is one place the catalogue puts one mount's rare: `{ entry, m, x, y }`. Carrying the
-- coordinates in the index is what lets the arrow point at the RARE instead of at the player.
-- A point from the Wowhead table carries `drop = { count, outof }` instead of coordinates:
-- that table knows who drops what and how often, but not where.

--------------------------------------------------------------------------------
-- The index: vignette and name -> the mounts you are missing
--------------------------------------------------------------------------------
local function Push(tabela, chave, ponto)
    if chave == nil or chave == "" then return end
    tabela[chave] = tabela[chave] or {}
    tabela[chave][#tabela[chave] + 1] = ponto
end

local function MountOfItem(item)
    local cached = mountOfItem[item]
    if cached ~= nil then return cached or nil end
    local id
    if C_MountJournal and C_MountJournal.GetMountFromItem then
        local ok, r = pcall(C_MountJournal.GetMountFromItem, item)
        id = ok and type(r) == "number" and r or nil
    end
    mountOfItem[item] = id or false
    return id
end

---(!) THE WOWHEAD TABLE IS WHAT KNOWS WHO DROPS WHAT. MCL ties Rootstalker Grimlynx to Rhazul
---alone; Wowhead records fifteen rares in Harandar dropping it. The table is keyed by npc id,
---read from the unit's GUID -- the same key SilverDragon uses, and it cannot be fooled by a name.
local function IndexarMobDrops(lista)
    if type(ns.MobDrops) ~= "table" then return end
    local porMontaria = {}
    for _, e in ipairs(lista) do
        if e.mountID and not e.unobtainable then porMontaria[e.mountID] = e end
    end
    for npc, rec in pairs(ns.MobDrops) do
        for _, d in ipairs(rec) do
            local e = d.count and d.count > 0 and porMontaria[MountOfItem(d.item)]
            if e then Push(byNpc, npc, { entry = e, drop = d }) end
        end
    end
end

---Rebuilt when the list changes, not on every event: a rare showing up is no time to walk four
---hundred mounts.
function Sighting.Rebuild()
    byVignette, byName, byNpc = {}, {}, {}
    if not ns.GetRanked then return end

    local ok, lista = pcall(ns.GetRanked)
    if not ok or type(lista) ~= "table" then return end
    IndexarMobDrops(lista)

    for _, e in ipairs(lista) do
        -- Only what can still be obtained: alerting about a mount that left the game is a taunt.
        if not e.unobtainable then
            local primeiro
            if e.coords then
                for _, wp in ipairs(e.coords) do
                    -- `dq` is the rare's daily tracking quest, when MCL knows it: see
                    -- `Sighting.LockedOut`.
                    local ponto = { entry = e, m = wp.m, x = wp.x, y = wp.y, dq = wp.dq }
                    primeiro = primeiro or ponto
                    -- `wp.v` IS THE VIGNETTE, and it is the good key: a number, identical in
                    -- every language, and it cannot collide with a pet's name.
                    if wp.v then Push(byVignette, wp.v, ponto) end
                    if wp.n then Push(byName, ns.Fold(wp.n), ponto) end
                end
            end
            -- `lockBossName` has no coordinates of its own, so it borrows the entry's first
            -- point. With no point at all it still goes in -- and the zone guard below will
            -- refuse it, which is the correct outcome: a place we cannot confirm is a place we
            -- do not claim.
            if e.bossName then
                Push(byName, ns.Fold(e.bossName), primeiro
                    or { entry = e, m = nil, x = nil, y = nil })
            end
        end
    end
    if ns.Log then
        local function Conta(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end
        pcall(ns.Log.Add, "rebuild", {
            missing = #lista, npcs = Conta(byNpc), vignettes = Conta(byVignette),
            names = Conta(byName), table = type(ns.MobDrops) == "table" and Conta(ns.MobDrops) or 0,
        })
    end
end

--------------------------------------------------------------------------------
-- The guards
--------------------------------------------------------------------------------
-- The GUID types that are a creature in the world. A player's pet is `Pet`, a totem is
-- `GameObject`, and neither can ever be a rare -- so neither gets in here.
local TIPO_DE_CRIATURA = { Creature = true, Vehicle = true }

---The npc id inside a creature GUID (`Creature-0-server-instance-zone-NPC-spawn`), or nil for
---anything that is not a creature. A secret GUID is refused before any string call touches it:
---identity can be hidden in some contexts (`C_Secrets.ShouldUnitIdentityBeSecret`).
function Sighting.NpcOfGUID(guid)
    if type(guid) ~= "string" then return nil end
    if issecretvalue and issecretvalue(guid) then return nil end
    local tipo, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    if not TIPO_DE_CRIATURA[tipo] then return nil end
    return tonumber(id)
end

---The name of a unit, but only when it is something that could actually be a rare.
---
---Two checks, both copied from SilverDragon because both earn their place:
---
---  * the GUID says `Creature`/`Vehicle`. This is what keeps a hunter pet named after a rare
---    out, and it does so structurally -- no list of names to maintain.
---  * `UnitClassification` says `rare`/`rareelite`. This is the game itself saying "this is a
---    rare", which no amount of catalogue reading can replace.
---@return string|nil
local function NomeDeRaro(unit)
    if not unit or not UnitExists or not UnitExists(unit) then return nil end
    if UnitIsPlayer and UnitIsPlayer(unit) then return nil end
    if UnitIsDead and UnitIsDead(unit) then return nil end

    local ok, guid = pcall(UnitGUID, unit)
    local npc = Sighting.NpcOfGUID(ok and guid)
    if not npc then return nil end

    -- (!) THE CLASSIFICATION GUARD IS FOR THE NAME, NOT FOR THE ID. A creature whose npc id is
    -- in the drop table is recognised exactly, whatever it is -- an elite, a world boss, the
    -- trash in Ahn'Qiraj that drops the Qiraji tanks. Only the name path, which can be fooled,
    -- still demands that the game call it a rare.
    local classe = UnitClassification and UnitClassification(unit)
    if byNpc and byNpc[npc] then
        classeVista[npc] = classe
        return UnitName(unit), npc
    end
    if classe ~= "rare" and classe ~= "rareelite" then return nil end

    return UnitName(unit), npc
end

---The map the player is standing on, or nil when the client will not say.
local function MapaAtual()
    if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
    return ok and id or nil
end

---(!) THE ZONE GUARD, and it is the one that would have stopped the Silvermoon alert on its
---own. A name match only counts when the player is standing where the catalogue puts that rare.
---
---A point with no map of its own cannot be confirmed, so it is refused -- the same rule this
---addon applies everywhere else: absence of data is not permission.
local function NoMapaCerto(pontos, mapa)
    if not pontos or not mapa then return nil end
    local ok
    for _, p in ipairs(pontos) do
        if p.m and p.m == mapa then
            ok = ok or {}
            ok[#ok + 1] = p
        end
    end
    return ok
end

--------------------------------------------------------------------------------
-- The panel
--------------------------------------------------------------------------------
-- The panel's geometry. Every row hangs from the panel's TOP, so the mount name and its chance
-- use the same arithmetic and cannot drift apart as the panel grows.
local WIDTH      = 300
local PAD        = 8
local ICON       = 48
local TEXT_X     = PAD + ICON + 10
local ROW_STEP   = 14
local MAX_ROWS   = 3                      -- plus one for "and N more"
local ODDS_WIDTH = 56
local NAME_WIDTH = WIDTH - TEXT_X - PAD - ODDS_WIDTH - 6

local function Build()
    if frame then return frame end

    frame = CreateFrame("Frame", ADDON .. "Sighting", UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, 64)
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)

    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
        })
        frame:SetBackdropColor(0.04, 0.04, 0.05, 0.92)
        frame:SetBackdropBorderColor(1, 0.82, 0, 0.6)
    end

    local pos = ns.db and ns.db.sightingPos
    if pos then
        frame:SetPoint(pos.point or "TOP", UIParent, pos.point or "TOP", pos.x or 0, pos.y or -180)
    else
        frame:SetPoint("TOP", UIParent, "TOP", 0, -180)
    end

    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        if ns.db then ns.db.sightingPos = { point = point, x = x, y = y } end
    end)

    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(ICON, ICON)
    frame.icon:SetPoint("TOPLEFT", PAD, -PAD)
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    frame.who = ns.NewText(frame, ns.Skin.rowFontSize, ns.Skin.gold)
    frame.who:SetPoint("TOPLEFT", frame.icon, "TOPRIGHT", 10, -2)
    frame.who:SetWidth(WIDTH - TEXT_X - PAD)
    frame.who:SetWordWrap(false)

    -- One row per mount: the name on the left, the chance right-aligned. Two single-line
    -- strings per row rather than two multi-line blocks side by side: a long name that wrapped
    -- in one block would push every chance in the other out of line with its mount.
    frame.rows = {}
    for i = 1, MAX_ROWS + 1 do
        local y = -PAD - 20 - (i - 1) * ROW_STEP
        local name = ns.NewText(frame, ns.Skin.subFontSize, ns.Skin.text)
        name:SetPoint("TOPLEFT", frame, "TOPLEFT", TEXT_X, y)
        name:SetWidth(NAME_WIDTH)
        name:SetWordWrap(false)
        name:SetJustifyH("LEFT")
        local odds = ns.NewText(frame, ns.Skin.subFontSize, ns.Skin.text)
        odds:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, y)
        odds:SetWidth(ODDS_WIDTH)
        odds:SetWordWrap(false)
        odds:SetJustifyH("RIGHT")
        frame.rows[i] = { name = name, odds = odds }
    end

    frame:SetScript("OnMouseUp", function(self) self:Hide() end)
    frame:Hide()
    return frame
end

-- (!) TWENTY-FIVE SECONDS, NOT TWELVE. The player's words: *"o aviso, o quadro, sai muito
-- rapido"* -- he could not even get a screenshot of it. Twelve seconds assumes you are looking
-- at the panel when it opens; in practice it opens while you are fighting, flying or loading
-- into the world, and a good part of the twelve is gone before you glance at it.
--
-- It still goes away on its own, because an alert that stays becomes scenery and stops being
-- read. Clicking it still dismisses it early.
local HOLD = 25

---"1/910", or a percentage when the chance is better than 1 in 10.
---
---Wowhead's numbers are samples, not Blizzard's rates, so they are rounded to two significant
---figures -- 6391/7 is "1/910", not a precise-looking "1/913" -- and marked "~" when fewer than
---ten drops were seen, which is where the estimate is roughest.
function Sighting.ChanceText(ponto)
    local n, rough
    local d = ponto and ponto.drop
    if d and d.count and d.count > 0 and d.outof and d.outof > 0 then
        n, rough = d.outof / d.count, d.count < 10
    elseif ponto and ponto.entry and ponto.entry.chance and ponto.entry.chance > 0 then
        n = ponto.entry.chance
    else
        return nil
    end
    local text
    if n < 10 then
        text = string.format("%d%%", math.floor(100 / n + 0.5))
    else
        local mag = 10 ^ (math.floor(math.log10(n)) - 1)
        text = "1/" .. string.format("%d", math.floor(n / mag + 0.5) * mag)
    end
    return rough and ("~" .. text) or text
end

---One point per mount. When two sources know the same mount, the one with a drop count wins
---the chance and the one with coordinates wins the arrow.
local function PorMontaria(pontos)
    local vistas, lista = {}, {}
    for _, p in ipairs(pontos) do
        local atual = vistas[p.entry]
        if not atual then
            atual = { entry = p.entry }
            vistas[p.entry] = atual
            lista[#lista + 1] = atual
        end
        atual.drop = atual.drop or p.drop
        if not atual.m and p.m then atual.m, atual.x, atual.y = p.m, p.x, p.y end
    end
    return lista
end

local function Show(nome, montarias)
    Build()
    frame.icon:SetTexture(montarias[1] and montarias[1].entry.icon)
    frame.who:SetText(nome)

    local linhas = math.min(#montarias, MAX_ROWS)
    for i, row in ipairs(frame.rows) do
        local m = montarias[i]
        if i <= math.min(#montarias, MAX_ROWS) then
            row.name:SetText(m.entry.name)
            row.odds:SetText(Sighting.ChanceText(m) or "")
        elseif i == MAX_ROWS + 1 and #montarias > MAX_ROWS then
            row.name:SetText(string.format(L["and %d more"], #montarias - MAX_ROWS))
            row.odds:SetText("")
            linhas = linhas + 1
        else
            row.name:SetText("")
            row.odds:SetText("")
        end
    end
    frame:SetHeight(math.max(64, PAD + 20 + ROW_STEP * linhas + PAD))

    frame:Show()
    -- Guarded BY TYPE: in the harness's simulator any unknown field answers a function, which
    -- is truthy, and then `:Cancel()` tries to index a function.
    if type(frame.__hide) == "table" and frame.__hide.Cancel then frame.__hide:Cancel() end
    if C_Timer and C_Timer.NewTimer then
        frame.__hide = C_Timer.NewTimer(HOLD, function() frame:Hide() end)
    end
end

--------------------------------------------------------------------------------
-- The chat link
--------------------------------------------------------------------------------
-- (!) THE ARROW POINTS AT THE RARE, NOT AT YOUR FEET.
--
-- It used to build the link from `GetPlayerMapPosition("player")`, so clicking it dropped a pin
-- wherever the player happened to be standing -- and then said *"seta apontada para onde você
-- viu"* with total confidence. In the Silvermoon report that pin landed in the capital, for a
-- rare that lives in another zone, while the rare's real coordinates were sitting in the very
-- record the alert came from.
--
-- `SetItemRef` is the funnel for EVERY link click in the game; the hook recognises our prefix
-- and lets everything else through untouched.
local LINK_PREFIX = "rocketmount"

---@param ponto table `{ m, x, y }` -- the rare's place, in the catalogue's 0-100 coordinates
local function ChatLink(ponto)
    if not (ponto and ponto.m and ponto.x and ponto.y) then return nil end
    -- Stored as ten-thousandths of the map, which is what `UiMapPoint` wants back as a
    -- fraction. The catalogue speaks in 0-100, hence the factor of 100.
    return string.format("|cff71d5ff|H%s:%d:%d:%d|h[%s]|h|r", LINK_PREFIX, ponto.m,
        math.floor(ponto.x * 100), math.floor(ponto.y * 100), L["point me at this rare"])
end

function Sighting.HandleLink(link)
    if type(link) ~= "string" then return false end
    local mapID, x, y = link:match("^" .. LINK_PREFIX .. ":(%d+):(%d+):(%d+)$")
    if not mapID then return false end
    mapID, x, y = tonumber(mapID), tonumber(x) / 10000, tonumber(y) / 10000

    if C_Map and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(mapID) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end
        ns.Print(string.format(L["arrow pointed at %s."], L["the rare"]))
    else
        ns.Print(L["this map does not accept pins."])
    end
    return true
end

--------------------------------------------------------------------------------
-- Announcing
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- The loot lockout
--
-- (!) A RARE YOU ALREADY LOOTED TODAY DROPS NOTHING. Most rares give loot once per day per
-- character (world bosses once per week); after that they respawn and die as often as you like,
-- and the loot window stays empty. The user's words: "se der respawn eu não posso avisar de
-- novo, por que o jogador já matou ele e não vai dropar nada".
--
-- Two sources, strongest first:
--
--   1. THE GAME'S OWN FLAG. MCL's catalogue carries, for 142 rares, the hidden daily tracking
--      quest (`dq`) the game completes when you get the day's credit -- the same thing MCL uses
--      to grey out its pins (`MCL_Guide.lua`, `GetWaypointState`). Exact, and it knows about a
--      kill made before this addon was installed.
--   2. OUR OWN RECORD, for every other creature. When a loot window opens, `GetLootSourceInfo`
--      says which corpse each item came from (Wowhead's own Looter reads it the same way); the
--      npc is written down for this character until the next daily reset -- weekly for a boss.
--      It is a heuristic: a very old rare with no lockout at all would be silenced until the
--      reset. Silence is the cheap mistake here; an alert for a rare that cannot drop anything
--      is the one the user reported.
--------------------------------------------------------------------------------

local function CharKey()
    local name = UnitName and UnitName("player")
    if not name then return nil end
    return name .. "-" .. (GetRealmName and GetRealmName() or "")
end

local function Registro()
    if not ns.db then return nil end
    local chave = CharKey()
    if not chave then return nil end
    ns.db.looted = ns.db.looted or {}
    ns.db.looted[chave] = ns.db.looted[chave] or {}
    return ns.db.looted[chave]
end

local function SegundosAteReset(semanal)
    local f = C_DateAndTime and (semanal and C_DateAndTime.GetSecondsUntilWeeklyReset
        or C_DateAndTime.GetSecondsUntilDailyReset)
    local ok, s = pcall(f or error)
    return ok and type(s) == "number" and s or 24 * 3600
end

---Write down what this loot window came from. Only creatures in the drop table: recording every
---boar the player skins would grow the saved file for nothing.
function Sighting.RecordLoot()
    if not (GetNumLootItems and GetLootSourceInfo and type(ns.MobDrops) == "table") then return end
    local reg = Registro()
    if not reg then return end
    local agora = time and time() or 0
    local okN, n = pcall(GetNumLootItems)
    local anotados = {}
    for slot = 1, (okN and n or 0) do
        local fontes = { pcall(GetLootSourceInfo, slot) }
        -- `GetLootSourceInfo` answers (guid, quantity) pairs, one per corpse the slot came from.
        for i = 2, #fontes, 2 do
            local npc = Sighting.NpcOfGUID(fontes[i])
            local rec = npc and ns.MobDrops[npc]
            if rec and not anotados[npc] then
                anotados[npc] = true
                local semanal = classeVista[npc] == "worldboss"
                reg[npc] = agora + SegundosAteReset(semanal)
                if ns.Log then
                    pcall(ns.Log.Add, "loot", {
                        npc = npc, name = rec.name, class = classeVista[npc] or "unseen",
                        lockout = semanal and "weekly" or "daily",
                        untilIn = reg[npc] - agora,
                    })
                end
            end
        end
    end
end

---True when this rare cannot drop anything for this character right now.
---@return boolean locked, string|nil source ("dq:<quest>" or "loot"), number|nil secondsLeft
function Sighting.LockedOut(npc, pontos)
    for _, p in ipairs(pontos or {}) do
        if p.dq and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
            local ok, feito = pcall(C_QuestLog.IsQuestFlaggedCompleted, p.dq)
            if ok and feito then return true, "dq:" .. tostring(p.dq) end
        end
    end
    if npc then
        local reg = Registro()
        local ate = reg and reg[npc]
        if ate then
            local agora = time and time() or 0
            if agora < ate then return true, "loot", ate - agora end
            reg[npc] = nil     -- the reset came: forget it, and keep the file small
        end
    end
    return false
end

---@return boolean announced, string|nil reason, number|nil secondsAgo
local function Announce(chave, nome, pontos, onde)
    if not ns.db or ns.db.sightings == false then return false, "off" end
    if not pontos or #pontos == 0 then return false, "no-missing-mount" end

    local agora = GetTime and GetTime() or 0
    if lastSeen[chave] and (agora - lastSeen[chave]) < REPEAT_AFTER then
        return false, "repeat", math.floor(agora - lastSeen[chave])
    end
    lastSeen[chave] = agora

    local montarias = PorMontaria(pontos)
    Show(nome, montarias)

    local partes = {}
    for i = 1, math.min(#montarias, MAX_ROWS) do
        local m = montarias[i]
        local chance = Sighting.ChanceText(m)
        partes[#partes + 1] = chance and string.format("%s (%s)", m.entry.name, chance) or m.entry.name
    end
    -- Where the rare IS beats where the catalogue says it spawns: a live vignette position
    -- first, the catalogue's point second.
    local alvo = onde
    if not alvo then
        for _, m in ipairs(montarias) do
            if m.m then alvo = m; break end
        end
    end
    local link = ChatLink(alvo)
    ns.Print(string.format(L["|cffffff00%s|r can drop: %s%s"], nome,
        table.concat(partes, ", "), link and ("  " .. link) or ""))
    return true
end

---Every way of recognising a rare ends here, so that one rare seen three ways -- vignette,
---nameplate, target -- is ONE alert, keyed by the strongest identity available.
---
---  npc       from a GUID: exact, and the key of the Wowhead table;
---  vignette  from the minimap: exact, the key of MCL's pins;
---  name      the fallback, and only inside the zone guard.
---(!) OPEN WORLD ONLY. The user: "os avisos são para áreas abertas, dentro de dungeons e raids
---não precisa do aviso". Inside an instance you already know what you came for, and a boss's
---mount is on the dungeon journal. `IsInInstance` is true in dungeons, raids, delves,
---scenarios, battlegrounds and arenas -- the same test SilverDragon applies (`core.lua:853`).
function Sighting.InOpenWorld()
    if not IsInInstance then return true end
    local ok, dentro = pcall(IsInInstance)
    return not (ok and dentro)
end

function Sighting.Sight(npc, vignetteID, nome, mapa, onde, via)
    if not Sighting.InOpenWorld() then return false end
    -- (!) ONLY MOUNTS YOU DO NOT HAVE. Learning a mount marks the list dirty and nothing more,
    -- so with the window closed this index kept the old list: kill a rare, loot its mount, see
    -- the next one, and the alert offered you the mount you had just learned. A dirty list is
    -- rebuilt here, before answering; `GetRanked` rebuilds this index itself via `MarkClean`.
    if ns.IsDirty and ns.IsDirty() and ns.GetRanked then
        pcall(ns.GetRanked)
    end
    if not byNpc then Sighting.Rebuild() end
    local pontos = {}
    local function Somar(lista)
        for _, p in ipairs(lista or {}) do pontos[#pontos + 1] = p end
    end
    if npc then Somar(byNpc[npc]) end
    if vignetteID then Somar(byVignette[vignetteID]) end
    local dobrado = nome and ns.Fold(nome) or ""
    if dobrado ~= "" then Somar(NoMapaCerto(byName[dobrado], mapa or MapaAtual())) end

    local chave = (npc and "npc:" .. npc) or (vignetteID and "v:" .. tostring(vignetteID))
        or ("n:" .. dobrado)

    -- Only a CANDIDATE gets a line: something in a table of ours, or a unit the game calls rare.
    -- Every vignette on the minimap (treasures, quests) and every yell would bury the rest.
    local conhecido = npc and type(ns.MobDrops) == "table" and ns.MobDrops[npc] ~= nil
    local candidato = #pontos > 0 or conhecido or (via and via:find("unit", 1, true))
        or (dobrado ~= "" and byName[dobrado] ~= nil)
    local base
    if candidato then
        base = { via = via or "direct", npc = npc, vignette = vignetteID, name = nome,
                 map = MapaAtual(), class = npc and classeVista[npc], known = conhecido or nil }
    end

    local preso, fonte, falta = Sighting.LockedOut(npc, pontos)
    if preso then
        if base then
            base.reason, base.lockout, base.untilIn = "looted", fonte, falta
            Trace("silent", chave, base)
        end
        return false
    end

    local ok, motivo, haQuanto = Announce(chave, nome or "?", pontos, onde)
    if base then
        if ok then
            local ms = {}
            for _, m in ipairs(PorMontaria(pontos)) do
                ms[#ms + 1] = tostring(m.entry.name) .. " " .. tostring(Sighting.ChanceText(m) or "?")
            end
            base.mounts = table.concat(ms, "; ")
            pcall(ns.Log.Add, "alert", base)
        else
            -- A name the catalogue knows, refused by the zone guard: say so, it is the one
            -- silence that looks like a bug.
            if motivo == "no-missing-mount" and dobrado ~= "" and byName[dobrado] and not conhecido then
                motivo = "wrong-zone"
            elseif motivo == "no-missing-mount" and not conhecido and not vignetteID then
                motivo = "not-in-table"
            end
            base.reason, base.ago = motivo, haQuanto
            Trace("silent", chave, base)
        end
    end
    return ok
end

---A vignette the minimap is showing. The precise path: the id is a number and means the same
---thing in every language, so no zone guard is needed -- a vignette you can see is, by
---definition, near you.
function Sighting.SightVignette(vignetteID, nome, npc, onde)
    return Sighting.Sight(npc, vignetteID, nome, nil, onde, "vignette")
end

---A name, from a unit or from a yell. The fallback path, and the one that needs the zone guard:
---a name on its own proves nothing.
function Sighting.SightName(nome, mapa, via)
    if (nome or "") == "" then return false end
    return Sighting.Sight(nil, nil, nome, mapa, nil, via or "name")
end

--------------------------------------------------------------------------------
-- Detection
--------------------------------------------------------------------------------
---Where a vignette is right now, in the catalogue's 0-100 scale, so the arrow points at the
---rare you are flying past rather than at one of its spawn points.
local function PosicaoDaVinheta(guid)
    local mapa = MapaAtual()
    if not (mapa and C_VignetteInfo.GetVignettePosition) then return nil end
    local ok, pos = pcall(C_VignetteInfo.GetVignettePosition, guid, mapa)
    if not ok or type(pos) ~= "table" or not pos.x then return nil end
    return { m = mapa, x = pos.x * 100, y = pos.y * 100 }
end

local function VarrerVinhetas()
    if not (C_VignetteInfo and C_VignetteInfo.GetVignettes) then return end
    local ok, lista = pcall(C_VignetteInfo.GetVignettes)
    if not ok or type(lista) ~= "table" then return end
    for _, guid in ipairs(lista) do
        local okI, info = pcall(C_VignetteInfo.GetVignetteInfo, guid)
        if okI and type(info) == "table" and info.vignetteID then
            -- A rare's vignette carries the creature's own GUID: that is the npc id, from as
            -- far away as the minimap reaches -- which is what makes the alert work in flight.
            local npc = Sighting.NpcOfGUID(info.objectGUID)
            Sighting.SightVignette(info.vignetteID, info.name, npc, PosicaoDaVinheta(guid))
        end
    end
end

function Sighting.OnEvent(_, event, arg1, arg2)
    -- The loot is recorded even with the alert off: turning it back on later must not bring
    -- back an alert for a rare already looted today.
    if event == "LOOT_OPENED" then
        Sighting.RecordLoot()
        return
    end
    if not ns.db or ns.db.sightings == false then return end
    -- Checked here too, before any work: inside a raid the nameplate events never stop.
    if not Sighting.InOpenWorld() then return end

    if event == "VIGNETTE_MINIMAP_UPDATED" or event == "VIGNETTES_UPDATED" then
        VarrerVinhetas()
        return
    end

    -- (!) THE YELL NO LONGER ANNOUNCES ON ITS OWN. It used to be the best clue -- it arrives the
    -- instant a rare spawns and carries further than a nameplate. But `arg2` is just a name, with
    -- no unit behind it to classify, so it is the weakest evidence there is. It now goes through
    -- the same zone guard as everything else, which is what makes it safe to keep.
    if event == "CHAT_MSG_MONSTER_YELL" or event == "CHAT_MSG_MONSTER_EMOTE" then
        Sighting.SightName(arg2, nil, "yell")
        return
    end

    local unit = arg1
    if event == "UPDATE_MOUSEOVER_UNIT" then unit = "mouseover" end
    if event == "PLAYER_TARGET_CHANGED" then unit = "target" end

    local nome, npc = NomeDeRaro(unit)
    if nome then Sighting.Sight(npc, nil, nome, nil, nil, "unit:" .. tostring(unit)) end
end

function Sighting.Enable()
    if frame and frame.__events then return end
    Build()
    frame.__events = CreateFrame("Frame", ADDON .. "SightingEvents")
    for _, event in ipairs({
        "NAME_PLATE_UNIT_ADDED", "UPDATE_MOUSEOVER_UNIT", "PLAYER_TARGET_CHANGED",
        "CHAT_MSG_MONSTER_YELL", "CHAT_MSG_MONSTER_EMOTE",
        "VIGNETTE_MINIMAP_UPDATED", "VIGNETTES_UPDATED", "LOOT_OPENED",
    }) do
        pcall(frame.__events.RegisterEvent, frame.__events, event)
    end
    frame.__events:SetScript("OnEvent", Sighting.OnEvent)

    if not Sighting.__hooked and hooksecurefunc then
        hooksecurefunc("SetItemRef", function(link)
            Sighting.HandleLink(link)
        end)
        Sighting.__hooked = true
    end
end
