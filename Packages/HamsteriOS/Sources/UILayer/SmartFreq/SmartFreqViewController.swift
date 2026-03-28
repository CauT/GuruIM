import HamsterUIKit
import SwiftUI
import UIKit

class SmartFreqViewController: NibLessViewController {
  override func loadView() {
    view = UIView()
    title = "智能调频"
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    let host = UIHostingController(rootView: SmartFreqRootView())
    addChild(host)
    host.view.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(host.view)
    NSLayoutConstraint.activate([
      host.view.topAnchor.constraint(equalTo: view.topAnchor),
      host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])
    host.didMove(toParent: self)
  }
}
