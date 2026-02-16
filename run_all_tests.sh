#!/bin/bash
# Usage: ./run_all_tests.sh <BrokerName> <ExecutionGroupName> <QueueManagerName> [--log-base <path>] [--test-filter <pattern>]

# Function to display usage
usage() {
    echo "Usage: $0 <BrokerName> <ExecutionGroupName> <QueueManagerName> [OPTIONS]"
    echo ""
    echo "Required parameters:"
    echo "  BrokerName             - Name of the broker"
    echo "  ExecutionGroupName     - Name of the execution group"
    echo "  QueueManagerName       - Name of the queue manager"
    echo ""
    echo "Optional parameters:"
    echo "  --log-base <path>      - Base directory for log files (default: console output)"
    echo "  --test-filter <pattern> - Filter test projects by pattern (default: all test projects)"
    echo "                           Examples: 'GenTest_MyApp*', 'GenTest_Specific', '*Integration*'"
    exit 1
}

# -----------------------------
# Parameters
# -----------------------------
BROKER_NAME=$1
EG_NAME=$2
QM_NAME=$3

# Validate required parameters
if [ -z "$BROKER_NAME" ] || [ -z "$EG_NAME" ] || [ -z "$QM_NAME" ]; then
    echo "Error: Missing required parameters"
    echo ""
    usage
fi

# Default values
LOG_BASE=""
TEST_FILTER=""

# Parse optional flags
shift 3
while [[ $# -gt 0 ]]; do
    case $1 in
        --log-base)
            LOG_BASE="$2"
            shift 2
            ;;
        --test-filter)
            TEST_FILTER="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Base directories
MQSI_WORKPATH="/var/mqsi"
SERVER_DIR="$MQSI_WORKPATH/components/${BROKER_NAME}/servers/${EG_NAME}"
RUN_DIR="${SERVER_DIR}/run"

# Generate timestamp for summary file
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Setup log directory and summary file
if [ -z "$LOG_BASE" ]; then
    # Console mode: use temp directory only for summary file
    SUMMARY_FILE="/tmp/summary_${BROKER_NAME}_${EG_NAME}_${TIMESTAMP}.csv"
else
    # File mode: create log directory and place summary there
    mkdir -p "$LOG_BASE"
    SUMMARY_FILE="${LOG_BASE}/summary_${BROKER_NAME}_${EG_NAME}_${TIMESTAMP}.csv"
fi

# Validation
if [ ! -d "$SERVER_DIR" ]; then
    echo "Error: Server directory not found: $SERVER_DIR"
    exit 1
fi
if [ ! -d "$RUN_DIR" ]; then
    echo "Error: Run directory not found: $RUN_DIR"
    exit 1
fi

echo "-------------------------------------------------------"
echo "Running tests for:"
echo " Broker          : $BROKER_NAME"
echo " Execution Group : $EG_NAME"
echo " Queue Manager   : $QM_NAME"
echo " Test Filter     : $TEST_FILTER"
if [ -n "$LOG_BASE" ]; then
    echo " Log Directory   : $LOG_BASE"
fi
echo " Summary File    : $SUMMARY_FILE"
echo "-------------------------------------------------------"

# Initialize summary file
echo "Test Project,Status,Passed,Failed,Aborted,Time(s),Log File" > "$SUMMARY_FILE"

# Track if there were any execution errors (not test failures)
EXECUTION_ERROR=0

# Find all test projects (directories with testproject.descriptor)
if [ -n "$TEST_FILTER" ]; then
    TEST_PROJECTS=$(find "$RUN_DIR" -maxdepth 1 -type d -name "$TEST_FILTER" | sort)
else
    TEST_PROJECTS=$(find "$RUN_DIR" -maxdepth 2 -name "testproject.descriptor" -exec dirname {} \; | sort)
fi

for TEST_PROJECT in $TEST_PROJECTS; do
    # Skip if not a directory or missing testproject.descriptor
    [ ! -d "$TEST_PROJECT" ] && continue
    [ ! -f "$TEST_PROJECT/testproject.descriptor" ] && continue
    
    PROJECT_NAME=$(basename "$TEST_PROJECT")
    LOG_FILE="${LOG_BASE}/${PROJECT_NAME}.log"
    CMD="IntegrationServer --work-dir ${SERVER_DIR} --no-nodejs --start-msgflows false --mq-queue-manager-name ${QM_NAME} --test-project ${PROJECT_NAME}"

    echo "-------------------------------------------------------"
    echo "Running test: $PROJECT_NAME"
    echo "-------------------------------------------------------"

    # Run command
    if [ -z "$LOG_BASE" ]; then
        # Console mode
        echo "Command: $CMD"
        OUTPUT=$(eval "$CMD" 2>&1)
        CMD_EXIT=$?
        echo "$OUTPUT"
    else
        # File mode - always append
        echo "Writing output to: $LOG_FILE"
        echo "" >> "$LOG_FILE"
        echo "-------------------------------------------------------" >> "$LOG_FILE"
        echo "Test: $PROJECT_NAME" >> "$LOG_FILE"
        echo "Command: $CMD" >> "$LOG_FILE"
        echo "Started at: $(date)" >> "$LOG_FILE"
        echo "-------------------------------------------------------" >> "$LOG_FILE"
        OUTPUT=$(eval "$CMD" 2>&1)
        CMD_EXIT=$?
        echo "$OUTPUT" >> "$LOG_FILE"
    fi

    # Extract test metrics with defaults (AIX-compatible)
    PASSED=$(echo "$OUTPUT" | grep 'PASSED' | grep ':' | sed 's/.*://;s/[^0-9]//g' | tail -1)
    FAILED=$(echo "$OUTPUT" | grep 'FAILED' | grep ':' | sed 's/.*://;s/[^0-9]//g' | tail -1)
    ABORTED=$(echo "$OUTPUT" | grep 'ABORTED' | grep ':' | sed 's/.*://;s/[^0-9]//g' | tail -1)
    TIME=$(echo "$OUTPUT" | grep 'TIME(secs)' | grep ':' | sed 's/.*://;s/[^0-9.]//g' | tail -1)
    
    # Set defaults if empty
    PASSED=${PASSED:-0}
    FAILED=${FAILED:-0}
    ABORTED=${ABORTED:-0}
    TIME=${TIME:-0}

    # Determine status - simplified logic
    if [ "$PASSED" = "0" ] && [ "$FAILED" = "0" ]; then
        STATUS="ERROR"
        EXECUTION_ERROR=1
    elif [ "$FAILED" -gt 0 ] || [ "$ABORTED" -gt 0 ]; then
        STATUS="FAIL"
    else
        STATUS="PASS"
    fi

    # Write to summary file
    echo "${PROJECT_NAME},${STATUS},${PASSED},${FAILED},${ABORTED},${TIME},${LOG_FILE:-}" >> "$SUMMARY_FILE"
done

echo
echo "-------------------------------------------------------"
echo "TEST SUMMARY"
echo "-------------------------------------------------------"
# Display summary table (7 columns: Test Project, Status, Passed, Failed, Aborted, Time, Log File)
awk -F, '{printf "%-35s %-8s %-8s %-8s %-8s %-10s %s\n", $1,$2,$3,$4,$5,$6,$7}
         NR==1 {print "---------------------------------------------------------------------------------------------------"}' "$SUMMARY_FILE"
echo "-------------------------------------------------------"
if [ -n "$LOG_BASE" ]; then
    echo "Full logs are available under: $LOG_BASE"
    echo "-------------------------------------------------------"
fi
echo "SUMMARY_FILE_PATH=${SUMMARY_FILE}"

# Exit with 0 if tests ran successfully (even if some tests failed)
# Exit with 1 only if there was an execution error
exit $EXECUTION_ERROR