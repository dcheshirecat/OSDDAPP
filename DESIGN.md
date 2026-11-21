# Design notes

## Decisions from the kickoff Q&A

| Topic | Choice |
|---|---|
| Inspiration | Lived experience and the wider DID/OSDD community |
| Tone | Mix of cozy, validating, funny slice-of-life and grounded |
| Gacha | Classic gacha with currency, random pulls and 5 rarity tiers (STT-like) |
| Sensitivity | Content warnings before heavy events, plus a resources page |
| Tasks | Like Star Trek Timelines: quick chores use shuttle-style timers; big life events use step-by-step away-mission style |
| Fronting | Team of 3–4; the chosen fronter's stats matter most |
| Resources | Spoons, stress, system communication |
| Failure | Moderate: lose rewards, gain stress |
| Skills | 6 core skills: Social, Organization, Physical, Regulation, Focus, Creativity |
| Roles | Yes, as gameplay traits |
| Progression | Levels, duplicate pulls raise stars, relationship bonds, comfort items |
| Custom alters | Cosmetic only (name, pronouns, alternate full-body look) |
| Art | Free commercial-use full-body art (Open Peeps / Humaaans); headshots cropped from the same body so they match |
| Scope | Full-featured |
| Monetization | Free; everything earned in game |
| Connectivity | Offline, with backup (currently a copy/paste backup code) |
| Story | Light: 6 chapters that unlock task areas |
| Headspace | Decoratable hub |

## Core math (`game/scripts/game.gd`)

- **Skill** = `base × (1 + 5%·(level−1)) × (1 + 20%·(stars−1))` + equipment, plus a roll range of +10%–50% of base. Base by rarity is 30/45/65/90/120 for the primary skill, ×0.7 for the second skill and ×0.45 for the third.
- **Chore power** = for each skill, fronter's average + 35% of each teammate's, weighted by the chore. That total is multiplied by `(1 + bonus%)`, where the bonus comes from traits, roles, bonds, communication and stress.
- **Chance** = `clamp(0.5 + 0.6·(power/difficulty − 1), 5%, 99%)`.
- **Events**: each step rolls the fronter's skill (plus 25% of teammates' skill) against a step difficulty. A failure costs a star and adds stress; the player can then retry (1 spoon), push through, or leave.

## Ideas for later

- Real cloud save (Google Play Games Saved Games or Google Drive)
- Local notifications when a task finishes
- Sound and music
- Seasonal events and more chapters
- Fully custom alters with their own stats
