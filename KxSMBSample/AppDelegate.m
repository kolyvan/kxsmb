//
//  AppDelegate.m
//  kxsmb project
//  https://github.com/kolyvan/kxsmb/
//
//  Created by Kolyvan on 27.03.13.
//

/*
 Copyright (c) 2013 Konstantin Bukreev All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 - Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/


#import "AppDelegate.h"
#import "TreeViewController.h"
#import "SmbAuthViewController.h"
#import "KxSMBProvider.h"

@interface AppDelegate() <KxSMBProviderDelegate, SmbAuthViewControllerDelegate>
@end

@implementation AppDelegate {

    TreeViewController *_headVC;
    NSMutableDictionary *_cachedAuths;
    SmbAuthViewController *_smbAuthViewController;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{   
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    _headVC = [[TreeViewController alloc] initAsHeadViewController];
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:_headVC];
    [self.window makeKeyAndVisible];
    
    _cachedAuths = [NSMutableDictionary dictionary];
    KxSMBProvider *provider = [KxSMBProvider sharedSmbProvider];
    provider.delegate = self;
    provider.config.browseMaxLmbCount = 0;
    provider.config.debugLevel = 1;
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{    
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
}

- (void)applicationWillTerminate:(UIApplication *)application
{
}

#pragma mark - KxSMBProviderDelegate

- (void) presentSmbAuthViewControllerForServer:(NSString *)server
                                         share:(NSString *)share
                                     workgroup:(NSString *)workgroup
                                      username:(NSString *)username
{
    if (!_smbAuthViewController) {
        _smbAuthViewController = [[SmbAuthViewController alloc] init];
        _smbAuthViewController.delegate = self;
        _smbAuthViewController.username = @"guest";
    }
    
    UINavigationController *nav = (UINavigationController *)self.window.rootViewController;
    
    if (nav.presentedViewController)
        return;
    
    _smbAuthViewController.server = server;
    _smbAuthViewController.workgroup = workgroup;
    _smbAuthViewController.username = username;
    
    UIViewController *vc = [[UINavigationController alloc] initWithRootViewController:_smbAuthViewController];
    
    [nav.topViewController presentViewController:vc
                                        animated:NO
                                      completion:nil];
}

- (void) couldSmbAuthViewController:(SmbAuthViewController *) controller
                               done:(BOOL) done
{
    if (done) {
        
        KxSMBAuth *auth = [KxSMBAuth smbAuthWorkgroup:controller.workgroup
                                             username:controller.username
                                             password:controller.password];
        
        _cachedAuths[controller.server.uppercaseString] = auth;
        
        NSLog(@"store auth %@ -> (%@) %@:%@", controller.server, controller.workgroup, controller.username, controller.password);
    }
    
    UINavigationController *nav = (UINavigationController *)self.window.rootViewController;
    [nav dismissViewControllerAnimated:YES completion:nil];
    
    [_headVC reloadPath];
}

- (KxSMBAuth *) smbRequestAuthServer:(NSString *)server
                               share:(NSString *)share
                           workgroup:(NSString *)workgroup
                            username:(NSString *)username
{
    if ([share isEqualToString:@"IPC$"] ||
        [share hasSuffix:@"$"])
    {
        // return nil;
    }
    
    KxSMBAuth *auth = _cachedAuths[server.uppercaseString];
    if (auth) {
        
        // NSLog(@"cached auth for %@ -> %@ (%@) %@:%@", server, share, auth.workgroup, auth.username, auth.password);
        return auth;
    }
    
    NSLog(@"ask auth for %@/%@ (%@)", server, share, workgroup);
    
    dispatch_async(dispatch_get_main_queue(), ^{
    
        [self presentSmbAuthViewControllerForServer:server
                                              share:share
                                          workgroup:workgroup
                                           username:username];
    });
    
    return nil;
}

@end
