#!/bin/bash

# ===== DATETIME ====
CURDATE=$(date +%d-%m-%Y"_"%H:%M:%S);

# Configuration
SOURCE_FOLDER="/Volumes/STUDIO/PROJECTS/MASCHINE"
HOURS=8
GDRIVE_FOLDER_ID=""
GDRIVE_FOLDER="FILES___${CURDATE}"
GDRIVE_REMOTE="gdrive:" # Your rclone remote name

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== MASCHINE Files Upload Script ===${NC}\n"

# Check if source folder exists
if [ ! -d "$SOURCE_FOLDER" ]; then
    echo -e "${RED}Error: Source folder does not exist: $SOURCE_FOLDER${NC}"
    exit 1
fi

# Check if rclone is configured
if ! command -v rclone &> /dev/null; then
    echo -e "${RED}Error: rclone is not installed. Install with: brew install rclone${NC}"
    exit 1
fi

# Find files modified in the last X hours
echo -e "${YELLOW}Searching for files modified in the last $HOURS hours...${NC}\n"

# Create temporary file list
TEMP_LIST=$(mktemp)

# Find files and store in temp file
find "$SOURCE_FOLDER" -type f -mtime -${HOURS}h -print0 | while IFS= read -r -d '' file; do
    echo "$file" >> "$TEMP_LIST"
done

# Count files
FILE_COUNT=$(wc -l < "$TEMP_LIST" | tr -d ' ')

if [ "$FILE_COUNT" -eq 0 ]; then
    echo -e "${RED}No files found modified in the last $HOURS hours.${NC}"
    rm "$TEMP_LIST"
    exit 0
fi

echo -e "${GREEN}Found $FILE_COUNT file(s):${NC}\n"

# Display files with size and modification date
counter=1
while IFS= read -r file; do
    filename=$(basename "$file")
    filesize=$(du -h "$file" | cut -f1)
    moddate=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$file")
    echo "  $counter. $filename (${filesize}, modified: $moddate)"
    ((counter++))
done < "$TEMP_LIST"

echo ""

# Ask for confirmation
read -p "Do you want to upload these files to Google Drive? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Upload cancelled.${NC}"
    rm "$TEMP_LIST"
    exit 0
fi

# Upload files
echo -e "\n${YELLOW}Uploading files...${NC}\n"

upload_count=0
error_count=0

while IFS= read -r file; do
    filename=$(basename "$file")
    echo -n "  Uploading: $filename ... "
    
    # Upload using rclone to the specific folder
    if rclone copy "$file" "${GDRIVE_REMOTE}${GDRIVE_FOLDER}" --drive-use-trash=false 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        ((upload_count++))
    else
        echo -e "${RED}✗${NC}"
        ((error_count++))
    fi
done < "$TEMP_LIST"

# Cleanup
rm "$TEMP_LIST"

# Summary
echo ""
echo -e "${GREEN}=== Upload Complete ===${NC}"
echo -e "  Successfully uploaded: $upload_count file(s)"
if [ "$error_count" -gt 0 ]; then
    echo -e "  ${RED}Errors: $error_count file(s)${NC}"
fi
echo ""
