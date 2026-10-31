#!/usr/bin/env python3
"""Export 15 Devpost gallery PNGs from authentic app/Kiro captures.

Pillow performs only layout, sizing and framing. No game UI or artwork is
reconstructed. Output: 1800×1200 (3:2), RGB PNG, each below 5,000,000 bytes.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps
import hashlib
import json
import math
import textwrap
import zipfile

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'build/devpost-gallery'
IMAGES = OUT / 'images'
SOURCE = ROOT / 'build/video/android'
W, H = 1800, 1200
INK = '#070b20'
WHITE = '#f3ede1'
GOLD = '#d4b568'
CYAN = '#a0d8e1'
MUTED = '#b8bed0'
CARDS = [
 ('01-hauntquest-ai-cover', 'cover', 'HauntQuest AI',
  'Enter the\nWhispering Manor.',
  'An offline Flutter mystery with five rooms, sixteen puzzles and three attainable endings.',
  ['menu'], ['The Whispering Manor'],
  'HauntQuest AI title screen beside the project introduction. The shipped game and its contextual Guide work offline.'),
 ('02-five-haunted-rooms', 'rooms', 'Five rooms. One investigation.',
  'Follow the trail through the manor.',
  'Moonlit Entrance Hall · Forgotten Library · Alchemist’s Workshop · Clocktower Chamber · Echo Vault',
  ['hall','library','workshop','clocktower','vault'],
  ['Entrance Hall','Forgotten Library','Workshop','Clocktower','Echo Vault'],
  'Five genuine Android room screenshots arranged in the order of the investigation.'),
 ('03-explore-and-discover', 'pair', 'Explore & discover', 'Every object\nhas a story.',
  'Examine the portrait, recover the brass key and carry its meaning into the next encounter.',
  ['hall','discovery'], ['Moonlit Entrance Hall','A real item discovery'],
  'Entrance Hall exploration and the portrait’s brass-key discovery panel.'),
 ('04-library-and-workshop', 'pair', 'Follow the evidence', 'From letters\nto lost voices.',
  'The library and workshop connect written clues, a torn recipe and a forgotten recording.',
  ['library','workshop'], ['Forgotten Library','Alchemist’s Workshop'],
  'Actual Library and Workshop scenes with their original code-drawn room artwork.'),
 ('05-clocktower-and-vault', 'pair', 'Deeper into the manor', 'Remember\nthe hour.\nHear the Echo.',
  'The clocktower’s mechanisms open the way to the Resonance Engine in the vault.',
  ['clocktower','vault'], ['Clocktower Chamber','The Echo Vault'],
  'Original Clocktower and Echo Vault scenes from the same legal Android playthrough.'),
 ('06-puzzles-and-feedback', 'pair', 'Playable puzzles', 'A wrong answer\nis another clue.',
  'Deliberate inputs and deterministic validation. Incorrect arrangements give meaningful feedback.',
  ['candle_input','candle_wrong'], ['Arrange the moons','Read the actual feedback'],
  'Candle Moons input controls and a genuine incorrect submission with contextual feedback.'),
 ('07-puzzles-unlock-progress', 'pair', 'Solve & progress', 'Read. Connect.\nOpen the way.',
  'Clues support the solution. Solving the candelabra changes the Hall and opens its hidden door.',
  ['candle_correct','hall_unlocked'], ['A clue-supported arrangement','The Hall after completion'],
  'A correct moon arrangement and the resulting unlocked Hall. These are captured game states, not a recreated interface.'),
 ('08-inventory-and-item-use', 'pair', 'Inventory & item use', 'Carry a clue\ninto its purpose.',
  'Use the recovered brass key on Tallow. His lantern becomes part of your journey.',
  ['item_use','lantern_reward'], ['Use an item on an object','Tallow’s lantern discovered'],
  'The actual item-use selection and lantern reward after waking the caretaker.'),
 ('09-branching-conversations', 'pair', 'Interactive storytelling', 'Your choices\nleave an echo.',
  'Original character portraits frame player replies. The story records the choices you make.',
  ['dialogue_choice','dialogue_result'], ['Choose a reply','See the story’s response'],
  'Tallow’s dialogue choices and the response to a compassionate reply.'),
 ('10-discovery-journal', 'single', 'Journal & discoveries', 'Keep the clues\nwithin reach.',
  'The journal preserves discoveries and conversations. Evidence connections appear when their clues are known.',
  ['journal'], ['A journal from real play'],
  'The in-game journal showing discoveries earned during the recorded playthrough.'),
 ('11-whispering-guide-offline', 'guide', 'The Whispering Guide', 'A nudge,\nwhen you need it.',
  'Contextual, spoiler-aware help. This release is offline and rule-based; no live AI service is connected.',
  ['guide_hint'], ['Actual offline guidance'],
  'The actual Whispering Guide panel, explicitly labeled offline and rule-based, displaying a subtle hint for a discovered puzzle.'),
 ('12-accessibility-and-sound', 'pair', 'Comfort & accessibility', 'Atmosphere,\non your terms.',
  'Reduced motion, reading controls, mute and separate sound levels keep the mystery adjustable.',
  ['settings_motion','settings_sound'], ['Motion and exploration settings','Mute and volume controls'],
  'Actual settings screens with reduced motion, object-list options and master, ambient and effects volume controls.'),
 ('13-final-choice-and-ending', 'pair', 'Ending spoiler · Release route', 'What becomes\nof the Echo?',
  'Final options depend on story requirements. Shown here: the earned Release ending.',
  ['final_choices','the_end'], ['The final decision','Release the Echo — earned'],
  'Spoiler: the final decision and the earned Release the Echo epilogue. Other endings are not presented as recorded here.'),
 ('14-kiro-development-evidence', 'kiro', 'Kiro development workflow', 'Specification, steering and real checks.',
  'Actual Kiro IDE capture. The retained .kiro directory contains the project’s requirements, design, tasks, steering and hook configurations.',
  ['spec'], ['Actual Kiro specification'],
  'An actual Kiro IDE screenshot with the project specification and retained .kiro structure. This is configuration evidence, not a fabricated chat.'),
 ('15-recorded-release-validation', 'kiro', 'Recorded validation · November 1, 2026', 'Checked, then packaged.',
  'The dated release record reports 394 passing tests and clean analysis, plus Android gameplay and save-reload checks. No new hosted CI run is implied.',
  ['tests'], ['Actual dated release record'],
  'Actual Kiro IDE view of the November 1 release-validation record, including 394 passing tests and Android integration results.'),
]


def font(size, serif=False):
    paths = ([Path('/System/Library/Fonts/Supplemental/Georgia.ttf')] if serif else
             [Path('/System/Library/Fonts/Supplemental/Arial.ttf')])
    paths += [Path('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf')]
    return ImageFont.truetype(str(next(p for p in paths if p.exists())), size)


def text(draw, value, xy, size, color=WHITE, serif=False, width=None, spacing=12):
    x, y = xy
    face = font(size, serif)
    for paragraph in value.split('\n'):
        lines = textwrap.wrap(paragraph, width=width, break_long_words=False) if width else [paragraph]
        for line in lines:
            draw.text((x,y),line,font=face,fill=color)
            y += size+spacing
    return y


def background():
    # Original code-native matte; no external decorative artwork.
    base=Image.new('RGB',(W,H))
    pixels=base.load()
    for y in range(H):
        for x in range(W):
            glow=max(0,1-math.hypot((x-1450)/1500,(y-280)/1600))
            pixels[x,y]=(int(5+9*glow),int(8+7*glow),int(24+24*glow))
    draw=ImageDraw.Draw(base)
    for radius in [170,300,440,590]:
        draw.ellipse((1060-radius,570-radius,1060+radius,570+radius),outline=(34,40,62),width=1)
    for i in range(65):
        x,y=(i*397+47)%W,(i*211+89)%H
        draw.ellipse((x,y,x+2,y+2),fill=(71,81,103))
    return base


def source(name):
    directory=SOURCE/name
    frames=sorted(directory.glob('*.png'))
    if not frames:raise RuntimeError(f'Missing genuine app capture: {name}')
    # Choose a settled captured frame; no UI reconstruction or state injection.
    index=min(20,len(frames)-1)
    return frames[index]


def screenshot(canvas,path,box,guide_crop=False):
    im=Image.open(path).convert('RGB')
    if guide_crop:im=im.crop((0,185,im.width,im.height))
    target=ImageOps.contain(im,(box[2],box[3]),Image.Resampling.LANCZOS)
    x=box[0]+(box[2]-target.width)//2
    y=box[1]+(box[3]-target.height)//2
    draw=ImageDraw.Draw(canvas)
    draw.rounded_rectangle((x-9,y-9,x+target.width+9,y+target.height+9),radius=18,
                           fill='#030615',outline='#9e8752',width=2)
    canvas.paste(target,(x,y))
    return {'path':str(path.relative_to(ROOT)),'crop':'Guide modal detail only' if guide_crop else 'Full capture retained'}


def main():
    IMAGES.mkdir(parents=True,exist_ok=True)
    base=background()
    manifest=[]
    for index,card in enumerate(CARDS,1):
        name,kind,kicker,title,body,names,labels,alt=card
        im=base.copy();d=ImageDraw.Draw(im)
        text(d,'HAUNTQUEST AI  /  PROJECT MEDIA',(75,38),22,GOLD)
        text(d,f'{index:02d} / 15',(1600,38),22,MUTED)
        d.line((75,88,1725,88),fill='#635638',width=1)
        provenance=[]
        if kind=='cover':
            text(d,'COSTUME CONTEST  ·  KIROWEEN 2026',(80,156),22,CYAN)
            text(d,'HauntQuest\nAI',(75,250),115,serif=True,spacing=7)
            text(d,title,(80,550),57,serif=True,spacing=8)
            text(d,body,(80,770),30,MUTED,width=48)
            text(d,'5 ROOMS   ·   16 PUZZLES   ·   3 ENDINGS',(80,1000),24,GOLD)
            provenance.append(screenshot(im,source('menu'),(1190,130,510,1020)))
        elif kind=='rooms':
            text(d,kicker,(75,125),66,serif=True)
            text(d,title,(80,210),29,MUTED)
            for i,(capture,label) in enumerate(zip(names,labels)):
                x=70+i*338
                text(d,label,(x,305),22,CYAN)
                provenance.append(screenshot(im,source(capture),(x,355,310,710)))
            text(d,'A continuous investigation across five distinct illustrated spaces.',(80,1090),29,MUTED)
        elif kind=='pair':
            text(d,kicker.upper(),(80,155),21,CYAN)
            text(d,title,(75,285),66,serif=True,spacing=12)
            text(d,body,(80,745),29,MUTED,width=34)
            for i,(capture,label) in enumerate(zip(names,labels)):
                x=770+i*487
                text(d,label,(x,135),20,CYAN)
                provenance.append(screenshot(im,source(capture),(x,190,445,940)))
        elif kind in {'single','guide'}:
            text(d,kicker.upper(),(80,155),23,CYAN)
            text(d,title,(75,290),77,serif=True,spacing=13)
            text(d,body,(80,745),31,MUTED,width=44)
            if kind=='guide':
                text(d,'OFFLINE  ·  RULE-BASED',(80,1010),25,GOLD)
            text(d,labels[0],(1125,120),20,CYAN)
            provenance.append(screenshot(im,source(names[0]),(1115,165,595,960),kind=='guide'))
        elif kind=='kiro':
            text(d,kicker.upper(),(80,122),22,CYAN)
            text(d,title,(75,170),55,serif=True)
            actual=ROOT/'build/video/kiro'/f'{names[0]}.png'
            shot=Image.open(actual).convert('RGB')
            # Crop editor chrome/account areas only; preserve source content.
            shot=shot.crop((48,50,1908,950))
            shot=ImageOps.contain(shot,(1640,795),Image.Resampling.LANCZOS)
            im.paste(shot,(80,275))
            text(ImageDraw.Draw(im),body,(80,1090),22,MUTED,width=145,spacing=7)
            provenance.append({'path':str(actual.relative_to(ROOT)),'crop':'Editor content; branding/status chrome excluded'})
        if kind!='kiro':
            text(ImageDraw.Draw(im),'Actual Android application capture · Edited framing · No reconstructed UI',(80,1163),17,MUTED)
        output=IMAGES/f'{name}.png'
        im.save(output,format='PNG',optimize=True)
        with Image.open(output) as verify:
            assert verify.size==(W,H) and verify.mode=='RGB'
            verify.verify()
        assert output.stat().st_size<5_000_000
        manifest.append({'order':index,'file':output.name,'title':kicker,
                         'caption':body.replace('\n',' '),'alt_text':alt,
                         'width':W,'height':H,'format':'PNG','bytes':output.stat().st_size,
                         'sha256':hashlib.sha256(output.read_bytes()).hexdigest(),
                         'sources':provenance})
        print(f'{index:02d}: {output.name} — {output.stat().st_size:,} bytes',flush=True)
    assert len(manifest)==15
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False))
    captions=['# HauntQuest AI — Devpost image gallery','',
              'Upload the 15 PNG files in images/ in numbered order. Each is 1800×1200 (3:2), RGB, below 5,000,000 bytes.',
              '01 is the recommended cover. 13 contains a Release-ending spoiler. 14–15 are development evidence.',
              'All app imagery is from actual instrumented Android captures. The Guide is offline/rule-based.',
              'Kiro imagery is genuine IDE capture; test counts refer to the dated release record, not a new CI run.','']
    for item in manifest:
        captions += [f"## {item['order']:02d}. {item['title']}",f"File: {item['file']}",
                     f"Caption: {item['caption']}",f"Alt text: {item['alt_text']}",'']
    (OUT/'CAPTIONS.md').write_text('\n'.join(captions))
    # Preview lives outside images/ and is not part of the 15-image upload set.
    preview=Image.new('RGB',(1800,2130),INK)
    pd=ImageDraw.Draw(preview)
    for i,item in enumerate(manifest):
        thumb=Image.open(IMAGES/item['file']).resize((600,400),Image.Resampling.LANCZOS)
        x=(i%3)*600;y=(i//3)*426
        preview.paste(thumb,(x,y))
        pd.text((x+10,y+402),f"{i+1:02d}  {item['title'][:42]}",font=font(16),fill=GOLD)
    preview.save(OUT/'contact-sheet.jpg',quality=94)
    with zipfile.ZipFile(OUT/'hauntquest-ai-project-media.zip','w',zipfile.ZIP_DEFLATED) as archive:
        for item in manifest:archive.write(IMAGES/item['file'],f"images/{item['file']}")
        for name in ['CAPTIONS.md','manifest.json']:archive.write(OUT/name,name)
    print('Validated 15 upload images: exact 3:2; every file below 5 MB.',flush=True)

if __name__=='__main__':main()
