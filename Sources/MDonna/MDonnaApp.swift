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


    func openDocument(
        at url: URL
    ) {

        guard
            confirmReplacingDocument()
        else {
            return
        }


        do {

            let loadedText =
                try String(
                    contentsOf:
                        url,
                    encoding:
                        .utf8
                )


            text =
                loadedText

            fileURL =
                url

            isEdited =
                false


        } catch {

            let alert =
                NSAlert()

            alert.messageText =
                "Could not open Markdown file"

            alert.informativeText =
                error.localizedDescription

            alert.alertStyle =
                .warning

            alert.addButton(
                withTitle:
                    "OK"
            )

            alert.runModal()
        }
    }


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

// MARK: - File menu

struct MDonnaCommands:
    Commands
{

    let document:
        MDonnaDocument


    var body: some Commands {

        CommandGroup(
            replacing: .newItem
        ) {

            Button(
                "New"
            ) {

                document
                    .newDocument()
            }
            .keyboardShortcut(
                "n",
                modifiers: .command
            )


            Button(
                "Open…"
            ) {

                document
                    .openDocument()
            }
            .keyboardShortcut(
                "o",
                modifiers: .command
            )
        }


        CommandGroup(
            replacing: .saveItem
        ) {

            Button(
                "Save"
            ) {

                document.save()
            }
            .keyboardShortcut(
                "s",
                modifiers: .command
            )


            Button(
                "Save As…"
            ) {

                document.saveAs()
            }
            .keyboardShortcut(
                "s",
                modifiers: [
                    .command,
                    .shift
                ]
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

    private var pendingOpenURLs:
        [URL] = []


    func attach(
        document: MDonnaDocument
    ) {

        self.document =
            document


        guard
            let url =
                pendingOpenURLs.first
        else {
            return
        }


        pendingOpenURLs
            .removeAll()


        document.openDocument(
            at:
                url
        )
    }


    func application(
        _ application: NSApplication,
        openFile filename: String
    ) -> Bool {

        let url =
            URL(
                fileURLWithPath:
                    filename
            )


        if let document {

            document.openDocument(
                at:
                    url
            )

        } else {

            pendingOpenURLs =
                [url]
        }


        return true
    }


    func application(
        _ application: NSApplication,
        open urls: [URL]
    ) {

        guard
            let firstURL =
                urls.first
        else {
            return
        }


        if let document {

            document.openDocument(
                at:
                    firstURL
            )

        } else {

            pendingOpenURLs =
                urls
        }
    }


    func application(
        _ application: NSApplication,
        openFiles filenames: [String]
    ) {

        let urls =
            filenames.map {
                URL(
                    fileURLWithPath:
                        $0
                )
            }


        guard
            let url =
                urls.first
        else {

            application.reply(
                toOpenOrPrint:
                    .failure
            )

            return
        }


        if let document {

            document.openDocument(
                at:
                    url
            )

        } else {

            pendingOpenURLs =
                urls
        }


        application.reply(
            toOpenOrPrint:
                .success
        )
    }



    var document:
        MDonnaDocument?


    func applicationShouldTerminate(
        _ sender: NSApplication
    ) -> NSApplication.TerminateReply {

        guard let document else {
            return .terminateNow
        }

        if document
            .confirmApplicationTermination() {

            return .terminateNow
        }

        return .terminateCancel
    }


    func applicationDidFinishLaunching(
        _ notification: Notification
    ) {

        if
            let iconURL =
                Bundle.main.url(
                    forResource:
                        "MDonna",
                    withExtension:
                        "icns"
                ),
            let iconImage =
                NSImage(
                    contentsOf:
                        iconURL
                )
        {
            NSApp.applicationIconImage =
                iconImage
        }


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

    @StateObject
    private var document =
        MDonnaDocument()


    var body: some Scene {

        Window(
            "MDonna",
            id: "main"
        ) {

            EditorView(
                document:
                    document
            )
            .onAppear {

                appDelegate.attach(document: document)
            }
        }
        .commands {

            MDonnaCommands(
                document:
                    document
            )
        }
    }
}
