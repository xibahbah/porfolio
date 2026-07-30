#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

static NSString *const PortfolioName = @"Portfolio";
static NSString *const PortfolioFallbackBundleIdentifier =
    @"com.datafolio.portfolio";

static NSString *PortfolioBundleIdentifier(void) {
    return NSBundle.mainBundle.bundleIdentifier
        ?: PortfolioFallbackBundleIdentifier;
}

@interface PortfolioDiagnosticLogger : NSObject

@property(nonatomic, readonly, nullable) NSURL *applicationSupportURL;
@property(nonatomic, readonly, nullable) NSURL *cachesURL;
@property(nonatomic, readonly, nullable) NSURL *logsURL;

+ (instancetype)sharedLogger;
- (BOOL)prepareDirectories:(NSError **)error;
- (void)recordMessage:(NSString *)message;

@end

@interface PortfolioDiagnosticLogger ()

@property(nonatomic, readwrite, nullable) NSURL *applicationSupportURL;
@property(nonatomic, readwrite, nullable) NSURL *cachesURL;
@property(nonatomic, readwrite, nullable) NSURL *logsURL;

@end

@implementation PortfolioDiagnosticLogger

+ (instancetype)sharedLogger {
    static PortfolioDiagnosticLogger *logger;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        logger = [[PortfolioDiagnosticLogger alloc] init];
    });
    return logger;
}

- (BOOL)prepareDirectories:(NSError **)error {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSURL *applicationSupportBase =
        [fileManager URLsForDirectory:NSApplicationSupportDirectory
                            inDomains:NSUserDomainMask].firstObject;
    NSURL *cachesBase =
        [fileManager URLsForDirectory:NSCachesDirectory
                            inDomains:NSUserDomainMask].firstObject;
    NSURL *libraryBase =
        [fileManager URLsForDirectory:NSLibraryDirectory
                            inDomains:NSUserDomainMask].firstObject;

    if (!applicationSupportBase || !cachesBase || !libraryBase) {
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                         code:NSFileNoSuchFileError
                                     userInfo:nil];
        }
        return NO;
    }

    NSString *bundleIdentifier = PortfolioBundleIdentifier();
    self.applicationSupportURL =
        [applicationSupportBase URLByAppendingPathComponent:bundleIdentifier
                                                isDirectory:YES];
    self.cachesURL =
        [cachesBase URLByAppendingPathComponent:bundleIdentifier
                                    isDirectory:YES];
    self.logsURL =
        [[libraryBase URLByAppendingPathComponent:@"Logs" isDirectory:YES]
            URLByAppendingPathComponent:bundleIdentifier
                            isDirectory:YES];

    for (NSURL *directory in @[
             self.applicationSupportURL,
             self.cachesURL,
             self.logsURL,
         ]) {
        if (![fileManager createDirectoryAtURL:directory
                   withIntermediateDirectories:YES
                                    attributes:nil
                                         error:error]) {
            return NO;
        }
    }

    return YES;
}

- (NSString *)redactedMessage:(NSString *)message {
    NSString *result = [message copy];
    NSArray<NSString *> *patterns = @[
        @"/Users/[^/\\s]+",
        @"[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}",
        @"(api[_-]?key|token|secret|password)\\s*[:=]\\s*\\S+",
    ];

    for (NSString *pattern in patterns) {
        NSRegularExpression *expression =
            [NSRegularExpression regularExpressionWithPattern:pattern
                                                      options:
                                                          NSRegularExpressionCaseInsensitive
                                                        error:nil];
        result = [expression
            stringByReplacingMatchesInString:result
                                     options:0
                                       range:NSMakeRange(0, result.length)
                                withTemplate:@"<redacted>"];
    }

    return result;
}

- (void)recordMessage:(NSString *)message {
    NSError *directoryError = nil;
    if (!self.logsURL && ![self prepareDirectories:&directoryError]) {
        return;
    }

    NSURL *logURL = [self.logsURL
        URLByAppendingPathComponent:@"portfolio.log"
                        isDirectory:NO];
    NSISO8601DateFormatter *formatter =
        [[NSISO8601DateFormatter alloc] init];
    NSString *entry = [NSString
        stringWithFormat:@"%@ %@\n",
                         [formatter stringFromDate:NSDate.date],
                         [self redactedMessage:message]];
    NSData *data = [entry dataUsingEncoding:NSUTF8StringEncoding];
    NSFileManager *fileManager = NSFileManager.defaultManager;

    if (![fileManager fileExistsAtPath:logURL.path]) {
        [fileManager createFileAtPath:logURL.path
                            contents:nil
                          attributes:@{
                              NSFilePosixPermissions : @0600,
                          }];
    }

    NSError *handleError = nil;
    NSFileHandle *handle =
        [NSFileHandle fileHandleForWritingToURL:logURL error:&handleError];
    if (!handle || handleError) {
        return;
    }

    @try {
        [handle seekToEndOfFile];
        [handle writeData:data];
        [handle closeFile];
    } @catch (__unused NSException *exception) {
        // Logging must never prevent the application from launching.
    }
}

@end

@interface PortfolioWindowController
    : NSObject <WKNavigationDelegate, WKUIDelegate, NSWindowDelegate>

- (void)show;
- (void)bringToFront;
- (void)reload;
- (void)goBack;
- (void)goForward;

@end

@interface PortfolioWindowController ()

@property(nonatomic) NSWindow *window;
@property(nonatomic) WKWebView *webView;
@property(nonatomic) NSURL *webRootURL;
@property(nonatomic) BOOL smokeTestFinished;
@property(nonatomic) NSInteger smokeTestStage;

@end

@implementation PortfolioWindowController

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }

    NSURL *resourcesURL = NSBundle.mainBundle.resourceURL;
    self.webRootURL =
        [[resourcesURL URLByAppendingPathComponent:@"Web" isDirectory:YES]
            URLByStandardizingPath];

    WKWebViewConfiguration *configuration =
        [[WKWebViewConfiguration alloc] init];
    configuration.websiteDataStore =
        WKWebsiteDataStore.nonPersistentDataStore;
    configuration.preferences.javaScriptCanOpenWindowsAutomatically = NO;
    configuration.defaultWebpagePreferences.allowsContentJavaScript = YES;

    self.webView = [[WKWebView alloc]
        initWithFrame:NSMakeRect(0, 0, 1120, 760)
        configuration:configuration];
    self.webView.navigationDelegate = self;
    self.webView.UIDelegate = self;
    self.webView.allowsMagnification = YES;
    self.webView.allowsBackForwardNavigationGestures = YES;

    self.window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 1120, 760)
                  styleMask:NSWindowStyleMaskTitled |
                            NSWindowStyleMaskClosable |
                            NSWindowStyleMaskMiniaturizable |
                            NSWindowStyleMaskResizable |
                            NSWindowStyleMaskFullSizeContentView
                    backing:NSBackingStoreBuffered
                      defer:NO];
    self.window.title = PortfolioName;
    self.window.contentView = self.webView;
    self.window.delegate = self;
    self.window.minSize = NSMakeSize(720, 520);
    [self.window center];
    [self.window setFrameAutosaveName:@"PortfolioMainWindow"];

    return self;
}

- (void)show {
    [self.window makeKeyAndOrderFront:nil];
    [self loadHomePage];
}

- (void)bringToFront {
    [self.window makeKeyAndOrderFront:nil];
}

- (void)reload {
    if (self.webView.URL) {
        [self.webView reload];
    } else {
        [self loadHomePage];
    }
}

- (void)goBack {
    if (self.webView.canGoBack) {
        [self.webView goBack];
    }
}

- (void)goForward {
    if (self.webView.canGoForward) {
        [self.webView goForward];
    }
}

- (void)loadHomePage {
    NSURL *indexURL =
        [self.webRootURL URLByAppendingPathComponent:@"index.html"];
    if (![NSFileManager.defaultManager
            fileExistsAtPath:indexURL.path]) {
        [self presentStartupError:@"The application content is missing."];
        return;
    }

    [self.webView loadFileURL:indexURL
        allowingReadAccessToURL:self.webRootURL];
}

- (BOOL)isApprovedLocalURL:(NSURL *)URL {
    if (!URL.isFileURL) {
        return NO;
    }

    NSString *candidate = URL.URLByStandardizingPath.path;
    NSString *root = self.webRootURL.path;
    return [candidate isEqualToString:root] ||
           [candidate hasPrefix:[root stringByAppendingString:@"/"]];
}

- (void)openExternally:(NSURL *)URL {
    NSString *scheme = URL.scheme.lowercaseString;
    if (![@[ @"https", @"http", @"mailto" ] containsObject:scheme]) {
        return;
    }

    if (![NSWorkspace.sharedWorkspace openURL:URL]) {
        [PortfolioDiagnosticLogger.sharedLogger
            recordMessage:@"The system could not open an external link."];
        [self
            presentReadableError:
                @"The link could not be opened in its default application."];
    }
}

- (BOOL)isSmokeTest {
    return [NSProcessInfo.processInfo.environment[@"PORTFOLIO_SMOKE_TEST"]
        isEqualToString:@"1"];
}

- (void)presentStartupError:(NSString *)message {
    [PortfolioDiagnosticLogger.sharedLogger recordMessage:message];
    [self presentReadableError:message];
}

- (void)presentReadableError:(NSString *)message {
    if (self.isSmokeTest) {
        [self finishSmokeTest:
                  [@"FAIL: " stringByAppendingString:message]];
        return;
    }

    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = @"Portfolio could not complete that action.";
    alert.informativeText = message;
    [alert addButtonWithTitle:@"OK"];
    [alert beginSheetModalForWindow:self.window completionHandler:nil];
}

- (void)finishSmokeTest:(NSString *)result {
    if (self.smokeTestFinished) {
        return;
    }
    self.smokeTestFinished = YES;

    NSString *resultPath =
        NSProcessInfo.processInfo.environment[@"PORTFOLIO_TEST_RESULT"];
    if (resultPath.length > 0) {
        [result writeToFile:resultPath
                 atomically:YES
                   encoding:NSUTF8StringEncoding
                      error:nil];
    }

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW,
                      (int64_t)(0.2 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
            [NSApp terminate:nil];
        });
}

- (void)webView:(WKWebView *)webView
    decidePolicyForNavigationAction:
        (WKNavigationAction *)navigationAction
                  decisionHandler:
                      (void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *URL = navigationAction.request.URL;
    if (!URL) {
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }

    if ([self isApprovedLocalURL:URL] ||
        [URL.scheme isEqualToString:@"about"]) {
        decisionHandler(WKNavigationActionPolicyAllow);
        return;
    }

    if ([@[ @"https", @"http", @"mailto" ]
            containsObject:URL.scheme.lowercaseString]) {
        decisionHandler(WKNavigationActionPolicyCancel);
        [self openExternally:URL];
        return;
    }

    [PortfolioDiagnosticLogger.sharedLogger
        recordMessage:
            @"A navigation to an unsupported URL scheme was blocked."];
    decisionHandler(WKNavigationActionPolicyCancel);
}

- (nullable WKWebView *)webView:(WKWebView *)webView
      createWebViewWithConfiguration:
          (WKWebViewConfiguration *)configuration
                forNavigationAction:
                    (WKNavigationAction *)navigationAction
                     windowFeatures:(WKWindowFeatures *)windowFeatures {
    if (!navigationAction.targetFrame) {
        NSURL *URL = navigationAction.request.URL;
        if ([self isApprovedLocalURL:URL]) {
            [webView loadRequest:[NSURLRequest requestWithURL:URL]];
        } else {
            [self openExternally:URL];
        }
    }
    return nil;
}

- (void)webView:(WKWebView *)webView
    didFinishNavigation:(WKNavigation *)navigation {
    if (!self.isSmokeTest) {
        return;
    }

    NSString *script = nil;
    NSString *nextPage = nil;
    switch (self.smokeTestStage) {
    case 0:
        script =
            @"document.title.includes('Xi (Keith) Gong') && "
             "Boolean(document.querySelector('main')) && "
             "document.querySelectorAll('.site-nav a').length === 4";
        nextPage = @"projects/index.html";
        break;
    case 1:
        script =
            @"(() => {"
             "const input = document.querySelector('.searchBar');"
             "if (!input || document.querySelectorAll('.projects article').length "
             "!== 13 || document.querySelectorAll('#projects-pie-plot path').length "
             "=== 0) return false;"
             "input.value = 'Bikewatching';"
             "input.dispatchEvent(new Event('input', { bubbles: true }));"
             "return document.querySelectorAll('.projects article').length === 1;"
             "})()";
        nextPage = @"resume/index.html";
        break;
    case 2:
        script =
            @"document.title.startsWith('Resume') && "
             "document.querySelectorAll('.cv-section').length === 4";
        nextPage = @"contact/index.html";
        break;
    default:
        script =
            @"document.title.startsWith('Contact') && "
             "Boolean(document.querySelector('form')) && "
             "Boolean(document.querySelector('textarea'))";
        break;
    }

    __weak typeof(self) weakSelf = self;
    [webView evaluateJavaScript:script
             completionHandler:^(id value, NSError *error) {
                 typeof(self) self = weakSelf;
                 if (!self) {
                     return;
                 }
                 if (error) {
                     [self finishSmokeTest:
                               @"FAIL: Web content validation failed."];
                     return;
                 }
                 if (![value respondsToSelector:@selector(boolValue)] ||
                     ![value boolValue]) {
                     [self finishSmokeTest:
                               @"FAIL: A packaged workflow check failed."];
                     return;
                 }
                 if (nextPage) {
                     self.smokeTestStage += 1;
                     NSURL *nextURL =
                         [self.webRootURL
                             URLByAppendingPathComponent:nextPage];
                     [self.webView
                         loadFileURL:nextURL
                         allowingReadAccessToURL:self.webRootURL];
                     return;
                 }
                 [self finishSmokeTest:
                           @"PASS: home, navigation, projects, search, chart, resume, and contact"];
             }];
}

- (void)webView:(WKWebView *)webView
    didFailNavigation:(WKNavigation *)navigation
             withError:(NSError *)error {
    if (error.code == NSURLErrorCancelled) {
        return;
    }
    [self presentStartupError:
              @"The portfolio page could not be loaded."];
}

- (void)webView:(WKWebView *)webView
    didFailProvisionalNavigation:(WKNavigation *)navigation
                       withError:(NSError *)error {
    if (error.code == NSURLErrorCancelled) {
        return;
    }
    [self presentStartupError:
              @"The portfolio page could not be opened."];
}

@end

@interface PortfolioApplicationDelegate : NSObject <NSApplicationDelegate>

@property(nonatomic) PortfolioWindowController *windowController;

@end

@implementation PortfolioApplicationDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    [self buildMenus];

    NSError *error = nil;
    if (![PortfolioDiagnosticLogger.sharedLogger
            prepareDirectories:&error]) {
        [PortfolioDiagnosticLogger.sharedLogger
            recordMessage:
                @"The application data directories could not be prepared."];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.windowController =
        [[PortfolioWindowController alloc] init];
    [self.windowController show];
    [NSApp activateIgnoringOtherApps:YES];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:
    (NSApplication *)sender {
    return YES;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender
                    hasVisibleWindows:(BOOL)flag {
    if (!flag) {
        [self.windowController bringToFront];
    }
    return YES;
}

- (void)reloadPage:(id)sender {
    [self.windowController reload];
}

- (void)goBack:(id)sender {
    [self.windowController goBack];
}

- (void)goForward:(id)sender {
    [self.windowController goForward];
}

- (void)buildMenus {
    NSMenu *mainMenu = [[NSMenu alloc] init];

    NSMenuItem *applicationItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:applicationItem];
    NSMenu *applicationMenu =
        [[NSMenu alloc] initWithTitle:PortfolioName];
    applicationItem.submenu = applicationMenu;

    NSMenuItem *aboutItem = [[NSMenuItem alloc]
        initWithTitle:[@"About " stringByAppendingString:PortfolioName]
               action:@selector(orderFrontStandardAboutPanel:)
        keyEquivalent:@""];
    aboutItem.target = NSApp;
    [applicationMenu addItem:aboutItem];
    [applicationMenu addItem:NSMenuItem.separatorItem];
    [applicationMenu
        addItemWithTitle:[@"Hide " stringByAppendingString:PortfolioName]
                  action:@selector(hide:)
           keyEquivalent:@"h"];
    NSMenuItem *hideOthersItem =
        [applicationMenu addItemWithTitle:@"Hide Others"
                                   action:@selector(hideOtherApplications:)
                            keyEquivalent:@"h"];
    hideOthersItem.keyEquivalentModifierMask =
        NSEventModifierFlagCommand | NSEventModifierFlagOption;
    [applicationMenu addItemWithTitle:@"Show All"
                               action:@selector(unhideAllApplications:)
                        keyEquivalent:@""];
    [applicationMenu addItem:NSMenuItem.separatorItem];
    [applicationMenu
        addItemWithTitle:[@"Quit " stringByAppendingString:PortfolioName]
                  action:@selector(terminate:)
           keyEquivalent:@"q"];

    NSMenuItem *editItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:editItem];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
    editItem.submenu = editMenu;
    [editMenu addItemWithTitle:@"Undo"
                        action:@selector(undo:)
                 keyEquivalent:@"z"];
    NSMenuItem *redoItem =
        [editMenu addItemWithTitle:@"Redo"
                            action:@selector(redo:)
                     keyEquivalent:@"z"];
    redoItem.keyEquivalentModifierMask =
        NSEventModifierFlagCommand | NSEventModifierFlagShift;
    [editMenu addItem:NSMenuItem.separatorItem];
    [editMenu addItemWithTitle:@"Cut"
                        action:@selector(cut:)
                 keyEquivalent:@"x"];
    [editMenu addItemWithTitle:@"Copy"
                        action:@selector(copy:)
                 keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Paste"
                        action:@selector(paste:)
                 keyEquivalent:@"v"];
    [editMenu addItemWithTitle:@"Select All"
                        action:@selector(selectAll:)
                 keyEquivalent:@"a"];

    NSMenuItem *viewItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:viewItem];
    NSMenu *viewMenu = [[NSMenu alloc] initWithTitle:@"View"];
    viewItem.submenu = viewMenu;
    NSMenuItem *backItem = [[NSMenuItem alloc]
        initWithTitle:@"Back"
               action:@selector(goBack:)
        keyEquivalent:@"["];
    backItem.target = self;
    [viewMenu addItem:backItem];
    NSMenuItem *forwardItem = [[NSMenuItem alloc]
        initWithTitle:@"Forward"
               action:@selector(goForward:)
        keyEquivalent:@"]"];
    forwardItem.target = self;
    [viewMenu addItem:forwardItem];
    NSMenuItem *reloadItem = [[NSMenuItem alloc]
        initWithTitle:@"Reload"
               action:@selector(reloadPage:)
        keyEquivalent:@"r"];
    reloadItem.target = self;
    [viewMenu addItem:reloadItem];
    [viewMenu addItem:NSMenuItem.separatorItem];
    NSMenuItem *fullScreenItem =
        [viewMenu addItemWithTitle:@"Enter Full Screen"
                            action:@selector(toggleFullScreen:)
                     keyEquivalent:@"f"];
    fullScreenItem.keyEquivalentModifierMask =
        NSEventModifierFlagCommand | NSEventModifierFlagControl;

    NSMenuItem *windowItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:windowItem];
    NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];
    windowItem.submenu = windowMenu;
    [windowMenu addItemWithTitle:@"Minimize"
                          action:@selector(performMiniaturize:)
                   keyEquivalent:@"m"];
    [windowMenu addItemWithTitle:@"Zoom"
                          action:@selector(performZoom:)
                   keyEquivalent:@""];

    NSApp.mainMenu = mainMenu;
    NSApp.windowsMenu = windowMenu;
}

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *application =
            NSApplication.sharedApplication;
        PortfolioApplicationDelegate *delegate =
            [[PortfolioApplicationDelegate alloc] init];
        application.delegate = delegate;
        [application
            setActivationPolicy:NSApplicationActivationPolicyRegular];
        [application run];
        (void)delegate;
    }
    return EXIT_SUCCESS;
}
