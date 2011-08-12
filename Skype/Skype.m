//
//  Skype.m
//  Skype
//
//  Created by Frank on 08/08/11.
//  Copyright 2011 Tapbits, LLC. All rights reserved.
//

#import <objc/runtime.h>
#import "Skype.h"

static BOOL window_is_fullscreen(NSWindow *window) {
    return !!([window styleMask] & NSFullScreenWindowMask);
}

static BOOL is_supported_window(NSWindow *window) {
    // a good test is to see if a window has the (+) button in the titlebar
    if (!([window styleMask] & NSResizableWindowMask)) return NO;
    
    Class class = [window class];
    NSString *className = NSStringFromClass(class);
    
    // ignore private windows, probably a good idea?
    if ([className hasPrefix:@"_"]) return NO;
    
    // panels are supposedly "auxiliary" windows
    if ([window isKindOfClass:NSClassFromString(@"NSPanel")]) return NO;
    
    return YES;
}

static id (*original_window_initwithcontentrect_stylemask_backing_defer)(NSWindow *self, SEL _cmd, NSRect contentRect, NSUInteger windowStyle, NSBackingStoreType bufferingType, BOOL deferCreation);
static id window_initwithcontentrect_stylemask_backing_defer(NSWindow *self, SEL _cmd, NSRect contentRect, NSUInteger windowStyle, NSBackingStoreType bufferingType, BOOL deferCreation) {
    self = original_window_initwithcontentrect_stylemask_backing_defer(self, _cmd, contentRect, windowStyle, bufferingType, deferCreation);
    
    // run this on the next runloop iteration because we might want
    // to check is_supported_window() after the window has been setup
    dispatch_async(dispatch_get_main_queue(), ^{
        if (is_supported_window(self)) {
#ifdef DEBUG
            // This is useful to determinte the class of malfunctioning NSWindow instances.
            NSLog(@"Supported window created of class: %@", [self class]);
#endif
            
            // this adds the full-screen behaviors, keeping the old ones
            [self setCollectionBehavior:[self collectionBehavior]];
        } else {
#ifdef DEBUG
            // This is useful to determinte the class of unsupported-but-should-be NSWindow instances.
            NSLog(@"Unsupported window created of class: %@", [self class]);
#endif
        }
    });
    
    return self;
}

static void (*original_window_setcollectionbehavior)(NSWindow *self, SEL _cmd, NSWindowCollectionBehavior behavior);
static void window_setcollectionbehavior(NSWindow *self, SEL _cmd, NSWindowCollectionBehavior behavior) {
    if (is_supported_window(self)) {
        behavior |= NSWindowCollectionBehaviorFullScreenPrimary | NSWindowCollectionBehaviorFullScreenAuxiliary;
    }
    
    original_window_setcollectionbehavior(self, _cmd, behavior);
}

@implementation Skype

+ (void)hookClass:(Class)class selector:(SEL)selector replacement:(IMP)replacement original:(IMP *)original {
    if (class == nil || selector == NULL || replacement == NULL) {
        NSLog(@"ERROR: Couldn't hook because a required argument was nil or NULL.");
        return;
    }
    
    Method method = class_getInstanceMethod(class, selector);
    
    if (method == NULL) {
        NSLog(@"ERROR: Unable to find method [%@ %@].", class, NSStringFromSelector(selector));
        return;
    }
    
    IMP result = method_setImplementation(method, replacement);
    
    if (original != NULL) {
        *original = result;
    }
}

+ (void)addToClass:(Class)class selector:(SEL)selector implementation:(IMP)implementation encoding:(const char *)types {
    BOOL success = class_addMethod(class, selector, implementation, types);
    
    if (!success) {
        NSLog(@"ERROR: Unable to add [%@ %@].", class, NSStringFromSelector(selector));
        return;
    }
}

+ (void)load {
    static Skype *skype = nil;
    
    if (skype == nil) {
        skype = [[self alloc] init];
        
#ifdef DEBUG
        NSLog(@"Loading Skypeskype into bundle: %@", [[NSBundle mainBundle] bundleIdentifier]);
#endif
        
        [[self class] hookClass:[NSWindow class] selector:@selector(initWithContentRect:styleMask:backing:defer:) replacement:(IMP) window_initwithcontentrect_stylemask_backing_defer original:(IMP *) &original_window_initwithcontentrect_stylemask_backing_defer];
        [[self class] hookClass:[NSWindow class] selector:@selector(setCollectionBehavior:) replacement:(IMP) window_setcollectionbehavior original:(IMP *) &original_window_setcollectionbehavior];
        
        for (NSWindow *window in [[NSApplication sharedApplication] windows]) {
            if (is_supported_window(window)) {
                // the hook for this adds the zoom button
                [window setCollectionBehavior:[window collectionBehavior]];
            }
        }
    }
}

@end
