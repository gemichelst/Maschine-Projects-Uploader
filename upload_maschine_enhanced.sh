#!/bin/bash

# ===== DATETIME ====
CURDATE=$(date +%d-%m-%Y"_"%H:%M:%S);

# ===== CONFIGURATION =====
SOURCE_FOLDER="/Volumes/STUDIO/PROJECTS/MASCHINE"
GDRIVE_FOLDER_ID=""
GDRIVE_FOLDER="FILES___${CURDATE}"
GDRIVE_REMOTE="gdrive:" # Your rclone remote name

# Time window options (uncomment one or pass as argument)
DEFAULT_HOURS=48

# File type filters (space-separated extensions)
# Leave empty to include all files: EXTENSIONS=""
EXTENSIONS="mxprj nki nksf nkm nkp wav aif aiff mp3 flac ogg m4a mid midi"
# Common MASCHINE extensions:
# - mxprj: Maschine project
# - nki/nksf/nkm/nkp: Native Instruments formats
# - Audio: wav, aif, aiff, mp3, flac, ogg, m4a
# - MIDI: mid, midi

# Exclude patterns (optional)
EXCLUDE_PATTERNS="*.backup *.tmp *~"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ===== FUNCTIONS =====

show_header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     MASCHINE Files Upload to Google Drive                 ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

format_size() {
    local size=$1
    if [ $size -lt 1024 ]; then
        echo "${size}B"
    elif [ $size -lt 1048576 ]; then
        echo "$(( size / 1024 ))KB"
    elif [ $size -lt 1073741824 ]; then
        echo "$(( size / 1048576 ))MB"
    else
        echo "$(( size / 1073741824 ))GB"
    fi
}

ask_time_window() {
    echo -e "${YELLOW}Time Window Selection:${NC}"
    echo "  1) Last 2 hours"
    echo "  2) Last 4 hours"
    echo "  3) Last 8 hours (default)"
    echo "  4) Last 12 hours"
    echo "  5) Last 24 hours"
    echo "  6) Last 48 hours"
    echo "  7) Custom hours"
    echo ""
    read -p "Select time window (1-7) [3]: " time_choice
    
    case $time_choice in
        1) HOURS=2 ;;
        2) HOURS=4 ;;
        3|"") HOURS=8 ;;
        4) HOURS=12 ;;
        5) HOURS=24 ;;
        6) HOURS=48 ;;
        7) 
            read -p "Enter number of hours: " custom_hours
            if [[ "$custom_hours" =~ ^[0-9]+$ ]]; then
                HOURS=$custom_hours
            else
                echo -e "${RED}Invalid input. Using default: 8 hours${NC}"
                HOURS=8
            fi
            ;;
        *)
            echo -e "${YELLOW}Invalid choice. Using default: 8 hours${NC}"
            HOURS=8
            ;;
    esac
    
    echo -e "${GREEN}✓ Time window set to: $HOURS hours${NC}\n"
}

ask_file_filters() {
    echo -e "${YELLOW}File Type Filter:${NC}"
    echo "  1) All files"
    echo "  2) MASCHINE projects only (.mxprj)"
    echo "  3) Audio files only"
    echo "  4) MASCHINE + Audio files (default)"
    echo "  5) Native Instruments formats only"
    echo "  6) Custom extensions"
    echo ""
    read -p "Select filter (1-6) [4]: " filter_choice
    
    case $filter_choice in
        1)
            EXTENSIONS=""
            echo -e "${GREEN}✓ Filter: All files${NC}"
            ;;
        2)
            EXTENSIONS="mxprj"
            echo -e "${GREEN}✓ Filter: MASCHINE projects (.mxprj)${NC}"
            ;;
        3)
            EXTENSIONS="wav aif aiff mp3 flac ogg m4a"
            echo -e "${GREEN}✓ Filter: Audio files${NC}"
            ;;
        4|"")
            EXTENSIONS="mxprj nki nksf nkm nkp wav aif aiff mp3 flac ogg m4a"
            echo -e "${GREEN}✓ Filter: MASCHINE + Audio files${NC}"
            ;;
        5)
            EXTENSIONS="mxprj nki nksf nkm nkp nkc nkb nks"
            echo -e "${GREEN}✓ Filter: Native Instruments formats${NC}"
            ;;
        6)
            read -p "Enter extensions (space-separated, e.g., 'mxprj wav mp3'): " custom_ext
            EXTENSIONS="$custom_ext"
            echo -e "${GREEN}✓ Filter: Custom ($EXTENSIONS)${NC}"
            ;;
        *)
            echo -e "${YELLOW}Invalid choice. Using default filter${NC}"
            EXTENSIONS="mxprj nki nksf nkm nkp wav aif aiff mp3 flac ogg m4a"
            ;;
    esac
    echo ""
}

build_find_command() {
    local find_cmd="find \"$SOURCE_FOLDER\" -type f -mtime -${HOURS}h"
    
    # Add extension filters
    if [ -n "$EXTENSIONS" ]; then
        find_cmd="$find_cmd \("
        first=true
        for ext in $EXTENSIONS; do
            if [ "$first" = true ]; then
                find_cmd="$find_cmd -iname \"*.$ext\""
                first=false
            else
                find_cmd="$find_cmd -o -iname \"*.$ext\""
            fi
        done
        find_cmd="$find_cmd \)"
    fi
    
    # Add exclude patterns
    if [ -n "$EXCLUDE_PATTERNS" ]; then
        for pattern in $EXCLUDE_PATTERNS; do
            find_cmd="$find_cmd ! -name \"$pattern\""
        done
    fi
    
    echo "$find_cmd"
}

show_file_list() {
    local temp_list=$1
    local total_size=0
    
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  #  │ Filename                          │ Size    │ Modified${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
    
    counter=1
    while IFS= read -r file; do
        filename=$(basename "$file")
        filesize=$(stat -f "%z" "$file")
        filesize_human=$(format_size $filesize)
        moddate=$(stat -f "%Sm" -t "%m/%d %H:%M" "$file")
        
        # Truncate filename if too long
        if [ ${#filename} -gt 32 ]; then
            display_name="${filename:0:29}..."
        else
            display_name="$filename"
        fi
        
        printf "${CYAN}║${NC} %-3d ${CYAN}│${NC} %-33s ${CYAN}│${NC} %-7s ${CYAN}│${NC} %s\n" \
            $counter "$display_name" "$filesize_human" "$moddate"
        
        total_size=$((total_size + filesize))
        ((counter++))
    done < "$temp_list"
    
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    
    local total_size_human=$(format_size $total_size)
    echo -e "${BLUE}Total: $(( counter - 1 )) files, $total_size_human${NC}\n"
}

confirm_upload() {
    local temp_list=$1
    local file_count=$2
    
    echo -e "${YELLOW}Upload Options:${NC}"
    echo "  y) Yes - Upload all files"
    echo "  s) Select - Choose specific files to upload"
    echo "  v) View - Show full file paths"
    echo "  n) No - Cancel upload"
    echo ""
    read -p "Choose action [y/s/v/n]: " -n 1 -r action
    echo -e "\n"
    
    case $action in
        [Yy])
            return 0
            ;;
        [Ss])
            select_files "$temp_list"
            return $?
            ;;
        [Vv])
            show_full_paths "$temp_list"
            confirm_upload "$temp_list" "$file_count"
            return $?
            ;;
        [Nn]|*)
            return 1
            ;;
    esac
}

show_full_paths() {
    local temp_list=$1
    echo -e "${CYAN}Full File Paths:${NC}\n"
    counter=1
    while IFS= read -r file; do
        echo "  $counter. $file"
        ((counter++))
    done < "$temp_list"
    echo ""
}

select_files() {
    local temp_list=$1
    local selected_list=$(mktemp)
    
    echo -e "${YELLOW}Enter file numbers to upload (e.g., 1 3 5-8 10):${NC}"
    echo -e "${BLUE}Type 'all' for all files, or 'cancel' to abort${NC}"
    read -p "> " selection
    
    if [ "$selection" = "cancel" ]; then
        rm "$selected_list"
        return 1
    fi
    
    if [ "$selection" = "all" ]; then
        cp "$temp_list" "$selected_list"
        SELECTED_FILES="$selected_list"
        return 0
    fi
    
    # Parse selection
    for item in $selection; do
        if [[ $item =~ ^([0-9]+)-([0-9]+)$ ]]; then
            # Range
            start=${BASH_REMATCH[1]}
            end=${BASH_REMATCH[2]}
            for i in $(seq $start $end); do
                sed -n "${i}p" "$temp_list" >> "$selected_list"
            done
        elif [[ $item =~ ^[0-9]+$ ]]; then
            # Single number
            sed -n "${item}p" "$temp_list" >> "$selected_list"
        fi
    done
    
    local selected_count=$(wc -l < "$selected_list" | tr -d ' ')
    if [ "$selected_count" -eq 0 ]; then
        echo -e "${RED}No files selected.${NC}"
        rm "$selected_list"
        return 1
    fi
    
    echo -e "${GREEN}Selected $selected_count file(s) for upload.${NC}\n"
    SELECTED_FILES="$selected_list"
    return 0
}

upload_files() {
    local file_list=$1
    local upload_count=0
    local error_count=0
    local skipped_count=0
    local total_files=$(wc -l < "$file_list" | tr -d ' ')
    
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║                    Uploading Files...                      ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}\n"
    
    current=0
    while IFS= read -r file; do
        ((current++))
        filename=$(basename "$file")
        filesize=$(stat -f "%z" "$file")
        filesize_human=$(format_size $filesize)
        
        # Truncate filename for display
        if [ ${#filename} -gt 40 ]; then
            display_name="${filename:0:37}..."
        else
            display_name="$filename"
        fi
        
        echo -ne "  [$current/$total_files] ${display_name} (${filesize_human}) ... "
        
        # Check if file exists on Google Drive
        # rclone copy will overwrite by default, but we can check first
        
        # Upload using rclone
        if rclone copy "$file" "${GDRIVE_REMOTE}${GDRIVE_FOLDER}" \
            --progress=false \
            --drive-use-trash=false \
            --transfers=1 \
            2>/dev/null; then
            echo -e "${GREEN}✓ Uploaded${NC}"
            ((upload_count++))
        else
            echo -e "${RED}✗ Failed${NC}"
            ((error_count++))
        fi
        
    done < "$file_list"
    
    # Summary
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    Upload Summary                          ║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
    printf "${CYAN}║${NC} ${GREEN}Successful:${NC} %-46d ${CYAN}║${NC}\n" $upload_count
    if [ "$error_count" -gt 0 ]; then
        printf "${CYAN}║${NC} ${RED}Failed:${NC}     %-46d ${CYAN}║${NC}\n" $error_count
    fi
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}\n"
    
    # Open Google Drive folder in browser
    read -p "Open Google Drive folder in browser? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open "https://drive.google.com/drive/folders/${GDRIVE_FOLDER_ID}"
    fi
}

# ===== MAIN SCRIPT =====

show_header

# Check prerequisites
if [ ! -d "$SOURCE_FOLDER" ]; then
    echo -e "${RED}Error: Source folder does not exist: $SOURCE_FOLDER${NC}"
    exit 1
fi

if ! command -v rclone &> /dev/null; then
    echo -e "${RED}Error: rclone is not installed.${NC}"
    echo -e "${YELLOW}Install with: brew install rclone${NC}"
    exit 1
fi

# Interactive configuration
ask_time_window
ask_file_filters

# Find files
echo -e "${YELLOW}Searching for files...${NC}"
TEMP_LIST=$(mktemp)

# Build and execute find command
FIND_CMD=$(build_find_command)
eval "$FIND_CMD -print0" | while IFS= read -r -d '' file; do
    echo "$file" >> "$TEMP_LIST"
done

# Count files
FILE_COUNT=$(wc -l < "$TEMP_LIST" | tr -d ' ')

if [ "$FILE_COUNT" -eq 0 ]; then
    echo -e "${RED}No files found matching criteria.${NC}"
    rm "$TEMP_LIST"
    exit 0
fi

echo -e "${GREEN}Found $FILE_COUNT file(s)${NC}\n"

# Show file list
show_file_list "$TEMP_LIST"

# Confirm and potentially select files
if confirm_upload "$TEMP_LIST" "$FILE_COUNT"; then
    # Determine which file list to use
    if [ -n "$SELECTED_FILES" ]; then
        upload_files "$SELECTED_FILES"
        rm "$SELECTED_FILES"
    else
        upload_files "$TEMP_LIST"
    fi
else
    echo -e "${YELLOW}Upload cancelled.${NC}"
fi

# Cleanup
rm "$TEMP_LIST"

echo -e "${GREEN}Script completed.${NC}"
