#!/usr/bin/env python3
"""Verify that a built Dumbo app actually packages its discoverable Focus Filter."""
import argparse
import json
from pathlib import Path
import sys


def verify(app_bundle):
    extension = app_bundle / "Extensions" / "DumboFocus.appex"
    metadata_path = extension / "Metadata.appintents" / "extract.actionsdata"
    if not metadata_path.is_file():
        raise ValueError(f"Focus registration metadata is missing: {metadata_path}")
    metadata = json.loads(metadata_path.read_text())
    action = metadata.get("actions", {}).get("DumboFocus")
    if not action or not action.get("isDiscoverable"):
        raise ValueError("The Dumbo Focus Filter is missing or not discoverable.")
    if "com.apple.link.systemProtocol.FocusConfiguration" not in action.get("systemProtocols", []):
        raise ValueError("DumboFocus is not registered as a Focus Filter.")
    parameters = {parameter["name"] for parameter in action.get("parameters", [])}
    if not {"list", "mode"}.issubset(parameters):
        raise ValueError("The Focus Filter is missing its list or mode parameter.")
    if "AppListEntity" not in metadata.get("entities", {}):
        raise ValueError("The saved-list entity is missing from the Focus metadata.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app_bundle", type=Path, help="Path to the built Dumbo.app")
    args = parser.parse_args()
    try:
        verify(args.app_bundle)
    except (ValueError, OSError, KeyError) as error:
        print(f"Focus metadata verification failed: {error}", file=sys.stderr)
        return 1
    print("Focus metadata verified: discoverable filter, list/mode parameters, and saved-list entity.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
