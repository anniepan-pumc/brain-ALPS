#!/usr/bin/env bash
#
# Script name: diagnose_input_files.sh
#
# Description: Diagnostic script to check input files for TBSS preprocessing
#              This helps identify files that might cause segmentation faults
#

# Function to check if a file exists and is readable
check_file() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo "ERROR: File $file does not exist"
        return 1
    fi
    if [ ! -r "$file" ]; then
        echo "ERROR: File $file is not readable"
        return 1
    fi
    return 0
}

# Function to check FSL environment
check_fsl() {
    if [ -z "$FSLDIR" ]; then
        echo "ERROR: FSLDIR is not set. Please source FSL environment."
        exit 1
    fi
    if [ ! -d "$FSLDIR" ]; then
        echo "ERROR: FSLDIR directory does not exist: $FSLDIR"
        exit 1
    fi
    return 0
}

# Function to check individual file
check_single_file() {
    local file="$1"
    echo "=== Checking file: $file ==="
    
    # Basic file checks
    if ! check_file "$file"; then
        echo "FAILED: Basic file checks"
        return 1
    fi
    
    # Check file size
    local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    if [ "$file_size" -eq 0 ]; then
        echo "FAILED: File is empty (0 bytes)"
        return 1
    fi
    echo "PASSED: File size is $file_size bytes"
    
    # Check if it's a valid NIfTI file
    if ! $FSLDIR/bin/fslinfo "$file" >/dev/null 2>&1; then
        echo "FAILED: Not a valid NIfTI file"
        return 1
    fi
    echo "PASSED: Valid NIfTI file"
    
    # Get image dimensions
    local dim1=$($FSLDIR/bin/fslval "$file" dim1 2>/dev/null)
    local dim2=$($FSLDIR/bin/fslval "$file" dim2 2>/dev/null)
    local dim3=$($FSLDIR/bin/fslval "$file" dim3 2>/dev/null)
    local dim4=$($FSLDIR/bin/fslval "$file" dim4 2>/dev/null)
    
    if [ -z "$dim1" ] || [ -z "$dim2" ] || [ -z "$dim3" ]; then
        echo "FAILED: Cannot read image dimensions"
        return 1
    fi
    
    echo "PASSED: Image dimensions: ${dim1}x${dim2}x${dim3}x${dim4}"
    
    # Check for reasonable dimensions (not too large)
    if [ "$dim1" -gt 1000 ] || [ "$dim2" -gt 1000 ] || [ "$dim3" -gt 1000 ]; then
        echo "WARNING: Very large image dimensions - may cause memory issues"
    fi
    
    # Check data type
    local datatype=$($FSLDIR/bin/fslval "$file" datatype 2>/dev/null)
    echo "PASSED: Data type: $datatype"
    
    # Check for NaN or Inf values
    local nan_count=$($FSLDIR/bin/fslstats "$file" -R 2>/dev/null | grep -c "nan\|NaN\|inf\|Inf" || echo "0")
    if [ "$nan_count" -gt 0 ]; then
        echo "WARNING: File contains NaN or Inf values"
    else
        echo "PASSED: No NaN or Inf values detected"
    fi
    
    # Check for extreme values
    local min_val=$($FSLDIR/bin/fslstats "$file" -R 2>/dev/null | cut -d' ' -f1)
    local max_val=$($FSLDIR/bin/fslstats "$file" -R 2>/dev/null | cut -d' ' -f2)
    echo "PASSED: Value range: $min_val to $max_val"
    
    # Test basic fslmaths operation
    local test_output="/tmp/test_${RANDOM}.nii.gz"
    if $FSLDIR/bin/fslmaths "$file" -thr 0 "$test_output" >/dev/null 2>&1; then
        echo "PASSED: Basic fslmaths operation successful"
        rm -f "$test_output"
    else
        echo "FAILED: Basic fslmaths operation failed"
        rm -f "$test_output"
        return 1
    fi
    
    echo "=== File $file PASSED all checks ==="
    return 0
}

# Main script
main() {
    echo "TBSS Input File Diagnostic Tool"
    echo "================================"
    
    # Check FSL environment
    if ! check_fsl; then
        exit 1
    fi
    
    # Check if arguments provided
    if [ $# -eq 0 ]; then
        echo "Usage: $0 <file1> [file2] [file3] ..."
        echo "       or"
        echo "Usage: $0 --pattern '*.nii.gz'"
        exit 1
    fi
    
    local failed_files=()
    local passed_files=()
    
    # Process files
    for file in "$@"; do
        if check_single_file "$file"; then
            passed_files+=("$file")
        else
            failed_files+=("$file")
        fi
        echo ""
    done
    
    # Summary
    echo "=== SUMMARY ==="
    echo "Passed files: ${#passed_files[@]}"
    echo "Failed files: ${#failed_files[@]}"
    
    if [ ${#failed_files[@]} -gt 0 ]; then
        echo ""
        echo "Failed files:"
        for file in "${failed_files[@]}"; do
            echo "  - $file"
        done
        echo ""
        echo "Recommendation: Fix or remove failed files before running TBSS preprocessing"
    fi
    
    if [ ${#passed_files[@]} -gt 0 ]; then
        echo ""
        echo "Passed files:"
        for file in "${passed_files[@]}"; do
            echo "  - $file"
        done
    fi
}

# Run main function
main "$@" 