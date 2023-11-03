//
//  ButtonState+Roles9.swift
//  
//
//  Created by Gleb Kovalenko on 03.11.2023.
//

extension ButtonState {
    
    public static func cancel(
        _ label: String, send: Action? = nil
    ) -> Self {
        Self(role: .cancel, action: ButtonStateAction.send(send)) {
            TextState(label)
        }
    }
    
    public static func `default`(
        _ label: String, send: Action? = nil
    ) -> Self {
        Self(action: ButtonStateAction.send(send)) {
            TextState(label)
        }
    }
    
    public static func destructive(
        _ label: String, send: Action? = nil
    ) -> Self {
        Self(role: .destructive, action: ButtonStateAction.send(send)) {
            TextState(label)
        }
    }
}
