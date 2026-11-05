<p align="center">
  <img src="https://raw.githubusercontent.com/glitchlend/Smiths-Hub/main/assets/logo.png" width="180" alt="Smith's Hub logo">
</p>

<h1 align="center">Smith's Hub</h1>

<p align="center">
  One loader. Two games.
  <br>
  Young Street, Ontario • Twisted
</p>

## 🚀 Getting started

Run this in your executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/glitchlend/Smiths-Hub/main/loader.lua"))()
```

Choose **YSO** or **Twisted** from the menu.

Join the matching game first. The selector loads its script; it does not teleport you.

## 🚗 Young Street, Ontario

### Movement
- Adjustable acceleration and gear speed boosts.
- Automatic detection of compatible A-Chassis vehicles.
- Retains normal steering and gear shifting.
- Applies your selected settings while driving.

### Candy tools
- **Candy ESP:** marks discovered Halloween candies.
- **Saved markers:** remembers discovered locations during the script session.
- **Auto Claw:** attempts the candy claw minigame automatically.
- **Auto Collect:** travels between discovered candies and attempts collection.

Candies must enter your streaming distance before they can be discovered. Auto Collect does not search unexplored areas.

Candy features depend on the game's Halloween event and available objects.

### Interface
- Movement and Auto Farm tabs.
- Adjustable sliders and individual toggles.
- Draggable, minimisable GUI.
- Animated RGB borders and custom logo.
- Animated welcome screen.

## 🌪️ Twisted

### Tornado tracking
- **Tornado info / ESP:** storm ID, ground status, estimated EF category, width, wind, travel speed and distance.
- **Tornado chams:** highlights detected tornado meshes.
- **Previous path:** shows the recorded path.
- **Predicted path:** estimates the heading from recent movement.
- **Storm selection:** select or deselect individual storms, or use Select all / Deselect all.
- **Units:** switch between metric and imperial.
- **Fullbright:** improves visibility and restores captured lighting settings when disabled or unloaded.

### Interface
- Draggable menu.
- Separate draggable minimised icon.
- Icon appears only while the menu is minimised.
- Menu and icon retain independent positions.
- Feature toggles start OFF.

### Measurement notes
Values marked `~` use unverified game-scale assumptions.

Distance is horizontal distance to the storm, excluding height differences. EF categories are estimates based on wind values. Predicted paths show an estimated heading, not a guaranteed future track.

## 🎨 Loader

- Custom Smith's Hub logo.
- Animated opening.
- YSO and Twisted selection buttons.
- Download and startup status.
- Console error details if a script fails to load.

The loader fetches the selected script from this repository's `main` branch. GitHub caching can briefly delay newly committed updates.

## 📁 Repository layout

```text
Smiths-Hub/
├── README.md
├── loader.lua
├── games/
│   ├── yso.lua
│   └── twisted.lua
└── assets/
    └── logo.png
```

## Compatibility

Requires an executor supporting the APIs used by each script.

Custom logos require local file-writing and asset-loading support. The loader displays an S fallback if its logo cannot load.

Vehicle boosts require compatible A-Chassis vehicles. Game updates may affect individual features.

## Developer

**glitchlend**

[GitHub repository](https://github.com/glitchlend/Smiths-Hub)

Smith's Hub is an unofficial project and is not affiliated with Roblox or either game's developers.
