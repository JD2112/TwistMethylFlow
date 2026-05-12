#!/usr/bin/env python

import yaml
import sys

def dump_versions(yaml_file):
    try:
        with open(yaml_file, 'r') as f:
            versions = yaml.safe_load(f)
            
        with open('software_versions.csv', 'w') as out:
            out.write("Process\tSoftware\tVersion\n")
            if versions:
                for process, tools in versions.items():
                    for tool, version in tools.items():
                        out.write(f"{process}\t{tool}\t{version}\n")
    except Exception as e:
        print(f"Error parsing versions: {e}")

if __name__ == '__main__':
    if len(sys.argv) > 1:
        dump_versions(sys.argv[1])
