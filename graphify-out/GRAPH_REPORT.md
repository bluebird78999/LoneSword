# Graph Report - .  (2026-05-21)

## Corpus Check
- 45 files · ~152,323 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 232 nodes · 303 edges · 18 communities (14 shown, 4 thin omitted)
- Extraction: 92% EXTRACTED · 8% INFERRED · 0% AMBIGUOUS · INFERRED: 23 edges (avg confidence: 0.81)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Browser Core & History|Browser Core & History]]
- [[_COMMUNITY_App Architecture Cross-Cutting|App Architecture Cross-Cutting]]
- [[_COMMUNITY_SwiftUI View Implementations|SwiftUI View Implementations]]
- [[_COMMUNITY_Documentation & Design Concepts|Documentation & Design Concepts]]
- [[_COMMUNITY_AI Assistant Core|AI Assistant Core]]
- [[_COMMUNITY_Speech & WebView Integration|Speech & WebView Integration]]
- [[_COMMUNITY_Qwen API Service|Qwen API Service]]
- [[_COMMUNITY_Project Documentation|Project Documentation]]
- [[_COMMUNITY_Graphify Metadata|Graphify Metadata]]
- [[_COMMUNITY_Keychain & Store Errors|Keychain & Store Errors]]
- [[_COMMUNITY_UI Testing|UI Testing]]
- [[_COMMUNITY_IAP & Subscription Mgmt|IAP & Subscription Mgmt]]
- [[_COMMUNITY_Accent Color Assets|Accent Color Assets]]
- [[_COMMUNITY_App Icon Config|App Icon Config]]
- [[_COMMUNITY_Asset Catalog Config|Asset Catalog Config]]
- [[_COMMUNITY_App Icon Images|App Icon Images]]
- [[_COMMUNITY_App Entry Point|App Entry Point]]
- [[_COMMUNITY_Unit Testing|Unit Testing]]

## God Nodes (most connected - your core abstractions)
1. `BrowserViewModel` - 24 edges
2. `AIAssistantViewModel` - 17 edges
3. `StoreKitManager` - 12 edges
4. `AIAssistantViewModel` - 11 edges
5. `LoneSword Browser App` - 9 edges
6. `BrowserViewModel` - 8 edges
7. `AIAssistantView` - 8 edges
8. `AIAssistantView` - 7 edges
9. `QwenService` - 7 edges
10. `ContentView` - 7 edges

## Surprising Connections (you probably didn't know these)
- `URL变更多重通知入口设计模式` --rationale_for--> `BrowserViewModel`  [EXTRACTED]
  URL_CHANGE_TRIGGER_FIX.md → LoneSword/LoneSword/ViewModels/BrowserViewModel.swift
- `BrowserViewModel` --conceptually_related_to--> `WebViewURLDidChange通知机制`  [EXTRACTED]
  LoneSword/LoneSword/ViewModels/BrowserViewModel.swift → URL_CHANGE_TRIGGER_FIX.md
- `AIAssistantView` --conceptually_related_to--> `WebViewURLDidChange通知机制`  [EXTRACTED]
  LoneSword/LoneSword/Views/AIAssistantView.swift → URL_CHANGE_TRIGGER_FIX.md
- `Private API Key Usage Limit Bypass` --conceptually_related_to--> `Tiered Usage Limitation System`  [INFERRED]
  PRIVATE_API_KEY_IMPLEMENTATION.md → IMPLEMENTATION_SUMMARY.md
- `Translation Feature Disabled for Cost Saving` --conceptually_related_to--> `Tiered Usage Limitation System`  [INFERRED]
  TRANSLATION_FEATURE_DISABLED.md → IMPLEMENTATION_SUMMARY.md

## Hyperedges (group relationships)
- **AI页面分析流水线：URL变化→重置AI→页面加载完成→自动分析** — aiassistantview_AIAssistantView, aiassistantviewmodel_AIAssistantViewModel, browserviewmodel_BrowserViewModel, qwenservice_QwenService, urlchangetriggerfix_WebViewURLDidChange [EXTRACTED 1.00]
- **使用限制与订阅系统：免费版/基础版/高级版三级订阅与每日配额** — aiassistantviewmodel_UsageLimitSystem, aisettings_AISettings, storekitmanager_StoreKitManager, settingsview_SettingsView, settingsview_SubscriptionTierCard [EXTRACTED 1.00]
- **SwiftUI MVVM架构：ContentView组装BrowserPageView+AIView，各自绑定ViewModel** — contentview_ContentView, contentview_BrowserPageView, browserviewmodel_BrowserViewModel, aiassistantviewmodel_AIAssistantViewModel, aiassistantview_AIAssistantView, webviewcontainer_WebViewContainer, browsertoolbarview_BrowserToolbarView [INFERRED 0.85]
- **AI Analysis Pipeline on Page Load** — concept_url_change_detection, concept_ai_insight_panel, concept_usage_limitation, concept_private_key_bypass, concept_translation_disabled [INFERRED 0.85]
- **Persistence Architecture Components** — concept_custom_history_stack, concept_swiftdata_migration, concept_mvvm [INFERRED 0.80]
- **Key Design Decisions Trade-offs** — concept_custom_history_stack, concept_url_change_detection, concept_content_provider_injection, concept_private_key_bypass, concept_translation_disabled [INFERRED 0.80]

## Communities (18 total, 4 thin omitted)

### Community 0 - "Browser Core & History"
Cohesion: 0.12
Nodes (4): BrowserHistory, BrowserViewModel, WKNavigationDelegate, WKUIDelegate

### Community 1 - "App Architecture Cross-Cutting"
Cohesion: 0.16
Nodes (24): AIAssistantView, OptionChip, AI页面分析流水线, AIAssistantViewModel, AI使用次数限制与订阅分级系统, AISettings, BrowserHistory, BrowserToolbarView (+16 more)

### Community 2 - "SwiftUI View Implementations"
Cohesion: 0.12
Nodes (8): BrowserPageView, ContentView, View, AIAssistantView, OptionChip, BrowserToolbarView, SettingsView, SubscriptionTierCard

### Community 3 - "Documentation & Design Concepts"
Cohesion: 0.13
Nodes (20): AI Insight Panel Design, WebView Content Provider Injection Pattern, Custom Persistent History Stack, MVVM Architecture Pattern, Private API Key Usage Limit Bypass, Three-Tier Subscription Model (Free/Basic/Premium), SwiftData Auto-Delete Migration Strategy, Translation Feature Disabled for Cost Saving (+12 more)

### Community 5 - "Speech & WebView Integration"
Cohesion: 0.15
Nodes (6): NSObject, ObservableObject, SpeechRecognitionService, UIViewRepresentable, Coordinator, WebViewContainer

### Community 6 - "Qwen API Service"
Cohesion: 0.21
Nodes (9): Codable, Config, Input, Message, Output, QwenService, RequestBody, ResponseBody (+1 more)

### Community 7 - "Project Documentation"
Cohesion: 0.14
Nodes (14): LoneSword Browser App, Responsive Layout Design (Portrait/Landscape), Slash Button Dual-Action Mechanism, Graphify Agent Instructions, Phase 1 Completion Report, LoneSword Delivery Summary, Settings Page Portrait Layout Fix, LoneSword Phase 1 Implementation Summary (+6 more)

### Community 8 - "Graphify Metadata"
Cohesion: 0.14
Nodes (13): files, code, document, image, paper, video, graphifyignore_patterns, needs_graph (+5 more)

### Community 9 - "Keychain & Store Errors"
Cohesion: 0.15
Nodes (9): Error, KeychainError, duplicateItem, invalidData, itemNotFound, unknown, KeychainService, StoreError (+1 more)

### Community 10 - "UI Testing"
Cohesion: 0.18
Nodes (3): LoneSwordUITests, LoneSwordUITestsLaunchTests, XCTestCase

### Community 12 - "Accent Color Assets"
Cohesion: 0.40
Nodes (4): colors, info, author, version

### Community 13 - "App Icon Config"
Cohesion: 0.40
Nodes (4): images, info, author, version

### Community 14 - "Asset Catalog Config"
Cohesion: 0.50
Nodes (3): info, author, version

### Community 15 - "App Icon Images"
Cohesion: 1.00
Nodes (3): App Icon Variation 1 (1024px), App Icon Variation 2 (1024px), App Icon Variation 3 (1024px)

## Knowledge Gaps
- **37 isolated node(s):** `code`, `document`, `paper`, `image`, `video` (+32 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **4 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `AIAssistantViewModel` connect `AI Assistant Core` to `Speech & WebView Integration`?**
  _High betweenness centrality (0.100) - this node is a cross-community bridge._
- **Why does `BrowserViewModel` connect `Browser Core & History` to `Speech & WebView Integration`?**
  _High betweenness centrality (0.095) - this node is a cross-community bridge._
- **Why does `StoreKitManager` connect `IAP & Subscription Mgmt` to `Keychain & Store Errors`, `Speech & WebView Integration`?**
  _High betweenness centrality (0.077) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `AIAssistantViewModel` (e.g. with `BrowserViewModel` and `StoreKitManager`) actually correct?**
  _`AIAssistantViewModel` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `code`, `document`, `paper` to the rest of the system?**
  _45 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Browser Core & History` be split into smaller, more focused modules?**
  _Cohesion score 0.11692307692307692 - nodes in this community are weakly interconnected._
- **Should `SwiftUI View Implementations` be split into smaller, more focused modules?**
  _Cohesion score 0.11857707509881422 - nodes in this community are weakly interconnected._