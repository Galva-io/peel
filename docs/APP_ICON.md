# AppIcon

Drop the macOS icon PNGs into this folder, with filenames matching the slots
declared in `Contents.json`:

| File | Size |
| --- | --- |
| `icon_16x16.png`     | 16×16 |
| `icon_16x16@2x.png`  | 32×32 |
| `icon_32x32.png`     | 32×32 |
| `icon_32x32@2x.png`  | 64×64 |
| `icon_128x128.png`   | 128×128 |
| `icon_128x128@2x.png`| 256×256 |
| `icon_256x256.png`   | 256×256 |
| `icon_256x256@2x.png`| 512×512 |
| `icon_512x512.png`   | 512×512 |
| `icon_512x512@2x.png`| 1024×1024 |

Then update each entry in `Contents.json` with a `"filename"` field, e.g.

```json
{ "idiom" : "mac", "scale" : "1x", "size" : "16x16", "filename" : "icon_16x16.png" }
```

Or simply open `Assets.xcassets` in Xcode and drag PNGs onto the slots —
Xcode rewrites `Contents.json` for you.

Until images land, the app launches with macOS's generic application icon,
which is harmless.
