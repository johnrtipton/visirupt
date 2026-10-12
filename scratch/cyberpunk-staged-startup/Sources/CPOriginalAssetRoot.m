#import "CPOriginalAssetRoot.h"
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#include <string.h>
#include <stdint.h>

static BOOL Read(uintptr_t address,void *out,size_t length) {
 vm_size_t copied=0;
 return vm_read_overwrite(mach_task_self(),address,length,(vm_address_t)out,&copied)==KERN_SUCCESS&&copied==length;
}
NSDictionary *CPReadOriginalAssetRoot(NSString *modulePath) {
 NSMutableDictionary *r=[@{@"state":@"ASSET_ROOT_VALIDATING",@"original_entrypoint_called":@NO,@"actual_asset_file_opens_verified":@NO} mutableCopy];
 const struct mach_header_64 *header=NULL;intptr_t slide=0;
 for(uint32_t i=0;i<_dyld_image_count();i++)if(strcmp(_dyld_get_image_name(i),modulePath.fileSystemRepresentation)==0){header=(const struct mach_header_64 *)_dyld_get_image_header(i);slide=_dyld_get_image_vmaddr_slide(i);break;}
 BOOL inside=NO;
 if(header&&header->magic==MH_MAGIC_64&&header->filetype==MH_DYLIB){const uint8_t *p=(const uint8_t *)(header+1),*end=p+header->sizeofcmds;
  for(uint32_t i=0;i<header->ncmds;i++){
   if((size_t)(end-p)<sizeof(struct load_command))break;
   const struct load_command *c=(const struct load_command *)p;if(c->cmdsize<sizeof(*c)||c->cmdsize>(size_t)(end-p))break;
   if(c->cmd==LC_SEGMENT_64&&c->cmdsize>=sizeof(struct segment_command_64)){
    const struct segment_command_64 *s=(const struct segment_command_64 *)p;
    if(s->nsects>(c->cmdsize-sizeof(*s))/sizeof(struct section_64))break;
    const struct section_64 *sections=(const struct section_64 *)(s+1);
    for(uint32_t j=0;j<s->nsects;j++)if(!strncmp(sections[j].segname,"__TEXT",16)&&!strncmp(sections[j].sectname,"__text",16)&&sections[j].addr<=0x102d9fed8&&0x102d9fed8-sections[j].addr+12<=sections[j].size)inside=YES;
   }p+=c->cmdsize;
  }
 }
 uint32_t words[3];uintptr_t address=0x102d9fed8+slide;
 BOOL verified=inside&&Read(address,words,sizeof(words))&&words[0]==0xa9bd57f6&&words[1]==0xa9014ff4&&words[2]==0xa9027bfd;
 r[@"resolver_bounds_and_instructions_verified"]=@(verified);
 if(!verified){r[@"state"]=@"ASSET_ROOT_VALIDATION_FAILED";return r;}
 void *p=((void *(*)(void))address)();
 if((uintptr_t)p!=(uintptr_t)(0x1084ef760+slide)){r[@"state"]=@"ASSET_ROOT_UNEXPECTED_OBJECT";return r;}
 unsigned char object[24];if(!Read((uintptr_t)p,object,sizeof(object))){r[@"state"]=@"ASSET_ROOT_OBJECT_UNREADABLE";return r;}
 uint32_t flags;memcpy(&flags,object+20,4);size_t length=flags&0x3fffffff;uintptr_t bytes=(uintptr_t)p;if(flags>>30)memcpy(&bytes,object,8);
 if(length==0||length>=4096){r[@"state"]=@"ASSET_ROOT_LENGTH_INVALID";return r;}
 char buffer[4096];if(!Read(bytes,buffer,length)){r[@"state"]=@"ASSET_ROOT_BYTES_UNREADABLE";return r;}
 NSString *path=[[NSString alloc]initWithBytes:buffer length:length encoding:NSUTF8StringEncoding];
 if(!path){r[@"state"]=@"ASSET_ROOT_ENCODING_INVALID";return r;}
 r[@"original_resolver_path"]=path;r[@"path_length"]=@(length);r[@"state"]=@"ORIGINAL_ASSET_ROOT_READ";
 r[@"host_executable_path"]=NSBundle.mainBundle.executablePath?:@"";
 return r;
}
