-- Native species IDs and encounter tables; no Gen1 data or required companion.
return function(Pokemon,Encounters)
 local E={}
 local night={ZUBAT=true,GOLBAT=true,CROBAT=true,HOOTHOOT=true,NOCTOWL=true,MURKROW=true}
 local flightless={DODUO=true,DODRIO=true,NATU=true}
 local legends={ARTICUNO=true,ZAPDOS=true,MOLTRES=true}
 local bands={PIDGEOTTO={15,20},PIDGEOT={25,32},FEAROW={20,27},GOLBAT={22,26}}
 function E.key(species)return Pokemon.keyName and Pokemon.keyName(species)or tostring(Pokemon.name(species)):upper():gsub('[^A-Z0-9]','')end
 function E.species(species)
  local id=tonumber(species)or(Pokemon.speciesFromName and Pokemon.speciesFromName(species))
  if id and Pokemon.name(id)then return id end
 end
 function E.legend(species)return legends[E.key(species)]==true end
 function E.flying(species)
  if flightless[E.key(species)]then return false end
  for _,t in ipairs(Pokemon.types(species)or{})do if t==2 or t=='FLYING'then return true end end
  return false
 end
 function E.environment(map,def)
  if not def then return end
  -- Numeric native map types outrank the facade's town/environment labels.
  local mapType=tonumber(def.mapType)
  if mapType==8 or mapType==9 then return end
  local name=tostring(map):upper()
  local cave=mapType==4 or (not mapType and (name:find('CAVE',1,true)or name:find('MT_',1,true)or name:find('TUNNEL',1,true)or name:find('VICTORY_ROAD',1,true)))
  local town=def.kind=='town'or def.environment=='TOWN'or def.mapType==1 or def.mapType==2
  if not cave and not town and(def.kind=='indoor'or def.environment=='INDOOR'or def.mapType==8 or def.mapType==9)then return end
  local canopy=name:find('FOREST',1,true)~=nil
  return{cave=not not cave,town=not not town,canopy=canopy,open=not cave and not town and not canopy}
 end
 function E.pool(map,def,hour)
  local env=E.environment(map,def);if not env then return{},nil end
  local table_=Encounters.tableFor(map)or{}
  local nightTime=hour and(hour>=18 or hour<6)
  local pool,lo,hi={},100,1
  local land=table_.land or table_.grass or{}
  local slots=land.slots or land.mons or land
  for _,slot in ipairs(slots)do
   local species=E.species(slot.species or slot[1])
   local min=tonumber(slot.minLevel or slot.level or slot[2])or 5
   local max=tonumber(slot.maxLevel or slot.level or slot[3])or min
   lo=math.min(lo,min);hi=math.max(hi,max)
   if species and E.flying(species)and(not night[E.key(species)]or nightTime or env.cave)then
    pool[#pool+1]={species=species,lo=min,hi=max}
   end
  end
  if #pool==0 then
   local sea=not env.cave and table_.water and #slots==0
   local fallback=(env.cave or nightTime and not sea)
    and {'ZUBAT','ZUBAT','GOLBAT'}or sea and{'PIDGEOTTO','PIDGEOT','FEAROW','FEAROW'}
    or{'PIDGEY','PIDGEY','SPEAROW','PIDGEOTTO','FEAROW'}
   for _,name in ipairs(fallback)do
    local species=E.species(name)
    if species then local band=bands[name];pool[#pool+1]={species=species,lo=band and band[1]or(lo==100 and 3 or lo),hi=band and band[2]or(hi==1 and 8 or hi)}end
   end
  end
  return pool,env
 end
 function E.pick(pool,env,random)
  random=random or math.random
  if env and env.open and random(1,1000)==1 then
   local id=E.species(({'ARTICUNO','ZAPDOS','MOLTRES'})[random(1,3)])
   if id then return id,random(48,52),true end
  end
  if #pool==0 then return end
  local slot=pool[random(1,#pool)]
  return slot.species,random(slot.lo,math.max(slot.lo,slot.hi)),false
 end
 return E
end
