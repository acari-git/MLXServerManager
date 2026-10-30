//
//  MLXServerManagerApp.swift
//  MLXServerManager
//
//  Created by yoinkun on 2026/06/11.
//

import SwiftUI

@main
struct MLXServerManagerApp: App {
    @NSApplicationDelegateAdaptor(ApplicationLifecycleDelegate.self) private var applicationDelegate
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup("MLX Server Manager", id: "main") {
            ContentView(viewModel: viewModel)
                .onAppear {
                    applicationDelegate.viewModel = viewModel
                }
        }
        .defaultSize(width: 1280, height: 820)
        .windowStyle(.hiddenTitleBar)
        .commands {
            AppCommands(viewModel: viewModel)
        }

        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
        } label: {
            Label(viewModel.menuBarTitle, systemImage: "server.rack")
        }
    }
}
