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
-- The band the template reserves at the bottom (26), plus the support line below it (Donate.lua,
-- `DONATE_ROW`, 27/09).
local DONATE_ROW = ns.DONATE_ROW or 0
local FOOTER = 26 + DONATE_ROW
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
-- 660 -> 840 (25/09): *"um pouco mais larga (...) para o conteudo de cada coluna caber melhor"*.
local LIST_W = 840
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
local WINDOW_H = 660 + DONATE_ROW   -- 580 -> 660 with the width; + the support line, same list

-- The row and its columns. Every x is derived from the one before it, so a column that grows
-- pushes the next instead of sitting on it -- the geometry test checks every gap.
local ROW_H = 54              -- 46 in the journal; "engrossar um pouco" (25/09)
local ROW_ICON = 42
local ROW_W = LIST_W - 3 - 3 - SCROLLBAR_W - ROW_PAD
local COL_GAP = 10
local NAME_X, NAME_W = 6, 320           -- name, and the "why" line under it
local TAG_X, TAG_W = NAME_X + NAME_W + COL_GAP, 210   -- three tags
local EXP_X, EXP_W = TAG_X + TAG_W + COL_GAP, 130
local PCT_W, PCT_INSET = 64, 8
local PCT_X = ROW_W - PCT_INSET - PCT_W

ns.Geometry = {
    windowW = WINDOW_W, windowH = WINDOW_H,
    insetX = INSET_X, listW = LIST_W, gutter = GUTTER, colX = COL_X,
    detailW = DETAIL_W, rightMargin = RIGHT_MARGIN, listTopY = LIST_TOP,
    scrollbarW = SCROLLBAR_W, rowPad = ROW_PAD,
    rowW = ROW_W, rowH = ROW_H, listTop = LIST_TOP, footer = FOOTER, donateRow = DONATE_ROW,
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
--
-- (!) A DESCRIPTION, NOT A RECORD (27/09). The user, with MCL's map tooltip on screen -- the
-- mount's flavour line, who sells it and where, and a paragraph on how to farm the currency:
-- *"com uma boa descrição tanto na popup quanto na janela do addon, fazer parecido"*.
--
-- MCL's paragraph is its author's own text, in English, kept in the addon's PRIVATE table
-- (`MCLcore.mountNotes`): it cannot be read while the game runs, and copying it into this addon
-- would be shipping somebody else's writing. What CAN be said, and in the player's language,
-- is what the game itself says:
--
--   the mount's flavour text                    `GetMountInfoExtraByID`
--   how it is obtained                          the journal's own source text
--   what the currency or item it costs IS       `GetCurrencyInfo().description`, the item's
--                                               flavour text (where it comes from, who takes it)
--   what the achievement asks, and what is left `GetAchievementInfo`, the criteria not yet done
--   on which difficulty it drops                `GetDifficultyInfo`
--
-- plus what this addon already knew: every place, each requirement met or not, the chance, how
-- often the loot comes back. `ns.DetailBlocks` builds it once; the card draws it and the map
-- tooltip quotes it (MapPins.Tooltip), so the two cannot say different things.
--------------------------------------------------------------------------------

-- How many of an achievement's missing criteria are listed before "and N more".
local MAX_CRITERIA = 6
-- And how many places.
local MAX_PLACES = 4
-- The scroll bar of the card sits in the window's right margin: 6 of air, then the bar, which
-- is 8 wide (`MinimalScrollBar.xml`).
local CARD_BAR_GAP = 6
local CARD_BAR_W = 8
local CARD_H = WINDOW_H + LIST_TOP - FOOTER - 6
ns.Geometry.cardBarGap, ns.Geometry.cardBarW, ns.Geometry.cardH = CARD_BAR_GAP, CARD_BAR_W, CARD_H

local function BuildDetail(parent)
    -- (!) THE CARD SCROLLS. It used to have six slots and drop the rest: "Where" was the ninth
    -- block of a vendor mount behind a reputation and never reached the screen. The game's own
    -- scroll box and bar (the list beside it uses the same pair), as Baganator builds a scrolling
    -- panel (`ItemViewCommon/Utilities.lua`, AddScrollBar).
    local box = CreateFrame("Frame", nil, parent, "WowScrollBox")
    box:SetSize(DETAIL_W, CARD_H)
    local bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
    bar:SetPoint("TOPLEFT", box, "TOPRIGHT", CARD_BAR_GAP, 0)
    bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", CARD_BAR_GAP, 0)

    local d = CreateFrame("Frame", nil, box)
    d.scrollable = true
    d:SetSize(DETAIL_W, CARD_H)
    d.box, d.bar = box, bar
    if ScrollUtil and ScrollUtil.InitScrollBoxWithScrollBar and CreateScrollBoxLinearView then
        ScrollUtil.InitScrollBoxWithScrollBar(box, bar, CreateScrollBoxLinearView())
        if ScrollUtil.AddManagedScrollBarVisibilityBehavior then
            ScrollUtil.AddManagedScrollBarVisibilityBehavior(box, bar)
        end
    end

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

    -- A stack of "label above, text below" blocks, made as they are needed. Stacking is right
    -- here: this is free text the full width of the column, not a form field.
    d.blocks = {}

    d.waypoint = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
    d.waypoint:SetSize(160, 22)
    d.waypoint:SetText(L["Set map pin"])
    d.waypoint:Hide()

    -- The "no longer exists" buttons, made as they are needed (`ForgetButton`).
    d.forget = {}

    d.empty = Text(d, "GameFontDisable")
    d.empty:SetPoint("TOPLEFT", 0, -6)
    d.empty:SetWidth(DETAIL_W)
    d.empty:SetText(L["Pick a mount in the list to see how it is obtained."])

    return d
end

local function Block(d, i)
    local b = d.blocks[i]
    if b then return b end
    b = {}
    b.label = Text(d, "GameFontNormal")
    b.label:SetWidth(DETAIL_W)
    b.label:SetJustifyV("TOP")
    b.value = Text(d, "GameFontHighlight")
    b.value:SetWidth(DETAIL_W)
    b.value:SetJustifyV("TOP")
    b.value:SetSpacing(2)
    d.blocks[i] = b
    return b
end

---Every place the mount is known to come from: who, in which zone, where on its map.
---@return table list of `{ name, zone, m, x, y, instance, text }`
function ns.Places(entry)
    local out, vistos = {}, {}
    local function Add(nome, m, x, y, zonaEscrita, entrada)
        if not (m or zonaEscrita or nome) then return end
        local chave = tostring(m) .. ":" .. (x and math.floor(x + 0.5) or "?") .. ":"
            .. (y and math.floor(y + 0.5) or "?") .. ":" .. (m and "" or tostring(nome))
        if vistos[chave] then return end
        vistos[chave] = true
        local zona
        if m and C_Map and C_Map.GetMapInfo then
            local ok, info = pcall(C_Map.GetMapInfo, m)
            zona = ok and type(info) == "table" and info.name or nil
        end
        zona = zona or zonaEscrita
        if zona == "" then zona = nil end
        local texto = zona or ""
        if x and y then texto = string.format("%s  %.1f, %.1f", texto, x, y) end
        if nome and nome ~= "" then
            texto = texto ~= "" and (nome .. " — " .. texto) or nome
        end
        if texto == "" then return end
        out[#out + 1] = { name = nome, zone = zona, m = m, x = x, y = y, instance = entrada, text = texto }
    end
    for _, v in ipairs(entry.vendors or {}) do
        Add(v.npc, v.m, v.x, v.y, v.zone)
    end
    for _, wp in ipairs(entry.coords or {}) do
        local nome = wp.n
        if nome and ns.LocalizedCreature then nome = ns.LocalizedCreature(nome) end
        Add(nome, wp.m, wp.x, wp.y, nil, wp.i)
    end
    return out
end

---What an achievement asks and what is still missing of it, in the game's words.
---@return string|nil name, string|nil text
local function AchievementDetail(achID)
    if not (achID and GetAchievementInfo) then return nil end
    local ok, _, nome, _, completo, _, _, _, descricao = pcall(GetAchievementInfo, achID)
    if not ok or type(nome) ~= "string" or completo then return nil end
    local linhas = {}
    if type(descricao) == "string" and descricao ~= "" then linhas[#linhas + 1] = descricao end
    local faltam = {}
    if GetAchievementNumCriteria and GetAchievementCriteriaInfo then
        local okN, num = pcall(GetAchievementNumCriteria, achID)
        for i = 1, (okN and type(num) == "number" and num or 0) do
            local okC, texto, _, feito, qty, req = pcall(GetAchievementCriteriaInfo, achID, i)
            if okC and not feito and type(texto) == "string" and texto ~= "" then
                if type(qty) == "number" and type(req) == "number" and req > 1 then
                    texto = string.format("%s (%s/%s)", texto, BreakUpLargeNumbers(qty),
                        BreakUpLargeNumbers(req))
                end
                faltam[#faltam + 1] = texto
            end
        end
    end
    for i = 1, math.min(#faltam, MAX_CRITERIA) do
        linhas[#linhas + 1] = "|cffff5a52x|r  " .. faltam[i]
    end
    if #faltam > MAX_CRITERIA then
        linhas[#linhas + 1] = string.format(L["and %d more"], #faltam - MAX_CRITERIA)
    end
    if #linhas == 0 then return nil end
    return nome, table.concat(linhas, string.char(10))
end

---The difficulties a mount drops on, by the names the game gives them.
local function Difficulties(ids)
    if type(ids) ~= "table" or not GetDifficultyInfo then return nil end
    local nomes, vistos = {}, {}
    for _, id in ipairs(ids) do
        local ok, nome = pcall(GetDifficultyInfo, id)
        if ok and type(nome) == "string" and nome ~= "" and not vistos[nome] then
            vistos[nome] = true
            nomes[#nomes + 1] = nome
        end
    end
    if #nomes == 0 then return nil end
    return table.concat(nomes, ", ")
end

---What each difficulty gave, for the card: a line for each difficulty the game names, the best
---first, and ONE line for the chests whose difficulty could not be told.
---@param rows table|nil what `ns.OwnChances` gives
---@return table|nil lines
function ns.ChanceByDifficulty(rows)
    if type(rows) ~= "table" or #rows < 2 then return nil end
    local linhas, soltas = {}, {}
    for _, r in ipairs(rows) do
        local nome
        if r.d and GetDifficultyInfo then
            local ok, n = pcall(GetDifficultyInfo, r.d)
            if ok and type(n) == "string" and n ~= "" then nome = n end
        end
        local taxa = ns.FormatChance(1 / r.rate)
        if nome and taxa then
            linhas[#linhas + 1] = string.format("%s: %s", nome, taxa)
        elseif taxa then
            -- The game does not name it, or it could not be told: not a difficulty to choose.
            soltas[#soltas + 1] = r.rate
        end
    end
    if #linhas == 0 then return nil end
    if #soltas > 0 then
        table.sort(soltas)
        local menor, maior = ns.FormatChance(1 / soltas[1]), ns.FormatChance(1 / soltas[#soltas])
        linhas[#linhas + 1] = string.format(L["Chests of a difficulty not identified: %s"],
            menor == maior and maior or string.format(L["%s to %s"], menor, maior))
    end
    table.insert(linhas, 1, L["By difficulty, as players measured it:"])
    linhas[#linhas + 1] = "|cff808080" .. L["The number of the list is of all the difficulties together."] .. "|r"
    return linhas
end

-- (!) O CONTEÚDO DA FICHA SE MONTA FORA DO DESENHO.
--
-- A regra morava dentro do código que pinta widget, e por isso o harness não tinha como
-- olhar para ela. Foi assim que a mesma informação chegou a aparecer três vezes na ficha
-- sem nenhum teste reclamar. Separada, esta é uma função pura: entra a montaria, sai a
-- lista de blocos, e o teste lê a lista.
---@return table blocos `{ { key, label, value }, ... }`, na ordem da ficha; o de `key = "flavor"`
---não tem rótulo
---@return table|nil wp o ponto do mapa, para o botão de seta
function ns.DetailBlocks(entry)
    local blocks = {}
    local function Add(key, label, value)
        if not value or value == "" then return end
        blocks[#blocks + 1] = { key = key, label = label, value = value }
        return blocks[#blocks]
    end

    -- THE FLAVOUR LINE, in quotes, the way the game writes one on an item.
    if type(entry.description) == "string" and entry.description ~= "" then
        Add("flavor", nil, '"' .. entry.description .. '"')
    end

    -- O texto da própria Blizzard. É o melhor "como pega" que existe, e já vem traduzido.
    Add("howto", L["How to get it"], entry.sourceText and entry.sourceText ~= "" and entry.sourceText
        or ns.SOURCE_NAMES[entry.sourceType])

    -- WHERE, right under how: every place, not the first one. A vendor mount the catalogue
    -- knows only by its vendor has no `coords` at all, and its card said nothing about where.
    local lugares = ns.Places(entry)
    local wp
    for _, p in ipairs(lugares) do
        if p.m and p.x and p.y then wp = wp or p end
    end
    if #lugares > 0 then
        local linhas = {}
        for i = 1, math.min(#lugares, MAX_PLACES) do linhas[#linhas + 1] = lugares[i].text end
        if #lugares > MAX_PLACES then
            linhas[#linhas + 1] = string.format(L["and %d more"], #lugares - MAX_PLACES)
        end
        Add("where", L["Where"], table.concat(linhas, string.char(10)))
    end

    if entry.chance and entry.chance > 0 then
        -- (Era "1 em %d" em portugues fixo no codigo: saia em portugues para quem joga em ingles.)
        local linhas = { ns.FormatChance(entry.chance) }
        if entry.bossName then
            linhas[#linhas + 1] = ns.LocalizedCreature and ns.LocalizedCreature(entry.bossName)
                or entry.bossName
        end
        local dificuldades = Difficulties(entry.difficulties)
        if dificuldades then linhas[#linhas + 1] = dificuldades end
        for _, l in ipairs(ns.ChanceByDifficulty(entry.chanceBy) or {}) do
            linhas[#linhas + 1] = l
        end
        -- How often the loot comes back, only when it IS known: "not known yet" belongs to the
        -- map's creature, not to a card about the mount.
        local npc = entry.bossName and ns.CreatureId and ns.CreatureId(entry.bossName)
        if npc and ns.Sighting and ns.Sighting.LootFrequency(npc) then
            linhas[#linhas + 1] = ns.Sighting.FrequencyText(npc)
        end
        -- The rare that comes on a clock: when it comes next (30/09).
        local janela = npc and ns.Sighting and ns.Sighting.WindowText and ns.Sighting.WindowText(npc)
        if janela then linhas[#linhas + 1] = janela end
        Add("chance", L["Chance"], table.concat(linhas, string.char(10)))
    end

    -- Requisito e aquisição são blocos separados de propósito: misturar os dois é o que
    -- fazia a lista anunciar "100%" numa montaria que ainda depende de sorte.
    -- A EXPANSÃO, no alto da ficha: é a primeira coisa que situa a montaria, e sem ela o
    -- jogador lê "Vendedor em Valdrakken" sem saber de que época aquilo é.
    if entry.expansionName then
        Add("expansion", L["Expansion"], entry.expansionName)
    end

    if entry.factionOnly then
        -- FACÇÃO É INFORMAÇÃO, e antes ela só servia para esconder a montaria. Quem planeja o
        -- outro lado precisa saber que ela existe e de quem ela é.
        Add("faction", L["Faction"], entry.factionOnly == "Horde" and L["Horde only"] or L["Alliance only"])
    end

    -- (!) A FICHA LISTA TODOS OS REQUISITOS, um por linha, com o estado de cada um.
    --
    -- Ela ja mostrou so o mais atrasado, e o usuario bateu de frente com o resultado disso:
    -- *"falta cristal de ressonancia mas que tambem falta reputacao"*. Uma montaria com dois
    -- requisitos que anuncia so um deles manda o jogador para a metade do caminho.
    local p = entry.requirementFrom and entry[entry.requirementFrom]
    local exigido
    if entry.requisitos and #entry.requisitos > 0 then
        local linhas = {}
        for _, r in ipairs(entry.requisitos) do
            linhas[#linhas + 1] = (r.cumprido and "|cff55dd66+|r  " or "|cffff5a52x|r  ")
                .. (r.label or "?")
        end
        exigido = Add("requirements", entry.faltando > 0
            and string.format(L["Requirements — %d of %d missing"], entry.faltando, #entry.requisitos)
            or L["Requirements — all met"],
            table.concat(linhas, string.char(10)))
    end

    -- WHAT IT COSTS, IN THE GAME'S WORDS. One block per currency or item of the price, under its
    -- own name: what it is, where it comes from, who takes it. Gold needs no introduction.
    local nomes = {}
    for _, parte in ipairs(entry.cost and entry.cost.parts or {}) do
        local sobre = parte.about
        if (not sobre or sobre == "") and parte.type == "item" and ns.Tooltip and ns.Tooltip.Flavor then
            sobre = ns.Tooltip.Flavor(parte.id)
        end
        if type(sobre) == "string" and sobre ~= "" and parte.name and not nomes[parte.name] then
            nomes[parte.name] = true
            local icone = parte.icon and string.format("|T%s:14:14:0:0|t ", tostring(parte.icon)) or ""
            Add("about", icone .. parte.name, sobre)
        end
    end

    -- WHAT THE ACHIEVEMENT ASKS, and what is left of it. The requirement line above says how far
    -- along it is; this says what to go and do.
    local conquistas = {}
    for _, chave in ipairs({ "achievement", "achievementReward" }) do
        local a = entry[chave]
        if a and a.achID and (a.pct or 0) < 1 and not conquistas[a.achID] then
            conquistas[a.achID] = true
            local nome, texto = AchievementDetail(a.achID)
            if nome then Add("achievement", string.format(L["Achievement: %s"], nome), texto) end
        end
    end

    -- WHAT PLAYERS FOUND OUT, in our words (Data/MountTips.lua). After everything the game says,
    -- and signed: it was true when somebody wrote it down, and the line under it says when.
    if ns.Tips then
        local dica, nota = ns.Tips.For(entry.mountID)
        if dica then
            Add("tip", L["Players' tip"], dica .. string.char(10) .. "|cff808080" .. nota .. "|r")
        end
    end

    -- QUAL PERSONAGEM TEM. A API só fala do conectado; esta lista vem do livro-caixa, que é
    -- escrito quando cada personagem entra. Por isso ela diz "pelo que ficou anotado" — uma
    -- anotação velha se passando por leitura ao vivo seria pior que anotação nenhuma.
    local anotados
    if p and p.unreadable and entry.rep and entry.rep.factionId ~= nil and ns.Roster then
        local quem = ns.Roster.WhoHas(entry.rep.factionId)
        if #quem > 0 then
            local linhas, nomeados = {}, {}
            for i = 1, math.min(#quem, 5) do
                local c = quem[i]
                linhas[#linhas + 1] = string.format("%s — %s", c.name,
                    _G["FACTION_STANDING_LABEL" .. c.reaction] or "?")
                nomeados[#nomeados + 1] = { key = c.key, name = c.name, seen = c.seen }
            end
            anotados = Add("who", L["Who has it, from what was recorded"],
                table.concat(linhas, string.char(10)))
            if anotados then anotados.chars = nomeados end
        end
    end

    -- (!) WHERE A CHARACTER IS NAMED, THE PLAYER CAN SAY IT IS GONE (28/09). The user: *"talvez
    -- onde está escrito quem é o personagem, ter algum botão ali para avisar que o personagem
    -- foi excluído"*. The block says which characters it names (`chars`), and the card puts a
    -- button under it for each. One button per character: when the list of who has it is on the
    -- card, the character of the requirement line is in it, and its button is there.
    local nomeado = entry.rep and entry.rep.named
    if exigido and not anotados and nomeado and nomeado.key then
        exigido.chars = { nomeado }
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
        Add("headsup", L["Heads up"],
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
            texto = L["Guild vendor. These ask for reputation with your guild AND an achievement OF THE GUILD — and the achievement is the part I cannot read. The price shown in the requirements is only part of what it costs."]
        else
            texto = L["Of what I can read, only the price shows up on this mount — and price is almost never what blocks. There may be an achievement, a guild level or a rating in the way, and those I do not read."]
            if entry.vendorVago then
                texto = texto .. L[" And where its vendor is, I do not know."]
            end
        end
        Add("why", L["Why check"], texto)
    end

    return blocks, wp
end

---A FontString's height once its text is set. In the game it is a number; the harness answers
---every unknown method with a table, and a rough count of the lines stands in for it there.
local function Altura(fs, texto, porLinha)
    local h = fs.GetStringHeight and fs:GetStringHeight()
    if type(h) == "number" and h > 0 then return h end
    local _, quebras = tostring(texto or ""):gsub(string.char(10), "")
    return (quebras + 1) * (porLinha or 14)
end

--------------------------------------------------------------------------------
-- "No longer exists": the button under the block that names a character
--------------------------------------------------------------------------------
-- The game does not tell an addon that a character was deleted: the ledger goes on naming it
-- until the player says so. `/rmt forget Name` does it from the chat; this does it from where
-- the name is read. The dialog is the game's own, and asks before anything is taken out: what
-- goes cannot be read again from a character that is gone.
local FORGET_POPUP = "ROCKETMOUNT_FORGET"
-- 6 from the text that names the character; 2 between buttons, which makes 24 from the middle of
-- one to the middle of the next.
local FORGET_GAP, FORGET_STEP, FORGET_H = 6, 2, 22
ns.Geometry.forgetGap, ns.Geometry.forgetStep, ns.Geometry.forgetH = FORGET_GAP, FORGET_STEP, FORGET_H

---Takes a character out of the records and says so. The list and the card are redone by
---`Roster.Forget` itself.
function ns.ForgetCharacter(key)
    if not (ns.Roster and ns.Roster.Forget(key)) then return false end
    ns.Print(string.format(L["%s is out of the records: reputations, rares looted and what the vendors said."], key))
    return true
end

---Asks, in the game's dialog, whether the character is to be taken out of the records.
function ns.AskForget(key)
    if not (key and StaticPopupDialogs and StaticPopup_Show) then return end
    if not StaticPopupDialogs[FORGET_POPUP] then
        StaticPopupDialogs[FORGET_POPUP] = {
            text = L["Take %s out of the records of Rocket Mount?|n|nFor a character that was deleted, renamed or moved. One that still exists is recorded again the next time it logs in."],
            button1 = YES,
            button2 = NO,
            -- (!) No `return`: the game keeps the dialog open when this answers true
            -- (`StaticPopup.lua`, `hide = not OnAccept(...)`).
            OnAccept = function(_, chave) ns.ForgetCharacter(chave) end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end
    StaticPopup_Show(FORGET_POPUP, key, nil, key)
end

---What the button's tooltip says: the character with its realm, the day it was last seen, and
---what the click does.
---@return string title, table lines
function ns.ForgetTooltip(key, seen)
    local linhas = {}
    seen = tonumber(seen)
    if seen and seen > 0 and date then
        linhas[#linhas + 1] = string.format(L["Last seen on %s"], date(L["%m/%d/%Y"], seen))
    end
    linhas[#linhas + 1] = L["The game does not tell an addon that a character was deleted, renamed or moved. Click to take it out of what Rocket Mount recorded."]
    return key, linhas
end

local function ForgetButton(d, i)
    local b = d.forget[i]
    if b then return b end
    b = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
    b:SetHeight(FORGET_H)
    b:SetScript("OnClick", function(self)
        if type(self.charKey) == "string" then ns.AskForget(self.charKey) end
    end)
    b:SetScript("OnEnter", function(self)
        if type(self.charKey) ~= "string" then return end
        local titulo, linhas = ns.ForgetTooltip(self.charKey, self.charSeen)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip_SetTitle then
            GameTooltip_SetTitle(GameTooltip, titulo)
        else
            GameTooltip:SetText(titulo, 1, 1, 1)
        end
        for _, linha in ipairs(linhas) do
            if GameTooltip_AddNormalLine then
                GameTooltip_AddNormalLine(GameTooltip, linha, true)
            else
                GameTooltip:AddLine(linha, 1, 0.82, 0, true)
            end
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    d.forget[i] = b
    return b
end

local function FillDetail(entry)
    local d = detail
    for _, b in ipairs(d.blocks) do
        b.label:Hide()
        b.value:Hide()
    end
    for _, b in ipairs(d.forget) do
        b.charKey, b.charSeen = nil, nil
        b:Hide()
    end
    d.waypoint:Hide()

    if not entry then
        d.icon:Hide(); d.name:Hide(); d.tier:Hide(); d.rule:Hide()
        d.empty:Show()
        d:SetHeight(CARD_H)
        if d.box.FullUpdate then d.box:FullUpdate(ScrollBoxConstants and ScrollBoxConstants.UpdateImmediately) end
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

    -- Stacked: 2 inside (label -> its text), 10 outside. The 5x ratio Blizzard uses in its one
    -- stacked form (`CommunitiesSettings.xml`). The flavour line has no label: it is the one
    -- piece of the card that is not an answer to a question.
    local anchor, y = d.rule, -10
    local total = 48 + 10 + 1
    local botoes = 0
    for i, bloco in ipairs(blocks) do
        local b = Block(d, i)
        b.label:ClearAllPoints()
        b.value:ClearAllPoints()
        if bloco.label then
            b.label:SetText(bloco.label)
            b.label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y)
            b.label:Show()
            b.value:SetText(bloco.value)
            b.value:SetPoint("TOPLEFT", b.label, "BOTTOMLEFT", 0, -2)
            b.value:Show()
            total = total - y + Altura(b.label, bloco.label, 14) + 2 + Altura(b.value, bloco.value, 14)
            anchor, y = b.value, -10
            -- Under the text that names them, one button for each character named.
            for n, c in ipairs(bloco.chars or {}) do
                botoes = botoes + 1
                local botao = ForgetButton(d, botoes)
                botao.charKey, botao.charSeen = c.key, c.seen
                botao:SetText(string.format(L["%s no longer exists"], c.name))
                -- As wide as its text plus 40, which is the template's own rule
                -- (`UIButtonFitToTextBehaviorMixin`). After the text, never before it.
                botao:FitToText()
                local vao = n == 1 and FORGET_GAP or FORGET_STEP
                botao:ClearAllPoints()
                botao:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -vao)
                botao:Show()
                total = total + vao + FORGET_H
                anchor = botao
            end
        else
            -- In the label's font: the game writes flavour text in its gold.
            b.label:SetText(bloco.value)
            b.label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y)
            b.label:Show()
            total = total - y + Altura(b.label, bloco.value, 14)
            anchor, y = b.label, -10
        end
    end

    if wp and C_Map and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(wp.m) then
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
        total = total + 14 + 22
    end

    -- The card is as tall as what it says, and the scroll box is told: a short card has no bar.
    d.contentHeight = total + 10
    d:SetHeight(math.max(CARD_H, d.contentHeight))
    if d.box.FullUpdate then
        d.box:FullUpdate(ScrollBoxConstants and ScrollBoxConstants.UpdateImmediately)
        if d.box.ScrollToBegin then d.box:ScrollToBegin() end
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

-- (!) THE NUMBER IS ANOTHER CHARACTER'S (25/09). The user: *"tem que estar 80% sim, mas com
-- alguma coisa que indique que é em outro char"*. Two signals: that character's class circle
-- beside the number -- the game's own art (`UI-Classes-Circles` + `CLASS_ICON_TCOORDS`, what every
-- installed addon uses), which names a character without inventing a colour -- and "on <name>" at
-- the head of the line under the name, for whoever does not read the icon.
local CLASS_CIRCLES = "Interface\\TargetingFrame\\UI-Classes-Circles"

---The inline class circle of the character the row's number belongs to, or "".
function ns.AltMark(e)
    local r = e and e.rep
    if not (r and r.char) then return "" end
    -- Only when the number shown IS that reputation: a drop shows its chance, and a requirement
    -- further behind is somebody else's number.
    local luck = not e.deterministic and e.chance and e.chance > 0
    if luck or e.requirementFrom ~= "rep" then return "" end
    local c = r.charClass and _G.CLASS_ICON_TCOORDS and _G.CLASS_ICON_TCOORDS[r.charClass]
    if not c then return "" end
    return string.format("|T%s:14:14:0:0:256:256:%d:%d:%d:%d|t ", CLASS_CIRCLES,
        c[1] * 256, c[2] * 256, c[3] * 256, c[4] * 256)
end

---The line under the name, led by the character when the reputation is another one's.
function ns.RowWhy(e)
    local why = e.why or ""
    local char = e.rep and e.rep.char
    if char and not why:find(char, 1, true) then
        why = string.format(L["on %s"], char) .. "  ·  " .. why
    end
    return why
end

local function FillRow(row, data)
    BuildRow(row)
    local e = data.entry
    row.entry = e
    row.icon:SetTexture(e.icon)
    row.name:SetText(e.name)
    row.why:SetText(ns.RowWhy(e))

    local _, tags = ns.Tags(e)
    local nomes = {}
    for i = 1, math.min(#tags, 3) do nomes[#nomes + 1] = ns.TAG_NAME[tags[i]] end
    row.tags:SetText(table.concat(nomes, " · "))
    row.exp:SetText(e.expansion and ns.ExpansionLabel(e.expansion, e.expansionName) or "")

    row.headline:SetText(ns.AltMark(e) .. ns.RowPercentText(e))
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

---The two collection boxes beside "Not collected".
function ns.UpdateCollectionBoxes()
    if not window or not window.collected then return end
    local n = ns.CollectedMountCount()
    window.collected.value:SetText(n and tostring(n) or "?")
    local a = ns.MountCountAchievement()
    window.achievement.data = a
    window.achievement:SetShown(a ~= nil)
    if a then
        window.achievement.label:SetText(a.name)
        window.achievement.value:SetText(a.done and string.format("%d/%d  |cff33ff99%s|r", a.req, a.req, L["done"])
            or string.format("%d/%d", a.qty or 0, a.req or 0))
    end
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
    ns.UpdateCollectionBoxes()

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
    footer = (UnitName("player") or "?") .. "  ·  " .. footer
    window.footer:SetText(footer)
    if window.tips then window.tips:Update() end
end

---The entry of the same mount in the list as it is NOW, or nil when the mount left it.
local function Fresh(entry)
    if not (entry and entry.mountID) then return entry end
    for _, e in ipairs(ns.GetRanked()) do
        if e.mountID == entry.mountID then return e end
    end
    return nil
end

function ns.RefreshWindow()
    if window and window:IsShown() then
        Redraw()
        if selected then
            -- (!) THE CARD FOLLOWS THE LIST (28/09). A rebuilt list is made of NEW entries, and
            -- the card was filled again from the OLD one: with the character taken out of the
            -- records, the row named the next one and the card went on naming the one that was
            -- gone.
            selected = Fresh(selected)
            FillDetail(selected)
        end
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
-- HOW TO FEED THE LIST (01/10)
--
-- The user: *"precisamos colocar na janela essa dica ou recomendação de acessar todos os chars,
-- o que fazer para melhorar e alimentar melhor esta lista"*. The list reads the game for the
-- character that is logged in, and a few things it only learns when the player DOES something:
-- enter with each character, open a vendor, open the Trading Post, loot a rare. None of that
-- was said anywhere. It is one line in the attic, at the right of the counters -- the game's
-- "i" and how many characters were read so far -- and the tips are its tooltip, in the game's
-- own tooltip colours (title white, text gold, the hint green).
--------------------------------------------------------------------------------
local TIPS = {
    { "Enter the game with each of your characters",
      "The addon reads only the character that is logged in. Each one you enter with is written down, and from then on the list says which of them already has the reputation a mount asks for." },
    { "Open the vendors that sell mounts",
      "The vendor is who knows the real price and whether it sells to this character. A mount with \"?\" is waiting for that." },
    { "Open the Trading Post every month",
      "Its mounts only enter the list after the game shows what is on offer." },
    { "Loot the rares you kill",
      "The addon learns how often each rare can drop again, and stops calling you to one that has nothing for you today." },
    { "A character that no longer exists",
      "Deleted, renamed or moved to another realm: on the card of a mount that names it, click \"no longer exists\"." },
}

---The lines of the tips, as `{ title, text }` in the player's language: for the tooltip and for
---the harness.
function ns.FeedTips()
    local out = {}
    for i, t in ipairs(TIPS) do out[i] = { L[t[1]], L[t[2]] } end
    return out
end

local function TipsLabel()
    local n = ns.Roster and ns.Roster.Count and ns.Roster.Count() or 0
    return string.format(n == 1 and L["Tips  ·  %d character read"] or L["Tips  ·  %d characters read"], n)
end

local function TipsButton(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(20)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(16, 16)
    b.icon:SetPoint("RIGHT")
    b.icon:SetTexture("Interface\\Common\\help-i")
    b.text = Text(b, "GameFontNormalSmall", "RIGHT")
    b.text:SetPoint("RIGHT", b.icon, "LEFT", -4, 0)
    function b:Update()
        self.text:SetText(TipsLabel())
        self:SetWidth((self.text.GetStringWidth and tonumber(self.text:GetStringWidth()) or 160) + 16 + 4)
    end
    b:SetScript("OnEnter", function(self)
        self.text:SetFontObject("GameFontHighlightSmall")
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip_SetTitle(GameTooltip, L["How to feed the list"])
        GameTooltip_AddNormalLine(GameTooltip, L["The list reads the game for the character you are on. What follows is what only you can show it."], true)
        for _, t in ipairs(ns.FeedTips()) do
            GameTooltip_AddBlankLineToTooltip(GameTooltip)
            GameTooltip_AddHighlightLine(GameTooltip, t[1], true)
            GameTooltip_AddNormalLine(GameTooltip, t[2], true)
        end
        local nomes = {}
        for _, c in ipairs(ns.Roster and ns.Roster.List and ns.Roster.List() or {}) do
            if type(c) == "table" and c.name then nomes[#nomes + 1] = c.name end
        end
        if #nomes > 0 then
            GameTooltip_AddBlankLineToTooltip(GameTooltip)
            GameTooltip_AddInstructionLine(GameTooltip, string.format(L["Read so far: %s"], table.concat(nomes, ", ")), true)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        self.text:SetFontObject("GameFontNormalSmall")
        GameTooltip:Hide()
    end)
    b:Update()
    return b
end

--------------------------------------------------------------------------------
-- The window
--------------------------------------------------------------------------------

local function Build()
    window = CreateFrame("Frame", ADDON .. "Window", UIParent, "ButtonFrameTemplate")
    window:SetSize(WINDOW_W, WINDOW_H)
    window:SetFrameStrata("HIGH")
    -- IN FRONT WHEN OPENED OR CLICKED (27/09). Every Rocket window shares the HIGH strata, and
    -- inside a strata the order is the frame LEVEL: without this, the rows of a window opened
    -- earlier (deeper children, higher levels) drew over the background of the one opened on
    -- top -- the user's print had RocketMount's list showing through RocketSwap. `toplevel`
    -- raises on click; `Raise` on show. Same pair as Chattynator (`CustomiseDialog/Main.lua:841,846`).
    window:SetToplevel(true)
    window:HookScript("OnShow", function(self) self:Raise() end)
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

    -- COLLECTED, and the "Obtain N mounts" achievement (26/09): two more boxes in the same row,
    -- the journal's own look. The achievement box explains, on hover, why its number is not the
    -- collected one.
    local function Caixa(largura, x, rotulo)
        local c = CreateFrame("Frame", nil, window, "InsetFrameTemplate3")
        c:SetSize(largura, 20)
        c:SetPoint("TOPLEFT", x, ATTIC_Y)
        c.value = Text(c, "GameFontHighlightSmall", "RIGHT")
        c.value:SetPoint("RIGHT", -10, 0)
        c.label = Text(c, "GameFontNormalSmall")
        c.label:SetPoint("LEFT", 10, 0)
        c.label:SetPoint("RIGHT", c.value, "LEFT", -3, 0)
        if c.label.SetWordWrap then c.label:SetWordWrap(false) end
        if rotulo then c.label:SetText(rotulo) end
        return c
    end
    window.collected = Caixa(130, 70 + 130 + 10, L["Collected"])
    window.achievement = Caixa(290, 70 + 2 * (130 + 10))
    window.achievement:EnableMouse(true)
    window.achievement:SetScript("OnEnter", function(self)
        local a = self.data
        if not a then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(a.name, 1, 0.82, 0)
        GameTooltip:AddLine(string.format(L["%d of %d mounts"], a.qty or 0, a.req or 0), 1, 1, 1)
        GameTooltip:AddLine(L["Only mounts this character can use count toward it."], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    window.achievement:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- The tips, at the right end of the same row (see "HOW TO FEED THE LIST").
    window.tips = TipsButton(window)
    window.tips:SetPoint("TOPRIGHT", window, "TOPRIGHT", -RIGHT_MARGIN, ATTIC_Y)

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
    detail.box:SetPoint("TOPLEFT", window, "TOPLEFT", COL_X, LIST_TOP - 6)
    window.detail = detail

    -- The footer band the template reserves.
    -- "Support the project" (27/09): a line of its own at the very bottom (Donate.lua).
    window.donate = ns.DonateFooter(window)

    window.footer = Text(window, "GameFontHighlightSmall")
    window.footer:SetPoint("BOTTOMLEFT", 10, 8 + DONATE_ROW)
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
