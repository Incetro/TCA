//
//  AlertState+Init.swift
//
//
//  Created by Gleb Kovalenko on 03.11.2023.
//

extension AlertState {

  public init(
    title: String,
    message: String? = nil,
    primaryButton: ButtonState<Action>,
    secondaryButton: ButtonState<Action>
  ) {
    self.init(
      title: TextState(title),
      message: message == nil ? nil : TextState(message.unsafelyUnwrapped),
      primaryButton: primaryButton,
      secondaryButton: secondaryButton
    )
  }
  public init(
    title: String,
    message: String? = nil
  ) {
    self.init(
      title: TextState(title),
      message: message == nil ? nil : TextState(message.unsafelyUnwrapped),
      dismissButton: nil
    )
  }
}
