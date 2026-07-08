import UIKit
import Capacitor

@objc(LinkVaultBridgeViewController)
open class LinkVaultBridgeViewController: CAPBridgeViewController {
    override open func capacitorDidLoad() {
        super.capacitorDidLoad()

        // App-local Capacitor plugins are not automatically available to the
        // WebView just because their Swift files are copied into the App target.
        // Registering the instance here makes window.Capacitor.registerPlugin("PendingShare")
        // bridge to PendingSharePlugin every time the app starts.
        bridge?.registerPluginInstance(PendingSharePlugin())
    }
}
