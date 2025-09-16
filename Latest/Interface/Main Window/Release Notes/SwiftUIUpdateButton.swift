//
//  SwiftUIUpdateButton.swift
//  Latest
//
//  Created by AI Assistant on 16.09.25.
//  Copyright © 2025 Max Langer. All rights reserved.
//

import SwiftUI
import Observation

// MARK: - SwiftUI Update Button

@MainActor
@Observable
final class UpdateButtonViewModel {
    var state: UpdateButtonState = .none
    var progress: Double = 0.0
    var error: Error?
    
    private var app: App?
    private var showActionButton: Bool = true
    
    init(app: App?, showActionButton: Bool = true) {
        self.app = app
        self.showActionButton = showActionButton
        setupUpdateObserver()
    }
    
    func setApp(_ app: App?, showActionButton: Bool = true) {
        // Remove observer from existing app
        if let oldApp = self.app {
            UpdateQueue.shared.removeObserver(self, for: oldApp.identifier)
        }
        
        self.app = app
        self.showActionButton = showActionButton
        setupUpdateObserver()
    }
    
    private func setupUpdateObserver() {
        if let app = self.app {
            UpdateQueue.shared.addObserver(self, to: app.identifier) { [weak self] progressState in
                DispatchQueue.main.async {
                    self?.updateInterface(with: progressState)
                }
            }
        }
        
        // Update initial state
        updateInitialState()
    }
    
    private func updateInitialState() {
        if let app = self.app, self.showActionButton {
            self.state = app.updateAvailable ? .update : .open
        } else {
            self.state = .none
        }
    }
    
    private func updateInterface(with progressState: UpdateOperation.ProgressState) {
        switch progressState {
        case .none:
            updateInitialState()
            
        case .pending, .initializing, .cancelling:
            self.state = .indeterminate
            
        case .downloading(let loadedSize, let totalSize):
            self.state = .progress
            self.progress = (Double(loadedSize) / Double(totalSize)) * 0.75
            
        case .extracting(let progressValue):
            self.state = .progress
            self.progress = 0.75 + (progressValue * 0.25)
            
        case .installing:
            self.state = .indeterminate
            
        case .error(let error):
            self.state = self.showActionButton ? .error : .none
            self.error = error
        }
    }
    
    deinit {
        if let app = self.app {
            UpdateQueue.shared.removeObserver(self, for: app.identifier)
        }
    }
}

enum UpdateButtonState {
    case none
    case update
    case open
    case progress
    case indeterminate
    case error
}

struct SwiftUIUpdateButtonView: View {
    let app: App?
    let showActionButton: Bool
    
    @State private var viewModel: UpdateButtonViewModel
    @State private var showingErrorAlert = false
    
    init(app: App?, showActionButton: Bool = true) {
        self.app = app
        self.showActionButton = showActionButton
        self._viewModel = State(initialValue: UpdateButtonViewModel(app: app, showActionButton: showActionButton))
    }
    
    var body: some View {
        Group {
            switch viewModel.state {
            case .none:
                EmptyView()
                
            case .update, .open, .error:
                actionButton
                
            case .progress:
                progressIndicator
                
            case .indeterminate:
                indeterminateIndicator
            }
        }
        .onChange(of: app) { _, newApp in
            viewModel.setApp(newApp, showActionButton: showActionButton)
        }
        .alert("Update Error", isPresented: $showingErrorAlert) {
            Button("Retry") {
                app?.performUpdate()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let app = app, let error = viewModel.error {
                Text(String.localizedStringWithFormat(
                    NSLocalizedString("UpdateErrorAlertTitle", comment: "Title of alert stating that an error occurred during an app update. The placeholder %@ will be replaced with the name of the app."),
                    app.name
                ))
                Text(error.localizedDescription)
            }
        }
    }
    
    @ViewBuilder
    private var actionButton: some View {
        Button(action: performAction) {
            HStack(spacing: 4) {
                if let image = buttonImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 13, height: 13)
                }
                
                if !buttonTitle.isEmpty {
                    Text(buttonTitle)
                        .font(.system(size: NSFont.systemFontSize - 1, weight: .medium))
                }
            }
        }
        .buttonStyle(UpdateButtonStyle())
    }
    
    @ViewBuilder
    private var progressIndicator: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 2.5)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: viewModel.progress)
                .stroke(tintColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.2), value: viewModel.progress)
            
            // Cancel button
            Button(action: cancelAction) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(tintColor)
                    .frame(width: 6, height: 6)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 25, height: 21)
    }
    
    @ViewBuilder
    private var indeterminateIndicator: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: tintColor))
            .controlSize(.mini)
            .frame(width: 25, height: 21)
    }
    
    private var buttonTitle: String {
        let title: String
        switch viewModel.state {
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
        switch viewModel.state {
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
    
    private func performAction() {
        switch viewModel.state {
        case .update:
            app?.performUpdate()
        case .open:
            app?.open()
        case .progress:
            app?.cancelUpdate()
        case .error:
            showingErrorAlert = true
        default:
            break
        }
    }
    
    private func cancelAction() {
        app?.cancelUpdate()
    }
}

// MARK: - Button Style

struct UpdateButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 10.5)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .foregroundColor(.primary)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        let baseColor = Color(red: 0.9488552213, green: 0.9487094283, blue: 0.9693081975)
        return isPressed ? baseColor.opacity(0.8) : baseColor
    }
}

// MARK: - NSViewRepresentable Wrapper for Legacy Code

struct SwiftUIUpdateButton: NSViewRepresentable {
    let app: App?
    let showActionButton: Bool

    init(app: App?, showActionButton: Bool = true) {
        self.app = app
        self.showActionButton = showActionButton
    }

    func makeNSView(context: Context) -> UpdateButton {
        let button = UpdateButton()
        button.showActionButton = showActionButton
        return button
    }

    func updateNSView(_ nsView: UpdateButton, context: Context) {
        nsView.app = app
        nsView.showActionButton = showActionButton
    }
}