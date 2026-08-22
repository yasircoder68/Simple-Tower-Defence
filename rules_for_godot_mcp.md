# Rules for Godot MCP — Complete AI Reference

> A comprehensive guide for AI agents on how to **connect**, **configure**, and **use** the Godot MCP Toolkit with a Godot 4 project.

---

## 1. What is the Godot MCP Toolkit?

The Godot MCP Toolkit is a **Model Context Protocol** server that gives AI agents direct, programmatic access to the Godot 4 editor and running game. Instead of guessing file contents or manually writing `.tscn` files, the AI calls MCP tools to:

- Create and inspect scenes and nodes
- Read, write, and edit scripts
- Set properties, connect signals
- Start/stop playtests, take screenshots, simulate input
- Manage project settings, autoloads, and more

---

## 2. How to Connect the Plugin (Setup)

### Step 1 — Install the Addon

Copy the `addons/godot_mcp_toolkit/` folder into your new project's `addons/` directory. You can copy it from an existing project or install it from the Godot Asset Library.

```
your-new-game/
├── addons/
│   └── godot_mcp_toolkit/   ← copy this entire folder
├── project.godot
└── ...
```

### Step 2 — Enable the Plugin in Godot

1. Open the project in the **Godot 4 Editor**.
2. Go to **Project → Project Settings → Plugins** tab.
3. Find **"Godot MCP Toolkit"** and check **Enable**.

This automatically:
- Registers the plugin in `project.godot` under `[editor_plugins]`
- Adds the `MCPRuntimeServer` autoload (needed for runtime/playtest tools)

Your `project.godot` will now contain:

```ini
[editor_plugins]
enabled=PackedStringArray("res://addons/godot_mcp_toolkit/plugin.cfg")

[autoload]
MCPRuntimeServer="*res://addons/godot_mcp_toolkit/runtime/mcp_runtime_server.gd"
```

### Step 3 — Generate `.mcp.json`

In the Godot Editor top menu bar:

**Project → Tools → MCP Toolkit → Write .mcp.json**

This creates a `.mcp.json` file in the project root that tells the AI how to launch the MCP server:

```json
{
  "mcpServers": {
    "godot-mcp-toolkit": {
      "args": ["/c", "npx", "-y", "@npgamedev/godot-mcp-server"],
      "command": "cmd",
      "env": {
        "GODOT_MCP_CONFIG_VERSION": "1"
      }
    }
  }
}
```

> [!IMPORTANT]
> This requires **Node.js / npm** to be installed on the system. The `npx` command auto-downloads and runs the MCP server package.

### Step 4 — Verify Connection

The AI agent should be able to call `discover_tools` successfully. If it works, the connection is live.

---

## 3. Core Principles — How the AI Should Use MCP

### Golden Rules

1. **Never guess — always inspect first.**
   - Call `scene_get_tree` before modifying any scene.
   - Call `script_read` before editing any script.

2. **Use MCP tools instead of raw file writes for scenes.**
   - Don't hand-write `.tscn` files. Use `scene_create`, `scene_create_node`, `node_set_property`, etc.
   - Scripts (`.gd`) can be written via `script_write` or `script_edit`.

3. **Validate after every change.**
   - Run `script_check` or `lsp_project_diagnostics` after writing/editing scripts.
   - Use `editor_save_scene` to persist scene changes.

4. **Use `discover_tools` to find advanced tools.**
   - Not all tools are loaded by default. Call `discover_tools` with a keyword (e.g. `"tilemap"`, `"particles"`, `"3d"`) to activate tool groups on demand.

5. **Save scenes explicitly.**
   - After creating nodes, setting properties, or connecting signals, call `editor_save_scene`.

---

## 4. Complete Tool Reference

### 4.1 — Scene Management

| Tool | Purpose |
|------|---------|
| `scene_create` | Create a new `.tscn` file with a root node |
| `scene_open` | Open an existing scene for editing |
| `editor_save_scene` | Save the currently edited scene (optional save-as path) |
| `scene_get_tree` | Get the node tree as JSON (set `max_depth: -1` for full tree) |
| `scene_query` | Search nodes by class, group, name glob, or property conditions |
| `scene_spatial_map` | Get spatial layout, positions, bounds, overlaps of nodes |

**Example — Create a scene and inspect it:**
```
1. scene_create(file_path: "res://scenes/Player.tscn", root_type: "CharacterBody2D")
2. scene_open(file_path: "res://scenes/Player.tscn")
3. scene_get_tree(max_depth: -1)
```

---

### 4.2 — Node Creation & Hierarchy

| Tool | Purpose |
|------|---------|
| `scene_create_node` | Add a child node under a parent path |
| `scene_delete_node` | Delete a node (cannot delete scene root) |
| `node_manage` | Rename, reparent, reorder, or duplicate nodes |
| `node_groups` | Add/remove/list group membership on nodes |
| `node_set_script` | Attach or detach a `.gd` script on a node |

**Example — Build a player scene:**
```
1. scene_create_node(class_name: "Sprite2D", parent_path: ".", node_name: "PlayerSprite")
2. scene_create_node(class_name: "CollisionShape2D", parent_path: ".", node_name: "Hitbox")
3. node_set_script(node_path: ".", script_path: "res://scripts/player.gd")
4. editor_save_scene()
```

**`scene_create_node` supports setting initial properties inline:**
```
scene_create_node(
  class_name: "Camera2D",
  parent_path: ".",
  node_name: "PlayerCamera",
  properties: { "zoom": { "__type": "Vector2", "x": 2, "y": 2 } }
)
```

---

### 4.3 — Node Properties

| Tool | Purpose |
|------|---------|
| `node_get_property` | Read a single property value from a node |
| `node_set_property` | Set a property (supports type wrappers and batch mode) |
| `node_get_property_list` | List all properties on a node (filterable) |
| `control_set_layout` | Set anchor preset + margins on Control nodes |

**Type Wrappers** — For complex types, use wrappers in the `value` field:
```json
{ "__type": "Vector2", "x": 100, "y": 200 }
{ "__type": "Color", "r": 1, "g": 0, "b": 0, "a": 1 }
{ "__type": "Resource", "path": "res://assets/texture.png" }
{ "__type": "NewResource", "class": "RectangleShape2D", "properties": { "size": { "__type": "Vector2", "x": 32, "y": 32 } } }
{ "__type": "LayerMask", "bits": [1, 3, 5] }
```

**Batch mode** — Set multiple properties at once:
```
node_set_property(batch: [
  { node_path: "PlayerSprite", property: "position", value: { "__type": "Vector2", "x": 0, "y": -16 } },
  { node_path: "PlayerSprite", property: "scale", value: { "__type": "Vector2", "x": 2, "y": 2 } }
])
```

---

### 4.4 — Signals

| Tool | Purpose |
|------|---------|
| `signal_list` | List signals on a node, optionally with connections |
| `signal_manage` | Connect or disconnect signals (persisted to `.tscn`) |

**Example — Connect a button signal:**
```
signal_manage(
  action: "connect",
  node_path: "StartButton",
  signal_name: "pressed",
  target_path: ".",
  method_name: "_on_start_button_pressed"
)
```

---

### 4.5 — Scripts & Code

| Tool | Purpose |
|------|---------|
| `script_read` | Read script contents (supports pagination with `start_line`/`end_line`) |
| `script_write` | Write or overwrite an entire script file. Returns diagnostics. |
| `script_edit` | Surgically replace an exact substring in a script (for targeted edits) |
| `script_check` | Validate a `.gd` file for syntax errors |

**Best practice workflow:**
```
1. script_read(file_path: "res://scripts/player.gd")        ← read first
2. script_edit(file_path: "...", old_string: "...", new_string: "...")  ← targeted edit
3. script_check(file_path: "res://scripts/player.gd")        ← validate
```

> [!WARNING]
> Always use `script_read` before `script_edit` so you know the exact text to match. The `old_string` must be a **byte-for-byte exact match**.

---

### 4.6 — Playtesting & Runtime

| Tool | Purpose |
|------|---------|
| `game_start` | Start a playtest (blocks until runtime connects by default) |
| `game_stop` | Stop the running game |
| `runtime_screenshot` | Capture a screenshot of the running game |
| `runtime_get_script_vars` | Read live variable values from a node in the running game |
| `execute_code` | Evaluate GDScript in the running game or editor |
| `input_simulate` | Inject keyboard, mouse, or action input into the running game |

**Example — Playtest workflow:**
```
1. game_start(scene_path: "main")
2. runtime_screenshot()                    ← see what's happening
3. input_simulate(events: { event_type: "key", event_data: { keycode: "W", pressed: true } })
4. runtime_screenshot()                    ← verify result
5. game_stop()
```

**Input event types:**
- `key` — keyboard key press/release
- `mouse_button` — mouse click
- `mouse_motion` — mouse movement
- `action` — Godot input action (e.g. `"ui_accept"`)
- `click` — click at screen coordinates
- `click_node` — click on a specific node by path
- `send_text` — type text into a focused input

---

### 4.7 — Debugging & Logs

| Tool | Purpose |
|------|---------|
| `editor_get_console` | Read editor output console (filter by level, text, regex) |
| `debugger_get_log` | Read game runtime log (during play and post-crash) |

**Example — Check for errors after running:**
```
editor_get_console(level_filter: "error")
debugger_get_log(text_filter: "ERROR")
```

---

### 4.8 — Project Settings & Autoloads

| Tool | Purpose |
|------|---------|
| `project_get_settings` | List project settings (filter by prefix) |
| `project_set_setting` | Update and persist a project setting |
| `autoload_manage` | Register, unregister, or list autoload singletons |
| `folder_create` | Create a directory (recursive, idempotent) |

**Example — Set up project basics:**
```
1. project_set_setting(setting: "application/config/name", value: "My New Game")
2. project_set_setting(setting: "display/window/size/viewport_width", value: 1280)
3. folder_create(path: "res://scenes")
4. folder_create(path: "res://scripts")
5. folder_create(path: "res://assets/sprites")
```

---

### 4.9 — On-Demand Tool Groups (via `discover_tools`)

These tools are **not loaded by default**. Call `discover_tools(request: "group_name")` to activate them.

| Group | Tools | Purpose |
|-------|-------|---------|
| `runtime_advanced` | `runtime_get_node_state`, `runtime_set_property`, `animation_player_control` | Live node inspection, runtime property changes, animation control |
| `animation_authoring` | `animation_keyframe`, `animation_get_keys`, `animationtree_edit`, `animationtree_list` | Create/edit keyframes, animation trees |
| `input_map` | `input_map_action`, `input_map_event` | Create/edit input actions and key bindings |
| `resource_io` | `resource_load`, `resource_write` | Load/write `.tres`/`.res` files |
| `asset_ops` | `asset_list`, `asset_get_dependencies`, `asset_import` | List assets, query dependencies, import files |
| `placeholders` | `texture_generate`, `sound_generate` | Generate placeholder textures and sounds |
| `cleanup` | `file_delete`, `scene_delete`, `script_delete`, `resource_delete`, `folder_delete` | Delete files, scenes, scripts, resources, folders |
| `user_data` | `save_read`, `save_write`, `save_delete`, `save_list` | Read/write/list `user://` save files |
| `scene_advanced` | `scene_diff`, `scene_instantiate` | Diff scenes, batch-instantiate packed scenes |
| `editor_advanced` | `editor_screenshot`, `editor_refresh`, `editor_wait_for_idle` | Editor screenshots, filesystem refresh |
| `tilemap` | `tilemap_read_cells`, `tilemap_set_cells` | Read/paint tilemap cells |
| `tileset` | `tileset_create`, `tileset_add_source`, etc. | Create and configure TileSet resources |
| `tileset_edit` | `tileset_edit_physics`, `tileset_edit_terrain`, etc. | Edit per-tile properties |
| `theme` | `theme_edit` | Edit UI theme overrides |
| `layer_naming` | `layer_names_set`, `layer_names_get` | Physics/render/navigation layer names |
| `path_editing` | `path2d_edit_curve`, `collision_from_texture` | Edit curves, generate collision from sprites |
| `3d_tools` | `3d_create_primitive`, `3d_setup_environment`, `3d_create_light`, `3d_create_camera` | 3D primitives, lights, cameras, environments |
| `procedural` | `procedural_edit_gradient`, `procedural_edit_curve`, `procedural_edit_noise` | Gradients, curves, noise for procedural generation |
| `scene_inheritance` | `scene_create_inherited` | Create inherited/variant scenes |
| `audio` | `audiobus_edit`, `audiobus_list` | Audio bus configuration |
| `spriteframes` | `spriteframes_create`, `spriteframes_edit`, `spriteframes_from_spritesheet` | SpriteFrames animations |
| `particles` | `particles_create` | GPU particle systems |
| `navigation` | `navigation_edit` | Navigation regions, meshes, obstacles |
| `lsp_code_analysis` | `lsp_diagnostics`, `lsp_symbols`, `lsp_hover`, `lsp_project_diagnostics` | GDScript diagnostics, symbols, project-wide checks |
| `lsp_code_navigation` | `lsp_completion`, `lsp_definition`, `lsp_references` | Code completion, go-to-definition, find references |
| `debugger` | `debug_state`, `debug_list_breakpoints`, `debug_set_breakpoint`, `debug_continue` | Breakpoints, debugger state, execution control |
| `classdb` | `classdb_get_info`, `classdb_search` | Search Godot class hierarchy |
| `signals` | `signal_emit` | Emit signals at editor-time or runtime |

---

## 5. Common Workflows

### Creating a New Scene from Scratch

```
1. folder_create(path: "res://scenes")
2. scene_create(file_path: "res://scenes/Player.tscn", root_type: "CharacterBody2D")
3. scene_open(file_path: "res://scenes/Player.tscn")
4. scene_create_node(class_name: "Sprite2D", parent_path: ".", node_name: "PlayerSprite")
5. scene_create_node(class_name: "CollisionShape2D", parent_path: ".", node_name: "Hitbox")
6. node_set_property(node_path: "Hitbox", property: "shape",
     value: { "__type": "NewResource", "class": "RectangleShape2D",
              "properties": { "size": { "__type": "Vector2", "x": 32, "y": 64 } } })
7. script_write(file_path: "res://scripts/player.gd", content: "extends CharacterBody2D\n...")
8. node_set_script(node_path: ".", script_path: "res://scripts/player.gd")
9. editor_save_scene()
```

### Debugging a Crash

```
1. game_start(scene_path: "main")
   ← game crashes
2. debugger_get_log(text_filter: "ERROR")
3. editor_get_console(level_filter: "error")
4. script_read(file_path: "res://scripts/problem_script.gd")
   ← identify the bug
5. script_edit(file_path: "...", old_string: "...", new_string: "...")
6. script_check(file_path: "res://scripts/problem_script.gd")
7. game_start()    ← re-test
```

### Adding UI Elements

```
1. scene_create(file_path: "res://scenes/HUD.tscn", root_type: "CanvasLayer")
2. scene_open(file_path: "res://scenes/HUD.tscn")
3. scene_create_node(class_name: "Label", parent_path: ".", node_name: "ScoreLabel")
4. control_set_layout(node_path: "ScoreLabel", preset: "PRESET_TOP_LEFT", margins: { left: 20, top: 10 })
5. node_set_property(node_path: "ScoreLabel", property: "text", value: "Score: 0")
6. editor_save_scene()
```

### Validating the Entire Project

```
1. discover_tools(request: "lsp_code_analysis")
2. lsp_project_diagnostics()
```

---

## 6. Tips & Gotchas

> [!TIP]
> **Type wrappers are essential.** When setting `Vector2`, `Color`, `Resource`, or other complex types via `node_set_property`, always use the `{ "__type": "...", ... }` wrapper format. Plain numbers/strings won't work for these types.

> [!WARNING]
> **Always save scenes.** MCP scene changes are in-memory until you call `editor_save_scene()`. If the editor closes without saving, changes are lost.

> [!CAUTION]
> **`script_edit` requires exact matches.** The `old_string` parameter must match the file contents byte-for-byte, including whitespace and newlines. Always `script_read` first.

> [!NOTE]
> **Runtime tools only work while the game is running.** Tools like `runtime_screenshot`, `input_simulate`, `runtime_get_script_vars`, and `execute_code` (channel: `"runtime"`) require an active playtest started with `game_start`.

> [!TIP]
> **Use batch mode for performance.** Both `node_set_property` and `node_groups` support batch arrays to set multiple values in a single call instead of making many individual calls.

> [!NOTE]
> **`discover_tools` is your friend.** If you need tilemap, 3D, particles, animation, audio, debugging, or LSP tools — call `discover_tools` with the relevant keyword first. These groups are loaded on demand to keep the default tool list manageable.

---

## 7. Troubleshooting MCP Connection

If the MCP server refuses to connect to a new project and keeps throwing an `AUTH_FAILED` error citing an old project's path (e.g., `"no registry entry for c:/old/project/path"`), this is due to a caching issue where the server script mistakenly locks onto the old working directory.

**Resolution Steps for New Games:**
1. **Ensure correct environment variable:** Open your Antigravity MCP configuration (`C:\Users\user0\.gemini\config\mcp_config.json`) and verify that the environment variable `GODOT_MCP_PROJECT_PATH` is set to the current project's absolute path (NOTE: It must be `GODOT_MCP_PROJECT_PATH`, *not* `GODOT_PROJECT_PATH`).
2. **Remove stale configuration files:** Check the old project's directory and delete any lingering `.mcp.json` files. If Antigravity scans for these, it might incorrectly load the old context.
3. **Clear the npx cache:** The `godot-mcp-server` downloaded via `npx` caches the node scripts (like `index.js` and `tokenPath.js`). If these were originally executed in the context of the old project without the proper environment variable, the old path gets hardcoded into the cached Javascript files. You MUST clear the npx cache to force a fresh, pristine download:
   - Open PowerShell or terminal.
   - Run: `Remove-Item -Recurse -Force $env:LOCALAPPDATA\npm-cache\_npx`
4. **Kill lingering node processes:** Ensure no old instances of the server are running in the background holding onto the old state:
   - Run: `Stop-Process -Name "node" -Force -ErrorAction SilentlyContinue`
5. **Restart MCP:** Refresh or restart the MCP server in Antigravity. It will download a clean copy of the server script and connect using the correct environment variable.
