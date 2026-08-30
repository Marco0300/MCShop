import json, math
from pathlib import Path

root=Path('/tmp/mcdata')
items=json.loads((root/'items.json').read_text())
recipes=json.loads((root/'recipes.json').read_text())
by_id={int(x['id']):x for x in items}
recipe_by_id={int(k):v for k,v in recipes.items()}
# Seed prices for items which are treated as raw inputs or have no usable recipe.
seed_names={'diamond':100,'emerald':80,'netherite_ingot':500,'netherite_scrap':250,'ancient_debris':300,'nether_star':1000,'heart_of_the_sea':250,'shulker_shell':100,'elytra':1000,'dragon_egg':5000,'dragon_breath':75,'blaze_rod':35,'ender_pearl':30,'ghast_tear':60,'gold_ingot':30,'iron_ingot':15,'copper_ingot':10,'coal':5,'redstone':8,'lapis_lazuli':12,'quartz':10,'amethyst_shard':12,'obsidian':20,'raw_iron':12,'raw_gold':24,'raw_copper':8,'stick':1,'string':3,'leather':5,'wheat':2,'carrot':2,'potato':2,'beetroot':2,'sugar_cane':1,'bamboo':1,'cactus':2,'clay_ball':3,'sand':2,'gravel':2,'flint':4,'cobblestone':1,'stone':2,'dirt':1,'oak_log':5,'spruce_log':5,'birch_log':5,'jungle_log':5,'acacia_log':5,'dark_oak_log':5,'cherry_log':5,'mangrove_log':5}
def seed(item):
 n=item['name']; return seed_names.get(n, 2 if item['stackSize']>1 else 10)
def ingredients(recipe):
 vals=[]
 raw=recipe.get('ingredients',[])
 if 'inShape' in recipe: raw=[v for row in recipe['inShape'] for v in row]
 for v in raw:
  if isinstance(v,int): vals.append((v,1))
  elif isinstance(v,list):
   for x in v:
    if isinstance(x,int): vals.append((x,1)); break
 return vals
def recipe_cost(i,memo,vis):
 if i in memo:return memo[i]
 if i in vis:return None
 vis.add(i); best=None
 for r in recipe_by_id.get(i,[]):
  ing=ingredients(r); out=r.get('result',{}); count=out.get('count',1)
  if not ing or count<=0: continue
  total=0; good=True
  for j,q in ing:
   c=recipe_cost(j,memo,vis)
   if c is None: c=seed(by_id.get(j,{'name':'unknown','stackSize':64}))
   total+=c*q
  total=(total*1.10)/count
  if best is None or total<best: best=total
 vis.remove(i)
 if best is None: best=seed(by_id[i])
 memo[i]=best; return best
memo={}; out={}
for i,item in by_id.items():
 if item['name']=='air': continue
 cost=recipe_cost(i,memo,set()); buy=max(1,math.ceil(cost)); sell=max(1,math.floor(buy*0.70))
 out['minecraft:'+item['name']]={'name':item['displayName'],'buy':buy,'sell':sell,'baseCost':round(cost,2),'source':'vanilla-1.21.1'}
# Lua table, understood by ComputerCraft textutils.unserialize.
def lua(v):
 if isinstance(v,dict): return '{'+','.join('['+json.dumps(k)+']='+lua(x) for k,x in v.items())+'}'
 if isinstance(v,str): return json.dumps(v)
 if isinstance(v,bool): return 'true' if v else 'false'
 if v is None:return 'nil'
 return str(v)
Path('/home/hermes/MCShop/shop_catalog').write_text(lua(out)+'\n')
print('generated',len(out),'catalog entries')
