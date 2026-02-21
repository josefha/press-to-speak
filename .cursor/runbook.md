# Local Runbook

## One-command test loop

```bash
cd /Users/josef/Desktop/projects/private-projects/press-to-speak-mono/press-to-speak
make install-local
open /Applications/PressToSpeak.app
```

## Website release artifacts

```bash
make release-artifacts
```

Produces:
- `dist/release/PressToSpeak-<version>-macOS.zip`
- `dist/release/PressToSpeak-<version>-macOS.dmg`

Optional notarization:
```bash
NOTARY_PROFILE=\"press-to-speak-notary\" make notarized-release
```

## If transcription fails

1. Check app log:
```bash
tail -n 120 /Users/josef/Library/Logs/PressToSpeak/app.log
```

2. Check crash reports:
```bash
ls -1t ~/Library/Logs/DiagnosticReports | head
```

3. Live system log:
```bash
log stream --style compact --predicate 'process == "PressToSpeak"'
```

## If permissions keep re-prompting

- Keep bundle id and install path unchanged.
- Use consistent signing behavior across builds.
- Optional stable signing:
```bash
CODESIGN_IDENTITY="Apple Development: Your Name (TEAMID)" make install-local
```

## Hotkey update QA

1. Open dashboard.
2. Click `Update Hotkey`.
3. Press combo (example: `Right Command + ,`).
4. Confirm hotkey label updates.
5. Verify hold-to-talk works with new shortcut.

## Paste fallback QA

- Dictate into app that blocks synthetic paste.
- Verify transcription still lands in clipboard.
- Use menu `Copy Clipboard` to re-copy latest text.
