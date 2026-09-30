#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

static BOOL isSpoofEnabled = YES;
static CLLocationCoordinate2D customCoords = {33.3152, 44.3661}; // الإحداثيات الافتراضية

// 1. اعتراض الموقع الجغرافي الأساسي
%hook CLLocationManager

- (CLLocation *)location {
    if (isSpoofEnabled) {
        return [[CLLocation alloc] initWithCoordinate:customCoords
                                             altitude:20.0
                                   horizontalAccuracy:5.0
                                     verticalAccuracy:5.0
                                               course:0.0
                                                speed:0.0
                                            timestamp:[NSDate date]];
    }
    return %orig;
}

%end

// 2. اعتراض موقع المستخدم داخل الخرائط
%hook MKUserLocation

- (CLLocation *)location {
    if (isSpoofEnabled) {
        return [[CLLocation alloc] initWithCoordinate:customCoords
                                             altitude:20.0
                                   horizontalAccuracy:5.0
                                     verticalAccuracy:5.0
                                            timestamp:[NSDate date]];
    }
    return %orig;
}

- (CLLocationCoordinate2D)coordinate {
    if (isSpoofEnabled) {
        return customCoords;
    }
    return %orig;
}

%end

// 3. حقن إيماءة النقر المزدوج لفتح الإعدادات
%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTweakMenu)];
    tap.numberOfTapsRequired = 2;
    tap.numberOfTouchesRequired = 2; // نقر بإصبعين مرتين
    [self addGestureRecognizer:tap];
}

%new
- (void)handleTweakMenu {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"CleanRider"
                                                                   message:@"التحكم في الموقع"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:isSpoofEnabled ? @"إيقاف التزييف" : @"تفعيل التزييف"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        isSpoofEnabled = !isSpoofEnabled;
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    
    UIViewController *root = self.rootViewController;
    while (root.presentedViewController) {
        root = root.presentedViewController;
    }
    [root presentViewController:alert animated:YES completion:nil];
}

%end
