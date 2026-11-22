# 英雄資料產生器：維護 SPEC 表後執行 `python3 tools/champion_data.py data/modules/fictional_base/champions.json`
# 欄位：id | 英文名 | 台服中文名 | 位置 | 前/中/後期強度 | 對線 | 傷害類型 | 標籤 | 操作難度。class 依標籤推導，OVR 可手動覆寫。
import json,sys
# id | English | 台服中文 | roles | early mid late | lane | dmg | tags | difficulty
SPEC = """
aatrox|Aatrox|厄薩斯|TOP|7 7 6|7|AD|teamfight2 frontline1 engage1 dps1|6
camille|Camille|卡蜜兒|TOP|5 7 8|6|AD|splitpush3 pick2 mobility2|7
darius|Darius|達瑞斯|TOP|8 7 5|8|AD|frontline2 teamfight2 dps1|4
fiora|Fiora|菲歐拉|TOP|6 7 8|7|AD|splitpush3 dps2 mobility1|7
garen|Garen|蓋倫|TOP|6 6 6|6|AD|frontline2 burst1 splitpush1|2
gnar|Gnar|吶兒|TOP|6 7 6|6|AD|engage2 teamfight3 frontline2 poke1|7
gragas|Gragas|古拉格斯|TOP JUNGLE SUPPORT|6 7 6|5|AP|engage2 disengage2 frontline2 pick1|5
gwen|Gwen|關|TOP|4 6 8|5|AP|dps3 splitpush2 frontline1|6
irelia|Irelia|伊瑞莉雅|TOP MID|7 7 6|7|AD|dps2 mobility2 engage1 splitpush1|8
jax|Jax|賈克斯|TOP JUNGLE|5 7 8|5|AD|splitpush3 dps2 frontline1|5
jayce|Jayce|杰西|TOP MID|8 7 5|8|AD|poke3 siege2 burst1|7
kennen|Kennen|凱能|TOP|6 7 6|7|AP|engage3 teamfight3 mobility1|6
ksante|K'Sante|卡桑帝|TOP|5 7 7|5|AD|frontline3 engage2 pick1 peel1|8
malphite|Malphite|墨菲特|TOP SUPPORT|4 6 7|4|AP|engage3 frontline3 teamfight3|2
ornn|Ornn|鄂爾|TOP|4 6 8|5|AD|engage3 frontline3 teamfight3|5
renekton|Renekton|雷尼克頓|TOP|8 7 4|8|AD|engage1 frontline2 burst1 dps1|4
riven|Riven|雷玟|TOP|7 7 6|7|AD|burst2 mobility2 splitpush2|8
rumble|Rumble|藍寶|TOP MID|6 7 6|7|AP|teamfight3 waveclear2 disengage1|6
sion|Sion|賽恩|TOP|4 6 7|4|AD|engage3 frontline3 siege1|4
shen|Shen|慎|TOP|5 7 6|5|AD|frontline2 peel3 splitpush1 engage1|5
leesin|Lee Sin|李星|JUNGLE|8 7 4|6|AD|pick3 mobility3 engage1|8
elise|Elise|伊莉絲|JUNGLE|8 6 4|6|AP|pick3 burst2|7
jarvaniv|Jarvan IV|嘉文四世|JUNGLE|7 7 5|5|AD|engage3 teamfight2 frontline1|5
sejuani|Sejuani|史瓦妮|JUNGLE|5 7 7|4|AP|engage3 frontline3 teamfight2|4
vi|Vi|菲艾|JUNGLE|7 7 5|5|AD|pick3 engage2 burst1|4
khazix|Kha'Zix|卡力斯|JUNGLE|7 7 6|5|AD|pick3 burst3 mobility2|6
graves|Graves|葛雷夫|JUNGLE|7 7 6|6|AD|dps2 burst2 siege1|6
nidalee|Nidalee|奈德麗|JUNGLE|8 6 4|6|AP|poke2 pick2 mobility2|9
reksai|Rek'Sai|雷珂煞|JUNGLE|8 6 4|5|AD|pick3 engage1 mobility2|6
xinzhao|Xin Zhao|趙信|JUNGLE|8 7 4|6|AD|engage2 dps1 pick1|3
viego|Viego|維爾戈|JUNGLE|6 7 7|5|AD|dps2 pick1 teamfight2|7
wukong|Wukong|悟空|JUNGLE TOP|6 7 7|6|AD|engage3 teamfight3 burst1|5
maokai|Maokai|茂凱|JUNGLE SUPPORT|5 7 7|4|AP|engage3 frontline3 peel1 teamfight2|3
lillia|Lillia|莉莉亞|JUNGLE|5 7 7|5|AP|teamfight3 mobility2 engage1|6
kindred|Kindred|金德|JUNGLE|6 7 7|5|AD|dps3 peel1 mobility1|7
nocturne|Nocturne|夜曲|JUNGLE|5 7 6|5|AD|pick3 engage2 burst1|4
hecarim|Hecarim|赫克林|JUNGLE|6 7 6|5|AD|engage3 mobility2 teamfight2|6
zac|Zac|札克|JUNGLE|5 7 7|4|AP|engage3 frontline3 teamfight2|6
rengar|Rengar|雷葛爾|JUNGLE|6 7 6|5|AD|pick3 burst3|7
ekko|Ekko|艾克|JUNGLE MID|5 7 7|6|AP|burst2 pick2 mobility2|7
taliyah|Taliyah|塔莉雅|JUNGLE MID|7 7 5|6|AP|poke1 pick2 waveclear2 burst1|7
poppy|Poppy|波比|JUNGLE TOP SUPPORT|6 6 6|5|AD|disengage3 frontline2 peel2 pick1|5
ahri|Ahri|阿璃|MID|5 7 6|6|AP|pick3 burst2 mobility2|5
azir|Azir|阿祈爾|MID|4 6 9|5|AP|dps3 siege2 engage1 waveclear2|9
orianna|Orianna|奧莉安娜|MID|5 7 8|6|AP|teamfight3 peel2 waveclear3 engage1|7
syndra|Syndra|星朵拉|MID|6 7 7|7|AP|burst3 pick2 waveclear1|7
leblanc|LeBlanc|勒布朗|MID|7 7 5|7|AP|burst3 pick3 mobility2|9
zed|Zed|劫|MID|6 7 6|7|AD|burst3 pick2 splitpush2 mobility1|8
yasuo|Yasuo|犽宿|MID TOP|5 7 7|6|AD|dps2 teamfight2 mobility2|9
yone|Yone|犽凝|MID TOP|5 7 7|6|AD|dps2 engage2 teamfight2 mobility1|8
viktor|Viktor|維克特|MID|4 7 8|6|AP|teamfight3 waveclear3 poke1|6
ryze|Ryze|雷茲|MID TOP|4 7 8|5|AP|dps2 waveclear2 mobility1 frontline1|8
cassiopeia|Cassiopeia|卡莎碧雅|MID|5 7 8|7|AP|dps3 peel1 teamfight1|8
corki|Corki|庫奇|MID|5 7 7|6|AD|poke3 siege2 dps1|6
galio|Galio|加里歐|MID SUPPORT|5 7 6|4|AP|engage3 frontline2 peel1 teamfight2|5
akali|Akali|阿卡莉|MID TOP|6 7 6|6|AP|burst3 mobility3 pick1|8
sylas|Sylas|賽勒斯|MID JUNGLE|6 7 6|6|AP|burst2 engage1 teamfight2 mobility1|8
twistedfate|Twisted Fate|逆命|MID|5 7 6|5|AP|pick3 waveclear2|6
annie|Annie|安妮|MID SUPPORT|6 6 6|5|AP|engage2 burst3 teamfight1|2
lissandra|Lissandra|麗珊卓|MID|5 7 6|5|AP|engage2 disengage2 teamfight2 peel1|6
vex|Vex|薇可絲|MID|6 7 6|5|AP|burst2 engage1 disengage1 teamfight2|4
zoe|Zoe|柔依|MID|6 7 6|7|AP|poke3 pick3 burst1|9
swain|Swain|斯溫|MID SUPPORT|5 7 7|5|AP|teamfight3 frontline1 dps1|5
anivia|Anivia|艾妮維亞|MID|4 7 8|5|AP|waveclear3 disengage2 teamfight2 siege1|7
veigar|Veigar|維迦|MID|4 6 8|4|AP|burst3 teamfight1 engage1|3
lux|Lux|拉克絲|MID SUPPORT|5 6 7|6|AP|poke2 pick2 waveclear2 peel1|4
xerath|Xerath|齊勒斯|MID SUPPORT|5 7 7|6|AP|poke3 siege3 waveclear2|6
ziggs|Ziggs|希格斯|MID ADC|5 7 7|6|AP|poke3 siege3 waveclear3|5
vladimir|Vladimir|弗拉迪米爾|MID TOP|3 6 9|4|AP|teamfight3 dps2|6
katarina|Katarina|卡特蓮娜|MID|5 7 6|5|AP|burst3 teamfight2 mobility2|9
neeko|Neeko|妮可|MID SUPPORT|6 7 6|6|AP|engage3 teamfight3 burst1|6
malzahar|Malzahar|馬爾札哈|MID|4 6 7|5|AP|pick3 waveclear3|3
qiyana|Qiyana|姬亞娜|MID JUNGLE|7 7 5|6|AD|burst3 engage2 pick2|9
jinx|Jinx|吉茵珂絲|ADC|4 6 9|5|AD|dps3 siege2 teamfight2|6
caitlyn|Caitlyn|凱特琳|ADC|8 7 6|9|AD|siege3 poke2 dps2|5
ezreal|Ezreal|伊澤瑞爾|ADC|5 7 7|6|AD|poke3 mobility2|7
kaisa|Kai'Sa|凱莎|ADC|5 7 8|5|AD|dps2 burst2 mobility2|7
aphelios|Aphelios|亞菲利歐|ADC|4 7 9|5|AD|dps3 teamfight2 siege1|9
xayah|Xayah|剎雅|ADC|5 7 8|6|AD|dps3 peel1 teamfight1|6
varus|Varus|法洛士|ADC MID|6 7 7|7|AD|poke3 pick2 engage1|6
jhin|Jhin|燼|ADC|6 7 7|7|AD|poke2 pick2 burst1|6
ashe|Ashe|艾希|ADC SUPPORT|5 6 7|6|AD|engage2 pick2 dps1 peel1|4
lucian|Lucian|路西恩|ADC MID|8 7 5|8|AD|burst2 dps2 mobility2|6
draven|Draven|達瑞文|ADC|9 7 5|9|AD|dps3 burst1|8
tristana|Tristana|崔絲塔娜|ADC MID|6 7 8|6|AD|dps3 siege3 mobility1|4
missfortune|Miss Fortune|好運姐|ADC|7 7 6|7|AD|teamfight3 poke1 dps1|3
sivir|Sivir|希維爾|ADC|4 7 7|5|AD|waveclear3 dps2 disengage1|4
kalista|Kalista|克黎思妲|ADC|8 7 5|8|AD|dps2 engage1 peel1 mobility2|9
zeri|Zeri|婕莉|ADC|4 7 9|5|AD|dps3 mobility3|8
vayne|Vayne|汎|ADC TOP|4 6 9|4|AD|dps3 splitpush2 mobility1|8
twitch|Twitch|圖奇|ADC|4 7 8|4|AD|dps3 pick1 teamfight2|7
samira|Samira|煞蜜拉|ADC|7 7 6|6|AD|burst2 teamfight2 mobility2|7
senna|Senna|姍娜|ADC SUPPORT|5 6 8|6|AD|poke2 peel2 dps1|7
thresh|Thresh|瑟雷西|SUPPORT|6 7 7|6|AP|pick3 peel2 engage2 disengage1|8
nautilus|Nautilus|納帝魯斯|SUPPORT|7 7 6|6|AP|engage3 frontline2 pick2|4
leona|Leona|雷歐娜|SUPPORT|7 7 6|6|AP|engage3 frontline3 pick1|4
rakan|Rakan|銳空|SUPPORT|6 7 7|5|AP|engage3 mobility2 disengage1 peel1|7
alistar|Alistar|亞歷斯塔|SUPPORT|6 7 6|5|AP|engage3 frontline3 peel2|6
braum|Braum|布郎姆|SUPPORT|6 6 6|6|AP|peel3 frontline2 disengage2|5
lulu|Lulu|露璐|SUPPORT|5 7 8|6|AP|peel3 disengage2 poke1|5
janna|Janna|珍娜|SUPPORT|4 6 7|5|AP|disengage3 peel3|4
karma|Karma|卡瑪|SUPPORT MID|7 7 6|7|AP|poke2 peel2 disengage1 mobility1|5
bard|Bard|巴德|SUPPORT|5 7 7|5|AP|pick2 engage1 mobility2 disengage1|9
renata|Renata Glasc|睿娜妲|SUPPORT|5 7 7|6|AP|peel2 teamfight3 disengage1|7
rell|Rell|銳兒|SUPPORT|5 7 6|4|AP|engage3 frontline3 teamfight2|5
yuumi|Yuumi|悠咪|SUPPORT|3 6 8|3|AP|peel3 dps1|2
nami|Nami|娜米|SUPPORT|7 7 6|7|AP|poke1 peel2 engage1 disengage1|5
soraka|Soraka|索拉卡|SUPPORT|4 6 7|5|AP|peel3 disengage1|3
blitzcrank|Blitzcrank|布里茨|SUPPORT|6 6 5|5|AP|pick3 engage1|4
pyke|Pyke|派克|SUPPORT|7 7 5|6|AD|pick3 burst1 mobility1|8
tahmkench|Tahm Kench|貪啃奇|SUPPORT TOP|5 6 6|6|AP|peel3 frontline3|5
milio|Milio|米里歐|SUPPORT|4 6 8|5|AP|peel3 disengage2|4
akshan|Akshan|埃可尚|MID ADC|7 7 6|7|AD|pick2 mobility2 burst1 dps1|7
ambessa|Ambessa|安比薩|TOP|7 7 6|7|AD|engage2 mobility2 dps2|7
amumu|Amumu|阿姆姆|JUNGLE SUPPORT|4 7 7|4|AP|engage3 frontline3 teamfight3|2
aurelionsol|Aurelion Sol|翱銳龍獸|MID|3 6 9|5|AP|teamfight2 waveclear3 poke1 siege1|7
aurora|Aurora|歐羅拉|MID TOP|6 7 6|6|AP|burst2 mobility2 pick1 teamfight1|7
belveth|Bel'Veth|貝爾薇斯|JUNGLE|5 7 8|5|AD|dps3 mobility2 splitpush1|6
brand|Brand|布蘭德|SUPPORT MID|5 7 7|6|AP|teamfight3 poke2 burst1|3
briar|Briar|布蕾爾|JUNGLE|7 7 5|6|AD|engage2 dps2 pick1|5
chogath|Cho'Gath|科加斯|TOP MID|4 6 8|5|AP|frontline3 pick1 teamfight2|4
diana|Diana|黛安娜|JUNGLE MID|6 7 6|6|AP|engage2 burst2 teamfight3|4
drmundo|Dr. Mundo|蒙多醫生|TOP JUNGLE|4 6 8|5|AD|frontline3 dps1|3
evelynn|Evelynn|伊芙琳|JUNGLE|4 7 7|4|AP|pick3 burst3|7
fiddlesticks|Fiddlesticks|費德提克|JUNGLE|4 7 7|4|AP|engage2 teamfight3 burst1|6
fizz|Fizz|飛斯|MID|6 7 6|6|AP|burst3 mobility3 pick1|7
gangplank|Gangplank|剛普朗克|TOP|4 6 9|5|AD|teamfight2 waveclear2 splitpush2 poke1|9
heimerdinger|Heimerdinger|漢默丁格|MID TOP SUPPORT|7 7 5|8|AP|poke2 siege2 waveclear3|6
hwei|Hwei|赫威|MID SUPPORT|5 7 8|6|AP|poke3 teamfight2 pick1|9
illaoi|Illaoi|伊羅旖|TOP|6 7 7|7|AD|splitpush3 frontline1 teamfight1|5
ivern|Ivern|埃爾文|JUNGLE|4 6 7|3|AP|peel3 disengage1|7
karthus|Karthus|卡爾瑟斯|JUNGLE MID|4 7 8|5|AP|teamfight2 dps2 waveclear2|7
kassadin|Kassadin|卡薩丁|MID|3 6 9|3|AP|burst2 mobility3 pick1|8
kayle|Kayle|凱爾|TOP|3 6 9|3|AP|dps3 peel1 splitpush1|5
kayn|Kayn|慨影|JUNGLE|4 7 7|4|AD|pick2 burst2 mobility2|7
kled|Kled|克雷德|TOP|8 7 5|7|AD|engage3 dps1|7
kogmaw|Kog'Maw|寇格魔|ADC|4 6 9|5|AP|dps3 siege1|5
locke|Locke|洛克|MID|6 7 6|6|AP|burst3 pick3|8
masteryi|Master Yi|易大師|JUNGLE|5 7 8|5|AD|dps3 mobility1|4
mel|Mel|梅爾|MID SUPPORT|5 7 7|6|AP|poke2 burst2 peel2|7
mordekaiser|Mordekaiser|魔鬥凱薩|TOP|5 7 7|6|AP|frontline2 dps2 pick1|4
morgana|Morgana|魔甘娜|SUPPORT MID|5 6 7|5|AP|pick2 peel2 teamfight1|3
naafiri|Naafiri|娜菲芮|MID|7 7 5|6|AD|burst3 pick2 mobility1|4
nasus|Nasus|納瑟斯|TOP|3 6 9|3|AD|splitpush3 frontline2|3
nilah|Nilah|淣菈|ADC|5 7 7|6|AD|dps2 teamfight2 engage1 mobility1|7
nunu|Nunu & Willump|努努和威朗普|JUNGLE|7 7 5|5|AP|engage2 pick2 frontline2|4
olaf|Olaf|歐拉夫|TOP JUNGLE|8 7 4|7|AD|dps2 frontline1 engage1|4
pantheon|Pantheon|潘森|TOP SUPPORT MID|9 7 4|8|AD|pick2 burst2 engage2|5
quinn|Quinn|葵恩|TOP|7 7 5|8|AD|splitpush2 pick2 mobility2|5
rammus|Rammus|拉姆斯|JUNGLE|5 7 6|4|AP|engage3 frontline3 pick1|3
seraphine|Seraphine|瑟菈紛|SUPPORT MID|4 7 8|5|AP|teamfight3 peel2 poke1|5
sett|Sett|賽特|TOP SUPPORT|7 7 6|7|AD|engage2 frontline2 teamfight2|3
shaco|Shaco|薩科|JUNGLE SUPPORT|7 6 5|5|AD|pick3 burst2|8
shyvana|Shyvana|希瓦娜|JUNGLE|4 7 7|4|AP|dps2 teamfight2 frontline1|4
singed|Singed|辛吉德|TOP|4 6 7|5|AP|frontline2 splitpush2 disengage1|6
skarner|Skarner|史加納|JUNGLE TOP|6 7 6|5|AP|engage3 pick2 frontline2|5
smolder|Smolder|史矛德|ADC MID|3 6 9|5|AD|dps2 poke2 siege1 waveclear1|5
sona|Sona|索娜|SUPPORT|4 6 8|5|AP|peel2 teamfight2 poke1|3
talon|Talon|塔隆|MID JUNGLE|7 7 5|7|AD|burst3 pick2 mobility2|7
taric|Taric|塔里克|SUPPORT|5 6 7|5|AP|peel3 engage1 frontline1|5
teemo|Teemo|提摩|TOP|6 6 6|7|AP|poke2 splitpush1 pick1|3
trundle|Trundle|特朗德|JUNGLE TOP|6 7 6|6|AD|dps2 splitpush2 siege1|4
tryndamere|Tryndamere|泰達米爾|TOP|5 7 8|7|AD|splitpush3 dps2|5
udyr|Udyr|烏迪爾|JUNGLE TOP|6 7 6|5|AP|frontline2 engage1 dps1|5
urgot|Urgot|烏爾加特|TOP|5 7 7|6|AD|frontline2 dps2 pick1|6
velkoz|Vel'Koz|威寇茲|MID SUPPORT|5 7 7|6|AP|poke3 burst2 siege1|6
volibear|Volibear|弗力貝爾|TOP JUNGLE|7 7 6|6|AP|engage2 frontline2 dps1|4
warwick|Warwick|沃維克|JUNGLE TOP|7 7 5|6|AD|pick2 dps2 engage1|3
yorick|Yorick|約瑞科|TOP|5 7 7|6|AD|splitpush3 siege2|5
yunara|Yunara|尤娜拉|ADC|5 7 8|6|AD|dps3 mobility1|5
zaahen|Zaahen|薩亨|TOP|6 7 7|7|AD|dps2 frontline2 engage1|6
zilean|Zilean|極靈|SUPPORT MID|5 6 7|6|AP|peel3 poke1 disengage1|6
zyra|Zyra|枷蘿|SUPPORT|7 7 6|6|AP|poke2 teamfight2 peel1|4
"""
out=[]
for line in SPEC.strip().splitlines():
    cid,en,zh,roles,curve,lane,dmg,tags,diff=line.split('|')
    e,m,l=map(int,curve.split())
    t={}
    for x in tags.split():
        k=x.rstrip('0123456789'); v=int(x[len(k):]); t[k]=v
    def cls():
        r=roles.split()
        if t.get("frontline",0)>=3 or (t.get("frontline",0)>=2 and t.get("engage",0)>=3): return "tank"
        if r[0]=="ADC": return "marksman"
        if t.get("peel",0)>=3 or (r[0]=="SUPPORT" and t.get("engage",0)<3 and dmg=="AP" and t.get("burst",0)<2): return "enchanter"
        if t.get("burst",0)>=3 or (t.get("pick",0)>=3 and t.get("mobility",0)>=2): return "assassin"
        if dmg=="AP" and t.get("frontline",0)==0: return "mage"
        return "fighter"
    out.append({"id":cid,"class":cls(),"name":zh,"name_en":en,"roles":roles.split(),"curve":{"early":e,"mid":m,"late":l},"lane":int(lane),"damage":dmg,"tags":t,"difficulty":int(diff)})
ids=[o["id"] for o in out]; assert len(ids)==len(set(ids))
names=[o["name"] for o in out]; assert len(names)==len(set(names))
from collections import Counter
c=Counter(r for o in out for r in o["roles"]); print(len(out),c,file=sys.stderr)
TAGS=["engage","disengage","poke","pick","splitpush","teamfight","peel","frontline","burst","dps","waveclear","mobility","siege"]
for o in out:
    for k in o["tags"]: assert k in TAGS,(o["id"],k)
OVR={"kindred":"marksman","corki":"marksman","ekko":"assassin","nidalee":"assassin","pyke":"assassin","shaco":"assassin","kayn":"assassin",
 "rakan":"enchanter","thresh":"tank","braum":"tank","blitzcrank":"tank","taric":"tank","shen":"tank","poppy":"tank","annie":"mage","veigar":"mage",
 "syndra":"mage","ahri":"mage","brand":"mage","zyra":"mage","morgana":"mage","diana":"fighter","rumble":"fighter","yasuo":"fighter","sylas":"fighter"}
for o in out:
    if o["id"] in OVR: o["class"]=OVR[o["id"]]
json.dump(out,open(sys.argv[1],'w'),ensure_ascii=False,indent=1)
