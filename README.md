# Noctalia Offline Dictionary Plugin

A high-speed, 100% offline dictionary plugin for [Noctalia](https://github.com/noctalia-dev/noctalia) on Wayland.

Just like Noctalia's OCR plugin, click the bar widget to select any word on your screen with `slurp` + `grim`. The word is recognized via `tesseract`, looked up instantly in a local indexed English dictionary database, copied to your clipboard, and presented with a definition card.

## ✨ Features

* **Instant Screen Selection**: Select any text or word on your screen with a responsive region selection box.
* **100% Offline & Private**: Zero network calls, zero tracking, sub-millisecond local SQLite queries (over 176,000+ English definitions).
* **Automatic Clipboard Copy**: Copies `word (part-of-speech): definition` directly to your clipboard.
* **Toast Notification & Detail Panel**: Preview definitions in toast notifications or explore full numbered senses in the slide-out panel.
* **Interactive Search Bar**: Type words manually with live auto-suggestions and recent lookup history.
* **Smart Lemmatization**: Automatically resolves inflections (plurals, `-ing`, `-ed`, `-ies`, `-ly`).

## 📦 Requirements

* [Noctalia Shell](https://github.com/noctalia-dev/noctalia) (API v14+)
* `grim`, `slurp`, `tesseract` (standard Wayland OCR tools)
* `python3` (with built-in `sqlite3`)

The local dictionary database is automatically installed to `~/.local/share/noctalia/dictionary/dictionary.db`.

## 🚀 Installation & Local Development

### 1. Clone the repository
```bash
git clone https://github.com/firomsa/noctalia-dictionary.git ~/Projects/noctalia-dictionary
```

### 2. Register as a Local Noctalia Source
```bash
mkdir -p ~/.local/share/noctalia/sources/local-dev
ln -s ~/Projects/noctalia-dictionary ~/.local/share/noctalia/sources/local-dev/dictionary

# Add local source if not already registered:
noctalia msg plugins source add local-dev path ~/.local/share/noctalia/sources/local-dev
```

### 3. Enable the Plugin
```bash
noctalia msg plugins enable firomsa/dictionary
```

### 4. Add the Widget to Your Top Bar
Open Noctalia Settings (`noctalia msg settings-open`) → **Bar** → select your capsule group → **Add Widget** → **Dictionary** (`firomsa/dictionary:widget`).

## 🎮 Usage

* **Left-Click on Bar Icon**: Starts the screen selection tool (`slurp`). Drag a box over any word on your screen.
* **Right-Click on Bar Icon**: Toggles the interactive Dictionary Search Panel.

## 📄 License

MIT © [Firomsa](https://github.com/firomsa)
