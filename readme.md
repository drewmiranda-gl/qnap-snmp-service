# What is this?

This is a simple bash script that queries QNAP web address in order to:

* Determine the current status of the SNMP Service (0=disable/stopped, 1=enabled/started)
* Enable/Start SNMP Service
* Disable/Stop SNMP Service

I needed to create this due to what appears to be a bug with QNAP's snmp service where each time a SNMP query is sent, the query time takes long and longer and longer. Eventually the SNMP service will take so long it times out before returning any results. Restarting the SNMP service addresses this.

# How to use

Download files

* `qnap_api.sh`
* `qnap_config.sh`

Configure variables in `qnap_config.sh`

| Variables | Description |
| ---- | ---- |
| `base_qnap_host` | base hostname to use when sending curl requests. May contain a port. MUST NOT have a trailing slash. |
| `username` | Username to use for curl requests |
| `pwd_in_plain_text` | Plaintext password for above username |
| `GELF_URI` | URI to use when sending GELF message to Graylog<br>Example: http://hostname.domain.tld:12201/gelf | 

# Usage and examples

Available commands

| Command | Description | 
| ---- | ---- |
| `status` | Get current SNMP status |
| `disable` `stop` | Stop SNMP service |
| `enable` `start` | Start SNMP service |
| `restart` | Stop and Start SNMP service. The same as calling `stop` and then `start` |
| `firmware` | Check for firmware update. Will return current and new firmware version.


## View SNMP Status

```
./qnap_api.sh status

Command: status
checking SNMP service status...
Status: 1
```

## Stop SNMP

```
./qnap_api.sh disable

Command: disable
Current Status: 1 (started/enabled)
disabling SNMP service...
Status: 0 (stopped/disabled)
```

## Start SNMP

```
./qnap_api.sh enable

Command: enable
Current Status: 0 (stopped/disabled)
enabling SNMP service...
Status: 1 (started/enabled)
```

## Restart SNMP

```
./qnap_api.sh restart

Command: restart
Current Status: 1 (started/enabled)
disabling SNMP service...
Status: 0 (stopped/disabled)
enabling SNMP service...
Status: 1 (started/enabled)
```

## Check for updated Firmware

```
./qnap_api.sh firmware

Command: firmware
New Firmware Available: 5.2.0.2851
{"message":"New Firmware Available for QNAP", "qnap_cur_ver":"5.1.8.2823", "qnap_new_ver":"5.2.0.2851", "hostname":"pve-metrics1", "source":"pve-metrics1", "tag":"qnap_api"}
```

# Tested and Validated on

* TS-462