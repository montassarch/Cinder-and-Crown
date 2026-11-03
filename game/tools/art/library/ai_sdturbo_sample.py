# Experiment: can an open-weight image model help with concept / background art, on this CPU-only container?
#   <venv>/bin/python -I game/tools/art/library/ai_sdturbo_sample.py <out_dir>
# Needs a venv with torch (CPU wheel), diffusers, transformers, accelerate, and the stabilityai/sd-turbo weights
# (Stability AI Community License: free for individuals / organisations under USD 1M revenue a year; outputs may be used).
# It times 1-step 512x512 generations, then turns each picture into a 384x216 game-palette backdrop (crop, BOX shrink,
# 24 colours, ashen grade) so the "AI concept -> pixel backdrop" idea can be judged side by side with hand-made layers.
import os, sys, time
import torch
from diffusers import AutoPipelineForText2Image
from PIL import Image

OUT = sys.argv[1]; os.makedirs(OUT, exist_ok=True)
torch.set_num_threads(os.cpu_count() or 4)
t0 = time.time()
pipe = AutoPipelineForText2Image.from_pretrained('stabilityai/sd-turbo', variant='fp16', torch_dtype=torch.float32)
pipe.set_progress_bar_config(disable=True)
print('load', round(time.time() - t0, 1), 's')

PROMPTS = {
    'cathedral_ruin': 'ruined gothic cathedral interior at night, broken stained glass windows, ash falling, braziers with warm firelight, '
                      'dark fantasy, muted desaturated colours, side view, wide matte painting',
    'crypt_corridor': 'ancient crypt corridor with stone coffins and candles, cobwebs, dark souls mood, warm candle light, cold blue shadows, side view',
    'forge_hall': 'colossal dwarven forge hall, molten metal rivers, chains and anvils, embers in the air, dark fantasy, side view background',
    'storm_spire': 'tall black stone spire on a cliff in a thunderstorm, lightning, ruined bridges, dark fantasy landscape, side view',
    'hollow_knight_concept': 'concept art of an undead armoured knight, tattered cape, rusted greatsword, glowing ember eyes, dark fantasy, full body, plain dark background',
}
times = []
for name, prompt in PROMPTS.items():
    g = torch.Generator().manual_seed(7)
    t = time.time()
    img = pipe(prompt=prompt, num_inference_steps=1, guidance_scale=0.0, width=512, height=512, generator=g).images[0]
    times.append(time.time() - t)
    img.save(os.path.join(OUT, name + '_512.png'))
    print(name, round(times[-1], 1), 's')
print('mean seconds per 512x512 image:', round(sum(times) / len(times), 1))
