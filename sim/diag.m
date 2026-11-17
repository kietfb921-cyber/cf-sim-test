/*
 * diag.m - CounterFlame (LOL.framework)
 * The gate bypass lives in the patched LOL binary itself (force_state).
 * This dylib does exactly ONE thing: after the app is up it asks the framework
 * to build its own floating icon (initTapGes). From there the framework's own
 * open/close logic drives the menu, exactly like for a licensed user.
 * No own views, no hooks, no gestures, no window games.
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
extern Class objc_allocateClassPair(Class, const char *, unsigned long);
extern void objc_registerClassPair(Class);
extern unsigned char class_addMethod(Class, SEL, IMP, const char *);
extern Method class_getInstanceMethod(id, SEL);
extern IMP method_setImplementation(Method, IMP);
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

#define MSG0(o, s)      ((id (*)(id, SEL))objc_msgSend)((id)(o), sel_registerName(s))
#define MSG1(o, s, a)   ((id (*)(id, SEL, id))objc_msgSend)((id)(o), sel_registerName(s), (id)(a))
#define MSG2(o, s, a, b) ((id (*)(id, SEL, id, id))objc_msgSend)((id)(o), sel_registerName(s), (id)(a), (id)(b))
#define MSGUL(o, s)     ((unsigned long (*)(id, SEL))objc_msgSend)((id)(o), sel_registerName(s))
#define MSGIDX(o, s, i) ((id (*)(id, SEL, unsigned long))objc_msgSend)((id)(o), sel_registerName(s), (unsigned long)(i))
#define CLS(n)          ((id)objc_getClass(n))
#define SELN(n)         sel_registerName(n)
#define nil ((id)0)

static char g_log[4000];
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

static void setup_path(void) {
    id dirs = NSSearchPathForDirectoriesInDomains(9, 1, 1);
    if (!dirs || MSGUL(dirs, "count") < 1) return;
    id d = MSGIDX(dirs, "objectAtIndex:", 0);
    id p = MSG1(d, "stringByAppendingPathComponent:", nsstr("cfdiag46.txt"));
    const char *cs = p ? ((const char *(*)(id, SEL))objc_msgSend)(p, sel_registerName("UTF8String")) : 0;
    if (!cs) return;
    int i = 0;
    while (cs[i] && i < 500) { g_path[i] = cs[i]; i++; }
    g_path[i] = 0;
    g_pathok = 1;
}

static id g_tgt = 0;
static IMP o_showmenu = 0, o_hidemenu = 0;

static void set_flag(int on) {
    id cls = CLS("ImGuiDrawView");
    if (!cls) return;
    @try { ((void (*)(id, SEL, unsigned char))objc_msgSend)(cls, sel_registerName("showChange:"), (unsigned char)(on ? 1 : 0)); }
    @catch (id e) { }
}

/* the framework draws the menu but leaves isMenuShowing at 0 in our bypassed
   flow, so its own hitTest passes every touch through to the game. Hook the
   open/close entry points and keep the flag in sync. */
static void hk_showmenu(id self, SEL c, id a) {
    @try { if (o_showmenu) ((void (*)(id, SEL, id))o_showmenu)(self, c, a); }
    @catch (id e) { }
    set_flag(1);
    LOG("showMenu -> flag 1");
    save_log();
}
static void hk_hidemenu(id self, SEL c) {
    @try { if (o_hidemenu) ((void (*)(id, SEL))o_hidemenu)(self, c); }
    @catch (id e) { }
    set_flag(0);
    LOG("hidemenuBtn -> flag 0");
    save_log();
}
static void swz(id cls, const char *selname, IMP fn, IMP *old) {
    if (!cls) return;
    Method m = class_getInstanceMethod(cls, sel_registerName(selname));
    if (!m) { LOG("no method %s", selname); return; }
    IMP prev = method_setImplementation(m, fn);
    if (old) *old = prev;
    LOG("hooked %s", selname);
}

static int r_has(const char *h, const char *n) {
    int i, j;
    if (!h || !n || !n[0]) return 0;
    for (i = 0; h[i]; i++) {
        for (j = 0; n[j] && h[i + j] == n[j]; j++) ;
        if (!n[j]) return 1;
    }
    return 0;
}

static int menu_showing(void) {
    id c = CLS("ImGuiDrawView");
    if (!c) return 0;
    return (int)((unsigned char (*)(id, SEL))objc_msgSend)(c, sel_registerName("isMenuShowing"));
}

static unsigned char vflag(id o, const char *selname) {
    if (!o) return 0;
    return ((unsigned char (*)(id, SEL))objc_msgSend)(o, sel_registerName(selname));
}

static void enable_chain(id v) {
    int n = 0;
    while (v && n < 16) {
        if (!vflag(v, "isUserInteractionEnabled")) {
            @try { ((void (*)(id, SEL, unsigned char))objc_msgSend)(v, sel_registerName("setUserInteractionEnabled:"), 1); }
            @catch (id e) { }
            LOG("enabled %s", class_getName(object_getClass(v)));
        }
        v = ((id (*)(id, SEL))objc_msgSend)(v, sel_registerName("superview"));
        n++;
    }
}

static void enable_tree(id v, int depth) {
    if (!v || depth > 5) return;
    if (!vflag(v, "isUserInteractionEnabled")) {
        @try { ((void (*)(id, SEL, unsigned char))objc_msgSend)(v, sel_registerName("setUserInteractionEnabled:"), 1); }
        @catch (id e) { }
        LOG("on %s", class_getName(object_getClass(v)));
    }
    id subs = 0;
    @try { subs = ((id (*)(id, SEL))objc_msgSend)(v, sel_registerName("subviews")); }
    @catch (id e) { }
    unsigned long n = subs ? MSGUL(subs, "count") : 0;
    unsigned long i;
    for (i = 0; i < n && i < 64; i++) enable_tree(MSGIDX(subs, "objectAtIndex:", i), depth + 1);
}

static void unpause_mtk(id v) {
    const char *nm = class_getName(object_getClass(v));
    if (!nm || !r_has(nm, "MTK")) return;
    unsigned char paused = 0;
    @try { paused = ((unsigned char (*)(id, SEL))objc_msgSend)(v, sel_registerName("isPaused")); }
    @catch (id e) { return; }
    if (paused) {
        @try { ((void (*)(id, SEL, unsigned char))objc_msgSend)(v, sel_registerName("setPaused:"), 0); }
        @catch (id e) { }
        LOG("unpaused %s", nm);
    }
}

static id g_catcher = 0;

static void find_menu_views(id v, int depth) {
    if (!v || depth > 6) return;
    const char *nm = class_getName(object_getClass(v));
    unpause_mtk(v);
    if (nm && (r_has(nm, "ImGui") || r_has(nm, "MenuInteraction") || r_has(nm, "OBF_"))) {
        enable_chain(v);
        enable_tree(v, 0);
        if (r_has(nm, "MenuInteraction")) g_catcher = v;
    }
    id subs = 0;
    @try { subs = ((id (*)(id, SEL))objc_msgSend)(v, sel_registerName("subviews")); }
    @catch (id e) { }
    unsigned long n2 = subs ? MSGUL(subs, "count") : 0;
    unsigned long i;
    for (i = 0; i < n2 && i < 64; i++) find_menu_views(MSGIDX(subs, "objectAtIndex:", i), depth + 1);
}

static void find_menu_views_safe(id v, int depth) {
    @try { find_menu_views(v, depth); }
    @catch (id e) { LOG("EXC in sweep"); }
}

static void fix_menu_input(void) {
    if (!menu_showing()) return;
    g_catcher = 0;
    id app = MSG0(CLS("UIApplication"), "sharedApplication");
    if (!app) return;
    id wins = 0;
    @try { wins = ((id (*)(id, SEL))objc_msgSend)(app, sel_registerName("windows")); }
    @catch (id e) { }
    unsigned long n = wins ? MSGUL(wins, "count") : 0;
    unsigned long i;
    for (i = 0; i < n && i < 16; i++) {
        id w = MSGIDX(wins, "objectAtIndex:", i);
        if (!w || vflag(w, "isHidden")) continue;
        find_menu_views_safe(w, 0);
    }
    /* the framework's own touch catcher must sit on top and cover the screen,
       otherwise every tap lands on UnityView and the menu never sees it */
    if (g_catcher) {
        id sup = 0;
        @try { sup = ((id (*)(id, SEL))objc_msgSend)(g_catcher, sel_registerName("superview")); }
        @catch (id e) { }
        if (sup) {
            @try {
                CGRect sb = ((CGRect (*)(id, SEL))objc_msgSend)(
                    ((id (*)(id, SEL))objc_msgSend)(CLS("UIScreen"), sel_registerName("mainScreen")),
                    sel_registerName("bounds"));
                ((void (*)(id, SEL, CGRect))objc_msgSend)(g_catcher, sel_registerName("setFrame:"), sb);
                ((void (*)(id, SEL, id))objc_msgSend)(sup, sel_registerName("bringSubviewToFront:"), g_catcher);
                LOG("catcher on top");
            } @catch (id e) { LOG("EXC catcher: %s", ((const char *(*)(id, SEL))objc_msgSend)(e, sel_registerName("UTF8String"))); }
        }
    }
}

/* the only job: let the framework build its own floating icon, then step away */
static void do_boot(id self, SEL c, id t) {
    setup_path();
    LOG("=== boot ===");
    id mc = CLS("MenuLoad");
    if (!mc) { LOG("no MenuLoad class"); save_log(); return; }
    id inst = 0;
    @try { inst = ((id (*)(id, SEL))objc_msgSend)(mc, sel_registerName("createInstance")); }
    @catch (id e) { LOG("EXC createInstance"); }
    if (!inst) {
        @try { inst = ((id (*)(id, SEL))objc_msgSend)(mc, sel_registerName("new")); }
        @catch (id e) { LOG("EXC new"); }
    }
    LOG("MenuLoad instance=%p", inst);
    if (!inst) { save_log(); return; }
    objc_retain(inst);
    @try { ((void (*)(id, SEL))objc_msgSend)(inst, sel_registerName("initTapGes")); }
    @catch (id e) { LOG("EXC initTapGes"); }
    swz(mc, "showMenu:", (IMP)hk_showmenu, &o_showmenu);
    swz(mc, "hidemenuBtn", (IMP)hk_hidemenu, &o_hidemenu);
    LOG("framework icon requested - the framework now owns the menu");
    save_log();
}
static void log_diag(void) {
    static int once = 0;
    (void)once;
    char b[160]; int i = 0;
    put_s(b, &i, "m="); put_dec(b, &i, menu_showing());
    id app = MSG0(CLS("UIApplication"), "sharedApplication");
    id wins = app ? ((id (*)(id, SEL))objc_msgSend)(app, sel_registerName("windows")) : 0;
    unsigned long n = wins ? MSGUL(wins, "count") : 0;
    put_s(b, &i, " w="); put_dec(b, &i, (long long)n);
    id hit = 0;
    if (n > 0) {
        id w = MSGIDX(wins, "objectAtIndex:", 0);
        @try {
            CGRect sb = ((CGRect (*)(id, SEL))objc_msgSend)(
                ((id (*)(id, SEL))objc_msgSend)(CLS("UIScreen"), sel_registerName("mainScreen")),
                sel_registerName("bounds"));
            CGPoint pp; pp.x = sb.size.w / 2; pp.y = sb.size.h / 2;
            hit = ((id (*)(id, SEL, CGPoint, id))objc_msgSend)(
                w, sel_registerName("hitTest:withEvent:"), pp, nil);
        } @catch (id e) { }
    }
    const char *hn = hit ? class_getName(object_getClass(hit)) : "-";
    put_s(b, &i, " hit="); put_s(b, &i, hn);
    b[i] = 0;
    LOG("DIAG %s", b);
}

static void do_tick(id self, SEL c, id t) { fix_menu_input(); log_diag(); save_log(); }

static void schedule(double delay, const char *selname, unsigned char repeats) {
    if (!g_tgt) return;
    id t = ((id (*)(id, SEL, double, id, SEL, id, unsigned char))objc_msgSend)(
        CLS("NSTimer"), sel_registerName("timerWithTimeInterval:target:selector:userInfo:repeats:"),
        delay, g_tgt, SELN(selname), nil, repeats);
    if (!t) return;
    id rl = MSG0(CLS("NSRunLoop"), "mainRunLoop");
    MSG2(rl, "addTimer:forMode:", t, nsstr("kCFRunLoopCommonModes"));
}

__attribute__((constructor)) static void diag_init(void) {
    if (objc_getClass("DiagTarget46")) return;
    signal(11, (void *)on_sig);
    signal(6, (void *)on_sig);
    Class tcls = objc_allocateClassPair(CLS("NSObject"), "DiagTarget46", 0);
    if (tcls) {
        class_addMethod(tcls, SELN("boot:"), (IMP)do_boot, "v@:@");
        class_addMethod(tcls, SELN("tick:"), (IMP)do_tick, "v@:@");
        objc_registerClassPair(tcls);
        g_tgt = MSG0((id)tcls, "new");
    }
    schedule(2.0, "boot:", 0);
    schedule(0.5, "tick:", 1);
}
