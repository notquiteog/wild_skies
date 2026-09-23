-- Native sprite registry. Every source is optional; imported species icons and
-- portraits keep a standalone installation complete without bundled ROM art.
return function(mod,Pokemon,Sprites)
 local A={sprites={},sources={},serial=740000,revision=0}
 local cache,base={},{}
 local previous=Sprites.getDraw
 Sprites.getDraw=function(id)return A.sprites[id]or previous(id)end
 local function register(image,w,h,count)
  A.serial=A.serial+1;local quads={};local iw,ih=image:getDimensions()
  for i=0,count-1 do quads[i]=love.graphics.newQuad(0,i*h,w,h,iw,ih)end
  A.sprites[A.serial]={image=image,width=w,height=h,quads=quads,frameCount=count,inanimate=count==1,generation=A.revision}
  return A.serial
 end
 local function imageSource(def)
  if type(def)=='number'then return Sprites.getDraw(def)end
  if type(def)~='table'then return end
  if def.graphicsId then return Sprites.getDraw(def.graphicsId)end
  if def.quads and def.image then return def end
  if not def.image then return end
  local img=type(def.image)=='string'and love.graphics.newImage(def.image)or def.image
  local iw,ih=img:getDimensions();local w,h=def.frameWidth or iw,def.frameHeight or iw
  if w<=0 or h<=0 or w>iw or h>ih then return end
  local count=math.min(tonumber(def.frames)or math.floor(ih/h),math.floor(ih/h))
  if count<1 then return end
  local quads={};for i=0,count-1 do quads[i]=love.graphics.newQuad(0,i*h,w,h,iw,ih)end
  return{image=img,quads=quads,width=w,height=h,frameCount=count}
 end
 function A.invalidate()cache={};base={};A.revision=A.revision+1 end
 function A.collect(used)
  for id,spr in pairs(A.sprites)do
   if id~=A.shadowId and spr.generation<A.revision and not used[id]then
    if spr.image.release then spr.image:release()end;A.sprites[id]=nil
   end
  end
 end
 function A.dispose()
  for _,spr in pairs(A.sprites)do if spr.image.release then spr.image:release()end end
  A.sprites={};A.shadowId=nil;A.invalidate()
 end
 local function begin(canvas)
  love.graphics.push('all');love.graphics.origin();love.graphics.setShader();love.graphics.setScissor()
  love.graphics.setBlendMode('alpha','alphamultiply');love.graphics.setCanvas(canvas);love.graphics.clear(0,0,0,0)
 end
 function A.register(source)
  if type(source)~='table'or type(source.resolve)~='function'or not(source.id or source.mod)then return false,'source needs id and resolve'end
  A.unregister(source.id or source.mod);table.insert(A.sources,1,source);A.invalidate();return true
 end
 function A.unregister(id)
  for i,s in ipairs(A.sources)do if(s.id or s.mod)==id then table.remove(A.sources,i);A.invalidate();return true end end
  return false
 end
 local function source(species,style,game)
  local key=species..':'..style
  if base[key]then return base[key]end
  local spr
  if style=='auto'then
   for _,s in ipairs(A.sources)do
    local other=s.mod and mod.find and mod.find(s.mod);local exports=other and other.exports
    if not s.mod or exports then
     local ok,res=pcall(s.resolve,exports,game,species,Pokemon.national(species))
     if ok then local loaded;loaded,spr=pcall(imageSource,res);if loaded and spr then break end;spr=nil end
    end
   end
   if not spr and style=='auto'then
    local other=mod.find and mod.find('overworld_wild_spawns');local ex=other and other.exports
    if ex and ex.resolveGen3Sprite then local ok,gid=pcall(ex.resolveGen3Sprite,species);if ok then spr=Sprites.getDraw(gid)end end
   end
  end
  if not spr then
   local pic=style=='portrait'and Pokemon.frontPic(species)or Pokemon.icon(species)
   if not pic then pic=Pokemon.frontPic(species)end
   if pic then
    local iw,ih=pic.image:getDimensions();local w,h=pic.w or pic.width or iw,pic.h or pic.height or math.min(iw,ih)
    local count=math.max(1,math.floor(ih/h));local quads={}
    for i=0,count-1 do quads[i]=love.graphics.newQuad(0,i*h,w,h,iw,ih)end
    spr={image=pic.image,quads=quads,width=w,height=h,frameCount=count}
   end
  end
  base[key]=spr;return spr
 end
 function A.sprite(species,game,bank)
  local style=mod.options:get('skyart')or'auto'
  local size=mod.options:get('size')or'normal'
  bank=mod.options:get('motion')and(bank or 0)or 0
  local key=species..':'..style..':'..size..':'..bank..':'..A.revision
  if cache[key]then return cache[key]end
  local spr=source(species,style,game);if not spr then return end
  local dex=Pokemon.dexEntry and Pokemon.dexEntry(species)
  local height=tonumber(dex and dex.height)or 10
  local scale=math.max(.75,math.min(1.8,math.sqrt(height/10)))
   *(({small=.7,normal=1,large=1.3,huge=1.6})[size]or 1)
  local target=24*scale;local k=target/math.max(spr.width,spr.height)
  local box=math.ceil(target*1.3+4);local canvas=love.graphics.newCanvas(box,box*9)
  begin(canvas);love.graphics.setColor(1,1,1,1)
  for i=0,8 do
   local frame=spr.frameCount>=9 and i or i%spr.frameCount
   local q=spr.quads[frame]or spr.quads[0]
   love.graphics.setScissor(0,i*box,box,box)
   love.graphics.draw(spr.image,q,box/2,(i+1)*box-2,bank*.08,k,k,spr.width/2,spr.height)
  end
  love.graphics.pop();canvas:setFilter('nearest','nearest')
  cache[key]=register(canvas,box,box,9);return cache[key]
 end
 function A.shadow()
  if A.shadowId then return A.shadowId end
  local c=love.graphics.newCanvas(18,8);begin(c)
  love.graphics.setColor(0,0,0,.2);love.graphics.ellipse('fill',9,5,7,2);love.graphics.pop()
  A.shadowId=register(c,18,8,1);return A.shadowId
 end
 function A.lanes(species,game)
  local rows={};for _,style in ipairs({'auto','portrait','classic'})do rows[#rows+1]={label=style:upper(),sprite=source(species,style,game)}end;return rows
 end
 return A
end
