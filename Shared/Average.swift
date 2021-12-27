// Copyright 2021 Yi Xie
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
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
