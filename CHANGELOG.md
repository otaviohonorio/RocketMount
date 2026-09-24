# Rocket Mount 0.22.0

**The window now looks like part of the game.** It is built on the same parts as Blizzard's own
mount journal: the portrait frame with its title and close button, the list inset with the
journal's row style and scroll bar, the search box and the standard filter button (with its
reset "x") at the top of the list, and a "Not collected" counter next to the portrait.

- The filter button replaces the old "Sources" button; the source list inside it is the same.
- **Rares on the world map.** The rares, elites and world bosses that drop a mount you are
  missing now show on the world map, with the game's own rare icons. Hover one to see which
  mounts it drops — with each mount's icon — and the chance of each; click it to point the
  arrow there. Creature and mount names come in your game's language. Once you loot it,
  it dims until it can drop again. Only in the open world; turn it off in the options.
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
