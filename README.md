# Hytale Prefab Viewer — Godot 4

Herramienta de planificación a escala para estructuras de Hytale.  
Importa archivos `.prefab.json` y los visualiza en un entorno 3D con cámaras de referencia e imágenes semitransparentes superpuestas.

---

## Requisitos

| Requisito         | Versión mínima |
|-------------------|----------------|
| Godot Engine      | **4.1** o superior |
| Sistema operativo | Windows / macOS / Linux |

---

## Instalación

1. Abre **Godot 4**.
2. En el Project Manager, haz clic en **Import**.
3. Navega a la carpeta `hytale_prefab_viewer/` y selecciona `project.godot`.
4. Haz clic en **Import & Edit** → luego **▶ Play** para ejecutar.

---

## Cómo usar

### 1. Cargar un prefab
- Clic en **"Cargar .prefab.json"** en el panel izquierdo.
- Navega al archivo `.prefab.json` exportado desde Hytale.
- La estructura aparece centrada en la cuadrícula.

### 2. Navegar la vista aérea
| Acción                        | Control                         |
|-------------------------------|---------------------------------|
| Mover cámara                  | `WASD` / teclas de flecha       |
| Zoom                          | Rueda del mouse                 |
| Paneo libre                   | Botón medio del mouse + arrastrar |
| Orbitar (rotar alrededor)     | Botón derecho del mouse + arrastrar |

### 3. Cámaras de referencia
- Coloca la **vista aérea** en la perspectiva que quieres guardar.
- Clic **"+ Añadir cámara"** → se crea una cámara con esa pose exacta.
- Usa el **selector de vista** para cambiar entre la cámara aérea y tus cámaras de referencia.

### 4. Imagen de referencia (overlay semitransparente)
- Selecciona una cámara de referencia haciendo clic en **"Seleccionar"**.
- Clic **"Cargar imagen para cámara activa"** → elige un PNG/JPG.
- La imagen aparece como overlay semitransparente cuando esa cámara está activa.
- Ajusta la **opacidad** con el slider (0 % = invisible, 100 % = opaco).

### 5. Verificar escala
- Alterna entre cámaras para comparar tu prefab con la imagen de referencia.
- Mueve bloques en Hytale hasta que coincidan visualmente con tu boceto.

---

## Estructura del proyecto

```
hytale_prefab_viewer/
├── project.godot               ← Configuración del proyecto Godot
├── scenes/
│   └── main.tscn               ← Escena principal (delega todo a main.gd)
└── scripts/
    ├── main.gd                 ← Controlador principal + construcción de UI
    ├── prefab_loader.gd        ← Parseo de archivos .prefab.json
    ├── block_renderer.gd       ← Renderizado 3D con MultiMesh (eficiente)
    ├── camera_controller.gd    ← Gestión de cámara aérea y cámaras de referencia
    └── reference_manager.gd    ← Overlays de imagen semitransparentes
```

---

## Formato de Prefab soportado

Compatible con el formato estándar de Hytale:

```json
{
  "version": 8,
  "blockIdVersion": 11,
  "anchorX": 0, "anchorY": 0, "anchorZ": 0,
  "blocks": [
    { "x": 0, "y": 0, "z": 0, "name": "Rock_Sandstone_Brick_Pillar_Middle" },
    { "x": 1, "y": 0, "z": 0, "name": "Rock_Sandstone_White_Brick", "rotation": 2 }
  ],
  "fluids": [ ... ]
}
```

**Campos leídos:** `blocks[].x/y/z`, `blocks[].name`, `blocks[].rotation`.  
Los fluidos (`fluids`) se ignoran actualmente (solo se muestran sólidos).

---

## Sistema de colores

Los bloques se colorean automáticamente por categoría según su nombre:

| Categoría      | Color aproximado       |
|----------------|------------------------|
| `Roof`         | Terracota oscuro        |
| `Sandstone`    | Arena cálida            |
| `Cobble`       | Gris medio              |
| `Wood / Plank` | Marrón cálido           |
| `Grass`        | Verde                   |
| `Sand`         | Arena clara             |
| `Stone / Rock` | Gris azulado            |
| `Water`        | Azul semitransparente   |
| `Ice / Glass`  | Azul hielo transparente |
| `Gold`         | Amarillo dorado         |
| Desconocido    | Color por hash del nombre |

---

## Rendimiento y Occlusion Culling

- Los bloques se renderizan usando **`MultiMeshInstance3D`** agrupado por color, reduciendo drásticamente los draw calls.
- El **SubViewport** tiene `use_occlusion_culling = true` activado.
- Godot 4 realiza **frustum culling** automáticamente sobre los MultiMesh.
- Prefabs de hasta ~50 000 bloques deberían funcionar con fluidez.

---

## Limitaciones actuales

- Los bloques se muestran como cubos coloreados (sin meshes originales de Hytale).
- Las texturas reales de Hytale no están incluidas (son propiedad de Hypixel Studios).
- Los fluidos no se renderizan todavía.
- No hay exportación de vuelta a `.prefab.json`.

---

## Licencia

Proyecto de uso personal / herramienta de ayuda. No afiliado a Hypixel Studios ni a Hytale.
