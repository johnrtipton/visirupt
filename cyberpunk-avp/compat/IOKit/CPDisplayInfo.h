#import <CoreFoundation/CoreFoundation.h>
#import <IOKit/IOKitLib.h>
CFDictionaryRef CPDisplayCreateInfoDictionary(io_service_t service, IOOptionBits options) CF_RETURNS_RETAINED;
IOReturn CPDisplayGetFloatParameter(io_service_t service, IOOptionBits options, CFStringRef parameter, float *value);
