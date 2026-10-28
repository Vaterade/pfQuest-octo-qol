# pfQuest [Octo QoL]

Convenience modules for [pfQuest](https://github.com/brues-code/pfQuest) on OctoWoW,
ported from the deleted `roby-brok/pfQuest-octo` pack. They were written by Shadowtoots for
[Bennylavaa/pfQuest-turtle](https://github.com/Bennylavaa/pfQuest-turtle).

Requires the ClassicAPI client mod. Meant to run with
[pfQuest-octo-plus](https://github.com/Salahaja/pfQuest-octo-plus) as the database, but works
with any pfQuest database.

## Nameplate quest icons

A sword on a mob your quests need killed, a bag on one that drops an item they need.

- `/pfqnp on | off` turns the icons on or off
- `/pfqnp scale <n> | x <n> | y <n>` sizes and moves them
- `/pfqnp debug` lists the mobs that get an icon

## Party quest progress

Party members running this addon send each other their objective counts. Mouse over a mob,
an object or a pfQuest map pin to see everyone's progress on it. The messages are the same
as the old pfQuest-octo pack's, so party members still running that pack also work.

- `/pfqparty on | off` turns it on or off, including sending
- `/pfqparty` lists what your party has sent
- `/pfqparty sync` asks the party to resend
- `/pfqparty test <unit name>` adds fake progress on a unit, to check the tooltip

## Corpse arrow

While you're a ghost, pfQuest's route arrow points at your corpse, with the distance in yards
and a rude message. When you revive it goes back to your quests.

- `/pfqarrow on | off` turns it on or off

The old module's arrow scale setting is not ported: brues-code's pfQuest has its own
(Arrow Scale, in pfQuest's settings).

## Changes from the pfQuest-octo modules

- Nameplates come from ClassicAPI's nameplate events instead of guessing them from
  `WorldFrame`'s children by their border texture, which pfUI's nameplates remove.
- Quest IDs come from the quest log through ClassicAPI instead of matching titles against
  every quest in the database on each update.
- Names come from the client's locale instead of English only.
- Turning party progress off also stops sending.
- The corpse arrow shows even without a quest target, points using world coordinates, and
  puts pfQuest's arrow text back after you revive.
- The party module no longer replaces the global Lua error handler.
- The settings window entries are only added when pfQuest hasn't built its window yet.
  The slash commands work either way.
