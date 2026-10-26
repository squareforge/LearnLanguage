//
//  LLSpeechService.swift
//  LearnLanguage
//

import AVFoundation

/// Main-thread speech service. Each utterance owns its completion callback.
final class LLSpeechService: NSObject {
    static let shared = LLSpeechService()
    private let synthesizer = AVSpeechSynthesizer()
    private var currentUtterance: AVSpeechUtterance?
    private var completion: ((Bool) -> Void)?
    private(set) var isSpeaking = false

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    @discardableResult
    func speak(_ text: String, language: String = "en-US", rate: Float = 0.5, completion: ((Bool) -> Void)? = nil) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = min(max(rate, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
        utterance.volume = LLSettingsStore.shared.settings.appAudioVolume
        currentUtterance = utterance
        self.completion = completion
        isSpeaking = true
        synthesizer.speak(utterance)
        return true
    }

    func stop() {
        let callback = completion
        completion = nil
        currentUtterance = nil
        isSpeaking = false
        synthesizer.stopSpeaking(at: .immediate)
        callback?(false)
    }

    private func finish(_ utterance: AVSpeechUtterance, success: Bool) {
        guard utterance === currentUtterance else { return }
        let callback = completion
        completion = nil
        currentUtterance = nil
        isSpeaking = false
        callback?(success)
    }
}

extension LLSpeechService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in self?.finish(utterance, success: true) }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in self?.finish(utterance, success: false) }
    }
}
