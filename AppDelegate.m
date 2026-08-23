#import "AppDelegate.h"
#import "MCMFilzaIntegration.h"
#import "ZEXFileService.h"
#import "ZEXInjectorVC.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        MCMFilzaStart();
    });
    UIColor *bg = [UIColor colorWithRed:.04 green:.01 blue:.02 alpha:1];
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.backgroundColor = bg;
    ZEXInjectorVC *vc = [[ZEXInjectorVC alloc] init];
    self.window.rootViewController = vc;
    [self.window makeKeyAndVisible];
    self.window.backgroundColor = bg;
    return YES;
}

@end
