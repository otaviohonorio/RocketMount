-- RocketMount | Collection.lua
-- The "Collection" tab: every mount of the game, the ones you have and the ones you do not.
--
-- (!) WHY IT EXISTS (02/10). The user, with his Simple Armory page on screen: *"na janela do
-- addon tu vai criar uma aba chamada de coleção, e vai fazer parecido, só que mais bonito e com
-- filtros coletadas ou ainda não coletadas, e outros filtros que achar interessante"*. The list
-- of the first tab answers "what do I go for next"; this one answers "what do I have, and what
-- is left, of each expansion and of each kind".
--
-- THE IDEA IS THAT PAGE'S; THE LOOK IS THE GAME'S (the skin rule). What that page shows and
-- where: blocks by expansion, the newest first, each with "have / total"; inside, one group per
-- kind of source; in the group a row of icons, in colour when collected and dim when not. How it
-- is drawn comes from the game's own collection journals, read in the client (12.1.0):
--
--   the slot      `CollectionsSpellButtonTemplate` (Blizzard_CollectionTemplates.xml): 50 x 50,
--                 the icon at 42; collected = the gold frame `collections-itemborder-collected`
--                 at 56; not collected = the icon desaturated and faint, the dark frame
--                 `collections-itemborder-uncollected` at 50 and its inner glow at 0.18.
--                 Drawn here at SLOT / 50 of that, every piece by the same ratio.
--   the header    `HeirloomHeaderTemplate`: the band `collections-slotheader` with the title
--                 centred on it.
--   the filter    `WowStyle1FilterDropdownTemplate`, the "Filter" button of the game's journals.
--   the tooltip   the game's own mount tooltip (`GameTooltip:SetMountBySpellID`).
--
-- The kind of source is the GAME'S word for each mount (the journal's source type: Drop, Quest,
-- Vendor, Achievement...), in the player's language. It is the one classification that exists
-- for the mounts already collected too: the addon's own tags are made only for the missing ones.
local ADDON, ns = ...
local L = ns.L

local Collection = {}
ns.Collection = Collection

local SLOT = 38                  -- the game's slot is 50: everything below is SLOT / 50 of it
local K = SLOT / 50
local GAP = 4                    -- between two slots
local LABEL_W = 150              -- the column of the kind's name, at the left of its icons
local HEADER_H = 34              -- an expansion's title
local ROW_H = SLOT + 6
local UNCOLLECTED_ALPHA = 0.35   -- the game's is 0.18 over parchment; over the dark inset the
                                 -- icon has to stay recognisable (it is what tells the mounts apart)
local OTHER = -1                 -- the expansion of a mount the table does not place

Collection.Geometry = { SLOT = SLOT, GAP = GAP, LABEL_W = LABEL_W, HEADER_H = HEADER_H, ROW_H = ROW_H }

--------------------------------------------------------------------------------
-- The model
--------------------------------------------------------------------------------
local function Filter()
    ns.db.collection = type(ns.db.collection) == "table" and ns.db.collection or {}
    local f = ns.db.collection
    if f.status ~= "have" and f.status ~= "missing" then f.status = "all" end
    f.hide = type(f.hide) == "table" and f.hide or {}
    return f
end
Collection.Filter = Filter

local function Fold(s) return ns.Fold and ns.Fold(s) or tostring(s or ""):lower() end

---Every mount the tab counts, whatever the filter: `{ mountID, name, icon, spellID, type,
---expansion, collected, entry }`. `entry` is the mount's line of the first tab, when it is
---missing and listed there.
function Collection.All()
    local out = {}
    if not (C_MountJournal and C_MountJournal.GetMountIDs) then return out end
    local faltam = {}
    local okL, lista = pcall(ns.GetRanked)
    for _, e in ipairs(okL and type(lista) == "table" and lista or {}) do faltam[e.mountID] = e end
    local meu = UnitFactionGroup and UnitFactionGroup("player")
    for _, id in ipairs(C_MountJournal.GetMountIDs() or {}) do
        local name, spellID, icon, _, _, sourceType, _, isFactionSpecific, faction, hideOnChar, isCollected =
            C_MountJournal.GetMountInfoByID(id)
        if name then
            local usavel = not hideOnChar
            if usavel and isFactionSpecific and faction ~= nil and meu then
                usavel = meu == ((faction == 0) and "Horde" or "Alliance")
            end
            local saiu = type(ns.MountGone) == "table" and ns.MountGone[id] == true
            local entra
            if isCollected then
                -- as the game's journal counts: collected and not hidden on this character
                entra = not hideOnChar
            else
                -- the missing ones follow the two options of the first tab
                entra = (usavel or not ns.db.hideUnavailable) and (not saiu or ns.db.showUnobtainable)
            end
            if entra then
                local exp, expName
                if ns.Expansion and ns.Expansion.Of then exp, expName = ns.Expansion.Of(id) end
                out[#out + 1] = {
                    mountID = id, name = name, icon = icon, spellID = spellID,
                    type = sourceType or 0, expansion = exp or OTHER, expansionName = expName,
                    collected = isCollected and true or false, entry = faltam[id],
                }
            end
        end
    end
    return out
end

---The kinds of source that exist among the mounts, for the filter's menu: `{ { type, name, total } }`.
function Collection.Types(todas)
    local por, out = {}, {}
    for _, m in ipairs(todas or Collection.All()) do
        local t = por[m.type]
        if not t then
            t = { type = m.type, name = ns.SOURCE_NAMES[m.type], total = 0 }
            por[m.type] = t
            out[#out + 1] = t
        end
        t.total = t.total + 1
    end
    table.sort(out, function(a, b) return tostring(a.name) < tostring(b.name) end)
    return out
end

---The page as data: the totals, and the expansions with their groups, AFTER the filter.
---The numbers of a block are of what the filter of KIND and the search let through; "collected"
---and "missing" only choose which icons are drawn, so "3 / 7" keeps meaning 3 of 7.
---@return table `{ have, total, shown, expansions = { { id, name, have, total, groups = { { type, name, have, total, mounts } } } } }`
function Collection.Model(busca)
    local f = Filter()
    local termos = {}
    for termo in Fold(busca or ""):gmatch("%S+") do termos[#termos + 1] = termo end
    local modelo = { have = 0, total = 0, shown = 0, expansions = {} }
    local porExp = {}
    for _, m in ipairs(Collection.All()) do
        local passa = not f.hide[m.type]
        if passa and #termos > 0 then
            local alvo = Fold(m.name)
            for _, termo in ipairs(termos) do
                if not alvo:find(termo, 1, true) then passa = false; break end
            end
        end
        if passa then
            modelo.total = modelo.total + 1
            if m.collected then modelo.have = modelo.have + 1 end
            local e = porExp[m.expansion]
            if not e then
                local nome = m.expansion == OTHER and L["Other mounts"]
                    or ns.ExpansionLabel(m.expansion, m.expansionName)
                e = { id = m.expansion, name = nome, have = 0, total = 0, groups = {}, por = {} }
                porExp[m.expansion] = e
                modelo.expansions[#modelo.expansions + 1] = e
            end
            e.total = e.total + 1
            if m.collected then e.have = e.have + 1 end
            local g = e.por[m.type]
            if not g then
                g = { type = m.type, name = ns.SOURCE_NAMES[m.type], have = 0, total = 0, mounts = {} }
                e.por[m.type] = g
                e.groups[#e.groups + 1] = g
            end
            g.total = g.total + 1
            if m.collected then g.have = g.have + 1 end
            local desenha = f.status == "all" or (f.status == "have") == m.collected
            if desenha then
                g.mounts[#g.mounts + 1] = m
                modelo.shown = modelo.shown + 1
            end
        end
    end
    -- the newest expansion first; inside, the kinds by name; in a kind, the collected first
    table.sort(modelo.expansions, function(a, b) return a.id > b.id end)
    for _, e in ipairs(modelo.expansions) do
        e.por = nil
        table.sort(e.groups, function(a, b) return tostring(a.name) < tostring(b.name) end)
        for _, g in ipairs(e.groups) do
            table.sort(g.mounts, function(a, b)
                if a.collected ~= b.collected then return a.collected end
                return a.mountID < b.mountID
            end)
        end
    end
    return modelo
end

---The model as the elements of the scroll list: a title per expansion, then the rows of icons
---of each kind (`perRow` icons to a row; the kind's name goes on its first row only).
function Collection.Elements(modelo, perRow)
    local out = {}
    for _, e in ipairs(modelo.expansions) do
        local temIcone = false
        for _, g in ipairs(e.groups) do if #g.mounts > 0 then temIcone = true end end
        if temIcone then
            out[#out + 1] = { kind = "expansion", name = e.name, have = e.have, total = e.total }
            for _, g in ipairs(e.groups) do
                for i = 1, #g.mounts, perRow do
                    local fila = {}
                    for k = i, math.min(#g.mounts, i + perRow - 1) do fila[#fila + 1] = g.mounts[k] end
                    out[#out + 1] = { kind = "row", label = i == 1 and g.name or nil,
                                      have = i == 1 and g.have or nil, total = i == 1 and g.total or nil, mounts = fila }
                end
            end
        end
    end
    return out
end

--------------------------------------------------------------------------------
-- The page
--------------------------------------------------------------------------------
local page, list, perRow

local function Text(parent, template, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function Percent(have, total)
    return total > 0 and math.floor(have / total * 100 + 0.5) or 0
end

---One slot: the game's collection slot, at SLOT / 50 of its size.
local function Slot(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(SLOT, SLOT)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(42 * K, 42 * K)
    b.icon:SetPoint("CENTER", 0, 1 * K)
    b.icon:SetTexCoord(0.04347826, 0.95652173, 0.04347826, 0.95652173)
    b.glow = b:CreateTexture(nil, "ARTWORK", nil, 1)
    b.glow:SetAtlas("collections-itemborder-uncollected-innerglow")
    b.glow:SetSize(42 * K, 41 * K)
    b.glow:SetPoint("CENTER", 0, 2 * K)
    b.glow:SetAlpha(0.18)
    b.have = b:CreateTexture(nil, "OVERLAY")
    b.have:SetAtlas("collections-itemborder-collected")
    b.have:SetSize(56 * K, 56 * K)
    b.have:SetPoint("CENTER")
    b.missing = b:CreateTexture(nil, "OVERLAY")
    b.missing:SetAtlas("collections-itemborder-uncollected")
    b.missing:SetSize(50 * K, 50 * K)
    b.missing:SetPoint("CENTER", 0, 2 * K)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetScript("OnEnter", function(self)
        local m = self.mount
        if not m then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        -- the game's own tooltip of the mount, when it answers; its name otherwise
        local ok = GameTooltip.SetMountBySpellID and m.spellID and pcall(GameTooltip.SetMountBySpellID, GameTooltip, m.spellID)
        if not ok then GameTooltip_SetTitle(GameTooltip, m.name) end
        GameTooltip_AddBlankLineToTooltip(GameTooltip)
        if m.collected then
            GameTooltip_AddInstructionLine(GameTooltip, COLLECTED or L["Collected"], true)
        else
            GameTooltip_AddErrorLine(GameTooltip, NOT_COLLECTED or L["Not collected"], true)
            if m.entry then
                local why = ns.RowWhy and ns.RowWhy(m.entry)
                if why and why ~= "" then GameTooltip_AddNormalLine(GameTooltip, why, true) end
                GameTooltip_AddInstructionLine(GameTooltip, L["Click: see it on the card"], true)
            end
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self)
        local m = self.mount
        if m and m.entry and ns.SelectEntry then ns.SelectEntry(m.entry) end
    end)
    return b
end

local function DressSlot(b, m)
    b.mount = m
    b.icon:SetTexture(m.icon)
    b.icon:SetDesaturated(not m.collected)
    b.icon:SetAlpha(m.collected and 1 or UNCOLLECTED_ALPHA)
    b.have:SetShown(m.collected)
    b.missing:SetShown(not m.collected)
    b.glow:SetShown(not m.collected)
    b:Show()
end

local built = {}
local function BuildRow(row)
    if built[row] then return end
    built[row] = true
    -- the title of an expansion: the game's header band, the name on it, the count at the right
    row.band = row:CreateTexture(nil, "BACKGROUND")
    row.band:SetAtlas("collections-slotheader", true)
    row.band:SetPoint("CENTER", 0, -2)
    row.title = Text(row, "GameFontNormalLarge", "CENTER")
    row.title:SetPoint("CENTER", 0, -2)
    row.count = Text(row, "GameFontHighlightSmall", "RIGHT")
    row.count:SetPoint("RIGHT", -8, -2)
    -- a row of icons: the kind's name and its count at the left, the slots after them
    row.label = Text(row, "GameFontNormalSmall")
    row.label:SetPoint("LEFT", 6, 5)
    row.label:SetWidth(LABEL_W - 12)
    row.sub = Text(row, "GameFontDisableSmall")
    row.sub:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -2)
    row.slots = {}
end

local function FillRow(row, data)
    BuildRow(row)
    local titulo = data.kind == "expansion"
    row.band:SetShown(titulo)
    row.title:SetShown(titulo)
    row.count:SetShown(titulo)
    row.label:SetShown(not titulo and data.label ~= nil)
    row.sub:SetShown(not titulo and data.label ~= nil)
    for _, b in ipairs(row.slots) do b:Hide() end
    if titulo then
        row.title:SetText(data.name)
        row.count:SetText(string.format(L["%d / %d (%d%%)"], data.have, data.total, Percent(data.have, data.total)))
        return
    end
    if data.label then
        row.label:SetText(data.label)
        row.sub:SetText(string.format("%d / %d", data.have, data.total))
    end
    for i, m in ipairs(data.mounts) do
        local b = row.slots[i]
        if not b then
            b = Slot(row)
            b:SetPoint("LEFT", LABEL_W + (i - 1) * (SLOT + GAP), 0)
            row.slots[i] = b
        end
        DressSlot(b, m)
    end
end

---The filter's menu: which mounts (all, collected, missing) and which kinds of source.
local function FilterMenu(_, root)
    local f = Filter()
    root:CreateTitle(L["Show"])
    for _, s in ipairs({ { "all", L["All of them"] }, { "have", COLLECTED or L["Collected"] }, { "missing", NOT_COLLECTED or L["Not collected"] } }) do
        root:CreateRadio(s[2], function() return f.status == s[1] end,
            function() f.status = s[1]; Collection.Refresh() end, s[1])
    end
    root:CreateDivider()
    root:CreateTitle(L["Kind of source"])
    for _, t in ipairs(Collection.Types()) do
        root:CreateCheckbox(string.format("%s (%d)", t.name, t.total),
            function() return not f.hide[t.type] end,
            function() f.hide[t.type] = (not f.hide[t.type]) or nil; Collection.Refresh() end)
    end
    root:CreateButton(L["Show all"], function() f.status = "all"; f.hide = {}; Collection.Refresh() end)
end

---Builds the page inside `host` (the window's inset), below `top` points from its top.
---@param width number the width the rows have to fill
function Collection.Build(host, top, width)
    if page then return page end
    page = CreateFrame("Frame", nil, host)
    page:SetPoint("TOPLEFT", host, "TOPLEFT", 3, -top)
    page:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -3, 3)
    page:Hide()

    perRow = math.max(1, math.floor((width - LABEL_W - 8 + GAP) / (SLOT + GAP)))
    Collection.perRow = perRow

    list = CreateFrame("Frame", nil, page, "WowScrollBoxList")
    local bar = CreateFrame("EventFrame", nil, page, "MinimalScrollBar")
    bar:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtentCalculator(function(_, data)
        return data.kind == "expansion" and HEADER_H or ROW_H
    end)
    view:SetElementFactory(function(factory) factory("Frame", FillRow) end)
    ScrollUtil.InitScrollBoxListWithScrollBar(list, bar, view)
    ScrollUtil.AddManagedScrollBarVisibilityBehavior(list, bar,
        { CreateAnchor("TOPLEFT", page, "TOPLEFT", 0, 0), CreateAnchor("BOTTOMRIGHT", page, "BOTTOMRIGHT", -17, 0) },
        { CreateAnchor("TOPLEFT", page, "TOPLEFT", 0, 0), CreateAnchor("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0) })
    page.list = list

    -- The game's "Filter" button, on the line of the search box.
    page.filter = CreateFrame("DropdownButton", nil, host, "WowStyle1FilterDropdownTemplate")
    page.filter:SetPoint("TOPRIGHT", host, "TOPRIGHT", -12, -10)
    page.filter:SetupMenu(FilterMenu)
    page.filter:Hide()

    page.empty = Text(page, "GameFontDisable", "CENTER")
    page.empty:SetPoint("CENTER", 0, 20)
    page.empty:SetText(L["No mount matches the filter."])
    page.empty:Hide()
    return page
end

function Collection.Show(sim)
    if not page then return end
    page:SetShown(sim)
    page.filter:SetShown(sim)
    if sim then Collection.Refresh() end
end

function Collection.IsShown() return page ~= nil and page:IsShown() end

---Draws the page again. Returns the model it drew, for the window's footer.
function Collection.Refresh()
    if not (page and page:IsShown()) then return nil end
    local modelo = Collection.Model(ns.search)
    local keep = ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition
    list:SetDataProvider(CreateDataProvider(Collection.Elements(modelo, perRow)), keep)
    page.empty:SetShown(modelo.shown == 0)
    Collection.last = modelo
    if ns.CollectionFooter then ns.CollectionFooter(modelo) end
    return modelo
end

-- For the harness.
function Collection.__page() return page end
