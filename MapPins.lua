-- RocketMount | MapPins.lua
-- Where the mounts you are missing come from, on the world map, with a tooltip.
--
-- The user (23/09): *"como o silverdragon mostra os raros/elites/world bosses no mapa, a gente
-- tbm mostrasse e com uma popup passando o mouse em cima, mostrando qual montaria dropa, a
-- chance"*. And on 27/09, with MCL's map beside ours: *"melhorar visualmente os icones no mapa,
-- seria copiar um pouco o que o MCL faz (...) o MCL mostra tanto as de vendors, drops, reputações,
-- raros e etc"* -- with one condition: *"o MCL tem uma skin dele, eu não quero deixar igual (...)
-- sempre vamos seguir o padrão de skin blizzard, o que tem de mais recente nativo dela"*.
--
-- So a pin is what MCL's is -- the MOUNT's icon, and what kind of source it is -- drawn the way
-- Blizzard draws a world quest: the marker disc, the icon inside it, the dragon around an elite,
-- a small glyph at the lower right (MapPins.xml). The tooltip is the game's own, written with the
-- game's own helpers, so it has the colours every other map tooltip has.
--
-- Built on the map's OWN pin system, the one Blizzard uses for its dig sites
-- (`DigSiteDataProvider.lua`, 12.1.0): a data provider added to `WorldMapFrame`, which acquires
-- one pin per place on the map being viewed. No library -- SilverDragon uses its own, and it
-- has no licence.
--
--   where   a PLACE: a creature's spawn point (`ns.MobDrops[npc].where`), a vendor, a chest
--           or a quest giver (`Data/MountPlaces.lua`), or the door of an instance, which the
--           game itself places on the map being viewed
--   what    the mounts THIS character is missing there, easiest first; for a creature it is
--           `Sighting.MountsOf(npc)`, the SAME index the alert uses, so the two never disagree
--   state   `Sighting.LockedOut`: looted today (or this week, for a world boss) goes dim
--   which   the map being viewed and the maps INSIDE it (a cave, a sub-zone), projected; on a
--           continent a creature is one pin, not one per spawn point
--   where not  instance maps (dungeons, raids): the alert is open-world only, and so is this
local ADDON, ns = ...
local L = ns.L

local MapPins = {}
ns.MapPins = MapPins

local TEMPLATE = "RocketMountMapPinTemplate"

-- The same numbers as MapPins.xml, for the harness to check the two against each other. The ring
-- of `worldquest-questmarker-epic` is 40 of the art's 64: drawn at 32 it is 20 across.
--
-- (!) THE SIZE IS THE GAME'S QUEST PIN (27/09). It was born the size of a world-quest pin (disc
-- at 40, ring of 25) and the user asked for smaller: *"pode reduzir um pouco o tamanho dos icones
-- do mapa?"*. The game's own quest marker is a button of 20 with its art at 32
-- (`POIButton.xml`, POIButtonTemplate), which is 80% of what we had -- so that is the size, and
-- every other number went down by the same 80%.
MapPins.Geometry = { PIN = 20, DISC = 32, ICON = 17, RING = 20, BADGE = 12, BADGE_X = 7, BADGE_Y = -7 }

-- Points of the SAME creature closer than this (in map fractions) become one pin. Wowhead gives
-- up to a dozen spawn points, and a patrol drew a cluster where one icon says the same thing.
local NEAR = 0.035
-- A vendor or a quest giver is ONE place however many mounts it has: points this close (and of
-- the same sort) are the same place, and the tooltip lists the mounts.
local SAME_PLACE = 0.012
local TIP_ICON = 22     -- the mount's icon in the tooltip
local TIP_MOUNTS = 8    -- then "and N more"

--------------------------------------------------------------------------------
-- What kind of source a place is
--
-- `atlas` is the glyph, `size` how big it is drawn (each art has its own padding), `dragon` the
-- elite underlay, `group` what may be merged into one place. Every name was checked against the
-- client's atlas table (tools/ver_atlas.py --check RocketMount).
--
-- A reputation has no glyph of its own in the game, and a mount behind one is bought from a
-- vendor: same glyph as the vendor, its own label.
--------------------------------------------------------------------------------
local KIND = {
    rare       = { atlas = "VignetteKill",              size = 12, label = L["Rare"],       group = "creature" },
    rareelite  = { atlas = "VignetteKill",              size = 12, label = L["Rare elite"], group = "creature", dragon = true },
    elite      = { atlas = "VignetteKill",              size = 12, label = L["Elite"],      group = "creature", dragon = true },
    boss       = { atlas = "worldquest-icon-boss",      size = 11, label = L["Boss"],       group = "creature", dragon = true },
    raid       = { atlas = "Raid",                      size = 16, label = L["Raid"],       group = "instance" },
    dungeon    = { atlas = "Dungeon",                   size = 16, label = L["Dungeon"],    group = "instance" },
    vendor     = { atlas = "auctioneer",                size = 12, label = L["Vendor"],     group = "vendor" },
    reputation = { atlas = "auctioneer",                size = 12, label = L["Reputation"], group = "vendor" },
    quest      = { atlas = "QuestNormal",               size = 14, label = L["Quest"],      group = "quest" },
    treasure   = { atlas = "VignetteLoot",              size = 12, label = L["Treasure"],   group = "treasure" },
    -- (!) THE WAY IN, NOT THE THING (28/09). The user: *"este raro em especifico ele não spawna
    -- no mapa, mas sim um portal, veja como indicar isto no mapa"* -- the Voidtalon of the Dark
    -- Star is in an egg on the other side of a portal that appears at one of some thirty
    -- places. The art is the game's own portal; measured (tools/ver_atlas.py), its ink is the
    -- middle 16 of the 32, so it is cut to the middle half or it would be a smudge of 6 px.
    portal     = { atlas = "portalpurple",              size = 14, label = L["Portal"],     group = "portal",
                   crop = { 0.25, 0.75, 0.25, 0.75 } },
    loot       = { atlas = "VignetteLoot",              size = 12, label = L["Drop"],       group = "loot" },
    fishing    = { atlas = "professions_tracking_fish", size = 12, label = L["Fishing"],    group = "fishing" },
    other      = { atlas = "worldquest-icon",           size = 11, label = L["Other"],      group = "other" },
}
MapPins.KIND = KIND

-- Wowhead's classification of a creature -> kind.
local KIND_OF_CLASS = { [4] = "rare", [2] = "rareelite", [1] = "elite", [3] = "boss" }

---The kind of a place as it reaches the pin and the tooltip. A record that only says which
---creature it is (no `kind`) is that creature's class.
local function KindDe(data)
    local nome = data.kind or (data.rec and KIND_OF_CLASS[data.rec.c]) or (data.npc and "rare")
    return KIND[nome] or KIND.other, nome or "other"
end

---An art that is mostly margin, cut to its ink: `crop` is { left, right, top, bottom } in
---fractions of the art. `SetAtlas` has just put the art's own rectangle on the texture, and the
---cut is made inside it (the same arithmetic the skin of the header uses). Without the atlas'
---numbers the art stays whole: small, but the right one.
function MapPins.Crop(texture, atlas, crop)
    if not (texture and type(crop) == "table" and C_Texture and C_Texture.GetAtlasInfo) then return false end
    local ok, info = pcall(C_Texture.GetAtlasInfo, atlas)
    if not (ok and type(info) == "table" and info.leftTexCoord and info.rightTexCoord
        and info.topTexCoord and info.bottomTexCoord) then
        return false
    end
    local l, t = info.leftTexCoord, info.topTexCoord
    local w, h = info.rightTexCoord - l, info.bottomTexCoord - t
    texture:SetTexCoord(l + w * crop[1], l + w * crop[2], t + h * crop[3], t + h * crop[4])
    return true
end

---What the options let through: the master switch, then the two families that can be turned off
---apart. A creature is what the map started with, and stays with the master switch.
local function KindShown(kind)
    local db = ns.db
    if db and db.mapPins == false then return false end
    local grupo = KIND[kind] and KIND[kind].group
    if grupo == "creature" then return true end
    if grupo == "instance" then return not (db and db.mapInstances == false) end
    return not (db and db.mapSources == false)
end

local function MapaAberto(mapID)
    if not (C_Map and C_Map.GetMapInfo) then return true end
    local ok, info = pcall(C_Map.GetMapInfo, mapID)
    if not ok or type(info) ~= "table" then return true end
    -- Dungeon maps are instance floors; the rest (zones, sub-zones, caves) is open world.
    local dungeon = Enum and Enum.UIMapType and Enum.UIMapType.Dungeon
    return not (dungeon and info.mapType == dungeon)
end

--------------------------------------------------------------------------------
-- The creature's name in the player's language
--
-- The table carries Wowhead's English name. The game knows the creature by id in the client's
-- language: the tooltip of the link `unit:Creature-0-0-0-0-<npc>` starts with its name (the same
-- API `C_TooltipInfo.GetHyperlink` that the rest of this addon uses for items). The first ask may
-- come back empty while the client fetches it, so the map asks when it draws the pins, and the
-- tooltip asks again when hovered.
--------------------------------------------------------------------------------
local nomes = {}

function MapPins.NpcName(npc, fallback)
    if nomes[npc] then return nomes[npc] end
    if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local ok, info = pcall(C_TooltipInfo.GetHyperlink, "unit:Creature-0-0-0-0-" .. npc)
        local linha = ok and type(info) == "table" and type(info.lines) == "table" and info.lines[1]
        local nome = type(linha) == "table" and linha.leftText
        -- (!) SECRET FIRST, THEN EVERYTHING ELSE. The comparison with "" came before the question
        -- and a secret string cannot be compared: "attempt to compare local 'nome' (a secret
        -- string value)", recorded by !BugGrabber on 27/09 from inside the list's own ranking.
        if type(nome) == "string" and not (issecretvalue and issecretvalue(nome))
            and nome ~= "" and nome ~= UNKNOWNOBJECT then
            nomes[npc] = nome
            return nome
        end
    end
    -- Seen in the world by this addon (Sighting.lua keeps it), or Wowhead's English one.
    return ns.db and ns.db.npcNames and ns.db.npcNames[npc] or fallback
end

---A creature's ENGLISH name (MCL's `lockBossName`, "Sha of Anger") in the client's language, when
---the drop table knows it -- the id is what lets the game answer. Unknown names come back as is.
local porNomeIngles
---The npc id the drop table has for a creature's English name, or nil.
function ns.CreatureId(nomeIngles)
    if type(nomeIngles) ~= "string" then return nil end
    if not porNomeIngles then
        porNomeIngles = {}
        for npc, rec in pairs(ns.MobDrops or {}) do
            if rec.name then porNomeIngles[rec.name] = npc end
        end
    end
    return porNomeIngles[nomeIngles]
end

function ns.LocalizedCreature(nomeIngles)
    if type(nomeIngles) ~= "string" then return nomeIngles end
    local npc = ns.CreatureId(nomeIngles)
    return npc and MapPins.NpcName(npc, nomeIngles) or nomeIngles
end

local function Perto(pontos, x, y, raio)
    raio = raio or NEAR
    for _, p in ipairs(pontos) do
        local dx, dy = p[1] - x, p[2] - y
        if dx * dx + dy * dy < raio * raio then return true end
    end
    return false
end

--------------------------------------------------------------------------------
-- The places, by map
--
-- Built once per list (a mount learned, a reputation gained -- `MapPins.Refresh` drops it) and
-- not per map opened: walking 300 creatures and 600 mounts at every zoom of the map would be
-- work done again for the same answer. What changes between two looks at the same list -- the
-- lockout -- is asked when the pins are drawn.
--------------------------------------------------------------------------------
local indice

---How much a mount weighs at a place, to put the easiest first: its chance there, or the number
---the list shows for it.
local function Peso(m)
    local d = m.drop
    if d and d.count and d.outof and d.outof > 0 then return d.count / d.outof end
    local e = m.entry
    if e and e.chance and e.chance > 0 and not e.deterministic then return 1 / e.chance end
    return (e and ns.RowPercent and ns.RowPercent(e)) or -1
end

local function Ordenar(montarias)
    local peso = {}
    for _, m in ipairs(montarias) do peso[m] = Peso(m) end
    table.sort(montarias, function(a, b)
        if peso[a] ~= peso[b] then return peso[a] > peso[b] end
        return (a.entry.name or "") < (b.entry.name or "")
    end)
    return montarias
end

---What kind of source one point is: the table says (Sources.lua, `ns.OwnPlaces`). A kind the
---map does not know how to draw is "other", never a guess.
local function KindOf(wp)
    if wp and wp.kind and KIND[wp.kind] then return wp.kind end
    return "other"
end

---A point the player has already spent for good: a treasure looted, a one-time quest done.
local function Gasto(wp)
    if not (wp and wp.q and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) then return false end
    local ok, feito = pcall(C_QuestLog.IsQuestFlaggedCompleted, wp.q)
    return ok and feito and true or false
end

---The routes of the table that pass through one marker: a creature that walks has one marker
---per route, ON the route (tools/rotas.py puts it at the point where it was seen most).
---@return table|nil `{ { loop = boolean, { x, y }, ... }, ... }`, in fractions of the map
local function RotasDe(rec, mapID, px, py)
    local lista = type(rec.route) == "table" and rec.route[mapID]
    if type(lista) ~= "table" then return nil end
    local out
    for _, r in ipairs(lista) do
        local passa = false
        for i = 1, #r - 1, 2 do
            if math.abs(r[i] - px) < 0.05 and math.abs(r[i + 1] - py) < 0.05 then passa = true end
        end
        if passa and #r >= 4 then
            local caminho = { loop = r.loop and true or false }
            for i = 1, #r - 1, 2 do caminho[#caminho + 1] = { r[i] / 100, r[i + 1] / 100 } end
            out = out or {}
            out[#out + 1] = caminho
        end
    end
    return out
end

local function Construir()
    local idx = {}
    local function Lista(m)
        idx[m] = idx[m] or {}
        return idx[m]
    end

    -- 1. THE CREATURES OF THE TABLE: one place per spawn point.
    if type(ns.MobDrops) == "table" and ns.Sighting then
        for npc, rec in pairs(ns.MobDrops) do
            if rec.where then
                local montarias = ns.Sighting.MountsOf(npc)
                if #montarias > 0 then
                    Ordenar(montarias)
                    for m, pontos in pairs(rec.where) do
                        local postos = {}
                        for i = 1, #pontos - 1, 2 do
                            local x, y = pontos[i] / 100, pontos[i + 1] / 100
                            if not Perto(postos, x, y) then
                                postos[#postos + 1] = { x, y }
                                local lista = Lista(m)
                                lista[#lista + 1] = {
                                    kind = KIND_OF_CLASS[rec.c] or "rare",
                                    npc = npc, rec = rec, name = rec.name, mounts = montarias,
                                    mapID = m, x = x, y = y, first = #postos == 1,
                                    routes = RotasDe(rec, m, pontos[i], pontos[i + 1]),
                                }
                            end
                        end
                    end
                end
            end
        end
    end

    -- 2. THE PLACES OF EACH MOUNT: vendors, chests, quest givers.
    local ok, ranqueadas = pcall(ns.GetRanked or error)
    if not ok or type(ranqueadas) ~= "table" then return idx end

    local function Juntar(kind, m, x, y, nome, e, wp)
        local grupo = KIND[kind].group
        local lista = Lista(m)
        local lugar
        for _, p in ipairs(lista) do
            if p.fromCatalogue and KIND[p.kind].group == grupo
                and Perto({ { p.x, p.y } }, x, y, SAME_PLACE) then
                lugar = p
                break
            end
        end
        if not lugar then
            lugar = {
                kind = kind, name = nome, rec = { name = nome },
                mounts = {}, mapID = m, x = x, y = y, fromCatalogue = true,
                -- One of SEVERAL places of the same thing (a portal that appears here or there)
                -- says which is the first of its map, as a creature's spawn points do.
                first = not (wp and wp.first == false),
            }
            lista[#lista + 1] = lugar
        end
        for _, mt in ipairs(lugar.mounts) do
            if mt.entry == e then return end
        end
        lugar.mounts[#lugar.mounts + 1] = { entry = e }
        -- Who or what the place is, by id: the name comes from the game, in its language.
        if wp then
            lugar.nameNpc = lugar.nameNpc or wp.npcId
            lugar.nameQuest = lugar.nameQuest or wp.questId
        end
        -- A vendor is "Reputation" only while EVERY mount there is behind one.
        if grupo == "vendor" and kind == "vendor" then lugar.kind = "vendor" end
    end

    for _, e in ipairs(ranqueadas) do
        if not e.unobtainable then
            for _, wp in ipairs(e.coords or {}) do
                if wp.m and wp.x and wp.y and not Gasto(wp) then
                    Juntar(KindOf(wp), wp.m, wp.x / 100, wp.y / 100, wp.n, e, wp)
                end
            end
            for _, v in ipairs(e.vendors or {}) do
                if v.m and v.x and v.y then
                    Juntar(e.rep and "reputation" or "vendor", v.m, v.x / 100, v.y / 100, v.npc, e,
                        v.npcId and { npcId = v.npcId } or nil)
                end
            end
        end
    end
    for _, lista in pairs(idx) do
        for _, p in ipairs(lista) do
            if p.fromCatalogue then Ordenar(p.mounts) end
        end
    end

    -- 3. THE INSTANCES: which mounts are behind each door. The door itself is not here -- the
    -- game says where it is, on the map being looked at (PinsFor).
    idx.instances = {}
    for _, e in ipairs(ranqueadas) do
        if not e.unobtainable and type(e.instanceID) == "number" and not e.worldBoss then
            local lista = idx.instances[e.instanceID] or {}
            idx.instances[e.instanceID] = lista
            lista[#lista + 1] = { entry = e }
        end
    end
    for _, lista in pairs(idx.instances) do Ordenar(lista) end
    return idx
end

--------------------------------------------------------------------------------
-- Which maps are drawn on the one being viewed
--
-- (!) A RARE IN A CAVE IS STILL A RARE OF THE ZONE (27/09). The pins were drawn only on the exact
-- map a point belongs to, so Rakshur and Eruundi -- in Slayer's Rise, a map inside Voidstorm --
-- were on nobody's zone map. SilverDragon marks them `parent=true`; MCL projects every child map
-- (`GuideMapPins.lua`, RefreshPins). The game does the arithmetic: map position -> world position
-- -> position on the other map.
--------------------------------------------------------------------------------
---@return table|nil set of mapIDs (nil: nothing is drawn on this map), boolean isContinent
local function Familia(mapID)
    local T = Enum and Enum.UIMapType or {}
    local tipo
    if C_Map and C_Map.GetMapInfo then
        local ok, info = pcall(C_Map.GetMapInfo, mapID)
        tipo = ok and type(info) == "table" and info.mapType or nil
    end
    -- The whole world is not a place to look for a rare.
    if tipo ~= nil and (tipo == T.Cosmic or tipo == T.World) then return nil end
    local set = { [mapID] = true }
    if C_Map and C_Map.GetMapChildrenInfo then
        local ok, filhos = pcall(C_Map.GetMapChildrenInfo, mapID, nil, true)
        for _, f in ipairs(ok and type(filhos) == "table" and filhos or {}) do
            if f.mapID and f.mapType ~= T.Dungeon then set[f.mapID] = true end
        end
    end
    return set, tipo ~= nil and tipo == T.Continent
end

---A point of one map on another. The same map answers itself; anything the game cannot place,
---or places outside the map, is nil.
function MapPins.Project(deMapa, x, y, paraMapa)
    if deMapa == paraMapa then return x, y end
    if not (C_Map and C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos and CreateVector2D) then
        return nil
    end
    local ok, continente, mundo = pcall(C_Map.GetWorldPosFromMapPos, deMapa, CreateVector2D(x, y))
    if not (ok and continente and mundo) then return nil end
    local ok2, _, pos = pcall(C_Map.GetMapPosFromWorldPos, continente, mundo, paraMapa)
    if not (ok2 and pos and pos.GetXY) then return nil end
    local px, py = pos:GetXY()
    if not (px and py) or px < 0 or px > 1 or py < 0 or py > 1 then return nil end
    return px, py
end

---What goes on this map: one entry per place that still has a mount for you.
function MapPins.PinsFor(mapID)
    local out = {}
    if not (mapID and ns.Sighting) then return out end
    if ns.db and ns.db.mapPins == false then return out end
    if not MapaAberto(mapID) then return out end
    local familia, continente = Familia(mapID)
    if not familia then return out end
    indice = indice or Construir()

    for m in pairs(familia) do
        for _, p in ipairs(indice[m] or {}) do
            local criatura = KIND[p.kind].group == "creature"
            -- On a continent a creature is ONE pin: forty-five points of a flight path, times
            -- every rare of every zone, is a map nobody can read. The same for a portal with
            -- seven places in a zone (`first` is only ever false for a thing of several places).
            if KindShown(p.kind) and not (continente and not p.first) then
                local x, y = MapPins.Project(m, p.x, p.y, mapID)
                if x then
                    local kind, nome = p.kind, p.name
                    local preso, fonte, falta
                    if criatura then
                        preso, fonte, falta = ns.Sighting.LockedOut(p.npc)
                        if p.npc then MapPins.NpcName(p.npc) end   -- warms the name for the tooltip
                    end
                    -- The road, on the map being viewed. Not on a continent (a zone's roads
                    -- there are scribbles), and whole or not at all: a road with a point
                    -- the game cannot place would be drawn cut.
                    local rotas
                    if p.routes and not continente and not (ns.db and ns.db.mapRoutes == false) then
                        for _, r in ipairs(p.routes) do
                            local caminho, inteiro = {}, true
                            for i, v in ipairs(r) do
                                local rx, ry = MapPins.Project(m, v[1], v[2], mapID)
                                if rx then caminho[i] = { rx, ry } else inteiro = false end
                            end
                            if inteiro and #caminho >= 2 then
                                rotas = rotas or {}
                                rotas[#rotas + 1] = { path = caminho, loop = r.loop, locked = preso and true or false }
                            end
                        end
                    end
                    out[#out + 1] = {
                        kind = kind, npc = p.npc, rec = p.rec or { name = nome }, name = nome,
                        mounts = p.mounts, fromCatalogue = p.fromCatalogue, routes = rotas,
                        nameNpc = p.nameNpc, nameQuest = p.nameQuest, first = p.first,
                        -- Where it is drawn, and where it IS: the arrow goes to the place's own map.
                        x = x, y = y, mapID = mapID, homeMap = p.mapID, homeX = p.x, homeY = p.y,
                        locked = preso, lockSource = fonte, lockLeft = falta,
                    }
                end
            end
        end
    end

    -- (!) THE DOOR IS WHERE THE GAME SAYS (28/09). No coordinate of an entrance is kept: the
    -- game answers for the map being looked at, in that map's own coordinates and with the name
    -- in the player's language -- the same call its own entrance markers are made of
    -- (`DungeonEntranceDataProvider.lua`).
    local portas = indice.instances
    if portas and next(portas) and C_EncounterJournal and C_EncounterJournal.GetDungeonEntrancesForMap then
        local ok, lista = pcall(C_EncounterJournal.GetDungeonEntrancesForMap, mapID)
        for _, d in ipairs(ok and type(lista) == "table" and lista or {}) do
            local montarias = type(d) == "table" and portas[d.journalInstanceID]
            local x, y
            if montarias and type(d.position) == "table" and d.position.GetXY then
                x, y = d.position:GetXY()
            end
            local kind = d and d.atlasName == "Raid" and "raid" or "dungeon"
            if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 and KindShown(kind) then
                out[#out + 1] = {
                    kind = kind, name = d.name, rec = { name = d.name }, mounts = montarias,
                    instance = d.journalInstanceID, first = true,
                    x = x, y = y, mapID = mapID, homeMap = mapID, homeX = x, homeY = y,
                }
            end
        end
    end
    return out
end

--------------------------------------------------------------------------------
-- The route of a creature that walks
--
-- (!) ONE MARKER AND ITS ROUTE (28/09). The user's screenshot of the Timeless Isle had the same
-- rare elite drawn seven times around the island, with the road drawn over it by hand: *"Reduzir
-- o número de icones quando o raro fizer uma rota, ou seja, deixa um icone apenas e faça uma
-- marcação tracejando a rota, apenas repita icones quando o spawn do raro for diferente e não
-- houver rota"*. The table says which creature walks and through where (`route`, from
-- tools/rotas.py); here the road is drawn.
--
-- THE LINE IS THE GAME'S: `_UI-Taxi-Line-horizontal`, the art of the flight paths, on a `Line`
-- of a frame of the map's canvas -- how Blizzard draws them (`FM_FlightPathDataProvider.lua`,
-- `FlightMap_BackgroundFlightLineTemplate`). The game has no dashed line, so the dashes are
-- short lines with a gap between them.
--
-- Sizes are in SCREEN points and divided by the canvas scale when drawn, so that a dash is the
-- same on the screen whatever the zoom -- a line of the canvas grows and shrinks with it.
--------------------------------------------------------------------------------
local ROUTE = {
    ATLAS = "_UI-Taxi-Line-horizontal",
    THICK = 18,             -- of the art, which carries its own glow: the core is about a quarter
    DASH = 10, GAP = 7,
    ALPHA = 0.9, ALPHA_LOCKED = 0.35,
    MAX_DASHES = 400,       -- per route: a canvas scale that came wrong cannot ask for thousands
}
MapPins.Route = ROUTE

---The dashes of a path: `{ { x1, y1, x2, y2 }, ... }`, in the units the path came in.
---The pattern runs along the whole path, so a dash that meets a corner bends there (two lines).
---@param path table `{ { x, y }, ... }`
---@param loop boolean|nil the path closes on its first point
function MapPins.Dashes(path, loop, dash, gap)
    local out = {}
    if type(path) ~= "table" or #path < 2 then return out end
    if type(dash) ~= "number" or dash <= 0 then return out end
    gap = (type(gap) == "number" and gap > 0) and gap or 0
    local pontos = {}
    for _, p in ipairs(path) do pontos[#pontos + 1] = p end
    if loop and #pontos > 2 then pontos[#pontos + 1] = pontos[1] end

    local tinta, resta = true, dash
    for i = 1, #pontos - 1 do
        local ax, ay, bx, by = pontos[i][1], pontos[i][2], pontos[i + 1][1], pontos[i + 1][2]
        local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
        local pos = 0
        while len - pos > 1e-9 do
            local passo = math.min(resta, len - pos)
            if tinta then
                if #out >= ROUTE.MAX_DASHES then return out end
                local a, b = pos / len, (pos + passo) / len
                out[#out + 1] = { ax + (bx - ax) * a, ay + (by - ay) * a,
                                  ax + (bx - ax) * b, ay + (by - ay) * b }
            end
            pos, resta = pos + passo, resta - passo
            if resta <= 1e-9 then
                tinta = (gap == 0) or not tinta
                resta = tinta and dash or gap
            end
        end
    end
    return out
end

--------------------------------------------------------------------------------
-- The data provider
--------------------------------------------------------------------------------
RocketMountMapDataProviderMixin = CreateFromMixins(MapCanvasDataProviderMixin)

function RocketMountMapDataProviderMixin:RemoveAllData()
    self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
    self.routes = nil
    self:LayoutRoutes()
end

---Draws `self.routes` on the canvas as it is now. Called when the pins are drawn and whenever
---the canvas changes scale or size: the dashes are sized for the screen (see ROUTE).
---@return number lines drawn
function RocketMountMapDataProviderMixin:LayoutRoutes()
    self.routeLines = self.routeLines or {}
    local usadas = 0
    local ok = pcall(function()
        local map = self:GetMap()
        local canvas = map and map.GetCanvas and map:GetCanvas()
        if not (canvas and self.routes and #self.routes > 0) then return end
        local w, h = canvas:GetSize()
        local escala = map.GetCanvasScale and map:GetCanvasScale() or 1
        if not (w and h and w > 0 and h > 0) or not escala or escala <= 0 then return end

        if not self.routeFrame then
            self.routeFrame = CreateFrame("Frame", nil, canvas)
            self.routeFrame:SetAllPoints(canvas)
            -- Under our own pins: the marker sits ON its road.
            local gerente = map.GetPinFrameLevelsManager and map:GetPinFrameLevelsManager()
            if gerente and gerente.GetValidFrameLevel then
                local okN, nivel = pcall(gerente.GetValidFrameLevel, gerente, "PIN_FRAME_LEVEL_VIGNETTE")
                if okN and type(nivel) == "number" and nivel > 1 then
                    self.routeFrame:SetFrameLevel(nivel - 1)
                end
            end
        end
        self.routeFrame:Show()

        for _, rota in ipairs(self.routes) do
            local pontos = {}
            for i, p in ipairs(rota.path) do pontos[i] = { p[1] * w, p[2] * h } end
            local tracos = MapPins.Dashes(pontos, rota.loop, ROUTE.DASH / escala, ROUTE.GAP / escala)
            for _, t in ipairs(tracos) do
                usadas = usadas + 1
                local linha = self.routeLines[usadas]
                if not linha then
                    linha = self.routeFrame:CreateLine(nil, "ARTWORK")
                    linha:SetAtlas(ROUTE.ATLAS)
                    self.routeLines[usadas] = linha
                end
                linha:SetThickness(ROUTE.THICK / escala)
                linha:SetStartPoint("TOPLEFT", canvas, t[1], -t[2])
                linha:SetEndPoint("TOPLEFT", canvas, t[3], -t[4])
                linha:SetAlpha(rota.locked and ROUTE.ALPHA_LOCKED or ROUTE.ALPHA)
                linha:SetDesaturated(rota.locked and true or false)
                linha:Show()
            end
        end
    end)
    for i = usadas + 1, #self.routeLines do self.routeLines[i]:Hide() end
    if self.routeFrame and usadas == 0 then self.routeFrame:Hide() end
    self.routeError = not ok
    return usadas
end

function RocketMountMapDataProviderMixin:OnCanvasScaleChanged() self:LayoutRoutes() end
function RocketMountMapDataProviderMixin:OnCanvasSizeChanged() self:LayoutRoutes() end

-- What the last drawing asked for and got, for `/rmt pins` and the diary.
local ultimo = { map = nil, asked = 0, drawn = 0, failed = 0, err = nil }

function RocketMountMapDataProviderMixin:RefreshAllData()
    self:RemoveAllData()
    local map = self:GetMap()
    local mapID = map:GetMapID()
    local lista = MapPins.PinsFor(mapID)
    ultimo = { map = mapID, asked = #lista, drawn = 0, failed = 0, err = nil, kinds = {},
               routes = 0, dashes = 0 }
    self.routes = {}
    for _, data in ipairs(lista) do
        for _, r in ipairs(data.routes or {}) do self.routes[#self.routes + 1] = r end
        -- (!) ONE PIN THAT FAILS DOES NOT TAKE THE REST WITH IT. For four days an assert inside
        -- `AcquirePin` stopped this loop at the first NEW pin, and the map showed whatever pins
        -- earlier openings had left in the pool (MapPins.xml tells the story). The cause is gone;
        -- the loop no longer depends on that.
        local ok, err = pcall(map.AcquirePin, map, TEMPLATE, data)
        if ok then
            ultimo.drawn = ultimo.drawn + 1
            ultimo.kinds[data.kind] = (ultimo.kinds[data.kind] or 0) + 1
        else
            ultimo.failed = ultimo.failed + 1
            ultimo.err = ultimo.err or tostring(err)
        end
    end
    ultimo.routes = #self.routes
    ultimo.dashes = self:LayoutRoutes()
    if self.routeError then ultimo.err = ultimo.err or "routes" end
    -- One line per drawing that has something to say: pins asked for, or a failure.
    if ultimo.asked > 0 or ultimo.failed > 0 then
        ns.Log.Add("pins", { map = mapID, asked = ultimo.asked, drawn = ultimo.drawn,
                             routes = ultimo.routes, dashes = ultimo.dashes,
                             failed = ultimo.failed, error = ultimo.err })
    end
end

---What the last drawing did, for `/rmt pins`.
function MapPins.LastDraw() return ultimo end

--------------------------------------------------------------------------------
-- The pin
--------------------------------------------------------------------------------
RocketMountMapPinMixin = CreateFromMixins(MapCanvasPinMixin)

function RocketMountMapPinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_VIGNETTE")
    self:SetScalingLimits(1, 1.0, 1.2)
    -- (!) OUT OF THE WAY OF THE ENTRANCE, THE WAY THE GAME DOES IT. The user's screenshot of MCL:
    -- *"montarias de raid e dungeons levemente deslocada para não ficar em cima do icone de raid e
    -- dungeon"*. The map has this built in: an entrance is a nudge SOURCE
    -- (`DungeonEntrancePinMixin:OnLoad`, radius 1, magnitude 2) and any pin that declares itself a
    -- TARGET is pushed away from it, more when zoomed out. These are the numbers Blizzard gives
    -- its own flight points (`FlightPointDataProvider.lua:71-73`).
    self:SetNudgeTargetFactor(0.015)
    self:SetNudgeZoomedOutFactor(1.25)
    self:SetNudgeZoomedInFactor(1)
end

---(!) NOT IN COMBAT. The map sets which buttons a pin lets through every time it hands one out,
---and `SetPassThroughButtons` is protected while fighting: "[ADDON_ACTION_BLOCKED] RocketMount
---tentou chamar a função protegida 'Frame:SetPassThroughButtons()'", seven times on 27/09, from
---a redraw after a loot. HandyNotes and HereBeDragons empty the function for good ("hack to avoid
---in-combat error"); here the right button keeps zooming the map out, which is what the game's own
---pins do, and only the call made in combat is skipped.
function RocketMountMapPinMixin:CheckMouseButtonPassthrough(...)
    if InCombatLockdown and InCombatLockdown() then return end
    MapCanvasPinMixin.CheckMouseButtonPassthrough(self, ...)
end

function RocketMountMapPinMixin:OnAcquired(data)
    self.data = data
    self:SetPosition(data.x, data.y)

    local kind = KindDe(data)
    local primeira = data.mounts and data.mounts[1]
    self.Icon:SetTexture(primeira and primeira.entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    self.Underlay:SetShown(kind.dragon and true or false)
    self.Badge:SetAtlas(kind.atlas)
    if kind.crop then MapPins.Crop(self.Badge, kind.atlas, kind.crop) end
    self.Badge:SetSize(kind.size, kind.size)

    local rotulo = not (ns.db and ns.db.mapLabels == false)
    self.Label:SetText(rotulo and kind.label or "")
    self.Label:SetShown(rotulo)

    -- LOOTED goes dim, not away: the place is still worth knowing for tomorrow's run.
    local preso = data.locked and true or false
    self.Icon:SetDesaturated(preso)
    self.Disc:SetDesaturated(preso)
    self.Underlay:SetDesaturated(preso)
    self.Badge:SetDesaturated(preso)
    self:SetAlpha(preso and 0.5 or 1)
end

local function Horas(segundos)
    if not segundos then return nil end
    local h = math.floor(segundos / 3600)
    if h >= 24 then return string.format(L["%dd"], math.floor(h / 24)) end
    if h >= 1 then return string.format(L["%dh"], h) end
    return string.format(L["%dmin"], math.max(1, math.floor(segundos / 60)))
end

--------------------------------------------------------------------------------
-- The tooltip
--
-- Written with the game's own helpers (`SharedTooltipTemplates.lua`), so it has the colours of
-- every other tooltip of the map: the title white, what it is in gold, what stands in the way in
-- red, what a click does in green. The names are in the client's language: the mount's from the
-- journal, the creature's from the game (NpcName), the entrance's from the dungeon journal.
--------------------------------------------------------------------------------
local function Cor(nome, r, g, b)
    local c = _G[nome]
    if type(c) == "table" and c.GetRGB then return c:GetRGB() end
    return r, g, b
end

local function Titulo(tip, texto)
    if GameTooltip_SetTitle then return GameTooltip_SetTitle(tip, texto) end
    tip:SetText(texto, Cor("HIGHLIGHT_FONT_COLOR", 1, 1, 1))
end

local function Linha(tip, texto, cor, r, g, b, quebra)
    local cr, cg, cb = Cor(cor, r, g, b)
    tip:AddLine(texto, cr, cg, cb, quebra and true or false)
end

local HEADER = {
    creature = L["Can drop:"], instance = L["Can drop:"], loot = L["Can drop:"],
    treasure = L["Can drop:"], fishing = L["Can drop:"], portal = L["Leads to:"],
    vendor = L["Sells:"], quest = L["Rewards:"], other = L["Mounts here:"],
}

-- What of the mount's card the tooltip quotes, and in which order. "Where" stays out: the pin IS
-- where. The chance stays out at a creature, whose line already carries the chance THERE.
local TIP_BLOCKS = { flavor = 1, howto = 2, chance = 3, requirements = 4, about = 5, achievement = 6,
                     tip = 7 }

---A text the game or the card wrote in several lines, one tooltip line each: the journal's
---source text separates them with `|n`, ours with a line break.
local function Linhas(texto)
    local out = {}
    texto = tostring(texto or ""):gsub("|n", string.char(10))
    for linha in (texto .. string.char(10)):gmatch("(.-)" .. string.char(10)) do
        if linha:gsub("%s", "") ~= "" then out[#out + 1] = linha end
    end
    return out
end

---(!) THE DESCRIPTION, for a place with ONE mount (27/09). The user, with MCL's tooltip on
---screen: *"com uma boa descrição tanto na popup quanto na janela do addon"*. It is the card's
---own text (`ns.DetailBlocks`), quoted: the mount's flavour line in the gold the game writes
---flavour in, then each block under its title. A place with several mounts keeps the list --
---six descriptions in one tooltip is a wall -- and the card has each of them. The exception is
---the players' tip the mounts of the place SHARE (`Tips.Shared`), which is one text.
local function Descricao(tooltip, e, criatura)
    if not ns.DetailBlocks then return end
    local ok, blocos = pcall(ns.DetailBlocks, e)
    if not ok or type(blocos) ~= "table" then return end
    for _, b in ipairs(blocos) do
        if TIP_BLOCKS[b.key] and not (criatura and b.key == "chance") then
            tooltip:AddLine(" ")
            if b.label then
                Linha(tooltip, b.label, "NORMAL_FONT_COLOR", 1, 0.82, 0)
                for _, l in ipairs(Linhas(b.value)) do
                    Linha(tooltip, l, "HIGHLIGHT_FONT_COLOR", 1, 1, 1, true)
                end
            else
                Linha(tooltip, b.value, "NORMAL_FONT_COLOR", 1, 0.82, 0, true)
            end
        end
    end
end

function MapPins.PlaceName(data)
    local kind = KindDe(data)
    if data.npc then return MapPins.NpcName(data.npc, data.rec and data.rec.name or data.name) end
    if data.nameNpc then return MapPins.NpcName(data.nameNpc, data.name) end
    if data.nameQuest and C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local ok, titulo = pcall(C_QuestLog.GetTitleForQuestID, data.nameQuest)
        if ok and type(titulo) == "string" and titulo ~= ""
            and not (issecretvalue and issecretvalue(titulo)) then
            return titulo
        end
    end
    if kind.group == "creature" and data.name then return ns.LocalizedCreature(data.name) end
    if data.name and data.name ~= "" then return data.name end
    -- A place with no name: one mount, its boss; several, what kind of place it is.
    local unica = data.mounts and #data.mounts == 1 and data.mounts[1].entry
    if unica and unica.bossName then return ns.LocalizedCreature(unica.bossName) end
    return kind.label
end

function MapPins.Tooltip(tooltip, data)
    local kind = KindDe(data)
    local criatura = kind.group == "creature"
    Titulo(tooltip, MapPins.PlaceName(data))
    Linha(tooltip, kind.label, "NORMAL_FONT_COLOR", 1, 0.82, 0)
    tooltip:AddLine(" ")
    Linha(tooltip, HEADER[kind.group] or HEADER.other, "NORMAL_FONT_COLOR", 1, 0.82, 0)

    local wr, wg, wb = Cor("HIGHLIGHT_FONT_COLOR", 1, 1, 1)
    local gr, gg, gb = Cor("NORMAL_FONT_COLOR", 1, 0.82, 0)
    local total = #data.mounts
    for i = 1, math.min(total, TIP_MOUNTS) do
        local m = data.mounts[i]
        local e = m.entry
        -- At a creature the number is the chance THERE; anywhere else, the one the list shows.
        local numero
        if criatura or m.drop then
            numero = ns.Sighting.ChanceText(m) or "?"
        else
            numero = ns.RowPercentText and ns.RowPercentText(e) or "?"
        end
        local icone = e.icon and string.format("|T%s:%d:%d:0:0|t ", tostring(e.icon), TIP_ICON, TIP_ICON) or ""
        tooltip:AddDoubleLine(icone .. e.name, numero, wr, wg, wb, gr, gg, gb)
        -- Why that number, when there is room to say it: what is asked, the price, the boss.
        -- (One mount alone gets the whole description instead, below.)
        if not criatura and total > 1 and total <= 3 then
            local porque = ns.RowWhy and ns.RowWhy(e) or e.why
            if kind.group == "instance" and e.bossName then
                porque = ns.LocalizedCreature(e.bossName)
            end
            if type(porque) == "string" and porque ~= "" then
                Linha(tooltip, porque, "DISABLED_FONT_COLOR", 0.5, 0.5, 0.5, true)
            end
        end
    end
    if total > TIP_MOUNTS then
        Linha(tooltip, string.format(L["and %d more"], total - TIP_MOUNTS),
            "DISABLED_FONT_COLOR", 0.5, 0.5, 0.5)
    end
    if total == 1 then
        Descricao(tooltip, data.mounts[1].entry, criatura)
    elseif ns.Tips and ns.Tips.Shared then
        -- Several mounts, ONE tip (the two a zone's rares drop): said once, under the list.
        local ok, dica, nota = pcall(ns.Tips.Shared, data.mounts)
        if ok and dica then
            tooltip:AddLine(" ")
            Linha(tooltip, L["Players' tip"], "NORMAL_FONT_COLOR", 1, 0.82, 0)
            for _, l in ipairs(Linhas(dica)) do
                Linha(tooltip, l, "HIGHLIGHT_FONT_COLOR", 1, 1, 1, true)
            end
            if nota then Linha(tooltip, nota, "DISABLED_FONT_COLOR", 0.5, 0.5, 0.5, true) end
            if criatura then tooltip:AddLine(" ") end
        end
    end

    if criatura then
        if total == 1 then tooltip:AddLine(" ") end
        -- How often its loot comes back: daily, weekly, every kill -- or plainly not known yet.
        Linha(tooltip, ns.Sighting.FrequencyText(data.npc), "DISABLED_FONT_COLOR", 0.5, 0.5, 0.5)
        if data.locked then
            tooltip:AddLine(" ")
            local volta = Horas(data.lockLeft)
            local semanal = ns.Sighting.LootFrequency(data.npc) == "weekly"
            Linha(tooltip, volta and string.format(L["Already looted — back in %s"], volta)
                or (semanal and L["Already looted this week"]) or L["Already looted today"],
                "RED_FONT_COLOR", 1, 0.125, 0.125)
        end
    end
    tooltip:AddLine(" ")
    Linha(tooltip, L["Click: point the arrow here"], "GREEN_FONT_COLOR", 0.1, 1, 0.1)
end

function RocketMountMapPinMixin:OnMouseEnter()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    MapPins.Tooltip(GameTooltip, self.data)
    GameTooltip:Show()
end

function RocketMountMapPinMixin:OnMouseLeave()
    GameTooltip:Hide()
end

---The click, where the map delivers it. `OnMouseUp` is Blizzard's, and overriding it (as this
---file did) takes the pin out of the map's own click handling.
function RocketMountMapPinMixin:OnMouseClickAction(button)
    if button ~= "LeftButton" then return end
    local d = self.data
    if not (d and C_Map and C_Map.CanSetUserWaypointOnMap and C_Map.SetUserWaypoint) then return end
    -- The place's own map first (a cave is where the arrow has to lead); the map being looked
    -- at when that one takes no pin.
    local m, x, y = d.homeMap or d.mapID, d.homeX or d.x, d.homeY or d.y
    if not C_Map.CanSetUserWaypointOnMap(m) then m, x, y = d.mapID, d.x, d.y end
    if C_Map.CanSetUserWaypointOnMap(m) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(m, x, y))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end
    end
end

--------------------------------------------------------------------------------
-- Wiring
--------------------------------------------------------------------------------
local provider

function MapPins.Enable()
    if provider or not WorldMapFrame or not WorldMapFrame.AddDataProvider then return end
    provider = CreateFromMixins(RocketMountMapDataProviderMixin)
    WorldMapFrame:AddDataProvider(provider)
end

---Redraw with fresh data: a mount learned, a rare looted, the option toggled.
function MapPins.Refresh()
    indice = nil
    local map = provider and provider.GetMap and provider:GetMap()
    if not map then return end
    -- A closed map draws nothing: it asks every provider again when it opens
    -- (`MapCanvasMixin:OnShow`), and the list changes far more often than the map is looked at.
    if map.IsShown and not map:IsShown() then return end
    pcall(provider.RefreshAllData, provider)
end

function MapPins.GetProvider() return provider end
