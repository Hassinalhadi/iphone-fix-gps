#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#import <objc/runtime.h>

// MARK: - Constants & Storage Keys
#define kFakeGPSEnabledKey   @"gufran_fake_gps_enabled"
#define kFakeLatitudeKey     @"gufran_fake_latitude"
#define kFakeLongitudeKey    @"gufran_fake_longitude"
#define kFavoritesListKey    @"gufran_favorites_list"

#define kWhatsAppPhone       @"966510316786"
#define kTelegramUsername    @"Gufran3729"

// MARK: - Helper Functions
static BOOL isFakeGPSEnabled() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kFakeGPSEnabledKey];
}

static CLLocationCoordinate2D getSavedCoordinate() {
    double lat = [[NSUserDefaults standardUserDefaults] doubleForKey:kFakeLatitudeKey];
    double lon = [[NSUserDefaults standardUserDefaults] doubleForKey:kFakeLongitudeKey];
    if (lat == 0.0 && lon == 0.0) {
        return CLLocationCoordinate2DMake(24.7136, 46.6753); // Default Riyadh
    }
    return CLLocationCoordinate2DMake(lat, lon);
}

static CLLocation *createSpoofedLocation() {
    if (!isFakeGPSEnabled()) return nil;

    CLLocationCoordinate2D coord = getSavedCoordinate();
    return [[CLLocation alloc] initWithCoordinate:coord
                                         altitude:15.0
                               horizontalAccuracy:5.0
                                 verticalAccuracy:5.0
                                           course:0.0
                                            speed:0.0
                                        timestamp:[NSDate date]];
}

static UIWindow *getKeyWindow() {
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *w in windowScene.windows) {
                    if (w.isKeyWindow) {
                        keyWindow = w;
                        break;
                    }
                }
            }
            if (keyWindow) break;
        }
    }
    if (!keyWindow) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        keyWindow = [UIApplication sharedApplication].keyWindow;
        if (!keyWindow && [UIApplication sharedApplication].windows.count > 0) {
            keyWindow = [UIApplication sharedApplication].windows.firstObject;
        }
#pragma clang diagnostic pop
    }
    return keyWindow;
}

static UIViewController *getTopViewController() {
    UIWindow *window = getKeyWindow();
    UIViewController *topVC = window.rootViewController;
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    return topVC;
}

// MARK: - Map View Controller (Dark Professional Theme)

@interface GufranMapViewController : UIViewController <MKMapViewDelegate>
@property (nonatomic, strong) MKMapView *mapView;
@property (nonatomic, strong) MKPointAnnotation *pinAnnotation;
@property (nonatomic, strong) UILabel *coordLabel;
@end

@implementation GufranMapViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    if (@available(iOS 13.0, *)) {
        self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    }
    self.view.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.10 alpha:1.0];

    // 1. Map Configuration
    self.mapView = [[MKMapView alloc] initWithFrame:self.view.bounds];
    self.mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.mapView.delegate = self;
    [self.view addSubview:self.mapView];

    CLLocationCoordinate2D savedCoord = getSavedCoordinate();
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(savedCoord, 1200, 1200);
    [self.mapView setRegion:region animated:NO];

    self.pinAnnotation = [[MKPointAnnotation alloc] init];
    self.pinAnnotation.coordinate = savedCoord;
    self.pinAnnotation.title = @"Selected Location";
    [self.mapView addAnnotation:self.pinAnnotation];

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 0.35;
    [self.mapView addGestureRecognizer:longPress];

    // 2. Floating Top Header
    UIVisualEffectView *topBar = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    topBar.frame = CGRectMake(20, 50, self.view.bounds.size.width - 40, 56);
    topBar.layer.cornerRadius = 16;
    topBar.clipsToBounds = YES;
    [self.view addSubview:topBar];

    UILabel *headerTitle = [[UILabel alloc] initWithFrame:CGRectMake(20, 16, 200, 24)];
    headerTitle.text = @"📍 Set Target Location";
    headerTitle.textColor = [UIColor whiteColor];
    headerTitle.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    [topBar.contentView addSubview:headerTitle];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(topBar.frame.size.width - 45, 11, 34, 34);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor colorWithWhite:0.85 alpha:1.0] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    [closeBtn addTarget:self action:@selector(dismissSelf) forControlEvents:UIControlEventTouchUpInside];
    [topBar.contentView addSubview:closeBtn];

    // 3. Floating Bottom Bar
    UIVisualEffectView *bottomBar = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    bottomBar.frame = CGRectMake(20, self.view.bounds.size.height - 135, self.view.bounds.size.width - 40, 95);
    bottomBar.layer.cornerRadius = 20;
    bottomBar.clipsToBounds = YES;
    [self.view addSubview:bottomBar];

    self.coordLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, bottomBar.frame.size.width - 20, 22)];
    self.coordLabel.textColor = [UIColor colorWithRed:0.2 green:0.8 blue:1.0 alpha:1.0];
    self.coordLabel.textAlignment = NSTextAlignmentCenter;
    self.coordLabel.font = [UIFont fontWithName:@"Courier-Bold" size:13] ?: [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    [self updateCoordLabel:savedCoord];
    [bottomBar.contentView addSubview:self.coordLabel];

    UIButton *applyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    applyBtn.frame = CGRectMake(15, 38, bottomBar.frame.size.width - 30, 44);
    applyBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0];
    applyBtn.layer.cornerRadius = 12;
    [applyBtn setTitle:@"Save & Apply Location" forState:UIControlStateNormal];
    [applyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    applyBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [applyBtn addTarget:self action:@selector(saveAndApply) forControlEvents:UIControlEventTouchUpInside];
    [bottomBar.contentView addSubview:applyBtn];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        CGPoint touchPoint = [gesture locationInView:self.mapView];
        CLLocationCoordinate2D coord = [self.mapView convertPoint:touchPoint toCoordinateFromView:self.mapView];
        self.pinAnnotation.coordinate = coord;
        [self updateCoordLabel:coord];
    }
}

- (void)updateCoordLabel:(CLLocationCoordinate2D)coord {
    self.coordLabel.text = [NSString stringWithFormat:@"Lat: %.5f | Lon: %.5f", coord.latitude, coord.longitude];
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    if ([annotation isKindOfClass:[MKPointAnnotation class]]) {
        static NSString *pinID = @"GufranPin";
        MKPinAnnotationView *pin = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:pinID];
        if (!pin) {
            pin = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:pinID];
            pin.pinTintColor = [UIColor colorWithRed:1.0 green:0.2 blue:0.3 alpha:1.0];
            pin.animatesDrop = YES;
            pin.draggable = YES;
        } else {
            pin.annotation = annotation;
        }
        return pin;
    }
    return nil;
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view didChangeDragState:(MKAnnotationViewDragState)newState fromOldState:(MKAnnotationViewDragState)oldState {
    if (newState == MKAnnotationViewDragStateEnding) {
        [self updateCoordLabel:view.annotation.coordinate];
    }
}

- (void)saveAndApply {
    CLLocationCoordinate2D coord = self.pinAnnotation.coordinate;
    [[NSUserDefaults standardUserDefaults] setDouble:coord.latitude forKey:kFakeLatitudeKey];
    [[NSUserDefaults standardUserDefaults] setDouble:coord.longitude forKey:kFakeLongitudeKey];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kFakeGPSEnabledKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    [self dismissSelf];
}

- (void)dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

// MARK: - Main Menu Controller (Gufran-Root VIP UI)

@interface GufranMenuViewController : UIViewController
@property (nonatomic, strong) UISwitch *statusSwitch;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *currentCoordLabel;
@end

@implementation GufranMenuViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.55];

    // Main Card
    UIVisualEffectView *cardView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    CGFloat cardWidth = self.view.bounds.size.width - 44;
    CGFloat cardHeight = 490;
    cardView.frame = CGRectMake(22, (self.view.bounds.size.height - cardHeight) / 2, cardWidth, cardHeight);
    cardView.layer.cornerRadius = 24;
    cardView.layer.borderWidth = 1.0;
    cardView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.12].CGColor;
    cardView.clipsToBounds = YES;
    [self.view addSubview:cardView];

    UIView *content = cardView.contentView;

    // Header Title
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, cardWidth - 70, 28)];
    titleLabel.text = @"⚡ Gufran-Root VIP";
    titleLabel.textColor = [UIColor colorWithRed:0.25 green:0.85 blue:1.0 alpha:1.0];
    titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightHeavy];
    [content addSubview:titleLabel];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(cardWidth - 46, 18, 30, 30);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor colorWithWhite:0.75 alpha:1.0] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    [closeBtn addTarget:self action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:closeBtn];

    // Status Row
    UIView *statusBox = [[UIView alloc] initWithFrame:CGRectMake(16, 62, cardWidth - 32, 50)];
    statusBox.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.07];
    statusBox.layer.cornerRadius = 14;
    [content addSubview:statusBox];

    UILabel *sTitle = [[UILabel alloc] initWithFrame:CGRectMake(15, 14, 150, 22)];
    sTitle.text = @"Spoofing Status";
    sTitle.textColor = [UIColor whiteColor];
    sTitle.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [statusBox addSubview:sTitle];

    self.statusSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(statusBox.frame.size.width - 65, 10, 51, 31)];
    self.statusSwitch.on = isFakeGPSEnabled();
    self.statusSwitch.onTintColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.4 alpha:1.0];
    [self.statusSwitch addTarget:self action:@selector(toggleStatus:) forControlEvents:UIControlEventValueChanged];
    [statusBox addSubview:self.statusSwitch];

    // Current Coordinates Display
    self.currentCoordLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 120, cardWidth - 32, 22)];
    self.currentCoordLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    self.currentCoordLabel.font = [UIFont fontWithName:@"Courier" size:12] ?: [UIFont systemFontOfSize:12];
    self.currentCoordLabel.textAlignment = NSTextAlignmentCenter;
    [self refreshCoordLabel];
    [content addSubview:self.currentCoordLabel];

    // Action Buttons
    UIButton *mapBtn = [self createStyledButtonWithTitle:@"🗺️ Open Map Editor" bg:[UIColor colorWithRed:0.15 green:0.45 blue:0.95 alpha:1.0] y:152];
    [mapBtn addTarget:self action:@selector(openMap) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:mapBtn];

    UIButton *favListBtn = [self createStyledButtonWithTitle:@"⭐ Favorite Locations" bg:[UIColor colorWithWhite:1.0 alpha:0.12] y:206];
    [favListBtn addTarget:self action:@selector(showFavoritesSheet) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:favListBtn];

    UIButton *saveFavBtn = [self createStyledButtonWithTitle:@"💾 Save Current as Favorite" bg:[UIColor colorWithWhite:1.0 alpha:0.12] y:260];
    [saveFavBtn addTarget:self action:@selector(promptSaveFavorite) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:saveFavBtn];

    UIButton *resetBtn = [self createStyledButtonWithTitle:@"🔄 Reset to Real Location" bg:[UIColor colorWithRed:0.75 green:0.25 blue:0.25 alpha:0.8] y:314];
    [resetBtn addTarget:self action:@selector(resetLocation) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:resetBtn];

    // Social & Support Buttons
    UILabel *supportLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 368, cardWidth - 32, 18)];
    supportLabel.text = @"Contact & Support";
    supportLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    supportLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    supportLabel.textAlignment = NSTextAlignmentCenter;
    [content addSubview:supportLabel];

    CGFloat btnW = (cardWidth - 42) / 2;

    // WhatsApp Button
    UIButton *waBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    waBtn.frame = CGRectMake(16, 394, btnW, 46);
    waBtn.backgroundColor = [UIColor colorWithRed:0.12 green:0.72 blue:0.35 alpha:1.0];
    waBtn.layer.cornerRadius = 13;
    [waBtn setTitle:@"💬 WhatsApp" forState:UIControlStateNormal];
    [waBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    waBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [waBtn addTarget:self action:@selector(openWhatsApp) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:waBtn];

    // Telegram Button
    UIButton *tgBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    tgBtn.frame = CGRectMake(26 + btnW, 394, btnW, 46);
    tgBtn.backgroundColor = [UIColor colorWithRed:0.15 green:0.60 blue:0.90 alpha:1.0];
    tgBtn.layer.cornerRadius = 13;
    [tgBtn setTitle:@"✈️ Telegram" forState:UIControlStateNormal];
    [tgBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    tgBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [tgBtn addTarget:self action:@selector(openTelegram) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:tgBtn];

    // Footer Info
    UILabel *footer = [[UILabel alloc] initWithFrame:CGRectMake(16, 452, cardWidth - 32, 18)];
    footer.text = @"Developer: Gufran-Root • Version 2.0";
    footer.textColor = [UIColor colorWithWhite:0.4 alpha:1.0];
    footer.font = [UIFont systemFontOfSize:11];
    footer.textAlignment = NSTextAlignmentCenter;
    [content addSubview:footer];
}

- (UIButton *)createStyledButtonWithTitle:(NSString *)title bg:(UIColor *)bgColor y:(CGFloat)y {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(16, y, self.view.bounds.size.width - 44 - 32, 44);
    btn.backgroundColor = bgColor;
    btn.layer.cornerRadius = 13;
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    return btn;
}

- (void)refreshCoordLabel {
    CLLocationCoordinate2D c = getSavedCoordinate();
    self.currentCoordLabel.text = [NSString stringWithFormat:@"Active: %.5f, %.5f", c.latitude, c.longitude];
}

- (void)toggleStatus:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:kFakeGPSEnabledKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)openMap {
    [self dismissViewControllerAnimated:YES completion:^{
        GufranMapViewController *mapVC = [[GufranMapViewController alloc] init];
        mapVC.modalPresentationStyle = UIModalPresentationFullScreen;
        [getTopViewController() presentViewController:mapVC animated:YES completion:nil];
    }];
}

- (void)promptSaveFavorite {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Save Location"
                                                                   message:@"Enter a name for this location:"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"e.g. Al Sulay Branch";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *name = alert.textFields.firstObject.text;
        if (!name || name.length == 0) name = @"Saved Location";

        CLLocationCoordinate2D c = getSavedCoordinate();
        NSMutableArray *favs = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] arrayForKey:kFavoritesListKey] ?: @[]];
        [favs addObject:@{@"name": name, @"lat": @(c.latitude), @"lon": @(c.longitude)}];
        [[NSUserDefaults standardUserDefaults] setObject:favs forKey:kFavoritesListKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showFavoritesSheet {
    NSArray *favs = [[NSUserDefaults standardUserDefaults] arrayForKey:kFavoritesListKey] ?: @[];
    if (favs.count == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"No Favorites"
                                                                       message:@"You have not saved any favorite locations yet."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"⭐ Favorite Locations"
                                                                   message:@"Select a location to apply immediately:"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSDictionary *item in favs) {
        NSString *title = [NSString stringWithFormat:@"📍 %@", item[@"name"]];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            double lat = [item[@"lat"] doubleValue];
            double lon = [item[@"lon"] doubleValue];
            [[NSUserDefaults standardUserDefaults] setDouble:lat forKey:kFakeLatitudeKey];
            [[NSUserDefaults standardUserDefaults] setDouble:lon forKey:kFakeLongitudeKey];
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kFakeGPSEnabledKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [self refreshCoordLabel];
            self.statusSwitch.on = YES;
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:@"Clear All Favorites" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kFavoritesListKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)resetLocation {
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kFakeGPSEnabledKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    self.statusSwitch.on = NO;
    [self closeMenu];
}

- (void)openWhatsApp {
    NSString *urlStr = [NSString stringWithFormat:@"https://wa.me/%@", kWhatsAppPhone];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlStr] options:@{} completionHandler:nil];
}

- (void)openTelegram {
    NSString *urlStr = [NSString stringWithFormat:@"https://t.me/%@", kTelegramUsername];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlStr] options:@{} completionHandler:nil];
}

- (void)closeMenu {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

// MARK: - Floating Button (Gufran-Root Icon)

@interface GufranFloatingButton : UIButton
@end

@implementation GufranFloatingButton

- (instancetype)init {
    self = [super initWithFrame:CGRectMake(16, 120, 58, 58)];
    if (self) {
        self.backgroundColor = [UIColor colorWithRed:0.08 green:0.12 blue:0.18 alpha:0.92];
        [self setTitle:@"⚡GR" forState:UIControlStateNormal];
        [self setTitleColor:[UIColor colorWithRed:0.25 green:0.85 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
        self.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightHeavy];
        self.layer.cornerRadius = 29;
        self.layer.borderWidth = 1.5;
        self.layer.borderColor = [UIColor colorWithRed:0.25 green:0.85 blue:1.0 alpha:0.5].CGColor;
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOpacity = 0.45;
        self.layer.shadowOffset = CGSizeMake(0, 4);
        self.layer.shadowRadius = 6;

        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:pan];
        [self addTarget:self action:@selector(openMenu) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.superview];
    self.center = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    [pan setTranslation:CGPointZero inView:self.superview];
}

- (void)openMenu {
    UIViewController *topVC = getTopViewController();
    if (!topVC) return;
    if ([topVC isKindOfClass:[GufranMenuViewController class]]) return;

    GufranMenuViewController *menuVC = [[GufranMenuViewController alloc] init];
    menuVC.modalPresentationStyle = UIModalPresentationOverFullScreen;
    menuVC.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [topVC presentViewController:menuVC animated:YES completion:nil];
}

@end

// MARK: - CoreLocation Hooks & Delegate Callback

static NSMutableSet *swizzledDelegateClasses;

static void hookDelegateClass(Class delClass) {
    if (!delClass) return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        swizzledDelegateClasses = [[NSMutableSet alloc] init];
    });

    NSString *className = NSStringFromClass(delClass);
    @synchronized (swizzledDelegateClasses) {
        if ([swizzledDelegateClasses containsObject:className]) return;
        [swizzledDelegateClasses addObject:className];
    }

    SEL newLocSel = @selector(locationManager:didUpdateLocations:);
    Method newLocMethod = class_getInstanceMethod(delClass, newLocSel);
    if (newLocMethod) {
        IMP originalImp = method_getImplementation(newLocMethod);
        IMP swizzledImp = imp_implementationWithBlock(^(id self_obj, CLLocationManager *manager, NSArray<CLLocation *> *locations) {
            CLLocation *spoofed = createSpoofedLocation();
            NSArray<CLLocation *> *passedLocations = locations;
            if (spoofed) {
                passedLocations = @[spoofed];
            }
            ((void(*)(id, SEL, CLLocationManager *, NSArray<CLLocation *> *))originalImp)(self_obj, newLocSel, manager, passedLocations);
        });
        class_replaceMethod(delClass, newLocSel, swizzledImp, method_getTypeEncoding(newLocMethod));
    }

    SEL oldLocSel = @selector(locationManager:didUpdateToLocation:fromLocation:);
    Method oldLocMethod = class_getInstanceMethod(delClass, oldLocSel);
    if (oldLocMethod) {
        IMP originalOldImp = method_getImplementation(oldLocMethod);
        IMP swizzledOldImp = imp_implementationWithBlock(^(id self_obj, CLLocationManager *manager, CLLocation *newLocation, CLLocation *oldLocation) {
            CLLocation *spoofed = createSpoofedLocation();
            CLLocation *finalLoc = spoofed ? spoofed : newLocation;
            ((void(*)(id, SEL, CLLocationManager *, CLLocation *, CLLocation *))originalOldImp)(self_obj, oldLocSel, manager, finalLoc, oldLocation);
        });
        class_replaceMethod(delClass, oldLocSel, swizzledOldImp, method_getTypeEncoding(oldLocMethod));
    }
}

%hook CLLocationManager

- (CLLocation *)location {
    CLLocation *spoofed = createSpoofedLocation();
    if (spoofed) {
        return spoofed;
    }
    return %orig;
}

- (void)setDelegate:(id<CLLocationManagerDelegate>)delegate {
    if (delegate) {
        hookDelegateClass([delegate class]);
    }
    %orig(delegate);
}

%end

// MARK: - UIWindow Hook for Floating Button

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        static BOOL buttonAdded = NO;
        if (!buttonAdded && self.rootViewController) {
            GufranFloatingButton *btn = [[GufranFloatingButton alloc] init];
            [self addSubview:btn];
            buttonAdded = YES;
        }
    });
}

%end
