//
//  LLTranslationTaskBridge.swift
//  LearnLanguage
//
//  Translation API 桥接层
//  系统 Translation 框架依赖 SwiftUI 的 .translationTask modifier，
//  这里用一个隐藏的 NSHostingView 做最小化桥接，其余代码全部保持 AppKit。
//

import SwiftUI
import Translation

@available(macOS 15.0, *)
final class LLTranslationTaskBridge {

    static let shared = LLTranslationTaskBridge()

    private struct Request {
        let window: NSWindow
        let completion: (Result<String, Error>) -> Void
    }
    private var requests: [UUID: Request] = [:]

    private init() {}

    // MARK: - Public

    @discardableResult
    func performTranslation(
        _ text: String,
        source: Locale.Language,
        target: Locale.Language,
        completion: @escaping (Result<String, Error>) -> Void
    ) -> UUID {
        let id = UUID()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            let bridgeView = LLTranslationBridgeView(
                text: text,
                source: source,
                target: target
            ) { [weak self] result in
                self?.finish(id, result: result)
            }

            // 1x1 隐藏窗口，仅用于承载 SwiftUI translationTask
            // 将窗口水平居中对齐状态栏弹出 Panel，使系统词库下载提示出现在 Panel 正上方
            let panelFrame = LLStatusBarPopoverPanel.shared.frame
            let centerX = panelFrame.midX
            let originY = panelFrame.maxY - 8
            let window = NSWindow(
                contentRect: NSRect(x: centerX, y: originY, width: 1, height: 1),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.alphaValue = 0
            window.level = .screenSaver
            window.contentView = NSHostingView(rootView: bridgeView)
            window.isReleasedWhenClosed = false
            self.requests[id] = Request(window: window, completion: completion)
            window.orderFront(nil)
        }
        return id
    }

    func cancel(_ id: UUID) {
        DispatchQueue.main.async { self.finish(id, result: .failure(CancellationError())) }
    }

    private func finish(_ id: UUID, result: Result<String, Error>) {
        guard let request = requests.removeValue(forKey: id) else { return }
        request.window.contentView = nil
        request.window.close()
        request.completion(result)
    }
}

// MARK: - Bridge SwiftUI View

@available(macOS 15.0, *)
private struct LLTranslationBridgeView: View {

    let text: String
    let source: Locale.Language
    let target: Locale.Language
    let completion: (Result<String, Error>) -> Void

    @State private var configuration: TranslationSession.Configuration?

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .translationTask(configuration) { session in
                do {
                    let response = try await session.translate(text)
                    DispatchQueue.main.async {
                        completion(.success(response.targetText))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
            .onAppear {
                configuration = TranslationSession.Configuration(
                    source: source,
                    target: target
                )
            }
    }
}
