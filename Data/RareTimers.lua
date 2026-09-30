-- RocketMount | Data/RareTimers.lua
--
-- The rares that appear on a FIXED CLOCK, and the clock of each. Written by us, one entry
-- per rare, from what two or more sources agree on; the game has no table that says it.
--
-- npc id -> { period, afterReset, lasts }: the window in which the rare appears opens
-- `afterReset` seconds after the daily reset and again every `period` seconds, and stays
-- open for `lasts` seconds. The addon computes the next opening from the game's own clock
-- (`C_DateAndTime.GetSecondsUntilDailyReset`), and says "appears in" or "appearing now".
--
-- (!) WHY (30/09). The user, with the tooltip of another addon that says "Shadow in 2h 13m":
-- *"adiciona esse tempo também para o usuário saber quando logar o char e tentar achar o
-- raro"*. A rare that dies in seconds and comes once every three hours is only got by whom
-- is there when it comes.
local ADDON, ns = ...

ns.RareTimers = {
    -- Beledar's Spawn (Hallowfall): appears when Beledar's Shadow begins, 1 h 01 min after the
    -- daily reset and every 3 hours, for 30 minutes. Sources: Wowhead comment 5879919 on npc
    -- 207802 (2024-06, rating 266: "every 3 hours, starting 1 hour after the daily reset,
    -- lasts for 30 minutes"); the HandyNotes plugin of The War Within counts the same cycle
    -- from the reset, 1 h 01 min after it (read only to confirm); Wowhead comment 2026-07-02:
    -- the players' timer macro uses a cycle of 10,800 seconds.
    [207802] = { period = 3 * 3600, afterReset = 3600 + 60, lasts = 30 * 60 },
}
