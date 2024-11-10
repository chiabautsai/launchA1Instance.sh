#!/bin/bash

# Default retry delay in seconds
RETRY_DELAY=30

# Configuration parameters
COMPARTMENT_ID=$(oci iam compartment list --query 'data[0]."compartment-id"' --raw-output)
AVAILABILITY_DOMAIN="UWhT:US-SANJOSE-1-AD-1"
SHAPE="VM.Standard.A1.Flex"
SUBNET_ID=""
IMAGE_ID=""
METADATA='{"ssh_authorized_keys":""}'
SHAPE_CONFIG='{"ocpus":4,"memoryInGBs":24}'

# Function to print timestamped logs
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to extract error message from JSON output
parse_error_message() {
    local json_output="$1"
    local error_message

    # Check if output contains ServiceError and attempt to parse the message
    if echo "$json_output" | grep -q "ServiceError"; then
        error_message=$(echo "$json_output" | grep '"message":' | sed 's/.*"message": "\(.*\)",/\1/')
        if [ -n "$error_message" ]; then
            log "Error: $error_message"
        else
            # If parsing fails, return the full output
            log "$json_output"
        fi
    else
        # If output doesn't contain ServiceError, return as is
        log "$json_output"
    fi
}

launch_instance() {
    local result
    local exit_code
    
    # Run the OCI command and capture both output and exit code
    result=$(oci compute instance launch \
--compartment-id "${COMPARTMENT_ID}" \
--availability-domain "${AVAILABILITY_DOMAIN}" \
--image-id "${IMAGE_ID}" \
--shape "${SHAPE}" \
--shape-config "$SHAPE_CONFIG" \
--metadata "$METADATA" \
--subnet-id "${SUBNET_ID}" 2>&1)
    exit_code=$?
    
    # Parse and print the result
    if [ $exit_code -eq 0 ]; then
        log "Success:"
        log "$result"
    else
        parse_error_message "$result"
    fi

    # Return the exit code to the caller
    return $exit_code
}

# Main loop
while true; do
    echo "Attempting to launch instance..."

    # Call the launch function
    launch_instance

    # Check if the command was successful
    if [ $? -eq 0 ]; then
        log "Instance launch successful. Exiting..."
        break
    else
        log "Retrying in $RETRY_DELAY seconds..."
        sleep $RETRY_DELAY
    fi
done
