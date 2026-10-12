#include "FileTrace.h"
#include <dlfcn.h>
#include <stdio.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <dirent.h>
#include <stdint.h>
#include <string.h>
int CPObservedOpen(const char *,int,...) __asm__("_open");
FILE *CPObservedFopen(const char *,const char *) __asm__("_fopen");
int CPObservedStat(const char *,struct stat *) __asm__("_stat");
int CPObservedAccess(const char *,int) __asm__("_access");
DIR *CPObservedOpendir(const char *) __asm__("_opendir");
int CPFileTraceControls(const char *directory){
 void *sys=dlopen("/usr/lib/libSystem.B.dylib",RTLD_NOW|RTLD_LOCAL);
 int(*directOpen)(const char *,int,...)=(int(*)(const char *,int,...))dlsym(sys,"open");
 FILE *(*directFopen)(const char *,const char *)=(FILE *(*)(const char *,const char *))dlsym(sys,"fopen");
 int(*directStat)(const char *,struct stat *)=(int(*)(const char *,struct stat *))dlsym(sys,"stat");
 int(*directAccess)(const char *,int)=(int(*)(const char *,int))dlsym(sys,"access");
 DIR *(*directOpendir)(const char *)=(DIR *(*)(const char *))dlsym(sys,"opendir");
 int ok=1;char file[4096],missing[4096];
 int size=snprintf(file,sizeof(file),"%s/fixture-\"name",directory);if(size<0||(size_t)size>=sizeof(file))return 0;
 size=snprintf(missing,sizeof(missing),"%s/absent-file",directory);if(size<0||(size_t)size>=sizeof(missing))return 0;
 int fd=CPObservedOpen(file,O_CREAT|O_EXCL|O_WRONLY,0600);if(fd<0)return 0;
 ok=write(fd,"abc",3)==3;close(fd);struct stat s;ok=ok&&directStat(file,&s)==0&&(s.st_mode&0777)==0600;
 errno=EDOM;int a=directOpen(file,O_RDONLY),ae=errno;errno=EDOM;int b=CPObservedOpen(file,O_RDONLY),be=errno;
 char bytes[3];ok=ok&&a>=0&&b>=0&&ae==be&&read(b,bytes,3)==3&&!memcmp(bytes,"abc",3);if(a>=0)close(a);if(b>=0)close(b);
 errno=EDOM;FILE *faok=directFopen(file,"rb");ae=errno;errno=EDOM;FILE *fbok=CPObservedFopen(file,"rb");be=errno;ok=ok&&faok&&fbok&&ae==be;if(fbok){ok=ok&&fread(bytes,1,3,fbok)==3&&!memcmp(bytes,"abc",3);fclose(fbok);}if(faok)fclose(faok);
 struct stat directS, observedS;errno=EDOM;a=directStat(file,&directS);ae=errno;errno=EDOM;b=CPObservedStat(file,&observedS);be=errno;ok=ok&&a==0&&a==b&&ae==be&&directS.st_size==observedS.st_size&&directS.st_mode==observedS.st_mode;
 errno=EDOM;a=directAccess(file,R_OK);ae=errno;errno=EDOM;b=CPObservedAccess(file,R_OK);be=errno;ok=ok&&a==0&&a==b&&ae==be;
 errno=EDOM;DIR *daok=directOpendir(directory);ae=errno;errno=EDOM;DIR *dbok=CPObservedOpendir(directory);be=errno;ok=ok&&daok&&dbok&&ae==be;if(daok)closedir(daok);if(dbok)closedir(dbok);

 errno=EDOM;a=directOpen(missing,O_RDONLY);ae=errno;errno=EDOM;b=CPObservedOpen(missing,O_RDONLY);be=errno;ok=ok&&a==-1&&a==b&&ae==be;
 errno=EDOM;FILE *fa=directFopen(missing,"rb");ae=errno;errno=EDOM;FILE *fb=CPObservedFopen(missing,"rb");be=errno;ok=ok&&!fa&&!fb&&ae==be;
 errno=EDOM;a=directStat(missing,&s);ae=errno;errno=EDOM;b=CPObservedStat(missing,&s);be=errno;ok=ok&&a==-1&&a==b&&ae==be;
 errno=EDOM;a=directAccess(missing,F_OK);ae=errno;errno=EDOM;b=CPObservedAccess(missing,F_OK);be=errno;ok=ok&&a==-1&&a==b&&ae==be;
 errno=EDOM;DIR *da=directOpendir(missing);ae=errno;errno=EDOM;DIR *db=CPObservedOpendir(missing);be=errno;ok=ok&&!da&&!db&&ae==be;
 errno=EDOM;a=directOpen((const char *)(uintptr_t)1,O_RDONLY);ae=errno;errno=EDOM;b=CPObservedOpen((const char *)(uintptr_t)1,O_RDONLY);be=errno;ok=ok&&a==-1&&a==b&&ae==be;
 unlink(file);return ok;
}
