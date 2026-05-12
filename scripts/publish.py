#!/usr/bin/env python3
import os
import re
import sys
import subprocess
from datetime import datetime

# Files to update and the regex patterns to find versions
# The dictionary value is a list of patterns to replace in that file
VERSION_FILES = {
    "nextflow.config": [
        (r'version\s*=\s*[\'"]([0-9.]+)[\'"]', "version = '{new_version}'")
    ],
    "conf/base.config": [
        (r'version\s*=\s*[\'"]([0-9.]+)[\'"]', "version         = '{new_version}'")
    ],
    "bin/build_unified_results.py": [
        (r'default="([0-9.]+)"', 'default="{new_version}"')
    ],
    "subworkflows/qc_reporting.nf": [
        (r"Pipeline Version'\] = '([0-9.]+)'", "Pipeline Version'] = '{new_version}'"),
        (r"MethylFlow v([0-9.]+)", "MethylFlow v{new_version}")
    ],
    "conf/containers.config": [
        (r'(jd21/methylflow[^:]*):([0-9.]+)', r'\1:{new_version}')
    ],
    "assets/report.qmd": [
        (r'Pipeline v([0-9.]+)', 'Pipeline v{new_version}'),
        (r'else "([0-9.]+)"', 'else "{new_version}"')
    ],
    "README.md": [
        (r'v([0-9.]+)', 'v{new_version}'),
        (r'MethylFlow \(([0-9.]+)\)', 'MethylFlow ({new_version})')
    ],
    "BENCHMARKING.md": [
        (r'v([0-9.]+)', 'v{new_version}')
    ]
}

# Add Dockerfiles to the list
for f in os.listdir("containers/docker"):
    if f.startswith("Dockerfile"):
        VERSION_FILES[f"containers/docker/{f}"] = [
            (r'image.version="([0-9.]+)"', 'image.version="{new_version}"'),
            (r'version="([0-9.]+)"', 'version="{new_version}"')
        ]

# Add documentation files
for f in os.listdir("docs"):
    if f.endswith(".md"):
        VERSION_FILES[f"docs/{f}"] = [
            (r'v([0-9.]+)', 'v{new_version}'),
            (r'-r ([0-9.]+)', '-r {new_version}')
        ]

def get_current_version():
    with open("conf/base.config", "r") as f:
        content = f.read()
        match = re.search(r'version\s*=\s*[\'"]([0-9.]+)[\'"]', content)
        if match:
            return match.group(1)
    return "0.0.0"

def bump_version(current, part):
    major, minor, patch = map(int, current.split("."))
    if part == "major":
        return f"{major + 1}.0.0"
    elif part == "minor":
        return f"{major}.{minor + 1}.0"
    else:
        return f"{major}.{minor}.{patch + 1}"

def update_file(file_path, old_version, new_version):
    if not os.path.exists(file_path):
        print(f"Warning: File {file_path} not found. Skipping.")
        return False
    
    with open(file_path, "r") as f:
        content = f.read()
    
    new_content = content
    patterns = VERSION_FILES.get(file_path, [])
    if not patterns and file_path.startswith("docs/"):
        patterns = VERSION_FILES.get("docs/index.md", [])
    
    for pattern, replacement in patterns:
        formatted_replacement = replacement.format(new_version=new_version)
        new_content = re.sub(pattern, formatted_replacement, new_content)
    
    if new_content != content:
        with open(file_path, "w") as f:
            f.write(new_content)
        return True
    return False

def run_git_commands(new_version):
    print(f"\n--- Git Operations for v{new_version} ---")
    subprocess.run(["git", "add", "."], check=True)
    subprocess.run(["git", "commit", "-m", f"Release v{new_version}"], check=True)
    subprocess.run(["git", "tag", "-a", f"v{new_version}", "-m", f"Release version {new_version}"], check=True)
    
    answer = input(f"Push to GitHub (origin main and tags)? [y/N]: ")
    if answer.lower() == 'y':
        subprocess.run(["git", "push", "origin", "main"], check=True)
        subprocess.run(["git", "push", "origin", "--tags"], check=True)
        print("Successfully pushed to GitHub.")

def main():
    if not os.path.exists("nextflow.config"):
        print("Error: Must be run from the project root.")
        sys.exit(1)

    current = get_current_version()
    print(f"Current version: {current}")
    
    print("\nSelect version bump:")
    print(f"1. Patch: {bump_version(current, 'patch')}")
    print(f"2. Minor: {bump_version(current, 'minor')}")
    print(f"3. Major: {bump_version(current, 'major')}")
    print("4. Custom")
    
    choice = input("\nChoice [1-4]: ")
    if choice == "1": new_version = bump_version(current, "patch")
    elif choice == "2": new_version = bump_version(current, "minor")
    elif choice == "3": new_version = bump_version(current, "major")
    elif choice == "4": new_version = input("Enter custom version (X.Y.Z): ")
    else: sys.exit(0)

    print(f"\nUpdating files to v{new_version}...")
    updated_count = 0
    # Process files
    for file_path in list(VERSION_FILES.keys()):
        if update_file(file_path, current, new_version):
            print(f"  ✓ Updated {file_path}")
            updated_count += 1
    
    # Also handle server_version if it exists
    if os.path.exists("server_version"):
        print("  Processing server_version directory...")
        for root, dirs, files in os.walk("server_version"):
            for name in files:
                rel_path = os.path.relpath(os.path.join(root, name), ".")
                # Try to use patterns from the non-server counterpart
                base_name = rel_path.replace("server_version/", "")
                if base_name in VERSION_FILES:
                    if update_file(rel_path, current, new_version):
                        print(f"  ✓ Updated {rel_path}")
                        updated_count += 1

    print(f"\nDone. Updated {updated_count} files.")
    
    run_git_commands(new_version)

if __name__ == "__main__":
    main()
