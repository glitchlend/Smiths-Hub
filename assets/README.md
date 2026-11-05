Smith's Hub

A custom utility hub for Young Street, Ontario (YSO) on Roblox.

Smith's Hub includes vehicle performance modifications, Halloween candy tools, a custom GUI and an animated loading screen.

Features

🚗 Movement

Acceleration Boost

- Adjustable acceleration multiplier from 1× to 5×.
- Increases engine power while retaining normal gear shifting and RPM behaviour.
- Automatically detects compatible A-Chassis vehicles.

Gear Speed Boost

- Adjustable gear speed multiplier from 1× to 5×.
- Increases the maximum speed of every forward gear.
- Preserves the vehicle's original gear spacing.
- Works alongside the Acceleration Boost.

Both settings operate automatically while driving. No activation key is required.

🍬 Auto Farm

Candy ESP

- Detects Halloween candies within the game's streaming distance.
- Displays markers showing discovered candy locations.
- Remembers discovered locations as saved markers when they are no longer streamed.
- Separately displays the number of visible and saved candies.

Auto Claw

- Automatically plays the Halloween candy claw minigame.
- Uses timing and alignment detection to attempt each claw.
- Includes recovery handling for missed attempts.

Auto Collect

- Automatically teleports between previously discovered candies.
- Supports both currently visible candies and saved markers.
- Attempts to activate each candy's collection prompt.
- Uses Auto Claw to complete the minigame.
- Waits for the claw interface to close, then waits an additional 2 seconds before collecting the next candy.
- Includes retry handling for unavailable candies.

⚠ StreamingEnabled Notice

Due to Roblox's StreamingEnabled system, candies must be loaded within your streaming distance before they can be detected.

You must first travel close enough to the candies for ESP to discover them. Auto Collect can then use their visible or saved markers.

Auto Collect does not automatically search unexplored areas of the map.

Discovered markers are retained for the current script session only.

🎨 Interface

Smith's Hub features:

- A horizontal, two-tab GUI.
- Movement and Auto Farm sections.
- Adjustable performance sliders.
- Individual Auto Farm toggles.
- A draggable and minimisable window.
- Animated RGB borders.
- A custom Smith's Hub logo.
- A three-second startup animation displaying "Welcome to Smith's Hub".

The logo is automatically retrieved from GitHub through a temporary file, which the script attempts to delete after loading.

🚀 Installation

Run the following code in a compatible Roblox Lua executor:

loadstring(game:HttpGet("https://raw.githubusercontent.com/glitchlend/Smiths-Hub/main/SmithsHub.lua"))()

The loader retrieves the latest committed version of Smith's Hub from this repository's main branch.

Compatibility

Game: Young Street, Ontario (YSO)

Executor: Requires support for the relevant Lua executor APIs.

Vehicle performance modifications require compatible A-Chassis vehicles.

The Auto Farm tools depend on the game's Halloween event objects, StreamingEnabled behaviour and available executor functions.

Features may stop functioning following game updates, and successful collection is not guaranteed.

Disclaimer

Smith's Hub is an unofficial community-created script and is not affiliated with Roblox or the developers of Young Street, Ontario.

Using third-party executors or modifications may violate game rules or Roblox's terms of use and could result in account penalties.

Developer

glitchlend

GitHub: https://github.com/glitchlend/Smiths-Hub

---

Smith's Hub — Vehicle Performance & Candy Automation
