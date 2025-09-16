//
//  AudioAnalyzerVisualizer_NEWApp.swift
//  AudioAnalyzerVisualizer NEW
//
//  Created by Максим Дюг on 16.09.2025.
//

import SwiftUI

@main
struct AudioAnalyzerVisualizer_NEWApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if model.docs.isEmpty {
                    StartView()
                } else if model.docs.contains(where: { $0.isAnalyzing || ($0.result == nil && $0.errorMessage == nil) }) {
                    LoadingView()
                } else {
                    ContentView()
                }
            }
            .animation(.easeInOut(duration: 0.2), value: model.docs.map { ($0.id, $0.isAnalyzing, $0.result?.duration ?? 0) }.description)
            .transition(.opacity)
            .environmentObject(model)
        }
        .defaultSize(width: 1100, height: 820)
    }

    var playPauseNotification: Notification.Name { Notification.Name("AAVPlayPauseToggle") }

    var commands: some Commands {
        CommandMenu("Відтворення") {
            Button("Відтворити/Пауза") {
                NotificationCenter.default.post(name: playPauseNotification, object: nil)
            }
            .keyboardShortcut(.space, modifiers: [])
        }
    }
}
