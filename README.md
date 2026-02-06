# IBM ACE Test Automation

Automated testing framework for IBM App Connect Enterprise (ACE) using Ansible and shell scripts.

## Files

- **ansible.yaml** - Ansible playbook that orchestrates ACE test execution
- **run_all_tests.sh** - Shell script that runs all test projects and generates summary reports
- **hosts.ini** - Inventory file for remote execution

## Quick Start

```bash
# Run with Ansible (localhost)
ansible-playbook ansible.yaml -i "localhost," -c local

# Run with Ansible (remote servers)
ansible-playbook -i hosts.ini ansible.yaml

# Run script directly (console mode - default)
./run_all_tests.sh TestNode TestServer MYQMGR

# Run script directly (file logging mode)
./run_all_tests.sh TestNode TestServer MYQMGR --log-base /tmp/logs
```

## Configuration

Edit `ansible.yaml` variables:
- `broker_name` - ACE Integration Node name
- `eg_name` - Integration Server name
- `qm_name` - MQ Queue Manager name
- `test_script_dir` - Directory where run_all_tests.sh is located
- `ace_profile` - Path to ACE profile script
- `log_dir_base` - Base directory for test logs (enables file logging mode)
  - If set: Logs written to `/tmp/<broker>_<server>_<timestamp>/`
  - If empty/commented: Console mode (no log files, summary only)

## Features

- Stops/starts Integration Server automatically
- Copies DSN configuration if missing
- Runs all `GenTest_*` projects sequentially
- Generates CSV summary report with test metrics
- Two logging modes:
  - **Console mode** (default): Output to console, summary in `/tmp/ace_test_summary_75975.csv`
  - **File mode**: Individual test logs + summary in specified directory

## Output

### Console Mode (default)
- Test output displayed in console
- Summary report: `/tmp/ace_test_summary_75975.csv`

### File Mode (when `log_dir_base` is set)
Results saved to `/tmp/<broker>_<server>_<timestamp>/`:
- Individual test logs: `<project_name>.log`
- Summary report: `summary.csv`
- Timestamp format: `YYYY-MM-DD_HHMMSS`