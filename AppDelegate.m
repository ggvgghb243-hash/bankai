#import "AppDelegate.h"
#import "MCMFilzaIntegration.h"
#import "ZEXFileService.h"
#import "ZEXInjectorVC.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    MCMFilzaStart();
    UIColor *bg = [UIColor colorWithRed:.04 green:.05 blue:.10 alpha:1];
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.backgroundColor = bg;
    ZEXInjectorVC *vc = [[ZEXInjectorVC alloc] init];
    self.window.rootViewController = vc;
    [self.window makeKeyAndVisible];
    // Force window background after display
    self.window.backgroundColor = bg;
    return YES;
}

@end
