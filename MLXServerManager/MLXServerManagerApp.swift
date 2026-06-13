//
//  MLXServerManagerApp.swift
//  MLXServerManager
//
//  Created by yoinkun on 2026/06/11.
//

import SwiftUI

@main
struct MLXServerManagerApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup("MLX Server Manager", id: "main") {
            ContentView(viewModel: viewModel)
        }

        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
        } label: {
            Label(viewModel.menuBarTitle, systemImage: "server.rack")
        }
    }
}
