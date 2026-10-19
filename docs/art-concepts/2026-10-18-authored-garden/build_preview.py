"""An authored spatial study, independent of the game's map generator.

Rebuilds the editable SVG, JSON and self-contained HTML. Uses only the Python
standard library. Coordinates are concept-grid units, not runtime nav cells.
"""
from pathlib import Path
from html import escape
import json
import math

OUT = Path(__file__).resolve().parent
S = 20
OX, OY = 88, 122
WIDTH, HEIGHT = 1270, 1160


def point(p):
    return (OX + p[0] * S, OY + p[1] * S)


def xy(p):
    x, y = point(p)
    return f'{x:g},{y:g}'


def attrs(values):
    return ' '.join(f'{key.replace("_", "-")}="{escape(str(value), quote=True)}"' for key, value in values.items())


def tag(name, content='', **kw):
    return f'<{name} {attrs(kw)}>{content}</{name}>'


def poly(points, **kw):
    return tag('polygon', points=' '.join(xy(p) for p in points), **kw)


def line(points, **kw):
    return tag('polyline', points=' '.join(xy(p) for p in points), fill='none', **kw)


def rect(x, y, w, h, **kw):
    px, py = point((x, y))
    return tag('rect', x=px, y=py, width=w*S, height=h*S, **kw)


def text(p, value, size=15, color='#323a35', anchor='middle', **kw):
    x, y = point(p)
    return tag('text', escape(value), x=x, y=y, font_size=size, fill=color, text_anchor=anchor, **kw)


POND = [
    [8,16],[12,14.7],[19.5,15],[23.8,14.2],[24.9,14.1],
    [25.2,12.2],[26.8,12.2],[27.5,14.4],[26.5,15.5],
    [28,18],[27.5,21],[28.7,23.3],[28.5,27.7],[26.5,30],
    [23.5,30.8],[21.8,32],[18,31.5],[16.8,33.3],[18,35.5],
    [16.5,37.5],[13,37.6],[11.5,35.8],[13,34.2],[13,33],
    [10,32.5],[8.5,29.8],[8,26],[6.5,24],[7,20],
]

# Architectural masses are deliberately different from event regions.
BUILDINGS = [
    {'id':'gatehouse','name':'门屋','rect':[44,41,6,4],'axis':'h','asset':'gate / screen'},
    {'id':'front_hall','name':'迎字厅','rect':[43,30,9,4],'axis':'h','asset':'hall'},
    {'id':'turn_gallery','name':'转廊','rect':[39,25.5,4,4],'axis':'v','asset':'covered_walk'},
    {'id':'south_gallery','name':'南廊','rect':[28,31.4,11,2.8],'axis':'h','asset':'covered_walk'},
    {'id':'ask_study','name':'问字轩','rect':[32,22.2,4.8,3.1],'axis':'h','asset':'shrine / small_loft'},
    {'id':'treasure_pavilion','name':'藏字水榭','rect':[28,24,4,4],'axis':'h','asset':'water_pavilion'},
    {'id':'shop','name':'字肆','rect':[34.5,18.8,5,3.1],'axis':'h','asset':'stall'},
    {'id':'shop_store','name':'后库','rect':[39.5,18.8,2.5,3.1],'axis':'v','asset':'small_loft'},
    {'id':'east_study','name':'东书斋','rect':[45,24.1,6,3.9],'axis':'h','asset':'small_loft'},
    {'id':'moon_study','name':'听雨书屋','rect':[29.5,12.5,4.5,4.3],'axis':'h','asset':'small_loft'},
    {'id':'stele_house','name':'碑堂','rect':[34.5,10.8,6.5,2.3],'axis':'h','asset':'hall / tomb'},
    {'id':'merge_hall','name':'折桂厅','rect':[43,13,8,5],'axis':'h','asset':'hall'},
    {'id':'north_study','name':'后书院','rect':[45,5.2,6,3.8],'axis':'h','asset':'small_loft'},
    {'id':'library','name':'藏经阁','rect':[34,2.8,7,2.5],'axis':'h','asset':'small_loft'},
    {'id':'north_shrine','name':'镇碑堂','rect':[34,6.3,7,2.1],'axis':'h','asset':'hall / tomb'},
    {'id':'last_rest','name':'息灯水榭','rect':[26,7,6,5],'axis':'h','asset':'water_pavilion / ghost_fire'},
    {'id':'boss_hall','name':'后殿','rect':[9,3,15,7],'axis':'h','asset':'hall / beast_gate'},
    {'id':'west_view','name':'听石轩','rect':[3.6,33.8,6,3.2],'axis':'h','asset':'square_pavilion'},
]

NODES = [
    ('start','start','门屋整备',[47,43],'门屋与照壁后的前庭共用一个入口组团。'),
    ('opening_1','battle','迎字厅',[47,32],'穿厅进入；厅前空地不再另围一圈完整院墙。'),
    ('opening_2','battle','转廊石庭',[41,27.5],'从前厅侧廊折入。清场后在相邻的南廊口、夹院门择路。'),
    ('g0_b0_0','battle','南廊守卫',[33,32.8],'战斗发生在廊与岸边平台；沿池的一整段建筑承担同一空间。'),
    ('g0_b0_1','rest','临水小亭',[26,34.5],'小亭靠岸，近观水尾；北侧短桥接水榭南门。'),
    ('g0_b1_0','battle','夹院守卫',[36.5,28],'问字轩、转廊和南廊围出的夹院，借用三侧建筑边界。'),
    ('g0_b1_1','event','问字轩',[34,23.6],'轩内问碑，从侧门看见水榭，过折廊由东侧进入。'),
    ('treasure_merge','treasure','藏字水榭',[30,26],'两支分别由南门与东门汇入；出北门进入沿池廊。'),
    ('g1_b0_0','shop','字肆',[37,20.5],'字摊和后库组成连续店面，前廊与庭地是同一组团。'),
    ('g1_b0_1','event','东书斋前院',[47,23],'穿过共墙月门到书斋前院；北行穿厅进入汇合厅。'),
    ('g1_b1_0','event','听雨书屋',[32,15.5],'沿池廊入书屋；这一支更贴近水面，与字肆支线隔墙相邻。'),
    ('g1_b1_1','elite','镇碑夹庭',[37.5,14.5],'碑堂与字肆之间的紧凑夹庭，横向出门接折桂厅。'),
    ('battle_merge','battle','折桂厅',[47,16],'一支从南门穿堂，一支从西侧院门进入，清场后开北门。'),
    ('g2_b0_0','elite','镇碑堂前庭',[37,9.2],'从折桂厅侧门沿夹道进入，单个高风险节点后可到息灯水榭。'),
    ('g2_b1_0','event','后书院',[48,7.2],'东侧套院，和镇碑堂共用界墙，不设置院外长联络路。'),
    ('g2_b1_1','battle','藏经阁',[37.5,4],'经后书院北侧楼廊到阁内，再从西廊折入水榭。'),
    ('last_rest','rest','息灯水榭',[29,9.5],'两支从北、东两门汇合；西南出口到后殿前庭。'),
    ('boss','boss','后殿',[17,7],'后殿和临池前庭构成终点组团；入口在前庭东侧。'),
]

KINDS = {'start':'起点','battle':'普通战','elite':'精英','event':'事件','shop':'商店','treasure':'宝藏','rest':'火堆','boss':'首领'}
GROUPS = [
    {'id':0,'source':'opening_2','merge':'treasure_merge','label':'南廊 / 夹院','branches':[['g0_b0_0','g0_b0_1'],['g0_b1_0','g0_b1_1']], 'options':['沿池南廊 · 普通战＋火堆','穿过夹院 · 普通战＋事件']},
    {'id':1,'source':'treasure_merge','merge':'battle_merge','label':'字肆 / 书屋','branches':[['g1_b0_0','g1_b0_1'],['g1_b1_0','g1_b1_1']], 'options':['字肆前廊 · 商店＋事件','沿池书屋 · 事件＋精英']},
    {'id':2,'source':'battle_merge','merge':'last_rest','label':'镇碑堂 / 后书院','branches':[['g2_b0_0'],['g2_b1_0','g2_b1_1']], 'options':['镇碑堂 · 精英，路程较短','后书院 · 事件＋普通战']},
]
NODE_MAP = {n[0]: {'id':n[0],'kind':n[1],'name':n[2],'at':n[3],'description':n[4],'number':i+1} for i,n in enumerate(NODES)}

EDGES = []


def edge(a,b,points=(),group=None,branch=None):
    EDGES.append({'from':a,'to':b,'group':group,'branch':branch,'points':[NODE_MAP[a]['at'],*points,NODE_MAP[b]['at']]})


edge('start','opening_1',[[49,43],[49,36],[47,36]])
edge('opening_1','opening_2',[[47,29.5],[41,29.5]])
edge('opening_2','g0_b0_0',[[41,32.8]],0,0)
edge('g0_b0_0','g0_b0_1',[[30,32.8],[30,34.5]],0,0)
edge('g0_b0_1','treasure_merge',[[26,30],[30,30]],0,0)
edge('opening_2','g0_b1_0',[[38,27.5],[38,28]],0,1)
edge('g0_b1_0','g0_b1_1',[[36.5,26],[34,26]],0,1)
edge('g0_b1_1','treasure_merge',[[34,26]],0,1)
edge('treasure_merge','g1_b0_0',[[30,18],[33,18],[33,20.5]],1,0)
edge('g1_b0_0','g1_b0_1',[[41.5,20.5],[41.5,23]],1,0)
edge('g1_b0_1','battle_merge',[[49,23],[49,19],[47,19]],1,0)
edge('treasure_merge','g1_b1_0',[[30,18],[30,15.5]],1,1)
edge('g1_b1_0','g1_b1_1',[[32,12],[37.5,12]],1,1)
edge('g1_b1_1','battle_merge',[[41.8,14.5],[41.8,16]],1,1)
edge('battle_merge','g2_b0_0',[[47,12],[42,12],[42,9.2]],2,0)
edge('g2_b0_0','last_rest',[[32.5,9.2],[32.5,9.5]],2,0)
edge('battle_merge','g2_b1_0',[[49,16],[49,10],[48,10]],2,1)
edge('g2_b1_0','g2_b1_1',[[48,3.8],[37.5,3.8]],2,1)
edge('g2_b1_1','last_rest',[[29,4]],2,1)
edge('last_rest','boss',[[29,12],[25,12],[17,12]])

# Gate markers represent actual openings, rather than points on abstract edges.
GATES = [
    {'id':'A0-in','at':[41,30.3],'axis':'h','group':0,'branch':0},
    {'id':'A0-out','at':[30,28.3],'axis':'h','group':0,'branch':0},
    {'id':'A1-in','at':[38.8,27.5],'axis':'v','group':0,'branch':1},
    {'id':'A1-out','at':[32.2,26],'axis':'v','group':0,'branch':1},
    {'id':'B0-in','at':[33,19.3],'axis':'h','group':1,'branch':0},
    {'id':'B0-out','at':[47,18.2],'axis':'h','group':1,'branch':0},
    {'id':'B1-in','at':[30,17.5],'axis':'h','group':1,'branch':1},
    {'id':'B1-out','at':[42.8,16],'axis':'v','group':1,'branch':1},
    {'id':'C0-in','at':[43.2,12],'axis':'v','group':2,'branch':0},
    {'id':'C0-out','at':[32.3,9.5],'axis':'v','group':2,'branch':0},
    {'id':'C1-in','at':[49,12.5],'axis':'h','group':2,'branch':1},
    {'id':'C1-out','at':[29,6.2],'axis':'h','group':2,'branch':1},
]

WALLS = [
    # One outer perimeter, with an entrance in its south side.
    [[3,2],[53,2],[53,45.8],[49,45.8]],
    [[45,45.8],[3,45.8],[3,2]],
    # Shared internal boundaries. Gaps coincide with a door or a corridor end.
    [[42.8,4.6],[42.8,10.9]], [[42.8,13],[42.8,15]],
    [[42.8,17],[42.8,21.9]], [[42.8,24.1],[42.8,29.8]],
    [[32.6,5.6],[42.7,5.6]],
    [[33.3,10.3],[41.8,10.3]],
    [[34.2,17.6],[42.4,17.6]],
    [[31.8,18.8],[31.8,24.7]],
    [[36.8,23.8],[42.8,23.8]],
    [[42.8,24.1],[45,24.1]], [[51.2,24.1],[53,24.1]],
    [[32.3,28.3],[32.3,30.3],[38.8,30.3]],
    [[33.2,25.9],[33.2,24.9]],
    [[38.8,29.8],[38.8,32.5]],
    [[40,35],[40,42],[43.7,42]],
    [[51.4,28.5],[51.4,30]],
    [[9.2,10.3],[9.2,14.2],[24.7,14.2],[24.7,13]],
    [[24.7,11],[24.7,3]],
    [[3.2,32.9],[10,32.9],[10,34]],
    [[10,37],[10,39.5],[3.2,39.5]],
]

GALLERIES = [
    [[49,40.8],[49,34]],
    [[47,29.5],[41,29.5]],
    [[41,29.5],[41,32.8],[39,32.8]],
    [[28,32.8],[26,32.8]],
    [[30,24],[30,18],[32.7,18]],
    [[32,17],[32,12]],
    [[34,12],[37.5,12]],
    [[41,16],[43,16]],
    [[51,23],[51,18]],
    [[47,13],[47,12],[42,12],[42,9.2],[41,9.2]],
    [[32.5,9.5],[32,9.5]],
    [[48,5.2],[48,3.8],[41,3.8]],
    [[34,3.8],[29,3.8],[29,7]],
    [[29,12],[25,12],[17,12],[17,10]],
]

PATHS = [
    [[44,43],[42,43],[42,37],[44,37]],
    [[26,34.5],[23.5,35.7],[22,38],[19,40],[13,40],[9,38]],
    [[9,38],[6,31],[5.7,26],[5.5,19],[6,13],[9,11]],
    [[27,13],[26,14],[26.6,17]],
]

# Deliberate asymmetry: broad water, dense architecture, planted rocky shore.
ROCKERIES = [
    [[4,6],[6,4.2],[8.3,5.6],[8.2,9.5],[6.8,12.5],[4.2,13.2]],
    [[5,16],[6.1,15],[7,16.8],[6.3,21],[4.5,24],[4,21]],
    [[5,28],[6.8,27],[7.2,31.1],[9,33],[8.5,34],[5.6,32.3]],
    [[10,39],[11.2,37.8],[13.7,39.5],[16.1,39],[17,41],[14,43],[10.5,42]],
    [[18,38],[20,37.4],[22,38.3],[23,40.2],[26,41],[27,43.7],[22,43],[18.8,41.8]],
    [[20,33],[21,32.7],[22.3,34],[21.8,36.6],[20,36.8],[19.1,35.1]],
    [[24,18],[25.1,17.3],[26,18.2],[25.8,19.6],[24.8,19.3]],
]
TREES = [
    (5.8,5.4,1.35,'pine'),(5.2,10,1.1,'pine'),(6.2,13,1.1,'maple'),
    (4.7,18,1.05,'pine'),(5,26,1.2,'pine'),(7,31.3,1.15,'maple'),
    (11,41.5,1.35,'pine'),(14.2,42.5,1.4,'pine'),(18,42.2,1.15,'maple'),
    (20.3,39,1.2,'pine'),(23.3,42.5,1.3,'pine'),(26,43,1.25,'maple'),
    (29,40.5,1.3,'pine'),(32.4,38.2,1.1,'maple'),(38.4,37.5,1.1,'pine'),
    (42,39.8,.8,'maple'),(51.3,37.2,.8,'pine'),(51.5,40.5,.8,'maple'),
    (44,20.2,.65,'maple'),(50.8,21,.6,'pine'),(35,27.2,.65,'maple'),
    (35.4,16.4,.65,'pine'),(50.8,10.9,.72,'maple'),(33.3,8.8,.55,'pine'),
    (11,12.5,.65,'pine'),(22.5,12.8,.6,'maple'),(17.5,13.4,.45,'pine'),
]


def roof(b):
    x,y,w,h=b['rect']
    chunks=[rect(x-.16,y-.16,w+.32,h+.32,fill='#b5b2a1',stroke='#293a36',stroke_width=2.5)]
    if b['axis']=='h':
        chunks += [poly([[x,y],[x+w,y],[x+w-.3,y+h/2],[x+.3,y+h/2]],fill='#46534d',stroke='#263a34',stroke_width=1),
                   poly([[x+.3,y+h/2],[x+w-.3,y+h/2],[x+w,y+h],[x,y+h]],fill='#63726a',stroke='#263a34',stroke_width=1),
                   line([[x+.15,y+h/2],[x+w-.15,y+h/2]],stroke='#1b2a28',stroke_width=3)]
        for i in range(1,int(w*2)):
            xx=x+i*.5
            chunks.append(line([[xx,y+.12],[xx,y+h-.12]],stroke='#a6b0a0',stroke_width=.6,opacity='.28'))
    else:
        chunks += [poly([[x,y],[x+w/2,y+.25],[x+w/2,y+h-.25],[x,y+h]],fill='#46534d',stroke='#263a34',stroke_width=1),
                   poly([[x+w/2,y+.25],[x+w,y],[x+w,y+h],[x+w/2,y+h-.25]],fill='#63726a',stroke='#263a34',stroke_width=1),
                   line([[x+w/2,y+.1],[x+w/2,y+h-.1]],stroke='#1b2a28',stroke_width=3)]
        for i in range(1,int(h*2)):
            yy=y+i*.5
            chunks.append(line([[x+.12,yy],[x+w-.12,yy]],stroke='#a6b0a0',stroke_width=.6,opacity='.28'))
    return tag('g',''.join(chunks),class_='roof',data_building=b['id'])


def tree(x,y,r,kind):
    points=[]
    for i in range(24):
        a=i*math.tau/24
        rr=r*(.88+.12*math.sin(i*2.7+x))
        points.append([x+math.cos(a)*rr,y+math.sin(a)*rr])
    color='#985f4c' if kind=='maple' else '#78856a'
    return poly(points,fill=color,stroke='#394d3c',stroke_width=1.6,opacity='.93')+line([[x-r*.42,y+r*.4],[x,y],[x+r*.24,y-r*.48]],stroke='#3e4b3b',stroke_width=1.2)


def gate(g,closed=False):
    x,y=g['at'];dx,dy=(.57,0) if g['axis']=='h' else (0,.57)
    parts=[line([[x-dx,y-dy],[x+dx,y+dy]],stroke='#d4bd8d',stroke_width=7),
           line([[x-dx,y-dy],[x+dx,y+dy]],stroke='#694b36',stroke_width=1.6)]
    if closed:
        parts=[line([[x-dx,y-dy],[x+dx,y+dy]],stroke='#9c403c',stroke_width=8),
               text([x,y+.2],'×',15,'#fff2d3')]
    return tag('g',''.join(parts),class_='gate-closed' if closed else 'gate-open',data_group=g['group'],data_branch=g['branch'],data_gate=g['id'])


def architectural_svg():
    defs='''<defs>
    <pattern id="water" width="64" height="45" patternUnits="userSpaceOnUse"><path d="M6 12h17m10 22h19" fill="none" stroke="#567d78" stroke-width="1" opacity=".36"/></pattern>
    <pattern id="paving" width="28" height="23" patternUnits="userSpaceOnUse"><path d="M0 0h28v23" fill="none" stroke="#878b7a" stroke-width=".65" opacity=".26"/></pattern>
    <pattern id="raked" width="8" height="8" patternUnits="userSpaceOnUse"><path d="M0 8L8 0" stroke="#929b81" stroke-width=".6" opacity=".3"/></pattern>
    <marker id="arrow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="4.5" markerHeight="4.5" orient="auto-start-reverse"><path d="M1 1L9 5L1 9Z" fill="context-stroke"/></marker>
    </defs>'''
    s=[f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {WIDTH} {HEIGHT}" role="img" aria-label="手工庭园总平面，非实机地图">',defs,
       '<style>text{font-family:"Microsoft YaHei","Noto Sans CJK SC",sans-serif}.title{font-family:"SimSun",serif}.roof{transition:opacity .15s}.route-edge{pointer-events:none}.node{cursor:pointer}.node:focus{outline:none}.node:hover circle,.node:focus circle{stroke:#fff9df;stroke-width:3}.label{paint-order:stroke;stroke:#e8e2ce;stroke-width:4;stroke-linejoin:round}.gate-closed{display:none}</style>',
       '<rect width="100%" height="100%" fill="#eee8d7"/>',
       '<text x="112" y="51" fill="#243a35" font-size="30" font-family="SimSun,serif">庭园总平面 · 手工样板 01</text>',
       '<text x="114" y="79" fill="#657066" font-size="14">主池与建筑组团先行　／　18 个玩法节点叠加　／　概念平面，非实机与施工图</text>',
       rect(3,2,50,43.8,fill='#c9cfb8'), rect(3,2,50,43.8,fill='url(#raked)'),
       poly([[25,3],[53,3],[53,45.8],[40,45.8],[40,37],[30,37],[29,31],[30,17],[27,13],[25,13]],fill='#d9d4be'),
       poly([[25,3],[53,3],[53,45.8],[40,45.8],[40,37],[30,37],[29,31],[30,17],[27,13],[25,13]],fill='url(#paving)'),
       rect(9.2,2.8,15.5,11.4,fill='#ddd8c5'), rect(9.2,2.8,15.5,11.4,fill='url(#paving)'),
       poly(POND,fill='#719790',stroke='#3d564c',stroke_width=5,stroke_linejoin='round'),
       poly(POND,fill='url(#water)',stroke='#d1c6a4',stroke_width=1.5),
       # Contact zone and inset stone platforms, never floating room slabs.
       rect(27.7,23.7,4.6,4.6,fill='#bdbba5',stroke='#606e60',stroke_width=2),
       poly([[24,32],[27,31.5],[28.5,33],[28.5,36.8],[24,36.8]],fill='#c6c4ab',stroke='#697665',stroke_width=1.5),
       poly([[27.2,12.5],[28.6,12.5],[28.6,18],[28,18],[27.8,15.7],[27,14.4]],fill='#bcbfa5',stroke='#697665',stroke_width=1.2),
       rect(25.8,6.8,6.5,5.5,fill='#c4c0a9',stroke='#68745f',stroke_width=2)]
    for points in PATHS:
        s.extend([line(points,stroke='#a6ac92',stroke_width=22,stroke_linecap='round',stroke_linejoin='round'),
                  line(points,stroke='#d9d1b5',stroke_width=14,stroke_linecap='round',stroke_linejoin='round')])
    for points in ROCKERIES:
        s.append(poly(points,fill='#9ca38c',stroke='#5b685a',stroke_width=2))
        cx=sum(p[0] for p in points)/len(points);cy=sum(p[1] for p in points)/len(points)
        for p in points[::2]:
            s.append(line([p,[(p[0]+cx)/2,(p[1]+cy)/2]],stroke='#6a7967',stroke_width=1))
    # A few irregular lotus leaves close to the sheltered water tail.
    for x,y,r in [(14.5,35.5,.4),(16,35,.24),(15.6,36.6,.32),(13.5,35,.21),(18.5,30.2,.27),(20,30.8,.18),(10.2,27.7,.3),(11.1,28.2,.15)]:
        px,py=point((x,y));s.append(tag('circle',cx=px,cy=py,r=r*S,fill='#7f8d65',stroke='#485e4d',stroke_width=1))
        s.append(line([[x,y],[x+r*.8,y-r*.5]],stroke='#48624c',stroke_width=1))
    s.append(tag('g',''.join(tree(*t) for t in TREES),id='planting'))
    # Roofed galleries: a continuous architectural element with paired posts.
    gallery=[]
    for points in GALLERIES:
        gallery.append(line(points,stroke='#3e4c40',stroke_width=25,stroke_linejoin='miter'))
        gallery.append(line(points,stroke='#87917d',stroke_width=20,stroke_linejoin='miter'))
        gallery.append(line(points,stroke='#4b5c4a',stroke_width=1.8,stroke_linejoin='miter'))
        for a,b in zip(points,points[1:]):
            distance=math.dist(a,b)
            for j in range(int(distance/1.6)+1):
                t=j/max(1,int(distance/1.6));x=a[0]+(b[0]-a[0])*t;y=a[1]+(b[1]-a[1])*t
                nx,ny=(.65,0) if a[0]==b[0] else (0,.65)
                gallery.extend([rect(x+nx-.06,y+ny-.06,.12,.12,fill='#54422d'),rect(x-nx-.06,y-ny-.06,.12,.12,fill='#54422d')])
    s.append(tag('g',''.join(gallery),id='galleries'))
    # A short stone bridge crosses the water mouth, not the whole pond.
    s.extend([rect(25.25,29.45,5.2,1.15,fill='#c7c5ae',stroke='#4c6054',stroke_width=2),
              line([[25.25,29.45],[30.45,29.45]],stroke='#354d43',stroke_width=2.3),
              line([[25.25,30.6],[30.45,30.6]],stroke='#354d43',stroke_width=2.3)])
    for xx in [26,27,28,29,30]:
        s.append(line([[xx,29.48],[xx,30.55]],stroke='#838c75',stroke_width=1))
    # Structural footprints remain when the roof layer is hidden.
    floor=[]
    for b in BUILDINGS:
        x,y,w,h=b['rect'];floor.append(rect(x,y,w,h,fill='#ddd5bc',stroke='#4c5442',stroke_width=2.8))
        for xx in [x+.25,x+w-.25]:
            for yy in [y+.3,y+h-.3]:floor.append(rect(xx-.08,yy-.08,.16,.16,fill='#694a37'))
    s.append(tag('g',''.join(floor),id='building-floors'))
    s.append(tag('g',''.join(roof(b) for b in BUILDINGS),id='roofs'))
    # Small waterside pavilion; its platform shares the bank.
    pavilion=[[26+math.cos(i*math.tau/6)*1.8,34.5+math.sin(i*math.tau/6)*1.8] for i in range(6)]
    s.append(poly(pavilion,fill='#647264',stroke='#2d4236',stroke_width=2))
    for p in pavilion:s.append(line([[26,34.5],p],stroke='#334a3b',stroke_width=1.2))
    # Walls are common boundaries, not a frame around every event marker.
    for points in WALLS:
        s.extend([line(points,stroke='#34473c',stroke_width=8,stroke_linecap='square',stroke_linejoin='miter'),
                  line(points,stroke='#c5bea5',stroke_width=3,stroke_linecap='square',stroke_linejoin='miter')])
    # A screen wall makes the southern entry turn once before the hall opens.
    s.append(line([[43.8,38.3],[47,38.3]],stroke='#314a3c',stroke_width=8))
    s.append(line([[44,38.3],[46.8,38.3]],stroke='#a98d70',stroke_width=3))
    # Fixtures identify scale: stele, desk, ghost fire and a few benches.
    for x,y in [(36.8,14),(38.4,14),(35.8,8.9),(38.3,8.9),(17,12.8)]:
        s.extend([rect(x-.22,y-.16,.44,.32,fill='#7d8978',stroke='#3e5144',stroke_width=1),
                  rect(x-.13,y-.48,.26,.35,fill='#718570',stroke='#3e5144',stroke_width=1)])
    for x,y in [(36.2,20.4),(38.1,20.4),(46.7,26),(46.5,43)]:
        s.append(rect(x-.35,y-.17,.7,.34,fill='#9a7752',stroke='#584d37',stroke_width=1))
    for x,y in [(29,10.1),(26,34.5)]:
        px,py=point((x,y));s.append(tag('circle',cx=px,cy=py,r=5,fill='#8ab1a6',stroke='#426b5b',stroke_width=2))
    # Three broad views; these are compositional intentions, not fog overrides.
    views=[line([[30,26],[13,23]],stroke='#587e85',stroke_width=2,stroke_dasharray='8 5',marker_end='url(#arrow)'),
           line([[29,10],[19,24]],stroke='#587e85',stroke_width=2,stroke_dasharray='8 5',marker_end='url(#arrow)'),
           line([[49,38],[46.8,38.3],[45,36]],stroke='#a05b46',stroke_width=2,stroke_dasharray='6 5',marker_end='url(#arrow)')]
    s.append(tag('g',''.join(views),id='sightlines',style='display:none'))
    # Names belong to physical spaces; gameplay categories stay in another layer.
    labels=[]
    for p,label,sz,col in [
        ([17,23.7],'主 池',25,'#355f59'),([14.6,35.8],'水尾',13,'#3d6961'),
        ([16,44.6],'山 石 林 木 · 南 岸',15,'#53674e'),
        ([6.5,7.7],'怪松',12,'#394b38'),([6.5,35.7],'听石轩',12,'#f2ead6'),
        ([47,43.3],'门屋',13,'#f2ead6'),([47,32.3],'迎字厅',16,'#f2ead6'),
        ([46.3,39.6],'前庭',15,'#62563e'),([41,27.7],'转廊',13,'#f2ead6'),
        ([33.5,33],'南廊',13,'#f2ead6'),([26,34.8],'亭',12,'#f2ead6'),
        ([36.6,29.2],'夹院',13,'#655a42'),([34.4,24.1],'问字轩',12,'#f2ead6'),
        ([30,26.5],'藏字',12,'#f2ead6'),([29.8,28.9],'水榭',12,'#5f614a'),
        ([36.8,20.8],'字肆',13,'#f2ead6'),([40.8,20.8],'库',11,'#f2ead6'),
        ([48,26.3],'东书斋',13,'#f2ead6'),([47,21.4],'书斋前院',13,'#655a42'),
        ([31.8,14.5],'听雨',12,'#f2ead6'),([31.8,15.8],'书屋',12,'#f2ead6'),
        ([37.6,12],'碑堂',12,'#f2ead6'),([37.5,16.2],'镇碑夹庭',12,'#655a42'),
        ([47,15.5],'折桂厅',15,'#f2ead6'),([48.2,7.5],'后书院',13,'#f2ead6'),
        ([37.5,4.2],'藏经阁',13,'#f2ead6'),([37.5,7.7],'镇碑堂',12,'#f2ead6'),
        ([29,9.4],'息灯',13,'#f2ead6'),([29,10.6],'水榭',13,'#f2ead6'),
        ([17,7],'后 殿',23,'#f2ead6'),([17,11.8],'临池前庭',13,'#655a42'),
    ]:
        labels.append(text(p,label,sz,col))
    s.append(tag('g',''.join(labels),id='space-labels'))
    s.append(tag('g',''.join(gate(g) for g in GATES),id='open-gates'))
    # Playable graph is overlaid on the same exact coordinates.
    routes=[]
    colors=['#ad4c3b','#aa7a25','#416c92']
    for e in EDGES:
        col=colors[e['group']] if e['group'] is not None else '#454d42'
        routes.append(tag('g',line(e['points'],stroke='#fbf4de',stroke_width=6,opacity='.9',stroke_linejoin='round')+
                          line(e['points'],stroke=col,stroke_width=3,stroke_dasharray='8 4',stroke_linejoin='round',marker_end='url(#arrow)'),
                          class_='route-edge',data_group=e['group'] if e['group'] is not None else '',data_branch=e['branch'] if e['branch'] is not None else ''))
    for n in NODE_MAP.values():
        x,y=point(n['at']);col='#803e34' if n['kind']=='boss' else '#f5ecd4'
        symbol=tag('circle',cx=x,cy=y,r=13,fill=col,stroke='#493f32',stroke_width=1.7)
        symbol+=tag('text',str(n['number']).zfill(2),x=x,y=y+4.5,text_anchor='middle',font_size=11,fill='#fff6df' if n['kind']=='boss' else '#423c30',font_weight='bold')
        routes.append(tag('g',tag('title',escape(n['name']+' · '+KINDS[n['kind']]))+symbol,class_='node',data_node=n['id'],tabindex='0',role='button',aria_label=n['name']+'，'+KINDS[n['kind']]))
    routes.extend(gate(g,True) for g in GATES)
    s.append(tag('g',''.join(routes),id='gameplay',style='display:none'))
    # Scale, north arrow and one unobtrusive drawing legend.
    s.extend([line([[55.5,5],[55.5,2.8]],stroke='#34473d',stroke_width=2,marker_end='url(#arrow)'),text([55.5,2.1],'北',14),
              line([[4,48],[9,48]],stroke='#34473d',stroke_width=3),line([[4,47.7],[4,48.3]],stroke='#34473d',stroke_width=2),
              line([[9,47.7],[9,48.3]],stroke='#34473d',stroke_width=2),text([6.5,49],'5 概念格',12),
              text([30,49.1],'尺度为布局推敲，尚未转换为运行通行格',13,'#737668'),
              '<text x="112" y="1140" font-size="13" fill="#687365">设计关系参考网师园、艺圃；未复刻历史总图。屋面可切换，事件与路线独立显示。</text>',
              '</svg>'])
    return ''.join(s).replace('class-=', 'class=')


HTML = r'''<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>庭园总平面 · 手工样板 01</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#172a27;color:#ddd7c4;font:14px/1.65 "Microsoft YaHei",sans-serif}button,input{font:inherit}button{cursor:pointer}a{color:#caad77}header{padding:20px 28px 14px;display:flex;justify-content:space-between;align-items:center;gap:20px;border-bottom:1px solid #42534a}h1{margin:0;font:24px/1.4 SimSun,serif;color:#eee7cf}header p{margin:4px 0 0;color:#b1bdad;font-size:12px}.badge{padding:5px 10px;border:1px solid #6d7864;color:#d1be8f;white-space:nowrap}.layout{display:grid;grid-template-columns:minmax(0,1fr) 310px;max-width:1800px;margin:auto}.sheet{min-width:0;background:#eee8d7;position:relative;overflow:hidden}.sheet svg{display:block;width:100%;height:auto;touch-action:none}.sidebar{padding:23px 22px;overflow:auto}.sidebar h2{font-size:14px;color:#d8bd8d;margin:24px 0 9px}.sidebar h2:first-child{margin-top:0}.sidebar p{color:#b1bcae}.tools{display:flex;gap:8px;flex-wrap:wrap}button{border:1px solid #576654;background:#243b31;color:#ddd7c4;border-radius:3px;padding:7px 9px}button:hover,button:focus-visible{background:#36503e;outline:2px solid #c2a575;outline-offset:2px}button[aria-pressed=true]{border-color:#d4b477;background:#4b5037}label{display:block;margin:10px 0;color:#c6cebd}input{accent-color:#c2a575;margin-right:8px}.divider{border-top:1px solid #435746;padding-top:16px;margin-top:18px}.choice{display:block;width:100%;text-align:left;margin:6px 0;font-size:12px}.choice-label{margin-top:14px;font-size:12px;color:#bdc5b5}.stats{display:flex;gap:20px;margin:18px 0}.stats b{font-size:23px;display:block;color:#e4c99a}.stats span{font-size:11px;color:#aabaac}.note{font-size:12px;color:#aabaac!important}.detail{min-height:118px;padding:12px;border-left:2px solid #b19763;background:#20372f}.detail strong{color:#dec49a}.detail p{font-size:12px;margin:6px 0}.hidden{display:none}.hint{font-size:11px;color:#91a28f}.mini-legend{display:flex;gap:10px;font-size:11px;margin:12px 0;color:#acb9a6}.mini-legend i{width:14px;display:inline-block;height:3px;vertical-align:middle;margin-right:4px}.roof-off #roofs{opacity:0}.roof-off #galleries{opacity:.4}.roof-off #space-labels text{fill:#3d4f40;paint-order:stroke;stroke:#e7dfc8;stroke-width:3px}.routes-on #gameplay{display:block!important}.routes-on #space-labels{opacity:.23}.sight-on #sightlines{display:block!important}footer{padding:14px 28px;font-size:12px;color:#a9b6a4;border-top:1px solid #42534a}.export-mode header,.export-mode .sidebar,.export-mode footer{display:none}.export-mode .layout{display:block;max-width:none}.export-mode .sheet{width:1270px}.export-mode svg{width:1270px;height:1160px}.export-mode body{background:#eee8d7}@media(max-width:920px){header{padding:16px}.layout{grid-template-columns:1fr}.sidebar{display:grid;grid-template-columns:1fr 1fr;gap:24px}.sidebar>div{min-width:0}footer{padding:12px 16px}}@media(max-width:580px){.badge{display:none}.sidebar{display:block}h1{font-size:20px}}
</style></head><body><header><div><h1>庭园总平面 · 手工样板 01</h1><p>先建立园子的空间关系，再叠加事件与分支。此页是设计推敲，不是当前游戏实机。</p></div><span class="badge">空间设计草案</span></header><main class="layout"><section class="sheet" aria-label="可缩放的总平面">__SVG__</section><aside class="sidebar"><div>
<h2>先看空间</h2><div class="tools"><button id="space" aria-pressed="true">空间总平面</button><button id="route" aria-pressed="false">节点与门禁</button></div>
<label><input type="checkbox" id="roof" checked>显示屋面</label><label><input type="checkbox" id="sight">显示主要观景方向</label><div class="tools"><button id="fit">全园</button><button id="east">建筑组团</button></div><p class="hint">滚轮缩放 · 拖动查看 · 节点模式可点选编号</p>
<div class="stats"><div><b>18</b><span>全图可选节点</span></div><div><b>12–13</b><span>单次访问节点</span></div></div>
<p>一片主池，东、北两侧建筑成组。前庭、夹院、书斋前院由建筑围出；廊贴岸、贴墙、穿堂，水尾用短桥跨过。</p><p class="note">西南山石与听石轩承担借景。示意游步道尚未开放为玩法支路，不增加奖励节点。</p>
<h2>空间与节点分开表达</h2><div class="detail" id="detail"><strong>点击“节点与门禁”查看玩法</strong><p>同一组建筑容纳多个节点，节点也可位于廊下、夹院与池岸。</p></div>
</div><div class="divider" id="choices"><h2>三次择路，落在不同空间</h2><div class="mini-legend"><span><i style="background:#ad4c3b"></i>前段</span><span><i style="background:#aa7a25"></i>中段</span><span><i style="background:#668caf"></i>后段</span></div>__CHOICES__<button id="reset" class="choice">重置选择</button><p id="route-summary" class="note">选择一支后，另一支的入口、汇合端同时封闭。</p><p class="note">这是门禁设计示意，尚未接入寻路。屋面、墙体、视野遮挡与通行净空需在后续灰盒确认。</p></div></aside></main><footer>研究依据：<a href="https://www.metmuseum.org/met-publications/a-chinese-garden-court" target="_blank" rel="noreferrer">网师园平面</a> · <a href="https://www.yunnanforestry.cn/uploadDir/pdf/20230425/1682409847630.pdf#page=156" target="_blank" rel="noreferrer">艺圃平面</a> · <a href="README.md">设计说明与限制</a></footer><script>
const plan=__DATA__;let picks=[null,null,null];const svg=document.querySelector('svg');const sheet=document.querySelector('.sheet');let box=[0,0,1270,1160];let drag=null;
function view(b){box=b;svg.setAttribute('viewBox',box.join(' '))}function mode(on){document.body.classList.toggle('routes-on',on);document.getElementById('space').setAttribute('aria-pressed',!on);document.getElementById('route').setAttribute('aria-pressed',on)}
document.getElementById('space').onclick=()=>mode(false);document.getElementById('route').onclick=()=>mode(true);document.getElementById('roof').onchange=e=>document.body.classList.toggle('roof-off',!e.target.checked);document.getElementById('sight').onchange=e=>document.body.classList.toggle('sight-on',e.target.checked);document.getElementById('fit').onclick=()=>view([0,0,1270,1160]);document.getElementById('east').onclick=()=>view([600,150,575,810]);
function update(){document.querySelectorAll('[data-choice]').forEach(b=>{const[g,k]=b.dataset.choice.split(',').map(Number);b.setAttribute('aria-pressed',picks[g]===k)});document.querySelectorAll('.route-edge').forEach(e=>{if(e.dataset.group!=='')e.style.opacity=picks[+e.dataset.group]!==null&&picks[+e.dataset.group]!==+e.dataset.branch?'.12':'1'});document.querySelectorAll('.gate-closed').forEach(e=>e.style.display=picks[+e.dataset.group]!==null&&picks[+e.dataset.group]!==+e.dataset.branch?'block':'none');document.querySelectorAll('.node').forEach(el=>{let n=el.dataset.node;if(!n.startsWith('g'))return;const[g,k]=n.match(/^g(\d)_b(\d)/).slice(1).map(Number);el.style.opacity=picks[g]!==null&&picks[g]!==k?'.22':'1'});const summary=document.getElementById('route-summary');if(picks.every(x=>x!==null)){let ids=['start','opening_1','opening_2'];plan.groups.forEach((g,i)=>ids.push(...g.branches[picks[i]],g.merge));ids.push('boss');const count={};ids.forEach(id=>{const k=plan.nodes[id].kind;count[k]=(count[k]||0)+1});summary.textContent=`此路线访问 ${ids.length} 个节点：${count.battle||0} 普通战、${count.elite||0} 精英、1 首领；${count.rest||0} 火堆、${count.shop||0} 商店。`;}else summary.textContent='选择一支后，另一支的入口、汇合端同时封闭。'}
document.querySelectorAll('[data-choice]').forEach(b=>b.onclick=()=>{const[g,k]=b.dataset.choice.split(',').map(Number);picks[g]=k;mode(true);update()});document.getElementById('reset').onclick=()=>{picks=[null,null,null];update()};document.querySelectorAll('.node').forEach(el=>{const show=()=>{const n=plan.nodes[el.dataset.node];const d=document.getElementById('detail');d.replaceChildren();const strong=document.createElement('strong');strong.textContent=String(n.number).padStart(2,'0')+' · '+n.name+' / '+plan.kinds[n.kind];const p=document.createElement('p');p.textContent=n.description;d.append(strong,p)};el.onclick=show;el.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();show()}}});
svg.addEventListener('wheel',e=>{e.preventDefault();const r=svg.getBoundingClientRect();const factor=e.deltaY>0?1.13:1/1.13;const w=Math.max(380,Math.min(1800,box[2]*factor));const h=w*box[3]/box[2];const tx=(e.clientX-r.left)/r.width,ty=(e.clientY-r.top)/r.height;view([box[0]+(box[2]-w)*tx,box[1]+(box[3]-h)*ty,w,h])},{passive:false});svg.addEventListener('pointerdown',e=>{if(e.target.closest('.node'))return;drag={x:e.clientX,y:e.clientY,box:[...box]};svg.setPointerCapture(e.pointerId)});svg.addEventListener('pointermove',e=>{if(!drag)return;const r=svg.getBoundingClientRect();view([drag.box[0]-(e.clientX-drag.x)*drag.box[2]/r.width,drag.box[1]-(e.clientY-drag.y)*drag.box[3]/r.height,drag.box[2],drag.box[3]])});svg.addEventListener('pointerup',()=>drag=null);svg.addEventListener('pointercancel',()=>drag=null);
const params=new URLSearchParams(location.search);if(params.has('export'))document.documentElement.classList.add('export-mode');if(params.get('routes')==='1')mode(true);if(params.get('sight')==='1'){document.getElementById('sight').checked=true;document.body.classList.add('sight-on')}if(params.get('detail')==='1')view([600,150,575,810]);update();window.gardenPreview={plan,get picks(){return picks},setPicks(p){picks=p;mode(true);update()},mode,view};
</script></body></html>'''


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    for e in EDGES:
        assert e['from'] in NODE_MAP and e['to'] in NODE_MAP
        assert all(a[0]==b[0] or a[1]==b[1] for a,b in zip(e['points'],e['points'][1:])),e
    data={'schema':1,'status':'authored spatial study, not runtime navigation',
          'bounds':[3,2,50,43.8],'nodes':NODE_MAP,'groups':GROUPS,'edges':EDGES,
          'gates':GATES,'kinds':KINDS,'buildings':BUILDINGS,'pond_polygon':POND,
          'walls':WALLS,'galleries':GALLERIES,'scenic_paths':PATHS,
          'limits':['Concept units are not locked to runtime tile scale.','Roof meshes, wall apertures and navigation are not integrated.','Scenic southwest path is not a gameplay branch.']}
    svg=architectural_svg()
    # class_ is an XML attribute spelling convenience, not an actual SVG class.
    svg=svg.replace('class-=', 'class=').replace('class_=', 'class=')
    (OUT/'garden-plan.svg').write_text(svg,encoding='utf-8')
    (OUT/'garden-routes.svg').write_text(svg.replace('id="gameplay" style="display:none"','id="gameplay" style="display:block"').replace('id="space-labels"','id="space-labels" opacity=".23"'),encoding='utf-8')
    (OUT/'garden-plan.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
    choices=''
    for g in GROUPS:
        choices+=f'<div class="choice-label">{g["id"]+1} · {g["label"]}</div>'
        for j,label in enumerate(g['options']):choices+=f'<button class="choice" data-choice="{g["id"]},{j}" aria-pressed="false">{label}</button>'
    html=HTML.replace('__SVG__',svg).replace('__DATA__',json.dumps(data,ensure_ascii=False)).replace('__CHOICES__',choices)
    (OUT/'index.html').write_text(html,encoding='utf-8')
    paths=[]
    def visit(id,path):
        if id=='boss':paths.append(path+[id]);return
        for e in EDGES:
            if e['from']==id:visit(e['to'],path+[id])
    visit('start',[])
    print(json.dumps({'nodes':len(NODE_MAP),'complete_routes':len(paths),'route_lengths':sorted(set(map(len,paths))),'buildings':len(BUILDINGS),'output':str(OUT)},ensure_ascii=False))


if __name__=='__main__':main()
