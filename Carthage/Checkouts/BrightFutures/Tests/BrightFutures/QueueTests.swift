// The MIT License (MIT)
//
// Copyright (c) 2014 Thomas Visser
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import XCTest
import BrightFutures
import ExecutionContext
import Result

class QueueTests: XCTestCase {

    func testMain() {
        let e = self.expectationWithDescription("")
        global.async {
            main.sync {
                XCTAssert(isMainThread(), "executing on the main queue should happen on the main thread")
            }
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testSync() {
        var i = 1
        global.sync {
            i++
        }
        XCTAssert(i == 2, "sync should execute the block synchronously")
    }
    
    func testSyncWithResult() {
        let input = "42"
        let output: String = global.sync {
            input
        }
        
        XCTAssertEqual(input, output, "sync should return the return value of the block")
    }
    
    func testSyncThrowsNone() {
        let t: () throws -> Void = { }
        do {
            try global.sync(t)
            XCTAssert(true)
        } catch _ {
            XCTFail()
        }
    }
    
    func testSyncThrowsError() {
        let t: () throws -> Void = { throw TestError.JustAnError }
        do {
            try global.sync(t)
            XCTFail()
        } catch TestError.JustAnError {
            XCTAssert(true)
        } catch _ {
            XCTFail()
        }
    }
    
    func testAsync() {
        var res = 2
        let e = self.expectationWithDescription("")
        global.async {
            NSThread.sleepForTimeInterval(1.0)
            res *= 2
            e.fulfill()
        }
        res += 2
        self.waitForExpectationsWithTimeout(2, handler: nil)
        XCTAssertEqual(res, 8, "async should not execute immediately")
    }
    
    func testAsyncFuture() {
        // unfortunately, the compiler is not able to figure out that we want the
        // future-returning async method
        let f: Future<String, NoError> = future(global) {
            NSThread.sleepForTimeInterval(1.0)
            return "fibonacci"
        }
        
        let e = self.expectationWithDescription("")
        f.onSuccess { val in
            XCTAssertEqual(val, "fibonacci", "the future should succeed with the value from the async block")
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testAfter() {
        var res = 2
        let e = self.expectationWithDescription("")
        global.async(1.0) {
            res *= 2
            e.fulfill()
        }
        res += 2
        self.waitForExpectationsWithTimeout(2, handler: nil)
        XCTAssertEqual(res, 8, "delay should not execute immediately")
    }

    func testAfterFuture() {
        // unfortunately, the compiler is not able to figure out that we want the
        // future-returning async method
        let f: Future<String, NoError> = Future { complete in
            global.async(1.0) {
                complete(.Success("fibonacci"))
            }
        }
        
        let e = self.expectationWithDescription("")
        f.onSuccess { val in
            XCTAssertEqual(val, "fibonacci", "the future should succeed with the value from the async block")
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }

}

#if os(Linux)
extension QueueTests : XCTestCaseProvider {
	var allTests : [(String, () throws -> Void)] {
		return [
			("testMain", testMain),
			("testSync", testSync),
			("testSyncWithResult", testSyncWithResult),
			("testSyncThrowsNone", testSyncThrowsNone),
			("testSyncThrowsError", testSyncThrowsError),
			("testAsync", testAsync),
			("testAsyncFuture", testAsyncFuture),
			("testAfter", testAfter),
			("testAfterFuture", testAfterFuture),
		]
	}
}
#endif