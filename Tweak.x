#import <CoreLocation/CoreLocation.h>

%hook CLLocationManager

- (CLLocation *)location {
    // تطبيق التعديلات المخصصة للموقع هنا
    return %orig;
}

%end
