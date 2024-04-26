//
//  ManualCommandView.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 4/4/2024.
//

import SwiftUI

struct ManualCommandView: View {
    
    @State var shellCommandText: String = ""
    @State var adbCommandText: String = ""
    
    var body: some View {
        VStack {
            TextField("Shell Command", text: $shellCommandText)
            Button(
                action: {
                    Task {
                        let output = try! await Shell.command(argsString: shellCommandText)
                        print(output)
                    }
                },
                label: {
                    Text("Run Command")
                }
            )
            
            Spacer().frame(height: 40)
            
            TextField("ADB Command", text: $adbCommandText)
            Button(
                action: {
                    Task {
                        try? await ADB.command(args: adbCommandText)
                    }
                },
                label: {
                    Text("Run Command")
                }
            )
            
            Spacer().frame(height: 40)
            
            Button(
                action: {
                    Task {
                        let path = URL(string: "/Users/Mark/Downloads/Crash%20Nitro%20Karto%20(USA).iso")!
                        print("Path \(path)")
                        let output = FileManager.default.fileExists(atPath: path.path(percentEncoded: false))
                        print("Output \(output)")
                    }
                },
                label: {
                    Text("Special Event")
                }
            )
        }
    }
}
