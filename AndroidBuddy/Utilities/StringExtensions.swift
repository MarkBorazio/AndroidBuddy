//
//  StringExtensions.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 28/4/2024.
//

import Foundation

extension String {
    
    /**
    Removes and returns the prefix up until the specified element.
     
    # Example
    ```swift
    var myString = "This is my string"

    let firstPrefix = myString.poppingPrefix(upTo: "m")
    print(firstPrefix) // "This is "
    print(myString) // "my string"
            
    let secondPrefix = myString.poppingPrefix(upTo: "r")
    print(secondPrefix) // "my st"
    print(myString) // "ring"
    ```
     */
    mutating func poppingPrefix(upTo element: Element) -> String {
        guard let spaceIndex = firstIndex(of: element) else { return self }
        let prefix = String(prefix(upTo: spaceIndex))
        removeSubrange(startIndex..<spaceIndex)
        return prefix
    }
    
    
    /**
     Returns a new string made by removing from the beginning of the String characters contained in a given character set.
     
     ```swift
     print(CharacterSet.newlines.containsUnicodeScalars(of: "\n")) // true
     print(CharacterSet.whitespacesAndNewlines.containsUnicodeScalars(of: "\n")) // true
     print(CharacterSet.whitespaces.containsUnicodeScalars(of: "\n")) // false
     ```
     */
    func trimmingPrefixCharacters(in set: CharacterSet) -> String {
        String(trimmingPrefix(while: { char in
            char.unicodeScalars.allSatisfy { set.contains($0) }
        }))
    }
}