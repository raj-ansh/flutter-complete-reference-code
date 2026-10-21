"""Run every program in bin/ and write its output to expected/<name>.txt.

Fails loudly if a program exits non-zero. Run from anywhere:
    python run_examples.py [name ...]
"""
import subprocess
import sys
import pathlib

root = pathlib.Path(__file__).resolve().parent
names = sys.argv[1:] or sorted(p.stem for p in (root / "bin").glob("*.dart"))
bad = 0
for n in names:
    r = subprocess.run(["dart", "run", f"bin/{n}.dart"], cwd=root, capture_output=True,
                       text=True, timeout=180, shell=True)
    out = r.stdout
    if r.returncode != 0:
        bad += 1
        print(f"FAIL {n} (exit {r.returncode})\n{r.stderr}")
    (root / "expected").mkdir(exist_ok=True)
    (root / "expected" / f"{n}.txt").write_text(out.replace("\r\n", "\n"), encoding="utf-8")
    print(f"ok   {n}: {len(out.splitlines())} lines")
sys.exit(1 if bad else 0)
