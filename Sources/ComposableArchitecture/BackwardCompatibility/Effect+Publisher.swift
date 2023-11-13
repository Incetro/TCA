//
//  Effect+Publisher.swift
//  
//
//  Created by Dmitry Savinov on 30.10.2023.
//

import Combine
import CombineSchedulers

// MARK: - Publisher+Effect

extension Publisher {
    
    public func catchToEffect() -> Effect<Result<Output, Failure>> {
        self.catchToEffect { $0 }
    }
    
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
    
    /// Turns any publisher into an ``EffectPublisher``.
    ///
    /// This can be useful for when you perform a chain of publisher transformations in a reducer, and
    /// you need to convert that publisher to an effect so that you can return it from the reducer:
    ///
    /// ```swift
    /// case .buttonTapped:
    ///   return fetchUser(id: 1)
    ///     .filter(\.isAdmin)
    ///     .eraseToEffect()
    /// ```
    ///
    /// - Returns: An effect that wraps `self`.
    public func eraseToEffect() -> Effect<Output> where Failure == Never {
        Effect.publisher {
            self
        }
    }
    
    /// Turns any publisher into an ``Effect`` for any output and failure type by ignoring
    /// all output and any failure.
    ///
    /// This is useful for times you want to fire off an effect but don't want to feed any data back
    /// into the system. It can automatically promote an effect to your reducer's domain.
    ///
    /// ```swift
    /// case .buttonTapped:
    ///   return analyticsClient.track("Button Tapped")
    ///     .fireAndForget()
    /// ```
    ///
    /// - Parameters:
    ///   - outputType: An output type.
    /// - Returns: An effect that never produces output or errors.
    public func fireAndForget<NewOutput>(
        outputType: NewOutput.Type = NewOutput.self
    ) -> Effect<NewOutput> {
        self
            .flatMap { _ in Empty<NewOutput, Failure>() }
            .catch { _ in Empty<NewOutput, Never>() }
            .eraseToEffect()
    }
}

// MARK: - Effect

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
    
    /// Initializes an effect from a callback that can send as many values as it wants, and can send
    /// a completion.
    ///
    /// This initializer is useful for bridging callback APIs, delegate APIs, and manager APIs to the
    /// ``Effect`` type. One can wrap those APIs in an Effect so that its events are sent
    /// through the effect, which allows the reducer to handle them.
    ///
    /// For example, one can create an effect to ask for access to `MPMediaLibrary`. It can start by
    /// sending the current status immediately, and then if the current status is `notDetermined` it
    /// can request authorization, and once a status is received it can send that back to the effect:
    ///
    /// ```swift
    /// EffectPublisher.run { subscriber in
    ///   subscriber.send(MPMediaLibrary.authorizationStatus())
    ///
    ///   guard MPMediaLibrary.authorizationStatus() == .notDetermined else {
    ///     subscriber.send(completion: .finished)
    ///     return AnyCancellable {}
    ///   }
    ///
    ///   MPMediaLibrary.requestAuthorization { status in
    ///     subscriber.send(status)
    ///     subscriber.send(completion: .finished)
    ///   }
    ///   return AnyCancellable {
    ///     // Typically clean up resources that were created here, but this effect doesn't
    ///     // have any.
    ///   }
    /// }
    /// ```
    ///
    /// - Parameter work: A closure that accepts a ``Subscriber`` value and returns a cancellable.
    ///   When the ``Effect`` is completed, the cancellable will be used to clean up any
    ///   resources created when the effect was started.
    public static func run(
        _ work: @escaping (Effect.Subscriber) -> Cancellable
    ) -> Self {
        let dependencies = DependencyValues._current
        return AnyPublisher.create { subscriber in
            DependencyValues.$_current.withValue(dependencies) {
                work(subscriber)
            }
        }
        .eraseToEffect()
    }
    
    /// Creates an effect that executes some work in the real world that doesn't need to feed data
    /// back into the store. If an error is thrown, the effect will complete and the error will be
    /// ignored.
    ///
    /// - Parameter work: A closure encapsulating some work to execute in the real world.
    /// - Returns: An effect.
    public static func fireAndForget(_ work: @escaping () throws -> Void) -> Self {
        .run { _ in
            try work()
        }
    }
    
    public func fireAndForget<NewOutput>(
        outputType: NewOutput.Type = NewOutput.self
    ) -> Effect<NewOutput> {
        self
            .publisher
            .fireAndForget()
    }
}
