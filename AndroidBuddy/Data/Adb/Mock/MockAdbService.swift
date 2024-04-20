//
//  MockAdbService.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 13/4/2024.
//

import Foundation
import Combine

class MockAdbService: ADBService {
    
    var connectedDevices: any Publisher<[Device], Error>
    var state: any Publisher<ADBServiceState, Never>
    
    init(adbState: ADBServiceState, devices: [Device]) {
        connectedDevices = CurrentValueSubject(devices).eraseToAnyPublisher()
        state = CurrentValueSubject(adbState).eraseToAnyPublisher()
    }
    
    func startServer() {}
    
    func killServer() async throws {}
    
    func list(serial: String, path: URL) async throws -> ListCommandResponse {
        let response = getResponse(fileName: "MockListResponse")
        return ListCommandResponse(path: path, rawResponse: response)
    }
    
    func pull(serial: String, remotePath: URL) -> any Publisher<PullProgressResponse, Error> { Empty() }
    
    func push(serial: String, localPath: URL, remotePath: URL) async throws {}
    
    func delete(serial: String, remotePath: URL) async throws {}
    
    func getBluetoothName(serial: String) async throws -> String {
        "Mock Device Name"
    }
    
    func devices() async throws -> DevicesResponse {
        let response = getResponse(fileName: "MockDevicesResponse")
        return DevicesResponse(rawOutput: response)
    }
    
    private func getResponse(fileName: String) -> String {
        let url = Bundle.main.url(forResource: fileName, withExtension: nil)!
        let data = try! Data(contentsOf: url)
        return String(data: data, encoding: .utf8)!
    }
}
