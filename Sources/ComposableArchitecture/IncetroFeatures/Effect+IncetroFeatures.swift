//
//  File.swift
//
//
//  Created by Gleb Kovalenko on 06.03.2024.
//

// MARK: - Effect

extension Effect {

  public static func async(
    priority: TaskPriority? = nil,
    action: @escaping @Sendable () async throws -> Action,
    catch handler: (@Sendable (_ error: Error, _ send: Send<Action>) async -> Void)? = nil,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    withEscapedDependencies { escaped in
      Self(
        operation: .run(priority) { send in
          await escaped.yield {
            do {
              try await send(action())
            } catch is CancellationError {
              return
            } catch {
              guard let handler = handler else {
                return
              }
              await handler(error, send)
            }
          }
        }
      )
    }
  }
}
