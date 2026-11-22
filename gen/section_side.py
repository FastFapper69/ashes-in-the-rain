"""(22. 11., the modular city) Two pieces cut from the Gemini section kit for a house among the city's fronts:
- art/section/tenement_side.png: the end wall (tenement_end's first 680 px) as a whole outer wall in section - its broken
  inner edge filled with its own bricks and inked straight, the grey void outside it and the black behind it cut away
  (the alley / the neighbour's front show past it, the hallway shows up to it).
- art/section/tenement_entry_city.png: the ground floor's entry without the side door open onto a painted street (the
  street door is in the front wall, drawn on the front seen from the street - a cut-away house shows the back wall
  there): that wall on the left, the end piece's hallway, then the entry's from its mailboxes on."""
from PIL import Image, ImageDraw
import os
R = os.path.join(os.path.dirname(__file__), "..", "art", "section")
OUT, IN, TOP, BOT = 160, 535, 100, 1040   # tenement_end: the wall's outer face, its inner face, its brick rows
SHIFT = 216                               # the brick bond repeats every 216 px (two bricks)


def wall():
    e = Image.open(os.path.join(R, "tenement_end.png")).convert("RGBA")
    w = e.crop((0, 0, 680, 1112))
    px = w.load()
    for y in range(TOP, BOT):
        for x in range(IN - 1, OUT + SHIFT - 1, -1):   # the broken edge: dark gaps filled from two bricks to the left
            r, g, b, a = px[x, y]
            if r + g + b < 75:
                px[x, y] = px[x - SHIFT, y]
    d = ImageDraw.Draw(w)
    d.rectangle((IN - 6, TOP, IN - 1, BOT), fill=(14, 12, 11, 255))   # its inner face inked like its outer one
    for y in range(1112):
        for x in range(0, OUT - 2):
            px[x, y] = (0, 0, 0, 0)
        if TOP <= y:
            for x in range(IN, 680):
                px[x, y] = (0, 0, 0, 0)
    return w, e


def main():
    w, e = wall()
    w.save(os.path.join(R, "tenement_side.png"))
    n = Image.open(os.path.join(R, "tenement_entry.png")).convert("RGBA")
    J = 1800                                   # the entry from past its mailboxes on (its rails meet the end piece's)
    out = Image.new("RGBA", (3168, 1112))
    out.paste(n.crop((J, 0, 3168, 1112)), (J, 0))
    out.paste(e.crop((680, 0, 680 + J - IN, 1112)), (IN, 0))
    F = 48                                     # the seam faded over 48 px
    more = e.crop((680 + J - IN, 0, 680 + J - IN + F, 1112))
    fade = Image.linear_gradient("L").rotate(90, expand=True).resize((F, 1112)).transpose(Image.FLIP_LEFT_RIGHT)
    out.paste(Image.composite(more, n.crop((J, 0, J + F, 1112)), fade), (J, 0))
    box = (1199, 508, 1717, 688)                # its mailboxes (to their frame), back on the wall where they hung
    out.paste(n.crop(box), box[:2])
    hall = w.crop((0, 0, IN, 1112))
    out.alpha_composite(hall, (0, 0))
    top = e.crop((0, 0, 3168, TOP))            # (the ceiling slab over the whole floor)
    out.paste(top.crop((OUT - 2, 0, 3168, TOP)), (OUT - 2, 0))
    out.save(os.path.join(R, "tenement_entry_city.png"))


if __name__ == "__main__":
    main()
