//
//  ContentView.swift
//  StreamAnimation
//
//  Created by Christian J Clampitt on 9/26/25.
//

import SwiftUI

// MARK: - Test Project for Node/Edge Animation Synchronization Issue

struct ContentView: View {
    @State private var nodeA = NodeModel(id: "A", position: CGPoint(x: 100, y: 200))
    @State private var nodeB = NodeModel(id: "B", position: CGPoint(x: 400, y: 200))

    var body: some View {
        ZStack {
            Color.gray.opacity(0.1)

            // Draw edge first (behind nodes) - using animating anchor points
            EdgeView(from: nodeA.animatingOutputAnchor, to: nodeB.animatingInputAnchor)

            // Draw nodes
            NodeView(model: nodeA)
            NodeView(model: nodeB)

            // Controls
            VStack {
                Spacer()
                HStack {
                    Button("Move Nodes (withAnimation)") {
                        withAnimation(.linear(duration: 0.3)) {
                            nodeA.position = CGPoint(x: 150, y: 300)
                            nodeB.position = CGPoint(x: 350, y: 300)
                        }
                    }

                    Button("Reset") {
                        withAnimation(.linear(duration: 0.3)) {
                            nodeA.position = CGPoint(x: 100, y: 200)
                            nodeB.position = CGPoint(x: 400, y: 200)
                        }
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Node Model

@Observable
class NodeModel {
    let id: String
    var position: CGPoint

    init(id: String, position: CGPoint) {
        self.id = id
        self.position = position
    }

    // Node is 100x100, so input is at -50, output at +50 from center
    var inputAnchor: CGPoint {
        CGPoint(x: position.x - 50, y: position.y)
    }

    var outputAnchor: CGPoint {
        CGPoint(x: position.x + 50, y: position.y)
    }

    // SOLUTION: Create animating versions that use the position value for animation
    var animatingInputAnchor: CGPoint {
        CGPoint(x: position.x - 50, y: position.y)
    }

    var animatingOutputAnchor: CGPoint {
        CGPoint(x: position.x + 50, y: position.y)
    }
}

// MARK: - Node View

struct NodeView: View {
    var model: NodeModel

    var body: some View {
        Rectangle()
            .fill(Color.blue.opacity(0.7))
            .frame(width: 100, height: 100)
            .position(model.position)
            .overlay(
                Text(model.id)
                    .foregroundColor(.white)
                    .position(model.position)
            )
    }
}

// MARK: - Edge View

struct EdgeView: View {
    let from: CGPoint
    let to: CGPoint

    var body: some View {
        AnimatableEdgeLine(from: from, to: to)
            .stroke(Color.purple, lineWidth: 3)
    }
}

// MARK: - Animatable Edge Shape

struct AnimatableEdgeLine: Shape {
    var from: CGPoint
    var to: CGPoint

    // This is absolutely required to redraw the Path smoothly
    var animatableData: AnimatablePair<AnimatablePair<Double, Double>, AnimatablePair<Double, Double>> {
        get {
            AnimatablePair(
                AnimatablePair(from.x, from.y),
                AnimatablePair(to.x, to.y)
            )
        }
        set {
            from.x = newValue.first.first
            from.y = newValue.first.second
            to.x = newValue.second.first
            to.y = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: from)

            // Simple curved connection (like Stitch's circuit edges)
            let midX = (from.x + to.x) / 2
            let controlPoint1 = CGPoint(x: midX, y: from.y)
            let controlPoint2 = CGPoint(x: midX, y: to.y)

            path.addCurve(to: to, control1: controlPoint1, control2: controlPoint2)
        }
    }
}

// MARK: - Alternative Implementations for Testing

// Version 2: Node with explicit position animation
struct NodeViewWithAnimation: View {
    var model: NodeModel

    var body: some View {
        Rectangle()
            .fill(Color.green.opacity(0.7))
            .frame(width: 100, height: 100)
            .position(model.position)
            .animation(.linear(duration: 0.3), value: model.position)
            .overlay(
                Text(model.id)
                    .foregroundColor(.white)
                    .position(model.position)
                    .animation(.linear(duration: 0.3), value: model.position)
            )
    }
}

// Version 3: Edge with explicit animation
struct EdgeViewWithAnimation: View {
    let from: CGPoint
    let to: CGPoint

    var body: some View {
        AnimatableEdgeLine(from: from, to: to)
            .stroke(Color.red, lineWidth: 3)
        
        // Not even required?
//            .animation(.linear(duration: 0.3), value: from)
//            .animation(.linear(duration: 0.3), value: to)
    }
}

// Version 4: Model with animated anchor point updates
@Observable
class NodeModelWithAnimatedAnchors {
    let id: String
    var position: CGPoint
    var inputAnchor: CGPoint
    var outputAnchor: CGPoint

    init(id: String, position: CGPoint) {
        self.id = id
        self.position = position
        self.inputAnchor = CGPoint(x: position.x - 50, y: position.y)
        self.outputAnchor = CGPoint(x: position.x + 50, y: position.y)
    }

    func updatePosition(_ newPosition: CGPoint, animated: Bool = false) {
        if animated {
            withAnimation(.linear(duration: 0.3)) {
                self.position = newPosition
                self.inputAnchor = CGPoint(x: newPosition.x - 50, y: newPosition.y)
                self.outputAnchor = CGPoint(x: newPosition.x + 50, y: newPosition.y)
            }
        } else {
            self.position = newPosition
            self.inputAnchor = CGPoint(x: newPosition.x - 50, y: newPosition.y)
            self.outputAnchor = CGPoint(x: newPosition.x + 50, y: newPosition.y)
        }
    }
}

#Preview {
    ContentView()
}
