import Foundation
import Combine
import Speech
import AVFoundation

final class SpeechRecognitionService: NSObject, ObservableObject {
    @Published var recognizedText: String = ""
    @Published var isListening: Bool = false
    @Published var errorMessage: String?
    
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    func start() {
        guard !audioEngine.isRunning else { return }
        do {
            recognitionTask?.cancel()
            recognitionTask = nil
            
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { return }
            recognitionRequest.shouldReportPartialResults = true
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            recognitionTask = recognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                if let result = result {
                    DispatchQueue.main.async { self?.recognizedText = result.bestTranscription.formattedString }
                }
                if error != nil || (result?.isFinal ?? false) {
                    self?.stop()
                }
            }
            
            DispatchQueue.main.async { self.isListening = true }
        } catch {
            DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
        }
    }
    
    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        DispatchQueue.main.async { self.isListening = false }
    }
}
