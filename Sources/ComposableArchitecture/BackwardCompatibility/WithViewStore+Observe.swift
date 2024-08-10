//
//  WithViewStore+Observe.swift
//
//
//  Created by Dmitry Savinov on 30.10.2023.
//

import Foundation
import SwiftUI

// MARK: - WithViewStore+Observe

extension WithViewStore where ViewState: Equatable {

  public init(
    _ store: Store<ViewState, ViewAction>,
    @ViewBuilder content: @escaping (_ viewStore: ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(
      store: store,
      removeDuplicates: ==,
      content: content,
      file: file,
      line: line
    )
  }
}
