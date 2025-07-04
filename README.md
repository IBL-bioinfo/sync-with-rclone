# Sync with Rclone

It is a script that serves as a base of scripts for a target folder, for syncing folder contents with a remote drive location.

## Usage

1. Copy the script to target folder
2. Edit the `sync-with-rclone.config` file to configure:
    1. Target remote drive location
    2. Type of sync, "copy" or "sync"
    3. Exclusion list
3. `chmod u+x <script>`
4. Run the script with `pull` or `push`

---

**Version 2.2 changes:**
- All settings (remote, path, operation, excludes, etc.) are now in `sync-with-rclone.config`.
- The main script (`sync-with-rclone.sh`) loads settings from this config file.
- You must keep `sync-with-rclone.config` in the same directory as the script.
- The script will error if the config file is missing.
- The `-y` option is now supported to skip confirmation prompts.
