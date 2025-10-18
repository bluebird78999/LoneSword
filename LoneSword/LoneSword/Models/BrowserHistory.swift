import Foundation
import SwiftData

@Model
final class BrowserHistory {
    var url: String
    var title: String
    var timestamp: Date
    
    init(url: String, title: String = "", timestamp: Date = Date()) {
        self.url = url
        self.title = title
        self.timestamp = timestamp
    }
}
