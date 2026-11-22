# Bloom Beat 🌱

A plant-themed rhythm game for iPhone, built with SwiftUI. Tap seeds as they reach the pots; hit well and your plant grows from a seedling into a daisy, tulip, cherry blossom and sunflower. Miss and it wilts.

- 2, 3, 4 or 5 tracks (Seedling / Sprout / Bloom / Garden)
- Tap notes, hold-vine notes and multi-lane chords. Every song grows one flower (daisy, tulip, cherry blossom or sunflower) from a seedling to a big bloom
- 23 songs, all public-domain compositions or originals, played by an in-app synthesizer (no audio files, royalty free):
  12 originals (gentle ambient to hard electro, with minor, blues, Japanese and lydian scales) plus classical pieces (*Mountain King*, *Bumblebee*, *Ode to Joy*) and folk and nursery tunes (*Twinkle Twinkle*, *Jingle Bells*, *When the Saints Go Marching In*, *Mary Had a Little Lamb*, *Row Row Row Your Boat*, *Hot Cross Buns*, *London Bridge*, *Oh! Susanna*)

## Build

Requires Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
xcodegen generate
open BloomBeat.xcodeproj
```

Launch with `-autoplay` to have the game hit every note (handy for testing).
Launch with `-seedshelf` to fill the plant shelf with sample plants.
Other debug flags: `-autostart <songId> <lanes>` starts a song directly (e.g. `-autostart neon 5`), `-showshelf` opens the shelf.
Debug flags for recording: `-fastgrow` (plant grows ~2.4x faster) and `-marker` (flashes a bright frame when a song starts).
