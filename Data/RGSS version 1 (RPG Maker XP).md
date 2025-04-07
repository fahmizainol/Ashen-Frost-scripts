RGSS version 1 (RPG Maker XP)
ALC_SOFT_pause_device present
Backend : OpenGL
GL Vendor : ATI Technologies Inc.
GL Renderer : AMD Radeon RX 6700 XT
GL Version : 4.6.0 Compatibility Profile Context 25.3.1.250220
GLSL Version : 4.60
Loading path cache...
Path cache completed.
Warning: No soundfont specified, sound might be mute
Warning: No soundfont specified, sound might be mute
Primary font not found: Arial
GPU Cache Max: 16384

---

## Pokemon Ashen Frost Output Window

If you can see this window, you are running the game in Debug Mode. This means
that you're either playing a debug version of the game, or you're playing from
within RPG Maker XP.

Closing this window will close the game. If you want to get rid of this window,
run the program from the Shell, or download a release version of the game.

---

## Debug Output:

Compiling plugin scripts... done.

Loaded plugin: v20.1 Hotfixes
Loaded plugin: Updated Quicksave
Loaded plugin: Tip Cards
Loaded plugin: Tutor.net
Loaded plugin: Roaming Icons in Map
Loaded plugin: Rename from Party
Loaded plugin: RMXP Event Exporter
Loaded plugin: Poké Ball Swap
Loaded plugin: Pokemon Selection
Loaded plugin: Generation 9 Pack
Loaded plugin: Ocarina
Loaded plugin: Multiple Protagonists
Loaded plugin: Modern Quest System + UI
Loaded plugin: Mid Battle Dialogue
Loaded plugin: Marin's Scripting Utilities
Loaded plugin: Phantombass AI
Loaded plugin: Luka's Scripting Utilities
Loaded plugin: Essentials Deluxe
Loaded plugin: Auto Multi Save
Loaded plugin: Hidden Abilities by Percentage
Loaded plugin: Marin's Case System
Loaded plugin: Fame Checker
Loaded plugin: FL's Controls Menu
Loaded plugin: Customizable Level Cap
Loaded plugin: Enhanced UI
Loaded plugin: Easy Text Skip
Loaded plugin: Discord Rich Presence API
Loaded plugin: Difficulty Modes
Loaded plugin: Level Based Mixed EV System and Allocator
Loaded plugin: Blackjack minigame
Loaded plugin: Better Speed Up
Loaded plugin: Better Move Tutor by Sonicover
Loaded plugin: Infinite Save Backups
Loaded plugin: Advanced Map Transfers

Exception `Errno::ENOENT' at 001_RPG_Cache.rb:118 - No such file or directory - Graphics/Characters/base_surf
Exception `Errno::ENOENT' at 001_RPG_Cache.rb:118 - No such file or directory - Graphics/Characters/base_dive
AI initialized
==============================
Bubble Beam => 40

Knock Off => 36

Protect => 0

Night Slash => 41

==============================
Now calcing all moves vs Crawdaunt
==============================
Ice Punch => 24
Beat Up => 21
Lash Out => 24
Brick Break => 61
========== Turn 1 ==========
[AI Threat Assessment: Crawdaunt] -1: for us outspeeding
[AI Threat Assessment: Crawdaunt] +0: to factor in set up
Crawdaunt's threat score against Sneasel => -1
Checking flags...
No flags found.
Setting flags...
Offensive Move Count: 3
Priority Move Count: 1
End flag assignment.
Moves for Sneasel against Crawdaunt

Test move Ice Punch (1)...
= 1

Test move Beat Up (1)...
= 1

Test move Lash Out (1)...
= 1

Test move Brick Break (1)...

- 4 to prefer highest damaging move or first status move
  = 5
  [Switch] -5: to not switch if we don't have a bad matchup.
  i m switchahandler
  i m switchahandler
  i m switchahandler
  Good moves against Gimmighoul: 2
  i m switchahandler
  i m switchahandler
  i m switchahandler
  Good moves against Carvanha: 3
  i m switchahandler
  i m switchahandler
  i m switchahandler
  Good moves against Persian: 3
  i m switchahandler
  i m switchahandler
  i m switchahandler
  Good moves against Gabite: 1
  i m switchahandler
  i m switchahandler
  i m switchahandler
  Good moves against Bibarel: 2
  [Switch] -3: for having no good switch ins
  Good switch ins: 0
  [AI] Switch out Score: -8
  [AI] The AI will not try to switch.
  ==============================
  MOVE(Crawdaunt) Ice Punch: 0

MOVE(Crawdaunt) Beat Up: 0

MOVE(Crawdaunt) Lash Out: 0

# MOVE(Crawdaunt) Brick Break: 5 << CHOSEN

name : Brick Break real dmg: 59

name : Knock Off real dmg: 56

==============================
Bubble Beam => 46

Knock Off => 38

Protect => 0

Night Slash => 44

==============================
Now calcing all moves vs Crawdaunt
==============================
Ice Punch => 23
Beat Up => 22
Lash Out => 21
Brick Break => 60

i have killing move
========== Turn 2 ==========
[AI Threat Assessment: Crawdaunt] -3: for us having fast kill
[AI Threat Assessment: Crawdaunt] +2: for target having slow kill
[AI Threat Assessment: Crawdaunt] +0: to factor in set up
Crawdaunt's threat score against Sneasel => -1
Checking flags...Flags found.
End flag search
Moves for Sneasel against Crawdaunt

Test move Ice Punch (1)...
= 1

Test move Beat Up (1)...
= 1

Test move Lash Out (1)...
= 1

Test move Brick Break (1)...

- 15 for fast kill
  = 16
  ==============================
  MOVE(Crawdaunt) Ice Punch: 0

MOVE(Crawdaunt) Beat Up: 0

MOVE(Crawdaunt) Lash Out: 0

# MOVE(Crawdaunt) Brick Break: 16 << CHOSEN

name : Brick Break real dmg: 31

==============================
Leech Seed => 0

Giga Drain => 30

Growth => 0

Mach Punch => 218

==============================
Now calcing all moves vs Breloom
==============================
Ice Punch => 88
Beat Up => 22
Lash Out => 25
Brick Break => 29

i have killing move
========== Turn 3 ==========
[AI Threat Assessment: Breloom] -3: for us having fast kill
[AI Threat Assessment: Breloom] +2: for target having slow kill
[AI Threat Assessment: Breloom] +0: to factor in set up
Breloom's threat score against Sneasel => -1
Checking flags...
No flags found.
Setting flags...
Offensive Move Count: 2
Priority Move Count: 1
End flag assignment.
Moves for Sneasel against Breloom

Test move Ice Punch (1)...

- 5 because we kill even though they kill us first
  = 16

Test move Beat Up (1)...
= 1

Test move Lash Out (1)...
= 1

Test move Brick Break (1)...
= 1
==============================
MOVE(Breloom) Ice Punch: 16 << CHOSEN

MOVE(Breloom) Beat Up: 0

MOVE(Breloom) Lash Out: 0

# MOVE(Breloom) Brick Break: 0

name : Mach Punch real dmg: 26

==============================
Now determining best switch choice

Scoring for Gimmighoul
+6.0 for slow kill
-1.0 defensive for target having no kills

Scoring for Carvanha
+13.0 for fast kill
-1.0 defensive for target having no kills

Scoring for Persian
+13.0 for fast kill
-1.0 defensive for target having no kills

Scoring for Gabite
-1.0 for having no kill
-1.0 defensive for target having no kills
+1.0 for being faster

Scoring for Bibarel
+13.0 for fast kill
-1.0 defensive for target having no kills
+1.0 for being faster
==============================
Leech Seed => 0

Giga Drain => 59

Growth => 0

Mach Punch => 88

==============================
Now calcing all moves vs Breloom
==============================
Rock Climb => 57
Swords Dance => 0
Aqua Tail => 30
Bulldoze => 14
========== Turn 4 ==========
[AI Threat Assessment: Breloom] -3: for us having fast kill
[AI Threat Assessment: Breloom] -1: for us outspeeding
[AI Threat Assessment: Breloom] +0: to factor in set up
Breloom's threat score against Bibarel => -4
Checking flags...Flags found.
End flag search
Moves for Bibarel against Breloom

Test move Rock Climb (1)...

- 4 to prefer highest damaging move or first status move
  = 5

Test move Swords Dance (4)...
= 4

Test move Aqua Tail (1)...
= 1

Test move Bulldoze (1)...
= 1
[Switch] +3: Grass type matchup
[Switch] +2.0: Target has super effective move
[Switch] -5: to not switch if we don't have a bad matchup.
i m switchahandler
i m switchahandler
Good moves against Gimmighoul: 0
i m switchahandler
i m switchahandler
Good moves against Carvanha: 2
i m switchahandler
i m switchahandler
Good moves against Persian: 1
i m switchahandler
i m switchahandler
Good moves against Gabite: 0
[Switch] +2: for having 2 good switch ins and having a bad matchup
Good switch ins: 2
[AI] Switch out Score: 8.0
[AI] The AI will try to switch.
==============================
Now determining optimal switch choice
-1.0 for having no kill
-1.0 defensive for target having no kills
Offensive score for Gimmighoul: 0.0
Defensive score for Gimmighoul: 0.0
+13.0 for fast kill
-1.0 defensive for target having no kills
Offensive score for Carvanha: 14.0
Defensive score for Carvanha: 0.0
+13.0 for fast kill
-1.0 defensive for target having no kills
Offensive score for Persian: 14.0
Defensive score for Persian: 0.0
-1.0 for having no kill
-1.0 defensive for target having no kills
+1.0 for being faster
Offensive score for Gabite: 1.0
Defensive score for Gabite: 0.0
==============================
Scoring for Persian

- 14.0 for offensive matchup

* 0.0 for defensive matchup
  Starting switch score for Persian => 16.0
  ==============================
  Scoring for Carvanha

- 14.0 for offensive matchup

* 0.0 for defensive matchup
  Starting switch score for Carvanha => 16.0
  ==============================
  Scoring for Gabite

- 1.0 for offensive matchup

* 0.0 for defensive matchup
  Starting switch score for Gabite => 3.0
  ==============================
  Scoring for Gimmighoul

- 0.0 for offensive matchup

* 0.0 for defensive matchup
  Starting switch score for Gimmighoul => 2.0
  [Switch][Persian] + 1 to prevent setup
  [Switch][Persian] + 0 for the matchup score
  [AI]
  Persian => 17.0
  [Switch][Persian] << Chosen Switch In
  ==============================
  SWITCH Persian: 17.0 << CHOSEN

MOVE(Breloom) Rock Climb: 5

MOVE(Breloom) Swords Dance: 0

MOVE(Breloom) Aqua Tail: 0

# MOVE(Breloom) Bulldoze: 0

name : Mach Punch real dmg: 48

==============================
Leech Seed => 0

Giga Drain => 35

Growth => 0

Mach Punch => 139

==============================
Now calcing all moves vs Breloom
==============================
Nasty Plot => 0
Swift => 54
Hidden Power => 159
Water Pulse => 18

i have killing move
========== Turn 5 ==========
[AI Threat Assessment: Breloom] -3: for us having fast kill
[AI Threat Assessment: Breloom] +2: for target having slow kill
[AI Threat Assessment: Breloom] +0: to factor in set up
Breloom's threat score against Persian => -1
Checking flags...Flags found.
End flag search
Moves for Persian against Breloom

Test move Nasty Plot (4)...
Scoring stopped status move since we see a kill

- 20 because a kill is seen and we should prioritize attacking moves
- -16 because we will not be able to get a status move off without dying
  Set score to 1 if less than 1 to prevent going for Struggle
  = 1

Test move Swift (1)...
= 1

Test move Hidden Power (1)...

- 5 because we kill even though they kill us first
  = 16

Test move Water Pulse (1)...
= 1
==============================
MOVE(Breloom) Nasty Plot: 0

MOVE(Breloom) Swift: 0

MOVE(Breloom) Hidden Power: 16 << CHOSEN

# MOVE(Breloom) Water Pulse: 0

name : Mach Punch real dmg: 40

==============================
Now determining best switch choice

Scoring for Gimmighoul
+6.0 for slow kill
-1.0 defensive for target having no kills

Scoring for Carvanha
+13.0 for fast kill
-1.0 defensive for target having no kills

Scoring for Gabite
-1.0 for having no kill
-1.0 defensive for target having no kills
+1.0 for being faster

Scoring for Bibarel
+13.0 for fast kill
-2.0 defensive for target having 2HKO and us having a fast KO
==============================
Leech Seed => 0

Giga Drain => 63

Growth => 0

Mach Punch => 87

==============================
Now calcing all moves vs Breloom
==============================
Rock Climb => 60
Swords Dance => 0
Aqua Tail => 33
Bulldoze => 15
========== Turn 6 ==========
[AI Threat Assessment: Breloom] -1: for us outspeeding
[AI Threat Assessment: Breloom] +0: to factor in set up
Breloom's threat score against Bibarel => -1
Checking flags...Flags found.
End flag search
Moves for Bibarel against Breloom

Test move Rock Climb (1)...

- 4 to prefer highest damaging move or first status move
  = 5

Test move Swords Dance (4)...
= 4

Test move Aqua Tail (1)...
= 1

Test move Bulldoze (1)...
= 1
[Switch] +3: Grass type matchup
[Switch] +2.0: Target has super effective move
[Switch] -5: to not switch if we don't have a bad matchup.
i m switchahandler
i m switchahandler
Good moves against Gimmighoul: 0
i m switchahandler
i m switchahandler
Good moves against Carvanha: 2
i m switchahandler
i m switchahandler
Good moves against Gabite: 0
[Switch] +2: for having 2 good switch ins and having a bad matchup
Good switch ins: 2
[AI] Switch out Score: 8.0
[AI] The AI will try to switch.
==============================
Now determining optimal switch choice
-1.0 for having no kill
-1.0 defensive for target having no kills
Offensive score for Gimmighoul: 0.0
Defensive score for Gimmighoul: 0.0
+13.0 for fast kill
-1.0 defensive for target having no kills
Offensive score for Carvanha: 14.0
Defensive score for Carvanha: 0.0
-1.0 for having no kill
-1.0 defensive for target having no kills
+1.0 for being faster
Offensive score for Gabite: 1.0
Defensive score for Gabite: 0.0
==============================
Scoring for Carvanha

- 14.0 for offensive matchup

* 0.0 for defensive matchup
  Starting switch score for Carvanha => 16.0
  ==============================
  Scoring for Gabite

- 1.0 for offensive matchup

* 0.0 for defensive matchup
  Starting switch score for Gabite => 3.0
  ==============================
  Scoring for Gimmighoul

- 0.0 for offensive matchup

* 0.0 for defensive matchup
  Starting switch score for Gimmighoul => 2.0
  [Switch][Carvanha] + 1 to prevent setup
  [Switch][Carvanha] + 0 for the matchup score
  [Switch][Carvanha] -0 to prevent switching into a super effective move
  [Switch][Carvanha] -0 to prevent switching into a super effective move
  [Switch][Carvanha] -0 to prevent switching into a super effective move
  [Switch][Carvanha] -0 to prevent switching into a super effective move
  [AI]
  Carvanha => 0
  [AI]
  Carvanha removed from switch choices
  [Switch][Gabite] + 1 to prevent setup
  [Switch][Gabite] + 0 for the matchup score
  [AI]
  Gabite => 4.0
  [AI]
  Gabite removed from switch choices
  [Switch][Gimmighoul] + 1 to prevent setup
  [Switch][Gimmighoul] + 0 for the matchup score
  [AI]
  Gimmighoul => 3.0
  [AI]
  Gimmighoul removed from switch choices
  ==============================
  MOVE(Breloom) Rock Climb: 5 << CHOSEN

MOVE(Breloom) Swords Dance: 0

MOVE(Breloom) Aqua Tail: 0

# MOVE(Breloom) Bulldoze: 0

name : Mach Punch real dmg: 89

name : Rock Climb real dmg: 59

# Bibarel's ability was revealed.

Leech Seed => 0

Giga Drain => 99

Growth => 0

Mach Punch => 86

==============================
Now calcing all moves vs Breloom
==============================
Rock Climb => 56
Swords Dance => 0
Aqua Tail => 30
Bulldoze => 15

i have killing move
========== Turn 7 ==========
[AI Threat Assessment: Breloom] -3: for us having fast kill
[AI Threat Assessment: Breloom] +2: for target having slow kill
[AI Threat Assessment: Breloom] +0: to factor in set up
Breloom's threat score against Bibarel => -1
Checking flags...Flags found.
End flag search
Moves for Bibarel against Breloom

Test move Rock Climb (1)...

- 5 because we kill even though they kill us first
  = 16

Test move Swords Dance (4)...
Scoring stopped status move since we see a kill

- 20 because a kill is seen and we should prioritize attacking moves
- -16 because we will not be able to get a status move off without dying
  Set score to 1 if less than 1 to prevent going for Struggle
  = 1

Test move Aqua Tail (1)...

- 5 because we kill even though they kill us first
  = 16

Test move Bulldoze (1)...

- 5 because we kill even though they kill us first
  = 16
  ==============================
  MOVE(Breloom) Rock Climb: 0

MOVE(Breloom) Swords Dance: 0

MOVE(Breloom) Aqua Tail: 0

# MOVE(Breloom) Bulldoze: 16 << CHOSEN

name : Mach Punch real dmg: 28

==============================
Now determining best switch choice

Scoring for Gimmighoul
+6.0 for slow kill
-1.0 defensive for target having no kills

Scoring for Carvanha
+13.0 for fast kill
-1.0 defensive for target having no kills

Scoring for Gabite
+13.0 for fast kill
-1.0 defensive for target having no kills
[ALSOFT] (EE) Failed to get padding: 0x88890004
