#!/usr/bin/env -S uv run --quiet
# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "python-dotenv",
#     "jinja2",
# ]
# ///

import os
import sys
import json
from pathlib import Path
from dotenv import load_dotenv
from jinja2 import Template

def main():
    """Hydrate Claude config template with environment variables."""
    
    # Load environment variables from .env file
    dotenv_path = Path.home() / '.dotfiles' / 'claude' / '.env'
    if not dotenv_path.exists():
        print(f"Error: {dotenv_path} not found. Create this file with your secrets.", file=sys.stderr)
        sys.exit(1)
    
    load_dotenv(dotenv_path)
    
    # Input template and output paths
    template_path = Path.home() / '.dotfiles' / 'claude' / 'claude_desktop_config.template.json'
    output_path = Path.home() / 'Library' / 'Application Support' / 'Claude' / 'claude_desktop_config.json'
    
    if not template_path.exists():
        print(f"Error: Template file {template_path} not found.", file=sys.stderr)
        sys.exit(1)
    
    # Read template
    with open(template_path, 'r') as f:
        template_content = f.read()
    
    # Create Jinja2 template
    template = Template(template_content)
    
    # Get all environment variables 
    env_vars = {k: v for k, v in os.environ.items()}
    
    # Render template with environment variables
    rendered_content = template.render(**env_vars)
    
    # Parse JSON to ensure it's valid
    try:
        json_data = json.loads(rendered_content)
    except json.JSONDecodeError as e:
        print(f"Error: Generated JSON is invalid: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Write output file with pretty formatting
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, 'w') as f:
        json.dump(json_data, f, indent=2)
    
    print(f"Successfully hydrated config to {output_path}")

if __name__ == "__main__":
    main()
