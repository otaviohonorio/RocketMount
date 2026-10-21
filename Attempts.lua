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
local recent = {}               -- mountID -> time() of the last count
local pending = {}              -- dungeon encounter id -> { counts = bool } from ENCOUNTER_START
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

---One more try at `mountID` for this character (nothing when it is collected, or just counted).
function Attempts.Count(mountID, why)
    local book, char = Book(), CharKey()
    if not (book and char and mountID) or Collected(mountID) then return false end
    local now = time and time() or 0
    if recent[mountID] and now - recent[mountID] < SAME_TRY then return false end
    recent[mountID] = now
    local r = book[mountID] or { n = 0, chars = {} }
    book[mountID] = r
    if r.got then return false end
    r.chars[char] = (r.chars[char] or 0) + 1
    r.n = Total(r)
    r.last = date and date("%Y-%m-%d") or nil
    if ns.Log then pcall(ns.Log.Add, "attempt", { mount = mountID, n = r.n, why = why }) end
    return true
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
        pending[a1] = { counts = not done }
        return
    end
    -- ENCOUNTER_END: id, name, difficulty, group size, success
    if not (a5 == 1 or a5 == true) then return end
    local p = pending[a1]
    pending[a1] = nil
    if p and not p.counts then return end
    for _, m in ipairs(byEncounter[a1]) do
        if DropsOn(m.difficulties, a3) then Attempts.Count(m.mount, "encounter:" .. a1) end
    end
    -- the statistic of the kill is the game's to update: read it a little later
    if C_Timer and C_Timer.After then C_Timer.After(5, Attempts.ReadStats) end
end)

Attempts.Index = Index            -- for the tests
