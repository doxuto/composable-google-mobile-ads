# Composable Google Mobile Ads SWiftUI/ UIKit

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A Swift package that integrates Google Mobile Ads (AdMob) with the Composable Architecture (TCA). This repository simplifies the use of Google AdMob in TCA-based projects, providing reusable and modular components for displaying banner, interstitial, and rewarded ads.

---

## Features

- **Composable Architecture Integration**: Works seamlessly with the Composable Architecture (TCA).
- **Banner Ads**: Display AdMob banner ads with ease.
- **Interstitial Ads**: Manage full-screen ads with proper lifecycle handling.
- **Rewarded Ads**: Implement rewarded ads to enhance user engagement.
- **Configuration Options**: Customize ad unit IDs and ad presentation logic.
- **Lightweight**: Modular and focused design with minimal dependencies.

---

## Installation

To integrate `ComposableGoogleMobileAds` into your project, use Swift Package Manager (SPM):

1. Open your Xcode project.
2. Navigate to **File > Add Packages**.
3. Enter the repository URL: https://github.com/doxuto/composable-google-mobile-ads
4. Choose a version or branch and add the package.

---

## Requirements

- **iOS**: 14.0+
- **Swift**: 5.6+
- **Composable Architecture**: Latest version supported by your project.

---

## Usage

### 1. Import the Package
```swift
import ComposableGoogleMobileAds

@Reducer
public struct BookDetail: Sendable {
  @Dependency(\.adClient) var adClient
....
 public enum Action {
  ....
  case adFullscreenDelegate(Result<AsyncThrowingStream<AdClient.DelegateEvent, Error>, Error>)
 }

 public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
        ...
        case .presentInterstitialAd:
          return .run { [interstitialAdUnit = state.interstitialAdUnit] send in
          await send(
            .adFullscreenDelegate(
              await Result {
                try await adClient.interstitialClient.present(interstitialAdUnit)
              }
            )
          )
        }

        case .adFullscreenDelegate(.success(let result)):
          return .run { send in
            do {
              for try await event in result {
                switch event {
                  case .adDidDismissFullScreenContent,
                      .didFailToPresentFullScreenContentWithError:
                    // Handle logic code
                  default:
                    break
                }
              }
            } catch {
            // Handle error logic
            }
          }
        case .adFullscreenDelegate(.failure):
        ...
      }
    }
}

