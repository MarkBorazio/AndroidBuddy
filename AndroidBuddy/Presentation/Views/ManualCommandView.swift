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
                    let output = try! shellCommand(args: shellCommandText)
                    print(output)
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
        }
    }
    
    @discardableResult
    private func shellCommand(args: String) throws -> String {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", args]
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.standardInput = nil

        try task.run()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)!
        
        return output
    }
}
