#!/usr/bin/env bash

# Expects the LUAROCKS_API_KEY secret to be set

TMP_DIR=$(mktemp -d)
MODREV=$(git describe --tags --always --first-parent | tr -d "v")
DEST_ROCKSPEC="$TMP_DIR/telescope.nvim-$MODREV-1.rockspec"
cp "telescope.nvim-scm-1.rockspec" "$DEST_ROCKSPEC"
sed -i "s/= 'scm'/= '$MODREV'/g" "$DEST_ROCKSPEC"
luarocks upload "$DEST_ROCKSPEC" --api-key="$LUAROCKS_API_KEY"
