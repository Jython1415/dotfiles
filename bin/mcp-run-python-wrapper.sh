#!/bin/bash

# This is a wrapper script to change the working directory before starting
# MCP Run Python with `deno`

cd /Users/Joshua
/Users/Joshua/.deno/bin/deno run -N -R=node_modules -W=node_modules --node-modules-dir=auto jsr:@pydantic/mcp-run-python stdio
