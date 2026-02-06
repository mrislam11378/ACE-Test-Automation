#!/bin/bash
# Usage: ./run_all_tests.sh <BrokerName> <ExecutionGroupName> <QueueManagerName> [--log-base <path>] [--test-filter <pattern>] [--timeout <seconds>]

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
    echo "  --test-filter <pattern> - Filter test projects by pattern (default: GenTest_*)"
    echo "                           Examples: 'GenTest_MyApp*', 'GenTest_Specific', '*Integration*'"
    echo "  --timeout <seconds>    - Timeout for each test in seconds (default: 60)"
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
TEST_FILTER="GenTest_*"
TIMEOUT=60

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
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Base directories
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
echo " Timeout         : ${TIMEOUT}s per test"
if [ -n "$LOG_BASE" ]; then
    echo " Log Directory   : $LOG_BASE"
fi
echo " Summary File    : $SUMMARY_FILE"
echo "-------------------------------------------------------"

# Initialize summary file
echo "Test Project,Status,Passed,Failed,Aborted,Time(s),Log File" > "$SUMMARY_FILE"

# Track if there were any execution errors (not test failures)
EXECUTION_ERROR=0

# Count total tests for progress indicator
TOTAL_TESTS=$(find "$RUN_DIR" -maxdepth 1 -type d -name "$TEST_FILTER" | wc -l)
CURRENT_TEST=0

for TEST_PROJECT in "$RUN_DIR"/$TEST_FILTER; do
    if [ -d "$TEST_PROJECT" ]; then
        CURRENT_TEST=$((CURRENT_TEST + 1))
        PROJECT_NAME=$(basename "$TEST_PROJECT")
        LOG_FILE="${LOG_BASE}/${PROJECT_NAME}.log"
        CMD="IntegrationServer --work-dir ${SERVER_DIR} --no-nodejs --start-msgflows false --mq-queue-manager-name ${QM_NAME} --test-project ${PROJECT_NAME}"

        echo "-------------------------------------------------------"
        echo "Running test [$CURRENT_TEST/$TOTAL_TESTS]: $PROJECT_NAME"
        echo "-------------------------------------------------------"

        # Run command with timeout
        if [ -z "$LOG_BASE" ]; then
            # Console mode
            echo "Command: $CMD"
            echo "Timeout: ${TIMEOUT}s"
            OUTPUT=$(timeout "$TIMEOUT" bash -c "$CMD" 2>&1)
            CMD_EXIT=$?
            echo "$OUTPUT"
        else
            # File mode - always append
            echo "Writing output to: $LOG_FILE"
            echo "" >> "$LOG_FILE"
            echo "-------------------------------------------------------" >> "$LOG_FILE"
            echo "Test: $PROJECT_NAME [$CURRENT_TEST/$TOTAL_TESTS]" >> "$LOG_FILE"
            echo "Command: $CMD" >> "$LOG_FILE"
            echo "Started at: $(date)" >> "$LOG_FILE"
            echo "Timeout: ${TIMEOUT}s" >> "$LOG_FILE"
            echo "-------------------------------------------------------" >> "$LOG_FILE"
            OUTPUT=$(timeout "$TIMEOUT" bash -c "$CMD" 2>&1)
            CMD_EXIT=$?
            echo "$OUTPUT" >> "$LOG_FILE"
        fi

        # Check if command timed out
        if [ $CMD_EXIT -eq 124 ]; then
            echo "WARNING: Test timed out after ${TIMEOUT} seconds"
            STATUS="TIMEOUT"
            EXECUTION_ERROR=1
            PASSED=0
            FAILED=0
            ABORTED=0
            TIME=$TIMEOUT
        else
            # Extract test metrics with defaults
            PASSED=$(echo "$OUTPUT" | grep -oP '^\s*PASSED\s*:\K\d+' | tail -1 || echo "0")
            FAILED=$(echo "$OUTPUT" | grep -oP '^\s*FAILED\s*:\K\d+' | tail -1 || echo "0")
            ABORTED=$(echo "$OUTPUT" | grep -oP '^\s*ABORTED\s*:\K\d+' | tail -1 || echo "0")
            TIME=$(echo "$OUTPUT" | grep -oP '^\s*TIME\(secs\)\s*:\K[\d.]+' | tail -1 || echo "0")

            # Determine status - simplified logic
            if [ "$PASSED" = "0" ] && [ "$FAILED" = "0" ]; then
                STATUS="ERROR"
                EXECUTION_ERROR=1
            elif [ "$FAILED" -gt 0 ] || [ "$ABORTED" -gt 0 ]; then
                STATUS="FAIL"
            else
                STATUS="PASS"
            fi
        fi

        # Write to summary file
        echo "${PROJECT_NAME},${STATUS},${PASSED},${FAILED},${ABORTED},${TIME},${LOG_FILE:-}" >> "$SUMMARY_FILE"
    fi
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

# Exit with 0 if tests ran successfully (even if some tests failed)
# Exit with 1 only if there was an execution error
exit $EXECUTION_ERROR