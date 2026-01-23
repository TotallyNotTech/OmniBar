# OmniBar 🚀

**OmniBar** is a lightweight, Spotlight-style developer utility blade for macOS built with Flutter. It runs in the background and provides quick access to essential tools (JSON formatting, color conversion, epoch timestamps) via a global hotkey.

---

## 🛠 Tech Stack

- **Framework:** Flutter (macOS Desktop)  
- **UI Library:** macos_ui (for native Apple aesthetics)  
- **Window Management:** window_manager (for frameless, floating windows)  
- **System Integration:** hotkey_manager, system_tray  
- **State Management:** (Choose one: Riverpod / Provider / Bloc)

---

## ✅ Development Roadmap / Checklist

Use this checklist to track your progress.

---

## Phase 1: Project Setup & Window Configuration

**Goal:** Get a frameless, transparent window running on macOS.

### Initialize Project
- [x] Run `flutter create -e macos omnibar`  
- [x] Verify the app runs on the macOS desktop target  

### Install Core Dependencies
- [x] Add `window_manager`, `macos_ui`, and `provider` (or your preferred state manager) to `pubspec.yaml`  

### Configure Main Window
- [x] Remove the native title bar  
- [x] Set the window size (e.g., 800x600 or 800x60)  
- [x] Make the window transparent/translucent  
- [x] Center the window on the screen on startup  

### Implement "Loss of Focus" Logic
- [x] Detect when the user clicks outside the app window  
- [x] Minimize or hide the app when focus is lost  

---

## Phase 2: The UI Skeleton

**Goal:** Create the visual layout of the command bar.

### Theme Setup
- [ ] Configure `MacosApp` and apply a dark/light theme based on system settings  

### The Search Bar
- [x] Create a large, auto-focused text input field at the top  
- [x] Remove standard borders to make it look clean/minimal  

### The Results List
- [ ] Create a `ListView` below the search bar to show search results or tool outputs  
- [ ] Implement keyboard navigation (Arrow Up/Down) to highlight list items  

---

## Phase 3: System Integration

**Goal:** Make the app behave like a background utility.

### System Tray Icon
- [x] Add `system_tray` package  
- [x] Create a Menu Bar icon (using an `.ico` or `.png`)  
- [ ] Add a context menu to the icon (e.g., "Show", "Quit")  

### Global Hotkeys
- [x] Add `hotkey_manager`  
- [ ] Register `Command + K` (or similar) to toggle the window visibility  
- [x] Ensure the app does not appear in the Dock (edit `Info.plist` key `LSUIElement` to `true`)  

---

## Phase 4: The Logic Engine (The "Brain")

**Goal:** Parse user input and decide which tool to show.

### Input Parser
- [x] Create a basic parser that reads the text field  
- [x] Implement logic: *If text starts with `json`, switch to JSON mode*  

### Tool 1: UUID Generator (The "Hello World")
- [x] Logic: When user types `uuid`, generate a v4 UUID  
- [x] UI: Display the UUID  
- [x] Action: Pressing Enter copies it to clipboard  

### Tool 2: Color Converter
- [ ] Logic: Detect Hex codes (e.g., `#FF0000`)  
- [ ] UI: Show a colored box and the RGB/HSL values  

### Tool 3: JSON Pretty Printer
- [x] Logic: Detect if input is valid JSON string  
- [x] UI: Show formatted, syntax-highlighted JSON  

---

## Phase 5: Polish & Distribution

**Goal:** Make it feel like a polished product.

### Visual Polish
- [ ] Add a backdrop blur (Glassmorphism) behind the window  
- [ ] Add smooth animations when the window appears/disappears  

### Settings Page
- [ ] Create a small settings view to change the hotkey or default theme  

### Build for Release
- [ ] Update app icon (`flutter_launcher_icons`)  
- [ ] Run `flutter build macos --release`  
