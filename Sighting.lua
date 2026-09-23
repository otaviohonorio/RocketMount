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
local lastSeen = {}  -- key              -> when we announced it
local frame

-- A point is one place the catalogue puts one mount's rare: `{ entry, m, x, y }`. Carrying the
-- coordinates in the index is what lets the arrow point at the RARE instead of at the player.

--------------------------------------------------------------------------------
-- The index: vignette and name -> the mounts you are missing
--------------------------------------------------------------------------------
local function Push(tabela, chave, ponto)
    if chave == nil or chave == "" then return end
    tabela[chave] = tabela[chave] or {}
    tabela[chave][#tabela[chave] + 1] = ponto
end

---Rebuilt when the list changes, not on every event: a rare showing up is no time to walk four
---hundred mounts.
function Sighting.Rebuild()
    byVignette, byName = {}, {}
    if not ns.GetRanked then return end

    local ok, lista = pcall(ns.GetRanked)
    if not ok or type(lista) ~= "table" then return end

    for _, e in ipairs(lista) do
        -- Only what can still be obtained: alerting about a mount that left the game is a taunt.
        if not e.unobtainable then
            local primeiro
            if e.coords then
                for _, wp in ipairs(e.coords) do
                    local ponto = { entry = e, m = wp.m, x = wp.x, y = wp.y }
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
end

--------------------------------------------------------------------------------
-- The guards
--------------------------------------------------------------------------------
-- The GUID types that are a creature in the world. A player's pet is `Pet`, a totem is
-- `GameObject`, and neither can ever be a rare -- so neither gets in here.
local TIPO_DE_CRIATURA = { Creature = true, Vehicle = true }

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
    if not ok or type(guid) ~= "string" then return nil end
    local tipo = guid:match("^(%a+)%-")
    if not TIPO_DE_CRIATURA[tipo] then return nil end

    local classe = UnitClassification and UnitClassification(unit)
    if classe ~= "rare" and classe ~= "rareelite" then return nil end

    return UnitName(unit)
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
local function Build()
    if frame then return frame end

    frame = CreateFrame("Frame", ADDON .. "Sighting", UIParent, "BackdropTemplate")
    frame:SetSize(280, 64)
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
    frame.icon:SetSize(48, 48)
    frame.icon:SetPoint("LEFT", 8, 0)
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    frame.who = ns.NewText(frame, ns.Skin.rowFontSize, ns.Skin.gold)
    frame.who:SetPoint("TOPLEFT", frame.icon, "TOPRIGHT", 10, -2)
    frame.who:SetWidth(200)
    frame.who:SetWordWrap(false)

    frame.what = ns.NewText(frame, ns.Skin.subFontSize, ns.Skin.text)
    frame.what:SetPoint("TOPLEFT", frame.icon, "TOPRIGHT", 10, -20)
    frame.what:SetWidth(200)
    frame.what:SetJustifyV("TOP")
    frame.what:SetSpacing(2)

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

local function Show(nome, pontos)
    Build()
    local vistas, entradas = {}, {}
    for _, p in ipairs(pontos) do
        if not vistas[p.entry] then
            vistas[p.entry] = true
            entradas[#entradas + 1] = p.entry
        end
    end

    frame.icon:SetTexture(entradas[1] and entradas[1].icon)
    frame.who:SetText(nome)

    local linhas = {}
    for i = 1, math.min(#entradas, 3) do
        linhas[#linhas + 1] = entradas[i].name
    end
    if #entradas > 3 then
        linhas[#linhas + 1] = string.format(L["and %d more"], #entradas - 3)
    end
    frame.what:SetText(table.concat(linhas, "\n"))
    frame:SetHeight(math.max(64, 28 + 14 * #linhas))

    frame:Show()
    -- Guarded BY TYPE: in the harness's simulator any unknown field answers a function, which
    -- is truthy, and then `:Cancel()` tries to index a function.
    if type(frame.__hide) == "table" and frame.__hide.Cancel then frame.__hide:Cancel() end
    if C_Timer and C_Timer.NewTimer then
        frame.__hide = C_Timer.NewTimer(HOLD, function() frame:Hide() end)
    end
    return entradas
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
local LINK_PREFIX = "rocketmounts"

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
local function Announce(chave, nome, pontos)
    if not ns.db or ns.db.sightings == false then return false end
    if not pontos or #pontos == 0 then return false end

    local agora = GetTime and GetTime() or 0
    if lastSeen[chave] and (agora - lastSeen[chave]) < REPEAT_AFTER then return false end
    lastSeen[chave] = agora

    local entradas = Show(nome, pontos)

    local nomes = {}
    for i = 1, math.min(#entradas, 3) do nomes[#nomes + 1] = entradas[i].name end
    local link = ChatLink(pontos[1])
    ns.Print(string.format(L["|cffffff00%s|r can drop: %s%s"], nome,
        table.concat(nomes, ", "), link and ("  " .. link) or ""))
    return true
end

---A vignette the minimap is showing. The precise path: the id is a number and means the same
---thing in every language, so no zone guard is needed -- a vignette you can see is, by
---definition, near you.
function Sighting.SightVignette(vignetteID, nome)
    if not byVignette then Sighting.Rebuild() end
    local pontos = byVignette and byVignette[vignetteID]
    if not pontos then return false end
    return Announce("v:" .. tostring(vignetteID), nome or "?", pontos)
end

---A name, from a unit or from a yell. The fallback path, and the one that needs the zone guard:
---a name on its own proves nothing.
function Sighting.SightName(nome, mapa)
    if not byName then Sighting.Rebuild() end
    local chave = ns.Fold(nome or "")
    if chave == "" then return false end
    local pontos = NoMapaCerto(byName[chave], mapa or MapaAtual())
    if not pontos then return false end
    return Announce("n:" .. chave, nome, pontos)
end

--------------------------------------------------------------------------------
-- Detection
--------------------------------------------------------------------------------
local function VarrerVinhetas()
    if not (C_VignetteInfo and C_VignetteInfo.GetVignettes) then return end
    local ok, lista = pcall(C_VignetteInfo.GetVignettes)
    if not ok or type(lista) ~= "table" then return end
    for _, guid in ipairs(lista) do
        local okI, info = pcall(C_VignetteInfo.GetVignetteInfo, guid)
        if okI and type(info) == "table" and info.vignetteID then
            Sighting.SightVignette(info.vignetteID, info.name)
        end
    end
end

function Sighting.OnEvent(_, event, arg1, arg2)
    if not ns.db or ns.db.sightings == false then return end

    if event == "VIGNETTE_MINIMAP_UPDATED" or event == "VIGNETTES_UPDATED" then
        VarrerVinhetas()
        return
    end

    -- (!) THE YELL NO LONGER ANNOUNCES ON ITS OWN. It used to be the best clue -- it arrives the
    -- instant a rare spawns and carries further than a nameplate. But `arg2` is just a name, with
    -- no unit behind it to classify, so it is the weakest evidence there is. It now goes through
    -- the same zone guard as everything else, which is what makes it safe to keep.
    if event == "CHAT_MSG_MONSTER_YELL" or event == "CHAT_MSG_MONSTER_EMOTE" then
        Sighting.SightName(arg2, nil)
        return
    end

    local unit = arg1
    if event == "UPDATE_MOUSEOVER_UNIT" then unit = "mouseover" end
    if event == "PLAYER_TARGET_CHANGED" then unit = "target" end

    local nome = NomeDeRaro(unit)
    if nome then Sighting.SightName(nome, nil) end
end

function Sighting.Enable()
    if frame and frame.__events then return end
    Build()
    frame.__events = CreateFrame("Frame", ADDON .. "SightingEvents")
    for _, event in ipairs({
        "NAME_PLATE_UNIT_ADDED", "UPDATE_MOUSEOVER_UNIT", "PLAYER_TARGET_CHANGED",
        "CHAT_MSG_MONSTER_YELL", "CHAT_MSG_MONSTER_EMOTE",
        "VIGNETTE_MINIMAP_UPDATED", "VIGNETTES_UPDATED",
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
