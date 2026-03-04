import Foundation
import Speech
import AVFoundation
import Observation

@MainActor
@Observable
final class SpeechManager {

    var isListening = false
    var transcript = ""
    var errorMessage: String?

    var isAvailable: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    // MARK: - Private

    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?

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

    // MARK: - Start / Stop

    func startListening(locale: Locale) {
        // Cancel any ongoing task
        stopListeningQuietly()

        speechRecognizer = SFSpeechRecognizer(locale: locale)
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognizer not available for this language."
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

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        do {
            try audioEngine.start()
        } catch {
            errorMessage = "Could not start audio engine."
            cleanupAudio()
            return
        }

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if error != nil || (result?.isFinal ?? false) {
                    // Auto-stop on final result or error
                    if self.isListening {
                        self.finishListening()
                    }
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

    // MARK: - Internals

    private func finishListening() {
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
