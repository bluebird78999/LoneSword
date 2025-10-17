//
//  ContentView.swift
//  LoneSword
//
//  Created by LiuHongfeng on 2025/10/18.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var _modelContext
    @Query private var _items: [Item]

    @State private var urlText: String = "https://ai.quark.cn/"
    @State private var canGoBack: Bool = true
    @State private var canGoForward: Bool = false

    // AI assistant toggles (default on)
    @State private var detectAIGenerated: Bool = true
    @State private var autoTranslateCN: Bool = true
    @State private var autoSummarize: Bool = true

    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height

            Group {
                if isLandscape {
                    // Landscape: horizontal split (web 2/3, assistant 1/3)
                    HStack(spacing: 0) {
                        browserArea
                            .frame(width: geo.size.width * 2/3)
                            .background(Color(.systemBackground))
                        Divider()
                        assistantArea
                            .frame(width: geo.size.width * 1/3)
                            .background(Color(.secondarySystemBackground))
                    }
                } else {
                    // Portrait: vertical stack (assistant 1/3 on top, web 2/3 bottom)
                    VStack(spacing: 0) {
                        assistantArea
                            .frame(height: geo.size.height * 1/3)
                            .background(Color(.secondarySystemBackground))
                        Divider()
                        browserArea
                            .frame(height: geo.size.height * 2/3)
                            .background(Color(.systemBackground))
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .ignoresSafeArea()
        }
    }

    // MARK: - Browser Area
    private var browserArea: some View {
        VStack(spacing: 0) {
            browserToolbar
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .overlay(Divider(), alignment: .bottom)

            // Main web content mock
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("今日科技新闻")
                        .font(.system(size: 28, weight: .bold))
                        .padding(.top, 8)

                    // Featured image placeholder
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(colors: [Color.blue.opacity(0.12), Color.purple.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(
                            VStack(spacing: 6) {
                                Image(systemName: "globe.asia.australia.fill")
                                    .font(.system(size: 34))
                                    .foregroundStyle(.blue)
                                Text("示例网站横幅图像")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        )
                        .frame(height: 180)

                    Group {
                        Text("人工智能正在改变我们的工作与生活方式。最新报告显示，多数行业开始采用 AI 工具来提升效率，并探索全新商业模式。")
                        Text("业界观点")
                            .font(.headline)
                        VStack(alignment: .leading, spacing: 8) {
                            labeledBullet("AI 提升生产力，帮助重复性任务自动化")
                            labeledBullet("数据隐私与安全需要更严格的治理")
                            labeledBullet("未来五年将出现更多 AIGC 消费级应用")
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("延伸阅读：").bold()
                            Text("如何在团队中安全部署生成式 AI ")
                                .foregroundStyle(.blue)
                        }
                    }
                    .font(.body)
                    .foregroundStyle(.primary)

                    Spacer(minLength: 12)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
        )
    }

    private var browserToolbar: some View {
        HStack(spacing: 10) {
            // Back / Forward
            HStack(spacing: 8) {
                toolbarButton(system: "chevron.left", enabled: canGoBack) {
                    // Placeholder action
                    canGoForward = true
                }
                toolbarButton(system: "chevron.right", enabled: canGoForward) {
                    // Placeholder action
                    canGoForward = false
                }
            }

            // URL / Search bar
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .foregroundStyle(.secondary)
                TextField("https://ai.quark.cn/", text: $urlText)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .keyboardType(.URL)
                Button(action: { /* go/search */ }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.blue))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Search or Go")
            }
            .padding(.horizontal, 10)
            .frame(height: 44)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.systemGray6)))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Assistant Area
    private var assistantArea: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("AI洞察")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.thinMaterial)
            .overlay(Divider(), alignment: .bottom)

            // Toggles row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    toggleChip(title: "识别AI生成", isOn: $detectAIGenerated)
                    toggleChip(title: "自动翻译中文", isOn: $autoTranslateCN)
                    toggleChip(title: "自动总结", isOn: $autoSummarize)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(Color(.secondarySystemBackground))
            .overlay(Divider(), alignment: .bottom)

            // Rich text area
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Group {
                        Text(md("基于当前网页内容，这篇文章讨论了**人工智能**在*日常生活*中的应用。"))
                        Text("主要要点包括：").bold()
                        VStack(alignment: .leading, spacing: 6) {
                            labeledBullet("AI 提升生产力")
                            labeledBullet("潜在隐私风险")
                            labeledBullet("未来发展趋势")
                        }
                        Text("建议进一步阅读相关报告。")
                    }
                    .font(.body)
                    .foregroundStyle(.primary)
                    .padding(.top, 6)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            // Input bar
            HStack(spacing: 10) {
                Button(action: { /* voice input */ }) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.blue)
                        .frame(width: 44, height: 44)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(.systemGray6)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Voice input")

                TextField("向 AI 提问…", text: .constant(""))
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(.systemGray6)))

                Button(action: { /* send */ }) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.blue))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Send message")
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .overlay(Divider(), alignment: .top)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
        )
    }

    // MARK: - Helpers
    private func toolbarButton(system: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(enabled ? .primary : .secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityHidden(!enabled)
    }

    private func toggleChip(title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.blue)
            Text(title)
                .font(.subheadline)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
        )
    }

    private func labeledBullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•")
                .font(.headline)
            Text(text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func md(_ markdown: String) -> AttributedString {
        (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
    }
}

#Preview("iPad Landscape", traits: .landscapeLeft) {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
        .frame(width: 1366, height: 1024)
}

#Preview("iPhone Portrait", traits: .portrait) {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
        .frame(width: 390, height: 844)
}
