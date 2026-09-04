# SG2 Old Launcher Bridge

A small Linux script for restoring the historical `launcher.exe` launch path for legacy Splitgate 2 builds, while keeping the current P2P executable backed up and easily restorable.

## Usage

```bash
./sg2_old_launcher_bridge.sh install
./sg2_old_launcher_bridge.sh restore
./sg2_old_launcher_bridge.sh status
```

`install` enables the old launcher, `restore` returns the P2P executable, and `status` shows the current state.
