# Bloom Beat 🌱

A plant-themed rhythm game for iPhone, built with SwiftUI. Tap seeds as they reach the pots; hit well and your plant grows from a seedling into a daisy, tulip, cherry blossom and sunflower. Miss and it wilts.

- 2, 3, 4 or 5 tracks (Seedling / Sprout / Bloom / Garden)
- Tap notes, hold-vine notes and multi-lane chords
- 10 songs, all public-domain compositions or originals, played by an in-app synthesizer (no audio files, royalty free):
  3 originals plus *Mountain King*, *Bumblebee*, *Ode to Joy*, *Twinkle Twinkle*, *Jingle Bells*, *When the Saints Go Marching In* and *Mary Had a Little Lamb*

## Build

Requires Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
xcodegen generate
open BloomBeat.xcodeproj
```

Launch with `-autoplay` to have the game hit every note (handy for testing).
Launch with `-seedshelf` to fill the plant shelf with sample plants.
