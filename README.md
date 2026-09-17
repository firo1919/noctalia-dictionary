# Noctalia Offline Dictionary Plugin

An offline dictionary plugin for [Noctalia](https://github.com/noctalia-dev/noctalia) on Wayland.

Inspired by Noctalia's OCR plugin, click the bar widget to drag a selection box over any word on your screen (in web browsers, video subtitles, PDFs, documents, or terminal). The word is extracted with `tesseract`, looked up in a local dictionary database, copied to your clipboard, and presented with a definition card.

## Features

* **Visual Screen Selection**: Drag a selection box over any text on screen with responsive `slurp` crosshairs.
* **100% Offline and Private**: No network requests or telemetry. Instant sub-millisecond local lookups.
* **Automatic Clipboard Copy**: Formats and copies `word (type): definition` to your clipboard automatically.
* **Toast Notification**: Displays a desktop notification showing the recognized word and definition preview.
* **Interactive Panel**: View full numbered senses, parts of speech, and browse recent lookup history.
* **Manual Search Input**: Type and look up words directly in the panel with live prefix suggestions.
* **Multi-Backend Architecture**:
  * Built-in local SQLite dictionary database (176,000+ words with lemmatization for plurals, `-ing`, `-ed`, and `-ly`).
  * Seamless support for `sdcv` (StarDict Console Version) if installed.
  * Support for the `dict` CLI if installed.

> [!TIP]
> Because screen region selection works via the compositor layer, you can look up words anywhere—including inside video streams, protected web pages, and image files where text cannot be highlighted with a mouse cursor.

## Requirements

The plugin requires the following packages on your system:

| Dependency | Package (Arch Linux) | Purpose |
| :--- | :--- | :--- |
| `grim` | `grim` | Wayland screenshot capture |
| `slurp` | `slurp` | Interactive region selection |
| `tesseract` | `tesseract` + `tesseract-data-eng` | Optical Character Recognition |
| `python3` | `python` | Local lookup engine and lemmatizer |

Install the dependencies:

```bash
sudo pacman -S grim slurp tesseract tesseract-data-eng python
```

> [!NOTE]
> If you prefer using StarDict dictionaries, install `sdcv` (`sudo pacman -S sdcv`). The plugin will automatically detect and query your installed StarDict dictionaries before falling back to the local SQLite database.

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

* **Left-Click the Bar Icon**: Launches screen selection (`slurp`). Drag a box over any word on screen to capture and define it. Press <kbd>Esc</kbd> to cancel.
* **Right-Click the Bar Icon**: Toggles the Dictionary Search Panel, where you can type any word manually and browse recent lookups.

## Configuration

Settings can be adjusted in Noctalia Settings under **Plugins → Dictionary**:

| Setting | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `copy_to_clipboard` | Boolean | `true` | Copies the definition summary to the system clipboard upon lookup |
| `show_notification` | Boolean | `true` | Shows a desktop toast notification with the word and definition preview |
| `show_panel_on_lookup` | Boolean | `true` | Automatically opens the slide-out panel with full definitions |
| `psm` | Select | `6` | Tesseract page segmentation mode (`6` = uniform block, `7` = single line, `8` = single word) |
| `glyph` | Glyph | `vocabulary` | Icon displayed on the Noctalia status bar |
