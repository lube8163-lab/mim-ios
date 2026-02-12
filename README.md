# Mim (iOS)

<p align="center">
  <img src="screenshots/feed.png" width="320">
  <img src="screenshots/20260201_235403.GIF" width="320">
</p>

# Mim iOS App

Mim is an experimental iOS social app focused on **semantic communication**: users share meaning, not raw pixels.

Instead of distributing original image files in the feed, Mim extracts semantic information from user-selected images and reconstructs visuals with on-device AI workflows.

## What It Does

- Create social posts with text and/or images
- Extract semantic signals from selected images
- Generate prompts and reconstruct images using Stable Diffusion (when models are installed)
- Show low-resolution guide previews while generation is in progress
- Browse a timeline feed with likes and sharing

## Safety & UGC Moderation

Mim is a UGC feed app and includes in-app safety controls:

- Email registration required before posting
- Privacy Policy and Terms agreement required on first launch
- In-app post reporting (`Timeline > Post menu > Report`)
- In-app user blocking (`Timeline > Post menu > Block User`)
- Blocked users’ posts are hidden from feed results
- Keyword-based screening for text before submission
- Reports are reviewed and actioned (content removal / account action) when needed

## Privacy

- Photos are accessed only through `PhotosPicker`
- Only user-selected images are processed
- No background photo library access
- Core semantic/image processing is primarily on-device
- No tracking SDKs are included

## Models & Backend

- This repository contains the iOS client source code
- AI models are optional and downloaded separately in-app
- Model licenses are governed by their respective upstream terms
- Backend services are used for social/feed features and moderation workflows

## TestFlight

External beta is available here:

[https://testflight.apple.com/join/9UndzF6P](https://testflight.apple.com/join/9UndzF6P)

## Requirements

- iOS 18+
- Recommended: newer devices with sufficient memory (e.g. iPhone 14 or later)

## Status

- External TestFlight beta
- Experimental / research-oriented
- Not intended as a production-ready release

## License

Application source code is licensed under the Apache License 2.0.

AI models are not bundled in this repository and remain under their own licenses.

## Contact

Developer contact: `lube8163@icloud.com`
