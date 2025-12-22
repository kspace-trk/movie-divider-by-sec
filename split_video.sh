#!/bin/bash

# Video Splitter - Split videos into 1-minute segments
# Auto-detects input.mov or input.mp4 from ~/Desktop
# Outputs split segments as out_000.mp4, out_001.mp4, etc. to ~/Desktop

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    print_error "ffmpeg is not installed. Please install it first."
    echo ""
    echo "Installation instructions:"
    echo "  macOS:   brew install ffmpeg"
    echo "  Ubuntu:  sudo apt-get install ffmpeg"
    echo "  CentOS:  sudo yum install ffmpeg"
    exit 1
fi

# Auto-detect input file from ~/Desktop
DESKTOP="$HOME/Desktop"
INPUT_FILE=""

if [ -f "$DESKTOP/input.mov" ]; then
    INPUT_FILE="$DESKTOP/input.mov"
    print_info "Found input file: input.mov"
elif [ -f "$DESKTOP/input.mp4" ]; then
    INPUT_FILE="$DESKTOP/input.mp4"
    print_info "Found input file: input.mp4"
else
    print_error "No input file found on Desktop"
    echo ""
    echo "Please place one of the following files on your Desktop:"
    echo "  - input.mov"
    echo "  - input.mp4"
    exit 1
fi

# Get video duration in seconds
print_info "Analyzing video file..."
DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INPUT_FILE")

# Check if duration was successfully extracted
if [ -z "$DURATION" ]; then
    print_error "Could not determine video duration"
    exit 1
fi

# Convert duration to integer (round down)
DURATION_INT=${DURATION%.*}

print_info "Video duration: ${DURATION_INT} seconds ($(echo "scale=2; $DURATION_INT/60" | bc) minutes)"

# Check if video is longer than 60 seconds
if [ "$DURATION_INT" -lt 60 ]; then
    print_warning "Video is shorter than 1 minute (${DURATION_INT} seconds)"
    print_warning "Skipping split operation"
    exit 0
fi

# Calculate number of segments
NUM_SEGMENTS=$(echo "($DURATION_INT + 59) / 60" | bc)
print_info "Expected number of segments: $NUM_SEGMENTS"

# Split video into 1-minute (60 seconds) segments
print_info "Splitting video into 1-minute segments..."

# Use ffmpeg to split the video
# -c copy: copy codec without re-encoding (fast)
# -map 0: include all streams (video, audio, subtitles)
# -segment_time 60: split every 60 seconds
# -f segment: use segment muxer
# -reset_timestamps 1: reset timestamps for each segment
ffmpeg -i "$INPUT_FILE" \
    -c copy \
    -map 0 \
    -segment_time 60 \
    -f segment \
    -reset_timestamps 1 \
    "$DESKTOP/out_%03d.mp4" 2>&1 | grep -v "frame=" || true

# Count generated segments
SEGMENT_COUNT=$(ls -1 "$DESKTOP"/out_*.mp4 2>/dev/null | wc -l | tr -d ' ')

if [ "$SEGMENT_COUNT" -eq 0 ]; then
    print_error "No output files were created"
    exit 1
fi

print_info "Successfully created $SEGMENT_COUNT segments on Desktop"
echo ""
print_info "Output files:"
ls -lh "$DESKTOP"/out_*.mp4 | awk '{print "  " $9 " (" $5 ")"}'

echo ""
print_info "Done!"
