# Noctalia Native Dictionary Plugin

A high-speed, 100% offline dictionary plugin for [Noctalia](https://github.com/noctalia-dev/noctalia) on Wayland.

Zero OCR, zero screenshots. Uses native Wayland primary selection (`wl-paste -p`) to capture highlighted text with 100% accuracy, instant sub-millisecond lookup, and automatic clipboard copy.

## ✨ Features

* **Native Selection Detection**: Highlight any word on your screen with your mouse cursor, and click the bar widget for an instant definition.
* **Selection Waiting Mode**: If you haven't highlighted a word yet, clicking the widget arms the waiting state. The moment you highlight any text, it defines it immediately!
* **100% Offline & Private**: Zero network calls, zero tracking, sub-millisecond local SQLite queries (over 176,000+ English definitions).
* **Multi-Backend Support**:
  * Built-in indexed SQLite dictionary (176,000+ words).
  * `sdcv` (StarDict Console Version) if installed (`sudo pacman -S sdcv`).
  * `dict` CLI if installed (`sudo pacman -S dictd`).
* **Automatic Clipboard Copy**: Copies `word (part-of-speech): definition` directly to your clipboard.
* **Toast Notification & Detail Panel**: Preview definitions in toast notifications or explore full numbered senses in the slide-out panel.
* **Interactive Search Bar**: Type words manually with live auto-suggestions and recent lookup history.
* **Smart Lemmatization**: Automatically resolves inflections (plurals, `-ing`, `-ed`, `-ies`, `-ly`).

## 📦 Requirements

* [Noctalia Shell](https://github.com/noctalia-dev/noctalia) (API v14+)
* `wl-clipboard` (provides `wl-paste`)
* `python3` (with built-in `sqlite3`)

Optional dictionary packages:
* `sdcv` (`sudo pacman -S sdcv`) for StarDict support

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

* **Highlight & Click**: Highlight any word on screen with your mouse, then click the Dictionary icon.
* **Click & Highlight**: Click the Dictionary icon first (it turns into a pointer icon waiting for you), then highlight any word!
* **Right-Click on Bar Icon**: Toggles the interactive Dictionary Search Panel.

## 📄 License

MIT © [Firomsa](https://github.com/firomsa)
