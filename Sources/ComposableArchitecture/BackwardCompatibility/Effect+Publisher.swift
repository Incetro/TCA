//
//  Effect+Publisher.swift
//  
//
//  Created by Dmitry Savinov on 30.10.2023.
//

import Combine

// MARK: - Publisher+Effect

extension Publisher {
    
    public func catchToEffect<T>(
        _ transform: @escaping (Result<Output, Failure>) -> T
    ) -> Effect<T> {
        let dependencies = DependencyValues._current
        let transform = { action in
            DependencyValues.$_current.withValue(dependencies) {
                transform(action)
            }
        }
        return Effect.publisher {
            self
                .map { transform(.success($0)) }
                .catch { Just(transform(.failure($0))) }
        }
    }
    
    public func catchToEffect<T>(
        _ transform: @escaping (Output) -> T
    ) -> Effect<T> where Failure == Never {
        Effect.publisher {
            self
                .map(transform)
        }
    }
}

extension Effect {
    
    public typealias Output = Action
    
    public func receive<S: Combine.Subscriber>(
        subscriber: S
    ) where S.Input == Action, S.Failure == Never {
        self.publisher.subscribe(subscriber)
    }
    
    var publisher: AnyPublisher<Action, Never> {
        switch self.operation {
        case .none:
            return Empty().eraseToAnyPublisher()
        case let .publisher(publisher):
            return publisher
        case let .run(priority, operation):
            return .create { subscriber in
                let task = Task(priority: priority) { @MainActor in
                    defer { subscriber.send(completion: .finished) }
                    let send = Send { subscriber.send($0) }
                    await operation(send)
                }
                return AnyCancellable {
                    task.cancel()
                }
            }
        }
    }
    
    /// Returns an effect that will be executed after given `dueTime`.
    ///
    /// ```swift
    /// case let .textChanged(text):
    ///   return self.apiClient.search(text)
    ///     .deferred(for: 0.5, scheduler: self.mainQueue)
    ///     .map(Action.searchResponse)
    /// ```
    ///
    /// - Parameters:
    ///   - dueTime: The duration you want to defer for.
    ///   - scheduler: The scheduler you want to deliver the defer output to.
    ///   - options: Scheduler options that customize the effect's delivery of elements.
    /// - Returns: An effect that will be executed after `dueTime`
    @available(
        iOS, deprecated: 9999.0, message: "Use 'clock.sleep' in `Effect.task` or 'Effect.run', instead."
    )
    @available(
        macOS, deprecated: 9999.0,
        message: "Use 'clock.sleep' in `Effect.task` or 'Effect.run', instead."
    )
    @available(
        tvOS, deprecated: 9999.0,
        message: "Use 'clock.sleep' in `Effect.task` or 'Effect.run', instead."
    )
    @available(
        watchOS, deprecated: 9999.0,
        message: "Use 'clock.sleep' in `Effect.task` or 'Effect.run', instead."
    )
    public func deferred<S: Scheduler>(
        for dueTime: S.SchedulerTimeType.Stride,
        scheduler: S,
        options: S.SchedulerOptions? = nil
    ) -> Self {
        switch self.operation {
        case .none:
            return .none
        case .publisher, .run:
            return Self(
                operation: .publisher(
                    Just(())
                        .delay(for: dueTime, scheduler: scheduler, options: options)
                        .flatMap { self.publisher.receive(on: scheduler) }
                        .eraseToAnyPublisher()
                )
            )
        }
    }
}
