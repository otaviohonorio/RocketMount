# Rocket Mount

The mounts you are still missing, **ordered from easiest to hardest**, with a card explaining how
each one is obtained. For World of Warcraft: Midnight (12.x).

> 🇧🇷 [Leia em português](README-ptBR.md)

⚠️ **Not published yet.** This addon is still in development. Everything it writes on screen now
goes through `Locales/`, with English as the key language and a Brazilian Portuguese translation
next to it, which was the last thing blocking the release pipeline.

## Why it exists

Mount catalogues already exist and they are good. What none of them answers is the question you
actually have when you sit down to collect: **which one should I go after first?**

The existing addons sort by rarity — the rarest first, which is the opposite of a starting point
— and they answer per zone, when you happen to have the world map open. Rocket Mount asks the
inverse question and answers it in one ordered list.

## How the order is decided

Every mount falls into a band by a **stated rule**, and each row shows **the number that put it
there**. If you disagree with the criterion, you can see why it landed where it did.

| Band | Rule |
|---|---|
| **Guaranteed — just go get it** | a known access requirement, met, and nothing left to luck — a purchase only once the vendor confirmed it |
| **Guaranteed — nearly unlocked** | 75% or more of the requirement |
| **Guaranteed — halfway** | 25% or more |
| **Luck — good odds** | unlocked, and 1% or better |
| **Long road** | worse odds, or the requirement barely started |
| **Not confirmed** | a purchase the vendor has not confirmed yet — open it once to settle it |
| **No estimate** | no installed catalogue knows how to measure this one |

Two distinctions carry the whole thing:

**A requirement is not an acquisition.** Reputation, currency and achievements say whether you
*may try*. What actually delivers the mount is something else — buying from a vendor delivers,
killing a boss with a 1-in-100 chance does not. So "just go get it" requires a deterministic
acquisition; with any drop chance in the way, the requirement at most unlocks the farm.

**Access is not price.** Gold is almost never what blocks anyone — reputation, achievements,
guild level and rating are. A mount where the only thing we know is its price goes to "Check with
the vendor", which promises exactly what can be proven.

## Where the data comes from

| Data | Source |
|---|---|
| What is missing, source type, the game's own "how to get" text | `C_MountJournal` |
| Reputation and renown progress | `C_Reputation`, `C_MajorFactions` |
| Currency, gold and items you hold | `C_CurrencyInfo`, `C_Item`, `GetMoney` |
| Partial achievement progress | `GetAchievementCriteriaInfo` |
| Whether the quest that grants it is done | `C_QuestLog.IsQuestFlaggedCompleted` |
| **What the game says is required** | the mount item's own tooltip, via `C_TooltipInfo` |
| Drop rate, coordinates, required faction | `MCL_GUIDE` (from the MCL addon) |
| Share of players who own the mount | `MountsRarity-2.0` (inside MountJournalEnhanced) |

The last two are **optional dependencies**: without them the window still opens and the footer
says in red what is no longer available. The addon deliberately does not rebuild a catalogue that
already exists and is well maintained — it contributes the ranking.

Everything about **your** progress comes from the API, which is exact and always current. Each
reputation line says whether the progress is account-wide or belongs only to the character you
are logged in on, by name.

## Which of your characters has it

Reputation is read from the character you are logged in on — that is all the API will answer.
Some reputations are account-wide since The War Within, and the row says which kind it is, by
name: *"reputation on the account"* or *"only on this character (Name)"*.

For the character-bound ones, the addon keeps a ledger: every time a character logs in, it writes
down where that character stands with the factions some mount asks for. A mount you cannot buy
here then says who can — *"Ottozinho has it (Exalted) — not on this character"*. Log in once on
each alt and they appear; `/rmt who` shows what is on record.

It is a ledger, not a live reading, and it says so: everything in it was true when that character
last logged in.

## On the world map

The rares, elites and world bosses that drop a mount **you** are missing show on the world map,
with the game's own rare icons. Hover one: which mounts, and the chance of each. Click it: the
map arrow points there. Looted today, it dims — the place is still worth knowing for tomorrow.
Open world only, like the alert. The positions come from Wowhead's map, built into the addon;
turn the pins off in the options.

## When something in front of you drops a mount

Fly past it and see it on the minimap, target it, mouse over it, or let it yell when it spawns,
and a small panel says who the rare is, which mounts you are missing can come from it, and **the
chance of each**. A link in chat points the map arrow at the rare.

It is not a second rare scanner. SilverDragon tells you a rare is there; this tells you **a mount
you are missing** is there, and which one. A rare whose mount you already have says nothing at
all, and neither does a rare you already looted today: it respawns, but it cannot drop anything
for you until the reset. Mounts that left the game say nothing either — that would just be
taunting. And it only speaks in the open world: inside dungeons, raids, delves and scenarios it
stays quiet.

The chances come from Wowhead's drop counts, built into the addon (`Data/MobDrops.lua`), so no
other addon is needed. They are samples, not Blizzard's rates: they are rounded to two figures,
and a `~` marks the ones based on fewer than ten drops. Turn the alert off with `/rmt warn` or
the checkbox in the options.

## Searching

The box at the top of the window filters as you type, and it does **not** search the mount name
only. The mount that drops from Fyrakk is called *Anu'relos, Flame's Guidance* — the word
"Fyrakk" appears nowhere in its name, so a name-only search would fail on exactly the case that
makes people reach for a search box.

So it searches everything the addon knows about a mount: name, Blizzard's own source text, the
boss, the vendor, the zone and the faction. Accents are ignored, and every word you type has to
match — typing more narrows, which is what typing more is supposed to do.

## Mounts that left the game

Ended promotions, trading card game mounts, retired achievements. They cannot be obtained by
anyone any more, so they stay out of the list — in a list whose whole subject is *where do I
start*, a mount nobody can get is the worst possible row. Turn them on with `/rmt gone` or in
the options, and they appear last, in their own band, with no effort estimate: it is not hard,
it is impossible.

## Why there is no curated database here

The obvious fix for "the catalogue does not know about this requirement" is to write our own
database. We do not, and the reason is the failure mode: **a curated entry that is wrong is
wrong silently**, forever, and it is the addon speaking with confidence about something nobody
verified. This addon's whole point is not claiming more than it can prove.

The game already knows. Hover the mount's item anywhere and the tooltip says, in your language,
*"Requires Exalted with <faction>"* or *"Requires <achievement>"*. `C_TooltipInfo` hands those
same lines to an addon as data, and the addon reads them: they cover every mount that has an
item, they are right after the next patch with nobody maintaining them, they are already
translated, and when they say nothing that silence is the truth rather than a gap in somebody's
spreadsheet.

The requirement patterns are built from the client's own global strings, never written out in
one language — a hardcoded "Requires" would break on every non-English client, silently.

## What cannot be answered: "is this quest available?"

If a mount comes from a quest, the addon tells you whether **you have completed it**, and whether
another of your characters has. It cannot tell you whether you can *pick it up* — whether some
earlier quest, reputation or level still stands in the way.

That is not an omission. The client does not expose a quest's prerequisites to addons at all; of
the addons installed here, 67 call `IsQuestFlaggedCompleted` and **none** call anything about
prerequisites, because there is nothing to call. The addons that do show quest chains, like
Zygor, ship a hand-built database of their own.

"Not completed" still answers the question that matters — something is in the way — without
pretending to know how many steps are left.

## Known gap

**Attempt lockouts are not modelled.** A 1-in-100 drop from a boss on a weekly lockout and a
1-in-100 drop from a mob with no lockout are years apart, and today they land in the same band.
Neither the API nor any installed catalogue stores the lockout period per mount, so the row shows
the method and leaves the judgement to you. No estimate was invented to fill the hole.

## How to use it

| Command | What it does |
|---|---|
| `/rmt` | opens and closes the list |
| `/rmt top <n>` | how many rows the list shows |
| `/rmt sources` | clears the source filter |
| `/rmt minimap` | shows or hides the minimap button |
| `/rmt faction [mine\|horde\|alliance]` | filters by faction |
| `/rmt who` | the characters on record and how many reputations each has |
| `/rmt gone` | shows or hides the mounts that left the game |
| `/rmt search <text>` | searches by name, boss, zone or vendor |
| `/rmt expansion [name]` | filters by expansion |
| `/rmt warn` | turns the sighting alert on or off |
| `/rmt i18n` | checks the labels taken from the game |
| `/rmt debug [name]` | what the addon managed to read, for everything or for one mount |

## Support

These addons are free and always will be. If they save you time every session, there are two
ways to help, and both pay for the same thing — the hours that go into keeping them current
with each patch:

- **[Ko-fi](https://ko-fi.com/ottorocket)** — a one-off tip, any amount, **no account needed**.
- **[GitHub Sponsors](https://github.com/sponsors/otaviohonorio)** — recurring, if you'd rather.

Doing neither costs you nothing here. A good bug report is worth just as much.

## License

MIT — see `LICENSE`.
