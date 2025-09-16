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
            ReleaseNotesTextView(attributedString: attributedString)
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
    let attributedString: NSAttributedString
    let contentInset: CGFloat = 14

    var formattedAttributedString: NSAttributedString {
        format(attributedString)
    }

    init(attributedString: NSAttributedString) {
        self.attributedString = attributedString
    }

    private func format(_ attributedString: NSAttributedString) -> NSAttributedString {
        let string = NSMutableAttributedString(attributedString: attributedString)
        let textRange = NSMakeRange(0, attributedString.length)
        let defaultFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)

        string.removeAttribute(.foregroundColor, range: textRange)
        string.addAttribute(.foregroundColor, value: NSColor.labelColor, range: textRange)

        string.removeAttribute(.backgroundColor, range: textRange)
        string.removeAttribute(.shadow, range: textRange)

        string.removeAttribute(.font, range: textRange)
        string.addAttribute(.font, value: defaultFont, range: textRange)

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

struct ReleaseNotesTextView: View {
    @StateObject private var viewModel: ReleaseNotesTextViewModel

    init(attributedString: NSAttributedString) {
        self._viewModel = StateObject(wrappedValue: ReleaseNotesTextViewModel(attributedString: attributedString))
    }

    var body: some View {
        AttributedTextView(attributedString: viewModel.formattedAttributedString)
            .padding(viewModel.contentInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Attributed Text View Wrapper

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