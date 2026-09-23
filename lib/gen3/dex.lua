-- Native field overlay; the stock START item is only a launcher. The field
-- stays paused while browsing and no engine menu is replaced.
return function(mod,S,Art,E,Pokemon,busy)
 local Player=require('src.core.game3.player')
 local list={}
 for nat=1,386 do local id=Pokemon.speciesFromNational and Pokemon.speciesFromNational(nat)or nat;if Pokemon.name(id)then list[#list+1]=id end end
 local cursor=1
 mod.exports.openSkyDex=function(game)
  game=game or mod.world.game;if not game or game.phase~='field'or busy()then return false end
  S.menu=true;return true
 end
 mod.exports.skyDexLanes=function(_,species)return Art.lanes(species,mod.world.game)end
 local update=Player.update
 Player.update=function(...)if S.menu then return end;return update(...)end
 local function key(k)
  if k=='escape'or k=='x'or k=='b'then S.menu=false
  elseif k=='up'or k=='dpup'then cursor=(cursor-2)%math.max(1,#list)+1
  elseif k=='down'or k=='dpdown'then cursor=cursor%math.max(1,#list)+1
  elseif k=='left'or k=='dpleft'then cursor=math.max(1,cursor-10)
  elseif k=='right'or k=='dpright'then cursor=math.min(#list,cursor+10)end
 end
 mod.hooks:wrap('ui.start_menu.items',function(nextFn,g,items)
  local out=nextFn(g,items);if type(out)=='table'then
   local at=#out+1;for i,r in ipairs(out)do if r.label=='QUIT'or r.label=='EXIT'then at=i;break end end
   table.insert(out,at,{label='SKY DEX',onSelect=function()require('src.ui.game3.start_menu').close();mod.exports.openSkyDex(g)end})
  end;return out
 end)
 mod.hooks:wrap('input.key',function(nextFn,g,event)
  if S.menu then
   if event and event.phase=='pressed'then key(event.key)end
   return
  end
  return nextFn(g,event)
 end)
 mod.hooks:wrap('input.gamepad',function(nextFn,g,event)
  if S.menu then if event and event.phase=='pressed'then key(event.button)end;return end
  return nextFn(g,event)
 end)
 mod.hooks:wrap('input.step',function(nextFn,g,dt)
  if not g or g.phase~='field'then S.menu=false end
  if S.menu and g.input and g.input.clearEdges then g.input:clearEdges()end
  return nextFn(g,dt)
 end)
 local font
 mod.hooks:wrap('render.hud',function(nextFn,g,v)
  nextFn(g,v);if not S.menu or not g or g.phase~='field'then return end
  font=font or love.graphics.newFont(16);love.graphics.push('all');love.graphics.setFont(font)
  local w,h=math.min(v.width-24,540),math.min(v.height-24,340);local x,y=(v.width-w)/2,(v.height-h)/2
  love.graphics.setColor(.055,.09,.14,.98);love.graphics.rectangle('fill',x,y,w,h,8)
  love.graphics.setColor(1,1,1,1);love.graphics.print('SKY DEX',x+18,y+14)
  local species=list[cursor]
  if species then
   love.graphics.print(('%03d  %s'):format(Pokemon.national(species),Pokemon.name(species)),x+18,y+49)
   love.graphics.print(E.flying(species)and'FLYING ECOLOGY'or'SCENARIO PREVIEW',x+18,y+74)
   local lanes=Art.lanes(species,g)
   for i,lane in ipairs(lanes)do
    local lx=x+28+(i-1)*(w-40)/3;love.graphics.print(lane.label,lx,y+113)
    local spr=lane.sprite
    if spr then local scale=math.min(2.5,(w-60)/3/spr.width,100/spr.height);love.graphics.draw(spr.image,spr.quads[0],lx,y+145,0,scale,scale)end
   end
  end
  love.graphics.printf('UP / DOWN: species   LEFT / RIGHT: page\nESC / B: close',x+18,y+h-54,w-36)
  love.graphics.pop()
 end)
end
