#!/usr/bin/env python3
"""Checks every script folder against the repo format."""
import re
import subprocess
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required: pip install pyyaml")

REQUIRED = ["name", "description", "version", "author", "license", "git", "distro"]
SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"

errors = []
host_ports = {}
containers = {}

for folder in sorted(p for p in SCRIPTS.iterdir() if p.is_dir()):
    name = folder.name
    info = folder / "info.yml"
    script = folder / "script.noshell"

    if not info.is_file():
        errors.append(f"{name}: missing info.yml")
        continue
    if not script.is_file():
        errors.append(f"{name}: missing script.noshell")
        continue

    try:
        meta = yaml.safe_load(info.read_text())
    except yaml.YAMLError as err:
        errors.append(f"{name}: info.yml is not valid YAML ({err})")
        continue
    if not isinstance(meta, dict):
        errors.append(f"{name}: info.yml is not a mapping")
        continue

    for key in REQUIRED:
        if key not in meta:
            errors.append(f"{name}: info.yml missing required key '{key}'")
    for key in ["name", "description", "version", "author", "license", "git"]:
        if key in meta and not isinstance(meta[key], str):
            errors.append(f"{name}: info.yml '{key}' must be a string")
    if "distro" in meta and not isinstance(meta["distro"], (str, list)):
        errors.append(f"{name}: info.yml 'distro' must be a string or a list")
    if meta.get("name") != name:
        errors.append(
            f"{name}: info.yml name '{meta.get('name')}' must equal the folder name")
    if isinstance(meta.get("description"), str) and not meta["description"].strip():
        errors.append(f"{name}: description is empty")
    if isinstance(meta.get("version"), str) and not re.fullmatch(
            r"\d+\.\d+\.\d+", meta["version"]):
        errors.append(f"{name}: version '{meta.get('version')}' is not X.Y.Z")

    body = script.read_text()
    if not body.strip():
        errors.append(f"{name}: script.noshell is empty")
    check = subprocess.run(["sh", "-n", str(script)], capture_output=True, text=True)
    if check.returncode != 0:
        errors.append(f"{name}: script.noshell fails sh -n: {check.stderr.strip()}")

    for container in re.findall(r"--name\s+(wslm-[\w-]+)", body):
        if container in containers:
            errors.append(
                f"{name}: container {container} already used by {containers[container]}")
        containers[container] = name
    for port in re.findall(r"-p\s+(\d+):\d+", body):
        if port in host_ports:
            errors.append(
                f"{name}: host port {port} already used by {host_ports[port]}")
        host_ports[port] = name

if errors:
    print("Structure check FAILED:")
    for error in errors:
        print(f"  - {error}")
    sys.exit(1)
print(f"Structure check passed for {len(list(SCRIPTS.iterdir()))} scripts "
      f"({len(containers)} Docker services, {len(host_ports)} unique host ports).")
