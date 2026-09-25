-- RocketMount | MapPins.lua
-- The creatures that drop a mount you are missing, on the world map, with a tooltip.
--
-- The user (23/09): *"como o silverdragon mostra os raros/elites/world bosses no mapa, a gente
-- tbm mostrasse e com uma popup passando o mouse em cima, mostrando qual montaria dropa, a
-- chance"*.
--
-- Built on the map's OWN pin system, the one Blizzard uses for its dig sites
-- (`DigSiteDataProvider.lua`, 12.1.0): a data provider added to `WorldMapFrame`, which acquires
-- one pin per creature on the map being viewed. No library -- SilverDragon uses its own, and it
-- has no licence.
--
--   where   `ns.MobDrops[npc].where`, from Wowhead's map, already in uiMapID
--   what    `Sighting.MountsOf(npc)`: the SAME index the alert uses -- only mounts THIS
--           character is missing, with the chance -- so the map and the alert never disagree
--   state   `Sighting.LockedOut`: looted today (or this week, for a world boss) goes dim
--   where not  instance maps (dungeons, raids): the alert is open-world only, and so is this
local ADDON, ns = ...
local L = ns.L

local MapPins = {}
ns.MapPins = MapPins

local TEMPLATE = "RocketMountMapPinTemplate"
-- 24, up from 20 at the user's request (24/09): "um pouquinho maior". Still under the 25 of
-- the game's own vignette highlight, so it reads as the same family.
local PIN_SIZE = 24
-- Points of the SAME creature closer than this (in map fractions) become one pin. Wowhead gives
-- up to a dozen spawn points, and a patrol drew a cluster where one icon says the same thing.
local NEAR = 0.035
local TIP_ICON = 22     -- the mount's icon in the tooltip

-- Wowhead's classification -> the game's own vignette art (the ones the minimap draws).
local ATLAS = {
    [4] = "VignetteKill",        -- rare
    [2] = "VignetteKillElite",   -- rare elite
    [1] = "VignetteKillElite",   -- elite (Wowhead files bosses here too)
}
local CLASS_NAME = {
    [4] = L["Rare"],
    [2] = L["Rare elite"],
    [1] = L["Elite"],
}

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
        if type(nome) == "string" and nome ~= "" and not (issecretvalue and issecretvalue(nome))
            and nome ~= UNKNOWNOBJECT then
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
function ns.LocalizedCreature(nomeIngles)
    if type(nomeIngles) ~= "string" then return nomeIngles end
    if not porNomeIngles then
        porNomeIngles = {}
        for npc, rec in pairs(ns.MobDrops or {}) do
            if rec.name then porNomeIngles[rec.name] = npc end
        end
    end
    local npc = porNomeIngles[nomeIngles]
    return npc and MapPins.NpcName(npc, nomeIngles) or nomeIngles
end

local function Perto(pontos, x, y)
    for _, p in ipairs(pontos) do
        local dx, dy = p[1] - x, p[2] - y
        if dx * dx + dy * dy < NEAR * NEAR then return true end
    end
    return false
end

---What goes on this map: one entry per point of each creature that still has a mount for you.
function MapPins.PinsFor(mapID)
    local out = {}
    if not (mapID and type(ns.MobDrops) == "table" and ns.Sighting) then return out end
    if ns.db and ns.db.mapPins == false then return out end
    if not MapaAberto(mapID) then return out end
    for npc, rec in pairs(ns.MobDrops) do
        local pontos = rec.where and rec.where[mapID]
        if pontos then
            local montarias = ns.Sighting.MountsOf(npc)
            if #montarias > 0 then
                local preso, fonte, falta = ns.Sighting.LockedOut(npc, montarias)
                MapPins.NpcName(npc)            -- warms the client's name cache for the tooltip
                local postos = {}
                for i = 1, #pontos - 1, 2 do
                    local x, y = pontos[i] / 100, pontos[i + 1] / 100
                    if not Perto(postos, x, y) then
                        postos[#postos + 1] = { x, y }
                        out[#out + 1] = {
                            npc = npc, rec = rec, mounts = montarias, mapID = mapID,
                            x = x, y = y,
                            locked = preso, lockSource = fonte, lockLeft = falta,
                        }
                    end
                end
            end
        end
    end
    MapPins.AddCatalogueRares(out, mapID)
    return out
end

---(!) THE RARES WOWHEAD DOES NOT KNOW (25/09). The user: *"até os raros de midnight, tem alguns
---faltando (...) confere em mais de uma fonte"*. Checked against SilverDragon and MCL: every rare
---in our table sits where they put it -- but some rares that DO drop a mount have no drop recorded
---on Wowhead yet (Farthik the Plunderer; Image of Astalor Bloodsworn, whose mount has no source
---on Wowhead at all), so they were not in the table. MCL knows them, with map, position and the
---daily lockout quest, and the addon already reads MCL at run time -- nothing copied. A rare the
---table already drew on this map is not drawn twice ("Lockjaw" there is "Lockjaw the Snapper"
---here: the names are matched by prefix).
function MapPins.AddCatalogueRares(out, mapID)
    if not (ns.GetRanked and mapID) then return end
    local desenhados = {}
    for _, pin in ipairs(out) do
        desenhados[#desenhados + 1] = (pin.rec.name or ""):lower()
    end
    local function JaTem(nome)
        nome = nome:lower()
        for _, d in ipairs(desenhados) do
            if nome == d or nome:sub(1, #d + 1) == d .. " " or nome:sub(1, #d + 1) == d .. ","
                or d:sub(1, #nome + 1) == nome .. " " then
                return true
            end
        end
        return false
    end
    local ok, lista = pcall(ns.GetRanked)
    if not ok or type(lista) ~= "table" then return end
    local porNome = {}
    for _, e in ipairs(lista) do
        local criatura = e.method == "NPC" or e.method == "BOSS"
        if not e.unobtainable and e.coords then
            for _, wp in ipairs(e.coords) do
                -- A creature, in the open world: not an instance pin (`i`), not a one-time
                -- treasure (`q`), and a rare's daily quest (`dq`) or a creature method.
                if wp.m == mapID and wp.x and wp.y and wp.n and not wp.i and not wp.q
                    and (criatura or wp.dq) and not JaTem(wp.n) then
                    local r = porNome[wp.n]
                    if not r then
                        r = { rec = { name = wp.n, c = 4 }, mounts = {}, pontos = {}, dq = {} }
                        porNome[wp.n] = r
                    end
                    local jaMontaria = false
                    for _, m in ipairs(r.mounts) do if m.entry == e then jaMontaria = true end end
                    if not jaMontaria then r.mounts[#r.mounts + 1] = { entry = e } end
                    if wp.dq then r.dq[#r.dq + 1] = { dq = wp.dq } end
                    local x, y = wp.x / 100, wp.y / 100
                    if not Perto(r.pontos, x, y) then r.pontos[#r.pontos + 1] = { x, y } end
                end
            end
        end
    end
    for _, r in pairs(porNome) do
        local preso, fonte, falta = ns.Sighting.LockedOut(nil, r.dq)
        for _, xy in ipairs(r.pontos) do
            out[#out + 1] = {
                npc = nil, rec = r.rec, mounts = r.mounts, mapID = mapID, x = xy[1], y = xy[2],
                locked = preso, lockSource = fonte, lockLeft = falta, fromCatalogue = true,
            }
        end
    end
end

--------------------------------------------------------------------------------
-- The data provider
--------------------------------------------------------------------------------
RocketMountMapDataProviderMixin = CreateFromMixins(MapCanvasDataProviderMixin)

function RocketMountMapDataProviderMixin:RemoveAllData()
    self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
end

function RocketMountMapDataProviderMixin:RefreshAllData()
    self:RemoveAllData()
    local map = self:GetMap()
    for _, data in ipairs(MapPins.PinsFor(map:GetMapID())) do
        map:AcquirePin(TEMPLATE, data)
    end
end

--------------------------------------------------------------------------------
-- The pin
--------------------------------------------------------------------------------
RocketMountMapPinMixin = CreateFromMixins(MapCanvasPinMixin)

function RocketMountMapPinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_VIGNETTE")
    self:SetScalingLimits(1, 1.0, 1.2)
    self:SetSize(PIN_SIZE, PIN_SIZE)
end

function RocketMountMapPinMixin:OnAcquired(data)
    self.data = data
    self:SetPosition(data.x, data.y)
    self.Texture:SetAtlas(ATLAS[data.rec.c] or "VignetteKill")
    -- LOOTED goes dim, not away: the place is still worth knowing for tomorrow's run.
    self.Texture:SetDesaturated(data.locked and true or false)
    self:SetAlpha(data.locked and 0.5 or 1)
end

local function Horas(segundos)
    if not segundos then return nil end
    local h = math.floor(segundos / 3600)
    if h >= 24 then return string.format(L["%dd"], math.floor(h / 24)) end
    if h >= 1 then return string.format(L["%dh"], h) end
    return string.format(L["%dmin"], math.max(1, math.floor(segundos / 60)))
end

local function Atlas(atlas, size)
    if CreateAtlasMarkup then
        local ok, m = pcall(CreateAtlasMarkup, atlas, size, size)
        if ok and m then return m .. " " end
    end
    return ""
end

---The tooltip, laid out like the game's own: the creature's icon and name as the title, what it
---is underneath, then one line per mount -- its ICON, its name and the chance -- and last what
---the pin does. Names in the client's language: the mount's from the journal, the creature's
---from the game (NpcName).
function MapPins.Tooltip(tooltip, data)
    local nome = data.npc and MapPins.NpcName(data.npc, data.rec.name)
        or (ns.LocalizedCreature and ns.LocalizedCreature(data.rec.name)) or data.rec.name
    tooltip:SetText(Atlas(ATLAS[data.rec.c] or "VignetteKill", 18) .. nome, 1, 0.82, 0)
    tooltip:AddLine(CLASS_NAME[data.rec.c] or "", 0.62, 0.62, 0.62)
    tooltip:AddLine(" ")
    tooltip:AddLine(L["Can drop:"], 1, 0.82, 0)
    for _, m in ipairs(data.mounts) do
        local chance = ns.Sighting.ChanceText(m) or "?"
        local icone = m.entry.icon and string.format("|T%s:%d:%d:0:0|t ", tostring(m.entry.icon), TIP_ICON, TIP_ICON) or ""
        tooltip:AddDoubleLine(icone .. m.entry.name, chance, 1, 1, 1, 1, 0.82, 0)
    end
    if data.locked then
        tooltip:AddLine(" ")
        local volta = Horas(data.lockLeft)
        tooltip:AddLine(volta and string.format(L["Already looted — back in %s"], volta)
            or L["Already looted today"], 1, 0.35, 0.35)
    end
    tooltip:AddLine(" ")
    tooltip:AddLine(L["Click: point the arrow here"], 0.5, 0.8, 1)
end

function RocketMountMapPinMixin:OnMouseEnter()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    MapPins.Tooltip(GameTooltip, self.data)
    GameTooltip:Show()
end

function RocketMountMapPinMixin:OnMouseLeave()
    GameTooltip:Hide()
end

function RocketMountMapPinMixin:OnMouseUp(button)
    if button ~= "LeftButton" then return end
    local d = self.data
    if C_Map and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(d.mapID) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(d.mapID, d.x, d.y))
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
    if provider and provider.GetMap and provider:GetMap() then
        pcall(provider.RefreshAllData, provider)
    end
end

function MapPins.GetProvider() return provider end
