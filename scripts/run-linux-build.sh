#!/usr/bin/env bash
set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
	echo "docker is required but was not found in PATH" >&2
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
	echo "docker daemon is not reachable (set DOCKER_HOST if needed)" >&2
	exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

declare -a attrs
if [[ "$#" -gt 0 ]]; then
	attrs=("$@")
else
	attrs=(
		".#checks.x86_64-linux.integration-test"
		".#checks.x86_64-linux.integration-workload-test"
	)
fi

for attr in "${attrs[@]}"; do
	echo "=== Building ${attr} in linux/amd64 container ==="
	docker run --rm \
		--platform linux/amd64 \
		-v "${repo_root}:/work" \
		-w /work \
		nixos/nix:2.30.3 \
		sh -lc "git config --global --add safe.directory /work && nix --extra-experimental-features 'nix-command flakes' build '${attr}' --no-link --option sandbox false --option filter-syscalls false"
done
