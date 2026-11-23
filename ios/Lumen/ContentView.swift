import SwiftUI

struct ContentView: View {
    @StateObject private var session = LumenSession()

    var body: some View {
        Group {
            if AppStoreConfig.blocksLaunch {
                SubmissionBlockedView(issues: AppStoreConfig.unresolved())
            } else {
                playable
            }
        }
    }

    private var playable: some View {
        ZStack(alignment: .top) {
            GameWebView(session: session)
                .ignoresSafeArea()
            if session.showChrome {
                VStack(spacing: 6) {
                    if !AppStoreConfig.unresolved().isEmpty {
                        Text("Not submission-ready. Placeholders are still in the app configuration.")
                            .font(.caption)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.yellow, in: Capsule())
                    }
                    HStack {
                        Spacer()
                        Button("Account") { session.accountOpen = true }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(red: 0.27, green: 0.84, blue: 1))
                            .foregroundStyle(.black)
                            .accessibilityIdentifier("accountButton")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }
        }
        .sheet(isPresented: $session.accountOpen) {
            AccountSheet(session: session)
        }
        .sheet(item: $session.legalDocument) { document in
            LegalDraftView(document: document)
        }
    }
}

struct SubmissionBlockedView: View {
    let issues: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("This build must not be submitted")
                    .font(.title2.bold())
                Text("Release is blocked because App Store configuration still contains placeholders. The game is not opened from this screen. Replace the values in ios/Config/AppStore.xcconfig, then archive again on a Mac.")
                ForEach(issues, id: \.self) { issue in
                    Text("• \(issue)")
                }
                Text("This screen is not an App Review approval and does not mean the rest of the project is compliant.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: 560, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.012, green: 0.016, blue: 0.043))
    }
}
