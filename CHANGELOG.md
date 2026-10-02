# Rocket Mount 0.25.0

- **Fixed an error on the world map.** After using the list's map pin, hovering one of the
  game's own event icons could show *"attempt to perform arithmetic on local 'textHeight' (a
  secret number value, while execution tainted by 'RocketMount')"*. The addon no longer opens
  the map itself: the pin and the arrow are set as before, and the chat line carries the
  game's own link, which opens the map on the pin.
- **Open and track the achievement, from the list.** A mount that comes from an achievement
  has no place on the map, so its row now carries the game's achievement shield: click it to
  open the achievement in the game's own window, right-click to put it in the game's tracker
  (or take it out).
- The mount's card has the two actions as buttons, **Open the achievement** and **Track**, for
  any mount with an achievement still to do.
