# Rocket Mount 0.22.1

- **One place, one marker.** A vendor and a quest at the same point were two markers, one on
  top of the other, even when they were of the same mounts; so were the creatures that take
  turns at one spot and drop the same mount. They are one marker now: its tooltip names each of
  them and lists every mount once, with the best chance there.
- **Ritual sites on the map.** The four mounts of the ritual sites now have a marker at the way
  in to the site, with the game's own ritual site icon. A site is only marked while the game
  itself shows it on the map.
- The tip of the Void-Corrupted Lynx now says what it really takes: the mount is crafted with
  Leatherworking, and the part you loot is the leash from the ritual chest.
- The way in to the Horrific Visions is on the map of Dornogal, with the eight mounts that come
  from them, while the game shows it. New tips for the Voidfire Deathcycle and the Mail Muncher.
- **Beledar's Spawn tells the hour.** Its marker and its card say when Beledar's Shadow comes
  next ("Appears in 2h 13min") or how long it still lasts, from the game's own clock.
- **The alert has a sound.** A short, simple chime plays when the alert of a rare shows. It is
  the addon's own, so it is not mistaken for any sound of the game. In the options, under the
  alert's own switch: turn it off, pick one of four chimes (picking one plays it) and set how
  loud it is, in five steps.
- **The alert is a little larger**, mostly wider: a long mount name and the line of numbers
  have more room.
- **Shorter labels in the options.** Each option is named in two or three words; hover it for
  what it does.
- **Tips in the window.** At the top right, the "Tips" button says how many of your characters
  the addon has read; hover it for what feeds the list: entering with each character, opening
  the mount vendors, opening the Trading Post, looting the rares. Click it for the list of
  those characters, and pick one that no longer exists to take it out.
- **The list keeps up with your character.** Renown gained, a covenant chosen, an achievement
  earned or advanced, a quest handed in, gold spent, an item of a price looted, a level or a
  profession gained now update the list and the map; before, some of these waited for
  something else to refresh them.
- A vendor's refusal is looked at again every time: once the requirement the item showed in red
  is met, the mount no longer reads "the vendor does not sell it to you yet".
- The price a vendor charges is kept for each character: a reputation discount on one no
  longer shows on the others.
- **A reputation on its way no longer reads 0%.** A vendor mount whose item names the same
  reputation the addon already measures (the riding goats of The Tillers, for one) showed 0%
  and "1 more requirement" even at Revered. It now shows how far along you are.
- Fixed a Lua error when looting Huolon.
- A marker of several creatures only dims as "already looted" when every one of them is.
