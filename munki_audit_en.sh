#!/bin/bash

# =================CONFIGURATION=================
CONFIG_FILE="$HOME/.munki_audit.conf"
PREFIX="app_"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Output Filenames
OUT_APPS_FULL="Export_Apps_Complete.csv"
OUT_APPS_UNIQUE="Export_Apps_Unique_Clean.csv"
OUT_OTHERS_FULL="Export_Others_Complete.csv"
OUT_OTHERS_UNIQUE="Export_Others_Unique.csv"
# ===============================================

# Load Config
load_config() {
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    REPO_PATH=""
fi
}

# Save Config
save_config() {
echo "REPO_PATH=\"$REPO_PATH\"" > "$CONFIG_FILE"
}

pause() {
echo ""
read -p "Press [Enter] to continue..."
}

# Progress Bar Function
draw_progress_bar() {
local _current=$1
local _total=$2
local _width=$(tput cols 2>/dev/null || echo 80)
local _bar_size=$(( _width - 25 ))
local _percent=$(( 100 * _current / _total ))
local _filled=$(( _percent * _bar_size / 100 ))
local _empty=$(( _bar_size - _filled ))

printf "\r["
printf "%0.s#" $(seq 1 $_filled)
if [ $_empty -gt 0 ]; then
    printf "%0.s." $(seq 1 $_empty)
fi
printf "] %d%% (%d/%d)" "$_percent" "$_current" "$_total"
}

# === MAIN AUDIT FUNCTION ===
run_audit() {
clear
echo -e "${BLUE}=== Munki Repository Audit ===${NC}"

if [ -z "$REPO_PATH" ] || [ ! -d "$REPO_PATH/manifests" ]; then
    echo -e "${RED}ERROR: No valid Munki repository configured.${NC}"
    echo "Please go to Settings and set the path."
    pause
    return
fi

echo "Initializing file list from: $REPO_PATH/manifests"

# Fill array (compatible with older bash versions on macOS)
file_list=()
while IFS=  read -r -d $'\0'; do
    file_list+=("$REPLY")
done < <(find "$REPO_PATH/manifests" -type f -not -name '.*' -print0)

total_files=${#file_list[@]}

if [ "$total_files" -eq 0 ]; then
    echo -e "${RED}No manifest files found!${NC}"
    pause
    return
fi

echo "Found manifests: $total_files"
echo "Starting analysis..."
echo ""

TMP_APPS=$(mktemp)
TMP_OTHERS=$(mktemp)
KEYS=("managed_installs" "optional_installs" "managed_uninstalls" "featured_items")

current_count=0

for manifest_file in "${file_list[@]}"; do
    ((current_count++))
    draw_progress_bar $current_count $total_files
    
    rel_path="${manifest_file#$REPO_PATH/manifests/}"

    for key in "${KEYS[@]}"; do
        # Extract JSON using plutil
        json_output=$(plutil -extract "$key" json -o - "$manifest_file" 2>/dev/null)
        
        if [ $? -eq 0 ]; then
            items=$(echo "$json_output" | tr -d '[]"' | tr ',' '\n' | sed '/^$/d' | sed 's/^[ \t]*//')

            while read -r item; do
                if [[ -n "$item" ]]; then
                    if [[ "$item" == "$PREFIX"* ]]; then
                        echo "$rel_path;$key;$item" >> "$TMP_APPS"
                    else
                        echo "$rel_path;$key;$item" >> "$TMP_OTHERS"
                    fi
                fi
            done <<< "$items"
        fi
    done
done

echo -e "\n\n${GREEN}Parsing complete! Creating CSV files...${NC}"

# EXPORTS
echo "Manifest;Section;Object" > "$OUT_APPS_FULL"
[ -s "$TMP_APPS" ] && sort -t';' -k3,3 -k1,1 -f "$TMP_APPS" >> "$OUT_APPS_FULL"

echo "Program Name" > "$OUT_APPS_UNIQUE"
[ -s "$TMP_APPS" ] && cut -d';' -f3 "$TMP_APPS" | sed "s/^$PREFIX//" | sort -f | uniq >> "$OUT_APPS_UNIQUE"

echo "Manifest;Section;Object" > "$OUT_OTHERS_FULL"
[ -s "$TMP_OTHERS" ] && sort -t';' -k3,3 -k1,1 -f "$TMP_OTHERS" >> "$OUT_OTHERS_FULL"

echo "Object Name" > "$OUT_OTHERS_UNIQUE"
[ -s "$TMP_OTHERS" ] && cut -d';' -f3 "$TMP_OTHERS" | sort -f | uniq >> "$OUT_OTHERS_UNIQUE"

rm "$TMP_APPS" "$TMP_OTHERS"

echo "------------------------------------------------"
echo -e "${GREEN}Success! The following files were created:${NC}"
echo " - $OUT_APPS_FULL"
echo " - $OUT_APPS_UNIQUE"
echo " - $OUT_OTHERS_FULL"
echo " - $OUT_OTHERS_UNIQUE"
echo "------------------------------------------------"
pause
}

# === SETTINGS ===
configure_repo() {
while true; do
    clear
    echo -e "${BLUE}=== Settings ===${NC}"
    
    if [ -z "$REPO_PATH" ]; then
        echo -e "Current Path: ${RED}Not set${NC}"
    else
        echo -e "Current Path: ${GREEN}$REPO_PATH${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}PATH NOTE:${NC}"
    echo "Please enter the path to the ROOT folder of your Munki repo."
    echo "This is the folder containing subfolders like 'manifests', 'pkgsinfo', etc."
    echo ""
    echo -e "${CYAN}Correct:   /Users/Shared/munki_repo${NC}"
    echo -e "${RED}Wrong:     /Users/Shared/munki_repo/manifests${NC}"
    echo ""
    echo "Enter new path (or press Enter to cancel):"
    echo -n "> "
    read input_path

    if [ -z "$input_path" ]; then
        break
    fi

    input_path="${input_path%/}"

    if [ -d "$input_path/manifests" ]; then
        REPO_PATH="$input_path"
        save_config
        echo -e "${GREEN}Path saved successfully!${NC}"
        sleep 1.5
        break
    else
        echo ""
        echo -e "${RED}ERROR:${NC} Subfolder '/manifests' not found in this path."
        echo "Did you accidentally select the 'manifests' folder itself?"
        echo "Please select the parent folder."
        echo ""
        read -p "Press Enter to try again..."
    fi
done
}

# === HELP ===
show_help() {
clear
echo -e "${BLUE}=== Help & Technical Documentation ===${NC}"
echo ""
echo -e "${YELLOW}General:${NC}"
echo "This script scans the Munki repository for software assignments."
echo "It exports these assignments into CSV files compatible with Excel."
echo ""
echo -e "${YELLOW}Technical Details (for Support/IT):${NC}"
echo "------------------------------------------------"
echo -e "${CYAN}1. Security & Access:${NC}"
echo "   - The script requires **Read-Only** access to the repo."
echo "   - **No changes** are made to any manifest files."
echo "   - No data is sent to the internet (local processing only)."
echo ""
echo -e "${CYAN}2. Used Commands (macOS Native):${NC}"
echo -e "   - ${GREEN}find${NC}: Recursive search for manifest files."
echo -e "   - ${GREEN}plutil${NC}: Apple tool to parse XML manifests."
echo "     (Command: plutil -extract [key] json -o - [file])"
echo -e "   - ${GREEN}tr / sed / cut${NC}: Text processing to clean JSON data."
echo -e "   - ${GREEN}sort / uniq${NC}: Alphabetical sorting and deduplication."
echo ""
echo -e "${CYAN}3. Logic:${NC}"
echo "   - Each manifest file is checked for keys: 'managed_installs',"
echo "     'optional_installs', 'managed_uninstalls'."
echo "   - Extracted data is stored temporarily in RAM/Tmp."
echo "   - Difference 'Complete' vs 'Unique': Complete lists every assignment,"
echo "     Unique creates a clean inventory list."
echo "------------------------------------------------"
echo ""
pause
}

# === MAIN LOOP ===
load_config

while true; do
clear
echo -e "${BLUE}########################################${NC}"
echo -e "${BLUE}#       MUNKI MANIFEST EXPORTER        #${NC}"
echo -e "${BLUE}########################################${NC}"
echo ""

if [ -n "$REPO_PATH" ]; then
    echo -e "Repo Path: ${GREEN}$REPO_PATH${NC}"
else
    echo -e "Repo Path: ${RED}NOT CONFIGURED${NC}"
fi

echo ""
echo "1) Start Audit (CSV Export)"
echo "2) Settings (Change Path)"
echo "3) Help / Tech Info"
echo "4) Exit"
echo ""
echo -n "Select an option [1-4]: "
read choice

case $choice in
    1)
        run_audit
        ;;
    2)
        configure_repo
        ;;
    3)
        show_help
        ;;
    4)
        echo "Goodbye!"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid selection.${NC}"
        sleep 1
        ;;
esac
done