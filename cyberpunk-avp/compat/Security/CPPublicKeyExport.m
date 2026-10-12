#import "CPPublicKeyExport.h"
#import <Foundation/Foundation.h>
#import <limits.h>

static CFDataRef fail(CFErrorRef *error, OSStatus code) {
    if (error) *error = CFErrorCreate(kCFAllocatorDefault, kCFErrorDomainOSStatus, code, NULL);
    return NULL;
}
static NSData *tlv(uint8_t tag, NSData *content) {
    NSMutableData *result = [NSMutableData data];
    [result appendBytes:&tag length:1];
    NSUInteger length = content.length;
    if (length < 128) { uint8_t byte=(uint8_t)length; [result appendBytes:&byte length:1]; }
    else {
        uint8_t bytes[sizeof(NSUInteger)]; unsigned count=0;
        for (NSUInteger remaining=length; remaining; remaining >>= 8) bytes[count++]=(uint8_t)remaining;
        uint8_t byte=(uint8_t)(0x80|count); [result appendBytes:&byte length:1];
        while (count) { byte=bytes[--count]; [result appendBytes:&byte length:1]; }
    }
    [result appendData:content];
    return result;
}
CFDataRef CPKeyCopyDesktopOpenSSLRepresentation(SecKeyRef key, CFErrorRef *error) {
    if (error) *error=NULL;
    if (!key || CFGetTypeID(key)!=SecKeyGetTypeID()) return fail(error,errSecParam);
    CFDictionaryRef copied = SecKeyCopyAttributes(key);
    if (!copied) return fail(error,errSecParam);
    NSDictionary *attributes = CFBridgingRelease(copied);
    if (![attributes[(__bridge id)kSecAttrKeyClass] isEqual:(__bridge id)kSecAttrKeyClassPublic])
        return fail(error,errSecParam);
    static const uint8_t rsa[] = {0x30,0x0d,0x06,0x09,0x2a,0x86,0x48,0x86,0xf7,0x0d,0x01,0x01,0x01,0x05,0x00};
    static const uint8_t p256[] = {0x30,0x13,0x06,0x07,0x2a,0x86,0x48,0xce,0x3d,0x02,0x01,0x06,0x08,0x2a,0x86,0x48,0xce,0x3d,0x03,0x01,0x07};
    static const uint8_t p384[] = {0x30,0x10,0x06,0x07,0x2a,0x86,0x48,0xce,0x3d,0x02,0x01,0x06,0x05,0x2b,0x81,0x04,0x00,0x22};
    static const uint8_t p521[] = {0x30,0x10,0x06,0x07,0x2a,0x86,0x48,0xce,0x3d,0x02,0x01,0x06,0x05,0x2b,0x81,0x04,0x00,0x23};
    id type=attributes[(__bridge id)kSecAttrKeyType]; NSData *algorithm; NSUInteger expectedECBytes=0;
    if ([type isEqual:(__bridge id)kSecAttrKeyTypeRSA]) algorithm=[NSData dataWithBytes:rsa length:sizeof(rsa)];
    else if ([type isEqual:(__bridge id)kSecAttrKeyTypeECSECPrimeRandom]) {
        NSUInteger bits=[attributes[(__bridge id)kSecAttrKeySizeInBits] unsignedIntegerValue];
        if (bits==256) {algorithm=[NSData dataWithBytes:p256 length:sizeof(p256)];expectedECBytes=65;}
        else if (bits==384) {algorithm=[NSData dataWithBytes:p384 length:sizeof(p384)];expectedECBytes=97;}
        else if (bits==521) {algorithm=[NSData dataWithBytes:p521 length:sizeof(p521)];expectedECBytes=133;}
        else return fail(error,errSecUnimplemented);
    } else return fail(error,errSecUnimplemented);
    CFDataRef external=SecKeyCopyExternalRepresentation(key,error);
    if (!external) return NULL;
    NSData *raw=CFBridgingRelease(external);
    if (!raw.length || (expectedECBytes && (raw.length!=expectedECBytes || ((const uint8_t *)raw.bytes)[0]!=4)))
        return fail(error,errSecDecode);
    uint8_t unusedBits=0;
    NSMutableData *bits=[NSMutableData dataWithBytes:&unusedBits length:1]; [bits appendData:raw];
    NSMutableData *body=[NSMutableData dataWithData:algorithm]; [body appendData:tlv(3,bits)];
    return (CFDataRef)CFBridgingRetain(tlv(0x30,body));
}
