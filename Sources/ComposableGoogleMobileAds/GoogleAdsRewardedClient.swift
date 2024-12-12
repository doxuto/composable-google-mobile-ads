//
//  GoogleAdsClient.swift
//  GoogleMobileAdsComposable
//
//  Created by Toan Doan on 12/12/24.
//

import ComposableArchitecture
import GoogleMobileAds

@DependencyClient
public struct GoogleAdsRewardedClient: Sendable {
  public var delegate: @Sendable (String) -> AsyncThrowingStream<DelegateEvent, Error> = {
    _ in .finished()
  }
  public var presentRewardedAds: () async throws -> Void
  
  @CasePathable
   public enum DelegateEvent {
     case adDidRecordImpression
     case adDidRecordClick
     case didFailToPresentFullScreenContentWithError(Error)
     case adWillPresentFullScreenContent
     case adWillDismissFullScreenContent
     case adDidDismissFullScreenContent
   }
  
  fileprivate class Delegate: NSObject, GADFullScreenContentDelegate, @unchecked Sendable {
    let continuation: AsyncThrowingStream<DelegateEvent, Error>.Continuation
    
    init(continuation: AsyncThrowingStream<DelegateEvent, Error>.Continuation) {
      self.continuation = continuation
    }
    
    func adDidRecordImpression(_ ad: any GADFullScreenPresentingAd) {
      continuation.yield(.adDidRecordImpression)
    }
    
    func adDidRecordClick(_ ad: any GADFullScreenPresentingAd) {
      continuation.yield(.adDidRecordClick)
    }
    
    func ad(
      _ ad: any GADFullScreenPresentingAd,
      didFailToPresentFullScreenContentWithError error: any Error
    ) {
      continuation.yield(.didFailToPresentFullScreenContentWithError(error))
    }
    
    func adDidDismissFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
      continuation.yield(.adDidDismissFullScreenContent)
    }
    
    func adWillDismissFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
      continuation.yield(.adWillDismissFullScreenContent)
    }
    
    func adWillPresentFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
      continuation.yield(.adWillPresentFullScreenContent)
    }
  }
}

extension GoogleAdsRewardedClient: DependencyKey {
  nonisolated(unsafe) fileprivate static var rewardedAd: GADRewardedAd!
  public static let liveValue: GoogleAdsRewardedClient = {
    Self { adUnitID in
      return AsyncThrowingStream<DelegateEvent, Error> { [adUnitID] continuation in
        Task {
          let delegate = Delegate(continuation: continuation)
          do {
            rewardedAd = try await GADRewardedAd.load(withAdUnitID: adUnitID, request: .init())
            rewardedAd.fullScreenContentDelegate = delegate
          } catch {
            continuation.finish(throwing: error)
          }
          
          continuation.onTermination = { _ in
            _ = delegate
          }
        }
      }
    } presentRewardedAds: {
      guard let rewardedAd = Self.rewardedAd else {
        throw GoogleAdError.notFoundAd
      }
      await withCheckedContinuation { continuation in
        rewardedAd.present(fromRootViewController: nil) {
          continuation.resume()
        }
      }
    }
  }()
}

public enum GoogleAdError: Error, Sendable {
  case notFoundAd
}
