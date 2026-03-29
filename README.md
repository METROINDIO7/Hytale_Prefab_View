# Hytale Prefab Viewer

[![Godot 4](https://img.shields.io/badge/Godot-4.x-blue.svg)](https://godotengine.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A lightweight, scale-accurate **3D prefab editor and viewer** made specifically for the Hytale modding community.

Plan, build, and visualize your structures with real Hytale blocks before importing them into the game.



## ✨ Features

- **Real-time 3D block editing** (Paint, Erase, Select tools)
- Multiple **brush planes**: Horizontal (XZ), Vertical X, Vertical Z
- **Group system** to organize large builds
- **Reference Cameras** + image overlay support (perfect for tracing concepts)
- **Axis Gizmo** in the corner showing camera orientation
- **Occlusion culling** for better performance with big structures
- **Undo / Redo** support
- Searchable block palette organized by categories (Rock, Wood, Planks, Metal, Glass, etc.)
- Import / Export `.prefab.json` files
- Save / Load complete projects (`.hvproj.json`)

## Screenshots

*(Add 4–6 screenshots here)*

## How to Use

1. Download the latest release (Windows / Linux / macOS)
2. Run the executable
3. Start building from scratch or **import** a `.prefab.json` file
4. Use the bottom palette to select blocks
5. Right panel for Groups and Reference Cameras
6. Press **F1** or go to **Help → Controls** for full keyboard shortcuts

## Controls (Quick Reference)

- **WASD / Arrows** – Move camera
- **Q / E** – Move up / down
- **Mouse Wheel** – Zoom
- **Middle Mouse Drag** – Pan
- **Right Mouse Drag** – Orbit
- **Left Click** – Paint / Erase / Select (depending on tool)

Full controls available in the in-app Help menu.

## Planned Features

- More block categories and variants
- Improved selection tools (hollow shapes, patterns)
- Better export options
- Theme switcher (Dark/Light)
- Multi-language support

## Building from Source

```bash
git clone https://github.com/yourusername/hytale-prefab-viewer.git
cd hytale-prefab-viewer
# Open the project in Godot 4.3 or newer
