# Rocket Mount 0.24.1

- **Much lighter on the CPU and on memory.** While you played, the addon rebuilt its whole list
  of mounts every couple of seconds, at every coin looted, reputation gained or creature
  hovered. It now rebuilds when the set of mounts changes or when you look at the list, and at
  most every 20 seconds in the background.
- The markers on the minimap are no longer redrawn from scratch ten times a second while you
  move.
