import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Markdown file type

extension UTType {

    static var mdonnaMarkdown: UTType {

        UTType(
            filenameExtension: "md",
            conformingTo: .plainText
        )
        ?? .plainText
    }
}


// MARK: - Document controller

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


    private var isLoading = false

    private var lastSavedText = ""


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


    // MARK: New

    func newDocument() {

        guard confirmReplacingDocument() else {
            return
        }

        isLoading = true

        text = ""
        fileURL = nil
        lastSavedText = ""

        isEdited = false

        isLoading = false
    }


    // MARK: Open

    func openDocument() {

        guard confirmReplacingDocument() else {
            return
        }

        let panel =
            NSOpenPanel()

        panel.allowedContentTypes = [
            .mdonnaMarkdown,
            .plainText
        ]

        panel.allowsMultipleSelection =
            false

        panel.canChooseDirectories =
            false

        panel.canChooseFiles =
            true


        guard
            panel.runModal() == .OK,
            let url = panel.url
        else {
            return
        }


        do {

            let contents =
                try String(
                    contentsOf: url,
                    encoding: .utf8
                )

            isLoading = true

            text = contents

            fileURL = url

            lastSavedText =
                contents

            isEdited =
                false

            isLoading =
                false

        } catch {

            showError(
                title:
                    "Could not open file",
                error:
                    error
            )
        }
    }


    // MARK: Save

    @discardableResult
    func save() -> Bool {

        if let fileURL {

            return write(
                to: fileURL
            )
        }

        return saveAs()
    }


    // MARK: Save As

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
            .hasSuffix(".md") {

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


        /*
         Guarantee the .md extension ourselves.

         We do not rely on DocumentGroup or NSSavePanel
         deciding whether to append it.
        */

        if targetURL
            .pathExtension
            .lowercased()
            != "md" {

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


    // MARK: Writing

    private func write(
        to url: URL
    ) -> Bool {

        do {

            try text.write(
                to: url,
                atomically: true,
                encoding: .utf8
            )

            fileURL =
                url

            lastSavedText =
                text

            isEdited =
                false

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


    // MARK: Application termination

    func confirmApplicationTermination() -> Bool {

        return confirmReplacingDocument()
    }


    // MARK: Unsaved changes

    private func confirmReplacingDocument() -> Bool {

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
            withTitle: "Save"
        )

        alert.addButton(
            withTitle: "Cancel"
        )

        alert.addButton(
            withTitle: "Don't Save"
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


    // MARK: Error

    private func showError(
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


// MARK: - Editor

struct EditorView: View {

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


// MARK: - Focused document

private struct MDonnaDocumentFocusedKey:
    FocusedValueKey
{
    typealias Value =
        MDonnaDocument
}


extension FocusedValues {

    var mdonnaDocument:
        MDonnaDocument?
    {
        get {
            self[
                MDonnaDocumentFocusedKey.self
            ]
        }

        set {
            self[
                MDonnaDocumentFocusedKey.self
            ] = newValue
        }
    }
}


// MARK: - Open-document registry

@MainActor
private final class WeakMDonnaDocument {

    weak var value:
        MDonnaDocument?


    init(
        _ value: MDonnaDocument
    ) {

        self.value =
            value
    }
}


@MainActor
final class MDonnaDocumentRegistry {

    static let shared =
        MDonnaDocumentRegistry()


    private var documents:
        [
            ObjectIdentifier:
                WeakMDonnaDocument
        ] = [:]


    private init() {}


    func register(
        _ document:
            MDonnaDocument
    ) {

        purge()

        documents[
            ObjectIdentifier(
                document
            )
        ] =
            WeakMDonnaDocument(
                document
            )
    }


    func unregister(
        _ document:
            MDonnaDocument
    ) {

        documents.removeValue(
            forKey:
                ObjectIdentifier(
                    document
                )
        )

        purge()
    }


    var liveDocuments:
        [MDonnaDocument]
    {

        purge()

        return documents
            .values
            .compactMap {
                $0.value
            }
    }


    private func purge() {

        documents =
            documents.filter {
                $0.value.value != nil
            }
    }
}


// MARK: - One independent document per window

struct EditorWindowRoot: View {

    @StateObject
    private var document =
        MDonnaDocument()


    var body: some View {

        EditorView(
            document:
                document
        )
        .focusedSceneValue(
            \.mdonnaDocument,
            document
        )
        .onAppear {

            MDonnaDocumentRegistry
                .shared
                .register(
                    document
                )
        }
        .onDisappear {

            MDonnaDocumentRegistry
                .shared
                .unregister(
                    document
                )
        }
    }
}


// MARK: - File menu

struct MDonnaCommands:
    Commands
{

    @Environment(
        \.openWindow
    )
    private var openWindow


    @FocusedValue(
        \.mdonnaDocument
    )
    private var document


    var body: some Commands {

        CommandGroup(
            replacing: .newItem
        ) {

            Button(
                "New"
            ) {

                /*
                 Every Cmd+N creates a genuinely new
                 WindowGroup instance.

                 EditorWindowRoot owns its own StateObject,
                 so every window gets its own MDonnaDocument.
                */

                openWindow(
                    id:
                        "editor"
                )
            }
            .keyboardShortcut(
                "n",
                modifiers: .command
            )


            Button(
                "Open…"
            ) {

                document?
                    .openDocument()
            }
            .keyboardShortcut(
                "o",
                modifiers: .command
            )
            .disabled(
                document == nil
            )
        }


        CommandGroup(
            replacing: .saveItem
        ) {

            Button(
                "Save"
            ) {

                document?
                    .save()
            }
            .keyboardShortcut(
                "s",
                modifiers: .command
            )
            .disabled(
                document == nil
            )


            Button(
                "Save As…"
            ) {

                document?
                    .saveAs()
            }
            .keyboardShortcut(
                "s",
                modifiers: [
                    .command,
                    .shift
                ]
            )
            .disabled(
                document == nil
            )
        }
    }
}


// MARK: - Application lifecycle

@MainActor
final class MDonnaAppDelegate:
    NSObject,
    NSApplicationDelegate
{

    func applicationShouldTerminate(
        _ sender:
            NSApplication
    ) -> NSApplication.TerminateReply {

        /*
         With multiple windows there is no longer one
         global document.

         Ask every currently open document whether the
         application may terminate.
        */

        for document
            in MDonnaDocumentRegistry
                .shared
                .liveDocuments
        {

            if !document
                .confirmApplicationTermination()
            {

                return .terminateCancel
            }
        }


        return .terminateNow
    }


    func applicationDidFinishLaunching(
        _ notification:
            Notification
    ) {

        NSApp.setActivationPolicy(
            .regular
        )

        NSApp.activate(
            ignoringOtherApps: true
        )
    }
}


// MARK: - Application

@main
struct MDonnaApp:
    App
{

    @NSApplicationDelegateAdaptor(
        MDonnaAppDelegate.self
    )
    private var appDelegate


    var body: some Scene {

        WindowGroup(
            id:
                "editor"
        ) {

            /*
             EditorWindowRoot, rather than MDonnaApp,
             owns the document.

             Therefore every WindowGroup instance has
             completely independent text/file/save state.
            */

            EditorWindowRoot()
        }
        .commands {

            /*
             Commands obtain the document from the
             currently focused window.
            */

            MDonnaCommands()
        }
    }
}
