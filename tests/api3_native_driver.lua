return function(game)
 local function wait(n)for _=1,n do coroutine.yield()end end
 local V=require('src.core.GameVersion');local gen=V.generation();local ver=V.get()
 assert(require('src.core.Version').modApi==3,'official API level')
 local Runtime=require('src.mods.Runtime')
 local function errors()for _,e in ipairs(Runtime.errors or{})do error('mod error: '..tostring(e))end end
 errors()
 local sky=game.mods.exports.wild_skies
 local ride=game.mods.exports.DRAMATIC_SKY_RIDE
 if os.getenv('QA_ONLY')=='wild_skies'then assert(sky and not ride,'standalone Skies')
 elseif os.getenv('QA_ONLY')=='DRAMATIC_SKY_RIDE'then assert(ride and not sky,'standalone Ride')
 else assert(sky and ride,'combined mods loaded')end
 if gen==3 then
  game:_handleBootAction({action='new_game',start={map=(ver=='firered'or ver=='leafgreen')and'FR_PALLET_TOWN'or(ver=='ruby'and'RU_LITTLEROOT_TOWN'or ver=='sapphire'and'SA_LITTLEROOT_TOWN'or'EM_LITTLEROOT_TOWN'),x=10,y=12,facing='down'}})
  local space=require('src.core.game3.scripting.space');local vm=space.getVm();if vm then vm:halt(true)end
  require('src.ui.game3.message').reset()
  local Party=require('src.core.game3.party');game.session.party={};assert(Party.giveMon(game.session,6,50))
  game.session.party[1].moves={19,57,33};game.session.party[1].pp={15,15,35}
  local opt=game.mods.modOptions.DRAMATIC_SKY_RIDE or{};game.mods.modOptions.DRAMATIC_SKY_RIDE=opt
  opt.badge_checks=false;opt.require_fly_move=false
  wait(35);errors()
  local S=ride and ride.gen3
  if ride then local ok,why=S.mount(1,'fly');assert(ok,why)
  wait(4);assert(ride.isMounted(),'native API3 flight active');assert(S.dismount(true))end
  if sky then assert(sky.openSkyDex(game),'public native sky dex');wait(2)
  Runtime.call('input.key',function()end,game,{phase='pressed',key='escape'})
  assert(not sky.gen3.menu,'dex closes')
  assert(sky.sharedSkyFieldSnapshot(require('src.core.game3.map').current),'native field snapshot')end
  if ride then local groundSource=os.getenv('QA_SOURCE')=='skies'
  if not groundSource then assert(S.mount(1,'fly'));wait(2)end
  local hit={species='PIDGEY',level=7,altitude=S.height}
  local doubleCase=os.getenv('QA_DOUBLES')
  local mateId
  if doubleCase then
   local db=assert(game.mods.exports.double_battles);assert(db.organicProtocol==1)
   game.mods.modOptions.double_battles=game.mods.modOptions.double_battles or{}
   game.mods.modOptions.double_battles.wild_doubles=doubleCase=='off'and'off'or'always'
   local P=require('src.core.game3.player');local map=require('src.core.game3.map').current
   local F=sky.gen3.fields[map];F.rows={};F.cooldown=999
   local leadId=assert(sky.spawnFlyer(16,7))
   if doubleCase~='nomate'then mateId=assert(sky.spawnFlyer(17,8))end
   for id,row in pairs(F.rows)do row.px=P.px+(id==leadId and 0 or 16);row.py=P.py;row.cellX=P.cellX+(id==leadId and 0 or 1);row.cellY=P.cellY;row.alt=groundSource and 0 or S.height;row.t=2;row.bold=true;row.flock='api3-native';row.mode='roam' end
   if not groundSource then hit=assert(sky.takeFlyer(P.cellX,P.cellY,0,S.height,20))end
  end
  local ok
  if groundSource then sky.gen3.rest=0;sky.gen3.update(0);ok=true else ok=ride.startSharedSkyEncounter(hit)end
  assert(ok,'API3 public canonical wild battle refused');wait(150)
  assert(require('src.core.game3.battle').isActive(),'public starter enters native battle');if not groundSource then assert(S.suspended and not ride.isMounted(),'public native battle lifecycle suspends flight')end
  if doubleCase then
   local double=require('src.core.game3.battle').getState().double==true
   assert(double==(doubleCase=='always'),'native source-only Doubles decision')
   if mateId then local map=require('src.core.game3.map').current;assert((sky.gen3.fields[map].rows[mateId]==nil)==(doubleCase=='always'),'flockmate consumed only after chance succeeds')end
   print('[PASS native organic source]',ver,groundSource and'skies'or'ride',doubleCase,double)
  end
  end
 else
  if gen==1 then game:startNewGame({intro=false});game.stack:top():enter('PALLET_TOWN',8,15,'down',{via='warp'})
  else game.stack:clear();assert(game:startWorld());assert(game.world:setMap('NEW_BARK_TOWN',9,7,'down'));game.phase='play' end
  local Mon=require(gen==2 and'src.battle.gen2.Mon'or'src.pokemon.Pokemon')
  local a=Mon.new(game.data,'ARCANINE',40);local b=Mon.new(game.data,'ARCANINE',40)
  game.save.party={a,b};wait(25);errors()
  if ride then local Party=require(gen==2 and'src.ui.gen2.PartyMenu'or'src.ui.PartyMenu')
  local menu=Party.new(game);game.stack:push(menu);menu.index=2
  local rows=Runtime.call('ui.party.submenu',function(_,items)return items end,game,{},b,{overworld=game.world or game.overworld})
  local action
  for _,row in ipairs(rows)do if row.label and row.label:find('RIDE')then action=row;break end end
  assert(action and action.onSelect,'API3 detached party exposes ground ride')
  action.onSelect(b,game);errors();assert(ride.isGroundRiding(),'API3 party action starts native ground ride')
  local pose=ride.networkPose();assert(pose and pose.mode=='ground','native mount pose')
  assert(ride.requestGroundDismount());wait(3)end
  if sky then local world=game.world or game.overworld
  local map=world.map.id
  assert(sky.registerSharedSkyProvider('api3-native',{role='guest',requestClaim=function()return true end}))
  local row={id='api3:duck',species=gen==2 and'FARFETCH_D'or'FARFETCHD',level=7,x=world.player.px,y=world.player.py,alt=0,vx=0,vy=0,bold=true,facing='down',mode='ground'}
  assert(sky.applySharedSkyFieldSnapshot({domain='SKY',map=map,revision=1,spawns={row},localAuthority=false}))
  for _,f in ipairs(world.entities)do if f.wildSkiesFlyer then f.t=2 end end
  local started=false;Runtime.events:on('battle.started',function()started=true end)
  local hit,status=sky.takeFlyer(world.player.cellX,world.player.cellY,1)
  assert(not hit and status=='pending','shared API3 claim requested')
  assert(sky.grantSharedSkyFieldContact(map,row.id,row),'canonical queueScript battle grant')
  wait(200);assert(started,'public canonical script enters native battle')end
 end
 errors();print('[PASS sky API3 native]',ver,'party/flight and field services')
 love.event.quit()
end
