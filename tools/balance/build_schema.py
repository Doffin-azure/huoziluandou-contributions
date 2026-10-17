"""Developer helper: regenerate the Excel contract from resources and mechanic definitions.

Run only when changing the supported configuration structure, not for daily tuning.
"""
import ast
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
# key: (default, minimum, maximum, Chinese label). Defaults preserve the current game.
PARAMS = {
    'shell': {'shield_target': (8, 0, 999, '补纸护盾目标')},
    'fold': {'resolved_damage': (5, 0, 999, '处理目标后伤害'), 'reward': (3, 0, 999, '组词解签奖励伤害')},
    'blank': {'empty_required': (3, 1, 16, '奖励所需空格'), 'reward': (3, 0, 999, '达标奖励伤害'), 'shield_gain': (4, 0, 999, '未达标护盾')},
    'corrosion': {'inject_cap': (3, 1, 16, '同源蚀盘面上限')},
    'glutton': {'stomach_capacity': (3, 1, 16, '吞字容量'), 'release_hit': (10, 1, 999, '吐字所需单段生命伤害'), 'release_material': (3, 1, 16, '吐字所需消耗材料数'), 'swallow_block': (4, 0, 999, '吞字获得护盾'), 'belly_bonus_cap': (3, 0, 16, '腹击附加伤害上限')},
    'furnace': {'heat_threshold': (8, 0, 99, '强化所需热度'), 'heat_bonus': (4, 0, 999, '高热附加伤害'), 'heat_gain': (2, 0, 99, '攻击后升热')},
    'charge': {'energy_required': (2, 1, 99, '所需净储能消费'), 'resolved_damage': (6, 0, 999, '任务完成后伤害'), 'break_block': (6, 0, 999, '任务完成拆盾')},
    'credit': {'resolved_damage': (6, 0, 999, '取得收讫印后伤害'), 'break_block': (8, 0, 999, '取得收讫印后拆盾')},
    'pair': {'resolved_damage': (7, 0, 999, '完整解题伤害'), 'partial_damage': (9, 0, 999, '部分解题或空题伤害'), 'reward': (5, 0, 999, '完整解题奖励伤害'), 'empty_block': (4, 0, 999, '翻签空题护盾')},
    'nest': {'resolved_damage': (7, 0, 999, '入盘组词完成后啄字伤害'), 'break_block': (6, 0, 999, '入盘组词拆盾'), 'inject_cap': (4, 1, 16, '同源连盘面上限'), 'replicate_count': (1, 0, 4, '每枚连每次复制数量'), 'replicate_delay': (1, 1, 9, '新连首次复制前等待玩家回合数')},
    'bomb': {'mark_block': (6, 0, 999, '布印护盾目标'), 'protect_block': (1, 0, 999, '防爆每救回一枚获得持久盾')},
    'copy': {'attack_damage': (10, 0, 999, '复制攻击类伤害'), 'defense_block': (8, 0, 999, '复制防御类护盾'), 'economy_block': (6, 0, 999, '复制经济类护盾'), 'other_block': (3, 0, 999, '无词或其他类护盾')},
    'seal': {'occupied_bonus': (2, 0, 999, '印区每个占用格附加伤害')},
    'wheel': {'required_uses': (2, 1, 9, '同一原实体所需成词次数'), 'resolved_damage': (8, 0, 999, '完成后压印伤害'), 'reward': (8, 0, 999, '完成奖励伤害')},
    'leech': {'steal': (2, 0, 99, '每次偷取储能上限'), 'shield_per_energy': (2, 0, 99, '每点偷取储能转护盾'), 'shield_cap': (8, 0, 999, '护盾上限')},
    'proof': {'phase_percent': (50, 1, 99, '二阶段生命百分比'), 'target_count': (2, 1, 2, '红蓝签目标数量'), 'reward': (3, 0, 999, '每枚成词解签奖励伤害'), 'unresolved_bonus': (2, 0, 999, '每枚未解签附加伤害'), 'phase2_damage': (10, 0, 999, '二阶段朱批基础伤害'), 'phase2_block': (8, 0, 999, '二阶段校勘护盾'), 'phase2_multi_damage': (7, 0, 999, '二阶段双批每段伤害')},
    'rail': {'phase_percent': (50, 1, 99, '二阶段生命百分比'), 'target_count': (3, 1, 4, '一阶段压轨目标数'), 'phase2_target_count': (4, 1, 4, '二阶段压轨目标数'), 'unresolved_bonus': (2, 0, 999, '每枚未撤离目标附加伤害'), 'phase2_damage': (12, 0, 999, '二阶段压轨基础伤害'), 'phase2_block': (10, 0, 999, '二阶段铅铸护盾'), 'phase2_multi_damage': (7, 0, 999, '二阶段双铸每段伤害'), 'clear_break': (8, 0, 999, '全部撤离拆盾')},
    'compiler': {'phase_percent': (50, 1, 99, '二阶段生命百分比'), 'distinct_required': (2, 1, 9, '异文所需不同多字词数'), 'repeat_required': (2, 1, 9, '重文所需同词主动次数'), 'reward': (6, 0, 999, '解题奖励伤害'), 'resolved_damage': (8, 0, 999, '一阶段解题后伤害'), 'phase2_resolved_damage': (10, 0, 999, '二阶段解题后伤害'), 'phase2_damage': (14, 0, 999, '二阶段未解题伤害'), 'fail_block': (6, 0, 999, '一阶段未解题获得护盾'), 'phase2_fail_block': (8, 0, 999, '二阶段未解题获得护盾'), 'phase2_multi_damage': (7, 0, 999, '二阶段收卷每段伤害')},
}

def fields(text):
    result = {}
    for key, value in re.findall(r'^(\w+) = (.+)$', text, re.M):
        if value.startswith('"'): result[key] = json.loads(value)
        elif value in ('true', 'false'): result[key] = value == 'true'
        elif re.fullmatch(r'-?\d+', value): result[key] = int(value)
    return result

def column(name, field, editable=False, low=0, high=999):
    return dict(name=name, field=field, editable=editable, min=low, max=high)

def spawn_metadata():
    """Read the actual expedition pools, not EnemyData.act (which is only an origin tag)."""
    expedition = (ROOT/'src/expedition/expedition.gd').read_text()
    roster = (ROOT/'src/core/enemy_roster.gd').read_text()
    pools = {}
    for const, role in [('NORMAL_STAGES', '小怪'), ('ELITE_STAGES', '精英')]:
        body = re.search(r'const ' + const + r' := (\{.*?^\})', expedition, re.M | re.S)
        for floor, stages in ast.literal_eval(body[1]).items():
            for stage, ids in enumerate(stages):
                for enemy_id in ids:
                    pools.setdefault(enemy_id, []).append((floor, ['前区', '中区', '深区'][stage], role))
    bosses = ast.literal_eval(re.search(r'const BOSSES := (\{[^\n]+\})', roster)[1])
    for floor, enemy_id in bosses.items(): pools.setdefault(enemy_id, []).append((floor, '末尾', 'Boss'))
    result = {}
    for enemy_id, entries in pools.items():
        floors = sorted({floor for floor, zone, role in entries})
        roles = {role for floor, zone, role in entries}
        assert len(roles) == 1, (enemy_id, roles)
        zones = []
        for floor in floors:
            names = [zone for f, zone, role in entries if f == floor]
            zones.append(f'{floor}层' + '、'.join(names))
        result[enemy_id] = ['第' + '、'.join(map(str, floors)) + '层', roles.pop(), '；'.join(zones), '当前投放']
    return result

def main():
    monsters, moves, parameters, pollution = [], [], [], []
    move_editable = {}
    placements = spawn_metadata()
    for path in sorted((ROOT/'resources/enemies').glob('*.tres')):
        text = path.read_text()
        ed = fields(text.split('[resource]')[1])
        meta = placements.get(ed['id'], ['不投放', 'Boss' if ed.get('is_boss') else ('精英' if ed.get('is_elite') else '小怪'), '—', '保留旧怪'])
        monsters.append([ed['id'], ed['name'], meta[0], ed.get('max_hp', 24), ed.get('initial_block', 0), ed.get('mechanic', ''), *meta[1:]])
        sub = {name: fields(body) for name, body in re.findall(r'\[sub_resource[^\]]*id="([^"]+)"\]\n(.*?)(?=\n\[)', text, re.S)}
        order = re.findall(r'SubResource\("([^"]+)"\)', text.split('[resource]')[1])
        for index, name in enumerate(order, 1):
            move = sub[name]
            action = move.get('mechanic_action', '')
            inject = {'corrode': (2, '蚀', 'rush'), 'seed_nest': (1, '连', 'replicate'), 'heat6': (1, '热', 'scorch'), 'heat8': (1, '热', 'scorch'), 'copy': (1, '重', 'block')}.get(action, (move.get('inject_count', 0), move.get('inject_glyph', ''), move.get('pollution_id', '')))
            moves.append([ed['id'], ed['name'], index, move.get('title', '攻击'), action, move.get('damage', 6), move.get('hits', 1), move.get('block', 0), inject[0], inject[1], inject[2], move.get('status_id', ''), move.get('status_stacks', 0)])
            kind = move.get('kind', 0)
            allowed = []
            if kind in (0, 2, 5) and action != 'corrode': allowed.append(5)
            if (kind in (0, 5) and action != 'corrode') or action == 'copy': allowed.append(6)
            if kind in (1, 2): allowed.append(7)
            if kind == 6 or action in ('corrode', 'seed_nest', 'heat6', 'heat8', 'copy'): allowed.append(8)
            if kind in (3, 4): allowed.append(12)
            move_editable[f"{ed['id']}/{index}"] = allowed
        for key, (value, low, high, label) in PARAMS.get(ed.get('mechanic'), {}).items():
            parameters.append([ed['id'], ed['name'], key, label, value, low, high])
    for path in sorted((ROOT/'resources/pollutions').glob('*.tres')):
        pd = fields(path.read_text().split('[resource]')[1])
        pollution.append([pd['id'], pd['name'], pd.get('hp_loss_on_play', 0), pd.get('draw_penalty_on_play', 0)])
    specs = [
        dict(name='怪物', key=[0], columns=[column('怪物ID','id'),column('怪物','name'),column('出现层数','spawn_floors'),column('生命','max_hp',True,1,9999),column('开场护盾','initial_block',True),column('机制标识','mechanic'),column('怪物类型','enemy_role'),column('投放区域','spawn_zones'),column('投放状态','spawn_status')], rows=monsters),
        dict(name='行动', key=[0,2], editable_by_key=move_editable, columns=[column('怪物ID','id'),column('怪物','name'),column('行动序号','index'),column('行动名','title'),column('机制动作','action'),column('基础伤害','damage',True),column('攻击段数','hits',True,1,20),column('护盾','block',True),column('塞字数量','inject_count',True,0,16),column('塞入字','inject_glyph'),column('污染类型','pollution_id'),column('状态类型','status_id'),column('状态层数','status_stacks',True,0,99)], rows=moves),
        dict(name='机制参数', key=[0,2], columns=[column('怪物ID','id'),column('怪物','name'),column('参数ID','parameter'),column('参数说明','label'),column('数值','value',True,0,9999),column('最小值','min'),column('最大值','max')], rows=parameters),
        dict(name='污染', key=[0], columns=[column('污染ID','id'),column('污染','name'),column('打出损失生命','hp_loss_on_play',True,0,99),column('打出下次少补字','draw_penalty_on_play',True,0,16)], rows=pollution),
    ]
    schema = dict(version=2, sheets=specs)
    (ROOT/'data/balance/schema.json').write_text(json.dumps(schema, ensure_ascii=False, indent=2)+'\n')
    print('schema:', ', '.join(f"{s['name']} {len(s['rows'])}行" for s in specs))

if __name__ == '__main__': main()
