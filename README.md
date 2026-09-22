# Rocket Mounts

The mounts you are still missing, **ordered from easiest to hardest**, with a card explaining how
each one is obtained. For World of Warcraft: Midnight (12.x).

> 🇧🇷 [Leia em português](README-ptBR.md)

⚠️ **Not published yet.** This addon is still in development and its interface is currently
hardcoded in Brazilian Portuguese. It needs `Locales/` with English as the key language before it
can go on the release pipeline.

## Why it exists

Mount catalogues already exist and they are good. What none of them answers is the question you
actually have when you sit down to collect: **which one should I go after first?**

The existing addons sort by rarity — the rarest first, which is the opposite of a starting point
— and they answer per zone, when you happen to have the world map open. Rocket Mounts asks the
inverse question and answers it in one ordered list.

## How the order is decided

Every mount falls into a band by a **stated rule**, and each row shows **the number that put it
there**. If you disagree with the criterion, you can see why it landed where it did.

| Band | Rule |
|---|---|
| **Guaranteed — just go get it** | a known access requirement, met, and nothing left to luck |
| **Check with the vendor** | the price fits, but no access requirement is known |
| **Guaranteed — nearly unlocked** | 75% or more of the requirement |
| **Guaranteed — halfway** | 25% or more |
| **Luck — good odds** | unlocked, and 1 in 100 or better |
| **Long road** | worse odds, or the requirement barely started |
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
each alt and they appear; `/rmt quem` shows what is on record.

It is a ledger, not a live reading, and it says so: everything in it was true when that character
last logged in.

## Mounts that left the game

Ended promotions, trading card game mounts, retired achievements. They cannot be obtained by
anyone any more, so they stay out of the list — in a list whose whole subject is *where do I
start*, a mount nobody can get is the worst possible row. Turn them on with `/rmt sumidas` or in
the options, and they appear last, in their own band, with no effort estimate: it is not hard,
it is impossible.

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
| `/rmt fontes` | clears the source filter |
| `/rmt minimapa` | shows or hides the minimap button |
| `/rmt faccao [minha\|horda\|alianca]` | filters by faction |
| `/rmt quem` | the characters on record and how many reputations each has |
| `/rmt sumidas` | shows or hides the mounts that left the game |
| `/rmt debug [name]` | what the addon managed to read, for everything or for one mount |

## License

MIT — see `LICENSE`.
