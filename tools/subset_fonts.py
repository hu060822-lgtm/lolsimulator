"""把 Noto Sans TC 縮成遊戲用得到的字（Big5 常用字 + 專案內出現的所有字），讓字型檔從 7MB 降到約 1.5MB。

用法：python3 tools/subset_fonts.py <放原始 NotoSansTC-*.ttf 的資料夾>
需要 fonttools（pip install fonttools）。原始字型：Google Fonts 的 Noto Sans TC（SIL OFL 1.1）。
"""
import pathlib
import sys

from fontTools import subset

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = pathlib.Path(sys.argv[1])
WEIGHTS = ["400", "700", "900"]


def big5_common() -> set:
    chars = set()
    for hi in range(0xA4, 0xC7):
        for lo in list(range(0x40, 0x7F)) + list(range(0xA1, 0xFF)):
            try:
                chars.add(bytes([hi, lo]).decode("big5"))
            except UnicodeDecodeError:
                pass
    return chars


def project_chars() -> set:
    chars = set()
    for ext in ("*.gd", "*.json", "*.tscn", "*.md", "*.csv"):
        for p in ROOT.rglob(ext):
            if ".godot" in p.parts:
                continue
            chars |= set(p.read_text(encoding="utf-8", errors="ignore"))
    return chars


text = big5_common() | project_chars()
text |= {chr(c) for c in range(0x20, 0x250)}          # ASCII、Latin-1、Latin Extended
text |= {chr(c) for c in range(0x2000, 0x2BFF)}        # 標點、箭頭、幾何圖形
text |= {chr(c) for c in range(0x3000, 0x3100)}        # CJK 標點、注音
text |= {chr(c) for c in range(0xFF00, 0xFFF0)}        # 全形
unicodes = sorted(ord(c) for c in text if ord(c) >= 0x20)
for w in WEIGHTS:
    opts = subset.Options()
    opts.layout_features = ["*"]
    opts.name_IDs = ["*"]
    opts.notdef_outline = True
    f = subset.load_font(str(SRC / f"NotoSansTC-{w}.ttf"), opts)
    s = subset.Subsetter(opts)
    s.populate(unicodes=unicodes)
    s.subset(f)
    out = ROOT / "assets" / "fonts" / f"NotoSansTC-{w}.ttf"
    subset.save_font(f, str(out), opts)
    print(out.name, out.stat().st_size // 1024, "KB")
