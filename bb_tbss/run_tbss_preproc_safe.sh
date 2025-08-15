#!/usr/bin/env bash
#
# Script name: run_tbss_preproc_safe.sh
#
# Description: Safe wrapper for TBSS preprocessing with enhanced error checking
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] ${message}${NC}"
}

# Function to check FSL environment
check_fsl_environment() {
    print_status $YELLOW "Checking FSL environment..."
    
    if [ -z "$FSLDIR" ]; then
        print_status $RED "ERROR: FSLDIR is not set"
        print_status $YELLOW "Please source FSL environment first:"
        print_status $YELLOW "  source /path/to/fsl/etc/fslconf/fsl.sh"
        return 1
    fi
    
    if [ ! -d "$FSLDIR" ]; then
        print_status $RED "ERROR: FSLDIR directory does not exist: $FSLDIR"
        return 1
    fi
    
    # Check essential FSL tools
    local required_tools=("fslmaths" "fslval" "imglob" "slicesdir")
    for tool in "${required_tools[@]}"; do
        if [ ! -x "$FSLDIR/bin/$tool" ]; then
            print_status $RED "ERROR: Required FSL tool not found: $tool"
            return 1
        fi
    done
    
    print_status $GREEN "FSL environment check passed"
    return 0
}

# Function to validate input files
validate_input_files() {
    local files=("$@")
    print_status $YELLOW "Validating input files..."
    
    local valid_files=()
    local invalid_files=()
    
    for file in "${files[@]}"; do
        if [ ! -f "$file" ]; then
            print_status $RED "ERROR: File does not exist: $file"
            invalid_files+=("$file")
            continue
        fi
        
        if [ ! -r "$file" ]; then
            print_status $RED "ERROR: File is not readable: $file"
            invalid_files+=("$file")
            continue
        fi
        
        # Check if it's a valid NIfTI file
        if ! $FSLDIR/bin/fslinfo "$file" >/dev/null 2>&1; then
            print_status $RED "ERROR: Not a valid NIfTI file: $file"
            invalid_files+=("$file")
            continue
        fi
        
        valid_files+=("$file")
        print_status $GREEN "Valid file: $file"
    done
    
    if [ ${#invalid_files[@]} -gt 0 ]; then
        print_status $RED "Found ${#invalid_files[@]} invalid files:"
        for file in "${invalid_files[@]}"; do
            print_status $RED "  - $file"
        done
        return 1
    fi
    
    print_status $GREEN "All ${#valid_files[@]} input files are valid"
    return 0
}

# Function to run TBSS preprocessing with error handling
run_tbss_preproc() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local preproc_script="$script_dir/bb_tbss_1_preproc"
    
    print_status $YELLOW "Running TBSS preprocessing..."
    print_status $YELLOW "Script: $preproc_script"
    print_status $YELLOW "Arguments: $*"
    
    # Run the preprocessing script
    if "$preproc_script" "$@"; then
        print_status $GREEN "TBSS preprocessing completed successfully"
        return 0
    else
        print_status $RED "TBSS preprocessing failed"
        return 1
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 <input_file1> [input_file2] [input_file3] ..."
    echo ""
    echo "Description:"
    echo "  Safe wrapper for TBSS preprocessing with enhanced error checking"
    echo ""
    echo "Options:"
    echo "  --help, -h     Show this help message"
    echo "  --diagnose     Run diagnostic checks on input files"
    echo ""
    echo "Examples:"
    echo "  $0 sub01_FA.nii.gz sub02_FA.nii.gz sub03_FA.nii.gz"
    echo "  $0 --diagnose *.nii.gz"
    echo ""
    echo "Note: Make sure FSL environment is properly sourced before running this script"
}

# Function to run diagnostics
run_diagnostics() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local diag_script="$script_dir/diagnose_input_files.sh"
    
    if [ ! -x "$diag_script" ]; then
        print_status $RED "ERROR: Diagnostic script not found: $diag_script"
        return 1
    fi
    
    print_status $YELLOW "Running diagnostic checks..."
    "$diag_script" "$@"
}

# Main function
main() {
    # Check if help is requested
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        show_usage
        exit 0
    fi
    
    # Check if diagnostics are requested
    if [ "$1" = "--diagnose" ]; then
        shift
        run_diagnostics "$@"
        exit $?
    fi
    
    # Check if arguments provided
    if [ $# -eq 0 ]; then
        print_status $RED "ERROR: No input files specified"
        show_usage
        exit 1
    fi
    
    print_status $GREEN "Starting TBSS preprocessing with safety checks..."
    
    # Step 1: Check FSL environment
    if ! check_fsl_environment; then
        exit 1
    fi
    
    # Step 2: Validate input files
    if ! validate_input_files "$@"; then
        print_status $RED "ERROR: Input file validation failed"
        print_status $YELLOW "Consider running diagnostics: $0 --diagnose <files>"
        exit 1
    fi
    
    # Step 3: Run TBSS preprocessing
    if ! run_tbss_preproc "$@"; then
        print_status $RED "ERROR: TBSS preprocessing failed"
        print_status $YELLOW "Check the error messages above for details"
        exit 1
    fi
    
    print_status $GREEN "TBSS preprocessing completed successfully!"
    print_status $GREEN "Check the 'FA' directory for output files"
}

# Run main function
main "$@" 