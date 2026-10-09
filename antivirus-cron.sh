#!/bin/bash
# We use double quotes around variables to treat their contents as a single argument.
# Use cmp to compare files.

if [ $# -eq 2 ]; then
    original=$1
    restore=$2

    mkdir -p "$restore"

    scan_files() {
        shopt -s nullglob

        for f in "$original"/*; do
            [ -f "$f" ] || continue
            hash=$(sha256sum "$f" | cut -d ' ' -f1)
            extension="${f##*.}"
            result="$hash$extension"

            if grep -Fqx "$result" "$original/whitelist.txt" 2>/dev/null; then
                echo "$f is whitelisted, skip..."
                continue
            fi

            virus=$(grep -Eci "virus|trojan|malware|worm|ransomware" "$f")

            if [ "$extension" = "exe" ] || [ "$extension" = "bat" ] || [ "$extension" = "vbs" ] || [ "$extension" = "scr" ] || [ "$extension" = "ps1" ] || [ "$virus" -gt 0 ]; then
                echo "$f is malicious and it is DELETED"
                cp "$f" "$restore"
                rm "$f"
            fi
        done
    }

    scan_files

    if [ ! -f directory-info.last ]; then
        ls -l "$original" > directory-info.last
    fi

    ls -l "$original" > directory-info.new

    if ! cmp -s directory-info.last directory-info.new; then
        scan_files
        ls -l "$original" > directory-info.new
    fi

    cp directory-info.new directory-info.last
else
    echo "pleaaaaaaaase dont forget arguments!"
fi
