//
//  AlertState+Init.swift
//  
//
//  Created by Gleb Kovalenko on 03.11.2023.
//

extension AlertState {
    
    public init(
        title: String,
        primaryButton: ButtonState<Action>,
        secondaryButton: ButtonState<Action>
    ) {
        self.init(
            title: TextState(title),
            primaryButton: primaryButton,
            secondaryButton: secondaryButton
        )
    }
}
