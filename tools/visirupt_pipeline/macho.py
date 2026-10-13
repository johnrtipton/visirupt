"""Bounded ARM64 Mach-O metadata decoding; never loads an inspected image."""
import hashlib
import struct
from .core import PipelineError

LOADS = (12,0x80000018,0x8000001f,0x20,0x80000023)
MAX_RECORDS = 2_000_000

def checked_slice(data: bytes, offset: int, length: int) -> bytes:
    if offset < 0 or length < 0 or offset > len(data) or length > len(data)-offset:
        raise PipelineError('INVALID_BINARY','out-of-file range')
    return data[offset:offset+length]

def unpack(fmt, data, offset=0):
    return struct.unpack(fmt,checked_slice(data,offset,struct.calcsize(fmt)))

def cstring(data: bytes, offset: int) -> str:
    if not 0 <= offset < len(data): raise PipelineError('INVALID_BINARY','string offset')
    end=data.find(b'\0',offset)
    if end < 0: raise PipelineError('INVALID_BINARY','unterminated string')
    try: return data[offset:end].decode('utf-8')
    except UnicodeError: raise PipelineError('INVALID_BINARY','invalid string') from None

def name(data):
    try:return data.split(b'\0')[0].decode('ascii')
    except UnicodeError:raise PipelineError('INVALID_BINARY','segment name') from None

def parse_macho(data: bytes) -> dict:
    magic,cpu,sub,kind,count,size,flags,reserved=unpack('<8I',data)
    if magic!=0xfeedfacf or cpu!=0x100000c or kind not in (2,6) or count>65536:
        raise PipelineError('INVALID_BINARY','unsupported header')
    checked_slice(data,32,size)
    image={'kind':kind,'flags':flags,'subtype':sub,'commands':[],'segments':[],
           'sections':[],'dependencies':[],'header_end':32+size,'symtab':None,'fixups':None,
           'dyld_info':None,'exports':None,'signature':None,'platform':None,'identity':None}
    cursor=32
    for _ in range(count):
        cmd,length=unpack('<II',data,cursor)
        if length<8 or length%8 or cursor+length>32+size:raise PipelineError('INVALID_BINARY','load command length')
        block=checked_slice(data,cursor,length)
        command={'cmd':cmd,'offset':cursor,'size':length,'raw':block}
        image['commands'].append(command)
        if cmd==25:
            vm,vmsize,fileoff,filesize,maxprot,initprot,nsects,sflags=unpack('<QQQQIIII',block,24)
            if nsects>(length-72)//80 or length<72 or vm+vmsize>1<<64:raise PipelineError('INVALID_BINARY','segment bounds')
            checked_slice(data,fileoff,filesize)
            seg={'name':name(block[8:24]),'vm':vm,'vmsize':vmsize,'fileoff':fileoff,'filesize':filesize,'index':len(image['segments'])}
            image['segments'].append(seg)
            for i in range(nsects):
                entry=checked_slice(block,72+80*i,80)
                address,nbytes,offset,align,reloff,nreloc,sflags=unpack('<QQIIIII',entry,32)
                if address<vm or address-vm>vmsize or nbytes>vmsize-(address-vm):raise PipelineError('INVALID_BINARY','section vm bounds')
                if nreloc:checked_slice(data,reloff,nreloc*8)
                # S_ZEROFILL / GB_ZEROFILL / THREAD_LOCAL_ZEROFILL have no file payload.
                if nbytes and offset and (sflags&255) not in (1,12,18):
                    checked_slice(data,offset,nbytes)
                    if offset<fileoff or nbytes>filesize-(offset-fileoff):raise PipelineError('INVALID_BINARY','section file bounds')
                    image['sections'].append({'segment':name(entry[16:32]),'name':name(entry[:16]),
                        'address':address,'offset':offset,'size':nbytes,'flags':sflags})
        elif cmd in (*LOADS,13):
            no,timestamp,current,compat=unpack('<4I',block,8)
            if no<24:raise PipelineError('INVALID_BINARY','library string offset')
            dep={'path':cstring(block,no),'current':current,'compatibility':compat,'command':cmd,'command_index':len(image['commands'])-1}
            if cmd==13:image['identity']=dep
            else:image['dependencies'].append(dep)
        elif cmd==2:
            if image['symtab'] is not None:raise PipelineError('INVALID_BINARY','duplicate symtab')
            symoff,nsymbols,stroff,strsize=unpack('<4I',block,8)
            if nsymbols>MAX_RECORDS:raise PipelineError('INVALID_BINARY','symbol count')
            checked_slice(data,symoff,nsymbols*16);checked_slice(data,stroff,strsize)
            image['symtab']=(symoff,nsymbols,stroff,strsize)
        elif cmd in (0x80000034,0x80000033,0x1d):
            key={0x80000034:'fixups',0x80000033:'exports',0x1d:'signature'}[cmd]
            if image[key] is not None:raise PipelineError('INVALID_BINARY','duplicate table')
            offset,nbytes=unpack('<II',block,8);checked_slice(data,offset,nbytes);image[key]=(offset,nbytes)
        elif cmd in (0x22,0x80000022):
            if image['dyld_info'] is not None:raise PipelineError('INVALID_BINARY','duplicate dyld info')
            values=unpack('<10I',block,8)
            for i in range(0,10,2):checked_slice(data,values[i],values[i+1])
            image['dyld_info']=values
            if values[9]:image['exports']=(values[8],values[9])
        elif cmd==0x32:
            if image['platform'] is not None:raise PipelineError('INVALID_BINARY','duplicate platform')
            platform,minimum,sdk,ntools=unpack('<4I',block,8)
            checked_slice(block,24,ntools*8);image['platform']=(platform,minimum,sdk)
        cursor+=length
    if cursor!=32+size:raise PipelineError('INVALID_BINARY','load command count')
    intervals=sorted((s['offset'],s['offset']+s['size']) for s in image['sections'])
    for before,after in zip(intervals,intervals[1:]):
        if before[1]>after[0]:raise PipelineError('INVALID_BINARY','overlapping sections')
    if intervals and intervals[0][0]<cursor:raise PipelineError('INVALID_BINARY','section overlaps header')
    return image

def semantic_inventory(data: bytes) -> dict:
    from .bindings import inventory_imports, inventory_exports
    image=parse_macho(data)
    return {'kind':image['kind'],'platform':image['platform'],'identity':image['identity'],
            'dependencies':image['dependencies'],'imports':inventory_imports(data,image),
            'exports':inventory_exports(data,image),
            'sections':[dict(s,sha256=hashlib.sha256(checked_slice(data,s['offset'],s['size'])).hexdigest()) for s in image['sections']]}
