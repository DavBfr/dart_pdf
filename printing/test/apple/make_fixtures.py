import os, sys

def build(objects):
    """objects: list of byte strings, 1-indexed. Returns the whole file."""
    out = bytearray(b"%PDF-1.7\n%\xe2\xe3\xcf\xd3\n")
    offsets = []
    for i, body in enumerate(objects, start=1):
        offsets.append(len(out))
        out += b"%d 0 obj\n" % i + body + b"\nendobj\n"
    xref = len(out)
    out += b"xref\n0 %d\n" % (len(objects) + 1)
    out += b"0000000000 65535 f \n"
    for off in offsets:
        out += b"%010d 00000 n \n" % off
    out += (b"trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n"
            % (len(objects) + 1, xref))
    return bytes(out)

def stream(content, extra=b""):
    return b"<< /Length %d %s>>\nstream\n" % (len(content), extra) + content + b"\nendstream"

def page_pdf(mediabox, content, cropbox=None, rotate=None, annots=None, annot_objs=()):
    page = b"<< /Type /Page /Parent 2 0 R /MediaBox [%s] " % mediabox
    if cropbox:
        page += b"/CropBox [%s] " % cropbox
    if rotate is not None:
        page += b"/Rotate %d " % rotate
    if annots:
        page += b"/Annots [%s] " % annots
    page += b"/Contents 4 0 R >>"
    objs = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        page,
        stream(content),
    ]
    objs.extend(annot_objs)
    return build(objs)

def corners(x, y, w, h):
    """Four 10x10 corner squares plus a grey background, in PDF user space."""
    c = b"0.5 0.5 0.5 rg %g %g %g %g re f\n" % (x, y, w, h)
    c += b"1 0 0 rg %g %g 10 10 re f\n" % (x, y)                    # red  bottom-left
    c += b"0 1 0 rg %g %g 10 10 re f\n" % (x + w - 10, y)           # green bottom-right
    c += b"0 0 1 rg %g %g 10 10 re f\n" % (x, y + h - 10)           # blue top-left
    c += b"1 1 0 rg %g %g 10 10 re f\n" % (x + w - 10, y + h - 10)  # yellow top-right
    return c

out = sys.argv[1]
os.makedirs(out, exist_ok=True)

def w(name, data):
    with open(os.path.join(out, name), "wb") as f:
        f.write(data)
    print(name, len(data), "bytes")

# 1. CropBox origin away from the media origin.
w("crop_bl.pdf", page_pdf(b"0 0 200 200", corners(40, 60, 100, 100),
                          cropbox=b"40 60 140 160"))
# 2. MediaBox origin away from zero.
w("offset.pdf", page_pdf(b"50 50 250 250", corners(50, 50, 200, 200)))
# 3. A quarter-turn page.
w("rot90.pdf", page_pdf(b"0 0 200 100", corners(0, 0, 200, 100), rotate=90))
# 4. A crop box flush with the media top-right corner: the case that worked.
w("crop_tr.pdf", page_pdf(b"0 0 200 200", corners(100, 100, 100, 100),
                          cropbox=b"100 100 200 200"))
# 5. A page that paints nothing at all, so only the backdrop shows.
w("blank.pdf", page_pdf(b"0 0 20 20", b""))
# 6. An annotation whose appearance stream paints the top-right quadrant red.
# /Resources is optional per the spec, but PDFKit renders the stream with a
# default (black) colour without it, so a faithful fixture carries one.
appearance = stream(b"1 0 0 rg 0 0 50 50 re f",
                    b"/Type /XObject /Subtype /Form /BBox [0 0 50 50] "
                    b"/Resources << >> ")
annot = (b"<< /Type /Annot /Subtype /Square /Rect [50 50 100 100] /F 4 "
         b"/AP << /N 6 0 R >> >>")
w("annot.pdf", page_pdf(b"0 0 100 100", b"1 1 1 rg 0 0 100 100 re f",
                        annots=b"5 0 R", annot_objs=(annot, appearance)))
# 7. The same annotation, hidden.
annot_hidden = (b"<< /Type /Annot /Subtype /Square /Rect [50 50 100 100] /F 2 "
                b"/AP << /N 6 0 R >> >>")
w("hidden.pdf", page_pdf(b"0 0 100 100", b"1 1 1 rg 0 0 100 100 re f",
                         annots=b"5 0 R", annot_objs=(annot_hidden, appearance)))
