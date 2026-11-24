#!/usr/bin/env python3
"""Static checks that do not need Xcode."""

import plistlib
import re
import sys
from pathlib import Path

# Characters CoreFoundation accepts in an unquoted OpenStep string.
# '+' is intentionally absent: unquoted gnu++20 makes Xcode reject the file.
_UNQUOTED = set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_$./:-")

ROOT = Path(__file__).resolve().parents[1]
errors = []


def fail(message):
    errors.append(message)


def apple_unquoted_violations(text: str):
    """Return (line, column, token) for tokens Xcode's plist parser rejects."""
    if text.startswith("//"):
        text = text.split("\n", 1)[1]
    i = 0
    line = 1
    col = 1
    n = len(text)
    violations = []

    def advance(count):
        nonlocal i, line, col
        for _ in range(count):
            if text[i] == "\n":
                line += 1
                col = 1
            else:
                col += 1
            i += 1

    while i < n:
        ch = text[i]
        if ch in " \t\r\n":
            advance(1)
            continue
        if ch == "/" and i + 1 < n and text[i + 1] == "*":
            end = text.find("*/", i + 2)
            if end < 0:
                violations.append((line, col, "unclosed comment"))
                break
            advance(end + 2 - i)
            continue
        if ch == '"':
            advance(1)
            while i < n:
                if text[i] == "\\":
                    advance(2 if i + 1 < n else 1)
                    continue
                if text[i] == '"':
                    advance(1)
                    break
                advance(1)
            continue
        if ch in "{}()=,;":
            advance(1)
            continue
        start_line, start_col, start = line, col, i
        token = []
        bad = False
        while i < n and text[i] not in " \t\r\n{}()=,;\"":
            if text[i] not in _UNQUOTED:
                bad = True
            token.append(text[i])
            advance(1)
        if bad or not token:
            violations.append((start_line, start_col, "".join(token) or ch))
    return violations


def main():
    entitlements = [
        ROOT / "SpotifyNow" / "SpotifyNow.entitlements",
        ROOT / "SpotifyNowWidget" / "SpotifyNowWidget.entitlements",
    ]
    for path in entitlements:
        text = path.read_text(encoding="utf-8")
        plistlib.loads(text.encode("utf-8"))
        if "$(TeamIdentifierPrefix)app.spotifynow" not in text:
            fail(f"{path.name} is missing the Team ID app group")
        if "group.app.spotifynow" in text or "<string>group." in text:
            fail(f"{path.name} uses a provisioned group. prefix")

    widget_ent = (ROOT / "SpotifyNowWidget" / "SpotifyNowWidget.entitlements").read_text(encoding="utf-8")
    if "com.apple.security.app-sandbox" not in widget_ent:
        fail("widget is not sandboxed")
    host_ent = (ROOT / "SpotifyNow" / "SpotifyNow.entitlements").read_text(encoding="utf-8")
    if "com.apple.security.app-sandbox" in host_ent:
        fail("menu bar app should stay unsandboxed")
    if "com.apple.security.automation.apple-events" not in host_ent:
        fail("menu bar app is missing the Apple Events entitlement")

    resolver = (ROOT / "Packages/SpotifyNowShared/Sources/SpotifyNowShared/AppGroupResolver.swift").read_text(encoding="utf-8")
    if 'groupSuffix = "app.spotifynow"' not in resolver:
        fail("AppGroupResolver.groupSuffix drifted from the entitlements")

    kind = (ROOT / "Packages/SpotifyNowShared/Sources/SpotifyNowShared/SpotifyIdentity.swift").read_text(encoding="utf-8")
    if 'nowPlaying = "SpotifyNow"' not in kind:
        fail("widget kind constant changed")

    info_paths = [ROOT / "SpotifyNow" / "Info.plist", ROOT / "SpotifyNowWidget" / "Info.plist"]
    for path in info_paths:
        plistlib.loads(path.read_bytes())
    host_info = plistlib.loads((ROOT / "SpotifyNow" / "Info.plist").read_bytes())
    if host_info.get("LSUIElement") is not True:
        fail("menu bar app would show a Dock icon")
    if "Spotify" not in host_info.get("NSAppleEventsUsageDescription", ""):
        fail("missing Apple Events usage description")
    widget_info = plistlib.loads((ROOT / "SpotifyNowWidget" / "Info.plist").read_bytes())
    point = widget_info.get("NSExtension", {}).get("NSExtensionPointIdentifier")
    if point != "com.apple.widgetkit-extension":
        fail(f"unexpected widget extension point {point}")

    project = (ROOT / "SpotifyNow.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")
    for line_no, column, token in apple_unquoted_violations(project):
        fail(f"pbxproj line {line_no}:{column} has an unquoted token Xcode rejects: {token!r}")
    if "CLANG_CXX_LANGUAGE_STANDARD = gnu++20;" in project:
        fail("gnu++20 is still unquoted")
    if "PBXFileSystemSynchronizedRootGroup" not in project:
        fail("project is not using synchronized folders")
    if "com.example.spotifynow.widget" not in project:
        fail("widget bundle id drifted from com.example.spotifynow.widget")
    if "DEVELOPMENT_TEAM" in project or "V8ZDQ3DFGH" in project:
        fail("project file still contains a personal team id")
    if "SpotifyNowWidget.appex" not in project:
        fail("embedded appex name drifted")
    bridge = (ROOT / "SpotifyNow" / "ShareBridge.swift").read_text(encoding="utf-8")
    if "SpotifyNowWidget.appex" not in bridge:
        fail("host looks for a different appex name than the project builds")
    if project.count("{") != project.count("}"):
        fail("pbxproj braces are unbalanced")
    definitions = re.findall(r"(?m)^\t\t([A-F0-9]{24}) ", project)
    if len(definitions) != len(set(definitions)):
        fail("duplicate pbxproj ids")

    required = [
        ROOT / "SpotifyNow.xcodeproj" / "xcshareddata" / "xcschemes" / "Spotify Now.xcscheme",
        ROOT / "Packages" / "SpotifyNowShared" / "Package.swift",
        ROOT / "SpotifyNow" / "Assets.xcassets" / "AppIcon.appiconset" / "icon_1024.png",
        ROOT / "README.md",
    ]
    for path in required:
        if not path.exists():
            fail(f"missing {path.relative_to(ROOT)}")

    if errors:
        print("\n".join(errors))
        return 1
    print("project checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
