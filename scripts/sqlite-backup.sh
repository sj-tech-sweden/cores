#!/bin/bash
# =============================================================================
# SQLite Backup Script for RentalCore & WarehouseCore
# =============================================================================
# Usage: ./sqlite-backup.sh [OPTIONS]
#
# Options:
#   -d, --data-dir DIR      Data directory containing SQLite databases
#                           (default: /data or ./data)
#   -b, --backup-dir DIR    Backup destination directory
#                           (default: /backups or ./backups)
#   -r, --retention DAYS    Number of days to keep backups (default: 7)
#   -c, --compress          Compress backups with gzip
#   -v, --verify            Verify backup integrity after creation
#   -h, --help              Show this help message
#
# Examples:
#   ./sqlite-backup.sh                                    # Use defaults
#   ./sqlite-backup.sh -d /data -b /backups -r 14 -c -v  # Full options
#   ./sqlite-backup.sh --compress --verify               # Compressed + verified
# =============================================================================

set -euo pipefail

# Default configuration
DATA_DIR="${DATA_DIR:-/data}"
BACKUP_DIR="${BACKUP_DIR:-/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
COMPRESS=false
VERIFY=false
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Show help
show_help() {
    head -n 24 "$0" | tail -n 22
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--data-dir)
            DATA_DIR="$2"
            shift 2
            ;;
        -b|--backup-dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        -r|--retention)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        -c|--compress)
            COMPRESS=true
            shift
            ;;
        -v|--verify)
            VERIFY=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            ;;
    esac
done

# Check if sqlite3 is available
check_sqlite() {
    if ! command -v sqlite3 &> /dev/null; then
        log_error "sqlite3 command not found. Please install SQLite."
        exit 1
    fi
    log_info "SQLite version: $(sqlite3 --version)"
}

# Create backup directory if it doesn't exist
ensure_backup_dir() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
        log_info "Created backup directory: $BACKUP_DIR"
    fi
}

# Backup a single SQLite database using the .backup command
# This is the safest method as it handles WAL mode correctly
backup_database() {
    local db_name="$1"
    local db_path="${DATA_DIR}/${db_name}.db"
    local backup_path="${BACKUP_DIR}/${db_name}_${TIMESTAMP}.db"
    
    if [[ ! -f "$db_path" ]]; then
        log_warn "Database not found: $db_path"
        return 1
    fi
    
    log_info "Backing up $db_name..."
    
    # Perform atomic backup using SQLite's .backup command
    # This properly handles WAL mode and provides a consistent snapshot
    if sqlite3 "$db_path" ".backup '$backup_path'"; then
        log_success "Backup created: $backup_path"
        
        # Verify backup if requested
        if [[ "$VERIFY" == true ]]; then
            verify_backup "$backup_path" "$db_name"
        fi
        
        # Compress if requested
        if [[ "$COMPRESS" == true ]]; then
            compress_backup "$backup_path"
        fi
        
        return 0
    else
        log_error "Failed to backup $db_name"
        return 1
    fi
}

# Verify backup integrity
verify_backup() {
    local backup_path="$1"
    local db_name="$2"
    
    log_info "Verifying $db_name backup integrity..."
    
    if sqlite3 "$backup_path" "PRAGMA integrity_check;" | grep -q "ok"; then
        log_success "Backup integrity verified for $db_name"
        return 0
    else
        log_error "Backup integrity check failed for $db_name"
        return 1
    fi
}

# Compress backup with gzip
compress_backup() {
    local backup_path="$1"
    
    log_info "Compressing backup..."
    if gzip -f "$backup_path"; then
        log_success "Compressed: ${backup_path}.gz"
    else
        log_warn "Compression failed for: $backup_path"
    fi
}

# Clean up old backups
cleanup_old_backups() {
    log_info "Cleaning up backups older than $RETENTION_DAYS days..."
    
    local deleted_count=0
    
    # Find and delete old backup files
    while IFS= read -r -d '' file; do
        rm -f "$file"
        ((deleted_count++))
    done < <(find "$BACKUP_DIR" -name "*.db" -o -name "*.db.gz" -mtime "+$RETENTION_DAYS" -print0 2>/dev/null)
    
    if [[ $deleted_count -gt 0 ]]; then
        log_success "Deleted $deleted_count old backup(s)"
    else
        log_info "No old backups to delete"
    fi
}

# List current backups
list_backups() {
    log_info "Current backups in $BACKUP_DIR:"
    echo "----------------------------------------"
    
    if ls -la "$BACKUP_DIR"/*.db* 2>/dev/null; then
        echo "----------------------------------------"
        local total_size
        total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
        log_info "Total backup size: $total_size"
    else
        log_warn "No backups found"
    fi
}

# Main backup process
main() {
    echo "=============================================="
    echo "🗄️  SQLite Backup Script"
    echo "=============================================="
    echo "Timestamp: $TIMESTAMP"
    echo "Data directory: $DATA_DIR"
    echo "Backup directory: $BACKUP_DIR"
    echo "Retention: $RETENTION_DAYS days"
    echo "Compress: $COMPRESS"
    echo "Verify: $VERIFY"
    echo "=============================================="
    
    check_sqlite
    ensure_backup_dir
    
    local success_count=0
    local fail_count=0
    
    # Backup RentalCore
    if backup_database "rentalcore"; then
        ((success_count++))
    else
        ((fail_count++))
    fi
    
    # Backup WarehouseCore
    if backup_database "warehousecore"; then
        ((success_count++))
    else
        ((fail_count++))
    fi
    
    # Clean up old backups
    cleanup_old_backups
    
    # Show current backups
    echo ""
    list_backups
    
    # Summary
    echo ""
    echo "=============================================="
    if [[ $fail_count -eq 0 ]]; then
        log_success "Backup completed successfully! ($success_count databases)"
    else
        log_warn "Backup completed with issues: $success_count succeeded, $fail_count failed"
    fi
    echo "=============================================="
    
    return $fail_count
}

# Run main function
main "$@"
