-- RocketMount | MinimapPins.lua
-- The places of the world map, on the minimap: what is within its reach, where the player is.
--
-- (!) THE USER, 28/09, after standing on a marker of the world map and finding nobody:
-- *"poderia até marcar no minimapa também"*. Near the place the world map is the wrong tool --
-- it has to be opened, and a marker of 20 px covers a whole village. The minimap is what the
-- player looks at while walking the last hundred yards.
--
-- NO LIBRARY. The addons that do this use HereBeDragons, and no addon of ours depends on
-- another one. The arithmetic is short and every number is the game's:
--   * where the player is: `UnitPosition` (yards, north and west; nothing inside an instance);
--   * where a place is: `C_Map.GetWorldPosFromMapPos` (the same yards, and the continent);
--   * how far the minimap sees: `C_Minimap.GetViewRadius` (yards, already with the zoom);
--   * which way is up: north, or the player's facing with "rotate minimap" on.
-- What the game does not answer is not drawn: no position, no radius, a secret value.
--
-- The marker is the SYMBOL of the kind of source (the star of a rare, the coins of a vendor,
-- the chest), the game's own art, the same the world map has on the corner of its marker. The
-- mount's icon stays on the world map: at 14 px nobody tells one mount from another.
local ADDON, ns = ...
local L = ns.L

local MinimapPins = {}
ns.MinimapPins = MinimapPins

local SIZE = 14         -- a marker, in pixels: the game's own tracking icons are of this order
local REACH = 0.9       -- of the radius: beyond it the minimap's border art covers the marker
local STEP = 0.1        -- seconds between two looks at where the player is
local LEVEL = 4         -- above the minimap's own art, below its buttons

local pool, usados = {}, 0
local lugares           -- the places of the zone the player is in: { data, instance, n, w }
local sujo = true       -- the list of places has to be read again
local ultimo = {}       -- what the last drawing was made with
local desenhados = {}   -- what is on the minimap now, for the tests and for /rmt pins
local relogio = 0

--------------------------------------------------------------------------------
-- The arithmetic
--------------------------------------------------------------------------------
---Where a place goes on the minimap, in fractions of its radius: right and up of the centre.
---`facing` only with the minimap that turns (radians, counter-clockwise from north).
---@return number|nil dx, number|nil dy nil when the place is out of reach
function MinimapPins.Offset(jn, jw, ln, lw, radius, facing)
    if type(radius) ~= "number" or radius <= 0 then return nil end
    -- The world counts north and WEST as positive; the screen, up and RIGHT.
    local dx, dy = (jw - lw) / radius, (ln - jn) / radius
    if facing then
        -- The map turned with the player: the world turns back by the same angle.
        local s, c = math.sin(facing), math.cos(facing)
        dx, dy = dx * c + dy * s, dy * c - dx * s
    end
    if dx * dx + dy * dy > REACH * REACH then return nil end
    return dx, dy
end

---A number the game gave, that can be read.
local function Numero(v)
    if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
    if type(v) ~= "number" then return nil end
    return v
end

---@return number|nil instance, number|nil north, number|nil west
local function Jogador()
    if type(UnitPosition) ~= "function" then return nil end
    local ok, n, w, _, instancia = pcall(UnitPosition, "player")
    if not ok then return nil end
    n, w, instancia = Numero(n), Numero(w), Numero(instancia)
    if not (n and w and instancia) then return nil end
    return instancia, n, w
end

---@return number|nil instance, number|nil north, number|nil west
local function NoMundo(mapa, x, y)
    if not (mapa and C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local ok, instancia, pos = pcall(C_Map.GetWorldPosFromMapPos, mapa, CreateVector2D(x, y))
    if not ok or type(pos) ~= "table" or type(pos.GetXY) ~= "function" then return nil end
    local n, w = pos:GetXY()
    instancia, n, w = Numero(instancia), Numero(n), Numero(w)
    if not (instancia and n and w) then return nil end
    return instancia, n, w
end

local function Raio()
    if not (C_Minimap and C_Minimap.GetViewRadius) then return nil end
    local ok, r = pcall(C_Minimap.GetViewRadius)
    r = ok and Numero(r) or nil
    return r and r > 0 and r or nil
end

---The player's facing when the minimap turns with it; false when north is up; nil when the
---minimap turns and the game does not say which way the player faces (nothing is drawn).
local function Rumo()
    local gira = GetCVar and GetCVar("rotateMinimap")
    if gira ~= "1" then return false end
    if type(GetPlayerFacing) ~= "function" then return nil end
    local ok, f = pcall(GetPlayerFacing)
    return ok and Numero(f) or nil
end

--------------------------------------------------------------------------------
-- Which places
--------------------------------------------------------------------------------
---The option of the minimap. (The ones of the world map are obeyed by the list of places
---itself: with the markers off, `PinsFor` has nothing to give.)
local function Ligado()
    return not (ns.db and ns.db.minimapPins == false)
end

---The ZONE the player is in: inside a cave the map is the cave's, and the places are the zone's.
local function Zona()
    if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local ok, mapa = pcall(C_Map.GetBestMapForUnit, "player")
    mapa = ok and Numero(mapa) or nil
    local zona = Enum and Enum.UIMapType and Enum.UIMapType.Zone
    local atual, passos = mapa, 0
    while atual and zona and C_Map.GetMapInfo and passos < 6 do
        local okI, info = pcall(C_Map.GetMapInfo, atual)
        if not okI or type(info) ~= "table" then break end
        if info.mapType == zona then return atual end
        -- above a zone there is no zone: the map the player is on is the one
        if type(info.mapType) == "number" and info.mapType < zona then break end
        atual, passos = Numero(info.parentMapID), passos + 1
        if atual == 0 then break end
    end
    return mapa
end

local function Ler()
    lugares, sujo = {}, false
    if not (Ligado() and ns.MapPins and ns.MapPins.PinsFor) then return end
    local mapa = Zona()
    if not mapa then return end
    local ok, pinos = pcall(ns.MapPins.PinsFor, mapa)
    if not ok or type(pinos) ~= "table" then return end
    for _, d in ipairs(pinos) do
        -- The place's own map and coordinates (a cave's), the ones the arrow is pointed at.
        local instancia, n, w = NoMundo(d.homeMap or d.mapID, d.homeX or d.x, d.homeY or d.y)
        if instancia then
            lugares[#lugares + 1] = { data = d, instance = instancia, n = n, w = w }
        end
    end
end

--------------------------------------------------------------------------------
-- The markers
--------------------------------------------------------------------------------
local function Criar()
    local f = CreateFrame("Frame", nil, Minimap)
    f:SetSize(SIZE, SIZE)
    if f.SetFrameLevel and Minimap.GetFrameLevel then
        local nivel = Minimap:GetFrameLevel()
        f:SetFrameLevel((type(nivel) == "number" and nivel or 1) + LEVEL)
    end
    f.Art = f:CreateTexture(nil, "OVERLAY")
    f.Art:SetAllPoints(f)
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
        if not (self.data and GameTooltip and ns.MapPins) then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        ns.MapPins.Tooltip(GameTooltip, self.data)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    f:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self.data and ns.MapPins and ns.MapPins.PointArrow then
            ns.MapPins.PointArrow(self.data)
        end
    end)
    return f
end

local function Vestir(f, d)
    local kind = ns.MapPins.KIND[d.kind] or ns.MapPins.KIND.other
    f.data = d
    -- (The cut is the texture's, and stays when the art changes: a recycled marker is told
    -- its cut every time, the whole art included.)
    f.Art:SetAtlas(kind.atlas)
    ns.MapPins.Crop(f.Art, kind.crop)
    local preso = d.locked and true or false
    if f.Art.SetDesaturated then f.Art:SetDesaturated(preso) end
    f:SetAlpha(preso and 0.5 or 1)
end

---Hide the markers from the `de`-th on: the ones of a place that went out of reach.
local function Esconder(de)
    for i = de, usados do
        local f = pool[i]
        if f then
            f:Hide()
            f.data = nil
        end
    end
    usados = math.min(usados, de - 1)
end

---Nothing to draw: every marker goes, and the next look draws from scratch.
local function Nada()
    Esconder(1)
    ultimo, desenhados = {}, {}
    return desenhados
end

---Draw what is within reach. `forcar` draws even when nothing moved.
---@return table|nil what is on the minimap; nil when nothing changed and nothing was touched
function MinimapPins.Update(forcar)
    if sujo then
        Ler()
        forcar = true
    end
    if not (Ligado() and Minimap and lugares and #lugares > 0) then return Nada() end
    local instancia, n, w = Jogador()
    local raio = Raio()
    local rumo = Rumo()
    if not (instancia and raio) or rumo == nil then return Nada() end
    local largura, altura = Numero(Minimap:GetWidth()), Numero(Minimap:GetHeight())
    if not (largura and altura) then return Nada() end
    if not forcar and ultimo.n == n and ultimo.w == w and ultimo.raio == raio and ultimo.rumo == rumo
        and ultimo.instancia == instancia and ultimo.largura == largura then
        return nil
    end
    ultimo = { n = n, w = w, raio = raio, rumo = rumo, instancia = instancia, largura = largura }

    local novos, i = {}, 0
    for _, l in ipairs(lugares) do
        if l.instance == instancia then
            local dx, dy = MinimapPins.Offset(n, w, l.n, l.w, raio, rumo or nil)
            if dx then
                i = i + 1
                local f = pool[i]
                if not f then
                    f = Criar()
                    pool[i] = f
                end
                Vestir(f, l.data)
                f:ClearAllPoints()
                f:SetPoint("CENTER", Minimap, "CENTER", dx * largura / 2, dy * altura / 2)
                f:Show()
                novos[#novos + 1] = { data = l.data, x = dx * largura / 2, y = dy * altura / 2, frame = f }
            end
        end
    end
    Esconder(i + 1)
    usados = i
    desenhados = novos
    return desenhados
end

---What is on the minimap now: `{ { data, x, y }, ... }`, in pixels from its centre.
function MinimapPins.Shown()
    return desenhados
end

---The list changed, the option changed, the player changed zone: read again at the next look.
function MinimapPins.Refresh()
    sujo = true
end

--------------------------------------------------------------------------------
-- Wiring
--------------------------------------------------------------------------------
local frame

function MinimapPins.Enabled()
    return frame ~= nil
end

function MinimapPins.Enable()
    if frame or not Minimap then return end
    frame = CreateFrame("Frame")
    for _, evento in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED",
                              "ZONE_CHANGED_INDOORS" }) do
        pcall(frame.RegisterEvent, frame, evento)
    end
    frame:SetScript("OnEvent", function() sujo = true end)
    frame:SetScript("OnUpdate", function(_, passado)
        relogio = relogio + (tonumber(passado) or 0)
        if relogio < STEP then return end
        relogio = 0
        -- One marker that fails must not leave the minimap throwing an error every tenth of
        -- a second: the markers go, and the next change of zone tries again.
        local ok = pcall(MinimapPins.Update)
        if not ok then
            lugares, sujo = {}, false
            pcall(Esconder, 1)
        end
    end)
end
