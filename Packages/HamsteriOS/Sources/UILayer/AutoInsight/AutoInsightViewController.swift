import HamsterUIKit
import SwiftUI
import UIKit

class AutoInsightViewController: NibLessViewController {
  override func loadView() {
    title = "每日洞察"
    let rootView = AutoInsightRootView()
    let host = UIHostingController(rootView: rootView)
    addChild(host)
    view = host.view
    host.didMove(toParent: self)
    host.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      host.view.topAnchor.constraint(equalTo: view.topAnchor),
      host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])
  }
}
