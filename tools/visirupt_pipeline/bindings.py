"""Logical providers across chained, nlist and legacy binding representations."""
from .core import PipelineError
from .macho import checked_slice,unpack,cstring,MAX_RECORDS

def decode_leb(data, offset, signed=False):
    value=0;shift=0
    for _ in range(10):
        byte=checked_slice(data,offset,1)[0];offset+=1
        value|=(byte&127)<<shift;shift+=7
        if not byte&128:
            if signed and byte&64:value-=1<<shift
            if signed and not -(1<<63)<=value<1<<63 or not signed and value>=1<<64:
                raise PipelineError('INVALID_BINARY','LEB overflow')
            return value,offset
    raise PipelineError('INVALID_BINARY','unterminated LEB')

def provider(image,ordinal):
    if ordinal<=0 or ordinal in (253,254,255):return 'SPECIAL:'+str(ordinal)
    if ordinal>len(image['dependencies']):raise PipelineError('INVALID_BINARY','provider ordinal')
    return image['dependencies'][ordinal-1]['path']

def inventory_imports(data, image):
    records=[]
    if image['fixups']:
        base,length=image['fixups'];blob=checked_slice(data,base,length)
        version,starts,imports,strings,count,fmt,symfmt=unpack('<7I',blob)
        if version!=0 or symfmt!=0 or fmt not in (1,2,3) or count>MAX_RECORDS or min(starts,imports,strings)<28:
            raise PipelineError('INVALID_BINARY','fixup format')
        stride={1:4,2:8,3:16}[fmt];checked_slice(blob,imports,count*stride)
        checked_slice(blob,strings,1)
        segment_count=unpack('<I',blob,starts)[0]
        if segment_count>len(image['segments']):raise PipelineError('INVALID_BINARY','fixup segment count')
        offsets=checked_slice(blob,starts+4,segment_count*4)
        for i in range(segment_count):
            at=unpack('<I',offsets,4*i)[0]
            if at:
                segment=starts+at
                size,page_size,pointer_fmt,segment_offset,max_pointer,pages=unpack('<IHHQIH',blob,segment)
                if size<22+pages*2 or pointer_fmt not in (1,2,6,9,12) or page_size not in (4096,16384):
                    raise PipelineError('INVALID_BINARY','fixup pointer format')
                checked_slice(blob,segment,size)
        for i in range(count):
            loc=imports+i*stride
            bits=unpack('<Q' if fmt==3 else '<I',blob,loc)[0]
            width=16 if fmt==3 else 8;ordinal=bits&((1<<width)-1)
            if ordinal&(1<<(width-1)):ordinal-=1<<width
            name_offset=bits>>32 if fmt==3 else bits>>9
            symbol=cstring(blob,strings+name_offset)
            addend=unpack('<q' if fmt==3 else '<i',blob,loc+(8 if fmt==3 else 4))[0] if fmt!=1 else 0
            records.append({'source':'chained','offset':base+loc,'width':width,'format':fmt,'symbol':symbol,
                'ordinal':ordinal,'provider':provider(image,ordinal),'weak':bool(bits&(1<<(16 if fmt==3 else 8))),'addend':addend})
    if image['symtab']:
        symoff,count,stroff,strsize=image['symtab'];strings=checked_slice(data,stroff,strsize)
        for i in range(count):
            loc=symoff+i*16;strx,typ,sect,desc,value=unpack('<IBBHQ',data,loc)
            if strx>=len(strings):raise PipelineError('INVALID_BINARY','nlist string offset')
            symbol=cstring(strings,strx)
            if not typ&0xe0 and typ&0xe==0 and typ&1:
                ordinal=desc>>8
                records.append({'source':'nlist','offset':loc,'ordinal':ordinal,'provider':provider(image,ordinal),
                    'symbol':symbol,'weak':bool(desc&0x40),'addend':0,'descriptor':desc,'value':value})
    if image['dyld_info']:
        info=image['dyld_info']
        for label,index in (('bind',2),('weak',4),('lazy',6)):
            base,size=info[index:index+2]
            if size:records.extend(legacy_imports(checked_slice(data,base,size),base,image,label))
    if len(records)>MAX_RECORDS:raise PipelineError('INVALID_BINARY','import count')
    return records

def legacy_imports(blob,base,image,label):
    result=[];pos=0;ordinal=-3 if label=='weak' else 0;symbol=None;weak=False;addend=0;segment=None;address_offset=0;type_=1;ordinal_loc=None
    def emit():
        if symbol is None or segment is None or segment>=len(image['segments']):raise PipelineError('INVALID_BINARY','incomplete bind')
        seg=image['segments'][segment]
        size=8 if type_==1 else 4 if type_ in (2,3) else 0
        if not size or address_offset<0 or address_offset+size>seg['vmsize']:raise PipelineError('INVALID_BINARY','binding address')
        result.append({'source':'legacy_'+label,'symbol':symbol,'ordinal':ordinal,'provider':provider(image,ordinal),
            'weak':weak,'addend':addend,'address':seg['vm']+address_offset,'ordinal_offset':ordinal_loc,'type':type_})
        if len(result)>MAX_RECORDS:raise PipelineError('INVALID_BINARY','bind count')
    while pos<len(blob):
        loc=pos;byte=blob[pos];pos+=1;op=byte&240;imm=byte&15
        if op==0:
            if label=='lazy':ordinal=0;symbol=None;weak=False;addend=0;segment=None;address_offset=0;type_=1;ordinal_loc=None
        elif op==16:ordinal=imm;ordinal_loc=base+loc
        elif op==32:ordinal,pos=decode_leb(blob,pos);ordinal_loc=base+loc
        elif op==48:ordinal=imm-16 if imm else 0;ordinal_loc=base+loc
        elif op==64:symbol=cstring(blob,pos);pos+=len(symbol.encode())+1;weak=bool(imm&1)
        elif op==80:type_=imm
        elif op==96:addend,pos=decode_leb(blob,pos,True)
        elif op==112:segment=imm;address_offset,pos=decode_leb(blob,pos)
        elif op==128:delta,pos=decode_leb(blob,pos);address_offset+=delta
        elif op==144:emit();address_offset+=8
        elif op==160:
            delta,pos=decode_leb(blob,pos);emit();address_offset+=8+delta
        elif op==176:emit();address_offset+=8+imm*8
        elif op==192:
            count,pos=decode_leb(blob,pos);skip,pos=decode_leb(blob,pos)
            if count>MAX_RECORDS:raise PipelineError('INVALID_BINARY','bind count')
            for _ in range(count):emit();address_offset+=8+skip
        else:raise PipelineError('INVALID_BINARY','unsupported legacy opcode')
    return result

def inventory_exports(data,image):
    if not image['exports']:return []
    offset,length=image['exports'];blob=checked_slice(data,offset,length);result=[];visits=0
    def visit(at,prefix,ancestors):
        nonlocal visits
        visits+=1
        if visits>MAX_RECORDS or len(prefix)>65536:raise PipelineError('INVALID_BINARY','export trie budget')
        if at in ancestors or len(ancestors)>256 or len(result)>MAX_RECORDS:raise PipelineError('INVALID_BINARY','export trie cycle or bounds')
        size,pos=decode_leb(blob,at);terminal=checked_slice(blob,pos,size);next_node=pos+size
        if size:
            flags,q=decode_leb(terminal,0)
            item={'symbol':prefix,'flags':flags}
            if flags&8:
                ordinal,q=decode_leb(terminal,q);item.update(ordinal=ordinal,provider=provider(image,ordinal),import_name=cstring(terminal,q))
            else:
                address,q=decode_leb(terminal,q);item['address']=address
                if flags&16:item['resolver'],q=decode_leb(terminal,q)
            result.append(item)
        children=checked_slice(blob,next_node,1)[0];pos=next_node+1
        for _ in range(children):
            edge=cstring(blob,pos);pos+=len(edge.encode())+1
            target,pos=decode_leb(blob,pos)
            visit(target,prefix+edge,ancestors|{at})
    if blob:visit(0,'',set())
    return result
