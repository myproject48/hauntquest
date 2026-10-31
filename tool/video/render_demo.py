#!/usr/bin/env python3
"""Render the 175-second caption-led demo from real Android and Kiro captures.

Requires ffmpeg/ffprobe on PATH and Pillow. All outputs stay in ignored build/video.
No external media, music, synthesized voice, remote service or fake UI is used.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import array
import hashlib
import json
import math
import re
import subprocess
import textwrap
import time
import wave

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'build/video'
FRAMES = OUT / 'android'
W, H = 1920, 1080
FPS = 30
GOLD = '#d4b568'
WHITE = '#f3ede1'
MUTED = '#b2b8ca'
CYAN = '#9cdae1'

# The timeline follows the requested eight chapters exactly (175 seconds).
# name, seconds, headline, detail, chapter, footage kind
SHOTS = [
 ('menu', 8, 'A mystery.\nA manor.\nA choice.', 'Ottoline Vask has vanished.\nThe Echo remembers.\nFollow the clues, entirely offline.', 0, 'app'),
 ('discovery', 7, 'Curiosity\nopens doors.', 'An original dark-fantasy investigation\nwhere objects become evidence.', 0, 'app'),
 ('menu', 8, 'Enter the\nWhispering Manor.', 'Original artwork drawn in Flutter code.\nNo stock game art. No network needed.', 1, 'app'),
 ('settings_motion', 6, 'Atmosphere,\non your terms.', 'Reading controls, high contrast\nand reduced-motion preferences.', 1, 'app'),
 ('settings_sound', 6, 'Listen.\nOr play silently.', 'Master, ambience and effects controls.\nWritten clues support every sound puzzle.', 1, 'app'),
 ('hall', 5, 'Look closer.', 'Moonlit Entrance Hall\nObjects respond to your investigation.', 2, 'app'),
 ('library', 5, 'Follow the\ntrail of evidence.', 'Forgotten Library\nLetters, a cipher and a torn recipe.', 2, 'app'),
 ('workshop', 5, 'Every room\nhas a voice.', "Alchemist’s Workshop\nOriginal locally synthesized ambience.", 2, 'app'),
 ('clocktower', 5, 'Remember\nthe hour.', 'Clocktower Chamber\nA stopped clock and a missing cog.', 2, 'app'),
 ('vault', 5, 'Hear what\nremains.', 'The Echo Vault\nRestore the engine. Decide its fate.', 2, 'app'),
 ('journal', 5, 'Keep the clues\nwithin reach.', 'The journal records discoveries\nand connects known evidence.', 2, 'app'),
 ('guide_hint', 5, 'A nudge,\nwhen you need it.', 'The Whispering Guide is OFFLINE\nand RULE-BASED. No live AI is connected.', 2, 'app'),
 ('candle_input', 5, 'Look. Connect.\nSolve.', 'A visible clue. An explicit input.\nA deliberate submission.', 3, 'app'),
 ('candle_wrong', 6, 'A wrong answer\nis another clue.', 'Meaningful feedback helps you rethink\nthe arrangement. Critical items are safe.', 3, 'app'),
 ('candle_correct', 5, 'Read the letter.\nArrange the moons.', 'Crescent → Half → Full → Waning\nInputs are validated deterministically.', 3, 'app'),
 ('hall_unlocked', 5, 'Progress changes\nthe manor.', 'A completed puzzle opens the way.\nRevisits preserve the solved state.', 3, 'app'),
 ('item_use', 5, 'Carry meaning\nfrom room to room.', 'Use the recovered brass key\non the dormant caretaker.', 3, 'app'),
 ('lantern_reward', 4, 'A light\nfor the journey.', "Tallow’s lantern joins your inventory.\nRewards cannot be collected twice.", 3, 'app'),
 ('dialogue_choice', 7, 'Your choices\nleave an echo.', 'A character portrait. A considered reply.\nDecisions become persistent story flags.', 4, 'app'),
 ('dialogue_result', 5, 'The manor\nremembers.', 'Earlier kindness and discoveries\nshape the final requirements.', 4, 'app'),
 ('final_choices', 8, 'Freedom,\ncontainment,\nor guardianship?', 'Later in the same legal journey:\nthe restored engine brings a final decision.', 4, 'app'),
 ('spec', 8, 'Specification', 'Actual Kiro IDE capture • requirements, design and tasks', 5, 'kiro'),
 ('steering', 7, 'Steering', 'Actual Kiro IDE capture • offline, visual and architecture constraints', 5, 'kiro'),
 ('hooks', 7, 'Hooks', 'Actual configuration • read-only targeted checks; no fresh invocation claimed', 5, 'kiro'),
 ('tests', 8, 'Validation', 'Recorded November 1 release result: 394 tests passed; clean analysis', 5, 'kiro'),
 ('ending_reveal', 7, 'Release\nthe Echo.', 'An ending earned through normal play.\nOriginal illustration and a finite reveal.', 6, 'app'),
 ('the_end', 8, 'An ending.\nA remembered\njourney.', 'Five rooms reached without injected flags.\nThis recorded route chooses Release.', 6, 'app'),
 ('menu', 6, 'Explore.\nConnect.\nChoose.', 'HauntQuest AI\nCostume Contest • Kiroween 2026', 7, 'app'),
 ('the_end', 4, 'The Echo’s fate\nis yours.', 'Source and playable build:\nsee the project links when published.', 7, 'app'),
]
CHAPTERS = [
 ('00:00', 'THE MYSTERY'), ('00:15', 'A HAUNTED INTERFACE'),
 ('00:35', 'EXPLORING THE MANOR'), ('01:10', 'PUZZLES & INVENTORY'),
 ('01:40', 'DECISIONS & PROGRESSION'), ('02:00', 'BUILT WITH KIRO'),
 ('02:30', 'AN EARNED ENDING'), ('02:45', 'HAUNTQUEST AI'),
]
EXPECTED = [15, 20, 35, 30, 20, 30, 15, 10]
assert [sum(s[1] for s in SHOTS if s[4] == i) for i in range(8)] == EXPECTED
assert sum(s[1] for s in SHOTS) == 175


def font(size, serif=False):
    candidates = ([Path('/System/Library/Fonts/Supplemental/Georgia.ttf')]
                  if serif else [Path('/System/Library/Fonts/Supplemental/Arial.ttf')])
    candidates += [Path('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf')]
    return ImageFont.truetype(str(next(p for p in candidates if p.exists())), size)


def lines(draw, text, at, size, color, serif=False, spacing=14):
    x, y = at
    f = font(size, serif)
    for line in text.split('\n'):
        draw.text((x, y), line, font=f, fill=color, stroke_width=0)
        y += size + spacing
    return y


BACKGROUND = None

def plate(index, shot):
    global BACKGROUND
    name, seconds, title, detail, chapter, kind = shot
    if BACKGROUND is None:
        BACKGROUND = Image.new('RGB', (W, H))
        pix = BACKGROUND.load()
        for y in range(H):
            for x in range(W):
                glow = max(0, 1 - math.hypot((x - 1600) / 1500, (y - 220) / 1400))
                pix[x, y] = (int(5 + 9 * glow), int(8 + 8 * glow), int(24 + 22 * glow))
    im = BACKGROUND.copy()
    d = ImageDraw.Draw(im)
    for r in [180, 300, 430, 570]:
        d.ellipse((1130-r, 520-r, 1130+r, 520+r), outline=(37, 41, 61), width=1)
    for n in range(48):
        x, y = (n*397 + 49) % W, (n*211 + 83) % H
        d.ellipse((x, y, x+2, y+2), fill=(69, 78, 96))
    lines(d, 'HAUNTQUEST AI   /   KIROWEEN 2026', (90, 45), 23, GOLD)
    lines(d, f'{chapter+1:02d}   {CHAPTERS[chapter][1]}', (90, 105), 24, CYAN)
    d.line((90, 157, 1150, 157), fill=(100, 84, 51), width=1)
    if kind == 'app':
        lines(d, title, (90, 210), 78, WHITE, serif=True, spacing=15)
        lines(d, detail, (95, 635), 32, MUTED, spacing=15)
        d.rounded_rectangle((1278, 65, 1740, 1050), radius=25,
                            fill=(3, 5, 15), outline=(126, 106, 66), width=2)
        lines(d, 'ANDROID EMULATOR • EDITED CAPTURE', (1278, 30), 16, MUTED)
        lines(d, 'Normal game actions • No review mode', (95, 1013), 21, MUTED)
    else:
        lines(d, title, (90, 170), 54, WHITE, serif=True)
        lines(d, detail, (90, 1045), 20, MUTED)
    d.line((90, 977, 1160, 977), fill=(50, 54, 73), width=1) if kind == 'app' else None
    # Genuine on-screen narration. No synthesized voice is claimed.
    path = OUT / 'plates' / f'{index:02d}.png'
    path.parent.mkdir(exist_ok=True)
    im.save(path)
    return path


def run(command, log):
    with log.open('w') as f:
        subprocess.run(command, cwd=ROOT, stdout=f, stderr=subprocess.STDOUT, check=True)


def make_audio():
    sample_rate = 16000
    mix = array.array('f', [0.0]) * (175 * sample_rate)
    def load(name):
        with wave.open(str(ROOT / 'assets/audio' / f'{name}.wav'), 'rb') as w:
            assert w.getframerate() == sample_rate and w.getnchannels() == 1
            return array.array('h', w.readframes(w.getnframes()))
    def add(name, start, duration, gain, loop=False):
        samples = load(name)
        length = min(int(duration * sample_rate), len(mix)-int(start*sample_rate))
        for i in range(length):
            if not loop and i >= len(samples):
                break
            edge = min(1, i/(sample_rate*.3), (length-i)/(sample_rate*.5))
            mix[int(start*sample_rate)+i] += samples[i % len(samples)] * gain * edge
    add('ambient_hall', 0, 49, .18, True)
    add('ambient_library', 49, 21, .16, True)
    add('ambient_workshop', 70, 30, .13, True)
    add('ambient_clocktower', 100, 20, .15, True)
    add('ambient_vault', 120, 55, .12, True)
    for name, at in [('pickup',8),('interact',23),('discovery',35),('discovery',56),
                     ('failure',75),('success',86),('unlock',91),('pickup',96),
                     ('interact',100),('chapter',112),('ending_release',150)]:
        add(name, at, 8, .4)
    pcm = array.array('h', (max(-32767, min(32767, int(x))) for x in mix))
    path = OUT / 'original-game-audio.wav'
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sample_rate)
        w.writeframes(pcm.tobytes())
    return path


def main():
    OUT.mkdir(exist_ok=True)
    clips = OUT / 'clips'; clips.mkdir(exist_ok=True)
    def await_shot(name):
        deadline = time.monotonic()+900
        while time.monotonic()<deadline:
            manifest_path = FRAMES/'manifest.json'
            if manifest_path.exists():
                manifest=json.loads(manifest_path.read_text())
                names={item['name']:item for item in manifest['shots']}
                if name in names: return names[name]
            time.sleep(.5)
        raise RuntimeError(f'Missing real Android capture: {name}')
    timeline = []
    start = 0
    for i, shot in enumerate(SHOTS):
        name, seconds, title, detail, chapter, kind = shot
        output = clips / f'{i:02d}.mp4'
        bg = plate(i, shot)
        command = ['ffmpeg','-y','-v','warning','-loop','1','-framerate','30','-i',str(bg)]
        if kind == 'app':
            source = await_shot(name)
            command += ['-framerate',str(source['fps']),'-i',str(FRAMES/name/'%06d.png')]
            filters = f'[1:v]scale=444:960:flags=lanczos,fps=30,tpad=stop_mode=clone:stop_duration={seconds}[app];[0:v][app]overlay=1287:77:shortest=1,format=yuv420p[v]'
        else:
            image = OUT/'kiro'/f'{name}.png'
            assert image.is_file(), image
            command += ['-loop','1','-framerate','30','-i',str(image)]
            filters = '[1:v]crop=1860:900:48:50,scale=1740:842:flags=lanczos[ide];[0:v][ide]overlay=90:250:shortest=1,crop=1920:1080:0:0,format=yuv420p[v]'
            # Keep the IDE above its explanatory footer.
            filters = '[1:v]crop=1860:900:48:50,scale=1640:794:flags=lanczos[ide];[0:v][ide]overlay=140:230:shortest=1,format=yuv420p[v]'
        filters = filters.replace(',format=yuv420p[v]', f',fade=t=in:d=0.2,fade=t=out:st={seconds-.2}:d=0.2,format=yuv420p[v]')
        command += ['-filter_complex',filters,'-map','[v]','-t',str(seconds),
                    '-an','-c:v','libx264','-preset','fast','-crf','19','-r','30',
                    '-threads','4',str(output)]
        print(f'Rendering {i+1}/{len(SHOTS)}: {name} ({seconds}s)', flush=True)
        run(command,OUT/f'render-{i:02d}.log')
        timeline.append({'start':start,'end':start+seconds,'source':name,'chapter':chapter+1,
                         'caption':detail,'kind':kind})
        start += seconds
    concat = OUT/'concat.txt'
    concat.write_text('\n'.join("file '"+str(clips/f'{i:02d}.mp4')+"'" for i in range(len(SHOTS))))
    audio = make_audio()
    # English closed captions use the original screenplay's narration.
    screenplay = (ROOT/'docs/devpost/DEMO_SCREENPLAY.md').read_text()
    narration = re.findall(r'^> (.+)$', screenplay, re.M)
    assert len(narration)==8
    def stamp(value):
        ms=round(value*1000)
        return f'{ms//3600000:02d}:{ms//60000%60:02d}:{ms//1000%60:02d},{ms%1000:03d}'
    cues=[]
    offset=0
    for words, length in zip(narration, EXPECTED):
        words=words.split()
        chunks=[words[i:i+13] for i in range(0,len(words),13)]
        consumed=0
        for chunk in chunks:
            begin=offset+length*consumed/len(words)
            consumed+=len(chunk)
            end=offset+length*consumed/len(words)
            cues.append(f'{len(cues)+1}\n{stamp(begin)} --> {stamp(end)}\n'+
                        '\n'.join(textwrap.wrap(' '.join(chunk), 62))+'\n')
        offset+=length
    subtitles=OUT/'hauntquest-ai-english.srt'
    subtitles.write_text('\n'.join(cues))
    metadata=OUT/'chapters.ffmetadata'
    parts=[';FFMETADATA1','title=HauntQuest AI — Kiroween 2026 demo',
           'comment=Caption-led video. Instrumented Android gameplay; edited original sound design.']
    start=0
    for i,length in enumerate(EXPECTED):
        parts.extend(['[CHAPTER]','TIMEBASE=1/1000',f'START={start*1000}',
                      f'END={(start+length)*1000}',f'TITLE={CHAPTERS[i][1]}'])
        start+=length
    metadata.write_text('\n'.join(parts))
    output = OUT/'hauntquest-ai-kiroween-demo.mp4' 
    run(['ffmpeg','-y','-v','warning','-f','concat','-safe','0','-i',str(concat),'-i',str(audio),
         '-i',str(subtitles),'-i',str(metadata),
         '-map','0:v:0','-map','1:a:0','-map','2:0','-map_metadata','3','-map_chapters','3',
         '-metadata:s:a:0','title=Original game sound design',
         '-metadata:s:s:0','language=eng','-metadata:s:s:0','title=English narration captions',
         '-c:v','copy','-c:a','aac','-b:a','192k','-af','volume=16dB','-ar','48000','-ac','2','-c:s','mov_text',
         '-t','175','-movflags','+faststart',str(output)], OUT/'mux.log')
    (OUT/'timeline.json').write_text(json.dumps(timeline,indent=2))
    probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_format','-show_streams','-show_chapters','-of','json',str(output)]))
    (OUT/'verification.json').write_text(json.dumps(probe,indent=2))
    assert abs(float(probe['format']['duration'])-175)<.15
    assert next(s for s in probe['streams'] if s['codec_type']=='video')['width']==1920
    assert len(probe['chapters'])==8
    assert any(s['codec_type']=='subtitle' for s in probe['streams'])
    digest=hashlib.sha256(output.read_bytes()).hexdigest()
    (OUT/'SHA256SUMS.txt').write_text(digest+'  '+output.name+'\n')
    print(f'Created {output.name}: 175 seconds, 1920×1080, SHA-256 {digest}',flush=True)

if __name__=='__main__':
    main()
