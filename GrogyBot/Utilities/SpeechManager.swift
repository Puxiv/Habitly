import Foundation
import Speech
import AVFoundation
import Observation

@MainActor
@Observable
final class SpeechManager: NSObject, AVSpeechSynthesizerDelegate {

    // MARK: - STT State
    var isListening = false
    var transcript = ""
    var errorMessage: String?

    var isAvailable: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    // MARK: - TTS State
    var isSpeaking = false
    /// ID of the message currently being spoken (for per-bubble UI)
    var speakingMessageId: UUID?

    // MARK: - Voice Chat Mode
    /// When true, silence auto-sends and TTS auto-restarts listening.
    var voiceChatMode = false

    /// Called when silence is detected with the final transcript.
    /// Used by voice chat mode to auto-send.
    var onSpeechFinished: ((String) -> Void)?

    /// Locale saved from the last `startListening` call so we can restart after TTS.
    private(set) var currentLocale: Locale?

    // MARK: - Private
    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?
    private let synthesizer = AVSpeechSynthesizer()

    /// Silence detection timer — fires after no new partial results.
    private var silenceTimer: Timer?
    private let silenceTimeout: TimeInterval = 1.5

    // MARK: - Init

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Authorization

    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                switch status {
                case .authorized:
                    self?.errorMessage = nil
                case .denied:
                    self?.errorMessage = "Speech recognition denied. Enable it in Settings."
                case .restricted:
                    self?.errorMessage = "Speech recognition is restricted on this device."
                case .notDetermined:
                    self?.errorMessage = nil
                @unknown default:
                    break
                }
            }
        }
    }

    // MARK: - STT  Start / Stop

    func startListening(locale: Locale) {
        // Stop any TTS first
        stopSpeaking()

        // Check authorization first
        guard isAvailable else {
            errorMessage = "Speech recognition not authorized. Enable it in Settings."
            return
        }

        // Cancel any ongoing task
        stopListeningQuietly()

        speechRecognizer = SFSpeechRecognizer(locale: locale)
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            let langId = locale.identifier.replacingOccurrences(of: "_", with: "-")
            errorMessage = "Speech recognizer not available for \(langId). Check Settings → General → Keyboard → Dictation Languages."
            return
        }

        currentLocale = locale
        transcript = ""
        errorMessage = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        self.recognitionRequest = request

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Could not configure audio session."
            return
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Guard against invalid format (sampleRate 0 on some devices)
        guard recordingFormat.sampleRate > 0 else {
            errorMessage = "Could not get a valid audio format."
            cleanupAudio()
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            errorMessage = "Could not start audio engine."
            cleanupAudio()
            return
        }

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self, self.isListening else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    // Reset silence timer on every new partial result
                    self.resetSilenceTimer()
                }
                if error != nil || (result?.isFinal ?? false) {
                    self.finishListening()
                }
            }
        }

        isListening = true
    }

    /// Stop listening and return the final transcript.
    @discardableResult
    func stopListening() -> String {
        let finalText = transcript
        finishListening()
        return finalText
    }

    // MARK: - Voice Chat: Restart after TTS

    /// Restart listening after a brief delay to let the audio session settle
    /// after TTS playback → record switch. Used by the voice conversation loop.
    func restartListeningAfterTTS(locale: Locale) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard voiceChatMode, !isListening else { return }
            startListening(locale: locale)
        }
    }

    // MARK: - TTS  Speak / Stop

    // MARK: - Voice Helpers

    /// All voices available for a locale, sorted: male first, then by quality (enhanced > default).
    static func availableVoices(for locale: Locale) -> [AVSpeechSynthesisVoice] {
        let langOnly = String(locale.identifier.replacingOccurrences(of: "_", with: "-").prefix(2))
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(langOnly) }
            .sorted { lhs, rhs in
                // Male first
                if lhs.gender == .male && rhs.gender != .male { return true }
                if lhs.gender != .male && rhs.gender == .male { return false }
                // Then by quality (enhanced/premium first)
                let lQ = lhs.quality == .enhanced || lhs.quality == .premium
                let rQ = rhs.quality == .enhanced || rhs.quality == .premium
                if lQ && !rQ { return true }
                if !lQ && rQ { return false }
                return lhs.name < rhs.name
            }
    }

    /// Speak a short preview of a voice so the user can hear it.
    func previewVoice(_ voice: AVSpeechSynthesisVoice, greeting: String) {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playback, mode: .default, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let utterance = AVSpeechUtterance(string: greeting)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0

        speakingMessageId = nil
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    // MARK: - TTS  Speak / Stop

    /// Speak text aloud. Optionally pass the message ID so the UI can highlight the right bubble.
    func speak(_ text: String, locale: Locale, messageId: UUID? = nil) {
        // Stop any current speech first
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        // Use saved voice preference, or auto-select
        let savedId = LanguageManager.shared.selectedVoiceId
        let langId = locale.identifier.replacingOccurrences(of: "_", with: "-")
        let langOnly = String(langId.prefix(2))

        let voice: AVSpeechSynthesisVoice?
        if !savedId.isEmpty, let saved = AVSpeechSynthesisVoice(identifier: savedId),
           saved.language.hasPrefix(langOnly) {
            voice = saved
        } else {
            // Auto-select: male + best quality → male → any
            let allVoices = AVSpeechSynthesisVoice.speechVoices()
                .filter { $0.language.hasPrefix(langOnly) }
            let maleVoices = allVoices.filter { $0.gender == .male }
            voice = maleVoices.first { $0.quality == .enhanced || $0.quality == .premium }
                ?? maleVoices.first
                ?? allVoices.first
        }

        guard let voice else {
            errorMessage = "No \(langId) voice installed. Go to Settings → Accessibility → Spoken Content → Voices to download it."
            return
        }

        // Configure audio session for playback
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playback, mode: .default, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0

        speakingMessageId = messageId
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        speakingMessageId = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
            speakingMessageId = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
            speakingMessageId = nil
        }
    }

    // MARK: - Silence Detection

    /// Reset the silence timer. Called on every new partial recognition result.
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        // Only start the timer if there is actual transcript content
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleSilenceDetected()
            }
        }
    }

    /// Called when the silence timer fires — user stopped speaking.
    private func handleSilenceDetected() {
        guard isListening else { return }
        let finalText = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        finishListening()
        if !finalText.isEmpty {
            onSpeechFinished?(finalText)
        }
    }

    /// Cancel the silence timer (cleanup helper).
    private func invalidateSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = nil
    }

    // MARK: - STT Internals

    private func finishListening() {
        guard isListening else { return }
        isListening = false
        invalidateSilenceTimer()
        cleanupAudio()

        // Voice chat error recovery: if we stopped unexpectedly (not via silence callback),
        // try to salvage any accumulated transcript or restart listening.
        if voiceChatMode, !isSpeaking {
            let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                guard voiceChatMode, !isListening, !isSpeaking else { return }
                if !text.isEmpty {
                    onSpeechFinished?(text)
                } else if let locale = currentLocale {
                    // No transcript — just restart listening
                    startListening(locale: locale)
                }
            }
        }
    }

    private func stopListeningQuietly() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
    }

    private func cleanupAudio() {
        invalidateSilenceTimer()
        stopListeningQuietly()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
