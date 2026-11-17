/*
 * diag.m - CounterFlame (LOL.framework): key bypass + menu on/off + touch fix
 * Rule: a fresh ImGuiDrawView is created for every open (so ImGui initialises
 * and draws), and the view is detached from the hierarchy when the menu is
 * closed (a detached view cannot receive a touch, so the game stays usable).
 */
typedef unsigned long NSUInteger;
typedef struct objc_object *id;
typedef struct objc_selector *SEL;
typedef struct objc_method *Method;
typedef void (*IMP)(void);
typedef struct objc_class *Class;
typedef struct { double x, y; } CGPoint;
typedef struct { double w, h; } CGSize;
typedef struct { CGPoint origin; CGSize size; } CGRect;

extern id objc_getClass(const char *);
extern SEL sel_registerName(const char *);
extern Method class_getInstanceMethod(id, SEL);
extern IMP method_setImplementation(Method, IMP);
extern unsigned char class_addMethod(Class, SEL, IMP, const char *);
extern Class objc_allocateClassPair(Class, const char *, unsigned long);
extern void objc_registerClassPair(Class);
extern id objc_msgSend(id, SEL, ...);
extern id objc_retain(id);
extern Class object_getClass(id);
extern const char *class_getName(Class);
extern id NSSearchPathForDirectoriesInDomains(unsigned long, unsigned long, unsigned char);
extern void *signal(int, void *);
extern int open(const char *, int, int);
extern long write(int, const void *, unsigned long);
extern int close(int);
extern int raise(int);

#define MSG0(o, s)          ((id (*)(id, SEL))objc_msgSend)((id)(o), sel_registerName(s))
#define MSG1(o, s, a)       ((id (*)(id, SEL, id))objc_msgSend)((id)(o), sel_registerName(s), (id)(a))
#define MSG2(o, s, a, b)    ((id (*)(id, SEL, id, id))objc_msgSend)((id)(o), sel_registerName(s), (id)(a), (id)(b))
#define MSG3(o, s, a, b, c) ((id (*)(id, SEL, id, id, id))objc_msgSend)((id)(o), sel_registerName(s), (id)(a), (id)(b), (id)(c))
#define MSGF(o, s, r)       ((id (*)(id, SEL, CGRect))objc_msgSend)((id)(o), sel_registerName(s), (r))
#define MSGV(o, s)          ((void (*)(id, SEL))objc_msgSend)((id)(o), sel_registerName(s))
#define MSGVB(o, s, b)      ((void (*)(id, SEL, unsigned char))objc_msgSend)((id)(o), sel_registerName(s), (unsigned char)(b))
#define MSGUL(o, s)         ((unsigned long (*)(id, SEL))objc_msgSend)((id)(o), sel_registerName(s))
#define MSGIDX(o, s, i)     ((id (*)(id, SEL, unsigned long))objc_msgSend)((id)(o), sel_registerName(s), (unsigned long)(i))
#define CLS(n)              ((id)objc_getClass(n))
#define SELN(n)             sel_registerName(n)
#define nil ((id)0)
#include "rules.h"

static char g_log[6000];
static int  g_len = 0;
static char g_path[512];
static int  g_pathok = 0;

static void put_s(char *b, int *i, const char *s) { while (s && *s) b[(*i)++] = *s++; }
static void put_dec(char *b, int *i, long long v) {
    char t[24]; int n = 0; unsigned long long u;
    if (v < 0) { b[(*i)++] = '-'; u = (unsigned long long)(-v); } else u = (unsigned long long)v;
    if (!u) t[n++] = '0';
    while (u) { t[n++] = (char)('0' + (int)(u % 10)); u /= 10; }
    while (n) b[(*i)++] = t[--n];
}
static void put_hex(char *b, int *i, unsigned long v) {
    char t[20]; int n = 0;
    if (!v) t[n++] = '0';
    while (v) { int d = (int)(v & 15); t[n++] = (char)(d < 10 ? '0' + d : 'a' + d - 10); v >>= 4; }
    while (n) b[(*i)++] = t[--n];
}
static void LOG(const char *fmt, ...) {
    char line[380]; int i = 0;
    __builtin_va_list ap; __builtin_va_start(ap, fmt);
    const char *p = fmt;
    while (*p && i < 360) {
        if (*p != '%') { line[i++] = *p++; continue; }
        p++;
        int lng = 0; while (*p == 'l') { lng++; p++; }
        char c = *p;
        if (c == 's') { const char *s = __builtin_va_arg(ap, const char *); put_s(line, &i, s ? s : "(null)"); }
        else if (c == 'd') { long long v = lng ? __builtin_va_arg(ap, long long) : (long long)__builtin_va_arg(ap, int); put_dec(line, &i, v); }
        else if (c == 'p') { void *v = __builtin_va_arg(ap, void *); line[i++] = '0'; line[i++] = 'x'; put_hex(line, &i, (unsigned long)v); }
        else { line[i++] = '%'; if (c) line[i++] = c; }
        if (c) p++;
    }
    __builtin_va_end(ap);
    if (g_len + i + 2 >= (int)sizeof(g_log)) {
        int cut = g_len / 2, k;
        for (k = 0; k < g_len - cut; k++) g_log[k] = g_log[k + cut];
        g_len -= cut;
    }
    int k;
    for (k = 0; k < i; k++) g_log[g_len + k] = line[k];
    g_len += i;
    g_log[g_len++] = '\n';
    g_log[g_len] = 0;
}
static void save_log(void) {
    if (!g_pathok) return;
    int fd = open(g_path, 0x0601, 0644);
    if (fd < 0) return;
    if (g_len > 0) write(fd, g_log, (unsigned long)g_len);
    close(fd);
}
static void on_sig(int sig) { save_log(); signal(sig, (void *)0); raise(sig); }
static id nsstr(const char *s) { return MSG1(CLS("NSString"), "stringWithUTF8String:", s); }
static const char *cstr(id o) {
    if (!o) return "(nil)";
    id d = MSG0(o, "description");
    if (!d) return "?";
    const char *p = ((const char *(*)(id, SEL))objc_msgSend)(d, sel_registerName("UTF8String"));
    return p ? p : "?";
}
static id safe(id obj, const char *selname, id a1, id a2) {
    if (!obj) return 0;
    @try { return ((id (*)(id, SEL, id, id))objc_msgSend)(obj, sel_registerName(selname), a1, a2); }
    @catch (id e) { LOG("EXC %s: %s", selname, cstr(e)); return 0; }
}
static unsigned char vflag(id o, const char *selname) {
    if (!o) return 0;
    return ((unsigned char (*)(id, SEL))objc_msgSend)(o, sel_registerName(selname));
}

/* ---------------- state ---------------- */
static id g_inst = 0, g_vna = 0, g_view = 0, g_host = 0, g_tgt = 0, g_gesture = 0;
static IMP o_tap = 0, o_view = 0, o_show = 0, o_create = 0;

static int menu_showing(void) {
    id c = CLS("ImGuiDrawView");
    if (!c) return 0;
    return (int)((unsigned char (*)(id, SEL))objc_msgSend)(c, sel_registerName("isMenuShowing"));
}
static void attach_view(void);
static void install_hit_test(id view);
static void restore_input(void);
static void setup_path(void);

static void force_state(id self) {
    if (!self) return;
    char *p = (char *)self;
    *(volatile unsigned char *)(p + 0x13) = 1;
    *(volatile unsigned char *)(p + 0x14) = 1;
    *(volatile long long *)(p + 0x20) = 86400LL * 3650;
    if (!*(void **)(p + 0x130)) *(void **)(p + 0x130) = objc_retain(nsstr("00000000-0000-0000-0000-000000000000"));
    if (!*(void **)(p + 0x138)) *(void **)(p + 0x138) = objc_retain(nsstr("00000000-0000-0000-0000-000000000001"));
}

static void hk_ensure(id self, SEL c, id arg) { force_state(self); LOG("ensure bypassed"); }
static void hk_tap(id self, SEL c) { @try { if (o_tap) ((void (*)(id, SEL))o_tap)(self, c); } @catch (id e) { LOG("EXC tap: %s", cstr(e)); } }
static id hk_view(id self, SEL c) {
    if (g_view) return g_view;
    attach_view();
    if (g_view) return g_view;
    id r = 0;
    @try { if (o_view) r = ((id (*)(id, SEL))o_view)(self, c); } @catch (id e) { LOG("EXC view: %s", cstr(e)); }
    return r;
}
static void hk_show(id self, SEL c, id a) { @try { if (o_show) ((void (*)(id, SEL, id))o_show)(self, c, a); } @catch (id e) { LOG("EXC show: %s", cstr(e)); } }
static id hk_create(id self, SEL c) {
    id r = 0;
    @try { if (o_create) r = ((id (*)(id, SEL))o_create)(self, c); } @catch (id e) { LOG("EXC create: %s", cstr(e)); }
    if (r) g_inst = objc_retain(r);
    return r;
}
static int swz(id cls, const char *s, IMP fn, IMP *old) {
    if (!cls) return 0;
    Method m = class_getInstanceMethod(cls, sel_registerName(s));
    if (!m) { LOG("no method %s", s); return 0; }
    IMP prev = method_setImplementation(m, fn);
    if (old) *old = prev;
    return 1;
}
static int swzc(id cls, const char *s, IMP fn, IMP *old) {
    if (!cls) return 0;
    Method m = class_getInstanceMethod(object_getClass(cls), sel_registerName(s));
    if (!m) { LOG("no class method +%s", s); return 0; }
    IMP prev = method_setImplementation(m, fn);
    if (old) *old = prev;
    return 1;
}

static id game_window(void) {
    id appi = safe(CLS("UIApplication"), "sharedApplication", nil, nil);
    if (!appi) return 0;
    id del = safe(appi, "delegate", nil, nil);
    if (del) {
        unsigned char ok = ((unsigned char (*)(id, SEL, SEL))objc_msgSend)(
            del, sel_registerName("respondsToSelector:"), sel_registerName("window"));
        if (ok) {
            id w = 0;
            @try { w = ((id (*)(id, SEL))objc_msgSend)(del, sel_registerName("window")); }
            @catch (id e) { }
            if (w) return w;
        }
    }
    id wins = safe(appi, "windows", nil, nil);
    unsigned long n = wins ? MSGUL(wins, "count") : 0;
    if (n > 0) return MSGIDX(wins, "objectAtIndex:", 0);
    return 0;
}

static id host_view(void) {
    id gw = game_window();
    if (!gw) return 0;
    id rvc = safe(gw, "rootViewController", nil, nil);
    id rv = rvc ? safe(rvc, "view", nil, nil) : 0;
    return rv ? rv : gw;
}

/* UIView default hit-testing + "menu closed => no touches" */
static id hk_hit_test(id self, SEL _cmd, CGPoint p, id ev) {
    if (!menu_showing()) return nil;
    id subs = safe(self, "subviews", nil, nil);
    unsigned long n = subs ? MSGUL(subs, "count") : 0;
    while (n > 0) {
        n--;
        id sub = MSGIDX(subs, "objectAtIndex:", n);
        if (!sub) continue;
        if (vflag(sub, "isHidden")) continue;
        double a = ((double (*)(id, SEL))objc_msgSend)(sub, sel_registerName("alpha"));
        if (a <= 0.01) continue;
        if (!vflag(sub, "isUserInteractionEnabled")) continue;
        CGPoint q = ((CGPoint (*)(id, SEL, CGPoint, id))objc_msgSend)(self, sel_registerName("convertPoint:toView:"), p, sub);
        id hit = ((id (*)(id, SEL, CGPoint, id))objc_msgSend)(sub, sel_registerName("hitTest:withEvent:"), q, ev);
        if (hit) return hit;
    }
    unsigned char inside = ((unsigned char (*)(id, SEL, CGPoint, id))objc_msgSend)(self, sel_registerName("pointInside:withEvent:"), p, ev);
    return inside ? self : nil;
}
static void install_hit_test(id view) {
    if (!view) return;
    Class c = object_getClass(view);
    if (!c) return;
    const char *cn = class_getName(c);
    /* NEVER patch UIKit classes: hitTest on UIView/MTKView would break every
       view in the app (that is exactly the "nothing tappable" bug) */
    if (!r_has(cn, "OBF_") && !r_has(cn, "ImGui") && !r_has(cn, "Menu")) {
        LOG("hitTest NOT installed on %s (shared class)", cn);
        return;
    }
    Method m = class_getInstanceMethod(c, SELN("hitTest:withEvent:"));
    if (m) method_setImplementation(m, (IMP)hk_hit_test);
    else class_addMethod(c, SELN("hitTest:withEvent:"), (IMP)hk_hit_test, "@@:{CGPoint=dd}@");
    LOG("hitTest installed on %s", cn);
}

static id get_inst(void) {
    if (g_inst) return g_inst;
    id c = CLS("MenuLoad");
    if (!c) return 0;
    id i = safe(c, "createInstance", nil, nil);
    if (!i) i = safe(c, "new", nil, nil);
    if (i) { g_inst = objc_retain(i); LOG("inst=%p", g_inst); }
    return g_inst;
}

/* build a brand new ImGui view and put it on screen */
static void attach_view(void) {
    if (g_view) return;                 /* exactly one Metal view per session */
    static int attaching = 0;
    if (attaching) return;
    attaching = 1;
    id inst = get_inst();
    if (!inst) { attaching = 0; return; }
    id vna = safe(CLS("ImGuiDrawView"), "alloc", nil, nil);
    vna = safe(vna, "init", nil, nil);
    if (!vna) { LOG("no ImGuiDrawView"); attaching = 0; return; }
    ((void (*)(id, SEL, id))objc_msgSend)(inst, sel_registerName("setVna:"), vna);
    id v = safe(vna, "view", nil, nil);
    if (!v) { LOG("no view"); attaching = 0; return; }
    id host = host_view();
    if (!host) { LOG("no host"); attaching = 0; return; }
    CGRect r = ((CGRect (*)(id, SEL))objc_msgSend)(MSG0(CLS("UIScreen"), "mainScreen"), sel_registerName("bounds"));
    @try { ((void (*)(id, SEL, CGRect))objc_msgSend)(v, sel_registerName("setFrame:"), r); }
    @catch (id e) { }
    install_hit_test(v);
    safe(host, "addSubview:", v, nil);
    g_vna = objc_retain(vna);
    g_view = objc_retain(v);
    g_host = objc_retain(host);
    LOG("fresh view %p attached", g_view);
    attaching = 0;
}

/* the view is created ONCE at boot and only shown/hidden afterwards.
   Creating a second ImGuiDrawView while the game runs aborts inside Metal
   (MTLTextureDescriptor validation), which is exactly the crash we saw. */
static void sync_menu_view(void) {
    if (!g_view) return;                 /* never create it from here */
    int showing = menu_showing();
    @try {
        ((void (*)(id, SEL, unsigned char))objc_msgSend)(g_view, sel_registerName("setHidden:"), (unsigned char)(showing ? 0 : 1));
        ((void (*)(id, SEL, double))objc_msgSend)(g_view, sel_registerName("setAlpha:"), showing ? 1.0 : 0.0);
        ((void (*)(id, SEL, unsigned char))objc_msgSend)(g_view, sel_registerName("setUserInteractionEnabled:"), (unsigned char)(showing ? 1 : 0));
    } @catch (id e) { }
}

static void open_menu(void) {
    id c = CLS("ImGuiDrawView");
    if (c) {
        @try { ((void (*)(id, SEL, unsigned char))objc_msgSend)(c, sel_registerName("showChange:"), 1); }
        @catch (id e) { LOG("EXC showChange: %s", cstr(e)); }
    }
    sync_menu_view();
    restore_input();
    LOG("open menu: showing=%d view=%p", menu_showing(), g_view);
    save_log();
}

static void close_menu(void) {
    id c = CLS("ImGuiDrawView");
    if (c) {
        @try { ((void (*)(id, SEL, unsigned char))objc_msgSend)(c, sel_registerName("showChange:"), 0); }
        @catch (id e) { }
    }
    sync_menu_view();
    LOG("close menu");
    save_log();
}

static unsigned char wflag(id o, const char *selname) {
    if (!o) return 0;
    return ((unsigned char (*)(id, SEL))objc_msgSend)(o, sel_registerName(selname));
}

static void fix_windows(void) {
    id appi = safe(CLS("UIApplication"), "sharedApplication", nil, nil);
    if (!appi) return;
    id gw = game_window();
    id wins = safe(appi, "windows", nil, nil);
    unsigned long n = wins ? MSGUL(wins, "count") : 0;
    unsigned long i;
    for (i = 0; i < n && i < 16; i++) {
        id w = MSGIDX(wins, "objectAtIndex:", i);
        if (!w) continue;
        const char *cn = class_getName(object_getClass(w));
        if (r_should_hide_window(cn, w == gw, wflag(w, "isHidden"))) {
            @try { ((void (*)(id, SEL, unsigned char))objc_msgSend)(w, sel_registerName("setHidden:"), 1); }
            @catch (id e) { }
            LOG("hid window %s", cn);
        }
    }
    if (!gw) return;
    if (!wflag(gw, "isUserInteractionEnabled")) {
        @try { ((void (*)(id, SEL, unsigned char))objc_msgSend)(gw, sel_registerName("setUserInteractionEnabled:"), 1); }
        @catch (id e) { }
        LOG("game window interaction re-enabled");
    }
}

/* while its menu is up the framework disables interaction on the game views
   and never turns it back on in our bypassed flow - force it back on */
static void enable_tree(id v, int depth) {
    if (!v || depth > 5) return;
    const char *cn = class_getName(object_getClass(v));
    if (r_has(cn, "ImGui") || r_has(cn, "MenuInteraction") || r_has(cn, "OBF_")) return;
    if (!wflag(v, "isUserInteractionEnabled")) {
        @try { ((void (*)(id, SEL, unsigned char))objc_msgSend)(v, sel_registerName("setUserInteractionEnabled:"), 1); }
        @catch (id e) { }
        LOG("re-enabled %s", class_getName(object_getClass(v)));
    }
    id subs = safe(v, "subviews", nil, nil);
    unsigned long n = subs ? MSGUL(subs, "count") : 0;
    unsigned long i;
    for (i = 0; i < n && i < 64; i++)
        enable_tree(MSGIDX(subs, "objectAtIndex:", i), depth + 1);
}

static void restore_input(void) {
    id gw = game_window();
    if (!gw) return;
    if (!wflag(gw, "isUserInteractionEnabled")) {
        @try { ((void (*)(id, SEL, unsigned char))objc_msgSend)(gw, sel_registerName("setUserInteractionEnabled:"), 1); }
        @catch (id e) { }
        LOG("re-enabled game window");
    }
    id rvc = safe(gw, "rootViewController", nil, nil);
    id rv = rvc ? safe(rvc, "view", nil, nil) : 0;
    if (rv) enable_tree(rv, 0);
}

static void install_gesture(void) {
    if (g_gesture) return;
    id gw = game_window();
    if (!gw) return;
    unsigned long touches[2] = { 3, 2 };
    const char *names[2] = { "3-finger", "2-finger" };
    int ci;
    for (ci = 0; ci < 2; ci++) {
        id g = MSG0(CLS("UITapGestureRecognizer"), "alloc");
        if (!g) continue;
        g = safe(g, "initWithTarget:action:", g_tgt, SELN("openMenu:"));
        if (!g) continue;
        @try {
            ((void (*)(id, SEL, unsigned long))objc_msgSend)(g, sel_registerName("setNumberOfTapsRequired:"), 2);
            ((void (*)(id, SEL, unsigned long))objc_msgSend)(g, sel_registerName("setNumberOfTouchesRequired:"), touches[ci]);
            ((void (*)(id, SEL, unsigned char))objc_msgSend)(g, sel_registerName("setCancelsTouchesInView:"), 0);
            ((void (*)(id, SEL, unsigned char))objc_msgSend)(g, sel_registerName("setDelaysTouchesEnded:"), 0);
        } @catch (id e) { }
        safe(gw, "addGestureRecognizer:", g, nil);
        objc_retain(g);
        LOG("gesture %s installed on game window", names[ci]);
    }
    g_gesture = (id)1;
}

static void do_open(id self, SEL c, id g) { LOG("gesture fired"); open_menu(); }
static void do_auto(id self, SEL c, id t) { LOG("auto open"); open_menu(); }
static int g_ticks = 0;
static void do_keep(id self, SEL c, id t) { fix_windows(); restore_input(); sync_menu_view(); if ((++g_ticks & 3) == 0) save_log(); }
static void do_boot(id self, SEL c, id t) { setup_path(); fix_windows(); restore_input(); get_inst(); attach_view(); install_gesture(); sync_menu_view(); save_log(); }

static void schedule(double delay, const char *selname, unsigned char repeats) {
    if (!g_tgt) return;
    id t = ((id (*)(id, SEL, double, id, SEL, id, unsigned char))objc_msgSend)(
        CLS("NSTimer"), sel_registerName("timerWithTimeInterval:target:selector:userInfo:repeats:"),
        delay, g_tgt, SELN(selname), nil, repeats);
    if (!t) return;
    id rl = MSG0(CLS("NSRunLoop"), "mainRunLoop");
    MSG2(rl, "addTimer:forMode:", t, nsstr("kCFRunLoopCommonModes"));
}

static void setup_path(void) {
    id dirs = NSSearchPathForDirectoriesInDomains(9, 1, 1);
    if (!dirs || MSGUL(dirs, "count") < 1) return;
    id d = MSGIDX(dirs, "objectAtIndex:", 0);
    id p = MSG1(d, "stringByAppendingPathComponent:", nsstr("cfdiag38.log"));
    const char *cs = p ? ((const char *(*)(id, SEL))objc_msgSend)(p, sel_registerName("UTF8String")) : 0;
    if (!cs) return;
    int i = 0;
    while (cs[i] && i < 500) { g_path[i] = cs[i]; i++; }
    g_path[i] = 0;
    g_pathok = 1;
}

__attribute__((constructor)) static void diag_init(void) {
    if (objc_getClass("DiagTarget38")) return;
    signal(11, (void *)on_sig);
    signal(6, (void *)on_sig);
    Class tcls = objc_allocateClassPair(CLS("NSObject"), "DiagTarget38", 0);
    if (tcls) {
        class_addMethod(tcls, SELN("boot:"), (IMP)do_boot, "v@:@");
        class_addMethod(tcls, SELN("openMenu:"), (IMP)do_open, "v@:@");
        class_addMethod(tcls, SELN("autoOpen:"), (IMP)do_auto, "v@:@");
        class_addMethod(tcls, SELN("keep:"), (IMP)do_keep, "v@:@");
        objc_registerClassPair(tcls);
        g_tgt = MSG0((id)tcls, "new");
    }
    id mgrcls = CLS("OBF_SK92E1B48");
    id mencls = CLS("MenuLoad");
    if (mgrcls) swz(mgrcls, "ensureUDIDAndCheckKey:", (IMP)hk_ensure, 0);
    if (mencls) {
        swz(mencls, "initTapGes", (IMP)hk_tap, &o_tap);
        swz(mencls, "GetImGuiView", (IMP)hk_view, &o_view);
        swz(mencls, "showMenu:", (IMP)hk_show, &o_show);
        swzc(mencls, "createInstance", (IMP)hk_create, &o_create);
    }
    setup_path();
    schedule(1.5, "boot:", 0);
    schedule(0.5, "keep:", 1);
    schedule(10.0, "autoOpen:", 0);
}
