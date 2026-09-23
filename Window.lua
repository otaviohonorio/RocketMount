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

-- The list column. The inset holds the search row on top (36, as in the journal) and the
-- scroll box under it, 3 in from each side; the scroll bar sits inside the inset's right side.
local LIST_W = 460
local SEARCH_ROW = 36
local SCROLLBAR_W = 17        -- what `AddManagedScrollBarVisibilityBehavior` gives up (RocketSwap)
local ROW_PAD = 44            -- the journal's left padding: room for the icon hanging off the row

-- Reading measure: the card is prose (Blizzard's "how to get it", the check-the-vendor note),
-- and running text wants 45 to 75 characters a line. At the game's 12pt, 360px is ~60.
local DETAIL_W = 360

local COL_X = INSET_X + LIST_W + GUTTER
local WINDOW_W = COL_X + DETAIL_W + RIGHT_MARGIN
local WINDOW_H = 560

-- The row. Its width is what the scroll box leaves once the scroll bar and the icon padding
-- are paid for -- derived, because the last time a number here was chosen by hand the name
-- ended 4px inside the figure on the right.
local ROW_H = 46              -- `MountListButtonTemplate`
local ROW_ICON = 38
local ROW_W = LIST_W - 3 - 3 - SCROLLBAR_W - ROW_PAD
local ROW_TEXT_X = 6          -- icon at -42, 38 wide, name 10 to its right: -42 + 38 + 10
local HEADLINE_W = 80
local HEADLINE_INSET = 8
local ROW_GAP = 10            -- between the name and the figure
local ROW_TEXT_W = ROW_W - ROW_TEXT_X - ROW_GAP - HEADLINE_W - HEADLINE_INSET

-- A band's header: a line of its own in the same list, spanning the icon column too.
local HEAD_H = 30
local TIER_TITLE_WIDTH = 230  -- the longest band name ("Guaranteed — halfway") at 12pt, ~220

ns.Geometry = {
    windowW = WINDOW_W, windowH = WINDOW_H,
    insetX = INSET_X, listW = LIST_W, gutter = GUTTER, colX = COL_X,
    detailW = DETAIL_W, rightMargin = RIGHT_MARGIN,
    scrollbarW = SCROLLBAR_W, rowPad = ROW_PAD,
    rowW = ROW_W, rowH = ROW_H, rowTextX = ROW_TEXT_X, rowTextW = ROW_TEXT_W,
    headlineW = HEADLINE_W, headlineInset = HEADLINE_INSET, rowGap = ROW_GAP,
    headH = HEAD_H, listTop = LIST_TOP, footer = FOOTER,
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
        if entry.bossName then txt = txt .. "\n" .. entry.bossName end
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

    local c = ns.TIER_COLOR[entry.tier] or S.dim
    d.tier:SetText(ns.TIER_NAME[entry.tier])
    d.tier:SetTextColor(c[1], c[2], c[3])

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
-- The list: two kinds of element in one scroll box -- a band's header and a mount
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
    row.icon:SetPoint("LEFT", -42, 0)

    row.selectedTexture = row:CreateTexture(nil, "OVERLAY")
    row.selectedTexture:SetAllPoints()
    row.selectedTexture:SetAtlas("PetList-ButtonSelect")
    row.selectedTexture:Hide()

    row:SetHighlightAtlas("PetList-ButtonHighlight")

    row.name = Text(row, "GameFontNormal")
    row.name:SetPoint("TOPLEFT", ROW_TEXT_X, -7)
    row.name:SetWidth(ROW_TEXT_W)
    row.name:SetWordWrap(false)

    row.why = Text(row, "GameFontDisableSmall")
    row.why:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
    row.why:SetWidth(ROW_TEXT_W)
    row.why:SetWordWrap(false)

    row.headline = Text(row, "GameFontHighlight", "RIGHT")
    row.headline:SetPoint("RIGHT", -HEADLINE_INSET, 0)
    row.headline:SetWidth(HEADLINE_W)

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
                -- Only mount rows have one; a band header does not. By TYPE, not truthiness.
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
    row.headline:SetText(e.headline or "")
    local c = ns.TIER_COLOR[e.tier] or S.cream
    row.headline:SetTextColor(c[1], c[2], c[3])
    row.selectedTexture:SetShown(Same(e, selected))
end

---A band's header. It hangs left into the icon column, so the band's name lines up with the
---icons below it rather than with the names.
local function FillHead(head, data)
    if not built[head] then
        built[head] = true
        head:SetSize(ROW_W, HEAD_H)
        -- Explicit widths on both: without them a FontString grows as far as its text asks
        -- and crosses the list's edge -- and these labels change length with every band.
        head.title = Text(head, "GameFontNormal")
        head.title:SetPoint("BOTTOMLEFT", -ROW_PAD + 4, 6)
        head.title:SetWidth(TIER_TITLE_WIDTH)
        head.title:SetWordWrap(false)

        head.hint = Text(head, "GameFontDisableSmall")
        head.hint:SetPoint("LEFT", head.title, "RIGHT", 8, 0)
        head.hint:SetWidth(ROW_W + ROW_PAD - 4 - TIER_TITLE_WIDTH - 8)
        head.hint:SetWordWrap(false)
    end
    head.title:SetText(ns.TIER_NAME[data.tier])
    local c = ns.TIER_COLOR[data.tier] or S.gold
    head.title:SetTextColor(c[1], c[2], c[3])
    head.hint:SetText(ns.TIER_HINT[data.tier])
end

---What the scroll box shows: the filtered list with a header before each band.
function ns.ListElements(entries)
    local items, lastTier = {}, nil
    for _, e in ipairs(entries) do
        if e.tier ~= lastTier then
            items[#items + 1] = { head = true, tier = e.tier }
            lastTier = e.tier
        end
        items[#items + 1] = { entry = e }
    end
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
-- The source filter: the journal's own filter button
--------------------------------------------------------------------------------

local function SetupFilter(dd)
    dd:SetWidth(90)
    -- The little "x" that resets to default, drawn by the template when this says "not default".
    if dd.SetIsDefaultCallback then
        dd:SetIsDefaultCallback(function() return ns.db.sources == nil end)
        dd:SetDefaultCallback(function()
            ns.db.sources = nil
            ns.RefreshWindow()
        end)
    end
    dd:SetupMenu(function(_, root)
        root:CreateTitle(L["Sources"])
        for id = 0, 11 do
            root:CreateCheckbox(ns.SOURCE_NAMES[id],
                function() return not ns.db.sources or ns.db.sources[id] end,
                function()
                    local t = ns.db.sources
                    if not t then
                        -- First untick: start from "all on".
                        t = {}
                        for i = 0, 11 do t[i] = true end
                        ns.db.sources = t
                    end
                    t[id] = not t[id]
                    local any = false
                    for i = 0, 11 do if t[i] then any = true end end
                    if not any then ns.db.sources = nil end
                    ns.RefreshWindow()
                end)
        end
    end)
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

    local filter = CreateFrame("DropdownButton", nil, host, "WowStyle1FilterDropdownTemplate")
    filter:SetPoint("TOPRIGHT", host, "TOPRIGHT", -5, -10)
    SetupFilter(filter)
    window.filter = filter

    list = CreateFrame("Frame", nil, host, "WowScrollBoxList")
    local bar = CreateFrame("EventFrame", nil, host, "MinimalScrollBar")
    bar:SetPoint("TOPRIGHT", host, "TOPRIGHT", -3, -SEARCH_ROW)
    bar:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -3, 3)

    local view = CreateScrollBoxListLinearView()
    view:SetPadding(0, 0, ROW_PAD, 0, 0)
    view:SetElementExtentCalculator(function(_, data)
        return data.head and HEAD_H or ROW_H
    end)
    view:SetElementFactory(function(factory, data)
        if data.head then
            factory("Frame", FillHead)
        else
            factory("Button", FillRow)
        end
    end)
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
