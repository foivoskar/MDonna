import SwiftUI
import AppKit

@MainActor
struct WindowConfigurator: NSViewRepresentable {

    let title: String


    func makeNSView(
        context: Context
    ) -> WindowProbeView {

        let view =
            WindowProbeView()

        view.title =
            title

        return view
    }


    func updateNSView(
        _ nsView: WindowProbeView,
        context: Context
    ) {

        nsView.title =
            title

        nsView.applyConfiguration()
    }
}


@MainActor
final class WindowProbeView: NSView {

    var title:
        String = ""


    override func viewDidMoveToWindow() {

        super.viewDidMoveToWindow()

        applyConfiguration()
    }


    func applyConfiguration() {

        guard let window else {
            return
        }


        /*
         IMPORTANT:

         Use a completely standard native macOS titlebar.

         No full-size content view.
         No hidden titlebar.
         No transparent titlebar.
         No document content inside the draggable region.
        */

        window.styleMask.remove(
            .fullSizeContentView
        )

        window.titlebarAppearsTransparent =
            false

        window.titlebarSeparatorStyle =
            .automatic

        window.titleVisibility =
            .visible

        window.isMovableByWindowBackground =
            false

        window.title =
            title


        /*
         Ensure this really behaves as the current app window.
        */

        window.makeKeyAndOrderFront(
            nil
        )

        NSApp.activate(
            ignoringOtherApps: true
        )
    }
}
