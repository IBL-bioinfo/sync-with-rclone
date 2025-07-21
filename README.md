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

## If git repository is encountered

(when this function is not disabled by the config file)

Will create a file aside with the repo:

```sh
% tree
.
├── your-geneious-repo
│   ├── file-in-repo
│   ├── does-not-include-.git-directory
│   └── rest-of-your-repo
├── your-geneious-repo_git_repository.txt
└── your-other-files

% cat your-geneious-repo_git_repository.txt
============ git repository information ============
Date: Sun Jul 19 12:16:26 CEST 2025
Commit Hash: 36f8odkvidufb518b5c3b727aa2f709d37372828
Remote(s):
origin: git@github.com:you/your-geneious-repo.git
Git Status:
Working directory clean
============ git repository information ============
Date: Sun Jul 20 14:09:18 CEST 2025
Commit Hash: 5dg3bdhcidufb518b5c3b727aa2f709d301us64y
Remote(s):
origin: git@github.com:you/your-geneious-repo.git
backup: git@gitlab.com:your-institute/your-geneious-repo.git
Git Status:
 M file-modified.txt
A  file-added.txt
?? file-untracted.txt
 D file-deleted.txt
```


---

**Version 2.2 changes:**
- All settings (remote, path, operation, excludes, etc.) are now in `sync-with-rclone.config`.
- The main script (`sync-with-rclone.sh`) loads settings from this config file.
- You must keep `sync-with-rclone.config` in the same directory as the script.
- The script will error if the config file is missing.
- The `-y` option is now supported to skip confirmation prompts.

**Version 2.3 changes:**
- Git repository is processed in a better way, example given above
    - now recording
        - Date and time of pushing to cloud
        - All remote URLs
        - Current commit hash
        - Current `git status` output
    - Pulling from cloud will not trigger this
    - Will not record if the repository has not been changed since the last push, comparing all except date and time
    - The record file now appears side to side with the repository root directory, with the same name. It is not saved inside the git repository anymore.
