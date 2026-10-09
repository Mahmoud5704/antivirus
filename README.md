# Simple Antivirus Daemon — CC373 Lab 2
A lightweight antivirus system written in Bash. A daemon watches a directory for any changes and, when something changes, scans every file inside and quarantines anything suspicious. A separate restore tool lets you go through the quarantine list and decide whether to restore a file or delete it permanently. Files you restore are remembered in a whitelist so they are never flagged again.


## Folder structure
```
├── antivirusd.sh        # the daemon — watches a directory and quarantines malicious files
├── restore.sh           # the restore tool — lets you review and manage quarantined files
├── antivirus-cron.sh    # cron version — runs one scan pass per invocation instead of looping
├── Makefile             # shortcuts to run everything
├── original/            # the directory being monitored (you create this)
│   └── whitelist.txt    # auto-created when you first restore a file
├── restore/             # quarantine folder — created automatically by make
├── directory-info.last  # saved snapshot of the directory (created at runtime)
└── directory-info.new   # current snapshot used for comparison (created at runtime)
```

`original/` and `restore/` hold files only — no subdirectories inside them.

## Prerequisites
Everything needed is standard on Ubuntu. The only thing you may need to install is `make`:

```bash
sudo apt update && sudo apt install -y make
```

For the cron bonus, also install and start cron if it is not already running:

```bash
sudo apt install -y cron
sudo systemctl enable --now cron
```

Before running anything, make the scripts executable:

```bash
chmod +x filename.sh
```

## How to run
### 1. Create the monitored directory
```bash
mkdir -p original
```

### 2. Start the antivirus daemon
```bash
make
```
This creates the `restore/` quarantine folder if it does not exist, then starts the daemon watching `original/` with a 2-second check interval.
You can also run it directly with different arguments:
```bash
./antivirusd.sh <dir> <malicious_dir> <interval-secs>
# example
./antivirusd.sh original restore 5
```

**What happens when you run it:**
1. On the very first run it immediately scans everything already in the directory.
2. Every `<interval-secs>` seconds it checks whether anything changed.
3. If nothing changed, it waits and checks again.
4. If something changed, it scans the directory and quarantines any malicious files it finds.
5. For each quarantined file it prints: `<file> is malicious and it is DELETED`
Stop the daemon with `Ctrl+C`.
To test it, drop a file into `original/` from another terminal while the daemon is running:
```bash
echo "virus" > original/test.txt
touch original/payload.exe
```

### 3. Review the quarantine (restore tool)
> Do **not** run this at the same time as the daemon.
```bash
make restore
```
Or directly:
```bash
./restore.sh <dir> <malicious_dir>
# example
./restore.sh original restore
```
The tool shows a numbered list of quarantined files and asks you to pick one. For example:
```
Choose a file:
1: file1.exe
2: file2.bat
> 2
For file2.bat:
1: Restore this file back into dir (it was a false positive)
2: Permanently delete this file from malicious_dir (it was genuinely malicious)
3: Go back
> 1
Restored file2.bat to original.
```

| Option | Action | Message logged |
| `1` | Copy the file back to `dir`, add to whitelist | `Restored <file> to <dir>.` |
| `2` | Permanently delete from quarantine | `<file> permanently deleted.` |
| `3` | Leave it and go back to the list | — |
If the quarantine folder is empty, the tool prints `No malicious files to review.` and exits.


## Where the flagged lists are defined
Both lists live inside the `scan_files()` function in `antivirusd.sh` (and are duplicated in `antivirus-cron.sh`):
- **Flagged extensions** — `.exe`, `.bat`, `.vbs`, `.scr`, `.ps1`  
  Look for the chain of `[ "$extension" = "exe" ] || ...` comparisons in the `if` block at the bottom of `scan_files()`.
- **Flagged keywords** — `virus`, `trojan`, `malware`, `worm`, `ransomware`  
  Look for the `grep -Eci "virus|trojan|malware|worm|ransomware"` line just above that `if`.
A file is quarantined if it matches **either** rule. Keywords match anywhere inside the file contents, including inside longer words (e.g. a file containing `wormhole` is flagged), and the match is case-insensitive. Only the final extension is checked — `file.txt.scr` is flagged but `file.scr.txt` is not.

---

## Bonus 1 — Cron job
`antivirus-cron.sh` performs one scan pass and exits, making it suitable for scheduling with cron.
```bash
./antivirus-cron.sh <dir> <malicious_dir>
```

### Prerequisites before setting up the cron job
1. `cron` is installed and running:
   ```bash
   sudo apt install -y cron
   sudo systemctl enable --now cron
   systemctl status cron   # should say "active (running)"
   ```
2. Scripts are executable (`chmod +x antivirus-cron.sh`).
3. Both `<dir>` and `<malicious_dir>` directories exist.
4. You know the **absolute path** of the project folder (run `pwd` inside it). Cron does not start in your project directory, so relative paths will not work.

### Step-by-step cron setup
1. Go to your project folder and note the absolute path:
   ```bash
   cd /path/to/project && pwd
   ```
2. Open your crontab:
   ```bash
   crontab -e
   ```   
4. Add this line, replacing `/path/to/project` with your actual path:
   ```
   * * * * * cd /path/to/project && sleep 23 && ./antivirus-cron.sh original restore >> /path/to/project/cron.log 2>&1
   ```
   - `* * * * *` — runs the job every minute.
   - `sleep 23` — delays execution to **second 23** of each minute. 
   - `cd /path/to/project` — makes relative paths like `original/` and `restore/` resolve correctly.
   - `>> cron.log 2>&1` — saves all output to a log file since there is no terminal.
5. Save and exit. Verify the line is registered:
   ```bash
   crontab -l
   ```
6. Watch it run:
   ```bash
   tail -f /path/to/project/cron.log
   ```
7. To stop the job, run `crontab -e` and delete the line.
> Do not run the cron job and `antivirusd.sh` on the same directories at the same time.

### Cron expression: every 3rd Friday of the month at 12:31 AM
```
31 0 15-21 * * [ "$(date +\%u)" = 5 ] && /path/to/project/antivirus-cron.sh /path/to/project/original /path/to/project/restore
```
- `31 0` — minute 31 of hour 0 = 12:31 AM.
- `15-21` — the 3rd Friday of any month always falls between the 15th and the 21st.
- Cron treats day-of-month and day-of-week fields as OR, not AND, so `5` in the weekday field would run on every Friday. Instead the command itself checks `date +%u` (1=Monday … 5=Friday) and only proceeds when it is a Friday.
- `\%` escapes `%` because cron treats a bare `%` as a newline.


## Bonus 2 — Whitelist
If a restored file still matches a flagged extension or keyword, it would be quarantined again on the next scan, but whitelist prevents this.
the whitelist is a plain text, it survives the daemon being stopped and restarted.
1. add file: choosing option `1` in the restore -> copies the file back to `<dir>`, computes `sha256sum`, builds the key `<hash><extension>` and appends that key as one line to `<dir>/whitelist.txt`.
2. How the daemon checks it: `scan_files()` runs:
```bash
grep -Fqx "$result" "$original/whitelist.txt" 2>/dev/null
```
If the key matches, the file is skipped and never quarantined.

