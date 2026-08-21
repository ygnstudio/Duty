import Foundation

/// 内置扩展名目录
/// 负责加载 builtin_extensions.json 并提供搜索功能
@MainActor
final class ExtensionCatalog: Sendable {
    static let shared = ExtensionCatalog()

    private var extensions: [ExtensionInfo] = []

    private init() {
        loadBuiltinExtensions()
    }

    // MARK: - Loading

    private func loadBuiltinExtensions() {
        // 尝试多种方式找到资源文件
        guard let data = loadBuiltinExtensionsData() else {
            logger.warning("[ExtensionCatalog] Could not load builtin_extensions.json, using empty catalog")
            return
        }

        do {
            let decoder = JSONDecoder()
            extensions = try decoder.decode([ExtensionInfo].self, from: data)
        } catch {
            logger.error("[ExtensionCatalog] Failed to parse extensions: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 从多种可能的路径加载资源数据（不引用 Bundle.module，避免 fatalError）
    private func loadBuiltinExtensionsData() -> Data? {
        let resourceName = "builtin_extensions"
        let resourceExt = "json"
        let bundleName = "Duty_Duty"

        // 方法 1：在主 bundle 的 Resources 目录中查找资源 bundle
        if let resourcesURL = Bundle.main.resourceURL {
            let bundleURL = resourcesURL.appendingPathComponent("\(bundleName).bundle")
            if let resourceURL = Bundle(url: bundleURL)?.url(forResource: resourceName, withExtension: resourceExt),
               let data = try? Data(contentsOf: resourceURL) {
                return data
            }
        }

        // 方法 2：在主 bundle 中直接查找
        if let url = Bundle.main.url(forResource: resourceName, withExtension: resourceExt),
           let data = try? Data(contentsOf: url) {
            return data
        }

        // 方法 3：遍历 Resources 目录查找所有 .bundle
        if let resourcesURL = Bundle.main.resourceURL,
           let contents = try? FileManager.default.contentsOfDirectory(at: resourcesURL, includingPropertiesForKeys: nil) {
            for url in contents where url.pathExtension == "bundle" {
                if let bundle = Bundle(url: url),
                   let resourceURL = bundle.url(forResource: resourceName, withExtension: resourceExt),
                   let data = try? Data(contentsOf: resourceURL) {
                    return data
                }
            }
        }

        logger.warning("[ExtensionCatalog] Failed to locate \(resourceName).\(resourceExt, privacy: .public)")
        return nil
    }

    // MARK: - Search

    /// 搜索扩展名
    func search(_ query: String) -> [ExtensionInfo] {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !normalizedQuery.isEmpty else {
            return extensions.sorted { $0.ext < $1.ext }
        }

        let cleanQuery = normalizedQuery.replacingOccurrences(of: ".", with: "")

        return extensions.filter { info in
            if info.ext.lowercased().contains(cleanQuery) { return true }
            if let zh = info.displayName["zh-Hans"], zh.lowercased().contains(cleanQuery) { return true }
            if let en = info.displayName["en"], en.lowercased().contains(cleanQuery) { return true }
            if info.localizedCategory.lowercased().contains(cleanQuery) { return true }
            if info.category.lowercased().contains(cleanQuery) { return true }
            return false
        }.sorted { $0.ext < $1.ext }
    }

    func find(extension ext: String) -> ExtensionInfo? {
        let normalized = ManagedAssociation.normalizeExtension(ext)
        return extensions.first { $0.ext == normalized }
    }

    func allExtensions() -> [ExtensionInfo] { extensions }
    func reload() { loadBuiltinExtensions() }
}
