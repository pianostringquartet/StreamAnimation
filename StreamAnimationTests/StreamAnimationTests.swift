//
//  StreamAnimationTests.swift
//  StreamAnimationTests
//
//  Created by Christian J Clampitt on 9/26/25.
//

import Testing
import Foundation


struct StreamAnimationTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        #expect(1 == 1)
    }
//
//    @Test func testRecursiveDictionaryMutationWithInout() throws {
//      
//
//         // Mimic your createLayerNodes with recursion + inout + closures
//         func createNodes(
//             layers: [BadAccessTestLayerData],
//             parentId: UUID?,
//             nodesDict: inout [UUID: BadAccessTestNodeEntity],
//             connections: inout [String: [UUID]],
//             depth: Int = 0
//         ) throws {
//             // Match your structure: forEach over array
//             layers.forEach { layer in
//                 let nodeId = UUID()
//                 let entity = BadAccessTestNodeEntity(
//                     id: nodeId,
//                     data: layer.id,
//                     nested: layer.inputs
//                 )
//
//                 // First mutation
//                 nodesDict[nodeId] = entity
//
//                 // Nested forEach (like your custom_layer_input_values)
//                 layer.inputs.forEach { nestedData in
//
//                     // Another nested forEach (like your inputData)
//                     nestedData.values.forEach { inputValue in
//                         do {
//                             // Mutating extension method called in nested closure
//                             try nodesDict.updateNode(
//                                 id: nodeId,
//                                 value: inputValue.payload,
//                                 otherDict: &connections
//                             )
//                         } catch {
//                             print("Error: \(error)")
//                         }
//                     }
//                 }
//
//                 // Recursive call with SAME inout parameters
//                 if let children = layer.children, !children.isEmpty {
//                     try! createNodes(
//                         layers: children,
//                         parentId: nodeId,
//                         nodesDict: &nodesDict,
//                         connections: &connections,
//                         depth: depth + 1
//                     )
//                 }
//             }
//         }
//
//         // Create deeply nested test data
//         func makeNestedLayers(depth: Int, breadth: Int) -> [BadAccessTestLayerData] {
//             guard depth > 0 else { return [] }
//
//             return (0..<breadth).map { i in
//                 let inputs = (0..<5).map { j in
//                     BadAccessTestNestedData(
//                         values: (0..<3).map { k in
//                             BadAccessTestInputValue(
//                                 coordinate: UUID(),
//                                 payload: "data_\(depth)_\(i)_\(j)_\(k)"
//                             )
//                         },
//                         children: nil
//                     )
//                 }
//
//                 return BadAccessTestLayerData(
//                     id: "layer_\(depth)_\(i)",
//                     inputs: inputs,
//                     children: makeNestedLayers(depth: depth - 1, breadth: breadth)
//                 )
//             }
//         }
//
//         // Test with increasing complexity
//         let testData = makeNestedLayers(depth: 10, breadth: 5)
//
//         var nodesDict: [UUID: BadAccessTestNodeEntity] = [:]
//         var connections: [String: [UUID]] = [:]
//
//         // Run with Address Sanitizer to catch corruption
//         try createNodes(
//             layers: testData,
//             parentId: nil,
//             nodesDict: &nodesDict,
//             connections: &connections
//         )
//
//         print("✅ Created \(nodesDict.count) nodes successfully")
//     }
    
}

// Mimic your actual types
struct BadAccessTestNodeEntity {
    let id: UUID
    var data: String
    var nested: [BadAccessTestNestedData]
}

struct BadAccessTestNestedData {
    let values: [BadAccessTestInputValue]
    let children: [BadAccessTestLayerData]?
}

struct BadAccessTestInputValue {
    let coordinate: UUID
    let payload: String
}

struct BadAccessTestLayerData {
    let id: String
    let inputs: [BadAccessTestNestedData]
    let children: [BadAccessTestLayerData]?
}

// Mimic your updateWithEventData as a mutating extension
extension Dictionary where Key == UUID, Value == BadAccessTestNodeEntity {
    mutating func updateNode(
        id: UUID,
        value: String,
        otherDict: inout [String: [UUID]]
    ) throws {
        // Read from dictionary (gets pointer to storage)
        guard var node = self[id] else { return }

        // Modify node
        node.data = value

        // Write back (might trigger reallocation if at capacity)
        self[id] = node

        // Also mutate other dictionary
        otherDict[value] = [id]
    }
}
