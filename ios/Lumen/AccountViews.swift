import AuthenticationServices
import SwiftUI

enum LegalDocument: String, Identifiable {
    case privacy
    case terms

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacy: return "Privacy draft"
        case .terms: return "Terms draft"
        }
    }

    var resource: String {
        switch self {
        case .privacy: return "PrivacyPolicyDraft"
        case .terms: return "TermsDraft"
        }
    }

    var configuredURL: URL? {
        switch self {
        case .privacy: return AppStoreConfig.openableHTTPS(AppStoreConfig.privacyURL)
        case .terms: return AppStoreConfig.openableHTTPS(AppStoreConfig.termsURL)
        }
    }
}

struct AccountSheet: View {
    @ObservedObject var session: LumenSession
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    @State private var resultMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(session.signedIn ? "Signed in\(session.displayName.isEmpty ? "" : " as \(session.displayName)")" : "Not signed in")
                        .font(.headline)
                    Text("Campaign, skirmish, daily, and local settings work without an account. An account is only for cloud save, the public daily leaderboard, and ranked play.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if !session.signedIn {
                        SignInWithAppleButton(.signIn) { request in
                            session.prepareAppleRequest(request)
                        } onCompletion: { result in
                            session.completeApple(result, purpose: "signIn")
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .accessibilityLabel("Sign in with Apple")

                        Button("Sign in with Google") {
                            dismiss()
                            session.startGoogleAfterSheet()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        Text("Google uses the existing Firebase web flow inside the game. It is not a native Google Sign-In SDK and has not been verified in this WebView. If it cannot complete, no account is created.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Sign out") { session.signOut() }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity, minHeight: 44)
                        Button("Delete account", role: .destructive) { confirmDelete = true }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .accessibilityIdentifier("deleteAccountButton")
                        Text("Deletion removes the sign-in and attempts to remove this account’s cloud save, rating, daily scores, and queue ticket. It asks Apple or Google to revoke this app’s token. The campaign stored on this device stays. It does not succeed until Firebase rules and the Apple provider are configured. A failure message means the account was not fully deleted.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button("Privacy draft") { session.legalDocument = .privacy }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    Button("Terms draft") { session.legalDocument = .terms }
                        .frame(maxWidth: .infinity, minHeight: 44)

                    if let support = AppStoreConfig.openableHTTPS(AppStoreConfig.supportURL) {
                        Link("Support", destination: support)
                    } else {
                        Text("Support contact is not configured. No address or email is published from this build.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if !AppStoreConfig.unresolved().isEmpty {
                        Text("Unresolved before any App Store upload:")
                            .font(.subheadline.bold())
                        ForEach(AppStoreConfig.unresolved(), id: \.self) { issue in
                            Text(issue).font(.footnote)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .confirmationDialog("Delete this LUMEN account?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete account", role: .destructive) {
                    Task {
                        resultMessage = await session.deleteAccount()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone. On-device campaign progress is kept. Cloud rows and the sign-in are removed only if every server step succeeds.")
            }
            .alert("Account", isPresented: Binding(
                get: { resultMessage != nil },
                set: { if !$0 { resultMessage = nil } }
            )) {
                Button("OK", role: .cancel) { resultMessage = nil }
            } message: {
                Text(resultMessage ?? "")
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct LegalDraftView: View {
    let document: LegalDocument
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("DRAFT. Not a published policy. Not legal advice. Do not link this build’s placeholder URL from App Store Connect.")
                        .font(.subheadline.bold())
                    Text(loadBody())
                        .font(.body)
                        .textSelection(.enabled)
                    if let url = document.configuredURL {
                        Link("Open configured URL", destination: url)
                    } else {
                        Text("The public URL is still a placeholder, so this build does not open it.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
                .frame(maxWidth: 680, alignment: .leading)
            }
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func loadBody() -> String {
        guard let url = Bundle.main.url(forResource: document.resource, withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return "The draft text is missing from this build. Nothing was loaded from the network."
        }
        return text
    }
}
