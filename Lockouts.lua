-- RocketMount | Lockouts.lua
-- Is the source of a mount already done in this lockout -- for this character and for the others?
--
-- (22/10) The user: *"do que já fez no dia, na semana"* and *"e se for raid e etc, dá para fazer com
-- vários chars, seria bom saber com quais fez, vai que esquece entrar com um que ja fez e perde
-- tempo"*. Old raids and dungeons lock a character too, on every difficulty the game keeps a lock for.
--
-- (!) A LEDGER, LIKE Roster.lua. The game only speaks for the character logged in: the saved
-- instances (`GetSavedInstanceInfo`), the bosses killed in each (`C_RaidLocks.IsEncounterComplete`)
-- and the hidden quest of a rare (`C_QuestLog.IsQuestFlaggedCompleted`). So each character writes
-- down what the game says when it logs in, after a boss kill and after a loot, with the moment the
-- lock ENDS (now + the lock's own reset seconds), and the other characters are read from what was
-- written. An entry past its end is a lock the reset cleared. Nothing here is a guess: a lock whose
-- end is not known stops counting at the first reset after it was seen, and a source the addon has
-- no way to read is left blank ("unknown"), never "available".
--
-- What the game gives, read in the client's own code (wow-ui-source, live, 12.1.0):
--   GetSavedInstanceInfo(i)   name, lockoutId, reset (seconds), difficultyID, locked, extended,
--                             instanceIDMostSig, isRaid, maxPlayers, difficultyName, numEncounters,
--                             encounterProgress, extendDisabled, instance map id
--                             (Blizzard_RaidFrame/RaidFrame.lua reads the first ten; the 14th is the
--                             map id, as AlterEgo and SavedInstances read it)
--   GetSavedInstanceEncounterInfo(i, j)   bossName, fileDataID, isKilled
--   GetSavedWorldBossInfo(i)  name, worldBossID, reset
--   C_RaidLocks.IsEncounterComplete(mapID, encounterID, difficultyID)   (Attempts.lua uses it)
--   C_RaidLocks.GetRedirectedDifficultyID(mapID, difficultyID)   the difficulty whose lock another
--                             shares (legacy raids where sizes share one lockout)
--   EJ_GetInstanceInfo(journalInstanceID)   ..., the 10th return is the instance's map id (the
--                             JournalInstance table's MapID column says the same)
--   C_QuestLog.IsAccountQuest(questID)   a warband quest: done by one, done by all
-- RequestRaidInfo() asks the server; UPDATE_INSTANCE_INFO says the answer arrived. The saved
-- instances are read ONLY then: before it, the list can be empty, and an empty list would erase
-- the locks of the character.
local ADDON, ns = ...
local L = ns.L

local Lockouts = {}
ns.Lockouts = Lockouts

local DAY = 86400
-- "Done today" when the lock ends at the next daily reset (give or take an hour of clock).
local SLACK = 3600

local function Secret(v) return issecretvalue and issecretvalue(v) end

local function Now() return time and time() or 0 end

-- The key of Roster.lua: "Name-Realm".
local function CharKey()
    local name = UnitName and UnitName("player")
    if not name or Secret(name) then return nil end
    return name .. "-" .. (GetRealmName and GetRealmName() or "")
end
Lockouts.CharKey = CharKey

local function Ledger()
    if not ns.db then return nil end
    ns.db.locks = type(ns.db.locks) == "table" and ns.db.locks or {}
    return ns.db.locks
end

-- The warband quests: one book for the account.
local function AccountBook()
    if not ns.db then return nil end
    ns.db.lockAccount = type(ns.db.lockAccount) == "table" and ns.db.lockAccount or {}
    return ns.db.lockAccount
end

local function SecondsUntil(weekly)
    if ns.Attempts and ns.Attempts.SecondsUntil then return ns.Attempts.SecondsUntil(weekly) end
    return nil
end

--------------------------------------------------------------------------------
-- From our tables to the game's ids
--------------------------------------------------------------------------------
local mapOf = {}          -- journal instance id -> instance map id (false: the game did not say)
local bossName = {}       -- journal encounter id -> the boss's name in the player's language

local function MapOf(journalInstanceID)
    if type(journalInstanceID) ~= "number" then return nil end
    local m = mapOf[journalInstanceID]
    if m == nil then
        m = false
        if EJ_GetInstanceInfo then
            local r = { pcall(EJ_GetInstanceInfo, journalInstanceID) }
            if r[1] and type(r[11]) == "number" and r[11] > 0 and not Secret(r[11]) then m = r[11] end
        end
        mapOf[journalInstanceID] = m
    end
    return m or nil
end

local function BossName(journalEncounterID)
    if type(journalEncounterID) ~= "number" then return nil end
    local n = bossName[journalEncounterID]
    if n == nil then
        n = false
        if EJ_GetEncounterInfo then
            local ok, name = pcall(EJ_GetEncounterInfo, journalEncounterID)
            if ok and type(name) == "string" and name ~= "" and not Secret(name) then n = name end
        end
        bossName[journalEncounterID] = n
    end
    return n or nil
end

-- map id -> { { enc = dungeon encounter id, je = journal encounter id }, ... }, the bosses of our
-- table, rebuilt when the table is another one.
local byMap, byMapFor
local function BossesByMap()
    local t = type(ns.MountBosses) == "table" and ns.MountBosses or {}
    if byMapFor == t and byMap then return byMap end
    byMap, byMapFor = {}, t
    for _, b in pairs(t) do
        local m = not b.world and MapOf(b.instance)
        if m then
            for _, boss in ipairs(b.bosses or {}) do
                if type(boss[3]) == "number" and boss[3] > 0 then
                    local l = byMap[m] or {}
                    byMap[m] = l
                    local ja = false
                    for _, x in ipairs(l) do if x.enc == boss[3] then ja = true end end
                    if not ja then l[#l + 1] = { enc = boss[3], je = boss[1] } end
                end
            end
        end
    end
    return byMap
end

---For the tests: the game's answers are asked again.
function Lockouts.Reset() mapOf, bossName, byMap, byMapFor = {}, {}, nil, nil end

-- The difficulty whose lock this one uses (legacy sizes that share a lock). The game answers; when
-- it does not, the difficulty itself.
local function Redirect(mapID, d)
    if C_RaidLocks and C_RaidLocks.GetRedirectedDifficultyID then
        local ok, r = pcall(C_RaidLocks.GetRedirectedDifficultyID, mapID, d)
        if ok and type(r) == "number" and r > 0 and not Secret(r) then return r end
    end
    return d
end

--------------------------------------------------------------------------------
-- Writing down this character
--------------------------------------------------------------------------------
-- Every saved instance the game lists, of any age and difficulty, with the bosses of our table
-- killed in it: `{ ["map:difficulty"] = { exp, d, name, killed = { [encounter] = true } } }`.
local function ReadInstances(now)
    if not (GetNumSavedInstances and GetSavedInstanceInfo) then return nil end
    local okN, n = pcall(GetNumSavedInstances)
    if not okN or type(n) ~= "number" or Secret(n) then return nil end
    local out, idx = {}, BossesByMap()
    for i = 1, n do
        local v = { pcall(GetSavedInstanceInfo, i) }
        local name, reset, diff, locked, extended = v[2], v[4], v[5], v[6], v[7]
        local numEnc, mapID = v[12], v[15]
        if v[1] and (locked or extended) and type(reset) == "number" and reset > 0 and not Secret(reset)
            and type(mapID) == "number" and not Secret(mapID) and type(diff) == "number" and not Secret(diff) then
            local e = { exp = now + reset, d = diff, name = type(name) == "string" and not Secret(name) and name or nil, killed = {} }
            for _, b in ipairs(idx[mapID] or {}) do
                local killed = false
                if C_RaidLocks and C_RaidLocks.IsEncounterComplete then
                    local ok, done = pcall(C_RaidLocks.IsEncounterComplete, mapID, b.enc, diff)
                    killed = ok and done == true
                end
                -- The saved instance's own list of bosses, by the name the game gives both.
                if not killed and GetSavedInstanceEncounterInfo and type(numEnc) == "number" and not Secret(numEnc) then
                    local nome = BossName(b.je)
                    for j = 1, numEnc do
                        local okE, bn, _, isKilled = pcall(GetSavedInstanceEncounterInfo, i, j)
                        if okE and isKilled == true and nome and bn == nome then killed = true end
                    end
                end
                if killed then e.killed[b.enc] = true end
            end
            out[mapID .. ":" .. diff] = e
        end
    end
    return out
end

-- The world bosses the game lists: `{ [name] = exp }`.
local function ReadWorldBosses(now)
    if not (GetNumSavedWorldBosses and GetSavedWorldBossInfo) then return nil end
    local okN, n = pcall(GetNumSavedWorldBosses)
    if not okN or type(n) ~= "number" or Secret(n) then return nil end
    local out = {}
    for i = 1, n do
        local ok, name, _, reset = pcall(GetSavedWorldBossInfo, i)
        if ok and type(name) == "string" and not Secret(name) and type(reset) == "number" and not Secret(reset) and reset > 0 then
            out[name] = now + reset
        end
    end
    return out
end

-- Every rare's hidden quest the table knows: done ones are written with when they end.
local function ReadQuests(me, now)
    if not (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and type(ns.RareLockout) == "table") then return end
    local conta = AccountBook()
    local daily, weekly = SecondsUntil(false), SecondsUntil(true)
    me.quests = {}
    for npc, rl in pairs(ns.RareLockout) do
        local q = type(rl) == "table" and rl.q
        local f = ns.Sighting and ns.Sighting.LootFrequency and ns.Sighting.LootFrequency(npc) or rl.f
        if type(q) == "number" and f ~= "unlimited" and f ~= "firstbest" then
            local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, q)
            if ok and not Secret(done) then
                local okA, acct = false, false
                if C_QuestLog.IsAccountQuest then okA, acct = pcall(C_QuestLog.IsAccountQuest, q) end
                acct = okA and acct == true
                local book = acct and conta or me.quests
                if done == true then
                    local exp = (f == "daily" and daily and now + daily) or (f == "weekly" and weekly and now + weekly) or nil
                    book[q] = { at = now, exp = exp, d = daily and now + daily or nil, w = weekly and now + weekly or nil }
                elseif book then
                    book[q] = nil
                end
            end
        end
    end
    me.questsAt = now
end

---Writes down this character: who it is, its rares' quests and, when `instances` (the answer to
---RequestRaidInfo just arrived), every saved instance and world boss.
function Lockouts.Record(instances)
    local book, key = Ledger(), CharKey()
    if not (book and key) then return end
    local now = Now()
    local me = type(book[key]) == "table" and book[key] or {}
    book[key] = me
    me.name = UnitName("player")
    me.realm = GetRealmName and GetRealmName() or ""
    if UnitClass then me.class = select(2, UnitClass("player")) end
    if UnitLevel then
        local ok, lv = pcall(UnitLevel, "player")
        if ok and type(lv) == "number" and not Secret(lv) then me.level = lv end
    end
    me.seen = now
    if instances then
        local inst = ReadInstances(now)
        if inst then me.inst, me.instAt = inst, now end
        local world = ReadWorldBosses(now)
        if world then me.world = world end
    end
    ReadQuests(me, now)
    if ns.Log then
        local n = 0
        for _ in pairs(me.inst or {}) do n = n + 1 end
        pcall(ns.Log.Add, "lockouts", { char = key, instances = instances and n or nil, level = me.level })
    end
end

---Asks the server for this character's saved instances (the answer is UPDATE_INSTANCE_INFO) and
---writes the quests now.
function Lockouts.Request()
    if RequestRaidInfo then pcall(RequestRaidInfo) end
    Lockouts.Record(false)
end

--------------------------------------------------------------------------------
-- Reading: one mount, one character
--------------------------------------------------------------------------------
---What decides the lockout of a mount: its bosses (an instance's, with the game's encounter id),
---else the rares of the drop table that give it, else its world boss by name.
local function Units(mountID)
    local units = {}
    local b = type(ns.MountBosses) == "table" and ns.MountBosses[mountID]
    if b and not b.world then
        local m = MapOf(b.instance)
        for _, boss in ipairs(m and b.bosses or {}) do
            if type(boss[3]) == "number" and boss[3] > 0 then
                units[#units + 1] = { kind = "boss", map = m, enc = boss[3], diffs = b.difficulties }
            end
        end
        if #units > 0 then return units end
    end
    local npcs = ns.Sighting and ns.Sighting.NpcsOfMount and ns.Sighting.NpcsOfMount(mountID) or {}
    for _, npc in ipairs(npcs) do
        local rl = type(ns.RareLockout) == "table" and ns.RareLockout[npc]
        local f = ns.Sighting.LootFrequency and ns.Sighting.LootFrequency(npc) or (rl and rl.f)
        if f == "unlimited" or f == "firstbest" then
            units[#units + 1] = { kind = "open" }
        elseif type(rl) == "table" and type(rl.q) == "number" then
            units[#units + 1] = { kind = "quest", q = rl.q }
        else
            units[#units + 1] = { kind = "unknown" }
        end
    end
    if #units == 0 and b and b.world then
        for _, boss in ipairs(b.bosses or {}) do
            local name = BossName(boss[1]) or boss[2]
            if name then units[#units + 1] = { kind = "world", name = name } end
        end
    end
    return units
end
Lockouts.Units = Units

local function DifficultyName(d)
    if GetDifficultyInfo then
        local ok, name = pcall(GetDifficultyInfo, d)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    return tostring(d)
end

-- The parts of one unit for one character: `{ state = "done"|"open"|"unknown", exp, label, account }`.
local function Parts(u, c, now, out)
    if u.kind == "open" then
        out[#out + 1] = { state = "open" }
    elseif u.kind == "unknown" then
        out[#out + 1] = { state = "unknown" }
    elseif u.kind == "quest" then
        local acct = AccountBook()
        local e = acct and acct[u.q]
        local account = e ~= nil
        e = e or (type(c.quests) == "table" and c.quests[u.q])
        if type(e) == "table" then
            if e.exp then
                out[#out + 1] = now < e.exp and { state = "done", exp = e.exp, account = account } or { state = "open" }
            elseif e.d and now < e.d then
                -- no reset went by since it was seen done: still done, return not known
                out[#out + 1] = { state = "done", account = account }
            else
                out[#out + 1] = { state = "unknown" }
            end
        elseif c.questsAt then
            out[#out + 1] = { state = "open" }
        else
            out[#out + 1] = { state = "unknown" }
        end
    elseif u.kind == "world" then
        local exp = type(c.world) == "table" and c.world[u.name]
        -- only "done" can be read here: an old world boss that is not in the game's list locks by a
        -- quest the addon may not know
        out[#out + 1] = (exp and now < exp) and { state = "done", exp = exp } or { state = "unknown" }
    elseif u.kind == "boss" then
        if type(c.inst) ~= "table" then
            out[#out + 1] = { state = "unknown" }
        elseif u.diffs then
            for _, d in ipairs(u.diffs) do
                local lock = c.inst[u.map .. ":" .. Redirect(u.map, d)]
                local done = type(lock) == "table" and lock.exp and now < lock.exp and lock.killed and lock.killed[u.enc]
                out[#out + 1] = done and { state = "done", exp = lock.exp, label = DifficultyName(d) }
                    or { state = "open", label = DifficultyName(d) }
            end
        else
            -- every difficulty: the ones the game lists a lock for are known; the rest of the
            -- instance's difficulties are not listed by us, so they are open as far as we know
            local any = false
            local prefix = u.map .. ":"
            for k, lock in pairs(c.inst) do
                if type(k) == "string" and k:sub(1, #prefix) == prefix and type(lock) == "table"
                    and lock.exp and now < lock.exp and lock.killed and lock.killed[u.enc] then
                    out[#out + 1] = { state = "done", exp = lock.exp, label = DifficultyName(lock.d) }
                    any = true
                end
            end
            out[#out + 1] = { state = "open", other = any }
        end
    end
end

---The state of a mount's source for one character of the ledger (this one when `key` is nil):
---`{ status = "done"|"partial"|"available", back = seconds until it comes back (or nil), done =
---{ labels }, open = { labels }, account = bool }`, or nil when it cannot be known.
function Lockouts.State(mountID, key, now)
    now = now or Now()
    key = key or CharKey()
    local book = Ledger()
    local c = book and key and book[key]
    if type(c) ~= "table" then return nil end
    local units = Units(mountID)
    if #units == 0 then return nil end
    local parts = {}
    for _, u in ipairs(units) do Parts(u, c, now, parts) end
    local nDone, nOpen, nUnknown, back, backKnown, account = 0, 0, 0, nil, true, false
    local doneL, openL = {}, {}
    for _, p in ipairs(parts) do
        if p.state == "done" then
            nDone = nDone + 1
            if p.exp then back = math.min(back or math.huge, p.exp - now) else backKnown = false end
            if p.account then account = true end
            if p.label then doneL[#doneL + 1] = p.label end
        elseif p.state == "open" then
            nOpen = nOpen + 1
            if p.label then openL[#openL + 1] = p.label end
        else
            nUnknown = nUnknown + 1
        end
    end
    local st = { done = doneL, open = openL, account = account }
    if nDone > 0 and nOpen == 0 and nUnknown == 0 then
        st.status = "done"
        st.back = backKnown and back or nil
    elseif nDone > 0 and nOpen > 0 then
        st.status = "partial"
        st.back = backKnown and back or nil
    elseif nOpen > 0 then
        st.status = "available"
    else
        return nil
    end
    return st
end

---"Done today" / "Done this week" / "Done", by when the lock ends against the game's resets.
function Lockouts.Period(back)
    local daily, weekly = SecondsUntil(false), SecondsUntil(true)
    if back and daily and back <= daily + SLACK then return L["Done today"] end
    if back and weekly and back <= weekly + SLACK then return L["Done this week"] end
    return L["Done"]
end

---The two lines of a state, for a cell: the state, and when it comes back.
function Lockouts.Label(st)
    if not st then return "", nil end
    if st.status == "done" then
        return Lockouts.Period(st.back), st.back and L["back in %s"]:format(ns.Attempts.FormatLeft(st.back)) or nil
    elseif st.status == "partial" then
        return L["Partly done"], nil
    end
    return L["Available"], nil
end

---One line for a tooltip or the card: "Done this week — back in 3 d 4 h", and for a partial one,
---which difficulties are done and which are still open.
function Lockouts.Sentence(st)
    if not st then return nil end
    if st.status == "done" then
        local p = Lockouts.Period(st.back)
        if st.back then p = L["%s — back in %s"]:format(p, ns.Attempts.FormatLeft(st.back)) end
        if st.account then p = p .. " " .. L["(the whole warband)"] end
        return p
    elseif st.status == "partial" then
        local linhas = {}
        if #st.done > 0 then
            local p = L["Done on %s"]:format(table.concat(st.done, ", "))
            if st.back then p = L["%s — back in %s"]:format(p, ns.Attempts.FormatLeft(st.back)) end
            linhas[#linhas + 1] = p
        else
            linhas[#linhas + 1] = L["Partly done"]
        end
        if #st.open > 0 then linhas[#linhas + 1] = L["Still open on %s"]:format(table.concat(st.open, ", ")) end
        return table.concat(linhas, string.char(10))
    end
    return L["Available"]
end

--------------------------------------------------------------------------------
-- Every character of the ledger
--------------------------------------------------------------------------------
local function Colored(c)
    local name = c.name or "?"
    if C_ClassColor and C_ClassColor.GetClassColor and c.class then
        local ok, color = pcall(C_ClassColor.GetClassColor, c.class)
        if ok and type(color) == "table" and color.WrapTextInColorCode then return color:WrapTextInColorCode(name) end
    end
    return name
end

local function MaxLevel()
    if not GetMaxLevelForPlayerExpansion then return nil end
    local ok, lv = pcall(GetMaxLevelForPlayerExpansion)
    return ok and type(lv) == "number" and lv or nil
end

---Who of the ledger did it and who can still go: `{ done = { char }, can = { char }, below = n,
---account = st|nil }`, this character first, then by name. A character below the maximum level is
---not offered as one that can go (what the content asks of it is not known); one with no state
---known is left out.
function Lockouts.Characters(mountID, now)
    now = now or Now()
    local book, me = Ledger(), CharKey()
    local out = { done = {}, can = {}, below = 0 }
    if not book then return out end
    local keys = {}
    for k, c in pairs(book) do if type(c) == "table" then keys[#keys + 1] = k end end
    table.sort(keys, function(a, b)
        if (a == me) ~= (b == me) then return a == me end
        return (book[a].name or a) < (book[b].name or b)
    end)
    local max = MaxLevel()
    for _, k in ipairs(keys) do
        local c = book[k]
        local st = Lockouts.State(mountID, k, now)
        if st and st.status == "done" and st.account then
            out.account = st
            break
        end
        if st then
            local entry = { key = k, name = c.name or k, class = c.class, st = st, me = k == me }
            if st.status == "done" then
                out.done[#out.done + 1] = entry
            elseif c.level and max and c.level < max then
                out.below = out.below + 1
            else
                out.can[#out.can + 1] = entry
            end
        end
    end
    return out
end

---"Done this week: A, B · Can still go: C", the names in their class colours; nil when the ledger
---has nobody to name. The second return is the quiet note about who is not in the ledger.
function Lockouts.CharactersText(mountID, now)
    local who = Lockouts.Characters(mountID, now)
    if who.account then
        return L["%s: the whole warband"]:format(Lockouts.Period(who.account.back)), nil
    end
    if #who.done == 0 and #who.can == 0 then return nil end
    local partes = {}
    if #who.done > 0 then
        local back
        for _, c in ipairs(who.done) do
            if c.st.back then back = math.min(back or math.huge, c.st.back) end
        end
        local nomes = {}
        for i, c in ipairs(who.done) do nomes[i] = Colored(c) end
        partes[#partes + 1] = L["%s: %s"]:format(Lockouts.Period(back), table.concat(nomes, ", "))
    end
    if #who.can > 0 then
        local nomes = {}
        for i, c in ipairs(who.can) do nomes[i] = Colored(c) end
        partes[#partes + 1] = L["Can still go: %s"]:format(table.concat(nomes, ", "))
    end
    local nota = L["Characters that never logged in with the addon are not listed."]
    if who.below > 0 then nota = nota .. " " .. L["Characters below the maximum level are not offered."] end
    return table.concat(partes, "  ·  "), nota
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------
local frame = CreateFrame("Frame")
-- (After a boss kill Attempts.lua asks again, and after a rare's loot it writes the quests.)
for _, e in ipairs({ "PLAYER_LOGIN", "UPDATE_INSTANCE_INFO" }) do
    pcall(frame.RegisterEvent, frame, e)
end
frame:SetScript("OnEvent", function(_, event)
    if event == "UPDATE_INSTANCE_INFO" then
        Lockouts.Record(true)
        if ns.RefreshAttemptsViews then ns.RefreshAttemptsViews() end
    elseif event == "PLAYER_LOGIN" then
        Lockouts.Request()
    end
end)
Lockouts.__frame = frame
