# Arch boot splash

Full `./setup.sh` installs Plymouth and restores the preference in
`config/boot/plymouth.json`: the bundled `script` Arch logo theme, with
`quiet splash loglevel=3`. The splash starts during Linux boot and continues
toward the login screen. Firmware and bootloader screens are separate; a brief
message or transition can still appear. Press Esc to see Plymouth boot details.

The boot helper supports standard **mkinitcpio** configurations with:

- Unified kernel images (UKIs), including this laptop's setup. Parameters go
  into `/etc/kernel/cmdline` or an explicitly configured preset command-line file.
- GRUB using `/etc/default/grub` and `/boot/grub/grub.cfg`.
- systemd-boot entries under `/boot`, `/efi`, or `/boot/efi`, where both the
  kernel and initramfs match the local mkinitcpio presets.

It inserts `plymouth` immediately after `udev` or `systemd`, retaining the
machine's other hooks, graphics modules, root disk, encryption, resume, and
other kernel parameters. Boot settings are derived on the destination machine;
disk UUIDs, partition IDs, generated boot images, and encryption details are
never copied into Git. The existing bootloader remains in place.

Run this on an already configured machine without reinstalling the desktop:

```bash
sudo python3 tools/install_boot_splash.py --dry-run
sudo python3 tools/install_boot_splash.py
```

The helper inspects the complete plan before writing, backs up changed files
under `/var/lib/hyprshell/boot-backups/`, and runs `mkinitcpio -P`. For GRUB it
also regenerates `/boot/grub/grub.cfg`. A rerun with unchanged configuration
does not rewrite files or rebuild images.

If rebuilding fails, the edited configuration is restored. Generated images
may have been partially updated: complete `sudo mkinitcpio -P` successfully
before rebooting, and regenerate GRUB if its rebuild failed. The original
configuration files remain in the printed backup directory.

Other initramfs generators such as dracut, other bootloaders, dynamic shell
presets/hooks, custom mkinitcpio config paths, symlinked config files, and UKI
command-line drop-in directories need manual integration. These layouts stop
before any boot configuration is written. To install the desktop while leaving
boot configuration unchanged:

```bash
./setup.sh --skip-boot-splash
```

`--config-only` also leaves system boot configuration unchanged. A new Arch
installation needs an already working bootloader, a writable boot partition,
and graphics drivers supporting early modesetting. The actual animation and
handoff should be checked after reboot on each machine.

Upstream references: [Plymouth](https://wiki.archlinux.org/title/Plymouth),
[silent boot](https://wiki.archlinux.org/title/Silent_boot), and
[unified kernel images](https://wiki.archlinux.org/title/Unified_kernel_image).
