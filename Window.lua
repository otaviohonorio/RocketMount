-- RocketMount | Window.lua
-- The window: the ranked list on the left, the card of the chosen mount on the right.
--
-- (!) REBUILT ON BLIZZARD'S OWN PARTS (23/09). The user put this window next to RocketSwap's in
-- one screenshot and asked for the same *"cara de Blizzard"*. This one was drawn by hand -- a
-- flat colour backdrop, the damage meter's header strip, a glyph for a close button, the old
-- `UIPanelScrollFrameTemplate` with its arrow buttons and self-painted rows -- and next to a
-- native frame every one of those reads as a stranger.
--
-- The reference is the game's own MOUNT JOURNAL (`Blizzard_MountCollection.xml`, 12.1.0, read
-- in the Gethe/wow-ui-source mirror), because it is the same content: a list of mounts with a
-- search, a filter and a detail pane. Every number below that is not derived is from there or
-- from RocketSwap's window, which follows the same template:
--
--   frame      `ButtonFrameTemplate`: portrait, title, close button, Esc, footer band of 26
--   counter    `InsetFrameTemplate3`, 130x20 at (70, -35) -- the journal's "Total" box
--   list       the template's `Inset` from y -60; search (SearchBoxTemplate) and filter
--              (`WowStyle1FilterDropdownTemplate`, width 90) INSIDE its top 36 px, like the
--              journal; `WowScrollBoxList` + `MinimalScrollBar` below them
--   row        `MountListButtonTemplate`'s parts: 46 high, `PetList-ButtonBackground`, select
--              and highlight atlases, 38 icon hanging in a 44 left padding, name in
--              `GameFontNormal`, the second line in `GameFontDisableSmall`
--   card       on the window background, not an inset -- RocketSwap's right column: the
--              inset's marble is a LIST background
local ADDON, ns = ...
local L = ns.L

local S = ns.Skin

-- The template's anatomy (`PANEL_INSET_*`, `SharedUIPanelTemplates.lua:4-9`; RocketSwap UI.lua).
local INSET_X = 4             -- the inset's left edge
local LIST_TOP = -60          -- top of the inset: below the portrait (disc of 58 at (26, -22))
local FOOTER = 26             -- the band the template reserves at the bottom
local ATTIC_Y = -35           -- the counter's line, between the title and the inset
local GUTTER = 20             -- between the list and the card (MountJournal, RocketSwap)
local RIGHT_MARGIN = 20       -- the card's art ends 20 from the right edge (RocketSwap)

-- The list column. The inset holds, on top, the search row (36, as in the journal) and the
-- column headers under it; the scroll box starts below both, 3 in from each side; the scroll bar
-- sits inside the inset's right side.
--
-- (!) WIDER AND WITH COLUMNS (25/09). The user: one list instead of bands, with tags, filter by
-- expansion, *"alarga a tela para incluir mais estes elementos na linha e pode engrossar um
-- pouco a linha"*. 460 -> 660 buys the Type and Expansion columns; the card keeps its 360.
local LIST_W = 660
local SEARCH_H = 36
local HEADER_H = 26
local SEARCH_ROW = SEARCH_H + HEADER_H   -- where the scroll box starts inside the inset
local SCROLLBAR_W = 17        -- what `AddManagedScrollBarVisibilityBehavior` gives up (RocketSwap)
local ROW_PAD = 44            -- the journal's left padding: room for the icon hanging off the row

-- Reading measure: the card is prose (Blizzard's "how to get it", the check-the-vendor note),
-- and running text wants 45 to 75 characters a line. At the game's 12pt, 360px is ~60.
local DETAIL_W = 360

local COL_X = INSET_X + LIST_W + GUTTER
local WINDOW_W = COL_X + DETAIL_W + RIGHT_MARGIN
local WINDOW_H = 580

-- The row and its columns. Every x is derived from the one before it, so a column that grows
-- pushes the next instead of sitting on it -- the geometry test checks every gap.
local ROW_H = 54              -- 46 in the journal; "engrossar um pouco" (25/09)
local ROW_ICON = 42
local ROW_W = LIST_W - 3 - 3 - SCROLLBAR_W - ROW_PAD
local COL_GAP = 10
local NAME_X, NAME_W = 6, 244           -- name, and the "why" line under it
local TAG_X, TAG_W = NAME_X + NAME_W + COL_GAP, 150
local EXP_X, EXP_W = TAG_X + TAG_W + COL_GAP, 96
local PCT_W, PCT_INSET = 56, 8
local PCT_X = ROW_W - PCT_INSET - PCT_W

ns.Geometry = {
    windowW = WINDOW_W, windowH = WINDOW_H,
    insetX = INSET_X, listW = LIST_W, gutter = GUTTER, colX = COL_X,
    detailW = DETAIL_W, rightMargin = RIGHT_MARGIN,
    scrollbarW = SCROLLBAR_W, rowPad = ROW_PAD,
    rowW = ROW_W, rowH = ROW_H, listTop = LIST_TOP, footer = FOOTER,
    cols = {
        { name = "name", x = NAME_X, w = NAME_W }, { name = "tag", x = TAG_X, w = TAG_W },
        { name = "exp", x = EXP_X, w = EXP_W }, { name = "pct", x = PCT_X, w = PCT_W },
    },
}

local window, list, detail
local selected           -- the entry on the card, matched by mountID across rebuilds
-- Which recycled frames were already built. A field on the frame (`row.built`) would do in the
-- game, but the harness answers every unknown field with a function -- truthy -- and the row
-- was never built there. A table of our own means the same thing in both.
local built = setmetatable({}, { __mode = "k" })

local function Text(parent, fontObject, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", fontObject)
    fs:SetJustifyH(justify or "LEFT")
    return fs
end

local function Same(a, b)
    return a ~= nil and b ~= nil and (a == b or (a.mountID ~= nil and a.mountID == b.mountID))
end

--------------------------------------------------------------------------------
-- The card (right column)
--------------------------------------------------------------------------------

local function BuildDetail(parent)
    local d = CreateFrame("Frame", nil, parent)
    d:SetSize(DETAIL_W, WINDOW_H + LIST_TOP - FOOTER)

    d.icon = d:CreateTexture(nil, "ARTWORK")
    d.icon:SetSize(48, 48)
    d.icon:SetPoint("TOPLEFT", 0, 0)

    d.name = Text(d, "GameFontNormalLarge")
    d.name:SetPoint("TOPLEFT", d.icon, "TOPRIGHT", 10, -4)
    d.name:SetWidth(DETAIL_W - 58)
    d.name:SetJustifyV("TOP")

    d.tier = Text(d, "GameFontHighlightSmall")
    d.tier:SetPoint("TOPLEFT", d.name, "BOTTOMLEFT", 0, -4)
    d.tier:SetWidth(DETAIL_W - 58)

    d.rule = d:CreateTexture(nil, "ARTWORK")
    d.rule:SetColorTexture(1, 0.82, 0, 0.25)
    d.rule:SetPoint("TOPLEFT", d.icon, "BOTTOMLEFT", 0, -10)
    d.rule:SetSize(DETAIL_W, 1)

    -- A stack of "label above, text below" blocks. Stacking is right here: this is free text
    -- the full width of the column, not a form field.
    d.blocks = {}
    for i = 1, 6 do
        local b = {}
        b.label = Text(d, "GameFontNormal")
        b.value = Text(d, "GameFontHighlight")
        b.value:SetWidth(DETAIL_W)
        b.value:SetJustifyV("TOP")
        b.value:SetSpacing(2)
        d.blocks[i] = b
    end

    d.waypoint = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
    d.waypoint:SetSize(160, 22)
    d.waypoint:SetText(L["Set map pin"])
    d.waypoint:Hide()

    d.empty = Text(d, "GameFontDisable")
    d.empty:SetPoint("TOPLEFT", 0, -6)
    d.empty:SetWidth(DETAIL_W)
    d.empty:SetText(L["Pick a mount in the list to see how it is obtained."])

    return d
end

local function ZoneLine(entry)
    if not entry.coords or not entry.coords[1] then return nil, nil end
    local wp = entry.coords[1]
    local zone
    if wp.m and C_Map and C_Map.GetMapInfo then
        local info = C_Map.GetMapInfo(wp.m)
        zone = info and info.name
    end
    if not zone then return nil, wp end
    if wp.x and wp.y then
        return string.format("%s  %.1f, %.1f%s", zone, wp.x, wp.y, wp.n and (" — " .. wp.n) or ""), wp
    end
    return zone, wp
end

-- (!) O CONTEÚDO DA FICHA SE MONTA FORA DO DESENHO.
--
-- A regra morava dentro do código que pinta widget, e por isso o harness não tinha como
-- olhar para ela. Foi assim que a mesma informação chegou a aparecer três vezes na ficha
-- sem nenhum teste reclamar. Separada, esta é uma função pura: entra a montaria, sai a
-- lista de blocos, e o teste lê a lista.
---@return table blocos `{ { label, value }, ... }`, na ordem da ficha
---@return table|nil wp o ponto do mapa, para o botão de seta
function ns.DetailBlocks(entry)
    local blocks = {}
    local function Block(label, value)
        if not value or value == "" then return end
        blocks[#blocks + 1] = { label = label, value = value }
    end

    -- O texto da própria Blizzard. É o melhor "como pega" que existe, e já vem traduzido.
    Block(L["How to get it"], entry.sourceText and entry.sourceText ~= "" and entry.sourceText
        or ns.SOURCE_NAMES[entry.sourceType])

    if entry.chance and entry.chance > 0 then
        -- (Era "1 em %d" em portugues fixo no codigo: saia em portugues para quem joga em ingles.)
        local txt = ns.FormatChance(entry.chance)
        if entry.bossName then
            txt = txt .. "\n" .. (ns.LocalizedCreature and ns.LocalizedCreature(entry.bossName) or entry.bossName)
        end
        Block(L["Chance"], txt)
    end

    -- Requisito e aquisição são blocos separados de propósito: misturar os dois é o que
    -- fazia a lista anunciar "100%" numa montaria que ainda depende de sorte.
    -- A EXPANSÃO, no alto da ficha: é a primeira coisa que situa a montaria, e sem ela o
    -- jogador lê "Vendedor em Valdrakken" sem saber de que época aquilo é.
    if entry.expansionName then
        Block(L["Expansion"], entry.expansionName)
    end

    if entry.factionOnly then
        -- FACÇÃO É INFORMAÇÃO, e antes ela só servia para esconder a montaria. Quem planeja o
        -- outro lado precisa saber que ela existe e de quem ela é.
        Block(L["Faction"], entry.factionOnly == "Horde" and L["Horde only"] or L["Alliance only"])
    end

    -- (!) A FICHA LISTA TODOS OS REQUISITOS, um por linha, com o estado de cada um.
    --
    -- Ela ja mostrou so o mais atrasado, e o usuario bateu de frente com o resultado disso:
    -- *"falta cristal de ressonancia mas que tambem falta reputacao"*. Uma montaria com dois
    -- requisitos que anuncia so um deles manda o jogador para a metade do caminho.
    local p = entry.requirementFrom and entry[entry.requirementFrom]
    if entry.requisitos and #entry.requisitos > 0 then
        local linhas = {}
        for _, r in ipairs(entry.requisitos) do
            linhas[#linhas + 1] = (r.cumprido and "|cff55dd66+|r  " or "|cffff5a52x|r  ")
                .. (r.label or "?")
        end
        Block(entry.faltando > 0
            and string.format(L["Requirements — %d of %d missing"], entry.faltando, #entry.requisitos)
            or L["Requirements — all met"],
            table.concat(linhas, string.char(10)))
    end

    -- QUAL PERSONAGEM TEM. A API só fala do conectado; esta lista vem do livro-caixa, que é
    -- escrito quando cada personagem entra. Por isso ela diz "pelo que ficou anotado" — uma
    -- anotação velha se passando por leitura ao vivo seria pior que anotação nenhuma.
    if p and p.unreadable and entry.rep and entry.rep.factionId ~= nil and ns.Roster then
        local quem = ns.Roster.WhoHas(entry.rep.factionId)
        if #quem > 0 then
            local linhas = {}
            for i = 1, math.min(#quem, 5) do
                local c = quem[i]
                linhas[#linhas + 1] = string.format("%s — %s", c.name,
                    _G["FACTION_STANDING_LABEL" .. c.reaction] or "?")
            end
            Block(L["Who has it, from what was recorded"],
                table.concat(linhas, string.char(10)))
        end
    end

    -- (!) O PREÇO NÃO TEM BLOCO PRÓPRIO, e isso é correção, não esquecimento.
    --
    -- Ele tinha: "Requisitos" listava o preço, e logo abaixo vinham "Preço" e "Falta" dizendo a
    -- mesma coisa outra vez. O usuário viu isso rodando: *"tem o Requisitos, tem o preço e o
    -- Falta, às vezes tem as mesmas informações"*. Três linhas para um fato só.
    --
    -- Preço É um requisito, e o lugar dele é a lista com os outros — com o mesmo sinal de
    -- cumprido, e contado no "faltam N de M". A exigência antiga continua valendo dentro da
    -- linha: o que ela custa primeiro, o que falta depois, nunca os dois números grudados
    -- (`CostProgress` monta esse texto, e é lá que ele vive).

    if entry.gated and not entry.deterministic then
        Block(L["Heads up"],
            L["The requirement above only UNLOCKS the attempt. Once met, the mount still depends on luck."])
    end

    -- ⛑ O AVISO QUE FALTAVA. O addon só enxerga reputação, renome, conquista, moeda e ouro.
    -- Conquista de guilda, nível de guilda, classificação de PvP e perícia de profissão ele NÃO
    -- lê — e foi por calar sobre isso que a Fênix Negra apareceu como "é só ir pegar".
    if entry.tier == ns.TIER.CHECK then
        local texto
        if entry.vendorGuilda then
            -- ESPECÍFICO quando dá para ser: toda montaria de vendedor de guilda exige
            -- reputação com a guilda mais uma conquista de guilda.
            texto = L["Guild vendor. These ask for reputation with your guild AND an achievement OF THE GUILD — and the achievement is the part I cannot read, because no installed catalogue says which achievement belongs to which mount. The price shown in the requirements is only part of what it costs."]
        else
            texto = L["Of what I can read, only the price shows up on this mount — and price is almost never what blocks. There may be an achievement, a guild level or a rating in the way, and those I do not read."]
            if entry.vendorVago then
                texto = texto .. L[" Not even the catalogue knows which vendor this one has."]
            end
        end
        Block(L["Why check"], texto)
    end

    local zone, wp = ZoneLine(entry)
    if zone then Block(L["Where"], zone) end

    if entry.ownedByPct then
        Block(L["How many players own it"], string.format(L["%.1f%% of the playerbase"], entry.ownedByPct))
    end

    if entry.blackMarket then
        Block(L["Also shows up at"], L["Black Market"])
    end

    return blocks, wp
end


local function FillDetail(entry)
    local d = detail
    for i = 1, #d.blocks do
        d.blocks[i].label:Hide()
        d.blocks[i].value:Hide()
    end
    d.waypoint:Hide()

    if not entry then
        d.icon:Hide(); d.name:Hide(); d.tier:Hide(); d.rule:Hide()
        d.empty:Show()
        return
    end
    d.empty:Hide()
    d.icon:Show(); d.name:Show(); d.tier:Show(); d.rule:Show()

    d.icon:SetTexture(entry.icon)
    d.name:SetText(entry.name)

    -- What the mount is (the row's tags) and its expansion, instead of a band name the list no
    -- longer shows.
    local _, tags = ns.Tags(entry)
    local nomes = {}
    for _, k in ipairs(tags) do nomes[#nomes + 1] = ns.TAG_NAME[k] end
    local linha = table.concat(nomes, " · ")
    local exp = entry.expansion and ns.ExpansionLabel(entry.expansion, entry.expansionName)
    if exp then linha = (linha ~= "" and (linha .. "  —  ") or "") .. exp end
    d.tier:SetText(linha)
    d.tier:SetTextColor(S.dim[1], S.dim[2], S.dim[3])

    local blocks, wp = ns.DetailBlocks(entry)
    local n = math.min(#blocks, #d.blocks)
    for i = 1, n do
        local b = d.blocks[i]
        b.label:SetText(blocks[i].label)
        b.value:SetText(blocks[i].value)
        b.label:Show(); b.value:Show()
    end

    -- Stacked: 2 inside (label -> its text), 10 outside. The 5x ratio Blizzard uses in its one
    -- stacked form (`CommunitiesSettings.xml`).
    local anchor, y = d.rule, -10
    for i = 1, n do
        local b = d.blocks[i]
        b.label:ClearAllPoints()
        b.label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y)
        b.value:ClearAllPoints()
        b.value:SetPoint("TOPLEFT", b.label, "BOTTOMLEFT", 0, -2)
        anchor, y = b.value, -10
    end

    if wp and wp.m and wp.x and wp.y and C_Map and C_Map.CanSetUserWaypointOnMap
        and C_Map.CanSetUserWaypointOnMap(wp.m) then
        d.waypoint:ClearAllPoints()
        d.waypoint:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -14)
        d.waypoint:SetScript("OnClick", function()
            local point = UiMapPoint.CreateFromCoordinates(wp.m, wp.x / 100, wp.y / 100)
            C_Map.SetUserWaypoint(point)
            if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
                C_SuperTrack.SetSuperTrackedUserWaypoint(true)
            end
            ns.Print(string.format(L["arrow pointed at %s."], entry.name or L["the mount"]))
        end)
        d.waypoint:Show()
    end
end

--------------------------------------------------------------------------------
-- The list: one kind of row, with columns
--------------------------------------------------------------------------------

---A mount row, built once. The scroll box recycles frames, so everything that depends on the
---mount goes in `FillRow`, never here.
local function BuildRow(row)
    if built[row] then return end
    built[row] = true
    row:SetSize(ROW_W, ROW_H)

    row.background = row:CreateTexture(nil, "BACKGROUND")
    row.background:SetAllPoints()
    row.background:SetAtlas("PetList-ButtonBackground")

    row.icon = row:CreateTexture(nil, "BORDER")
    row.icon:SetSize(ROW_ICON, ROW_ICON)
    row.icon:SetPoint("LEFT", -(ROW_ICON + 4), 0)

    row.selectedTexture = row:CreateTexture(nil, "OVERLAY")
    row.selectedTexture:SetAllPoints()
    row.selectedTexture:SetAtlas("PetList-ButtonSelect")
    row.selectedTexture:Hide()

    row:SetHighlightAtlas("PetList-ButtonHighlight")

    row.name = Text(row, "GameFontNormal")
    row.name:SetPoint("TOPLEFT", NAME_X, -10)
    row.name:SetWidth(NAME_W)
    row.name:SetWordWrap(false)

    row.why = Text(row, "GameFontDisableSmall")
    row.why:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
    row.why:SetWidth(NAME_W)
    row.why:SetWordWrap(false)

    -- The TAGS, in the column the header filters. Two lines at most: a mount rarely is more than
    -- "Raid · Drop" or "Reputation · Vendor", and a third tag is in the card.
    row.tags = Text(row, "GameFontHighlightSmall")
    row.tags:SetPoint("LEFT", TAG_X, 0)
    row.tags:SetWidth(TAG_W)
    row.tags:SetJustifyV("MIDDLE")

    row.exp = Text(row, "GameFontDisableSmall")
    row.exp:SetPoint("LEFT", EXP_X, 0)
    row.exp:SetWidth(EXP_W)
    row.exp:SetWordWrap(false)

    row.headline = Text(row, "GameFontHighlight", "RIGHT")
    row.headline:SetPoint("RIGHT", -PCT_INSET, 0)
    row.headline:SetWidth(PCT_W)

    row:SetScript("OnEnter", function(self)
        local e = self.entry
        if e and e.description and e.description ~= "" then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(e.name, 1, 0.82, 0)
            GameTooltip:AddLine(e.description, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self)
        selected = self.entry
        FillDetail(selected)
        if list and list.ForEachFrame then
            list:ForEachFrame(function(f)
                if type(f.selectedTexture) == "table" then
                    f.selectedTexture:SetShown(Same(f.entry, selected))
                end
            end)
        end
    end)
end

local function FillRow(row, data)
    BuildRow(row)
    local e = data.entry
    row.entry = e
    row.icon:SetTexture(e.icon)
    row.name:SetText(e.name)
    row.why:SetText(e.why or "")

    local _, tags = ns.Tags(e)
    local nomes = {}
    for i = 1, math.min(#tags, 2) do nomes[#nomes + 1] = ns.TAG_NAME[tags[i]] end
    row.tags:SetText(table.concat(nomes, " · "))
    row.exp:SetText(e.expansion and ns.ExpansionLabel(e.expansion, e.expansionName) or "")

    row.headline:SetText(ns.RowPercentText(e))
    -- White for a number, green for "ready", grey for "cannot be measured": no band colours, the
    -- list has no bands any more.
    if e.tier == ns.TIER.READY then
        row.headline:SetTextColor(0.30, 0.85, 0.40)
    elseif ns.RowPercent(e) == nil then
        row.headline:SetTextColor(S.dim[1], S.dim[2], S.dim[3])
    else
        row.headline:SetTextColor(1, 1, 1)
    end
    row.selectedTexture:SetShown(Same(e, selected))
end

---What the scroll box shows: one element per mount, in the window's order.
function ns.ListElements(entries)
    local items = {}
    for _, e in ipairs(entries) do items[#items + 1] = { entry = e } end
    return items
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

-- (!) THE 100-ROW CEILING IS GONE (0.10.0), and it was the cause of *"tá faltando MUITA
-- montaria nessa lista"*: the list is sorted by effort, recent-expansion mounts are almost always
-- far down, and the cut removed exactly what the player wanted to check. The ceiling existed for
-- performance; the right answer was not to build what is not on screen -- which is what the
-- scroll box does.
--------------------------------------------------------------------------------
-- The loading bar, while the validation runs (Core.lua)
--------------------------------------------------------------------------------
local loading

local function BuildLoading(host)
    loading = CreateFrame("Frame", nil, host)
    loading:SetPoint("TOPLEFT", host, "TOPLEFT", 20, -SEARCH_ROW - 40)
    loading:SetPoint("TOPRIGHT", host, "TOPRIGHT", -20, -SEARCH_ROW - 40)
    loading:SetHeight(60)

    loading.text = Text(loading, "GameFontNormal", "CENTER")
    loading.text:SetPoint("TOP")
    loading.text:SetPoint("LEFT")
    loading.text:SetPoint("RIGHT")
    loading.text:SetText(L["Checking every mount for this character…"])

    loading.bar = CreateFrame("StatusBar", nil, loading)
    loading.bar:SetPoint("TOPLEFT", loading.text, "BOTTOMLEFT", 20, -12)
    loading.bar:SetPoint("TOPRIGHT", loading.text, "BOTTOMRIGHT", -20, -12)
    loading.bar:SetHeight(14)
    loading.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    loading.bar:SetStatusBarColor(1, 0.82, 0)
    loading.bar:SetMinMaxValues(0, 1)
    loading.bar.bg = loading.bar:CreateTexture(nil, "BACKGROUND")
    loading.bar.bg:SetAllPoints()
    loading.bar.bg:SetColorTexture(0, 0, 0, 0.5)

    loading.detail = Text(loading, "GameFontHighlightSmall", "CENTER")
    loading.detail:SetPoint("TOP", loading.bar, "BOTTOM", 0, -6)
end

---Shows the bar while validating, the list once done. Called by the validation as it goes.
function ns.UpdateLoading()
    if not (window and loading) then return end
    local pronto = ns.ValidationDone and ns.ValidationDone()
    loading:SetShown(not pronto)
    list:SetShown(pronto)
    if pronto then return end
    local v = ns.validation or {}
    local feitos, total = v.done or 0, v.total or 0
    loading.bar:SetValue(total > 0 and feitos / total or 0)
    loading.detail:SetText(total > 0
        and string.format(L["%d of %d items loaded"], feitos, total)
        or L["waiting for the collection data"])
end

local function Redraw()
    ns.UpdateLoading()
    if ns.ValidationDone and not ns.ValidationDone() then return end
    local entries, total = ns.GetFiltered()
    ns.SortForWindow(entries, ns.db.sortBy or "pct")
    if ns.UpdateHeaders then ns.UpdateHeaders() end
    local provider = CreateDataProvider(ns.ListElements(entries))
    local keep = ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition
    list:SetDataProvider(provider, keep)

    window.count:SetText(tostring(#entries))

    local mcl, rar = ns.ProviderStatus()
    -- WHOSE LIST THIS IS. Reputation, currency and achievements are read from the character
    -- logged in, and the player cannot tell that by looking -- the second defect reported on
    -- 21/09: *"qual char tem essa reputação?"*. The name stays in sight the whole time.
    local footer = string.format(L["%d mounts missing"], #entries)
    if #entries ~= total then
        footer = footer .. string.format(L[" (filtered from %d)"], total)
    end
    -- A SEARCH WITH NO RESULT HAS TO SAY SO. An empty list with no explanation looks like a
    -- broken addon.
    if ns.search and ns.search ~= "" and #entries == 0 then
        footer = string.format(L['nothing found for "%s"'], ns.search)
    end
    if not mcl then
        footer = footer .. L["  |cffcc6666· without MCL, there is no drop chance|r"]
    elseif not rar then
        footer = footer .. L["  |cff888888· without MountJournalEnhanced, there is no playerbase share|r"]
    end
    footer = (UnitName("player") or "?") .. "  ·  " .. footer
    window.footer:SetText(footer)
end

function ns.RefreshWindow()
    if window and window:IsShown() then
        Redraw()
        if selected then FillDetail(selected) end
    end
end

--------------------------------------------------------------------------------
-- The column headers: sort by clicking, filter from the menu -- no grid, no table look
--------------------------------------------------------------------------------
local headers = {}

local function Menu(owner, gerar)
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(owner, gerar)
    end
end

local function Contagem(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

---The header's text: the column's name, "(n)" when filtered, and the sort arrow when it leads.
function ns.UpdateHeaders()
    local by = ns.db.sortBy or "pct"
    for chave, h in pairs(headers) do
        local nome = h.label
        local n = chave == "tag" and Contagem(ns.db.tagFilter) or chave == "expansion" and Contagem(ns.db.expFilter) or 0
        if n > 0 then nome = nome .. string.format(" (%d)", n) end
        h.text:SetText(nome)
        h.arrow:SetShown(by == chave)
    end
    if headers.pct then headers.pct.arrow:SetShown(true) end   -- the number always orders, at least second
end

local function TagMenu(owner)
    Menu(owner, function(_, root)
        root:CreateRadio(L["Group by type, then %"], function() return ns.db.sortBy == "tag" end,
            function() ns.db.sortBy = "tag"; ns.RefreshWindow() end)
        root:CreateDivider()
        root:CreateTitle(L["Show"])
        for _, k in ipairs(ns.TAG_ORDER) do
            root:CreateCheckbox(ns.TAG_NAME[k],
                function() return ns.db.tagFilter and ns.db.tagFilter[k] end,
                function()
                    ns.db.tagFilter = ns.db.tagFilter or {}
                    ns.db.tagFilter[k] = not ns.db.tagFilter[k] or nil
                    ns.RefreshWindow()
                end)
        end
        root:CreateButton(L["Show all"], function() ns.db.tagFilter = nil; ns.RefreshWindow() end)
    end)
end

local function ExpMenu(owner)
    Menu(owner, function(_, root)
        root:CreateRadio(L["Group by expansion, then %"], function() return ns.db.sortBy == "expansion" end,
            function() ns.db.sortBy = "expansion"; ns.RefreshWindow() end)
        root:CreateDivider()
        root:CreateTitle(L["Show"])
        local faixas = ns.Expansion and ns.Expansion.RANGES or {}
        for i = #faixas, 1, -1 do
            local id = faixas[i].id
            root:CreateCheckbox(ns.ExpansionLabel(id, faixas[i].name),
                function() return ns.db.expFilter and ns.db.expFilter[id] end,
                function()
                    ns.db.expFilter = ns.db.expFilter or {}
                    ns.db.expFilter[id] = not ns.db.expFilter[id] or nil
                    ns.RefreshWindow()
                end)
        end
        root:CreateButton(L["Show all"], function() ns.db.expFilter = nil; ns.RefreshWindow() end)
    end)
end

local function Header(host, chave, label, x, w, onClick, justify)
    local h = CreateFrame("Button", nil, host)
    h:SetSize(w, HEADER_H - 4)
    h:SetPoint("TOPLEFT", host, "TOPLEFT", 3 + ROW_PAD + x, -SEARCH_H)
    h.label = label
    h.text = Text(h, "GameFontNormalSmall", justify or "LEFT")
    h.text:SetAllPoints()
    -- The game's own sort arrow (guild roster, who list).
    h.arrow = h:CreateTexture(nil, "ARTWORK")
    h.arrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
    h.arrow:SetSize(9, 8)
    if justify == "RIGHT" then
        h.arrow:SetPoint("RIGHT", h.text, "LEFT", -2, 0)
    else
        h.arrow:SetPoint("LEFT", h, "RIGHT", -8, 0)
    end
    h.arrow:Hide()
    h:SetHighlightTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight", "ADD")
    h:SetScript("OnClick", function(self) onClick(self) end)
    headers[chave] = h
    return h
end

-- The "?" beside the % header: what the number is, in one place (the user asked for the
-- explanation to stay once the two readings became one).
local function PctHelp(host, pctHeader)
    local ajuda = CreateFrame("Button", nil, host)
    ajuda:SetSize(16, 16)
    ajuda:SetPoint("RIGHT", pctHeader, "LEFT", -14, 0)
    ajuda.tex = ajuda:CreateTexture(nil, "ARTWORK")
    ajuda.tex:SetAllPoints()
    ajuda.tex:SetTexture("Interface\\Common\\help-i")
    ajuda:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["What the percentage means"], 1, 0.82, 0)
        GameTooltip:AddLine(L["It is what the mount depends on, and the list is ordered by it."], 0.9, 0.9, 0.9, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(L["Drop"], L["the chance of each attempt"], 1, 1, 1, 0.8, 0.8, 0.8)
        GameTooltip:AddDoubleLine(L["Achievement"], L["how much of it is done"], 1, 1, 1, 0.8, 0.8, 0.8)
        GameTooltip:AddDoubleLine(L["Reputation"], L["how far to the standing asked for"], 1, 1, 1, 0.8, 0.8, 0.8)
        GameTooltip:AddDoubleLine(L["Renown"], L["how far to the renown level asked for"], 1, 1, 1, 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["\"?\" means it cannot be measured yet: open the vendor, or there is no data."], 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    ajuda:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

--------------------------------------------------------------------------------
-- The window
--------------------------------------------------------------------------------

local function Build()
    window = CreateFrame("Frame", ADDON .. "Window", UIParent, "ButtonFrameTemplate")
    window:SetSize(WINDOW_W, WINDOW_H)
    window:SetFrameStrata("HIGH")
    window:SetMovable(true)
    window:EnableMouse(true)
    window:SetClampedToScreen(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        ns.db.window = { point = point, x = x, y = y }
    end)

    local pos = ns.db.window
    if pos then
        window:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 0, pos.y or 0)
    else
        window:SetPoint("CENTER")
    end

    if window.SetTitle then window:SetTitle(L["Rocket Mount — where to start"]) end
    if window.SetPortraitToAsset then
        window:SetPortraitToAsset("Interface\\Icons\\Ability_Mount_RidingHorse")
    end

    -- The counter, in the attic between the title and the inset, right of the portrait (x >= 58).
    local counter = CreateFrame("Frame", nil, window, "InsetFrameTemplate3")
    counter:SetSize(130, 20)
    counter:SetPoint("TOPLEFT", 70, ATTIC_Y)
    window.count = Text(counter, "GameFontHighlightSmall", "RIGHT")
    window.count:SetPoint("RIGHT", -10, 0)
    local label = Text(counter, "GameFontNormalSmall")
    label:SetPoint("LEFT", 10, 0)
    label:SetPoint("RIGHT", window.count, "LEFT", -3, 0)
    label:SetText(L["Not collected"])

    -- The inset covers the list column only; the card sits on the window background.
    local host = window
    if type(window.Inset) == "table" then
        window.Inset:ClearAllPoints()
        window.Inset:SetPoint("TOPLEFT", window, "TOPLEFT", INSET_X, LIST_TOP)
        window.Inset:SetPoint("BOTTOMRIGHT", window, "BOTTOMLEFT", INSET_X + LIST_W, FOOTER)
        host = window.Inset
    end

    -- Search and filter inside the top of the inset, where the journal has them.
    local busca = CreateFrame("EditBox", nil, host, "SearchBoxTemplate")
    busca:SetSize(220, 20)
    busca:SetPoint("TOPLEFT", host, "TOPLEFT", 15, -9)
    busca:SetAutoFocus(false)
    -- `if busca.Instructions then` IS NOT ENOUGH: in the harness any unknown field answers a
    -- function, which is truthy. Guarding by TYPE works on both sides.
    if type(busca.Instructions) == "table" and busca.Instructions.SetText then
        busca.Instructions:SetText(L["name, boss, zone, vendor"])
    end
    -- FILTERS ON EVERY KEY, not only on Enter: a list answering while you type is what lets
    -- you search by trial.
    busca:SetScript("OnTextChanged", function(self, byUser)
        if not byUser then return end
        ns.search = self:GetText()
        ns.RefreshWindow()
    end)
    busca:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
        ns.search = ""
        ns.RefreshWindow()
    end)
    window.search = busca

    -- The column headers, aligned with the row's columns.
    Header(host, "name", L["Mount"], NAME_X, NAME_W,
        function() ns.db.sortBy = "name"; ns.RefreshWindow() end)
    Header(host, "tag", L["Type"], TAG_X, TAG_W, TagMenu)
    Header(host, "expansion", L["Expansion"], EXP_X, EXP_W, ExpMenu)
    local pctHeader = Header(host, "pct", "%", PCT_X, PCT_W,
        function() ns.db.sortBy = "pct"; ns.RefreshWindow() end, "RIGHT")
    PctHelp(host, pctHeader.text)
    window.headers = headers

    list = CreateFrame("Frame", nil, host, "WowScrollBoxList")
    local bar = CreateFrame("EventFrame", nil, host, "MinimalScrollBar")
    bar:SetPoint("TOPRIGHT", host, "TOPRIGHT", -3, -SEARCH_ROW)
    bar:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -3, 3)

    local view = CreateScrollBoxListLinearView()
    view:SetPadding(0, 0, ROW_PAD, 0, 0)
    view:SetElementExtentCalculator(function() return ROW_H end)
    view:SetElementFactory(function(factory) factory("Button", FillRow) end)
    ScrollUtil.InitScrollBoxListWithScrollBar(list, bar, view)
    ScrollUtil.AddManagedScrollBarVisibilityBehavior(list, bar,
        { CreateAnchor("TOPLEFT", host, "TOPLEFT", 3, -SEARCH_ROW),
          CreateAnchor("BOTTOMRIGHT", host, "BOTTOMRIGHT", -3 - SCROLLBAR_W, 3) },
        { CreateAnchor("TOPLEFT", host, "TOPLEFT", 3, -SEARCH_ROW),
          CreateAnchor("BOTTOMRIGHT", host, "BOTTOMRIGHT", -3, 3) })
    window.list = list
    BuildLoading(host)

    detail = BuildDetail(window)
    detail:SetPoint("TOPLEFT", window, "TOPLEFT", COL_X, LIST_TOP - 6)

    -- The footer band the template reserves.
    window.footer = Text(window, "GameFontHighlightSmall")
    window.footer:SetPoint("BOTTOMLEFT", 10, 8)
    window.footer:SetWidth(WINDOW_W - 20)
    window.footer:SetWordWrap(false)

    tinsert(UISpecialFrames, window:GetName())   -- Esc closes
    window:Hide()
    ns.window = window
end

function ns.ToggleWindow()
    if not window then Build() end
    if window:IsShown() then
        window:Hide()
        return
    end
    window:Show()
    Redraw()
    FillDetail(selected)
end
