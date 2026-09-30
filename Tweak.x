#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

static BOOL isSpoofEnabled = YES;
static CLLocationCoordinate2D customCoords = {33.3152, 44.3661};

// 1. اعتراض الموقع الجغرافي الأساسي
%hook CLLocationManager

- (CLLocation *)location {
    if (isSpoofEnabled) {
        return [[CLLocation alloc] initWithLatitude:customCoords.latitude longitude:customCoords.longitude];
    }
    return %orig;
}

%end

// 2. اعتراض موقع المستخدم في الخرائط
%hook MKUserLocation

- (CLLocation *)location {
    if (isSpoofEnabled) {
        return [[CLLocation alloc] initWithLatitude:customCoords.latitude longitude:customCoords.longitude];
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

// 3. إضافة إيماءة لفتح القائمة
%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleCleanRiderTap)];
    tap.numberOfTapsRequired = 2;
    tap.numberOfTouchesRequired = 2;
    [self addGestureRecognizer:tap];
}

%new
- (void)handleCleanRiderTap {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"CleanRider"
                                                                   message:@"حالة تغيير الموقع"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    NSString *btnTitle = isSpoofEnabled ? @"إيقاف التزييف" : @"تفعيل التزييف";
    [alert addAction:[UIAlertAction actionWithTitle:btnTitle
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        isSpoofEnabled = !isSpoofEnabled;
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"إغلاق" style:UIAlertActionStyleCancel handler:nil]];
    
    UIViewController *root = self.rootViewController;
    while (root.presentedViewController) {
        root = root.presentedViewController;
    }
    [root presentViewController:alert animated:YES completion:nil];
}

%end
