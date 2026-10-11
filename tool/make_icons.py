"""Erzeugt das App-Icon (gleiches Motiv wie AppLogo in widgets.dart)."""
import os, sys
from PIL import Image, ImageDraw

FOREST=(31,77,58); GOLD=(184,145,58); WHITE=(255,255,255)

def draw(size, rounded=True, full_bleed=False):
    S=size*4
    im=Image.new('RGBA',(S,S),(0,0,0,0)); d=ImageDraw.Draw(im)
    if rounded and not full_bleed:
        d.rounded_rectangle([0,0,S-1,S-1],radius=int(S*0.24),fill=FOREST)
    else:
        d.rectangle([0,0,S,S],fill=FOREST)
    w=int(S*0.06); m=S*0.2; l=S*0.16
    for x,y,dx,dy in [(m,m,1,1),(S-m,m,-1,1),(m,S-m,1,-1),(S-m,S-m,-1,-1)]:
        d.line([(x,y),(x+dx*l,y)],fill=WHITE,width=w)
        d.line([(x,y),(x,y+dy*l)],fill=WHITE,width=w)
        for (px,py) in [(x,y),(x+dx*l,y),(x,y+dy*l)]:
            d.ellipse([px-w/2,py-w/2,px+w/2,py+w/2],fill=WHITE)
    # Schild (Polygon-Näherung der Bezierkurven)
    import math
    def quad(p0,p1,p2,n=30):
        return [((1-t)**2*p0[0]+2*(1-t)*t*p1[0]+t*t*p2[0],(1-t)**2*p0[1]+2*(1-t)*t*p1[1]+t*t*p2[1]) for t in [i/n for i in range(n+1)]]
    cx=S/2
    pts=[(cx,S*0.31),(S*0.66,S*0.37)]+quad((S*0.66,S*0.37),(S*0.66,S*0.6),(cx,S*0.7))+quad((cx,S*0.7),(S*0.34,S*0.6),(S*0.34,S*0.37))
    d.polygon(pts,fill=GOLD)
    cw=int(S*0.05)
    d.line([(S*0.43,S*0.5),(S*0.485,S*0.555),(S*0.58,S*0.45)],fill=FOREST,width=cw,joint='curve')
    return im.resize((size,size),Image.LANCZOS)

if __name__=='__main__':
    root=sys.argv[1]
    android={'mdpi':48,'hdpi':72,'xhdpi':96,'xxhdpi':144,'xxxhdpi':192}
    for k,v in android.items():
        p=f'{root}/android/app/src/main/res/mipmap-{k}/ic_launcher.png'
        if os.path.isdir(os.path.dirname(p)): draw(v).save(p)
    iosdir=f'{root}/ios/Runner/Assets.xcassets/AppIcon.appiconset'
    if os.path.isdir(iosdir):
        import json
        c=json.load(open(f'{iosdir}/Contents.json'))
        for img in c['images']:
            fn=img.get('filename')
            if not fn: continue
            sz=float(img['size'].split('x')[0]); sc=int(img['scale'][0])
            px=int(round(sz*sc))
            # iOS: kein Alphakanal, keine eigenen Rundungen
            draw(px,full_bleed=True).convert('RGB').save(f'{iosdir}/{fn}')
    draw(512).save(f'{root}/docs/icon.png')
    print('ok')
