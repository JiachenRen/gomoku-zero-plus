//
//  ZobristBoard.swift
//  Gomoku Zero
//
//  Created by Jiachen Ren on 10/8/18.
//  Copyright © 2018 Jiachen Ren. All rights reserved.
//

import Foundation

typealias ZobristTable = [[[Int]]]

class Zobrist: Hashable {
    
    // This is for accomodating different board dimensions
    private static var tables = [Int: ZobristTable]()
    
    /// Hashed heuristic values of nodes
    static var heuristicHash = [Zobrist: Int]()
    
    /// A map that records scores for each coordinate for a specific game state.
    /// It is used to elimate re-computations when generating heuristic value of a node.
    static var scoreMap = [Zobrist: [[Int?]]]()
    
    /// Hashed ordered moves
    static var orderedMovesHash = [Zobrist: [Move]]()
    
    /// Slightly boosts performance at a neglegible risk of judging two diffenrent game states to be the same.
    static var strictEqualityCheck = false
    
    static let orderedMovesQueue = DispatchQueue(label: "orderedMovesQueue")
    static let heuristicQueue = DispatchQueue(label: "hueristicQueue")
    static let scoreMapQueue = DispatchQueue(label: "scoreMapQueue")
    
    let dim: Int
    var matrix = [[Piece]]()
    var hashValue = 0
    
    init(zobrist: Zobrist) {
        self.dim = zobrist.dim
        self.matrix = zobrist.matrix
        hashValue = zobrist.hashValue
    }
    
    init(matrix: [[Piece]]) {
        self.dim = matrix.count
        self.matrix = matrix
        
        if Zobrist.tables[dim] == nil {
            // Make a new table if a table of the new dimension does not exist
            let table = Zobrist.makeZobristTable(dim: dim)
            Zobrist.tables[dim] = table
        }
        hashValue = computeInitialHash()
    }
    
    /**
     Compute the initial hashValue by cross-referencing the pieces in the matrix and the shared table.
     - Note: when changes are made to the matrix, the hashValue is updated accordingly by a much more
             light-weight algorithm.
     */
    private func computeInitialHash() -> Int {
        var hash = 0
        for i in 0..<dim {
            for q in 0..<dim {
                let piece = matrix[i][q]
                switch piece {
                case .none: continue
                case .black: hash ^= Zobrist.tables[dim]![i][q][0]
                case .white: hash ^= Zobrist.tables[dim]![i][q][1]
                }
            }
        }
        return hash
    }
    
    /**
     Due to the nature of xor operation, putting and reverting a piece use the same operation
     */
    private func updateHashValue(at co: Coordinate, _ piece: Piece) {
        hashValue ^= Zobrist.tables[dim]![co.row][co.col][piece == .black ? 0 : 1]
    }
    
    func put(at co: Coordinate, _ piece: Piece) {
        matrix[co.row][co.col] = piece
        updateHashValue(at: co, piece)
    }
    
    func revert(at co: Coordinate) {
        let original = matrix[co.row][co.col]
        matrix[co.row][co.col] = .none
        updateHashValue(at: co, original)
    }
    
    static func == (lhs: Zobrist, rhs: Zobrist) -> Bool {
        if strictEqualityCheck {
            let dim = lhs.dim
            for i in 0..<dim {
                for q in 0..<dim where lhs.matrix[i][q] != rhs.matrix[i][q] {
                    return false
                }
            }
            return true
        }
        // Loads faster, but could be faulty!
        return lhs.hashValue == rhs.hashValue
    }
    
    func get(_ co: Coordinate) -> Piece {
        return matrix[co.row][co.col]
    }
    
    /**
     Generate a table filled with random
     */
    static func makeZobristTable(dim: Int) -> ZobristTable {
        var table = [[[Int]]]()
        for _ in 0..<dim {
            var col = [[Int]]()
            for _ in 0..<dim {
                var piece = [Int]()
                for _ in 0...1 {
                    let rand = Int.random(in: 0..<Int.max)
                    piece.append(rand)
                }
                col.append(piece)
            }
            table.append(col)
        }
        return table
    }
    
    enum Value {
        case orderedMoves(_ moves: [Move])
        case heuristic(_ score: Int)
        case scoreMap(_ map: [[Int?]])
    }
    
    /// Update the values for the current game state on their corresponding serial threads given the new value.
    func update(_ value: Value) {
        let copy = Zobrist(zobrist: self)
        Zobrist.update(copy, value)
    }
    
    static func update(_ key: Zobrist, _ value: Value) {
        switch value {
        case .orderedMoves(let moves):
            orderedMovesQueue.sync {
                orderedMovesHash[key] = moves
            }
        case .heuristic(let score):
            heuristicQueue.sync {
                heuristicHash[key] = score
            }
        case .scoreMap(let map):
            scoreMapQueue.sync {
                scoreMap[key] = map
            }
        }
    }
    
}

extension Zobrist: CustomStringConvertible {
    public var description: String {
        var str = ""
        matrix.forEach { row in
            row.forEach { col in
                switch col {
                case .none: str += "- "
                case .black: str += "* "
                case .white: str += "o "
                }
            }
            str += "\n"
        }
        return str
    }
}
