# Smith's Hub

A custom Roblox utility hub for **Young Street, Ontario (YSO)**, featuring movement controls, vehicle performance tuning and Halloween candy tools.

## Features

### Movement
- **WalkSpeed:** Adjust your character's walking speed.
- **JumpPower:** Adjust your character's jumping power.
- **Acceleration Boost:** Increase vehicle acceleration from 1× to 5×.
- **Gear Speed Boost:** Increase maximum speed within each forward gear from 1× to 5×.
- Automatically detects compatible A-Chassis vehicles and reads their individual settings.
- Preserves normal steering, braking, gear shifting and engine redline behaviour where supported.

### Auto Farm
- **Candy ESP:** Displays markers for discovered candies.
- **Auto Claw:** Automatically attempts the Halloween claw minigame.
- **Auto Collect:** Teleports to previously discovered and saved candy markers to attempt collection.
- No automatic map searching or discovery sweeps.
- Discovered markers are stored for the current script session.

## Installation

Run the following in a compatible Roblox Lua executor:

`loadstring(game:HttpGet("https://raw.githubusercontent.com/glitchlend/Smiths-Hub/main/SmithsHub.lua"))()`

Requires an executor supporting the script's relevant APIs.

## Interface

Smith's Hub includes two tabs:

**Movement** — Character movement and vehicle performance settings.

**Auto Farm** — Candy ESP, Auto Claw and Auto Collect.

The interface includes a draggable window, a minimised icon and an animated RGB border.

## Custom Logo

The hub automatically retrieves its logo from this repository. It uses a temporary local file to register the image, then attempts to delete that temporary file after loading.

The user does not need to manually install the logo.

## Compatibility

Designed for Roblox Young Street, Ontario, including supported A-Chassis vehicles.

Some features depend on executor capabilities, game updates, client physics and vehicle configurations. Functionality is not guaranteed across all executors or vehicles.

## Disclaimer

Unofficial community-created script. Not affiliated with Roblox or the developers of Young Street, Ontario.

Using third-party scripts may violate the game's rules or Roblox's terms and can result in account penalties.

## Credits

Developed by **glitchlend**.

GitHub: https://github.com/glitchlend/Smiths-Hub
