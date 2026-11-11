"""Собирает OneForAll/Locales/Names_ruRU.lua — русские названия заданий, NPC, объектов, предметов
и цели заданий — из русских l10n-файлов QuestieDB (это тексты настоящего ruRU-клиента).

    py -3 tools/ru/names.py --tag v1.0.14 --check   только отчёт
    py -3 tools/ru/names.py --tag v1.0.14           пересобрать Names_ruRU.lua

Какие названия нужны: все ключи из Names_deDE.lua (автор пересобирает его в каждой версии),
ключи, что уже есть в Names_ruRU.lua, и строки из файлов данных аддона, которые совпадают
с английским названием в QuestieDB. Русский берётся по номеру записи; если одно английское
название у нескольких записей, выбирается та, чьё немецкое название совпадает с Names_deDE.

Тонкость QuestieDB: база Forever — это Classic с теми же номерами плюс поправки, собранные в самом
Forever (src/corrections/Forever/traces: новые записи и записи, которые Forever переделал), а русские
l10n-файлы Forever — копия Classic. Поэтому русский из основного файла берётся, только если в Classic
под тем же номером тот же английский текст; для переделанных и новых записей — из l10n/.../traces.
Файлы QuestieDB кэшируются в tools/ru/.cache/<tag>/.
"""
import argparse
import collections
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
ROOT = Path(__file__).resolve().parents[2]
ADDON = ROOT / "OneForAll"
LOCALES = ADDON / "Locales"
CACHE = Path(__file__).resolve().parent / ".cache"
RAW = "https://raw.githubusercontent.com/Questie/QuestieDB/{tag}/{path}"
KINDS = {  # вид: (имя в файлах QuestieDB, папка l10n)
    "quest": ("Quest", "lookupQuests"),
    "npc": ("Npc", "lookupNpcs"),
    "object": ("Object", "lookupObjects"),
    "item": ("Item", "lookupItems"),
}
LINE = re.compile(r"^\s*\[(\d+)\]\s*=\s*(.*?),?\s*$")
TRACE_START = re.compile(r"^\s*\[(\d+)\]\s*=\s*\{\s*$")
TRACE_FIELD = re.compile(r"^\s*\[\w+Keys\.(name|objectivesText)\]\s*=\s*(.*?),?\s*$")
WORD = re.compile(r"-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?|nil|true|false")
ESC = {"n": "\n", "t": "\t", "r": "\r", "\\": "\\", '"': '"', "'": "'", "a": "\a", "b": "\b", "f": "\f", "v": "\v"}


# --- разбор литералов Lua -------------------------------------------------------------------

def skip(s, i):
    while i < len(s) and s[i] in " \t\r\n":
        i += 1
    return i


def parse_str(s, i):
    q, i, out = s[i], i + 1, []
    while s[i] != q:
        c = s[i]
        if c == "\\":
            n = s[i + 1]
            if n.isdigit():
                m = re.match(r"\d{1,3}", s[i + 1:])
                out.append(chr(int(m.group(0))))
                i += 1 + len(m.group(0))
                continue
            out.append(ESC.get(n, n))
            i += 2
            continue
        out.append(c)
        i += 1
    return "".join(out), i + 1


def parse(s, i=0):
    """Значение Lua-литерала, начиная с позиции i: (значение, позиция после него)."""
    i = skip(s, i)
    c = s[i]
    if c in "\"'":
        return parse_str(s, i)
    if c == "{":
        i, items, keyed = i + 1, [], {}
        while True:
            i = skip(s, i)
            if s[i] == "}":
                if keyed:
                    keyed.update({n + 1: v for n, v in enumerate(items)})
                    return keyed, i + 1
                return items, i + 1
            if s[i] == "[":
                k, i = parse(s, i + 1)
                i = skip(s, i) + 1  # ]
                i = skip(s, i) + 1  # =
                v, i = parse(s, i)
                keyed[k] = v
            else:
                v, i = parse(s, i)
                items.append(v)
            i = skip(s, i)
            if s[i] in ",;":
                i += 1
    m = WORD.match(s, i)
    tok = m.group(0)
    val = {"nil": None, "true": True, "false": False}.get(tok, tok)
    if val is tok:
        val = float(tok) if "." in tok or "e" in tok.lower() else int(tok)
    return val, m.end()


def records(path):
    """{номер: значение} из файла QuestieDB, где каждая запись — строка  [номер] = {...},"""
    out = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        m = LINE.match(line)
        if m:
            out[int(m.group(1))], _ = parse(m.group(2))
    return out


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def names_file(path):
    """{английский: перевод} из Names_xxXX.lua (строки  ["ключ"]="значение",)."""
    out = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("["):
            k, i = parse(line, 1)
            i = skip(line, i) + 1  # ]
            i = skip(line, i) + 1  # =
            out[k], _ = parse(line, i)
    return out


# --- данные QuestieDB -----------------------------------------------------------------------

def fetch(tag):
    """Скачивает (один раз) нужные файлы QuestieDB. Файлов traces может не быть — тогда None."""
    folder = CACHE / tag
    files = {}
    for kind, (db, l10n) in KINDS.items():
        wanted = {
            "forever": f"data/Forever/forever{db}DB.lua",
            "forever traces": f"src/corrections/Forever/traces/forever{db}Traces.lua",
            "classic": f"data/Classic/classic{db}DB.lua",
            "ruRU": f"l10n/Forever/{l10n}/ruRU.lua",
            "ruRU traces": f"l10n/Forever/traces/{l10n}/ruRU.lua",
            "deDE": f"l10n/Forever/{l10n}/deDE.lua",
            "deDE traces": f"l10n/Forever/traces/{l10n}/deDE.lua",
        }
        for name, rel in wanted.items():
            dst = folder / rel
            missing = dst.with_name(dst.name + ".404")
            if not dst.exists() and not missing.exists():
                dst.parent.mkdir(parents=True, exist_ok=True)
                print(f"Скачиваю {rel} ({tag})")
                try:
                    with urllib.request.urlopen(RAW.format(tag=tag, path=rel), timeout=120) as r:
                        dst.write_bytes(r.read())
                except urllib.error.HTTPError as e:
                    if e.code != 404 or "traces" not in name:
                        raise
                    missing.touch()
            files[kind, name] = dst if dst.exists() else None
    return files


def trace_fields(path):
    """{номер: {"name": ..., "objectivesText": [...]}} из src/corrections/Forever/traces/*.lua."""
    out, rid = {}, None
    for line in path.read_text(encoding="utf-8").splitlines():
        m = TRACE_START.match(line)
        if m:
            rid = int(m.group(1))
            continue
        m = TRACE_FIELD.match(line)
        if m and rid is not None:
            out.setdefault(rid, {})[m.group(1)], _ = parse(m.group(2))
    return out


def forever_records(files, kind):
    """База Forever с наложенными поправками из traces: имена и цели заданий как в самом Forever."""
    db = records(files[kind, "forever"])
    if files[kind, "forever traces"]:
        for rid, fields in trace_fields(files[kind, "forever traces"]).items():
            rec = list(db.get(rid) or [])
            rec += [None] * (8 - len(rec))
            if "name" in fields:
                rec[0] = fields["name"]
            if "objectivesText" in fields:
                rec[7] = fields["objectivesText"]
            db[rid] = rec
    return db


def first(v):
    return v[0] if isinstance(v, list) and v else v


def objectives(v):
    return v[1] if isinstance(v, list) and len(v) > 1 and isinstance(v[1], list) else []


def at(lst, n):
    return lst[n] if n < len(lst) else None


def candidates(files, stats):
    """{английский текст: [(русский, немецкий), ...]} по всем записям всех видов (см. тонкость в начале)."""
    cands = collections.defaultdict(list)
    for kind in KINDS:
        db = forever_records(files, kind)
        classic = records(files[kind, "classic"])
        ru = records(files[kind, "ruRU"])
        ru_tr = records(files[kind, "ruRU traces"]) if files[kind, "ruRU traces"] else {}
        de = records(files[kind, "deDE"])
        de.update(records(files[kind, "deDE traces"]) if files[kind, "deDE traces"] else {})
        for rid, rec in db.items():
            if not isinstance(rec, list) or not rec or not isinstance(rec[0], str):
                continue
            old = classic.get(rid) if isinstance(classic.get(rid), list) else []
            d = de.get(rid)
            if rid in ru_tr:
                r, same = ru_tr[rid], True
                stats["traces"] += 1
            else:
                r, same = ru.get(rid), bool(old) and old[0] == rec[0]
                if r is not None and not same:
                    stats["отброшено: в Classic другая запись"] += 1
            cands[rec[0]].append((first(r) if same else None, first(d)))
            if kind == "quest" and len(rec) >= 8 and isinstance(rec[7], list):
                old_obj = old[7] if len(old) >= 8 and isinstance(old[7], list) else []
                for n, text in enumerate(rec[7]):
                    if not isinstance(text, str):
                        continue
                    ok = rid in ru_tr or at(old_obj, n) == text
                    cands[text].append((at(objectives(r), n) if ok else None, at(objectives(d), n)))
    return cands


def data_strings():
    """Строки из файлов аддона (кроме переводов) — среди них английские названия, которые он показывает."""
    lit = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
    out = set()
    for path in ADDON.rglob("*.lua"):
        if "Locales" in path.parts:
            continue
        for m in lit.finditer(path.read_text(encoding="utf-8", errors="replace")):
            out.add(parse_str('"' + m.group(1) + '"', 0)[0])
    return out


# --- сборка ---------------------------------------------------------------------------------

def resolve(key, cands, de_value):
    pairs = [(r, d) for r, d in cands.get(key, []) if r]
    if not pairs:
        return None, "нет в QuestieDB"
    if de_value is not None:
        match = [r for r, d in pairs if d == de_value]
        if match:
            return collections.Counter(match).most_common(1)[0][0], "сверено"
    variants = collections.Counter(r for r, _ in pairs)
    best = variants.most_common(1)[0][0]
    return best, "один вариант" if len(variants) == 1 else f"выбран из {len(variants)}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tag", required=True, help="версия QuestieDB, например v1.0.14")
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    files = fetch(args.tag)
    stats = collections.Counter()
    cands = candidates(files, stats)
    print("Записи QuestieDB:", dict(stats))
    de = names_file(LOCALES / "Names_deDE.lua")
    ru_path = LOCALES / "Names_ruRU.lua"
    old = names_file(ru_path)
    from_data = {s for s in data_strings() if s in cands}
    keys = set(de) | set(old) | from_data
    print(f"Ключей: из Names_deDE {len(de)}, из старого Names_ruRU {len(old)}, "
          f"из данных аддона {len(from_data)}; всего {len(keys)}")

    new, how, missing, changed = {}, collections.Counter(), [], []
    for key in sorted(keys):
        val, note = resolve(key, cands, de.get(key))
        if val is None and key in old:
            val, note = old[key], "из старого файла"
        if val is None:
            if key in de:
                missing.append(key)
            continue
        if val == key:  # перевод совпадает с английским — запись не нужна
            continue
        how[note] += 1
        new[key] = val
        if key in old and old[key] != val:
            changed.append((key, old[key], val))
    print("Как найдены:", dict(how))
    print(f"Без русского названия (останутся по-английски): {len(missing)}")
    for k in missing[:20]:
        print("   -", k, "| de:", de.get(k))
    added = [k for k in new if k not in old]
    print(f"Новых по сравнению со старым файлом: {len(added)}; изменилось значений: {len(changed)}")
    for k in added[:15]:
        print(f"   + {k} -> {new[k]}")
    for k, a, b in changed[:15]:
        print(f"   ~ {k}: {a} -> {b}")
    if args.check:
        return 0

    head = [line for line in ru_path.read_text(encoding="utf-8").splitlines() if not line.startswith("[")]
    open_at = next(n for n, h in enumerate(head) if "NAME_LOCALES.ruRU = function()" in h)
    head = [re.sub(r"^-- QuestieDB \S+ \([^)]*\)", f"-- QuestieDB {args.tag.lstrip('v')} (l10n + Forever traces)", h)
            for h in head[:open_at + 1]]
    body = [f"[{lua_str(k)}]={lua_str(v)}," for k, v in sorted(new.items())]
    eol = "\r\n" if b"\r\n" in ru_path.read_bytes() else "\n"
    ru_path.write_text("\n".join(head + body + ["} end"]) + "\n", encoding="utf-8", newline=eol)
    print(f"Записан {ru_path.relative_to(ROOT)}: {len(new)} названий")
    return 0


if __name__ == "__main__":
    sys.exit(main())
