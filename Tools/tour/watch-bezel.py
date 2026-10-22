"""An Apple Watch frame (screen cut out, band stubs, Digital Crown and side button), the touch
ring, and the end card's icon, for watch-compose.mjs. Usage: python3 watch-bezel.py <out dir> <icon png>.
Needs Pillow."""
import sys

from PIL import Image, ImageDraw, ImageFilter

out, icon = sys.argv[1], sys.argv[2]
W, H = 1080, 1920
# The film is 410x502 (205x251 points); shown at 700 wide that is 858 high.
SCREEN = (190, 560, 890, 1418)
BODY = (150, 500, 930, 1478)

frame = Image.new("RGBA", (W, H), (0, 0, 0, 0))
draw = ImageDraw.Draw(frame)
# The band, tapering into the case at top and bottom.
band = (58, 62, 74, 255)
draw.polygon([(270, 330), (810, 330), (850, 520), (230, 520)], fill=band)
draw.polygon([(230, 1458), (850, 1458), (810, 1660), (270, 1660)], fill=band)
draw.rounded_rectangle(BODY, radius=190, fill=(20, 21, 26, 255))
draw.rounded_rectangle((BODY[0] + 3, BODY[1] + 3, BODY[2] - 3, BODY[3] - 3), radius=187, outline=(70, 74, 86, 255), width=4)
# Digital Crown and side button, on the right as worn on the left wrist.
draw.rounded_rectangle((922, 720, 966, 880), radius=16, fill=(44, 46, 54, 255))
draw.rounded_rectangle((926, 960, 950, 1150), radius=10, fill=(44, 46, 54, 255))

hole = Image.new("L", (W, H), 0)
ImageDraw.Draw(hole).rounded_rectangle(SCREEN, radius=120, fill=255)
frame.putalpha(Image.composite(Image.new("L", (W, H), 0), frame.getchannel("A"), hole))
shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ImageDraw.Draw(shadow).rounded_rectangle((BODY[0], BODY[1] + 24, BODY[2], BODY[3] + 24), radius=190, fill=(0, 0, 0, 130))
shadow = shadow.filter(ImageFilter.GaussianBlur(34))
shadow.putalpha(Image.composite(Image.new("L", (W, H), 0), shadow.getchannel("A"), hole))
Image.alpha_composite(shadow, frame).save(f"{out}/bezel.png")

# Larger than the iPhone's: a fingertip covers more of a watch face.
tap = Image.new("RGBA", (110, 110), (0, 0, 0, 0))
# The landing page's honey orange.
ImageDraw.Draw(tap).ellipse((6, 6, 104, 104), fill=(255, 170, 68, 90), outline=(255, 170, 68, 255), width=6)
tap.save(f"{out}/tap.png")
Image.open(icon).convert("RGBA").resize((280, 280), Image.LANCZOS).save(f"{out}/icon.png")
