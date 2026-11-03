// ZL2-iOS · 设置页
// 对照 ZL2 安卓版的「设置」：渲染器 / 分辨率 / 内存 / Java 环境 / 下载源
import SwiftUI

struct SettingsScreen: View {
    @AppStorage("renderer")     private var renderer = "MobileGlues"
    @AppStorage("resolution")   private var resolution = 100.0
    @AppStorage("memoryMB")     private var memoryMB = 2048
    @AppStorage("mirrorSource") private var mirrorSource = false

    private let renderers = ["MobileGlues", "Krypton Wrapper", "GL4ES", "Vulkan Zink", "VirGLRenderer"]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                section("渲染设置") {
                    pickerRow("渲染器", selection: $renderer, options: renderers)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("分辨率").font(.system(size: 14))
                            Spacer()
                            Text("\(Int(resolution))%")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(ZLTheme.primary)
                        }
                        Slider(value: $resolution, in: 30...100, step: 10)
                    }
                    hint("分辨率越低，渲染压力越小、帧率越稳。2K 屏建议 50%。")
                }

                section("游戏设置") {
                    stepperRow("内存分配", value: $memoryMB, range: 1024...8192, step: 512, unit: "MB")
                    hint("并非越大越好，分配过高会让系统资源紧张，反而卡顿闪退。")
                    toggleRow("自动选择 Java 环境", isOn: .constant(true))
                    hint("少数客户端需要特定版本时才需手动指定。")
                }

                section("启动器设置") {
                    toggleRow("优先使用镜像源", isOn: $mirrorSource)
                    hint("国内网络下官方源可能很慢，下载失败时切开。")
                }
            }
            .padding(.horizontal, ZLTheme.screenPadding)
            .padding(.vertical, 12)
        }
        .background(ZLTheme.surface)
    }

    // MARK: 组件
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ZLTheme.textSecond)
                .padding(.leading, 4)
            ZLCard { VStack(alignment: .leading, spacing: 12) { content() } }
        }
    }

    private func pickerRow(_ title: String, selection: Binding<String>, options: [String]) -> some View {
        HStack {
            Text(title).font(.system(size: 14))
            Spacer()
            Menu {
                ForEach(options, id: \.self) { o in
                    Button(o) { selection.wrappedValue = o }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selection.wrappedValue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ZLTheme.primary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(ZLTheme.primary)
                }
            }
        }
    }

    private func stepperRow(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, unit: String) -> some View {
        HStack {
            Text(title).font(.system(size: 14))
            Spacer()
            Stepper(value: value, in: range, step: step) {
                Text("\(value.wrappedValue) \(unit)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ZLTheme.primary)
            }
            .labelsHidden()
            Text("\(value.wrappedValue) \(unit)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ZLTheme.primary)
                .frame(minWidth: 70, alignment: .trailing)
        }
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title).font(.system(size: 14))
            Spacer()
            Toggle("", isOn: isOn).labelsHidden()
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(ZLTheme.textSecond)
            .fixedSize(horizontal: false, vertical: true)
    }
}
