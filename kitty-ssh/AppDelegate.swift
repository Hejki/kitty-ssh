// MIT License
//
// Copyright (c) 2020 Hejki
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Cocoa
import SwiftUI

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    private static let kittyAppPath = "/Applications/kitty.app/Contents/MacOS/kitty"
    private static let kittyBundleIdentifier = "net.kovidgoyal.kitty"
    private static var kittySocketPath = "/tmp/kitty-ssh"
    private var launchType = "tab"

    func application(_ application: NSApplication, open urls: [URL]) {
        checkStatus()

        for url in urls {
            openConnection(to: url)
        }

        application.terminate(self)
    }

    private func checkStatus() {
        switch getStatus() {
        case .notRunning:
            runKitty()
            launchType = "overlay"
        case .noWindowOpen:
            alertAndTryAgain()
        case .listening:
            break
        }

        for _ in 0..<100 where !FileManager.default.fileExists(atPath: Self.kittySocketPath) {
            usleep(100000)
        }
    }

    private func runKitty() {
        let process = Process()

        process.launchPath = Self.kittyAppPath
        process.arguments = [
            "-o", "allow_remote_control=yes",
            "--listen-on", "unix:\(Self.kittySocketPath)"
        ]
        process.launch()
    }

    private func openConnection(to url: URL) {
        let process = createProcess(arguments: [
            "launch",
            "--type", launchType,
            "ssh", url.host ?? ""
        ])

        process.launch()
        process.waitUntilExit()

        launchType = "tab"
    }

    private func alertAndTryAgain() {
        let alert = NSAlert()

        alert.messageText = "No kitty session"
        alert.informativeText = "Remote controll kitty running but without open window. Please open its window or quit it completely."
        alert.alertStyle = .warning

        alert.addButton(withTitle: "Try it again")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            checkStatus()
        }
    }

    private func getStatus() -> KittyStatus {
        let app = NSWorkspace.shared.runningApplications.first {$0.bundleIdentifier == Self.kittyBundleIdentifier }

        if (app != nil) {
            Self.kittySocketPath += "-" + String((app?.processIdentifier.description)!)
        }

        if !FileManager.default.fileExists(atPath: Self.kittySocketPath) {
            return .notRunning
        }

        let outputPipe = Pipe()
        let process = createProcess(arguments: ["ls"])

        process.standardOutput = outputPipe
        process.launch()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            let lsResult = String(data: outputPipe.fileHandleForReading.availableData, encoding: .utf8)

            if lsResult == "[]\n" {
                return .noWindowOpen
            }
            return .listening
        }
        return .notRunning
    }

    private func openWindow() {
        let process = createProcess(arguments: ["new-window"])

        process.launch()
        process.waitUntilExit()
    }

    private func createProcess(arguments: [String]) -> Process {
        let process = Process()

        process.launchPath = Self.kittyAppPath
        process.arguments = ["@", "--to", "unix:\(Self.kittySocketPath)"] + arguments
        return process
    }
}

private enum KittyStatus {
    case notRunning
    case noWindowOpen
    case listening
}
