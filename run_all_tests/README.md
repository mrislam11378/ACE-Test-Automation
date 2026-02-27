# IBM ACE Test Automation

Automated testing framework for IBM App Connect Enterprise (ACE).

## Quick Start

```bash
# Run all tests with log directory
./run_all_tests.sh <BrokerName> <ExecutionGroupName> <QueueManagerName> --log-base /tmp/logs
```

## Options

| Parameter | Required | Description |
|-----------|----------|-------------|
| BrokerName | Yes | ACE Integration Node name |
| ExecutionGroupName | Yes | Integration Server name |
| QueueManagerName | Yes | MQ Queue Manager name |
| --log-base | Yes | Directory for log files and summary |

## Features

- ✅ Parameter validation with usage help
- ✅ Runs all test projects automatically
- ✅ File logging with command visibility
- ✅ Timestamped CSV summaries
- ✅ Formatted table output
- ✅ Proper exit codes (0=success, 1=error)

## Output

**Summary File:** `summary_<broker>_<eg>_<timestamp>.csv`

| Status | Meaning |
|--------|---------|
| PASS | All tests passed |
| FAIL | Some tests failed/aborted |
| ERROR | Execution error (no test output) |

**Example Summary Table:**
```
TEST SUMMARY
=================================================================================
Project                             Status     Pass     Fail     Abort    Time
GeneratedTests_OndorWorkflow        FAIL       4        6        0        0.14
GenTest_Common_Realtime_Workflow    FAIL       6        7        0        0.429
=================================================================================
```

**CSV Format:**
```csv
Test Project,Status,Passed,Failed,Aborted,Time(s),Log File
GenTest_Project1,PASS,10,0,0,5.23,/tmp/logs/GenTest_Project1.log
GenTest_Project2,FAIL,8,2,0,4.56,/tmp/logs/GenTest_Project2.log
```

## Example

```bash
# Run all tests
./run_all_tests.sh MyBroker MyEG MyQM --log-base /tmp/logs
```

## Exit Codes

- **0** = Tests ran successfully (check CSV for pass/fail)
- **1** = Execution error (validation or system error)

## Ansible Usage

### Configuration

Edit `ansible.yaml` or `ansible-embedded.yaml` variables:

**Required:**
```yaml
broker_name: "TestNode"                  # ACE broker name
eg_name: "TestServer"                    # Integration server name
qm_name: "MYQMGR"                        # Queue manager name
test_script_dir: "/path/to/dir"          # Script directory (ansible.yaml only)
ace_version: "12.0.12.22"                # ACE version
file_owner: "username"                   # File ownership user
file_group: "groupname"                  # File ownership group
```

**Optional:**
```yaml
log_dir_base: "/tmp/GenTestRun"          # Log directory (default)
delete_dsn_before_start: true            # Delete DSN before server start (WARNING)
mqsi_workpath: "/var/mqsi"               # Custom MQSI_WORKPATH if different
```

**Auto-configured:**
```yaml
ace_profile_path: "/opt/IBM/ace-{{ ace_version }}/server/bin/mqsiprofile"
ace_profile: "[ -f ~/.bash_profile ] && . ~/.bash_profile || . {{ ace_profile_path }}"
# Checks .bash_profile first, falls back to ACE profile
```

### Run Playbook

**Option 1: With External Script** (`ansible.yaml`)
```bash
# Localhost
ansible-playbook ansible.yaml -i "localhost," -c local

# Remote servers (edit hosts.ini first)
ansible-playbook -i hosts.ini ansible.yaml
```

**Option 2: Embedded Shell Script** (`ansible-embedded.yaml`)
```bash
# Localhost
ansible-playbook ansible-embedded.yaml -i "localhost," -c local

# Remote servers
ansible-playbook -i hosts.ini ansible-embedded.yaml
```

### Differences Between Playbooks

| Feature | ansible.yaml | ansible-embedded.yaml |
|---------|--------------|----------------------|
| Script dependency | Requires `run_all_tests.sh` | Self-contained |
| Portability | Need to distribute script | Single file |
| Maintenance | Separate files | All in one |
| Use case | Traditional setup | Simplified deployment |

### What It Does

1. **Generates timestamp** - Creates unique timestamp for this run
2. **Stops Integration Server** - Fails if can't stop
3. **Checks DSN directory** - Dry-run comparison (no copy)
4. **Sets up test environment** - Validates directories, creates summary file
5. **Runs all tests** - Executes all test projects, logs output
6. **Optionally deletes DSN** - If `delete_dsn_before_start: true`
7. **Starts Integration Server** - Brings server back up
8. **Displays formatted summary** - Shows test results in table format

### DSN Directory Check

The playbook uses `rsync` in dry-run mode with checksum comparison to detect differences between source and destination DSN directories. It reports what files differ but does not copy them.

### Test Output

Each test execution shows:
- Test project name
- Command being executed
- Log file location
- Test results (Pass/Fail/Abort counts)
- Execution time

Final summary displays formatted table with all results.