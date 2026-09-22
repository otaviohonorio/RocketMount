# Rocket Mounts 0.18.0

First public release, and it is an **alpha**: the ranking rules are covered by an offline test
harness, but very little of this has been confirmed in a live client yet. Expect rough edges,
and please report what you find.

What it does:

- Lists the mounts you are still missing, ordered from easiest to hardest, with a card
  explaining how each one is obtained.
- Reads requirements from the game itself — reputation and renown, achievements, quests, vendor
  prices, and the item's own tooltip — rather than from a hand-maintained database.
- Says "I cannot read this" instead of treating unknown requirements as no requirement. A mount
  gated behind something the addon cannot measure stays out of the top of the list.
- Warns you when something in front of you drops a mount you are missing, with a chat link that
  drops a map pin where you saw it.
- Filters by source, expansion and faction, and searches by name, boss, zone or vendor.
- Notes which of your characters has a legacy reputation, from a ledger written as each one
  logs in.
- English and Brazilian Portuguese, using the game's own words where the game provides them.

Known limits, stated up front:

- Drop chances and map coordinates come from Mount Collection Log, and the share-of-playerbase
  number from MountJournalEnhanced. Without those addons installed, the list still works with
  less information, and the footer says so.
- Guild vendor mounts cannot be fully read: no installed catalogue links a guild achievement to
  a mount, so the card tells you that instead of guessing.
- Expansion is derived from mount ID ranges, so a handful of late additions land one expansion
  off. It is a way to narrow the list, not a source of truth.
