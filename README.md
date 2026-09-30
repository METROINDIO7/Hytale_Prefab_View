# Hytale Prefab Viewer

[![Godot 4](https://img.shields.io/badge/Godot-4.x-blue.svg)](https://godotengine.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A lightweight, scale-accurate **3D prefab editor and viewer** made specifically for the Hytale modding community.

Plan, build, and visualize your structures with real Hytale blocks before importing them into the game.

**Free and open source** — use it, modify it, share it.



## ✨ Features

- **Real-time 3D block editing** (Paint, Erase, Select tools)
- Multiple **brush planes**: Horizontal (XZ), Vertical X, Vertical Z
- **Mirror / Symmetry** — paint on X, Y, Z axes with configurable center offset
- **Group system** to organize large builds
- **Reference Cameras** + image overlay support (perfect for tracing concepts)
- **Axis Gizmo** in the corner showing camera orientation
- **Occlusion culling** for better performance with big structures
- **Undo / Redo** support
- Searchable block palette organized by categories (Rock, Wood, Planks, Metal, Glass, etc.)
- **Custom model support** — imports `.blockymodel` files with correct UVs, rotation, and transparency
- Import / Export `.prefab.json` files
- Save / Load complete projects (`.hvproj.json`)



## 📦 Importing Assets

To use the full block palette, you need to import Hytale's `Assets.zip`:

1. Open the application
2. Go to **File → Import Assets** (or press **Ctrl + I**)
3. Select your `Assets.zip` file from Hytale's installation directory
4. Wait for the import to finish — on first import it extracts icons, textures, and models to disk
5. The block palette will populate automatically

**Re-importing:** If you update your `Assets.zip`, simply import again — textures and models will be updated.

**Note:** The first import may take a while depending on the number of blocks. Subsequent imports use a cached index and are significantly faster.



## 🕹️ Controls

- **WASD / Arrows** – Move camera
- **Q / E** – Move up / down
- **Mouse Wheel** – Zoom
- **Middle Mouse Drag** – Pan
- **Right Mouse Drag** – Orbit
- **Left Click** – Paint / Erase / Select (depending on tool)
- **Ctrl + Shift + X** – Toggle Mirror (all axes)

Full controls available in the in-app **Help → Controls** menu.



## 🔧 Mirror / Symmetry

The mirror tool lets you paint symmetrically across one or more axes:

- Toggle **X**, **Y**, **Z** buttons in the left panel to enable mirroring
- Combine axes for multi-way symmetry (e.g., X + Z = 4-way)
- Use the **Center** offset fields to move the mirror plane away from the origin (0, 0, 0)
- Works with Paint, Erase, and Selection tools



## 🚀 Planned Features

- More block categories and variants
- Improved selection tools (hollow shapes, patterns)
- Better export options
- Theme switcher (Dark/Light)
- Multi-language support

---

**Made for the Hytale modding community** — Feedback and suggestions are welcome!
