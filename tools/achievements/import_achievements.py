#!/usr/bin/env python3
"""成就 Excel -> 定义 JSON。仅使用 Python 3 标准库，不执行游戏或修改玩家存档。"""
import argparse
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import re
import string
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/balance'))
import import_excel as excel

ID = re.compile(r'^[a-z][a-z0-9_]{1,63}$')


def text(value, label, maximum=180, optional=False):
    if not isinstance(value, str) or value != value.strip() or (not value and not optional):
        raise excel.ConfigurationError(label + '：请填文字，且不要留首尾空格')
    if len(value) > maximum or any(ord(c) < 32 for c in value):
        raise excel.ConfigurationError(label + f'：长度应不超过{maximum}字，且不能含换行或控制字符')
    return value


def identifier(value, label):
    text(value, label, 64)
    if not ID.fullmatch(value):
        raise excel.ConfigurationError(label + '：应为2～64位小写英文、数字、下划线，且以字母开头')
    return value


def integer(value, label, low, high):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not low <= value <= high or not math.isfinite(value) or value != int(value):
        raise excel.ConfigurationError(label + f'：应填{low}～{high}之间的整数')
    return int(value)


def description(template, target, label):
    text(template, label, 100)
    try:
        fields = list(string.Formatter().parse(template))
        if not any(field == 'target' for _, field, _, _ in fields):
            raise ValueError('必须保留 {target} 占位符')
        if any(field is not None and (field != 'target' or spec or conversion) for _, field, spec, conversion in fields):
            raise ValueError('只支持 {target} 占位符')
        result = template.format(target=target)
    except (ValueError, KeyError, IndexError) as error:
        raise excel.ConfigurationError(label + '：' + str(error)) from error
    # 避免目标改动后，说明仍残留手写的目标数字。
    if re.search(r'\d', template):
        raise excel.ConfigurationError(label + '：目标数字请使用 {target}，不要手写数字')
    return result


def validate_tables(tables, schema):
    expected_names = {spec['name'] for spec in schema['sheets']}
    if set(tables) != expected_names:
        raise excel.ConfigurationError('缺少配置表或存在未知数据表')
    for spec in schema['sheets']:
        for index, row in enumerate(tables[spec['name']], 5):
            if not isinstance(row, list) or len(row) != len(spec['columns']):
                raise excel.ConfigurationError(f'{spec["name"]}第{index}行：列数不匹配')
    expected_metrics = [[m['id'], m['name'], m['method'], '、'.join(m['scopes']), m['rule'], m['hook'], m['unit'], m['status']] for m in schema['metrics']]
    # 可以排序，不能把尚未实现的新指标伪装成已注册指标。
    if sorted(tables['指标字典'], key=lambda r: str(r[0])) != sorted(expected_metrics, key=lambda r: r[0]):
        raise excel.ConfigurationError('指标字典为程序契约，请勿增删或修改；新增指标需同步程序')
    registry = {m['id']: m for m in schema['metrics']}
    achievements, seen, badge_ids, orders = [], set(), set(), set()
    for number, row in enumerate(tables['成就配置'], 5):
        label = f'成就配置第{number}行'
        key, name, category, tier, template, target, scope, metric, selector, requires, hidden, enabled, badge, order = row
        identifier(key, label + '成就ID')
        if key in seen:
            raise excel.ConfigurationError(label + '：成就ID重复 ' + key)
        seen.add(key)
        text(name, label + '名称', 16)
        if category not in schema['categories'] or tier not in schema['tiers']:
            raise excel.ConfigurationError(label + '：分类或品质无效')
        target = integer(target, label + '目标值', 1, 1_000_000_000)
        if metric not in registry or scope not in registry[metric]['scopes']:
            raise excel.ConfigurationError(label + '：统计指标不存在或不支持该统计范围')
        text(selector, label + '筛选值', 64, optional=True)
        allowed = registry[metric]['filters'].split(',') if registry[metric]['filters'] else []
        if (allowed and selector not in allowed) or (not allowed and selector):
            raise excel.ConfigurationError(label + '：筛选值不匹配指标；指定敌人请填写字典允许的资源ID')
        text(requires, label + '前置成就', 500, optional=True)
        prerequisites = requires.split(',') if requires else []
        for prerequisite in prerequisites:
            identifier(prerequisite, label + '前置成就')
        if len(set(prerequisites)) != len(prerequisites):
            raise excel.ConfigurationError(label + '：前置成就重复')
        identifier(badge, label + '徽章ID')
        if badge in badge_ids:
            raise excel.ConfigurationError(label + '：徽章ID不能被多个成就共用')
        badge_ids.add(badge)
        order = integer(order, label + '排序', 1, 100_000)
        if order in orders:
            raise excel.ConfigurationError(label + '：排序值重复')
        orders.add(order)
        achievements.append(dict(id=key, name=name, category=category, tier=tier,
            description_template=template, description=description(template, target, label + '说明'),
            target=target, scope=schema['scopes'][scope], metric=metric,
            aggregation={'累加': 'sum', '去重计数': 'unique_count', '取最大': 'max'}[registry[metric]['method']],
            filter=selector, prerequisites=prerequisites,
            hidden=bool(integer(hidden, label + '隐藏', 0, 1)),
            enabled=bool(integer(enabled, label + '启用', 0, 1)), badge_id=badge, order=order,
            reward={'type': 'badge', 'id': badge}))
    if not achievements or len(achievements) > 2000:
        raise excel.ConfigurationError('成就配置应有1～2000条记录')
    by_id = {a['id']: a for a in achievements}
    for item in achievements:
        for prerequisite in item['prerequisites']:
            if prerequisite not in by_id:
                raise excel.ConfigurationError(item['id'] + '：前置成就不存在 ' + prerequisite)
            if item['enabled'] and not by_id[prerequisite]['enabled']:
                raise excel.ConfigurationError(item['id'] + '：启用的成就不能依赖停用成就')
    visiting, visited = set(), set()
    def visit(key):
        if key in visiting:
            raise excel.ConfigurationError('成就前置存在循环：' + key)
        if key in visited:
            return
        visiting.add(key)
        for prerequisite in by_id[key]['prerequisites']:
            visit(prerequisite)
        visiting.remove(key)
        visited.add(key)
    for key in by_id:
        visit(key)
    badges, seen = [], set()
    for number, row in enumerate(tables['徽章美术'], 5):
        label = f'徽章美术第{number}行'
        key, motif, engraving, shape, path, size, small = row
        identifier(key, label + '徽章ID')
        if key in seen:
            raise excel.ConfigurationError(label + '：徽章ID重复')
        seen.add(key)
        text(motif, label + '中心图形', 40)
        text(engraving, label + '玉雕细节', 100)
        text(small, label + '小图要求', 100)
        if shape != schema['art']['shape_label'] or integer(size, label + '输出尺寸', 512, 512) != 512:
            raise excel.ConfigurationError(label + '：统一使用512像素玉符自然轮廓')
        text(path, label + '图标路径', 180, optional=True)
        if path:
            parsed = PurePosixPath(path)
            if not path.startswith('assets/achievements/') or '..' in parsed.parts or '\\' in path or parsed.suffix not in ['.png', '.svg'] or str(parsed) != path:
                raise excel.ConfigurationError(label + '：图标路径应为 assets/achievements/ 下的 PNG 或 SVG 相对路径')
        badges.append(dict(id=key, motif=motif, engraving=engraving, shape=schema['art']['shape'],
                           asset_path=path, size=size, small_size_requirement=small,
                           asset_status='assigned' if path else 'pending'))
    if seen != badge_ids:
        raise excel.ConfigurationError('徽章美术与成就必须一一对应。缺少：' + ','.join(sorted(badge_ids-seen)) + '；多余：' + ','.join(sorted(seen-badge_ids)))
    return dict(achievements=sorted(achievements, key=lambda a: a['order']), badges=sorted(badges, key=lambda b: b['id']))


def validate_payload(payload, schema):
    if payload.get('version') != schema['version'] or payload.get('contract') != schema['contract'] or payload.get('runtime_status') != schema['runtime_status']:
        raise excel.ConfigurationError('成就配置版本或契约不匹配')
    result = validate_tables(payload['tables'], schema)
    if any(payload.get(key) != result[key] for key in result):
        raise excel.ConfigurationError('JSON内容与原始配置表不一致')
    if payload.get('metrics') != schema['metrics'] or payload.get('art') != schema['art'] or payload.get('tiers') != schema['tiers']:
        raise excel.ConfigurationError('JSON指标或美术契约不匹配')
    return payload


def upgrade_payload(payload, schema):
    """仅迁移接入前的v1定义元数据；不接触玩家成就存档或改动目标。"""
    if payload.get('version') != 1 or payload.get('contract') != 'huozi.achievements.v1':
        return validate_payload(payload, schema)
    import copy
    tables = copy.deepcopy(payload['tables'])
    tiers = {'铜蚀': '素玉', '银蚀': '青玉', '金蚀': '金縫', '玄蚀': '墨玉'}
    if {r[0] for r in tables['指标字典']} != {m['id'] for m in schema['metrics']}:
        raise excel.ConfigurationError('旧成就指标契约不匹配，无法迁移')
    for row in tables['成就配置']:
        row[3] = tiers.get(row[3], row[3])
    for row in tables['徽章美术']:
        if row[3] != '正六边形蚀刻章':
            raise excel.ConfigurationError('旧成就美术契约不匹配，无法迁移')
        row[3] = schema['art']['shape_label']
    tables['指标字典'] = [[m['id'], m['name'], m['method'], '、'.join(m['scopes']), m['rule'], m['hook'], m['unit'], m['status']] for m in schema['metrics']]
    result = validate_tables(tables, schema)
    return dict(version=schema['version'], contract=schema['contract'], runtime_status=schema['runtime_status'],
                source_sha256=payload.get('source_sha256', ''), tables=tables, metrics=schema['metrics'],
                art=schema['art'], tiers=schema['tiers'], **result)


def main(argv=None):
    parser = argparse.ArgumentParser(description='导入成就条件、目标与玉符美术需求；重启游戏后生效。')
    parser.add_argument('--input', type=Path, default=ROOT / '策划配置/成就配置.xlsx')
    parser.add_argument('--output', type=Path, default=ROOT / 'data/achievements/catalog.json')
    parser.add_argument('--schema', type=Path, default=ROOT / 'data/achievements/schema.json')
    action = parser.add_mutually_exclusive_group()
    action.add_argument('--check', action='store_true', help='只校验，不写入或备份')
    action.add_argument('--restore', action='store_true', help='恢复上次导入前的JSON，不改Excel')
    args = parser.parse_args(argv)
    try:
        schema = json.loads(args.schema.read_text(encoding='utf-8'))
        backup = args.output.with_suffix(args.output.suffix + '.bak')
        if args.restore:
            payload = upgrade_payload(json.loads(backup.read_text(encoding='utf-8')), schema)
        else:
            tables = excel.read_workbook(args.input, schema, validator=lambda tables, _schema: tables)
            result = validate_tables(tables, schema)
            payload = dict(version=schema['version'], contract=schema['contract'], runtime_status=schema['runtime_status'],
                source_sha256=hashlib.sha256(args.input.read_bytes()).hexdigest(), tables=tables,
                metrics=schema['metrics'], art=schema['art'], tiers=schema['tiers'], **result)
        content = (json.dumps(payload, ensure_ascii=False, indent=2, allow_nan=False) + '\n').encode('utf-8')
        if not args.check:
            if not args.restore and args.output.exists():
                previous = args.output.read_bytes()
                upgraded = upgrade_payload(json.loads(previous), schema)
                if json.loads(previous).get('version') != schema['version']:
                    previous = (json.dumps(upgraded, ensure_ascii=False, indent=2, allow_nan=False) + '\n').encode('utf-8')
                excel.atomic_write(backup, previous)
            excel.atomic_write(args.output, content)
        print(('校验通过' if args.check else '恢复成功' if args.restore else '导入成功') + f'：{len(payload["achievements"])}项成就，{len(payload["badges"])}枚徽章，{len(payload["metrics"])}个统计指标。')
        print('成就追踪、跨局存档、主界面总览和解锁提示已接入。导入或恢复后重启游戏生效。')
        return 0
    except (OSError, ValueError, TypeError, KeyError, IndexError, RecursionError, zipfile.BadZipFile, excel.ET.ParseError) as error:
        print('导入失败，当前成就配置未改动：' + str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
