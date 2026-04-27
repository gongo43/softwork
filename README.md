# Screen Assist

A lightweight mouse jiggler / keyboard simulator that keeps your PC awake.

## Features

- **Mouse mode** — moves the cursor by 1 pixel after idle timeout
- **Keyboard mode** — sends a random keystroke after idle timeout
- Configurable idle time (5 s – 5 min)
- Configurable session duration (10 min – 4 hours, or unlimited)
- Auto-starts on launch

## Running

- Double-click `ScreenAssist.exe`, or
- Right-click `screen_assist.ps1` → **Run with PowerShell**, or
- From a terminal:
  ```powershell
  powershell -ExecutionPolicy Bypass -File screen_assist.ps1
  ```

## Building

### Prerequisites

Install the [ps2exe](https://github.com/MScholtes/PS2EXE) module (one-time):

```powershell
Install-Module -Name ps2exe -Scope CurrentUser -Force
```

### Build

Run the build script from the project root:

```powershell
.\build.ps1
```

This compiles `screen_assist.ps1` into `ScreenAssist.exe` with the app icon.
