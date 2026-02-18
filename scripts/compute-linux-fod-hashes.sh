#!/usr/bin/env bash
set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
	echo "docker is required but was not found in PATH"
	exit 1
fi

if [[ -z "${DOCKER_HOST:-}" ]]; then
	if [[ -S "${HOME}/.colima/x64/docker.sock" ]]; then
		export DOCKER_HOST="unix://${HOME}/.colima/x64/docker.sock"
	elif [[ -S "${HOME}/.colima/docker.sock" ]]; then
		export DOCKER_HOST="unix://${HOME}/.colima/docker.sock"
	fi
fi

if ! docker info >/dev/null 2>&1; then
	echo "docker daemon is not reachable (set DOCKER_HOST if needed)"
	exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

run_and_extract_hash() {
	local profile="$1"
	local workloads_expr
	local output got_line hash

	case "$profile" in
	basic)
		workloads_expr='[]'
		;;
	workload)
		workloads_expr='["android"]'
		;;
	*)
		echo "unknown profile: ${profile}" >&2
		return 1
		;;
	esac

	output="$({
		docker run --rm \
			--platform linux/amd64 \
			-v "${repo_root}:/work" \
			-w /work \
			nixos/nix:2.30.3 \
			sh -lc "expr=\"\$(cat <<'EOF_NIX'
let
  flake = builtins.getFlake \"path:/work\";
  pkgs = import flake.inputs.nixpkgs { system = \"x86_64-linux\"; };
  dotnet = import /work/src/nix-dotnet.nix { inherit pkgs; };
in
  dotnet.mkDotnet {
    globalJsonPath = /work/global.json;
    workloads = ${workloads_expr};
    outputHash = pkgs.lib.fakeHash;
  }
EOF_NIX
)\"; nix --extra-experimental-features 'nix-command flakes' build --impure --option sandbox false --option filter-syscalls false --expr \"\$expr\" --no-link"
	} 2>&1 || true)"

	got_line="$(printf '%s\n' "${output}" | rg -m1 "got:\\s+sha256-" || true)"
	hash="${got_line##*got: }"
	hash="$(printf '%s' "${hash}" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"

	if [[ -z "${hash}" || "${hash}" == "${got_line}" ]]; then
		echo "Failed to extract hash for ${profile}. Full output:" >&2
		printf '%s\n' "${output}" >&2
		return 1
	fi

	printf '%s\n' "${hash}"
}

echo "Computing Linux fixed-output hashes using Docker (linux/amd64)..."
basic_hash=""
workload_hash=""
failed=0

if ! basic_hash="$(run_and_extract_hash basic)"; then
	failed=1
fi

if ! workload_hash="$(run_and_extract_hash workload)"; then
	failed=1
fi

cat <<EOF

Computed hashes for x86_64-linux:
  basic-example:    ${basic_hash}
  workload-example: ${workload_hash}

Update flake.nix x86_64-linux branches to:
  basic-example    -> \"${basic_hash}\"
  workload-example -> \"${workload_hash}\"
EOF

exit ${failed}
