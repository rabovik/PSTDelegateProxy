//
// PSTDelegateProxy.m
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

#import "PSTDelegateProxy.h"
#import <objc/runtime.h>
#import <libkern/OSAtomic.h>

@interface PSTDefaultingDelegateProxy : PSTDelegateProxy
- (id)initWithDelegate:(id)delegate conformingToProtocol:(Protocol *)protocol defaultReturn:(id)defaultReturn;
@end

@implementation PSTDelegateProxy {
    CFDictionaryRef _signatures;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithDelegate:(id)delegate conformingToProtocol:(Protocol *)protocol {
    NSParameterAssert(protocol);
    if (self) {
        _delegate = delegate;
        _protocol = protocol;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p delegate:%@ protocol:%@>", self.class, self, self.delegate, self.protocol];
}

- (BOOL)respondsToSelector:(SEL)selector {
    return [_delegate respondsToSelector:selector];
}

- (id)forwardingTargetForSelector:(SEL)selector {
    id delegate = _delegate;
    return [delegate respondsToSelector:selector] ? delegate : self;
}

// Regular message forwarding continues if delegate doesn't respond to selector or is nil.
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    NSMethodSignature *signature = [_delegate methodSignatureForSelector:selector];
    if (!signature) {
        if (!_signatures) _signatures = [self methodSignaturesForProtocol:_protocol];
        signature = CFDictionaryGetValue(_signatures, selector);
    }
    return signature;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    // Ignore built invocation.
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

- (instancetype)YESDefault {
    return [self defaultReturn:@YES];
}

- (instancetype)defaultReturn:(id)defaultReturn {
    return [[PSTDefaultingDelegateProxy alloc] initWithDelegate:self.delegate
                                           conformingToProtocol:self.protocol
                                                   defaultReturn:defaultReturn];
}


///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private

static CFMutableDictionaryRef _protocolCache = nil;
static OSSpinLock _lock = OS_SPINLOCK_INIT;

- (CFDictionaryRef)methodSignaturesForProtocol:(Protocol *)protocol {
    OSSpinLockLock(&_lock);
    // Cache lookup
    if (!_protocolCache) _protocolCache = CFDictionaryCreateMutable(NULL, 0, NULL, &kCFTypeDictionaryValueCallBacks);
    CFDictionaryRef signatureCache = CFDictionaryGetValue(_protocolCache, (__bridge const void *)(protocol));

    if (!signatureCache) {
        // Add protocol methods + derived protocol method definitions into protocolCache.
        signatureCache = CFDictionaryCreateMutable(NULL, 0, NULL, &kCFTypeDictionaryValueCallBacks);
        [self methodSignaturesForProtocol:protocol inDictionary:(CFMutableDictionaryRef)signatureCache];
        CFDictionarySetValue(_protocolCache, (__bridge const void *)(protocol), signatureCache);
        CFRelease(signatureCache);
    }
    OSSpinLockUnlock(&_lock);
    return signatureCache;
}

- (void)methodSignaturesForProtocol:(Protocol *)protocol inDictionary:(CFMutableDictionaryRef)cache {
    void (^enumerate)(BOOL, BOOL) = ^(BOOL isRequired, BOOL isInstance) {
        unsigned int methodCount;
        struct objc_method_description *descr = protocol_copyMethodDescriptionList(protocol, isRequired, isInstance, &methodCount);
        for (NSUInteger idx = 0; idx < methodCount; idx++) {
            NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:descr[idx].types];
            CFDictionarySetValue(cache, descr[idx].name, (__bridge const void *)(signature));
        }
        free(descr);
    };
    // We need to enumerate all possible combinations here.
    enumerate(NO, NO); enumerate(YES, NO); enumerate(NO,YES); enumerate(YES, YES);

    // There might be sub-protocols we need to catch as well.
    unsigned int inheritedProtocolCount;
    Protocol *__unsafe_unretained* inheritedProtocols = protocol_copyProtocolList(protocol, &inheritedProtocolCount);
    for (NSUInteger idx = 0; idx < inheritedProtocolCount; idx++) {
        [self methodSignaturesForProtocol:inheritedProtocols[idx] inDictionary:cache];
    }
    free(inheritedProtocols);
}
@end

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSTYESDelegateProxy

@implementation PSTDefaultingDelegateProxy{
    id _defaultReturn;
}

- (id)initWithDelegate:(id)delegate conformingToProtocol:(Protocol *)protocol defaultReturn:(id)defaultReturn {
    NSParameterAssert(defaultReturn);
    self = [super initWithDelegate:delegate conformingToProtocol:protocol];
    if (nil == self) return nil;
    
    _defaultReturn = defaultReturn;
    
    return self;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    const char *returnType = invocation.methodSignature.methodReturnType;
    
    BOOL voidReturnType = (0 == strncmp("v", returnType, 1));
    if (voidReturnType) {
        @throw [NSException
                exceptionWithName:@"PSTDelegateProxyException"
                reason:[NSString stringWithFormat:
                        @"Default value can not be used for methods with void return type."]
                userInfo:nil];
    }
    
    BOOL objectReturnType = (0 == strncmp("@", returnType, 1));
    if (objectReturnType) {
        [invocation setReturnValue:&_defaultReturn];
    }else{
        if (![_defaultReturn isKindOfClass:[NSValue class]]) {
            @throw [NSException
                    exceptionWithName:@"PSTDelegateProxyException"
                    reason:[NSString stringWithFormat:
                            @"Default value for return type %s should be kind of NSValue",
                            returnType]
                    userInfo:nil];
        }
        
        const char *defaultType = [(NSValue *)_defaultReturn objCType];
        
        BOOL typeMatch = (0 == strcmp(defaultType, returnType));
        if (!typeMatch) {
            @throw [NSException
                    exceptionWithName:@"PSTDelegateProxyException"
                    reason:[NSString stringWithFormat:
                            @"Default value type %s and return type %s do not match",
                            defaultType,
                            returnType]
                    userInfo:nil];
        }
        
        NSUInteger returnLength = invocation.methodSignature.methodReturnLength;
        char buffer[returnLength];
        [(NSValue *)_defaultReturn getValue:buffer];
        [invocation setReturnValue:&buffer];   
    }
}

@end
