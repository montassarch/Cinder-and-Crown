# Turns AI concept pictures (ai_sdturbo_sample.py output) into game-palette backdrops and a comparison sheet.
#   python3 -I game/tools/art/library/ai_to_backdrop.py <ai_out dir> <dest dir>
# Each 512x512 picture: centre crop to 16:9 -> 384x216 (BOX), 24 colours, ashen grade, darkened for a far layer.
import glob, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib
from PIL import Image, ImageDraw, ImageEnhance

src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)
rows = []
for f in sorted(glob.glob(os.path.join(src, '*_512.png'))):
    name = os.path.basename(f)[:-8]
    im = Image.open(f).convert('RGB')
    h = int(im.width * 9 / 16); top = (im.height - h) // 2
    crop = im.crop((0, top, im.width, top + h)).resize((384, 216), Image.BOX)
    q = crop.convert('RGBA'); q = lib.quantize_set([q], 24)[0]; q = lib.ashen(q, sat=0.6, val=0.8)
    q = ImageEnhance.Contrast(q.convert('RGB')).enhance(1.1).convert('RGBA')
    im.resize((256, 256), Image.LANCZOS).save(os.path.join(dst, name + '_concept_256.jpg'), quality=85)
    lib.save(q, os.path.join(dst, name + '_backdrop_384x216.png'))
    rows.append((name, im.resize((216, 216), Image.LANCZOS).convert('RGBA'), q))
W = 216 + 384 + 12; H = len(rows) * 232 + 4
sheet = Image.new('RGBA', (W, H), (30, 26, 36, 255)); d = ImageDraw.Draw(sheet)
for i, (name, a, b) in enumerate(rows):
    y = 4 + i * 232
    d.text((4, y), name + '  (SD-Turbo, 1 step, ~17 s on 4 CPU cores)  ->  384x216, 24 colours, ashen grade', fill=(235, 215, 150, 255))
    sheet.alpha_composite(a, (4, y + 14)); sheet.alpha_composite(b, (224, y + 14))
lib.save(sheet, os.path.join(dst, 'ai_sample_sheet.png'))
print('sheet', sheet.size)
