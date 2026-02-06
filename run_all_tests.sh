#!/bin/bash
# Usage: ./run_all_tests.sh <BrokerName> <ExecutionGroupName> <QueueManagerName> [--log-base <path>]

# -----------------------------
# Parameters
# -----------------------------
BROKER_NAME=$1
EG_NAME=$2
QM_NAME=$3

# Default values
LOG_BASE=""
LOG_MODE="console"

# Parse optional flags
shift 3
while [[ $# -gt 0 ]]; do
    case $1 in
        --log-base)
            LOG_BASE="$2"
            LOG_MODE="file"
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

# Setup log directory and summary file
if [ -z "$LOG_BASE" ]; then
    # Console mode: use temp directory only for summary file
    SUMMARY_FILE="/tmp/ace_test_summary_$$.csv"
else
    # File mode: create log directory and place summary there
    mkdir -p "$LOG_BASE"
    SUMMARY_FILE="${LOG_BASE}/summary.csv"
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
echo " Log Mode        : $LOG_MODE"
if [ "$LOG_MODE" = "file" ]; then
    echo " Log Directory   : $LOG_BASE"
fi
echo " Summary File    : $SUMMARY_FILE"
echo "-------------------------------------------------------"

# Initialize summary file
echo "Test Project,Status,Passed,Failed,Aborted,Time(s),Log File" > "$SUMMARY_FILE"

OVERALL_EXIT=0

for TEST_PROJECT in "$RUN_DIR"/GenTest_*; do
    if [ -d "$TEST_PROJECT" ]; then
        PROJECT_NAME=$(basename "$TEST_PROJECT")
        LOG_FILE="${LOG_BASE}/${PROJECT_NAME}.log"
        CMD="IntegrationServer --work-dir ${SERVER_DIR} --no-nodejs --start-msgflows false --mq-queue-manager-name ${QM_NAME} --test-project ${PROJECT_NAME}"

        echo "Running test: $PROJECT_NAME"

        if [ "$LOG_MODE" = "console" ]; then
            echo "-------------------------------------------------------"
            echo "Command: $CMD"
            echo "-------------------------------------------------------"
            OUTPUT=$(eval "$CMD" 2>&1)
            EXIT_CODE=$?
            echo "$OUTPUT"
        else
            echo "  Writing output to: $LOG_FILE"
            echo "-------------------------------------------------------" > "$LOG_FILE"
            echo "Command: $CMD" >> "$LOG_FILE"
            echo "Started at: $(date)" >> "$LOG_FILE"
            echo "-------------------------------------------------------" >> "$LOG_FILE"
            OUTPUT=$(eval "$CMD" 2>&1)
            EXIT_CODE=$?
            echo "$OUTPUT" >> "$LOG_FILE"
        fi

        # Extract test metrics from output (PASSED, FAILED, ABORTED, TIME)
        PASSED=$(echo "$OUTPUT" | grep -oP '^\s*PASSED\s*:\K\d+' | tail -1)
        FAILED=$(echo "$OUTPUT" | grep -oP '^\s*FAILED\s*:\K\d+' | tail -1)
        ABORTED=$(echo "$OUTPUT" | grep -oP '^\s*ABORTED\s*:\K\d+' | tail -1)
        TIME=$(echo "$OUTPUT" | grep -oP '^\s*TIME\(secs\)\s*:\K[\d.]+' | tail -1)
        PASSED=${PASSED:-0}
        FAILED=${FAILED:-0}
        ABORTED=${ABORTED:-0}
        TIME=${TIME:-0}

        if [ $EXIT_CODE -ne 0 ]; then
            STATUS="FAIL"
            OVERALL_EXIT=1
        else
            STATUS="PASS"
        fi

        # Write to summary file
        if [ "$LOG_MODE" = "console" ]; then
            echo "${PROJECT_NAME},${STATUS},${PASSED},${FAILED},${ABORTED},${TIME}," >> "$SUMMARY_FILE"
        else
            echo "${PROJECT_NAME},${STATUS},${PASSED},${FAILED},${ABORTED},${TIME},${LOG_FILE}" >> "$SUMMARY_FILE"
        fi
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
if [ "$LOG_MODE" = "file" ]; then
    echo "Full logs are available under: $LOG_BASE"
    echo "-------------------------------------------------------"
fi

exit $OVERALL_EXIT