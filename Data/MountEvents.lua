-- RocketMount | Data/MountEvents.lua
--
-- The world events that lead to a mount, and the clock of each, for the alert minutes before one starts
-- (Events.lua). Written by us, one entry per event.
--
-- (!) WHY (22/10). The user: *"existe 'eventos' que podem dropar ou conseguir moeda (...) para conseguir
-- montaria, seria legal ter a opção de ser avisado por padrão mas editável 5 min antes de iniciar o
-- evento"*, and: *"apenas para os eventos das montarias que ele ainda não tem e apenas das que tem
-- certeza que tem montaria"*. An event is here only when the mount is SURELY its own: its chest, its
-- currency, its renown. Left out on purpose:
--   * Superbloom: the Dream mounts come from the seeds and from quests (Dream Infusion), not from the
--     event (the user: "não é evento e (...) vale até revisão");
--   * Curse Surge: our own tip (MountTips 3051/3061) says ANY rare of the Coiled Isle can drop Topaz
--     Skyfang and Ruby Writhe -- not the surge's;
--   * events the player starts (Awakening the Machine) or that follow a phase with no known start
--     (Spreading the Light), and those whose clock no two sources agree on (Dreamsurge, Elemental Storm).
--
-- Each entry:
--   key       the option's name (`ns.db.eventOff[key]`)
--   name      the game's name of the event (Locales: AreaPOI / AreaPOI.ptBR of the client, 12.1)
--   map       the zone, by uiMapID: its name comes from the game (C_Map.GetMapInfo)
--   pois      the event's AreaPOI ids: the game's own schedule (C_EventScheduler) is asked first
--   mounts    the mount ids the event leads to; the alert names the ones the player lacks
--   quest     optional: the hidden quest that marks the reward taken (weekly); done = no alert
--   clock     optional: { period, lasts, anchor } in seconds, anchor = a start in server time (Unix),
--             or a table of anchors by region (GetCurrentRegion: 1 Americas -- Brazil included --,
--             3 Europe). With neither clock nor a game schedule, no alert: never a guessed hour.
--   npc       optional: a rare on Data/RareTimers.lua's clock (Beledar's Spawn)
--   how       "drop" | "currency" | "renown": what the tooltip says about the mount
--   reward    "weekly" | "daily" | "repeat": how often the event gives what leads to the mount (the chest, the currency,
--             the renown); a rare's comes from its loot table (Sighting.LootFrequency)
--
-- The clocks: the hourly and half-hourly starts agree in two independent places -- the event's own
-- pages (Wowhead, warcraft.wiki.gg) and the anchors other addons count from (read to learn, 22/10:
-- GW2_UI's event tracker). The game's schedule (C_EventScheduler), when it lists the event, wins.
local ADDON, ns = ...

ns.MountEvents = {
    -- Midnight, Voidstorm: every 30 minutes, for 15. The weekly Victorious Stormarion Pinnacle Cache
    -- (item 260940) carries Contained Stormarion Defender, 441 in 11,661 (MountPlaces). Weekly quest 90962.
    { key = "stormarion", name = "Stormarion Assault", map = 2405, pois = { 8419, 8421, 8422 }, how = "drop",
      mounts = { 2767 }, quest = 90962, reward = "weekly", clock = { period = 1800, lasts = 900, anchor = 1772728200 } },
    -- Midnight: Unalloyed Abundance (currency 3377) buys Amani Sunfeather and Blessed Amani Burrower,
    -- 6,400 each (MountPlaces). The cave moves: only the game's schedule says when.
    { key = "abundance", name = "Abundance", pois = { 8415, 8416, 8417, 8418 }, how = "currency",
      mounts = { 2693, 2772 }, reward = "repeat" },
    -- The War Within, Hallowfall: Beledar's Spawn, on its own clock (Data/RareTimers.lua).
    { key = "beledar", name = "Beledar's Spawn", map = 2215, npc = 207802, how = "drop", mounts = { 2192 } },     -- its loot: Data/RareLockout.lua
    -- The War Within, Hallowfall: every hour on the hour, 15 minutes. Flame's Radiance renown 9:
    -- Radiant Imperial Lynx (MountReputation).
    { key = "nightfall", name = "Nightfall", map = 2215, pois = { 8174, 8175, 8291 }, how = "renown",
      mounts = { 2519 }, reward = "repeat", clock = { period = 3600, lasts = 900, anchor = 1757134800 } },
    -- Dragonflight, Thaldraszus: every hour on the hour, 15 minutes. Paracausal Flakes (currency 2594)
    -- buy the seven mounts at 3,000 each (MountPlaces 1776-1783).
    { key = "timerift", name = "Time Rift", map = 2025, pois = { 7492 }, how = "currency",
      mounts = { 1776, 1777, 1778, 1779, 1781, 1782, 1783 }, reward = "repeat",
      clock = { period = 3600, lasts = 900, anchor = { [1] = 1701831600, [3] = 1689274800 } } },
    -- Dragonflight, the Azure Span: every hour at half past, 10 minutes. Immaculate Tome (item 213177):
    -- Clayscale Hornstrider, 406 in 27,334 (MountPlaces).
    { key = "bigdig", name = "The Big Dig", map = 2024, pois = { 7657 }, how = "drop",
      mounts = { 2038 }, reward = "repeat", clock = { period = 3600, lasts = 600, anchor = 1705595400 } },
    -- Dragonflight, the Azure Span: every 90 minutes, 15; the Americas and Europe half an hour apart.
    -- Iskaara Tuskarr renown 25/30: the four Ottuks (MountReputation). Weekly quest 70893.
    { key = "feast", name = "Community Feast", map = 2024, pois = { 7218, 7219, 7220 }, how = "renown",
      mounts = { 1653, 1655, 1657, 1659 }, quest = 70893, reward = "weekly",
      clock = { period = 5400, lasts = 900, anchor = { [1] = 1679751000, [3] = 1679749200 } } },
    -- Dragonflight, Zaralek Cavern: every hour at half past, 25 minutes. Loamm Niffen renown 18:
    -- Morsel Sniffer (MountReputation).
    { key = "researchers", name = "Researchers Under Fire", map = 2133, pois = { 7459, 7460, 7461, 7462 }, how = "renown",
      mounts = { 1738 }, reward = "repeat", clock = { period = 3600, lasts = 1500, anchor = { [1] = 1670333400, [3] = 1683804600 } } },
}
