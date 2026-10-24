# Privacy and Data Handling

TactileMac is a local-only utility. It has no network client, telemetry, analytics, accounts, or cloud sync.

## What is processed

- **Hardware key code** from a listen-only `CGEventTap`, used only to choose the mapped sound category/key.
- **Modifier flags** for modifier feedback.
- **Mouse button number** and **scroll delta/phase** for trackpad feedback.
- **Secure Event Input status** to pause feedback.
- **Pointer movement and scroll deltas** to generate local material pulses.
- **Settings and pack selections**, stored locally.

## What is not processed or stored

- No typed characters, Unicode strings, input method text, clipboard, screen contents, accessibility tree, microphone audio, or camera data.
- No key history or raw event log. `InputMonitor` keeps a transient pressed-key set solely to pair key-down/key-up and suppress duplicates; it is cleared on stop/reset. The coordinator's duplicate set behaves the same way.
- The UI's "last event" label records only an event category (keyboard/modifier/click/scroll) and a button/direction, not the character typed.
- No telemetry and no network requests. External `Link` controls only open a browser when the user clicks them; the app itself does not fetch them.
- No crash/usage upload. Diagnostics are copied to the clipboard only when the user presses **Copy diagnostics**.

## Permissions

- **Input Monitoring** is required for the listen-only event tap. The app explains why and only attempts to start the tap when the status is granted. The user initiates the system request.
- **Accessibility** is not requested and not used. The app does not inspect UI elements or window contents. The Permissions page reports the system value for transparency only.
- **Secure Event Input** is respected. TactileMac never tries to bypass it; it drops feedback while active and says so.
- No microphone, screen recording, contacts, calendar, location, or automation permission is requested.

## Haptic adapter

The experimental enhanced path loads Apple's private `MultitouchSupport` framework locally to drive the trackpad actuator. It does not send data anywhere and falls back to public AppKit. It is the only private framework used.

## Local files

```
~/Library/Application Support/TactileMac/
  settings.json
  settings.invalid-<timestamp>.json   (only after a corrupt file)
  SoundPacks/<pack-id>/
    tactilemac.pack.json
    tactilemac.import.json            (third-party imports only)
    original files (config.json, audio, icon)
  Imports/<UUID>/                     (temporary staging, removed after import)
```

- Settings are written atomically and versioned.
- Imported packs are copied; the user's original source folder is not modified.
- Imported audio is decoded for validation but not executed. Path traversal and symlinks are rejected.
- Removing a pack deletes the installed copy only.
- The Application Support folder is marked excluded from backup on creation (best-effort); this does not prevent the user from backing it up manually.

## Retention

- No input history is retained.
- Pressed-key sets exist only while keys are down and are cleared on stop/reset.
- Session counters (events/sounds/haptics) are in memory only and reset on relaunch.
- Settings and installed packs persist until the user deletes them.

## Diagnostics

**Copy diagnostics** writes a summary containing app/macOS version, permission/tap status, secure-input status, trackpad capability, audio device/rate/buffer, pack IDs, and installed pack IDs. It contains no typed text, key history, file paths beyond the app's known data location, or personal identifiers. The user must paste it somewhere; the app does not send it.

## Third-party content

TactileMac does not bundle third-party recordings or source code. Imported sound packs remain the user's files and may have their own licenses. No imported content is executed.
