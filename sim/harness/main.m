/* Harness app: builds a game-like hierarchy, loads the real diag.m dylib,
   then measures UIKit's own hit-testing in each menu state. */
#import <UIKit/UIKit.h>

static UIWindow *g_win;
static UIView *g_game;
static FILE *g_out;

static void logline(NSString *s) {
    NSLog(@"[HARNESS] %@", s);
    if (g_out) fprintf(g_out, "%s\n", [s UTF8String]);
}
#define PASS(cond, name) do { logline([NSString stringWithFormat:@"%s: %@", (cond) ? @"PASS" : @"FAIL", \
    [NSString stringWithUTF8String:name]]); } while (0)

static UIView *hitAt(CGPoint p) {
    return [g_win hitTest:p withEvent:nil];
}

@interface TestVC : UIViewController
@end
@implementation TestVC
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)o {
    g_win = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    TestVC *vc = [TestVC new];
    g_win.rootViewController = vc;
    g_game = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    g_game.backgroundColor = [UIColor blueColor];
    g_game.userInteractionEnabled = YES;
    [vc.view addSubview:g_game];
    [g_win makeKeyAndVisible];
    self.window = g_win;

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *logPath = [paths[0] stringByAppendingPathComponent:@"harness.log"];
    g_out = fopen(logPath.UTF8String, "w");
    logline(@"=== harness start ===");

    NSArray *steps = @[@2.0, @3.5, @5.0, @7.0];
    [steps enumerateObjectsUsingBlock:^(NSNumber *delay, NSUInteger idx, BOOL *stop) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ [self step:(int)idx]; });
    }];
    return YES;
}

- (void)step:(int)idx {
    Class im = NSClassFromString(@"ImGuiDrawView");
    switch (idx) {
        case 0: {
            logline(@"-- step 0: menu closed (initial)");
            PASS([im isMenuShowing] == NO, "menu flag starts closed");
            UIView *hit = hitAt(CGPointMake(100, 100));
            PASS(hit == g_game, "touch reaches game view while menu closed");
            break;
        }
        case 1: {
            logline(@"-- step 1: open menu");
            [im showChange:YES];
            PASS([im isMenuShowing] == YES, "menu flag now open");
            break;
        }
        case 2: {
            logline(@"-- step 2: menu open, view attached");
            UIView *hit = hitAt(CGPointMake(100, 100));
            PASS(hit != nil, "some view receives the touch with the menu open");
            BOOL found = NO;
            for (UIView *v in g_win.rootViewController.view.subviews)
                if ([v.superview] && v != g_game) found = YES;
            PASS(found, "menu view is in the hierarchy");
            break;
        }
        case 3: {
            logline(@"-- step 3: close menu, verify touches return to the game");
            [im showChange:NO];
            __block int done = 0;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                UIView *hit = hitAt(CGPointMake(100, 100));
                PASS(hit == g_game, "touch reaches game view again after closing the menu");
                PASS([im isMenuShowing] == NO, "menu flag back to closed");
                logline(@"=== harness end ===");
                if (g_out) { fflush(g_out); fclose(g_out); g_out = NULL; }
                done = 1;
                exit(0);
            });
            (void)done;
            break;
        }
    }
}
@end
int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, @"AppDelegate"); }
}
