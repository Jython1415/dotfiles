#!/bin/sh
# Syntax-check the Hammerspoon config and run dim.lua's off-host tests with a fake `hs`.
#   hammerspoon/tests/run.sh            (needs lua5.4/lua and luac5.4/luac, or LUA=/LUAC=)
# Hammerspoon embeds Lua 5.4, so use 5.4. On Ubuntu without root:
#   curl -fsSLO http://archive.ubuntu.com/ubuntu/pool/universe/l/lua5.4/lua5.4_5.4.6-3build2_amd64.deb
#   echo "2f9b2b33fb49fb508421da9f60d6f6d6b7d819f6e97baebde42fa15d99b357f7  lua5.4_5.4.6-3build2_amd64.deb" | sha256sum -c -
#   dpkg-deb -x lua5.4_5.4.6-3build2_amd64.deb x   (luac5.4 is static; lua5.4 needs liblua5.4-0)
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
LUA=${LUA:-$(command -v lua5.4 || command -v lua)}
LUAC=${LUAC:-$(command -v luac5.4 || command -v luac || true)}
if [ -n "$LUAC" ]; then
  "$LUAC" -p "$here/init.lua" "$here/dim.lua" && echo "syntax ok: init.lua dim.lua"
fi
tmp=$(mktemp -d "${TMPDIR:-/tmp}/dimtest.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/Library/Logs" "$tmp/Library/Caches"
HOME=$tmp TZ=America/New_York "$LUA" "$here/tests/test_dim.lua"
