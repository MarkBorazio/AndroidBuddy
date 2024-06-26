<p align="center">
  <img width="256" src="res/app_icon.png" alt="App Icon">
</p>

# Android Buddy

A simple Mac application that lets you transfer files to and from your Android device.

[Download the latest release here](https://github.com/MarkBorazio/AndroidBuddy/releases) (Requires MacOS 13.5 or later)
> Note: Android Buddy **does not** run in sandbox mode.

# Introduction

I created this because I hate Google's Android File Transfer app. Other alternatives exist, but I wanted one that looks like a standard MacOS app.

# Features
- Transfer files larger than 4GB
- Install APKs
- Delete, move, and rename files and folders
- Create new folders
- Instantaneous USB device detection
- Drag and Drop files
- Supports multiple devices simultaneously
- Standard MacOS theming (including dark mode support)
- **Does not** automatically open when you plug in an Android device

# Screenshots

<p>
  <img width="800" src="res/directory.png" alt="Directory">
  <img width="800" src="res/uploading.png" alt="Uploading">
  <img width="800" src="res/downloading.png" alt="Downloading">
</p>

# Contribute
PRs and bugfixes are welcome.

In order to set yourself up for development, you will need:
- MacOS 13.5 or higher
- Xcode 15 or higher

Simply clone the repository and open it in Xcode. The only dependency in this app is ADB, which is bundled statically, so Xcode should be able to run things without an issue.

This app is built using Apple's SwiftUI and Combine frameworks.