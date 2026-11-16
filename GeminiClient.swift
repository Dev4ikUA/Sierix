import Foundation

struct ChatMessage: Codable {
    let role: String
    let text: String
    
    var isError: Bool {
        return text.hasPrefix("Error:") || text.hasPrefix("Помилка:")
    }
}

struct ChatSession: Codable {
    var id: String
    var title: String
    var messages: [ChatMessage]
}

class GeminiClient {
    private let apiKey: String
    // Список моделей за пріоритетом. Якщо перша лежить (503/429/404), піде на наступну
    private let modelChain = [
        "gemini-4-hydrogen",
        "gemini-3.8-flash",
        "gemini-2.5-flash"
    ]
    private let retryableStatusCodes: Set<Int> = [429, 500, 502, 503, 504]
    private let maxAttempts = 4
    
    // Окрема послідовна черга для безпечного запису на диск без фрізів UI
    private let ioQueue = DispatchQueue(label: "com.sierix.geminiclient.io", qos: .utility)
    
    var sessions: [ChatSession] = []
    var currentSessionIndex: Int = 0
    
    private func makeURL(for modelName: String) -> URL? {
        return URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent")
    }
    
    init(apiKey: String) {
        self.apiKey = apiKey
        loadHistory()
        if sessions.isEmpty {
            createNewSession()
        }
    }
    
    func createNewSession() {
        let newSession = ChatSession(id: UUID().uuidString, title: "New chat", messages: [])
        sessions.insert(newSession, at: 0)
        currentSessionIndex = 0
        saveHistory()
    }
    
    func addMessageToCurrentSession(_ role: String, text: String) {
        guard sessions.indices.contains(currentSessionIndex) else { return }
        sessions[currentSessionIndex].messages.append(ChatMessage(role: role, text: text))
        saveHistory()
    }
    
    func deleteCurrentSession() {
        guard sessions.indices.contains(currentSessionIndex) else { return }
        sessions.remove(at: currentSessionIndex)
        
        if sessions.isEmpty {
            createNewSession()
        } else {
            currentSessionIndex = min(currentSessionIndex, sessions.count - 1)
            saveHistory()
        }
    }
    
    func sendPrompt(_ text: String, completion: @escaping (_ result: String?, _ error: NSError?) -> Void) {
        guard let firstModel = modelChain.first,
            let initialURL = makeURL(for: firstModel) else {
                completion(nil, makeError(code: 400, message: "Invalid model URL"))
                return
        }
        guard sessions.indices.contains(currentSessionIndex) else {
            completion(nil, makeError(code: 400, message: "No active session"))
            return
        }
        
        let idx = currentSessionIndex
        let sessionID = sessions[idx].id
        
        if sessions[idx].messages.isEmpty {
            let shortTitle = text.components(separatedBy: .newlines).first ?? text
            sessions[idx].title = String(shortTitle.prefix(25))
        }
        
        sessions[idx].messages.append(ChatMessage(role: "user", text: text))
        saveHistory()
        
        // Формуємо історію, фільтруючи помилки та зливаючи сусідні user-повідомлення
        var contentsArray: [[String: Any]] = []
        for msg in sessions[idx].messages where !msg.isError {
            if let lastRole = contentsArray.last?["role"] as? String, lastRole == msg.role,
                var parts = contentsArray.last?["parts"] as? [[String: String]] {
                parts.append(["text": msg.text])
                contentsArray[contentsArray.count - 1]["parts"] = parts
            } else {
                contentsArray.append(["role": msg.role, "parts": [["text": msg.text]]])
            }
        }
        
        var request = URLRequest(url: initialURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: ["contents": contentsArray], options: [])
        } catch {
            completion(nil, error as NSError)
            return
        }
        
        let finalRequest = request
        
        func finish(_ result: String?, _ err: NSError?) {
            DispatchQueue.main.async { [weak self] in
                if let self = self,
                    let result = result,
                    let i = self.sessions.index(where: { $0.id == sessionID }) {
                    self.sessions[i].messages.append(ChatMessage(role: "model", text: result))
                    self.saveHistory()
                }
                completion(result, err)
            }
        }
        
        func parseAPIErrorMessage(from body: String, statusCode: Int) -> String {
            guard let data = body.data(using: .utf8),
                let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                let errorObj = json!["error"] as? [String: Any],
                let message = errorObj["message"] as? String else {
                    return "HTTP \(statusCode): \(body)"
            }
            return "HTTP \(statusCode): \(message)"
        }
        
        func attempt(_ n: Int, modelIndex: Int) {
            guard modelIndex < self.modelChain.count else {
                finish(nil, self.makeError(code: 503, message: "All models in chain are unavailable"))
                return
            }
            
            let currentModel = self.modelChain[modelIndex]
            guard let url = makeURL(for: currentModel) else {
                finish(nil, self.makeError(code: 400, message: "Invalid URL for model \(currentModel)"))
                return
            }
            
            var req = finalRequest
            req.url = url
            
            let task = URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
                guard let self = self else { return }
                
                if let error = error {
                    finish(nil, error as NSError)
                    return
                }
                guard let data = data else {
                    finish(nil, self.makeError(code: 500, message: "No data received"))
                    return
                }
                
                let body = String(data: data, encoding: .utf8) ?? ""
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    // Якщо 404 (неправильний ID моделі) — одразу переходимо на наступну модель
                    if http.statusCode == 404 && modelIndex + 1 < self.modelChain.count {
                        attempt(1, modelIndex: modelIndex + 1)
                        return
                    }
                    
                    if self.retryableStatusCodes.contains(http.statusCode) {
                        if n < self.maxAttempts {
                            let jitter = Double(arc4random_uniform(800)) / 1000.0 + 0.1
                            let delay = Double(1 << n) + jitter
                            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                                attempt(n + 1, modelIndex: modelIndex)
                            }
                            return
                        } else if modelIndex + 1 < self.modelChain.count {
                            attempt(1, modelIndex: modelIndex + 1)
                            return
                        }
                    }
                    
                    let cleanMessage = parseAPIErrorMessage(from: body, statusCode: http.statusCode)
                    finish(nil, self.makeError(code: http.statusCode, message: "[\(currentModel)] \(cleanMessage)"))
                    return
                }
                
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                        let candidates = json["candidates"] as? [[String: Any]],
                        let firstCandidate = candidates.first else {
                            finish(nil, self.makeError(code: 422, message: "Unexpected JSON format: \(body)"))
                            return
                    }
                    
                    if let content = firstCandidate["content"] as? [String: Any],
                        let parts = content["parts"] as? [[String: Any]] {
                        let answer = parts.compactMap { $0["text"] as? String }.joined()
                        if !answer.isEmpty {
                            finish(answer, nil)
                            return
                        }
                    }
                    
                    let finishReason = firstCandidate["finishReason"] as? String ?? "UNKNOWN"
                    finish(nil, self.makeError(code: 422, message: "Empty response (reason: \(finishReason))"))
                } catch {
                    finish(nil, error as NSError)
                }
            }
            task.resume()
        }
        
        attempt(1, modelIndex: 0)
    }
    
    // MARK: - Persistence
    
    private func getHistoryFileURL() -> URL? {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dirURL = appSupport.appendingPathComponent("Sierix")
        do {
            try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true, attributes: nil)
            return dirURL.appendingPathComponent("chats.json")
        } catch {
            return nil
        }
    }
    
    func saveHistory() {
        guard let fileURL = getHistoryFileURL() else { return }
        let sessionsSnapshot = self.sessions
        
        ioQueue.async {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(sessionsSnapshot)
                try data.write(to: fileURL, options: .atomic)
            } catch {
                print("Failed to save JSON history: \(error)")
            }
        }
    }
    
    func loadHistory() {
        guard let fileURL = getHistoryFileURL(),
            let data = try? Data(contentsOf: fileURL) else { return }
        
        do {
            sessions = try JSONDecoder().decode([ChatSession].self, from: data)
        } catch {
            print("Failed to load JSON history: \(error)")
        }
    }
    
    private func makeError(code: Int, message: String) -> NSError {
        return NSError(domain: "GeminiClient", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
