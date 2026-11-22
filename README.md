# Photosynth 🌱

A plant-themed rhythm game for iPhone, built with SwiftUI. Tap seeds as they reach the pots; hit well and your plant grows from a seedling into a daisy, tulip, cherry blossom and sunflower. Miss and it wilts.

- 2, 3, 4 or 5 tracks (Seedling / Sprout / Bloom / Garden)
- Tap notes, hold-vine notes and multi-lane chords
- 5 songs, all public-domain compositions or originals, played by an in-app synthesizer (no audio files, royalty free):
  *Morning Dew*, *Sunbeam Stroll*, *Rain Dance*, *In the Hall of the Mountain King* (Grieg, 1875), *Flight of the Bumblebee* (Rimsky-Korsakov, 1900)

## Build

Requires Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
xcodegen generate
open Photosynth.xcodeproj
```

Launch with `-autoplay` to have the game hit every note (handy for testing).
