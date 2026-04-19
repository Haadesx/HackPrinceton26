import SwiftUI

struct RootNavigationView: View {
    @State private var launched = true

    var body: some View {
        if launched {
            MainTabView()
        } else {
            HomeView(onLaunch: { launched = true })
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            CommandCenterView()
                .tabItem {
                    Label("Mission", systemImage: "chart.bar.xaxis")
                }

            StudyLabView()
                .tabItem {
                    Label("Study", systemImage: "graduationcap")
                }

            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }

            KnowledgeGraphView()
                .tabItem {
                    Label("Graph", systemImage: "point.3.connected.trianglepath.dotted")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
        .tint(.scarlet)
        .background(Color.bgBase)
        .toolbarBackground(Color.bgBase, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
