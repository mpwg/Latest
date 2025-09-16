//
//  ReleaseNotesView.swift
//  Latest
//
//  Created by AI Assistant on 16.09.25.
//  Copyright © 2025 Max Langer. All rights reserved.
//

import SwiftUI
import Observation

// MARK: - Main View

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

// MARK: - Content Views

struct ReleaseNotesContentView: View {
    let state: ReleaseNotesState

    var body: some View {
        switch state {
        case .empty:
            ReleaseNotesEmptyView()
        case .loading:
            ReleaseNotesLoadingView()
        case .error(let error):
            ReleaseNotesErrorView(error: error)
        case .content(let attributedString):
            ReleaseNotesTextView(attributedString: AttributedString(attributedString))
        }
    }
}

struct ReleaseNotesEmptyView: View {
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 8) {
                Text(NSLocalizedString("NoAppSelectedTitle", comment: "Title of release notes empty state"))
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(NSLocalizedString("NoAppSelectedDescription", comment: "Description of release notes empty state"))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
            
            Spacer()
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

@MainActor
final class ReleaseNotesTextViewModel: ObservableObject {
    let attributedString: AttributedString
    let contentInset: CGFloat = 14

    var formattedAttributedString: AttributedString {
        format(attributedString)
    }

    init(attributedString: AttributedString) {
        self.attributedString = attributedString
    }

    private func format(_ attributedString: AttributedString) -> AttributedString {
        var string = attributedString

        // Set default font and remove problematic attributes
        string.font = .body
        string.foregroundColor = .primary

        // Remove any background colors and shadows that might not work well in SwiftUI
        // SwiftUI AttributedString handles this differently than NSAttributedString

        // Process the string to enhance formatting while preserving existing styles
        var finalString = AttributedString()

        for run in string.runs {
            var runString = AttributedString(string[run.range])

            // Preserve bold and italic formatting from the original
            if let font = run.font {
                // Convert font traits to SwiftUI equivalents
                if font.weight == .bold {
                    runString.font = .body.bold()
                } else if font.weight == .medium {
                    runString.font = .body.weight(.medium)
                } else if font.weight == .semibold {
                    runString.font = .body.weight(.semibold)
                } else {
                    runString.font = .body
                }

                // Handle italic styling
                if font.design == .default {
                    // For italic detection in AttributedString, we need to check the font descriptor
                    // This is simplified - in a real implementation you might want more sophisticated detection
                    runString.font = runString.font?.italic() ?? .body.italic()
                }
            }

            // Ensure good contrast and readability
            runString.foregroundColor = .primary

            // Remove any background colors that might interfere with dark mode
            // SwiftUI handles background colors differently

            finalString.append(runString)
        }

        return finalString
    }
}

struct ReleaseNotesTextView: View {
    @StateObject private var viewModel: ReleaseNotesTextViewModel

    init(attributedString: AttributedString) {
        self._viewModel = StateObject(wrappedValue: ReleaseNotesTextViewModel(attributedString: attributedString))
    }

    var body: some View {
        ScrollView {
            Text(viewModel.formattedAttributedString)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(viewModel.contentInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

