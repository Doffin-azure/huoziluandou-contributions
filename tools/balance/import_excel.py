#!/usr/bin/env python3
"""Import the designer workbook using Python's standard library only.

No Excel/Office process, third-party package, or network access is required.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import posixpath
import sys
import tempfile
import zipfile
from decimal import Decimal, InvalidOperation
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
NS = {'m': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main',
      'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'}

class ConfigurationError(ValueError):
    pass

def key_of(row, spec):
    return tuple(row[i] for i in spec['key'])

def validate_tables(tables, schema):
    if set(tables) != {s['name'] for s in schema['sheets']}:
        raise ConfigurationError('配置表不完整或含未知表')
    for spec in schema['sheets']:
        expected = {key_of(row, spec): row for row in spec['rows']}
        seen = set()
        for number, row in enumerate(tables[spec['name']], 5):
            label = f"{spec['name']} 第{number}行"
            if not isinstance(row, list) or len(row) != len(spec['columns']):
                raise ConfigurationError(label + '：列数错误')
            key = key_of(row, spec)
            if key not in expected: raise ConfigurationError(label + f'：未知ID {key}')
            if key in seen: raise ConfigurationError(label + f'：重复ID {key}')
            seen.add(key)
            for i, col in enumerate(spec['columns']):
                value = row[i]
                location = f"{label}「{col['name']}」"
                if not col['editable'] or ('editable_by_key' in spec and i not in spec['editable_by_key']['/'.join(map(str,key))]):
                    if value != expected[key][i]:
                        raise ConfigurationError(location + '：灰色标识/说明列不可修改')
                    continue
                if isinstance(value, bool) or not isinstance(value, (int, float)):
                    raise ConfigurationError(location + '：必须填写整数，不能留空或填文字')
                try: number_value = Decimal(str(value))
                except InvalidOperation: raise ConfigurationError(location + '：不是有效整数')
                if not number_value.is_finite() or number_value != number_value.to_integral_value():
                    raise ConfigurationError(location + '：必须填写有限整数')
                low, high = (expected[key][5:7] if spec['name'] == '机制参数' else (col['min'], col['max']))
                if not low <= value <= high:
                    raise ConfigurationError(location + f'：应在 {low}～{high} 之间，当前为 {value}')
                row[i] = int(value)
        if seen != set(expected):
            raise ConfigurationError(f"{spec['name']}：缺少记录 {sorted(set(expected)-seen)}")
    return tables

def read_workbook(path, schema, validator=None):
    with zipfile.ZipFile(path) as archive:
        if sum(i.file_size for i in archive.infolist()) > 32 * 1024 * 1024:
            raise ConfigurationError('工作簿过大，请使用配套配置表')
        strings = []
        if 'xl/sharedStrings.xml' in archive.namelist():
            for item in ET.fromstring(archive.read('xl/sharedStrings.xml')).findall('m:si', NS):
                strings.append(''.join(n.text or '' for n in item.findall('.//m:t', NS)))
        relationships = {n.attrib['Id']: n.attrib['Target'] for n in ET.fromstring(archive.read('xl/_rels/workbook.xml.rels'))}
        paths = {}
        for item in ET.fromstring(archive.read('xl/workbook.xml')).findall('m:sheets/m:sheet', NS):
            target = relationships[item.attrib['{' + NS['r'] + '}id']]
            paths[item.attrib['name']] = target.lstrip('/') if target.startswith('/') else posixpath.normpath('xl/' + target)
        tables = {}
        for spec in schema['sheets']:
            if spec['name'] not in paths: raise ConfigurationError('缺少工作表：' + spec['name'])
            cells = {}
            for cell in ET.fromstring(archive.read(paths[spec['name']])).findall('.//m:sheetData/m:row/m:c', NS):
                address = cell.attrib['r']
                if cell.find('m:f', NS) is not None:
                    raise ConfigurationError(f"{spec['name']}!{address}：配置单元格不能使用公式，请粘贴为数值")
                value_node = cell.find('m:v', NS)
                raw = value_node.text if value_node is not None else None
                kind = cell.attrib.get('t', 'n')
                if kind == 's': value = strings[int(raw)] if raw is not None else ''
                elif kind == 'inlineStr': value = ''.join(t.text or '' for t in cell.findall('.//m:t', NS))
                elif kind in ('str', 'e'): value = raw or ''
                elif kind == 'b': value = raw == '1'
                elif raw is None: value = ''
                else:
                    try:
                        value_decimal = Decimal(raw)
                        value = int(value_decimal) if value_decimal.is_finite() and value_decimal == value_decimal.to_integral_value() else float(value_decimal)
                    except (ValueError, InvalidOperation): value = raw
                # Stable table coordinates: title 2, note 3, column names 4, data 5+.
                col_letters = ''.join(c for c in address if c.isalpha())
                col_number = 0
                for char in col_letters: col_number = col_number * 26 + ord(char) - ord('A') + 1
                row_number = int(''.join(c for c in address if c.isdigit()))
                cells[row_number, col_number] = value
            header = [cells.get((4, i + 1), '') for i in range(len(spec['columns']))]
            if header != [c['name'] for c in spec['columns']]:
                raise ConfigurationError(spec['name'] + '：第4行表头被修改或列顺序不匹配')
            last_row = max((r for (r, c), value in cells.items() if value != ''), default=4)
            rows = []
            for number in range(5, last_row + 1):
                row = [cells.get((number, i + 1), '') for i in range(len(spec['columns']))]
                if any(v != '' for (r, c), v in cells.items() if r == number and c > len(row)):
                    raise ConfigurationError(f"{spec['name']} 第{number}行：存在未知数据列")
                if any(value != '' for value in row): rows.append(row)
            tables[spec['name']] = rows
    return (validator or validate_tables)(tables, schema)

def atomic_write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    handle, temporary = tempfile.mkstemp(prefix=path.name + '.', suffix='.tmp', dir=path.parent)
    try:
        with os.fdopen(handle, 'wb') as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary): os.unlink(temporary)

def main(argv=None):
    parser = argparse.ArgumentParser(description='校验并导入怪物 Excel。修改后须保存、导入，再重新启动游戏或新开测试战斗。')
    parser.add_argument('--input', type=Path, default=ROOT/'策划配置/怪物数值.xlsx')
    parser.add_argument('--output', type=Path, default=ROOT/'data/balance/enemies.json')
    parser.add_argument('--check', action='store_true', help='仅校验，不写文件')
    parser.add_argument('--restore', action='store_true', help='恢复上一次成功导入前的配置')
    args = parser.parse_args(argv)
    if args.output == ROOT/'data/balance/enemies.json' and (ROOT/'data/balance/battle_schema.json').exists():
        if args.input != ROOT/'策划配置/怪物数值.xlsx':
            print('旧怪物工作簿不再覆盖当前游戏，请使用 import_battle_excel.py 与战斗数值.xlsx。', file=sys.stderr)
            return 1
        import import_battle_excel
        return import_battle_excel.main((['--check'] if args.check else []) + (['--restore'] if args.restore else []))
    try:
        schema = json.loads((ROOT/'data/balance/schema.json').read_text())
        backup = args.output.with_suffix('.json.bak')
        if args.restore:
            payload = json.loads(backup.read_text())
            if payload.get('version') != schema['version']: raise ConfigurationError('备份版本不匹配')
            validate_tables(payload['tables'], schema)
        else:
            tables = read_workbook(args.input, schema)
            payload = {'version': schema['version'], 'source_sha256': hashlib.sha256(args.input.read_bytes()).hexdigest(), 'tables': tables}
        content = (json.dumps(payload, ensure_ascii=False, indent=2, allow_nan=False) + '\n').encode()
        if not args.check:
            if not args.restore:
                previous = args.output.read_bytes() if args.output.exists() else (json.dumps({'version': schema['version'], 'tables': {s['name']: s['rows'] for s in schema['sheets']}}, ensure_ascii=False, indent=2) + '\n').encode()
                atomic_write(backup, previous)
            atomic_write(args.output, content)
        total = sum(len(rows) for rows in payload['tables'].values())
        print(f"{'校验通过' if args.check else ('恢复成功' if args.restore else '导入成功')}：{len(schema['sheets'])}张配置表，{total}行。")
        if not args.check: print('重新启动游戏后生效；已开始的战斗不自动修改。')
        return 0
    except (ConfigurationError, OSError, ValueError, KeyError, IndexError, TypeError, zipfile.BadZipFile, ET.ParseError) as error:
        print('导入失败，游戏配置未改动：' + str(error), file=sys.stderr)
        return 1

if __name__ == '__main__': sys.exit(main())
