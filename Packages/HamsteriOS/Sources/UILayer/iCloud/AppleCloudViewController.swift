//
//  AppleCloudViewController.swift
//  Hamster
//
//  Created by morse on 2023/6/14.
//
import Combine
import HamsterUIKit
import UIKit

protocol AppleCloudViewModelFactory {
  func makeAppleCloudViewModel() -> AppleCloudViewModel
}

class AppleCloudViewController: NibLessViewController {
  // MARK: properties

  let appleCloudViewModelFactory: AppleCloudViewModelFactory
  private var viewModel: AppleCloudViewModel?
  private var cancellables = Set<AnyCancellable>()

  // MARK: methods

  init(appleCloudViewModelFactory: AppleCloudViewModelFactory) {
    self.appleCloudViewModelFactory = appleCloudViewModelFactory
    super.init()
  }
}

// MARK: override UIViewController

extension AppleCloudViewController {
  override func loadView() {
    title = "iCloud同步"
    let vm = appleCloudViewModelFactory.makeAppleCloudViewModel()
    viewModel = vm
    view = AppleCloudRootView(viewModel: vm)
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    viewModel?.$syncState
      .receive(on: DispatchQueue.main)
      .sink { [weak self] state in
        guard case .finished(let success, let message) = state else { return }
        self?.showSyncResultAlert(success: success, message: message)
      }
      .store(in: &cancellables)
  }

  private func showSyncResultAlert(success: Bool, message: String) {
    let alert = UIAlertController(
      title: success ? "同步成功" : "同步失败",
      message: message,
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
      (self?.view as? AppleCloudRootView)?.reloadSyncStatus()
    })
    present(alert, animated: true)
  }
}
