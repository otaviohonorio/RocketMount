# Rocket Mounts 0.19.0

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
