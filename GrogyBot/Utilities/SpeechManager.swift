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

    // MARK: - Private
    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?
    private let synthesizer = AVSpeechSynthesizer()

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

    // MARK: - TTS  Speak / Stop

    /// Speak text aloud. Optionally pass the message ID so the UI can highlight the right bubble.
    func speak(_ text: String, locale: Locale, messageId: UUID? = nil) {
        // Stop any current speech first
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        // Find a voice — try exact locale, then language-only, then any installed voice for that language
        let langId = locale.identifier.replacingOccurrences(of: "_", with: "-")   // "bg_BG" → "bg-BG"
        let langOnly = String(langId.prefix(2))                                    // "bg"
        let voice: AVSpeechSynthesisVoice? =
            AVSpeechSynthesisVoice(language: langId)
            ?? AVSpeechSynthesisVoice(language: langOnly)
            ?? AVSpeechSynthesisVoice.speechVoices().first { $0.language.hasPrefix(langOnly) }

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
        guard synthesizer.isSpeaking else { return }
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

    // MARK: - STT Internals

    private func finishListening() {
        guard isListening else { return }
        isListening = false
        cleanupAudio()
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
        stopListeningQuietly()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
