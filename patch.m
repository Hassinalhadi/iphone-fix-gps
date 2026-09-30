#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonDigest.h>

#define SECRET_KEY "MySecretTweakKey2026!#"

// --- 1. استخراج معرف الـ 8 خانات وفحص المفتاح ---

static NSString* GetCleanShortID(NSString *fullUDID) {
    if (!fullUDID || fullUDID.length == 0) return @"A1B2C3D4";
    NSString *clean = [[fullUDID stringByReplacingOccurrencesOfString:@"-" withString:@""] uppercaseString];
    if (clean.length >= 8) {
        return [clean substringToIndex:8];
    }
    return clean;
}

static BOOL VerifyLicense(NSString *licenseKey, NSString *shortID) {
    if (!licenseKey || !shortID) return NO;
    NSArray *parts = [licenseKey componentsSeparatedByString:@"-"];
    if (parts.count != 3) return NO;
    
    NSString *keyDevice = [parts[0] uppercaseString];
    NSString *expiryStr = parts;
    NSString *sig = parts;
    
    // 1. التحقق من تطابق معرف الجهاز المكون من 8 خانات
    if (![keyDevice isEqualToString:[shortID uppercaseString]]) return NO;
    
    // 2. التحقق من صحة التوقيع الرقمي
    NSString *payload = [NSString stringWithFormat:@"%@-%@", keyDevice, expiryStr];
    const char *keyBytes = SECRET_KEY;
    const char *dataBytes = [payload UTF8String];
    unsigned char hmac[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, keyBytes, strlen(keyBytes), dataBytes, strlen(dataBytes), hmac);
    
    NSMutableString *expectedSig = [NSMutableString stringWithCapacity:8];
    for (int i = 0; i < 4; i++) {
        [expectedSig appendFormat:@"%02X", hmac[i]];
    }
    if (![[sig uppercaseString] isEqualToString:expectedSig]) return NO;
    
    // 3. التحقق من تاريخ الصلاحية
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"yyyyMMdd"];
    [df setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    NSDate *expDate = [df dateFromString:expiryStr];
    return (expDate && [expDate compare:[NSDate date]] == NSOrderedDescending);
}

// --- 2. تعريب الواجهة وتعديل النصوص للإنجليزية وإظهار المعرف ---

static void TranslateViewToEnglish(UIView *view, NSString *shortID) {
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *lbl = (UILabel *)view;
        NSString *txt = lbl.text ?: @"";
        if ([txt containsString:@"التفعيل"] || [txt containsString:@"GUFRAN"]) {
            lbl.text = @"GPS Simulator - Activation";
        } else if ([txt containsString:@"يرجى إدخال"] || [txt containsString:@"كود التفعيل"]) {
            lbl.text = @"Please enter your activation code:";
        }
    } else if ([view isKindOfClass:[UIButton class]]) {
        UIButton *btn = (UIButton *)view;
        NSString *title = [btn titleForState:UIControlStateNormal] ?: @"";
        if ([title containsString:@"تحقق"] || [title containsString:@"تفعيل"]) {
            [btn setTitle:@"Verify & Activate" forState:UIControlStateNormal];
        } else if ([title containsString:@"نسخ"] || [title containsString:@"UDID"] || [title containsString:@"Copy"]) {
            // إظهار المعرف المكون من 8 خانات بوضوح داخل الزر
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

// --- 3. اعتراض شاشة التفعيل وزر النسخ ---

static void (*orig_CLSActivationVC_viewDidLoad)(id, SEL);
static void hook_CLSActivationVC_viewDidLoad(UIViewController *self, SEL _cmd) {
    orig_CLSActivationVC_viewDidLoad(self, _cmd);
    
    // استخراج أول 8 خانات من المعرف الموجود في الواجهة الأصلية
    NSString *raw = @"";
    @try {
        UILabel *udidLbl = [self valueForKey:@"_udidLabel"];
        raw = udidLbl.text ?: @"";
    } @catch (NSException *e) {}
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[A-Fa-f0-9]{8}" options:0 error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:raw options:0 range:NSMakeRange(0, raw.length)];
    NSString *shortID = match ? [raw substringWithRange:match.range] : GetCleanShortID(raw);
    
    // حفظ المعرف لاستخدامه أثناء النسخ والتحقق
    objc_setAssociatedObject(self, "kShortDeviceID", shortID, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // ترجمة عناصر الواجهة للإنجليزية وإظهار المعرف
    TranslateViewToEnglish(self.view, shortID);
}

static void hook_CLSActivationVC_copyUDID(id self, SEL _cmd) {
    NSString *shortID = objc_getAssociatedObject(self, "kShortDeviceID") ?: @"A1B2C3D4";
    [UIPasteboard generalPasteboard].string = shortID;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Copied"
                                                                   message:[NSString stringWithFormat:@"Device ID: %@ copied to clipboard!", shortID]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

// --- 4. اعتراض التحقق مع السيرفر وتفعيله محلياً ---

static void hook_verifyCodeWithServer(id self, SEL _cmd, NSString *code, NSString *udid, BOOL isBg, void(^completion)(BOOL, NSString*)) {
    NSString *shortID = GetCleanShortID(udid);
    
    if (VerifyLicense(code, shortID)) {
        // حفظ بيانات التفعيل في إعدادات التطبيق
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"gufran_is_activated"];
        [[NSUserDefaults standardUserDefaults] setObject:code forKey:@"gufran_saved_code"];
        [[NSUserDefaults standardUserDefaults] setObject:udid forKey:@"gufran_locked_udid"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        if (completion) {
            completion(YES, @"Activated successfully!");
        }
    } else {
        if (completion) {
            completion(NO, @"Invalid or expired activation code.");
        }
    }
}

// إجبار اللغة الإنجليزية في مدير الإعدادات
static NSString* hook_language(id self, SEL _cmd) {
    return @"en";
}

// دالة البدء التلقائي عند تشغيل التطبيق
__attribute__((constructor))
static void InitHook() {
    [[NSUserDefaults standardUserDefaults] setObject:@"en" forKey:@"cls_language"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // اعتراض واجهة التفعيل
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
    }
    
    // اعتراض دالة التحقق من السيرفر
    Class actMgr = objc_getMetaClass("GUFRANActivationManager");
    if (actMgr) {
        Method mVerify = class_getClassMethod(actMgr, NSSelectorFromString(@"verifyCodeWithServer:udid:isBackground:completion:"));
        if (mVerify) {
            method_setImplementation(mVerify, (IMP)hook_verifyCodeWithServer);
        }
    }
    
    // إجبار اللغة الإنجليزية في CLSManager
    Class clsMgr = NSClassFromString(@"CLSManager");
    if (clsMgr) {
        Method mLang = class_getInstanceMethod(clsMgr, NSSelectorFromString(@"language"));
        if (mLang) {
            method_setImplementation(mLang, (IMP)hook_language);
        }
    }
}
