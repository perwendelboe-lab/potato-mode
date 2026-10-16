# shellcheck shell=bash
# Pinned sources for the optional local-AI module (omarchy-potato ai). Sourced.
# Bump together, after re-testing on real no-AVX hardware.
POTATO_AI_FORK_URL=https://github.com/PrismML-Eng/llama.cpp
POTATO_AI_FORK_COMMIT=5ae2e169eac202d2f065606539c3ad6ab8b51333  # branch prism, 2026-10-16
POTATO_AI_MODEL_REPO=prism-ml/Ternary-Bonsai-2-2B-gguf
POTATO_AI_MODEL_REV=683f7be2629342a50987627b40881e54761a2430
POTATO_AI_MODEL_FILE=Ternary-Bonsai-2-2B-PTQ1_0.gguf
POTATO_AI_MODEL_SHA256=${POTATO_AI_MODEL_SHA256:-36061ad406df8a4903a6db005be350c50fabfaf717f9ef0acf4b76adcd9929fa}
POTATO_AI_MODEL_BYTES=429183456
# Documented fallback (upstream llama.cpp can run Q2_0; ~2.5x slower, +110 MiB):
POTATO_AI_FALLBACK_FILE=Ternary-Bonsai-2-2B-Q2_0.gguf
POTATO_AI_FALLBACK_SHA256=${POTATO_AI_FALLBACK_SHA256:-c2893fa6f951daee8b7263d5f49b455e57989ef56417a22125b03566dc560650}
# MemTotal floor in kB: a "2 GB" machine reports a bit under 2 GiB.
POTATO_AI_MIN_KB=1800000
POTATO_AI_BUILD_DEPS=(base-devel cmake git curl jq)
# Fallback runtime: upstream llama.cpp (runs Q2_0 only). Commit present 2026-10-16; not box-tested with Bonsai.
POTATO_AI_UPSTREAM_URL=https://github.com/ggml-org/llama.cpp
POTATO_AI_UPSTREAM_COMMIT=7182ef71e6d5dd0c8ea76486fac134fcd25025d4
# Smoke-test RSS ceiling (kB); box measurement for PTQ1_0 was ~527 MiB, Q2_0 ~639 MiB.
POTATO_AI_RSS_LIMIT_KB=${POTATO_AI_RSS_LIMIT_KB:-900000}
# Free disk needed under the AI dir: source ~300 MB + build ~200 MB + model ~0.55 GB + margin.
POTATO_AI_MIN_FREE_KB=${POTATO_AI_MIN_FREE_KB:-1500000}
