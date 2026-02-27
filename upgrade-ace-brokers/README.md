# ACE Broker Upgrade Playbook

Ansible playbook for backing up and upgrading IBM ACE brokers.

## Quick Start

```bash
# Backup only
ansible-playbook playbook/main.yaml -i hosts.ini -e "broker_list=broker1,broker2"

# Backup + upgrade
ansible-playbook playbook/main.yaml -i hosts.ini -e "broker_list=broker1,broker2" -e "upgrade_brokers=true"
```

## Configuration

Edit `vars/main.yaml` before running:

| Variable | Default | Description |
|---|---|---|
| `broker_list` | `"TestNode"` | Comma-separated list of brokers to process |
| `env_name` | `"var"` | Environment name (`dev`, `tst`, `prd`, `prda`, `prdb`) |
| `old_ace_version` | `"12.0.12.22"` | Current installed ACE version |
| `new_ace_version` | `"13.0.6.2"` | Target ACE version to upgrade to |
| `backup_broker` | `true` | Run backup tasks |
| `upgrade_brokers` | `true` | Run upgrade tasks (requires `backup_broker: true`) |
| `is_multi_instance` | `true` | `true` = use `--shared-work-path`, `false` = use `--work-path` |
| `enable_trace` | `true` | Pass `--trace` flag to `ibmint extract node` |
| `overwrite_existing` | `true` | Pass `--overwrite-existing` flag to `ibmint extract node` |
| `backup_base_path` | `"/tmp/mqiibbkp"` | Directory where broker backups are stored (must pre-exist) |
| `work_path` | `"/var/mqsi"` | Work path for single-instance brokers |
| `shared_workpath` | `"/{{ env_name_normalized }}mqm/mqsi"` | Shared work path for multi-instance brokers |

> `prda` and `prdb` are both normalized to `prd` for path construction.

## Playbook Flow

```
main.yaml
├── backup.yaml          (when backup_broker: true)
│   ├── Assert backup_base_path exists
│   ├── Generate timestamp
│   ├── Validate broker_list
│   ├── Parse broker_list → brokers
│   ├── Validate brokers exist in mqsilist
│   ├── Display configuration
│   └── Backup all brokers (mqsibackupbroker)
│
├── upgrade.yaml         (when upgrade_brokers: true AND is_multi_instance: false)
│   ├── Assert work_path exists
│   ├── Stop all brokers (ibmint stop node)
│   └── Extract all brokers (ibmint extract node --work-path)
│
└── upgrade_multi_instance.yaml  (when upgrade_brokers: true AND is_multi_instance: true)
    ├── Assert shared_workpath exists
    ├── Stop all brokers (ibmint stop node)
    └── Extract all brokers (ibmint extract node --shared-work-path)
```

## File Structure

```
ansible/upgrade-ace-brokers/
├── playbook/
│   ├── main.yaml                    # Entry point
│   ├── backup.yaml                  # Backup tasks
│   ├── upgrade.yaml                 # Upgrade tasks (single instance)
│   └── upgrade_multi_instance.yaml  # Upgrade tasks (multi instance)
├── vars/
│   └── main.yaml                    # All configuration variables
├── hosts.ini                        # Target server inventory
└── README.md