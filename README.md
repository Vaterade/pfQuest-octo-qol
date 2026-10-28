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

## Objective announcements

Tells your party when you finish a quest objective, with links to the quest and the item:
"Finished [Harpy Feather] for [Gather Feathers]." Optionally also every step: "[Harpy
Feather] for [Gather Feathers] (5 left)". Both are off until you turn them on. Only sent
while you're in a party.

- `/pfqannounce finished on | off` announces finished objectives
- `/pfqannounce remaining on | off` announces each step
- `/pfqannounce item on | off` links the item in finished announcements, or names the
  objective instead
- `/pfqannounce test Harpy Feather: 8/8` shows what would be sent, in your chat only

## Rare loot panel

World map and minimap pins of elites, rares and bosses show the mob's rank. Alt-Click one on
the world map to open a panel of what it drops, with drop chances; hover an icon for the
item. Alt-Click the pin again, or the x, to close it.

- `/pfqloot` lists the filters and their state
- `/pfqloot <filter> on | off` with the filters `pooled` (loot from shared pools), `unknown`
  (items with no known chance), `worlddrops` (hide items 200+ mobs drop), `equip`, `quest`,
  `starters`, `recipes`, `grey`, `white`

## Continent pins

pfQuest only draws its pins on zone maps. This draws them on the continent maps and the world
view too, for every zone the client can place, Turtle's included. Utility pins (flight masters,
innkeepers, banks and the like) show; other tracking pins would bury the continent and don't.
Quests that are grey or too high for you are left off, following pfQuest's own settings.

- `/pfqmap on | off` turns them on or off
- `/pfqmap ctrl on | off` makes the pins ignore the mouse unless you hold Ctrl, so clicks
  reach the map
- `/pfqmap size <n>`, `/pfqmap utilitysize <n>` set the pin sizes (12 and 14)

## Quest automation

Off until you turn it on. Talking to an NPC then turns in your finished quests and accepts
the ones it offers. Hold Shift while talking to do it by hand. It leaves to you turn-ins that
cost money and rewards with more than one choice, and by default skips grey quests.

- `/pfqauto on | off` turns it on or off
- `/pfqauto lowlevel on | off` skips or accepts grey quests
- `/pfqauto runecloth on | off` includes the repeatable Additional Runecloth donations

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
- Announcements read the quest log without changing its selection, take the quest and item
  IDs from ClassicAPI, respect pfQuest's quest link setting, and are only sent for
  objectives of quests in your log. They have their own `/pfqannounce` command instead of
  hooking `/pfdb`.
- The loot panel's filters use ClassicAPI's item class IDs instead of English type names,
  asks the server for items the client hasn't seen so their icons fill in, keeps each mob's
  drop list for the session instead of rebuilding it whenever the map opens, and is only
  offered on world map pins, since the panel lives on the world map.
- Continent pins are placed from the client's own map data through ClassicAPI instead of
  hand-written boundaries for the 47 original zones, use pfQuest's own pins, no longer resize
  zone map pins, and redraw when the map or pins change instead of every 0.15 seconds. Pins
  that land on the same spot are drawn once, for any city and zone rather than six fixed
  pairs. The old module's quest filter settings were never applied by that pack and are left
  out.
- Quest automation reads gossip quests through ClassicAPI instead of parsing the list as the
  later clients' (title, level, low-level) triples, which picked the wrong quests on 1.12. It
  only opens finished quests instead of the first one you have with that NPC, takes a single
  reward without asking, leaves turn-ins that cost money to you, stops instead of retrying a
  quest that just failed, and finds low level quests from their level instead of the words
  "low level" in the title.
- The settings window entries are only added when pfQuest hasn't built its window yet.
  The slash commands work either way.
