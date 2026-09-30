#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonDigest.h>

#define SECRET_KEY "MySecretTweakKey2026!#"

// --- 1. فحص التوقيع الرقمي للمفتاح ---

static BOOL VerifyLicense(NSString *licenseKey, NSString *expectedID) {
    if (!licenseKey || licenseKey.length < 15) return NO;
    NSArray *parts = [licenseKey componentsSeparatedByString:@"-"];
    if (parts.count != 3) return NO;
    
    NSString *keyDevice = [[parts objectAtIndex:0] uppercaseString];
    NSString *expiryStr = [parts objectAtIndex:1];
    NSString *sig = [[parts objectAtIndex:2] uppercaseString];
    
    // فحص تطابق معرف الجهاز
    if (![keyDevice isEqualToString:[expectedID uppercaseString]]) return NO;
    
    // التحقق من توقيع HMAC-SHA256
    NSString *payload = [NSString stringWithFormat:@"%@-%@", keyDevice, expiryStr];
    const char *keyBytes = SECRET_KEY;
    const char *dataBytes = [payload UTF8String];
    unsigned char hmac[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, keyBytes, strlen(keyBytes), dataBytes, strlen(dataBytes), hmac);
    
    NSMutableString *expectedSig = [NSMutableString stringWithCapacity:8];
    for (int i = 0; i < 4; i++) {
        [expectedSig appendFormat:@"%02X", hmac[i]];
    }
    if (![sig isEqualToString:expectedSig]) return NO;
    
    // فحص تاريخ الصلاحية
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"yyyyMMdd"];
    [df setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    NSDate *expDate = [df dateFromString:expiryStr];
    return (expDate && [expDate compare:[NSDate date]] == NSOrderedDescending);
}

// --- 2. تعريب وتعديل عناصر الواجهة للإنجليزية ---

static void TranslateViewToEnglish(UIView *view, NSString *shortID) {
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *lbl = (UILabel *)view;
        NSString *txt = lbl.text ?: @"";
        if ([txt containsString:@"التفعيل"] || [txt containsString:@"GUFRAN"]) {
            lbl.text = @"GPS Simulator - Activation";
        } else if ([txt containsString:@"يرجى إدخال"] || [txt containsString:@"كود التفعيل"]) {
            lbl.text = @"Enter your activation key:";
        }
    } else if ([view isKindOfClass:[UIButton class]]) {
        UIButton *btn = (UIButton *)view;
        NSString *title = [btn titleForState:UIControlStateNormal] ?: @"";
        if ([title containsString:@"تحقق"] || [title containsString:@"تفعيل"]) {
            [btn setTitle:@"Verify & Activate" forState:UIControlStateNormal];
        } else if ([title containsString:@"نسخ"] || [title containsString:@"UDID"] || [title containsString:@"Copy"]) {
            [btn setTitle:[NSString stringWithFormat:@"Device ID: %@ (Copy)", shortID] forState:UIControlStateNormal];
        }
    } else if ([view isKindOfClass:[UITextField class]]) {
        UITextField *tf = (UITextField *)view;
        tf.placeholder = @"XXXX-XXXXXXXX-XXXX";
    }
    
    for (UIView *sub in view.subviews) {
        TranslateViewToEnglish(sub, shortID);
    }
}

// --- 3. اعتراض شاشة التفعيل وزر التفعيل والنسخ ---

static void (*orig_CLSActivationVC_viewDidLoad)(id, SEL);
static void hook_CLSActivationVC_viewDidLoad(UIViewController *self, SEL _cmd) {
    orig_CLSActivationVC_viewDidLoad(self, _cmd);
    
    NSString *shortID = @"A1B2C3D4";
    objc_setAssociatedObject(self, "kShortDeviceID", shortID, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    TranslateViewToEnglish(self.view, shortID);
}

static void hook_CLSActivationVC_copyUDID(id self, SEL _cmd) {
    NSString *shortID = @"A1B2C3D4";
    [UIPasteboard generalPasteboard].string = shortID;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Copied"
                                                                   message:[NSString stringWithFormat:@"Device ID: %@ copied to clipboard!", shortID]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

// اعتراض زر الضغط "Verify & Activate" مباشرة بدون الرجوع للسيرفر
static void hook_CLSActivationVC_activateTapped(UIViewController *self, SEL _cmd) {
    [self.view endEditing:YES];
    
    UITextField *field = nil;
    for (UIView *v in self.view.subviews) {
        if ([v isKindOfClass:[UITextField class]]) {
            field = (UITextField *)v;
            break;
        }
        for (UIView *sub in v.subviews) {
            if ([sub isKindOfClass:[UITextField class]]) {
                field = (UITextField *)sub;
                break;
            }
        }
    }
    
    NSString *inputKey = [field.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    // فحص المفتاح الجديد أوفلاين
    if (VerifyLicense(inputKey, @"A1B2C3D4") || VerifyLicense(inputKey, @"DC249A18")) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"gufran_is_activated"];
        [[NSUserDefaults standardUserDefaults] setObject:inputKey forKey:@"gufran_saved_code"];
        [[NSUserDefaults standardUserDefaults] setObject:[NSDate dateWithTimeIntervalSinceNow:315360000] forKey:@"gufran_expires_at"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        UIViewController *currentVC = self;
        UIAlertController *success = [UIAlertController alertControllerWithTitle:@"Success"
                                                                         message:@"Activated successfully!"
                                                                  preferredStyle:UIAlertControllerStyleAlert];
        [success addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [currentVC dismissViewControllerAnimated:YES completion:nil];
        }]];
        [self presentViewController:success animated:YES completion:nil];
    } else {
        UIAlertController *fail = [UIAlertController alertControllerWithTitle:@"Invalid Key"
                                                                      message:@"The license key is invalid or expired."
                                                               preferredStyle:UIAlertControllerStyleAlert];
        [fail addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:fail animated:YES completion:nil];
    }
}

static NSString* hook_language(id self, SEL _cmd) {
    return @"en";
}

static void hook_enforceActivation(id self, SEL _cmd) {
    BOOL isAct = [[NSUserDefaults standardUserDefaults] boolForKey:@"gufran_is_activated"];
    if (isAct) {
        return;
    }
}

// --- دالة التهيئة والربط الفوري ---
__attribute__((constructor))
static void InitHook() {
    [[NSUserDefaults standardUserDefaults] setObject:@"en" forKey:@"cls_language"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    Class actVC = NSClassFromString(@"CLSActivationViewController");
    if (actVC) {
        Method m1 = class_getInstanceMethod(actVC, @selector(viewDidLoad));
        if (m1) {
            orig_CLSActivationVC_viewDidLoad = (void(*)(id, SEL))method_getImplementation(m1);
            method_setImplementation(m1, (IMP)hook_CLSActivationVC_viewDidLoad);
        }
        
        Method mCopy = class_getInstanceMethod(actVC, NSSelectorFromString(@"copyUDID"));
        if (mCopy) {
            method_setImplementation(mCopy, (IMP)hook_CLSActivationVC_copyUDID);
        }
        
        Method mAct = class_getInstanceMethod(actVC, NSSelectorFromString(@"activateTapped"));
        if (mAct) {
            method_setImplementation(mAct, (IMP)hook_CLSActivationVC_activateTapped);
        }
    }
    
    Class actMgr = objc_getClass("GUFRANActivationManager");
    if (actMgr) {
        Method mEnforce = class_getClassMethod(actMgr, NSSelectorFromString(@"enforceActivation"));
        if (mEnforce) {
            method_setImplementation(mEnforce, (IMP)hook_enforceActivation);
        }
    }
    
    Class clsMgr = NSClassFromString(@"CLSManager");
    if (clsMgr) {
        Method mLang = class_getInstanceMethod(clsMgr, NSSelectorFromString(@"language"));
        if (mLang) {
            method_setImplementation(mLang, (IMP)hook_language);
        }
    }
}
