# IBM App Connect Test Automation

The testing automation framework provides comprehensive automated testing for IBM App Connect Enterprise messageflows, using generated JUnit tests from recorded messages.

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│           Test Automation Workflow                      │
├─────────────────────────────────────────────────────────┤
│  Phase 1: Pre-Test Setup                                │
│    ├─ Generate timestamp                                │
│    ├─ Stop Integration Server                           │
│    ├─ Check DSN directory differences                   │
│    └─ Clean log directory (optional)                    │
│                                                         │
│  Phase 2: Test Execution                                │
│    ├─ Validate directories exist                        │
│    ├─ Auto-discover test projects                       │
│    ├─ For each test project:                            │
│    │   ├─ Execute IntegrationAPI --test-project         │
│    │   ├─ Parse PASSED/FAILED/ABORTED/TIME              │
│    │   ├─ Determine status (PASS/FAIL/ERROR)            │
│    │   └─ Write to CSV summary                          │
│    └─ Log all output to individual files                │
│                                                         │
│  Phase 3: Post-Test Processing                          │
│    ├─ Start Integration Server                          │
│    ├─ Display formatted summary table                   │
│    ├─ Create zip archive of logs                        │
│    └─ Send email with attachments                       │
└─────────────────────────────────────────────────────────┘
```

## Features

- ✅ Parameter validation
- ✅ Runs all test projects automatically
- ✅ File logging with command visibility
- ✅ Timestamped CSV summaries
- ✅ Formatted table output
- ✅ Proper exit codes (0=success, 1=error)
- ✅ Modular playbook structure
- ✅ DSN directory validation

## Test Generation and Automation

IBM App Connect Enterprise facilitates test-driven development through its test framework, enabling rapid adoption of new product versions and architectural changes. Integration tests verify that flows operate correctly after development changes, upgrades, or modifications to external services.

### Test Automation Pipeline

1. **Message Capture** - Record live traffic from v12 integration brokers
2. **Test Generation** - Generate JUnit test suites from recorded messages
3. **Build (CI)** - Build BAR files containing test projects via GitHub Actions
4. **Deploy (CD)** - Deploy test projects to target environments via UrbanCode Deploy

### 1. Message Capture

Enable message recording by configuring the `RecordedMessageManager` in `server.conf.yaml`:

```yaml
ResourceManagers:
  RecordedMessageManager:
    recordedMessagePath: 'C:\temp\IntegrationServer\recorded_messages'
    recordAllMessages: true
```

**Steps:**
1. Restart the execution group (full broker restart not recommended)
2. Invoke the application to generate traffic
3. Recorded messages are saved as `.mxml` files in the specified directory
4. To stop recording, set `recordAllMessages: false` and restart

### 2. Test Generation

Generate JUnit tests from recorded messages using IBM App Connect Enterprise Toolkit:

```bash
ibmint generate tests \
  --recorded-messages mmc/OndotWorkflow/ \
  --output-test-project GeneratedTestProjects/Generated_Tests_OnDotWorkflow \
  --java-class com.nfcu.tests
```

**Optional: Analyze Message Coverage**

Use `msgindex` to identify which flow nodes were exercised by each recorded message:

```bash
ibmint generate msgindex --recorded-messages mmc/OndotWorkflow/
```

**Generated Test Project Structure:**
```
GeneratedTests_OndotWorkflow/
├── .classpath
├── .project
├── testproject.descriptor
└── src/main/
    ├── java/com/nfcu/tests/
    │   └── WholeFlow_OndorWorkflow_Tests.java
    └── resources/
        ├── 00006977-68DD7AF7-00000001-0.mxml
        ├── 00006977-68DD7AF7-00000001-1.mxml
        └── ... (additional .mxml files)
```

### 3. Continuous Integration (GitHub Actions)

Test projects are committed to GitHub with a `build.xml` file. GitHub Actions:
- Build test project BAR files using `ant` and `ibmint`
- Place BAR files in a location accessible to UrbanCode Deploy
- Create UrbanCode tags to trigger deployment

### 4. Continuous Deployment (UrbanCode Deploy)

UrbanCode Deploy:
- Monitors for new BAR files and tags
- Deploys test projects to target environments using `mqsideploybar`
- Triggers Ansible test automation after deployment

**Complete CI/CD Pipeline:**

```
┌─────────────────┐
│  Developer      │
│  Commits Code   │
└────────┬────────┘
         ↓
┌─────────────────┐
│ GitHub Actions  │
│ Build & Package │
└────────┬────────┘
         ↓
┌─────────────────┐
│ UrbanCode Deploy│
│ Deploy to AIX   │
└────────┬────────┘
         ↓
┌─────────────────┐
│ Ansible         │
│ Run Tests       │
└────────┬────────┘
         ↓
┌─────────────────┐
│ Email/Splunk    │
│ Report Results  │
└─────────────────┘
```


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

## Ansible Usage

### Survey Variables

The following variables are coming in from the survey:

```yaml
env_name: "intg"                         # Environment name (used in paths)
broker_name: "mmcbroker1"                # ACE Integration Node name
eg_name: "mmc,SalesForce01"              # Integration Server name (single or comma-separated list)
qm_name: "IVIMMC1"                       # Queue Manager name
ace_version: "13.0.6.1"                  # ACE version
to_emails: ""                            # Leave empty to skip email notification
cc_emails: []                            # List of CC recipients
cleanup_log: false                       # Clean log directory before run
```

### Playbook Structure

The modular playbook structure provides better organization and reusability:

**Main Files:**
- **playbook/main.yaml** - Main entry point, handles single/multiple servers
- **playbook/run_all_tests.yaml** - Core test execution logic
- **playbook/check_prereqs.yaml** - Prerequisite validation (checks required variables)
- **vars/main.yaml** - Centralized configuration variables

### What It Does

1. **Validates prerequisites** - Checks all required variables are defined (`env_name`, `mqm_user`, `mqm_group`, `broker_name`, `qm_name`, `eg_name`, `cc_emails`, `to_emails`)
2. **Parses server list** - Splits comma-separated `eg_name` if multiple servers specified
3. **For each server:**
   - **Generates timestamp** - Creates unique timestamp for this run
   - **Stops Integration Server** - Uses `become` to run as mqm user
   - **Checks DSN directory** - Dry-run rsync comparison (no copy)
   - **Optionally cleans logs** - If `cleanup_log: true`
   - **Sets up test environment** - Validates directories, creates summary CSV
   - **Runs all tests** - Executes all test projects with ODBC environment
   - **Optionally deletes DSN** - If `delete_dsn_before_start: true`
   - **Starts Integration Server** - Brings server back up
   - **Creates zip archive** - Archives all logs to `archive_path`
   - **Sends email** - Attaches summary CSV and zip file (if `to_emails` configured)
   - **Displays formatted summary** - Shows test results in table format


### Test Output

Each test execution shows:
- Test project name
- Command being executed
- Log file location
- Test results (Pass/Fail/Abort counts)
- Execution time

**Log Files:**
- Individual test logs: `{{ log_dir_base }}/<Test ProjectName>.log`
- Summary CSV: `{{ log_dir_base }}/summary_<broker>_<eg>_<timestamp>.csv`
- Archive: `{{ archive_path }}/<broker>_<eg>_<timestamp>_archive.zip`

**Email Notification:**
When `to_emails` is configured, an email is sent with:
- DSN directory differences
- Test summary table
- Attached summary CSV
- Attached zip archive of all logs

Final summary displays formatted table with all results.

### Multiple Server Support

The `eg_name` variable supports both single and multiple Integration Servers:

**Single Server:**
```yaml
eg_name: "TestServer"
```

**Multiple Servers (comma-separated):**
```yaml
eg_name: "server1,server2,server3"
```

When multiple servers are specified, the playbook runs tests on each server sequentially. Each server will:
- Stop independently
- Run its own tests
- Generate separate logs and summaries (timestamped per server)
- Start back up
- Send separate email notifications (if configured)

**Example Output Files:**
```
/intgmqm/recorded_messages/logs/summary_TestNode_server1_20260324_153045.csv
/intgmqm/recorded_messages/logs/summary_TestNode_server2_20260324_153145.csv
/intgmqm/recorded_messages/logs/summary_TestNode_server3_20260324_153245.csv
```