// Copyright 2023 Yi Xie
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
import Combine

protocol PublishedWrapper: AnyObject {
    var objectWillChange: ObservableObjectPublisher? { get set }
    func reset()
}

@propertyWrapper
class AutoStored<T> : PublishedWrapper {
    weak var objectWillChange: ObservableObjectPublisher?
    
    private let key: String
    private let defaultValue: T
    private var value: T
    var wrappedValue: T {
        get { value }
        set {
            value = newValue
            UserDefaults.standard.set(value, forKey: key)
            objectWillChange?.send()
        }
    }
    init(wrappedValue: T, _ key: String) {
        self.key = key
        self.defaultValue = wrappedValue
        if let storedValue = UserDefaults.standard.object(forKey: key) as? T {
            value = storedValue
        } else {
            value = wrappedValue
        }
    }
    func reset() {
        wrappedValue = defaultValue
    }
}
