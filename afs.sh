#!/bin/bash
# File: afs.sh
# Auto File Sorter for Linux
# Migrated from PowerShell to Bash
# Sorts files from source to destination directory with date-based folder structure

# Default configuration values
declare -A CONFIG
CONFIG[script_processing_lang]="EN"
CONFIG[search_filter_type]="extension"
CONFIG[search_filter]="jpg"
CONFIG[src_path]="/mnt/sorting_point"
CONFIG[dst_path]="/mnt/sorting_point"
CONFIG[destination_naming_pattern]="yyyy.MM.dd"
CONFIG[debug]="false"
CONFIG[scheduler]=""
CONFIG[interval]="repetitive"
CONFIG[repetitive_interval]="3600"
CONFIG[log_path]=""
CONFIG[config_file_name]="config.ini"
CONFIG[admin_mode]="false"
CONFIG[remove_logs_older_than]="30"

# Script variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_PATH="${SCRIPT_DIR}/config.ini"
TASK_NAME="AutoFileSorter"
CRON_COMMENT="# AutoFileSorter cron job"
DRY_RUN=false

# Localization strings
declare -A STRINGS_UA
STRINGS_UA[StartScript]="Початок виконання скрипта"
STRINGS_UA[EndScript]="Завершення виконання скрипта"
STRINGS_UA[FileProcessed]="Оброблено файл:"
STRINGS_UA[ErrorOccurred]="Виникла помилка:"
STRINGS_UA[FileIgnored]="Проігноровано файл:"
STRINGS_UA[ConfigLoaded]="Завантажено конфігурацію:"
STRINGS_UA[NoFilesFound]="Файлів для обробки не знайдено"
STRINGS_UA[TaskCreated]="Створено завдання в cron:"
STRINGS_UA[TaskRemoved]="Видалено завдання з cron:"
STRINGS_UA[TaskExists]="Завдання вже існує в cron:"
STRINGS_UA[TaskNotFound]="Завдання не знайдено в cron:"
STRINGS_UA[TestFilesGenerated]="Згенеровано тестові файли:"
STRINGS_UA[ConfigFileGenerated]="Згенеровано конфігураційний файл:"

declare -A STRINGS_EN
STRINGS_EN[StartScript]="Script execution started"
STRINGS_EN[EndScript]="Script execution completed"
STRINGS_EN[FileProcessed]="Processed file:"
STRINGS_EN[ErrorOccurred]="An error occurred:"
STRINGS_EN[FileIgnored]="Ignored file:"
STRINGS_EN[ConfigLoaded]="Configuration loaded:"
STRINGS_EN[NoFilesFound]="No files found for processing"
STRINGS_EN[TaskCreated]="Task created in cron:"
STRINGS_EN[TaskRemoved]="Task removed from cron:"
STRINGS_EN[TaskExists]="Task already exists in cron:"
STRINGS_EN[TaskNotFound]="Task not found in cron:"
STRINGS_EN[TestFilesGenerated]="Test files generated:"
STRINGS_EN[ConfigFileGenerated]="Configuration file generated:"

# Function to get localized string
get_localized_string() {
    local key=$1
    local lang=${CONFIG[script_processing_lang]}
    
    if [[ "$lang" == "UA" ]]; then
        echo "${STRINGS_UA[$key]}"
    else
        echo "${STRINGS_EN[$key]}"
    fi
}

# Function to read configuration file
read_config() {
    local config_file="${1:-$CONFIG_PATH}"
    
    if [[ ! -f "$config_file" ]]; then
        echo "Config file not found: $config_file"
        return 1
    fi
    
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^#.*$ ]] && continue
        [[ -z "$key" ]] && continue
        
        # Remove leading/trailing whitespace
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        
        # Store in CONFIG array
        if [[ -n "$key" && -n "$value" ]]; then
            CONFIG[$key]="$value"
        fi
    done < "$config_file"
    
    # Validate required parameters
    local required_params=("interval" "repetitive_interval" "src_path" "dst_path")
    for param in "${required_params[@]}"; do
        if [[ -z "${CONFIG[$param]}" ]]; then
            echo "Configuration error: Missing or empty required parameter '$param'"
            return 1
        fi
    done
    
    # Validate interval value
    if [[ "${CONFIG[interval]}" != "on-boot" && "${CONFIG[interval]}" != "repetitive" && "${CONFIG[interval]}" != "once" ]]; then
        echo "Configuration error: Invalid value for 'interval'. Must be 'on-boot', 'repetitive', or 'once'."
        return 1
    fi
    
    return 0
}

# Function for logging
write_log() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_message="[$timestamp] [$level] $message"
    
    # Determine log path
    local log_path="${CONFIG[log_path]}"
    if [[ -z "$log_path" ]]; then
        log_path="${SCRIPT_DIR}/script_logs"
    else
        log_path=$(dirname "$log_path")
    fi
    
    # Create log directory if it doesn't exist
    mkdir -p "$log_path"
    
    # Create log file name with date
    local log_file="${log_path}/log_$(date '+%d-%m-%Y').txt"
    
    # Write to log file
    echo "$log_message" >> "$log_file"
    
    # Display if in admin mode or once mode or debug mode
    if [[ "${CONFIG[admin_mode]}" == "true" || "${CONFIG[interval]}" == "once" || "${CONFIG[debug]}" == "true" ]]; then
        echo "$log_message"
    fi
}

# Function to create folder structure
create_folder_structure() {
    local date_str="$1"
    local base_folder="$2"
    local naming_pattern="${3:-yyyy.MM.dd}"
    local lang="${4:-EN}"
    
    # Parse date components
    local year=$(date -d "$date_str" '+%Y')
    local month_num=$(date -d "$date_str" '+%m')
    local day=$(date -d "$date_str" '+%d')
    
    # Handle month naming
    local month
    if [[ "$naming_pattern" =~ [Mm]onth ]]; then
        if [[ "$lang" == "UA" ]]; then
            local months_ua=("Січень" "Лютий" "Березень" "Квітень" "Травень" "Червень" 
                           "Липень" "Серпень" "Вересень" "Жовтень" "Листопад" "Грудень")
            month="${months_ua[$((10#$month_num - 1))]}"
        else
            month=$(date -d "$date_str" '+%B')
        fi
    else
        month="$month_num"
    fi
    
    # Create path
    local year_path="${base_folder}/${year}"
    local month_path="${year_path}/${month}"
    local day_path="${month_path}/${day}"
    
    # Create directories
    mkdir -p "$day_path"
    
    echo "$day_path"
}

# Function to add cron job
add_cron_job() {
    local script_path="$1"
    local interval="${CONFIG[interval]}"
    local repetitive_interval="${CONFIG[repetitive_interval]}"
    
    # Remove existing cron job if present
    remove_cron_job
    
    # Always add --cron flag for automatic execution
    local cron_command="$script_path --cron"
    local cron_entry=""
    
    case "$interval" in
        "on-boot")
            cron_entry="@reboot $cron_command"
            ;;
        "repetitive")
            # Convert seconds to minutes for cron
            local minutes=$((repetitive_interval / 60))
            if [[ $minutes -lt 1 ]]; then
                minutes=1
                echo "Warning: Minimum interval is 1 minute. Setting interval to 60 seconds."
            fi
            
            if [[ $minutes -lt 60 ]]; then
                cron_entry="*/$minutes * * * * $cron_command"
            else
                local hours=$((minutes / 60))
                if [[ $hours -lt 24 ]]; then
                    cron_entry="0 */$hours * * * $cron_command"
                else
                    local days=$((hours / 24))
                    cron_entry="0 0 */$days * * $cron_command"
                fi
            fi
            ;;
        "once")
            # For 'once', we don't add to cron
            return 0
            ;;
        *)
            echo "Invalid scheduler interval: $interval"
            return 1
            ;;
    esac
    
    # Add to crontab
    (crontab -l 2>/dev/null; echo "$CRON_COMMENT"; echo "$cron_entry") | crontab -
    
    if [[ $? -eq 0 ]]; then
        echo "$(get_localized_string 'TaskCreated') $TASK_NAME"
        return 0
    else
        echo "Error creating cron job"
        return 1
    fi
}

# Function to remove cron job
remove_cron_job() {
    # Remove lines containing our comment and the next line (the actual cron job)
    crontab -l 2>/dev/null | grep -v "$CRON_COMMENT" | grep -v "$SCRIPT_DIR/$(basename $0)" | crontab -
    
    if [[ $? -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Function to check if cron job exists
check_cron_job() {
    crontab -l 2>/dev/null | grep -q "$SCRIPT_DIR/$(basename $0)"
    return $?
}

# Function to remove old logs
remove_old_logs() {
    local log_path="${1:-$SCRIPT_DIR/script_logs}"
    local days_to_keep="${2:-30}"
    
    if [[ -d "$log_path" ]]; then
        find "$log_path" -name "log_*.txt" -type f -mtime +$days_to_keep -delete
    fi
}

# Function to extract date from filename
extract_date_from_filename() {
    local filename="$1"
    
    # Check if filename matches pattern with date (e.g., _241011)
    if [[ "$filename" =~ _([0-9]{6}) ]]; then
        local date_string="${BASH_REMATCH[1]}"
        local year="20${date_string:0:2}"
        local month="${date_string:2:2}"
        local day="${date_string:4:2}"
        
        echo "${year}-${month}-${day}"
        return 0
    fi
    
    return 1
}

# Function to get file creation date (birth time)
get_file_creation_date() {
    local file="$1"
    
    # Try to get birth time (creation time) - %w in stat
    # Note: Not all filesystems support this
    local birth_time=$(stat -c %w "$file" 2>/dev/null)
    
    if [[ "$birth_time" != "-" && -n "$birth_time" && "$birth_time" != "0" ]]; then
        # Birth time is available
        # Log to stderr to avoid interfering with the return value
        write_log "Using file creation date (birth time) for: $(basename "$file")" >&2
        echo "$birth_time" | cut -d' ' -f1
        return 0
    else
        # Birth time not available, fall back to modification time
        local mod_time=$(stat -c %y "$file" 2>/dev/null | cut -d' ' -f1)
        # Log to stderr to avoid interfering with the return value
        write_log "Birth time not available, using modification date for: $(basename "$file")" >&2
        echo "$mod_time"
        return 0
    fi
}

# Main sorting function
sort_files() {
    local lang="${CONFIG[script_processing_lang]}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "========================================"
        echo "    DRY RUN MODE - NO FILES WILL BE MOVED"
        echo "========================================"
        write_log "Starting DRY RUN - no files will be moved"
    else
        write_log "$(get_localized_string 'StartScript')"
    fi
    
    # Resolve paths
    local src_path="${CONFIG[src_path]}"
    local dst_path="${CONFIG[dst_path]}"
    
    # Use default if empty
    [[ -z "$src_path" ]] && src_path="$SCRIPT_DIR"
    [[ -z "$dst_path" ]] && dst_path="$src_path"
    
    # Convert relative paths to absolute
    [[ ! "$src_path" = /* ]] && src_path="$SCRIPT_DIR/$src_path"
    [[ ! "$dst_path" = /* ]] && dst_path="$SCRIPT_DIR/$dst_path"
    
    write_log "Source path: $src_path"
    write_log "Destination path: $dst_path"
    
    # Check if source path exists
    if [[ ! -d "$src_path" ]]; then
        write_log "Source path does not exist: $src_path" "ERROR"
        return 1
    fi
    
    # Build find command based on filter type
    local find_cmd="find \"$src_path\" -maxdepth 1 -type f"
    
    if [[ "${CONFIG[search_filter_type]}" == "extension" ]]; then
        find_cmd="$find_cmd -name \"*.${CONFIG[search_filter]}\""
    fi
    
    # Execute find and process files
    local file_count=0
    local files_processed=0
    local files_skipped=0
    
    # Arrays to store action summary for dry run
    declare -a move_actions
    
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        
        # Skip config file
        local filename=$(basename "$file")
        [[ "$filename" == "${CONFIG[config_file_name]}" ]] && continue
        
        ((file_count++))
        
        # Apply name-regex filter if specified
        if [[ "${CONFIG[search_filter_type]}" == "name-regex" ]]; then
            if ! [[ "$filename" =~ ${CONFIG[search_filter]} ]]; then
                write_log "$(get_localized_string 'FileIgnored') $filename"
                ((files_skipped++))
                continue
            fi
        fi
        
        # Extract or determine date
        local file_date
        if date_str=$(extract_date_from_filename "$filename"); then
            file_date="$date_str"
            write_log "Extracted date from filename: $file_date"
        else
            # Try to get file creation date, will fall back to modification date if needed
            file_date=$(get_file_creation_date "$file" 2>/dev/null)
            write_log "Using file timestamp: $file_date"
        fi
        
        # Create destination folder structure
        local dest_folder=$(create_folder_structure "$file_date" "$dst_path" "${CONFIG[destination_naming_pattern]}" "$lang")
        
        # Prepare destination path
        local dest_path="$dest_folder/$filename"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            # Dry run - just show what would happen
            echo "Would move: $filename"
            echo "       From: $(dirname "$file")"
            echo "         To: $dest_folder"
            echo "       Date: $file_date"
            echo "---"
            move_actions+=("$filename -> $dest_folder")
            ((files_processed++))
        else
            # Actually move the file
            if mv "$file" "$dest_path" 2>/dev/null; then
                write_log "$(get_localized_string 'FileProcessed') $filename"
                ((files_processed++))
            else
                write_log "$(get_localized_string 'ErrorOccurred') Failed to move $filename" "ERROR"
            fi
        fi
        
    done < <(eval $find_cmd 2>/dev/null)
    
    # Summary
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "========================================"
        echo "           DRY RUN SUMMARY"
        echo "========================================"
        echo "Total files found: $file_count"
        echo "Files to be moved: $files_processed"
        echo "Files to be skipped: $files_skipped"
        echo ""
        echo "No files were actually moved."
        echo "Run without --dry-run to perform the actual sorting."
        write_log "DRY RUN completed: $files_processed files would be moved"
    else
        if [[ $file_count -eq 0 ]]; then
            write_log "$(get_localized_string 'NoFilesFound')"
        else
            write_log "Processed $files_processed out of $file_count files"
        fi
        write_log "$(get_localized_string 'EndScript')"
    fi
}

# Function to edit configuration value
edit_config_value() {
    echo "Доступні змінні конфігурації:"
    echo "--------------------------------"
    echo "1. script_processing_lang (current: ${CONFIG[script_processing_lang]})"
    echo "2. search_filter_type (current: ${CONFIG[search_filter_type]})"
    echo "3. search_filter (current: ${CONFIG[search_filter]})"
    echo "4. src_path (current: ${CONFIG[src_path]})"
    echo "5. dst_path (current: ${CONFIG[dst_path]})"
    echo "6. destination_naming_pattern (current: ${CONFIG[destination_naming_pattern]})"
    echo "7. debug (current: ${CONFIG[debug]})"
    echo "8. interval (current: ${CONFIG[interval]})"
    echo "9. repetitive_interval (current: ${CONFIG[repetitive_interval]})"
    echo "10. remove_logs_older_than (current: ${CONFIG[remove_logs_older_than]})"
    echo "--------------------------------"
    
    read -p "Вкажіть номер змінної для зміни (1-10) або 'q' для виходу: " var_choice
    
    if [[ "$var_choice" == "q" ]]; then
        return
    fi
    
    local var_name=""
    local var_description=""
    local current_value=""
    
    case $var_choice in
        1)
            var_name="script_processing_lang"
            var_description="Мова інтерфейсу (EN або UA)"
            current_value="${CONFIG[script_processing_lang]}"
            ;;
        2)
            var_name="search_filter_type"
            var_description="Тип фільтру (extension або name-regex)"
            current_value="${CONFIG[search_filter_type]}"
            ;;
        3)
            var_name="search_filter"
            var_description="Значення фільтру (наприклад: jpg)"
            current_value="${CONFIG[search_filter]}"
            ;;
        4)
            var_name="src_path"
            var_description="Шлях джерела файлів"
            current_value="${CONFIG[src_path]}"
            ;;
        5)
            var_name="dst_path"
            var_description="Шлях призначення файлів"
            current_value="${CONFIG[dst_path]}"
            ;;
        6)
            var_name="destination_naming_pattern"
            var_description="Формат назв папок (yyyy.MM.dd або yyyy.month.dd)"
            current_value="${CONFIG[destination_naming_pattern]}"
            ;;
        7)
            var_name="debug"
            var_description="Режим налагодження (true або false)"
            current_value="${CONFIG[debug]}"
            ;;
        8)
            var_name="interval"
            var_description="Інтервал запуску (once, repetitive, on-boot)"
            current_value="${CONFIG[interval]}"
            ;;
        9)
            var_name="repetitive_interval"
            var_description="Інтервал повторення в секундах"
            current_value="${CONFIG[repetitive_interval]}"
            ;;
        10)
            var_name="remove_logs_older_than"
            var_description="Видаляти логи старші ніж (днів)"
            current_value="${CONFIG[remove_logs_older_than]}"
            ;;
        *)
            echo "Невірний вибір"
            return
            ;;
    esac
    
    echo ""
    echo "Змінна: $var_name"
    echo "Опис: $var_description"
    echo "Поточне значення: $current_value"
    echo ""
    read -p "Введіть нове значення (або Enter щоб залишити без змін): " new_value
    
    if [[ -n "$new_value" ]]; then
        # Update CONFIG array
        CONFIG[$var_name]="$new_value"
        
        # Save to config file
        save_config_to_file
        
        echo "✓ Змінено $var_name на: $new_value"
    else
        echo "Значення не змінено"
    fi
}

# Function to save configuration to file
save_config_to_file() {
    local temp_file="${CONFIG_PATH}.tmp"
    
    # Read original file and update values
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*#.*$ ]] || [[ -z "$line" ]]; then
            # Keep comments and empty lines as is
            echo "$line"
        else
            # Check if this is a configuration line
            if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
                local key="${BASH_REMATCH[1]}"
                key=$(echo "$key" | xargs)  # trim whitespace
                
                # If this key exists in our CONFIG array, use new value
                if [[ -n "${CONFIG[$key]+isset}" ]]; then
                    echo "$key=${CONFIG[$key]}"
                else
                    echo "$line"
                fi
            else
                echo "$line"
            fi
        fi
    done < "$CONFIG_PATH" > "$temp_file"
    
    # Replace original file with updated one
    mv "$temp_file" "$CONFIG_PATH"
    
    echo "Конфігурацію збережено в $CONFIG_PATH"
}
generate_test_files() {
    local directory="${1:-$SCRIPT_DIR}"
    
    local test_files=(
        "0314_2410111145113_001.jpg:2024-10-11"
        "0313_2410111445454_001.jpg:2024-10-11"
        "0312_2409111429506_001.jpg:2024-09-11"
        "0311_2409111440957_001.jpg:2024-09-11"
        "0310_2408111131747_001.jpg:2024-08-11"
        "0309_2408111130739_001.jpg:2024-08-11"
        "0308_2407111125446_001.jpg:2024-07-11"
        "0307_2407111129939_001.jpg:2024-07-11"
        "0300_2410110723909_001.jpg:2024-10-11"
    )
    
    local count=0
    for file_info in "${test_files[@]}"; do
        local filename="${file_info%%:*}"
        local filedate="${file_info##*:}"
        local filepath="$directory/$filename"
        
        touch "$filepath"
        # Set modification time
        touch -d "$filedate" "$filepath"
        ((count++))
    done
    
    echo "$count"
}

# Function to generate default config file
generate_default_config() {
    local config_path="${1:-$CONFIG_PATH}"
    
    cat > "$config_path" << 'EOF'
# Configuration file for AutoFileSorter script

# Language for script processing and logging (UA for Ukrainian, EN for English)
script_processing_lang=EN

# Type of search filter (extension or name-regex)
search_filter_type=extension

# Value for the search filter (e.g., jpg for extension, or regex pattern for name-regex)
search_filter=jpg

# Source path to search for files
# You can use absolute path: /home/username/files_to_sort
# Or relative path: ./files_to_sort or ../files_to_sort
# Leave empty for current directory
src_path=/mnt/sorting_point

# Destination path to place sorted files
# You can use absolute path: /home/username/sorted_files
# Or relative path: ./sorted_files or ../sorted_files
# Leave empty for current directory
dst_path=/mnt/sorting_point

# Pattern for naming destination folders (yyyy for year, MM for month, dd for day)
# Use 'month' (case-insensitive) to use month names instead of numbers
destination_naming_pattern=yyyy.MM.dd

# Enable debug mode for detailed logging (true or false)
debug=false

# Scheduler action (add, remove, or check)
scheduler=

# Interval for scheduled runs (once, on-boot, or repetitive)
interval=repetitive

# Interval in seconds for repetitive scheduling
repetitive_interval=3600

# Path for the log file (leave empty for default location)
log_path=

# Name of this configuration file
config_file_name=config.ini

# Enable admin mode (true or false)
admin_mode=false

# Number of days to keep logs before removing
remove_logs_older_than=30
EOF
    
    echo "$(get_localized_string 'ConfigFileGenerated') $config_path"
}

# Function to show admin menu
show_admin_menu() {
    local is_config_missing=$1
    
    while true; do
        clear
        echo "========================================"
        echo "   Auto File Sorter - Admin Menu"
        echo "========================================"
        echo "1. Enable/Disable Cron scheduler"
        echo "2. Check Cron scheduler status"
        echo "3. Generate test files in source directory"
        echo "4. Generate default config file"
        echo "5. Run file sorting now"
        echo "6. Run DRY RUN (preview changes without moving files)"
        echo "7. View current configuration"
        echo "8. Edit configuration values"
        echo "9. Exit"
        echo "========================================"
        
        read -p "Enter your choice (1-9): " choice
        
        case $choice in
            1)
                if [[ $is_config_missing -eq 1 ]]; then
                    echo "Error: Cannot enable scheduler without a configuration file."
                    echo "Please create a config file first (option 4)."
                else
                    if check_cron_job; then
                        read -p "Cron job is currently enabled. Disable it? (y/n): " confirm
                        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                            if remove_cron_job; then
                                echo "$(get_localized_string 'TaskRemoved') $TASK_NAME"
                            else
                                echo "Failed to remove cron job"
                            fi
                        fi
                    else
                        read -p "Cron job is currently disabled. Enable it? (y/n): " confirm
                        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                            if add_cron_job "$SCRIPT_DIR/$(basename $0)"; then
                                echo "$(get_localized_string 'TaskCreated') $TASK_NAME"
                            fi
                        fi
                    fi
                fi
                ;;
            2)
                if check_cron_job; then
                    echo "$(get_localized_string 'TaskExists') $TASK_NAME"
                    echo ""
                    echo "Current crontab entries for this script:"
                    crontab -l 2>/dev/null | grep -A1 "$CRON_COMMENT"
                    echo ""
                    echo "----------------------------------------"
                    echo "Пояснення формату cron:"
                    echo "----------------------------------------"
                    
                    # Parse current cron entry
                    local cron_line=$(crontab -l 2>/dev/null | grep "$SCRIPT_DIR" | head -1)
                    if [[ -n "$cron_line" ]]; then
                        echo "Ваш запис: $cron_line"
                        echo ""
                        
                        # Extract timing part
                        local timing=$(echo "$cron_line" | awk '{print $1" "$2" "$3" "$4" "$5}')
                        
                        case "$timing" in
                            "* * * * *")
                                echo "⏰ Запускається: ЩОХВИЛИНИ"
                                ;;
                            "*/5 * * * *")
                                echo "⏰ Запускається: кожні 5 хвилин"
                                ;;
                            "*/10 * * * *")
                                echo "⏰ Запускається: кожні 10 хвилин"
                                ;;
                            "*/30 * * * *")
                                echo "⏰ Запускається: кожні 30 хвилин"
                                ;;
                            "0 * * * *")
                                echo "⏰ Запускається: щогодини (о 0 хвилин)"
                                ;;
                            "0 */2 * * *")
                                echo "⏰ Запускається: кожні 2 години"
                                ;;
                            "0 */3 * * *")
                                echo "⏰ Запускається: кожні 3 години"
                                ;;
                            "0 0 * * *")
                                echo "⏰ Запускається: щодня о 00:00"
                                ;;
                            "0 2 * * *")
                                echo "⏰ Запускається: щодня о 02:00"
                                ;;
                            "@reboot")
                                echo "⏰ Запускається: при старті системи"
                                ;;
                            *)
                                echo "⏰ Нестандартний розклад: $timing"
                                ;;
                        esac
                        
                        echo ""
                        echo "Формат: хвилини години дні місяці дні_тижня команда"
                        echo "Приклади:"
                        echo "  */5 * * * *    - кожні 5 хвилин"
                        echo "  0 * * * *      - щогодини"
                        echo "  0 */6 * * *    - кожні 6 годин"
                        echo "  0 2 * * *      - щодня о 2:00"
                        echo "  0 0 * * 0      - щонеділі о півночі"
                        
                        # Check for syntax errors
                        if [[ "$cron_line" =~ \*\*+ ]]; then
                            echo ""
                            echo "⚠️  УВАГА: Знайдено синтаксичну помилку!"
                            echo "    Зайві зірочки: **"
                            echo "    Використайте 'crontab -e' для виправлення"
                        fi
                    fi
                else
                    echo "$(get_localized_string 'TaskNotFound') $TASK_NAME"
                    echo ""
                    echo "Приклади cron записів для додавання:"
                    echo "  */5 * * * * /root/afs/afs.sh --cron   # кожні 5 хвилин"
                    echo "  0 * * * * /root/afs/afs.sh --cron     # щогодини"
                    echo "  0 */6 * * * /root/afs/afs.sh --cron   # кожні 6 годин"
                    echo "  0 2 * * * /root/afs/afs.sh --cron     # щодня о 2:00"
                fi
                ;;
            3)
                local src_path="${CONFIG[src_path]}"
                [[ -z "$src_path" ]] && src_path="$SCRIPT_DIR"
                [[ ! "$src_path" = /* ]] && src_path="$SCRIPT_DIR/$src_path"
                
                local count=$(generate_test_files "$src_path")
                echo "$(get_localized_string 'TestFilesGenerated') $count"
                echo "Files created in: $src_path"
                ;;
            4)
                generate_default_config
                is_config_missing=0
                # Reload config
                read_config
                ;;
            5)
                if [[ $is_config_missing -eq 1 ]]; then
                    echo "Error: Cannot run without a configuration file."
                    echo "Please create a config file first (option 4)."
                else
                    echo "Running file sorting..."
                    DRY_RUN=false
                    sort_files
                    echo "File sorting completed."
                fi
                ;;
            6)
                if [[ $is_config_missing -eq 1 ]]; then
                    echo "Error: Cannot run without a configuration file."
                    echo "Please create a config file first (option 4)."
                else
                    echo ""
                    DRY_RUN=true
                    sort_files
                fi
                ;;
            7)
                echo "Current Configuration:"
                echo "----------------------"
                for key in "${!CONFIG[@]}"; do
                    echo "$key = ${CONFIG[$key]}"
                done | sort
                
                echo ""
                echo "System Information:"
                echo "----------------------"
                # Check if filesystem supports birth time
                local test_file="/tmp/.afs_test_$"
                touch "$test_file"
                local birth_test=$(stat -c %w "$test_file" 2>/dev/null)
                rm -f "$test_file"
                
                if [[ "$birth_test" != "-" && -n "$birth_test" ]]; then
                    echo "Filesystem supports creation time: YES"
                else
                    echo "Filesystem supports creation time: NO (will use modification time)"
                fi
                ;;
            8)
                if [[ $is_config_missing -eq 1 ]]; then
                    echo "Error: No configuration file to edit."
                    echo "Please create a config file first (option 4)."
                else
                    edit_config_value
                fi
                ;;
            9)
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo "Invalid choice. Please try again."
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Main script logic
main() {
    local is_config_missing=0
    local force_run=false
    
    # Check for command line arguments
    for arg in "$@"; do
        case $arg in
            --admin)
                CONFIG[admin_mode]="true"
                ;;
            --cron|--auto)
                # Force automatic run, ignore admin_mode setting
                force_run=true
                CONFIG[admin_mode]="false"
                ;;
            --dry-run)
                DRY_RUN=true
                echo "DRY RUN MODE ENABLED"
                ;;
            --help|-h)
                echo "Auto File Sorter - Usage:"
                echo "  $(basename $0)           - Run based on config settings"
                echo "  $(basename $0) --admin   - Enter admin menu"
                echo "  $(basename $0) --cron    - Force automatic run (for cron/scheduler)"
                echo "  $(basename $0) --dry-run - Preview changes without moving files"
                echo "  $(basename $0) --help    - Show this help message"
                exit 0
                ;;
        esac
    done
    
    # Check if config file exists
    if [[ ! -f "$CONFIG_PATH" ]]; then
        echo "Config file not found. Starting in administrative mode."
        echo "Please create a config file to start using the script."
        is_config_missing=1
        CONFIG[admin_mode]="true"
    else
        # Read configuration
        if ! read_config; then
            echo "Error reading configuration file"
            exit 1
        fi
    fi
    
    # Remove old logs
    if [[ $is_config_missing -eq 0 ]]; then
        remove_old_logs "" "${CONFIG[remove_logs_older_than]}"
    fi
    
    # If --cron flag was used, force non-interactive mode
    if [[ "$force_run" == "true" ]]; then
        # Just run sorting, no menus or interactive elements
        sort_files
        exit 0
    fi
    
    # Handle admin mode
    if [[ "${CONFIG[admin_mode]}" == "true" ]]; then
        show_admin_menu $is_config_missing
    else
        # Handle scheduler actions
        case "${CONFIG[scheduler]}" in
            "add")
                if ! check_cron_job; then
                    if add_cron_job "$SCRIPT_DIR/$(basename $0) --cron"; then
                        write_log "$(get_localized_string 'TaskCreated') $TASK_NAME"
                    else
                        write_log "Failed to create cron job" "ERROR"
                    fi
                else
                    write_log "$(get_localized_string 'TaskExists') $TASK_NAME"
                fi
                ;;
            "remove")
                if remove_cron_job; then
                    write_log "$(get_localized_string 'TaskRemoved') $TASK_NAME"
                else
                    write_log "$(get_localized_string 'TaskNotFound') $TASK_NAME"
                fi
                ;;
            "check")
                if check_cron_job; then
                    write_log "$(get_localized_string 'TaskExists') $TASK_NAME"
                else
                    write_log "$(get_localized_string 'TaskNotFound') $TASK_NAME"
                fi
                ;;
        esac
        
        # Run sorting
        sort_files
    fi
}

# Run main function
main "$@"