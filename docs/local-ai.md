# Local AI for potato-mode (evaluation, 2026-10-16)

Status: **recommendation, not implemented.** The base stays at 1 GB and keeps Codex CLI (cloud) as the default agent. Local AI would be an **optional module, gated on 2 GB of RAM or more**.

## 1. What sybil-solutions/omarchy-local-ai is (ref clone: /workspace/ref/omarchy-local-ai @ 55b2342, v6.18.0)
- A Quattro-shell bar plugin (QML panel + one bash backend, `bin/omarchy-local-ai`). It runs engines (llama.cpp, SGLang, vLLM, TabbyAPI) in **Docker**, with images pinned by digest from ghcr.io. Each engine sits behind a keyed OpenAI/Anthropic/Responses gateway on 127.0.0.1:12434+. It opens pi, Claude Code, **Codex**, OpenCode, Crush, etc., pointed at that gateway.
- Setup turns on Omarchy's *sudoless Docker*, which is root-equivalent. Usage telemetry pings usage.sybilsolutions.ai every 12 h (opt-out). It also refreshes its catalog from GitHub.
- The only CPU path is **x86-64 with AVX2**: `grep -qw avx2 /proc/cpuinfo` (bin/omarchy-local-ai:320). The single CPU recipe is LFM2.5-2.6B QAD-Q4_0 with `needs: host_ram_gb 4, disk_gb 1.7`, 8K context, 6 threads.
- It **does not provide an Omarchy skill**. `rg -i skill` finds nothing. The skill ships with Omarchy itself (`default/agents/skills/omarchy/SKILL.md` in basecamp/omarchy, about 12 KB, roughly 3k tokens). It points agents at `omarchy commands [--json]` and `omarchy <group> --help`.

**Verdict on the plugin: do not include it.** On a Core 2 machine it would detect no hardware: no AVX2, no supported GPU, and it needs 4 GB. Docker alone costs hundreds of MB, and it adds telemetry and a root-equivalent group. What is worth reusing is the idea: llama-server, an OpenAI-compatible endpoint on localhost, and launching an agent against it.

## 2. Omarchy skill + Codex
Codex CLI loads `SKILL.md` skills from `~/.agents/skills/` (current) and `~/.codex/skills/` (legacy), plus `/etc/codex/skills` (admin) (developers/learn docs; openai/codex#14337, PR #10317). So the **Omarchy skill works with Codex cloud today** with no local model. potato-mode should symlink or copy Omarchy's SKILL.md into `~/.agents/skills/omarchy/`, and add a short potato addendum (sway/X11 fallback, low-RAM rules). This is the base-tier "Omarchy skill" answer at 0 MB of extra RAM.

## 3. Lead candidate: PrismML Ternary Bonsai 2 (collection "Bonsai 2 Small")
Licence Apache-2.0. Derived from Qwen3.5 (hybrid linear/full attention, 262K context). Vision through an optional mmproj, not needed here.

| Model | PTQ1_0 | PQ2_0 | Q2_0 (upstream llama.cpp OK) |
|---|---|---|---|
| Bonsai-2-2B (1.88B LM) | **0.43 GB** | 0.52 GB | 0.55 GB |
| Bonsai-2-4B | 0.94 GB | 1.14 GB | 1.21 GB |
| Bonsai-2-9B | 1.99 GB | 2.41 GB | 2.55 GB |

(Sizes from the HF API tree, 2026-10-16.)

Runtime: PTQ1_0 and PQ2_0 need the **PrismML fork** (github.com/PrismML-Eng/llama.cpp, branch `prism`). Upstream rejects them; upstream master only runs Q2_0 (model card). The fork has generic C fallbacks for the ternary dot products (`arch-fallback.h`, `*_generic`), so **AVX is not required**. On Arch there's no official package, the AUR fork package is CUDA-only (`llama-prism-cuda`), and `llama.cpp-bin-noavx` (AUR) assumes SSE4.2, which a Merom Core 2 lacks. → **Build from source on the target** (`cmake -DGGML_NATIVE=ON`, or `-march=core2` with AVX/F16C/FMA/BMI2 OFF), or ship our own prebuilt core2 binary.

### Box measurement (not a 2006 machine)
Debian box, "Intel Xeon Processor" vCPU, prism fork @5ae2e16 built with `-march=core2`, all AVX/FMA/F16C off, i.e. an SSE2–SSSE3 build. `llama-bench -t 2 -p 128 -n 32`, max RSS via `/usr/bin/time`:

| Model | file | pp128 tok/s | tg tok/s | max RSS |
|---|---|---|---|---|
| Bonsai-2-2B PTQ1_0 | 399 MiB | 9.8 | 6.5 | **527 MiB** |
| Bonsai-2-2B Q2_0 | 511 MiB | 3.6 | 2.6 | 639 MiB |
| Qwen2.5-0.5B-Instruct Q4_K_M (reference) | 463 MiB | 8.7 | 7.3 | 531 MiB |

Tool-call test, box measurement: Bonsai-2-2B PTQ1_0 on llama-server `--jinja`, thinking off, with a short Omarchy command list and one `run` tool. Asked "Turn on night light and switch theme to nord", it returned two correct calls: `omarchy toggle nightlight` and `omarchy theme set nord`. That is one sample, not a benchmark.

Extrapolating to a Core 2 Duo (2 cores, ~2 GHz, no AVX) is an estimate, not a measurement. Expect it to be slower than the box: very roughly 2–5 tok/s generation and single-digit tok/s prompt processing. **No published Core 2 llama.cpp numbers were found.** Measure on real hardware before promising speed.

Consequence: prompt processing is the bottleneck. The full Omarchy SKILL.md (~3k tokens) would take ~5 min to ingest at box speed and longer on a Core 2. The local path needs a **condensed "mini-skill"** (≤500 tokens: command groups plus "run `omarchy <group> --help` when unsure"), a fixed system prompt kept warm by llama-server's prompt cache, thinking **off**, and a short context (`-c 2048`).

### Memory tiers
- **1 GB:** not feasible alongside a desktop. Model RSS is ~530 MiB plus Wayland, browser and Codex; zram would thrash on an HDD. → no local AI. Codex cloud plus the skill (§2).
- **2 GB:** feasible for **one-shot command help**. Bonsai-2-2B PTQ1_0 (~530 MiB RSS) with on-demand start and stop (systemd socket or a launcher). It is not a resident daemon, and it is not a coding agent.
- **≥4 GB:** Bonsai-2-4B PTQ1_0 (0.94 GB file) becomes reasonable. The 9B is out of scope for this hardware.

## 4. Hybrid design (recommended)
- `potato-ask` (local, optional module): a tiny CLI → llama-server (prism fork, PTQ1_0 2B) with the mini-skill and a single `run` tool. Every command needs **confirmation before it runs**. Scope is Omarchy/potato commands and config questions only. The server loads on first use and exits after N minutes idle to free RAM.
- Codex CLI (cloud, default): everything heavy (coding, multi-file edits, long reasoning), with the full Omarchy skill in `~/.agents/skills/omarchy`.
- Optionally, `potato-ask` hands off to Codex when the local model is unsure or the task is not an Omarchy command.
- Codex can also target the local server through a custom OpenAI-compatible provider, but a 2B ternary model at these speeds can't drive Codex's large agent prompt usefully. Don't offer that.

## 5. Product choices for the user
1. Ship the Omarchy skill for Codex in the base (0 MB). **Recommended: yes.**
2. Add the optional `local-ai` module, gated on MemTotal ≥ 2 GB (refuses below, warns at 2–3 GB). **Recommended: yes, opt-in, off by default.**
3. Runtime: build the PrismML fork on the target (slow on a Core 2: tens of minutes) **vs** ship a prebuilt `-march=core2` binary from potato-mode (fast install, but we maintain it). Recommended: prebuilt binary, with a build-from-source fallback.
4. Model: Bonsai-2-2B **PTQ1_0** (smallest and fastest here). The fallback is Q2_0 on upstream llama.cpp if the fork goes stale; it is 2.5× slower and +110 MiB.
5. Do **not** include sybil-solutions/omarchy-local-ai (AVX2/Docker/4 GB/telemetry).

## 6. Implementation (branch `local-ai`)
Decisions taken on 2026-10-16: the skill ships in the base, the module is opt-in and needs ≥2 GB, the build runs on the target from a pinned commit, the model is Bonsai-2-2B PTQ1_0, Q2_0 on upstream is the fallback, and omarchy-local-ai is dropped.

- **Base (`omarchy-potato apply`)** symlinks Omarchy's skill (`$OMARCHY_PATH/default/agents/skills/omarchy`) to `~/.agents/skills/omarchy` if nothing is already there. It writes the `potato-mode` addendum skill (`share/potato-mode/skills/potato-mode/SKILL.md`). `disable` removes both, and also removes the AI module if present.
- **`omarchy-potato ai enable|disable|status [--dry-run] [--yes] [--fallback]`** (`bin/omarchy-potato-ai`, pins in `share/potato-mode/ai/pins.sh`):
  - *Preflight:* MemTotal ≥ 1,800,000 kB (a "2 GB" machine), SSE3, ≥1.5 GB free disk, toolchain (installs `base-devel cmake git curl jq` after a confirm), and reachability of the pinned repo and model URL.
  - *Build:* `git fetch --depth 1 <url> <commit>`, then verify `HEAD == pin`. cmake uses `GGML_NATIVE=OFF`. Each of AVX/AVX2/FMA/F16C/BMI2/SSE4.2 is ON only if `/proc/cpuinfo` lists it, with `-march=core2` for SSSE3 CPUs and AVX512 always off. The build runs `nice -n 19 ionice -c3`, `-j1` (or `-j2` at ≥3.5 GB) under `timeout 6h`, logged to `~/.local/state/potato-mode/ai/logs/build-*.log`. Only the `llama-server` target is built.
  - *Model:* resumable `curl -C -` into `.part` from the pinned HF revision. The SHA-256 must match before the file is moved into place.
  - *Smoke test:* `llama-server --version` (this catches illegal instructions), then load the model, get a 4-token chat completion, and check peak VmHWM ≤ 900,000 kB.
  - *On failure:* the step, message and log path go to `last-build` (shown by `ai status`), and the module stays disabled. Fetched source with a wrong commit, a bad-checksum model or a crashing binary is deleted. Interrupted downloads and partial builds are kept so a retry resumes. The error message offers a retry and `--fallback`. Base potato-mode files are never touched.
- **`omarchy-potato-ask "<question>"`** (also `omarchy-potato ask`):
  - It starts llama-server on demand on 127.0.0.1:12480 (`-c 2048`, nice 10) and sends the ≤500-token mini-skill (`share/potato-mode/ai/mini-skill.md`) with thinking off, max 256 tokens, and one `run` tool.
  - Each proposed command is shown and runs **only after confirmation**. `--dry-run` never runs anything.
  - A watchdog stops the server after 600 s idle (`POTATO_AI_IDLE`). `--stop` stops it now.
- **Tests (`tests/run.sh`, stubbed git/cmake/curl/server):** RAM refusal, dry-run without changes, no AVX on Core 2 flags, AVX2 only when present, the success path, disable, every failure path (network, toolchain, disk, wrong commit, build error, timeout, checksum, interrupted download, illegal instruction, RSS limit, no generation), resume without re-fetch, `--fallback`, ask confirm/deny/dry-run/thinking-off, and the mini-skill token budget.
