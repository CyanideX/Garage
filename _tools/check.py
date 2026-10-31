"""Checks Garage without touching the game folder.

    python _tools/check.py            everything
    python _tools/check.py reds       the compile matrix
    python _tools/check.py scan       the static scans

Compiling and the redscript lints come from XUtils' tools/compile_check.py, next to this repo like the XU2
scripts it compiles against (XU_GAME picks the game, same as there).
"""

import importlib.util
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
GITHUB = REPO.parent
SCRIPTS = REPO / "r6/scripts/Garage"
os.environ.setdefault("XU_CHECK_DIR", str(Path(tempfile.gettempdir()) / "garage-compile-check"))

spec = importlib.util.spec_from_file_location("compile_check", GITHUB / "XUtils/v2/tools/compile_check.py")
cc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cc)

AUDIOXL = cc.GAME / "r6/scripts/AudioXL"
TWEAKXL = cc.GAME / "red4ext/plugins/TweakXL/Scripts"
VEHICLECORE = GITHUB / "VehicleCore/r6/scripts"
CARS = sorted(GITHUB.glob("SDH0/*/r6/scripts"))
BASE = [cc.XUTILS, cc.CODEWARE, cc.MOD_SETTINGS]

cc.CONFIGS.clear()
cc.CONFIGS.update({
    "garage": [*BASE, TWEAKXL, VEHICLECORE, SCRIPTS],
    "nomodsettings": [cc.XUTILS, cc.CODEWARE, TWEAKXL, VEHICLECORE, SCRIPTS],
    "audio": [*BASE, TWEAKXL, AUDIOXL, VEHICLECORE, SCRIPTS],
    "cars": [*BASE, TWEAKXL, AUDIOXL, SCRIPTS, VEHICLECORE, *CARS],
    "carsalone": [cc.CODEWARE, cc.MOD_SETTINGS, TWEAKXL, AUDIOXL, VEHICLECORE, *CARS],
})


def check_reds():
    base = cc.prepare()
    failed = False
    for name, paths in cc.CONFIGS.items():
        missing = [str(p) for p in paths if not p.exists()]
        if missing:
            print(f"[{name}] FAILED, missing: {', '.join(missing)}")
            failed = True
            continue
        run = subprocess.run([sys.executable, __file__, "--one", name, str(base)], capture_output=True, text=True,
                             encoding="utf-8", errors="replace")
        print(f"[{name}] {'ok' if run.returncode == 0 else 'FAILED'}")
        for line in run.stdout.splitlines():
            if line.strip() and not line.startswith(("C:", "/")) and "[INFO" not in line:
                print("  " + line)
        failed = failed or run.returncode != 0
    files = sorted(SCRIPTS.rglob("*.reds"))
    hits = cc.prefix_clashes(files)
    returns = cc.struct_returns(files)
    for path in files:
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            code = re.sub(r'"(?:\\.|[^"\\])*"', '""', line.split("//")[0])
            if cc.CALL_SIZE.search(code) or any(m.group(1) in returns for m in cc.CALL_FIELD.finditer(code)):
                hits.append(f"[lint] {path.relative_to(REPO).as_posix()}:{number}: read a call's result through a local: {line.strip()}")
    for hit in hits:
        print(hit)
    return failed or bool(hits)


TEXT = re.compile(r'this\.Text\("([^"]+)"')
KEY_USE = re.compile(r'n"(Garage-[\w-]+)"')


def check_scan():
    hits = []
    if (REPO / "bin").exists():
        hits.append("bin/ exists: Garage has no CET side")
    for path in sorted(SCRIPTS.rglob("*.reds")):
        rel = path.relative_to(REPO).as_posix()
        text = path.read_text(encoding="utf-8")
        for number, line in enumerate(text.splitlines(), 1):
            code = line.split("//")[0]
            if 'Game["' in code:
                hits.append(f'{rel}:{number}: Game["..."] is CET')
            if "/Addons/" in rel and re.search(r"@(wrapMethod|replaceMethod|addField|addMethod)\b", code):
                hits.append(f"{rel}:{number}: addons don't wrap game classes, core does")
            if "/Localization/" not in rel and re.search(r'\.SetText\(\s*"[^"]*[A-Za-z]{2}', code):
                hits.append(f"{rel}:{number}: UI text goes through GarageText")

    # Two Mod Settings pages on one class: only the last page's values reach user.ini
    for path in sorted(SCRIPTS.rglob("*.reds")):
        for block in re.split(r"^(?=(?:public |private )?(?:\w+ )*class )", path.read_text(encoding="utf-8"), flags=re.M):
            mods = set(re.findall(r'"ModSettings\.mod", "([^"]+)"', block))
            if len(mods) > 1:
                hits.append(f"{path.relative_to(REPO).as_posix()}: one class on Mod Settings pages {sorted(mods)}")

    packages = {p.stem: set(TEXT.findall(p.read_text(encoding="utf-8")))
                for p in sorted((SCRIPTS / "Localization").glob("Garage*.reds")) if p.stem not in ("GarageLocalization", "GarageText")}
    english = packages.get("GarageEnglish", set())
    for name, keys in packages.items():
        for key in sorted(english - keys):
            hits.append(f"{name} is missing {key}")
        for key in sorted(keys - english):
            hits.append(f"{name} has {key}, English doesn't")
    for path in sorted(SCRIPTS.rglob("*.reds")):
        for key in KEY_USE.findall(path.read_text(encoding="utf-8")):
            if key not in english:
                hits.append(f"{path.relative_to(REPO).as_posix()}: {key} isn't in English")
    for hit in hits:
        print("[scan] " + hit)
    print(f"[scan] {'FAILED' if hits else 'ok'}, {len(packages)} packages, {len(english)} keys")
    return bool(hits)


def main(args):
    if args[:1] == ["--one"]:
        return cc.compile_one(args[1], Path(args[2]))
    what = args or ["reds", "scan"]
    failed = False
    if "reds" in what:
        failed = check_reds() or failed
    if "scan" in what:
        failed = check_scan() or failed
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
