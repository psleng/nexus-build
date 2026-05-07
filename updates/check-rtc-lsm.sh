#!/bin/bash

# Define paths for early boot environment
HWCLOCK="/sbin/hwclock"
PARAM_INDEX=2
TARGET_VALUE=2
RTC_DEVICE="/dev/rtc0"

# 1. Wait for the RTC device node to appear (up to 5 seconds)
MAX_RETRIES=10
RETRY_COUNT=0

while [ ! -e "$RTC_DEVICE" ] && [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    echo "Waiting for $RTC_DEVICE to appear... (Attempt $((RETRY_COUNT+1)))"
    sleep 0.5
    RETRY_COUNT=$((RETRY_COUNT+1))
done

if [ ! -e "$RTC_DEVICE" ]; then
    echo "ERROR: $RTC_DEVICE not found after waiting. Is the hardware okay?"
    exit 1
fi

# 2. Get the current value
# Output of --param-get is usually "parameter 2 is 0x2 (2)"
RAW_OUT=$($HWCLOCK -f "$RTC_DEVICE" --param-get $PARAM_INDEX 2>&1)

# Parsing logic: Look for "set to" and take the last word (e.g., 0x2)
# Then convert that hex to a decimal integer for comparison
CURRENT_HEX=$(echo "$RAW_OUT" | awk '/set to/ {print $NF}' | sed 's/\.//g')

if [ -z "$CURRENT_HEX" ]; then
    echo "ERROR: Could not parse hwclock output: $RAW_OUT"
    exit 1
fi

# Convert hex (0x2) to decimal (2)
CURRENT_VAL=$(printf "%d" "$CURRENT_HEX")

# 3. Compare and Set
if [ "$CURRENT_VAL" -ne "$TARGET_VALUE" ]; then
    echo "Current BSM is $CURRENT_VAL. Updating to $TARGET_VALUE..."
    if $HWCLOCK -f "$RTC_DEVICE" --param-set "$PARAM_INDEX=$TARGET_VALUE"; then
        echo "SUCCESS: RTC parameter $PARAM_INDEX updated."
    else
        echo "ERROR: Failed to set parameter."
        exit 1
    fi
else
    echo "RTC BSM is already correctly set to $TARGET_VALUE (LSM)."
fi

exit 0