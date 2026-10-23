# Logitech Driving Force GT on Windows 11 with Memory Integrity enabled

[Покрокова інструкція українською / Full Ukrainian guide](README.uk.md)

An anonymized case study, documented on October 23, 2026. This is **not a new Windows driver or a complete force-feedback solution**. The original PC previously had Logitech drivers; this procedure has not been validated from start to finish on a clean Windows installation.

## Confirmed on the original PC

- Memory Integrity remained enabled. The physical wheel used Microsoft's `input.inf`.
- A locally tested HID script switched Logitech `VID_046D` from fallback `PID_C294` to native `PID_C29A`.
- A separate command set 360° total rotation, with full input at roughly ±180°, and disabled the excessive automatic centering spring.
- Independent accelerator Y and brake Z inputs were inverted: released 65535, fully pressed 0.
- x360ce 4.26.38.0 converted them into independent Xbox RT/LT inputs: 0 released, 255 fully pressed.
- HidHide hid only the physical DFGT from games while allowing x360ce and the Windows PowerShell executable used for mode/range scripts to access it.
- The owner confirmed steering and pedal operation in Need for Speed Unbound (Epic → EA app).

## Outline

1. Create and verify a restore point, preserve Memory Integrity, and inspect current hardware IDs and driver bindings.
2. With the game closed, check native mode and the rotation range using reviewed local scripts. Verify the actual PID and physical range; a successful write alone is insufficient.
3. Check pedal independence in a freshly opened `joy.cpl`. Do not replace registry axis mappings based on misleading labels.
4. Use [x360ce 4.x](https://www.x360ce.com/) with the official signed [ViGEmBus](https://github.com/nefarius/ViGEmBus/releases/tag/v1.22.0) package. ViGEmBus is [end of life](https://docs.nefarius.at/projects/ViGEm/End-of-Life/); future compatibility is not guaranteed.
5. Identify actual input axes before mapping. This particular x360ce profile used Left Thumb X `=a1`, RT `=1-a2`, LT `=1-a3`. Verify the output, including full 255 travel, before launching the game.
6. Configure [HidHide](https://docs.nefarius.at/projects/HidHide/Simple-Setup-Guide/) only after mapping works. Allow the exact x360ce executable and the script host; leave the virtual Xbox visible. Reconnect USB and recheck x360ce input.
7. Keep x360ce running during play. Review the in-game deadzone separately; an early screenshot showed 22%, but its current value is unverified. A 2–5% setting was suggested for a manual test.
8. Enable optional per-user mode-switch automation only after successful manual checks. It polls for C294 and applies 360°/AutoCenter Off after switching; it does not reset a wheel already in C29A.

The full guide contains commands using portable `C:\DFGT` example paths, troubleshooting, and rollback. Copies of the four mode/range/automation scripts used in this session are included in the repository root. Download the repository ZIP, extract it, and place the four `.ps1` files together in `C:\DFGT`. Review them before running. Nothing is installed or run automatically.

## Force feedback remains unresolved

The owner recalls full force feedback with the old Logitech driver, apart from pedal mapping problems. With the current Microsoft profile, a fresh DirectInput capability query returned flags `0x5` with `DIDC_FORCEFEEDBACK=False`. x360ce's short tests produced no physical response; cached old metadata was misleading.

A separate low-force 250 ms HID pulse and its stop command were accepted by Windows. The owner reported no noticeable movement during that test. REA research and an offline command-encoding component exist, but there is no finished or installed replacement driver, DirectInput effect module, or game feedback integration.

A future user-mode effect module may be possible; the need for a new kernel driver is unproven. A kernel driver would require proper signing and [Memory Integrity compatibility testing](https://learn.microsoft.com/en-us/windows-hardware/test/hlk/testref/driver-compatibility-with-device-guard). Xbox rumble, an artificial centering spring, and wheel-specific physics effects are different outputs.

## Lessons and rollback

Registry axis swaps did not fix the game and temporarily worsened input. They were rolled back using device-specific backups. An old `joy.cpl` window also retained stale metadata; reopening the entire panel mattered. Do not import another computer's registry exports or clear a working device profile.

To return to direct physical input, close the game, unhide only your DFGT, reconnect USB, close x360ce, and disable/stop the `DFGT Native AutoSwitch` task if installed. Restore 900° separately if desired. Uninstall optional virtual-controller drivers only after checking whether other software uses them.

No proprietary Logitech binaries, access tokens, personal instance IDs, registry dumps, or user screenshots are included. Protocol references: [Linux lg4ff](https://github.com/torvalds/linux/blob/master/drivers/hid/hid-lg4ff.c), [Microsoft DirectInput effect-driver API](https://learn.microsoft.com/en-us/windows/win32/api/dinputd/).
