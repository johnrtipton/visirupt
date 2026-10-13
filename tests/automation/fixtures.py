"""Authored Mach-O fixtures, with literal expected semantics in tests."""
import struct

def macho(commands=(), payload=b'', kind=6):
    commands=b''.join(commands)
    return struct.pack('<8I',0xfeedfacf,0x100000c,0,kind,sum(1 for _ in walk(commands)),len(commands),0,0)+commands+payload

def walk(commands):
    cursor=0
    while cursor<len(commands):
        size=struct.unpack_from('<I',commands,cursor+4)[0]
        yield cursor
        cursor+=size

def dylib(path,cmd=12):
    text=path.encode()+b'\0';size=(24+len(text)+7)&~7
    return struct.pack('<6I',cmd,size,24,0,0x10000,0x10000)+text+b'\0'*(size-24-len(text))

def chained(symbol='_test', ordinal=2, addend=-7, fmt=2):
    libs=[dylib('/one'),dylib('/two')]
    stride={1:4,2:8,3:16}[fmt]
    imports=32;strings=imports+stride
    pool=symbol.encode()+b'\0'
    if fmt==3: row=struct.pack('<Qq',(ordinal&0xffff)|(1<<16),addend)
    else:
        row=struct.pack('<I',(ordinal&255)|(1<<8))
        if fmt==2:row+=struct.pack('<i',addend)
    payload=struct.pack('<7I',0,28,imports,strings,1,fmt,0)+struct.pack('<I',0)+row+pool
    base=32+sum(map(len,libs))+16
    command=struct.pack('<4I',0x80000034,16,base,len(payload))
    return macho([*libs,command],payload)

def legacy(stream):
    libs=[dylib('/one'),dylib('/two')]
    segment=struct.pack('<II16sQQQQIIII',25,72,b'__DATA',0x1000,4096,0,0,3,3,0,0)
    base=32+sum(map(len,libs))+72+48
    command=struct.pack('<12I',0x80000022,48,0,0,base,len(stream),0,0,0,0,0,0)
    return macho([*libs,segment,command],stream)

def provider_image(name):
    if name=='Bink':
        libs=['/System/Library/Frameworks/AudioUnit.framework/Versions/A/AudioUnit','/System/Library/Frameworks/CoreAudio.framework/Versions/A/CoreAudio','/System/Library/Frameworks/AudioToolbox.framework/Versions/A/AudioToolbox','/System/Library/Frameworks/Carbon.framework/Versions/A/Carbon','/usr/lib/libSystem.B.dylib']
        symbols=[('_audio',2),('_system',5)]
    elif name=='AppStoreServices':
        libs=['/System/Library/Frameworks/AppKit.framework/Versions/C/AppKit','/System/Library/Frameworks/GameKit.framework/Versions/A/GameKit','/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation','/usr/lib/libobjc.A.dylib','/usr/lib/libc++.1.dylib','/usr/lib/libSystem.B.dylib','/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation']
        symbols=[('_NSApp',1),('_NSApplicationDidBecomeActiveNotification',1),('_NSApplicationWillResignActiveNotification',1),('_syslog$DARWIN_EXTSN',6),('_OBJC_CLASS_$_GKDialogController',2)]
    else:
        libs=['/System/Library/Frameworks/Cocoa.framework/Versions/A/Cocoa','/System/Library/Frameworks/Security.framework/Versions/A/Security','/System/Library/Frameworks/SystemConfiguration.framework/Versions/A/SystemConfiguration','/usr/lib/libSystem.B.dylib','/usr/lib/libc++.1.dylib','/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation']
        symbols=[('_SecItemImport',2),('_SecItemExport',2),('_SecIdentityCreateWithCertificate',2),('_SecCertificateCopyLongDescription',2)]
    section=struct.pack('<16s16sQQIIIIIIII',b'__text',b'__TEXT',0x1400,16,1024,2,0,0,0x80000400,0,0,0)
    text=struct.pack('<II16sQQQQIIII',25,152,b'__TEXT',0x1000,1040,0,1040,5,5,1,0)+section
    symoff=1040;pool=b'\0';rows=[]
    for symbol,ordinal in symbols:
        rows.append(struct.pack('<IBBHQ',len(pool),1,0,ordinal<<8,0));pool+=symbol.encode()+b'\0'
    legacy_stream=b'\x12\x40_audio\0\x51\x70\x80\x08\x90\x15\x40_system\0\x70\x88\x08\x90\0' if name=='Bink' else b''
    stroff=symoff+16*len(rows)+len(legacy_stream)+1
    payload=b'CODE'*4+b''.join(rows)+legacy_stream+b'\0'+pool
    end=1024+len(payload)
    fixup_command=None
    if name!='Bink':
        imports=32;strings=imports+4*len(rows)
        chain_rows=b''.join(struct.pack('<I', ordinal|(struct.unpack_from('<I', row)[0]<<9)) for row,(_,ordinal) in zip(rows,symbols))
        fixup_payload=struct.pack('<7I',0,28,imports,strings,len(rows),1,0)+struct.pack('<I',0)+chain_rows+pool
        fixup_command=struct.pack('<4I',0x80000034,16,end,len(fixup_payload))
        payload+=fixup_payload;end+=len(fixup_payload)
    link=struct.pack('<II16sQQQQIIII',25,72,b'__LINKEDIT',0x2000,4096,1040,end-1040,1,1,0,0)
    symtab=struct.pack('<6I',2,24,symoff,len(rows),stroff,len(pool))
    platform=struct.pack('<6I',0x32,24,1,0xF0000,0xF0000,0)
    commands=[text,link,*map(dylib,libs),dylib('@rpath/original',13),symtab,platform]
    if fixup_command:commands.append(fixup_command)
    if legacy_stream:commands.append(struct.pack('<12I',0x80000022,48,0,0,symoff+16*len(rows),len(legacy_stream),0,0,0,0,0,0))
    header=macho(commands)
    return header+b'\0'*(1024-len(header))+payload

def game_image():
    names=['/usr/lib/libbz2.1.0.dylib','/usr/lib/libcurl.4.dylib','/System/Library/Frameworks/MetricKit.framework/Versions/A/MetricKit','/System/Library/Frameworks/Cocoa.framework/Versions/A/Cocoa','/System/Library/Frameworks/MetalFX.framework/Versions/A/MetalFX','@executable_path/../Frameworks/libBink2MacArm64.dylib','@executable_path/../Frameworks/libGameServicesAppStore.dylib','/System/Library/Frameworks/GameKit.framework/Versions/A/GameKit','@rpath/libREDGalaxy64.dylib','/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation','/System/Library/Frameworks/QuartzCore.framework/Versions/A/QuartzCore','/System/Library/Frameworks/IOKit.framework/Versions/A/IOKit','/System/Library/Frameworks/Metal.framework/Versions/A/Metal','/System/Library/Frameworks/AudioToolbox.framework/Versions/A/AudioToolbox','/System/Library/Frameworks/CoreAudio.framework/Versions/A/CoreAudio','/System/Library/Frameworks/GameController.framework/Versions/A/GameController','/System/Library/Frameworks/CoreHaptics.framework/Versions/A/CoreHaptics','/System/Library/Frameworks/AVFAudio.framework/Versions/A/AVFAudio','/usr/lib/libobjc.A.dylib','/usr/lib/libc++.1.dylib','/usr/lib/libSystem.B.dylib','/System/Library/Frameworks/AppKit.framework/Versions/C/AppKit','/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation','/System/Library/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics']
    pagezero=struct.pack('<II16sQQQQIIII',25,72,b'__PAGEZERO',0,0x100000000,0,0,0,0,0,0)
    sections=b''.join(struct.pack('<16s16sQQIIIIIIII',name,b'__TEXT',address,size,offset,2,0,0,flags,0,0,0) for name,address,size,offset,flags in ((b'__text',0x100012350,80,4096,0x80000400),(b'__init_offsets',0x1000123a0,8,4176,0)))
    text=struct.pack('<II16sQQQQIIII',25,232,b'__TEXT',0x100000000,0x13000,0,4184,5,5,2,0)+sections
    symbols=[('_call',5),('_mmap',21),('_desktop',22)]
    pool=b'\0';rows=[];imports=[]
    for symbol,ordinal in symbols:
        rows.append(struct.pack('<IBBHQ',len(pool),1,0,ordinal<<8,0));imports.append(struct.pack('<I',ordinal|(len(pool)<<9)));pool+=symbol.encode()+b'\0'
    symoff=4184;stroff=symoff+len(rows)*16
    fixoffset=stroff+len(pool);fix=struct.pack('<7I',0,28,32,44,3,1,0)+struct.pack('<I',0)+b''.join(imports)+pool
    payload=bytearray(b'X'*80+struct.pack('<II',0x12350,0x1239c)+b''.join(rows)+pool+fix)
    struct.pack_into('<I',payload,8,0xd2c00209);struct.pack_into('<I',payload,76,0xd2c00109)
    end=4096+len(payload)
    link=struct.pack('<II16sQQQQIIII',25,72,b'__LINKEDIT',0x100013000,16384,4184,end-4184,1,1,0,0)
    commands=[pagezero,text,link,*map(dylib,names),struct.pack('<6I',2,24,symoff,len(rows),stroff,len(pool)),struct.pack('<4I',0x80000034,16,fixoffset,len(fix)),struct.pack('<6I',0x32,24,1,0xf0500,0xf0000,0),struct.pack('<IIQQ',0x80000028,24,4096,0)]
    header=macho(commands,kind=2)
    header=bytearray(header);struct.pack_into('<I',header,24,0x200000)
    return bytes(header)+b'\0'*(4096-len(header))+bytes(payload)
