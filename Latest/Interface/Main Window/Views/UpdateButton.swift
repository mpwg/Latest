//
//  UpdateButton.swift
//  Latest
//
//  Created by Max Langer on 1.12.20.
//  Copyright © 2020 Max Langer. All rights reserved.
//

import SwiftUI
import AppKit

/// The button controlling and displaying the entire update procedure.
/// Now powered by SwiftUI while maintaining the original API.
class UpdateButton: NSButton {

    /// Internal state that represents the current display mode
    private enum InterfaceState {
        /// No update progress should be shown.
        case none

        /// A state where the update button should be shown.
        case update

        /// A state where the open button should be shown.
        case open

        /// A progress bar should be shown.
        case progress

        /// An indeterminate progress should be shown.
        case indeterminate

        /// An error should be shown.
        case error
    }

    /// Whether an action button such as "Open" or "Update" should be displayed
    @IBInspectable var showActionButton: Bool = true {
        didSet {
            updateHostingView()
        }
    }

    /// The app for which update progress should be displayed.
    var app: App? {
        willSet {
            // Remove observer from existing app
            if let app = self.app {
                UpdateQueue.shared.removeObserver(self, for: app.identifier)
            }
        }

        didSet {
            if let app = self.app {
                UpdateQueue.shared.addObserver(self, to: app.identifier) { [weak self] progress in
                    DispatchQueue.main.async {
                        self?.updateInterface(with: progress)
                    }
                }
            } else {
                self.isHidden = true
            }
            updateHostingView()
            self.invalidateIntrinsicContentSize()
        }
    }

    /// The background color for this button. Animatable.
    @objc dynamic var backgroundColor: NSColor = NSColor(red: 0.9488552213, green: 0.9487094283, blue: 0.9693081975, alpha: 1) {
        didSet {
            updateHostingView()
        }
    }

    private var hostingView: NSHostingView<AnyView>?
    private var interfaceState: InterfaceState = .none
    private var progress: Double = 0.0
    private var error: Error?

    // MARK: - Initialization

    override func awakeFromNib() {
        super.awakeFromNib()
        setupHostingView()
    }

    deinit {
        if let app = self.app {
            UpdateQueue.shared.removeObserver(self, for: app.identifier)
        }
    }

    private func setupHostingView() {
        self.target = self
        self.action = #selector(performAction(_:))
        self.isBordered = false
        self.title = ""

        if #available(OSX 10.14, *) {
            self.contentTintColor = .controlAccentColor
        }

        updateHostingView()
    }

    private func updateHostingView() {
        // Remove existing hosting view
        hostingView?.removeFromSuperview()

        // Create SwiftUI view based on current state
        let swiftUIView = createSwiftUIView()

        // Create hosting view
        hostingView = NSHostingView(rootView: AnyView(swiftUIView))
        guard let hostingView = hostingView else { return }

        // Configure hosting view
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        // Add as subview
        addSubview(hostingView)

        // Set up constraints to fill the button
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: self.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
    }

    @ViewBuilder
    private func createSwiftUIView() -> some View {
        switch interfaceState {
        case .none:
            EmptyView()
        case .update, .open, .error:
            actionButtonView
        case .progress:
            progressIndicatorView
        case .indeterminate:
            indeterminateIndicatorView
        }
    }

    @ViewBuilder
    private var actionButtonView: some View {
        Button(action: performSwiftUIAction) {
            HStack(spacing: 4) {
                if let image = buttonImage {
                    Image(nsImage: image)
                        .foregroundStyle(tintColor)
                }
                if !buttonTitle.isEmpty {
                    Text(buttonTitle)
                        .font(.system(size: NSFont.systemFontSize - 1, weight: .medium))
                        .foregroundStyle(tintColor)
                }
            }
            .padding(.horizontal, buttonTitle.isEmpty ? 2 : 8)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10.5)
                .fill(Color(backgroundColor))
        )
        .frame(height: 21)
    }

    @ViewBuilder
    private var progressIndicatorView: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color(NSColor.tertiaryLabelColor), lineWidth: 2.5)
                .frame(width: 16.8, height: 16.8)

            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tintColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 16.8, height: 16.8)

            // Cancel button (pause icon)
            RoundedRectangle(cornerRadius: 2)
                .fill(tintColor)
                .frame(width: 6, height: 6)
        }
        .frame(width: 25, height: 21)
        .contentShape(Rectangle())
        .onTapGesture { [weak self] in
            self?.performSwiftUIAction()
        }
    }

    @ViewBuilder
    private var indeterminateIndicatorView: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(tintColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(0))
                .frame(width: 16.8, height: 16.8)
                .rotationEffect(.degrees(.random(in: 0...360)))
                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: UUID())
        }
        .frame(width: 25, height: 21)
    }

    // MARK: - Interface Updates

    private func updateInterface(with state: UpdateOperation.ProgressState) {
        switch state {
        case .none:
            if let app = self.app, self.showActionButton {
                updateInterfaceVisibility(with: app.updateAvailable ? .update : .open)
            } else {
                updateInterfaceVisibility(with: .none)
            }

        case .pending:
            updateInterfaceVisibility(with: .indeterminate)

        case .initializing:
            updateInterfaceVisibility(with: .indeterminate)

        case .downloading(let loadedSize, let totalSize):
            updateInterfaceVisibility(with: .progress)
            progress = (Double(loadedSize) / Double(totalSize)) * 0.75

        case .extracting(let progressValue):
            updateInterfaceVisibility(with: .progress)
            progress = 0.75 + (progressValue * 0.25)

        case .installing:
            updateInterfaceVisibility(with: .indeterminate)

        case .error(let error):
            updateInterfaceVisibility(with: self.showActionButton ? .error : .none)
            self.error = error

        case .cancelling:
            updateInterfaceVisibility(with: .indeterminate)
        }
    }

    private func updateInterfaceVisibility(with state: InterfaceState) {
        self.isHidden = (state == .none)

        guard self.interfaceState != state else {
            return
        }

        self.interfaceState = state
        updateHostingView()

        // Invalidate intrinsic content size when state changes
        self.invalidateIntrinsicContentSize()
    }

    // MARK: - Computed Properties

    private var buttonTitle: String {
        let title: String
        switch interfaceState {
        case .update:
            title = NSLocalizedString("UpdateAction", comment: "Action to update a given app.")
        case .open:
            title = NSLocalizedString("OpenAction", comment: "Action to open a given app.")
        default:
            title = ""
        }

        // Beginning with macOS 14, the button text is no longer uppercase
        if #available(macOS 14.0, *) {
            return title
        } else {
            return title.localizedUppercase
        }
    }

    private var buttonImage: NSImage? {
        switch interfaceState {
        case .error:
            if #available(macOS 11.0, *) {
                return NSImage(systemSymbolName: "exclamationmark.triangle.fill",
                              accessibilityDescription: NSLocalizedString("ErrorButtonAccessibilityTitle",
                                                                         comment: "Description of button that opens an error dialogue."))
            } else {
                return NSImage(named: "warning")
            }
        default:
            return nil
        }
    }

    private var tintColor: Color {
        if #available(macOS 10.14, *) {
            return Color(NSColor.controlAccentColor)
        } else {
            return Color(NSColor.systemBlue)
        }
    }

    // MARK: - Intrinsic Content Size

    override var intrinsicContentSize: NSSize {
        switch interfaceState {
        case .none:
            return NSSize(width: 0, height: 0)

        case .update, .open, .error:
            // Calculate size based on text content
            let title = buttonTitle
            if !title.isEmpty {
                let font = NSFont.systemFont(ofSize: NSFont.systemFontSize - 1, weight: .medium)
                let textSize = title.size(withAttributes: [.font: font])
                let padding: CGFloat = 16 // 8 pixels on each side
                let width = ceil(textSize.width) + padding
                return NSSize(width: max(width, 60), height: 21)
            } else {
                // Icon-only button
                return NSSize(width: 25, height: 21)
            }

        case .progress, .indeterminate:
            // Progress/spinner indicators are square-ish
            return NSSize(width: 25, height: 21)
        }
    }

    // MARK: - Actions

    @objc func performAction(_ sender: UpdateButton) {
        performSwiftUIAction()
    }

    private func performSwiftUIAction() {
        switch interfaceState {
        case .update:
            app?.performUpdate()
        case .open:
            app?.open()
        case .progress:
            app?.cancelUpdate()
        case .error:
            presentError()
        default:
            break
        }
    }

    private func presentError() {
        guard let error = self.error,
              let window = self.window else { return }

        let alert = NSAlert()
        alert.alertStyle = .informational

        let message = NSLocalizedString("UpdateErrorAlertTitle",
                                       comment: "Title of alert stating that an error occurred during an app update. The placeholder %@ will be replaced with the name of the app.")
        alert.messageText = String.localizedStringWithFormat(message, app?.name ?? "")
        alert.informativeText = error.localizedDescription

        alert.addButton(withTitle: NSLocalizedString("RetryAction",
                                                    comment: "Button to retry an update in an error dialogue"))
        alert.addButton(withTitle: NSLocalizedString("CancelAction",
                                                    comment: "Cancel button in an update dialogue"))

        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn {
                self.app?.performUpdate()
            }
        }
    }
}

// MARK: - Animator Proxy
extension UpdateButton {
    override func animation(forKey key: NSAnimatablePropertyKey) -> Any? {
        switch key {
        case "backgroundColor":
            return CABasicAnimation()
        default:
            return super.animation(forKey: key)
        }
    }
}