"""Assemble20 proposals from pinned Gothic UI bitmaps. Never load addon code."""
from pathlib import Path
import json
import html
import os
from PIL import Image,ImageDraw,ImageFont,ImageEnhance,ImageChops

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/designs/tally-gothic'
TEX=ROOT/'media/tex'
S=3
UIFONT='/System/Library/Fonts/Supplemental/Arial.ttf'
BOLD='/System/Library/Fonts/Supplemental/Arial Bold.ttf'
NATIVEFONT=os.environ.get('SDUI_PREVIEW_FONT')
FONT=str(Path(NATIVEFONT).expanduser()) if NATIVEFONT and Path(NATIVEFONT).expanduser().is_file() else UIFONT
ASSETS=json.loads((OUT/'research/assets.json').read_text())
DESIGNS=[
 ('01','Roth scrollwork','RothUI · castbar.tga','scroll',['R01'], 'Carved lower corners and the original grained bronze trough.'),
 ('02','Roth shrine','RothUI · targettarget.tga','shrine',['R03'], 'The compact shrine frame, with its deeper carved lower rail.'),
 ('03','Gothic cornerwork','RothUI · d3_altpower_border.tga','filigree',['R05'], 'Real etched Gothic corners and a thin continuous lower rim.'),
 ('04','Iron sarcophagus','RothUI · demonic_fury_border.tga','angular',['R04'], 'Angular stone-dark metal with the original diamond cornerwork.'),
 ('05','Diablo II silverwork','RothUI · d2tex/border_left.tga','diablo2',['R20'], 'Original Diablo II silver scrollwork across the lower edge.'),
 ('06','Bone scrolls','RothUI · combo_bar_left.tga','scrollcaps',['R09','R06'], 'Carved bone-colored end scrolls around the textured stone channel.'),
 ('07','Knotted iron','RothUI · d3_nameplate_border.tga','knots',['R25'], 'Blackened knotwork and pointed metal ends from the older Diablo skin.'),
 ('08','Diablo I masonry','RothUI · Diablo1/bar.tga','masonry',['D1','R05'], 'The original rough stone surface beneath a Gothic metal surround.'),
 ('09','Acanthus base','RothUI · vehiclebar.tga','acanthus',['R16','R06'], 'An actual bronze acanthus skirt under a charcoal stone channel.'),
 ('10','ARPG carved cornice','ARPG · TopBar.tga','arpg',['ARPG','R06'], 'The original carved lower cornice around a textured Gothic channel.'),
 ('11','Gothic leaf corners','Diablo III UI · UIButton texture','button',['N4'], 'Existing leaf-etched side and lower corners, with the upper rim removed.'),
 ('12','Dragon iron','Diablo III UI · target.tga','dragon',['N0'], 'Sculpted iron end ornaments and the source lower metal rail.'),
 ('13','Demon reliquary','Diablo III UI · target_elite.tga','elite',['N0','N1'], 'A real demon pendant below the original copper-dark target-frame edging.'),
 ('14','Spartan engraved bronze','SpartanUI · Classic DataBar','classic',['N11','N12','N13'], 'The actual engraved bronze ends and textured lower bar.'),
 ('15','Spartan tusk carving','SpartanUI · Tribal DataBar','tribal',['N14','N15','N16'], 'Real carved wood and tusks, toned toward aged Vanilla metal.'),
 ('16','Chiselled stone','SpartanUI · Shard DataBar','shard',['N17','N18','N19'], 'The original cut stone endcaps, with a dark recessed center.'),
 ('17','Black cathedral','SpartanUI · Midnight DataBar','midnight',['N20','N21','N22'], 'The Gothic tracery remains; purple is reduced to match gray Vanilla chrome.'),
 ('18','Weathered steel','SpartanUI · Classic base-left1','weathered',['N23','R05'], 'Actual worn metal and black curling linework, framed by Gothic corners.'),
 ('19','Gargoyle crest','RothUI · castbar + d3_head_garg','gargoyle',['R01','R15'], 'The original carved trough with its original-source gargoyle ornament.'),
 ('20','Bone reliquary','RothUI · shrine + d3_head_skull','bones',['R03','R12','R09'], 'A Gothic shrine channel with bone scrolls and the source winged skull.'),
]


def asset(key,crop=None):
    im=Image.open(OUT/ASSETS[key]['local']).convert('RGBA')
    rect=crop if crop is not None else ASSETS[key].get('rect')
    return im.crop(tuple(rect)) if rect else im


def local(path,crop=None):
    im=Image.open(TEX/path).convert('RGBA')
    return im.crop(crop) if crop else im


def grade(im,saturation=.35,brightness=1.2):
    # Source detail is retained. Only its palette is matched to Vanilla chrome.
    alpha=im.getchannel('A')
    im=ImageEnhance.Color(im).enhance(saturation)
    im=ImageEnhance.Brightness(im).enhance(brightness)
    im.putalpha(alpha)
    return im


def paste(im,piece,x,y,w,h):
    im.alpha_composite(piece.resize((max(1,round(w*S)),max(1,round(h*S))),Image.Resampling.LANCZOS),(round(x*S),round(y*S)))


def text(im,x,y,value,size=12,color='#d8d2c4',bold=False,center=False,native=False):
    font=ImageFont.truetype(FONT if native else BOLD if bold else UIFONT,round(size*S))
    d=ImageDraw.Draw(im)
    if center:x-=d.textlength(value,font=font)/(2*S)
    d.text((round(x*S)+1,round(y*S)+2),value,font=font,fill='#050608')
    d.text((round(x*S),round(y*S)),value,font=font,fill=color)


def slice3(im,source,x,y,w,h,cap):
    # Preserve original end ornaments; extend only the middle region.
    sw,sh=source.size
    dw=min(w*.22,cap*h/sh)
    paste(im,source.crop((0,0,cap,sh)),x,y,dw,h)
    paste(im,source.crop((cap,0,sw-cap,sh)),x+dw,y,w-2*dw,h)
    paste(im,source.crop((sw-cap,0,sw,sh)),x+w-dw,y,dw,h)


def tiled(im,source,x,y,w,h):
    source=source.resize((max(1,round(source.width*h/source.height*S)),round(h*S)),Image.Resampling.LANCZOS)
    band=Image.new('RGBA',(round(w*S),round(h*S)))
    for p in range(0,band.width,source.width):band.alpha_composite(source,(p,0))
    im.alpha_composite(band,(round(x*S),round(y*S)))


SHELL=local('actionbars/HDActionBar.tga')
JOINED=local('actionbars/HDActionBarXP.tga',(0,0,512,144))
BUTTON=local('actionbars/HDActionBarBtn.tga')
XP=local('xprep/main_soft.tga')
VANILLA=Image.open(OUT/'research/vanilla/compact7-no-xp.png').convert('RGBA')
VANILLAXP=Image.open(OUT/'research/vanilla/compact7-xp.png').convert('RGBA')
ICONS=[Image.open(OUT/'research/Attack.png').convert('RGBA'),local('chat/cleaner_coins.tga',(0,0,32,32)),Image.open(OUT/'research/LootAll.png').convert('RGBA')]
BODY=grade(asset('R06',(0,32,64,44)),.2,.62)


def action(im,x,seam,vanilla,xp):
    if vanilla:
        upper=VANILLAXP if xp else VANILLA
        paste(im,upper,x,seam-upper.height,300,upper.height)
        return
    height=72 if xp else 64
    top=seam-height+8
    half=JOINED if xp else SHELL
    # Composite only through the actual silver edge, excluding its blank padding.
    canvas=Image.new('RGBA',(900,round(height*S)))
    paste(canvas,half,0,0,150,height)
    paste(canvas,half.transpose(Image.Transpose.FLIP_LEFT_RIGHT),150,0,150,height)
    for j in range(7):paste(canvas,BUTTON,2+j*42,10,44,44)
    if xp:
        fill=XP.resize((282*S,6*S),Image.Resampling.BILINEAR)
        r,g,b,a=fill.split()
        fill=Image.merge('RGBA',(r.point(lambda v:round(v*.85)),g.point(lambda v:round(v*.4)),b.point(lambda v:round(v*.85)),a))
        canvas.alpha_composite(fill.crop((0,0,round(282*.62*S),6*S)),(9*S,53*S))
    canvas=canvas.crop((0,0,canvas.width,round((height-8)*S)))
    im.alpha_composite(canvas,(round(x*S),round(top*S)))


def spartan(im,ids,x,seam,w,h):
    left,center,right=[grade(asset(i),.25 if ids[0]=='N20' else .48,1.12) for i in ids]
    lw=min(42,left.width*h/left.height)
    rw=min(42,right.width*h/right.height)
    paste(im,left,x,seam,lw,h)
    paste(im,center,x+lw,seam,w-lw-rw,h)
    paste(im,right,x+w-rw,seam,rw,h)


def lower_art(im,design,x,y):
    _,_,_,kind,ids,_=design
    h=36
    if kind in ('scroll','gargoyle'):
        source=grade(asset(ids[0]),.4,1.28)
        slice3(im,source,x,y,300,h,55 if source.width>300 else 43)
    elif kind in ('shrine','bones'):
        # Keep the original side scrolls and lower edge, extending the open
        # native trough instead of its second, internal resource-divider line.
        source=grade(asset('R03'),.4,1.28)
        cap=32
        paste(im,source.crop((0,0,43,49)),x,y,cap,h)
        paste(im,source.crop((213,0,256,49)),x+300-cap,y,cap,h)
        paste(im,grade(asset('R03',(43,58,213,80)),.4,1.28),x+cap,y,300-2*cap,29)
        paste(im,grade(asset('R03',(43,99,213,107)),.4,1.28),x+cap,y+29,300-2*cap,7)
    elif kind in ('filigree','button'):
        source=grade(asset(ids[0]),.48,1.25)
        slice3(im,source,x,y,300,h,34)
    elif kind=='angular':
        source=grade(asset('R04'),.38,1.25)
        slice3(im,source,x,y+18,300,18,27)
        # Continue source corner side pixels to the shared seam, with no new rim.
        paste(im,source.crop((4,0,12,8)),x+4,y,5,19)
        paste(im,source.crop((244,0,252,8)),x+291,y,5,19)
    elif kind=='diablo2':
        tiled(im,grade(asset('R20'),.1,1.14),x,y+27,300,10)
        raw=asset('R20',(381,228,426,474))
        paste(im,grade(raw,.1,1.14),x,y,11,29)
        paste(im,grade(raw,.1,1.14).transpose(Image.Transpose.FLIP_LEFT_RIGHT),x+289,y,11,29)
    elif kind=='scrollcaps':
        tiled(im,grade(asset('R06'),.1,1.15),x+21,y,258,h)
        cap=grade(asset('R09'),.35,1.15)
        paste(im,cap,x,y,30,36)
        paste(im,cap.transpose(Image.Transpose.FLIP_LEFT_RIGHT),x+270,y,30,36)
    elif kind=='knots':
        slice3(im,grade(asset('R25'),.25,1.25),x,y+9,300,28,30)
    elif kind in ('masonry','weathered'):
        source=asset('D1',(150,100,280,180)) if kind=='masonry' else asset('N23')
        tiled(im,grade(source,.1,.52 if kind=='masonry' else .7),x+4,y,292,h)
        slice3(im,grade(asset('R05'),.15,1.3),x,y,300,h,34)
    elif kind=='acanthus':
        source=grade(asset('R16'),.52,1.23)
        slice3(im,source,x,y+24,300,14,42)
        cap=grade(asset('R09'),.35,1.1)
        paste(im,cap,x,y,24,31)
        paste(im,cap.transpose(Image.Transpose.FLIP_LEFT_RIGHT),x+276,y,24,31)
    elif kind=='arpg':
        source=grade(asset('ARPG',(325,24,699,63)),.45,1.4)
        paste(im,source,x,y,300,40)
    elif kind in ('dragon','elite'):
        source=grade(asset('N0'),.4,1.2)
        paste(im,grade(asset('N0',(58,60,106,106)),.4,1.2),x,y,31,36)
        paste(im,grade(asset('N0',(406,60,454,106)),.4,1.2),x+269,y,31,36)
        # Stop before the source's transparent edge fade so the center rail
        # joins the original right ornament without changing its geometry.
        paste(im,grade(asset('N0',(106,88,400,106)),.4,1.2),x+29,y+23,242,14)
    elif kind in ('classic','tribal','shard','midnight'):
        spartan(im,ids,x,y,300,36)
    if kind=='bones':
        cap=grade(asset('R09'),.2,1.1)
        paste(im,cap,x,y+1,25,30)
        paste(im,cap.transpose(Image.Transpose.FLIP_LEFT_RIGHT),x+275,y+1,25,30)
    return h


def lower(im,design,x,y):
    stage=Image.new('RGBA',(300*S,64*S))
    lower_art(stage,design,0,0)
    # Close the real bitmap silhouette up to the shared seam. This keeps the
    # dark source material inside carved/pointed outlines and off their skirts.
    alpha=stage.getchannel('A')
    mask=Image.new('L',stage.size)
    draw=ImageDraw.Draw(mask)
    for column in range(stage.width):
        bottom=next((row for row in range(36*S-1,-1,-1) if alpha.getpixel((column,row))>=96),None)
        if bottom is not None:draw.line((column,0,column,bottom),fill=255)
    if design[3]=='angular':
        # The lower flare is wider than the action bar's visible bottom edge.
        # Keep its projected backing inside that edge until the flare begins.
        inset=300*12/1024
        left,right=round(inset*S),round((300-inset)*S)
        bottom=round(18*S)-1
        draw.rectangle((0,0,left-1,bottom),fill=0)
        draw.rectangle((right,0,stage.width-1,bottom),fill=0)
    backing=Image.new('RGBA',stage.size)
    tiled(backing,BODY,0,0,300,36)
    backing.putalpha(ImageChops.multiply(backing.getchannel('A'),mask))
    backing.alpha_composite(stage)
    # Footer crests overlap the real lower rim; they do not extend the body
    # silhouette or create backing islands in the open space around their wings.
    kind=design[3]
    if kind=='elite':paste(backing,grade(asset('N1',(208,100,304,128)),.42,1.25),119,26,62,18)
    if kind=='gargoyle':paste(backing,grade(asset('R15'),.18,1.18),116,20,68,25)
    if kind=='bones':paste(backing,grade(asset('R12'),.38,1.08),114,24,72,29)
    im.alpha_composite(backing,(round(x*S),round(y*S)))


def values(im,x,seam):
    # Identical18-unit native icons and samples in every proposal.
    for j in range(3):
        left=x+45+j*72
        paste(im,ICONS[j],left,seam+6,18,18)
        text(im,left+45.5,seam+7,['1,248','3,820','450'][j],12,'#eee1bf',center=True,native=True)


def sample(im,design,x,seam,vanilla,xp):
    lower(im,design,x,seam)
    action(im,x,seam,vanilla,xp)
    values(im,x,seam)


def proof(im,design,x,y,w):
    source=asset(design[4][0],ASSETS[design[4][0]].get('rect'))
    if design[3]=='masonry':source=asset('D1',(150,100,280,180))
    if design[3]=='arpg':source=asset('ARPG',(325,24,699,63))
    ratio=min(w/source.width,52/source.height)
    display_w,display_h=source.width*ratio,source.height*ratio
    for yy in range(0,round(58*S),18):
        for xx in range(0,round(w*S),18):
            color='#2b3038' if (yy//18+xx//18)%2 else '#353b44'
            ImageDraw.Draw(im).rectangle((round(x*S)+xx,round(y*S)+yy,round(x*S)+xx+18,round(y*S)+yy+18),fill=color)
    paste(im,source,x+(w-display_w)/2,y+(58-display_h)/2,display_w,display_h)


def make(design,xp=True):
    im=Image.new('RGBA',(900*S,430*S),'#10151c')
    number,name,source,kind,ids,desc=design
    text(im,27,18,number+'  '+name,25,'#dfd6c0',True)
    text(im,27,55,source,13,'#baa681')
    text(im,240,104,'VANILLA CHROME · COMPACT STUDY',11,'#acb8c6',center=True)
    text(im,660,104,'INSTALLED BAR · XP '+('ON' if xp else 'OFF'),11,'#acb8c6',center=True)
    sample(im,design,90,217,True,xp)
    sample(im,design,510,217,False,xp)
    text(im,27,299,desc,13,'#c1c8cd')
    text(im,27,325,'Actual source crop',11,'#a3adba')
    proof(im,design,27,345,300)
    text(im,355,346,'The same upper edge is shared with the action bar.',12,'#b5bfcb')
    text(im,355,369,'Original icons. Bitmap art cropped and toned to Vanilla gray.',11,'#95a4b4')
    text(im,355,392,'Static composition · selected skin not installed',10,'#768696')
    suffix='' if xp else '-xp-off'
    im.convert('RGB').save(OUT/(number+suffix+'.png'))
    return im


def render():
    images=[make(d) for d in DESIGNS]
    for d in DESIGNS:make(d,False)
    records=[]
    for d in DESIGNS:
        records.append(dict(id=d[0],name=d[1],source=d[2],description=d[5],image=d[0]+'.png',imageXPoff=d[0]+'-xp-off.png',assets=[{'id':id,**ASSETS[id]} for id in d[4]]))
    (OUT/'designs.json').write_text(json.dumps(records,indent=2)+'\n')
    (OUT/'sources.json').write_text(json.dumps({
        'designs':records,
        'vanilla':json.loads((OUT/'research/vanilla/sources.json').read_text()),
        'commonBackground':{'asset':ASSETS['R06'],'crop':[0,32,64,44],'use':'Original texture shaded inside the real bitmap contour, never outside the lower silhouette.'},
        'cropOverrides':{
            '02,20':{'R03':[[0,58,43,107],[213,58,256,107],[43,58,213,80],[43,99,213,107]]},
            '04':{'R04':[[0,16,256,32],[4,16,12,24],[244,16,252,24]]},
            '05':{'R20':[[381,474,1024,512],[381,228,426,474]]},
            '08':{'D1':[[150,100,280,180]]},
            '10':{'ARPG':[[325,24,699,63]]},
            '12,13':{'N0':[[58,60,106,106],[406,60,454,106],[106,88,400,106]]},
            '13':{'N1':[[208,100,304,128]]},
        },
        'assembly':'scripts/preview_tally_gothic.py contains exact crop overrides, slice widths, placements and tone adaptation; every upper border is omitted.',
        'runtime':'Static artwork proposals only. Original bytes remain separate under research/originals. No runtime textures or font added.',
    },indent=2)+'\n')
    for page in range(2):
        sheet=Image.new('RGB',(1600,1560),'#10151c')
        dd=ImageDraw.Draw(sheet)
        dd.text((25,15),f'GOTHIC / DIABLO TALLY — {page*10+1:02d}–{page*10+10:02d}',font=ImageFont.truetype(BOLD,27),fill='#e1d6bd')
        dd.text((25,52),'Real GitHub artwork · Vanilla on left / installed bar on right · one shared top edge',font=ImageFont.truetype(UIFONT,17),fill='#aab8c7')
        for j in range(10):
            thumb=images[page*10+j].resize((770,368),Image.Resampling.LANCZOS).crop((0,0,770,271))
            sheet.paste(thumb,(15+(j%2)*795,88+(j//2)*292))
        sheet.save(OUT/f'sheet-{page+1}.png')
    overview=Image.new('RGB',(1800,1750),'#10151c')
    dd=ImageDraw.Draw(overview)
    dd.text((25,15),'20 GOTHIC / DIABLO DESIGNS — REAL WOW UI ASSETS',font=ImageFont.truetype(BOLD,27),fill='#e1d6bd')
    for j,im in enumerate(images):
        thumb=im.resize((580,277),Image.Resampling.LANCZOS).crop((0,0,580,204))
        overview.paste(thumb,(15+(j%3)*595,62+(j//3)*239))
    overview.save(OUT/'overview.png')
    cards=[]
    for r in records:
        links=' · '.join(f'<a href="{html.escape(a["source_url"])}" target="_blank">{html.escape(a["path"].split("/")[-1])}</a>' for a in r['assets'])
        cards.append(f'<article data-name="{r["name"].lower()} {r["source"].lower()}"><h2>{r["id"]} · {html.escape(r["name"])}</h2><p>{html.escape(r["source"])}</p><a class="full" href="{r["image"]}" target="_blank"><img data-id="{r["id"]}" src="{r["image"]}" alt="{html.escape(r["description"])}" loading="lazy"></a><p>{html.escape(r["description"])}</p><div class="sources">Actual assets: {links}</div><button onclick="pick(\'{r["id"]}\')">Compare {r["id"]}</button></article>')
    (OUT/'index.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>20 Gothic tally designs — real WoW artwork</title><style>body{margin:0;background:#10151c;color:#dfd6c0;font:16px system-ui}header{padding:23px;background:#10151cf0;border-bottom:1px solid #35404d;position:sticky;top:0;z-index:2}h1{font-size:26px;margin:0 0 8px}p{color:#aab7c5;line-height:1.5}main{padding:22px;display:grid;grid-template-columns:repeat(auto-fit,minmax(570px,1fr));gap:20px}article{padding:15px;background:#171e28;border:1px solid #394454;border-radius:8px}article h2{font-size:20px;margin:0}article p{margin:8px 0}img{display:block;width:100%}a{color:#d1ba85}button,input{padding:8px 12px;background:#27313e;color:#e8dcc1;border:1px solid #576271;border-radius:4px;margin:4px}.sources{font-size:12px;padding:10px 0;line-height:1.8}#compare{position:fixed;inset:0;z-index:4;display:none;overflow:auto;background:#090d13f8;padding:25px}#compare img{max-width:1500px;margin:auto}.note{font-size:13px}</style><header><h1>20 Gothic / Diablo tally designs</h1><p>Actual texture artwork from RothUI, Diablo III UI, ARPG and SpartanUI. Every design shares its top edge with the action bar and keeps the original three icons.</p><input placeholder="Filter designs or sources" oninput="document.querySelectorAll('article').forEach(a=>a.hidden=!a.dataset.name.includes(this.value.toLowerCase()))"><button onclick="toggleXP()" id="xp">XP: on</button><button onclick="showCompare()">Open comparison</button><span id="chosen"></span><p class="note">Left: adapted seven-slot Vanilla chrome. Right: the installed action bar. Click an image for its full size and source crop. <a href="research/vanilla/vanilla-context-preview.png">Original Vanilla reference</a> · <a href="ARTWORK.md">Source and artwork notes</a> · <a href="overview.png">All 20</a></p></header><main>'''+''.join(cards)+'''</main><section id="compare"><button onclick="document.getElementById('compare').style.display='none'">Close</button><button onclick="selected.clear();showCompare()">Clear selection</button><div id="picked"></div></section><script>let xp=true;const selected=new Set();function filename(id){return id+(xp?'':'-xp-off')+'.png'}function toggleXP(){xp=!xp;document.getElementById('xp').textContent='XP: '+(xp?'on':'off');document.querySelectorAll('img[data-id]').forEach(im=>{im.src=filename(im.dataset.id);im.parentElement.href=im.src});}function pick(id){selected.has(id)?selected.delete(id):selected.add(id);document.getElementById('chosen').textContent=' Selected: '+[...selected].join(', ')}function showCompare(){document.getElementById('compare').style.display='block';document.getElementById('picked').innerHTML=[...selected].map(id=>'<img src="'+filename(id)+'">').join('')||'<p>Select designs with Compare first.</p>'}</script></html>''')


if __name__=='__main__':render()
