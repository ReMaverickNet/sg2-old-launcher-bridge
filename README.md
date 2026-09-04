# SG2 Old Launcher Bridge

A small script for restoring the historical `launcher.exe` launch path for legacy Splitgate 2/Arena Reloaded builds, while keeping the current P2P executable backed up and easily restorable.

## Required launcher location

The historical launcher must be located at:

```text
Linux:  ~/.local/share/Steam/steamapps/common/Splitgate 2/launcher.exe
Windows: C:\Program Files (x86)\Steam\steamapps\common\Splitgate 2\launcher.exe
```

If your game is in another drive, please edit that respective path or set `STEAM_GAME_DIR` to the game directory.

## Usage

### Linux

```bash
./sg2_old_launcher_bridge.sh install
./sg2_old_launcher_bridge.sh restore
./sg2_old_launcher_bridge.sh status
```

### Windows

Run PowerShell as usual; the script will request Administrator privileges automatically:

```powershell
.\sg2_old_launcher_bridge.ps1 install
.\sg2_old_launcher_bridge.ps1 restore
.\sg2_old_launcher_bridge.ps1 status
```

`install` enables the old launcher, `restore` returns the P2P executable, and `status` shows the current state.

---

This project is not affiliated with 1047 Games, Splitgate etc.
