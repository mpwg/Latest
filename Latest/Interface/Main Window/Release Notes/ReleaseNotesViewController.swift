//
//  UpdateDetailsViewController.swift
//  Latest
//
//  Created by Max Langer on 26.02.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa
import WebKit
import SwiftUI
import Combine


/**
 This is a super rudimentary implementation of an release notes viewer.
 It can open urls or display HTML strings right away.
 */
class ReleaseNotesViewController: NSViewController {
    
    @IBOutlet weak var appInfoBackgroundView: NSVisualEffectView!
    @IBOutlet weak var appInfoContentView: NSStackView!
    
    @IBOutlet weak var updateButton: UpdateButton!
	@IBOutlet weak var externalUpdateLabel: NSTextField!
    
    @IBOutlet weak var appNameTextField: NSTextField!
    @IBOutlet weak var appDateTextField: NSTextField!
    @IBOutlet weak var appVersionTextField: NSTextField!
    @IBOutlet weak var appIconImageView: NSImageView!
	
	/// Button indicating the support state of a given app.
	@IBOutlet private weak var supportStateButton: NSButton!
	
	/// The app currently presented
	private(set) var app: App? {
		didSet {
			// Forward app
			self.updateButton.app = self.app
		}
	}

    /// SwiftUI content view and hosting controller
    private var swiftUIViewModel = ReleaseNotesSwiftUIViewModel()
    private var swiftUIHostingController: NSHostingController<ReleaseNotesView>?

    // MARK: - View Lifecycle
    
    override func viewWillAppear() {
        super.viewWillAppear()

        let constraint = NSLayoutConstraint(item: self.appInfoContentView!, attribute: .top, relatedBy: .equal, toItem: self.view.window?.contentLayoutGuide, attribute: .top, multiplier: 1.0, constant: 0)
        constraint.isActive = true

        self.setupSwiftUIContent()
		self.setEmptyState()
	}
	
    
    
    // MARK: - Actions
    
    @objc func update(_ sender: NSButton) {
        self.app?.performUpdate()
    }
	
	@objc func cancelUpdate(_ sender: NSButton) {
		self.app?.cancelUpdate()
	}
    
    
    // MARK: - Display Methods
    
    /**
     Loads the content of the URL and displays them
     - parameter content: The content to be displayed
     */
	func display(releaseNotesFor app: App?) {
        self.display(app)
        self.setupSwiftUIContent()
        self.swiftUIViewModel.loadReleaseNotes(for: app)
    }
	
    
    // MARK: - User Interface Stuff
	
	/// Date formatter used to display the apps update date.
	private lazy var appDateFormatter: DateFormatter = {
		let dateFormatter = DateFormatter()
		dateFormatter.dateStyle = .long
		dateFormatter.timeStyle = .none
		
		return dateFormatter
	}()
    
    private func display(_ app: App?) {
        guard let app = app else {
            self.app = nil
            self.appInfoBackgroundView.isHidden = true
            self.updateSwiftUILayout()
            return
        }

		// Update header
        self.appInfoBackgroundView.isHidden = false
        self.app = app
        self.appNameTextField.stringValue = app.name
        
		// Version Information
        if let versionInformation = app.localizedVersionInformation {
			self.appVersionTextField.stringValue = versionInformation.combined(includeNew: app.updateAvailable)
		}
		
		// Support state
		self.supportStateButton.isHidden = !(AppListSettings.shared.includeUnsupportedApps || AppListSettings.shared.includeAppsWithLimitedSupport)
		if !self.supportStateButton.isHidden {
			self.supportStateButton.title = app.source.supportState.compactLabel
			self.supportStateButton.image = app.source.supportState.statusImage
		}
		
		// Icon
		IconCache.shared.icon(for: app) { (image) in
			self.appIconImageView.image = image
		}
		
		// Date
		if let date = app.latestUpdateDate {
            self.appDateTextField.stringValue = appDateFormatter.string(from: date)
            self.appDateTextField.isHidden = false
        } else {
            self.appDateTextField.isHidden = true
        }
		
		// Update Action
		if app.updateAvailable, let name = app.externalUpdaterName {
			externalUpdateLabel.stringValue = String(format: NSLocalizedString("ExternalUpdateActionWithAppName", comment: "An explanatory text indicating where the update will be performed. The placeholder will be filled with the name of the external updater (App Store, App Name). The text will appear below the Update button, so that it reads: \"Update in XY\""), name)
		} else {
			externalUpdateLabel.stringValue = ""
		}
        

        self.updateInsets()
        self.updateSwiftUILayout()
    }

    private func setupSwiftUIContent() {
        // Only set up once
        guard swiftUIHostingController == nil else { return }

        // Create SwiftUI hosting controller with the view model
        let contentView = ReleaseNotesView(viewModel: swiftUIViewModel)
        let hostingController = NSHostingController(rootView: contentView)

        // Configure hosting controller for proper sizing - use constraints, not intrinsic size
        hostingController.sizingOptions = []

        swiftUIHostingController = hostingController

        addChild(hostingController)
        view.addSubview(hostingController.view)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        // Set up initial constraints - will be updated in updateSwiftUILayout
        self.updateSwiftUILayout()
    }

    private var swiftUIConstraints: [NSLayoutConstraint] = []

    private func updateSwiftUILayout() {
        guard let hostingController = swiftUIHostingController else { return }

        // Remove old constraints
        NSLayoutConstraint.deactivate(swiftUIConstraints)
        swiftUIConstraints.removeAll()

        let topAnchor = app == nil ? view.topAnchor : appInfoBackgroundView.bottomAnchor

        swiftUIConstraints = [
            topAnchor.constraint(equalTo: hostingController.view.topAnchor, constant: 0),
            view.bottomAnchor.constraint(equalTo: hostingController.view.bottomAnchor, constant: 0),
            view.leadingAnchor.constraint(equalTo: hostingController.view.leadingAnchor, constant: 0),
            view.trailingAnchor.constraint(equalTo: hostingController.view.trailingAnchor, constant: 0)
        ]

        NSLayoutConstraint.activate(swiftUIConstraints)
    }
	
	private func setEmptyState() {
        self.display(releaseNotesFor: nil)
	}
    /// Updates the top inset of the release notes scrollView - now handled by SwiftUI layout
    private func updateInsets() {
        // No longer needed with SwiftUI implementation
    }
	
	// MARK: - Navigation
	
	override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
		switch segue.identifier {
		case "presentSupportStateInfo":
			guard let controller = segue.destinationController as? SupportStatusInfoViewController else { fatalError("Unknown controller for segue \(String(describing: segue.identifier))")}
			controller.app = self.app
		default:
			break
		}
	}

}

// MARK: - SwiftUI Implementation

enum ReleaseNotesState {
    case empty
    case loading
    case error(Error)
    case content(NSAttributedString)
}

@MainActor
final class ReleaseNotesSwiftUIViewModel: ObservableObject {
    @Published var state: ReleaseNotesState = .loading
    @Published var app: App?

    private let releaseNotesProvider = ReleaseNotesProvider()
    private var loadingTimer: Timer?

    func loadReleaseNotes(for app: App?) {
        guard let app = app else {
            // Show empty state error for no app selected
            let error = LatestError.custom(
                title: NSLocalizedString("NoAppSelectedTitle", comment: "Title of release notes empty state"),
                description: NSLocalizedString("NoAppSelectedDescription", comment: "Description of release notes empty state")
            )
            self.state = .error(error)
            self.app = nil
            return
        }

        self.app = app

        // Cancel any existing timer
        loadingTimer?.invalidate()

        // Delay the loading screen to avoid flickering
        loadingTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.state = .loading
            }
        }

        releaseNotesProvider.releaseNotes(for: app) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                self.loadingTimer?.invalidate()

                // Only update if this is still the current app
                guard self.app == app else { return }

                switch result {
                case .success(let attributedString):
                    self.state = .content(attributedString)
                case .failure(let error):
                    self.state = .error(error)
                }
            }
        }
    }

    deinit {
        loadingTimer?.invalidate()
    }
}

// MARK: - App Info Header View

struct AppInfoHeaderView: View {
    let app: App
    @State private var appIcon: NSImage?
    @State private var showingSupportStatus = false

    private static let appDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        return dateFormatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // App Icon
                Group {
                    if let appIcon = appIcon {
                        Image(nsImage: appIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.quaternary)
                            .overlay(
                                Image(systemName: "app.dashed")
                                    .foregroundColor(.secondary)
                            )
                    }
                }
                .frame(width: 48, height: 48)
                .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    // App Name
                    Text(app.name)
                        .font(.headline)
                        .lineLimit(1)

                    // Version Information
                    if let versionInfo = app.localizedVersionInformation {
                        Text(versionInfo.combined(includeNew: app.updateAvailable))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    // Update Date
                    if let date = app.latestUpdateDate {
                        Text(Self.appDateFormatter.string(from: date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(spacing: 8) {
                    // Update Button - Simplified placeholder for now
                    Button("Update") {
                        app.performUpdate()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    // External Update Label
                    if app.updateAvailable, let externalUpdaterName = app.externalUpdaterName {
                        Text("Update in \(externalUpdaterName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Support Status Button (if enabled)
            if shouldShowSupportStatus {
                HStack {
                    Button(action: {
                        showingSupportStatus = true
                    }) {
                        HStack(spacing: 6) {
                            Image(nsImage: app.source.supportState.statusImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)

                            Text(app.source.supportState.compactLabel)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            loadAppIcon()
        }
        .onChange(of: app) { _, _ in
            loadAppIcon()
        }
        .sheet(isPresented: $showingSupportStatus) {
            SupportStatusInfoView(app: app)
        }
    }

    private var shouldShowSupportStatus: Bool {
        AppListSettings.shared.includeUnsupportedApps || AppListSettings.shared.includeAppsWithLimitedSupport
    }

    private func loadAppIcon() {
        IconCache.shared.icon(for: app) { icon in
            DispatchQueue.main.async {
                self.appIcon = icon
            }
        }
    }
}

// MARK: - Support Status Info View

struct SupportStatusInfoView: View {
    let app: App
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(nsImage: app.source.supportState.statusImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)

                Text(app.source.supportState.label)
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button("Done") {
                    dismiss()
                }
            }

            // Description
            Text(supportStateDescription)
                .font(.body)
                .foregroundColor(.secondary)

            // Report Issue Button (only for full support)
            if case .full = app.source.supportState {
                Button("Report Issue") {
                    NSWorkspace.shared.open(URL(string: "https://github.com/mangerlahn/Latest/issues")!)
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .padding()
        .frame(width: 400, height: 200)
    }

    private var supportStateDescription: String {
        switch app.source.supportState {
        case .none:
            return NSLocalizedString("NoSupportDescription", comment: "Description for apps without support.")
        case .limited:
            return NSLocalizedString("LimitedSupportDescription", comment: "Description for apps with limited support.")
        case .full:
            return NSLocalizedString("FullSupportDescription", comment: "Description for apps with full support.")
        }
    }
}

struct ReleaseNotesView: View {
    @ObservedObject var viewModel: ReleaseNotesSwiftUIViewModel

    var body: some View {
        VStack(spacing: 0) {
            if let app = viewModel.app {
                AppInfoHeaderView(app: app)
                    .background(.regularMaterial)

                Divider()
            }

            ReleaseNotesContentView(state: viewModel.state)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ReleaseNotesContentView: View {
    let state: ReleaseNotesState

    var body: some View {
        Group {
            switch state {
            case .empty:
                EmptyView()
            case .loading:
                ReleaseNotesLoadingView()
            case .error(let error):
                ReleaseNotesErrorView(error: error)
            case .content(let attributedString):
                ReleaseNotesTextView(attributedString: attributedString)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ReleaseNotesLoadingView: View {
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .controlSize(.regular)
                Spacer()
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ReleaseNotesErrorView: View {
    let error: Error

    var body: some View {
        VStack(spacing: 8) {
            Spacer()

            VStack(alignment: .center, spacing: 8) {
                if let localizedError = error as? LocalizedError,
                   let failureReason = localizedError.failureReason {
                    Text(localizedError.localizedDescription)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)

                    Text(failureReason)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text(error.localizedDescription)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ReleaseNotesTextView: View {
    let attributedString: NSAttributedString
    let contentInset: CGFloat = 14

    var body: some View {
        AttributedTextView(attributedString: formattedAttributedString)
            .padding(contentInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var formattedAttributedString: NSAttributedString {
        format(attributedString)
    }

    private func format(_ attributedString: NSAttributedString) -> NSAttributedString {
        let string = NSMutableAttributedString(attributedString: attributedString)
        let textRange = NSMakeRange(0, attributedString.length)
        let defaultFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)

        // Fix foreground color
        string.removeAttribute(.foregroundColor, range: textRange)
        string.addAttribute(.foregroundColor, value: NSColor.labelColor, range: textRange)

        // Remove background color
        string.removeAttribute(.backgroundColor, range: textRange)

        // Remove shadows
        string.removeAttribute(.shadow, range: textRange)

        // Reset font
        string.removeAttribute(.font, range: textRange)
        string.addAttribute(.font, value: defaultFont, range: textRange)

        // Copy traits like italic and bold
        attributedString.enumerateAttribute(NSAttributedString.Key.font, in: textRange, options: .reverse) { (fontObject, range, stopPointer) in
            guard let font = fontObject as? NSFont else { return }

            let traits = font.fontDescriptor.symbolicTraits
            let fontDescriptor = defaultFont.fontDescriptor.withSymbolicTraits(traits)
            if let font = NSFont(descriptor: fontDescriptor, size: defaultFont.pointSize) {
                string.addAttribute(.font, value: font, range: range)
            }
        }

        return string
    }
}

struct AttributedTextView: NSViewRepresentable {
    let attributedString: NSAttributedString

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.allowsUndo = false
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        // Ensure scrollView expands to fill available space
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        textView.textStorage?.setAttributedString(attributedString)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        return proposal.replacingUnspecifiedDimensions(by: CGSize(width: 400, height: 300))
    }
}

// MARK: - SwiftUI Update Button

struct SwiftUIUpdateButtonView: View {
    let app: App?
    let showActionButton: Bool

    init(app: App?, showActionButton: Bool = true) {
        self.app = app
        self.showActionButton = showActionButton
    }

    var body: some View {
        Group {
            if let app = app, showActionButton {
                Button(action: {
                    // Simple action - could be enhanced later
                    print("Update button tapped for \(app.name)")
                }) {
                    Text("Update")
                        .font(.system(size: 11))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                EmptyView()
            }
        }
    }
}