"""Compose static design proposals from real artwork. Never load addon Lua."""

from pathlib import Path
import json
from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/designs/guardian-tracker"
TEX = ROOT / "media/tex"
S = 2
GOLD = "#ddbd7d"
WHITE = "#eee5cf"
MUTED = "#9caaa6"
GREEN = "#9cce85"
RED = "#ed8a75"
AMBER = "#e6ba65"
FONT = "/System/Library/Fonts/Supplemental/Arial.ttf"
BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
ROWS = [
    ("Dreadmaw", "Asleep", GREEN),
    ("Bloodtalon", "Fighting 70%", RED),
    ("Marshlurker", "Returns 1:24", AMBER),
    ("Mournshade", "Due", GOLD),
    ("Ashfang", "Empty", MUTED),
]
DESIGNS = [
    ("Waypoint ledger", "The closest fit to the existing Guardian HUD.", "A", "A transparent list, one medallion and the existing muted gold baseline."),
    ("Editor metal ledger", "Matches the /sdui diamond-metal frame.", "AB", "A contained list using the editor's fixed corners and stretched edge strips."),
    ("Character metal panel", "Plain Blizzard metal, restrained gold text.", "AC", "A compact sibling of the character window with its plain metal frame."),
    ("Quest header list", "A published quest-tracker header above open rows.", "AD", "An older retail-style header option; more ornamental than the current HUD."),
    ("Medallion stack", "Independent rows built around the Guardian medallion.", "A", "A smaller repeat of the existing floating waypoint language on every row."),
    ("State chapters", "Separate sections for held and vacant lairs.", "A", "Status grouping keeps fighting and upcoming returns easy to find."),
    ("Two-column ledger", "Living on the left, vacant lairs on the right.", "AB", "A wider, shorter list for placement below the minimap."),
    ("Numbered lair register", "A compact three-column register in native order.", "AB", "Stable lair numbers, names and a right-aligned status column."),
    ("Timer bezel rows", "The same gold-edged pills as the run timer.", "AE", "Each status sits inside a real timer bezel; only known health has a fill."),
    ("Horizontal nameplates", "Five small entries in a single row.", "A", "A wide strip with one medallion per lair and status underneath."),
    ("Lair tile grid", "A compact three-by-two arrangement.", "AC", "Five metal tiles with clear state text and a reserved final summary cell."),
    ("Numbered spine", "A vertical guide line with small lair badges.", "AF", "One continuous spine keeps the list visually light."),
    ("Metal row cards", "Shallow character-panel cards for each guardian.", "AC", "Native stat-card pieces form individual rows without a surrounding window."),
    ("Fight focus", "A larger active fight beside the complete roster.", "ACE", "Highlights the fighting guardian's actual health; all other lairs stay listed."),
    ("Next return focus", "A large return time beside the held lairs.", "ABE", "A readable native countdown without inventing a respawn progress percentage."),
    ("Micro ledger", "The narrowest complete list.", "A", "A very small open ledger with concise, readable status text."),
    ("Soft shadow ledger", "A fading dark backdrop borrowed from Level Up.", "AF", "The soft backdrop supports the text without another hard window border."),
    ("Highlighted register", "A single focus row with the editor's gold selection.", "AB", "A list that can later show the selected lair; the preview demonstrates the artwork only."),
    ("Bottom status tray", "Five evenly spaced state cells in a thin tray.", "ABE", "A low, wide alternative intended near the action-bar stack."),
    ("Waypoint companion", "The current guidance label above a matching roster.", "A", "Reuses the visual proportions of the existing Guardian guidance HUD."),
]


def art(path, crop=None):
    image = Image.open(TEX / path).convert("RGBA")
    return image.crop(crop) if crop else image


ICON = art("waypoint/GuardianFloating.tga", (0, 0, 65, 65))
EDITOR = art("editor/border.tga")
CHROME = art("character/Chrome.tga")
PARTS = art("character/Parts.tga")


def paste(image, layer, box, opacity=1):
    x, y, w, h = box
    layer = layer.resize((max(1, round(w*S)), max(1, round(h*S))), Image.Resampling.LANCZOS)
    if opacity != 1:
        layer.putalpha(layer.getchannel("A").point(lambda v: round(v*opacity)))
    image.alpha_composite(layer, (round(x*S), round(y*S)))


def text(image, x, y, message, size=14, color=WHITE, bold=False, right=False, width=None):
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype(BOLD if bold else FONT, round(size*S))
    if width is not None:
        original = message
        while message and draw.textlength(message, font=font) > width*S:
            original = original[:-1]
            message = original + "…"
    if right:
        x -= draw.textlength(message, font=font)/S
    draw.text((round(x*S)+1, round(y*S)+2), message, font=font, fill="#000000")
    draw.text((round(x*S), round(y*S)), message, font=font, fill=color)


def rect(image, box, color):
    x, y, w, h = box
    ImageDraw.Draw(image).rectangle((round(x*S), round(y*S), round((x+w)*S), round((y+h)*S)), fill=color)


def line(image, x, y, w, color="#806744"):
    rect(image, (x, y, w, 0.6), color)


def icon(image, x, y, size=28, opacity=1):
    paste(image, ICON, (x, y, size, size), opacity)


def panel(image, x, y, w, h, kind="editor"):
    rect(image, (x+5, y+5, w-10, h-10), "#111817ed")
    if kind == "editor":
        size = 25
        pieces = [EDITOR.crop((i*128, 0, (i+1)*128, 128)) for i in range(8)]
        positions = [
            (x, y, size, size), (x+w-size, y, size, size),
            (x, y+h-size, size, size), (x+w-size, y+h-size, size, size),
            (x, y+size, size, h-2*size), (x+w-size, y+size, size, h-2*size),
            (x+size, y, w-2*size, size), (x+size, y+h-size, w-2*size, size),
        ]
    else:
        size = 34
        pieces = [CHROME.crop(b) for b in [
            (0, 0, 150, 150), (256, 0, 406, 150),
            (512, 0, 576, 64), (640, 0, 704, 64),
            (0, 192, 150, 224), (256, 192, 406, 224),
            (768, 0, 832, 150), (896, 0, 928, 64),
        ]]
        positions = [
            (x, y, size, size), (x+w-size, y, size, size),
            (x, y+h-16, 16, 16), (x+w-16, y+h-16, 16, 16),
            (x, y+size, size, h-size-16), (x+w-size, y+size, size, h-size-16),
            (x+size, y, w-2*size, size), (x+16, y+h-16, w-32, 16),
        ]
    for piece, position in zip(pieces, positions):
        paste(image, piece, position)


def heading(image, x, y, w, title="GUARDIANS", count=True):
    icon(image, x, y-5, 30)
    text(image, x+39, y, title, 17, GOLD, True)
    if count:
        text(image, x+w, y+3, "2 / 5 alive", 12, MUTED, right=True)


def row(image, x, y, w, number, rowdata, medallion=False, small=False, index=False):
    name, status, color = rowdata
    offset = 0
    if medallion:
        icon(image, x-2, y-4, 25, opacity=1 if number<2 else 0.65)
        offset = 31
    elif index:
        text(image, x, y+1, str(number+1).zfill(2), 11, MUTED)
        offset = 29
    size = 12 if small else 14
    status_width = 90 if small else 115
    text(image, x+offset, y, name, size, GOLD, width=w-offset-status_width-12)
    text(image, x+w, y, status, size, color, right=True)


def rows(image, x, y, w, height=31, indices=None, **kwargs):
    selected = range(5) if indices is None else indices
    for j, i in enumerate(selected):
        row(image, x, y+j*height, w, i, ROWS[i], **kwargs)


def pill(image, x, y, w, label, color=GOLD, health=None, boss=False):
    paste(image, art("timer/BackgroundCenter.tga", (0, 0, 64, 18)), (x+8, y+5, w-16, 15))
    if health is not None:
        fill=art("timer/FillWhite.tga", (0, 0, 256, 15))
        tint=ImageChops.multiply(fill,Image.new("RGBA",fill.size,(219,31,26,255))) if boss else Image.new("RGBA",fill.size,RED)
        tint.putalpha(fill.getchannel("A"))
        paste(image,tint,(x+10,y+6,(w-20)*health,13),1 if boss else 0.7)
    paste(image, art("timer/BorderCenter.tga", (0, 0, 64, 31)), (x+16, y, w-32, 26))
    paste(image, art("timer/BorderLeft.tga", (0, 0, 35, 31)), (x, y, 29, 26))
    paste(image, art("timer/BorderRight.tga", (0, 0, 35, 31)), (x+w-29, y, 29, 26))
    text(image, x+w/2+ImageDraw.Draw(image).textlength(label,font=ImageFont.truetype(FONT,12*S))/(2*S), y+6,label,12,color,right=True)


def card(image,x,y,w,h):
    paste(image,PARTS.crop((1,65,170,74)),(x,y,w,7))
    paste(image,PARTS.crop((1,192,170,200)),(x,y+7,w,h-18))
    paste(image,PARTS.crop((1,1,170,47)),(x,y+h-22,w,22))


def make(index, selected=False, collapsed=False):
    image=Image.new("RGBA",(720*S,440*S))
    d=ImageDraw.Draw(image)
    for y in range(440*S):
        t=y/(440*S)
        d.line((0,y,720*S,y),fill=(round(22-8*t),round(33-12*t),round(31-10*t)))
    title,subtitle,recipe,_=DESIGNS[index-1]
    if selected:
        title, subtitle, recipe = "Guardians · expanded", "Minus visible: all lairs, including respawn timers and empty lairs.", "ADE"
        if collapsed:
            title, subtitle = "Guardians · collapsed", "Plus visible: only living guardians, including those in combat."
    text(image,25,20,f"{'04 + 09' if selected else str(index).zfill(2)}   {title}",22,GOLD,True)
    text(image,25,52,subtitle,12,MUTED)
    if index==1:
        heading(image,170,118,370); rows(image,170,164,370);line(image,170,326,370)
    elif index in (2,3):
        panel(image,137,103,446,251,"editor" if index==2 else "metal")
        if index==2:paste(image,art("editor/header.tga",(0,0,199,32)),(164,122,392,30),0.55)
        heading(image,164,126,392); rows(image,169,178,380,height=30)
    elif index==4:
        canvas=image
        gap=16*0.1 if selected else 0
        if selected:
            image=Image.new("RGBA",canvas.size)
        paste(image,Image.open(OUT/"questtracker-header.png").convert("RGBA"),(154,113,408-gap,(408-gap)/8),0.8)
        heading(image,167,128,380-gap,count=not selected)
        if selected:
            toggle = art("minimap/ZoomIn32.tga" if collapsed else "minimap/ZoomOut32.tga")
            toggle_offset=25.6*2/32 if collapsed else 0
            paste(image,toggle,(525.4-gap+toggle_offset,120,25.6,25.6))
        for i, rowdata in enumerate(ROWS):
            if selected and collapsed and i>1:
                continue
            y=184+i*29
            if selected and i==1:
                text(image,171,y,rowdata[0],14,GOLD,width=170)
                pill(image,347-gap,y-5,206,"6300 / 9000","#ffffff",0.7,boss=True)
            else:
                if selected and i==0:
                    rowdata=(rowdata[0],"Alive",rowdata[2])
                elif selected and i==2:
                    rowdata=(rowdata[0],"Respawns in 1:24",rowdata[2])
                elif selected and i==3:
                    rowdata=(rowdata[0],"Alive",GREEN)
                row(image,171,y,378-gap,i,rowdata)
        if selected:
            layer=image.crop((154*S,113*S,562*S,335*S))
            layer=layer.resize((round(layer.width*0.85),round(layer.height*0.85)),Image.Resampling.LANCZOS)
            canvas.alpha_composite(layer,(round((562-408*0.85)*S),113*S))
            image=canvas
    elif index==5:
        text(image,176,110,"GUARDIANS",16,GOLD,True)
        text(image,548,113,"2 / 5 alive",12,MUTED,right=True)
        rows(image,174,158,374,height=36,medallion=True)
    elif index==6:
        heading(image,166,112,392)
        text(image,169,153,"HELD LAIRS",10,MUTED,True);line(image,169,171,386)
        rows(image,173,184,379,height=29,indices=[0,1])
        text(image,169,252,"VACANT LAIRS",10,MUTED,True);line(image,169,270,386)
        rows(image,173,282,379,height=27,indices=[2,3,4])
    elif index==7:
        panel(image,72,127,576,203);heading(image,98,149,524)
        text(image,101,194,"HELD",10,MUTED,True);text(image,375,194,"VACANT",10,MUTED,True)
        rows(image,101,219,243,height=31,indices=[0,1],small=True)
        rows(image,375,219,243,height=31,indices=[2,3,4],small=True)
    elif index==8:
        panel(image,140,100,440,260);heading(image,165,124,388)
        text(image,170,166,"LAIR",10,MUTED,True);text(image,205,166,"GUARDIAN",10,MUTED,True)
        text(image,550,166,"STATE",10,MUTED,True,right=True);line(image,166,184,388)
        rows(image,170,196,380,height=29,index=True)
    elif index==9:
        heading(image,159,104,401)
        for i,(name,status,col) in enumerate(ROWS):
            y=157+i*35;text(image,166,y+6,name,14,GOLD,width=166)
            pill(image,341,y,216,status,col,0.7 if i==1 else None)
    elif index==10:
        text(image,65,167,"GUARDIANS",16,GOLD,True);text(image,653,170,"2 / 5 alive",12,MUTED,right=True)
        for i,(name,status,col) in enumerate(ROWS):
            x=65+i*121;icon(image,x+36,212,38,opacity=1 if i<2 else 0.6)
            text(image,x+7,259,name,12,GOLD,width=110)
            text(image,x+7,281,status,11,col)
        line(image,65,312,589)
    elif index==11:
        heading(image,111,104,497)
        for i,(name,status,col) in enumerate(ROWS):
            x=111+(i%3)*169;y=157+(i//3)*96
            card(image,x,y,158,83);icon(image,x+11,y+11,25,opacity=1 if i<2 else 0.6)
            text(image,x+43,y+13,"LAIR "+str(i+1),10,MUTED)
            text(image,x+12,y+41,name,13,GOLD);text(image,x+12,y+59,status,11,col)
        text(image,461,275,"2 / 5 alive",17,GOLD)
    elif index==12:
        heading(image,163,109,393);rect(image,(177,162,0.5,155),"#806744")
        for i in range(5):
            y=161+i*33;paste(image,art("levelup/CountBadge.tga",(0,0,64,64)),(165,y-2,24,24),0.4)
            text(image,173,y+3,str(i+1),11,WHITE)
            row(image,209,y,345,i,ROWS[i])
    elif index==13:
        heading(image,160,103,398)
        for i in range(5):
            y=151+i*37;card(image,158,y,404,32);row(image,171,y+7,377,i,ROWS[i],small=True)
    elif index==14:
        panel(image,66,116,589,224,"metal");heading(image,91,138,539)
        card(image,92,182,219,124);icon(image,112,195,40)
        text(image,165,205,"Bloodtalon",15,GOLD,True)
        text(image,113,252,"Fighting",13,RED);text(image,290,250,"70%",22,WHITE,right=True)
        pill(image,107,278,187,"6,300 / 9,000",WHITE,0.7)
        rows(image,329,185,299,height=25,small=True)
    elif index==15:
        panel(image,99,116,523,230);heading(image,124,138,472)
        rows(image,126,194,231,height=32,indices=[0,1],small=True)
        row(image,126,269,231,3,ROWS[3],small=True);row(image,126,300,231,4,ROWS[4],small=True)
        paste(image,art("editor/header.tga",(0,0,199,32)),(379,184,217,34),0.5)
        text(image,391,194,"NEXT RETURN",11,GOLD,True)
        text(image,394,228,"1:24",42,WHITE,True)
        text(image,395,286,"Marshlurker",14,GOLD)
        text(image,395,309,"Lair 3",11,MUTED)
    elif index==16:
        heading(image,214,126,296);rows(image,216,171,289,height=24,small=True)
        line(image,214,302,296)
    elif index==17:
        paste(image,art("levelup/Backdrop.tga"),(129,95,463,269),0.9)
        heading(image,164,125,392);rows(image,168,174,384,height=29)
    elif index==18:
        panel(image,140,103,440,253);heading(image,165,126,389)
        paste(image,art("editor/choice.tga",(0,0,187,21)),(163,206,394,27),0.55)
        rows(image,170,178,381,height=31);line(image,169,337,382)
    elif index==19:
        panel(image,46,156,628,153);heading(image,71,174,576)
        for i,(name,status,col) in enumerate(ROWS):
            x=70+i*117;text(image,x,220,name,12,GOLD,width=112)
            pill(image,x-2,246,113,status,col)
    elif index==20:
        icon(image,258,103,43);text(image,310,105,"Guardian",14,GOLD)
        text(image,310,125,"126 yd",17,WHITE);line(image,258,154,205)
        rows(image,175,186,371,height=29,medallion=True)
        line(image,174,343,373)
    text(image,25,406,"STATIC CONCEPT  ·  SAMPLE NAMES / VALUES  ·  DEFAULT FONT PROXY  ·  RECIPE "+recipe,9,MUTED)
    image.convert("RGB").save(OUT/("collapsed.png" if collapsed else "selected.png" if selected else f"{index:02d}.png"))
    return image.convert("RGB")


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    images=[make(i) for i in range(1,21)]
    expanded=make(4, selected=True)
    collapsed=make(4, selected=True, collapsed=True)
    states=Image.new("RGB",(1440,440),"#111918")
    states.paste(expanded.resize((720,440),Image.Resampling.LANCZOS),(0,0))
    states.paste(collapsed.resize((720,440),Image.Resampling.LANCZOS),(720,0))
    states.save(OUT/"toggle-states.png")
    overview=Image.new("RGB",(1800,880),"#111918")
    for i,img in enumerate(images):overview.paste(img.resize((360,220),Image.Resampling.LANCZOS),((i%5)*360,(i//5)*220))
    overview.save(OUT/"overview.png")
    for group in range(4):
        sheet=Image.new("RGB",(1440,1320),"#111918")
        for j in range(5):sheet.paste(images[group*5+j].resize((720,440),Image.Resampling.LANCZOS),((j%2)*720,(j//2)*440))
        draw=ImageDraw.Draw(sheet)
        draw.text((760,1055),"SurvivorsDragonUi\nGuardian tracker concepts\nStatic compositions of actual artwork.",font=ImageFont.truetype(FONT,20),fill=GOLD,spacing=12)
        sheet.save(OUT/f"sheet-{group+1}.png")
    records=[dict(number=i+1,title=d[0],subtitle=d[1],recipe=d[2],description=d[3]) for i,d in enumerate(DESIGNS)]
    (OUT/"designs.json").write_text(json.dumps(records,indent=2)+"\n")
    cards="\n".join(f'<button class="card" onclick="show({i})"><img src="{i+1:02d}.png" alt="{d[0]}" loading="lazy"><span>{i+1:02d} · {d[0]}</span></button>' for i,d in enumerate(DESIGNS))
    html='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>SurvivorsDragonUi · Guardian tracker designs</title><style>
    *{box-sizing:border-box}body{margin:0;background:#0d1413;color:#e9e3d4;font:16px Arial,sans-serif}header,main{max-width:1600px;margin:auto;padding:30px}header{padding-bottom:12px}h1{color:#ddbd7d;font-size:28px;margin:8px 0 12px}p{line-height:1.6;max-width:960px;color:#afbab4}a{color:#ddbd7d}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:18px}.card{padding:0;border:1px solid #493e2c;border-radius:5px;overflow:hidden;background:#17211d;color:#e5d4ae;text-align:left;cursor:pointer}.card:hover{border-color:#c5a45d}.card img{width:100%;display:block}.card span{display:block;padding:13px}dialog{width:min(1300px,96vw);max-height:94vh;border:1px solid #9e8147;background:#101916;color:#eee5cf;padding:16px;border-radius:5px}dialog::backdrop{background:#000b}dialog img{width:100%}dialog p{max-width:none;margin:12px 0}button.nav{background:#2b3027;border:1px solid #756140;color:#ead6a7;padding:10px 20px;cursor:pointer}.toolbar{display:flex;gap:10px;align-items:center}.toolbar a{margin-left:auto}small{color:#afbab4}footer{padding:30px;color:#9faea5;max-width:1600px;margin:auto;font-size:13px}
    </style><header><small>SURVIVORSDRAGONUI · DESIGN STUDY · 20 OPTIONS</small><h1>Guardian tracker</h1><p>Selected: design 04 with design 09 health bezels only in combat, using the regular boss-bar colors and current / maximum health text. Resting guardians are labelled Alive. The header uses the minimap plus/minus icons: plus shows living guardians only; minus shows every lair. The toggle is session-only. These are the original static proposals assembled from actual WoW artwork. Names and values are samples; Arial stands in for the game’s DEFAULT face.</p><p><strong>Selected combination:</strong> <a href="selected.png">Expanded: all lairs</a> · <a href="collapsed.png">Collapsed: living guardians</a> · <a href="toggle-states.png">Compare both states</a>. The other nineteen options remain available for comparison. Click any design to inspect it. Use the arrow keys to compare.</p><p><a href="asset-study.png">Existing artwork study</a> · <a href="ARTWORK.md">Sources, crops and attribution</a> · <a href="overview.png">All 20 on one sheet</a></p></header><main class="grid">'''+cards+'''</main><dialog id="detail"><div class="toolbar"><button class="nav" onclick="show(current-1)">← Previous</button><button class="nav" onclick="show(current+1)">Next →</button><button class="nav" onclick="detail.close()">Close</button><a id="original" target="_blank">Open full image</a></div><img id="preview"><p id="description"></p><small id="recipe"></small></dialog><footer>Artwork © Blizzard Entertainment. Source projects provide the published artwork; their software licenses do not relicense Blizzard textures. These previews are design compositions, not game captures or evidence of runtime rendering.</footer><script>
    const designs='''+json.dumps(records)+''';let current=0;const detail=document.getElementById('detail');function show(n){current=(n+20)%20;const d=designs[current];const file=String(current+1).padStart(2,'0')+'.png';document.getElementById('preview').src=file;document.getElementById('preview').alt=d.title;document.getElementById('description').textContent=String(d.number).padStart(2,'0')+' · '+d.title+' — '+d.description;document.getElementById('recipe').textContent='Artwork recipe '+d.recipe+' · See ARTWORK.md for exact sources and crops.';document.getElementById('original').href=file;if(!detail.open)detail.showModal()}document.addEventListener('keydown',e=>{if(detail.open&&e.key==='ArrowRight')show(current+1);if(detail.open&&e.key==='ArrowLeft')show(current-1)});
    </script></html>'''
    (OUT/"index.html").write_text(html)


if __name__ == "__main__":
    main()
