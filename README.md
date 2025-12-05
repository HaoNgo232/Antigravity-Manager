# 🚀 Antigravity Manager

> **Modern Multi-Account Management Tool for Antigravity on macOS & Windows**

Antigravity Manager is a powerful utility designed to solve the pain point of Antigravity client's lack of native multi-account switching support. By taking over the application's configuration state, it allows users to seamlessly switch between unlimited accounts with a single click, while providing automatic backup, process monitoring, and a visual management interface.

---

## ✨ Core Features

### 🛡️ Account Security & Management
*   **Unlimited Account Snapshots**: Create any number of account backups, fully preserving login credentials, user configurations, and local state.
*   **Smart Recognition**: Automatically reads the current logged-in account's email and ID from the database, no manual input required.
*   **Automatic Backup Mechanism**:
    *   **Startup Backup**: Automatically backs up the current state every time the manager starts, preventing accidental overwrites.
    *   **Switch Backup**: Automatically saves the current account's latest state before switching accounts.
*   **Detailed Metadata**: Records creation time, last used time, email, and unique ID for each archive.

### ⚡️ Seamless Experience
*   **One-Click Switching**: Complete the entire process of "close app -> replace data -> restart app" with just one click.
*   **Process Monitoring**:
    *   **Graceful Exit**: Prioritizes using AppleScript (macOS) or taskkill (Windows) to notify the app to exit normally, protecting data integrity.
    *   **Force Fallback**: If the app freezes, automatically escalates to force termination strategy to ensure successful switching.
*   **Cross-Platform Support**: Perfect compatibility with macOS (Intel/Apple Silicon), Windows 10/11, and Linux (Ubuntu, Mint, Debian).

### 🎨 Modern Interface
*   **Flet-Powered**: High-performance GUI based on Flutter, responsive and fast.
*   **Native Integration**: Automatically adapts to system dark/light mode, providing a native window experience.
*   **User-Friendly**: Clear list views, intuitive action buttons, and friendly confirmation dialogs.

---

## 🛠️ Quick Start

### Requirements
*   **Operating System**: macOS 10.15+, Windows 10+, or Linux (Ubuntu 22.04+, Linux Mint 22+, Debian 12+)
*   **Python**: 3.10 or higher
*   **Antigravity**: Must be installed and run at least once

### 1. Install Dependencies
Run the following command in the project root directory to install required libraries:

```bash
pip install -r requirements.txt
```

### 2. Run the Application

#### 🖥️ GUI Mode (Recommended)
Launch the graphical interface for the complete interactive experience:

```bash
# macOS / Linux
python gui/main.py

# Windows
python gui\\main.py
```

#### ⌨️ CLI Mode
Suitable for script integration or power users.

**Interactive Menu**:
```bash
python main.py
```

**Common Commands**:
```bash
# List all archives
python main.py list

# Backup current account (auto-detect name)
python main.py add

# Backup with custom name
python main.py add -n "Work Account"

# Switch account (using ID or list index)
python main.py switch -i 1

# Delete backup
python main.py delete -i 1
```

---

## 📦 Building & Deployment

This project includes automated build scripts to generate standalone executables that don't require a Python environment.

### 🍎 macOS Build
Build `.app` application and `.dmg` installer.

```bash
# 1. Grant execution permission
chmod +x build_macos.sh

# 2. Run build
./build_macos.sh
```
*   **Output Path**: `gui/build/macos/`
*   **Contains**: `Antigravity Manager.app`, `Antigravity Manager.dmg`
*   **Architecture**: Universal Binary (supports Intel & M1/M2/M3)

### 🪟 Windows Build
Build single-file `.exe` executable.

```powershell
# Run in PowerShell
./build_windows.ps1
```
*   **Output Path**: `dist/`
*   **Contains**: `Antigravity Manager.exe`
*   **Features**: No console window, single-file portable execution.

### 🐧 Linux Build
Build portable `.AppImage` for Linux distributions.

```bash
# 1. Grant execution permission
chmod +x build_linux.sh

# 2. Run build
./build_linux.sh
```
*   **Output Path**: `./Antigravity-Manager-x86_64.AppImage`
*   **Tested On**: Linux Mint 22.1, Ubuntu 22.04+, Debian 12+
*   **Features**: Portable, no installation required, runs on most Linux distros
*   **Dependencies**: Python 3.10+, wget (auto-installed if missing)

**To run the AppImage:**
```bash
./Antigravity-Manager-x86_64.AppImage
```

**Optional: Install to system:**
```bash
# User installation
mv Antigravity-Manager-x86_64.AppImage ~/.local/bin/

# System-wide installation (requires sudo)
sudo mv Antigravity-Manager-x86_64.AppImage /usr/local/bin/
```

---

## 🧩 Technical Architecture

### Directory Structure
```
antigravity_manager/
├── assets/                 # Static resources (icons, etc.)
├── gui/                    # Core codebase
│   ├── main.py             # GUI entry point
│   ├── account_manager.py  # Account logic (CRUD operations)
│   ├── process_manager.py  # Process control (cross-platform process management)
│   ├── db_manager.py       # Data persistence (file operations)
│   ├── views/              # UI view components
│   └── utils.py            # Common utilities
├── main.py                 # CLI entry point
├── build_macos.sh          # macOS build script
├── build_windows.ps1       # Windows build script
├── build_linux.sh          # Linux build script
└── requirements.txt        # Python dependencies
```

### Data Storage
*   **Configuration File**: `~/.antigravity-agent/accounts.json` (stores account list index)
*   **Backup Data**: `~/.antigravity-agent/backups/*.json` (actual account data snapshots)
*   **Log File**: `~/.antigravity-agent/app.log`

---

## ❓ Frequently Asked Questions (FAQ)

**Q: Antigravity doesn't auto-launch after switching accounts?**
A: Please ensure Antigravity is installed in the standard path (macOS: `/Applications`, Windows: default installation directory). If using a custom path, the program will attempt to launch via URI protocol (`antigravity://`).

**Q: Where are backup files stored?**
A: All data is stored in the `.antigravity-agent` folder in the user's home directory. You can manually backup this folder at any time.

**Q: Why does antivirus software flag the Windows version?**
A: Single-file executables packaged with PyInstaller are occasionally flagged as false positives. This is a known PyInstaller issue. Please add the app to your whitelist or run directly from Python source code.

---

## 📄 License

This project is licensed under the MIT License. Issues and Pull Requests are welcome.

Copyright (c) 2025 Ctrler. All rights reserved.
