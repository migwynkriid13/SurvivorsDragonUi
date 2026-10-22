"""Archived Vanilla chrome assembly record; this file is intentionally inert.

The original public-comparison/UI-MainMenuBar-Dwarf.PNG and
public-comparison/UI-MainMenuBar-EndCap-Dwarf.PNG inputs were temporary
preparation files and are not retained here. Their exact public source paths
and commit pins remain in sources.json. The generated context/compact PNGs are
retained. This record does not download inputs or generate artwork when run.
"""

ASSEMBLY_RECORD = r"""
from pathlib import Path
from PIL import Image, ImageOps, ImageDraw, ImageFont
import json

ROOT=Path('vanilla-preparation')  # Historical preparation-directory basename.
PUBLIC=ROOT/'public-comparison'
atlas=Image.open(PUBLIC/'UI-MainMenuBar-Dwarf.PNG').convert('RGBA')
gryphon=Image.open(PUBLIC/'UI-MainMenuBar-EndCap-Dwarf.PNG').convert('RGBA')
body=Image.new('RGBA',(1024,43))
rail=Image.new('RGBA',(1024,10))
for index,(top,bottom) in enumerate([(213,256),(149,192),(85,128),(21,64)]):
    body.alpha_composite(atlas.crop((0,top,256,bottom)),(index*256,0))
for index,(top,bottom) in enumerate([(203,213),(139,149),(75,85),(11,21)]):
    rail.alpha_composite(atlas.crop((0,top,256,bottom)),(index*256,0))
body.save(ROOT/'vanilla-1024-body.png')
rail.save(ROOT/'vanilla-1024-xp-rail.png')
full=Image.new('RGBA',(1216,128))
full.alpha_composite(body,(96,85))
full.alpha_composite(rail,(96,75))
full.alpha_composite(gryphon,(0,0))
full.alpha_composite(ImageOps.mirror(gryphon),(1088,0))
full.save(ROOT/'vanilla-full-1024-with-gryphons.png')
compact=body.crop((2,0,302,43))
compact.paste(body.crop((506,0,512,43)),(294,0))
compact.save(ROOT/'compact7-no-xp.png')
compact_rail=rail.crop((2,0,302,10))
compact_rail.paste(rail.crop((506,0,512,10)),(294,0))
compact_rail.save(ROOT/'compact7-xp-rail.png')
compact_xp=Image.new('RGBA',(300,53))
compact_xp.alpha_composite(compact_rail,(0,0))
compact_xp.alpha_composite(compact,(0,10))
compact_xp.save(ROOT/'compact7-xp.png')
compact_gryphons=Image.new('RGBA',(492,128))
compact_gryphons.alpha_composite(compact_xp,(96,75))
compact_gryphons.alpha_composite(gryphon,(0,0))
compact_gryphons.alpha_composite(ImageOps.mirror(gryphon),(364,0))
compact_gryphons.save(ROOT/'compact7-with-gryphons.png')
font_path='/System/Library/Fonts/Supplemental/Arial.ttf'
font=ImageFont.truetype(font_path,22)
small=ImageFont.truetype(font_path,16)
preview=Image.new('RGBA',(1400,600),(24,29,34,255))
draw=ImageDraw.Draw(preview)
draw.text((24,18),'VANILLA FRAME ART / ORIGINAL 1.12.1 ASSEMBLY REFERENCE',font=font,fill=(225,219,201))
draw.text((24,54),'Retained legacy pixels from pinned Gethe mirror; original source geometry from pinned Vanilla FrameXML.',font=small,fill=(165,178,188))
preview.alpha_composite(full,(92,88))
draw.text((24,245),'ADAPTED SEVEN-SLOT CHROME / 300 LOCAL UNITS',font=font,fill=(225,219,201))
draw.text((24,278),'Existing source pixels cropped and stitched; this compact layout is not the original 1.12.1 layout.',font=small,fill=(165,178,188))
preview.alpha_composite(compact_xp.resize((600,106),Image.Resampling.NEAREST),(72,325))
preview.alpha_composite(compact.resize((600,86),Image.Resampling.NEAREST),(728,345))
draw.text((72,448),'Native XP border included; fill omitted',font=small,fill=(165,178,188))
draw.text((728,448),'Native body without XP border',font=small,fill=(165,178,188))
draw.text((24,518),'Palette: aged silver / gray highlights, charcoal stone, muted olive-brown recesses. No recolor applied.',font=small,fill=(194,194,182))
draw.text((24,550),'Static sprite composition only; no addon or game execution. Local packaged atlas kept separately because its menu quarter is modified.',font=small,fill=(165,178,188))
preview.convert('RGB').save(ROOT/'vanilla-context-preview.png')
metadata={
 'source_framexml':{'repo':'MOUZU/Blizzard-WoW-Interface','commit':'d162a4c0d198a4381b5b6573d975635ed7316702','era':'1.12.1','paths':['1.12.1/FrameXML/MainMenuBar.xml','1.12.1/FrameXML/ActionBarFrame.xml','1.12.1/FrameXML/ActionButtonTemplate.xml']},
 'source_pixels':{'repo':'Gethe/wow-ui-textures','commit':'e80e3278cc833c89e1f3fc79557b68315d750935','era':'Dragonflight PTR10.0.0(45454) retained legacy textures, not claimed byte-identical1.12.1','paths':['MAINMENUBAR/UI-MainMenuBar-Dwarf.PNG','MAINMENUBAR/UI-MainMenuBar-EndCap-Dwarf.PNG']},
 'body_rects':[[0,213,256,256],[0,149,256,192],[0,85,256,128],[0,21,256,64]],
 'xp_rects':[[0,203,256,213],[0,139,256,149],[0,75,256,85],[0,11,256,21]],
 'original_assembly':{'bar':[1024,53],'body':[1024,43],'xp_border':[1024,10],'gryphons':[128,128],'left_cap_center_x_from_bar_center':-544,'right_cap_center_x_from_bar_center':544,'output_canvas':[1216,128],'bar_x':96,'body_y':85,'xp_y':75,'left_cap_x':0,'right_cap_x':1088},
 'compact_assembly':{'adaptation':'Seven native slots at36px with6px gaps, originx6; use native first12slot strip x2..302 and replace final6 columns with x506..512. All trim remains original source pixels.','width':300,'height_without_xp':43,'height_with_xp':53,'native_slot_x':[6,48,90,132,174,216,258],'native_slot_y_from_body_top':3,'native_slot_size':[36,36]},
 'local_extraction':{'archive':'local game archive: patch.MPQ','paths':['Interface\\MainMenuBar\\UI-MainMenuBar-Dwarf.blp','Interface\\MainMenuBar\\UI-MainMenuBar-EndCap-Dwarf.blp','Interface\\MainMenuBar\\UI-MainMenuBar-Human.blp','Interface\\Buttons\\UI-Quickslot.blp'],'caveat':'Dwarf menu quarter changed to additional ability placeholders in packaged game. Not used for full-original assembly. mpyq raw-block reader needs direct bytes for flags0x80000000 to avoid misinterpreting uncompressed contiguous blocks as sector tables.'},
 'rights':'Blizzard Entertainment artwork. Public mirror and source availability do not grant a new art license. Context/proposal files only; no runtime import.'
}
(ROOT/'sources.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n')

"""
