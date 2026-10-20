from contextlib import redirect_stdout, redirect_stderr
import copy
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/achievements'))
import import_achievements as m


class AchievementImportTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.schema = json.loads((ROOT / 'data/achievements/schema.json').read_text())
        cls.book = ROOT / '策划配置/成就配置.xlsx'
        cls.tables = m.excel.read_workbook(cls.book, cls.schema, validator=lambda t, s: t)

    def bad(self, change, message=None):
        tables = copy.deepcopy(self.tables)
        change(tables)
        with self.assertRaises(m.excel.ConfigurationError) as context:
            m.validate_tables(tables, self.schema)
        if message:
            self.assertIn(message, str(context.exception))

    def cli(self, args):
        with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
            return m.main(args)

    def test_complete_and_sorted(self):
        result = m.validate_tables(copy.deepcopy(self.tables), self.schema)
        self.assertEqual(len(result['achievements']), 48)
        self.assertEqual(len(result['badges']), 48)
        self.assertEqual(len(self.schema['metrics']), 32)
        self.assertEqual(result['achievements'][0]['description'], '累计成功打出1个词。')
        self.assertEqual({a['reward']['type'] for a in result['achievements']}, {'badge'})

    def test_tune_target_and_generated_copy(self):
        tables = copy.deepcopy(self.tables)
        tables['成就配置'][1][5] = 120
        a = m.validate_tables(tables, self.schema)['achievements'][1]
        self.assertEqual(a['target'], 120)
        self.assertEqual(a['description'], '累计成功打出120个词。')

    def test_add_new_achievement_and_badge(self):
        tables = copy.deepcopy(self.tables)
        achievement, badge = copy.deepcopy(tables['成就配置'][0]), copy.deepcopy(tables['徽章美术'][0])
        achievement[0], achievement[12], achievement[13] = 'new_word', 'seal_new_word', 49
        badge[0] = 'seal_new_word'
        tables['成就配置'].append(achievement)
        tables['徽章美术'].append(badge)
        self.assertEqual(len(m.validate_tables(tables, self.schema)['achievements']), 49)

    def test_row_sorting(self):
        tables = {k: list(reversed(v)) for k, v in copy.deepcopy(self.tables).items()}
        self.assertEqual(m.validate_tables(tables, self.schema), m.validate_tables(self.tables, self.schema))

    def test_zero(self): self.bad(lambda t: t['成就配置'][0].__setitem__(5, 0))
    def test_negative(self): self.bad(lambda t: t['成就配置'][0].__setitem__(5, -1))
    def test_fraction(self): self.bad(lambda t: t['成就配置'][0].__setitem__(5, 1.5))
    def test_number_as_text(self): self.bad(lambda t: t['成就配置'][0].__setitem__(5, '1'))
    def test_boolean(self): self.bad(lambda t: t['成就配置'][0].__setitem__(5, True))
    def test_nan(self): self.bad(lambda t: t['成就配置'][0].__setitem__(5, float('nan')))
    def test_limit(self): self.bad(lambda t: t['成就配置'][0].__setitem__(5, 1_000_000_001))
    def test_duplicate_id(self): self.bad(lambda t: t['成就配置'][1].__setitem__(0, 'first_word'), '重复')
    def test_invalid_id(self): self.bad(lambda t: t['成就配置'][0].__setitem__(0, 'BAD id'))
    def test_unknown_metric(self): self.bad(lambda t: t['成就配置'][0].__setitem__(7, 'made_up'), '统计指标')
    def test_wrong_scope(self): self.bad(lambda t: t['成就配置'][0].__setitem__(6, '单次'), '范围')
    def test_wrong_filter(self): self.bad(lambda t: t['成就配置'][0].__setitem__(8, 'boss_lead_plate'), '筛选')
    def test_unknown_boss(self): self.bad(lambda t: t['成就配置'][40].__setitem__(8, 'unknown_boss'), '筛选')
    def test_missing_prerequisite(self): self.bad(lambda t: t['成就配置'][0].__setitem__(9, 'missing'), '不存在')
    def test_self_dependency(self): self.bad(lambda t: t['成就配置'][0].__setitem__(9, 'first_word'), '循环')
    def test_cycle(self): self.bad(lambda t: t['成就配置'][0].__setitem__(9, 'words_1000'), '循环')
    def test_disabled_prerequisite(self): self.bad(lambda t: t['成就配置'][0].__setitem__(11, 0), '停用')
    def test_invalid_flag(self): self.bad(lambda t: t['成就配置'][0].__setitem__(10, 2))
    def test_sort_duplicate(self): self.bad(lambda t: t['成就配置'][1].__setitem__(13, 1), '排序')
    def test_unknown_tier(self): self.bad(lambda t: t['成就配置'][0].__setitem__(3, '传奇'))
    def test_missing_badge(self): self.bad(lambda t: t['徽章美术'].pop(), '一一对应')
    def test_shared_badge(self): self.bad(lambda t: t['成就配置'][1].__setitem__(12, 'seal_first_word'), '共用')
    def test_path_traversal(self): self.bad(lambda t: t['徽章美术'][0].__setitem__(4, 'assets/achievements/../bad.png'), '路径')
    def test_wrong_shape(self): self.bad(lambda t: t['徽章美术'][0].__setitem__(3, '圆形'), '玉符')
    def test_wrong_size(self): self.bad(lambda t: t['徽章美术'][0].__setitem__(5, 64), '512')
    def test_metric_contract(self): self.bad(lambda t: t['指标字典'][0].__setitem__(4, 'new rule'), '契约')
    def test_template_no_target(self): self.bad(lambda t: t['成就配置'][0].__setitem__(4, '累计打出一个词。'), '占位符')
    def test_template_unknown_field(self): self.bad(lambda t: t['成就配置'][0].__setitem__(4, '{target}{wrong}'), '占位符')
    def test_template_format_spec(self): self.bad(lambda t: t['成就配置'][0].__setitem__(4, '{target:03d}'), '占位符')
    def test_template_hardcoded_goal(self): self.bad(lambda t: t['成就配置'][0].__setitem__(4, '累计打出1次，目标{target}'), '手写')
    def test_missing_sheet(self): self.bad(lambda t: t.pop('徽章美术'), '配置表')

    def rewrite(self, target, mutate):
        with zipfile.ZipFile(self.book) as source, zipfile.ZipFile(target, 'w') as dest:
            for name in source.namelist():
                raw = source.read(name)
                if name == 'xl/worksheets/sheet1.xml':
                    root = m.excel.ET.fromstring(raw)
                    mutate(root)
                    raw = m.excel.ET.tostring(root)
                dest.writestr(name, raw)

    def test_reject_formula_from_real_xlsx(self):
        with tempfile.TemporaryDirectory() as d:
            book = Path(d) / 'formula.xlsx'
            def mutate(root):
                cell = root.find('.//m:c[@r="F5"]', m.excel.NS)
                m.excel.ET.SubElement(cell, '{' + m.excel.NS['m'] + '}f').text = '1+1'
            self.rewrite(book, mutate)
            with self.assertRaisesRegex(m.excel.ConfigurationError, '公式'):
                m.excel.read_workbook(book, self.schema, validator=lambda t, s: t)

    def test_import_check_change_restore(self):
        with tempfile.TemporaryDirectory() as d:
            output, modified = Path(d) / 'catalog.json', Path(d) / 'tuned.xlsx'
            base = ['--output', str(output)]
            self.assertEqual(self.cli(base), 0)
            original = output.read_bytes()
            self.assertFalse(output.with_suffix('.json.bak').exists())
            def mutate(root): root.find('.//m:c[@r="F5"]/m:v', m.excel.NS).text = '2'
            self.rewrite(modified, mutate)
            args = base + ['--input', str(modified)]
            self.assertEqual(self.cli(args + ['--check']), 0)
            self.assertEqual(output.read_bytes(), original)
            self.assertEqual(self.cli(args), 0)
            current = json.loads(output.read_text())
            self.assertEqual(current['achievements'][0]['target'], 2)
            self.assertEqual(current['achievements'][0]['description'], '累计成功打出2个词。')
            self.assertEqual(output.with_suffix('.json.bak').read_bytes(), original)
            output.write_text('broken')
            self.assertEqual(self.cli(args), 1)
            self.assertEqual(output.read_text(), 'broken')
            self.assertEqual(output.with_suffix('.json.bak').read_bytes(), original)
            self.assertEqual(self.cli(base + ['--restore']), 0)
            self.assertEqual(json.loads(output.read_text()), json.loads(original))

    def test_invalid_xlsx_preserves_output(self):
        with tempfile.TemporaryDirectory() as d:
            output, invalid = Path(d) / 'catalog.json', Path(d) / 'invalid.xlsx'
            output.write_text('existing')
            invalid.write_text('not a zip file')
            self.assertEqual(self.cli(['--input', str(invalid), '--output', str(output)]), 1)
            self.assertEqual(output.read_text(), 'existing')
            self.assertFalse(output.with_suffix('.json.bak').exists())

    def legacy_payload(self):
        tables = copy.deepcopy(self.tables)
        tiers = {'素玉': '铜蚀', '青玉': '银蚀', '金縫': '金蚀', '墨玉': '玄蚀'}
        for row in tables['成就配置']:
            row[3] = tiers[row[3]]
        for row in tables['徽章美术']:
            row[3] = '正六边形蚀刻章'
        return dict(version=1, contract='huozi.achievements.v1', runtime_status='definitions_only', tables=tables)

    def test_draft_migration_preserves_goals(self):
        migrated = m.upgrade_payload(self.legacy_payload(), self.schema)
        self.assertEqual(migrated['version'], 2)
        self.assertEqual(migrated['runtime_status'], 'tracking_enabled')
        self.assertEqual([a['target'] for a in migrated['achievements']], [r[5] for r in self.tables['成就配置']])
        self.assertEqual({b['shape'] for b in migrated['badges']}, {'natural_jade'})
        self.assertIs(m.validate_payload(migrated, self.schema), migrated)

    def test_draft_backup_can_restore(self):
        with tempfile.TemporaryDirectory() as d:
            output = Path(d) / 'catalog.json'
            output.write_text(json.dumps(self.legacy_payload(), ensure_ascii=False))
            self.assertEqual(self.cli(['--output', str(output)]), 0)
            self.assertEqual(json.loads(output.with_suffix('.json.bak').read_text())['version'], 2)
            output.write_text('broken')
            self.assertEqual(self.cli(['--output', str(output), '--restore']), 0)
            m.validate_payload(json.loads(output.read_text()), self.schema)

    def test_draft_migration_still_rejects_invalid_goals(self):
        legacy = self.legacy_payload()
        legacy['tables']['成就配置'][0][5] = 0
        with self.assertRaises(m.excel.ConfigurationError):
            m.upgrade_payload(legacy, self.schema)


if __name__ == '__main__':
    unittest.main()
