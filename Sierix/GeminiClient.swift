import Foundation

struct ChatMessage {
    let role: String
    let text: String
}

struct ChatSession {
    var id: String
    var title: String
    var messages: [ChatMessage]
}

class GeminiClient {
    private let apiKey: String
    
    var sessions: [ChatSession] = []
    var currentSessionIndex: Int = 0
    
    init(apiKey: String) {
        self.apiKey = apiKey
        loadHistory()
        if sessions.isEmpty {
            createNewSession()
        }
    }
    
    func createNewSession() {
        let newID = NSUUID().UUIDString
        let newSession = ChatSession(id: newID, title: "Новий чат", messages: [])
        sessions.insert(newSession, atIndex: 0)
        currentSessionIndex = 0
        saveHistory()
    }
    
    func addMessageToCurrentSession(role: String, text: String) {
        guard currentSessionIndex < sessions.count else { return }
        sessions[currentSessionIndex].messages.append(ChatMessage(role: role, text: text))
        saveHistory()
    }
    
    // Замість baseURL:
    private let model = "gemini-3.8-flash"   // підстав назву зі списку моделей
    private var baseURL: String {
        return "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
    }
    
    func sendPrompt(text: String, completion: (result: String?, error: NSError?) -> Void) {
        guard let url = NSURL(string: baseURL) else {
            completion(result: nil, error: NSError(domain: "GeminiClient", code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        guard currentSessionIndex < sessions.count else { return }
        
        let idx = currentSessionIndex
        let sessionID = sessions[idx].id
        
        if sessions[idx].messages.isEmpty {
            let shortTitle = text.componentsSeparatedByString("\n").first ?? text
            sessions[idx].title = String(shortTitle.characters.prefix(25))
        }
        sessions[idx].messages.append(ChatMessage(role: "user", text: text))
        saveHistory()
        
        var contentsArray: [[String: AnyObject]] = []
        for msg in sessions[idx].messages where !msg.text.hasPrefix("Помилка:") {
            contentsArray.append(["role": msg.role, "parts": [["text": msg.text]]])
        }
        
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        
        do {
            request.HTTPBody = try NSJSONSerialization.dataWithJSONObject(["contents": contentsArray], options: [])
        } catch let jsonErr as NSError {
            completion(result: nil, error: jsonErr)
            return
        }
        
        let task = NSURLSession.sharedSession().dataTaskWithRequest(request) { (data, response, error) in
            // Усе, що чіпає sessions або UI, виконується в головному потоці
            func finish(result: String?, _ err: NSError?) {
                dispatch_async(dispatch_get_main_queue()) {
                    if let result = result, let i = self.sessions.indexOf({ $0.id == sessionID }) {
                        self.sessions[i].messages.append(ChatMessage(role: "model", text: result))
                        self.saveHistory()
                    }
                    completion(result: result, error: err)
                }
            }
            func fail(code: Int, _ message: String) {
                finish(nil, NSError(domain: "GeminiClient", code: code,
                    userInfo: [NSLocalizedDescriptionKey: message]))
            }
            
            if let error = error { finish(nil, error); return }
            guard let data = data else { fail(500, "No data received"); return }
            
            let body = String(data: data, encoding: NSUTF8StringEncoding) ?? ""
            if let http = response as? NSHTTPURLResponse where http.statusCode != 200 {
                fail(http.statusCode, "HTTP \(http.statusCode): \(body)")
                return
            }
            
            do {
                if let json = try NSJSONSerialization.JSONObjectWithData(data, options: []) as? [String: AnyObject],
                    let candidates = json["candidates"] as? [[String: AnyObject]],
                    let content = candidates.first?["content"] as? [String: AnyObject],
                    let parts = content["parts"] as? [[String: AnyObject]] {
                    let answer = parts.flatMap { $0["text"] as? String }.joinWithSeparator("")
                    if !answer.isEmpty { finish(answer, nil); return }
                }
                fail(422, body)   // порожня відповідь, блокування за безпекою тощо
            } catch let parseError as NSError {
                finish(nil, parseError)
            }
        }
        task.resume()
    }
    
    private func getHistoryFilePath() -> String? {
        let fileManager = NSFileManager.defaultManager()
        guard let appSupport = fileManager.URLsForDirectory(.ApplicationSupportDirectory, inDomains: .UserDomainMask).first else { return nil }
        let dirPath = appSupport.URLByAppendingPathComponent("Sierix")
        
        do {
            try fileManager.createDirectoryAtURL(dirPath, withIntermediateDirectories: true, attributes: nil)
            return dirPath.URLByAppendingPathComponent("chats.json").path
        } catch {
            return nil
        }
    }
    
    func saveHistory() {
        guard let path = getHistoryFilePath() else { return }
        var exportArray: [[String: AnyObject]] = []
        
        for session in sessions {
            var msgs: [[String: String]] = []
            for m in session.messages {
                msgs.append(["role": m.role, "text": m.text])
            }
            exportArray.append([
                "id": session.id,
                "title": session.title,
                "messages": msgs
                ])
        }
        
        do {
            let data = try NSJSONSerialization.dataWithJSONObject(exportArray, options: .PrettyPrinted)
            data.writeToFile(path, atomically: true)
        } catch {
            print("Failed to save JSON history")
        }
    }
    
    func loadHistory() {
        guard let path = getHistoryFilePath(),
            let data = NSData(contentsOfFile: path) else { return }
        
        do {
            if let array = try NSJSONSerialization.JSONObjectWithData(data, options: []) as? [[String: AnyObject]] {
                sessions.removeAll()
                for item in array {
                    if let id = item["id"] as? String,
                        let title = item["title"] as? String,
                        let rawMsgs = item["messages"] as? [[String: String]] {
                        
                        var msgs: [ChatMessage] = []
                        for m in rawMsgs {
                            if let role = m["role"], let text = m["text"] {
                                msgs.append(ChatMessage(role: role, text: text))
                            }
                        }
                        sessions.append(ChatSession(id: id, title: title, messages: msgs))
                    }
                }
            }
        } catch {
            print("Failed to load JSON history")
        }
    }
    
    func deleteCurrentSession() {
        if !sessions.isEmpty {
            sessions.removeAtIndex(currentSessionIndex)
            if currentSessionIndex >= sessions.count {
                currentSessionIndex = max(0, sessions.count - 1)
            }
            if sessions.isEmpty {
                createNewSession()
            }
            saveHistory()
        }
    }
}