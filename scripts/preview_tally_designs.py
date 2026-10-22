"""Compose thirty shared-edge concepts from existing art; never load addon code."""
from pathlib import Path
import json
import math
from PIL import Image, ImageDraw, ImageFont, ImageOps, ImageChops, ImageColor

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/designs/tally-attachment'
TEX=ROOT/'media/tex'
S=3
FONT='/System/Library/Fonts/Supplemental/Arial.ttf'
BOLD='/System/Library/Fonts/Supplemental/Arial Bold.ttf'
DESIGNS=[
 ('Continuous silver','One silver seam, straight sidewalls and a shallow dark lower chamber.','straight','#b6bcc4'),
 ('Soft graphite','Shared silver top with gently rounded lower corners.','round','#a3aebc'),
 ('Clipped steel','The same top edge, with clean diagonal lower corners.','chamfer','#c0c6ce'),
 ('Recessed bays','Three inset counter bays inside one continuous outer shell.','inset','#a4adb8'),
 ('Fine ledger','Very fine side and bottom lines around an open dark row.','minimal','#acb8c7'),
 ('Carved iron','A heavier lower lip and worn metal along the bottom corners.','gothic','#a9a7a2'),
 ('Central point','One joined compartment tapering to a shallow central point.','point','#aeb2b7'),
 ('Stepped ends','Squared upper walls with compact steps at the lower ends.','step','#a9b1bc'),
 ('Gothic cornice','A heavy carved lower cornice beneath the unchanged silver seam.','cornice','#b4afa4'),
 ('Triple scallop','Three shallow scallops along a single continuous lower edge.','scallop','#abb2bc'),
 ('Central drop','The middle counter sits in a slightly deeper part of the shell.','drop','#aeb6bf'),
 ('Fluted ash','A dark straight chamber with fluting confined to its bottom lip.','fluted','#8d939c'),
 ('Bronze double lip','Restrained bronze details appear only on the lower edge.','lowerdouble','#bda37c'),
 ('Curved basin','A single shallow curved lower outline beneath all three counters.','bowl','#aeb9c0'),
 ('Descending chevron','An angular lower edge drops gently below the gold counter.','chevron','#a4a9ad'),
 ('Silver three-bay','Silver inner dividers meet the existing shared top edge.','bays','#b9c1c7'),
 ('Asymmetric pennant','The lower contour descends on one side; the top stays continuous.','banner','#b4ada0'),
 ('Center step','A wider lower center shelf creates a quiet stepped silhouette.','centerstep','#b0b6c0'),
 ('Gunmetal groove','A recessed channel follows the inside of the lower silver lip.','groove','#939eaa'),
 ('Icon alcoves','Small dark icon recesses sit inside the joined counter row.','alcove','#afb7be'),
 ('Copper taper','Warm copper walls narrow toward the lower edge.','taper','#b48a67'),
 ('Blood iron','A subdued crimson recess inside an uninterrupted iron shell.','recess','#a36c68'),
 ('Cobalt etching','Blue steel with fine etching along the lower edge.','engraved','#7c9eb4'),
 ('Amethyst point','A violet chamber ends in a short silver central spear.','spear','#a58cba'),
 ('Verdigris glass','Three green glass recesses share the same outer metal shell.','glass','#82a99c'),
 ('Ivory ledger','Pale stone inlays inside the shared silver compartment.','ivory','#c3b48e'),
 ('Undercut base','A recessed bottom section leaves short solid lower corners.','undercut','#a7b2b9'),
 ('Broad bevel','A broad lower bevel gives the common chamber a heavier foundation.','broad','#b5b5b8'),
 ('Open lower row','A transparent row framed by the shared silver seam and a fine lower rail.','open','#a9b1bb'),
 ('Arched foundation','Three connected arches shape the lower edge of the same shell.','arches','#b8aa91'),
]


def art(path,crop=None):
    layer=Image.open(TEX/path).convert('RGBA')
    return layer.crop(crop) if crop else layer


def paste(im,layer,x,y,w,h):
    im.alpha_composite(layer.resize((max(1,round(w*S)),max(1,round(h*S))),Image.Resampling.LANCZOS),(round(x*S),round(y*S)))


def text(im,x,y,value,size=12,color='#d8d4ca',bold=False,center=False):
    font=ImageFont.truetype(BOLD if bold else FONT,round(size*S))
    d=ImageDraw.Draw(im)
    if center:x-=d.textlength(value,font=font)/(2*S)
    d.text((round(x*S)+1,round(y*S)+2),value,font=font,fill='#080a0d')
    d.text((round(x*S),round(y*S)),value,font=font,fill=color)


def line(im,points,color,width=1):
    ImageDraw.Draw(im).line([(round(x*S),round(y*S)) for x,y in points],fill=color,width=max(1,round(width*S)),joint='curve')


def rect(im,x,y,w,h,fill):
    ImageDraw.Draw(im).rectangle((round(x*S),round(y*S),round((x+w)*S),round((y+h)*S)),fill=fill)


SHELL=art('actionbars/HDActionBar.tga')
JOINED=art('actionbars/HDActionBarXP.tga',(0,0,512,144))
BUTTON=art('actionbars/HDActionBarBtn.tga')
XP=art('xprep/main_soft.tga')
ICONS=[Image.open(OUT/'research/Attack.png').convert('RGBA'),art('chat/cleaner_coins.tga',(0,0,32,32)),Image.open(OUT/'research/LootAll.png').convert('RGBA')]
CHROME=art('character/Chrome.tga')


def action(im,x,y,xp):
    half=JOINED if xp else SHELL
    h=72 if xp else 64
    paste(im,half,x,y,150,h)
    paste(im,half.transpose(Image.Transpose.FLIP_LEFT_RIGHT),x+150,y,150,h)
    for j in range(7):
        bx=x+6+j*42
        rect(im,bx,y+14,36,36,'#0c0e13')
        paste(im,BUTTON,bx-4,y+10,44,44)
    if xp:
        rect(im,x+9,y+53,282,6,'#17111d')
        fill=XP.resize((282*S,6*S),Image.Resampling.BILINEAR)
        r,g,b,a=fill.split()
        fill=Image.merge('RGBA',(r.point(lambda v:round(v*.85)),g.point(lambda v:round(v*.4)),b.point(lambda v:round(v*.85)),a))
        im.alpha_composite(fill.crop((0,0,round(282*.62*S),6*S)),(round((x+9)*S),round((y+53)*S)))
    return y+h-8


def outline(kind,w,h):
    # Only the sides and bottom are traced. The action bar owns the top border.
    if kind=='round':
        return [(0,-2),(0,h-7)]+[(7-7*math.cos(i*math.pi/12),h-7+7*math.sin(i*math.pi/12)) for i in range(1,7)]+[(w-7,h)]+[(w-7+7*math.sin(i*math.pi/12),h-7+7*math.cos(i*math.pi/12)) for i in range(1,7)]+[(w,-2)]
    if kind in ('chamfer','taper'):
        inset=8 if kind=='chamfer' else 18
        return [(0,-2),(0,10),(inset,h),(w-inset,h),(w,10),(w,-2)]
    if kind in ('point','spear'):
        return [(0,-2),(0,h-5),(w*.39,h-5),(w*.5,h+2),(w*.61,h-5),(w,h-5),(w,-2)]
    if kind=='step':return [(0,-2),(0,h-8),(6,h-8),(6,h-3),(15,h-3),(15,h),(w-15,h),(w-15,h-3),(w-6,h-3),(w-6,h-8),(w,h-8),(w,-2)]
    if kind in ('scallop','arches'):
        points=[(0,-2),(0,h-5)]
        for j in range(3):
            for k in range(13):
                xx=(j+k/12)*w/3
                yy=h-5+5*math.sin(k/12*math.pi)
                if kind=='arches':yy=h-5-5*math.sin(k/12*math.pi)
                points.append((xx,yy))
        return points+[(w,-2)]
    if kind in ('drop','centerstep'):
        inset=w/3 if kind=='drop' else w*.27
        return [(0,-2),(0,h-5),(inset,h-5),(inset,h+1),(w-inset,h+1),(w-inset,h-5),(w,h-5),(w,-2)]
    if kind=='chevron':return [(0,-2),(0,h-7),(w*.28,h-7),(w*.4,h),(w*.6,h),(w*.72,h-7),(w,h-7),(w,-2)]
    if kind=='bowl':return [(0,-2),(0,h-8)]+[(w*k/24,h-8+8*math.sin(k/24*math.pi)) for k in range(25)]+[(w,-2)]
    if kind=='banner':return [(0,-2),(0,h),(w*.7,h),(w,h-10),(w,-2)]
    if kind=='undercut':return [(0,-2),(0,h),(18,h),(18,h-4),(w-18,h-4),(w-18,h),(w,h),(w,-2)]
    if kind=='broad':return [(0,-2),(0,h-5),(5,h),(w-5,h),(w,h-5),(w,-2)]
    return [(0,-2),(0,h),(w,h),(w,-2)]


def chamber(im,x,y,w,h,kind,c):
    points=[(x+xx,y+yy) for xx,yy in outline(kind,w,h)]
    # Close the fill at its top only; this path is never drawn as a border.
    mask=Image.new('L',im.size)
    ImageDraw.Draw(mask).polygon([(round(xx*S),round(yy*S)) for xx,yy in points],fill=255)
    layer=Image.new('RGBA',im.size)
    rgb=ImageColor.getrgb(c)
    for row in range(-2,h+4):
        base=30-13*max(0,row)/max(1,h)
        if kind=='ivory':color=(round(base+125),round(base+118),round(base+99),255)
        elif kind=='glass':color=(16,round(base+15),round(base+11),245)
        elif kind=='recess':color=(round(base+13),round(base*.5),round(base*.65),255)
        elif kind=='open':color=(12,16,23,100)
        else:color=(round(base*.85),round(base*.96),round(base+5),245)
        line(layer,[(x,y+row),(x+w,y+row)],color)
    layer.putalpha(ImageChops.multiply(layer.getchannel('A'),mask))
    im.alpha_composite(layer)
    thickness=.8 if kind in ('minimal','open') else 3 if kind in ('cornice','broad') else 1.6
    line(im,points,'#080b0f',thickness+1.2)
    line(im,points,c,thickness)
    # Thin interior shade follows the lower lip, with no repeated top stroke.
    if kind not in ('minimal','open','scallop','arches','bowl'):
        inner=[(xx,yy-1.5 if yy>y+h-8 else yy) for xx,yy in points]
        line(im,inner,'#48515c',.45)
    for j in (1,2):
        if kind not in ('minimal','open','alcove'):
            line(im,[(x+j*w/3,y+2),(x+j*w/3,y+h-6)],c,.45)
    if kind in ('inset','bays','glass','ivory','recess'):
        for j in range(3):
            xx=x+j*w/3+4
            fill='#1d3432' if kind=='glass' else '#c1b697' if kind=='ivory' else '#11161b'
            rect(im,xx,y+3,w/3-8,h-9,fill)
            line(im,[(xx,y+4),(xx,y+h-6),(xx+w/3-8,y+h-6),(xx+w/3-8,y+4)],c,.5)
    if kind in ('gothic','cornice'):
        paste(im,CHROME.crop((896,0,928,64)),x+3,y+h-6,w-6,9)
    if kind=='fluted':
        for j in range(45):line(im,[(x+6+j*(w-12)/44,y+h-4),(x+6+j*(w-12)/44,y+h-1)],'#59606a',.5)
    if kind in ('lowerdouble','groove','engraved'):
        line(im,[(x+6,y+h-5),(x+w-6,y+h-5)],c,.65)
    if kind=='engraved':
        for j in range(9):
            cx=x+12+j*(w-24)/8
            line(im,[(cx-2,y+h-4),(cx,y+h-2),(cx+2,y+h-4)],c,.5)
    if kind=='alcove':
        for j in range(3):
            cx=x+20+j*w/3
            ImageDraw.Draw(im).ellipse((round((cx-11)*S),round((y+3)*S),round((cx+11)*S),round((y+25)*S)),fill='#080c12',outline='#48535c',width=2)
    if kind=='broad':
        line(im,[(x+6,y+h-2),(x+w-6,y+h-2)],'#d4d5d7',.65)


def counter(im,cx,cy,index,color):
    paste(im,ICONS[index],cx-30,cy-9,18,18)
    text(im,cx+10,cy-8,['1,248','3,820','450'][index],12,color,center=True)


def sample(im,index,x,y,xp):
    _,_,kind,c=DESIGNS[index-1]
    edge=y+(64 if xp else 56)
    # Draw the lower compartment behind the action shell. Its one existing
    # lower silver edge remains the only top border after compositing.
    heights={
        'point':30,'spear':30,'drop':30,'centerstep':30,'chevron':32,
        'bowl':32,'banner':35,'arches':35,'undercut':29,
        'lowerdouble':30,'groove':30,'engraved':30,
        'gothic':31,'cornice':31,'inset':31,'bays':31,'glass':31,
        'ivory':31,'recess':31,
    }
    h=heights.get(kind,27)
    inset=300*12/1024
    if index==1:
        # Preview the prepared runtime's actual source strips, not a substitute
        # outline. Its sole top border remains the original action-shell bevel.
        rect(im,x+inset,edge,300-2*inset,h,(12,12,13,245))
        wall=SHELL.crop((0,35,7,92))
        wall_width=300*7/1024
        bottom_height=3.5
        paste(im,wall,x+inset,edge,wall_width,h-bottom_height)
        paste(im,wall.transpose(Image.Transpose.FLIP_LEFT_RIGHT),x+300-inset-wall_width,edge,wall_width,h-bottom_height)
        bottom=SHELL.crop((16,105,512,112))
        paste(im,bottom,x+inset,edge+h-bottom_height,150-inset,bottom_height)
        paste(im,bottom.transpose(Image.Transpose.FLIP_LEFT_RIGHT),x+150,edge+h-bottom_height,150-inset,bottom_height)
        for j in (1,2):
            xx=x+8+j*(300-16)/3
            line(im,[(xx,edge+6),(xx,edge+21)],(140,143,148,153),.8)
    else:
        chamber(im,x+inset,edge-1,300-2*inset,h,kind,c)
    action(im,x,y,xp)
    for j in range(3):
        yy=edge+13.5+(2 if kind=='drop' and j==1 else 0)
        counter(im,x+50+j*100,yy,j,'#30291f' if kind=='ivory' else '#e7dfcd')


def make(index):
    im=Image.new('RGBA',(880*S,320*S),'#10141a')
    for yy in range(320):
        shade=round(23-yy/70)
        line(im,[(0,yy),(880,yy)],(shade,shade+5,shade+11))
    title,desc,_,_=DESIGNS[index-1]
    text(im,25,18,f'{index:02d}  {title}',23,'#e2d7bd',True)
    text(im,25,52,desc,12,'#9faebb')
    text(im,235,88,'XP ATTACHED · VISIBLE',11,'#a5b1c1',center=True)
    text(im,645,88,'XP OFF / DETACHED / UNAVAILABLE',11,'#a5b1c1',center=True)
    sample(im,index,85,112,True)
    sample(im,index,495,112,False)
    text(im,25,251,'One shared silver top edge · continuous lower compartment · original three icons',11,'#a1adbb')
    text(im,25,276,'Static artwork proposals. Empty sample slots and illustrative values; no game rendering.',10,'#74818f')
    im.convert('RGB').save(OUT/f'{index:02d}.png')
    return im


def gallery():
    OUT.mkdir(parents=True,exist_ok=True)
    images=[make(i) for i in range(1,31)]
    records=[dict(id=f'{i:02d}',name=d[0],description=d[1],shape=d[2],accent=d[3],image=f'{i:02d}.png') for i,d in enumerate(DESIGNS,1)]
    (OUT/'designs.json').write_text(json.dumps(records,indent=2)+'\n')
    for page in range(3):
        sheet=Image.new('RGB',(1400,1080),'#10141a')
        d=ImageDraw.Draw(sheet)
        d.text((24,15),f'SHARED SILVER EDGE / {page*10+1:02d}–{page*10+10:02d}',font=ImageFont.truetype(BOLD,24),fill='#ddd3bc')
        d.text((24,49),'One continuous shell in every design. XP on: left. XP off: right.',font=ImageFont.truetype(FONT,15),fill='#96a5b5')
        for n in range(10):
            thumb=images[page*10+n].resize((680,247),Image.Resampling.LANCZOS).crop((0,0,680,191))
            sheet.paste(thumb,(15+(n%2)*695,83+(n//2)*198))
        sheet.save(OUT/f'sheet-{page+1}.png')
    overview=Image.new('RGB',(1800,1820),'#10141a')
    d=ImageDraw.Draw(overview)
    d.text((25,12),'30 SHARED-EDGE TALLY DESIGNS',font=ImageFont.truetype(BOLD,26),fill='#ddd3bc')
    for n,im in enumerate(images):
        thumb=im.resize((580,211),Image.Resampling.LANCZOS).crop((0,0,580,169))
        overview.paste(thumb,(15+(n%3)*595,52+(n//3)*176))
    overview.save(OUT/'overview.png')
    cards='\n'.join(f'<article data-name="{r["name"].lower()}"><h2>{r["id"]} · {r["name"]}</h2><a href="{r["image"]}" target="_blank"><img src="{r["image"]}" alt="{r["description"]}" loading="lazy"></a><p>{r["description"]}</p><button onclick="pick(\'{r["id"]}\')">Compare {r["id"]}</button></article>' for r in records)
    html='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>30 shared-edge tally designs</title><style>body{background:#10141a;color:#dcd6ca;font:16px system-ui;margin:0}header{padding:24px;position:sticky;top:0;background:#10141aee;z-index:2;border-bottom:1px solid #343f4a}h1{margin:0 0 8px;font-size:27px}p{color:#a4b0bd;line-height:1.5}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(520px,1fr));gap:18px;padding:24px}article{border:1px solid #35404c;border-radius:8px;background:#171c24;overflow:hidden;padding:15px}h2{font-size:18px;margin:0 0 8px}img{display:block;width:100%}button,input{background:#27313d;color:#eee0bc;border:1px solid #526172;border-radius:5px;padding:8px 12px}#compare{display:none;position:fixed;inset:0;z-index:4;overflow:auto;background:#080b10f5;padding:24px}#compare img{max-width:1400px;margin:auto}#selection{color:#d4bc87}a{color:#c3ab7d}.note{font-size:13px}</style><header><h1>30 shared-edge tally designs</h1><p>The action bar's lower silver edge IS the tally's top border. Every proposal has a continuous lower compartment. Left: attached XP visible. Right: XP off, detached or unavailable.</p><input placeholder="Filter names" oninput="document.querySelectorAll('article').forEach(a=>a.hidden=!a.dataset.name.includes(this.value.toLowerCase()))"> <button onclick="showCompare()">Open comparison</button><span id="selection"></span><p class="note">Original three icons throughout. Static design proposals; installed baseline is the plain shared-edge lower chamber. <a href="ARTWORK.md">Artwork notes</a> · <a href="overview.png">All 30</a></p></header><main>'''+cards+'''</main><section id="compare"><button onclick="document.getElementById('compare').style.display='none'">Close comparison</button><button onclick="selected.clear();showCompare()">Clear selection</button><div id="picked"></div></section><script>const selected=new Set();function pick(id){selected.has(id)?selected.delete(id):selected.add(id);document.getElementById('selection').textContent='  Selected: '+[...selected].join(', ')}function showCompare(){document.getElementById('compare').style.display='block';document.getElementById('picked').innerHTML=[...selected].map(id=>'<img src="'+id+'.png">').join('')||'<p>Use Compare on the designs you want to see together.</p>'}</script></html>'''
    (OUT/'index.html').write_text(html)


if __name__=='__main__':gallery()
