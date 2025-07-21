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

**Version 2.3 changes:**
- Git repository is processed in a better way
    - now recording
        - Date and time of pushing to cloud
        - All remote URLs
        - Current commit hash
        - Current `git status` output
    - Pulling from cloud will not trigger this
    - Will not record if the repository has not been changed since the last push, comparing all except date and time
        - (Now searching the whole file. Potential drawback here: if repository is reverted to a previous commit that has been recorded before, the record will still be skipped)
    - The record file now appears side to side with the repository root directory, with the same name.
