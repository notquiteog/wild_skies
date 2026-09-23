-- Native FRLG sky ecology. Native event objects carry altitude via raiseY, so
-- the stock renderer and optional Battle Art use one set of actor records.
return function(mod)
 local function loadPart(path)return assert((loadstring or load)(assert(mod:read(path)),'@wild_skies/'..path))()end
 local Player=require('src.core.game3.player')
 local Map=require('src.core.game3.map')
 local Collision=require('src.core.game3.collision')
 local Objects=require('src.core.game3.objects')
 local Sprites=require('src.core.game3.ow_sprites')
 local Pokemon=require('src.core.game3.pokemon')
 local Encounters=require('src.core.game3.encounters')
 local Compat=require('src.mods.Gen3Compat')
 local Runtime=require('src.core.game3.runtime')
 local E=loadPart('lib/gen3/ecology.lua')(Pokemon,Encounters)
 local Art=loadPart('lib/gen3/art.lua')(mod,Pokemon,Sprites)
 local S={fields={},serial=0,time=0,rest=0,revision=0}
 local function finite(v)return type(v)=='number'and v==v and math.abs(v)<1000000 end
 local density={low={3,8},med={6,4},high={10,2.5}}
 local function game()return mod.world.game end
 local function option(key)return mod.options:get(key)end
 local function ex(id)local other=mod.find and mod.find(id);return other and other.exports end
 local function emit(name,payload)if mod.events and mod.events.emit then mod.events:emit('mod.wild_skies.'..name,payload)end end
 local function busy()local g=game();return not g or g.phase~='field'or Compat.worldBusy(g)or S.menu end
 local function simulationBusy()
  local g=game();if not g or g.phase~='field'or S.menu then return true end
  local field=package.loaded['src.core.game3.field'];if field and(field.locked or field.running==false)then return true end
  if Runtime.uiBusy and Runtime.uiBusy()then return true end
  local space=package.loaded['src.core.game3.scripting.space'];local vm=space and((space.getVm and space.getVm())or space.vm)
  if vm and vm.isRunning and vm:isRunning()then return true end
  local warp=package.loaded['src.core.game3.warp'];return warp and warp.isBusy and warp.isBusy()or false
 end
 local function defFor(map)return map==Map.current and Map.currentDef()or(game()and game().data and game().data.maps and game().data.maps[map])end
 local function size(def)local layout=def and def.midLayout;return layout and layout.width or def and def.width,layout and layout.height or def and def.height end
 local function eligible(map)
  return E.environment(map,defFor(map))
 end
 local function field(map)
  if not eligible(map)then return end
  if S.fields[map]then return S.fields[map]end
  local def=defFor(map);local w,h=size(def)
  if not w or not h or not E.environment(map,def)then return end
  local f={map=map,def=def,w=w,h=h,rows={},cooldown=0};S.fields[map]=f;return f
 end
 local function liveAuthority()return not S.provider or S.provider.role=='host'or S.provider.localAuthority==true end
 local function hit(row)return{id=row.id,species=row.species,level=row.level,altitude=row.alt,cellX=row.cellX,cellY=row.cellY}end
 local function remove(row)
  local f=S.fields[row.map];if f then f.rows[row.id]=nil end
 end
 local function ground(f,x,y)
  if x<0 or y<0 or x>=f.w or y>=f.h then return false end
  if f.map==Map.current then return Collision.isWalkable(x,y)and not Collision.isWater(x,y)and not Collision.warpAt(x,y)and not Objects.blocks(x,y)end
  local layout=Map.ensureMidLayout and Map.ensureMidLayout(game(),f.map,f.def)
  if not layout or not layout.collAt then return false end
  local coll=layout:collAt(x,y)
  if coll~=0 and coll~=0x10 and coll~=0x14 and coll~=0x18 then return false end
  for _,list in ipairs({f.def.objects or{},f.def.warps or{}})do for _,e in ipairs(list)do if e.x==x and e.y==y then return false end end end
  return true
 end
 local function spawn(f,species,level,opts)
  if not f or not liveAuthority()then return end
  species=E.species(species);if not species then return end
  local gid=Art.sprite(species,game(),0);if not gid then return end
  S.serial=S.serial+1;local random=love.math.random
  local x,y=random(0,f.w-1),random(0,f.h-1)
  if f.map==Map.current then
   local side=random(1,4);x=math.max(0,math.min(f.w-1,Player.cellX+(side==1 and-9 or side==2 and 9 or random(-8,8))))
   y=math.max(0,math.min(f.h-1,Player.cellY+(side==3 and-7 or side==4 and 7 or random(-6,6))))
  end
  opts=opts or{};local env=eligible(f.map)
  local row={id='sky3_'..S.serial,map=f.map,species=species,level=math.max(1,math.min(100,math.floor(level or 5))),
   px=opts.x or x*16,py=opts.y or y*16,cellX=x,cellY=y,alt=opts.alt or random(28,76),altTarget=random(28,76),
   heading=random()*math.pi*2,speed=random(28,44),t=0,life=random(35,65),mode='roam',
   bold=not env.town and(opts.bold==true or E.legend(species)or random()<.33),flock=opts.flock or S.serial,
   graphicsId=gid,localId=740000+S.serial,passable=true,visible=true,wildSkiesFlyer=true,
   stepFrames=16,animClock=0,facing='right',def={graphicsId=gid,elevation=0}}
  f.rows[row.id]=row;return row
 end
 local function populate(f,initial)
  if not liveAuthority()then return end
  local config=density[option('density')]or density.med
  local count=0;for _ in pairs(f.rows)do count=count+1 end
  if count>=config[1]or not initial and f.cooldown>0 then return end
  local pool,env=E.pool(f.map,f.def,os.date('*t').hour)
  local species,level,legend=E.pick(pool,env,love.math.random);if not species then return end
  local lead=spawn(f,species,level,{bold=legend});if not lead then return end
  if not legend and love.math.random()<.35 then
   for i=1,math.min(config[1]-count-1,love.math.random(1,2))do
    spawn(f,species,level,{flock=lead.flock,x=math.max(0,math.min(f.w*16-1,lead.px+i*20)),y=math.max(0,math.min(f.h*16-1,lead.py+i*12)),alt=lead.alt+i*3})
   end
  end
  f.cooldown=config[2]
 end
 local function near(x,y,radius,alt,tolerance,restExempt)
  if not restExempt and S.rest>0 then return end
  local f=S.fields[Map.current];if not f then return end
  local best,dist
  for _,r in pairs(f.rows)do
   local d=math.abs(r.cellX-x)+math.abs(r.cellY-y)
   if r.bold and r.t>=.75 and not r.summon and d<=(radius or 1)
    and(alt==nil or math.abs(r.alt-alt)<=(tolerance or 20))and(not dist or d<dist)then best,dist=r,d end
  end
  return best
 end
 local function request(row,airborne)
  if not S.provider or not S.provider.requestClaim or S.pending then return false end
  local p={map=Map.current,id=row.id,row=row,airborne=airborne};S.pending=p
  local ok,accepted=pcall(S.provider.requestClaim,Map.current,row.id,{airborne=airborne,domain='SKY'})
  if not ok or accepted~=true then if S.pending==p then S.pending=nil end;return false end
  return true
 end
 local function start(row,shared)
  if busy()then return false end
  local enc={species=row.species,level=row.level}
  S.mate=nil
  local db=ex('double_battles')
  S.lastBump=not shared and{species=row.species,flock=row.flock,alt=row.alt}or nil
  if not shared and db and db.tagOrganic then db.tagOrganic(enc,{map=Map.current,terrain='air',requirePartnerSource=true})end
  S.building=true
  local result={pcall(require('src.core.game3.battle_bridge').startWild,Runtime._mod,game(),enc,{})}
  S.building=false
  if not result[1]or not result[2]then S.lastBump=nil;return false end
  if not shared then S.localBattle={lead=row,mate=S.mate};S.mate=nil end
  remove(row);S.rest=25;emit('flyer_bumped',hit(row));return true
 end
 mod.exports.flyerAt=function(x,y,radius,alt,tolerance)local r=near(x,y,radius,alt,tolerance);return r and hit(r)end
 mod.exports.takeFlyer=function(x,y,radius,alt,tolerance)
  local row=near(x,y,radius,alt,tolerance);if not row then return end
  if S.provider then if request(row,alt~=nil and alt>12)then return nil,'pending'end;return end
  remove(row);S.rest=25;S.lastTaken=row;S.lastTakenAt=S.time;emit('flyer_taken',hit(row));return hit(row)
 end
 mod.exports.takeFlockmate=function(x,y,radius,alt,tolerance)
  if S.provider then return end
  local lead=S.lastBump or S.lastTaken
  if lead and E.legend(lead.species)then return end
  local row,distance
  local f=S.fields[Map.current];if not f then return end
  for _,r in pairs(f.rows)do
   local d=math.abs(r.cellX-x)+math.abs(r.cellY-y)
   if r.bold and r.t>=.75 and not r.summon and not E.legend(r.species)and(not lead or r.flock==lead.flock)
    and d<=(radius or 8)and(alt==nil or math.abs(r.alt-alt)<=(tolerance or 20))and(not distance or d<distance)then row,distance=r,d end
  end
  if not row then return end
  remove(row);S.mate=row;emit('flyer_taken',hit(row));return hit(row)
 end
 mod.exports.spawnFlyer=function(species,level)
  if not liveAuthority()then return nil,'shared replica'end
  local row=spawn(field(Map.current),species,level,{bold=true});return row and row.id or nil,row and nil or'no native sky or sprite'
 end
 mod.exports.summonFlyer=function(x,y,opts)
  if S.provider then return nil,'shared sky requires authority contact'end
  local row=near(x,y,opts and opts.radius or 12,nil,nil,true);if not row then return nil,'no nearby bold flyer'end
  S.summonSerial=(S.summonSerial or 0)+1;row.summon={id='summon3_'..S.summonSerial,x=x*16,y=y*16,left=4};return row.summon.id
 end
 mod.exports.registerSpriteSource=Art.register;mod.exports.unregisterSpriteSource=Art.unregister
 mod.exports.registerSharedSkyProvider=function(id,provider)
  if type(id)~='string'or type(provider)~='table'or type(provider.requestClaim)~='function'then return false,'provider id and requestClaim required'end
  S.providerId=id;S.provider=provider;S.pending=nil
  if not liveAuthority()then S.fields={}end
  return true
 end
 mod.exports.clearSharedSkyField=function()S.fields={};S.pending=nil;S.sharedBattle=nil;return true end
 mod.exports.unregisterSharedSkyProvider=function(id)
  if id~=S.providerId then return false end
  S.provider=nil;S.providerId=nil;return mod.exports.clearSharedSkyField()
 end
 mod.exports.sharedSkyNeighborMaps=function()
  local out={};for _,entry in ipairs(Map.world or{})do if entry.id~=Map.current then out[#out+1]=entry.id end end;table.sort(out);return out
 end
 mod.exports.sharedSkyFieldSnapshot=function(map)
  local f=field(map);if not f then return end
  if liveAuthority()then populate(f,true)end
  local out={domain='SKY',map=map,revision=S.revision,localAuthority=liveAuthority(),spawns={}}
  for _,r in pairs(f.rows)do if not r.summon then out.spawns[#out.spawns+1]={id=r.id,map=map,species=E.key(r.species),level=r.level,
   x=r.px,y=r.py,alt=r.alt,vx=r.vx or 0,vy=r.vy or 0,facing=r.facing,mode=r.mode,bold=r.bold}end end
  table.sort(out.spawns,function(a,b)return a.id<b.id end);return out
 end
 mod.exports.applySharedSkyFieldSnapshot=function(snapshot)
  if not S.provider or type(snapshot)~='table'or snapshot.domain~='SKY'or type(snapshot.map)~='string'or type(snapshot.spawns)~='table'or #snapshot.spawns>32 then return false,'invalid SKY snapshot'end
  local f=field(snapshot.map);if not f then return false,'unsupported native map'end
  if not finite(snapshot.revision)or snapshot.revision<0 then return false,'invalid revision'end
  if f.revision and snapshot.revision<f.revision then return false,'stale snapshot'end
  local rows={}
  for _,wire in ipairs(snapshot.spawns)do
   if type(wire.id)~='string'or #wire.id==0 or #wire.id>96 or rows[wire.id]or not E.species(wire.species)
    or not finite(wire.x)or not finite(wire.y)or not finite(wire.alt)or wire.alt<0 or wire.alt>1024
    or not finite(wire.level)or wire.level<1 or wire.level>100 or wire.level%1~=0
    or wire.vx and(not finite(wire.vx)or math.abs(wire.vx)>256)or wire.vy and(not finite(wire.vy)or math.abs(wire.vy)>256)
    or not({roam=true,ground=true,rise=true,toLand=true,leave=true})[wire.mode or'roam']then return false,'invalid SKY row'end
   local old=f.rows[wire.id]
   local r={id=wire.id,map=f.map,t=1,heading=0,speed=32,altTarget=wire.alt,life=40,flock=wire.id,passable=true,visible=true,wildSkiesFlyer=true,stepFrames=16}
   if old then for k,v in pairs(old)do r[k]=v end end
   r.def={elevation=0}
   r.species=E.species(wire.species)
   r.px,r.py,r.alt=wire.x,wire.y,wire.alt;r.cellX=math.floor((r.px+8)/16);r.cellY=math.floor((r.py+8)/16)
   r.vx,r.vy=wire.vx or 0,wire.vy or 0;r.facing=wire.facing or'right';r.level=wire.level;r.bold=wire.bold==true;r.mode=wire.mode or'roam'
   if not r.localId then S.serial=S.serial+1;r.localId=740000+S.serial end
   r.graphicsId=Art.sprite(r.species,game(),0);r.def.graphicsId=r.graphicsId;r.animClock=0;r.raiseY=-r.alt
   if not r.graphicsId then return false,'native sky art unavailable'end
   rows[r.id]=r
  end
  f.rows=rows;f.revision=snapshot.revision;return true
 end
 mod.exports.removeSharedSkyFieldSpawn=function(id)for _,f in pairs(S.fields)do f.rows[id]=nil end;return true end
 mod.exports.canClaimSky=function(position,row,context,map)
  if not position or not row or not row.bold or position.map~=map or not eligible(map)or eligible(map).town
   or not finite(position.x)or not finite(position.y)or not finite(row.x)or not finite(row.y)or not finite(row.alt)then return false end
  local dx,dy=math.abs(position.x-math.floor((row.x+8)/16)),math.abs(position.y-math.floor((row.y+8)/16))
  if dx+dy>1 then return false end
  if context and context.airborne then return type(position.altitude)=='number'and position.altitude>12 and math.abs(position.altitude-row.alt)<=20 end
  return option('bumps')==true and row.alt<=12
 end
 mod.exports.grantSharedSkyFieldContact=function(map,id,wire)
  local p=S.pending;if not p or p.map~=map or p.id~=id then return false end
  S.pending=nil;if Map.current~=map or busy()then return false end
  local row=p.row
  if wire then row.species=E.species(wire.species);row.level=wire.level;row.alt=wire.alt;if not row.species then return false end end
  local started
  if p.airborne then local ride=ex('DRAMATIC_SKY_RIDE')or ex('free_fly');if ride and ride.startSharedSkyEncounter then started=ride.startSharedSkyEncounter(hit(row))end end
  if not started then started=start(row,true)end
  if started then remove(row);S.rest=25;S.sharedBattle={map=map,id=id};return true end
  return false
 end
 mod.exports.denySharedSkyFieldContact=function(map,id)if S.pending and S.pending.map==map and S.pending.id==id then S.pending=nil;return true end;return false end
 local function face(r)
  r.facing=math.abs(r.vx)>math.abs(r.vy)and(r.vx<0 and'left'or'right')or(r.vy<0 and'up'or'down')
 end
 local function tick(f,r,dt)
  r.t=r.t+dt
  if S.provider and not liveAuthority()then
   r.px=r.px+(r.vx or 0)*dt;r.py=r.py+(r.vy or 0)*dt
  else
   local nearPlayer=f.map==Map.current and math.abs(r.cellX-Player.cellX)+math.abs(r.cellY-Player.cellY)<=2
   if r.summon then
    local q=r.summon;q.left=q.left-dt;local dx,dy=q.x-r.px,q.y-r.py
    if math.abs(dx)+math.abs(dy)<8 then remove(r);emit('flyer_summoned',{summonId=q.id,species=r.species,level=r.level,cellX=r.cellX,cellY=r.cellY});return end
    if q.left<=0 then emit('summon_failed',{summonId=q.id,reason='too slow'});r.summon=nil
    else r.heading=math.atan2(dy,dx);r.altTarget=8 end
   elseif r.mode=='ground'then
    r.groundLeft=(r.groundLeft or 6)-dt
    if nearPlayer or r.groundLeft<=0 then r.mode='rise';r.altTarget=love.math.random(28,76)else r.vx,r.vy=0,0;return end
   elseif r.mode=='toLand'then
    if not ground(f,r.cellX,r.cellY)or nearPlayer then r.mode='rise';r.altTarget=48
    elseif r.alt<=1 then r.mode='ground';r.alt=0;r.groundLeft=love.math.random(4,10);return end
   elseif r.mode=='rise'and r.alt>=r.altTarget-1 then r.mode='roam'
   elseif r.t>r.life then r.mode='leave'
   elseif love.math.random()<dt/9 and ground(f,r.cellX,r.cellY)then r.mode='toLand';r.altTarget=0
   elseif love.math.random()<dt/6 then r.altTarget=love.math.random()<.12 and 8 or love.math.random(28,76)end
   local old=r.heading
   if r.mode~='toLand'then
    r.heading=r.heading+(love.math.random()-.5)*2.5*dt
    if r.px<16 or r.px>f.w*16-16 or r.py<16 or r.py>f.h*16-16 then
     if r.mode=='leave'then remove(r);return end
     r.heading=math.atan2(f.h*8-r.py,f.w*8-r.px)
    end
    if not r.summon then for _,mate in pairs(f.rows)do if mate~=r and mate.flock==r.flock and math.abs(mate.px-r.px)+math.abs(mate.py-r.py)>48 then
     local want=math.atan2(mate.py-r.py,mate.px-r.px);local delta=(want-r.heading+math.pi)%(math.pi*2)-math.pi;r.heading=r.heading+math.max(-dt*.6,math.min(dt*.6,delta));break
    end end end
    r.vx,r.vy=math.cos(r.heading)*r.speed,math.sin(r.heading)*r.speed
    r.px=r.px+r.vx*dt;r.py=r.py+r.vy*dt
   else r.vx,r.vy=0,0 end
   local step=44*dt;r.alt=r.alt+math.max(-step,math.min(step,(r.altTarget or 48)-r.alt))
   r.bank=math.max(-2,math.min(2,math.floor((r.heading-old)/math.max(dt,.001)*2+.5)))
  end
  r.cellX=math.floor((r.px+8)/16);r.cellY=math.floor((r.py+8)/16);face(r)
 end
 function S.update(dt)
  dt=math.max(0,math.min(.1,dt or 1/60));S.time=S.time+dt;S.rest=math.max(0,S.rest-dt)
  if S.currentMap and S.currentMap~=Map.current then
   for _,f in pairs(S.fields)do for _,r in pairs(f.rows)do if r.summon then emit('summon_failed',{summonId=r.summon.id,reason='map changed'});r.summon=nil end end end
   S.menu=false
  end
  S.currentMap=Map.current
  if S.pending and S.pending.map~=Map.current then S.pending=nil end
  local current=field(Map.current)
  for _,entry in ipairs(Map.world or{})do field(entry.id)end
  if simulationBusy()then return end
  for _,f in pairs(S.fields)do
   f.cooldown=math.max(0,f.cooldown-dt);populate(f)
   local limit=(density[option('density')]or density.med)[1];local n=0
   for _,r in pairs(f.rows)do
    n=n+1;if liveAuthority()and n>limit then r.mode='leave';r.life=0 end
    tick(f,r,dt)
    r.animClock=option('motion')and r.t*60 or 0;r.moving=option('motion')==true
    r.raiseY=-r.alt-(option('motion')and math.sin(r.t*8)*2 or 0)
    r.graphicsId=Art.sprite(r.species,game(),r.bank);r.def.graphicsId=r.graphicsId
   end
  end
  S.revision=S.revision+1
  local used={};for _,f in pairs(S.fields)do for _,r in pairs(f.rows)do if r.graphicsId then used[r.graphicsId]=true end end end;Art.collect(used)
  if current and option('bumps')and S.rest<=0 then
   local ride=ex('DRAMATIC_SKY_RIDE');local flying=ride and ride.isFlying and ride.isFlying()
   if not flying then local row=near(Player.cellX,Player.cellY,0,0,12)
    if row then if S.provider then request(row,false)else start(row,false)end end
   end
  end
 end
 local previous=Objects.forDraw
 Objects.forDraw=function(...)
  local out=previous(...)
  if not eligible(Map.current)then return out end
  local offsets={[Map.current]={0,0}};for _,entry in ipairs(Map.world or{})do offsets[entry.id]={entry.ox or 0,entry.oy or 0}end
  for map,offset in pairs(offsets)do local f=S.fields[map];if f and eligible(map) then for _,r in pairs(f.rows)do if r.graphicsId then
   local view={};for k,v in pairs(r)do view[k]=v end
   view.px=r.px+offset[1]*16;view.py=r.py+offset[2]*16;view.cellX=r.cellX+offset[1];view.cellY=r.cellY+offset[2]
   out[#out+1]=view
   if r.alt>2 then local shadow={};for k,v in pairs(view)do shadow[k]=v end;shadow.graphicsId=Art.shadow();shadow.def={graphicsId=shadow.graphicsId,elevation=0};shadow.localId=(r.localId or 0)+100000;shadow.raiseY=0;shadow.moving=false;out[#out+1]=shadow end
  end end end end
  return out
 end
 local registered
 local function registerDoubles()
  local db=ex('double_battles');if not db or registered==db then return end
  if db.registerDoubleVeto then db.registerDoubleVeto({id='wild_skies_legendary',veto=function(_,b)return b and b.enemy and b.enemy.mon and E.legend(b.enemy.mon.species)end})end
  if db.registerPartnerSource then db.registerPartnerSource({id='wild_skies_flock',priority=45,provide=function(_,b)
   if not S.building or not S.lastBump or not b or b.generation~=3 or not b.enemy or b.enemy.mon.species~=S.lastBump.species then return end
   local mate=mod.exports.takeFlockmate(Player.cellX,Player.cellY,8,S.lastBump.alt,20);if mate then return mate.species,mate.level end
  end})end
  registered=db
 end
 mod.hooks:wrap('input.step',function(nextFn,g,dt)local result=nextFn(g,dt);registerDoubles();S.update(dt);return result end)
 mod.events:on('mod.options_changed',function(payload)if not payload or payload.mod==mod.id or payload.mod=='overworld_wild_spawns'then Art.invalidate()end end)
 mod.events:on('battle.started',function(ev)
  local lead=S.lastTaken
  local enemy=ev and ev.battle and ev.battle.enemy
  if not S.provider and lead and lead.map==Map.current and S.time-(S.lastTakenAt or-20)<12
   and enemy and enemy.mon and enemy.mon.species==lead.species and enemy.mon.level==lead.level then
   S.localBattle={lead=lead,mate=S.mate};S.lastTaken=nil;S.mate=nil
  end
 end)
 mod.events:on('battle.ended',function(ev)
  if S.sharedBattle or S.localBattle then S.rest=25 end
  if S.sharedBattle then
   local claim=S.sharedBattle;S.sharedBattle=nil
   if S.provider and S.provider.finishClaim then S.provider.finishClaim(claim.map,claim.id,{consumed=ev.result=='win'or ev.result=='catch'or ev.result=='caught',result=ev.result})end
  elseif S.localBattle then
   local battle=S.localBattle;S.localBattle=nil
   local second=ev.battle and((ev.battle.battlers and ev.battle.battlers[3])or ev.battle.enemy2)
   local function restore(row,mon)if row and(not mon or(mon.hp or 0)>0)then local f=field(row.map);if f then row.mode='rise';row.altTarget=48;row.t=1;f.rows[row.id]=row end end end
   if ev.result=='run'or ev.result=='lose'then restore(battle.lead,ev.battle and ev.battle.enemy and ev.battle.enemy.mon);restore(battle.mate,second and second.mon)
   elseif ev.result=='catch'or ev.result=='caught'then
    -- Doubles promotes the remaining foe into enemy for capture while keeping
    -- its original battler slot. That living mon is captured, not a survivor.
    local captured=ev.battle and ev.battle.enemy and ev.battle.enemy.mon
    if not second or second.mon~=captured then restore(battle.mate,second and second.mon)end
   end
  end
 end)
 mod.hooks:wrap('core.quit_to_launcher',function(nextFn,...)S.fields={};S.pending=nil;S.sharedBattle=nil;S.menu=false;Art.dispose();return nextFn(...)end)
 loadPart('lib/gen3/dex.lua')(mod,S,Art,E,Pokemon,busy)
 mod.exports.gen3=S;mod.exports.nativeSkyArt=Art;mod.exports.nativeSkyEcology=E
 return S
end
