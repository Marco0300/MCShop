#!/usr/bin/env python3
import re, urllib.request
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
ROOT=Path(__file__).parent; catalog=(ROOT/'shop_catalog').read_text(); ids=sorted(set(re.findall(r'\["(minecraft:[a-z0-9_./-]+)"\]',catalog))); out=ROOT/'web_assets'/'items'; out.mkdir(parents=True,exist_ok=True); base='https://raw.githubusercontent.com/InventivetalentDev/minecraft-assets/1.21.1/assets/minecraft/textures/'
def one(item):
 name=item.split(':',1)[1]; target=out/(name+'.png'); target.parent.mkdir(parents=True,exist_ok=True)
 if target.exists(): return True
 for folder in ('item','block'):
  try:
   with urllib.request.urlopen(base+folder+'/'+name+'.png',timeout=5) as r: target.write_bytes(r.read()); return True
  except Exception: pass
 return False
with ThreadPoolExecutor(max_workers=24) as ex:
 results=list(ex.map(one,ids))
print(f'downloaded/available {sum(results)}, unavailable {len(ids)-sum(results)}, total {len(ids)}')
