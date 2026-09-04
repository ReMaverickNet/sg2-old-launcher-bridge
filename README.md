# SG2 Old Launcher Bridge

A small script for restoring the historical `launcher.exe` launch path for legacy Splitgate 2/Arena Reloaded builds that use this Steam launch path.

## Required launcher location

The historical `launcher.exe` must be located in the root of the game directory:

```text
Linux:   ~/.local/share/Steam/steamapps/common/Splitgate 2/launcher.exe
Windows: C:\Program Files (x86)\Steam\steamapps\common\Splitgate 2\launcher.exe
```

If your game is installed elsewhere, set `STEAM_GAME_DIR` to the game directory.

## Usage

### Linux

```bash
./sg2_old_launcher_bridge.sh install
./sg2_old_launcher_bridge.sh restore
./sg2_old_launcher_bridge.sh status
```

### Windows

```powershell
.\sg2_old_launcher_bridge.ps1 install
.\sg2_old_launcher_bridge.ps1 restore
.\sg2_old_launcher_bridge.ps1 status
```

The Windows script requests Administrator privileges automatically.

`install` creates the bridge and backs up an existing executable at Steam's expected path when present. `restore` removes the bridge and restores that backup when one exists. `status` shows the current state.

---

This project is not affiliated with 1047 Games, Splitgate etc.
