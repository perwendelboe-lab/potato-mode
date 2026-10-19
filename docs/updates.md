# Running `omarchy update` unattended (Omarchy 4.0.5)

## Problem (seen in the 1 GB VM, 4.0.4 → 4.0.5)
`omarchy update -y` still stopped twice, at `gum confirm` prompts:
1. `omarchy-update-orphan-pkgs`: "Remove 1 orphaned package(s)?"
2. `omarchy-update-restart`: "Linux kernel has been updated. Reboot?"

Cause (from /usr/bin in 4.0.5): `omarchy-update` re-runs itself under `script -qefc … /tmp/omarchy-update.log`,
which gives the steps a pseudo-terminal. The orphan step only skips its prompt when stdin/stdout are **not** a TTY,
and the restart step always calls `gum confirm`. `-y` sets `OMARCHY_UPDATE_UNATTENDED=1`, but neither step checks it.

## Workaround (tested 2026-10-19 on 4.0.5)
Run it without the `script` wrapper and without a terminal:

```sh
OMARCHY_UPDATE_LOGGED=1 omarchy update -y </dev/null >~/omarchy-update.log 2>&1
# over ssh / from cron, also: OMARCHY_PATH=/usr/share/omarchy (unset outside the desktop session)
```

- Orphans: the step printed "1 orphaned package(s) found. Re-run omarchy-update-orphan-pkgs in a terminal…" and
  **kept** them (verified).
- Reboot: with no controlling terminal, `gum confirm` fails ("could not open TTY", exit 1), which counts as **no**. So
  the machine is **never rebooted automatically**. Reboot yourself later (`omarchy-system-reboot`). This was checked by running
  `gum confirm` without a TTY. The kernel prompt itself wasn't hit in the workaround run (no kernel update was pending).
- Side effects: no /tmp/omarchy-update.log (one step greps it and prints "No such file"; harmless), and "Omarchy shell did not
  become ready after restart" when no desktop session is attached.
- The potato-mode post-update hook still runs (applied-at was updated during the run).

potato-mode does **not** answer the reboot prompt for you, by design. Interactively, just answer the two prompts.
An upstream fix would be for both steps to honour `OMARCHY_UPDATE_UNATTENDED`. This was not reported upstream (needs the user's OK).
