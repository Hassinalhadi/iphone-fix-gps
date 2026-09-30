#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonDigest.h>

#define SECRET_KEY "MySecretTweakKey2026!#"

// --- 1. دوال توليد المعرف والتحقق من المفتاح ---

static NSString* GetShortDeviceID() {
    NSString *rawID = [[[UIDevice currentDevice] identifierForVendor] UUIDString] ?: @"DEFAULT1";
    const char *str = [rawID UTF8String];
    unsigned char result[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(str, (CC_LONG)strlen(str), result);
    
    NSMutableString *hex = [NSMutableString stringWithCapacity:8];
    for (int i = 0; i < 4; i++) {
        [hex appendFormat:@"%02X", result[i]];
    }
    return [hex uppercaseString];
}

static BOOL VerifyLicenseKey(NSString *licenseKey) {
    if (!licenseKey) return NO;
    NSArray *parts = [licenseKey componentsSeparatedByString:@"-"];
    if (parts.count != 3) return NO;
    
    NSString *keyDevice = parts[0];
    NSString *expiryStr = parts;
    NSString *signature = parts;
    
    // فحص تطابق معرف الجهاز
    if (![keyDevice isEqualToString:GetShortDeviceID()]) return NO;
    
    // التحقق من التوقيع الرقمي
    NSString *payload = [NSString stringWithFormat:@"%@-%@", keyDevice, expiryStr];
    const char *keyBytes = SECRET_KEY;
    const char *dataBytes = [payload UTF8String];
    unsigned char hmac[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, keyBytes, strlen(keyBytes), dataBytes, strlen(dataBytes), hmac);
    
    NSMutableString *expectedSig = [NSMutableString stringWithCapacity:8];
    for (int i = 0; i < 4; i++) {
        [expectedSig appendFormat:@"%02X", hmac[i]];
    }
    if (![signature isEqualToString:expectedSig]) return NO;
    
    // التحقق من تاريخ الانتهاء
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"yyyyMMdd"];
    [df setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    NSDate *expDate = [df dateFromString:expiryStr];
    return (expDate && [expDate compare:[NSDate date]] == NSOrderedDescending);
}

// واجهة التفعيل باللغة الإنجليزية
@interface CustomActivationVC : UIViewController <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *codeField;
@end

@implementation CustomActivationVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.09 green:0.09 blue:0.11 alpha:1.0];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"GPS Location Simulator";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:22];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:titleLabel];
    
    UILabel *idLabel = [[UILabel alloc] init];
    idLabel.text = [NSString stringWithFormat:@"Device ID: %@", GetShortDeviceID()];
    idLabel.textColor = [UIColor systemGrayColor];
    idLabel.font = [UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightMedium];
    idLabel.textAlignment = NSTextAlignmentCenter;
    idLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:idLabel];
    
    self.codeField = [[UITextField alloc] init];
    self.codeField.placeholder = @"Enter Activation Key";
    self.codeField.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
    self.codeField.textColor = [UIColor whiteColor];
    self.codeField.textAlignment = NSTextAlignmentCenter;
    self.codeField.layer.cornerRadius = 10;
    self.codeField.delegate = self;
    self.codeField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.codeField];
    
    UIButton *actBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [actBtn setTitle:@"Activate" forState:UIControlStateNormal];
    actBtn.backgroundColor = [UIColor systemRedColor];
    [actBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    actBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    actBtn.layer.cornerRadius = 10;
    actBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [actBtn addTarget:self action:@selector(handleActivate) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:actBtn];
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:80],
        [titleLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        
        [idLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:12],
        [idLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        
        [self.codeField.topAnchor constraintEqualToAnchor:idLabel.bottomAnchor constant:30],
        [self.codeField.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.codeField.widthAnchor constraintEqualToConstant:280],
        [self.codeField.heightAnchor constraintEqualToConstant:44],
        
        [actBtn.topAnchor constraintEqualToAnchor:self.codeField.bottomAnchor constant:15],
        [actBtn.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [actBtn.widthAnchor constraintEqualToConstant:280],
        [actBtn.heightAnchor constraintEqualToConstant:44]
    ]];
}

- (void)handleActivate {
    [self.view endEditing:YES];
    NSString *key = [self.codeField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (VerifyLicenseKey(key)) {
        [[NSUserDefaults standardUserDefaults] setObject:key forKey:@"kSavedCustomLicenseKey"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Invalid Key" message:@"The license key is invalid or expired." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}
@end

// --- 2. إجبار اللغة الإنجليزية وتعطيل السيرفر القديم ---

static NSString* Hooked_language(id self, SEL _cmd) {
    return @"en";
}

static void Hooked_setLanguage(id self, SEL _cmd, NSString *lang) {
    // إهمال أي محاولة لتغيير اللغة
}

static void Hooked_enforceActivation(id self, SEL _cmd) {
    NSString *saved = [[NSUserDefaults standardUserDefaults] stringForKey:@"kSavedCustomLicenseKey"];
    if (!VerifyLicenseKey(saved)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIWindow *keyWin = nil;
            for (UIWindow *w in [UIApplication sharedApplication].windows) {
                if (w.isKeyWindow) { keyWin = w; break; }
            }
            if (keyWin.rootViewController && ![keyWin.rootViewController.presentedViewController isKindOfClass:[CustomActivationVC class]]) {
                CustomActivationVC *vc = [[CustomActivationVC alloc] init];
                vc.modalPresentationStyle = UIModalPresentationFullScreen;
                [keyWin.rootViewController presentViewController:vc animated:YES completion:nil];
            }
        });
    }
}

__attribute__((constructor))
static void InitPatch() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // تثبيت اللغة الإنجليزية
        Class clsManager = NSClassFromString(@"CLSManager");
        if (clsManager) {
            Method m1 = class_getInstanceMethod(clsManager, NSSelectorFromString(@"language"));
            if (m1) method_setImplementation(m1, (IMP)Hooked_language);
            
            Method m2 = class_getInstanceMethod(clsManager, NSSelectorFromString(@"setLanguage:"));
            if (m2) method_setImplementation(m2, (IMP)Hooked_setLanguage);
            
            Method m3 = class_getInstanceMethod(clsManager, NSSelectorFromString(@"setLanguageTo:"));
            if (m3) method_setImplementation(m3, (IMP)Hooked_setLanguage);
        }
        
        // استبدال التحقق القديم بالنظام الجديد
        Class actManager = objc_getMetaClass("GUFRANActivationManager");
        if (actManager) {
            Method mEnforce = class_getClassMethod(actManager, NSSelectorFromString(@"enforceActivation"));
            if (mEnforce) method_setImplementation(mEnforce, (IMP)Hooked_enforceActivation);
            
            Method mCheck = class_getClassMethod(actManager, NSSelectorFromString(@"checkStateAndPrompt"));
            if (mCheck) method_setImplementation(mCheck, (IMP)Hooked_enforceActivation);
        }
    });
}
