import AuthenticationServices
import CryptoKit
import SwiftUI
import WebKit

@MainActor
final class LumenSession: ObservableObject {
    @Published var showChrome = true
    @Published var accountOpen = false
    @Published var signedIn = false
    @Published var displayName = ""
    @Published var providers: [String] = []
    @Published var legalDocument: LegalDocument?
    weak var bridge: GameBridge?

    fileprivate var rawNonce: String?
    fileprivate var applePurpose = "signIn"

    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Nonce.random()
        rawNonce = nonce
        applePurpose = "signIn"
        request.requestedScopes = [.fullName, .email]
        request.nonce = Nonce.sha256(nonce)
    }

    func completeApple(_ result: Result<ASAuthorization, Error>, purpose: String) {
        switch result {
        case .failure(let error):
            bridge?.deliver(ok: false, error: appleError(error), purpose: purpose)
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                bridge?.deliver(ok: false, error: "Apple did not return a credential. Nothing was signed in.", purpose: purpose)
                return
            }
            bridge?.deliverCredential(credential, nonce: rawNonce, purpose: purpose)
            rawNonce = nil
        }
    }

    func beginAppleFromPage(purpose: String) {
        applePurpose = purpose
        let nonce = Nonce.random()
        rawNonce = nonce
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Nonce.sha256(nonce)
        guard let bridge else { return }
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = bridge
        controller.presentationContextProvider = bridge
        controller.performRequests()
    }

    func startGoogleAfterSheet() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            bridge?.startGoogle()
        }
    }

    func signOut() {
        bridge?.run("window.__lumenSignOut&&window.__lumenSignOut()")
    }

    func deleteAccount() async -> String {
        guard let bridge else { return "The game is not loaded. Nothing was deleted." }
        return await bridge.deleteAccount()
    }

    fileprivate func appleError(_ error: Error) -> String {
        let ns = error as NSError
        if ns.domain == ASAuthorizationError.errorDomain && ns.code == ASAuthorizationError.canceled.rawValue {
            return "Sign in with Apple was cancelled."
        }
        return "Sign in with Apple failed. Nothing was signed in."
    }
}

final class GameBridge: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    weak var session: LumenSession?
    weak var container: GameContainer?
    private var popup: WKWebView?
    private weak var gameWebView: WKWebView?

    func attach(webView: WKWebView, container: GameContainer) {
        gameWebView = webView
        self.container = container
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "lumenNative",
              let body = message.body as? [String: Any],
              let action = body["action"] as? String
        else { return }
        switch action {
        case "signInWithApple":
            DispatchQueue.main.async { [weak self] in self?.session?.beginAppleFromPage(purpose: "signIn") }
        case "appleAuthorizationCode":
            DispatchQueue.main.async { [weak self] in self?.session?.beginAppleFromPage(purpose: "revoke") }
        case "authState":
            let signedIn = body["signedIn"] as? Bool ?? false
            let name = body["name"] as? String ?? ""
            let providers = body["providers"] as? [String] ?? []
            Task { @MainActor in
                session?.signedIn = signedIn
                session?.displayName = String(name.prefix(80))
                session?.providers = providers
            }
        case "shell":
            let mode = body["mode"] as? String ?? "menu"
            Task { @MainActor in
                session?.showChrome = mode != "play"
            }
        default:
            break
        }
    }

    func startGoogle() {
        run("window.__lumenStartGoogle&&window.__lumenStartGoogle()")
    }

    func deleteAccount() async -> String {
        guard let webView = gameWebView else { return "The game is not loaded. Nothing was deleted." }
        do {
            let value = try await webView.evaluateJavaScript("window.__lumenDeleteAccount&&window.__lumenDeleteAccount(true)")
            if let text = value as? String, !text.isEmpty { return text }
            return "Deletion did not return a result. Do not assume the account was deleted."
        } catch {
            return "Deletion failed before it could finish. Do not assume the account was deleted."
        }
    }

    func run(_ script: String) {
        gameWebView?.evaluateJavaScript(script, completionHandler: nil)
    }

    func deliverCredential(_ credential: ASAuthorizationAppleIDCredential, nonce: String?, purpose: String) {
        guard let nonce, !nonce.isEmpty,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8),
              let codeData = credential.authorizationCode,
              let code = String(data: codeData, encoding: .utf8)
        else {
            deliver(ok: false, error: "Apple did not return the token this app needs. Nothing was signed in and no token was revoked.", purpose: purpose)
            return
        }
        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        deliver(ok: true, error: nil, purpose: purpose, idToken: idToken, nonce: nonce, authorizationCode: code, fullName: name)
    }

    func deliver(ok: Bool, error: String?, purpose: String, idToken: String? = nil, nonce: String? = nil, authorizationCode: String? = nil, fullName: String? = nil) {
        var payload: [String: Any] = ["ok": ok, "purpose": purpose]
        if let error { payload["error"] = error }
        if let idToken { payload["idToken"] = idToken }
        if let nonce { payload["nonce"] = nonce }
        if let authorizationCode { payload["authorizationCode"] = authorizationCode }
        if let fullName, !fullName.isEmpty { payload["fullName"] = fullName }
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        let b64 = data.base64EncodedString()
        guard b64.allSatisfy({ character in
            character.isLetter || character.isNumber || character == "+" || character == "/" || character == "="
        }) else { return }
        run("window.__lumenNativeDeliver('\(b64)')")
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            session?.completeApple(.success(authorization), purpose: session?.applePurpose ?? "signIn")
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            let purpose = session?.applePurpose ?? "signIn"
            session?.completeApple(.failure(error), purpose: purpose)
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        container?.window ?? ASPresentationAnchor()
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        if webView === gameWebView {
            decisionHandler(BundleSchemeHandler.isGameURL(url) ? .allow : .cancel)
            return
        }
        if url.absoluteString == "about:blank" || AuthURLAllowlist.contains(url) {
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard webView === gameWebView else { return nil }
        configuration.userContentController.removeScriptMessageHandler(forName: "lumenNative")
        configuration.userContentController.removeAllUserScripts()
        let target = navigationAction.request.url
        if let target, target.absoluteString != "about:blank", !AuthURLAllowlist.contains(target) {
            return nil
        }
        let popupView = WKWebView(frame: .zero, configuration: configuration)
        popupView.navigationDelegate = self
        popupView.uiDelegate = self
        popup = popupView
        container?.showPopup(popupView) { [weak self] in
            self?.closePopup()
        }
        return popupView
    }

    func webViewDidClose(_ webView: WKWebView) {
        if webView === popup { closePopup() }
    }

    private func closePopup() {
        popup?.stopLoading()
        container?.hidePopup()
        popup = nil
    }
}

struct GameWebView: UIViewRepresentable {
    @ObservedObject var session: LumenSession

    func makeCoordinator() -> GameBridge {
        let bridge = GameBridge()
        bridge.session = session
        DispatchQueue.main.async { session.bridge = bridge }
        return bridge
    }

    func makeUIView(context: Context) -> GameContainer {
        let container = GameContainer()
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(BundleSchemeHandler(), forURLScheme: "lumen-local")
        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(source: Self.bootstrap, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        controller.add(context.coordinator, name: "lumenNative")
        configuration.userContentController = controller
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = true
        webView.backgroundColor = UIColor(red: 3 / 255, green: 4 / 255, blue: 11 / 255, alpha: 1)
        if #available(iOS 16.4, *) {
            #if DEBUG
            webView.isInspectable = true
            #endif
        }
        container.install(webView)
        context.coordinator.attach(webView: webView, container: container)
        if let url = URL(string: "lumen-local://app/index.html") {
            webView.load(URLRequest(url: url))
        }
        return container
    }

    func updateUIView(_ uiView: GameContainer, context: Context) {
        context.coordinator.session = session
        session.bridge = context.coordinator
    }

    private static let bootstrap = """
    window.__LUMEN_IOS_APP=true;
    window.__lumenNativeQueue=[];
    window.__lumenNativeDeliver=function(b64){
      if(typeof window.__lumenOnNative==='function') window.__lumenOnNative(b64);
      else window.__lumenNativeQueue.push(b64);
    };
    """
}

final class GameContainer: UIView {
    private let popupHost = UIView()
    private let cancel = UIButton(type: .system)
    private var onCancel: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 3 / 255, green: 4 / 255, blue: 11 / 255, alpha: 1)
        popupHost.isHidden = true
        popupHost.backgroundColor = .black
        cancel.setTitle("Cancel sign-in", for: .normal)
        cancel.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        cancel.backgroundColor = UIColor(white: 0.12, alpha: 1)
        cancel.setTitleColor(.white, for: .normal)
        cancel.layer.cornerRadius = 10
        cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        addSubview(popupHost)
        popupHost.addSubview(cancel)
    }

    required init?(coder: NSCoder) { nil }

    func install(_ webView: WKWebView) {
        webView.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(webView, at: 0)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func showPopup(_ webView: WKWebView, onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
        popupHost.isHidden = false
        bringSubviewToFront(popupHost)
        webView.translatesAutoresizingMaskIntoConstraints = true
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        popupHost.addSubview(webView)
        setNeedsLayout()
    }

    func hidePopup() {
        popupHost.subviews.filter { $0 !== cancel }.forEach { $0.removeFromSuperview() }
        popupHost.isHidden = true
        onCancel = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        popupHost.frame = bounds
        let top = safeAreaInsets.top + 8
        cancel.frame = CGRect(x: 16, y: top, width: max(0, bounds.width - 32), height: 44)
        let contentTop = cancel.frame.maxY + 8
        for view in popupHost.subviews where view !== cancel {
            view.frame = CGRect(x: 0, y: contentTop, width: bounds.width, height: max(0, bounds.height - contentTop))
        }
    }

    @objc private func cancelTapped() { onCancel?() }
}

enum AuthURLAllowlist {
    private static let hosts: Set<String> = [
        "accounts.google.com",
        "appleid.apple.com",
        "appleid.cdn-apple.com",
        "idmsa.apple.com",
        "lumon-4397e.firebaseapp.com",
        "lumon-4397e.web.app"
    ]
    private static let suffixes = [
        ".google.com",
        ".googleapis.com",
        ".gstatic.com",
        ".googleusercontent.com",
        ".firebaseapp.com",
        ".web.app"
    ]

    static func contains(_ url: URL) -> Bool {
        guard url.scheme == "https", let host = url.host?.lowercased() else { return false }
        if hosts.contains(host) { return true }
        return suffixes.contains { host.hasSuffix($0) }
    }
}

final class BundleSchemeHandler: NSObject, WKURLSchemeHandler {
    private let lock = NSLock()
    private var stopped = Set<ObjectIdentifier>()

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let id = ObjectIdentifier(urlSchemeTask)
        guard let url = urlSchemeTask.request.url, let file = Self.resolve(url) else {
            finish(id, task: urlSchemeTask) { $0.didFailWithError(URLError(.badURL)) }
            return
        }
        do {
            let data = try Data(contentsOf: file)
            guard let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: [
                    "Content-Type": Self.mime(file),
                    "Content-Length": String(data.count),
                    "Cache-Control": "no-store"
                ]
            ) else {
                finish(id, task: urlSchemeTask) { $0.didFailWithError(URLError(.badServerResponse)) }
                return
            }
            finish(id, task: urlSchemeTask) {
                $0.didReceive(response)
                $0.didReceive(data)
                $0.didFinish()
            }
        } catch {
            finish(id, task: urlSchemeTask) { $0.didFailWithError(error) }
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        lock.lock()
        stopped.insert(ObjectIdentifier(urlSchemeTask))
        lock.unlock()
    }

    private func finish(_ id: ObjectIdentifier, task: WKURLSchemeTask, _ body: (WKURLSchemeTask) -> Void) {
        lock.lock()
        let dead = stopped.contains(id)
        if !dead { stopped.remove(id) }
        lock.unlock()
        if !dead { body(task) }
    }

    static func isGameURL(_ url: URL) -> Bool {
        resolve(url) != nil
    }

    static func resolve(_ url: URL) -> URL? {
        guard url.scheme == "lumen-local", url.host == "app" else { return nil }
        let raw = url.path
        if raw.contains("..") || raw.contains("//") { return nil }
        let relative = raw.hasPrefix("/") ? String(raw.dropFirst()) : raw
        let allowed = relative == "index.html"
            || relative == "sw.js"
            || relative == "manifest.webmanifest"
            || relative == "icon-192.png"
            || relative == "icon-512.png"
            || relative == "icon-maskable-512.png"
            || relative == "apple-touch-icon.png"
            || relative == "vendor/peerjs.min.js"
            || (relative.hasPrefix("vendor/firebase/") && relative.hasSuffix(".js") && !relative.contains(".."))
        guard allowed, let root = Bundle.main.resourceURL else { return nil }
        let destination = root.appendingPathComponent(relative).standardizedFileURL
        let rootPath = root.standardizedFileURL.path
        guard destination.path.hasPrefix(rootPath + "/") else { return nil }
        guard FileManager.default.fileExists(atPath: destination.path) else { return nil }
        return destination
    }

    private static func mime(_ url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "html": return "text/html; charset=utf-8"
        case "js": return "text/javascript; charset=utf-8"
        case "png": return "image/png"
        case "webmanifest": return "application/manifest+json"
        default: return "application/octet-stream"
        }
    }
}

enum Nonce {
    static func random(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var output = ""
        output.reserveCapacity(length)
        while output.count < length {
            var byte: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &byte)
            if status != errSecSuccess { continue }
            if byte < charset.count { output.append(charset[Int(byte)]) }
        }
        return output
    }

    static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
