//
//  File.swift
//
//
//  Created by Dmitry Savinov on 30.10.2023.
//

import Foundation

// MARK: - Store

extension Store {

  /// Scopes the store to one that exposes child state.
  ///
  /// A version of ``scope(state:action:)`` that leaves the action type unchanged.
  ///
  /// - Parameter toChildState: A function that transforms `State` into `ChildState`.
  /// - Returns: A new store with its domain (state and action) transformed.
  public func scope<ChildState>(
    state toChildState: @escaping (State) -> ChildState
  ) -> Store<ChildState, Action> {
    self.scope(state: toChildState, action: { $0 })
  }
}
