# IBM ACE Test Automation

Automated testing framework for IBM App Connect Enterprise (ACE).

## Quick Start

```bash
# Basic usage
./run_all_tests.sh <BrokerName> <ExecutionGroupName> <QueueManagerName>

# With options
./run_all_tests.sh MyBroker MyEG MyQM --log-base /tmp/logs --test-filter "GenTest_*"
```

## Options

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| BrokerName | Yes | - | ACE Integration Node name |
| ExecutionGroupName | Yes | - | Integration Server name |
| QueueManagerName | Yes | - | MQ Queue Manager name |
| --log-base | No | console | Directory for log files |
| --test-filter | No | GenTest_* | Pattern to filter test projects |

## Features

- ✅ Parameter validation with usage help
- ✅ Test filtering by pattern
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
| ERROR | Execution error (no test output) |

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

# All options
./run_all_tests.sh MyBroker MyEG MyQM --log-base /tmp/logs --test-filter "GenTest_*"
```

## Exit Codes

- **0** = Tests ran successfully (check CSV for pass/fail)
- **1** = Execution error (validation or system error)

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
log_dir_base: "/tmp/GenTestRun"          # Log directory (default)
test_filter: "GenTest_*"                 # Test pattern filter
delete_dsn_before_start: true            # Delete DSN before server start (WARNING)
mqsi_work_path: "/var/mqsi"              # Custom MQSI_WORKPATH if different
```

### Run Playbook

```bash
# Localhost
ansible-playbook ansible.yaml -i "localhost," -c local

# Remote servers (edit hosts.ini first)
ansible-playbook -i hosts.ini ansible.yaml
```

### What It Does

1. Stops Integration Server (fails if can't stop)
2. Checks DSN directory differences (dry-run, no copy)
3. Runs all tests via `run_all_tests.sh`
4. Optionally deletes DSN directory (if enabled)
5. Starts Integration Server
6. Displays test summary

### DSN Directory Check

The playbook uses `rsync` in dry-run mode with checksum comparison to detect differences between source and destination DSN directories. It reports what files differ but does not copy them.