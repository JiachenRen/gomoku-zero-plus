//
//  Minimax.swift
//  Gomoku Zero
//
//  Created by Jiachen Ren on 10/20/18.
//  Copyright © 2018 Jiachen Ren. All rights reserved.
//

import Foundation

//    function minimax(node, depth, maximizingPlayer)
//    02     if depth = 0 or node is a terminal node
//    03         return the heuristic value of node
//
//    04     if maximizingPlayer
//    05         bestValue := −∞
//    06         for each child of node
//    07             v := minimax(child, depth − 1, FALSE)
//    08             bestValue := max(bestValue, v)
//    09         return bestValue
//
//    10     else    (* minimizing player *)
//    11         bestValue := +∞
//    12         for each child of node
//    13             v := minimax(child, depth − 1, TRUE)
//    14             bestValue := min(bestValue, v)
//    15         return bestValue

class MinimaxCortex: BasicCortex, TimeLimitedSearchProtocol {
    var depth: Int
    var breadth: Int
    var searchCancelledInProgress = false
    var alphaCut = 0
    var betaCut = 0
    var cumCutDepth = 0
    var verbose = false
    
    init(_ delegate: CortexDelegate, depth: Int, breadth: Int) {
        self.depth = depth
        self.breadth = breadth
        super.init(delegate)
    }
    
    override func getMove() -> Move {
        let move = minimax(depth, identity, Int.min, Int.max)
        if verbose {
            let avgCutDepth = Double(cumCutDepth) / Double(alphaCut + betaCut)
            print("alpha cut: \(alphaCut)\t beta cut: \(betaCut)\t avg. cut depth: \(avgCutDepth))")
            print("recognized sequences: \(evaluator.seqHashMap.count)")
            print("calc. duration (s): \(delegate.duration)")
        }
        
        if let mv = move {
            return mv
        }
        // If the computer is to lose for sure, get a basic move.
        print("generating basic move...")
        return BasicCortex(delegate).getMove()
    }
    
    func isTerminal(score: Int) -> Bool {
        return score >= Evaluator.win || score <= -Evaluator.win
    }
    
    /**
     In plain minimax, the heuristic value of leaf node is the horizon; Because of this,
     the algorithm is short sighted and is unable to foresee drastic changes beyond the horizon.
     This can lead to imperfect decision making.
     */
    func beyondHorizon(_ score: Int, _ alpha: Int, _ beta: Int, _ player: Piece) -> Int {
        return score
    }
    
    /**
     - Returns: a list of candidates [Move] arranged in order of greatest threat potential to
                least threat potential. For standard minimax, it uses the basic method built
                into the cortex.
     */
    func getCandidates() -> [Move] {
        return Array(getSortedMoves().prefix(breadth))
    }
    
    /**
     Plain old minimax algorithm with alpha beta pruning.
     Empty implementation for beyondHorizon(_:) - does not attempt to address horizon effect.
     
     - Returns: the best move for the current player in the given delegate.
     */
    func minimax(_ depth: Int, _ player: Piece,  _ alpha: Int, _ beta: Int) -> Move? {
        var alpha = alpha, beta = beta, depth = depth // Make alpha beta mutable
        var score = getHeuristicValue()
        if delegate.strategy.randomizedSelection {
            score += Int.random(in: 0..<10)
        }
        
        if isTerminal(score: score) {
            // Terminal state has reached
            return Move(co: (0,0), score: score)
        } else if depth == 0 {
            var move = Move(co: (0,0), score: score)
            move.score = beyondHorizon(score, alpha, beta, player)
            return move
        }
        
        if player == identity {
            let candidates = getCandidates()
            if candidates.count == 0 {
                return nil
            }
            var bestMove = candidates.randomElement()!
            bestMove.score = Int.min
            for move in candidates {
                delegate.put(at: move.co)
                let score = minimax(depth - 1, player.next(),alpha, beta)?.score
                delegate.revert()
                if let s = score {
                    if s > bestMove.score {
                        bestMove = move
                        bestMove.score = s
                        if s >= Evaluator.win {
                            return bestMove
                        }
                        
                        alpha = max(alpha, s)
                        if beta <= alpha {
                            bestMove.score = alpha
                            cumCutDepth += depth
                            alphaCut += 1
                            return bestMove
                        }
                    }
                }
                    
                // If time's up, return the current best move.
                if delegate.timeout {
                    searchCancelledInProgress = true
                    return bestMove
                }
            }
            
            // No defense measurements can dodge enemy's attack. Losing is inevitable. Select a random defensive move.
            if bestMove.score < -Evaluator.win {
                var mv = getSortedMoves().sorted{$0.score > $1.score}[0]
                mv.score = bestMove.score
                return mv
            }
            
            return bestMove
        } else {
            let candidates = getCandidates()
            if candidates.count == 0 {
                return nil
            }
            var bestMove = candidates.randomElement()!
            bestMove.score = Int.max
            for move in candidates {
                delegate.put(at: move.co)
                let score = minimax(depth - 1, player.next(), alpha, beta)?.score
                delegate.revert()
                if let s = score {
                    if s < bestMove.score {
                        bestMove = move
                        bestMove.score = s
                        if s <= -Evaluator.win {
                            return bestMove
                        }
                        
                        beta = min(beta, s)
                        if beta <= alpha {
                            bestMove.score = beta
                            cumCutDepth += depth
                            betaCut += 1
                            return bestMove
                        }
                    }
                }
                if delegate.timeout {
                    searchCancelledInProgress = true
                    return bestMove
                }
            }
            return bestMove
        }
    }
    
    override var description: String {
        return "Minimax(depth: \(depth), breadth: \(breadth))"
    }
}
