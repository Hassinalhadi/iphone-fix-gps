#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#import <objc/runtime.h>

// MARK: - مفاتيح التخزين في NSUserDefaults
#define kFakeGPSEnabledKey @"hs_fake_gps_enabled"
#define kFakeLatitudeKey   @"hs_fake_latitude"
#define kFakeLongitudeKey  @"hs_fake_longitude"

// MARK: - دوال مساعدة لإدارة الموقع
static BOOL isFakeGPSEnabled() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kFakeGPSEnabledKey];
}

static CLLocationCoordinate2D getSavedCoordinate() {
    double lat = [[NSUserDefaults standardUserDefaults] doubleForKey:kFakeLatitudeKey];
    double lon = [[NSUserDefaults standardUserDefaults] doubleForKey:kFakeLongitudeKey];
    if (lat == 0.0 && lon == 0.0) {
        // إحداثيات افتراضية إذا لم يتم تحديد موقع مسبقاً (مثلاً: الرياض)
        return CLLocationCoordinate2DMake(24.7136, 46.6753);
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

// MARK: - واجهة الخريطة التفاعلية (MKMapView UI)

@interface HSRiderMapViewController : UIViewController <MKMapViewDelegate>
@property (nonatomic, strong) MKMapView *mapView;
@property (nonatomic, strong) MKPointAnnotation *pinAnnotation;
@property (nonatomic, strong) UISwitch *enableSwitch;
@property (nonatomic, strong) UILabel *coordLabel;
@end

@implementation HSRiderMapViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    // 1. الخريطة
    self.mapView = [[MKMapView alloc] initWithFrame:self.view.bounds];
    self.mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.mapView.delegate = self;
    [self.view addSubview:self.mapView];

    // تحديد الموقع الحالي وضبط الكاميرا
    CLLocationCoordinate2D savedCoord = getSavedCoordinate();
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(savedCoord, 1000, 1000);
    [self.mapView setRegion:region animated:NO];

    // إضافة الدبوس
    self.pinAnnotation = [[MKPointAnnotation alloc] init];
    self.pinAnnotation.coordinate = savedCoord;
    self.pinAnnotation.title = @"الموقع الوهمي المحدد";
    [self.mapView addAnnotation:self.pinAnnotation];

    // إيماءة الضغط المطول لتغيير مكان الدبوس
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 0.4;
    [self.mapView addGestureRecognizer:longPress];

    // 2. الشريط العلوي (Header Bar)
    UIView *topBar = [[UIView alloc] initWithFrame:CGRectMake(20, 50, self.view.bounds.size.width - 40, 60)];
    topBar.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.75];
    topBar.layer.cornerRadius = 14;
    topBar.clipsToBounds = YES;
    [self.view addSubview:topBar];

    // سويتش التفعيل
    self.enableSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(15, 15, 51, 31)];
    self.enableSwitch.on = isFakeGPSEnabled();
    [self.enableSwitch addTarget:self action:@selector(toggleEnabled:) forControlEvents:UIControlEventValueChanged];
    [topBar addSubview:self.enableSwitch];

    UILabel *switchLabel = [[UILabel alloc] initWithFrame:CGRectMake(75, 18, 120, 24)];
    switchLabel.text = @"تفعيل التزييف";
    switchLabel.textColor = [UIColor whiteColor];
    switchLabel.font = [UIFont boldSystemFontOfSize:14];
    [topBar addSubview:switchLabel];

    // زر الإغلاق
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(topBar.frame.size.width - 45, 12, 35, 35);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    [closeBtn addTarget:self action:@selector(dismissSelf) forControlEvents:UIControlEventTouchUpInside];
    [topBar addSubview:closeBtn];

    // 3. لوحة الإحداثيات والزر السفلي
    UIView *bottomBar = [[UIView alloc] initWithFrame:CGRectMake(20, self.view.bounds.size.height - 140, self.view.bounds.size.width - 40, 100)];
    bottomBar.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
    bottomBar.layer.cornerRadius = 16;
    bottomBar.clipsToBounds = YES;
    [self.view addSubview:bottomBar];

    self.coordLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, bottomBar.frame.size.width - 20, 25)];
    self.coordLabel.textColor = [UIColor yellowColor];
    self.coordLabel.textAlignment = NSTextAlignmentCenter;
    self.coordLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [self updateCoordLabel:savedCoord];
    [bottomBar addSubview:self.coordLabel];

    UIButton *saveBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    saveBtn.frame = CGRectMake(15, 45, bottomBar.frame.size.width - 30, 42);
    saveBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.55 blue:1.0 alpha:1.0];
    saveBtn.layer.cornerRadius = 10;
    [saveBtn setTitle:@"حفظ وتطبيق الموقع" forState:UIControlStateNormal];
    [saveBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    saveBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [saveBtn addTarget:self action:@selector(saveLocation) forControlEvents:UIControlEventTouchUpInside];
    [bottomBar addSubview:saveBtn];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        CGPoint touchPoint = [gesture locationInView:self.mapView];
        CLLocationCoordinate2D coord = [self.mapView convertPoint:touchPoint toCoordinateFromView:self.mapView];
        self.pinAnnotation.coordinate = coord;
        [self updateCoordLabel:coord];
    }
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    if ([annotation isKindOfClass:[MKPointAnnotation class]]) {
        static NSString *pinID = @"HSRiderPin";
        MKPinAnnotationView *pin = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:pinID];
        if (!pin) {
            pin = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:pinID];
            pin.pinTintColor = [UIColor redColor];
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

- (void)updateCoordLabel:(CLLocationCoordinate2D)coord {
    self.coordLabel.text = [NSString stringWithFormat:@"Lat: %.5f | Lon: %.5f", coord.latitude, coord.longitude];
}

- (void)toggleEnabled:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:kFakeGPSEnabledKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)saveLocation {
    CLLocationCoordinate2D coord = self.pinAnnotation.coordinate;
    [[NSUserDefaults standardUserDefaults] setDouble:coord.latitude forKey:kFakeLatitudeKey];
    [[NSUserDefaults standardUserDefaults] setDouble:coord.longitude forKey:kFakeLongitudeKey];
    [[NSUserDefaults standardUserDefaults] setBool:self.enableSwitch.isOn forKey:kFakeGPSEnabledKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    [self dismissSelf];
}

- (void)dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

// MARK: - الزر العائم (Floating Button) لإظهار الخريطة في التطبيق

@interface HSRiderFloatingButton : UIButton
@end

@implementation HSRiderFloatingButton

- (instancetype)init {
    self = [super initWithFrame:CGRectMake(20, 120, 56, 56)];
    if (self) {
        self.backgroundColor = [UIColor colorWithRed:0.95 green:0.25 blue:0.25 alpha:0.9];
        [self setTitle:@"📍" forState:UIControlStateNormal];
        self.titleLabel.font = [UIFont systemFontOfSize:26];
        self.layer.cornerRadius = 28;
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOpacity = 0.35;
        self.layer.shadowOffset = CGSizeMake(0, 3);
        self.layer.shadowRadius = 5;

        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:pan];
        [self addTarget:self action:@selector(openMap) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.superview];
    self.center = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    [pan setTranslation:CGPointZero inView:self.superview];
}

- (void)openMap {
    UIViewController *topVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    HSRiderMapViewController *mapVC = [[HSRiderMapViewController alloc] init];
    mapVC.modalPresentationStyle = UIModalPresentationFullScreen;
    [topVC presentViewController:mapVC animated:YES completion:nil];
}

@end

// MARK: - اعتراض الـ Delegate Callback ديناميكياً

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

    // 1. اعتراض locationManager:didUpdateLocations: (الحديثة)
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

    // 2. اعتراض locationManager:didUpdateToLocation:fromLocation: (القديمة)
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

// MARK: - Hooks لـ CoreLocation و UIKit

%hook CLLocationManager

// اعتراض قراءة خاصية الموقع المباشرة
- (CLLocation *)location {
    CLLocation *spoofed = createSpoofedLocation();
    if (spoofed) {
        return spoofed;
    }
    return %orig;
}

// اعتراض تعيين الـ Delegate لتسجيل الـ Hook عليه فوراً
- (void)setDelegate:(id<CLLocationManagerDelegate>)delegate {
    if (delegate) {
        hookDelegateClass([delegate class]);
    }
    %orig(delegate);
}

%end

// إضافة الزر العائم فوق واجهة التطبيق
%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;

    static BOOL buttonAdded = NO;
    if (!buttonAdded) {
        HSRiderFloatingButton *btn = [[HSRiderFloatingButton alloc] init];
        [self addSubview:btn];
        buttonAdded = YES;
    }
}

%end
