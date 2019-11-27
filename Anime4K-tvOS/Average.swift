//
//  Average.swift
//  Anime4K-tvOS
//
//  Created by 谢宜 on 2019/11/27.
//  Copyright © 2019 xieyi. All rights reserved.
//

import Foundation

class Average {
    
    let count: Int
    var pointer: Int
    var numbers: [Double]
    
    init(count: Int) {
        self.count = count
        numbers = .init(repeating: 0, count: count)
        pointer = -1
    }
    
    func update(_ number: Double) -> Double {
        pointer = (pointer + 1) % count
        numbers[pointer] = number
        var total: Double = 0
        for number in numbers {
            total += number
        }
        return total / Double(count)
    }
    
}
