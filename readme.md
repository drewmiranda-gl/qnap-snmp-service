# What is this?

This is a simple bash script that queries QNAP web address in order to:

* Determine the current status of the SNMP Service (0=disable/stopped, 1=enabled/started)
* Enable/Start SNMP Service
* Disable/Stop SNMP Service

I needed to create this due to what appears to be a bug with QNAP's snmp service where each time a SNMP query is sent, the query time takes long and longer and longer. Eventually the SNMP service will take so long it times out before returning any results. Restarting the SNMP service addresses this.

# How to use

Download files

* `qnap_snmp.sh`
* `qnap_snmp_config.sh`

Configure variables in `qnap_snmp_config.sh`

| Variables | Description |
| ---- | ---- |
| `base_qnap_host` | base hostname to use when sending curl requests. May contain a port. MUST NOT have a trailing slash. |
| `username` | Username to use for curl requests |
| `pwd_in_plain_text` | Plaintext password for above username |

# Usage and examples

## View SNMP Status

```
./qnap_snmp.sh status

Command: status
checking SNMP service status...
Status: 1
```

## Stop SNMP

```
./qnap_snmp.sh disable

Command: disable
Current Status: 1 (started/enabled)
disabling SNMP service...
Status: 0 (stopped/disabled)
```

## Start SNMP

```
./qnap_snmp.sh enable

Command: enable
Current Status: 0 (stopped/disabled)
enabling SNMP service...
Status: 1 (started/enabled)
```

## Restart SNMP

```
./qnap_snmp.sh restart

Command: restart
Current Status: 1 (started/enabled)
disabling SNMP service...
Status: 0 (stopped/disabled)
enabling SNMP service...
Status: 1 (started/enabled)
```

# Tested and Validated on

* TS-462