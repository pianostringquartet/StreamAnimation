//
//  ContentView.swift
//  StreamAnimation
//
//  Created by Christian J Clampitt on 9/26/25.
//

import SwiftUI

// MARK: - Test Project for Node/Edge Animation Synchronization Issue

struct ContentView: View {
    @State private var graph = GraphModel()

    var body: some View {
        ZStack {
            // Enhanced gradient background
            RadialGradient(
                colors: [
                    Color.gray.opacity(0.05),
                    Color.gray.opacity(0.15),
                    Color.gray.opacity(0.25)
                ],
                center: .center,
                startRadius: 50,
                endRadius: 400
            )

            // Draw edges first (behind nodes)
            ForEach(graph.edges) { edge in
                EdgeView(edge: edge)
            }

            // Draw nodes
            ForEach(graph.nodes) { node in
                NodeView(model: node)
            }

            // Controls
            VStack {
                Spacer()
                HStack {
                    Button("Animate") {
                        graph.randomizeGraph()
                    }

                    if graph.isStreaming {
                        Button("Stop Streaming") {
                            graph.stopStreaming()
                        }
                    } else {
                        Button("Start Streaming") {
                            graph.startStreaming()
                        }
                    }
                }
                .padding()
            }
        }.padding()
    }
}

// MARK: - Graph Model

@Observable
class GraphModel {
    var nodes: [NodeModel] = []
    var edges: [EdgeModel] = []
    var isStreaming = false
    private var streamingTimer: Timer?

    init() {
        // Start with initial nodes at temporary positions
        let nodeA = NodeModel(id: "A", position: CGPoint.zero)
        let nodeB = NodeModel(id: "B", position: CGPoint.zero)
        nodes = [nodeA, nodeB]

        // Start with initial edge
        let initialEdge = EdgeModel(fromNodeID: "A", toNodeID: "B")
        edges = [initialEdge]

        // Arrange nodes in tree layout
        arrangeNodesInTreeLayout()

        // Initialize edge's animated points to current positions
        initialEdge.initializeAnimatedPoints(graph: self)
    }

    func randomizeGraph() {
        // PHASE 1: Retract all edges and fade out nodes to be removed
        for edge in edges {
            edge.retract()
        }

        // Determine what changes to make
        let shouldAddNodes = Bool.random()
        let changeCount = Int.random(in: 1...2)

        // Fade out nodes that will be removed
        if !shouldAddNodes && self.nodes.count > 2 {
            let removeCount = min(changeCount, self.nodes.count - 2)
            let nodesToRemove = Array(self.nodes.suffix(removeCount))
            for node in nodesToRemove {
                withAnimation(.easeInOut(duration: 0.3)) {
                    node.opacity = 0.0
                }
            }
        }

        // PHASE 2 (0.3-0.6s): Update nodes with constrained random positioning
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.linear(duration: 0.3)) {
                if shouldAddNodes && self.nodes.count < 8 {
                    // Add 1-2 new nodes (start with opacity 0)
                    for _ in 0..<changeCount {
                        let nodeID = self.availableNodeID()
                        let newNode = NodeModel(id: nodeID, position: self.constrainedRandomPosition())
                        newNode.opacity = 0.0
                        self.nodes.append(newNode)
                    }
                } else if self.nodes.count > 2 {
                    // Remove 1-2 nodes (keeping at least 2)
                    let removeCount = min(changeCount, self.nodes.count - 2)
                    for _ in 0..<removeCount {
                        self.nodes.removeLast()
                    }
                }

                // Reposition existing nodes randomly (with constraints)
                for node in self.nodes {
                    node.position = self.constrainedRandomPosition(excluding: node)
                }

                // Clean up edges that reference removed nodes
                let nodeIDs = Set(self.nodes.map { $0.id })
                self.edges.removeAll { edge in
                    !nodeIDs.contains(edge.fromNodeID) || !nodeIDs.contains(edge.toNodeID)
                }

                // Create sensible edges with directional constraint
                let edgeCount = Int.random(in: 1...min(3, self.nodes.count - 1))
                for _ in 0..<edgeCount {
                    guard let fromNode = self.nodes.randomElement() else { continue }

                    // Find valid targets (east of source, max 2 incoming edges)
                    let incomingCounts = Dictionary(grouping: self.edges, by: { $0.toNodeID })
                        .mapValues { $0.count }

                    let validTargets = self.nodes.filter { targetNode in
                        targetNode.id != fromNode.id &&
                        targetNode.position.x > fromNode.position.x && // Must be east
                        (incomingCounts[targetNode.id] ?? 0) < 2 && // Max 2 incoming edges
                        !self.wouldCreateCycle(from: fromNode.id, to: targetNode.id) // No cycles
                    }

                    guard let toNode = validTargets.randomElement() else { continue }

                    // Avoid duplicate edges
                    let edgeExists = self.edges.contains { edge in
                        edge.fromNodeID == fromNode.id && edge.toNodeID == toNode.id
                    }

                    if !edgeExists {
                        let newEdge = EdgeModel(fromNodeID: fromNode.id, toNodeID: toNode.id)
                        // Initialize at retracted state
                        newEdge.animatedFromPoint = fromNode.outputAnchor
                        newEdge.animatedToPoint = fromNode.outputAnchor
                        self.edges.append(newEdge)
                    }
                }
            }
        }

        // PHASE 3 (0.6-0.9s): Extend all edges and fade in new nodes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            for edge in self.edges {
                edge.extend(graph: self)
            }

            // Fade in new nodes
            for node in self.nodes where node.opacity == 0.0 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    node.opacity = 1.0
                }
            }
        }
    }

    // Constrained random positioning for Animate button
    func constrainedRandomPosition(excluding: NodeModel? = nil) -> CGPoint {
        let maxAttempts = 20

        for _ in 0..<maxAttempts {
            let position = CGPoint(
                x: Double.random(in: 70...330),
                y: Double.random(in: 120...480)
            )

            if !hasCollision(at: position, excluding: excluding) {
                return position
            }
        }

        // Fallback to safe position
        return safePosition(excluding: excluding)
    }

    func node(withID id: String) -> NodeModel? {
        nodes.first { $0.id == id }
    }

    func startStreaming() {
        isStreaming = true

        // Create a timer that fires every 0.5-1.5 seconds randomly
        streamingTimer = Timer.scheduledTimer(withTimeInterval: Double.random(in: 0.5...1.5), repeats: false) { _ in
            if self.isStreaming {
                self.performStreamingUpdate()
                self.scheduleNextStreamingUpdate()
            }
        }
    }

    func stopStreaming() {
        isStreaming = false
        streamingTimer?.invalidate()
        streamingTimer = nil
    }

    private func scheduleNextStreamingUpdate() {
        guard isStreaming else { return }

        let nextInterval = Double.random(in: 0.5...1.5)
        streamingTimer = Timer.scheduledTimer(withTimeInterval: nextInterval, repeats: false) { _ in
            if self.isStreaming {
                self.performStreamingUpdate()
                self.scheduleNextStreamingUpdate()
            }
        }
    }

    private func performStreamingUpdate() {
        // PHASE 1: Retract all edges and fade out nodes to be removed
        for edge in edges {
            edge.retract()
        }

        // Fade out nodes that will be removed
        let nodesToRemove = Int.random(in: 0...min(2, max(0, self.nodes.count - 2))) // Keep at least 2 nodes
        if nodesToRemove > 0 {
            for i in 0..<nodesToRemove {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.nodes[i].opacity = 0.0
                }
            }
        }

        // PHASE 2: Update nodes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.linear(duration: 0.3)) {
                // Remove the faded out nodes
                if nodesToRemove > 0 {
                    self.nodes.removeFirst(nodesToRemove)
                }

                // Add 2-5 new nodes (start with opacity 0)
                let nodesToAdd = Int.random(in: 2...5)
                for _ in 0..<nodesToAdd {
                    let nodeID = self.availableNodeID()
                    let newNode = NodeModel(id: nodeID, position: CGPoint.zero)
                    newNode.isNewlyAdded = true
                    newNode.opacity = 0.0
                    self.nodes.append(newNode)
                }

                // Arrange nodes in tree layout
                self.arrangeNodesInTreeLayout()

                // Clean up edges that reference removed nodes
                let nodeIDs = Set(self.nodes.map { $0.id })
                self.edges.removeAll { edge in
                    !nodeIDs.contains(edge.fromNodeID) || !nodeIDs.contains(edge.toNodeID)
                }

                // Add sensible edges - at most 2 incoming edges per node
                let edgeCount = Int.random(in: 1...min(3, self.nodes.count - 1))
                for _ in 0..<edgeCount {
                    guard let fromNode = self.nodes.randomElement() else { continue }

                    // Find nodes that have fewer than 2 incoming edges
                    let incomingCounts = Dictionary(grouping: self.edges, by: { $0.toNodeID })
                        .mapValues { $0.count }

                    let validTargets = self.nodes.filter { targetNode in
                        targetNode.id != fromNode.id &&
                        (incomingCounts[targetNode.id] ?? 0) < 2 && // Max 2 incoming edges
                        !self.wouldCreateCycle(from: fromNode.id, to: targetNode.id) // No cycles
                    }

                    guard let toNode = validTargets.randomElement() else { continue }

                    // Avoid duplicate edges
                    let edgeExists = self.edges.contains { edge in
                        edge.fromNodeID == fromNode.id && edge.toNodeID == toNode.id
                    }

                    if !edgeExists {
                        let newEdge = EdgeModel(fromNodeID: fromNode.id, toNodeID: toNode.id)
                        // Initialize at retracted state
                        newEdge.animatedFromPoint = fromNode.outputAnchor
                        newEdge.animatedToPoint = fromNode.outputAnchor
                        self.edges.append(newEdge)
                    }
                }
            }
        }

        // PHASE 3: Extend all edges and fade in new nodes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            for edge in self.edges {
                edge.extend(graph: self)
            }

            // Fade in new nodes
            for node in self.nodes where node.opacity == 0.0 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    node.opacity = 1.0
                }
            }

            // Reset newly added flags after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                for node in self.nodes {
                    node.isNewlyAdded = false
                }
            }
        }
    }
}

// MARK: - Edge Model

@Observable
class EdgeModel: Identifiable {
    let id = UUID()
    let fromNodeID: String
    let toNodeID: String

    // Animatable edge points - these drive the visual appearance
    var animatedFromPoint: CGPoint = CGPoint.zero
    var animatedToPoint: CGPoint = CGPoint.zero

    init(fromNodeID: String, toNodeID: String) {
        self.fromNodeID = fromNodeID
        self.toNodeID = toNodeID
    }

    // Get the current anchor points from the graph
    func liveFromPoint(graph: GraphModel) -> CGPoint {
        return graph.node(withID: fromNodeID)?.outputAnchor ?? CGPoint.zero
    }

    func liveToPoint(graph: GraphModel) -> CGPoint {
        return graph.node(withID: toNodeID)?.inputAnchor ?? CGPoint.zero
    }

    // Initialize animated points to match current node positions
    func initializeAnimatedPoints(graph: GraphModel) {
        animatedFromPoint = liveFromPoint(graph: graph)
        animatedToPoint = liveToPoint(graph: graph)
    }

    // Retract: animate to-point toward from-point
    func retract() {
        withAnimation(.linear(duration: 0.3)) {
            animatedToPoint = animatedFromPoint
        }
    }

    // Extend: animate drawing from source to destination
    func extend(graph: GraphModel) {
        // Set both points to source position first (reset state)
        animatedFromPoint = liveFromPoint(graph: graph)
        animatedToPoint = liveFromPoint(graph: graph)

        // Then animate only the destination point to target
        withAnimation(.linear(duration: 0.3)) {
            animatedToPoint = liveToPoint(graph: graph)
        }
    }
}

// MARK: - Node Model

@Observable
class NodeModel: Identifiable {
    let id: String
    var position: CGPoint
    var hierarchyLevel: Int = 0
    var isNewlyAdded: Bool = false
    var opacity: Double = 1.0

    init(id: String, position: CGPoint) {
        self.id = id
        self.position = position
    }

    // Node is 100x50, anchors adjusted for rounded rectangle visual boundaries
    var inputAnchor: CGPoint {
        CGPoint(x: position.x - 42, y: position.y)
    }

    var outputAnchor: CGPoint {
        CGPoint(x: position.x + 42, y: position.y)
    }

    // SOLUTION: Create animating versions that use the position value for animation
    var animatingInputAnchor: CGPoint {
        CGPoint(x: position.x - 42, y: position.y)
    }

    var animatingOutputAnchor: CGPoint {
        CGPoint(x: position.x + 42, y: position.y)
    }
}

// MARK: - Node View

struct NodeView: View {
    var model: NodeModel

    private var nodeGradient: LinearGradient {
        let baseHue = 0.6 // Blue base
        let lightness = max(0.3, 0.8 - Double(model.hierarchyLevel) * 0.15) // Darker for deeper levels
        let topColor = Color(hue: baseHue, saturation: 0.7, brightness: lightness + 0.2)
        let bottomColor = Color(hue: baseHue, saturation: 0.8, brightness: lightness - 0.1)

        return LinearGradient(
            colors: [topColor, bottomColor],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(nodeGradient)
            .frame(width: 100, height: 50)
            .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
            .scaleEffect(model.isNewlyAdded ? 1.1 : 1.0)
            .opacity(model.opacity)
            .position(model.position)
            .overlay(
                Text(model.id)
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium))
                    .shadow(color: .black.opacity(0.3), radius: 1)
                    .opacity(model.opacity)
                    .position(model.position)
            )
            .animation(.easeInOut(duration: 0.3), value: model.isNewlyAdded)
            .animation(.easeInOut(duration: 0.3), value: model.opacity)
    }
}

// MARK: - Edge View

struct EdgeView: View {
    let edge: EdgeModel

    var body: some View {
        AnimatableEdgeLine(
            from: edge.animatedFromPoint,
            to: edge.animatedToPoint
        )
        .stroke(Color.purple, lineWidth: 6)
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

            // Enhanced curve calculation for more natural flow
            let deltaX = to.x - from.x
            let deltaY = to.y - from.y
            let distance = sqrt(deltaX * deltaX + deltaY * deltaY)

            // Adaptive curve strength based on distance and direction
            let baseCurveStrength = min(distance * 0.4, 120)
            let verticalInfluence = abs(deltaY) * 0.3

            // Control points create an S-curve for better visual flow
            let controlPoint1 = CGPoint(
                x: from.x + baseCurveStrength + verticalInfluence * 0.5,
                y: from.y + deltaY * 0.2
            )
            let controlPoint2 = CGPoint(
                x: to.x - baseCurveStrength - verticalInfluence * 0.5,
                y: to.y - deltaY * 0.2
            )

            path.addCurve(to: to, control1: controlPoint1, control2: controlPoint2)
        }
    }
}

// MARK: - Tree Layout System

struct TreeLevel {
    var nodes: [NodeModel] = []
    var yPosition: Double = 0
}

// MARK: - Additional Graph Utilities

extension GraphModel {
    func availableNodeID() -> String {
        let usedIDs = Set(nodes.map { $0.id })
        for i in 0..<26 {
            let id = String(UnicodeScalar(65 + i)!) // A, B, C, D...
            if !usedIDs.contains(id) {
                return id
            }
        }
        return "Z" // Fallback
    }

    // Check if adding an edge would create a cycle
    func wouldCreateCycle(from fromNodeID: String, to toNodeID: String) -> Bool {
        // If we're adding A->B, check if there's already a path from B to A
        return hasPath(from: toNodeID, to: fromNodeID)
    }

    // Check if there's a path from one node to another (using existing edges)
    private func hasPath(from startNodeID: String, to targetNodeID: String) -> Bool {
        var visited = Set<String>()
        var queue = [startNodeID]

        while !queue.isEmpty {
            let currentNode = queue.removeFirst()

            if currentNode == targetNodeID {
                return true
            }

            if visited.contains(currentNode) {
                continue
            }
            visited.insert(currentNode)

            // Find all outgoing edges from current node
            let outgoingEdges = edges.filter { $0.fromNodeID == currentNode }
            for edge in outgoingEdges {
                if !visited.contains(edge.toNodeID) {
                    queue.append(edge.toNodeID)
                }
            }
        }

        return false
    }

    // Check if a position collides with existing nodes
    func hasCollision(at position: CGPoint, excluding: NodeModel? = nil) -> Bool {
        let minDistance: Double = 120 // Minimum distance between node centers

        for node in nodes {
            if let excluding = excluding, node.id == excluding.id {
                continue
            }

            let distance = sqrt(pow(position.x - node.position.x, 2) + pow(position.y - node.position.y, 2))
            if distance < minDistance {
                return true
            }
        }
        return false
    }

    // Generate a safe position without collisions
    func safePosition(excluding: NodeModel? = nil) -> CGPoint {
        let maxAttempts = 20

        for _ in 0..<maxAttempts {
            let position = CGPoint(
                x: Double.random(in: 70...330), // Account for node width
                y: Double.random(in: 120...480)  // Account for node height
            )

            if !hasCollision(at: position, excluding: excluding) {
                return position
            }
        }

        // Fallback: grid positioning if random fails
        return findGridPosition(excluding: excluding)
    }

    // Fallback grid positioning
    private func findGridPosition(excluding: NodeModel? = nil) -> CGPoint {
        let gridSpacing: Double = 130
        let startX: Double = 85
        let startY: Double = 140

        for row in 0..<4 {
            for col in 0..<3 {
                let position = CGPoint(
                    x: startX + Double(col) * gridSpacing,
                    y: startY + Double(row) * gridSpacing
                )

                if !hasCollision(at: position, excluding: excluding) {
                    return position
                }
            }
        }

        // Final fallback
        return CGPoint(x: 200, y: 200)
    }

    // Build tree structure and assign levels
    func buildTreeLevels() -> [TreeLevel] {
        var levels: [TreeLevel] = []
        var nodeToLevel: [String: Int] = [:]
        var visited: Set<String> = []

        // Find root nodes (nodes with no incoming edges)
        let hasIncomingEdge = Set(edges.map { $0.toNodeID })
        let rootNodes = nodes.filter { !hasIncomingEdge.contains($0.id) }

        // If no clear roots, pick first few nodes as roots
        let actualRoots = rootNodes.isEmpty ? Array(nodes.prefix(min(2, nodes.count))) : rootNodes

        // Assign root level
        if !actualRoots.isEmpty {
            levels.append(TreeLevel(nodes: actualRoots, yPosition: 140))
            for root in actualRoots {
                root.hierarchyLevel = 0
                nodeToLevel[root.id] = 0
                visited.insert(root.id)
            }
        }

        // Build subsequent levels using BFS-like approach
        var currentLevel = 0
        while visited.count < nodes.count && currentLevel < 5 { // Max 5 levels
            var nextLevelNodes: [NodeModel] = []

            // Find nodes that are children of current level nodes
            for edge in edges {
                if nodeToLevel[edge.fromNodeID] == currentLevel && !visited.contains(edge.toNodeID) {
                    if let childNode = nodes.first(where: { $0.id == edge.toNodeID }) {
                        childNode.hierarchyLevel = currentLevel + 1
                        nextLevelNodes.append(childNode)
                        nodeToLevel[edge.toNodeID] = currentLevel + 1
                        visited.insert(edge.toNodeID)
                    }
                }
            }

            if !nextLevelNodes.isEmpty {
                let yPos = 140 + Double(currentLevel + 1) * 120 // 120px between levels
                levels.append(TreeLevel(nodes: nextLevelNodes, yPosition: yPos))
            }

            currentLevel += 1
        }

        // Add any remaining unvisited nodes to final level
        let unvisitedNodes = nodes.filter { !visited.contains($0.id) }
        if !unvisitedNodes.isEmpty {
            let yPos = levels.isEmpty ? 140 : levels.last!.yPosition + 120
            levels.append(TreeLevel(nodes: unvisitedNodes, yPosition: yPos))
        }

        return levels
    }

    // Position nodes in tree layout
    func arrangeNodesInTreeLayout() {
        let levels = buildTreeLevels()

        for level in levels {
            let nodeCount = level.nodes.count
            let screenWidth: Double = 400
            let totalNodeWidth = Double(nodeCount) * 100 // Node width
            let totalSpacing = max(0, Double(nodeCount - 1) * 30) // 30px spacing between nodes
            let totalWidth = totalNodeWidth + totalSpacing

            let startX = (screenWidth - totalWidth) / 2 + 80 // Center horizontally, shifted east

            for (index, node) in level.nodes.enumerated() {
                let xPos = startX + Double(index) * (100 + 30) // Node width + spacing
                node.position = CGPoint(x: xPos, y: level.yPosition)
            }
        }
    }
}

#Preview {
    ContentView()
}
