# Bugzilla Report Draft

## Product / Component

Core :: Widget: Gtk

## Summary

Linux: Show in Folder opens two Nautilus windows when FileManager1 ShowItems
times out during Nautilus cold start

## Description

### Steps to reproduce

1. Use Firefox on Fedora GNOME.
2. Ensure Nautilus is not already running, for example by closing all Nautilus
   windows and running `nautilus -q`.
3. Start Firefox.
4. Download a small file.
5. Open the downloads panel and click the folder icon / "Show in Folder" once.

### Actual result

Two Nautilus windows can open. One selects the downloaded file, and the other
opens the containing directory.

### Expected result

Only one Nautilus window should open, preferably with the downloaded file
selected.

### Environment

- Fedora Linux 44 Workstation
- GNOME on Wayland
- Firefox 151.0.2, RPM package
- Nautilus 50.1
- `xdg-desktop-portal` 1.21.2
- `xdg-desktop-portal-gnome` 50.0
- `xdg-desktop-portal-gtk` 1.15.3
- Default directory handler: `org.gnome.Nautilus.desktop`

### Evidence

Sanitized `journalctl --user -b` excerpt:

```text
May 26 22:55:03 systemd: Started dbus-:1.2-org.freedesktop.FileManager1@0.service.
May 26 22:55:03 org.gnome.Nautilus: Connecting to org.freedesktop.Tracker3.Miner.Files
May 26 22:55:04 firefox.desktop: Failed to query file manager via ShowItems: Timeout was reached
May 26 22:55:05 systemd: Started dbus-:1.2-org.gnome.NautilusPreviewer@0.service.
May 26 22:55:05 org.gnome.Nautilus: g_file_equal: assertion 'G_IS_FILE (file2)' failed
May 26 22:55:05 org.gnome.Nautilus: g_file_equal: assertion 'G_IS_FILE (file2)' failed
```

The local system locale rendered the timeout as `已到超时限制`.

### Analysis

This looks like a timeout/fallback race in the GTK file manager reveal path:

1. Firefox calls `org.freedesktop.FileManager1.ShowItems`.
2. The call times out after the default
   `widget.gtk.file-manager-show-items-timeout-ms = 1000`.
3. Firefox falls back to opening the parent directory directly.
4. Nautilus still finishes the original `ShowItems` request, so a second window
   appears.

The workaround is to increase
`widget.gtk.file-manager-show-items-timeout-ms`, for example to `5000`.

Full notes and local reproduction artifact:

https://github.com/JJYYY-JJY/linux-desktop-bug-repros/tree/main/firefox-nautilus-double-open

