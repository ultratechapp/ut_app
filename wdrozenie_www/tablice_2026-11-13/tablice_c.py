from PIL import Image, ImageDraw, ImageFilter
import sys
a=Image.open('ekipa_rolka_v5.webp').convert('RGB')
b=Image.open('ekipa_rolka_v5b.webp').convert('RGB')  # keeps softened faces
out=b.copy()
# restore original around plates first (undo heavy blobs)
for box in [(8290,480,8470,600),(11130,395,11200,445),(4405,440,4485,485)]:
    out.paste(a.crop(box),box[:2])
# (polygon of letter area, blur radius, feather)
plates=[([(8327,538),(8441,507),(8441,532),(8329,571)],6,1.5),
        ([(11150,411),(11183,411),(11183,427),(11150,427)],2.6,0.8),
        ([(4430,457),(4467,457),(4467,467),(4430,467)],2.2,0.8)]
for poly,r,f in plates:
    xs=[p[0] for p in poly];ys=[p[1] for p in poly]
    box=(min(xs)-20,min(ys)-20,max(xs)+20,max(ys)+20)
    reg=out.crop(box)
    # blur only plate interior: fill outside with nearest by blurring a clipped copy
    m=Image.new('L',reg.size,0);ImageDraw.Draw(m).polygon([(x-box[0],y-box[1]) for x,y in poly],fill=255)
    bl=reg.filter(ImageFilter.GaussianBlur(r))
    # normalise blurred interior toward plate brightness so it reads as a plate, not a blob
    mm=m.filter(ImageFilter.GaussianBlur(f))
    reg.paste(bl,(0,0),mm)
    out.paste(reg,box[:2])
out.save('ekipa_rolka_v5c.webp','WEBP',quality=int(sys.argv[1]) if len(sys.argv)>1 else 82,method=6)
for i,(x0,y0,x1,y1) in enumerate([(8305,495,8452,588),(11143,406,11190,434),(4418,448,4474,476)]):
  m=60;bx=(x0-m,y0-m,x1+m,y1+m);w=bx[2]-bx[0];h=bx[3]-bx[1]
  c=Image.new('RGB',(w*2+10,h),'white');c.paste(a.crop(bx),(0,0));c.paste(out.crop(bx),(w+10,0))
  c.resize((c.width*3,c.height*3)).save(f'cmpc{i}.png')
