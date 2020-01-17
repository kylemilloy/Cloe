// Created by Gil Birman on 1/11/20.

import Combine
import Foundation

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
public func createPublisherMiddleware<State>() -> Middleware<State> {
  var cancellablesCache = [UUID:Set<AnyCancellable>]()

  return { (fullDispatch, getState, nextDispatch) in
    { action in
      switch action {
      case let publisherAction as PublisherAction<State>:
        publisherAction.execute(dispatch: dispatch, getState: getState)
      case let publisherAction as RetainedPublisherAction<State>:
        let refCount = Box(0)
        let uuid = UUID()
        let cleanup = {
          refCount.value -= 1
          if refCount.value == 0 {
            cancellablesCache[uuid] = nil
          }
          // Note: Negative ref count can happen for 2 reasons:
          // 1. cleanup() was called too many times
          // 2. the publisher is syncronous and calls cleanup before ref count is updated below
        }
        let cancellables = publisherAction.execute(
          dispatch: fullDispatch,
          getState: getState,
          cleanup: cleanup)
        if cancellables.count > 0 {
          refCount.value = cancellables.count
          cancellablesCache[uuid] = cancellables
        }
      default:
        nextDispatch(action)
      }
    }
  }
}