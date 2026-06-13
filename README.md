# Music Understanding Experiments

A SwiftUI lab app for exploring Apple's `MusicUnderstanding` framework through song analysis, dataset comparison, DJ transition matching, practice tools, and live PCM stream analysis.

The app is built as a hands-on music analysis workspace: import a song, inspect its musical structure, compare multiple analyzed tracks, find transition candidates, rehearse section loops, and monitor loudness from a generated audio stream.

<p>
  <img width="336" height="730" alt="606996078-10a07d7a-849f-4bf5-bed9-790a1a389e32" src="https://github.com/user-attachments/assets/063d100e-93ce-4232-a5fc-70ea4a23c2da" />
  <img width="336" height="730" alt="606996247-c8c13694-771e-4329-86cd-deb6e78a3e40" src="https://github.com/user-attachments/assets/7d13a2f5-9c7f-4017-b08e-738ef394debc" />
</p>

## Features

- Analyze local audio files for key, tempo, meter, structure, pace, instrument activity, and loudness.
- View timeline lanes for sections, phrases, segments, beats, bars, key regions, density, and LUFS curves.
- Play analyzed songs with transport controls and timeline-aware metrics.
- Export a single-song analysis as JSON and summary text.
- Compare analyzed songs by BPM, key, LUFS, density, energy, and duration.
- Export multiple analyzed songs as a dataset JSON file.
- Find DJ-friendly transition candidates using tempo, key, and energy matching.
- Practice with section loops, beat/bar tracking, and count-in markers.
- Generate a live PCM stream and inspect loudness metrics in real time.

## App Sections

### Analysis

Import a song and inspect the generated music understanding document. The analysis view shows high-level song metadata, playback controls, key and rhythm summaries, structure lanes, instrument activity, loudness curves, and detailed timeline visualizations.

### Data Compare

Collect analyzed songs into a comparison view. This screen summarizes the library, lists per-song metrics, visualizes BPM/energy distribution, and prepares dataset exports.

<img width="336" height="730" alt="Screenshot iPhone 17 Pro Max 12 06 2026 at 10 56 09" src="https://github.com/user-attachments/assets/d24f64bd-7331-4c4b-903c-8f496d24eb21" />

### DJ Finder

Ranks transition candidates between analyzed songs. Matches are scored using BPM distance, key compatibility, and energy similarity.

<img width="336" height="730" alt="Screenshot iPhone 17 Pro Max 12 06 2026 at 10 56 13" src="https://github.com/user-attachments/assets/f26ca1f5-43fd-4ae1-95c1-de2455121591" />

### Practice

Turns an analyzed song into a rehearsal companion. You can play the track, jump through sections, loop song parts, and follow current bar/beat markers.

<img width="336" height="730" alt="Screenshot iPhone 17 Pro Max 12 06 2026 at 10 56 21" src="https://github.com/user-attachments/assets/cefc97f5-ebc1-496e-8f17-17ff04c61991" />

### Streaming

Creates a generated PCM audio stream and analyzes loudness as samples arrive. Frequency, amplitude, and duration can be adjusted live before starting a run.

<img width="336" height="730" alt="Screenshot iPhone 17 Pro Max 12 06 2026 at 10 56 42" src="https://github.com/user-attachments/assets/fe778fad-b837-4960-8fcc-56dd1fada4d3" />

## Requirements

- Xcode 27
- SwiftUI
- Apple platform SDKs matching the project configuration
- A simulator or device capable of running the selected target

## Running

1. Open `MU-Experiments.xcodeproj` in Xcode.
2. Select the `MU-Experiments` scheme.
3. Choose a supported simulator or device.
4. Build and run.
5. Use **Select & Analyze Song** to import an audio file.

## Exports

Single-song exports include:

- Pretty-printed JSON analysis data
- A readable text summary

Dataset exports include:

- A JSON array of analyzed song documents, suitable for comparison, prototyping, or downstream experiments

## Notes

This project is an experimentation space for music analysis workflows. The UI is optimized for quickly moving between analysis, comparison, DJ preparation, rehearsal, and live-stream inspection rather than for a single production workflow.

Official documentation: https://developer.apple.com/documentation/musicunderstanding 
