import SwiftUI
import AppKit
import UniformTypeIdentifiers

extension UTType {

    static let mdonnaMarkdown =
        UTType(
            importedAs:
                "net.daringfireball.markdown",
            conformingTo:
                .plainText
        )
}

@MainActor
final class MDonnaDocument:
    ObservableObject
{

    @Published
    var text: String = "" {

        didSet {

            guard !isLoading else {
                return
            }

            if text != lastSavedText {
                isEdited = true
            }
        }
    }

    @Published
    private(set)
    var fileURL: URL?

    @Published
    private(set)
    var isEdited = false

    private var
        isLoading = false

    private var
        lastSavedText = ""

    var displayTitle: String {

        if let fileURL {

            return fileURL
                .deletingPathExtension()
                .lastPathComponent
        }

        return "Untitled"
    }

    var windowTitle: String {

        if isEdited {
            return displayTitle + " — Edited"
        }

        return displayTitle
    }

    func load(
        from url: URL
    ) throws {

        let contents =
            try String(
                contentsOf: url,
                encoding: .utf8
            )

        isLoading = true

        text = contents
        fileURL = url
        lastSavedText = contents
        isEdited = false

        isLoading = false
    }

    @discardableResult
    func save() -> Bool {

        if let fileURL {
            return write(
                to: fileURL
            )
        }

        return saveAs()
    }

    @discardableResult
    func saveAs() -> Bool {

        let panel =
            NSSavePanel()

        panel.allowedContentTypes = [
            .mdonnaMarkdown
        ]

        panel.allowsOtherFileTypes =
            false

        panel.isExtensionHidden =
            false

        panel.canCreateDirectories =
            true

        var suggestedName =
            displayTitle

        if suggestedName
            .lowercased()
            .hasSuffix(".md")
        {

            suggestedName =
                String(
                    suggestedName
                        .dropLast(3)
                )
        }

        panel.nameFieldStringValue =
            suggestedName + ".md"

        guard
            panel.runModal() == .OK,
            var targetURL =
                panel.url
        else {
            return false
        }

        if targetURL
            .pathExtension
            .lowercased()
            != "md"
        {

            targetURL =
                targetURL
                    .appendingPathExtension(
                        "md"
                    )
        }

        return write(
            to: targetURL
        )
    }

    @discardableResult
    private func write(
        to url: URL
    ) -> Bool {

        do {

            try text.write(
                to: url,
                atomically: true,
                encoding: .utf8
            )

            fileURL = url
            lastSavedText = text
            isEdited = false

            return true

        } catch {

            showError(
                title:
                    "Could not save file",
                error:
                    error
            )

            return false
        }
    }

    func confirmClosing() -> Bool {

        guard isEdited else {
            return true
        }

        let alert =
            NSAlert()

        alert.messageText =
            "Do you want to save the changes to “\(displayTitle)”?"

        alert.informativeText =
            "Your changes will be lost if you don't save them."

        alert.alertStyle =
            .warning

        alert.addButton(
            withTitle:
                "Save"
        )

        alert.addButton(
            withTitle:
                "Cancel"
        )

        alert.addButton(
            withTitle:
                "Don't Save"
        )

        switch alert.runModal() {

        case .alertFirstButtonReturn:
            return save()

        case .alertThirdButtonReturn:
            return true

        default:
            return false
        }
    }

    func showError(
        title: String,
        error: Error
    ) {

        let alert =
            NSAlert()

        alert.messageText =
            title

        alert.informativeText =
            error.localizedDescription

        alert.alertStyle =
            .critical

        alert.runModal()
    }
}

struct EditorView:
    View
{

    @ObservedObject
    var document:
        MDonnaDocument

    var body: some View {

        WebEditor(
            text:
                $document.text,
            fileURL:
                document.fileURL
        )
        .frame(
            minWidth: 720,
            minHeight: 520
        )
        .background(
            WindowConfigurator(
                title:
                    document.windowTitle
            )
        )
    }
}

@MainActor
final class MDonnaWindowController:
    NSWindowController,
    NSWindowDelegate
{

    let mdonnaDocument:
        MDonnaDocument

    weak var appOwner:
        MDonnaAppDelegate?

    var allowCloseWithoutPrompt =
        false

    init(
        document: MDonnaDocument,
        owner: MDonnaAppDelegate
    ) {

        self.mdonnaDocument =
            document

        self.appOwner =
            owner

        let rootView =
            EditorView(
                document:
                    document
            )

        let hostingController =
            NSHostingController(
                rootView:
                    rootView
            )

        let window =
            NSWindow(
                contentRect:
                    NSRect(
                        x: 0,
                        y: 0,
                        width: 1000,
                        height: 700
                    ),
                styleMask: [
                    .titled,
                    .closable,
                    .miniaturizable,
                    .resizable
                ],
                backing:
                    .buffered,
                defer:
                    false
            )

        window.contentViewController =
            hostingController

        window.title =
            document.windowTitle

        window.minSize =
            NSSize(
                width: 720,
                height: 520
            )

        window.isReleasedWhenClosed =
            false

        window.center()

        super.init(
            window:
                window
        )

        window.delegate =
            self
    }

    required init?(
        coder: NSCoder
    ) {
        fatalError(
            "init(coder:) has not been implemented"
        )
    }

    func windowShouldClose(
        _ sender: NSWindow
    ) -> Bool {

        if allowCloseWithoutPrompt {
            return true
        }

        return mdonnaDocument
            .confirmClosing()
    }

    func windowWillClose(
        _ notification:
            Notification
    ) {

        appOwner?
            .removeWindowController(
                self
            )
    }
}

@MainActor
final class MDonnaAppDelegate:
    NSObject,
    NSApplicationDelegate
{

    private var
        windowControllers:
            [MDonnaWindowController] = []

    private var
        receivedLaunchFile =
            false

    func applicationWillFinishLaunching(
        _ notification:
            Notification
    ) {

        installMainMenu()
    }

    func application(
        _ sender: NSApplication,
        openFiles filenames: [String]
    ) {

        receivedLaunchFile =
            true

        var failed =
            false

        for filename in filenames {

            let url =
                URL(
                    fileURLWithPath:
                        filename
                )

            if !openFile(
                at: url
            ) {
                failed = true
            }
        }

        sender.reply(
            toOpenOrPrint:
                failed
                    ? .failure
                    : .success
        )
    }

    func applicationShouldOpenUntitledFile(
        _ sender:
            NSApplication
    ) -> Bool {

        false
    }

    func applicationDidFinishLaunching(
        _ notification:
            Notification
    ) {

        if
            !receivedLaunchFile &&
            windowControllers.isEmpty
        {
            createUntitledWindow()
        }

        NSApp.setActivationPolicy(
            .regular
        )

        NSApp.activate(
            ignoringOtherApps:
                true
        )
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {

        if
            !flag &&
            windowControllers.isEmpty
        {
            createUntitledWindow()
        }

        return true
    }

    func applicationShouldTerminate(
        _ sender:
            NSApplication
    ) -> NSApplication.TerminateReply {

        for controller
            in windowControllers
        {

            if !controller
                .mdonnaDocument
                .confirmClosing()
            {
                return .terminateCancel
            }
        }

        for controller
            in windowControllers
        {
            controller
                .allowCloseWithoutPrompt =
                    true
        }

        return .terminateNow
    }

    func createUntitledWindow() {

        let document =
            MDonnaDocument()

        showWindow(
            for:
                document
        )
    }

    @discardableResult
    private func openFile(
        at url: URL
    ) -> Bool {

        if let existing =
            windowControllers
                .first(
                    where: {
                        $0.mdonnaDocument.fileURL
                            == url
                    }
                )
        {

            existing.window?
                .makeKeyAndOrderFront(
                    nil
                )

            return true
        }

        let document =
            MDonnaDocument()

        do {

            try document.load(
                from: url
            )

            showWindow(
                for:
                    document
            )

            return true

        } catch {

            document.showError(
                title:
                    "Could not open file",
                error:
                    error
            )

            return false
        }
    }

    private func showWindow(
        for document:
            MDonnaDocument
    ) {

        let controller =
            MDonnaWindowController(
                document:
                    document,
                owner:
                    self
            )

        windowControllers
            .append(
                controller
            )

        controller
            .showWindow(
                nil
            )

        controller
            .window?
            .makeKeyAndOrderFront(
                nil
            )

        NSApp.activate(
            ignoringOtherApps:
                true
        )
    }

    func removeWindowController(
        _ controller:
            MDonnaWindowController
    ) {

        windowControllers
            .removeAll {
                $0 === controller
            }
    }

    private var activeController:
        MDonnaWindowController?
    {

        if let keyWindow =
            NSApp.keyWindow
        {

            if let controller =
                windowControllers
                    .first(
                        where: {
                            $0.window
                                === keyWindow
                        }
                    )
            {
                return controller
            }
        }

        if let mainWindow =
            NSApp.mainWindow
        {

            return windowControllers
                .first(
                    where: {
                        $0.window
                            === mainWindow
                    }
                )
        }

        return nil
    }

    @objc
    private func newDocumentAction(
        _ sender: Any?
    ) {

        createUntitledWindow()
    }

    @objc
    private func openDocumentAction(
        _ sender: Any?
    ) {

        let panel =
            NSOpenPanel()

        panel.allowedContentTypes = [
            .mdonnaMarkdown,
            .plainText
        ]

        panel.allowsMultipleSelection =
            true

        panel.canChooseDirectories =
            false

        panel.canChooseFiles =
            true

        guard
            panel.runModal() == .OK
        else {
            return
        }

        for url
            in panel.urls
        {
            _ = openFile(
                at: url
            )
        }
    }

    @objc
    private func saveDocumentAction(
        _ sender: Any?
    ) {

        _ = activeController?
            .mdonnaDocument
            .save()
    }

    @objc
    private func saveDocumentAsAction(
        _ sender: Any?
    ) {

        _ = activeController?
            .mdonnaDocument
            .saveAs()
    }

    @objc
    private func closeWindowAction(
        _ sender: Any?
    ) {

        activeController?
            .window?
            .performClose(
                sender
            )
    }

    private func installMainMenu() {

        let mainMenu =
            NSMenu()

        let appMenuItem =
            NSMenuItem()

        mainMenu.addItem(
            appMenuItem
        )

        let appMenu =
            NSMenu()

        appMenuItem.submenu =
            appMenu

        appMenu.addItem(
            withTitle:
                "About MDonna",
            action:
                #selector(
                    NSApplication
                        .orderFrontStandardAboutPanel(
                            _:
                        )
                ),
            keyEquivalent:
                ""
        )

        appMenu.addItem(
            NSMenuItem.separator()
        )

        let hideItem =
            appMenu.addItem(
                withTitle:
                    "Hide MDonna",
                action:
                    #selector(
                        NSApplication
                            .hide(
                                _:
                            )
                    ),
                keyEquivalent:
                    "h"
            )

        hideItem.target =
            NSApp

        let hideOthers =
            appMenu.addItem(
                withTitle:
                    "Hide Others",
                action:
                    #selector(
                        NSApplication
                            .hideOtherApplications(
                                _:
                            )
                    ),
                keyEquivalent:
                    "h"
            )

        hideOthers
            .keyEquivalentModifierMask = [
                .command,
                .option
            ]

        hideOthers.target =
            NSApp

        let showAll =
            appMenu.addItem(
                withTitle:
                    "Show All",
                action:
                    #selector(
                        NSApplication
                            .unhideAllApplications(
                                _:
                            )
                    ),
                keyEquivalent:
                    ""
            )

        showAll.target =
            NSApp

        appMenu.addItem(
            NSMenuItem.separator()
        )

        let quitItem =
            appMenu.addItem(
                withTitle:
                    "Quit MDonna",
                action:
                    #selector(
                        NSApplication
                            .terminate(
                                _:
                            )
                    ),
                keyEquivalent:
                    "q"
            )

        quitItem.target =
            NSApp

        let fileMenuItem =
            NSMenuItem()

        fileMenuItem.title =
            "File"

        mainMenu.addItem(
            fileMenuItem
        )

        let fileMenu =
            NSMenu(
                title:
                    "File"
            )

        fileMenuItem.submenu =
            fileMenu

        let newItem =
            fileMenu.addItem(
                withTitle:
                    "New",
                action:
                    #selector(
                        newDocumentAction(
                            _:
                        )
                    ),
                keyEquivalent:
                    "n"
            )

        newItem.target =
            self

        let openItem =
            fileMenu.addItem(
                withTitle:
                    "Open…",
                action:
                    #selector(
                        openDocumentAction(
                            _:
                        )
                    ),
                keyEquivalent:
                    "o"
            )

        openItem.target =
            self

        fileMenu.addItem(
            NSMenuItem.separator()
        )

        let saveItem =
            fileMenu.addItem(
                withTitle:
                    "Save",
                action:
                    #selector(
                        saveDocumentAction(
                            _:
                        )
                    ),
                keyEquivalent:
                    "s"
            )

        saveItem.target =
            self

        let saveAsItem =
            fileMenu.addItem(
                withTitle:
                    "Save As…",
                action:
                    #selector(
                        saveDocumentAsAction(
                            _:
                        )
                    ),
                keyEquivalent:
                    "s"
            )

        saveAsItem
            .keyEquivalentModifierMask = [
                .command,
                .shift
            ]

        saveAsItem.target =
            self

        fileMenu.addItem(
            NSMenuItem.separator()
        )

        let closeItem =
            fileMenu.addItem(
                withTitle:
                    "Close",
                action:
                    #selector(
                        closeWindowAction(
                            _:
                        )
                    ),
                keyEquivalent:
                    "w"
            )

        closeItem.target =
            self

        let editMenuItem =
            NSMenuItem()

        editMenuItem.title =
            "Edit"

        mainMenu.addItem(
            editMenuItem
        )

        let editMenu =
            NSMenu(
                title:
                    "Edit"
            )

        editMenuItem.submenu =
            editMenu

        editMenu.addItem(
            withTitle:
                "Undo",
            action:
                Selector(
                    ("undo:")
                ),
            keyEquivalent:
                "z"
        )

        let redo =
            editMenu.addItem(
                withTitle:
                    "Redo",
                action:
                    Selector(
                        ("redo:")
                    ),
                keyEquivalent:
                    "z"
            )

        redo
            .keyEquivalentModifierMask = [
                .command,
                .shift
            ]

        editMenu.addItem(
            NSMenuItem.separator()
        )

        editMenu.addItem(
            withTitle:
                "Cut",
            action:
                #selector(
                    NSText.cut(
                        _:
                    )
                ),
            keyEquivalent:
                "x"
        )

        editMenu.addItem(
            withTitle:
                "Copy",
            action:
                #selector(
                    NSText.copy(
                        _:
                    )
                ),
            keyEquivalent:
                "c"
        )

        editMenu.addItem(
            withTitle:
                "Paste",
            action:
                #selector(
                    NSText.paste(
                        _:
                    )
                ),
            keyEquivalent:
                "v"
        )

        editMenu.addItem(
            withTitle:
                "Select All",
            action:
                #selector(
                    NSText.selectAll(
                        _:
                    )
                ),
            keyEquivalent:
                "a"
        )

        let windowMenuItem =
            NSMenuItem()

        windowMenuItem.title =
            "Window"

        mainMenu.addItem(
            windowMenuItem
        )

        let windowMenu =
            NSMenu(
                title:
                    "Window"
            )

        windowMenuItem.submenu =
            windowMenu

        windowMenu.addItem(
            withTitle:
                "Minimize",
            action:
                #selector(
                    NSWindow
                        .performMiniaturize(
                            _:
                        )
                ),
            keyEquivalent:
                "m"
        )

        windowMenu.addItem(
            withTitle:
                "Zoom",
            action:
                #selector(
                    NSWindow
                        .performZoom(
                            _:
                        )
                ),
            keyEquivalent:
                ""
        )

        windowMenu.addItem(
            NSMenuItem.separator()
        )

        let bringAll =
            windowMenu.addItem(
                withTitle:
                    "Bring All to Front",
                action:
                    #selector(
                        NSApplication
                            .arrangeInFront(
                                _:
                            )
                    ),
                keyEquivalent:
                    ""
            )

        bringAll.target =
            NSApp

        NSApp.mainMenu =
            mainMenu

        NSApp.windowsMenu =
            windowMenu
    }
}

@main
struct MDonnaMain {

    @MainActor
    private static var
        appDelegate:
            MDonnaAppDelegate?

    @MainActor
    static func main() {

        let application =
            NSApplication.shared

        let delegate =
            MDonnaAppDelegate()

        appDelegate =
            delegate

        application.delegate =
            delegate

        application.setActivationPolicy(
            .regular
        )

        application.run()
    }
}
