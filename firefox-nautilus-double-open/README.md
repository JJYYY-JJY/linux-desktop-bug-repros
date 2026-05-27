# Firefox "Show in Folder" Opens Two Nautilus Windows

## Summary

On Fedora GNOME, Firefox can open two Nautilus windows after clicking the
download panel's "Show in Folder" button for a completed download. One window
selects the downloaded file; the other opens the containing directory.

The evidence points to a timeout/fallback race:

1. Firefox asks Nautilus to reveal the file through
   `org.freedesktop.FileManager1.ShowItems`.
2. Nautilus cold start takes longer than Firefox's default 1000 ms timeout.
3. Firefox treats the D-Bus call as failed and falls back to opening the parent
   directory directly.
4. The original Nautilus `ShowItems` request still completes, so two windows are
   opened.

## Environment

Observed locally on May 26, 2026:

- Fedora Linux 44 Workstation
- GNOME on Wayland
- Firefox 151.0.2, RPM package
- Nautilus 50.1
- `xdg-desktop-portal` 1.21.2
- `xdg-desktop-portal-gnome` 50.0
- `xdg-desktop-portal-gtk` 1.15.3
- Default directory handler: `org.gnome.Nautilus.desktop`
- `org.freedesktop.FileManager1` D-Bus activation:
  `/usr/bin/nautilus --gapplication-service`

I did not find competing `inode/directory` handlers in the user MIME
configuration.

## Reproduction

1. Close all Nautilus windows.
2. Quit the Nautilus background service, if needed:

   ```sh
   nautilus -q
   ```

3. Start Firefox.
4. Download a small file.
5. Open the downloads panel and click the folder icon / "Show in Folder" once.

Expected result: one Nautilus window opens and selects the downloaded file.

Actual result: two Nautilus windows can open. Exactly one selects the downloaded
file.

## Relevant Log

Sanitized excerpt from `journalctl --user -b`:

```text
May 26 22:55:03 systemd: Started dbus-:1.2-org.freedesktop.FileManager1@0.service.
May 26 22:55:03 org.gnome.Nautilus: Connecting to org.freedesktop.Tracker3.Miner.Files
May 26 22:55:04 firefox.desktop: Failed to query file manager via ShowItems: Timeout was reached
May 26 22:55:05 systemd: Started dbus-:1.2-org.gnome.NautilusPreviewer@0.service.
May 26 22:55:05 org.gnome.Nautilus: g_file_equal: assertion 'G_IS_FILE (file2)' failed
May 26 22:55:05 org.gnome.Nautilus: g_file_equal: assertion 'G_IS_FILE (file2)' failed
```

The local system locale rendered the timeout as `已到超时限制`.

## Root-Cause Notes

Firefox's GTK integration has a short timeout for the file manager reveal path:

- `widget.gtk.file-manager-show-items-timeout-ms` defaults to `1000`.
- `RevealFile()` calls `org.freedesktop.FileManager1.ShowItems` for files.
- On D-Bus failure or timeout, Firefox calls `RevealDirectory(file, true)`,
  which opens the parent directory directly.

The relevant Mozilla source paths are:

- [`toolkit/system/gnome/nsGIOService.cpp`](https://searchfox.org/firefox-main/source/toolkit/system/gnome/nsGIOService.cpp)
- [`modules/libpref/init/StaticPrefList.yaml`](https://searchfox.org/firefox-main/source/modules/libpref/init/StaticPrefList.yaml)

Related reports:

- [Bugzilla 1901595: "Show in Folder" opens two Downloads folders](https://bugzilla.mozilla.org/show_bug.cgi?id=1901595)
- [Bugzilla 776866: "Open containing folder" may open the file manager multiple times](https://bugzilla.mozilla.org/show_bug.cgi?id=776866)
- [Debian bug 1121941: Firefox opens two windows of Nautilus](https://www.mail-archive.com/debian-bugs-dist%40lists.debian.org/msg2071826.html)
- [NixOS/nixpkgs issue 409003: Nautilus opens twice from Firefox](https://github.com/NixOS/nixpkgs/issues/409003)

## Workaround

Increase Firefox's D-Bus timeout for the reveal operation.

In `about:config`, set:

```text
widget.gtk.file-manager-show-items-timeout-ms = 5000
```

Equivalent `user.js` entry:

```js
user_pref("widget.gtk.file-manager-show-items-timeout-ms", 5000);
```

After changing the preference, restart Firefox and test the cold-start
reproduction steps again.

## Local Validation

The underlying D-Bus behavior was validated locally with a cold Nautilus start:

```text
ShowItems with 1000ms timeout: Timeout was reached, elapsed=0:01.06
ShowItems with 5000ms timeout: success, elapsed=0:00.27
```

This supports the workaround direction. The Firefox download-panel end-to-end
test still requires restarting Firefox so the profile `user.js` pref is loaded.

## Upstream Status

- Mozilla Bugzilla: submitted as a comment on
  [Bug 776866, comment 13](https://bugzilla.mozilla.org/show_bug.cgi?id=776866#c13)
- GitHub tracking issue:
  <https://github.com/JJYYY-JJY/linux-desktop-bug-repros/issues/1>
- Local workaround: configured with
  `widget.gtk.file-manager-show-items-timeout-ms = 5000`; D-Bus mechanism
  validated, Firefox end-to-end validation pending restart
