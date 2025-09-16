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
    
    func updateInitialState() {
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
            switch currentButtonState {
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

    // Compute button state directly from app properties
    private var currentButtonState: UpdateButtonState {
        // If there's an active operation, use the view model state
        if viewModel.state == .progress || viewModel.state == .indeterminate || viewModel.state == .error {
            return viewModel.state
        }

        // Otherwise, compute state directly from app
        guard let app = app, showActionButton else {
            return .none
        }

        return app.updateAvailable ? .update : .open
    }
    
    @ViewBuilder
    private var actionButton: some View {
        Button(action: performAction) {
            HStack(spacing: 4) {
                if let image = buttonSystemImage {
                    Image(systemName: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 13, height: 13)
                }
                
                if !buttonTitle.isEmpty {
                    Text(buttonTitle)
                        .font(.system(size: 12, weight: .medium))
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
        switch currentButtonState {
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
    
    private var buttonSystemImage: String? {
        switch currentButtonState {
        case .error:
            return "exclamationmark.triangle.fill"
        default:
            return nil
        }
    }
    
    private var tintColor: Color {
        return .accentColor
    }
    
    private func performAction() {
        switch currentButtonState {
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

// MARK: - Pure SwiftUI Update Button Alias

typealias SwiftUIUpdateButton = SwiftUIUpdateButtonView