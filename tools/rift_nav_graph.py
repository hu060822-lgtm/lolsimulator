# Nav graph for the rift map image (pixel coords in the 1024 square image).
# Run: python3 tools/rift_nav_graph.py  -> rift_nav_graph.json; NAV_NODES/NAV_EDGES in rift_geometry.gd were generated from it.
import json
top=[(100,840),(95,770),(100,290),(110,130),(170,72),(330,68),(565,95),(735,82),(860,110)]
mid=[(150,870),(267,753),(400,620),(450,570),(575,445),(630,390),(780,237),(875,140)]
bot=[(140,905),(246,940),(306,938),(495,918),(752,955),(905,935),(962,880),(982,702),(948,430),(946,280),(905,150)]
N={}; E=[]
def add(name,p): N[name]=p; return name
def chain(prefix,pts):
    ids=[add(f"{prefix}{i}",p) for i,p in enumerate(pts)]
    for a,b in zip(ids,ids[1:]): E.append((a,b))
    return ids
T=chain("top",top); M=chain("mid",mid); B=chain("bot",bot)
# extra lane sample points so jungle can join lanes mid-segment
def split(ids,i,p,name):
    a,b=ids[i],ids[i+1]; E.remove((a,b)); add(name,p); E.append((a,name)); E.append((name,b)); ids.insert(i+1,name)
split(T,2,(98,500),"topL")        # top lane, left side middle
split(T,6,(450,80),"topT")        # top lane, top edge middle (between 330 and 565)
split(M,3,(512,508),"midC")       # mid lane center (river crossing)
split(B,4,(620,935),"botB")       # bottom edge middle
split(B,8,(965,560),"botR")       # right edge middle
# base links
for s,(nx,fo) in {"b":((114,908),(55,962)),"r":((912,107),(968,56))}.items():
    add(s+"nexus",nx); add(s+"fount",fo); E.append((s+"fount",s+"nexus"))
E += [("bnexus","top0"),("bnexus","mid0"),("bnexus","bot0"),("rnexus","top8"),("rnexus","mid7"),("rnexus","bot10")]
# river (self-symmetric)
river=[(150,150),(255,245),(390,335),(455,420),(512,500),(570,590),(640,680),(770,770),(870,865)]
R=chain("riv",river)
E.remove(("riv3","riv4")); E.remove(("riv4","riv5")); E += [("riv3","midC"),("midC","riv5")]
del N["riv4"]
E += [("riv0","top3"),("riv8","bot6")]
add("baron",(330,300)); add("dragon",(690,720)); E += [("baron","riv1"),("baron","riv2"),("dragon","riv6"),("dragon","riv7")]
# blue jungle (left quadrant + bottom quadrant); red = mirror
blue={
 "jL_gromp":(175,460),"jL_blue":(255,480),"jL_wolves":(265,585),"jL_hub":(210,540),"jL_ent":(330,420),
 "jB_raptor":(480,645),"jB_red":(540,755),"jB_krug":(575,860),"jB_hub":(470,740),"jB_ent":(600,640),
}
bedges=[("jL_gromp","jL_blue"),("jL_blue","jL_hub"),("jL_hub","jL_wolves"),("jL_gromp","topL"),("jL_blue","jL_ent"),("jL_ent","riv2"),("jL_ent","riv3"),
 ("jL_wolves","mid2"),("jL_hub","top1"),
 ("jB_raptor","mid3"),("jB_raptor","jB_ent"),("jB_ent","riv5"),("jB_ent","riv6"),("jB_raptor","jB_hub"),("jB_hub","jB_red"),("jB_red","jB_krug"),("jB_krug","botB"),("jB_hub","mid1"),("jB_hub","bot3")]
mir=lambda p:(1024-p[0],1015-p[1])
lane_mir={"topL":"botR","top1":"bot8","mid2":"mid5","mid3":"mid4","mid1":"mid6","botB":"topT","bot3":"top7","riv2":"riv6","riv3":"riv5","riv5":"riv3","riv6":"riv2"}
for k,p in blue.items():
    add("b_"+k,p); add("r_"+k,mir(p))
for a,b in bedges:
    E.append(("b_"+a if a in blue else a, "b_"+b if b in blue else b))
    ra="r_"+a if a in blue else lane_mir.get(a,a); rb="r_"+b if b in blue else lane_mir.get(b,b)
    E.append((ra,rb))
for a,b in E: assert a in N and b in N,(a,b)
json.dump({"nodes":N,"edges":E},open("rift_nav_graph.json","w"))
print(len(N),len(E))
