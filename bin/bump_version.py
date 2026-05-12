#!/usr/bin/env python3
import sys
import re
import os

if len(sys.argv) != 2:
    print("Usage: python bump_version.py <new_version>")
    sys.exit(1)

# strip 'v' prefix if provided
new_version = sys.argv[1].lstrip('v')

files_to_update = {
    'conf/base.config': (
        r"(version\s*=\s*')[^']+(\')",
        rf"\g<1>{new_version}\g<2>"
    ),
    'docs/usage.md': (
        r"(-r\s+)\d+\.\d+\.\d+",
        rf"\g<1>{new_version}"
    )
}

project_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

for rel_path, (pattern, replacement) in files_to_update.items():
    filepath = os.path.join(project_dir, rel_path)
    if os.path.exists(filepath):
        with open(filepath, 'r') as f:
            content = f.read()

        new_content = re.sub(pattern, replacement, content)

        if new_content != content:
            with open(filepath, 'w') as f:
                f.write(new_content)
            print(f"Updated version to {new_version} in {rel_path}")
        else:
            print(f"Version already matches or pattern not found in {rel_path}.")
    else:
        print(f"Warning: File {filepath} not found.")
