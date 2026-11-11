"""Проверка русского перевода перед сборкой: синтаксис файлов, подключение в .toc и Locale.lua, %s/%d.

    py -3 tools/ru/check.py

Lua в системе может не быть, поэтому файлы переводов проверяются строгим разбором: внутри таблицы
каждая строка — либо комментарий/пустая, либо целиком запись  ["строка"] = "строка",
Код возврата 0 — всё в порядке.
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import names  # noqa: E402  (разбор строк Lua)
import sync_ui  # noqa: E402  (сверка с немецким)

sys.stdout.reconfigure(encoding="utf-8")
ADDON = names.ADDON
errors = []


def check_table(path, opener):
    lines = path.read_text(encoding="utf-8").splitlines()
    try:
        start = lines.index(opener)
    except ValueError:
        errors.append(f"{path.name}: нет строки {opener!r}")
        return 0
    if lines[-1] != "} end":
        errors.append(f"{path.name}: последняя строка не '}} end'")
    keys, count = set(), 0
    for n, line in enumerate(lines[start + 1:-1], start + 2):
        s = line.strip()
        if not s or s.startswith("--"):
            continue
        try:
            if not s.startswith("["):
                raise ValueError("не запись")
            key, i = names.parse(s, 1)
            i = names.skip(s, i)
            if s[i] != "]":
                raise ValueError("нет ]")
            i = names.skip(s, i + 1)
            if s[i] != "=":
                raise ValueError("нет =")
            value, i = names.parse(s, i + 1)
            i = names.skip(s, i)
            if s[i:] != ",":
                raise ValueError(f"после значения {s[i:]!r}")
            if not isinstance(key, str) or not isinstance(value, str):
                raise ValueError("ключ или значение не строка")
        except (ValueError, IndexError, AttributeError) as e:
            errors.append(f"{path.name}:{n}: {e}: {s[:100]}")
            continue
        if key in keys:
            errors.append(f"{path.name}:{n}: ключ повторяется: {key[:80]}")
        keys.add(key)
        count += 1
    return count


ui = check_table(ADDON / "Locales" / "ruRU.lua", "FLT.LOCALES.ruRU = function() return {")
nm = check_table(ADDON / "Locales" / "Names_ruRU.lua", "FLT.NAME_LOCALES.ruRU = function() return {")
print(f"ruRU.lua: {ui} строк интерфейса; Names_ruRU.lua: {nm} названий")

toc = (ADDON / "OneForAll.toc").read_text(encoding="utf-8-sig").splitlines()
listed = [t.strip().replace("\\", "/") for t in toc if t.strip() and not t.startswith("#")]
for f in ("Locales/ruRU.lua", "Locales/Names_ruRU.lua"):
    if f not in listed:
        errors.append(f"OneForAll.toc: нет {f}")
for f in listed:
    if not (ADDON / f).exists():
        errors.append(f"OneForAll.toc: файла нет на диске: {f}")
if listed.index("Locales/ruRU.lua") < listed.index("Locales/Locale.lua"):
    errors.append("OneForAll.toc: ruRU.lua подключён раньше Locale.lua")
version = next((t.split(":", 1)[1].strip() for t in toc if t.startswith("## Version")), "?")

locale = (ADDON / "Locales" / "Locale.lua").read_text(encoding="utf-8")
if not re.search(r'\{\s*key\s*=\s*"ruRU"\s*,\s*label\s*=\s*"Русский"\s*\}', locale):
    errors.append("Locale.lua: в FLT.LANGUAGES нет русского")

de = sync_ui.entries(ADDON / "Locales" / "deDE.lua")
ru = sync_ui.entries(ADDON / "Locales" / "ruRU.lua")
missing = [k for k in de if k not in ru]
bad = [k for k, v in ru.items() if sync_ui.placeholders(k) != sync_ui.placeholders(v)]
for k in bad:
    errors.append(f"ruRU.lua: не совпадают %s/%d: {k[:80]}")
print(f"Версия аддона {version}; строк без перевода (будут по-английски): {len(missing)}")

if errors:
    print("ОШИБКИ:")
    for e in errors:
        print("  -", e)
    sys.exit(1)
print("Проверка пройдена.")
