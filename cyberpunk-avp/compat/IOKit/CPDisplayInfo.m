#import "CPDisplayInfo.h"
CFDictionaryRef CPDisplayCreateInfoDictionary(io_service_t service, IOOptionBits options) {
 (void)options;
 // The virtual scene has no physical monitor service. Match the real Mac
 // zero-service dictionary instead of returning NULL to an unchecked caller.
 CFMutableDictionaryRef result=CFDictionaryCreateMutable(kCFAllocatorDefault,4,&kCFTypeDictionaryKeyCallBacks,&kCFTypeDictionaryValueCallBacks);
 if(!result)return NULL;
 CFDictionarySetValue(result,CFSTR("IODisplayLocation"),CFSTR("unknown"));
 if(service) {
  // Copy only real, correctly typed registry metadata when available. This
  // does not synthesize EDID, vendor/model identity or product names.
  CFMutableDictionaryRef properties=NULL;
  kern_return_t status=IORegistryEntryCreateCFProperties(service,&properties,kCFAllocatorDefault,0);
  if(status==KERN_SUCCESS && properties) {
   const CFStringRef keys[]={CFSTR("DisplayVendorID"),CFSTR("DisplayProductID"),CFSTR("DisplaySerialNumber"),CFSTR("IODisplayLocation")};
   for(unsigned i=0;i<4;i++) {
    CFTypeRef value=CFDictionaryGetValue(properties,keys[i]);
    if(value && CFGetTypeID(value)==(i==3?CFStringGetTypeID():CFNumberGetTypeID()))CFDictionarySetValue(result,keys[i],value);
   }
  }
  if(properties)CFRelease(properties);
 }
 return result;
}
IOReturn CPDisplayGetFloatParameter(io_service_t service, IOOptionBits options, CFStringRef parameter, float *value) {
 (void)service;(void)options;
 if(!parameter || !value)return kIOReturnBadArgument;
 // No physical display parameter backend exists here. Preserve the caller's
 // default float exactly, as the real zero-service Mac query does.
 return kIOReturnUnsupported;
}
