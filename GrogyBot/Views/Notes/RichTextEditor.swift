import SwiftUI
import UIKit

// MARK: - Formatter (Observable)

@MainActor
@Observable
final class RichTextFormatter {
    weak var textView: UITextView?

    var isBold = false
    var isItalic = false
    var isUnderline = false
    var isStrikethrough = false
    var currentHeading: HeadingLevel = .body

    enum HeadingLevel: String, CaseIterable {
        case title, heading, subheading, body

        var fontSize: CGFloat {
            switch self {
            case .title:      return 28
            case .heading:    return 22
            case .subheading: return 18
            case .body:       return 17
            }
        }

        var weight: UIFont.Weight {
            switch self {
            case .title:      return .bold
            case .heading:    return .semibold
            case .subheading: return .medium
            case .body:       return .regular
            }
        }

        var displayName: String {
            switch self {
            case .title:      return "Title"
            case .heading:    return "Heading"
            case .subheading: return "Subheading"
            case .body:       return "Body"
            }
        }
    }

    // MARK: - Formatting Commands

    func toggleBold() {
        guard let tv = textView else { return }
        toggleTrait(.traitBold, on: tv)
        updateState(from: tv)
    }

    func toggleItalic() {
        guard let tv = textView else { return }
        toggleTrait(.traitItalic, on: tv)
        updateState(from: tv)
    }

    func toggleUnderline() {
        guard let tv = textView else { return }
        let range = tv.selectedRange
        if range.length > 0 {
            let storage = tv.textStorage
            var hasUnderline = false
            storage.enumerateAttribute(.underlineStyle, in: range) { val, _, _ in
                if let v = val as? Int, v != 0 { hasUnderline = true }
            }
            storage.addAttribute(.underlineStyle,
                                 value: hasUnderline ? 0 : NSUnderlineStyle.single.rawValue,
                                 range: range)
        } else {
            var attrs = tv.typingAttributes
            let current = (attrs[.underlineStyle] as? Int) ?? 0
            attrs[.underlineStyle] = current == 0 ? NSUnderlineStyle.single.rawValue : 0
            tv.typingAttributes = attrs
        }
        updateState(from: tv)
    }

    func toggleStrikethrough() {
        guard let tv = textView else { return }
        let range = tv.selectedRange
        if range.length > 0 {
            let storage = tv.textStorage
            var hasStrike = false
            storage.enumerateAttribute(.strikethroughStyle, in: range) { val, _, _ in
                if let v = val as? Int, v != 0 { hasStrike = true }
            }
            storage.addAttribute(.strikethroughStyle,
                                 value: hasStrike ? 0 : NSUnderlineStyle.single.rawValue,
                                 range: range)
        } else {
            var attrs = tv.typingAttributes
            let current = (attrs[.strikethroughStyle] as? Int) ?? 0
            attrs[.strikethroughStyle] = current == 0 ? NSUnderlineStyle.single.rawValue : 0
            tv.typingAttributes = attrs
        }
        updateState(from: tv)
    }

    func setHeading(_ level: HeadingLevel) {
        guard let tv = textView else { return }
        let range = tv.selectedRange.length > 0 ? tv.selectedRange : currentLineRange(in: tv)
        let font = UIFont.systemFont(ofSize: level.fontSize, weight: level.weight)
        tv.textStorage.addAttribute(.font, value: font, range: range)
        tv.typingAttributes[.font] = font
        currentHeading = level
    }

    func insertBulletList() {
        insertListPrefix("•  ")
    }

    func insertNumberedList() {
        insertListPrefix("1.  ")
    }

    func insertChecklist() {
        insertListPrefix("☐  ")
    }

    func insertImage(_ image: UIImage) {
        guard let tv = textView else { return }
        let maxWidth = tv.textContainer.size.width - tv.textContainer.lineFragmentPadding * 2 - 20
        let scale = min(1.0, maxWidth / image.size.width)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(origin: .zero, size: newSize)

        let attrStr = NSMutableAttributedString(attachment: attachment)
        attrStr.append(NSAttributedString(string: "\n",
                                          attributes: [.font: UIFont.systemFont(ofSize: 17),
                                                       .foregroundColor: UIColor.white]))

        let loc = tv.selectedRange.location
        tv.textStorage.insert(attrStr, at: loc)
        tv.selectedRange = NSRange(location: loc + attrStr.length, length: 0)
    }

    // MARK: - State Sync

    func updateState(from tv: UITextView) {
        let attrs: [NSAttributedString.Key: Any]
        if tv.selectedRange.length > 0, tv.selectedRange.location < tv.textStorage.length {
            attrs = tv.textStorage.attributes(at: tv.selectedRange.location, effectiveRange: nil)
        } else {
            attrs = tv.typingAttributes
        }

        if let font = attrs[.font] as? UIFont {
            let traits = font.fontDescriptor.symbolicTraits
            isBold = traits.contains(.traitBold)
            isItalic = traits.contains(.traitItalic)

            // Detect heading level
            let size = font.pointSize
            if size >= 26 { currentHeading = .title }
            else if size >= 20 { currentHeading = .heading }
            else if size >= 18 { currentHeading = .subheading }
            else { currentHeading = .body }
        } else {
            isBold = false
            isItalic = false
            currentHeading = .body
        }

        isUnderline = ((attrs[.underlineStyle] as? Int) ?? 0) != 0
        isStrikethrough = ((attrs[.strikethroughStyle] as? Int) ?? 0) != 0
    }

    // MARK: - Helpers

    private func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits, on tv: UITextView) {
        let range = tv.selectedRange
        if range.length > 0 {
            let storage = tv.textStorage
            storage.enumerateAttribute(.font, in: range) { value, subRange, _ in
                guard let font = value as? UIFont else { return }
                let descriptor = font.fontDescriptor
                let traits = descriptor.symbolicTraits
                if traits.contains(trait) {
                    if let newDesc = descriptor.withSymbolicTraits(traits.subtracting(trait)) {
                        storage.addAttribute(.font, value: UIFont(descriptor: newDesc, size: font.pointSize), range: subRange)
                    }
                } else {
                    if let newDesc = descriptor.withSymbolicTraits(traits.union(trait)) {
                        storage.addAttribute(.font, value: UIFont(descriptor: newDesc, size: font.pointSize), range: subRange)
                    }
                }
            }
        } else {
            var attrs = tv.typingAttributes
            let font = (attrs[.font] as? UIFont) ?? UIFont.systemFont(ofSize: 17)
            let descriptor = font.fontDescriptor
            let traits = descriptor.symbolicTraits
            if traits.contains(trait) {
                if let newDesc = descriptor.withSymbolicTraits(traits.subtracting(trait)) {
                    attrs[.font] = UIFont(descriptor: newDesc, size: font.pointSize)
                }
            } else {
                if let newDesc = descriptor.withSymbolicTraits(traits.union(trait)) {
                    attrs[.font] = UIFont(descriptor: newDesc, size: font.pointSize)
                }
            }
            tv.typingAttributes = attrs
        }
    }

    private func currentLineRange(in tv: UITextView) -> NSRange {
        let text = tv.text as NSString
        return text.lineRange(for: tv.selectedRange)
    }

    private func insertListPrefix(_ prefix: String) {
        guard let tv = textView else { return }
        let loc = tv.selectedRange.location
        let text = tv.text as NSString

        // Find the start of the current line
        let lineRange = text.lineRange(for: NSRange(location: loc, length: 0))
        let lineStart = lineRange.location
        let lineText = text.substring(with: lineRange)

        // Check if this line already has this prefix
        let trimmed = lineText.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix(prefix.trimmingCharacters(in: .whitespaces)) {
            // Remove the prefix
            if let range = lineText.range(of: prefix) {
                let nsRange = NSRange(range, in: lineText)
                tv.textStorage.replaceCharacters(
                    in: NSRange(location: lineStart + nsRange.location, length: nsRange.length),
                    with: ""
                )
            }
        } else {
            // Add the prefix at the start of the line
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 17),
                .foregroundColor: UIColor.white
            ]
            let prefixAttr = NSAttributedString(string: prefix, attributes: attrs)

            // If cursor is at beginning of empty area, insert prefix + newline awareness
            if loc == tv.textStorage.length || text.substring(with: NSRange(location: loc, length: 0)).isEmpty {
                let insertStr = loc > 0 && text.character(at: loc - 1) != 10
                    ? NSAttributedString(string: "\n" + prefix, attributes: attrs)
                    : prefixAttr
                tv.textStorage.insert(insertStr, at: loc)
                tv.selectedRange = NSRange(location: loc + insertStr.length, length: 0)
            } else {
                tv.textStorage.insert(prefixAttr, at: lineStart)
                tv.selectedRange = NSRange(location: loc + prefix.count, length: 0)
            }
        }
    }
}

// MARK: - RichTextEditor View

struct RichTextEditor: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    var formatter: RichTextFormatter
    var placeholder: String

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.allowsEditingTextAttributes = true
        tv.isEditable = true
        tv.isScrollEnabled = false // let ScrollView handle scrolling
        tv.font = UIFont.systemFont(ofSize: 17)
        tv.textColor = .white
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        tv.textContainer.lineFragmentPadding = 0
        tv.autocorrectionType = .default
        tv.typingAttributes = [
            .font: UIFont.systemFont(ofSize: 17),
            .foregroundColor: UIColor.white
        ]

        // Set initial content
        if attributedText.length > 0 {
            tv.attributedText = attributedText
        }

        DispatchQueue.main.async {
            formatter.textView = tv
        }

        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        // Only update if the source changed externally (avoid feedback loop)
        if context.coordinator.isUpdating { return }
        if tv.attributedText != attributedText {
            tv.attributedText = attributedText
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        let parent: RichTextEditor
        var isUpdating = false

        init(_ parent: RichTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            isUpdating = true
            parent.attributedText = textView.attributedText
            isUpdating = false

            // Fix dark text from paste operations
            fixDarkText(in: textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            Task { @MainActor in
                parent.formatter.updateState(from: textView)
            }
        }

        // Handle checklist taps: toggle ☐ ↔ ☑
        func textView(_ textView: UITextView, shouldInteractWith textAttachment: NSTextAttachment, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
            return true
        }

        private func fixDarkText(in tv: UITextView) {
            let fullRange = NSRange(location: 0, length: tv.textStorage.length)
            tv.textStorage.enumerateAttribute(.foregroundColor, in: fullRange) { value, range, _ in
                if let color = value as? UIColor {
                    var white: CGFloat = 0
                    color.getWhite(&white, alpha: nil)
                    if white < 0.3 {
                        tv.textStorage.addAttribute(.foregroundColor, value: UIColor.white, range: range)
                    }
                }
            }
        }
    }
}
