# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

StreamAnimation is a SwiftUI test project for visualizing and debugging node-edge graph animations during streaming updates. The core challenge it addresses is synchronizing edge animations with node movements to prevent visual artifacts like "edges to nowhere" or edges jumping to positions.

## Core Architecture

### Animation System (3-Phase Strategy)
The app implements a sophisticated 3-phase animation pattern for all graph updates:

1. **Phase 1 - Retraction (0.0-0.3s)**:
   - All edges retract to their source nodes
   - Nodes marked for removal fade out (opacity → 0)

2. **Phase 2 - Repositioning (0.3-0.6s)**:
   - Nodes are added/removed/repositioned
   - Tree layout algorithm arranges nodes hierarchically
   - Edges are recalculated but remain retracted

3. **Phase 3 - Extension (0.6-0.9s)**:
   - Edges extend from source to destination
   - New nodes fade in (opacity 0 → 1)
   - Visual emphasis animations complete

### Key Components in ContentView.swift

**GraphModel (@Observable class)**:
- Manages `nodes` and `edges` arrays
- Implements two animation modes:
  - `randomizeGraph()`: Constrained random positioning with directional flow
  - `performStreamingUpdate()`: Tree-based hierarchical layout for streaming
- Contains graph algorithms:
  - `wouldCreateCycle()`: Prevents cycles using BFS path detection
  - `buildTreeLevels()`: Creates hierarchical tree structure
  - `hasCollision()`: Ensures minimum node spacing (120px)

**EdgeModel (@Observable class)**:
- Maintains `animatedFromPoint` and `animatedToPoint` for smooth transitions
- `retract()`: Animates edge to source node
- `extend()`: Animates edge from source to destination
- Uses separate animated points from live positions to control timing

**NodeModel (@Observable class)**:
- Position, opacity, hierarchyLevel properties
- Anchor points for edges (±42px from center for visual boundaries)
- `isNewlyAdded` flag for visual emphasis

**AnimatableEdgeLine (Shape)**:
- Custom Shape with animatableData for smooth bezier curve animations
- Adaptive control points based on distance and direction
- Creates natural S-curves between nodes

### Animation Constraints

- **No cycles**: DAG (Directed Acyclic Graph) enforced
- **Directional flow**: Downstream nodes positioned east of upstream
- **Edge limits**: Maximum 2 incoming edges per node
- **Collision detection**: 120px minimum distance between nodes
- **Visual boundaries**: Edge anchors at ±42px (accounting for rounded rectangles)

## Development Commands

Since this is an Xcode project, use the Xcode IDE or xcodebuild:

- **Build**: `swift build` or Xcode (⌘+B)
- **Run Tests**: `swift test` or Xcode (⌘+U)
- **Run App**: Through Xcode (⌘+R) on simulator/device
- **Clean Build**: `swift package clean` or Xcode (⌘+Shift+K)

## Testing Framework

Uses the new Swift Testing framework:
- Import with `import Testing`
- Use `@Test` attribute for test functions
- Use `#expect(...)` for assertions instead of XCTest's `XCTAssert`

## Project Structure

```
StreamAnimation/
├── StreamAnimation/           # Main app target
│   ├── StreamAnimationApp.swift    # App entry point with @main
│   ├── ContentView.swift           # Complete implementation (all logic)
│   └── Assets.xcassets/            # App assets
├── StreamAnimationTests/      # Unit tests (Swift Testing)
├── StreamAnimationUITests/    # UI tests
└── StreamAnimation.xcodeproj/ # Xcode project configuration
```

## Key Implementation Details

- All animation logic is contained in a single `ContentView.swift` file
- Uses SwiftUI's `@Observable` macro (not ObservableObject protocol)
- Animation timing is precisely controlled with DispatchQueue.asyncAfter
- Graph layout alternates between tree-based (streaming) and constrained random (manual)
- Opacity transitions provide smooth node appearance/disappearance
- Edge curves use adaptive bezier control points for natural flow