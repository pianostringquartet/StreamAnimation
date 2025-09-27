# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a SwiftUI iOS application called "StreamAnimation" created with Xcode. The project follows the standard iOS app structure with:
- Main app entry point: `StreamAnimationApp.swift`
- Primary view: `ContentView.swift`
- Standard Xcode test targets for unit and UI tests

## Architecture

- **App Structure**: Standard SwiftUI app with `@main` entry point in `StreamAnimationApp.swift`
- **UI Framework**: SwiftUI-based with `ContentView` as the root view
- **Testing**: Uses the new Swift Testing framework (`import Testing`) for unit tests
- **Project Type**: Xcode project (`.xcodeproj`) with standard iOS app configuration

## Development Commands

Since this is an Xcode project, development typically happens through Xcode IDE. Key operations:

- **Build**: Use Xcode's build system (⌘+B) or through Xcode's interface
- **Run Tests**: Use Xcode's test navigator or ⌘+U for all tests
- **Run App**: Use Xcode's run button or ⌘+R to build and run on simulator/device

## Project Structure

```
StreamAnimation/
├── StreamAnimation/           # Main app target
│   ├── StreamAnimationApp.swift    # App entry point
│   ├── ContentView.swift           # Main view
│   └── Assets.xcassets/            # App assets and resources
├── StreamAnimationTests/      # Unit tests (Swift Testing)
├── StreamAnimationUITests/    # UI tests
└── StreamAnimation.xcodeproj/ # Xcode project file
```

## Testing Framework

The project uses the new Swift Testing framework introduced in recent iOS versions:
- Import with `import Testing`
- Use `@Test` attribute for test functions
- Use `#expect(...)` for assertions instead of XCTest's `XCTAssert`