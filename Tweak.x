#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>

%hook CLLocationManager

- (CLLocation *)location {
    CLLocation *originalLocation = %orig;
    // تخصيص أو تثبيت إحداثيات الموقع هنا عند الحاجة
    return originalLocation;
}

%end

%ctor {
    NSLog(@"[hsrider] Library loaded successfully.");
}
