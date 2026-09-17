# Noctalia Offline Dictionary Plugin

A high-speed, 100% offline dictionary plugin for [Noctalia](https://github.com/noctalia-dev/noctalia) on Wayland.

Inspired by [omarchy-lookup](https://github.com/keegan-sucks/omarchy-lookup), this plugin brings instant, private, offline dictionary definitions to your desktop. Highlight or copy any word on your screen, click the bar widget, and immediately get its definition with automatic clipboard copy and a slide-out card.

## Features

* **Instant Selection Flow**: Highlight any word on your screen with your mouse or copy it (<kbd>Ctrl+C</kbd>), then click the bar widget. It captures the word and defines it in under 10 milliseconds.
* **100% Offline & Pre-Packaged**: Ships with Webster's 1913 dictionary compressed via `xz` directly in `data/` (~5.8 MB). Auto-decompresses into `~/.cache/` on first run with zero manual setup.
* **Smart Morphology Rules**: Automatically resolves inflections like plurals, verb tenses (`-ing`, `-ed`), adverbs (`-ly`), and comparatives (`-er`, `-est`).
* **Progressive Prefix Backoff**: When an exact word or typo is missing, it progressively shortens the prefix down to 4 characters to surface intelligent *"Did you mean:"* suggestions.
* **Automatic Clipboard Copy**: Formats and copies `word (part-of-speech): definition` to your clipboard automatically.
* **Desktop Toast Notifications**: Shows a quick notification previewing the definition.
* **Interactive Search Panel**: Type any word directly into the search bar, click suggestion chips, and view recent lookup history.
* **Multi-Backend Fallback**: Supports `sdcv` (StarDict) and `dict` CLI if installed on your system.

> [!NOTE]
> If nothing is selected or copied when you click the bar icon, the dictionary panel opens directly with keyboard focus ready for typing.

## Requirements

The plugin relies on standard Wayland utilities:

| Dependency | Package (Arch Linux) | Purpose |
| :--- | :--- | :--- |
| `wl-paste` | `wl-clipboard` | Wayland primary selection and clipboard reading |
| `python3` | `python` | Query engine, decompression, and morphology matching |

Install the dependencies:

```bash
sudo pacman -S wl-clipboard python
```

## Installation & Local Development

### 1. Clone the repository

```bash
git clone https://github.com/firo1919/noctalia-dictionary.git ~/Projects/noctalia-dictionary
```

### 2. Register as a Local Noctalia Source

```bash
mkdir -p ~/.local/share/noctalia/sources/local-dev
ln -s ~/Projects/noctalia-dictionary ~/.local/share/noctalia/sources/local-dev/dictionary

# Register the source directory with Noctalia:
noctalia msg plugins source add local-dev path ~/.local/share/noctalia/sources/local-dev
```

### 3. Enable the Plugin

```bash
noctalia msg plugins enable firo1919/dictionary
```

### 4. Add the Widget to Your Bar

1. Open Noctalia Settings (`noctalia msg settings-open`).
2. Go to **Bar** → select your capsule group (e.g. `g4`).
3. Click **Add Widget** and select **Dictionary** (`firo1919/dictionary:widget`).

## Usage

* **Highlight & Click**: Highlight any word with your mouse (or copy it with <kbd>Ctrl+C</kbd>), then click the Dictionary icon on your bar.
* **Type to Search**: If no text is selected, clicking the icon opens the Dictionary panel so you can type any word.
* **Right-Click**: Toggles the Dictionary Search Panel at any time.

## Configuration

Settings can be adjusted in Noctalia Settings under **Plugins → Dictionary**:

| Setting | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `copy_to_clipboard` | Boolean | `true` | Copies the definition summary to the system clipboard upon lookup |
| `show_notification` | Boolean | `true` | Shows a desktop toast notification with the word and definition preview |
| `show_panel_on_lookup` | Boolean | `true` | Automatically opens the slide-out panel with full definitions |
| `glyph` | Glyph | `vocabulary` | Icon displayed on the Noctalia status bar |

## License

MIT © [firo1919](https://github.com/firo1919)
