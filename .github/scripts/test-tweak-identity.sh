#!/usr/bin/env bash
set -euo pipefail
python3 - <<'PY'
import io
import pathlib
import subprocess
import tarfile
import tempfile

repo = pathlib.Path.cwd()
verify = repo / '.github/scripts/verify-tweak-identity.sh'
with tempfile.TemporaryDirectory(prefix='dyads-identity-') as directory:
    work = pathlib.Path(directory)
    def package(name, prefix, names):
        folder = work / name
        folder.mkdir()
        (folder / 'debian-binary').write_text('2.0\n')
        with tarfile.open(folder / 'control.tar.gz', 'w:gz') as archive:
            data = b'Package: com.huami.dyyy\nVersion: 1.0\nArchitecture: iphoneos-arm64\n'
            member = tarfile.TarInfo('control')
            member.size = len(data)
            archive.addfile(member, io.BytesIO(data))
        with tarfile.open(folder / 'data.tar.gz', 'w:gz') as archive:
            for entry in names:
                data = b'test injection file\n'
                member = tarfile.TarInfo(prefix + '/' + entry)
                member.size = len(data)
                archive.addfile(member, io.BytesIO(data))
        result = folder / 'fixture package.deb'
        # 固定采用 dpkg Deb 的空格填充短成员名，不使用 GNU ar 尾部斜杠变体。
        with result.open('wb') as output:
            output.write(b'!<arch>\n')
            for filename in ['debian-binary', 'control.tar.gz', 'data.tar.gz']:
                data = (folder / filename).read_bytes()
                header = f'{filename:<16}{0:<12}{0:<6}{0:<6}{"100644":<8}{len(data):<10}`\n'.encode('ascii')
                assert len(header) == 60
                output.write(header)
                output.write(data)
                if len(data) % 2:
                    output.write(b'\n')
        return result
    cases = [
        ('rootful', 'Library/MobileSubstrate/DynamicLibraries', ['DYads-.dylib', 'DYads-.plist'], True),
        ('rootless', 'var/jb/Library/MobileSubstrate/DynamicLibraries', ['DYads-.dylib', 'DYads-.plist'], True),
        ('roothide', 'var/containers/Bundle/.jbroot-test/usr/lib/TweakInject', ['DYads-.dylib', 'DYads-.plist'], True),
        ('legacy', 'Library/MobileSubstrate/DynamicLibraries', ['DYYY.dylib', 'DYYY.plist'], False),
        ('mixed', 'Library/MobileSubstrate/DynamicLibraries', ['DYads-.dylib', 'DYads-.plist', 'DYYY.dylib'], False),
        ('missing-filter', 'Library/MobileSubstrate/DynamicLibraries', ['DYads-.dylib'], False),
        ('missing-library', 'Library/MobileSubstrate/DynamicLibraries', ['DYads-.plist'], False),
        ('duplicate-library', 'Library/MobileSubstrate/DynamicLibraries', ['DYads-.dylib', 'DYads-.plist', 'nested/DYads-.dylib'], False),
    ]
    for name, prefix, names, accepted in cases:
        deb = package(name, prefix, names)
        result = subprocess.run(['bash', str(verify), str(deb)], capture_output=True, text=True)
        if (result.returncode == 0) != accepted:
            raise AssertionError(f'{name}: unexpected identity result\n{result.stdout}\n{result.stderr}')
    print('DYads- package identity tests passed (3 install paths, 5 invalid identities)')
PY
