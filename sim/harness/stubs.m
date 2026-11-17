/* Stub classes that imitate LOL.framework's API surface used by diag.m */
#import <UIKit/UIKit.h>

static BOOL g_menu_showing = NO;

@interface ImGuiDrawView : UIViewController
@end
@implementation ImGuiDrawView
+ (BOOL)isMenuShowing { return g_menu_showing; }
+ (void)showChange:(BOOL)on { g_menu_showing = on; }
- (void)viewDidLoad { [super viewDidLoad]; self.view.backgroundColor = [UIColor greenColor]; }
@end

@interface MenuLoad : NSObject
@property (nonatomic, strong) ImGuiDrawView *vna;
@end
@implementation MenuLoad
static MenuLoad *s_inst = nil;
+ (instancetype)createInstance { return [[MenuLoad alloc] init]; }
- (void)initTapGes { NSLog(@"[stub] initTapGes"); }
- (UIView *)GetImGuiView { return nil; }   /* forces diag.m to build its own view */
- (void)showMenu:(id)sender { NSLog(@"[stub] showMenu"); }
@end

@interface OBF_SK92E1B48 : NSObject
@end
@implementation OBF_SK92E1B48 { char pad[0x200]; }
static OBF_SK92E1B48 *s_mgr = nil;
+ (instancetype)sharedManager { return s_mgr ?: (s_mgr = [OBF_SK92E1B48 new]); }
- (void)ensureUDIDAndCheckKey:(id)arg { NSLog(@"[stub] ensureUDIDAndCheckKey"); }
@end
