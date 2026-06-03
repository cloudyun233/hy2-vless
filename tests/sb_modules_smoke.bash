#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
entry="$repo_root/archive/sb.bash"
module_dir="$repo_root/archive/sb"
modules=(
  common
  service
  firewall
  protocols
  maintenance
  menu
)

[[ -f "$entry" ]] || {
  echo "missing entry: $entry" >&2
  exit 1
}

for module in "${modules[@]}"; do
  path="$module_dir/$module.bash"
  [[ -f "$path" ]] || {
    echo "missing module: $path" >&2
    exit 1
  }
done

bash -n "$entry"
SB_SKIP_MAIN=1 bash "$entry"
for module in "${modules[@]}"; do
  bash -n "$module_dir/$module.bash"
done

export SB_SKIP_MAIN=1
# shellcheck source=/dev/null
source "$entry"

for fn in check_sys install_singbox config_vless run_ip_sentinel_agent show_menu; do
  declare -F "$fn" >/dev/null || {
    echo "missing function: $fn" >&2
    exit 1
  }
done

menu_output="$(printf '0\n' | show_menu 2>&1 || true)"
grep -q 'IP-Sentinel' <<< "$menu_output" || {
  echo "menu does not contain IP-Sentinel option" >&2
  exit 1
}

isolated="$(mktemp -d)"
trap 'rm -rf "$isolated"' EXIT
mkdir -p "$isolated/archive"
cp "$entry" "$isolated/archive/sb.bash"
(
  export SB_SKIP_MAIN=1
  export SB_MODULE_BASE_URL="file://$module_dir"
  # shellcheck source=/dev/null
  source "$isolated/archive/sb.bash"
  declare -F run_ip_sentinel_agent >/dev/null
)

echo "sb module smoke test passed"
