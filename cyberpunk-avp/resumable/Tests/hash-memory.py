import pathlib, re, subprocess, tempfile
root=pathlib.Path(__file__).resolve().parents[1]
scratch=root.parents[1]/'scratch/cyberpunk-resumable'
work=pathlib.Path(tempfile.mkdtemp(prefix='hash-memory-',dir=scratch))
fixture=work/'fixture/Data/benchmark.bin'; fixture.parent.mkdir(parents=True)
with fixture.open('wb') as stream: stream.truncate(2*1024**3)
main=work/'main.swift'; main.write_text((root/'Tests/hash-memory.swift').read_text())
binary=work/'benchmark'
subprocess.run(['xcrun','swiftc','-module-cache-path',str(scratch/'ModuleCache'),str(root/'Sources/AssetReceiver.swift'),str(main),'-o',str(binary)],check=True)
p=subprocess.run(['/usr/bin/time','-l',str(binary),str(work/'fixture'),str(2*1024**3)],capture_output=True,text=True)
(work/'metrics.log').write_text(p.stdout+p.stderr)
if p.returncode: raise RuntimeError('Hash benchmark or OS memory metrics failed: '+str(work/'metrics.log'))
match=re.search(r'(\d+)\s+maximum resident set size',p.stderr)
if not match: raise RuntimeError('No authoritative resident-memory metric')
peak=int(match.group(1))
if peak>128*1024**2: raise RuntimeError(f'Hash scan retained too much memory: {peak}bytes')
print(f'PASS two-GiB hash scan used {peak} peak resident bytes (<128MiB)')
