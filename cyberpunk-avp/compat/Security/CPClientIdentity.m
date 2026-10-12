#import "CPClientIdentity.h"
#import <Foundation/Foundation.h>

OSStatus CPImportPKCS12ToMemory(CFDataRef data, CFStringRef passphrase, CFArrayRef *items) {
    if (items) *items = NULL;
    if (!items || !data || CFGetTypeID(data) != CFDataGetTypeID() ||
        (passphrase && CFGetTypeID(passphrase) != CFStringGetTypeID())) return errSecParam;
    NSMutableDictionary *options = [@{(__bridge id)kSecImportToMemoryOnly:@YES} mutableCopy];
    if (passphrase) options[(__bridge id)kSecImportExportPassphrase] = (__bridge id)passphrase;
    CFArrayRef result = NULL;
    OSStatus status = SecPKCS12Import(data, (__bridge CFDictionaryRef)options, &result);
    if (status != errSecSuccess) {
        if (result) CFRelease(result);
        return status;
    }
    // Preserve real native success, including certificate-only containers.
    // The engine's existing identity requirement decides whether TLS setup can proceed.
    *items = result;
    return status;
}

OSStatus CPIdentityCopyMatchingCertificate(CFArrayRef items, SecCertificateRef certificate,
                                         SecIdentityRef *identity) {
    if (identity) *identity = NULL;
    if (!identity || !items || CFGetTypeID(items) != CFArrayGetTypeID() ||
        !certificate || CFGetTypeID(certificate) != SecCertificateGetTypeID()) return errSecParam;
    CFDataRef wanted = SecCertificateCopyData(certificate);
    if (!wanted) return errSecDecode;
    OSStatus status = errSecItemNotFound;
    for (CFIndex i = 0; i < CFArrayGetCount(items); i++) {
        CFTypeRef item = CFArrayGetValueAtIndex(items, i);
        CFTypeRef candidate = item;
        if (CFGetTypeID(item) == CFDictionaryGetTypeID()) candidate = CFDictionaryGetValue(item, kSecImportItemIdentity);
        if (!candidate || CFGetTypeID(candidate) != SecIdentityGetTypeID()) continue;
        SecCertificateRef found = NULL;
        SecKeyRef privateKey = NULL;
        if (SecIdentityCopyCertificate((SecIdentityRef)candidate, &found) == errSecSuccess && found) {
            CFDataRef der = SecCertificateCopyData(found);
            if (der && CFEqual(wanted, der) &&
                SecIdentityCopyPrivateKey((SecIdentityRef)candidate, &privateKey) == errSecSuccess && privateKey) {
                *identity = (SecIdentityRef)CFRetain(candidate);
                status = errSecSuccess;
            }
            if (der) CFRelease(der);
            CFRelease(found);
        }
        if (privateKey) CFRelease(privateKey);
        if (*identity) break;
    }
    CFRelease(wanted);
    return status;
}
