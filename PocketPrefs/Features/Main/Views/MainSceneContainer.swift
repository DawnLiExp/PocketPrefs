//
//  MainSceneContainer.swift
//  PocketPrefs
//
//  Root composition container for the main scene.
//

import SwiftUI

struct MainSceneContainer: View {
    @State private var coordinator: MainCoordinator
    @State private var mainViewModel: MainViewModel

    init() {
        let coordinator = MainCoordinator()
        _coordinator = State(initialValue: coordinator)
        _mainViewModel = State(initialValue: MainViewModel(coordinator: coordinator))
    }

    var body: some View {
        MainView()
            .environment(coordinator)
            .environment(mainViewModel)
    }
}

#Preview {
    MainSceneContainer()
        .frame(width: 900, height: 600)
}
