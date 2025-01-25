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
      @Sendable (String) async throws -> AsyncThrowingStream<
        DelegateEvent, Error
      > =
        { _ in .finished() }
  }

  @DependencyClient
  public struct RewardInterstitialClient: Sendable {
    public var preloadAd: @Sendable (String) async throws -> Void
    public var present:
      @Sendable (String) async throws -> AsyncThrowingStream<
        DelegateEvent, Error
      > =
        { _ in
          .finished()
        }
  }

  @DependencyClient
  public struct RewardClient: Sendable {
    public var preloadAd: @Sendable (String) async throws -> Void
    public var present:
      @Sendable (String) async throws -> AsyncThrowingStream<
        DelegateEvent, Error
      > =
        { _ in
          .finished()
        }
  }

  @DependencyClient
  public struct AppOpenClient: Sendable {
    public var preloadAd: @Sendable (String) async throws -> Void
    public var present:
      @Sendable (String) async throws -> AsyncThrowingStream<
        DelegateEvent, Error
      > =
        { _ in
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
        do {
          interstitialAd =
            try await GADInterstitialAd.load(
              withAdUnitID: adUnitId, request: request)
        } catch {
          let _error = error as NSError
          let adClientError =
            AdClientError(
              rawValue: _error.code
            ) ?? AdClientError.invalidRequest
          throw adClientError
        }
      }

      func present(adUnitId: String) async throws
        -> AsyncThrowingStream<
          DelegateEvent, Error
        >
      {
        if interstitialAd == nil {
          let request = GADRequest()
          do {
            interstitialAd =
              try await GADInterstitialAd.load(
                withAdUnitID: adUnitId, request: request)
          } catch {
            let _error = error as NSError
            let adClientError =
              AdClientError(
                rawValue: _error.code
              ) ?? AdClientError.invalidRequest
            throw adClientError
          }

        }

        class Delegate: NSObject, GADFullScreenContentDelegate, @unchecked
          Sendable
        {
          let continuation:
            AsyncThrowingStream<DelegateEvent, Error>.Continuation

          init(
            continuation: AsyncThrowingStream<DelegateEvent, Error>.Continuation
          ) {
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
            logger.error(
              "Ad failed to present full screen content: \(error.localizedDescription)"
            )
            Task {
              await MainActor.run {
                AdClient.isShowingFullscreenAd = false
              }
            }
            continuation.yield(
              .didFailToPresentFullScreenContentWithError(error))
            continuation.finish()
          }

          func adDidDismissFullScreenContent(
            _ ad: any GADFullScreenPresentingAd
          ) {
            logger.info("Ad did dismiss full screen content")
            Task {
              await MainActor.run {
                AdClient.isShowingFullscreenAd = false
              }
            }
            continuation.yield(.adDidDismissFullScreenContent)
            continuation.finish()
          }

          func adWillDismissFullScreenContent(
            _ ad: any GADFullScreenPresentingAd
          ) {
            logger.info("Ad will dismiss full screen content")
            continuation.yield(.adWillDismissFullScreenContent)
          }

          func adWillPresentFullScreenContent(
            _ ad: any GADFullScreenPresentingAd
          ) {
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
        do {
          rewardedInterstitialAd =
            try await GADRewardedInterstitialAd.load(
              withAdUnitID: adUnitId, request: request)
        } catch {
          let _error = error as NSError
          let adClientError =
            AdClientError(
              rawValue: _error.code
            ) ?? AdClientError.invalidRequest
          throw adClientError
        }
      }

      func present(adUnitId: String) async throws
        -> AsyncThrowingStream<DelegateEvent, Error>
      {
        if rewardedInterstitialAd == nil {
          let request = GADRequest()
          do {
            rewardedInterstitialAd =
              try await GADRewardedInterstitialAd.load(
                withAdUnitID: adUnitId, request: request)
          } catch {
            let _error = error as NSError
            let adClientError =
              AdClientError(
                rawValue: _error.code
              ) ?? AdClientError.invalidRequest
            throw adClientError
          }
        }

        class Delegate: NSObject, GADFullScreenContentDelegate, @unchecked
          Sendable
        {
          let continuation:
            AsyncThrowingStream<DelegateEvent, Error>.Continuation

          init(
            continuation: AsyncThrowingStream<DelegateEvent, Error>.Continuation
          ) {
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
            logger.error(
              "Ad failed to present full screen content: \(error.localizedDescription)"
            )
            Task {
              await MainActor.run {
                AdClient.isShowingFullscreenAd = false
              }
            }
            continuation.yield(
              .didFailToPresentFullScreenContentWithError(error))
            continuation.finish()
          }

          func adDidDismissFullScreenContent(
            _ ad: any GADFullScreenPresentingAd
          ) {
            logger.info("Ad did dismiss full screen content")
            Task {
              await MainActor.run {
                AdClient.isShowingFullscreenAd = false
              }
            }
            continuation.yield(.adDidDismissFullScreenContent)
            continuation.finish()
          }

          func adWillDismissFullScreenContent(
            _ ad: any GADFullScreenPresentingAd
          ) {
            logger.info("Ad will dismiss full screen content")
            continuation.yield(.adWillDismissFullScreenContent)
          }

          func adWillPresentFullScreenContent(
            _ ad: any GADFullScreenPresentingAd
          ) {
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
                let amountReward = self.rewardedInterstitialAd.adReward.amount
                  .doubleValue
                continuation.yield(.adDidEarnReward(amountReward))
                continuation.finish()
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
        do {
          rewardedAd =
            try await GADRewardedAd.load(
              withAdUnitID: adUnitId, request: request)
        } catch {
          let _error = error as NSError
          let adClientError =
            AdClientError(
              rawValue: _error.code
            ) ?? AdClientError.invalidRequest
          throw adClientError
        }
      }

      func present(adUnitId: String) async throws
        -> AsyncThrowingStream<DelegateEvent, Error>
      {
        if rewardedAd == nil {
          let request = GADRequest()
          do {
            rewardedAd =
              try await GADRewardedAd.load(
                withAdUnitID: adUnitId, request: request)
          } catch {
            let _error = error as NSError
            let adClientError =
              AdClientError(
                rawValue: _error.code
              ) ?? AdClientError.invalidRequest
            throw adClientError
          }
        }

        class Delegate: NSObject, GADFullScreenContentDelegate, @unchecked
          Sendable
        {
          let continuation:
            AsyncThrowingStream<DelegateEvent, Error>.Continuation

          init(
            continuation: AsyncThrowingStream<DelegateEvent, Error>.Continuation
          ) {
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
            logger.error(
              "Ad failed to present full screen content: \(error.localizedDescription)"
            )
            Task {
              await MainActor.run {
                AdClient.isShowingFullscreenAd = false
              }
            }
            continuation.yield(
              .didFailToPresentFullScreenContentWithError(error))
            continuation.finish()
          }

          func adDidDismissFullScreenContent(
            _ ad: any GADFullScreenPresentingAd
          ) {
            logger.info("Ad did dismiss full screen content")
            Task {
              await MainActor.run {
                AdClient.isShowingFullscreenAd = false
              }
            }
            continuation.yield(.adDidDismissFullScreenContent)
            continuation.finish()
          }

          func adWillDismissFullScreenContent(
            _ ad: any GADFullScreenPresentingAd
          ) {
            logger.info("Ad will dismiss full screen content")
            continuation.yield(.adWillDismissFullScreenContent)
          }

          func adWillPresentFullScreenContent(
            _ ad: any GADFullScreenPresentingAd
          ) {
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
      nonisolated(unsafe) var appOpenAd: GADAppOpenAd!

      func preloadAd(adUnitId: String) async throws {
        let request = GADRequest()
        do {
          appOpenAd =
            try await GADAppOpenAd.load(
              withAdUnitID: adUnitId, request: request)
        } catch {
          let _error = error as NSError
          let adClientError =
            AdClientError(
              rawValue: _error.code
            ) ?? AdClientError.invalidRequest
          throw adClientError
        }
      }

      func present(adUnitId: String) async throws
        -> AsyncThrowingStream<DelegateEvent, Error>
      {
        if appOpenAd == nil {
          let request = GADRequest()
          do {
            appOpenAd =
              try await GADAppOpenAd.load(
                withAdUnitID: adUnitId, request: request)
          } catch {
            let _error = error as NSError
            let adClientError =
              AdClientError(
                rawValue: _error.code
              ) ?? AdClientError.invalidRequest
            throw adClientError
          }
        }

        class Delegate: NSObject, GADFullScreenContentDelegate, @unchecked
          Sendable
        {
          let continuation:
            AsyncThrowingStream<DelegateEvent, Error>.Continuation

          init(
            continuation: AsyncThrowingStream<DelegateEvent, Error>.Continuation
          ) {
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
            logger.error(
              "Ad failed to present full screen content: \(error.localizedDescription)"
            )
            Task {
              await MainActor.run {
                AdClient.isShowingFullscreenAd = false
              }
            }

            continuation.yield(
              .didFailToPresentFullScreenContentWithError(error))
            continuation.finish()
          }

          func adDidDismissFullScreenContent(
            _ ad: any GADFullScreenPresentingAd
          ) {
            logger.info("Ad did dismiss full screen content")
            Task {
              await MainActor.run {
                AdClient.isShowingFullscreenAd = false
              }
            }
            continuation.yield(.adDidDismissFullScreenContent)
            continuation.finish()
          }

          func adWillDismissFullScreenContent(
            _ ad: any GADFullScreenPresentingAd
          ) {
            logger.info("Ad will dismiss full screen content")
            continuation.yield(.adWillDismissFullScreenContent)
          }

          func adWillPresentFullScreenContent(
            _ ad: any GADFullScreenPresentingAd
          ) {
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
              self.appOpenAd?.fullScreenContentDelegate = delegate
              self.appOpenAd.present(fromRootViewController: nil)
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

/// Error codes for GAD error domain.
public enum AdClientError: Int, Error, Sendable {
  /// The ad request is invalid. The localizedFailureReason error description will have more
  /// details. Typically this is because the ad did not have the ad unit ID or root view
  /// controller set.
  case invalidRequest = 0

  /// The ad request was successful, but no ad was returned.
  case noFill = 1

  /// There was an error loading data from the network.
  case networkError = 2

  /// The ad server experienced a failure processing the request.
  case serverError = 3

  /// The current device's OS is below the minimum required version.
  case osVersionTooLow = 4

  /// The request was unable to be loaded before being timed out.
  case timeout = 5

  /// The mediation response was invalid.
  case mediationDataError = 7

  /// Error finding or creating a mediation ad network adapter.
  case mediationAdapterError = 8

  /// Attempting to pass an invalid ad size to an adapter.
  case mediationInvalidAdSize = 10

  /// Internal error.
  case internalError = 11

  /// Invalid argument error.
  case invalidArgument = 12

  /// Received invalid response.
  case receivedInvalidResponse = 13

  /// Will not send request because the ad object has already been used.
  case adAlreadyUsed = 19

  /// Will not send request because the application identifier is missing.
  case applicationIdentifierMissing = 20

  /// A mediation ad network adapter received an ad request, but did not fill. The adapter's error
  /// is included as an underlyingError. (Deprecated)
  @available(
    *, deprecated,
    message:
      "This error will be replaced with GADErrorCode.noFill in a future version"
  )
  case mediationNoFill = 9

  /// A localized description for the error code.
  public var localizedDescription: String {
    switch self {
    case .invalidRequest:
      return
        "The ad request is invalid. Ensure the ad unit ID or root view controller is set."
    case .noFill:
      return "The ad request was successful, but no ad was returned."
    case .networkError:
      return "There was an error loading data from the network."
    case .serverError:
      return "The ad server experienced a failure processing the request."
    case .osVersionTooLow:
      return "The current device's OS is below the minimum required version."
    case .timeout:
      return "The request timed out before being loaded."
    case .mediationDataError:
      return "The mediation response was invalid."
    case .mediationAdapterError:
      return "Error finding or creating a mediation ad network adapter."
    case .mediationInvalidAdSize:
      return "Attempting to pass an invalid ad size to an adapter."
    case .internalError:
      return "An internal error occurred."
    case .invalidArgument:
      return "An invalid argument was provided."
    case .receivedInvalidResponse:
      return "The response received was invalid."
    case .adAlreadyUsed:
      return "The ad object has already been used and cannot be reused."
    case .applicationIdentifierMissing:
      return "The application identifier is missing. Ensure it is set."
    case .mediationNoFill:
      return
        "A mediation ad network adapter did not fill the request. This error is deprecated and will be replaced with GADErrorCode.noFill."
    }
  }
}
