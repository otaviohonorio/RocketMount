# Rocket Mount 0.21.0

**The rare alert now tells you the chance.** When you fly past a rare that drops a mount you are
missing, the panel says who the rare is, which mounts, and the chance of each — for example
`Rootstalker Grimlynx ~1/910`.

- The chances come from Wowhead's drop counts and are built into the addon, so no other addon is
  needed. They are samples, not official rates: rounded to two figures, with a `~` when fewer than
  ten drops were recorded.
- Many more creatures are recognised — rares, elites, world bosses and the trash that drops a
  mount, such as the Qiraji tanks in Ahn'Qiraj. Rootstalker Grimlynx, for instance, drops from
  fifteen rares in Harandar, not just Rhazul.
- Rares are now identified by their creature ID, including from the minimap vignette, so the
  alert works in flight and the same rare seen two ways alerts only once.
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
