def lum(h):
    h=h.lstrip('#'); c=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    c=[x/12.92 if x<=0.03928 else ((x+0.055)/1.055)**2.4 for x in c]
    return 0.2126*c[0]+0.7152*c[1]+0.0722*c[2]
def cr(a,b):
    la,lb=sorted([lum(a),lum(b)],reverse=True); return (la+0.05)/(lb+0.05)

P = {
 'A_light': dict(bg={'paper':'#FAF6F0','card':'#FFFFFF','raised':'#F1EAF0'},
   text={'ink':'#221530','inkSecondary':'#5D4E68','plum':'#6B2D8C','saffronInk':'#8C4F00',
         'cafe':'#8A5A2B','restaurant':'#B23A2E','country':'#2B7553','city':'#4B5BB5','airline':'#1D689E','film':'#A3245E','custom':'#56606E'}),
 'A_dark': dict(bg={'paper':'#15101A','card':'#1F1826','raised':'#2B2233'},
   text={'ink':'#F4EEF6','inkSecondary':'#BBAFC4','plum':'#C9A3EC','saffronInk':'#F5B54A',
         'cafe':'#D9A066','restaurant':'#FF8A7A','country':'#6FD3A4','city':'#9DA8FF','airline':'#7CC0F2','film':'#F49AC1','custom':'#AEB8C6'}),
 'B_light': dict(bg={'bg':'#F8F5FA','card':'#FFFFFF','raised':'#EEE8F3'}, text={'ink':'#1E1426','sec':'#5A4E66','brand':'#7A3FA0'}),
 'B_dark': dict(bg={'bg':'#120E17','card':'#1C1622','raised':'#28202F'}, text={'ink':'#F2EDF6','sec':'#B8ADC3','brand':'#D3B0F2'}),
 'C_light': dict(bg={'bg':'#FAF7F2','card':'#FFFFFF','raised':'#F1ECE4'}, text={'ink':'#1F1B16','sec':'#5C554C','saffron':'#A8401C','plum':'#6B2D8C'}),
 'C_dark': dict(bg={'bg':'#141210','card':'#1E1B18','raised':'#2A2622'}, text={'ink':'#F3EEE7','sec':'#B5ADA2','saffron':'#F08A5D','plum':'#C9A3EC'}),
}
bad=[]
for name,p in P.items():
    print('==',name)
    for t,tv in p['text'].items():
        row=[f"{cr(tv,bv):5.2f}" for bv in p['bg'].values()]
        mn=min(cr(tv,bv) for bv in p['bg'].values())
        print(f"  {t:13} {tv} on {list(p['bg'])}: {row}{'  FAIL' if mn<4.5 else ''}")
        if mn<4.5: bad.append((name,t))
pairs = [('onPlum light','#FFFFFF','#6B2D8C'),('onPlum dark','#15101A','#C9A3EC'),
 ('onSaffron light','#221530','#F2A93B'),('onSaffron dark','#15101A','#F5B54A'),
 ('cream on aubergine','#FAF6F0','#3A1748'),('saffron on aubergine','#F5B54A','#3A1748'),
 ('lilac on aubergine','#C9A3EC','#3A1748'),('cream on aubergineDeep','#FAF6F0','#24102E'),
 ('saffron on aubergineDeep','#F5B54A','#24102E'),('ink on saffronWash light','#221530','#FBEBD0'),
 ('saffronInk on saffronWash','#8C4F00','#FBEBD0'),('plum on plumWash light','#6B2D8C','#EFE3F5'),
 ('ink on plumWash','#221530','#EFE3F5'),('plum dark on plumWash dark','#C9A3EC','#2F2140'),
 ('ink dark on plumWash dark','#F4EEF6','#2F2140'),('secondary dark on plumWash dark','#BBAFC4','#2F2140'),
 ('secondary light on plumWash','#5D4E68','#EFE3F5'),
 ('onBrand B light','#FFFFFF','#7A3FA0'),('onBrand B dark','#120E17','#D3B0F2')]
for n,a,b in pairs:
    v=cr(a,b); print(f"{n:34} {a} on {b}: {v:5.2f}{'  FAIL' if v<4.5 else ''}")
    if v<4.5: bad.append(n)
print('FAILS:',bad)
