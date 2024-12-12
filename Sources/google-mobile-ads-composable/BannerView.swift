//
//  BannerView.swift
//  GoogleMobileAdsComposable
//
//  Created by doxuto on 12/12/24.
//

import SwiftUI
import GoogleMobileAds

public struct BannerView: UIViewRepresentable {
  public let adUnitID: String
  
  public init(adUnitID: String) {
    self.adUnitID = adUnitID
  }
  
  public func makeCoordinator() -> Coordinator {
    Coordinator(adUnitID: adUnitID)
  }
  
  public func makeUIView(context: Context) -> some UIView {
    context.coordinator.bannerView
  }
  
  public func updateUIView(_ uiView: UIViewType, context: Context) {
  }
  
  @MainActor public final class Coordinator {
    fileprivate let bannerView: GADBannerView
    
    public init(adUnitID: String) {
      bannerView = GADBannerView()
      bannerView.isAutoloadEnabled = true
      bannerView.adUnitID = adUnitID
      bannerView.load(.init())
    }
  }
}
