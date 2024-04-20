//
//  ADBService.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 13/4/2024.
//

import Foundation
import Combine

protocol ADBService {
    
    var connectedDevices: any Publisher<[Device], Error> { get }
    var state: any Publisher<ADBServiceState, Never> { get }
    
    func startServer()
    func killServer() async throws
    func list(serial: String, path: URL) async throws -> ListCommandResponse
    func pull(serial: String, remotePath: URL) -> any Publisher<PullProgressResponse, Error>
    func push(serial: String, localPath: URL, remotePath: URL) async throws
    func delete(serial: String, remotePath: URL) async throws
    func getBluetoothName(serial: String) async throws -> String
    func devices() async throws -> DevicesResponse
}

enum ADBServiceState {
    case notRunning
    case settingUp
    case running
    case error
}