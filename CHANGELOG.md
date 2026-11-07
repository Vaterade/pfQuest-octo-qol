# Changelog

Each release gets a section here, newest first. The release workflow copies the section for
the version in `pfQuest-octo-qol.toc` into the GitHub release notes, so write it for players.

Versions follow [semantic versioning](https://semver.org/): a fix raises the last number, a
new feature the middle one. While the first number is 0 the addon isn't considered stable yet.

## [0.1.0] - 2026-11-06

The first release. Each module has a slash command and a setting in pfQuest's settings window;
the README describes them.

### Added
- **Nameplate quest icons** (`/pfqnp`): a sword or bag on mobs your quests need.
- **Party quest progress** (`/pfqparty`): party members' objective counts in tooltips,
  compatible with the old pfQuest-octo pack.
- **Corpse arrow** (`/pfqarrow`): pfQuest's route arrow points at your corpse while you're a ghost.
- **Objective announcements** (`/pfqannounce`, off by default): tells your party about finished objectives.
- **Rare loot panel** (`/pfqloot`): rank on elite, rare and boss pins; Alt-Click shows their drops.
- **Continent pins** (`/pfqmap`): pfQuest's pins on the continent and world maps.
- **Quest automation** (`/pfqauto`, off by default): accepts and turns in quests at NPCs.
- **Survival trees** (`/pfqtrees`, off by default): tracks the trees Survival cuts wood from.
- All module settings in pfQuest's settings window, laid out in three columns.

[0.1.0]: https://github.com/Vaterade/pfQuest-octo-qol/releases/tag/v0.1.0
