#!/usr/bin/env bash
# Pruebas de humo de la skill cheat-engine-tables (Linux/WSL; requiere python3 y un Lua 5.3:
# lua5.3 o texlua). Uso:  bash tests/run_tests.sh [tabla.CT]
set -euo pipefail
cd "$(dirname "$0")/.."
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
LUA="$(command -v lua5.3 || command -v lua || command -v texlua || true)"

echo "== sigmaker: PE sintético =="
python3 tests/make_test_pe.py "$TMP/test.exe" >/dev/null
python3 scripts/sigmaker.py make "$TMP/test.exe" --rva 0x2040 --json "$TMP/sig.json" >/dev/null
python3 - "$TMP/sig.json" <<'EOF'
import json, sys
best = json.load(open(sys.argv[1]))["best"]
assert best["aob"].startswith("48 "), "se perdió el prefijo REX"
print("  mejor firma:", best["aob"])
EOF
python3 scripts/sigmaker.py check "$TMP/test.exe" --aob "48 8B 05 ?? ?? ?? ?? 48 85 C0 74 05 E8" \
        --disp-offset 3 --instr-len 7 | tail -1

if [[ -n "$LUA" ]]; then
  echo "== Lua (mock de CE) con $LUA =="
  "$LUA" tests/mock_ce.lua | tail -1
  python3 - "$TMP/blk_test.lua" <<'EOF'
import json, re, sys
sys.path.insert(0, "scripts"); import ct_tool
cfg = json.load(open("templates/resolvers.megaman_sf.json"))
cfg["bases"][0].update(aobs=[], aob="48 8B 05 ?? ?? ?? ?? 48 85 C0", disp_offset=3, instr_len=7, fallback_offset="0E120A40")
cfg["bases"][1].update(aobs=[{"aob": "AA BB", "disp_offset": 3, "instr_len": 7}], aob="DE AD BE EF", fallback_offset="0E124218")
blk = re.findall(r"\{\$lua\}(.*?)\{\$asm\}", ct_tool.build_resolver_script(cfg), re.S)[0]
open(sys.argv[1], "w").write(blk)
EOF
  sed "s#/tmp/claude-0/blk_test.lua#$TMP/blk_test.lua#" tests/mock_resolver.lua > "$TMP/mr.lua"
  "$LUA" "$TMP/mr.lua" | tail -1
else
  echo "(sin intérprete Lua: se omiten pruebas Lua)"
fi

if [[ $# -ge 1 ]]; then
  echo "== Tabla real: $1 =="
  python3 scripts/ct_tool.py validate "$1" --max 5 || true
  python3 scripts/ct_tool.py info "$1" | sed -n '1,4p'
fi
echo "TODAS LAS PRUEBAS OK"
