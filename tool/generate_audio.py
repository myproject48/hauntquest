#!/usr/bin/env python3
"""Original HauntQuest sound synthesis. Standard-library only; no recordings.
Run from the project root: python3 tool/generate_audio.py
All waveforms are deterministic 16-bit mono PCM; ambient loops use periodic bins.
"""
import math, random, struct, wave
from pathlib import Path
RATE=16000
OUT=Path('assets/audio'); OUT.mkdir(parents=True,exist_ok=True)
def write(name, samples):
    peak=max(max(abs(v) for v in samples),.001)
    scale=.65/max(peak,1)
    pcm=b''.join(struct.pack('<h',int(max(-1,min(1,v*scale))*32767)) for v in samples)
    with wave.open(str(OUT/(name+'.wav')),'wb') as w:
        w.setparams((1,2,RATE,0,'NONE','not compressed'));w.writeframes(pcm)
def effect(name, seconds, notes, noise=.0, seed=0):
    rng=random.Random(seed); out=[]
    for i in range(int(seconds*RATE)):
        t=i/RATE; v=0
        for freq,start,length,gain in notes:
            q=t-start
            if 0<=q<length:
                env=min(1,q/.008)*math.exp(-5*q/length)*min(1,(length-q)/.02)
                v+=gain*env*(math.sin(2*math.pi*freq*q)+.15*math.sin(2*math.pi*freq*2.01*q))
        v+=noise*rng.uniform(-1,1)*min(1,t/.004)*math.exp(-16*t/max(seconds,.1))
        out.append(v)
    write(name,out)
effect('pickup',.6,[(660,0,.45,.35),(990,.07,.42,.25),(1320,.14,.4,.2)])
effect('unlock',.65,[(135,0,.5,.4),(270,.04,.4,.2),(1050,.02,.09,.12)],.22,2)
effect('success',1.1,[(294,0,.9,.25),(370,.12,.8,.25),(440,.24,.8,.25),(880,.35,.5,.12)])
effect('failure',.5,[(92,0,.4,.3),(97,0,.4,.24),(63,.15,.25,.15)],.1,3)
effect('footstep',.55,[(110,0,.16,.24),(85,.26,.18,.2)],.24,4)
effect('discovery',1.1,[(520,0,.7,.2),(780,.15,.7,.2),(1040,.3,.6,.2),(1560,.4,.6,.1)])
effect('chapter',1.8,[(146.8,0,1.7,.2),(220,.2,1.5,.2),(293.6,.4,1.3,.2),(440,.55,1.1,.12)])
effect('interact',.12,[(460,0,.09,.12),(180,0,.08,.12)],.08,5)
effect('ending_release',2.4,[(392,0,2.2,.2),(587.3,.3,2,.2),(784,.6,1.7,.12)])
effect('ending_seal',2.4,[(130.8,0,2.1,.25),(196,.35,1.8,.2),(261.6,.7,1.5,.15)])
effect('ending_guardian',2.4,[(220,0,2.2,.2),(329.6,.3,2,.18),(440,.6,1.8,.15),(659.3,.85,1.4,.1)])
for hz in (220,330,440,550):effect('echo_'+str(hz),.45,[(hz,0,.42,.38)])
# Seam-safe wind, paper rustle, glass resonance, clockwork and vault drones.
for idx,name in enumerate(['hall','library','workshop','clocktower','vault']):
    rng=random.Random(100+idx); duration=8; count=duration*RATE
    bins=[(rng.randrange(80,12000),rng.random()*2*math.pi,rng.uniform(.001,.006)) for _ in range(24)]
    fundamental=[55,73.5,98,65.5,82.5][idx]
    samples=[]
    for n in range(count):
        t=n/RATE
        wind=sum(g*math.sin(2*math.pi*(b/duration)*t+p) for b,p,g in bins)
        drift=.6+.4*math.sin(2*math.pi*t/duration)
        hum=.06*math.sin(2*math.pi*fundamental*t)+.025*math.sin(2*math.pi*fundamental*2*t)
        shimmer=.015*math.sin(2*math.pi*(fundamental*6)*t)*(.5+.5*math.cos(2*math.pi*2*t/duration))
        samples.append(wind*drift+hum+shimmer)
    write('ambient_'+name,samples)
print('Generated',len(list(OUT.glob('*.wav'))),'original WAV assets:',sum(p.stat().st_size for p in OUT.glob('*.wav')),'bytes')
