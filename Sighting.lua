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

local byName         -- folded name      -> { points }
local byNpc          -- npc id           -> { points }, from Data/MobDrops.lua
local lastSeen = {}  -- key              -> when we announced it
local mountOfItem = {} -- item id -> mount id, once the game has said which; never changes
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

-- (!) A "NO" IS NOT KEPT (28/09). The diary of 28/09 has a session whose only index of creatures
-- came out with NONE of the 351 creatures of the table tied to a mount (`rebuild npcs=0`), when
-- every other session has 223. Whatever answered "no" at that moment, the "no" was written down
-- for the rest of the session: no rare on any map, no sighting. An answer that is a mount is the
-- game's and does not change; an answer that is nothing is asked again at the next index.
local function MountOfItem(item)
    local cached = mountOfItem[item]
    if cached then return cached end
    local id
    if C_MountJournal and C_MountJournal.GetMountFromItem then
        local ok, r = pcall(C_MountJournal.GetMountFromItem, item)
        id = ok and type(r) == "number" and r or nil
    end
    if id then mountOfItem[item] = id end
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
        -- A line that is not what the collector writes is skipped, not tripped over.
        for _, d in ipairs(type(rec) == "table" and rec or {}) do
            local n = type(d) == "table" and tonumber(d.count)
            -- `unknown`: the game's journal names this creature and no drop was recorded yet.
            -- It is still the creature to look for; what is not known is how often.
            local larga = (n and n > 0) or (type(d) == "table" and d.unknown == true)
            local e = larga and d.item and porMontaria[MountOfItem(d.item)]
            if e then
                Push(byNpc, npc, { entry = e, drop = d })
                -- BY NAME TOO, for what arrives without a GUID (a yell): the name the table
                -- has, with the place the creature lives at -- one point per map, which is
                -- what the zone guard asks for. A creature the table cannot place goes in
                -- without a place, and the guard refuses it.
                if type(rec.name) == "string" and rec.name ~= "" then
                    local chave, posto = ns.Fold(rec.name), false
                    for mapa, pts in pairs(type(rec.where) == "table" and rec.where or {}) do
                        if type(pts) == "table" and pts[1] and pts[2] then
                            Push(byName, chave, { entry = e, drop = d, npc = npc, m = mapa, x = pts[1], y = pts[2] })
                            posto = true
                        end
                    end
                    if not posto then Push(byName, chave, { entry = e, drop = d, npc = npc }) end
                end
            end
        end
    end
end

---Rebuilt when the list changes, not on every event: a rare showing up is no time to walk four
---hundred mounts.
function Sighting.Rebuild()
    byName, byNpc = {}, {}
    if not ns.GetRanked then return end

    local ok, lista = pcall(ns.GetRanked)
    if not ok or type(lista) ~= "table" then return end
    IndexarMobDrops(lista)

    for _, e in ipairs(lista) do
        -- Only what can still be obtained: alerting about a mount that left the game is a taunt.
        if not e.unobtainable then
            -- (28/09) The places of a mount are vendors, chests and quest givers now: none of
            -- them is a creature to be sighted. The creatures are the table's (IndexarMobDrops).
            -- A boss is known by name too, and with no place of its own the zone guard below
            -- refuses it -- a place we cannot confirm is a place we do not claim.
            if e.bossName then
                Push(byName, ns.Fold(e.bossName), { entry = e, m = nil, x = nil, y = nil })
            end
        end
    end
    if ns.Log then
        local function Conta(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end
        pcall(ns.Log.Add, "rebuild", {
            missing = #lista, npcs = Conta(byNpc),
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
        -- The name in the player's language, for the world-map tooltip: the table only has
        -- Wowhead's English one. Kept for this character's account, and only for our creatures.
        if ns.db then
            ns.db.npcNames = ns.db.npcNames or {}
            local okN, nomeLocal = pcall(UnitName, unit)
            if okN and type(nomeLocal) == "string" and not (issecretvalue and issecretvalue(nomeLocal)) then
                ns.db.npcNames[npc] = nomeLocal
            end
        end
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
-- The alert
--
-- (!) THE GAME'S OWN TOAST (27/09). This was a panel painted by hand -- a flat dark backdrop with
-- a one-pixel gold edge -- and the user, with MCL's "rare spotted" banner beside it: *"deixar algo
-- semelhante mas com skin da blizzard"*. What Blizzard shows when a mount is concerned is the
-- new-mount alert (`NewMountAlertFrameTemplate`, AlertFrameSystems.xml, 12.1.0): the leather
-- band, the icon in the item border of its quality, a small gold line and the name under it.
-- This is that frame, piece by piece and number by number, with our content in it:
--
--   the gold line   who is in front of you
--   the name        the mount that is likeliest to drop from it, in the colour of its quality
--   the last line   the chance, how many more it can drop, how often the loot comes back
--
-- The whole list -- every mount, each chance, the lockout -- is one mouse-over away, in the
-- game's tooltip: the same one the world-map pin shows (MapPins.Tooltip), so the alert and the
-- map cannot say different things. A click points the map arrow at the rare, as MCL's does; the
-- right button sends the alert away.
--
-- The template itself cannot be inherited: it is a `ContainedAlertFrame`, owned by the game's
-- alert queue, which shows and hides it on its own schedule. The parts are created here.
--------------------------------------------------------------------------------
-- ItemAlertFrameTemplate: the frame, the icon at LEFT 23,-2, its border, the two text lines.
local TOAST_W, TOAST_H = 276, 96
local ICON, ICON_X, ICON_Y = 52, 23, -2
local BORDER = 60
local TEXT_W = 167
local LABEL_X, LABEL_Y, LABEL_H = 7, 5, 16       -- from the icon's TOPRIGHT
local NAME_X, NAME_Y, NAME_H = 10, -16, 16
-- Ours: Blizzard's name box is 33 tall, for a name that wraps to two lines. A mount's name is
-- kept to one, and the second line of that box carries the numbers.
local SUB_Y, SUB_H = -33, 14

Sighting.Geometry = {
    WIDTH = TOAST_W, HEIGHT = TOAST_H, ICON = ICON, ICON_X = ICON_X, BORDER = BORDER,
    TEXT = TEXT_W, TEXT_X = NAME_X, TEXT_TOP = LABEL_Y, TEXT_BOTTOM = SUB_Y - SUB_H,
    -- Blizzard's own text box: the label starts 5 above the icon, the name box ends 49 below
    -- its top (16 + 33). Ours has to stay inside it.
    NATIVE_TOP = 5, NATIVE_BOTTOM = -49,
}

-- (!) TWENTY-FIVE SECONDS, NOT TWELVE. The player's words: *"o aviso, o quadro, sai muito
-- rapido"* -- he could not even get a screenshot of it. Twelve seconds assumes you are looking
-- at the panel when it opens; in practice it opens while you are fighting, flying or loading
-- into the world, and a good part of the twelve is gone before you glance at it.
--
-- It still goes away on its own, because an alert that stays becomes scenery and stops being
-- read. The mouse over it holds it (the game's own alerts do the same), and it leaves a little
-- after the mouse does.
local HOLD = 25
local HOLD_AFTER_HOVER = 6

-- Mounts have no quality of their own and the game always shows them as epic
-- (`NewMountAlertFrameMixin:SetUp`).
local EPIC_BORDER = "loottoast-itemborder-purple"
local EPIC_HEX = "|cffa335ee"

local function CancelHide()
    local t = rawget(frame, "__hide")
    if type(t) == "table" and t.Cancel then t:Cancel() end
    frame.__hide = nil
end

local function HideLater(segundos)
    CancelHide()
    if C_Timer and C_Timer.NewTimer then
        frame.__hide = C_Timer.NewTimer(segundos, function() frame:Hide() end)
    end
end

local function Build()
    if frame then return frame end

    frame = CreateFrame("Button", ADDON .. "Sighting", UIParent)
    frame:SetSize(TOAST_W, TOAST_H)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    frame:SetClampedToScreen(true)

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

    frame.Background = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    frame.Background:SetAtlas("MountToast-Background", true)
    frame.Background:SetPoint("CENTER")

    frame.Icon = frame:CreateTexture(nil, "BORDER")
    frame.Icon:SetSize(ICON, ICON)
    frame.Icon:SetPoint("LEFT", ICON_X, ICON_Y)

    frame.IconBorder = frame:CreateTexture(nil, "ARTWORK")
    frame.IconBorder:SetAtlas(EPIC_BORDER)
    frame.IconBorder:SetSize(BORDER, BORDER)
    frame.IconBorder:SetPoint("CENTER", frame.Icon, "CENTER", 0, 0)

    frame.Label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.Label:SetSize(TEXT_W, LABEL_H)
    frame.Label:SetJustifyH("LEFT")
    frame.Label:SetWordWrap(false)
    frame.Label:SetPoint("TOPLEFT", frame.Icon, "TOPRIGHT", LABEL_X, LABEL_Y)

    frame.Name = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalMed3")
    frame.Name:SetSize(TEXT_W, NAME_H)
    frame.Name:SetJustifyH("LEFT")
    frame.Name:SetWordWrap(false)
    frame.Name:SetPoint("TOPLEFT", frame.Icon, "TOPRIGHT", NAME_X, NAME_Y)

    frame.Sub = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.Sub:SetSize(TEXT_W, SUB_H)
    frame.Sub:SetJustifyH("LEFT")
    frame.Sub:SetWordWrap(false)
    frame.Sub:SetPoint("TOPLEFT", frame.Icon, "TOPRIGHT", NAME_X, SUB_Y)

    frame:SetScript("OnEnter", function(self)
        CancelHide()
        local d = rawget(self, "data")
        if d and ns.MapPins and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            ns.MapPins.Tooltip(GameTooltip, d)
            GameTooltip:Show()
        end
    end)
    frame:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
        HideLater(HOLD_AFTER_HOVER)
    end)
    frame:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            self:Hide()
            return
        end
        Sighting.PointAt(rawget(self, "target"))
    end)
    frame:SetScript("OnHide", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    frame:Hide()
    return frame
end

---The chance as a percentage (`ns.FormatChance`, in Score.lua).
---
---Wowhead's numbers are samples, not Blizzard's rates: two significant figures -- 7 in 6391 is
---"0.11%", not a precise-looking "0.1095%" -- and "~" when fewer than ten drops were seen, which
---is where the estimate is roughest.
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
    return ns.FormatChance(n, rough)
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

---How likely a mount is from this creature, as a number, to put the likeliest first.
local function Chance(m)
    local d = m.drop
    if d and d.count and d.outof and d.outof > 0 then return d.count / d.outof end
    local c = m.entry and m.entry.chance
    return (c and c > 0) and (1 / c) or 0
end

---@param nome string the creature, in the player's language
---@param montarias table list of `{ entry, drop }`
---@param frequencia string|nil how often the loot comes back, as the tooltip says it
---@param npc number|nil
---@param alvo table|nil `{ m, x, y }` in the catalogue's 0-100 scale: where a click points
local function Show(nome, montarias, frequencia, npc, alvo)
    Build()
    local lista = {}
    for i, m in ipairs(montarias) do lista[i] = m end
    table.sort(lista, function(a, b)
        local ca, cb = Chance(a), Chance(b)
        if ca ~= cb then return ca > cb end
        return (a.entry.name or "") < (b.entry.name or "")
    end)
    local primeira = lista[1]

    frame.Icon:SetTexture(primeira and primeira.entry.icon)
    frame.Label:SetText(nome)
    frame.Name:SetText(primeira and (EPIC_HEX .. (primeira.entry.name or "?") .. "|r") or "")

    -- The numbers, in the order they matter: the chance of the one named, how many more this
    -- creature can drop, how often it can be looted. Each part only when there is one.
    local partes = {}
    local chance = primeira and Sighting.ChanceText(primeira)
    if chance then partes[#partes + 1] = chance end
    if #lista > 1 then partes[#partes + 1] = string.format(L["and %d more"], #lista - 1) end
    if frequencia and frequencia ~= "" then partes[#partes + 1] = frequencia end
    frame.Sub:SetText(table.concat(partes, "  ·  "))

    -- What the tooltip and the click need.
    frame.target = alvo
    frame.data = {
        npc = npc, name = nome, mounts = lista,
        rec = (npc and type(ns.MobDrops) == "table" and ns.MobDrops[npc]) or { name = nome, c = 4 },
    }

    frame:Show()
    HideLater(HOLD)
end

function Sighting.GetPanel() return frame end

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

local function Apontar(mapID, x, y)
    if C_Map and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(mapID) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end
        ns.Print(string.format(L["arrow pointed at %s."], L["the rare"]))
    else
        ns.Print(L["this map does not accept pins."])
    end
end

function Sighting.HandleLink(link)
    if type(link) ~= "string" then return false end
    local mapID, x, y = link:match("^" .. LINK_PREFIX .. ":(%d+):(%d+):(%d+)$")
    if not mapID then return false end
    Apontar(tonumber(mapID), tonumber(x) / 10000, tonumber(y) / 10000)
    return true
end

---The click on the alert: the arrow goes to where the rare is (or spawns).
---@param ponto table|nil `{ m, x, y }` in the catalogue's 0-100 scale
---@return boolean pointed
function Sighting.PointAt(ponto)
    if not (ponto and ponto.m and ponto.x and ponto.y) then return false end
    Apontar(ponto.m, ponto.x / 100, ponto.y / 100)
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

--------------------------------------------------------------------------------
-- HOW OFTEN A RARE'S LOOT COMES BACK (25/09)
--
-- The user: *"posso tá indo matar o sha da raiva todo dia, mas ele é por semana, to indo em vão"*.
-- `Data/RareLockout.lua` has, for 143 rares, the hidden quest the game marks when you get the loot
-- (the quest that hides the rare's star on the map, from the game's own table) -- and for a few
-- of them how often it resets. Nothing in the client says how often a quest resets, so the rest
-- is LEARNED:
-- the quest is watched after a kill, and the reset that clears it gives the answer -- the daily
-- one means daily, surviving the daily and clearing at the weekly means weekly. What is learned is
-- written account-wide, so one character's kill teaches every other.
--
-- A rare with no known quest can still be learned "unlimited": looted twice inside what would have
-- been its lockout. Nothing known stays "not known yet" on screen -- never a guess.
--------------------------------------------------------------------------------
local function Aprendido()
    if not ns.db then return nil end
    ns.db.lockoutLearned = ns.db.lockoutLearned or {}
    return ns.db.lockoutLearned
end

local function Vigias()
    if not ns.db then return nil end
    local chave = CharKey()
    if not chave then return nil end
    ns.db.lockoutWatch = ns.db.lockoutWatch or {}
    ns.db.lockoutWatch[chave] = ns.db.lockoutWatch[chave] or {}
    return ns.db.lockoutWatch[chave]
end

---"daily", "weekly", "unlimited", "once" or nil, and where it came from ("data" or "learned").
function Sighting.LootFrequency(npc)
    local rl = npc and ns.RareLockout and ns.RareLockout[npc]
    if rl and rl.f then return rl.f, "data" end
    local ap = ns.db and ns.db.lockoutLearned
    if ap then
        if rl and ap[rl.q] then return ap[rl.q], "learned" end
        if npc and ap["npc:" .. npc] then return ap["npc:" .. npc], "learned" end
    end
    return nil
end

---The line the map tooltip and the alert show.
function Sighting.FrequencyText(npc)
    local f = Sighting.LootFrequency(npc)
    if f == "daily" then return L["Loot: once a day"] end
    if f == "weekly" then return L["Loot: once a week"] end
    if f == "unlimited" then return L["Loot: every kill"] end
    if f == "firstbest" then return L["Loot: every kill, best chance on the day's first"] end
    if f == "once" then return L["Loot: once per character"] end
    return L["Loot: how often is not known yet"]
end

---Start watching a tracking quest this character just completed, to learn its reset.
local function Vigiar(q)
    local ap, vig = Aprendido(), Vigias()
    if not (ap and vig) or ap[q] or vig[q] then return end
    local agora = time and time() or 0
    vig[q] = { d = agora + SegundosAteReset(false), w = agora + SegundosAteReset(true) }
end

---Looks at every watched quest: the first look after a reset decides. Runs at login, on a timer
---and after a loot.
function Sighting.LearnTick()
    local ap, vig = Aprendido(), Vigias()
    if not (ap and vig and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) then return end
    local agora = time and time() or 0
    for q, w in pairs(vig) do
        local ok, feito = pcall(C_QuestLog.IsQuestFlaggedCompleted, q)
        if ok then
            if not w.passouDia and agora >= w.d then
                if agora >= w.w then
                    vig[q] = nil          -- both resets went by unseen: cannot tell, watch again
                elseif not feito then
                    ap[q] = "daily"; vig[q] = nil
                else
                    w.passouDia = true    -- survived the daily reset: weekly or longer
                end
            elseif w.passouDia and agora >= w.w then
                ap[q] = feito and "once" or "weekly"
                vig[q] = nil
            end
        end
    end
end

---Write down what this loot window came from. Only creatures in the drop table: recording every
---boar the player skins would grow the saved file for nothing.
function Sighting.RecordLoot()
    -- The looted creature's pin goes dim right away.
    if ns.MapPins then C_Timer.After(0, ns.MapPins.Refresh) end
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
                local rl = ns.RareLockout and ns.RareLockout[npc]
                local ap = Aprendido()
                -- LOOTED AGAIN inside what was taken for its lockout, and no quest to say
                -- otherwise: this rare gives loot on every kill.
                if not rl and ap and reg[npc] and agora < reg[npc] then
                    ap["npc:" .. npc] = "unlimited"
                end
                if rl then Vigiar(rl.q) end
                local semanal = classeVista[npc] == "worldboss"
                    or Sighting.LootFrequency(npc) == "weekly"
                reg[npc] = agora + SegundosAteReset(semanal)
                if Sighting.LootFrequency(npc) == "unlimited" then reg[npc] = nil end
                if ns.Log then
                    pcall(ns.Log.Add, "loot", {
                        npc = npc, name = rec.name, class = classeVista[npc] or "unseen",
                        lockout = semanal and "weekly" or "daily",
                        untilIn = reg[npc] and (reg[npc] - agora) or 0,
                        frequency = Sighting.LootFrequency(npc) or "unknown",
                    })
                end
            end
        end
    end
end

---True when this rare cannot drop anything for this character right now.
---What one creature can still give THIS character: the mounts it drops that are missing, with
---the chance. The world-map pins ask this, so the map and the alert can never disagree.
---@return table list of `{ entry, drop }`, empty when it has nothing left for you
function Sighting.MountsOf(npc)
    if ns.IsDirty and ns.IsDirty() and ns.GetRanked then pcall(ns.GetRanked) end
    if not byNpc then Sighting.Rebuild() end
    return PorMontaria(byNpc[npc] or {})
end

---@return boolean locked, string|nil source ("dq:<quest>" or "loot"), number|nil secondsLeft
function Sighting.LockedOut(npc, pontos)
    -- THE RARE'S OWN QUEST, when known: the game answers, for any frequency. Not done means the
    -- loot is there, whatever this addon wrote down at the last kill.
    local rl = npc and ns.RareLockout and ns.RareLockout[npc]
    if rl and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        -- A MOUNT THAT DROPS ON EVERY KILL is never "already looted", whatever the rare's daily
        -- credit says: Huolon's quest 33311 is daily, and his mount drops on the second kill of the
        -- day (Data/RareLockout.lua, tools/coletar_lockout.py).
        local f0 = Sighting.LootFrequency(npc)
        if f0 == "unlimited" or f0 == "firstbest" then return false end
        local ok, feito = pcall(C_QuestLog.IsQuestFlaggedCompleted, rl.q)
        if ok then
            if not feito then return false end
            Vigiar(rl.q)
            local f = Sighting.LootFrequency(npc)
            local falta = (f == "daily" and SegundosAteReset(false))
                or (f == "weekly" and SegundosAteReset(true)) or nil
            return true, "q:" .. rl.q, falta
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
local function Announce(chave, nome, pontos, onde, npc)
    if not ns.db or ns.db.sightings == false then return false, "off" end
    if not pontos or #pontos == 0 then return false, "no-missing-mount" end

    local agora = GetTime and GetTime() or 0
    if lastSeen[chave] and (agora - lastSeen[chave]) < REPEAT_AFTER then
        return false, "repeat", math.floor(agora - lastSeen[chave])
    end
    lastSeen[chave] = agora

    local montarias = PorMontaria(pontos)
    local frequencia = Sighting.FrequencyText(npc)
    -- Where the rare IS beats where the catalogue says it spawns: a live vignette position
    -- first, the catalogue's point second, the drop table's first place on this map last.
    local alvo = onde
    if not alvo then
        for _, m in ipairs(montarias) do
            if m.m then alvo = m; break end
        end
    end
    if not alvo and npc and type(ns.MobDrops) == "table" and ns.MobDrops[npc] then
        local mapa = MapaAtual()
        local pts = mapa and ns.MobDrops[npc].where and ns.MobDrops[npc].where[mapa]
        if pts and pts[1] and pts[2] then alvo = { m = mapa, x = pts[1], y = pts[2] } end
    end
    Show(nome, montarias, frequencia, npc, alvo)

    -- The chat line names up to three; the alert's tooltip has them all.
    local partes = {}
    for i = 1, math.min(#montarias, 3) do
        local m = montarias[i]
        local chance = Sighting.ChanceText(m)
        partes[#partes + 1] = chance and string.format("%s (%s)", m.entry.name, chance) or m.entry.name
    end
    local link = ChatLink(alvo)
    ns.Print(string.format(L["|cffffff00%s|r can drop: %s%s"], nome,
        table.concat(partes, ", "), "  ·  " .. frequencia .. (link and ("  " .. link) or "")))
    return true
end

---Every way of recognising a rare ends here, so that one rare seen three ways -- vignette,
---nameplate, target -- is ONE alert, keyed by the strongest identity available.
---
---  npc       from a GUID (a unit's, or the one a vignette carries): exact, and the key of
---            the table of creatures;
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

    local ok, motivo, haQuanto = Announce(chave, nome or "?", pontos, onde, npc)
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
    -- The watched tracking quests are looked at now and every five minutes: the answer is the
    -- first look after a reset, and a player can sit through one without any event of ours.
    Sighting.LearnTick()
    if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(300, Sighting.LearnTick) end
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
