#import <UIKit/UIKit.h>

@interface NSObject (MenuStub)
+ (BOOL)isMenuShowing;
+ (void)showChange:(BOOL)on;
@end

static UIWindow *g_win;
static UIView *g_game;
static FILE *g_out;

static void logline(NSString *s) {
    NSLog(@"[HARNESS] %@", s);
    if (g_out) { fprintf(g_out, "%s\n", [s UTF8String]); fflush(g_out); }
}
#define PASS(cond, name) do { logline([NSString stringWithFormat:@"%@: %@", (cond) ? @"PASS" : @"FAIL", \
    [NSString stringWithUTF8String:(name)]]); } while (0)

static UIView *hitAt(CGPoint p) { return [g_win hitTest:p withEvent:nil]; }

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
    [vc.view addSubview:g_game];
    [g_win makeKeyAndVisible];
    self.window = g_win;

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    g_out = fopen([[paths[0] stringByAppendingPathComponent:@"harness.log"] UTF8String], "w");
    logline(@"=== harness start ===");

    for (int i = 0; i < 4; i++) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((1.5 + i * 1.5) * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ [self step:i]; });
    }
    return YES;
}

- (void)step:(int)idx {
    Class im = NSClassFromString(@"ImGuiDrawView");
    if (idx == 0) {
        logline(@"-- step 0: menu closed (initial)");
        PASS([im isMenuShowing] == NO, "menu flag starts closed");
        PASS(hitAt(CGPointMake(100, 100)) == g_game, "touch reaches game view while menu closed");
    } else if (idx == 1) {
        logline(@"-- step 1: open menu");
        [im showChange:YES];
        PASS([im isMenuShowing] == YES, "menu flag now open");
    } else if (idx == 2) {
        logline(@"-- step 2: menu open");
        PASS(hitAt(CGPointMake(100, 100)) != nil, "some view receives the touch with the menu open");
        BOOL found = NO;
        for (UIView *v in g_win.rootViewController.view.subviews) {
            if ([v superview] && v != g_game) found = YES;
        }
        PASS(found, "menu view is in the hierarchy");
    } else {
        logline(@"-- step 3: close menu");
        [im showChange:NO];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            PASS(hitAt(CGPointMake(100, 100)) == g_game, "touch reaches game view again after closing the menu");
            PASS([im isMenuShowing] == NO, "menu flag back to closed");
            logline(@"=== harness end ===");
            if (g_out) { fclose(g_out); g_out = NULL; }
            exit(0);
        });
    }
}
@end
int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, @"AppDelegate"); }
}
