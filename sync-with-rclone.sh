#!/bin/bash
#
# sync-with-rclone.sh
#   One command sync/copy between local and remote directories,
#   using rclone. Made for simplicity and efficiency (reduce unnecessary transfer of useless small files).
#     Meaning:
#       1. Built-in ignore list for common "no need to backup" files
#       2. Only record git commit hash for git repositories, without syncing .git directories
#       3. Supports both pull and push operations
#       4. Configure once, use forever
#     Will **not** implement for a reason:
#       1. Create remote subdirectory if it does not exist
# Author: Chao Du
# Version: 2.3 (2025-07-19)
# Created: 2024-02-11
# Repository: https://github.com/IBL-bioinfo/sync-with-rclone

# Load project-specific variables from config file
CONFIG_FILE="$(dirname "$0")/sync-with-rclone.config"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Config file '$CONFIG_FILE' not found. Please copy a template from"
    echo "       repository and modify it to set your parameters."
    exit 1
fi
# shellcheck source=sync-with-rclone.config
. "$CONFIG_FILE"

# ====== Change and check parameters in sync-with-rclone.config ======================
# ==================== Do not change anything below this line ========================

readonly LOCAL_PATH="." # Local project path (current directory)
# Exclude .git and python temporary files
exclude+=(
    "**/.git/" "**/__pycache__/" "*.pyc"
    "*.pyo" "*.pyd" "*.swp" "*.swo" "*.swn" "*.bak" "*.tmp"
)

# Store script name as a relative path
SCRIPT_NAME="$0"

# Function to display usage
usage() {
    echo "Usage: modify the variables in the script and run
    $SCRIPT_NAME pull|push [--include <subdirectory>] [additional rclone parameters]"
    cat <<EOF

Description:
  One command sync/copy between local and remote directories using rclone.
  Made for simplicity and efficiency (reduces unnecessary transfer of useless small files).
  
  Features:
  - Built-in ignore list for common "no need to backup" files
  - Records git commit hash for git repositories, without syncing .git directories
  - Supports both pull and push operations
  - Configure once, use forever
  
  Choose "pull" to download from the remote to the local path, or "push" to upload
  from the local path to the remote. If git repositories are found in the local path,
  the latest commit hash is recorded in a git repository info file for each repository.
  The .git directories are excluded from syncing by default.
  
Options:
  -h, --help
      Show this help message and exit.
  -y
      Skip confirmation prompts and run non-interactively (no user confirmation needed).
  --include <subdirectory>
      Temporary pull or push only the specified subdirectory. If the subdirectory
      does not exist remotely, the script will prompt you to create it.
      The first --include option sets the remote path; subsequent --include options
      are passed directly to rclone.
  
  [additional rclone parameters]
      Any extra parameters you want to pass to rclone (e.g., --dry-run, --exclude).
  
Notes:
  1. The options --progress and --links are always included. On "pull," the script adds
     "--exclude \$SCRIPT_NAME" to avoid deleting itself.
  2. Setting ALLOW_PULL=false or ALLOW_PUSH=false disables that specific direction.
  
Examples:
  $SCRIPT_NAME pull
  $SCRIPT_NAME push --include src --dry-run

EOF
    exit 1
}

# Show help
if [[ $# -lt 1 || "$1" == "-h" || "$1" == "--help" ]]; then
    usage
fi

# Parse -y argument for no confirmation
NO_CONFIRM=false
NEW_ARGS=()
for arg in "$@"; do
    if [[ "$arg" == "-y" ]]; then
        NO_CONFIRM=true
        continue
    fi
    NEW_ARGS+=("$arg")
    # skip empty args
done
set -- "${NEW_ARGS[@]}"

if [[ "$REMOTE_PATH" == "" ]]; then
    echo "Error: Please set the REMOTE_PATH variable in the script."
    usage
    exit 1
fi
if [[ "$OPERATION" == "" ]]; then
    echo "Error: Please set the OPERATION variable in the script."
    usage
    exit 1
fi

valid_operations=("sync" "copy")
if ! printf '%s\n' "${valid_operations[@]}" | grep -qx "$OPERATION"; then
    echo "Error: OPERATION must be 'sync' or 'copy'."
    exit 1
fi
if [[ ! -d "$LOCAL_PATH" ]]; then
    echo "Error: LOCAL_PATH '$LOCAL_PATH' is not a directory."
    exit 1
fi

# Get sync direction first
SYNC_DIRECTION="$1"
shift
if [[ "$SYNC_DIRECTION" == "pull" ]]; then
    if [[ "$ALLOW_PULL" != true ]]; then
        echo "Pulling is disabled."
        exit 1
    fi
elif [[ "$SYNC_DIRECTION" == "push" ]]; then
    if [[ "$ALLOW_PUSH" != true ]]; then
        echo "Pushing is disabled."
        exit 1
    fi
else
    echo "Error: SYNC_DIRECTION can only be 'pull' or 'push'."
    exit 1
fi

# Deal with --include argument
if [[ "$1" == "--include" ]]; then
    if [[ -n "$2" ]]; then
        include_path="$2"
        remote_path_final="${REMOTE_PATH%/}/$include_path"
        local_path_final="${LOCAL_PATH%/}/$include_path"
        shift 2
    else
        echo "Error: --include requires a subdirectory argument."
        exit 1
    fi
else
    remote_path_final="$REMOTE_PATH"
    local_path_final="$LOCAL_PATH"
fi

# Capture any additional rclone parameters
EXTRA_PARAMS=("$@")

# Ensure rclone is installed
if ! command -v rclone &>/dev/null; then
    echo "Error: rclone is not installed. Please install rclone first."
    exit 1
fi

# Print rclone version
echo "Using rclone version: $(rclone version | awk 'NR==1{print $2}')"

# Check if the remote directory exists
if [[ "$REMOTE_PATH" == "__test" ]]; then
    echo "Warning: The remote path is set to '__test'. Please change it to the actual path."
    echo "Skipping remote path existence check."
else
    if ! rclone config show "$REMOTE_NAME" &>/dev/null; then
        echo "Error: Rclone remote '$REMOTE_NAME' does not exist."
        exit 1
    fi
    if ! rclone lsjson "$REMOTE_NAME:$remote_path_final" &>/dev/null; then
        # Separate the checks to avoid parse errors
        if [[ -n "$include_path" ]] && rclone lsjson "$REMOTE_NAME:$REMOTE_PATH" &>/dev/null; then
            echo "Warning: Specified subdirectory '$include_path' does not exist remotely."
            if [[ "$NO_CONFIRM" == true ]]; then
                confirm="y"
            else
                echo -n "Do you want to create it? (y/n) "
                read confirm
            fi
            if [[ "$confirm" != "y" ]]; then
                echo "Aborting operation."
                exit 1
            fi
            rclone mkdir "$REMOTE_NAME:$remote_path_final" || {
                echo "Failed to create remote directory"
                exit 1
            }
        else
            echo "Error: Remote directory $REMOTE_NAME:$REMOTE_PATH does not exist."
            exit 1
        fi
    fi
fi

# Construct the rclone command
cmd=("rclone" "$OPERATION")
rclone_paras=("--progress" "--links" "--use-cookies" "--transfers" "4" "--timeout" "60m")
# Check if EXTRA_PARAMS contains --transfers and --timeout, if so,
# remove them from rclone_paras, they will be added later with EXTRA_PARAMS.
for ((i = 0; i < ${#EXTRA_PARAMS[@]}; i++)); do
    case "${EXTRA_PARAMS[i]}" in
    # Check from back to front to avoid index issues
    --timeout)
        rclone_paras=("${rclone_paras[@]:0:5}" "${rclone_paras[@]:7}")
        ((i++)) # Skip the next value as it is the associated value
        ;;
    --transfers)
        rclone_paras=("${rclone_paras[@]:0:3}" "${rclone_paras[@]:5}")
        ((i++))
        ;;
    esac
done

if [[ "$SYNC_DIRECTION" == "pull" ]]; then
    echo "Pull from ${REMOTE_NAME}:${remote_path_final} to ${local_path_final}."
    src="${REMOTE_NAME}:${remote_path_final}"
    dest="${local_path_final}"
    rclone_paras+=("--exclude" "$(basename -- "$SCRIPT_NAME")")
    rclone_paras+=("--exclude" "$(basename -- "$CONFIG_FILE")")
elif [[ "$SYNC_DIRECTION" == "push" ]]; then
    echo "Push from ${local_path_final} to ${REMOTE_NAME}:${remote_path_final}."
    src="${local_path_final}"
    dest="${REMOTE_NAME}:${remote_path_final}"
else
    : # Do nothing, already checked above
fi

# Add exclude patterns from exclude array
for pattern in "${exclude[@]}"; do
    rclone_paras+=("--exclude" "$pattern")
done

# Function to scan directories and subdirectories for .git directories and record the latest commit hash
scan_and_record_git_commit() {
    local dir="$1"
    # Check if the directory exists
    if [[ ! -d "$dir" ]]; then
        echo "Directory $dir does not exist, skip git repository scan."
        return 1
    fi
    # Check if the directory is empty
    if ! find "$dir" -mindepth 1 -maxdepth 1 | read -r; then
        return 1
    fi
    local found_repos=1 # 1 indicates no repos found initially (false)
    for subdir in "$dir"/*; do
        if [[ ! -d "$subdir" ]]; then
            continue
        elif [[ -d "$subdir/.git" ]]; then
            echo "Found git repository $subdir"
            if commit_hash=$(git -C "$subdir" rev-parse HEAD); then
                found_repos=0 # 0 indicates repos found (true)
                remote_url=$(git -C "$subdir" config --get remote.origin.url)
                git_status=$(git -C "$subdir" status --porcelain)
                git_status_line=""
                if [[ -n "$git_status" ]]; then
                    # Clean up git status by removing empty lines and normalizing line endings
                    git_status_line=$(echo "$git_status" | sed 's/\r$//' | sed '/^$/d')
                else
                    git_status_line="Working directory clean"
                fi
                # Record git repository information
                subdir_name=$(basename "$subdir")
                git_info_file="$(dirname "$subdir")/${subdir_name}_git_repository.txt"

                # Check if we need to update the record
                needs_update=true
                if [[ -f "$git_info_file" ]]; then
                    # Extract previous commit hash from existing file
                    prev_commit=$(grep "^Commit Hash:" "$git_info_file" 2>/dev/null | cut -d' ' -f3-)
                    # Extract previous git status (all lines after "Git Status:" until next section or EOF)
                    prev_status=""
                    if grep -q "^Git Status:" "$git_info_file" 2>/dev/null; then
                        # Get the last occurrence of "Git Status:" and extract content after it
                        # Find the line number of the last "Git Status:" occurrence
                        last_git_status_line=$(grep -n "^Git Status:" "$git_info_file" 2>/dev/null | tail -1 | cut -d: -f1)
                        if [[ -n "$last_git_status_line" ]]; then
                            # Get all lines after the last "Git Status:" until next "====" or EOF
                            prev_status=$(sed -n "${last_git_status_line},/^====/p" "$git_info_file" 2>/dev/null | sed '1d;$d' | sed 's/\r$//' | sed '/^$/d')
                            # If no "====" line found after the last "Git Status:", get from there to EOF
                            if [[ -z "$prev_status" ]]; then
                                prev_status=$(sed -n "${last_git_status_line},\$p" "$git_info_file" 2>/dev/null | sed '1d' | sed 's/\r$//' | sed '/^$/d')
                            fi
                        fi
                    fi

                    # Compare current status with previous
                    if [[ "$prev_commit" == "$commit_hash" && "$prev_status" == "$git_status_line" ]]; then
                        needs_update=false
                        echo "Git repository info unchanged for $subdir, skipping update"
                    fi
                fi

                if [[ "$needs_update" == true ]]; then
                    # Write new git repository information by appending
                    echo "============ git repository information ============" >>"$git_info_file"
                    echo "Date: $(date)" >>"$git_info_file"
                    echo "Remote URL: $remote_url" >>"$git_info_file"
                    echo "Commit Hash: $commit_hash" >>"$git_info_file"
                    echo "Git Status:" >>"$git_info_file"
                    echo "$git_status_line" >>"$git_info_file"
                    echo "Recorded commit hash for $subdir: $commit_hash"
                fi
            else
                echo "Warning: Failed to record commit hash for $subdir"
            fi
        else
            scan_and_record_git_commit "$subdir"
            local subdir_found_repos=$?
            # Update found_repos if subdir found any repos (0 indicates found)
            if [[ $subdir_found_repos -eq 0 ]]; then
                found_repos=0
            fi
        fi
    done
    return $found_repos # Return 0 if any repos found, else 1
}

if [[ "$RECORD_GIT_COMMIT" == true && "$SYNC_DIRECTION" == "push" ]]; then
    echo "Searching git repositories..."
    scan_and_record_git_commit "$local_path_final"
    found_repos=$?
    if scan_and_record_git_commit "$local_path_final"; then
        echo "Git repositories found and recorded."
    else
        echo "No git repositories found in '$local_path_final'"
    fi
fi
# Use array expansion to preserve quoted arguments
cmd+=("$src" "$dest" "${rclone_paras[@]}" "${EXTRA_PARAMS[@]}")

echo "Final rclone command:"
printf "%q " "${cmd[@]}"
echo

if [[ "$NO_CONFIRM" == true ]]; then
    confirm="y"
else
    echo -n "Confirm? (y/n) "
    read confirm
fi
if [[ "$confirm" != "y" ]]; then
    echo "Aborting operation."
    exit 1
fi
if [[ "$REMOTE_PATH" == "__test" ]]; then
    echo "Warning: Test mode is enabled. The command will not be executed."
else
    # Execute the command using array expansion
    "${cmd[@]}"
fi
