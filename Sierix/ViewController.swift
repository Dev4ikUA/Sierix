import Cocoa

@objc(ViewController)
class ViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    
    @IBOutlet weak var inputTextField: NSTextField!
    @IBOutlet var outputTextView: NSTextView!
    @IBOutlet weak var sendButton: NSButton!
    @IBOutlet weak var chatsTableView: NSTableView!
    @IBOutlet weak var logoImageView: NSImageView!
    @IBOutlet weak var bannerImageView: NSImageView!
    
    let client = GeminiClient(apiKey: "AIzaSyCed0u2IfZsoL4TbRVDiCerA4WYUnnk1wE")
    
    private var didSetup = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        guard !didSetup else { return }
        didSetup = true
        
        // 1. Завантажуємо лого-зірочку
        if let logo = NSImage(named: "gemini_logo") {
            logoImageView?.image = logo
            logoImageView?.imageScaling = .ScaleProportionallyDown
            logoImageView?.imageAlignment = .AlignCenter
        }
        
        // 2. Завантажуємо банер
        if let banner = NSImage(named: "gemini_banner") {
            bannerImageView?.image = banner
            bannerImageView?.imageScaling = .ScaleProportionallyDown
            bannerImageView?.imageAlignment = .AlignCenter
        }
        
        // 3. Налаштування поля введення (Enter)
        inputTextField.target = self
        inputTextField.action = #selector(sendClicked(_:))
        
        outputTextView.textContainerInset = NSSize(width: 15, height: 15)
        
        if let column = chatsTableView.tableColumns.first {
            let cell = NSTextFieldCell()
            cell.font = NSFont.systemFontOfSize(12)
            column.dataCell = cell
        }
        
        renderCurrentSession()
    }
    
    // --- NSTableView DataSource & Delegate ---
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return client.sessions.count
    }
    
    func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
        guard row < client.sessions.count else { return "" }
        return client.sessions[row].title
    }
    
    func tableViewSelectionDidChange(notification: NSNotification) {
        let selectedRow = chatsTableView.selectedRow
        if selectedRow >= 0 && selectedRow < client.sessions.count {
            client.currentSessionIndex = selectedRow
            renderCurrentSession()
        }
    }
    
    // --- Логіка відмалювання ---
    
    func renderCurrentSession() {
        guard client.currentSessionIndex < client.sessions.count else { return }
        
        let currentSession = client.sessions[client.currentSessionIndex]
        let attrString = NSMutableAttributedString()
        
        for msg in currentSession.messages {
            let isUser = (msg.role == "user")
            let prefix = isUser ? "Ви:\n" : "Gemini:\n"
            let color = isUser ? NSColor(calibratedRed: 0.1, green: 0.45, blue: 0.85, alpha: 1.0) : NSColor(calibratedRed: 0.85, green: 0.25, blue: 0.4, alpha: 1.0)
            
            let headerAttr: [String: AnyObject] = [
                NSFontAttributeName: NSFont.boldSystemFontOfSize(12),
                NSForegroundColorAttributeName: color
            ]
            let textAttr: [String: AnyObject] = [
                NSFontAttributeName: NSFont.systemFontOfSize(13),
                NSForegroundColorAttributeName: NSColor.blackColor()
            ]
            
            attrString.appendAttributedString(NSAttributedString(string: prefix, attributes: headerAttr))
            attrString.appendAttributedString(NSAttributedString(string: "\(msg.text)\n\n", attributes: textAttr))
        }
        
        outputTextView.textStorage?.setAttributedString(attrString)
        outputTextView.scrollToEndOfDocument(nil)
        
        chatsTableView.reloadData()
        chatsTableView.selectRowIndexes(NSIndexSet(index: client.currentSessionIndex), byExtendingSelection: false)
    }
    
    // Приймає AnyObject, щоб працювати і від кнопки, і від Enter у NSTextField
    @IBAction func sendClicked(sender: AnyObject) {
        let prompt = inputTextField.stringValue
        guard !prompt.isEmpty else { return }
        
        inputTextField.stringValue = ""
        sendButton.enabled = false
        
        client.sendPrompt(prompt) { (resultString, error) in
            dispatch_async(dispatch_get_main_queue()) {
                print("result: \(resultString), error: \(error)")
                self.sendButton.enabled = true
                if let error = error {
                    self.client.addMessageToCurrentSession("model", text: "Помилка: \(error.localizedDescription)")
                }
                self.renderCurrentSession()
            }
        }
        renderCurrentSession()   // після sendPrompt, щоб показати твоє повідомлення
    }
    
    @IBAction func newChatClicked(sender: AnyObject) {
        client.createNewSession()
        renderCurrentSession()
    }
    
    @IBAction func deleteChatClicked(sender: AnyObject) {
        client.deleteCurrentSession()
        renderCurrentSession()
    }
}