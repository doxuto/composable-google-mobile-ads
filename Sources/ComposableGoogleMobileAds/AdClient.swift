//
//  AdClient.swift
//  ComposableGoogleMobileAds
//
//  Created by Toan Doan on 18/1/25.
//


import Combine
import ComposableArchitecture
@preconcurrency import GoogleMobileAds
import OSLog

private let logger = Logger(
  subsystem: Bundle.main.bundleIdentifier!,
  category: "AdClient"
)

@DependencyClient
public struct AdClient: Sendable {
  @MainActor fileprivate static var isShowingFullscreenAd = false
  public var interstitialClient: InterstitialClient
  public var rewardInterstitialClient: RewardInterstitialClient
  public var rewardClient: RewardClient
  public var appOpenClient: AppOpenClient

  @DependencyClient
  public struct InterstitialClient: Sendable {
    public var preloadAd: @Sendable (String) async throws -> Void
    public var present:
      @Sendable (String) async throws -> AsyncThrowingStream<DelegateEvent, Error> = { _ in
        .finished()
      }
  }
  
  @DependencyClient
  public struct RewardInterstitialClient: Sendable {
    public var preloadAd: @Sendable (String) async throws -> Void
    public var present:
      @Sendable (String) async throws -> AsyncThrowingStream<DelegateEvent, Error> = { _ in
        .finished()
      }
  }
  
  @DependencyClient
  public struct RewardClient: Sendable {
    public var preloadAd: @Sendable (String) async throws -> Void
    public var present:
      @Sendable (String) async throws -> AsyncThrowingStream<DelegateEvent, Error> = { _ in
        .finished()
      }
  }
  
  
  @DependencyClient
  public struct AppOpenClient: Sendable {
    public var preloadAd: @Sendable (String) async throws -> Void
    public var present:
      @Sendable (String) async throws -> AsyncThrowingStream<DelegateEvent, Error> = { _ in
        .finished()
      }
  }

  @CasePathable
  public enum DelegateEvent: Sendable {
    case adDidRecordImpression
    case adDidRecordClick
    case didFailToPresentFullScreenContentWithError(Error)
    case adWillPresentFullScreenContent
    case adWillDismissFullScreenContent
    case adDidDismissFullScreenContent
    case adDidEarnReward(Double)
  }
}

extension AdClient: DependencyKey {
  public static var liveValue: Self {
    actor InterstitialPresenter {
      nonisolated(unsafe) var interstitialAd: GADInterstitialAd!

      func preloadAd(adUnitId: String) async throws {
        let request = GADRequest()
        interstitialAd =
          try await GADInterstitialAd
          .load(withAdUnitID: adUnitId, request: request)
      }

      func present(adUnitId: String) async throws -> AsyncThrowingStream<DelegateEvent, Error> {
        if interstitialAd == nil {
          let request = GADRequest()
          interstitialAd =
            try await GADInterstitialAd
            .load(withAdUnitID: adUnitId, request: request)
        }

        class Delegate: NSObject, GADFullScreenContentDelegate, @unchecked Sendable {
          let continuation: AsyncThrowingStream<DelegateEvent, Error>.Continuation

          init(continuation: AsyncThrowingStream<DelegateEvent, Error>.Continuation) {
            self.continuation = continuation
          }

          func adDidRecordImpression(_ ad: any GADFullScreenPresentingAd) {
            logger.info("Ad did record impression")
            continuation.yield(.adDidRecordImpression)
          }

          func adDidRecordClick(_ ad: any GADFullScreenPresentingAd) {
            logger.info("Ad did record click")
            continuation.yield(.adDidRecordClick)
          }

          func ad(
            _ ad: any GADFullScreenPresentingAd,
            didFailToPresentFullScreenContentWithError error: any Error
          ) {
            logger.error("Ad failed to present full screen content: \(error.localizedDescription)")
            Task {
              await MainActor.run {
                AdClient.isShowingFullscreenAd = false
              }
            }
            continuation.yield(.didFailToPresentFullScreenContentWithError(error))
            continuation.finish()
          }

          func adDidDismissFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
            logger.info("Ad did dismiss full screen content")
            Task {
              await MainActor.run {
                AdClient.isShowingFullscreenAd = false
              }
            }
            continuation.yield(.adDidDismissFullScreenContent)
            continuation.finish()
          }

          func adWillDismissFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
            logger.info("Ad will dismiss full screen content")
            continuation.yield(.adWillDismissFullScreenContent)
          }

          func adWillPresentFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
            logger.info("Ad will present full screen content")
            continuation.yield(.adWillPresentFullScreenContent)
          }
        }
        return AsyncThrowingStream<DelegateEvent, Error> { continuation in
          Task {
            await MainActor.run {
              if AdClient.isShowingFullscreenAd {
                continuation.finish()
                return
              }

              let delegate = Delegate(continuation: continuation)
              self.interstitialAd?.fullScreenContentDelegate = delegate
              self.interstitialAd.present(fromRootViewController: nil)
              AdClient.isShowingFullscreenAd = true
              continuation.onTermination = { _ in
                _ = delegate
                Task {
                  try? await self.preloadAd(adUnitId: adUnitId)
                }
              }
            }
          }
        }
      }
    }

    actor RewardedInterstitialPresenter {
      nonisolated(unsafe) var rewardedInterstitialAd: GADRewardedInterstitialAd!

      func preloadAd(adUnitId: String) async throws {
        let request = GADRequest()
        rewardedInterstitialAd = try await GADRewardedInterstitialAd.load(
          withAdUnitID: adUnitId, request: request)
      }

      func present(adUnitId: String) async throws -> AsyncThrowingStream<DelegateEvent, Error> {
        if rewardedInterstitialAd == nil {
          let request = GADRequest()
          rewardedInterstitialAd = try await GADRewardedInterstitialAd.load(
            withAdUnitID: adUnitId, request: request)
        }

        class Delegate: NSObject, GADFullScreenContentDelegate, @unchecked Sendable {
          let continuation: AsyncThrowingStream<DelegateEvent, Error>.Continuation

          init(continuation: AsyncThrowingStream<DelegateEvent, Error>.Continuation) {
            self.continuation = continuation
          }

          func adDidRecordImpression(_ ad: any GADFullScreenPresentingAd) {
            logger.info("Ad did record impression")
            continuation.yield(.adDidRecordImpression)
          }

          func adDidRecordClick(_ ad: any GADFullScreenPresentingAd) {
            logger.info("Ad did record click")
            continuation.yield(.adDidRecordClick)
          }

          func ad(
            _ ad: any GADFullScreenPresentingAd,
            didFailToPresentFullScreenContentWithError error: any Error
          ) {
            logger.error("Ad failed to present full screen content: \(error.localizedDescription)")
            Task {
              await MainActor.run {
                AdClient.isShowingFullscreenAd = false
              }
            }
            continuation.yield(.didFailToPresentFullScreenContentWithError(error))
            continuation.finish()
          }

          func adDidDismissFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
            logger.info("Ad did dismiss full screen content")
            Task {
              await MainActor.run {
                AdClient.isShowingFullscreenAd = false
              }
            }
            continuation.yield(.adDidDismissFullScreenContent)
            continuation.finish()
          }

          func adWillDismissFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
            logger.info("Ad will dismiss full screen content")
            continuation.yield(.adWillDismissFullScreenContent)
          }

          func adWillPresentFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
            logger.info("Ad will present full screen content")
            continuation.yield(.adWillPresentFullScreenContent)
          }
        }
        return AsyncThrowingStream<DelegateEvent, Error> { continuation in
          Task {
            await MainActor.run {
              if AdClient.isShowingFullscreenAd {
                continuation.finish()
                return
              }

              let delegate = Delegate(continuation: continuation)
              self.rewardedInterstitialAd?.fullScreenContentDelegate = delegate
              self.rewardedInterstitialAd.present(fromRootViewController: nil) {
                let amountReward = self.rewardedInterstitialAd.adReward.amount.doubleValue
                continuation.yield(.adDidEarnReward(amountReward))
              }
              AdClient.isShowingFullscreenAd = true
              continuation.onTermination = { _ in
                _ = delegate
                Task {
                  try? await self.preloadAd(adUnitId: adUnitId)
                }
              }
            }
          }
        }
      }
    }
    
    actor RewardedPresenter {
      nonisolated(unsafe) var rewardedAd: GADRewardedAd!

      func preloadAd(adUnitId: String) async throws {
        let request = GADRequest()
        rewardedAd = try await GADRewardedAd.load(
          withAdUnitID: adUnitId, request: request)
      }

      func present(adUnitId: String) async throws -> AsyncThrowingStream<DelegateEvent, Error> {
        if rewardedAd == nil {
          let request = GADRequest()
          rewardedAd = try await GADRewardedAd.load(
            withAdUnitID: adUnitId, request: request)
        }

        class Delegate: NSObject, GADFullScreenContentDelegate, @unchecked Sendable {
          let continuation: AsyncThrowingStream<DelegateEvent, Error>.Continuation

          init(continuation: AsyncThrowingStream<DelegateEvent, Error>.Continuation) {
            self.continuation = continuation
          }

          func adDidRecordImpression(_ ad: any GADFullScreenPresentingAd) {
            logger.info("Ad did record impression")
            continuation.yield(.adDidRecordImpression)
          }

          func adDidRecordClick(_ ad: any GADFullScreenPresentingAd) {
            logger.info("Ad did record click")
            continuation.yield(.adDidRecordClick)
          }

          func ad(
            _ ad: any GADFullScreenPresentingAd,
            didFailToPresentFullScreenContentWithError error: any Error
          ) {
            logger.error("Ad failed to present full screen content: \(error.localizedDescription)")
            Task {
              await MainActor.run {
                AdClient.isShowingFullscreenAd = false
              }
            }
            continuation.yield(.didFailToPresentFullScreenContentWithError(error))
            continuation.finish()
          }

          func adDidDismissFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
            logger.info("Ad did dismiss full screen content")
            Task {
              await MainActor.run {
                AdClient.isShowingFullscreenAd = false
              }
            }
            continuation.yield(.adDidDismissFullScreenContent)
            continuation.finish()
          }

          func adWillDismissFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
            logger.info("Ad will dismiss full screen content")
            continuation.yield(.adWillDismissFullScreenContent)
          }

          func adWillPresentFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
            logger.info("Ad will present full screen content")
            continuation.yield(.adWillPresentFullScreenContent)
          }
        }
        return AsyncThrowingStream<DelegateEvent, Error> { continuation in
          Task {
            await MainActor.run {
              if AdClient.isShowingFullscreenAd {
                continuation.finish()
                return
              }

              let delegate = Delegate(continuation: continuation)
              self.rewardedAd?.fullScreenContentDelegate = delegate
              self.rewardedAd.present(fromRootViewController: nil) {
                let amountReward = self.rewardedAd.adReward.amount.doubleValue
                continuation.yield(.adDidEarnReward(amountReward))
              }
              AdClient.isShowingFullscreenAd = true
              continuation.onTermination = { _ in
                _ = delegate
                Task {
                  try? await self.preloadAd(adUnitId: adUnitId)
                }
              }
            }
          }
        }
      }
    }
    
    actor AppOpenPresenter {
      nonisolated(unsafe) var interstitialAd: GADAppOpenAd!

      func preloadAd(adUnitId: String) async throws {
        let request = GADRequest()
        interstitialAd =
          try await GADAppOpenAd
          .load(withAdUnitID: adUnitId, request: request)
      }

      func present(adUnitId: String) async throws -> AsyncThrowingStream<DelegateEvent, Error> {
        if interstitialAd == nil {
          let request = GADRequest()
          interstitialAd =
            try await GADAppOpenAd
            .load(withAdUnitID: adUnitId, request: request)
        }

        class Delegate: NSObject, GADFullScreenContentDelegate, @unchecked Sendable {
          let continuation: AsyncThrowingStream<DelegateEvent, Error>.Continuation

          init(continuation: AsyncThrowingStream<DelegateEvent, Error>.Continuation) {
            self.continuation = continuation
          }

          func adDidRecordImpression(_ ad: any GADFullScreenPresentingAd) {
            logger.info("Ad did record impression")
            continuation.yield(.adDidRecordImpression)
          }

          func adDidRecordClick(_ ad: any GADFullScreenPresentingAd) {
            logger.info("Ad did record click")
            continuation.yield(.adDidRecordClick)
          }

          func ad(
            _ ad: any GADFullScreenPresentingAd,
            didFailToPresentFullScreenContentWithError error: any Error
          ) {
            logger.error("Ad failed to present full screen content: \(error.localizedDescription)")
            Task {
              await MainActor.run {
                AdClient.isShowingFullscreenAd = false
              }
            }
           
            continuation.yield(.didFailToPresentFullScreenContentWithError(error))
            continuation.finish()
          }

          func adDidDismissFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
            logger.info("Ad did dismiss full screen content")
            Task {
              await MainActor.run {
                AdClient.isShowingFullscreenAd = false
              }
            }
            continuation.yield(.adDidDismissFullScreenContent)
            continuation.finish()
          }

          func adWillDismissFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
            logger.info("Ad will dismiss full screen content")
            continuation.yield(.adWillDismissFullScreenContent)
          }

          func adWillPresentFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
            logger.info("Ad will present full screen content")
            continuation.yield(.adWillPresentFullScreenContent)
          }
        }
        return AsyncThrowingStream<DelegateEvent, Error> { continuation in
          Task {
            await MainActor.run {
              if AdClient.isShowingFullscreenAd {
                continuation.finish()
                return
              }

              let delegate = Delegate(continuation: continuation)
              self.interstitialAd?.fullScreenContentDelegate = delegate
              self.interstitialAd.present(fromRootViewController: nil)
              AdClient.isShowingFullscreenAd = true
              continuation.onTermination = { _ in
                _ = delegate
                Task {
                  try? await self.preloadAd(adUnitId: adUnitId)
                }
              }
            }
          }
        }
      }
    }

    let interstitialPresenter = InterstitialPresenter()
    let interstitialClient = InterstitialClient(
      preloadAd: interstitialPresenter.preloadAd(adUnitId:),
      present: interstitialPresenter.present)
    
    let rewardedInterstitialPresenter = RewardedInterstitialPresenter()
    let rewardedInterstitialClient = RewardInterstitialClient(
      preloadAd: rewardedInterstitialPresenter.preloadAd(adUnitId:),
      present: rewardedInterstitialPresenter.present)
    
    let rewardedPresenter = RewardedPresenter()
    let rewardClient = RewardClient(
      preloadAd: rewardedPresenter.preloadAd(adUnitId:),
      present: rewardedPresenter.present)
    
    let appOpenPresenter = AppOpenPresenter()
    let appOpenClient = AppOpenClient(
      preloadAd: appOpenPresenter.preloadAd(adUnitId:),
      present: appOpenPresenter.present)

    return .init(
      interstitialClient: interstitialClient,
      rewardInterstitialClient: rewardedInterstitialClient,
      rewardClient: rewardClient,
      appOpenClient: appOpenClient
    )
  }
}

extension DependencyValues {
  public var adClient: AdClient {
    get { self[AdClient.self] }
    set { self[AdClient.self] = newValue }
  }
}
