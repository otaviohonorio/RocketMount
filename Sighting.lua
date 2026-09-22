-- RocketMounts | Sighting.lua
-- Tells you when something in front of you can drop a mount you are missing.
--
-- (!) NO NEW DATA WAS NEEDED FOR THIS. The catalogue already records, per mount, the name of the
-- boss or rare that drops it (`lockBossName`) and the names on its map pins (`coords[].n`). Turn
-- that inside out -- name -> mounts -- and the addon can recognise a mob the moment it appears.
--
-- The detection path is the one MCL uses, and it is proven: nameplates, mouseover, target, and
-- the yells rares make when they spawn. The yell is the best of them, because it carries further
-- than the minimap and lands the instant the rare appears.
--
-- WHAT MAKES THIS DIFFERENT FROM SILVERDRAGON, which the player already has: SilverDragon tells
-- you a rare is there. This tells you **a mount you are missing** is there, and which one. A rare
-- whose mount you already collected says nothing at all -- that is the whole point of it living
-- in this addon and not being a second rare scanner.
local ADDON, ns = ...

local Sighting = {}
ns.Sighting = Sighting

-- Um aviso por bicho a cada dez minutos. Sem isso, um raro parado na sua frente dispara a cada
-- placa de nome que aparece e reaparece -- e aviso repetido vira aviso ignorado.
local REPEAT_AFTER = 600

local index          -- nome dobrado -> { entradas }
local lastSeen = {}  -- nome dobrado -> quando avisamos
local frame

--------------------------------------------------------------------------------
-- O índice: nome de bicho -> montarias que faltam
--------------------------------------------------------------------------------
---Refeito quando a lista muda, e não a cada evento: um raro aparecendo não é hora de varrer
---quatrocentas montarias.
function Sighting.Rebuild()
    index = {}
    if not ns.GetRanked then return end

    local ok, lista = pcall(ns.GetRanked)
    if not ok or type(lista) ~= "table" then return end

    for _, e in ipairs(lista) do
        -- Só o que dá para conseguir: avisar sobre uma montaria que saiu do jogo é provocação.
        if not e.unobtainable then
            local nomes = {}
            if e.bossName then nomes[#nomes + 1] = e.bossName end
            if e.coords then
                for _, wp in ipairs(e.coords) do
                    if wp.n then nomes[#nomes + 1] = wp.n end
                end
            end
            for _, nome in ipairs(nomes) do
                local chave = ns.Fold(nome)
                if chave ~= "" then
                    index[chave] = index[chave] or {}
                    index[chave][#index[chave] + 1] = e
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- O aviso
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

-- Some sozinho: aviso que fica na tela vira parte do cenário e para de ser lido.
local HOLD = 12

local function Show(nome, entradas)
    Build()
    local primeira = entradas[1]

    frame.icon:SetTexture(primeira.icon)
    frame.who:SetText(nome)

    local linhas = {}
    for i = 1, math.min(#entradas, 3) do
        linhas[#linhas + 1] = entradas[i].name
    end
    if #entradas > 3 then
        linhas[#linhas + 1] = string.format("e mais %d", #entradas - 3)
    end
    frame.what:SetText(table.concat(linhas, "\n"))
    frame:SetHeight(math.max(64, 28 + 14 * #linhas))

    frame:Show()
    -- Guarda pelo TIPO: no simulador do harness qualquer campo desconhecido responde uma
    -- função, que é verdadeira, e aí o `:Cancel()` tenta indexar função. Já estourou uma vez
    -- hoje com a caixa de busca; a guarda por tipo vale nos dois lados.
    if type(frame.__hide) == "table" and frame.__hide.Cancel then frame.__hide:Cancel() end
    if C_Timer and C_Timer.NewTimer then
        frame.__hide = C_Timer.NewTimer(HOLD, function() frame:Hide() end)
    end
end

--------------------------------------------------------------------------------
-- O link do chat
--------------------------------------------------------------------------------
-- (!) UM LINK CLICÁVEL PRÓPRIO, e não um botão na caixa de aviso.
--
-- O pedido foi *"no chat um link para clicar e marcar a posição"*, e o chat é o lugar certo: a
-- caixa some em doze segundos, a linha do chat fica. Quem estava em combate quando o raro
-- apareceu ainda acha o link depois.
--
-- `SetItemRef` é o funil de TODO clique em link do jogo; o gancho reconhece o nosso prefixo e
-- deixa os outros passarem. O prefixo tem o nome do addon justamente para não colidir.
local LINK_PREFIX = "rocketmounts"

local function ChatLink(nome)
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local x, y = 0, 0
    if mapID and C_Map.GetPlayerMapPosition then
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        if pos and pos.GetXY then
            local px, py = pos:GetXY()
            x, y = math.floor((px or 0) * 10000), math.floor((py or 0) * 10000)
        end
    end
    if not mapID then return nil end

    return string.format("|cff71d5ff|H%s:%d:%d:%d|h[%s]|h|r",
        LINK_PREFIX, mapID, x, y, "marcar onde vi")
end

function Sighting.HandleLink(link)
    local mapID, x, y = link:match("^" .. LINK_PREFIX .. ":(%d+):(%d+):(%d+)$")
    if not mapID then return false end
    mapID, x, y = tonumber(mapID), tonumber(x) / 10000, tonumber(y) / 10000

    if C_Map and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(mapID) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end
        ns.Print("seta apontada para onde você viu.")
    else
        ns.Print("este mapa não aceita marcação.")
    end
    return true
end

--------------------------------------------------------------------------------
-- A detecção
--------------------------------------------------------------------------------
local function Announce(nome)
    if not ns.db or ns.db.sightings == false then return end
    if not index then Sighting.Rebuild() end

    local chave = ns.Fold(nome or "")
    local entradas = chave ~= "" and index[chave]
    if not entradas or #entradas == 0 then return end

    local agora = GetTime and GetTime() or 0
    if lastSeen[chave] and (agora - lastSeen[chave]) < REPEAT_AFTER then return end
    lastSeen[chave] = agora

    Show(nome, entradas)

    local nomes = {}
    for i = 1, math.min(#entradas, 3) do nomes[#nomes + 1] = entradas[i].name end
    local link = ChatLink(nome)
    ns.Print(string.format("|cffffff00%s|r pode largar: %s%s", nome,
        table.concat(nomes, ", "), link and ("  " .. link) or ""))
end

Sighting.Announce = Announce

-- O nome de uma unidade, quando ela existe, não é jogador e está viva.
local function NameOf(unit)
    if not unit or not UnitExists(unit) then return nil end
    if UnitIsPlayer(unit) or UnitIsDead(unit) then return nil end
    return UnitName(unit)
end

function Sighting.OnEvent(_, event, arg1, arg2)
    if not ns.db or ns.db.sightings == false then return end

    -- O GRITO É A MELHOR PISTA, e por isso vem primeiro: ele chega no instante em que o raro
    -- aparece e alcança mais longe que a placa de nome. `arg2` é quem falou.
    if event == "CHAT_MSG_MONSTER_YELL" or event == "CHAT_MSG_MONSTER_EMOTE" then
        Announce(arg2)
        return
    end

    local unit = arg1
    if event == "UPDATE_MOUSEOVER_UNIT" then unit = "mouseover" end
    if event == "PLAYER_TARGET_CHANGED" then unit = "target" end

    local nome = NameOf(unit)
    if nome then Announce(nome) end
end

function Sighting.Enable()
    if frame and frame.__events then return end
    Build()
    frame.__events = CreateFrame("Frame", ADDON .. "SightingEvents")
    for _, event in ipairs({
        "NAME_PLATE_UNIT_ADDED", "UPDATE_MOUSEOVER_UNIT", "PLAYER_TARGET_CHANGED",
        "CHAT_MSG_MONSTER_YELL", "CHAT_MSG_MONSTER_EMOTE",
    }) do
        pcall(frame.__events.RegisterEvent, frame.__events, event)
    end
    frame.__events:SetScript("OnEvent", Sighting.OnEvent)

    -- O gancho do clique em link. `hooksecurefunc` deixa o comportamento original intacto: se o
    -- link não é nosso, o jogo trata como sempre tratou.
    if not Sighting.__hooked and hooksecurefunc then
        hooksecurefunc("SetItemRef", function(link)
            Sighting.HandleLink(link)
        end)
        Sighting.__hooked = true
    end
end
