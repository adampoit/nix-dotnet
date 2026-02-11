#!/usr/bin/env bash
set -euo pipefail

version="${1:-}"
platform="${2:-linux}"
arch="${3:-x64}"

if [ -z "$version" ]; then
	echo "Usage: $0 <sdk-version> [platform] [arch]"
	echo "  platform: linux, osx (default: linux)"
	echo "  arch: x64, arm64 (default: x64)"
	echo "Example: $0 10.0.103"
	echo "Example: $0 10.0.103 osx arm64"
	exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
hash_file="${script_dir}/../sdk-hashes.json"

url="https://builds.dotnet.microsoft.com/dotnet/Sdk/${version}/dotnet-sdk-${version}-${platform}-${arch}.tar.gz"

echo "Fetching hash for .NET SDK ${version}..."
echo "URL: ${url}"

hash=$(nix-prefetch-url "$url" 2>&1 | tail -1)

echo "Got hash: ${hash}"

if [ -f "$hash_file" ]; then
	content=$(cat "$hash_file")
else
	content='{"hashes": {}}'
fi

cache_key="${platform}-${arch}"

updated=$(echo "$content" | jq --arg version "$version" --arg key "$cache_key" --arg hash "$hash" '
  .hashes[$version][$key] = $hash
')

echo "$updated" >"$hash_file"
echo "Updated ${hash_file}"
echo ""
echo "SDK ${version} hash for ${cache_key} cached. You can now use this SDK version in your global.json."
