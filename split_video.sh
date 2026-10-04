#!/bin/bash

# Video Splitter - Split videos into segments that never exceed 1 minute
# Uses the file path given as the first argument (.mov or .mp4) if provided,
# otherwise auto-detects input.mov or input.mp4 from ~/Desktop
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

# Use the file path given as an argument, or auto-detect input file from ~/Desktop
DESKTOP="$HOME/Desktop"
INPUT_FILE=""

if [ -n "$1" ]; then
    if [ ! -f "$1" ]; then
        print_error "Input file not found: $1"
        exit 1
    fi
    case "$1" in
        *.[mM][oO][vV]|*.[mM][pP]4)
            INPUT_FILE="$1"
            print_info "Using input file: $INPUT_FILE"
            ;;
        *)
            print_error "Unsupported file type: $1"
            echo ""
            echo "Supported file types: .mov, .mp4"
            exit 1
            ;;
    esac
elif [ -f "$DESKTOP/input.mov" ]; then
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

# Maximum length of each segment in seconds
# (kept slightly below 60 so that no segment ever exceeds 1 minute)
MAX_SEGMENT_SEC=59.5

# Without re-encoding, a video can only be cut at keyframes.
# Pick the latest keyframe within MAX_SEGMENT_SEC of each segment start as the cut point.
# Prints "NG" if keyframes are too sparse to keep every segment within the limit.
START_TIME=$(ffprobe -v error -show_entries format=start_time -of default=noprint_wrappers=1:nokey=1 "$INPUT_FILE")
CUT_TIMES=$(ffprobe -v error -select_streams v:0 -show_entries packet=pts_time,flags -of csv=p=0 "$INPUT_FILE" \
    | awk -F, '$2 ~ /K/ { print $1 }' \
    | sort -n -u \
    | awk -v max="$MAX_SEGMENT_SEC" -v dur="$DURATION" -v offset="${START_TIME:-0}" '
        function cut() {
            if (prev <= start) { ng = 1; return }
            # Cut slightly before the keyframe so the segment muxer splits exactly at it
            cuts = cuts (cuts == "" ? "" : ",") sprintf("%.6f", prev - 0.001)
            start = prev
        }
        {
            t = $1 - offset
            if (t - start > max) {
                cut()
                if (t - start > max) ng = 1
            }
            prev = t
        }
        END {
            if (dur - start > max) {
                cut()
                if (dur - start > max) ng = 1
            }
            print (ng ? "NG" : cuts)
        }')

if [ "$CUT_TIMES" != "NG" ] && [ -n "$CUT_TIMES" ]; then
    NUM_SEGMENTS=$(( $(echo "$CUT_TIMES" | tr -cd ',' | wc -c) + 2 ))
    print_info "Expected number of segments: $NUM_SEGMENTS"
    print_info "Splitting video into segments of up to ${MAX_SEGMENT_SEC} seconds..."

    # Use ffmpeg to split the video
    # -c copy: copy codec without re-encoding (fast)
    # -map 0:v -map 0:a: include only video and audio streams (exclude unsupported data streams)
    # -segment_times: split at the keyframes chosen above
    # -f segment: use segment muxer
    # -reset_timestamps 1: reset timestamps for each segment
    # -avoid_negative_ts make_zero: fix timestamp issues that cause black frames
    ffmpeg -i "$INPUT_FILE" \
        -c copy \
        -map 0:v \
        -map 0:a \
        -avoid_negative_ts make_zero \
        -segment_times "$CUT_TIMES" \
        -f segment \
        -reset_timestamps 1 \
        "$DESKTOP/out_%03d.mp4"
else
    print_warning "Keyframes are too sparse to split within ${MAX_SEGMENT_SEC} seconds without re-encoding"
    print_info "Re-encoding while splitting (this may take a while)..."

    # Re-encode with a forced keyframe every MAX_SEGMENT_SEC seconds and split there
    # iPhone-compatible settings: yuv420p, faststart, High Profile Level 4.1
    # -segment_time_delta: tolerate the small timestamp shift of the forced keyframes
    #   (without it the split slips to the next keyframe)
    ffmpeg -i "$INPUT_FILE" \
        -map 0:v \
        -map 0:a \
        -c:v libx264 -preset fast -crf 18 \
        -profile:v high -level 4.1 \
        -pix_fmt yuv420p \
        -force_key_frames "expr:gte(t,n_forced*${MAX_SEGMENT_SEC})" \
        -c:a aac -b:a 320k \
        -segment_time "$MAX_SEGMENT_SEC" \
        -segment_time_delta 0.05 \
        -f segment \
        -segment_format_options movflags=+faststart \
        -reset_timestamps 1 \
        "$DESKTOP/out_%03d.mp4"
fi

# Count generated segments
SEGMENT_COUNT=$(ls -1 "$DESKTOP"/out_*.mp4 2>/dev/null | wc -l | tr -d ' ')

if [ "$SEGMENT_COUNT" -eq 0 ]; then
    print_error "No output files were created"
    exit 1
fi

# Fix first segment by removing the first frame (if it exists)
if [ -f "$DESKTOP/out_000.mp4" ]; then
    print_info "Fixing first frame of out_000.mp4..."
    
    # Remove first frame using video filter (requires re-encoding but more reliable)
    # select='gte(n\,1)' skips the first frame (frame 0)
    # setpts resets presentation timestamps
    # iPhone-compatible settings: yuv420p, faststart, High Profile Level 4.1
    ffmpeg -i "$DESKTOP/out_000.mp4" \
        -vf "select='gte(n\,1)',setpts=PTS-STARTPTS" \
        -af "aselect='gte(n\,1)',asetpts=PTS-STARTPTS" \
        -c:v libx264 -preset fast -crf 18 \
        -profile:v high -level 4.1 \
        -pix_fmt yuv420p \
        -c:a aac -b:a 320k \
        -movflags +faststart \
        "$DESKTOP/out_000_temp.mp4" -y > /dev/null 2>&1
    
    # Replace original with trimmed version
    mv "$DESKTOP/out_000_temp.mp4" "$DESKTOP/out_000.mp4"
    
    print_info "First frame removed from out_000.mp4"
fi

print_info "Successfully created $SEGMENT_COUNT segments on Desktop"
echo ""
print_info "Output files:"
ls -lh "$DESKTOP"/out_*.mp4 | awk '{print "  " $9 " (" $5 ")"}'

echo ""
print_info "Done!"
