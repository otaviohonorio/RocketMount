# Rocket Mount 0.22.0

**The window now looks like part of the game.** It is built on the same parts as Blizzard's own
mount journal: the portrait frame with its title and close button, the list inset with the
journal's row style and scroll bar, the search box and the standard filter button (with its
reset "x") at the top of the list, and a "Not collected" counter next to the portrait.

- The filter button replaces the old "Sources" button; the source list inside it is the same.
- **Collected, and the next mount-count achievement.** Beside "Not collected", the window shows
  how many mounts you have and the next "Obtain N mounts" achievement with the game's own
  progress on it (546/600) — which only counts mounts this character can use.
- **One list, with columns.** The bands are gone from the window: the list is ordered by one
  number, and each row says what the mount is — **Type** (Raid, Dungeon, Drop, Quest,
  Achievement, Renown, Reputation, Vendor…) and **Expansion**, both in your game's language. Click
  a column to filter by it or group the list by it; inside a group the number still decides. The
  window is wider and taller (1244×660), the rows a little taller, and the Type column shows up to three tags.
- **One number, and it means what the mount depends on.** A drop shows its chance (a 1-in-3
  cache is 33%, even while a reputation still stands in the way); an achievement shows how much
  of it is done; a reputation shows how far you are to the standing asked for. Gold counts
  last: only once every other requirement is met.
- **Achievements count like Almost Completed Achievements.** Partial criteria count — 546 of 600
  mounts is 91%, not 0% — and a meta achievement counts the progress of the achievements inside
  it (Worldsoul-Searching, Light Up the Night, A World Awoken…).
- **Your closest character counts.** For a character-bound reputation, the list uses whichever
  of your characters is closest and names it — the number carries that character's class icon, and the line under the name starts with its name; logging in on that character, the chat tells you
  which mounts it is the closest to. Characters are noted as they log in.
- **Reputations that only the vendor asks for are known**: 171 mounts, 76 of them new — like
  the Gilded Prowler, which asks for Exalted with The Ascended although its item does not say so.
- **Every achievement that gives a mount is known**, from the game's own data: about 260 of
  them, secret achievements included, and the ones whose reward line names an item instead of
  the mount (Glory of the Firelands Raider, the Gladiator mounts…). Only your faction's
  achievement counts.
- **How often a rare's loot comes back.** The map tooltip, the on-screen alert and the chat line
  say whether a rare can be looted once a day, once a week or on every kill — so nobody camps a
  weekly world boss every day. Where no source says, the addon learns it from the game: after
  your kill it watches which reset clears the rare's hidden quest, and remembers the answer for
  the whole account. Until then it says plainly that it is not known yet. "Already looted" now
  comes from the game itself for the 140 rares whose hidden quest is known.
- **Every source on the world map.** Each place a mount you are missing comes from is a
  marker: the rares, elites and world bosses that drop it, the vendor, the quest giver, the
  treasure, the raid or dungeon entrance. The marker is the **mount's icon** inside the game's
  own map marker, with a small symbol for the kind of source and the word under it (which you
  can turn off); elites wear the game's dragon frame. Hover one to see every mount you are
  missing there — with each mount's icon — and the chance or how far along you are; click it
  to point the arrow there. Names come in your game's language. A vendor with several mounts
  is one marker; a marker on an entrance steps aside so the game's entrance icon stays
  visible; a rare inside a cave or sub-zone shows on the zone's map too. Every known spawn
  point is on the map (Beledar's Spawn has 20). Once you loot a rare, it dims until it can
  drop again. Vendors, quests, treasures and entrances come from Mount Collection Log when
  it is installed. Only in the open world; each family can be turned off in the options.
- **A real description of how to get each mount**, on the card and on the map. The card opens
  with the mount's flavour line and then says, in your game's language: how the game says it
  is obtained; **where** — who sells or drops it, in which zone, at which coordinates, every
  place and not just the first; the chance, the boss, the difficulty it drops on and how often
  the loot comes back; every requirement, met or not; **what the currency or item it costs
  is**, in the game's own words (where it comes from, who takes it); and **what the
  achievement asks**, with the criteria you still have to do. The card scrolls, so nothing is
  left out. On the world map, a marker with a single mount shows the same description.
- **Players' tips**: where the game's own text is not enough — a secret, a long chain, a
  currency nobody explains — the card adds a short tip written from what players reported,
  checked against other sources, with the year it was reported. Names in it come from your
  game. The first batch covers the Midnight mounts that need one: the treasures with steps
  (Untainted Grove Crawler, Ancestral War Bear, Hexed Vilefeather Eagle, Insatiable
  Shredclaw), Echo of Aln'sharan, the ritual site mounts, the mounts that drop from a zone's
  rares, Hexflame Reaver, Spirit of Tok'jara, and a price the journal gets wrong (Blessed
  Amani Burrower). The second covers The War Within: Alunira, Siesbarg, Thrayir, the mounts
  of the Horrific Visions, the Stonevault Mechsuit, the mounts of Undermine and of K'aresh,
  and the ones the journal still lists under a quest that is gone (the Delver's mounts, now
  sold by Reno Jackson). On the world map, a rare that drops two mounts with the same tip
  shows it once, under the list.
- **A mount you cannot pay for is no longer shown at 100%.** The price used to come from
  another addon's table; alone, RocketMount knew no price, and a vendor mount costing a
  currency you did not have could read "100%, all requirements met". The price now comes from
  the game: what the vendor charges, read when you open the vendor, and before that what the
  mount journal states. The journal's price only ever counts against you — it often names
  just the first part of a price — so such a mount waits in "check with the vendor" until a
  vendor has been seen.
- **The drop chance comes from the addon itself.** The list used to take it from another
  addon; now it reads the table built into RocketMount (Wowhead's counts, 158 mounts). When
  several creatures drop a mount, the number is the best creature's; an estimate from few drops
  is marked with "~". A creature that drops the mount nearly every time — a rare that is hard
  to find, a boss you have to summon — shows no chance at all, and the row says why: the kill
  is certain, reaching it is the task.
- **Smaller map markers.** They are now the size of the game's own quest marker (the ring is
  20 across, it was 25), so a zone full of rares covers less of the map.
- **The rare alert looks like the game's.** It is now the game's own new-mount alert: who the
  rare is, the mount you are likeliest to get and its chance, and how often the loot comes
  back. Hover it for every mount and each chance; click it to point the map arrow at the
  rare; right-click to dismiss it.
- **Nothing reaches the top of the list without being checked.** When a character logs in, the
  addon loads every missing mount's item from the server and reads its requirements before
  showing the list — a loading bar shows the progress. A mount bought from a vendor is "just go
  get it" only when that vendor has told this character it will sell; open the vendor once and
  the game settles it. Until then it waits in "Not confirmed", near the end of the list, with
  what is already known about it.
- Vendor mounts that the collection data knows only by vendor are now read from their item, so
  covenant, reputation and Archivists' Codex requirements show up. Some conditions live only at
  the vendor — a guild achievement, a Brawler's Guild rank — and those mounts stay in "Not
  confirmed" until the vendor itself answers.
- Guild vendor mounts (such as the Dark Phoenix) are recognised again in every case.
- **Every drop chance is now a percentage** — in the list, on the mount's card, in the alert
  and in chat. 1 in 200 reads 0.5%; 1 in 100 reads 1%.
- The chat command is `/rmt` (also `/rocketmount`).

## 0.21.0

**The rare alert now tells you the chance.** When you fly past a rare that drops a mount you are
missing, the panel says who the rare is, which mounts, and the chance of each — for example
`Rootstalker Grimlynx ~0.11%`.

- The chances come from Wowhead's drop counts and are built into the addon, so no other addon is
  needed. They are samples, not official rates: rounded to two figures, with a `~` when fewer than
  ten drops were recorded. For a boss, the chance is the one on the difficulty the mount drops on
  (Invincible's Reins: 1% on 25 heroic).
- Many more creatures are recognised — rares, elites and world bosses. Ordinary mobs with a
  zone-wide drop are left out on purpose: an alert on every nameplate would be noise.
- Alerts are for the open world only. Inside dungeons, raids, delves and scenarios the addon
  stays quiet. Rootstalker Grimlynx, for instance, drops from
  fifteen rares in Harandar, not just Rhazul.
- Rares are now identified by their creature ID, including from the minimap vignette, so the
  alert works in flight and the same rare seen two ways alerts only once.
- A rare you already looted today stays quiet when it respawns, since it cannot drop anything
  for you until the daily reset (the weekly one for bosses). Mounts you already own are never
  offered, including one you learned a minute ago.
- The chat link points the map arrow at where the rare actually is.

**The addon is now called Rocket Mount** (it was *Rocket Mounts*). The folder, the saved settings
and the GitHub repository all use the new name.

Still an **alpha** — most of this is covered by an offline test harness rather than confirmed in
a live client. Please keep reporting what you find.

**The sighting alert was wrong in four different ways, and this fixes all four.** It fired in
Silvermoon, at the login screen, for a rare that lives in another zone entirely:

- It matched on the rare's **name alone**. Now the minimap **vignette id** is the main key — a
  number, identical in every language — and a name match is only accepted when you are actually
  standing in a zone where that rare lives.
- It trusted anything wearing the right name. Now a unit has to be a **creature** (so a hunter
  pet named after a rare can never trigger it) **and** be classified by the game as rare or
  rare elite.
- The map pin landed on **your own feet**, wherever you happened to be, while the rare's real
  coordinates went unused. The arrow now points at the rare.
- The panel held for 12 seconds, which is not long enough to read while you are playing. It now
  holds for 25, and still closes on a click.

If you have **Mount Collection Log** installed, note that it has an equivalent alert of its own
and you may see both. Turn either one off with `/rmt warn` or in MCL's options.
- **Support the project**: a small link with the PayPal logo, on its own line at the bottom of the window (and a row at the end of the options panel), opens the PayPal link ready to copy — in reais when the game
  is in Portuguese, in dollars otherwise.
