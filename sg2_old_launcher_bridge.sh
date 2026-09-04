#!/usr/bin/env bash
set -euo pipefail

# Splitgate 2 historical-launcher bridge
#
# Makes Steam's CURRENT expected executable path resolve to the historical
# root-level launcher.exe, while preserving the current P2P executable for
# easy restoration.
#
# Historical launch target:
#   <Steam>/Splitgate 2/launcher.exe
#
# Current Steam target:
#   <Steam>/Splitgate 2/PortalWars2/Binaries/Win64/PortalWars2-Win64-Shipping.exe

GAME_DIR="${STEAM_GAME_DIR:-$HOME/.local/share/Steam/steamapps/common/Splitgate 2}"
LAUNCHER="$GAME_DIR/launcher.exe"
TARGET_DIR="$GAME_DIR/PortalWars2/Binaries/Win64"
TARGET="$TARGET_DIR/PortalWars2-Win64-Shipping.exe"
BACKUP="$TARGET.p2p-backup"

usage() {
    cat <<EOF
Usage: $0 {install|restore|status}

install  Back up the current P2P executable (if it exists as a precaution) and replace it with a symlink
         to the historical root-level launcher.exe.

restore  Remove the symlink (and restore the original P2P executable if it existed).

status   Show what is currently installed.

Optional:
  STEAM_GAME_DIR="/path/to/Splitgate 2" $0 install
EOF
}

status() {
    echo "Game directory : $GAME_DIR"
    echo "Launcher       : $LAUNCHER"
    echo "Steam target   : $TARGET"
    echo

    if [[ -f "$LAUNCHER" ]]; then
        echo "[OK] launcher.exe exists"
        stat -c '     size: %s bytes' "$LAUNCHER"
        stat -c '     mode: %A' "$LAUNCHER"
    else
        echo "[!!] launcher.exe NOT FOUND"
    fi

    if [[ -L "$TARGET" ]]; then
        echo "[BRIDGE] Steam target is a symlink:"
        readlink "$TARGET"
    elif [[ -f "$TARGET" ]]; then
        echo "[P2P] Steam target is a regular file"
        stat -c '     size: %s bytes' "$TARGET"
    else
        echo "[!!] Steam target does not exist"
    fi

    if [[ -f "$BACKUP" ]]; then
        echo "[BACKUP] Original P2P executable:"
        stat -c '         size: %s bytes' "$BACKUP"
    fi
}

install_bridge() {
    if [[ ! -f "$LAUNCHER" ]]; then
        echo "ERROR: Historical launcher.exe was not found:"
        echo "  $LAUNCHER"
        echo
        echo "Place the launcher.exe in the root of the game directory,"
        echo "or set STEAM_GAME_DIR to the correct installation path."
        exit 1
    fi

    mkdir -p "$TARGET_DIR"

    if [[ -L "$TARGET" ]]; then
        current_link="$(readlink "$TARGET")"
        if [[ "$current_link" == "../../../../launcher.exe" ]]; then
            echo "Bridge is already installed."
            exit 0
        fi

        echo "ERROR: $TARGET is already a symlink to:"
        echo "  $current_link"
        echo "Refusing to overwrite it."
        exit 1
    fi

    if [[ -f "$TARGET" ]]; then
        if [[ -e "$BACKUP" ]]; then
            echo "ERROR: Backup already exists:"
            echo "  $BACKUP"
            echo
            echo "Refusing to overwrite it. Use 'restore' first."
            exit 1
        fi

        echo "Backing up current P2P executable..."
        mv -- "$TARGET" "$BACKUP"
    fi

    echo "Creating Steam launch bridge..."
    # TARGET_DIR -> GAME_DIR is four levels up:
    # Win64 -> Binaries -> PortalWars2 -> Splitgate 2
    ln -s "../../../../launcher.exe" "$TARGET"

    echo
    echo "Installed successfully."
    echo
    echo "Steam will still try to launch:"
    echo "  $TARGET"
    echo
    echo "but Linux will resolve that path to:"
    echo "  $LAUNCHER"
    echo
    echo "Nothing was modified inside launcher.exe."
    echo
    echo "Run '$0 status' to verify."
}

restore_bridge() {
    if [[ ! -L "$TARGET" ]]; then
        if [[ -f "$BACKUP" ]]; then
            echo "No symlink is present; restoring the P2P executable..."
            mv -- "$BACKUP" "$TARGET"
            echo "Restored."
        else
            echo "Nothing to restore."
        fi
        exit 0
    fi

    link_target="$(readlink "$TARGET")"
    echo "Current symlink:"
    echo "  $TARGET -> $link_target"

    rm -- "$TARGET"

    if [[ -f "$BACKUP" ]]; then
        echo "Restoring original P2P executable..."
        mv -- "$BACKUP" "$TARGET"
        echo "Restored successfully."
    else
        echo
        echo "WARNING: No .p2p-backup file was found."
        echo "The bridge was removed, but the original P2P executable was not restored if it existed (if you're using an old build, you can ignore this message)."
    fi
}

case "${1:-}" in
    install)
        install_bridge
        ;;
    restore)
        restore_bridge
        ;;
    status)
        status
        ;;
    *)
        usage
        exit 2
        ;;
esac
