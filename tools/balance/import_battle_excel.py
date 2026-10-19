#!/usr/bin/env python3
"""策划总表 -> 单个原子 JSON；仅 Python 3 标准库，无 Office/网络依赖。"""
import argparse,hashlib,json,math,sys,zipfile
from pathlib import Path
import import_excel as legacy
ROOT=Path(__file__).resolve().parents[2]

def validate_tables(tables,schema):
 if set(tables)!={s['name'] for s in schema['sheets']}:raise legacy.ConfigurationError('配置表不完整或有未知表')
 for spec in schema['sheets']:
  expected={legacy.key_of(row,spec):row for row in spec['rows']};seen=set()
  for n,row in enumerate(tables[spec['name']],5):
   loc=f'{spec["name"]}第{n}行'
   if len(row)!=len(spec['columns']):raise legacy.ConfigurationError(loc+'列数错误')
   key=legacy.key_of(row,spec)
   if key not in expected or key in seen:raise legacy.ConfigurationError(loc+'未知或重复ID')
   seen.add(key)
   for i,col in enumerate(spec['columns']):
    v=row[i];editable=col['editable'] and ('editable_by_key' not in spec or i in spec['editable_by_key']['/'.join(map(str,key))])
    if not editable:
     if v!=expected[key][i]:raise legacy.ConfigurationError(loc+'「'+col['name']+'」灰色标识或说明不可修改')
     continue
    low,high,integer=col['min'],col['max'],True
    if spec.get('parameter_table'):
     meta=schema['params'][row[0]];low,high,integer=meta['min'],meta['max'],meta['integer']
    elif spec['name']=='机制参数':low,high=expected[key][5:7]
    if isinstance(v,bool) or not isinstance(v,(int,float)) or not math.isfinite(v) or (integer and v!=int(v)) or not low<=v<=high:raise legacy.ConfigurationError(loc+'「'+col['name']+f'」应为范围{low}～{high}的'+('整数' if integer else '数值'))
    row[i]=int(v) if integer else float(v)
  if seen!=set(expected):raise legacy.ConfigurationError(spec['name']+'缺少记录')
 return tables

def validate_payload(data,schema):
 if not isinstance(data,dict) or data.get('version')!=schema['version'] or data.get('contract')!=schema['contract']:raise legacy.ConfigurationError('配置版本或参数契约不匹配')
 validate_tables(data['tables'],schema);return data

def main(argv=None):
 p=argparse.ArgumentParser(description='一键校验并导入全部战斗数值；保存Excel、导入成功后重新启动游戏生效。')
 p.add_argument('--input',type=Path,default=ROOT/'策划配置/战斗数值.xlsx');p.add_argument('--output',type=Path,default=ROOT/'data/balance/battle.json');p.add_argument('--schema',type=Path,default=ROOT/'data/balance/battle_schema.json');p.add_argument('--check',action='store_true');p.add_argument('--restore',action='store_true');a=p.parse_args(argv)
 try:
  schema=json.loads(a.schema.read_text());backup=a.output.with_suffix('.json.bak')
  if a.restore:data=validate_payload(json.loads(backup.read_text()),schema)
  else:
   tables=legacy.read_workbook(a.input,schema,validator=validate_tables)
   data={'version':schema['version'],'contract':schema['contract'],'source_sha256':hashlib.sha256(a.input.read_bytes()).hexdigest(),'tables':tables}
  content=(json.dumps(data,ensure_ascii=False,indent=2,allow_nan=False)+'\n').encode()
  if not a.check:
   if not a.restore:
    previous=a.output.read_bytes() if a.output.exists() else (json.dumps({'version':schema['version'],'contract':schema['contract'],'tables':{s['name']:s['rows'] for s in schema['sheets']}},ensure_ascii=False)+'\n').encode()
    validate_payload(json.loads(previous),schema)
    legacy.atomic_write(backup,previous)
   legacy.atomic_write(a.output,content)
  print(('校验通过' if a.check else ('恢复成功' if a.restore else '导入成功'))+f'：{len(schema["sheets"])}张数值表，共{sum(map(len,data["tables"].values()))}行。')
  if not a.check:print('关闭并重新启动游戏后生效。Excel、Mac与Windows脚本同目录移动也可使用。')
  return 0
 except (OSError,ValueError,TypeError,KeyError,IndexError,zipfile.BadZipFile,legacy.ET.ParseError) as error:
  print('导入失败，游戏配置未改动：'+str(error),file=sys.stderr);return 1
if __name__=='__main__':sys.exit(main())
