#!/bin/bash
# Usage: ./run_all_tests.sh <BrokerName> <ExecutionGroupName> <QueueManagerName> --log-base <path>

# Function to display usage
usage() {
    echo "Usage: $0 <BrokerName> <ExecutionGroupName> <QueueManagerName> --log-base <path>"
    echo ""
    echo "Required parameters:"
    echo "  BrokerName             - Name of the broker"
    echo "  ExecutionGroupName     - Name of the execution group"
    echo "  QueueManagerName       - Name of the queue manager"
    echo "  --log-base <path>      - Base directory for log files"
    exit 1
}

# Function to parse command line arguments
parse_arguments() {
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

    # Parse optional flags
    shift 3
    while [[ $# -gt 0 ]]; do
        case $1 in
            --log-base)
                LOG_BASE="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Validate log-base is provided
    if [ -z "$LOG_BASE" ]; then
        echo "Error: --log-base is required"
        echo ""
        usage
    fi
}

# Function to setup and validate environment
setup_environment() {
    # Base directories
    MQSI_WORKPATH="/var/mqsi"
    SERVER_DIR="$MQSI_WORKPATH/components/${BROKER_NAME}/servers/${EG_NAME}"
    RUN_DIR="${SERVER_DIR}/run"

    # Validate directories exist
    [ ! -d "$SERVER_DIR" ] && { echo "Error: Server directory not found: $SERVER_DIR"; exit 1; }
    [ ! -d "$RUN_DIR" ] && { echo "Error: Run directory not found: $RUN_DIR"; exit 1; }

    # Setup summary file path
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    mkdir -p "$LOG_BASE"
    SUMMARY_FILE="${LOG_BASE}/summary_${BROKER_NAME}_${EG_NAME}_${TIMESTAMP}.csv"

    # Initialize summary file and display configuration
    echo "Test Project,Status,Passed,Failed,Aborted,Time(s),Log File" > "$SUMMARY_FILE"
    
    echo "-------------------------------------------------------"
    echo "Running tests for:"
    echo " Broker          : $BROKER_NAME"
    echo " Execution Group : $EG_NAME"
    echo " Queue Manager   : $QM_NAME"
    echo " Log Directory   : $LOG_BASE"
    echo " Summary File    : $SUMMARY_FILE"
    echo "-------------------------------------------------------"
}

# Function to find test projects
find_test_projects() {
    TEST_PROJECTS=$(find "$RUN_DIR" -maxdepth 2 -name "testproject.descriptor" -exec dirname {} \; | sort)
}

# Function to run a single test
run_test() {
    local test_project=$1
    local project_name=$(basename "$test_project")
    local log_file="${LOG_BASE}/${project_name}.log"
    local cmd="IntegrationServer --work-dir ${SERVER_DIR} --no-nodejs --start-msgflows false --mq-queue-manager-name ${QM_NAME} --test-project ${project_name}"

    echo "-------------------------------------------------------"
    echo "Running test: $project_name"
    echo "Command: $cmd"
    echo "-------------------------------------------------------"
    echo "Writing output to: $log_file"

    # Run command and log
    local output
    {
        echo ""
        echo "-------------------------------------------------------"
        echo "Test: $project_name"
        echo "Command: $cmd"
        echo "Started at: $(date)"
        echo "-------------------------------------------------------"
        output=$(eval "$cmd" 2>&1)
        echo "$output"
    } >> "$log_file"

    # Return output for parsing
    echo "$output"
}

# Function to process test results
process_test_results() {
    local output=$1
    local project_name=$2
    local log_file=$3
    
    # Extract test metrics (AIX-compatible)
    PASSED=$(echo "$output" | grep 'PASSED' | grep ':' | sed 's/.*://;s/[^0-9]//g' | tail -1)
    FAILED=$(echo "$output" | grep 'FAILED' | grep ':' | sed 's/.*://;s/[^0-9]//g' | tail -1)
    ABORTED=$(echo "$output" | grep 'ABORTED' | grep ':' | sed 's/.*://;s/[^0-9]//g' | tail -1)
    TIME=$(echo "$output" | grep 'TIME(secs)' | grep ':' | sed 's/.*://;s/[^0-9.]//g' | tail -1)
    
    # Set defaults and determine status
    PASSED=${PASSED:-0}
    FAILED=${FAILED:-0}
    ABORTED=${ABORTED:-0}
    TIME=${TIME:-0}
    
    if [ "$PASSED" = "0" ] && [ "$FAILED" = "0" ]; then
        STATUS="ERROR"
        EXECUTION_ERROR=1
    elif [ "$FAILED" -gt 0 ] || [ "$ABORTED" -gt 0 ]; then
        STATUS="FAIL"
    else
        STATUS="PASS"
    fi
    
    # Write to summary file
    echo "${project_name},${STATUS},${PASSED},${FAILED},${ABORTED},${TIME},${log_file:-}" >> "$SUMMARY_FILE"
}

# Function to display test summary
display_test_summary() {
    echo
    echo "TEST SUMMARY"
    echo "================================================================================="
    awk -F, 'BEGIN {printf "%-35s %-10s %-8s %-8s %-8s %-8s\n", "Project", "Status", "Pass", "Fail", "Abort", "Time" }
         NR>1 {printf "%-35s %-10s %-8s %-8s %-8s %-8s\n", $1, $2, $3, $4, $5, $6}' "$SUMMARY_FILE"
    echo "================================================================================="
}

# -----------------------------
# Main execution flow
# -----------------------------

parse_arguments "$@"
setup_environment

EXECUTION_ERROR=0
find_test_projects

# Run each test project
for TEST_PROJECT in $TEST_PROJECTS; do
    [ ! -d "$TEST_PROJECT" ] && continue
    [ ! -f "$TEST_PROJECT/testproject.descriptor" ] && continue
    
    PROJECT_NAME=$(basename "$TEST_PROJECT")
    LOG_FILE="${LOG_BASE}/${PROJECT_NAME}.log"
    
    OUTPUT=$(run_test "$TEST_PROJECT")
    process_test_results "$OUTPUT" "$PROJECT_NAME" "$LOG_FILE"
done

display_test_summary
exit $EXECUTION_ERROR