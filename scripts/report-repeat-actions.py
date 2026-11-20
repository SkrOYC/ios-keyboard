"""Print only bounded, text-free delete events from the simulator extension log."""

import plistlib
import re
import sys
from pathlib import Path


ACTION = re.compile(r"delete(?: motion phase=(?:move|end) first=(?:true|false) travel=-?[0-9]+\.[0-9] count=[0-9]+)?")


def actions(text):
    result = []
    for line in text.splitlines():
        message = line.partition(" · ")[2]
        if len(message) <= 160 and ACTION.fullmatch(message):
            result.append(message)
    return result[-40:]


def read_actions(containers, bundle_id):
    result = []
    for metadata in sorted(containers.glob("*/.com.apple.mobile_container_manager.metadata.plist")):
        try:
            info = plistlib.loads(metadata.read_bytes())
            if isinstance(info, dict) and info.get("MCMMetadataIdentifier") == bundle_id:
                log = metadata.parent / "Library/Caches/keyboard.log"
                result.extend(actions(log.read_text(errors="replace")[-65_536:]))
        except (OSError, ValueError, plistlib.InvalidFileException):
            continue
    return result[-40:]


def main():
    try:
        info = plistlib.loads(Path(sys.argv[2]).read_bytes())
        bundle_id = info["CFBundleIdentifier"]
        containers = Path.home() / "Library/Developer/CoreSimulator/Devices" / sys.argv[1] / "data/Containers/Data/PluginKitPlugin"
        events = read_actions(containers, bundle_id)
    except (OSError, ValueError, KeyError, TypeError, plistlib.InvalidFileException):
        events = []
    for index, event in enumerate(events):
        print(f"REPEAT_DELETE action[{index}]={event}")
    if not events:
        print("REPEAT_DELETE actions unavailable")


if __name__ == "__main__":
    main()
