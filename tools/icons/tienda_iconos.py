# Iconos 512x512 de los gamepasses y productos de la tienda.
# Uso: python3 tools/icons/tienda_iconos.py assets/monetization
import math, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops
S=1024
OUT=sys.argv[1]
FB="/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
def font(n): return ImageFont.truetype(FB,n)

def background(glow):
    img=Image.new("RGB",(S,S),(8,6,10))
    g=Image.new("L",(S,S),0); d=ImageDraw.Draw(g)
    for r in range(620,0,-8):
        d.ellipse([S/2-r,S/2-r-40,S/2+r,S/2+r-40],fill=int(255*(1-r/620)**1.6))
    col=Image.new("RGB",(S,S),glow)
    img=Image.composite(col,img,g.point(lambda v:int(v*0.55)))
    # vignette
    v=Image.new("L",(S,S),0); dv=ImageDraw.Draw(v)
    for r in range(760,300,-10):
        dv.ellipse([S/2-r,S/2-r,S/2+r,S/2+r],fill=int(255*(1-(r-300)/460)))
    img=Image.composite(img,Image.new("RGB",(S,S),(0,0,0)),v.filter(ImageFilter.GaussianBlur(40)))
    return img

def glowlayer(img,draw_fn,color,blur=30,strength=1.0):
    m=Image.new("L",(S,S),0); draw_fn(ImageDraw.Draw(m))
    gl=m.filter(ImageFilter.GaussianBlur(blur)).point(lambda v:min(255,int(v*strength)))
    return Image.composite(Image.new("RGB",(S,S),color),img,gl)

def frame(img,color):
    d=ImageDraw.Draw(img)
    d.rounded_rectangle([18,18,S-18,S-18],radius=90,outline=color,width=14)
    d.rounded_rectangle([44,44,S-44,S-44],radius=70,outline=tuple(int(c*0.45) for c in color),width=4)
    return img

def label(img,text,color,y=860,size=110):
    d=ImageDraw.Draw(img); f=font(size)
    w=d.textlength(text,font=f)
    while w>S-160:
        size-=6; f=font(size); w=d.textlength(text,font=f)
    x=(S-w)/2
    img=glowlayer(img,lambda dd:dd.text((x,y-size/2),text,font=f,fill=255),color,blur=18,strength=0.9)
    d=ImageDraw.Draw(img)
    d.text((x+5,y-size/2+6),text,font=f,fill=(0,0,0))
    d.text((x,y-size/2),text,font=f,fill=color)
    return img

GOLD=(242,198,88); DARKGOLD=(150,105,30)

def coin(d,cx,cy,r,tilt=1.0):
    d.ellipse([cx-r,cy-r*tilt+14,cx+r,cy+r*tilt+14],fill=DARKGOLD)
    d.ellipse([cx-r,cy-r*tilt,cx+r,cy+r*tilt],fill=GOLD,outline=(255,232,150),width=4)
    ri=r*0.72
    d.ellipse([cx-ri,cy-ri*tilt,cx+ri,cy+ri*tilt],outline=(200,145,45),width=max(3,int(r*0.08)))

def coin_face(d,cx,cy,r):
    coin(d,cx,cy,r)
    f=font(int(r*1.0)); t="M"
    w=d.textlength(t,font=f)
    d.text((cx-w/2,cy-r*0.62),t,font=f,fill=(190,135,40))

def pile(d,cx,base,n_rows,width):
    # monedas planas apiladas en pirámide
    r=70
    rows=[]
    for row in range(n_rows):
        cnt=max(1,width-row)
        for i in range(cnt):
            x=cx+(i-(cnt-1)/2)*r*1.55
            for h in range(3 if row==0 else 2):
                rows.append((x,base-row*70-h*22))
    for x,y in sorted(rows,key=lambda p:-p[1]):
        coin(d,x,y,r,tilt=0.38)

def coins_icon(amount,rows,width,extra_face):
    img=background((140,95,20))
    img=glowlayer(img,lambda d:d.ellipse([200,260,824,700]),(255,200,80),blur=90,strength=0.5)
    d=ImageDraw.Draw(img)
    pile(d,512,640,rows,width)
    for (x,y,r) in extra_face: coin_face(d,x,y,r)
    img=label(img,amount,GOLD,y=850,size=150)
    return frame(img,GOLD)

def uv():
    V=(170,90,255)
    img=background((60,20,110))
    cone=lambda d:d.polygon([(360,560),(900,250),(960,700)],fill=255)
    img=glowlayer(img,cone,V,blur=40,strength=0.8)
    img=glowlayer(img,cone,(220,180,255),blur=90,strength=0.35)
    d=ImageDraw.Draw(img)
    # huellas brillantes
    for (x,y,a) in [(700,560,0),(800,470,1),(860,600,0)]:
        img=glowlayer(img,lambda dd,x=x,y=y:(dd.ellipse([x-26,y-40,x+26,y+30],fill=255),[dd.ellipse([x-30+i*15,y-72,x-16+i*15,y-56],fill=255) for i in range(4)]),(230,200,255),blur=6,strength=1.2)
    d=ImageDraw.Draw(img)
    # linterna
    body=[(150,610),(330,500),(380,580),(200,690)]
    d.polygon(body,fill=(40,38,48),outline=(120,110,140),width=6)
    d.polygon([(330,500),(400,450),(450,640),(380,580)],fill=(70,66,84),outline=(150,140,170),width=6)
    d.polygon([(400,450),(450,640),(470,630),(420,445)],fill=(220,190,255))
    img=label(img,"LUZ UV PRO",(205,160,255),size=110)
    return frame(img,V)

def crown(d,cx,cy,w,col,shade):
    h=w*0.62
    pts=[(cx-w/2,cy+h/2),(cx-w/2,cy-h*0.25),(cx-w*0.27,cy+h*0.05),(cx,cy-h/2),(cx+w*0.27,cy+h*0.05),(cx+w/2,cy-h*0.25),(cx+w/2,cy+h/2)]
    d.polygon(pts,fill=col,outline=(255,235,160),width=8)
    d.rectangle([cx-w/2,cy+h/2-60,cx+w/2,cy+h/2],fill=shade,outline=(255,235,160),width=8)
    for px,py in [(cx-w/2,cy-h*0.25),(cx,cy-h/2),(cx+w/2,cy-h*0.25)]:
        d.ellipse([px-26,py-26,px+26,py+26],fill=(255,240,180))
    for i,c in enumerate([(220,40,50),(60,200,120),(220,40,50)]):
        x=cx+(i-1)*w*0.3
        d.ellipse([x-20,cy+h/2-50,x+20,cy+h/2-10],fill=c)

def vip():
    img=background((150,100,20))
    img=glowlayer(img,lambda d:d.ellipse([240,200,784,640]),(255,210,90),blur=80,strength=0.6)
    d=ImageDraw.Draw(img)
    crown(d,512,420,520,GOLD,(200,150,50))
    img=label(img,"VIP",GOLD,y=800,size=210)
    return frame(img,GOLD)

def founder():
    img=background((120,80,10))
    eyes=lambda d:[d.ellipse([x-62,330,x+62,390],fill=255) for x in (390,634)]
    img=glowlayer(img,eyes,(255,190,50),blur=60,strength=1.3)
    img=glowlayer(img,eyes,(255,220,120),blur=16,strength=1.4)
    d=ImageDraw.Draw(img)
    for x in (390,634):
        d.ellipse([x-46,338,x+46,382],fill=(255,236,170))
    # linterna dorada con haz
    beam=lambda dd:dd.polygon([(560,610),(980,470),(980,780)],fill=255)
    img=glowlayer(img,beam,(255,220,130),blur=40,strength=0.6)
    d=ImageDraw.Draw(img)
    d.polygon([(250,640),(500,560),(530,660),(280,740)],fill=(200,150,50),outline=(255,230,150),width=6)
    d.polygon([(500,560),(565,540),(595,690),(530,660)],fill=GOLD,outline=(255,235,170),width=6)
    d.polygon([(565,540),(595,690),(612,684),(582,535)],fill=(255,250,220))
    img=label(img,"FUNDADOR",GOLD,y=870,size=120)
    return frame(img,GOLD)

def revive():
    G=(110,255,170)
    img=background((20,90,60))
    ghost=lambda d:(d.ellipse([352,200,672,520],fill=255),d.rectangle([352,360,672,640],fill=255),[d.ellipse([352+i*80,600,432+i*80,680],fill=255) for i in range(4)])
    img=glowlayer(img,ghost,G,blur=50,strength=0.9)
    d=ImageDraw.Draw(img)
    ghost(d)  # dibuja en blanco sobre la imagen? usar color
    img2=Image.new("L",(S,S),0); ghost(ImageDraw.Draw(img2))
    img=Image.composite(Image.new("RGB",(S,S),(220,255,235)),img,img2)
    d=ImageDraw.Draw(img)
    for x in (460,564):
        d.ellipse([x-26,330,x+26,400],fill=(20,40,30))
    # flecha hacia arriba
    d.polygon([(512,430),(580,520),(540,520),(540,600),(484,600),(484,520),(444,520)],fill=(40,200,110))
    img=label(img,"REVIVE",G,size=140)
    return frame(img,G)

import os
os.makedirs(OUT,exist_ok=True)
items={
 "pase_luz_uv_pro":uv(),
 "pase_vip":vip(),
 "pase_fundador":founder(),
 "producto_revive":revive(),
 "producto_500_monedas":coins_icon("500",1,3,[(512,420,120)]),
 "producto_1500_monedas":coins_icon("1.500",2,4,[(380,380,100),(640,360,120)]),
 "producto_4000_monedas":coins_icon("4.000",3,5,[(300,330,95),(512,290,125),(724,330,95)]),
}
for k,im in items.items():
    im.resize((512,512),Image.LANCZOS).save(f"{OUT}/{k}.png")
# hoja de contacto para revisar
sheet=Image.new("RGB",(512*4+50,512*2+30),(20,20,20))
for i,(k,im) in enumerate(items.items()):
    sheet.paste(im.resize((512,512),Image.LANCZOS),(10+(i%4)*522,10+(i//4)*522))
sheet.save(f"{OUT}/_hoja.png")
