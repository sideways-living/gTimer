import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

#if os(iOS)
struct ShareSheet: UIViewControllerRepresentable {
  var items: [Any]

  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: items, applicationActivities: nil)
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#elseif os(macOS)
struct ShareSheet: NSViewControllerRepresentable {
  var items: [Any]

  func makeNSViewController(context: Context) -> NSViewController {
    ShareHostViewController(items: items)
  }

  func updateNSViewController(_ nsViewController: NSViewController, context: Context) {}
}

private final class ShareHostViewController: NSViewController {
  private let items: [Any]
  private var didShowPicker = false

  init(items: [Any]) {
    self.items = items
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    nil
  }

  override func loadView() {
    view = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
  }

  override func viewDidAppear() {
    super.viewDidAppear()
    guard !didShowPicker else { return }
    didShowPicker = true
    let picker = NSSharingServicePicker(items: items)
    picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
  }
}
#endif
