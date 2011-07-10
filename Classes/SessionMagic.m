//
//  SessionMagic.m
//  gfxCardStatus
//
//  Created by Cody Krieger on 6/20/11.
//  Copyright 2011 Cody Krieger. All rights reserved.
//

#import "SessionMagic.h"
#import "PrefsController.h"
#import "SystemInfo.h"

static SessionMagic *sharedInstance = nil;
static dispatch_queue_t queue = NULL;

void DisplayReconfigurationCallback(CGDirectDisplayID display, CGDisplayChangeSummaryFlags flags, void *userInfo);

@implementation SessionMagic

@synthesize delegate, 
            usingIntegrated, 
            usingLegacy,
            integratedString, 
            discreteString,
            mode;

- (id)init {
    self = [super init];
    if (self) {
        _canGrowl = YES;
        
        NSDictionary *profile = [SystemInfo getGraphicsProfile];
        usingLegacy = [(NSNumber *)[profile objectForKey:@"legacy"] boolValue];
        
        if (usingLegacy)
            mode = kModeToggleGPU;
        else
            mode = kModeDynamicSwitching;
        
        queue = dispatch_queue_create("com.codykrieger.gfxCardStatus.notificationQueue", NULL);
        
        CGDisplayRegisterReconfigurationCallback(DisplayReconfigurationCallback, self);
    }
    
    return self;
}

- (void)setCanGrowl:(BOOL)canGrowl {
    _canGrowl = canGrowl;
}

- (BOOL)canGrowl {
    return (_canGrowl && [[PrefsController sharedInstance] shouldGrowl]);
}

#pragma mark -
#pragma mark Notifications

void DisplayReconfigurationCallback(CGDirectDisplayID display, CGDisplayChangeSummaryFlags flags, void *userInfo) {
    dispatch_async(queue, ^(void) {
        [NSThread sleepForTimeInterval:0.1];
        
        if (flags & kCGDisplaySetModeFlag) {
            SessionMagic *state = (SessionMagic *)userInfo;
            
            // display has been reconfigured
            DLog(@"Has the gpu changed? Let's find out!\n\n");
            
            BOOL nowIsUsingIntegrated = [MuxMagic isUsingIntegrated];
            DLog(@"nowIsUsingIntegrated (current): %i, _usingIntegrated (previous): %i", nowIsUsingIntegrated, [state usingIntegrated]);
            
            if ((nowIsUsingIntegrated != [state usingIntegrated])) {
                // gpu has indeed changed
                [state gpuChanged];
            }
        }
    });
}

- (void)gpuChanged {
    self.usingIntegrated = !self.usingIntegrated;
    
    if ([delegate respondsToSelector:@selector(gpuChangedTo:)])
        [delegate gpuChangedTo:(self.usingIntegrated ? kGPUTypeIntegrated : kGPUTypeDiscrete)];
}

#pragma mark -
#pragma mark Singleton methods

+ (SessionMagic *)sharedInstance {
    @synchronized(self) {
        if (sharedInstance == nil)
            sharedInstance = [[super allocWithZone:NULL] init];
    }
    return sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone {
    @synchronized(self) {
        if (sharedInstance == nil) {
            sharedInstance = [super allocWithZone:zone];
            return sharedInstance; // assignment and return on first allocation
        }
    }
    return nil; // on subsequent allocation attempts return nil
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (id)retain {
    return self;
}

- (NSUInteger)retainCount {
    return NSUIntegerMax;  //denotes an object that cannot be released
}

- (oneway void)release {
    //do nothing
}

- (id)autorelease {
    return self;
}

@end
