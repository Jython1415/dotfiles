#!/bin/bash

# This is a wrapper script to change the working directory before starting
# MCP Run Python with `deno`

mkdir -p /Users/Joshua/.dotfiles/.untracked/mcp-run-python
cd /Users/Joshua/.dotfiles/.untracked/mcp-run-python
/Users/Joshua/.deno/bin/deno run -N -R=node_modules -W=node_modules --node-modules-dir=auto jsr:@pydantic/mcp-run-python stdio
