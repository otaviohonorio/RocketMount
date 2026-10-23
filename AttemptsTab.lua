-- RocketMount | AttemptsTab.lua
-- The "Attempts" tab: every mount the account has tried for, with how lucky or unlucky that is,
-- the time it took, what was done today and this week, and whether the source is open right now.
--
-- (22/10) The user: a third tab with the attempts, *"do que já fez no dia, na semana"*, and which
-- characters already did a raid this week. What each column is, and where it comes from:
--
--   Mount         icon and name (`C_MountJournal`), and under the name where it drops: the
--                 instance (`EJ_GetInstanceInfo`) or the zone of the place the list knows
--   Attempts      `Attempts.Number`, or the try it came on
--   Chance        the chance of each try, the same number the list shows (`ns.FormatChance`)
--   Would have    1-(1-p)^n: the share of players who would already have it after as many tries;
--                 for a mount that came, 1-(1-p)^(n-1), the share who would have needed fewer
--   Today / This week   the tries since the daily and the weekly reset (Attempts.Recent)
--   Time          our own measure: gaps under 10 minutes between tries, and the boss fights
--   Status        this character's lock on the source (Lockouts.lua): done, partly, available,
--                 or blank when it cannot be known
--
-- The look is the main list's, row for row (the plate, the icon in the collections frame, the
-- headers that sort): it is the same kind of list, on the inset's dark background.
local ADDON, ns = ...
local L = ns.L

local Tab = {}
ns.AttemptsTab = Tab

local G = ns.Geometry or {}
local ROW_H = G.rowH or 58
local ROW_PAD = G.rowPad or 44
local ROW_GAP = G.rowGap or 4
local ROW_ICON = G.rowIcon or 40
local ICON_INSET = G.iconInset or 12
local ICON_FRAME = G.iconFrame or 53
local ROW_W = G.rowW or 843
local HEADER_H = 26
local COL_GAP = 10

-- The columns, each from the one before it. Widths measured with the game's font (frizqt) on the
-- longest real value in Portuguese (scratchpad `measure_attempts.py`, 22/10):
--   name     220: the mount name wraps to two lines (the longest, 333 px, breaks into 213 + 132);
--            the place under it is 10 pt, the longest 165 ("Amirdrassil, a Esperança Onírica")
--   att       56: "Tentativas" 50 (header, 10 pt); "12.345" 43
--   chance    56: "~0,11%" 45; "Chance" 37
--   luck      60: "Já teriam" 43; "97,6%" 37
--   today     40: "Hoje" 23; "999" 24
--   week      84: "Nesta semana" 71 + the sort arrow
--   time      80: "312 h 05 min" 77
--   status   130: "Feito nesta semana" 109; "volta em 23 h 59 min" 102 (10 pt)
-- The row ends at 818 of its 843. The place is a line under the name, not a column: there is no
-- width to drop it from.
local NAME_X = ICON_INSET + ROW_ICON + 14 - ROW_PAD
local COLS = {}
do
    local x = NAME_X
    for _, c in ipairs({
        { "name", 220, "LEFT" }, { "attempts", 56, "RIGHT" }, { "chance", 56, "RIGHT" },
        { "luck", 60, "RIGHT" }, { "today", 40, "RIGHT" }, { "week", 84, "RIGHT" },
        { "time", 80, "RIGHT" }, { "status", 130, "LEFT" },
    }) do
        COLS[#COLS + 1] = { key = c[1], x = x, w = c[2], justify = c[3] }
        x = x + c[2] + COL_GAP
    end
end
Tab.Columns = COLS
local COL = {}
for _, c in ipairs(COLS) do COL[c.key] = c end

local HEADER_LABEL = {
    name = "Mount", attempts = "Attempts", chance = "Chance", luck = "Would have",
    today = "Today", week = "This week", time = "Time", status = "Status",
}

--------------------------------------------------------------------------------
-- The model
--------------------------------------------------------------------------------
local function Fold(s) return ns.Fold and ns.Fold(s) or tostring(s or ""):lower() end

---Where a mount drops, short: the instance of its boss, else the zone of its first place.
function Tab.Where(mountID, entry)
    local b = type(ns.MountBosses) == "table" and ns.MountBosses[mountID]
    if b and b.instance and not b.world and EJ_GetInstanceInfo then
        local ok, name = pcall(EJ_GetInstanceInfo, b.instance)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    if type(entry) == "table" and ns.Places then
        local ok, places = pcall(ns.Places, entry)
        for _, p in ipairs(ok and places or {}) do
            if p.zone and p.zone ~= "" then return p.zone end
        end
    end
    if b and b.zone then return b.zone end
    return nil
end

local STATUS_ORDER = { available = 1, partial = 2, done = 3 }
local gotEntry = {}      -- mountID -> the entry of a mount that came (built once)

---The rows of the tab, filtered by the search and sorted: `{ mountID, name, icon, entry, n, got,
---p, rough, chanceText, luck, today, week, time, where, state }`.
function Tab.Model(search, by, desc, now)
    local A = ns.Attempts
    local termos = {}
    for termo in Fold(search or ""):gmatch("%S+") do termos[#termos + 1] = termo end
    local out = {}
    for _, r in ipairs(A.Rows(now)) do
        local id = r.mountID
        local name, icon
        if C_MountJournal and C_MountJournal.GetMountInfoByID then
            local ok, n, _, ic = pcall(C_MountJournal.GetMountInfoByID, id)
            if ok then name, icon = n, ic end
        end
        -- A mount that came is not in the list, and its entry is built for it alone: once is enough
        -- (its chance does not change); the ones still missing are the list's own entries.
        local entry = r.got and gotEntry[id] or nil
        if not entry then
            local okE, e = pcall(ns.EntryOf, id)
            entry = okE and type(e) == "table" and e or nil
            if r.got and entry then gotEntry[id] = entry end
        end
        name = name or (entry and entry.name) or ("#" .. id)
        local passa = true
        local alvo = Fold(name)
        for _, termo in ipairs(termos) do
            if not alvo:find(termo, 1, true) then passa = false; break end
        end
        if passa then
            local p, rough = A.Chance(entry)
            local luck
            if p then luck = r.got and (A.Cumulative(p, r.n - 1) or 0) or A.Cumulative(p, r.n) end
            local st
            if not r.got and ns.Lockouts then
                local okS, s = pcall(ns.Lockouts.State, id, nil, now)
                st = okS and s or nil
            end
            out[#out + 1] = {
                mountID = id, name = name, icon = icon or (entry and entry.icon), entry = entry,
                n = r.n, got = r.got, p = p, rough = rough,
                chanceText = p and ns.FormatChance(entry.chance, rough) or nil,
                luck = luck, today = r.today, week = r.week, time = r.time,
                where = Tab.Where(id, entry), state = st,
            }
        end
    end
    by = COL[by or ""] and by or "attempts"
    local function Key(row)
        if by == "name" then return Fold(row.name) end
        if by == "attempts" then return row.n end
        if by == "chance" then return row.p end
        if by == "luck" then return row.luck end
        if by == "today" then return row.today end
        if by == "week" then return row.week end
        if by == "time" then return row.time end
        if by == "status" then
            if row.got then return 5 end
            return row.state and STATUS_ORDER[row.state.status] or 4
        end
    end
    table.sort(out, function(a, b)
        local ka, kb = Key(a), Key(b)
        -- what has no value goes last, whichever the direction
        if ka == nil and kb ~= nil then return false end
        if kb == nil and ka ~= nil then return true end
        if ka ~= nil and ka ~= kb then
            if desc then return ka > kb end
            return ka < kb
        end
        return Fold(a.name) < Fold(b.name)
    end)
    return out
end

--------------------------------------------------------------------------------
-- The page
--------------------------------------------------------------------------------
local page, list, headers = nil, nil, {}
local built = setmetatable({}, { __mode = "k" })

local function Text(parent, template, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    fs:SetJustifyH(justify or "LEFT")
    return fs
end

local function Gray(fs)
    if LIGHTGRAY_FONT_COLOR then fs:SetTextColor(LIGHTGRAY_FONT_COLOR:GetRGB()) end
end

local function White(fs)
    if HIGHLIGHT_FONT_COLOR then fs:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB()) end
end

local function Sort()
    ns.db.attemptsSort = type(ns.db.attemptsSort) == "table" and ns.db.attemptsSort or {}
    local s = ns.db.attemptsSort
    if not COL[s.by or ""] then s.by, s.desc = "attempts", true end
    return s
end
Tab.Sort = Sort

---Clicking a header: sorts by it; clicking it again turns the order around. Numbers start with the
---largest, the name and the status with the first.
function Tab.SortBy(key)
    local s = Sort()
    if s.by == key then
        s.desc = not s.desc
    else
        s.by, s.desc = key, key ~= "name" and key ~= "status"
    end
    Tab.Refresh()
end

---Every line of the tooltip of a row, in order: `{ kind, text }` (kind: title, highlight, normal,
---gray, blank, instruction). Built apart from the tooltip so the harness reads it.
function Tab.TooltipLines(row)
    local A, Lk = ns.Attempts, ns.Lockouts
    local out = { { "title", row.name } }
    local function Add(kind, text) if text and text ~= "" then out[#out + 1] = { kind, text } end end
    Add("highlight", A.Text(row.mountID))
    if row.chanceText then Add("normal", L["Chance of each attempt: %s"]:format(row.chanceText)) end
    local _, luckText = A.LuckText(row.mountID, row.entry)
    Add("highlight", luckText)
    if row.time and row.time > 0 then
        Add("highlight", L["Time spent: %s"]:format(A.FormatDuration(row.time)))
        Add("gray", L["Counted between attempts less than 10 minutes apart, plus each boss fight."])
    end
    if (row.today or 0) > 0 or (row.week or 0) > 0 then
        Add("highlight", A.RecentText(row.today, row.week))
    end
    if Lk and not row.got then
        Add("highlight", row.state and Lk.Sentence(row.state))
        local quem, nota = Lk.CharactersText(row.mountID)
        Add("normal", quem)
        if quem then Add("gray", nota) end
    end
    out[#out + 1] = { "blank" }
    out[#out + 1] = { "instruction", L["Click: see it on the card"] }
    return out
end

local function ShowTooltip(owner, row)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    for _, l in ipairs(Tab.TooltipLines(row)) do
        local kind, text = l[1], l[2]
        if kind == "title" then GameTooltip_SetTitle(GameTooltip, text)
        elseif kind == "highlight" then GameTooltip_AddHighlightLine(GameTooltip, text, true)
        elseif kind == "normal" then GameTooltip_AddNormalLine(GameTooltip, text, true)
        elseif kind == "gray" then GameTooltip_AddColoredLine(GameTooltip, text, LIGHTGRAY_FONT_COLOR, true)
        elseif kind == "blank" then GameTooltip_AddBlankLineToTooltip(GameTooltip)
        elseif kind == "instruction" then GameTooltip_AddInstructionLine(GameTooltip, text, true)
        end
    end
    GameTooltip:Show()
end

local function BuildRow(row)
    if built[row] then return end
    built[row] = true
    row:SetSize(ROW_W, ROW_H)
    local function Plate(t)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", row, "TOPLEFT", -ROW_PAD, 0)
        t:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    end
    row.background = row:CreateTexture(nil, "BACKGROUND")
    Plate(row.background)
    row.background:SetAtlas("PetList-ButtonBackground")
    row.icon = row:CreateTexture(nil, "BORDER")
    row.icon:SetSize(ROW_ICON, ROW_ICON)
    row.icon:SetPoint("LEFT", row, "LEFT", ICON_INSET - ROW_PAD, 0)
    row.iconFrame = row:CreateTexture(nil, "ARTWORK")
    row.iconFrame:SetSize(ICON_FRAME, ICON_FRAME)
    row.iconFrame:SetPoint("CENTER", row.icon, "CENTER", 0, 0)
    row.iconFrame:SetAtlas("collections-itemborder-collected")
    row:SetHighlightAtlas("PetList-ButtonHighlight")
    local brilho = row.GetHighlightTexture and row:GetHighlightTexture()
    if type(brilho) == "table" and brilho.ClearAllPoints then Plate(brilho) end
    if row.SetHitRectInsets then row:SetHitRectInsets(-ROW_PAD, 0, 0, 0) end

    -- the name, two lines at most, and where it drops under it
    row.name = Text(row, "GameFontNormal")
    row.name:SetWidth(COL.name.w)
    if row.name.SetMaxLines then row.name:SetMaxLines(2) end
    row.where = Text(row, "GameFontHighlightSmall")
    Gray(row.where)
    row.where:SetWidth(COL.name.w)
    row.where:SetWordWrap(false)
    row.where:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)

    row.cells = {}
    for _, c in ipairs(COLS) do
        if c.key ~= "name" and c.key ~= "status" then
            local fs = Text(row, "GameFontHighlight", c.justify)
            fs:SetPoint("LEFT", c.x, 0)
            fs:SetWidth(c.w)
            fs:SetWordWrap(false)
            row.cells[c.key] = fs
        end
    end
    -- the status: what it is, and when it comes back under it
    row.status = Text(row, "GameFontHighlight")
    row.status:SetWidth(COL.status.w)
    row.status:SetWordWrap(false)
    row.back = Text(row, "GameFontHighlightSmall")
    Gray(row.back)
    row.back:SetWidth(COL.status.w)
    row.back:SetWordWrap(false)
    row.back:SetPoint("TOPLEFT", row.status, "BOTTOMLEFT", 0, -3)

    row:SetScript("OnEnter", function(self) if self.data then ShowTooltip(self, self.data) end end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- A click does what a click on a row of the list does: the mount on the card.
    row:SetScript("OnClick", function(self)
        local d = self.data
        if not (d and ns.SelectEntry) then return end
        local e = d.entry or (ns.EntryOf and ns.EntryOf(d.mountID))
        if e then ns.SelectEntry(e) end
    end)
end

local function Set(fs, text, gray)
    fs:SetText(text or "")
    if gray then Gray(fs) else White(fs) end
end

local function FillRow(row, data)
    BuildRow(row)
    row.data = data
    row.icon:SetTexture(data.icon)
    row.name:SetText(data.name)
    row.where:SetText(data.where or "")
    -- a name on two lines starts higher, so the three lines stay in the middle of the row
    local linhas = 1
    if row.name.GetNumLines then
        local ok, n = pcall(row.name.GetNumLines, row.name)
        if ok and type(n) == "number" then linhas = n end
    end
    row.name:ClearAllPoints()
    row.name:SetPoint("TOPLEFT", NAME_X, linhas > 1 and -7 or (data.where and -13 or -21))

    local A, c = ns.Attempts, row.cells
    Set(c.attempts, BreakUpLargeNumbers and BreakUpLargeNumbers(data.n) or tostring(data.n))
    Set(c.chance, data.chanceText or "?", data.chanceText == nil)
    Set(c.luck, data.luck and A.FormatShare(data.luck) or "")
    Set(c.today, tostring(data.today or 0), (data.today or 0) == 0)
    Set(c.week, data.week and tostring(data.week) or "", (data.week or 0) == 0)
    Set(c.time, (data.time or 0) > 0 and A.FormatDuration(data.time) or "")

    local line1, line2
    if data.got then
        line1 = COLLECTED or L["Collected"]
    elseif ns.Lockouts then
        line1, line2 = ns.Lockouts.Label(data.state)
    end
    row.status:SetText(line1 or "")
    if data.got or (data.state and data.state.status == "available") then
        if GREEN_FONT_COLOR then row.status:SetTextColor(GREEN_FONT_COLOR:GetRGB()) end
    else
        White(row.status)
    end
    row.back:SetText(line2 or "")
    row.status:ClearAllPoints()
    row.status:SetPoint("TOPLEFT", COL.status.x, line2 and -14 or -22)
end

local function Header(host, c)
    local h = CreateFrame("Button", nil, host)
    h:SetSize(c.w, HEADER_H - 4)
    h:SetPoint("TOPLEFT", host, "TOPLEFT", ROW_PAD + c.x, 0)
    h.key, h.w, h.justify = c.key, c.w, c.justify
    h.label = L[HEADER_LABEL[c.key]]
    h.text = Text(h, "GameFontNormalSmall", c.justify)
    h.text:SetAllPoints()
    h.text:SetText(h.label)
    h.arrow = h:CreateTexture(nil, "ARTWORK")
    h.arrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
    h.arrow:SetSize(9, 8)
    h.arrow:Hide()
    h:SetHighlightTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight", "ADD")
    h:SetScript("OnClick", function(self) Tab.SortBy(self.key) end)
    headers[c.key] = h
    return h
end

-- The sort arrow beside the title that leads, pointing the way it goes.
local function UpdateHeaders()
    local s = Sort()
    for key, h in pairs(headers) do
        h.arrow:SetShown(s.by == key)
        h.arrow:ClearAllPoints()
        local ok, sw = pcall(h.text.GetStringWidth, h.text)
        sw = ok and tonumber(sw) or 0
        if h.justify == "RIGHT" then
            h.arrow:SetPoint("RIGHT", h, "RIGHT", -(math.min(sw, h.w) + 2), 0)
        else
            h.arrow:SetPoint("LEFT", h, "LEFT", math.min(sw, h.w) + 2, 0)
        end
        -- the game's arrow points down; turned over, it points up
        if s.desc then h.arrow:SetTexCoord(0, 0.5625, 0, 1) else h.arrow:SetTexCoord(0, 0.5625, 1, 0) end
    end
end

---Builds the page inside `host` (the window's inset), below `top` points from its top.
---@param summaryX number where the summary line starts, on the search box's row
function Tab.Build(host, top, summaryX)
    if page then return page end
    page = CreateFrame("Frame", nil, host)
    page:SetPoint("TOPLEFT", host, "TOPLEFT", 3, -top)
    page:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -3, 3)
    page:Hide()

    for _, c in ipairs(COLS) do Header(page, c) end
    page.headers = headers

    list = CreateFrame("Frame", nil, page, "WowScrollBoxList")
    local bar = CreateFrame("EventFrame", nil, page, "MinimalScrollBar")
    bar:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -HEADER_H)
    bar:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
    local view = CreateScrollBoxListLinearView()
    view:SetPadding(0, 0, ROW_PAD, 0, ROW_GAP)
    view:SetElementExtentCalculator(function() return ROW_H end)
    view:SetElementFactory(function(factory) factory("Button", FillRow) end)
    ScrollUtil.InitScrollBoxListWithScrollBar(list, bar, view)
    ScrollUtil.AddManagedScrollBarVisibilityBehavior(list, bar,
        { CreateAnchor("TOPLEFT", page, "TOPLEFT", 0, -HEADER_H), CreateAnchor("BOTTOMRIGHT", page, "BOTTOMRIGHT", -17, 0) },
        { CreateAnchor("TOPLEFT", page, "TOPLEFT", 0, -HEADER_H), CreateAnchor("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0) })
    page.list = list

    -- "Today: N attempts at M mounts · This week: N at M", on the search box's row
    page.summary = Text(host, "GameFontHighlight")
    page.summary:SetPoint("LEFT", host, "TOPLEFT", summaryX or 250, -19)
    page.summary:SetWordWrap(false)
    page.summary:Hide()

    page.empty = Text(page, "GameFontHighlight", "CENTER")
    Gray(page.empty)
    page.empty:SetPoint("TOP", 0, -HEADER_H - 60)
    page.empty:SetWidth(560)
    page.empty:SetText(L["No attempts counted yet. Kill a boss or loot a rare that drops a mount you are missing, and it shows up here."])
    page.empty:Hide()
    return page
end

function Tab.Show(sim)
    if not page then return end
    page:SetShown(sim)
    page.summary:SetShown(sim)
    if sim then Tab.Refresh() end
end

function Tab.IsShown() return page ~= nil and page:IsShown() end

---The line over the tab.
function Tab.SummaryText(now)
    local s = ns.Attempts.Summary(now)
    local hoje
    if s.todayN == 1 then
        hoje = L["1 attempt at 1 mount"]
    elseif s.todayM == 1 then
        hoje = L["%d attempts at 1 mount"]:format(s.todayN)
    else
        hoje = L["%d attempts at %d mounts"]:format(s.todayN, s.todayM)
    end
    hoje = L["Today: %s"]:format(hoje)
    if not s.weekKnown then return hoje end
    return hoje .. "  ·  " .. L["This week: %d at %d"]:format(s.weekN, s.weekM)
end

---Draws the page again; returns the rows it drew.
function Tab.Refresh()
    if not (page and page:IsShown()) then return nil end
    local s = Sort()
    local rows = Tab.Model(ns.search, s.by, s.desc)
    local keep = ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition
    list:SetDataProvider(CreateDataProvider(rows), keep)
    UpdateHeaders()
    page.summary:SetText(Tab.SummaryText())
    -- A search with no result says so; an empty book says how it fills.
    if ns.search and ns.search ~= "" then
        page.empty:SetText(L['nothing found for "%s"']:format(ns.search))
    else
        page.empty:SetText(L["No attempts counted yet. Kill a boss or loot a rare that drops a mount you are missing, and it shows up here."])
    end
    page.empty:SetShown(#rows == 0)
    Tab.last = rows
    if ns.AttemptsFooter then ns.AttemptsFooter(#rows) end
    return rows
end

-- For the harness.
function Tab.__page() return page end
