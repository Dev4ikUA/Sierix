import Cocoa

// MARK: - Rounded view (colors follow Dark Mode automatically)

final class RoundedView: NSView {
    var fillColor: NSColor = .clear { didSet { needsDisplay = true } }
    var strokeColor: NSColor? { didSet { needsDisplay = true } }
    var cornerRadius: CGFloat = 12 { didSet { needsDisplay = true } }
    
    override var wantsUpdateLayer: Bool { return true }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLayer() {
        guard let layer = layer else { return }
        layer.cornerRadius = cornerRadius
        layer.backgroundColor = fillColor.cgColor
        layer.borderWidth = strokeColor == nil ? 0 : 1
        layer.borderColor = strokeColor?.cgColor
    }
}

// MARK: - Minimal markdown renderer (headings, bullets, **bold**, `code`, ``` blocks)

enum Markdown {
    private static let inlineRegex = try! NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*|`([^`]+)`", options: [])
    private static let bulletRegex = try! NSRegularExpression(pattern: "^\\s*[\\*\\-]\\s+", options: [])
    
    static func render(_ source: String, color: NSColor) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let bodyFont = NSFont.systemFont(ofSize: 14)
        let monoFont = NSFont.userFixedPitchFont(ofSize: 13) ?? bodyFont
        let lines = source.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n")
        var inCode = false
        
        for (index, rawLine) in lines.enumerated() {
            var line = rawLine
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("```") {
                inCode.toggle()
                continue
            }
            
            let piece: NSMutableAttributedString
            let hashes = trimmed.prefix(while: { $0 == "#" }).count
            
            if inCode {
                piece = NSMutableAttributedString(string: line, attributes: [
                    .font: monoFont,
                    .foregroundColor: color,
                    .backgroundColor: NSColor.quaternaryLabelColor
                    ])
            } else if hashes > 0 && hashes <= 4 && trimmed.dropFirst(hashes).hasPrefix(" ") {
                let title = trimmed.dropFirst(hashes).trimmingCharacters(in: .whitespaces)
                let size: CGFloat = hashes == 1 ? 20 : (hashes == 2 ? 17 : 15)
                piece = inline(title, font: NSFont.boldSystemFont(ofSize: size), color: color)
            } else {
                let ns = line as NSString
                if let m = bulletRegex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: ns.length)) {
                    let indent = String(line.prefix(while: { $0 == " " }))
                    line = indent + "•  " + ns.substring(from: m.range.length)
                }
                piece = inline(line, font: bodyFont, color: color)
            }
            
            result.append(piece)
            if index < lines.count - 1 {
                result.append(NSAttributedString(string: "\n", attributes: [.font: bodyFont]))
            }
        }
        
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 3
        result.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: result.length))
        return result
    }
    
    private static func inline(_ s: String, font: NSFont, color: NSColor) -> NSMutableAttributedString {
        let out = NSMutableAttributedString()
        let ns = s as NSString
        let bold = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        let mono = NSFont.userFixedPitchFont(ofSize: font.pointSize - 1) ?? font
        var last = 0
        
        for m in inlineRegex.matches(in: s, options: [], range: NSRange(location: 0, length: ns.length)) {
            if m.range.location > last {
                let plain = ns.substring(with: NSRange(location: last, length: m.range.location - last))
                out.append(NSAttributedString(string: plain, attributes: [.font: font, .foregroundColor: color]))
            }
            if m.range(at: 1).location != NSNotFound {
                out.append(NSAttributedString(string: ns.substring(with: m.range(at: 1)),
                                              attributes: [.font: bold, .foregroundColor: color]))
            } else {
                out.append(NSAttributedString(string: ns.substring(with: m.range(at: 2)),
                                              attributes: [.font: mono, .foregroundColor: color,
                                                           .backgroundColor: NSColor.quaternaryLabelColor]))
            }
            last = NSMaxRange(m.range)
        }
        if last < ns.length {
            out.append(NSAttributedString(string: ns.substring(from: last),
                                          attributes: [.font: font, .foregroundColor: color]))
        }
        return out
    }
}

// MARK: - One chat message row

final class MessageRowView: NSView {
    private let label = NSTextField(wrappingLabelWithString: "")
    private let isUser: Bool
    
    init(text: NSAttributedString, isUser: Bool) {
        self.isUser = isUser
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        
        label.translatesAutoresizingMaskIntoConstraints = false
        label.maximumNumberOfLines = 0
        label.attributedStringValue = text
        
        if isUser {
            // Right-aligned blue bubble that hugs the text
            let bubble = RoundedView(frame: .zero)
            bubble.fillColor = .systemBlue
            bubble.cornerRadius = 16
            bubble.translatesAutoresizingMaskIntoConstraints = false
            addSubview(bubble)
            bubble.addSubview(label)
            NSLayoutConstraint.activate([
                bubble.topAnchor.constraint(equalTo: topAnchor),
                bubble.bottomAnchor.constraint(equalTo: bottomAnchor),
                bubble.trailingAnchor.constraint(equalTo: trailingAnchor),
                bubble.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
                label.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 9),
                label.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -9),
                label.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 14),
                label.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -14)
                ])
        } else {
            // Gemini answers: plain text over the full width
            addSubview(label)
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: topAnchor),
                label.bottomAnchor.constraint(equalTo: bottomAnchor),
                label.leadingAnchor.constraint(equalTo: leadingAnchor),
                label.trailingAnchor.constraint(equalTo: trailingAnchor)
                ])
        }
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        let available = bounds.width
        if available > 0 {
            let maxWidth = isUser ? max(120, available * 0.78) - 28 : available
            if label.preferredMaxLayoutWidth != maxWidth {
                label.preferredMaxLayoutWidth = maxWidth
            }
        }
        super.layout()
    }
}

private final class FlippedView: NSView {
    override var isFlipped: Bool { return true }
}

// MARK: - Main view controller (UI built entirely in code, no XIB needed)

@objc(ViewController)
class ViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    
    let client = GeminiClient(apiKey: Config.geminiAPIKey ?? "")
    
    private let chatsTableView = NSTableView()
    private let inputField = NSTextField()
    private let sendButton = NSButton()
    private let scrollView = NSScrollView()
    private let documentView = FlippedView()
    private let messagesStack = NSStackView()
    private let emptyLabel = NSTextField(labelWithString: "How can I help?")
    
    private var waitingSessionID: String?
    private var isSyncingSelection = false
    
    // MARK: Build UI
    
    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 980, height: 640))
        view = root
        
        // ---------- Sidebar ----------
        let sidebar = NSVisualEffectView()
        sidebar.material = .sidebar
        sidebar.blendingMode = .behindWindow
        sidebar.state = .followsWindowActiveState
        
        let logo = NSImageView()
        logo.image = NSImage(named: NSImage.Name("gemini_banner"))
        logo.imageScaling = .scaleProportionallyDown
        
        let newChat = NSButton(title: "＋  New chat", target: self, action: #selector(newChatClicked(_:)))
        newChat.bezelStyle = .rounded
        
        let deleteChat = NSButton(title: "Delete chat", target: self, action: #selector(deleteChatClicked(_:)))
        deleteChat.bezelStyle = .rounded
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("chat"))
        column.resizingMask = .autoresizingMask
        chatsTableView.addTableColumn(column)
        chatsTableView.headerView = nil
        chatsTableView.backgroundColor = .clear
        chatsTableView.selectionHighlightStyle = .sourceList
        chatsTableView.rowHeight = 32
        chatsTableView.dataSource = self
        chatsTableView.delegate = self
        
        let chatsScroll = NSScrollView()
        chatsScroll.documentView = chatsTableView
        chatsScroll.drawsBackground = false
        chatsScroll.hasVerticalScroller = true
        chatsScroll.autohidesScrollers = true
        chatsScroll.borderType = .noBorder
        
        // ---------- Main area ----------
        let main = NSView()
        
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView
        
        messagesStack.orientation = .vertical
        messagesStack.alignment = .leading
        messagesStack.spacing = 20
        documentView.addSubview(messagesStack)
        
        emptyLabel.font = NSFont.systemFont(ofSize: 28, weight: .semibold)
        emptyLabel.textColor = .secondaryLabelColor
        
        let inputBox = RoundedView(frame: .zero)
        inputBox.fillColor = .controlBackgroundColor
        inputBox.strokeColor = .separatorColor
        inputBox.cornerRadius = 14
        
        inputField.isBordered = false
        inputField.isBezeled = false
        inputField.drawsBackground = false
        inputField.focusRingType = .none
        inputField.font = NSFont.systemFont(ofSize: 14)
        inputField.placeholderString = "Ask Gemini…"
        inputField.cell?.usesSingleLineMode = true
        inputField.cell?.isScrollable = true
        inputField.target = self
        inputField.action = #selector(sendClicked(_:))
        
        sendButton.title = "Send"
        sendButton.bezelStyle = .rounded
        sendButton.target = self
        sendButton.action = #selector(sendClicked(_:))
        
        inputBox.addSubview(inputField)
        inputBox.addSubview(sendButton)
        main.addSubview(scrollView)
        main.addSubview(emptyLabel)
        main.addSubview(inputBox)
        
        sidebar.addSubview(logo)
        sidebar.addSubview(newChat)
        sidebar.addSubview(chatsScroll)
        sidebar.addSubview(deleteChat)
        root.addSubview(sidebar)
        root.addSubview(main)
        
        let manual: [NSView] = [sidebar, logo, newChat, deleteChat, chatsScroll, main, scrollView,
                                messagesStack, emptyLabel, inputBox, inputField, sendButton]
        manual.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        
        // Keeps content in a centered column, max 760pt wide
        func capWidth(_ v: NSView, within c: NSView, margin: CGFloat) -> [NSLayoutConstraint] {
            let w = v.widthAnchor.constraint(equalToConstant: 760)
            w.priority = .defaultHigh
            return [
                w,
                v.centerXAnchor.constraint(equalTo: c.centerXAnchor),
                v.leadingAnchor.constraint(greaterThanOrEqualTo: c.leadingAnchor, constant: margin),
                v.trailingAnchor.constraint(lessThanOrEqualTo: c.trailingAnchor, constant: -margin)
            ]
        }
        
        NSLayoutConstraint.activate([
            // sidebar
            sidebar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: root.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 250),
            
            logo.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 18),
            logo.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 16),
            logo.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -16),
            logo.heightAnchor.constraint(equalToConstant: 44),
            
            newChat.topAnchor.constraint(equalTo: logo.bottomAnchor, constant: 14),
            newChat.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 16),
            newChat.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -16),
            
            chatsScroll.topAnchor.constraint(equalTo: newChat.bottomAnchor, constant: 12),
            chatsScroll.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 8),
            chatsScroll.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -8),
            chatsScroll.bottomAnchor.constraint(equalTo: deleteChat.topAnchor, constant: -12),
            
            deleteChat.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 16),
            deleteChat.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -16),
            deleteChat.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -16),
            
            // main area
            main.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            main.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            main.topAnchor.constraint(equalTo: root.topAnchor),
            main.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            
            scrollView.topAnchor.constraint(equalTo: main.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: main.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: main.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: inputBox.topAnchor, constant: -12),
            
            documentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            documentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            documentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            
            messagesStack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 24),
            messagesStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -24),
            
            emptyLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
            
            inputBox.bottomAnchor.constraint(equalTo: main.bottomAnchor, constant: -20),
            inputBox.heightAnchor.constraint(equalToConstant: 48),
            
            sendButton.trailingAnchor.constraint(equalTo: inputBox.trailingAnchor, constant: -8),
            sendButton.centerYAnchor.constraint(equalTo: inputBox.centerYAnchor),
            
            inputField.leadingAnchor.constraint(equalTo: inputBox.leadingAnchor, constant: 16),
            inputField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
            inputField.centerYAnchor.constraint(equalTo: inputBox.centerYAnchor)
            ])
        NSLayoutConstraint.activate(capWidth(messagesStack, within: documentView, margin: 28))
        NSLayoutConstraint.activate(capWidth(inputBox, within: main, margin: 28))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        renderAll()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(inputField)
    }
    
    // MARK: Sidebar (NSTableView, view-based)
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return client.sessions.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("ChatCell")
        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: id, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = id
            let tf = NSTextField(labelWithString: "")
            tf.translatesAutoresizingMaskIntoConstraints = false
            tf.lineBreakMode = .byTruncatingTail
            tf.font = NSFont.systemFont(ofSize: 13)
            cell.addSubview(tf)
            cell.textField = tf
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                tf.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
                ])
        }
        cell.textField?.stringValue = row < client.sessions.count ? client.sessions[row].title : ""
        return cell
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !isSyncingSelection else { return }
        let row = chatsTableView.selectedRow
        guard row >= 0, row < client.sessions.count, row != client.currentSessionIndex else { return }
        client.currentSessionIndex = row
        renderMessages()
    }
    
    // MARK: Rendering
    
    private func renderAll() {
        reloadSidebar()
        renderMessages()
    }
    
    private func reloadSidebar() {
        isSyncingSelection = true
        chatsTableView.reloadData()
        if client.currentSessionIndex < client.sessions.count {
            chatsTableView.selectRowIndexes(IndexSet(integer: client.currentSessionIndex), byExtendingSelection: false)
        }
        isSyncingSelection = false
    }
    
    private func renderMessages() {
        for v in messagesStack.arrangedSubviews {
            messagesStack.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
        guard client.currentSessionIndex < client.sessions.count else { return }
        
        let session = client.sessions[client.currentSessionIndex]
        let waitingHere = (waitingSessionID == session.id)
        emptyLabel.isHidden = !(session.messages.isEmpty && !waitingHere)
        
        for msg in session.messages {
            addRow(for: msg)
        }
        if waitingHere {
            let t = NSAttributedString(string: "Gemini is thinking…", attributes: [
                .font: NSFont.systemFont(ofSize: 14),
                .foregroundColor: NSColor.secondaryLabelColor
                ])
            append(MessageRowView(text: t, isUser: false))
        }
        scrollToBottom()
    }
    
    private func addRow(for msg: ChatMessage) {
        let row: MessageRowView
        if msg.role == "user" {
            let t = NSAttributedString(string: msg.text, attributes: [
                .font: NSFont.systemFont(ofSize: 14),
                .foregroundColor: NSColor.white
                ])
            row = MessageRowView(text: t, isUser: true)
        } else if msg.text.hasPrefix("Error:") {
            let t = NSAttributedString(string: msg.text, attributes: [
                .font: NSFont.systemFont(ofSize: 13),
                .foregroundColor: NSColor.systemRed
                ])
            row = MessageRowView(text: t, isUser: false)
        } else {
            row = MessageRowView(text: Markdown.render(msg.text, color: NSColor.labelColor), isUser: false)
        }
        append(row)
    }
    
    private func append(_ row: MessageRowView) {
        messagesStack.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: messagesStack.widthAnchor).isActive = true
    }
    
    private func scrollToBottom() {
        DispatchQueue.main.async {
            self.view.layoutSubtreeIfNeeded()
            self.view.layoutSubtreeIfNeeded()
            let clip = self.scrollView.contentView
            let y = max(0, self.documentView.frame.height - clip.bounds.height)
            clip.scroll(to: NSPoint(x: 0, y: y))
            self.scrollView.reflectScrolledClipView(clip)
        }
    }
    
    // MARK: Actions
    
    @objc func sendClicked(_ sender: Any) {
        let prompt = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, waitingSessionID == nil,
            client.currentSessionIndex < client.sessions.count else { return }
        
        inputField.stringValue = ""
        sendButton.isEnabled = false
        waitingSessionID = client.sessions[client.currentSessionIndex].id
        
        client.sendPrompt(prompt) { [weak self] _, error in
            guard let self = self else { return }
            self.waitingSessionID = nil
            self.sendButton.isEnabled = true
            if let error = error {
                self.client.addMessageToCurrentSession("model", text: "Error: \(error.localizedDescription)")
            }
            self.renderAll()
            self.view.window?.makeFirstResponder(self.inputField)
        }
        renderAll()   // показує повідомлення користувача і індикатор "думає…"
    }
    
    @objc func newChatClicked(_ sender: Any) {
        client.createNewSession()
        renderAll()
        view.window?.makeFirstResponder(inputField)
    }
    
    @objc func deleteChatClicked(_ sender: Any) {
        client.deleteCurrentSession()
        renderAll()
    }
}
