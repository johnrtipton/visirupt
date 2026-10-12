#define _DARWIN_C_SOURCE 1
#include "FileTrace.h"
#include <dlfcn.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/stat.h>
#include <stdarg.h>
#include <errno.h>
#include <stdint.h>
#include <pthread.h>
#include <stdatomic.h>
#include <mach/mach.h>
#include <string.h>
static int (*nOpen)(const char *,int,...);
static FILE *(*nFopen)(const char *,const char *);
static int (*nStat)(const char *,struct stat *);
static int (*nAccess)(const char *,int);
static DIR *(*nOpendir)(const char *);
static int output=-1;
static _Atomic int phase;
static unsigned long long sequence;
static pthread_mutex_t lock=PTHREAD_MUTEX_INITIALIZER;
static _Thread_local int recording;
void CPFileTracePhase(int value){int e=errno;atomic_store(&phase,value);errno=e;}
static void Log(const char *api,const char *path,int flags,long long result,int failed,int error){
 if(output<0||recording)return;recording=1;
 // Copy bounded bytes from this process; invalid native caller pointers do not crash the logger.
 char hex[8193];size_t count=0;int terminated=0;
 if(path){for(;count<4096;count++){
  unsigned char c;vm_size_t copied=0;
  if(vm_read_overwrite(mach_task_self(),(vm_address_t)(uintptr_t)(path+count),1,(vm_address_t)(uintptr_t)&c,&copied)!=KERN_SUCCESS||copied!=1)break;
  if(!c){terminated=1;break;}static const char digits[]="0123456789abcdef";hex[2*count]=digits[c>>4];hex[2*count+1]=digits[c&15];
 }}
 hex[count*2]=0;
 char line[8704];pthread_mutex_lock(&lock);
 int size=snprintf(line,sizeof(line),"{\"event\":\"%s\",\"sequence\":%llu,\"phase\":%d,\"path_bytes_hex\":\"%s\",\"path_terminated\":%s,\"flags_or_mode\":%d,\"native_result\":%lld,\"failed\":%s,\"errno_after_native_call\":%d}\n",api,++sequence,atomic_load(&phase),hex,terminated?"true":"false",flags,result,failed?"true":"false",error);
 if(size>0&&(size_t)size<sizeof(line)){const char *p=line;size_t left=(size_t)size;while(left){ssize_t n=write(output,p,left);if(n<0&&errno==EINTR)continue;if(n<=0)break;p+=n;left-=(size_t)n;}}
 pthread_mutex_unlock(&lock);recording=0;
}
int CPFileTraceBegin(const char *path){int saved=errno;void *system=dlopen("/usr/lib/libSystem.B.dylib",RTLD_NOW|RTLD_LOCAL);if(!system)return 0;
 nOpen=(int (*)(const char *,int,...))dlsym(system,"open");nFopen=(FILE *(*)(const char *,const char *))dlsym(system,"fopen");nStat=(int (*)(const char *,struct stat *))dlsym(system,"stat");nAccess=(int (*)(const char *,int))dlsym(system,"access");nOpendir=(DIR *(*)(const char *))dlsym(system,"opendir");
 void *providers[]={(void *)nOpen,(void *)nFopen,(void *)nStat,(void *)nAccess,(void *)nOpendir};
 for(size_t i=0;i<5;i++){Dl_info info={0};if(!providers[i]||!dladdr(providers[i],&info)||!info.dli_fname||strncmp(info.dli_fname,"/usr/lib/",9))return 0;}
 output=nOpen(path,O_CREAT|O_TRUNC|O_WRONLY,0600);if(output<0)return 0;errno=saved;return 1;
}
static char logicalData[4096], stagedData[4096];
int CPFileTraceMapData(const char *source, const char *target) {
 if(!source||!target||source[0]!='/'||target[0]!='/')return 0;
 size_t a=strlen(source),b=strlen(target);if(a==0||b==0||a>=sizeof(logicalData)||b>=sizeof(stagedData))return 0;
 memcpy(logicalData,source,a+1);memcpy(stagedData,target,b+1);return 1;
}
static const char *Mapped(const char *path,char *buffer) {
 if(!logicalData[0]||!path)return path;
 char original[4096];size_t count;
 for(count=0;count<sizeof(original);count++) {
  vm_size_t copied=0;
  if(vm_read_overwrite(mach_task_self(),(vm_address_t)(uintptr_t)(path+count),1,(vm_address_t)(uintptr_t)&original[count],&copied)!=KERN_SUCCESS||copied!=1)return path;
  if(!original[count])break;
 }
 if(count==sizeof(original))return path;
 size_t prefix=strlen(logicalData);
 if(count<prefix||memcmp(original,logicalData,prefix)||(original[prefix]&&original[prefix]!='/'))return path;
 int n=snprintf(buffer,4096,"%s%s",stagedData,original+prefix);
 return n>0&&n<4096?buffer:path;
}
int CPObservedOpen(const char *,int,...) __asm__("_open");
int CPObservedOpen(const char *path,int flags,...){mode_t mode=0;if(flags&O_CREAT){va_list args;va_start(args,flags);mode=(mode_t)va_arg(args,int);va_end(args);}if(!nOpen){errno=ENOSYS;return -1;}char mapped[4096];const char *actual=Mapped(path,mapped);int r=(flags&O_CREAT)?nOpen(actual,flags,mode):nOpen(actual,flags);int e=errno;Log("open",path,flags,r,r<0,e);errno=e;return r;}
FILE *CPObservedFopen(const char *,const char *) __asm__("_fopen");
FILE *CPObservedFopen(const char *path,const char *mode){if(!nFopen){errno=ENOSYS;return NULL;}char mapped[4096];FILE *r=nFopen(Mapped(path,mapped),mode);int e=errno;Log("fopen",path,0,r?fileno(r):-1,r==NULL,e);errno=e;return r;}
int CPObservedStat(const char *,struct stat *) __asm__("_stat");
int CPObservedStat(const char *path,struct stat *buffer){if(!nStat){errno=ENOSYS;return -1;}char mapped[4096];int r=nStat(Mapped(path,mapped),buffer);int e=errno;Log("stat",path,0,r,r<0,e);errno=e;return r;}
int CPObservedAccess(const char *,int) __asm__("_access");
int CPObservedAccess(const char *path,int mode){if(!nAccess){errno=ENOSYS;return -1;}char mapped[4096];int r=nAccess(Mapped(path,mapped),mode);int e=errno;Log("access",path,mode,r,r<0,e);errno=e;return r;}
DIR *CPObservedOpendir(const char *) __asm__("_opendir");
DIR *CPObservedOpendir(const char *path){if(!nOpendir){errno=ENOSYS;return NULL;}char mapped[4096];DIR *r=nOpendir(Mapped(path,mapped));int e=errno;Log("opendir",path,0,r?dirfd(r):-1,r==NULL,e);errno=e;return r;}
