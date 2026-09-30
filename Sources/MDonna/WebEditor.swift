import SwiftUI
import Foundation
import AppKit
import WebKit
import UniformTypeIdentifiers

private func mdonnaResourceURL(
    forResource name: String?,
    withExtension ext: String?,
    subdirectory: String? = nil
) -> URL? {

    /*
     1. Normal packaged MDonna.app.

     Resources are copied directly into:

         MDonna.app/Contents/Resources
    */

    if let url =
        Bundle.main.url(
            forResource:
                name,
            withExtension:
                ext,
            subdirectory:
                subdirectory
        )
    {
        return url
    }


    /*
     SwiftPM flattens our WebEditor resource directory.

     Therefore, if a lookup using "WebEditor" failed,
     also try the app's resource root before doing anything
     else.
    */

    if subdirectory != nil {

        if let url =
            Bundle.main.url(
                forResource:
                    name,
                withExtension:
                    ext
            )
        {
            return url
        }
    }


    /*
     2. Development builds (`swift run`).

     Do NOT call Bundle.module here.

     Bundle.module may fatalError when its expected SwiftPM
     resource bundle is not present — which is exactly what
     happens inside our standalone packaged application.

     Instead, look safely for MDonna_MDonna.bundle beside the
     executable.
    */

    var candidates:
        [URL] = []


    if let executableURL =
        Bundle.main.executableURL
    {

        let executableDirectory =
            executableURL
            .deletingLastPathComponent()


        candidates.append(
            executableDirectory
                .appendingPathComponent(
                    "MDonna_MDonna.bundle",
                    isDirectory:
                        true
                )
        )


        candidates.append(
            executableDirectory
                .deletingLastPathComponent()
                .appendingPathComponent(
                    "MDonna_MDonna.bundle",
                    isDirectory:
                        true
                )
        )
    }


    candidates.append(
        Bundle.main
            .bundleURL
            .appendingPathComponent(
                "MDonna_MDonna.bundle",
                isDirectory:
                    true
            )
    )


    for bundleURL
        in candidates
    {

        guard
            FileManager
                .default
                .fileExists(
                    atPath:
                        bundleURL.path
                ),
            let bundle =
                Bundle(
                    url:
                        bundleURL
                )
        else {
            continue
        }


        if let url =
            bundle.url(
                forResource:
                    name,
                withExtension:
                    ext,
                subdirectory:
                    subdirectory
            )
        {
            return url
        }


        /*
         Same flattening fallback for the development bundle.
        */

        if subdirectory != nil {

            if let url =
                bundle.url(
                    forResource:
                        name,
                    withExtension:
                        ext
                )
            {
                return url
            }
        }
    }


    return nil
}



final class MDonnaLocalFileSchemeHandler:
    NSObject,
    WKURLSchemeHandler
{

    func webView(
        _ webView: WKWebView,
        start urlSchemeTask:
            WKURLSchemeTask
    ) {

        guard
            let requestURL =
                urlSchemeTask
                    .request
                    .url,
            let components =
                URLComponents(
                    url: requestURL,
                    resolvingAgainstBaseURL:
                        false
                ),
            let path =
                components
                    .queryItems?
                    .first(
                        where: {
                            $0.name == "path"
                        }
                    )?
                    .value
        else {

            urlSchemeTask.didFailWithError(
                NSError(
                    domain:
                        "MDonnaLocalFile",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Invalid local image URL."
                    ]
                )
            )

            return
        }


        let fileURL =
            URL(
                fileURLWithPath:
                    path
            )
            .standardizedFileURL


        do {

            let data =
                try Data(
                    contentsOf:
                        fileURL
                )


            let mimeType =
                UTType(
                    filenameExtension:
                        fileURL
                        .pathExtension
                )?
                .preferredMIMEType
                ?? "application/octet-stream"


            let response =
                URLResponse(
                    url:
                        requestURL,
                    mimeType:
                        mimeType,
                    expectedContentLength:
                        data.count,
                    textEncodingName:
                        nil
                )


            urlSchemeTask.didReceive(
                response
            )

            urlSchemeTask.didReceive(
                data
            )

            urlSchemeTask.didFinish()


        } catch {

            urlSchemeTask.didFailWithError(
                error
            )
        }
    }


    func webView(
        _ webView: WKWebView,
        stop urlSchemeTask:
            WKURLSchemeTask
    ) {

        // Nothing asynchronous to cancel.
    }
}


@MainActor
struct WebEditor: NSViewRepresentable {

    @Binding var text: String

    var fileURL: URL?

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(
        context: Context
    ) -> WKWebView {

        let configuration =
            WKWebViewConfiguration()

        let controller =
            WKUserContentController()

        controller.add(
            context.coordinator,
            name: "mdonna"
        )

        configuration.userContentController =
            controller

        configuration.setURLSchemeHandler(
            context.coordinator
                .localFileSchemeHandler,
            forURLScheme:
                "mdonna-file"
        )

        let webView =
            WKWebView(
                frame: .zero,
                configuration: configuration
            )

        webView.navigationDelegate =
            context.coordinator

        webView.setValue(
            false,
            forKey:
                "drawsBackground"
        )

        context.coordinator.webView =
            webView

        let resourceURL =
            mdonnaResourceURL(
                forResource: "index",
                withExtension: "html",
                subdirectory: "WebEditor"
            )
            ??
            mdonnaResourceURL(
                forResource: "index",
                withExtension: "html"
            )

        guard let resourceURL else {

            print(
                "ERROR: MDonna index.html not found."
            )

            print(
                "Resource bundle:",
                (
                    Bundle.main.resourceURL
                    ?? Bundle.main.bundleURL
                ).path
            )

            if let enumerator =
                FileManager.default.enumerator(
                    at:
                    (
                        Bundle.main.resourceURL
                        ?? Bundle.main.bundleURL
                    ),
                    includingPropertiesForKeys: nil
                ) {

                for case let url as URL in enumerator {
                    print(
                        "Resource:",
                        url.path
                    )
                }
            }

            return webView
        }

        print(
            "MDonna WebEditor:",
            resourceURL.path
        )

        let directoryURL =
            resourceURL
                .deletingLastPathComponent()

        webView.loadFileURL(
            resourceURL,
            allowingReadAccessTo:
                directoryURL
        )

        return webView
    }


    func updateNSView(
        _ webView: WKWebView,
        context: Context
    ) {

        context.coordinator
            .latestNativeText =
                text

        let baseURL =
            fileURL.map {
                URL(
                    fileURLWithPath:
                        $0
                        .deletingLastPathComponent()
                        .path,
                    isDirectory:
                        true
                )
                .absoluteString
            }

        context.coordinator
            .latestDocumentBaseURL =
                baseURL

        context.coordinator
            .latestDocumentFileURL =
                fileURL

        print(
            "MDonna Swift updateNSView: length =",
            text.utf16.count,
            "ready =",
            context.coordinator.isReady
        )

        guard
            context.coordinator
                .isReady
        else {
            return
        }

        context.coordinator
            .pushNativeTextToJavaScript(
                text
            )

        context.coordinator
            .pushDocumentContextToJavaScript(
                baseURL
            )
    }


    // MARK: - Coordinator

    @MainActor
    final class Coordinator:
        NSObject,
        WKScriptMessageHandler,
        WKNavigationDelegate
    {

        var text: Binding<String>

        weak var webView:
            WKWebView?

        var isReady =
            false

        var latestNativeText:
            String

        var latestDocumentBaseURL:
            String?

        var latestDocumentFileURL:
            URL?

        var lastDocumentBaseURLSent:
            String?

        let localFileSchemeHandler =
            MDonnaLocalFileSchemeHandler()

        private var lastTextSentToJavaScript:
            String?

        init(
            text: Binding<String>
        ) {

            self.text =
                text

            self.latestNativeText =
                text.wrappedValue
        }


        func userContentController(
            _ userContentController:
                WKUserContentController,
            didReceive message:
                WKScriptMessage
        ) {

            guard
                message.name == "mdonna",
                let dictionary =
                    message.body
                    as? [String: Any],
                let type =
                    dictionary["type"]
                    as? String
            else {
                return
            }

            switch type {

            case "ready":

                isReady =
                    true

                print(
                    "MDonna Swift READY: latestNativeText length =",
                    latestNativeText.utf16.count
                )

                pushNativeTextToJavaScript(
                    latestNativeText
                )

                pushDocumentContextToJavaScript(
                    latestDocumentBaseURL
                )

                DispatchQueue.main.async {
                    self.webView?
                        .evaluateJavaScript(
                            "window.MDonna.focus();"
                        ) { _, error in

                            if let error {
                                print(
                                    "MDonna focus JS error:",
                                    error
                                )
                            }
                        }
                }


            case "change":

                guard let markdown =
                    dictionary["markdown"]
                    as? String
                else {
                    return
                }

                latestNativeText =
                    markdown

                lastTextSentToJavaScript =
                    markdown

                if text.wrappedValue
                    != markdown {

                    text.wrappedValue =
                        markdown
                }


            case "openLink":

                guard
                    let value =
                        dictionary["url"]
                        as? String,
                    let url =
                        URL(string: value)
                else {
                    return
                }

                NSWorkspace.shared.open(
                    url
                )


            case "importImage":

                importImage(
                    from:
                        (
                            message.body
                            as? [String: Any]
                        )
                        ?? [:]                )


            case "imageImportNeedsSavedDocument":

                showImageImportAlert(
                    title:
                        "Save the document first",
                    message:
                        "MDonna needs to know where the Markdown file lives before it can create an images folder."
                )


            case "imageImportError":

                let text =
                    (
                        message.body
                        as? [String: Any]
                    )?["message"]
                    as? String
                    ??
                    "The image could not be imported."

                showImageImportAlert(
                    title:
                        "Could not import image",
                    message:
                        text
                )


            case "copy":

                guard
                    let value =
                        dictionary["text"]
                        as? String
                else {
                    return
                }

                NSPasteboard.general.clearContents()

                NSPasteboard.general.setString(
                    value,
                    forType: .string
                )


            case "log":

                if let value =
                    dictionary["message"]
                    as? String {

                    print(
                        "MDonna WebEditor:",
                        value
                    )
                }


            default:
                break
            }
        }


        func pushNativeTextToJavaScript(
            _ markdown: String
        ) {

            print(
                "MDonna Swift PUSH requested: length =",
                markdown.utf16.count,
                "ready =",
                isReady
            )

            guard isReady else {

                print(
                    "MDonna Swift PUSH skipped: WebEditor not ready"
                )

                return
            }

            guard
                lastTextSentToJavaScript
                    != markdown
            else {

                print(
                    "MDonna Swift PUSH skipped: text already sent"
                )

                return
            }

            guard
                let jsonData =
                    try? JSONSerialization.data(
                        withJSONObject: markdown,
                        options: [.fragmentsAllowed]
                    ),
                let argument =
                    String(
                        data: jsonData,
                        encoding: .utf8
                    )
            else {

                print(
                    "MDonna Swift PUSH failed: JSON encoding"
                )

                return
            }

            let script =
                "window.MDonna.setMarkdown(" +
                argument +
                ");"

            print(
                "MDonna Swift PUSH executing JavaScript..."
            )

            webView?
                .evaluateJavaScript(
                    script
                ) { result, error in

                    if let error {

                        print(
                            "MDonna Swift PUSH JavaScript ERROR:",
                            error
                        )

                        return
                    }

                    self.lastTextSentToJavaScript =
                        markdown

                    print(
                        "MDonna Swift PUSH succeeded"
                    )
                }
        }


        func showImageImportAlert(
            title: String,
            message: String
        ) {

            let alert =
                NSAlert()

            alert.messageText =
                title

            alert.informativeText =
                message

            alert.alertStyle =
                .informational

            alert.addButton(
                withTitle:
                    "OK"
            )

            alert.runModal()
        }


        func javascriptString(
            _ value: String
        ) -> String? {

            guard
                let data =
                    try? JSONSerialization
                        .data(
                            withJSONObject:
                                value,
                            options:
                                [.fragmentsAllowed]
                        )
            else {
                return nil
            }


            return String(
                data:
                    data,
                encoding:
                    .utf8
            )
        }


        func failImageImport(
            requestID: String,
            message: String
        ) {

            guard
                let requestJSON =
                    javascriptString(
                        requestID
                    ),
                let messageJSON =
                    javascriptString(
                        message
                    )
            else {
                return
            }


            webView?
                .evaluateJavaScript(
                    """
                    window.MDonna.failImageImport(
                        \(requestJSON),
                        \(messageJSON)
                    );
                    """
                )
        }


        func importImage(
            from body:
                [String: Any]
        ) {

            guard
                let requestID =
                    body["requestID"]
                    as? String
            else {
                return
            }


            guard
                let documentURL =
                    latestDocumentFileURL
            else {

                showImageImportAlert(
                    title:
                        "Save the document first",
                    message:
                        "Save this Markdown document before adding local images."
                )

                failImageImport(
                    requestID:
                        requestID,
                    message:
                        "Document has not been saved."
                )

                return
            }


            guard
                let dataURL =
                    body["dataURL"]
                    as? String,
                let comma =
                    dataURL
                    .firstIndex(
                        of:
                            ","
                    )
            else {

                failImageImport(
                    requestID:
                        requestID,
                    message:
                        "Invalid image data."
                )

                return
            }


            let encoded =
                String(
                    dataURL[
                        dataURL.index(
                            after:
                                comma
                        )...
                    ]
                )


            guard
                let imageData =
                    Data(
                        base64Encoded:
                            encoded
                    )
            else {

                failImageImport(
                    requestID:
                        requestID,
                    message:
                        "Could not decode image data."
                )

                return
            }


            let originalFilename =
                (
                    body["filename"]
                    as? String
                )
                ?? ""


            let mimeType =
                (
                    body["mimeType"]
                    as? String
                )
                ?? ""


            var extensionName =
                URL(
                    fileURLWithPath:
                        originalFilename
                )
                .pathExtension
                .lowercased()


            if extensionName.isEmpty {

                extensionName =
                    UTType(
                        mimeType:
                            mimeType
                    )?
                    .preferredFilenameExtension
                    ?? "png"
            }


            let type =
                UTType(
                    filenameExtension:
                        extensionName
                )
                ??
                UTType(
                    mimeType:
                        mimeType
                )


            guard
                type?
                .conforms(
                    to:
                        .image
                )
                == true
            else {

                failImageImport(
                    requestID:
                        requestID,
                    message:
                        "The dropped file is not a supported image."
                )

                return
            }


            var baseName =
                URL(
                    fileURLWithPath:
                        originalFilename
                )
                .deletingPathExtension()
                .lastPathComponent


            if baseName.isEmpty {

                baseName =
                    "pasted-image"
            }


            baseName =
                baseName
                .replacingOccurrences(
                    of:
                        "/",
                    with:
                        "-"
                )
                .replacingOccurrences(
                    of:
                        "\\",
                    with:
                        "-"
                )
                .replacingOccurrences(
                    of:
                        ":",
                    with:
                        "-"
                )
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )


            if baseName.isEmpty {

                baseName =
                    "image"
            }


            let documentFolder =
                documentURL
                .deletingLastPathComponent()


            let imagesFolder =
                documentFolder
                .appendingPathComponent(
                    "images",
                    isDirectory:
                        true
                )


            do {

                try FileManager
                    .default
                    .createDirectory(
                        at:
                            imagesFolder,
                        withIntermediateDirectories:
                            true
                    )


                var filename =
                    "\(baseName).\(extensionName)"


                var destination =
                    imagesFolder
                    .appendingPathComponent(
                        filename
                    )


                var counter =
                    2


                while FileManager
                    .default
                    .fileExists(
                        atPath:
                            destination.path
                    ) {

                    filename =
                        "\(baseName)-\(counter).\(extensionName)"

                    destination =
                        imagesFolder
                        .appendingPathComponent(
                            filename
                        )

                    counter += 1
                }


                try imageData
                    .write(
                        to:
                            destination,
                        options:
                            .atomic
                    )


                let relativePath =
                    "images/\(filename)"


                let requestedPosition =
                    (
                        body["position"]
                        as? NSNumber
                    )?
                    .intValue
                    ?? 0


                let altText =
                    baseName


                guard
                    let requestJSON =
                        javascriptString(
                            requestID
                        ),
                    let pathJSON =
                        javascriptString(
                            relativePath
                        ),
                    let altJSON =
                        javascriptString(
                            altText
                        )
                else {
                    return
                }


                webView?
                    .evaluateJavaScript(
                        """
                        window.MDonna.completeImageImport(
                            \(requestJSON),
                            \(pathJSON),
                            \(altJSON),
                            \(requestedPosition)
                        );
                        """
                    )


            } catch {

                failImageImport(
                    requestID:
                        requestID,
                    message:
                        error.localizedDescription
                )


                showImageImportAlert(
                    title:
                        "Could not import image",
                    message:
                        error.localizedDescription
                )
            }
        }


        func pushDocumentContextToJavaScript(
            _ baseURL: String?
        ) {

            guard
                isReady,
                lastDocumentBaseURLSent
                    != baseURL
            else {
                return
            }


            let argument: String

            if let baseURL {

                guard
                    let data =
                        try? JSONSerialization
                            .data(
                                withJSONObject:
                                    baseURL,
                                options:
                                    [.fragmentsAllowed]
                            ),
                    let value =
                        String(
                            data: data,
                            encoding: .utf8
                        )
                else {
                    return
                }

                argument =
                    value

            } else {

                argument =
                    "null"
            }


            webView?
                .evaluateJavaScript(
                    """
                    window.MDonna.setDocumentContext(
                        \(argument)
                    );
                    """
                ) { _, error in

                    if let error {

                        print(
                            "MDonna document context JS error:",
                            error
                        )

                        return
                    }

                    self.lastDocumentBaseURLSent =
                        baseURL
                }
        }


        func webView(
            _ webView: WKWebView,
            didFinish navigation:
                WKNavigation!
        ) {

            let script = """
            (() => {
                const editor =
                    document.querySelector(".cm-editor");

                const style =
                    editor
                    ? getComputedStyle(editor)
                    : null;

                return JSON.stringify({
                    hasMDonna:
                        !!window.MDonna,

                    hasCodeMirror:
                        !!editor,

                    styleSheetCount:
                        document.styleSheets.length,

                    stylesheets:
                        Array.from(
                            document.styleSheets
                        ).map(
                            sheet =>
                                sheet.href
                                || "inline"
                        ),

                    fontFamily:
                        style
                        ? style.fontFamily
                        : null,

                    fontSize:
                        style
                        ? style.fontSize
                        : null,

                    bodyTextStart:
                        document.body.innerText
                            .slice(0, 80)
                });
            })();
            """

            webView.evaluateJavaScript(
                script
            ) { result, error in

                if let error {

                    print(
                        "MDonna WebEditor diagnostic error:",
                        error
                    )

                    return
                }

                print(
                    "MDonna WebEditor diagnostic:",
                    result ?? "nil"
                )
            }
        }
    }
}
