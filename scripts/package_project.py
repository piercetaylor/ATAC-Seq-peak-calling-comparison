#!/usr/bin/env python3
"""Create a source-only transfer archive; exclude reads, results, and runtimes."""
from pathlib import Path
import hashlib
import tarfile

root = Path(__file__).resolve().parents[1]
output = root / "dist"
output.mkdir(exist_ok=True)
archive = output / "ATAC_Seq_Project.tar.gz"
files = [root / name for name in ("README.md", ".gitignore", ".gitattributes")]
for directory in ("config", "docs", "scripts", "slurm", "tests", "dashboard"):
    files.extend(path for path in (root / directory).rglob("*")
                 if path.is_file() and "__pycache__" not in path.parts and path.name != "local.sh")
files.extend(root / "env" / name for name in ("environment.yml", "bootstrap.sh"))
with tarfile.open(archive, "w:gz") as bundle:
    for path in sorted(files):
        relative = path.relative_to(root)
        info = bundle.gettarinfo(str(path), arcname="ATAC_Seq_Project/" + relative.as_posix())
        info.uid = info.gid = 0
        info.uname = info.gname = ""
        info.mode = 0o755 if path.suffix in (".sh", ".sbatch") else 0o644
        with path.open("rb") as handle:
            bundle.addfile(info, handle)
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
(output / "ATAC_Seq_Project.tar.gz.sha256").write_text(f"{digest}  {archive.name}\n")
print(f"Created {archive} ({archive.stat().st_size:,} bytes, {len(files)} source files)")
