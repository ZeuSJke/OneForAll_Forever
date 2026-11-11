"""Сверяет русский перевод интерфейса (ruRU.lua) с немецким (deDE.lua) и пересобирает ruRU.lua.

Немецкий автор обновляет в каждой версии, поэтому он служит образцом: те же ключи и тот же порядок.

    py -3 tools/ru/sync_ui.py --check            только отчёт: чего не хватает, что лишнее, ошибки в %s/%d
    py -3 tools/ru/sync_ui.py --add new.lua      добавить переводы из new.lua и пересобрать ruRU.lua
    py -3 tools/ru/sync_ui.py --version 6.2.5    заодно поменять версию в шапке

Файл для --add в том же формате, что и ruRU.lua: строки  ["English"] = "Русский",
Чего нет в переводе, аддон показывает по-английски, так что пропуск не ломает игру,
а вот разное число или порядок %s/%d ломает string.format — такие строки скрипт не пишет.
"""
import argparse
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
ROOT = Path(__file__).resolve().parents[2]
LOCALES = ROOT / "OneForAll" / "Locales"
STR = r'"(?:[^"\\]|\\.)*"'
ENTRY = re.compile(r'^\s*\[(' + STR + r')\]\s*=\s*(' + STR + r')\s*,?\s*(?:--.*)?$')
# подстановки string.format в Lua; обычный знак процента («1% Hit», «100 %») сюда не попадает
PLACEHOLDER = re.compile(r"%[-+#0]*\d*(?:\.\d+)?[diucxXoeEfgGqsaA%]")
OPEN, CLOSE = "FLT.LOCALES.{} = function() return {{", "} end"


def entries(path):
    """[(ключ, значение)] из файла перевода; ключ и значение — как в файле, в кавычках."""
    out = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        m = ENTRY.match(line)
        if m:
            out[m.group(1)] = m.group(2)
    return out


def placeholders(s):
    return [p for p in PLACEHOLDER.findall(s) if p != "%%"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--add", type=Path)
    ap.add_argument("--version")
    args = ap.parse_args()

    de_path, ru_path = LOCALES / "deDE.lua", LOCALES / "ruRU.lua"
    de_lines = de_path.read_text(encoding="utf-8").splitlines()
    de = entries(de_path)
    ru = entries(ru_path)
    if args.add:
        added = entries(args.add)
        print(f"Из {args.add.name} добавлено переводов: {len(added)}")
        ru.update(added)

    bad = {k: v for k, v in ru.items() if placeholders(k) != placeholders(v)}
    missing = [k for k in de if k not in ru]
    extra = [k for k in ru if k not in de]
    print(f"Строк в немецком: {len(de)}; переведено на русский: {len(de) - len(missing)}; "
          f"нет перевода: {len(missing)}; лишних (нет в немецком): {len(extra)}; "
          f"ошибок в %s/%d: {len(bad)}")
    for k in missing:
        print(f"  НЕТ   [{k}] = ...   -- de: {de[k]}")
    for k in extra:
        print(f"  ЛИШН  [{k}]")
    for k, v in bad.items():
        print(f"  %ОШИБ [{k}] = {v}")
    if args.check:
        return 1 if missing or bad else 0

    ru_head = ru_path.read_text(encoding="utf-8").splitlines()
    head = ru_head[:ru_head.index(OPEN.format("ruRU"))]
    if args.version:
        head = [re.sub(r"^-- Russian \([^)]*\)", f"-- Russian ({args.version})", h) for h in head]
    body = []
    start = de_lines.index(OPEN.format("deDE")) + 1
    end = len(de_lines) - 1 - de_lines[::-1].index(CLOSE)
    for line in de_lines[start:end]:
        m = ENTRY.match(line)
        if not m:
            body.append(line)  # комментарии-разделы и пустые строки как в немецком
            continue
        key = m.group(1)
        if key in ru and key not in bad:
            indent = line[:len(line) - len(line.lstrip())]
            body.append(f"{indent}[{key}] = {ru[key]},")
    eol = "\r\n" if b"\r\n" in ru_path.read_bytes() else "\n"
    text = "\n".join(head + [OPEN.format("ruRU")] + body + [CLOSE]) + "\n"
    ru_path.write_text(text, encoding="utf-8", newline=eol)
    print(f"Записан {ru_path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
