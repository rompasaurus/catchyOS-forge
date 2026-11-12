# Making the ASUS XG32UCWMG look like it does on CachyOS (Windows settings)

The ROG Strix OLED XG32UCWMG looks brighter and easier to read on this KDE Wayland
setup than on Windows. This note records what the Linux session is actually sending
the monitor and the Windows changes that reproduce it.

Captured on 2026-11-12 with `kscreen-doctor -o`, `edid-decode`, `ddcutil`, and `fc-match`.

## What KDE is doing (DP-1, Radeon RX 9070 XT)

| Setting | Linux (KDE Wayland) |
|---|---|
| HDR | on, SDR content brightness **550 nits** |
| Wide color gamut | on, SDR gamut wideness 0% (sRGB colors, not oversaturated) |
| Mode | 3840x2160 @ 240 Hz, 16 bits per color, RGB range auto |
| Color power preference | prefer accuracy |
| Display scale | 100% |
| Font rendering | grayscale antialiasing, slight hinting, no subpixel (ClearType-style) rendering |
| Monitor OSD (via DDC/CI) | brightness 90, contrast 80, 6500K, User mode |

Panel facts from the EDID: peak 1317 nits, max frame-average 265 nits, min 0.0002 nits,
10-bit, BT.2020 capable, gamma 2.2.

## Why Windows looks dimmer and fuzzier

1. **Brightness.** With HDR off, Windows runs the monitor in SDR mode, where an OLED is
   capped by its SDR brightness limit and any "Uniform Brightness" setting, usually well
   under 550 nits. KDE keeps the panel in HDR mode full time and tone-maps the desktop to
   550 nits, so the desktop is far brighter than SDR mode can ever reach.
2. **Text.** The XG32UCWMG is a WOLED with an RGWB subpixel layout. Windows ClearType
   assumes a standard RGB stripe, so it adds red/green fringing on text. KDE uses plain
   grayscale antialiasing, which looks clean on OLED.

## Windows changes to match

1. **Turn on HDR.** Settings > System > Display > HDR > "Use HDR" on. Then run the
   *Windows HDR Calibration* app (Microsoft Store) so Windows knows the panel's real peak
   (1317 nits) and frame-average (265 nits) and does not clip.
2. **Raise the SDR content brightness slider** on the same HDR page. It defaults low,
   which is the "washed out HDR desktop" everyone complains about. On one measured OLED
   the slider at 100 landed near 500 nits, close to KDE's 550. Start at 80-100 and tune
   by eye.
3. **Optional: fix raised blacks.** Windows maps SDR into HDR with the piecewise sRGB
   curve while KDE uses gamma 2.2, so Windows shadows look slightly lifted. Community fix:
   Dylan Raga's sRGB-to-gamma-2.2 ICC profile for Windows 11 HDR
   (`win11hdr-srgb-to-gamma2.2-icm` on GitHub), applied under Color Management.
4. **Match the signal.** Settings > Display > Advanced display: 240 Hz.
   AMD Adrenalin > Display: pixel format RGB 4:4:4 Full, color depth 10 bpc.
5. **Fix text.** Start menu > "Adjust ClearType text" > uncheck "Turn on ClearType" to get
   grayscale antialiasing like KDE. For finer control, the free *Better ClearType Tuner*
   lets you pick grayscale explicitly. KDE is at 100% scale here; Windows recommends 150%
   for a 32" 4K panel, so size will differ unless you set Windows to 100% too.
6. **Monitor OSD.** Nothing to change. Brightness, contrast and color temperature live in
   the monitor and apply to both OSes. In HDR mode the panel ignores the brightness
   setting anyway.

## Reproducing the Linux side

```sh
kscreen-doctor -o                               # HDR, SDR brightness, gamut, mode
edid-decode /sys/class/drm/card1-DP-1/edid      # panel luminance / colorimetry
ddcutil --display 2 getvcp 10 12 14 DC          # OSD brightness, contrast, preset, mode
fc-match -v sans | grep -E 'antialias|hint|rgba'
```

## Sources

- [ASUS: 32-inch glossy WOLED panels debut in the XG32UCWMG (RGWB layout)](https://rog.asus.com/eg-en/articles/gaming-monitors/32-inch-glossy-woled-panels-debut-in-the-rog-strix-oled-xg32ucwmg-and-xg32ucwg-gaming-monitors/)
- [TFTCentral on ClearType and OLED subpixel layouts](https://tftcentral.co.uk/news/asus-unveil-the-rog-swift-oled-pg32ucwm-a-new-32-4k-tandem-woled-monitor-with-rgb-stripe)
- [Microsoft: HDR settings in Windows](https://support.microsoft.com/en-us/windows/2d767185-38ec-7fdc-6f97-bbc6c5ef24e6)
- [HardForum: SDR content brightness nit measurements](https://hardforum.com/threads/windows-11-sdr-content-brightness.2027311/)
- [ElevenForum: change SDR content brightness in Windows 11](https://www.elevenforum.com/t/change-hdr-or-sdr-content-brightness-for-hdr-display-in-windows-11.7832/)
