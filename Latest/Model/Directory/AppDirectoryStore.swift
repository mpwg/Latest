//
//  AppDirectoryStore.swift
//  Latest
//
//  Created by Max Langer on 05.07.24.
//  Copyright © 2024 Max Langer. All rights reserved.
//

import Foundation

/// Object that takes care of storing and observing application directories.
final class AppDirectoryStore: ObservableObject {
    
    typealias UpdateHandler = () -> Void
    
    /// Published list of directories that should be scanned for applications.
    @Published private(set) var directoryList: [URL]
    
    private var observer: NSKeyValueObservation?
    private let updateHandler: UpdateHandler?
    
    /// Initializes the store with the given update handler.
    init(updateHandler: UpdateHandler? = nil) {
        self.updateHandler = updateHandler
        self.directoryList = Self.loadDefaultAndCustomURLs()
        
        observer = UserDefaults.standard.observe(\.directoryPaths, options: [.new]) { [weak self] _, _ in
            self?.directoriesDidChange()
        }
    }
    
    deinit {
        observer?.invalidate()
    }
    
    
    // MARK: - URLs
    
    /// The URLs stored in this object.
    var URLs: [URL] {
        Self.defaultURLs + customURLs
    }
    
    
    /// Set of URLs that will always be checked.
    private static let defaultURLs: [URL] = {
        let fileManager = FileManager.default
        let urls = [FileManager.SearchPathDomainMask.localDomainMask, .userDomainMask].flatMap { domainMask -> [URL] in
            fileManager.urls(for: .applicationDirectory, in: domainMask)
        }
        
        return urls.filter { url -> Bool in
            fileManager.fileExists(atPath: url.path)
        }
    }()
    
    /// User-definable URLs.
    private var customURLs: [URL] {
        get { Self.customURLs(from: UserDefaults.standard) }
        set { UserDefaults.standard.directoryPaths = newValue.map { $0.relativePath } }
    }
    
    private static func customURLs(from defaults: UserDefaults) -> [URL] {
        guard let paths = defaults.directoryPaths else { return [] }
        
        return paths.map { path in
            if #available(macOS 13.0, *) {
                URL(filePath: path, directoryHint: .isDirectory, relativeTo: nil)
            } else {
                URL(fileURLWithPath: path)
            }
        }
    }
    
    private static func loadDefaultAndCustomURLs() -> [URL] {
        defaultURLs + customURLs(from: .standard)
    }
    
    private func directoriesDidChange() {
        let urls = Self.loadDefaultAndCustomURLs()
        DispatchQueue.main.async {
            self.directoryList = urls
        }
        updateHandler?()
    }
    
    
    // MARK: - Actions
    
    /// Adds the given URL to the store.
    ///
    /// This method does nothing if the URL already exists.
    func add(_ url: URL) {
        // Ignore adding the same URL multiple times
        guard !URLs.contains(url) else { return }
        customURLs.append(url)
    }
    
    /// Removes the custom URL, if set.
    func remove(_ url: URL) {
        customURLs.removeAll(where: { $0 == url })
    }
    
    /// Whether the URL can be removed from the store.
    func canRemove(_ url: URL) -> Bool {
        customURLs.contains(url) && !Self.defaultURLs.contains(url)
    }
    
    /// Whether the url currently reachable.
    func isReachable(_ url: URL) -> Bool {
        (try? url.checkResourceIsReachable()) == true
    }
}

extension UserDefaults {
    private static let directoryPathsKey = "directoryPaths"
    @objc dynamic var directoryPaths: [String]? {
        get { stringArray(forKey: Self.directoryPathsKey) }
        set { setValue(newValue, forKey: Self.directoryPathsKey) }
    }
}

