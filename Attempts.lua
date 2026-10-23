-- RocketMount | Attempts.lua
--
-- How many times the player tried for each mount that drops by chance, and, once it came, on
-- which try. The user (13/10), passing on a player's request: *"incluir o número de tentativas de
-- drop de montaria, exemplo, raid do Fyrakk, fez 372 vezes e claro que a contagem para quando pega,
-- mas fica salva quantas vezes tentou até conseguir, e claro, só montarias com taxa de drop"*.
--
-- What is one attempt, and how the game says it (measured, 13/10):
--   * A BOSS (Data/MountBosses.lua: raid, dungeon and world bosses of the Adventure Guide): a kill
--     on a difficulty the mount drops on, when the boss was NOT already dead in this character's
--     lockout as the fight began -- a boss killed again, already looted, gives nothing.
--     ENCOUNTER_START/END carry the dungeon encounter id and the result readable in Midnight
--     (RocketMeter's diary, a key of 12/10: encounter "2609", success "1"); `bosses[i][3]` is that
--     id (tools/coletar_chefes.py, JournalEncounter.DungeonEncounterID); the lockout is
--     `C_RaidLocks.IsEncounterComplete(map, encounter, difficulty)`, asked at the START.
--   * A CREATURE of the drop table (Data/MobDrops.lua, the rares): its corpse looted -- a loot
--     window opens only for whom the loot is (`GetLootSourceInfo`, Sighting.RecordLoot).
--   * A mount counted in the last few minutes is not counted again: an old boss both ends an
--     encounter and opens a loot window (legacy loot).
-- Counted for the account, with each character's share. Once the mount is collected the count
-- stops and the try it came on is kept.
-- BEFORE THE ADDON (13/10, the user: *"quem jogou DF e não tem ainda a montaria que dropa do fyrak
-- deve ter um numero de tentativas bem alta"*): the game keeps, per character, its kills of each
-- boss on each difficulty -- the statistics, `GetStatistic(id)`. Data/MountStats.lua has the ones
-- whose every kill is a try at the mount (tools/coletar_estatisticas.py; 43 of the 66 boss mounts).
-- Each character's share is the larger of what the addon counted and its statistics, read at login
-- and after a kill: they count the same kills, never added. A character counts once it logs in.
-- Per character, not the account's: Accountwide Stats (CurseForge, 12.1.0, 14/09/2026) still sums
-- the characters one by one. The rest (rares, old dungeons, chests) starts at 0 when installed.
-- Not counted (yet): chests and bags that may hold a mount (the Tormentor's Cache and the like).
local ADDON, ns = ...

local Attempts = {}
ns.Attempts = Attempts

local SAME_TRY = 300            -- seconds: an encounter and its loot window are one try
-- (22/10) THE TIME SPENT, our own measure. Two tries at the same mount less than TIME_GAP apart are
-- one sitting: the gap between them is time spent on that mount. A boss fight adds its own length
-- (ENCOUNTER_START to ENCOUNTER_END). The gap runs from one try to the START of the next fight, so
-- a fight is never counted twice. A first try after a pause adds only its fight.
local TIME_GAP = 600
local MAX_FIGHT = 2 * 3600      -- a longer "fight" is a clock that went wrong, not a fight
-- (22/10) TODAY AND THIS WEEK: the tries of each mount by game day (the day that starts at the
-- daily reset, not at midnight), kept for HISTORY_DAYS -- a week and a day, enough for "since the
-- last weekly reset".
local DAY = 86400
local HISTORY_DAYS = 8
local recent = {}               -- mountID -> time() of the last count
local pending = {}              -- dungeon encounter id -> { counts = bool, at = time() } from ENCOUNTER_START
local byEncounter               -- dungeon encounter id -> { { mount, difficulties }, ... }

local function CharKey()
    local name = UnitName and UnitName("player")
    if not name or (issecretvalue and issecretvalue(name)) then return nil end
    return name .. "-" .. (GetRealmName and GetRealmName() or "")
end

local function Book()
    if not ns.db then return nil end
    ns.db.attempts = ns.db.attempts or {}
    return ns.db.attempts
end

local function Collected(mountID)
    if not (C_MountJournal and C_MountJournal.GetMountInfoByID) then return false end
    local ok, _, _, _, _, _, _, _, _, _, _, isCollected = pcall(C_MountJournal.GetMountInfoByID, mountID)
    return ok and isCollected == true
end

local function Index()
    byEncounter = {}
    for mount, b in pairs(type(ns.MountBosses) == "table" and ns.MountBosses or {}) do
        for _, boss in ipairs(b.bosses or {}) do
            local enc = boss[3]
            if type(enc) == "number" and enc > 0 then
                local list = byEncounter[enc] or {}
                byEncounter[enc] = list
                list[#list + 1] = { mount = mount, difficulties = b.difficulties }
            end
        end
    end
end

local function DropsOn(difficulties, difficultyID)
    if not difficulties then return true end
    for _, d in ipairs(difficulties) do if d == difficultyID then return true end end
    return false
end

-- The account's total: each character's share is the larger of the addon's count and the game's
-- statistics (the same kills, counted two ways).
local function Total(r)
    local n = 0
    for char, v in pairs(r.chars or {}) do n = n + math.max(v, (r.stats or {})[char] or 0) end
    for char, v in pairs(r.stats or {}) do
        if not (r.chars or {})[char] then n = n + v end
    end
    return n
end

-- The game's clock for the resets, or nil when it does not answer (or answers a secret).
local function SecondsUntil(weekly)
    if not C_DateAndTime then return nil end
    local f
    if weekly then f = C_DateAndTime.GetSecondsUntilWeeklyReset else f = C_DateAndTime.GetSecondsUntilDailyReset end
    if not f then return nil end
    local ok, s = pcall(f)
    if not ok or type(s) ~= "number" or (issecretvalue and issecretvalue(s)) then return nil end
    return s
end
Attempts.SecondsUntil = SecondsUntil

-- A reset's moment, rounded to a quarter of an hour: `now + secondsUntil` read a second apart
-- must name the same day.
local function Round(t) return math.floor((t + 450) / 900) * 900 end

-- The start of the period of `length` that holds `now`: the game's clock says when the CURRENT one
-- ends, and another moment is that start moved by whole periods.
local function PeriodStart(now, weekly, length)
    local s = SecondsUntil(weekly)
    if not s then return nil end
    local present = time and time() or now
    local start = Round(present + s - length)
    return start + math.floor((now - start) / length) * length
end

---When the game day that holds `now` started: the last daily reset. Without the game's clock, the
---UTC midnight (a day still, just not the game's).
function Attempts.DayStart(now)
    now = now or (time and time() or 0)
    return PeriodStart(now, false, DAY) or (now - now % DAY)
end

---When the week that holds `now` started: the weekly reset, or nil when the game does not say.
function Attempts.WeekStart(now)
    now = now or (time and time() or 0)
    return PeriodStart(now, true, 7 * DAY)
end

-- One more try today; days older than HISTORY_DAYS go.
local function AddToDay(r, now)
    r.days = type(r.days) == "table" and r.days or {}
    local key = Attempts.DayStart(now)
    r.days[key] = (r.days[key] or 0) + 1
    for k in pairs(r.days) do
        if type(k) ~= "number" or k < now - HISTORY_DAYS * DAY then r.days[k] = nil end
    end
end
Attempts.AddToDay = AddToDay      -- for the tests

-- The time of this try: the gap since the last one, when it is the same sitting, and the fight.
local function AddTime(r, now, fight)
    fight = type(fight) == "number" and fight > 0 and math.min(fight, MAX_FIGHT) or 0
    local start = now - fight
    local last = tonumber(r.lastAt)
    local gap = last and start - last
    local t = tonumber(r.time) or 0
    if gap and gap >= 0 and gap <= TIME_GAP then t = t + gap end
    r.time = t + fight
    r.lastAt = now
end

---One more try at `mountID` for this character (nothing when it is collected, or just counted).
---`fight` is how long the boss fight took, in seconds, when the try was a boss.
function Attempts.Count(mountID, why, fight)
    local book, char = Book(), CharKey()
    if not (book and char and mountID) or Collected(mountID) then return false end
    local now = time and time() or 0
    if recent[mountID] and now - recent[mountID] < SAME_TRY then return false end
    recent[mountID] = now
    local r = book[mountID] or { n = 0, chars = {} }
    book[mountID] = r
    if r.got then return false end
    r.chars = r.chars or {}
    r.chars[char] = (r.chars[char] or 0) + 1
    r.n = Total(r)
    r.last = date and date("%Y-%m-%d") or nil
    AddTime(r, now, fight)
    AddToDay(r, now)
    if ns.Log then pcall(ns.Log.Add, "attempt", { mount = mountID, n = r.n, why = why, fight = fight, time = r.time }) end
    return true
end

---Tries at a mount today (since the daily reset) and this week (since the weekly reset); the
---week is nil when the game does not say when it reset.
function Attempts.Recent(mountID, now)
    local r = Attempts.Of(mountID)
    now = now or (time and time() or 0)
    local day, week = Attempts.DayStart(now), Attempts.WeekStart(now)
    local today, thisWeek = 0, week and 0 or nil
    for k, n in pairs(r and type(r.days) == "table" and r.days or {}) do
        if type(k) == "number" and type(n) == "number" and k <= now then
            if k >= day - 450 then today = today + n end
            if week and k >= week - 450 then thisWeek = thisWeek + n end
        end
    end
    return today, thisWeek
end

---The time spent on a mount, in seconds (0 when none was measured).
function Attempts.Time(mountID)
    local r = Attempts.Of(mountID)
    return r and tonumber(r.time) or 0
end

---The share of players who would already have the mount after `n` tries at `p` each: 1-(1-p)^n.
function Attempts.Cumulative(p, n)
    if type(p) ~= "number" or type(n) ~= "number" or p <= 0 or n <= 0 then return nil end
    if p >= 1 then return 1 end
    -- short of certain stays short of certain, even where the float rounds it to 1
    return math.min(1 - (1 - p) ^ n, 1 - 1e-12)
end

---The chance of each try at a mount, 0..1, from the list's entry (`chance` is "1 in n"), and
---whether it is a rough sample.
function Attempts.Chance(entry)
    local c = type(entry) == "table" and tonumber(entry.chance)
    if not c or c <= 0 then return nil end
    return 1 / c, entry.chanceRough and true or false
end

---A share as the player reads it: one decimal ("97,6%"), never "100%" short of certain, and two
---significant figures under 1% ("0,35%").
function Attempts.FormatShare(v)
    if type(v) ~= "number" then return nil end
    if v >= 1 then return "100%" end
    if v <= 0 then return "0%" end
    local pct = v * 100
    local casas = pct >= 1 and 1 or math.max(1, -math.floor(math.log10(pct)) + 1)
    local m = 10 ^ casas
    local cut = math.floor(pct * m + 0.5) / m
    if cut >= 100 then cut = 100 - 1 / m end
    if cut <= 0 then cut = 1 / m end
    local txt = string.format("%." .. casas .. "f", cut):gsub("0+$", ""):gsub("%.$", "")
    return (txt:gsub("%.", ns.L["."])) .. "%"
end

---Time spent: "1 h 05 min", "12 min", "45 s".
function Attempts.FormatDuration(s)
    s = math.floor(tonumber(s) or 0)
    local L = ns.L
    if s < 60 then return L["%d s"]:format(s) end
    local h, m = math.floor(s / 3600), math.floor((s % 3600) / 60)
    if h > 0 then return L["%d h %02d min"]:format(h, m) end
    return L["%d min"]:format(m)
end

---Time until something comes back: "3 d 4 h", "5 h 12 min", "12 min".
function Attempts.FormatLeft(s)
    s = math.max(0, math.floor(tonumber(s) or 0))
    local L = ns.L
    local d, h, m = math.floor(s / DAY), math.floor((s % DAY) / 3600), math.floor((s % 3600) / 60)
    if d > 0 then return L["%d d %d h"]:format(d, h) end
    if h > 0 then return L["%d h %02d min"]:format(h, m) end
    return L["%d min"]:format(math.max(1, m))
end

---(22/10) How lucky the count is, in plain words, for the card and the tooltips: the share of
---players who would already have the mount after as many tries (1-(1-p)^n), and that the next try
---still has the same chance; for a mount that came, the share who would have needed fewer tries
---(1-(1-p)^(n-1)). Returns the share and the sentence, or nil when the chance or the count is not known.
function Attempts.LuckText(mountID, entry)
    local p = Attempts.Chance(entry)
    local r = Attempts.Of(mountID)
    if not (p and r) then return nil end
    local L = ns.L
    local chance = ns.FormatChance(entry.chance, entry.chanceRough)
    if r.got then
        local n = r.got.n or 0
        if n < 1 then return nil end
        local v = Attempts.Cumulative(p, n - 1) or 0
        return v, L["It came on attempt %d. At %s each, %s of players would have needed fewer attempts."]:format(
            n, chance, Attempts.FormatShare(v))
    end
    local n = r.n or 0
    if n < 1 then return nil end
    local v = Attempts.Cumulative(p, n)
    return v, L["With %d attempts at %s, %s of players would already have it. The chance of the next attempt is still %s."]:format(
        n, chance, Attempts.FormatShare(v), chance)
end

---"Today: 3 · This week: 12" (the week left out when the game does not say when it began).
function Attempts.RecentText(today, week)
    local L = ns.L
    if week then return L["Today: %d · This week: %d"]:format(today or 0, week) end
    return L["Today: %d"]:format(today or 0)
end

---The lines the card adds under the count: luck, time spent, today and this week.
function Attempts.DetailLines(mountID, entry, now)
    local out = {}
    local _, luck = Attempts.LuckText(mountID, entry)
    if luck then out[#out + 1] = luck end
    local t = Attempts.Time(mountID)
    if t > 0 then out[#out + 1] = ns.L["Time spent: %s"]:format(Attempts.FormatDuration(t)) end
    local r = Attempts.Of(mountID)
    if r and not r.got then
        local today, week = Attempts.Recent(mountID, now)
        if today > 0 or (week or 0) > 0 then out[#out + 1] = Attempts.RecentText(today, week) end
    end
    return out
end

---Every mount with a count, for the Attempts tab: the ones still being tried and the ones that
---came on a counted try. `{ mountID, n, got, today, week, time }`.
function Attempts.Rows(now)
    local out = {}
    for mountID, r in pairs(Book() or {}) do
        if type(mountID) == "number" and type(r) == "table" and ((r.n or 0) > 0 or r.got) then
            local today, week = Attempts.Recent(mountID, now)
            out[#out + 1] = { mountID = mountID, n = r.got and r.got.n or r.n or 0, got = r.got ~= nil,
                              today = today, week = week, time = tonumber(r.time) or 0 }
        end
    end
    return out
end

---The line over the tab: today N tries at M mounts, and this week (nil when the game does not
---say when the week began).
function Attempts.Summary(now)
    local t = { todayN = 0, todayM = 0, weekN = 0, weekM = 0, weekKnown = Attempts.WeekStart(now) ~= nil }
    for _, row in ipairs(Attempts.Rows(now)) do
        if row.today > 0 then t.todayN, t.todayM = t.todayN + row.today, t.todayM + 1 end
        if row.week and row.week > 0 then t.weekN, t.weekM = t.weekN + row.week, t.weekM + 1 end
    end
    return t
end

---The count of a mount: { n, chars, got = { n, at } } or nil.
function Attempts.Of(mountID)
    local book = Book()
    return book and book[mountID]
end

---(21/10) Does the addon count the tries at this mount? A boss of the Adventure Guide with its
---encounter id (ENCOUNTER_END), a creature of the drop table (its loot), or a count already made.
---The list's Attempts column shows a number only for these; the rest stay blank.
function Attempts.Countable(mountID)
    if not mountID then return false end
    local r = Attempts.Of(mountID)
    if r and (r.n or 0) > 0 then return true end
    local b = type(ns.MountBosses) == "table" and ns.MountBosses[mountID]
    for _, boss in ipairs(b and b.bosses or {}) do
        if type(boss[3]) == "number" and boss[3] > 0 then return true end
    end
    if ns.Sighting and ns.Sighting.CountedMounts then
        local ok, set = pcall(ns.Sighting.CountedMounts)
        if ok and type(set) == "table" and set[mountID] then return true end
    end
    return false
end

---The number for the list: the account's tries so far (0 when counted and none yet), nil when the
---addon does not count this mount.
function Attempts.Number(mountID)
    if not Attempts.Countable(mountID) then return nil end
    local r = Attempts.Of(mountID)
    return r and r.n or 0
end

---"372 attempts so far" / "Got on attempt 372", and under it, with more than one character, each
---one's share: "By character: Eldriss 210, Ezra 162" (13/10, the user: *"x tentativas nas que não
---dropou e pega com x tentativas as que já pegou (...) com o texto melhorado"*).
function Attempts.Text(mountID)
    local r = Attempts.Of(mountID)
    if not r or (r.n or 0) == 0 then return nil end
    local L = ns.L
    local text
    if r.got then
        text = L["Got on attempt %d"]:format(r.got.n)
    else
        text = r.n == 1 and L["1 attempt so far"] or L["%d attempts so far"]:format(r.n)
    end
    local names, seen = {}, {}
    for _, t in ipairs({ r.chars or {}, r.stats or {} }) do
        for char in pairs(t) do
            if not seen[char] then
                seen[char] = true
                names[#names + 1] = { char = char, n = math.max((r.chars or {})[char] or 0, (r.stats or {})[char] or 0) }
            end
        end
    end
    if #names > 1 then
        table.sort(names, function(a, b) return a.n > b.n end)
        local parts = {}
        for i, c in ipairs(names) do
            parts[i] = ("%s %d"):format((c.char:match("^[^-]+") or c.char), c.n)
        end
        text = text .. string.char(10) .. L["By character: %s"]:format(table.concat(parts, ", "))
    end
    return text
end

---How the count of a mount is made, for the window: the game's statistics by their names in the
---player's language, or the addon since it was installed. Nil for a mount that is not counted.
function Attempts.Source(mountID)
    local L = ns.L
    local stats = type(ns.MountStats) == "table" and ns.MountStats[mountID]
    if stats then
        local names = {}
        for _, id in ipairs(stats) do
            local ok, _, name = pcall(GetAchievementInfo, id)
            if ok and type(name) == "string" and name ~= "" then names[#names + 1] = name end
        end
        return L["From the game's statistics of each character, so also from before the addon: %s. A character counts once it logs in with the addon."]:format(
            #names > 0 and table.concat(names, "; ") or "?")
    end
    return L["Counted by the addon since it was installed: the game keeps no count of these tries."]
end

-- The number a statistic shows ("12"; "--" for none), or nil when it cannot be read.
local function StatValue(id)
    if not GetStatistic then return nil end
    local ok, v = pcall(GetStatistic, id)
    if not ok or v == nil or (issecretvalue and issecretvalue(v)) then return nil end
    if type(v) == "number" then return v end
    local digits = tostring(v):gsub("[^%d]", "")
    return tonumber(digits) or 0
end

---This character's statistics for every mount still to come (login, and after a kill).
function Attempts.ReadStats()
    local book, char = Book(), CharKey()
    if not (book and char and type(ns.MountStats) == "table") then return end
    for mountID, ids in pairs(ns.MountStats) do
        local r = book[mountID]
        if not (r and r.got) and not Collected(mountID) then
            local sum, read = 0, false
            for _, id in ipairs(ids) do
                local v = StatValue(id)
                if v then sum, read = sum + v, true end
            end
            if read and (sum > 0 or (r and r.stats and r.stats[char])) then
                r = r or { n = 0, chars = {} }
                book[mountID] = r
                r.stats = r.stats or {}
                if r.stats[char] ~= sum and ns.Log then
                    pcall(ns.Log.Add, "attempt-stats", { mount = mountID, char = char, was = r.stats[char], now = sum })
                end
                r.stats[char] = sum
                r.n = Total(r)
            end
        end
    end
end

---The mount came: the count stops, and the try it came on is kept.
function Attempts.Collected(mountID)
    local r = Attempts.Of(mountID)
    if r and not r.got and (r.n or 0) > 0 then
        r.got = { n = r.n, at = date and date("%Y-%m-%d") or nil }
    end
end

-- A mount learned with this addon off: on login, every count of a collected mount is closed.
local function CloseCollected()
    for mountID, r in pairs(Book() or {}) do
        if not r.got and Collected(mountID) then Attempts.Collected(mountID) end
    end
end

---A creature of the drop table looted (Sighting.RecordLoot): a try at each mount it drops.
function Attempts.Looted(npc)
    if not (ns.Sighting and ns.Sighting.MountsOf) then return end
    local ok, list = pcall(ns.Sighting.MountsOf, npc)
    for _, m in ipairs(ok and list or {}) do
        local id = m.entry and m.entry.mountID
        if id then Attempts.Count(id, "loot:" .. npc) end
    end
    -- the rare's hidden quest is flagged with the loot: this character's ledger (Lockouts.lua)
    if ns.Lockouts and C_Timer and C_Timer.After then C_Timer.After(2, function() ns.Lockouts.Record(false) end) end
end

local frame = CreateFrame("Frame")
for _, e in ipairs({ "ENCOUNTER_START", "ENCOUNTER_END", "NEW_MOUNT_ADDED", "PLAYER_LOGIN" }) do
    pcall(frame.RegisterEvent, frame, e)
end
frame:SetScript("OnEvent", function(_, event, a1, _, a3, _, a5)
    if event == "PLAYER_LOGIN" then
        CloseCollected()
        Attempts.ReadStats()
        return
    end
    if event == "NEW_MOUNT_ADDED" then
        Attempts.Collected(a1)
        return
    end
    if type(a1) ~= "number" or (issecretvalue and issecretvalue(a1)) then return end
    if not byEncounter then Index() end
    if not byEncounter[a1] then return end
    if event == "ENCOUNTER_START" then
        -- already dead in this lockout: the kill to come gives no loot, and is no try
        local _, _, difficultyID, _, _, _, _, mapID = GetInstanceInfo()
        local done = false
        if C_RaidLocks and C_RaidLocks.IsEncounterComplete and mapID then
            local ok, v = pcall(C_RaidLocks.IsEncounterComplete, mapID, a1, difficultyID)
            done = ok and v == true
        end
        pending[a1] = { counts = not done, at = time and time() or nil }
        return
    end
    -- ENCOUNTER_END: id, name, difficulty, group size, success
    if not (a5 == 1 or a5 == true) then return end
    local p = pending[a1]
    pending[a1] = nil
    if p and not p.counts then return end
    local fight = p and p.at and time and (time() - p.at) or nil
    for _, m in ipairs(byEncounter[a1]) do
        if DropsOn(m.difficulties, a3) then Attempts.Count(m.mount, "encounter:" .. a1, fight) end
    end
    -- the statistic of the kill is the game's to update: read it a little later; and this
    -- character's lockouts, which the kill just changed (Lockouts.lua)
    if C_Timer and C_Timer.After then
        C_Timer.After(5, Attempts.ReadStats)
        if ns.Lockouts then C_Timer.After(3, ns.Lockouts.Request) end
    end
end)

Attempts.Index = Index            -- for the tests
