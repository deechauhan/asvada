import importlib.util,sys
exec(open(sys.argv[1]).read().split("P = {")[0])
L_bg={'paper':'#FAF6F0','surface':'#FFFFFF','surfaceRaised':'#F1EAF0','keepsake':'#FFFBF4','plumWash':'#EFE3F5','saffronWash':'#FBEBD0'}
D_bg={'paper':'#15101A','surface':'#1F1826','surfaceRaised':'#2B2233','keepsake':'#241C2B','plumWash':'#2F2140','saffronWash':'#33261A'}
L_t={'ink':'#221530','inkSecondary':'#5D4E68','plum':'#6B2D8C','saffronInk':'#8C4F00','cafe':'#8A5A2B','restaurant':'#B23A2E','country':'#2B7553','city':'#4B5BB5','airline':'#1D689E','film':'#A3245E','custom':'#56606E'}
D_t={'ink':'#F4EEF6','inkSecondary':'#BBAFC4','plum':'#C9A3EC','saffronInk':'#F5B54A','cafe':'#D9A066','restaurant':'#FF8A7A','country':'#6FD3A4','city':'#9DA8FF','airline':'#7CC0F2','film':'#F49AC1','custom':'#AEB8C6'}
for mode,bg,t in (('LIGHT',L_bg,L_t),('DARK',D_bg,D_t)):
    print(f"\n{mode}  | "+" | ".join(bg))
    for k,v in t.items():
        vals=[cr(v,b) for b in bg.values()]
        print(f"{k:12} {v} | "+" | ".join(f"{x:.1f}" for x in vals)+("  <-- FAIL" if min(vals)<4.5 else ""))
