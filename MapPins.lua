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
local PIN_SIZE = 20

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
                for i = 1, #pontos - 1, 2 do
                    out[#out + 1] = {
                        npc = npc, rec = rec, mounts = montarias, mapID = mapID,
                        x = pontos[i] / 100, y = pontos[i + 1] / 100,
                        locked = preso, lockSource = fonte, lockLeft = falta,
                    }
                end
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

function MapPins.Tooltip(tooltip, data)
    local nome = ns.db and ns.db.npcNames and ns.db.npcNames[data.npc] or data.rec.name
    tooltip:SetText(nome, 1, 0.82, 0)
    tooltip:AddLine(CLASS_NAME[data.rec.c] or "", 0.7, 0.7, 0.7)
    for _, m in ipairs(data.mounts) do
        local chance = ns.Sighting.ChanceText(m) or "?"
        tooltip:AddDoubleLine(m.entry.name, chance, 1, 1, 1, 1, 1, 1)
    end
    if data.locked then
        local volta = Horas(data.lockLeft)
        tooltip:AddLine(volta and string.format(L["Already looted — back in %s"], volta)
            or L["Already looted today"], 1, 0.35, 0.35)
    end
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
