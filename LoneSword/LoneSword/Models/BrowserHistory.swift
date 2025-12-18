import Foundation
import SwiftData

@Model
final class BrowserHistory {
    var url: String
    var title: String
    var timestamp: Date
    var visitOrder: Int = 0 // 用于排序，数字越大越新（默认值0以支持数据迁移）
    
    init(url: String, title: String = "", timestamp: Date = Date(), visitOrder: Int = 0) {
        self.url = url
        self.title = title
        self.timestamp = timestamp
        self.visitOrder = visitOrder
    }
}
