#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, WKNavigationDelegate>
@property (strong) NSWindow *window;
@property (strong) WKWebView *web;
@end

@implementation AppDelegate

- (NSString *)savedURL {
    NSString *u = [[NSUserDefaults standardUserDefaults] stringForKey:@"server"];
    if (u.length == 0) u = @"https://dash.arbusville.duckdns.org";
    return u;
}

/* A unique document URL per launch. WKWebView caches aggressively and a page
   stored by an older build otherwise keeps being shown after an update. */
- (void)load {
    NSString *u = [self savedURL];
    NSString *sep = [u containsString:@"?"] ? @"&" : @"?";
    NSString *full = [NSString stringWithFormat:@"%@%@_t=%ld", u, sep,
                      (long)[[NSDate date] timeIntervalSince1970]];
    NSURL *url = [NSURL URLWithString:full];
    if (url == nil) {
        [self fail:[NSString stringWithFormat:@"Not a valid address:\n%@", u]];
        return;
    }
    [self.web loadRequest:[NSURLRequest requestWithURL:url]];
}

- (void)fail:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *a = [[NSAlert alloc] init];
        a.messageText = @"Cannot reach the homelab";
        a.informativeText = [NSString stringWithFormat:@"%@\n\nServer: %@\n\nIs Tailscale running on this Mac?",
                             msg, [self savedURL]];
        [a addButtonWithTitle:@"Retry"];
        [a addButtonWithTitle:@"Change server…"];
        [a addButtonWithTitle:@"Quit"];
        NSModalResponse r = [a runModal];
        if (r == NSAlertFirstButtonReturn) {
            [self load];
        } else if (r == NSAlertSecondButtonReturn) {
            [self askServer:nil];
        } else {
            [NSApp terminate:nil];
        }
    });
}

- (void)askServer:(id)sender {
    NSAlert *a = [[NSAlert alloc] init];
    a.messageText = @"Dashboard server";
    a.informativeText = @"Where dashd lives.\n\nTailscale:  http://100.119.139.93:8770\nHome LAN:   http://10.0.0.11:8770";
    NSTextField *f = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 340, 24)];
    f.stringValue = [self savedURL];
    a.accessoryView = f;
    a.window.initialFirstResponder = f;
    [a addButtonWithTitle:@"Save"];
    [a addButtonWithTitle:@"Cancel"];
    if ([a runModal] == NSAlertFirstButtonReturn) {
        NSString *u = [f.stringValue stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (u.length > 0) {
            if (![u hasPrefix:@"http"]) u = [@"http://" stringByAppendingString:u];
            while ([u hasSuffix:@"/"]) u = [u substringToIndex:u.length - 1];
            [[NSUserDefaults standardUserDefaults] setObject:u forKey:@"server"];
            [self load];
        }
    }
}

- (void)buildMenu {
    NSMenu *bar = [[NSMenu alloc] init];

    NSMenuItem *appItem = [[NSMenuItem alloc] init];
    [bar addItem:appItem];
    NSMenu *appMenu = [[NSMenu alloc] init];
    [appMenu addItemWithTitle:@"Set server…" action:@selector(askServer:) keyEquivalent:@","];
    [appMenu addItemWithTitle:@"Reload" action:@selector(reload:) keyEquivalent:@"r"];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"Quit Arbusville Control" action:@selector(terminate:) keyEquivalent:@"q"];
    appItem.submenu = appMenu;

    NSMenuItem *editItem = [[NSMenuItem alloc] init];
    [bar addItem:editItem];
    NSMenu *edit = [[NSMenu alloc] initWithTitle:@"Edit"];
    [edit addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    [edit addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [edit addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [edit addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
    editItem.submenu = edit;

    [NSApp setMainMenu:bar];
}

- (void)reload:(id)sender { [self load]; }

- (void)applicationDidFinishLaunching:(NSNotification *)note {
    NSRect frame = NSMakeRect(0, 0, 1180, 780);
    self.window = [[NSWindow alloc]
        initWithContentRect:frame
                  styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                             NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable)
                    backing:NSBackingStoreBuffered
                      defer:NO];
    self.window.title = @"Arbusville Control";
    self.window.minSize = NSMakeSize(520, 420);
    [self.window setFrameAutosaveName:@"MainWindow"];

    WKWebViewConfiguration *cfg = [[WKWebViewConfiguration alloc] init];
    cfg.websiteDataStore = [WKWebsiteDataStore nonPersistentDataStore];
    self.web = [[WKWebView alloc] initWithFrame:frame configuration:cfg];
    self.web.navigationDelegate = self;
    self.web.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.web setValue:@NO forKey:@"drawsBackground"];
    self.window.contentView = self.web;

    [self buildMenu];
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];

    [self load];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app { return YES; }

- (void)webView:(WKWebView *)wv didFinishNavigation:(WKNavigation *)nav {
    [wv evaluateJavaScript:@"(document.body && document.body.innerText.trim().length) || 0"
         completionHandler:^(id result, NSError *error) {
        NSInteger n = [result respondsToSelector:@selector(integerValue)] ? [result integerValue] : 0;
        if (n < 20) {
            [self fail:@"The page loaded but rendered nothing."];
        }
    }];
}

- (void)webView:(WKWebView *)wv
    didFailProvisionalNavigation:(WKNavigation *)nav
                       withError:(NSError *)error {
    [self fail:error.localizedDescription];
}

- (void)webView:(WKWebView *)wv
    didFailNavigation:(WKNavigation *)nav
            withError:(NSError *)error {
    [self fail:error.localizedDescription];
}

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        AppDelegate *d = [[AppDelegate alloc] init];
        NSApp.delegate = d;
        [NSApp run];
    }
    return 0;
}
