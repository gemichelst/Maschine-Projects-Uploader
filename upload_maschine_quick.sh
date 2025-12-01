#!/bin/bash

# Quick preset configurations
show_menu() {
    clear
    echo "╔════════════════════════════════════════╗"
    echo "║   MASCHINE Upload Quick Launch         ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    echo "  1) Last 2 hours - All files"
    echo "  2) Last 4 hours - MASCHINE projects only"
    echo "  3) Last 8 hours - MASCHINE + Audio (default)"
    echo "  4) Last 24 hours - All files"
    echo "  5) Custom (interactive mode)"
    echo ""
    read -p "Select preset (1-5): " choice
    
    case $choice in
        1)
            export QUICK_HOURS=2
            export QUICK_FILTER="all"
            ;;
        2)
            export QUICK_HOURS=4
            export QUICK_FILTER="mxprj"
            ;;
        3)
            export QUICK_HOURS=8
            export QUICK_FILTER="maschine_audio"
            ;;
        4)
            export QUICK_HOURS=24
            export QUICK_FILTER="all"
            ;;
        5)
            # Run full interactive script
            exec /bin/bash ~/.bin/upload_maschine_enhanced.sh
            exit 0
            ;;
        *)
            echo "Invalid choice"
            exit 1
            ;;
    esac
}

show_menu

# Run main script with preset
exec /bin/bash ~/.bin/upload_maschine_enhanced.sh
