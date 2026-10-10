# Simple Antivirus Daemon — CC373 Lab 2
A lightweight antivirus system written in Bash. A daemon watches a directory for any changes and, when something changes, scans every file inside and quarantines anything suspicious. A separate restore tool lets you go through the quarantine list and decide whether to restore a file or delete it permanently. Files you restore are remembered in a whitelist so they are never flagged again.


## Folder structure
```
antivirusd.sh        # the daemon — watches a directory and quarantines malicious files
restore.sh           # the restore tool — lets you review and manage quarantined files
antivirus-cron.sh    # cron version — runs one scan pass per invocation instead of looping
Makefile             # shortcuts to run everything
original/            # the directory being monitored (contain files only)
  -- whitelist.txt   # creeated when you first file restored
restore/             # the directory copied to it malicious files and can restore them from it(contain files only)
directory-info.last  # saved snapshot of the directory (created at runtime)
directory-info.new   # current snapshot used for comparison (created at runtime)
```
.

## Prerequisites
as I use Ubuntu,ensure only the following:-
1. install `make`:
  ```bash
  sudo apt update && sudo apt install -y make
  ```
2. make the scripts executable:
  ```bash
  chmod +x filename.sh
  ```
3. `cron` is installed and running:
   ```bash
   sudo apt install -y cron
   sudo systemctl enable --now cron
   systemctl status cron   # should say "active (running)"
   ```
4. also for all -> dir and malicious dir must be exist

## How to run
### 1. Create the monitored directory
```bash
mkdir -p original
```

### 2. Run antivirus steps
```bash
make
```
This starts the daemon watching `original/` with a 2-second check interval.
You can also run it directly with parametersyou prefer:
```bash
./antivirusd.sh <dir> <malicious_dir> <interval-secs>
# example
./antivirusd.sh original restore 5
```

What happens when you run it?
- first run it immediately scans everything already in the directory.
- Every `<interval-secs>` seconds it checks whether anything changed.
- If nothing changed, it waits and checks again.
- If something changed, it scans the directory and quarantines any malicious files it finds.
- For each quarantined file it prints: `<file> is malicious and it is DELETED`
- to Stop the daemon -> `Ctrl+C`.

How detect a malicious file in detail?
1. extensions: `.exe`, `.bat`, `.vbs`, `.scr`, `.ps1`:-
   look for `[ "$extension" = "exe" ] || ...` comparisons in the `if` block, detect any malicious extension.
2. keywords: `virus`, `trojan`, `malware`, `worm`, `ransomware`:-
   Look for the `grep -Eci "virus|trojan|malware|worm|ransomware"`, detect any malicious content.
3. symbols used in grep `-Eoi`:- 
   -E (Extended regex): Search using patterns(grep -E "cat|dog" file.txt), so he will search for cat and dog separately 
   -o (Count): Count the matching words
   -i (Ignore case): Find the word regardless of uppercase or lowercase.
4. but if the file was restored after flagged so we skip it (see bouns 2 --- whitelist)


### 3. Run Restore steps
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
1: Restore this file back into dir (also to the whitelist->;see bouns2)
2: Permanently delete this file from malicious_dir (it was genuinely malicious)
3: Go back
> 1
Restored file2.bat to original.
```
Options:
- `1` -> Copy the file back to `dir` + add to whitelist.
- `2` -> Permanently delete it.
- `3` -> Leave it and go back to the list.
If the quarantine folder is empty, it prints `No malicious files to review.` and exits.


## Bonus 1 — Cron job
`antivirus-cron.sh` performs one scan pass and exits, making it suitable for scheduling with cron.
```bash
./antivirus-cron.sh <dir> <malicious_dir>
```
note: Cron does not start in your project directory, so relative paths will not work.
### Run cron
1. Go to your project folder and note the absolute path:
2. Open your crontab:
   ```bash
   crontab -e
   ```   
3. Add this line, replacing `/path/to/project` with your actual path:
   ```
   * * * * * cd /path/to/project && sleep 23 && ./antivirus-cron.sh original restore >> /path/to/project/cron.log 2>&1
   ```
   - `* * * * *` — runs the job every minute.
   - `sleep 23` — delays execution to **second 23** of each minute. 
   - `>> cron.log 2>&1` — saves all output to a log file.
4. Save and exit. Verify what you modify with this command:
   ```bash
   crontab -l
   ```
5. to see the run logs:
   ```bash
   cat cron.log
   ```
6. To stop the job, run `crontab -e` and delete the line.

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

