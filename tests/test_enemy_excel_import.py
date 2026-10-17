"""XLSX parser/validation/atomic import regression. No third-party dependencies."""
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('excel_import', ROOT/'tools/balance/import_excel.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class ImportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.schema = json.loads((ROOT/'data/balance/schema.json').read_text())
        cls.book = ROOT/'策划配置/怪物数值.xlsx'
        cls.tables = module.read_workbook(cls.book, cls.schema)

    def setUp(self):
        self.tables = copy.deepcopy(type(self).tables)

    def rejected(self):
        with self.assertRaises(module.ConfigurationError): module.validate_tables(self.tables, self.schema)

    def test_complete_baseline(self):
        self.assertEqual([len(self.tables[s['name']]) for s in self.schema['sheets']], [29,80,67,4])
        self.assertEqual(self.tables, {s['name']: s['rows'] for s in self.schema['sheets']})

    def test_zero_is_valid(self):
        for row in self.tables['行动']: row[8] = 0
        module.validate_tables(self.tables, self.schema)

    def test_empty_numeric_rejected(self):
        self.tables['怪物'][0][3] = ''; self.rejected()

    def test_negative_rejected(self):
        self.tables['怪物'][0][3] = -1; self.rejected()

    def test_fraction_rejected(self):
        self.tables['行动'][0][6] = 1.5; self.rejected()

    def test_nan_rejected(self):
        self.tables['怪物'][0][3] = float('nan'); self.rejected()

    def test_infinity_rejected(self):
        self.tables['怪物'][0][3] = float('inf'); self.rejected()

    def test_bool_rejected(self):
        self.tables['怪物'][0][3] = True; self.rejected()

    def test_parameter_specific_bounds(self):
        self.tables['机制参数'][0][4] = 17; self.rejected()

    def test_duplicate_rejected(self):
        self.tables['怪物'].append(self.tables['怪物'][0]); self.rejected()

    def test_unknown_id_rejected(self):
        self.tables['怪物'][0][0] = 'missing_enemy'; self.rejected()

    def test_missing_row_rejected(self):
        self.tables['行动'].pop(); self.rejected()

    def test_missing_sheet_rejected(self):
        del self.tables['污染']; self.rejected()

    def test_locked_metadata_rejected(self):
        self.tables['行动'][0][9] = '击'; self.rejected()

    def test_sorting_rows_is_safe(self):
        for rows in self.tables.values(): rows.reverse()
        module.validate_tables(self.tables, self.schema)

    def test_unused_action_field_rejected(self):
        row = next(r for r in self.tables['行动'] if r[0] == 'nest_moth' and r[2] == 1)
        row[5] = 99
        self.rejected()

    def test_formula_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/'formula.xlsx'
            with zipfile.ZipFile(self.book) as source, zipfile.ZipFile(path, 'w') as target:
                for item in source.infolist():
                    data = source.read(item.filename)
                    if item.filename == 'xl/worksheets/sheet2.xml':
                        root = ET.fromstring(data)
                        cell = next(c for c in root.findall('.//m:c', module.NS) if c.attrib['r'] == 'D5')
                        ET.SubElement(cell, '{'+module.NS['m']+'}f').text = '1+1'
                        data = ET.tostring(root)
                    target.writestr(item, data)
            with self.assertRaisesRegex(module.ConfigurationError, '公式'): module.read_workbook(path, self.schema)

    def test_atomic_success_failure_and_restore(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)/'enemies.json'
            self.assertEqual(module.main(['--input',str(self.book),'--output',str(output)]),0)
            before = output.read_bytes(); backup = output.with_suffix('.json.bak').read_bytes()
            self.assertEqual(module.main(['--input',str(self.book),'--output',str(output),'--check']),0)
            self.assertEqual(output.read_bytes(),before)
            self.assertEqual(module.main(['--input',str(Path(directory)/'missing.xlsx'),'--output',str(output)]),1)
            self.assertEqual(output.read_bytes(),before)
            self.assertEqual(output.with_suffix('.json.bak').read_bytes(),backup)
            self.assertEqual(module.main(['--output',str(output),'--restore']),0)
            self.assertEqual(json.loads(output.read_text())['tables'],self.tables)

if __name__ == '__main__': unittest.main()
