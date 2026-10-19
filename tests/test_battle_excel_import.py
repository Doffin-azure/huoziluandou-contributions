from pathlib import Path
import copy,importlib.util,json,subprocess,sys,tempfile,unittest,zipfile
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/balance'))
import import_battle_excel as m
class BattleExcelTest(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.schema=json.loads((ROOT/'data/balance/battle_schema.json').read_text());cls.book=ROOT/'策划配置/战斗数值.xlsx';cls.tables=m.legacy.read_workbook(cls.book,cls.schema,validator=m.validate_tables)
 def test_default_roundtrip(self):self.assertEqual(len(self.tables),12)
 def bad(self,callback):
  t=copy.deepcopy(self.tables);callback(t)
  with self.assertRaises(m.legacy.ConfigurationError):m.validate_tables(t,self.schema)
 def test_text(self):self.bad(lambda t:t['单字数值'][0].__setitem__(3,'9'))
 def test_boolean(self):self.bad(lambda t:t['单字数值'][0].__setitem__(3,True))
 def test_negative(self):self.bad(lambda t:t['单字数值'][0].__setitem__(3,-1))
 def test_fractional_count(self):self.bad(lambda t:t['单字数值'][0].__setitem__(3,1.2))
 def test_infinite(self):self.bad(lambda t:t['单字数值'][0].__setitem__(3,float('inf')))
 def test_missing(self):self.bad(lambda t:t['单字数值'].pop())
 def test_duplicate(self):self.bad(lambda t:t['单字数值'].append(t['单字数值'][0]))
 def test_readonly(self):self.bad(lambda t:t['单字数值'][0].__setitem__(4,999))
 def test_unknown(self):self.bad(lambda t:t['单字数值'][0].__setitem__(0,'unknown'))
 def test_missing_table(self):self.bad(lambda t:t.pop('污染'))
 def test_decimal_multiplier(self):
  t=copy.deepcopy(self.tables);row=next(r for r in t['状态参数'] if r[0]=='core/vulnerable_mult');row[3]=1.75;self.assertEqual(m.validate_tables(t,self.schema)['状态参数'],t['状态参数'])
 def test_reordered_rows(self):
  t=copy.deepcopy(self.tables);t['单字数值'].reverse();m.validate_tables(t,self.schema)
 def test_atomic_import_restore(self):
  with tempfile.TemporaryDirectory() as d:
   output=Path(d)/'battle.json';args=['--output',str(output),'--schema',str(ROOT/'data/balance/battle_schema.json'),'--input',str(self.book)]
   self.assertEqual(m.main(args),0);before=output.read_bytes();self.assertEqual(m.main(args+['--check']),0);self.assertEqual(output.read_bytes(),before)
   output.write_text('{bad');self.assertEqual(m.main(args),1);self.assertEqual(output.read_text(),'{bad');self.assertEqual(m.main(args+['--restore']),0)
   m.validate_payload(json.loads(output.read_text()),self.schema)
 def test_formula_rejected(self):
  from xml.etree import ElementTree as ET
  with tempfile.TemporaryDirectory() as d:
   output=Path(d)/'bad.xlsx'
   with zipfile.ZipFile(self.book) as z,zipfile.ZipFile(output,'w') as w:
    for name in z.namelist():
     b=z.read(name)
     if name=='xl/worksheets/sheet2.xml':
      root=ET.fromstring(b);cell=root.find('.//m:c[@r="D5"]',m.legacy.NS);ET.SubElement(cell,'{'+m.legacy.NS['m']+'}f').text='1+2';b=ET.tostring(root)
     w.writestr(name,b)
   with self.assertRaisesRegex(m.legacy.ConfigurationError,'公式'):m.legacy.read_workbook(output,self.schema,validator=m.validate_tables)
if __name__=='__main__':unittest.main()
