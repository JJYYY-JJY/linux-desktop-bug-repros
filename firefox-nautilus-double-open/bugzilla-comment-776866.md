I can reproduce a related variant of this on a current Fedora GNOME system, and
the logs suggest a specific timeout/fallback race rather than a double-click.

Observed environment:

- Fedora Linux 44 Workstation
- GNOME on Wayland
- Firefox 151.0.2, RPM package
- Nautilus 50.1
- `xdg-desktop-portal` 1.21.2
- `xdg-desktop-portal-gnome` 50.0
- `xdg-desktop-portal-gtk` 1.15.3
- Default directory handler: `org.gnome.Nautilus.desktop`

Steps:

1. Close all Nautilus windows.
2. Quit the Nautilus background service with `nautilus -q`.
3. Start Firefox.
4. Download a small file.
5. Open the downloads panel and single-click the folder icon / "Show in
   Folder" once.

Actual result:

Two Nautilus windows can open. One selects the downloaded file, and the other
opens the containing directory.

Relevant sanitized `journalctl --user -b` excerpt:

```text
May 26 22:55:03 systemd: Started dbus-:1.2-org.freedesktop.FileManager1@0.service.
May 26 22:55:03 org.gnome.Nautilus: Connecting to org.freedesktop.Tracker3.Miner.Files
May 26 22:55:04 firefox.desktop: Failed to query file manager via ShowItems: Timeout was reached
May 26 22:55:05 systemd: Started dbus-:1.2-org.gnome.NautilusPreviewer@0.service.
May 26 22:55:05 org.gnome.Nautilus: g_file_equal: assertion 'G_IS_FILE (file2)' failed
May 26 22:55:05 org.gnome.Nautilus: g_file_equal: assertion 'G_IS_FILE (file2)' failed
```

The local system locale rendered the timeout as `已到超时限制`.

This matches the GTK reveal path in `nsGIOService.cpp`: Firefox calls
`org.freedesktop.FileManager1.ShowItems`, uses
`widget.gtk.file-manager-show-items-timeout-ms` as the D-Bus call timeout
(default 1000 ms), and on failure falls back to opening the parent directory
directly via `RevealDirectory(file, true)`. If Nautilus cold-starts slowly,
the fallback opens the directory, and the original ShowItems request can still
complete afterward, producing a second window.

Increasing `widget.gtk.file-manager-show-items-timeout-ms` to 5000 appears to
be the local workaround to validate.

Full reproduction notes and links:

https://github.com/JJYYY-JJY/linux-desktop-bug-repros/tree/main/firefox-nautilus-double-open

