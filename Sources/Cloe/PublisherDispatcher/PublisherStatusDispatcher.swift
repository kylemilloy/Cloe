// Created by Gil Birman on 1/19/20.

import Combine
import Foundation

/// Track the status of a Combine Publisher
public enum PublisherStatus<Failure: Error> {
  case initial
  case loading
  case loadingWithOutput
  case completed
  case completedWithOutput
  case failed(_ error: Failure)
  case cancelled
}

extension PublisherStatus {
  public var isLoading: Bool {
    switch self {
    case .loading, .loadingWithOutput:
      return true
    default:
      return false
    }
  }

  public var isCompleted: Bool {
    switch self {
    case .completed, .completedWithOutput:
      return true
    default:
      return false
    }
  }

  public var isDone: Bool {
    switch self {
    case .cancelled, .completed, .completedWithOutput, .failed(_):
      return true
    default:
      return false
    }
  }
}

extension PublisherStatus: Equatable {
  public static func == (lhs: PublisherStatus, rhs: PublisherStatus) -> Bool {
    switch (lhs, rhs) {
    case (.initial, .initial),
         (.loading, .loading),
         (.loadingWithOutput, .loadingWithOutput),
         (.completed, .completed),
         (.completedWithOutput, .completedWithOutput),
         (.cancelled, .cancelled),
          // Since a Publisher can only fail once and it must
          // enter a different state before failing, this should
          // be the correct assumption for the failed case so long as
          // we don't do anything weird with PublisherStatus
         (.failed(_), .failed(_)):
      return true
    default:
      return false
    }
  }
}

extension Publisher {
  /// Automatically dispatches actions on your behalf to update the
  /// state of a `PublisherStatus` object in your store.
  ///
  /// The dispatched actions are not intended to be used in any way
  /// that isn't already supported by the PublisherDispatcher reducer.
  public func statusDispatcher<State>(
    _ dispatch: @escaping Dispatch,
    statePath: WritableKeyPath<State, PublisherStatus<Failure>>,
    description: String? = nil)
    -> Publishers.HandleEvents<Self>
  {
    var fullDescription = "[StateDispatcher]"
    if let description = description {
      fullDescription += " \(description)"
    }
    return handleEvents(
      receiveOutput: { _ in
        dispatch(PublisherDispatcherAction<State>(.loadingWithOutput, description: fullDescription) { state in
          state[keyPath: statePath] = .loadingWithOutput
        })
      },
      receiveCompletion: { completion in
        switch completion {
        case .failure(let error):
          dispatch(PublisherDispatcherAction<State>(.failed, description: fullDescription) { state in
            state[keyPath: statePath] = .failed(error)
          })
        case .finished:
          dispatch(PublisherDispatcherAction<State>(.finished, description: fullDescription) { state in
            if case .loadingWithOutput = state[keyPath: statePath] {
              state[keyPath: statePath] = .completedWithOutput
            } else {
              state[keyPath: statePath] = .completed
            }
          })
        }
      },
      receiveCancel: {
        dispatch(PublisherDispatcherAction<State>(.cancelled, description: fullDescription) { state in
          state[keyPath: statePath] = .cancelled
        })
      },
      receiveRequest: { _ in
        dispatch(PublisherDispatcherAction<State>(.loading, description: fullDescription) { state in
          state[keyPath: statePath] = .loading
        })
      })
  }
}
