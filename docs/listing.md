# Getting potato-mode listed (research, 2026-10-20)

Status: research only. Nothing has been submitted, the repo stays private, and no other repo was touched.

## Where listings live

| Registry | What it is today | Submission |
|---|---|---|
| **Omarchy Plugin Marketplace**: omarchyplugins.com, also served at plugins.omarchy.org (repo `omacom/omarchy-plugin-marketplace`) | The live community catalog. The Omarchy manual (`manual/32-shell-plugins.md`) points here. Snapshot of `site/catalog.json`: 5,717 entries. | A GitHub **issue form** (`[Plugin]: <name>`, label `submission`), or the same body via `gh issue create`. No PR to a registry file. The bot validates, a maintainer applies `approved-and-verified`, and CI writes `registry.json`/`catalog.json`. |
| **Omarchy Plugin Registry** (`omacom/omarchy-plugin-registry`, Rails) | Planned successor at plugins.omarchy.org: accounts with MFA, `publisher/name` namespaces, immutable tarballs, a kill-bit. Its README says the client (`omarchy plugin add/publish`) and the deployment are **"not yet done, and required before launch."** At launch it plans to seed from omarchyplugins.com. | Not open yet. It plans `omarchy plugin publish` with short-lived tokens or OIDC trusted publishing. |

Install path for users: `omarchy plugin add <git-url> [--enable]`. This clones the repo into `~/.config/omarchy/plugins/<id>/` and validates it. It **never runs plugin code, never runs an install hook, never uses sudo**. Removal is `omarchy plugin remove <id>`.

Sources:
- https://github.com/omacom/omarchy-plugin-marketplace (README)
- https://github.com/omacom/omarchy-plugin-marketplace/blob/HEAD/SUBMISSION.md
- https://github.com/omacom/omarchy-plugin-marketplace/blob/HEAD/SECURITY.md
- https://github.com/omacom/omarchy-plugin-marketplace/blob/HEAD/VERIFICATION.md
- https://github.com/omacom/omarchy-plugin-marketplace/blob/HEAD/.github/ISSUE_TEMPLATE/submit-plugin.yml
- https://github.com/omacom/omarchy-plugin-marketplace/blob/HEAD/scripts/build-catalog.mjs (the validator: lines ~50-865)
- https://omarchyplugins.com/publish.html , https://omarchyplugins.com/develop.html
- https://github.com/omacom/omarchy/blob/quattro/docs/omarchy-shell.md (Plugin manifest, Installing a third-party plugin)
- https://github.com/omacom/omarchy/blob/quattro/manual/32-shell-plugins.md
- https://github.com/omacom/omarchy-plugin-registry (README) and docs/design.md §1, §6, §8, §9

## Requirements (marketplace, current)

Repository (SUBMISSION.md, validator):
- A **public** GitHub repo, submitted by its root URL.
- One plugin, with `manifest.json` at the repo root.
- A root `README*` (required by the validator), with **install and removal instructions** (required by the checklist).
- A root `LICENSE*`/`LICENCE*`/`COPYING*` file (required by the validator). External dependencies documented.
- A globally unique, **lowercase**, permanent ID outside `omarchy.*`. Recommended form: `io.github.<user>.<name>`. Retired IDs can't be reused.
- Optional root `preview.(png|jpg|jpeg|webp|avif)`, up to 50 MB / 40 MP. It is optimized automatically.
- No symlinks anywhere in the plugin folder.

Manifest (`schemaVersion: 1`):
- Required by the marketplace validator: `id`, `name`, `version`, `author`, `description`, `kinds`, `entryPoints`. Omarchy itself requires only id/name/version/kinds/entryPoints.
- Optional: `license` (SPDX string, ≤120 chars). The planned registry requires it. Length limits: id 128, name 120, version 64, author 120, description 500.
- `kinds` ⊆ {`bar-widget`, `bar`, `panel`, `overlay`, `menu`, `service`}. Every kind needs a **QML entry point** (`barWidget`/`bar`/`panel`/`overlay`/`menu`/`service`) that exists and is a safe relative path.
- No compatibility field today. The planned registry adds optional `minOmarchyVersion` and `repository`, and enforces monotonic semver. In the current system `version` is never compared, so git HEAD is what users get.

Listing metadata (issue form): exactly one category (Appearance, Desktop, Developer Tools, Hardware, Kids, Productivity, **System**, Widgets, Other) and 1–3 tags (ai, bar, education, games, hyprland, kids, launcher, media, power-management, quickshell, security, **system**, vpn, workspaces). You may suggest one new tag. Optional maintainer notes cover install, permissions and deps. Five checklist attestations:
1. The repo is public and has install and removal instructions.
2. The license and external deps are documented.
3. The submitter owns or has permission for the plugin and its preview assets.
4. **The plugin does not overwrite user configuration without explicit consent.**
5. Approval is a listing, not a security review.

The guide also tells AI agents to show the owner the full title and body and to create the issue only after explicit owner approval.

Review and security (SECURITY.md, VERIFICATION.md):
- Validation and the static **Automated Security Baseline** run on the exact commit SHA without executing code. Then a maintainer must apply `approved-and-verified`.
- **Findings** (`needs-fixes`): curl/wget piped to a shell; `cargo install --git` without a 40-char rev; external git code built or executed without first checking out a full commit in detached mode; dangerous `NOPASSWD` sudoers rules; privileged process control from a PID file in `/tmp`.
- **Review capabilities** (`review-required`, a maintainer can accept them): `installer`, `package-manager`, `privilege` (sudo/pkexec), `remote-build`, `bundled-executable-binary`, `service-management` (systemctl, unit files), `sudoers-modification`.
- Later upstream commits show **"Update unverified"** until you file a verification/update issue with the new SHA.

## Is a package- or compositor-swapping add-on allowed?

There's no rule against it. There is a **structural mismatch**, though:
- A listing must be a QML shell plugin (one of the six kinds). The marketplace and Omarchy have no "script", "suite" or "tool" kind for listings. The few catalog entries showing "Plugin"/"Suite" are legacy multi-plugin sources.
- `omarchy plugin add` only clones files into `~/.config/omarchy/plugins/`. It never runs `install.sh`, never runs `omarchy-potato enable`, and never runs sudo. Removing the plugin deletes the checkout but **would not revert** packages, SDDM state, fstab, or anything else potato-mode changed.
- Precedent: listed System plugins such as `io.github.amikeal.battery-plus` (TLP/CPU tuning) and `imagineit.ram-manager` ship a QML widget or service and act from inside the shell. System-changing listings exist, but each is still a QML plugin.
- **Name collision:** `io.github.axawys.potato-mode` ("Potato Mode", a Service, MIT, verified, listed 2026-10-04) is already in the marketplace. It only flattens Hyprland effects through Omarchy's toggle directory. Our ID would differ, but the same display name would confuse users.

So the realistic listing shape is a **companion shell plugin**, for example a `service` + `bar-widget`/`menu` that shows potato status and offers "Enable/Disable potato-mode (opens a terminal)". It would document that the real installer is `./install.sh && omarchy-potato enable`, run by the user in a terminal with confirmation. The baseline would flag it `review-required` (installer, package-manager, privilege, service-management, and possibly remote-build for the opt-in AI module), so it needs maintainer acceptance. The other option is no listing: distribute as a plain repo or install script, and maybe later as an AUR/pacman package.

Note on the Sway path: the Omarchy shell (`omarchy-shell`) is launched from Hyprland autostart. In the potato Sway session a shell plugin may never load, so any companion plugin would only be useful on the Hyprland path or for enabling potato-mode in the first place.

## Gap check: potato-mode @ f2cb066

| Requirement | Status |
|---|---|
| Public GitHub repo | ❌ private (`perwendelboe-lab/potato-mode`). The visibility decision is the user's. |
| `manifest.json` at root | ❌ none. It needs a QML entry point, so this means building a companion plugin. |
| QML entry point / valid kind | ❌ none. potato-mode is bash plus config. |
| Root README | ✅ `README.md`: install (`./install.sh`), revert (`omarchy-potato disable`). An **Uninstall** section (disable, then `./install.sh --uninstall`) was added with this doc, since the flag existed but wasn't documented. Still to do: list external deps in one place. |
| Root LICENSE | ❌ missing. Without it the validator rejects the repo, and the code isn't legally reusable. |
| Manifest `license`/`author`/`description`/`version` | ❌ n/a until a manifest exists. There's no project version or tag anywhere. |
| Versioning / tags | ❌ no git tags, no releases. A compat range exists (`share/potato-mode/compat`: Omarchy 4.0.0 ≤ v < 4.1.0). |
| Unique lowercase ID | ⚠️ suggest `io.github.perwendelboe-lab.potato-mode`. The display name collides with the Axawys plugin. |
| Preview image | ⚠️ optional, none. A before/after or `omarchy-potato status` screenshot from the VM would do. |
| Removal instructions | ✅ in the README (see above). A companion plugin would also need to say that `omarchy plugin remove` doesn't revert system changes. |
| Consent before overwriting user config (checklist 4) | ✅ `enable` is explicit, `--dry-run` exists, backups and `disable` restore. The fstab edit needs `--confirm-fstab` or gum confirm. |
| Baseline findings | ✅ likely none: no curl-pipe-sh, and no sudoers files in the shipped code (the VM test sudoers live under `vm/` only). The AI module fetches a full 40-char commit and checks out `FETCH_HEAD` detached, with a rev check. The scanner may still flag it because the URL/commit come from variables. Not verified, because the scanner wasn't run. |
| Baseline capabilities | ⚠️ expect `review-required`: installer (`install.sh`), package-manager (pacman), privilege (sudo), service-management (systemctl), remote-build (AI module). |
| Scan limits (1,000 files / 8 MiB) | ✅ well under, but `vm/omarchy/raw-*.txt` and the vm scripts add bulk. Consider whether `vm/` belongs in a published repo. |

The only local change is the README Uninstall section, which documents existing behaviour. LICENSE, manifest and version are all decisions (below).

## Decisions for the user

1. **License.** Pick one, for example MIT (Omarchy and most listings use it), GPL-3.0, or Apache-2.0. This blocks any public release, listed or not.
2. **Go public?** The marketplace requires a public GitHub repo. Before flipping: retire `vm/` test material or keep it (it has no secrets after 962bbfa/f2cb066), and decide whether to squash the history. History rewriting is your call, and it isn't needed for secrets.
3. **Listing shape:**
   - (a) **Don't list.** Publish the repo with `install.sh` and link it from forums. This is the cheapest option and honest about what potato-mode is.
   - (b) **Companion shell plugin** (`service` + `menu` or `bar-widget`): a status indicator plus "enable/disable potato-mode in a terminal". It needs new QML (I'd estimate a small amount of work) and is subject to maintainer `review-required` acceptance. It only helps on the Hyprland path.
   - (c) Wait for plugins.omarchy.org (tarball registry) and decide then. The rules for system-level add-ons there are unpublished.
4. **Name.** Keep "potato-mode" with a distinct display name (e.g. "Potato Mode 2006" / "Potato Mode (full system)"), or rename to avoid confusion with `io.github.axawys.potato-mode`. Possibly credit or coordinate with that author: its Hyprland-flattening overlaps a small part of ours.
5. **Versioning.** Start tags at `v0.1.0`, and add a version to `omarchy-potato --version` and, if listed, to the manifest. The compat range stays in `share/potato-mode/compat`.
6. **Category and tags** if listed: `System`; tags `system`, `power-management`, `hyprland`. You could suggest a new tag such as `low-end`.
