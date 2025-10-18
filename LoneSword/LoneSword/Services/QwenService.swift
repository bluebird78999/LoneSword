import Foundation

final class QwenService {
    struct Config {
        let apiKey: String
        let endpoint: String
        init(apiKey: String, endpoint: String = "https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation") {
            self.apiKey = apiKey
            self.endpoint = endpoint
        }
    }
    
    private let config: Config
    init(config: Config) {
        self.config = config
    }
    
    struct RequestBody: Codable {
        let model: String
        let input: Input
        struct Input: Codable {
            let messages: [Message]
            struct Message: Codable {
                let role: String
                let content: String
            }
        }
    }
    
    struct ResponseBody: Codable {
        let output: Output?
        struct Output: Codable {
            let text: String?
        }
        let requestId: String?
    }
    
    func call(webContent: String, userQuery: String) async throws -> String {
        var request = URLRequest(url: URL(string: config.endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        
        let body = RequestBody(
            model: "qwen-plus",
            input: .init(messages: [
                .init(role: "user", content: "分析网页内容：\(webContent.prefix(6000))\n\n用户问题：\(userQuery)")
            ])
        )
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "QwenService", code: 1, userInfo: [NSLocalizedDescriptionKey: "HTTP error"]) 
        }
        if let decoded = try? JSONDecoder().decode(ResponseBody.self, from: data), let text = decoded.output?.text {
            return text
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    struct TranslationResult {
        let detectedLanguage: String
        let translatedContent: String
        let isTranslated: Bool
    }
    
    /// Detect page language and translate to Chinese if needed
    func detectAndTranslate(webContent: String) async throws -> TranslationResult {
        var request = URLRequest(url: URL(string: config.endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        
        let prompt = """
        检测以下网页内容的语言。如果不是中文，请翻译为中文；如果已是中文，返回原文。
        请以JSON格式回复：{"language": "语言名称", "translated": "翻译后的内容", "isTranslated": true/false}
        
        内容：\(webContent.prefix(3000))
        """
        
        let body = RequestBody(
            model: "qwen-plus",
            input: .init(messages: [
                .init(role: "user", content: prompt)
            ])
        )
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "QwenService", code: 1, userInfo: [NSLocalizedDescriptionKey: "HTTP translation error"])
        }
        
        if let decoded = try? JSONDecoder().decode(ResponseBody.self, from: data),
           let text = decoded.output?.text {
            // Parse JSON response
            if let jsonData = text.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let language = json["language"] as? String,
               let translated = json["translated"] as? String,
               let isTranslated = json["isTranslated"] as? Bool {
                return TranslationResult(
                    detectedLanguage: language,
                    translatedContent: translated,
                    isTranslated: isTranslated
                )
            }
        }
        
        // Fallback: return original content
        return TranslationResult(
            detectedLanguage: "unknown",
            translatedContent: String(webContent.prefix(3000)),
            isTranslated: false
        )
    }
    
    /// Test API key validity
    func testKey() async throws -> Bool {
        var request = URLRequest(url: URL(string: config.endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        
        let body = RequestBody(
            model: "qwen-plus",
            input: .init(messages: [
                .init(role: "user", content: "测试")
            ])
        )
        request.httpBody = try JSONEncoder().encode(body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return false }
        return (200..<300).contains(http.statusCode)
    }
}
