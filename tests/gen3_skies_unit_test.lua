-- Native contract doubles: no game process, imported cache, profile or save.
local checks=0
local function eq(a,b,label)assert(a==b,(label or'check')..': '..tostring(a)..' ~= '..tostring(b));checks=checks+1 end
local function module(name,value)package.loaded[name]=value;return value end
local function noop()end
local function image(w,h)return{getDimensions=function()return w,h end,setFilter=noop}end
local g={};for _,k in ipairs({'push','pop','setCanvas','clear','setColor','setScissor','setShader','setBlendMode','origin','draw','ellipse','rectangle','print','printf','setFont'})do g[k]=noop end
g.newCanvas=image;g.newQuad=function(x,y,w,h,iw,ih)assert(x>=0 and y>=0 and x+w<=iw and y+h<=ih,'quad outside native sheet');return{}end
g.newFont=function()return{}end
love={graphics=g,math={random=function(a,b)if a then return math.floor((a+(b or a))/2)end;return .5 end}}
local options,hooks,events,others={},{},{},{}
local Player=module('src.core.game3.player',{cellX=10,cellY=10,px=160,py=160,facing='right',update=noop})
local def={width=40,height=40,kind='route',environment='ROUTE'}
local defs={FR_ROUTE_1=def,FR_ROUTE_2=def,FR_REMOTE_ROUTE=def,FR_PALLET_TOWN={width=20,height=20,kind='town'},FR_HOUSE={width=10,height=10,kind='indoor'},FR_MT_MOON={width=20,height=20,kind='indoor'}}
local Map=module('src.core.game3.map',{current='FR_ROUTE_1',world={{id='FR_ROUTE_1',ox=0,oy=0},{id='FR_ROUTE_2',ox=40,oy=0}},currentDef=function()return defs[Map and Map.current or'FR_ROUTE_1']end,ensureMidLayout=function()return{collAt=function()return 0 end}end})
Map.currentDef=function()return defs[Map.current]end
module('src.core.GameVersion',{generation=function()return 3 end})
local Objects=module('src.core.game3.objects',{forDraw=function()return{}end,blocks=function()return false end})
local Sprites=module('src.core.game3.ow_sprites',{getDraw=function()end})
module('src.core.game3.collision',{isWalkable=function()return true end,isWater=function()return false end,warpAt=function()end})
local names={[16]='PIDGEY',[17]='PIDGEOTTO',[18]='PIDGEOT',[21]='SPEAROW',[22]='FEAROW',[41]='ZUBAT',[42]='GOLBAT',[84]='DODUO',[132]='DITTO',[144]='ARTICUNO',[145]='ZAPDOS',[146]='MOLTRES'}
local Pokemon=module('src.core.game3.pokemon',{name=function(id)return names[id]end,keyName=function(id)return names[id]end,
 speciesFromName=function(name)for id,n in pairs(names)do if n==name then return id end end end,speciesFromNational=function(id)return id end,national=function(id)return id end,
 types=function(id)return id==132 and{0}or{0,2}end,icon=function()return{image=image(32,64),w=32,h=32}end,frontPic=function()return{image=image(64,64),w=64,h=64}end,dexEntry=function()return{height=10}end})
local Encounters=module('src.core.game3.encounters',{tableFor=function(map)return{land={slots={{species=16,minLevel=3,maxLevel=5},{species=84,level=6},{species=41,level=7}}}}end})
module('src.mods.Gen3Compat',{worldBusy=function()return false end})
module('src.core.game3.runtime',{_mod={}})
module('src.mods.Runtime',{emit=noop})
module('src.ui.game3.start_menu',{close=noop})
local Rows=module('src.ui.game3.option_rows',{build=function()return{}end,group=function(rows)return rows end})
local begins=0;local allowBattle=true
module('src.core.game3.battle_bridge',{startWild=function(_,game,enc)begins=begins+1;return allowBattle end})
local game={phase='field',data={maps=defs},options={modOptions={}},mods={modOptions={}},input={clearEdges=noop}}
local mod={id='wild_skies',world={game=game},exports={},log={info=noop,warn=noop,error=noop},find=function(id)return others[id]end,
 read=function(_,path)local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end,
 options={define=function(_,rows)for _,r in ipairs(rows)do options[r.key]=r.default end end,get=function(_,key)return options[key]end},
 hooks={wrap=function(_,name,fn)local old=hooks[name]or function()end;hooks[name]=function(...)return fn(old,...)end end},
 events={on=function(_,name,fn)events[name]=events[name]or{};table.insert(events[name],fn)end,emit=noop}}
assert(loadfile('main.lua'))()(mod)
local X,S=mod.exports,mod.exports.gen3
eq(#Rows.build({game=game}),5,'five native settings rows')
local snapshot
for _=1,12 do snapshot=X.sharedSkyFieldSnapshot(Map.current)end
eq(#snapshot.spawns,6,'medium density cap')
eq(type(snapshot.spawns[1].species),'string','wire uses canonical species keys')
local protocol=loadfile('../gen1online-plus/lib/crossgen/sky_world.lua')
if protocol then eq(protocol().record(snapshot.spawns[1])~=nil,true,'native snapshot accepted by Online SKY wire schema')end
eq(#X.sharedSkyNeighborMaps(),1,'native seam neighbor discovery')
eq(X.sharedSkyFieldSnapshot('FR_HOUSE'),nil,'no indoor sky')
eq(X.sharedSkyFieldSnapshot('FR_REMOTE_ROUTE').map,'FR_REMOTE_ROUTE','host can simulate native remote route')
local E=X.nativeSkyEcology
eq(E.flying(84),false,'flightless species excluded')
local pool=E.pool(Map.current,def,12);eq(#pool,1,'day ecology excludes nocturnal and flightless slots')
pool=E.pool(Map.current,def,22);eq(#pool,2,'night ecology includes bats')
pool=E.pool('FR_MT_MOON',defs.FR_MT_MOON,12);eq(#pool,2,'cave supports bats by day')
for _,r in pairs(S.fields[Map.current].rows)do r.t=2 end
S.update(.1)
local row=select(2,next(S.fields[Map.current].rows));local oldGid=row.graphicsId
local age=row.t;Player.moving=true;package.loaded['src.mods.Gen3Compat'].worldBusy=function()return Player.moving end
S.update(.1);eq(row.t>age,true,'ecology advances during player walking');Player.moving=false
options.size='huge';S.update(.1);eq(row.graphicsId~=oldGid,true,'size changes live sprite geometry')
eq(X.nativeSkyArt.sprites[row.graphicsId].width>X.nativeSkyArt.sprites[oldGid].width,true,'huge changes actual rendered footprint')
options.motion=false;S.update(.1);eq(row.raiseY,-row.alt,'motion off removes decorative bob');eq(row.animClock,0,'motion off freezes flapping')
options.skyart='portrait';S.update(.1);eq(row.graphicsId~=oldGid,true,'portrait selects separate native art')
eq(X.registerSpriteSource({id='test',resolve=function()return{image=image(24,144),frames=6,frameWidth=24,frameHeight=24}end}),true,'optional public sprite source accepted')
eq(X.unregisterSpriteSource('test'),true,'optional sprite source removable')
S.update(.1);eq(X.nativeSkyArt.sprites[oldGid],nil,'retired generated art released after live refresh')
local neighbor=X.sharedSkyFieldSnapshot('FR_ROUTE_2');local views=Objects.forDraw();local ghost=false
for _,view in ipairs(views)do if view.map=='FR_ROUTE_2'and view.px>=40*16 then ghost=true end end
eq(ghost,true,'neighbor flyers projected through native object list')
eq(#X.skyDexLanes(nil,16),3,'native dex previews all art lanes')
eq(X.openSkyDex(game),true,'native sky dex opens');eq(S.menu,true,'dex modal active')
hooks['input.key'](game,{phase='pressed',key='escape'});eq(S.menu,false,'native key hook closes dex')
X.openSkyDex(game);game.phase='battle';hooks['input.step'](game,.1);eq(S.menu,false,'native dex closes before battle input');game.phase='field'
local requests,finishes={},{}
eq(X.registerSharedSkyProvider('test',{role='guest',requestClaim=function(map,id,context)requests[#requests+1]={map=map,id=id,context=context};return true end,
 finishClaim=function(map,id,outcome)finishes[#finishes+1]=outcome end}),true,'guest provider registers')
S.update(.1);eq(next(S.fields[Map.current].rows),nil,'guest never spawns before snapshot')
eq(X.spawnFlyer(16,5),nil,'guest summon cannot create local roster')
local wire={id='host:bird',species='PIDGEY',level=9,x=160,y=160,alt=8,vx=0,vy=0,bold=true,facing='right',mode='ground'}
local snap={domain='SKY',map=Map.current,revision=1,spawns={wire},localAuthority=false}
eq(X.applySharedSkyFieldSnapshot(snap),true,'guest consumes native host roster')
local original=S.fields[Map.current].rows[wire.id]
eq(X.applySharedSkyFieldSnapshot({domain='SKY',map=Map.current,revision=2,spawns={
 {id=wire.id,species='PIDGEY',level=9,x=200,y=200,alt=8,bold=true},
 {id='bad',species='MISSING',level=1,x=0,y=0,alt=0}}}),false,'invalid later row rejects complete snapshot')
eq(S.fields[Map.current].rows[wire.id].px,original.px,'rejected snapshot does not mutate existing actor')
eq(X.flyerAt(10,10,1,0,12).species,16,'public contact sees host species')
eq(X.flyerAt(10,10,1,70,20),nil,'air contact honors vertical distance')
local found,status=X.takeFlyer(10,10,1,0,12);eq(found,nil,'shared take returns no local foe');eq(status,'pending','shared take advertises claim wait')
eq(#requests,1,'one authority request');eq(begins,0,'request does not start a battle')
eq(X.applySharedSkyFieldSnapshot({domain='SKY',map=Map.current,revision=2,spawns={}}),true,'reserved actor removal applied before grant')
eq(X.grantSharedSkyFieldContact(Map.current,wire.id,wire),true,'grant survives preceding removal snapshot')
eq(begins,1,'grant starts exactly one native battle');eq(X.grantSharedSkyFieldContact(Map.current,wire.id,wire),false,'duplicate grant rejected')
for _,fn in ipairs(events['battle.ended'])do fn({result='run'})end
eq(finishes[1].consumed,false,'survivor requests authority release');eq(next(S.fields[Map.current].rows),nil,'guest never locally recreates survivor')
local posed={map=Map.current,x=10,y=10,altitude=60}
eq(X.canClaimSky(posed,wire,{airborne=false},Map.current),true,'host ground altitude eligible')
wire.alt=60;eq(X.canClaimSky(posed,wire,{airborne=false},Map.current),false,'ground cannot claim high bird')
eq(X.canClaimSky(posed,wire,{airborne=true},Map.current),true,'air contact exact band eligible')
wire.bold=false;eq(X.canClaimSky(posed,wire,{airborne=true},Map.current),false,'timid scenery excluded');wire.bold=true
eq(X.canClaimSky(posed,wire,{airborne=true},'UNSUPPORTED'),false,'unsupported host map fails closed')
S.rest=0;wire.alt=8;X.applySharedSkyFieldSnapshot({domain='SKY',map=Map.current,revision=3,spawns={wire}})
X.takeFlyer(10,10,1,0,12);allowBattle=false
eq(X.grantSharedSkyFieldContact(Map.current,wire.id,wire),false,'native battle start rejection releases claim')
eq(S.fields[Map.current].rows[wire.id]~=nil,true,'failed start leaves local replica intact')
allowBattle=true;X.takeFlyer(10,10,1,0,12);X.grantSharedSkyFieldContact(Map.current,wire.id,wire)
for _,fn in ipairs(events['battle.ended'])do fn({result='catch'})end
eq(finishes[#finishes].consumed,true,'native catch result commits authoritative bird')
X.unregisterSharedSkyProvider('test');eq(X.spawnFlyer(16,5)~=nil,true,'disconnect restores independent sky')
print('gen3_skies_unit_test: '..checks..' assertions passed')
