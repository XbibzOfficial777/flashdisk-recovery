#!/bin/bash

# Script: Xbibz Recovery Flashdisk Repair
# Author: Xbibz Recovery



RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Variabel global
CURRENT_OS=""
SELECTED_DEVICE=""
LOG_FILE="xbibz_recovery_$(date +%Y%m%d_%H%M%S).log"

# Function untuk logging
log_message() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    echo -e "$2$1${NC}"
}

# Function untuk menampilkan header
show_header() {
    clear
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                                                          ║"
    echo "║           XBIBZ RECOVERY FLASHDISK REPAIR TOOL           ║"
    echo "║                GitHub : @XbibzOfficial777                ║"
    echo "║                                                          ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Function untuk error handling
error_exit() {
    log_message "ERROR: $1" "$RED"
    echo -e "${YELLOW}Check log file: $LOG_FILE${NC}"
    exit 1
}

# Function untuk deteksi OS
detect_os() {
    log_message "Detecting operating system..." "$CYAN"
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [[ -f /etc/arch-release ]]; then
            CURRENT_OS="Arch"
        elif [[ -f /etc/debian_version ]]; then
            CURRENT_OS="Debian"
        else
            CURRENT_OS="Linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        CURRENT_OS="macOS"
    elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        CURRENT_OS="Windows"
    else
        error_exit "Unsupported operating system"
    fi
    
    log_message "Operating System detected: $CURRENT_OS" "$GREEN"
}

# Function untuk check dependencies
check_dependencies() {
    log_message "Checking dependencies..." "$CYAN"
    
    local missing_deps=()
    
    case $CURRENT_OS in
        "Linux"|"Arch"|"Debian")
            command -v lsblk >/dev/null 2>&1 || missing_deps+=("lsblk")
            command -v mount >/dev/null 2>&1 || missing_deps+=("mount")
            command -v umount >/dev/null 2>&1 || missing_deps+=("umount")
            command -v fsck >/dev/null 2>&1 || missing_deps+=("fsck")
            command -v mkfs.vfat >/dev/null 2>&1 || missing_deps+=("dosfstools")
            command -v badblocks >/dev/null 2>&1 || missing_deps+=("badblocks")
            ;;
        "Windows")
            command -v diskpart >/dev/null 2>&1 || missing_deps+=("diskpart")
            command -v chkdsk >/dev/null 2>&1 || missing_deps+=("chkdsk")
            ;;
        "macOS")
            command -v diskutil >/dev/null 2>&1 || missing_deps+=("diskutil")
            command -v fsck_msdos >/dev/null 2>&1 || missing_deps+=("fsck_msdos")
            ;;
    esac
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        error_exit "Missing dependencies: ${missing_deps[*]}"
    fi
    
    log_message "All dependencies satisfied" "$GREEN"
}

# Function untuk list devices
list_devices() {
    log_message "Scanning for storage devices..." "$CYAN"
    
    case $CURRENT_OS in
        "Linux"|"Arch"|"Debian")
            echo -e "${YELLOW}Available storage devices:${NC}"
            lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE | grep -v "loop"
            ;;
        "Windows")
            echo -e "${YELLOW}Available storage devices:${NC}"
            wmic diskdrive get deviceid,size,model 2>/dev/null || \
            echo "Please run as Administrator for full device list"
            ;;
        "macOS")
            echo -e "${YELLOW}Available storage devices:${NC}"
            diskutil list
            ;;
    esac
}

# Function untuk validasi device
validate_device() {
    local device=$1
    
    if [ -z "$device" ]; then
        return 1
    fi
    
    case $CURRENT_OS in
        "Linux"|"Arch"|"Debian")
            if lsblk | grep -q "^$device"; then
                return 0
            fi
            ;;
        "Windows")
            # Validasi dasar untuk Windows
            if [[ "$device" =~ ^[a-zA-Z]:?$ ]]; then
                return 0
            fi
            ;;
        "macOS")
            if diskutil list | grep -q "$device"; then
                return 0
            fi
            ;;
    esac
    
    return 1
}

# Function untuk unmount device
unmount_device() {
    local device=$1
    log_message "Unmounting device: $device" "$YELLOW"
    
    case $CURRENT_OS in
        "Linux"|"Arch"|"Debian")
            for mount_point in $(mount | grep "$device" | awk '{print $3}'); do
                umount "$mount_point" 2>/dev/null && \
                log_message "Successfully unmounted: $mount_point" "$GREEN" || \
                log_message "Could not unmount: $mount_point" "$RED"
            done
            ;;
        "Windows")
            # Unmount di Windows
            diskpart << EOF > /dev/null 2>&1
select volume $device
remove all
exit
EOF
            ;;
        "macOS")
            diskutil unmountDisk "$device" > /dev/null 2>&1 && \
            log_message "Successfully unmounted device" "$GREEN" || \
            log_message "Could not unmount device" "$RED"
            ;;
    esac
}

# Function untuk repair filesystem
repair_filesystem() {
    local device=$1
    log_message "Starting filesystem repair..." "$CYAN"
    
    case $CURRENT_OS in
        "Linux"|"Arch"|"Debian")
            # Repair dengan fsck
            log_message "Running filesystem check..." "$YELLOW"
            fsck -y "/dev/$device" 2>&1 | tee -a "$LOG_FILE"
            local result=$?
            
            if [ $result -eq 0 ] || [ $result -eq 1 ]; then
                log_message "Filesystem repair completed successfully" "$GREEN"
            else
                log_message "Filesystem repair encountered errors" "$RED"
                return 1
            fi
            ;;
        "Windows")
            # Repair dengan chkdsk
            log_message "Running CHKDSK..." "$YELLOW"
            chkdsk "$device:" /f /r /x 2>&1 | tee -a "$LOG_FILE"
            ;;
        "macOS")
            # Repair dengan diskutil
            log_message "Running Disk Utility repair..." "$YELLOW"
            diskutil repairVolume "$device" 2>&1 | tee -a "$LOG_FILE"
            ;;
    esac
    
    return 0
}

# Function untuk bad sector check
check_bad_sectors() {
    local device=$1
    log_message "Checking for bad sectors..." "$CYAN"
    
    case $CURRENT_OS in
        "Linux"|"Arch"|"Debian")
            log_message "Running badblocks check..." "$YELLOW"
            badblocks -v "/dev/$device" 2>&1 | tee -a "$LOG_FILE"
            ;;
        "Windows")
            log_message "Bad sector check via CHKDSK..." "$YELLOW"
            chkdsk "$device:" /r 2>&1 | tee -a "$LOG_FILE"
            ;;
        "macOS")
            log_message "cek error di flashdisk..." "$YELLOW"
            diskutil verifyVolume "$device" 2>&1 | tee -a "$LOG_FILE"
            ;;
    esac
}


format_device() {
    local device=$1
    log_message "Tw format device..." "$YELLOW"
    
    echo -e "${RED}WARNING: hapus all data device!${NC}"
    read -p "lu setuju ga? (y/N): " confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_message "Operasi di hentikan oleh suki user" "$YELLOW"
        return 1
    fi
    
    case $CURRENT_OS in
        "Linux"|"Arch"|"Debian")
            log_message "Format Device Berjalan..." "$CYAN"
            mkfs.vfat -F 32 -n "XBIBZ_RECOVERY" "/dev/$device" 2>&1 | tee -a "$LOG_FILE"
            ;;
        "Windows")
            log_message "Formatting device with FAT32..." "$CYAN"
            format "$device:" /FS:FAT32 /Q /Y 2>&1 | tee -a "$LOG_FILE"
            ;;
        "macOS")
            log_message "Formatting device with FAT32..." "$CYAN"
            diskutil eraseDisk FAT32 XBIBZ_RECOVERY MBRFormat "$device" 2>&1 | tee -a "$LOG_FILE"
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        log_message "Format completed successfully" "$GREEN"
    else
        error_exit "Format operation failed"
    fi
}


show_main_menu() {
    while true; do
        show_header
        echo -e "${WHITE}Selected Device: ${GREEN}$SELECTED_DEVICE${NC}"
        echo ""
        echo -e "${CYAN}Please choose an option:${NC}"
        echo -e "1. Scan and list storage devices"
        echo -e "2. Select device for repair"
        echo -e "3. Unmount device"
        echo -e "4. Repair filesystem"
        echo -e "5. Check for bad sectors"
        echo -e "6. Format device (WILL ERASE ALL DATA)"
        echo -e "7. Show system information"
        echo -e "8. View repair log"
        echo -e "9. Exit"
        echo ""
        read -p "Enter your choice [1-9]: " choice
        
        case $choice in
            1)
                list_devices
                ;;
            2)
                read -p "Enter device name (e.g., sdb1, D:, disk2s1): " device
                if validate_device "$device"; then
                    SELECTED_DEVICE="$device"
                    log_message "Device selected: $device" "$GREEN"
                else
                    log_message "Invalid device: $device" "$RED"
                fi
                ;;
            3)
                if [ -n "$SELECTED_DEVICE" ]; then
                    unmount_device "$SELECTED_DEVICE"
                else
                    log_message "No device selected" "$RED"
                fi
                ;;
            4)
                if [ -n "$SELECTED_DEVICE" ]; then
                    repair_filesystem "$SELECTED_DEVICE"
                else
                    log_message "No device selected" "$RED"
                fi
                ;;
            5)
                if [ -n "$SELECTED_DEVICE" ]; then
                    check_bad_sectors "$SELECTED_DEVICE"
                else
                    log_message "No device selected" "$RED"
                fi
                ;;
            6)
                if [ -n "$SELECTED_DEVICE" ]; then
                    format_device "$SELECTED_DEVICE"
                else
                    log_message "No device selected" "$RED"
                fi
                ;;
            7)
                show_system_info
                ;;
            8)
                if [ -f "$LOG_FILE" ]; then
                    less "$LOG_FILE"
                else
                    log_message "Log file not found" "$RED"
                fi
                ;;
            9)
                log_message "Thank you for using Xbibz Recovery Tool!" "$GREEN"
                exit 0
                ;;
            *)
                log_message "Invalid option, please try again" "$RED"
                ;;
        esac
        
        echo ""
        read -p "klik enter..."
    done
}


show_system_info() {
    log_message "System Information:" "$CYAN"
    echo -e "${YELLOW}Operating System: $CURRENT_OS${NC}"
    echo -e "${YELLOW}Kernel: $(uname -r)${NC}"
    echo -e "${YELLOW}Architecture: $(uname -m)${NC}"
    echo -e "${YELLOW}Current User: $(whoami)${NC}"
    echo -e "${YELLOW}Log File: $LOG_FILE${NC}"
}


main() {
    
    if [[ $EUID -eq 0 ]]; then
        log_message "Running with root privileges" "$GREEN"
    else
        echo -e "${YELLOW}Warning: Some operations may require root/administrator privileges${NC}"
    fi
    
    # Initialize
    detect_os
    check_dependencies
    
    
    touch "$LOG_FILE"
    log_message "Xbibz Recovery Tool started." "$GREEN"
    log_message "OS: $CURRENT_OS" "$CYAN"
    
    
    show_main_menu
}


trap 'error_exit "Keyboard intreerupt"' SIGINT
trap 'error_exit "Script terminated unexpectedly"' SIGTERM


main "$@"