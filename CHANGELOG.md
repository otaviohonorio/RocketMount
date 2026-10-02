# Rocket Mount 0.24.1

- **Much lighter on the CPU and on memory.** While you played, the addon rebuilt its whole list
  of mounts every couple of seconds, at every coin looted, reputation gained or creature
  hovered. It now rebuilds when the set of mounts changes or when you look at the list, and at
  most every 20 seconds in the background.
- **A lighter start.** When the game opens, the addon waits a few seconds for the world to be
  on screen and then does its work a little per frame, instead of all of it in the busiest
  moment. The list is also rebuilt a little per frame while you play.
- The markers on the minimap are no longer redrawn from scratch ten times a second while you
  move.
