# IBM ACE Test Automation

Automated testing framework for IBM App Connect Enterprise (ACE).

## Quick Start

```bash
# Basic usage
./run_all_tests.sh <BrokerName> <ExecutionGroupName> <QueueManagerName>

# With options
./run_all_tests.sh MyBroker MyEG MyQM --log-base /tmp/logs --test-filter "GenTest_*" --timeout 60
```

## Options

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| BrokerName | Yes | - | ACE Integration Node name |
| ExecutionGroupName | Yes | - | Integration Server name |
| QueueManagerName | Yes | - | MQ Queue Manager name |
| --log-base | No | console | Directory for log files |
| --test-filter | No | GenTest_* | Pattern to filter test projects |
| --timeout | No | 60 | Timeout per test in seconds |

## Features

- ✅ Parameter validation with usage help
- ✅ Test filtering by pattern
- ✅ Configurable timeout (prevents hanging)
- ✅ Progress indicator (e.g., "Test 3/10")
- ✅ Console or file logging
- ✅ Log appending (tracks test history)
- ✅ Timestamped CSV summaries
- ✅ Proper exit codes (0=success, 1=error)

## Output

**Summary File:** `summary_<broker>_<eg>_<timestamp>.csv`

| Status | Meaning |
|--------|---------|
| PASS | All tests passed |
| FAIL | Some tests failed/aborted |
| TIMEOUT | Test exceeded timeout |
| ERROR | Execution error |

**Example:**
```csv
Test Project,Status,Passed,Failed,Aborted,Time(s),Log File
GenTest_Project1,PASS,10,0,0,5.23,/tmp/logs/GenTest_Project1.log
GenTest_Project2,FAIL,8,2,0,4.56,/tmp/logs/GenTest_Project2.log
```

## Examples

```bash
# Console output only
./run_all_tests.sh MyBroker MyEG MyQM

# Save logs to files
./run_all_tests.sh MyBroker MyEG MyQM --log-base /tmp/logs

# Filter specific tests
./run_all_tests.sh MyBroker MyEG MyQM --test-filter "GenTest_Payment*"

# Custom timeout
./run_all_tests.sh MyBroker MyEG MyQM --timeout 300

# All options
./run_all_tests.sh MyBroker MyEG MyQM --log-base /tmp/logs --test-filter "GenTest_*" --timeout 120
```

## Exit Codes

- **0** = Tests ran successfully (check CSV for pass/fail)
- **1** = Execution error (validation, timeout, or system error)

## Ansible Usage

### Configuration

Edit `ansible.yaml` variables:

**Required:**
```yaml
broker_name: "TestNode"          # ACE broker name
eg_name: "TestServer"            # Integration server name
qm_name: "MYQMGR"                # Queue manager name
test_script_dir: "/path/to/dir"  # Script directory
ace_profile: ". /path/to/mqsiprofile"  # ACE profile
file_owner: "username"           # File ownership user
file_group: "groupname"          # File ownership group
```

**Optional:**
```yaml
log_dir_base: "/tmp/GenTestRun"  # Log directory (default)
test_filter: "GenTest_*"         # Test pattern filter
test_timeout: 60                 # Timeout per test (seconds)
```

### Run Playbook

```bash
# Localhost
ansible-playbook ansible.yaml -i "localhost," -c local

# Remote servers (edit hosts.ini first)
ansible-playbook -i hosts.ini ansible.yaml
```

### What It Does

1. Stops Integration Server
2. Copies DSN directory if missing
3. Runs all tests via `run_all_tests.sh`
4. Starts Integration Server
5. Displays test summary