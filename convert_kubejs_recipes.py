#!/usr/bin/env python3
"""Convert KubeJS recipe export JSON into an MCShop catalog JSON file.

Usage: python3 convert_kubejs_recipes.py mcshop_recipes.json mcshop_import.json
"""
import json, math, re, sys
from pathlib import Path

SEEDS = {
    'diamond':100,'emerald':80,'netherite_ingot':500,'netherite_scrap':250,
    'ancient_debris':300,'nether_star':1000,'heart_of_the_sea':250,
    'shulker_shell':100,'elytra':1000,'dragon_egg':5000,'blaze_rod':35,
    'ender_pearl':30,'ghast_tear':60,'gold_ingot':30,'iron_ingot':15,
    'copper_ingot':10,'coal':5,'redstone':8,'lapis_lazuli':12,'quartz':10,
    'amethyst_shard':12,'obsidian':20,'raw_iron':12,'raw_gold':24,
    'raw_copper':8,'stick':1,'string':3,'leather':5,'wheat':2,'carrot':2,
    'potato':2,'beetroot':2,'sugar_cane':1,'bamboo':1,'cactus':2,
    'clay_ball':3,'sand':2,'gravel':2,'flint':4,'cobblestone':1,'stone':2,
    'dirt':1,'oak_log':5,'spruce_log':5,'birch_log':5,'jungle_log':5,
    'acacia_log':5,'dark_oak_log':5,'cherry_log':5,'mangrove_log':5,
}
MULTIPLIER = 5.0
SELL_RATE = 0.70
CRAFT_FEE = 0.10

def item_id(x):
    if isinstance(x, str): return x
    if isinstance(x, dict): return x.get('item') or x.get('id')
    return None

def count(x):
    if isinstance(x, dict): return float(x.get('count', 1))
    return 1.0

def ingredient_list(data):
    out=[]
    def add(x):
        if isinstance(x, list):
            for y in x: add(y)
        elif isinstance(x, dict):
            i=item_id(x)
            if i and ':' in i: out.append((i, count(x)))
            elif x.get('tag'):
                out.append(('#'+x['tag'], count(x)))
        elif isinstance(x,str) and ':' in x: out.append((x,1.0))
    if 'ingredients' in data: add(data['ingredients'])
    if 'ingredient' in data: add(data['ingredient'])
    if 'key' in data and 'pattern' in data:
        keys=data['key'];
        for row in data['pattern']:
            for ch in row:
                if ch!=' ' and ch in keys: add(keys[ch])
    # Sequenced assembly consumes its base and sequence inputs per loop.
    if data.get('type')=='create:sequenced_assembly':
        loops=float(data.get('loops',1)); seq=[]
        for step in data.get('sequence',[]):
            seq.extend(ingredient_list(step))
        out.extend((i,q*loops) for i,q in seq)
        base=data.get('ingredient')
        if base: add(base)
    return out

def results(data):
    raw=data.get('results') or data.get('result') or []
    if not isinstance(raw,list): raw=[raw]
    out=[]
    for x in raw:
        i=item_id(x)
        if i and ':' in i: out.append((i,count(x)))
    return out

def display(i):
    n=i.split(':',1)[-1].replace('_',' ')
    return ' '.join(w.capitalize() for w in n.split())

def seed(i):
    return SEEDS.get(i.split(':',1)[-1], 2.0)

def tag_cost(tag):
    t=tag.lower()
    for key,value in SEEDS.items():
        if key in t: return value
    if 'wood' in t or 'rod' in t or 'planks' in t or 'logs' in t: return SEEDS['stick']
    if 'plate' in t: return SEEDS.get('iron_ingot',15)
    if 'nugget' in t: return SEEDS.get('iron_ingot',15)/9
    if 'ingot' in t: return SEEDS.get('iron_ingot',15)
    return 2.0

def main(src,dst):
    data=json.loads(Path(src).read_text())
    recipes=data.get('recipes',[]); graph={}
    for r in recipes:
        d=r.get('json',{})
        ing=ingredient_list(d); res=results(d)
        if ing and res:
            for out,qty in res:
                graph.setdefault(out,[]).append((ing,qty))
    memo={}
    def cost(i,stack=None):
        if i in memo:return memo[i]
        if stack is None: stack=set()
        if i in stack:return seed(i)
        if i.split(':',1)[-1] in SEEDS: memo[i]=seed(i); return memo[i]
        best=None
        for ing,outqty in graph.get(i,[]):
            total=0
            for ii,q in ing: total += (tag_cost(ii[1:]) if ii and ii.startswith('#') else cost(ii,stack|{i}))*q
            value=(total/outqty)*(1+CRAFT_FEE)
            best=value if best is None else min(best,value)
        memo[i]=best if best is not None else seed(i)
        return memo[i]
    catalog={}
    for i in sorted(graph):
        c=cost(i); buy=max(1,math.ceil(c*MULTIPLIER)); catalog[i]={'name':display(i),'buy':buy,'sell':max(1,math.floor(buy*SELL_RATE)),'baseCost':round(c,2),'source':'kubejs'}
    Path(dst).write_text(json.dumps(catalog,indent=2,sort_keys=True)+'\n')
    print(f'Wrote {len(catalog)} priced recipe outputs to {dst}')

if __name__=='__main__':
    if len(sys.argv)!=3: raise SystemExit('usage: convert_kubejs_recipes.py input.json output.json')
    main(sys.argv[1],sys.argv[2])
