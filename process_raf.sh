#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 [-s] [-g] <RAF filename(s) or wildcard>"
    echo "  -s    Split the processed image into left and right halves"
    echo "  -g    Convert the image to grayscale (in addition to negation)"
    echo "  The script will always compress, resize, and negate the image(s)"
    exit 1
}

# Function to process a single RAF file
process_file() {
    input_file="$1"
    base_name="${input_file%.*}"

    echo "Processing file: $input_file"

    # Build the ImageMagick command
    cmd="magick \"$input_file\" -compress zip -depth 16 -resize 60% -negate"
    
    if [ "$grayscale" = true ]; then
        cmd+=" -colorspace gray"
    fi
    
    cmd+=" \"${base_name}_processed.tif\""
    
    # Execute the command
    eval $cmd

    if [ "$split" = true ]; then
        # Get the dimensions of the processed image
        dimensions=$(magick identify -format "%wx%h" "${base_name}_processed.tif")
        width=$(echo $dimensions | cut -d'x' -f1)
        height=$(echo $dimensions | cut -d'x' -f2)

        # Calculate half width
        half_width=$((width / 2))

        # Split and save left half
        magick "${base_name}_processed.tif" -crop ${half_width}x${height}+0+0 "${base_name}_left.tif"

        # Split and save right half
        magick "${base_name}_processed.tif" -crop ${half_width}x${height}+${half_width}+0 "${base_name}_right.tif"

        # Remove the whole processed image
        rm "${base_name}_processed.tif"

        echo "Completed processing: ${base_name}_left.tif and ${base_name}_right.tif"
    else
        echo "Completed processing: ${base_name}_processed.tif"
    fi
}

# Function to check if file is RAF (case-insensitive)
is_raf_file() {
    case "$1" in
        *.raf|*.RAF) return 0 ;;
        *) return 1 ;;
    esac
}

# Initialize options
split=false
grayscale=false

# Parse command line options
while getopts ":sg" opt; do
    case ${opt} in
        s )
            split=true
            ;;
        g )
            grayscale=true
            ;;
        \? )
            usage
            ;;
    esac
done
shift $((OPTIND -1))

# Check if filename arguments were provided
if [ $# -eq 0 ]; then
    usage
fi

# Loop through all arguments
for arg in "$@"; do
    # Check if the argument is a wildcard
    if [[ $arg == *\** ]]; then
        # Process all matching files
        for file in $arg; do
            if [ -f "$file" ] && is_raf_file "$file"; then
                process_file "$file"
            fi
        done
    elif [ -f "$arg" ] && is_raf_file "$arg"; then
        # Process single file
        process_file "$arg"
    else
        echo "Skipping invalid file or non-RAF file: $arg"
    fi
done

echo "All processing complete."
