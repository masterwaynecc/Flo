import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingFlowView()
            }
        }
        .tint(DawtColor.rose)
        .sheet(isPresented: $appState.showingDayLog) {
            DayLogView(date: appState.dayLogDate)
                .environmentObject(appState)
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
                .tag(AppTab.today)

            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
                .tag(AppTab.calendar)

            InsightsView()
                .tabItem { Label("Insights", systemImage: "sparkles") }
                .tag(AppTab.insights)

            SettingsView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(AppTab.settings)
        }
    }
}
