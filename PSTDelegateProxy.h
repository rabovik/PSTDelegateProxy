//
// PSTDelegateProxy.h
//
// Copyright (c) 2013 Peter Steinberger (http://petersteinberger.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
#import <Foundation/Foundation.h>

// Add this define into your implementation to save the delegate into the delegate proxy.
// You will also require an internal declaration as follows:
// @property (nonatomic, strong) id<XXXDelegate> delegateProxy;
#define PST_DELEGATE_PROXY(protocolname) \
- (void)setDelegate:(id<protocolname>)delegate { self.delegateProxy = delegate ? (id<protocolname>)[[PSPDFDelegateProxy alloc] initWithDelegate:delegate conformingToProtocol:@protocol(protocolname)] : nil; } \
- (id<protocolname>)delegate { return ((PSPDFDelegateProxy *)self.delegateProxy).delegate; }

// Forwards calls to a delegate. Uses modern message forwarding with almost no runtime overhead.
@interface PSTDelegateProxy : NSProxy

// Designated initializer. `delegate` can be nil.
- (id)initWithDelegate:(id)delegate conformingToProtocol:(Protocol*)protocol;

// Returns an object that will return YES for messages that return a BOOL if they are not implemented.
- (instancetype)YESDefault;

// Returns an object that will return default value for not implemented methods.
// Non-object types must be wrapped in NSValue (or NSNumber).
- (instancetype)defaultReturn:(id)defaultReturn;

// The internal (weak) delegate.
@property (nonatomic, weak, readonly) id delegate;

// The property we allow calling to.
@property (nonatomic, strong, readonly) Protocol *protocol;

@end
