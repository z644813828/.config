# Proxmox UPS Migration

The USB UPS (051d:0002) belongs to the Proxmox host, not the OMV VM.
Do not run competing USB UPS managers or pass the device through to OMV.

## Verified Target State

- On 2026-11-01, apcupsd 3.14.14-5 was enabled and started on Proxmox.
  NUT services were inactive and pve-guests was active.
- USB Back-UPS BX1600MI reported ONLINE, charge 100 percent, load 38 percent,
  estimated runtime 11.5 minutes, and SELFTEST OK. These are reported values,
  not a measured battery discharge or end-to-end shutdown test.
- The daemon reported MBATTCHG 20, MINTIMEL 5, and MAXTIME 0.
- The package apccontrol shutdown handler is retained; no custom doshutdown hook
  was present. pve-guests stops guests during host shutdown.

## Configuration And Remaining Validation

- Merge `apcupsd.conf.example` into the package configuration, preserving other
  directives. Leave DEVICE empty for USB autodetection. The proposed 20 percent
  / 5 minute thresholds are preliminary, not a tested shutdown guarantee.
- Inspect package configuration and UPS state before enabling shutdown handling.
- Keep the package's shutdown handler; do not copy the legacy parent-directory
  `doshutdown` hook, which controls other machines and depends on old credentials.
- Bind the unauthenticated NIS listener to 127.0.0.1, not 0.0.0.0.
- Review battery thresholds against actual runtime and measured guest shutdown.
  The old 5 percent / 1 minute thresholds are not validated for this host.
- Verify Proxmox guest shutdown ordering and timeout before a controlled test.
- Connect host-side notifications separately; shutdown must not depend on OMV
  or Telegram being available.

Do not unplug mains power or invoke `doshutdown`, `killpower`, or `apctest`
as part of the initial inspection. Host/VM backups are still pending.
