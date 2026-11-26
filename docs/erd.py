"""Draws docs/erd.png — the seven-table schema, readable at a glance.

Regenerate with:  python3 docs/erd.py
"""
from PIL import Image, ImageDraw, ImageFont

S = 2
W, H = 1460, 1010
img = Image.new("RGB", (W * S, H * S), "#FAF8F5")
d = ImageDraw.Draw(img)

PAPER, SURFACE, INK, SEC, HAIR = "#FAF8F5", "#FFFFFF", "#1B1A18", "#6B6660", "#E4DED6"
ACCENT, WARN = "#0E6B5F", "#8A5A00"

def F(path, size):
    return ImageFont.truetype(path, size * S)

AR = "/System/Library/Fonts/Supplemental/Arial.ttf"
ARB = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
MONO = "/System/Library/Fonts/Menlo.ttc"
f_title, f_sub = F(ARB, 16), F(AR, 10)
f_field, f_tag = F(MONO, 12), F(ARB, 9)
f_edge, f_leg, f_legb = F(AR, 10), F(AR, 11), F(ARB, 11)

HEAD, ROW, PAD = 34, 21, 10

def entity(name, subtitle, fields, x, y, w):
    h = HEAD + 24 + ROW * len(fields) + PAD
    d.rounded_rectangle([x*S, y*S, (x+w)*S, (y+h)*S], radius=10*S, fill=SURFACE, outline=HAIR, width=2*S)
    d.rounded_rectangle([x*S, y*S, (x+w)*S, (y+HEAD)*S], radius=10*S, fill=ACCENT, outline=ACCENT, width=2*S)
    d.rectangle([x*S, (y+HEAD-12)*S, (x+w)*S, (y+HEAD)*S], fill=ACCENT)
    d.text(((x+12)*S, (y+8)*S), name, font=f_title, fill="#FFFFFF")
    d.text(((x+12)*S, (y+HEAD+6)*S), subtitle, font=f_sub, fill=SEC)
    yy = y + HEAD + 26
    for i, (fname, tag) in enumerate(fields):
        d.text(((x+14)*S, yy*S), fname, font=f_field, fill=INK)
        if tag:
            tw = d.textlength(fname, font=f_field)
            d.text(((x+18)*S+tw, (yy+2)*S), tag, font=f_tag,
                   fill=ACCENT if tag == "PK" else (WARN if tag.startswith("FK") else SEC))
        if i < len(fields) - 1:
            d.line([((x+12)*S, (yy+17)*S), ((x+w-12)*S, (yy+17)*S)], fill=HAIR, width=1)
        yy += ROW
    return dict(x=x, y=y, w=w, h=h)

def row(geo, i):
    return geo["y"] + HEAD + 26 + i * ROW + 7

def path(points, colour=SEC):
    d.line([(px*S, py*S) for px, py in points], fill=colour, width=2*S, joint="curve")

def crow(x, y, side):
    s = 8
    prongs = {"left": [(x+s, y-s), (x+s, y+s)], "right": [(x-s, y-s), (x-s, y+s)],
              "top": [(x-s, y+s), (x+s, y+s)], "bottom": [(x-s, y-s), (x+s, y-s)]}[side]
    for px, py in prongs:
        d.line([(x*S, y*S), (px*S, py*S)], fill=SEC, width=2*S)

def one(x, y, side):
    if side in ("left", "right"):
        d.line([((x-3)*S, (y-8)*S), ((x-3)*S, (y+8)*S)], fill=SEC, width=2*S)
    else:
        d.line([((x-8)*S, (y-3)*S), ((x+8)*S, (y-3)*S)], fill=SEC, width=2*S)

def tag(x, y, text):
    d.text((x*S, y*S), text, font=f_edge, fill=SEC)

owner = entity("owner", "one household · no accounts", [("id","PK"),("name",""),("email",""),("phone",""),("created_at",""),("updated_at","")], 40, 60, 240)
pet = entity("pet", "one animal · deleted with its owner", [("id","PK"),("owner_id","FK"),("name",""),("species",""),("breed",""),("sex",""),("date_of_birth",""),("weight_kg",""),("microchip","U"),("photo_path",""),("created_at",""),("updated_at","")], 40, 340, 240)
journal = entity("journal_entry", "one moment · deleted with its pet", [("id","PK"),("pet_id","FK"),("kind",""),("occurred_at",""),("note",""),("duration_minutes",""),("created_at",""),("updated_at","")], 430, 60, 280)
health = entity("health_record", "one note · append-only, deleted with its pet", [("id","PK"),("pet_id","FK"),("recorded_on",""),("condition",""),("diagnosis",""),("treatment",""),("prescribed_medication",""),("vet_name",""),("created_at","")], 430, 360, 280)
vacc = entity("vaccination", "one dose · catalog link may be cleared", [("id","PK"),("pet_id","FK"),("vaccine_type_id","FK"),("vaccine_name",""),("vaccination_date",""),("next_due_date",""),("vet_name",""),("created_at","")], 430, 680, 280)
appt = entity("appointment", "one vet visit · kept if the pet goes", [("id","PK"),("pet_id","FK ~"),("clinic_name",""),("purpose",""),("scheduled_at",""),("status",""),("completed_at",""),("cancel_reason",""),("created_at",""),("updated_at","")], 860, 360, 270)
vtype = entity("vaccine_type", "the shared catalog", [("id","PK"),("name","U"),("interval_months",""),("is_core",""),("sort_order","")], 1210, 680, 220)

# owner 1 : N pet
x0 = owner["x"] + 48
path([(x0, owner["y"] + owner["h"]), (x0, pet["y"])])
one(x0, owner["y"] + owner["h"] + 18, "top")
crow(pet["x"] + 48, pet["y"], "top")
tag(x0 + 10, owner["y"] + owner["h"] + 10, "1 : N")

# pet 1 : N journal_entry
xr = pet["x"] + pet["w"]
yj = row(journal, 1)
path([(xr, 400), (352, 400), (352, yj), (journal["x"], yj)])
crow(journal["x"], yj, "left")
one(xr, 400, "right")
tag(300, yj - 16, "1 : N")

# pet 1 : N health_record
yh = row(health, 1)
path([(xr, yh), (health["x"], yh)])
crow(health["x"], yh, "left")
one(xr, yh, "right")
tag(xr + 8, yh - 16, "1 : N")

# pet 1 : N vaccination
yv = row(vacc, 1)
path([(xr, 580), (392, 580), (392, yv), (vacc["x"], yv)])
crow(vacc["x"], yv, "left")
one(xr, 580, "right")
tag(344, yv - 16, "1 : N")

# pet 1 : N appointment (gap above health)
ya = row(appt, 1)
path([(xr, 480), (392, 480), (392, 330), (820, 330), (820, ya), (appt["x"], ya)])
crow(appt["x"], ya, "left")
one(xr, 480, "right")
tag(430, 312, "1 : N")

# vaccine_type 1 : N vaccination
yt = row(vtype, 0)
yv2 = row(vacc, 2)
path([(vtype["x"], yt), (1150, yt), (1150, yv2), (vacc["x"] + vacc["w"], yv2)])
crow(vacc["x"] + vacc["w"], yv2, "right")
one(vtype["x"], yt, "left")
tag(1050, yt - 16, "N : 1")

# title block (top-right, in the empty quadrant)
d.text((1000*S, 70*S), "Pet Health Tracker", font=F(ARB, 22), fill=INK)
d.text((1000*S, 104*S), "Relational schema · 7 tables · SQLite", font=F(AR, 12), fill=SEC)
d.text((1000*S, 138*S), "One household owns many pets;", font=F(AR, 11), fill=SEC)
d.text((1000*S, 156*S), "each pet owns its own records,", font=F(AR, 11), fill=SEC)
d.text((1000*S, 174*S), "vaccinations and visits.", font=F(AR, 11), fill=SEC)

# legend
lx, ly = 40, 940
d.text((lx*S, ly*S), "PK", font=f_tag, fill=ACCENT); d.text(((lx+26)*S, ly*S), "primary key", font=f_leg, fill=SEC)
d.text(((lx+120)*S, ly*S), "FK", font=f_tag, fill=WARN); d.text(((lx+146)*S, ly*S), "foreign key", font=f_leg, fill=SEC)
d.text(((lx+236)*S, ly*S), "FK ~", font=f_tag, fill=WARN); d.text(((lx+270)*S, ly*S), "nullable — the row survives without it", font=f_leg, fill=SEC)
d.text(((lx+510)*S, ly*S), "U", font=f_tag, fill=SEC); d.text(((lx+524)*S, ly*S), "unique", font=f_leg, fill=SEC)
path([(lx+590, ly+7), (lx+630, ly+7)])
for px, py in [((lx+590), (ly-1)), ((lx+590), (ly+15))]:
    d.line([((lx+590)*S, (ly+7)*S), (px*S, py*S)], fill=SEC, width=2*S)
d.text(((lx+638)*S, ly*S), "the many end", font=f_leg, fill=SEC)
d.text(((lx+760)*S, ly*S), "1 : N  one parent row, many child rows", font=f_legb, fill=SEC)

img.resize((W*2, H*2), Image.LANCZOS).save("docs/erd.png")
print("saved docs/erd.png")
