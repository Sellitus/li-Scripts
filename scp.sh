#!/bin/bash

USER="sellitus"
ARGS=()
while [ $# -gt 0 ]; do
    case "$1" in
        --user|-u)
            USER="$2"
            shift 2
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

if [ ${#ARGS[@]} -lt 3 ]; then
    echo "Usage: $0 [--user|-u <user>] {--send|-s|--receive|-r} <source> <destination>"
    echo ""
    echo "Options:"
    echo "  --user, -u <user>  Remote username (default: sellitus)"
    echo ""
    echo "Send (upload) examples:"
    echo "  $0 --send /local/file.txt /home/sellitus/file.txt"
    echo "  $0 -u root -s /local/folder /home/root/folder"
    echo ""
    echo "Receive (download) examples:"
    echo "  $0 --receive /home/sellitus/file.txt /local/file.txt"
    echo "  $0 --user root -r /home/root/file.txt /local/file.txt"
    exit 1
fi

MODE="${ARGS[0]}"
SOURCE="${ARGS[1]}"
DEST="${ARGS[2]}"
HOST="$USER@192.168.6.75"

CTRL_SOCKET="/tmp/scp_ai32_$$"
SSH_OPTS=(-i ~/.ssh/id_ed25519 -o "ControlMaster=auto" -o "ControlPath=$CTRL_SOCKET" -o "ControlPersist=60")
cleanup() { ssh -o "ControlPath=$CTRL_SOCKET" -O exit "$HOST" 2>/dev/null; }
trap cleanup EXIT

case "$MODE" in
    -s|--send)
        if [ ! -e "$SOURCE" ]; then
            echo "Error: Local path does not exist: $SOURCE"
            exit 1
        fi

        if [ -d "$SOURCE" ]; then
            echo "Uploading directory '$SOURCE' to '$HOST:$DEST'"
            scp "${SSH_OPTS[@]}" -r "$SOURCE" "$HOST:$DEST"
            echo "Uploaded directory: $SOURCE"
        else
            echo "Uploading file '$SOURCE' to '$HOST:$DEST'"
            scp "${SSH_OPTS[@]}" "$SOURCE" "$HOST:$DEST"
            echo "Uploaded file: $SOURCE"
        fi
        ;;

    -r|--receive)
        REMOTE_TYPE=$(ssh "${SSH_OPTS[@]}" "$HOST" "if [ -d \"$SOURCE\" ]; then echo dir; elif [ -e \"$SOURCE\" ]; then echo file; else echo missing; fi" 2>/dev/null)

        if [ "$REMOTE_TYPE" = "missing" ] || [ -z "$REMOTE_TYPE" ]; then
            echo "Error: Remote path does not exist or is not accessible: $SOURCE"
            exit 1
        fi

        if [ "$REMOTE_TYPE" = "dir" ]; then
            echo "Downloading directory '$SOURCE' to '$DEST'"
            scp "${SSH_OPTS[@]}" -r "$HOST:$SOURCE" "$DEST"
            echo "Downloaded directory to: $DEST"
        else
            echo "Downloading file '$SOURCE' to '$DEST'"
            scp "${SSH_OPTS[@]}" "$HOST:$SOURCE" "$DEST"
            echo "Downloaded file to: $DEST"
        fi
        ;;

    *)
        echo "Error: Invalid mode '$MODE'. Use --send/-s or --receive/-r"
        exit 1
        ;;
esac
