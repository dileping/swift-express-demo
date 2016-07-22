//
//  Async.swift
//  BrightFutures
//
//  Created by Thomas Visser on 09/07/15.
//  Copyright © 2015 Thomas Visser. All rights reserved.
//

import Foundation
import ExecutionContext

/// This queue is used for all callback related administrative tasks
/// to prevent that a callback is added to a completed future and never
/// executed or perhaps excecuted twice.
private let ec = ExecutionContext(kind: .Serial)// temporary solution to move out of Async to avoid creation of a queue each time. Actually we should get rid of it ideally

public class Async<Value>: AsyncType {

    typealias CompletionCallback = Value -> Void
    
    public private(set) var result: Value? {
        willSet {
            assert(result == nil)
        }
        
        didSet {
            assert(result != nil)
            runCallbacks()
        }
    }

    /// Upon completion of the future, all callbacks are asynchronously scheduled to their
    /// respective execution contexts (which is either given by the client or returned from
    /// DefaultThreadingModel). Inside the context, this semaphore will be used
    /// to make sure that all callbacks are executed serially.
    private let callbackExecutionSemaphore = LoopSemaphore(value: 1);
    private var callbacks = [CompletionCallback]()
    
    public required init() {
        
    }
    
    public required init(result: Value) {
        self.result = result
    }
    
    public required init(result: Value, delay: NSTimeInterval) {
        global.async(delay) {
            self.complete(result)
        }
    }
    
    public required init<A: AsyncType where A.Value == Value>(other: A) {
        completeWith(other)
    }
    
    public required init(@noescape resolver: (result: Value -> Void) -> Void) {
        resolver { val in
            self.complete(val)
        }
    }
    
    private func runCallbacks() {
        guard let result = self.result else {
            assert(false, "can only run callbacks on a completed future")
            return
        }
        
        for callback in self.callbacks {
            callback(result)
        }
        
        self.callbacks.removeAll()
    }
    
    /// Adds the given closure as a callback for when the Async completes. The closure is executed on the given context.
    /// If no context is given, the behavior is defined by the default threading model (see README.md)
    /// Returns self
    public func onComplete(context: ExecutionContextType = DefaultThreadingModel(), callback: Value -> Void) -> Self {
        let wrappedCallback : Value -> Void = { [weak self] value in
            let a = self // this is a workaround for a compiler segfault
            
            context.execute {
                a?.callbackExecutionSemaphore.execute {
                    callback(value)
                }
                return
            }
        }
        
        try! ec.sync {
            if let value = self.result {
                wrappedCallback(value)
            } else {
                self.callbacks.append(wrappedCallback)

            }
        }
        
        return self
    }
    
}

extension Async: MutableAsyncType {
    func tryComplete(value: Value) -> Bool{
        return try! ec.sync {
            guard self.result == nil else {
                return false
            }
            
            self.result = value
            return true
        }
    }
}

extension Async: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return "Async<\(Value.self)>(\(self.result))"
    }
    
    public var debugDescription: String {
        return description
    }
}
