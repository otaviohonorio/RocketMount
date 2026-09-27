-- RocketMount | Data/MountTips.lua
-- What players found out about getting a mount, in OUR words. A PILOT: five mounts (27/09).
--
-- The user, after the card learnt to quote the game: MCL's tooltip also says HOW to farm, and
-- that text is MCL's author's. His pointer to where the knowledge is public: *"pelo wowhead
-- quando tu achar a montaria, sempre vai ter os comentários, ali tu pode filtrar o pessoal
-- explicando como pega"*.
--
-- HOW A TIP IS MADE. `tools/coletar_dicas.py` picks, from the comments on the mount's item page,
-- the ones that read like an explanation, and writes them to `.release/dicas/` for a person to
-- read. The tip is then WRITTEN here, short, from what two or more of them agree on. No comment
-- is copied: the facts are nobody's, the sentences are their authors'.
--
-- WHAT A TIP IS NOT. It is not the game speaking. The card's other blocks are read from the
-- client and are right after every patch; this one was true when somebody wrote it down, and
-- the card says so, with the year. `year` is that year.
--
-- THE NAMES COME FROM THE GAME. `{item:207026|Dreamsurge Coalescence}` is shown as the item's
-- name in the player's language, asked by id; what follows the bar is what is shown when the game
-- does not answer. Kinds: item, npc, achievement, quest, faction, currency, map. A thing the game
-- cannot name by id (a chest, a crystal on the ground) is written out, and translated with the
-- sentence.
--
-- Keyed by mount id (`C_MountJournal`). The Portuguese of each one is in `Locales/ptBR.lua`,
-- under the English text, like every other sentence of this addon.
local ADDON, ns = ...

ns.MountTips = {
    -- Duskwing Ohuna
    [1671] = { year = 2023, text =
        "{item:207026|Dreamsurge Coalescence} comes from the green orbs scattered over the zone "
        .. "where the Dreamsurge is active, and from the creatures killed there. "
        .. "{npc:210608|Celestine of the Harvest} is at the Dreamsurge symbol on the map." },

    -- Otto
    [1656] = { year = 2023, text =
        "A chain, most of it fishing.\n"
        .. "1. Get one {item:199340|Gold Coin of the Isles}: fished in the Dragon Isles, or 75 "
        .. "{item:199338|Copper Coin of the Isles} traded up with {npc:191608|The Great Swog}.\n"
        .. "2. Buy {item:202102|Immaculate Sac of Swog Treasures} from him with it. Most of the "
        .. "time it has {item:202042|Aquatic Shades}; when it does not, it takes another coin.\n"
        .. "3. Wearing the shades, dance for 5 minutes on the dance floor of the underwater bar in "
        .. "{map:2022|The Waking Shores}, at 19.6, 36.5.\n"
        .. "4. Pick up the {item:202061|Empty Fish Barrel} and fill it: 100 "
        .. "{item:202072|Frigid Floe Fish} (open water around Iskaara), 25 "
        .. "{item:202073|Calamitous Carp} (lava around the Obsidian Citadel) and 1 "
        .. "{item:202074|Kingfin, the Wise Whiskerfish} (water around Algeth'ar Academy).\n"
        .. "5. Take the barrel back to where you danced: Otto offers {quest:72738|The Way to an Otto's Heart}." },

    -- Long-Forgotten Hippogryph
    [802] = { year = 2018, text =
        "Five Ephemeral Crystals appear at the same time at random spots of {map:630|Azsuna}, "
        .. "many of them inside caves. Touching the first one starts 8 hours to touch the other "
        .. "four; dying loses the count. Other players are after the same crystals, and when "
        .. "somebody finishes they all vanish until the next round." },

    -- Dark Phoenix
    [401] = { year = 2021, text =
        "Sold by the guild vendors to a character Exalted with a guild that has "
        .. "{achievement:4988|Guild Glory of the Cataclysm Raider}. Joining a guild that already "
        .. "has it works, but the reputation with a new guild starts over. Once learnt, the mount "
        .. "is yours whatever guild you are in." },

    -- Verdant Skitterfly
    [1617] = { year = 2022, text =
        "Reach Renown 25 with {faction:2507|Dragonscale Expedition}. From then on it has a small "
        .. "chance to be inside every Expedition Scout's Pack." },
}
