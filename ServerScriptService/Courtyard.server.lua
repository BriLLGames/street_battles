-- Courtyard v1.3 (день/ночь, мягкие окна, мелкие детали; база — v1.2): мрачная карта — v0.8 + футбольное поле (СВ) + гаражи (СЗ) + периметр из 9-12-этажек + мрачная атмосфера и детали. Процедурная геометрия, без внешних ассетов.
local Lighting=game:GetService('Lighting')
local rng=Random.new(1984)
local rad=math.rad
local function fresh(class,name)
 local o=Lighting:FindFirstChild(name);if o then o:Destroy() end
 o=Instance.new(class);o.Name=name;o.Parent=Lighting;return o
end
local RS=game:GetService('ReplicatedStorage')
local DN=require(RS:WaitForChild('DayNight')) -- смена дня и ночи, настройки в ReplicatedStorage/DayNight
workspace:SetAttribute('DN_T0',workspace:GetServerTimeNow()) -- точка отсчёта времени суток для всех игроков
Lighting.GlobalShadows=true;Lighting.ShadowSoftness=.3
Lighting.EnvironmentDiffuseScale=.7;Lighting.EnvironmentSpecularScale=.5
local atm=fresh('Atmosphere','StreetAtmosphere');atm.Offset=.1;atm.Glare=0
local bloom=fresh('BloomEffect','StreetBloom');bloom.Size=16;bloom.Threshold=1.1
local cc=fresh('ColorCorrectionEffect','StreetColor')
local sky=Lighting:FindFirstChildOfClass('Sky');if not sky then sky=Instance.new('Sky');sky.Parent=Lighting end
sky.StarCount=2500;sky.SunAngularSize=13;sky.MoonAngularSize=10 -- маленькое солнце не слепит
local oldRays=Lighting:FindFirstChild('StreetRays');if oldRays then oldRays:Destroy() end
local tr=workspace.Terrain;local clouds=tr:FindFirstChildOfClass('Clouds');if not clouds then clouds=Instance.new('Clouds');clouds.Parent=tr end
clouds.Cover=.88;clouds.Density=.75
DN.apply(DN.hour()) -- начальное освещение; дальше плавно ведёт клиент (DayNight.client)

local old=workspace:FindFirstChild('StreetCourtyard');if old then old:Destroy() end
local w=Instance.new('Folder');w.Name='StreetCourtyard';w.Parent=workspace
local M=Enum.Material
local function C3(r,g,b) return Color3.fromRGB(r,g,b) end
local function part(name,size,cf,color,mat,parent)
 local o=Instance.new('Part');o.Name=name;o.Size=size;o.CFrame=typeof(cf)=='CFrame' and cf or CFrame.new(cf);o.Color=color;o.Material=mat or M.Concrete;o.Anchored=true
 o.TopSurface=Enum.SurfaceType.Smooth;o.BottomSurface=Enum.SurfaceType.Smooth
 if math.max(size.X,size.Y,size.Z)<7 then o.CastShadow=false end
 o.Parent=parent or w;return o
end
local function cyl(name,diam,height,pos,color,mat,parent) -- вертикальный цилиндр
 local o=part(name,Vector3.new(height,diam,diam),CFrame.new(pos)*CFrame.Angles(0,0,rad(90)),color,mat,parent);o.Shape=Enum.PartType.Cylinder;return o
end
local function ball(name,d,pos,color,mat,parent)
 local o=part(name,Vector3.new(d,d,d),pos,color,mat,parent);o.Shape=Enum.PartType.Ball;o.CanCollide=false;return o
end

-- ===== Смена дня и ночи: списки окон и фонарей (переключаются внизу файла) =====
local windows,lamps={},{}
local wrng=Random.new(555)  -- отдельный генератор, чтобы не сдвигать остальную карту
local drng=Random.new(31337)
local function dimc(c) local k=DN.WindowGlow;return Color3.new(c.R*k,c.G*k,c.B*k) end
local WIN_OFF=C3(58,78,90)
local WIN_WARM,WIN_COOL,WIN_TV=dimc(C3(236,208,140)),dimc(C3(214,222,224)),dimc(C3(120,160,235))
local function regLamp(p,light,offC,offMat) -- цвет/материал/свет на момент вызова = «включено»
 local l={p=p,light=light,onC=p.Color,onMat=p.Material,offC=offC,offMat=offMat or M.Metal,base=light and light.Brightness or 0,last=-1,flickOn=true}
 lamps[#lamps+1]=l;return l
end
local function setLamp(l,level)
 l.last=level
 local on=l.flickOn and level or 0
 l.p.Color=l.offC:Lerp(l.onC,on)
 l.p.Material=(on>.3) and l.onMat or l.offMat
 if l.light then l.light.Brightness=l.base*on;l.light.Enabled=on>.02 end
end
local function updateLamps(level)
 for _,l in ipairs(lamps) do
  if math.abs(level-l.last)>=.04 or (level~=l.last and (level==0 or level==1)) then setLamp(l,level) end
 end
end
local function updateWindows(h)
 local hh=h<12 and h+24 or h
 for _,win in ipairs(windows) do
  local on=hh>=win.on and hh<=win.off
  if on~=win.state then
   win.state=on
   local pr=win.p
   if on then pr.Color=win.c;pr.Material=M.Neon;pr.Reflectance=0 else pr.Color=WIN_OFF;pr.Material=M.SmoothPlastic;pr.Reflectance=.1 end
  end
 end
end

-- ===== Земля =====
local asphalt=C3(52,55,56);local concrete=C3(148,145,137)
part('Асфальт',Vector3.new(720,2,720),Vector3.new(0,-1,0),asphalt,M.Asphalt)
for _,z in ipairs({-225,225}) do part('Тротуар поперечный',Vector3.new(565,.25,14),Vector3.new(0,.14,z),concrete) end
for _,x in ipairs({-225,225}) do part('Тротуар продольный',Vector3.new(14,.25,565),Vector3.new(x,.14,0),concrete) end
for _,z in ipairs({-80,80}) do part('Дорожка',Vector3.new(455,.18,9),Vector3.new(0,.12,z),C3(119,116,108),M.Pavement) end
for _,x in ipairs({-90,90}) do part('Дорожка',Vector3.new(9,.18,440),Vector3.new(x,.12,0),C3(119,116,108),M.Pavement) end
-- газоны
for _,l in ipairs({{-185,0,36,150},{185,0,36,150},{0,-185,150,36},{0,185,150,36}}) do
 part('Газон',Vector3.new(l[3],.16,l[4]),Vector3.new(l[1],.08,l[2]),C3(58,78,52),M.Grass)
 part('Газон бордюр',Vector3.new(l[3]+1.2,.3,l[4]+1.2),Vector3.new(l[1],.05,l[2]),C3(160,157,148))
end
-- заплатки асфальта, люки, разметка
for i=1,30 do
 local x,z=rng:NextNumber(-290,290),rng:NextNumber(-290,290)
 if math.sqrt(x*x+z*z)>45 then
  part('Заплатка',Vector3.new(rng:NextNumber(3,9),.04,rng:NextNumber(2,7)),CFrame.new(x,.03,z)*CFrame.Angles(0,rng:NextNumber(0,3),0),C3(58+rng:NextInteger(0,12),60+rng:NextInteger(0,12),61+rng:NextInteger(0,12)),M.Asphalt).CanCollide=false
 end
end
for _,v in ipairs({{-40,-110},{40,110},{-150,40},{150,-40},{110,-200},{-110,200}}) do
 cyl('Люк',3.4,.12,Vector3.new(v[1],.1,v[2]),C3(52,54,56),M.Metal).CanCollide=false
end
for i=-3,3 do part('Разметка парковки',Vector3.new(.35,.05,9),Vector3.new(i*8-100,.04,-212),C3(224,224,215),M.SmoothPlastic).CanCollide=false end
for i=-3,3 do part('Разметка парковки',Vector3.new(.35,.05,9),Vector3.new(i*8+100,.04,212),C3(224,224,215),M.SmoothPlastic).CanCollide=false end

-- ===== Центральная площадь + лидерборды =====
cyl('Площадь основание',84,.5,Vector3.new(0,.15,0),C3(103,101,96),M.Concrete)
cyl('Площадь',78,.6,Vector3.new(0,.22,0),C3(172,169,160),M.Pavement)
cyl('Площадь кольцо',62,.7,Vector3.new(0,.24,0),C3(143,140,132),M.Slate)
cyl('Площадь центр',58,.8,Vector3.new(0,.26,0),C3(176,173,164),M.Pavement)
for i=0,15 do -- декоративные плиты-лучи
 part('Луч',Vector3.new(1,.05,26),CFrame.new(0,.7,0)*CFrame.Angles(0,rad(i*11.25),0),C3(150,147,138),M.Slate).CanCollide=false
end
local boards=Instance.new('Model');boards.Name='Leaderboards';boards.Parent=w
local function board(name,x,title,kind,accent)
 local m=Instance.new('Model');m.Name=name;m.Parent=boards
 part('Основание',Vector3.new(24,.7,4),Vector3.new(x,.75,0),C3(55,57,60),M.Concrete,m)
 for _,dx in ipairs({-8,8}) do part('Опора',Vector3.new(1.4,3.4,1.4),Vector3.new(x+dx,2.5,0),C3(40,42,45),M.Metal,m) end
 part('Рама',Vector3.new(21.8,17.8,.6),Vector3.new(x,12,0),C3(35,37,40),M.Metal,m)
 local screen=part('Экран',Vector3.new(20,16,.9),Vector3.new(x,12,0),C3(14,16,20),M.SmoothPlastic,m)
 screen:SetAttribute('Board',kind)
 local strip=part('Подсветка',Vector3.new(20,.35,.35),Vector3.new(x,21.2,0),accent,M.Neon,m);strip.CanCollide=false
 local lamp=Instance.new('PointLight');lamp.Color=accent;lamp.Range=26;lamp.Brightness=.9;lamp.Parent=strip
 for _,face in ipairs({Enum.NormalId.Front,Enum.NormalId.Back}) do
  local gui=Instance.new('SurfaceGui');gui.Face=face;gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud;gui.PixelsPerStud=50;gui.LightInfluence=0;gui.Brightness=1.3;gui.Parent=screen
  local bg=Instance.new('Frame');bg.Size=UDim2.fromScale(1,1);bg.BackgroundColor3=C3(16,18,24);bg.BorderSizePixel=0;bg.Parent=gui
  local head=Instance.new('Frame');head.Size=UDim2.new(1,0,0,110);head.BackgroundColor3=accent;head.BorderSizePixel=0;head.Parent=bg
  local t=Instance.new('TextLabel');t.Size=UDim2.fromScale(1,1);t.BackgroundTransparency=1;t.Font=Enum.Font.GothamBlack;t.TextSize=62;t.TextColor3=C3(20,20,24);t.Text=title;t.Parent=head
  for i=1,10 do
   local row=Instance.new('Frame');row.Name='Row'..i;row.Position=UDim2.new(0,20,0,122+(i-1)*66);row.Size=UDim2.new(1,-40,0,60);row.BorderSizePixel=0
   row.BackgroundColor3=i%2==0 and C3(30,33,42) or C3(24,27,35);row.Parent=bg
   local rank=Instance.new('TextLabel');rank.Name='Rank';rank.Size=UDim2.new(0,90,1,0);rank.BackgroundTransparency=1;rank.Font=Enum.Font.GothamBlack;rank.TextSize=40
   rank.TextColor3=(i==1 and C3(255,205,60)) or (i==2 and C3(205,210,220)) or (i==3 and C3(214,140,80)) or C3(150,155,170);rank.Text='#'..i;rank.Parent=row
   local nm=Instance.new('TextLabel');nm.Name='PlayerName';nm.Position=UDim2.new(0,95,0,0);nm.Size=UDim2.new(0,520,1,0);nm.BackgroundTransparency=1;nm.Font=Enum.Font.GothamBold;nm.TextSize=36
   nm.TextXAlignment=Enum.TextXAlignment.Left;nm.TextColor3=C3(240,242,248);nm.Text='—';nm.Parent=row
   local val=Instance.new('TextLabel');val.Name='Score';val.Position=UDim2.new(0,620,0,0);val.Size=UDim2.new(0,300,1,0);val.BackgroundTransparency=1;val.Font=Enum.Font.GothamBlack;val.TextSize=36
   val.TextXAlignment=Enum.TextXAlignment.Right;val.TextColor3=accent;val.Text='';val.Parent=row
  end
 end
end
board('Лидерборд убийств',-16,'ТОП УБИЙСТВ','Kills',C3(255,96,72))
board('Лидерборд времени',16,'ТОП ПО ВРЕМЕНИ','Time',C3(86,196,255))
for _,v in ipairs({{-30,-14},{30,-14},{-30,14},{30,14}}) do -- клумбы-ограждения площади
 part('Тумба',Vector3.new(4,1.6,4),Vector3.new(v[1],1.1,v[2]),C3(110,108,102),M.Concrete)
 ball('Куст',3.4,Vector3.new(v[1],3,v[2]),C3(70,112,62),M.Grass)
end

-- ===== Дома =====
-- building(x,z,rot,idx,F,W,lite): F этажей, W ширина. lite=true — высотка периметра (окна только с внутренней стороны, меньше деталей)
local palettes={C3(112,106,96),C3(124,118,104),C3(102,108,104),C3(118,114,108)}
local curtains={C3(196,170,120),C3(160,92,88),C3(110,140,160),C3(215,205,180)}
local function building(x,z,rot,idx,F,W,lite)
 F=F or 5;W=W or 73
 local H=5+F*8.4
 local model=Instance.new('Model');model.Name=(lite and 'Высотка ' or 'Хрущёвка ')..idx;model.Parent=w
 local cf=CFrame.new(x,0,z)*CFrame.Angles(0,rad(rot),0)
 local function block(n,size,offset,col,mat)
  return part(n,size,cf*CFrame.new(offset),col,mat,model)
 end
 local sides=lite and {1} or {-1,1}
 local pal=palettes[idx%#palettes+1]
 block('Фасад',Vector3.new(W,H,24),Vector3.new(0,H/2,0),pal)
 block('Крыша',Vector3.new(W+3,1.5,27),Vector3.new(0,H+.5,0),C3(77,79,78))
 block('Цоколь',Vector3.new(W+1,2.6,25),Vector3.new(0,1.3,0),C3(103,105,102))
 for _,pz in ipairs({-13.3,13.3}) do block('Парапет',Vector3.new(W+3,1.9,.5),Vector3.new(0,H+1.4,pz),C3(98,100,98)) end
 for _,sx in ipairs({-(W/2+1.2),W/2+1.2}) do block('Парапет',Vector3.new(.5,1.9,27),Vector3.new(sx,H+1.4,0),C3(98,100,98)) end
 for f=1,(lite and 0 or F-1) do for _,side in ipairs(sides) do block('Карниз',Vector3.new(W+.6,.5,.5),Vector3.new(0,f*8.4+2.2,side*12.2),C3(205,201,188)) end end
 local sp=lite and 9.4 or 7.3
 local gw=lite and 4.6 or 3.4
 local n=math.max(1,math.floor((W-6)/sp))
 for i=1,n do
  local wx=(i-(n+1)/2)*sp
  local col=math.floor(i-(n+1)/2+.5)
  for floor=1,F do
   local y=4.5+(floor-1)*8.4
   for _,side in ipairs(sides) do
    local zz=side*12.15
    local lit=rng:NextNumber()<.22
    local glass=block('Окно',Vector3.new(gw,4.1,.15),Vector3.new(wx,y+2,zz),WIN_OFF,M.SmoothPlastic)
    glass.Reflectance=.1
    glass.CanCollide=false
    if lit then -- окно загорается вечером в своё время и гаснет ночью/под утро
     local k=wrng:NextNumber()
     windows[#windows+1]={p=glass,on=17.8+wrng:NextNumber()*2.8,off=23+wrng:NextNumber()*6.7,c=(k<.12 and WIN_TV) or (k<.3 and WIN_COOL) or WIN_WARM,state=false}
    end
    if not lite then
     if rng:NextNumber()<.15 then block('Штора',Vector3.new(1.5,3.2,.1),Vector3.new(wx+(rng:NextNumber()<.5 and -.9 or .9),y+2.2,zz+side*.1),curtains[rng:NextInteger(1,#curtains)],M.Fabric).CanCollide=false end
    end
    if not lite then block('Подоконник',Vector3.new(4,.23,.65),Vector3.new(wx,y-.13,zz+side*.3),C3(150,148,140)) end
    if (not lite) and rng:NextNumber()<.07 then
     for _,by in ipairs({1.1,2.9}) do block('Доска',Vector3.new(4.3,.55,.3),Vector3.new(wx,y+by,zz+side*.25),C3(72,54,38),M.Wood).CanCollide=false end
    end
    if col%3==0 and floor>1 and ((not lite) or floor%2==0) then
     block('Балкон плита',Vector3.new(5,.35,2.6),Vector3.new(wx,y-.25,zz+side*1.1),C3(112,115,114))
     if not lite then block('Балкон ограда',Vector3.new(5,2,.2),Vector3.new(wx,y+1,zz+side*2.35),C3(105,113,113),M.Metal) end
    end
   end
  end
 end
 local doors=W>=66 and {-23,0,23} or {-18,18}
 for _,dx in ipairs(doors) do
  block('Подъезд дверь',Vector3.new(4.5,6,.3),Vector3.new(dx,3.6,12.3),C3(71,88,85),M.Metal)
  block('Подъезд рама',Vector3.new(5.3,.4,.5),Vector3.new(dx,6.8,12.3),C3(190,188,178))
  block('Козырёк',Vector3.new(7,.35,4),Vector3.new(dx,7.4,13.9),C3(93,98,95))
  block('Ступень',Vector3.new(5,.4,2),Vector3.new(dx,.4,14),C3(134,132,125))
  local lamp=block('Лампа подъезда',Vector3.new(.9,.3,.9),Vector3.new(dx,7.1,13.9),C3(232,192,132),M.Neon);lamp.CanCollide=false;regLamp(lamp,nil,C3(92,86,74),M.SmoothPlastic)
 end
 if not lite then
  local tags={'ДВОР','НЕ ЛЕЗЬ','ТУТ БЫЛ ВАСЯ','ЦСКА','СЕРЁГА+ЛЕНКА','РАЙОН','НЕ ВЕРЬ'}
  local cols={C3(200,50,44),C3(230,230,220),C3(30,30,32),C3(60,120,200)}
  for _,gx in ipairs({-11.5,11.5}) do
   if rng:NextNumber()<.6 then
    local gp=block('Граффити',Vector3.new(9,1.7,.05),Vector3.new(gx,3.3,12.08),C3(255,255,255),M.SmoothPlastic);gp.Transparency=1;gp.CanCollide=false
    local gui=Instance.new('SurfaceGui');gui.Face=Enum.NormalId.Front;gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud;gui.PixelsPerStud=40;gui.LightInfluence=1;gui.Parent=gp
    local t=Instance.new('TextLabel');t.Size=UDim2.fromScale(1,1);t.BackgroundTransparency=1;t.Font=Enum.Font.PermanentMarker;t.TextScaled=true;t.TextColor3=cols[rng:NextInteger(1,#cols)];t.Text=tags[rng:NextInteger(1,#tags)];t.Rotation=rng:NextInteger(-7,7);t.Parent=gui
   end
  end
 end
 for _,dx in ipairs({-(W/2-.5),W/2-.5}) do block('Водосток',Vector3.new(.5,H,.5),Vector3.new(dx,H/2,12.4),C3(95,98,96),M.Metal).CanCollide=false end
 -- спутниковые тарелки на стенах хрущёвок
 if not lite then
  for _=1,4 do
   local side=sides[drng:NextInteger(1,#sides)]
   local ci=drng:NextInteger(1,n-1);local wx=(ci-(n+1)/2)*sp+sp/2
   local fl=drng:NextInteger(2,F)
   local y=4.5+(fl-1)*8.4+2.6;local zz=side*12.15
   part('Тарелка кронштейн',Vector3.new(.2,.2,1.2),cf*CFrame.new(wx,y,zz+side*.6),C3(120,120,118),M.Metal,model).CanCollide=false
   local dish=part('Тарелка',Vector3.new(.3,1.9,1.9),cf*CFrame.new(wx,y+.1,zz+side*1.3)*CFrame.Angles(0,rad(90),rad(-12)),C3(214,212,204),M.Metal,model)
   dish.Shape=Enum.PartType.Cylinder;dish.CanCollide=false
  end
 end
 -- крыша
 block('Вентблок',Vector3.new(6,3,5),Vector3.new(rng:NextInteger(-24,-10),H+2.8,rng:NextInteger(-3,3)),C3(120,122,120),M.Concrete)
 local tx=rng:NextInteger(8,26)
 block('Бак',Vector3.new(5,5,5),Vector3.new(tx,H+4,0),C3(100,110,108),M.Metal).Shape=Enum.PartType.Cylinder
 block('Антенна',Vector3.new(.25,9,.25),Vector3.new(rng:NextInteger(-5,5),H+6,-3),C3(160,160,160),M.Metal)
 block('Антенна перекладина',Vector3.new(4,.2,.2),Vector3.new(0,H+8,-3),C3(160,160,160),M.Metal)
end
-- старые 5-этажки из v0.8 (внутри карты)
local placements={{-255,-200,0},{-130,-275,0},{130,-275,0},{255,-200,90},{255,-45,90},{255,130,90},{130,275,180},{-130,275,180},{-255,155,90},{-255,-35,90},{0,-250,0},{0,250,180}}
for i,b in ipairs(placements) do building(b[1],b[2],b[3],i) end
-- ПЕРИМЕТР: сплошное кольцо 9- и 12-этажек, фасады на линии ±304, зазоров нет — выпасть из карты нельзя
do
 local idx=100
 local function ringSide(count,len,shift,fn)
  local Wd=len/count
  for k=1,count do
   idx=idx+1
   local F=((k+shift)%2==0) and 12 or 9
   fn((k-.5)*Wd-len/2,Wd,F,idx)
  end
 end
 ringSide(9,660,0,function(c,Wd,F,id) building(c,-316,0,id,F,Wd,true) end)   -- север
 ringSide(9,660,1,function(c,Wd,F,id) building(c,316,180,id,F,Wd,true) end)  -- юг
 ringSide(8,608,0,function(c,Wd,F,id) building(316,c,270,id,F,Wd,true) end)  -- восток
 ringSide(8,608,1,function(c,Wd,F,id) building(-316,c,90,id,F,Wd,true) end)  -- запад
end

-- ===== Мелочи двора =====
local function bench(x,z,rot)
 local cf=CFrame.new(x,0,z)*CFrame.Angles(0,rad(rot),0)
 part('Скамейка сиденье',Vector3.new(10,.55,2.5),cf*CFrame.new(0,2,0),C3(117,76,49),M.Wood)
 part('Скамейка спинка',Vector3.new(10,2.4,.45),cf*CFrame.new(0,3.1,1.15),C3(117,76,49),M.Wood)
 for _,xx in ipairs({-4,4}) do part('Ножка',Vector3.new(.5,2,.5),cf*CFrame.new(xx,1,0),C3(61,65,66),M.Metal) end
end
for _,b in ipairs({{-42,-40,0},{42,-40,180},{-42,40,0},{42,40,180},{-160,80,90},{160,-80,90},{155,135,180},{-75,150,0},{60,-150,180}}) do bench(b[1],b[2],b[3]) end
local function tree(x,z,scale)
 cyl('Ствол',2*scale,13*scale,Vector3.new(x,6.5*scale,z),C3(91,72,54),M.Wood)
 for i=1,4 do ball('Листва',(9+i)*scale,Vector3.new(x+(i-2.5)*3*scale,(14+(i%2)*2)*scale,z+((i*7)%3-1)*2*scale),C3(66+i*5,72+i*3,44+i*2),M.Grass) end
end
for _,v in ipairs({{-160,175},{-110,125},{160,175},{110,125},{-155,-212},{-35,155},{35,155},{-35,-155},{35,-155},{-185,0},{185,0},{0,185},{0,-185}}) do tree(v[1],v[2],.8+(math.abs(v[1])%3)*.1) end
for _,x in ipairs({-195,195}) do for _,z in ipairs({-190,-70,70,190}) do
 if not(x==-195 and z==-190) then
 part('Фонарный столб',Vector3.new(.65,16,.65),Vector3.new(x,8,z),C3(62,66,70),M.Metal)
 part('Фонарь кронштейн',Vector3.new(.3,.3,3),Vector3.new(x,16.2,z+(x<0 and 1.2 or -1.2)),C3(62,66,70),M.Metal)
 local lamp=part('Фонарь',Vector3.new(3,1.1,2),Vector3.new(x,16.5,z),C3(255,226,177),M.Neon);lamp.CanCollide=false
 local light=Instance.new('PointLight');light.Range=26;light.Brightness=.7;light.Color=C3(255,220,170);light.Parent=lamp;regLamp(lamp,light,C3(120,118,110),M.Metal)
 end
end end
for _,v in ipairs({{-135,-80},{135,80},{-140,105},{215,-135}}) do
 local x,z=v[1],v[2]
 part('Гараж',Vector3.new(20,9,13),Vector3.new(x,4.5,z),C3(113,120,116),M.Metal)
 part('Гараж ворота',Vector3.new(15,7,.3),Vector3.new(x,3.7,z+6.7),C3(78,89,89),M.CorrugatedMetal)
 part('Гараж крыша',Vector3.new(21,.5,14),Vector3.new(x,9.3,z),C3(76,77,76),M.Metal)
end
for _,v in ipairs({{-60,0},{60,0},{0,-110},{0,110}}) do
 local x,z=v[1],v[2]
 part('Клумба земля',Vector3.new(13,.4,7),Vector3.new(x,.4,z),C3(88,72,58),M.Ground)
 part('Клумба бортик',Vector3.new(14,.6,8),Vector3.new(x,.2,z),C3(150,147,138))
 for i=-2,2 do ball('Цветы',1.2,Vector3.new(x+i*2,1.2,z),C3(184,82+(i+2)*20,93),M.Grass) end
end
-- детская площадка
part('Песочница',Vector3.new(17,.4,17),Vector3.new(-120,.3,25),C3(187,163,112),M.Sand)
for _,v in ipairs({{-129,16},{-111,16},{-129,34},{-111,34}}) do part('Борт песочницы',Vector3.new(2,1,2),Vector3.new(v[1],.7,v[2]),C3(119,80,52),M.Wood) end
for _,z in ipairs({-30,30}) do part('Турник стойка',Vector3.new(.6,8,.6),Vector3.new(125,4,z),C3(61,92,119),M.Metal) end
part('Турник перекладина',Vector3.new(.55,.55,60),Vector3.new(125,8,0),C3(61,92,119),M.Metal)
do -- горка
 local gx,gz=-100,45
 part('Горка площадка',Vector3.new(5,.4,5),Vector3.new(gx,6,gz),C3(198,150,60),M.Wood)
 for _,o in ipairs({{-2.2,-2.2},{2.2,-2.2},{-2.2,2.2},{2.2,2.2}}) do part('Горка стойка',Vector3.new(.4,6,.4),Vector3.new(gx+o[1],3,gz+o[2]),C3(61,92,119),M.Metal) end
 part('Горка скат',Vector3.new(3.2,.3,9),CFrame.new(gx,3,gz+7)*CFrame.Angles(rad(-34),0,0),C3(210,70,60),M.SmoothPlastic)
 for i=0,4 do part('Горка лестница',Vector3.new(3,.25,.8),Vector3.new(gx,.8+i*1.1,gz-3.2),C3(61,92,119),M.Metal) end
end
do -- качели
 local sx,sz=-140,60
 for _,dx in ipairs({-7,7}) do
  part('Качели стойка',Vector3.new(.5,9,.5),CFrame.new(sx+dx,4.5,sz+1.5)*CFrame.Angles(rad(12),0,0),C3(200,60,50),M.Metal)
  part('Качели стойка',Vector3.new(.5,9,.5),CFrame.new(sx+dx,4.5,sz-1.5)*CFrame.Angles(rad(-12),0,0),C3(200,60,50),M.Metal)
 end
 part('Качели перекладина',Vector3.new(15,.5,.5),Vector3.new(sx,8.8,sz),C3(200,60,50),M.Metal)
 for _,dx in ipairs({-3,3}) do
  for _,cx in ipairs({-.8,.8}) do part('Цепь',Vector3.new(.1,5.5,.1),Vector3.new(sx+dx+cx,6,sz),C3(110,110,110),M.Metal).CanCollide=false end
  part('Качели сиденье',Vector3.new(2,.3,.9),Vector3.new(sx+dx,3.2,sz),C3(60,60,64),M.Wood)
 end
end
-- машины
local carColors={C3(150,40,40),C3(60,80,120),C3(190,190,185),C3(55,60,58),C3(170,140,60),C3(90,110,90)}
local function car(x,z,rot,col)
 local cf=CFrame.new(x,0,z)*CFrame.Angles(0,rad(rot),0)
 local model=Instance.new('Model');model.Name='Машина';model.Parent=w
 part('Кузов',Vector3.new(14,2.2,6.2),cf*CFrame.new(0,2.1,0),col,M.Metal,model)
 part('Кабина',Vector3.new(7,2,5.6),cf*CFrame.new(-.6,4.2,0),col,M.Metal,model)
 local g=part('Стёкла',Vector3.new(7.2,1.5,5.7),cf*CFrame.new(-.6,4.3,0),C3(70,95,105),M.Glass,model);g.Transparency=.25;g.CanCollide=false
 part('Бампер',Vector3.new(14.4,.7,6.4),cf*CFrame.new(0,1.2,0),C3(50,52,54),M.Metal,model)
 for _,wp in ipairs({{-4.2,3.1},{4.2,3.1},{-4.2,-3.1},{4.2,-3.1}}) do
  local wheel=part('Колесо',Vector3.new(1,2.8,2.8),cf*CFrame.new(wp[1],1.4,wp[2])*CFrame.Angles(0,rad(90),0),C3(25,25,27),M.Rubber,model);wheel.Shape=Enum.PartType.Cylinder
 end
 for _,s in ipairs({-2,2}) do
  local h=part('Фара',Vector3.new(.3,.7,1.1),cf*CFrame.new(7.1,2.4,s),C3(255,240,200),M.SmoothPlastic,model);h.CanCollide=false
  local t=part('Стоп',Vector3.new(.3,.6,1),cf*CFrame.new(-7.1,2.4,s),C3(180,30,30),M.SmoothPlastic,model);t.CanCollide=false
 end
end
local carSpots={{-70,-212,0},{70,-208,0},{-70,214,0},{72,210,0},{-232,-110,90},{212,110,90},{-212,100,90},{212,-100,90},{-18,-236,0}}
for i,s in ipairs(carSpots) do car(s[1],s[2],s[3],carColors[(i-1)%#carColors+1]) end
-- мусорные баки и контейнеры (укрытия в бою)
local function dumpster(x,z,rot)
 local cf=CFrame.new(x,0,z)*CFrame.Angles(0,rad(rot),0)
 part('Бак',Vector3.new(6,3.6,3.4),cf*CFrame.new(0,2.4,0),C3(46,98,66),M.Metal)
 part('Бак крышка',Vector3.new(6.2,.4,3.6),cf*CFrame.new(0,4.4,.1)*CFrame.Angles(rad(-6),0,0),C3(33,70,48),M.Metal)
 for _,xx in ipairs({-2.4,2.4}) do local wh=part('Колёсико',Vector3.new(.4,.9,.9),cf*CFrame.new(xx,.5,1.4),C3(20,20,20),M.Rubber);wh.Shape=Enum.PartType.Cylinder end
end
for _,v in ipairs({{110,110,200},{-30,-215,0},{30,215,180},{-215,45,90},{215,-45,270}}) do dumpster(v[1],v[2],v[3]) end
for _,v in ipairs({{-20,-60},{20,60},{-95,95},{95,-95},{-60,-130},{60,130}}) do
 cyl('Урна',1.6,2.2,Vector3.new(v[1],1.1,v[2]),C3(52,56,58),M.Metal)
end
-- ===== РАЙОН: футбольное поле (северо-восток) =====
local FX,FZ=135,-140
do
 local fm=Instance.new('Model');fm.Name='Футбольное поле';fm.Parent=w
 local white=C3(236,236,228)
 local G1,G2=C3(54,88,48),C3(62,100,54)
 part('Поле подложка',Vector3.new(114,.3,74),Vector3.new(FX,.15,FZ),C3(122,118,106),M.Concrete,fm)
 part('Газон поля',Vector3.new(110,.4,70),Vector3.new(FX,.2,FZ),G1,M.Grass,fm)
 for i=0,9 do
  if i%2==0 then part('Полоса газона',Vector3.new(10,.05,70),Vector3.new(FX-50+5+i*10,.43,FZ),G2,M.Grass,fm).CanCollide=false end
 end
 local function ln(sx,sz,x,z)
  local p=part('Разметка поля',Vector3.new(sx,.06,sz),Vector3.new(FX+x,.47,FZ+z),white,M.SmoothPlastic,fm);p.CanCollide=false;return p
 end
 for _,s in ipairs({-1,1}) do
  ln(100,.6,0,s*30);ln(.6,60,s*50,0)           -- боковые и лицевые линии
  ln(.6,36,s*34,0);ln(16,.6,s*42,-18);ln(16,.6,s*42,18) -- штрафная
  ln(.6,20,s*44,0);ln(6,.6,s*47,-10);ln(6,.6,s*47,10)   -- вратарская
  local pen=cyl('Точка пенальти',1.1,.06,Vector3.new(FX+s*38,.47,FZ),white,M.SmoothPlastic,fm);pen.CanCollide=false
 end
 ln(.6,60,0,0)
 for k=0,23 do -- центральный круг
  local a=rad(k*15)
  local seg=part('Центральный круг',Vector3.new(.6,.06,2.6),CFrame.new(FX+math.cos(a)*9,.47,FZ+math.sin(a)*9)*CFrame.Angles(0,-a,0),white,M.SmoothPlastic,fm);seg.CanCollide=false
 end
 cyl('Центральная точка',1.3,.06,Vector3.new(FX,.47,FZ),white,M.SmoothPlastic,fm).CanCollide=false
 -- ворота
 for _,s in ipairs({-1,1}) do
  local gx=FX+s*50
  for _,pz in ipairs({-9,9}) do part('Штанга',Vector3.new(.6,8,.6),Vector3.new(gx,4.4,FZ+pz),white,M.Metal,fm) end
  part('Перекладина',Vector3.new(.6,.6,18.6),Vector3.new(gx,8.2,FZ),white,M.Metal,fm)
  local netc=C3(235,235,235)
  local function net(sz,pos) local p=part('Сетка ворот',sz,pos,netc,M.SmoothPlastic,fm);p.Transparency=.6;p.CanCollide=false end
  net(Vector3.new(.15,8,18),Vector3.new(gx+s*4,4.4,FZ))
  net(Vector3.new(4,.15,18),Vector3.new(gx+s*2,8.2,FZ))
  for _,pz in ipairs({-9,9}) do net(Vector3.new(4,8,.15),Vector3.new(gx+s*2,4.4,FZ+pz)) end
 end
 -- мяч
 local b2=Instance.new('Part');b2.Name='Мяч';b2.Shape=Enum.PartType.Ball;b2.Size=Vector3.new(2.4,2.4,2.4);b2.Position=Vector3.new(FX,2,FZ)
 b2.Color=C3(245,245,245);b2.Material=M.SmoothPlastic;b2.CustomPhysicalProperties=PhysicalProperties.new(.5,.4,.75,1,1);b2.Parent=fm
 -- сетчатый забор («коробка») с проходами
 local HXf,HZf=56,36
 local function fencePanel(cx,cz,len,alongX)
  local sx,sz=len,.2;if not alongX then sx,sz=.2,len end
  local mesh=part('Сетка забора',Vector3.new(sx,11,sz),Vector3.new(cx,7.5,cz),C3(120,126,132),M.Metal,fm);mesh.Transparency=.75
  local tx,tz=len,.45;if not alongX then tx,tz=.45,len end
  part('Забор верх',Vector3.new(tx,.45,tz),Vector3.new(cx,13.2,cz),C3(58,64,70),M.Metal,fm)
  part('Забор низ',Vector3.new(tx,.45,tz),Vector3.new(cx,1.8,cz),C3(58,64,70),M.Metal,fm)
 end
 local function fenceSide(alongX,fixed,length,count,skipList)
  local pl=length/count
  for k=0,count do -- столбы
   local pos=-length/2+k*pl
   if alongX then part('Столб забора',Vector3.new(.7,14,.7),Vector3.new(FX+pos,7,FZ+fixed),C3(50,56,62),M.Metal,fm)
   else part('Столб забора',Vector3.new(.7,14,.7),Vector3.new(FX+fixed,7,FZ+pos),C3(50,56,62),M.Metal,fm) end
  end
  for k=1,count do
   local pos=-length/2+(k-.5)*pl
   local skip=false
   for _,s in ipairs(skipList) do if math.abs(pos-s)<.5 then skip=true end end
   if not skip then
    if alongX then fencePanel(FX+pos,FZ+fixed,pl,true) else fencePanel(FX+fixed,FZ+pos,pl,false) end
   end
  end
 end
 fenceSide(true,-HZf,112,7,{0})        -- север: проход по центру
 fenceSide(true,HZf,112,7,{-32,32})    -- юг: два прохода к дорожке
 fenceSide(false,-HXf,72,5,{28.8})     -- запад: проход
 fenceSide(false,HXf,72,5,{-28.8})     -- восток: проход
 -- прожекторы по углам
 for _,sx in ipairs({-1,1}) do for _,sz in ipairs({-1,1}) do
  local px,pz=FX+sx*(HXf+3),FZ+sz*(HZf+3)
  part('Мачта прожектора',Vector3.new(.9,32,.9),Vector3.new(px,16,pz),C3(70,74,78),M.Metal,fm)
  local head=part('Прожектор',Vector3.new(7,.8,2.4),Vector3.new(px,32.4,pz),C3(255,244,214),M.Neon,fm);head.CanCollide=false
  local pl=Instance.new('PointLight');pl.Range=44;pl.Brightness=.5;pl.Parent=head;regLamp(head,pl,C3(110,108,100),M.Metal)
 end end
 -- табло-баннер над северным проходом и скамейки запасных
 local ban=part('Баннер поля',Vector3.new(26,4.5,.4),Vector3.new(FX,16.25,FZ-HZf),C3(28,52,96),M.SmoothPlastic,fm)
 for _,face in ipairs({Enum.NormalId.Front,Enum.NormalId.Back}) do
  local gui=Instance.new('SurfaceGui');gui.Face=face;gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud;gui.PixelsPerStud=40;gui.LightInfluence=0;gui.Parent=ban
  local t=Instance.new('TextLabel');t.Size=UDim2.fromScale(1,1);t.BackgroundTransparency=1;t.Font=Enum.Font.GothamBlack;t.TextScaled=true;t.TextColor3=C3(255,226,120);t.Text='ДВОРОВАЯ КОРОБКА';t.Parent=gui
 end
 for _,bx in ipairs({-22,22}) do bench(FX+bx,FZ+HZf+5,0) end
end

-- ===== РАЙОН: гаражный кооператив (северо-запад) =====
local GX,GZ=-155,-145
do
 local gm=Instance.new('Model');gm.Name='Гаражи';gm.Parent=w
 part('Гаражи земля',Vector3.new(118,.3,94),Vector3.new(GX,.18,GZ),C3(92,88,80),M.Ground,gm)
 for _,az in ipairs({-22,23}) do part('Гаражный проезд',Vector3.new(118,.2,16),Vector3.new(GX,.32,GZ+az),C3(68,70,70),M.Asphalt,gm) end
 local bodyCols={C3(113,120,116),C3(128,112,96),C3(104,108,112),C3(132,126,112),C3(96,104,98)}
 local doorCols={C3(78,89,89),C3(128,52,44),C3(54,84,120),C3(112,104,58),C3(96,72,50),C3(58,100,70)}
 local function cell(cx,cz,face)
  local body=bodyCols[rng:NextInteger(1,#bodyCols)]
  local dcol=doorCols[rng:NextInteger(1,#doorCols)]
  part('Гараж стены',Vector3.new(9,8,14),Vector3.new(cx,4.33,cz),body,M.Metal,gm)
  part('Гараж крыша',Vector3.new(9.4,.5,14.6),Vector3.new(cx,8.55,cz),C3(70,72,70),M.Metal,gm)
  part('Гараж ворота',Vector3.new(7.4,6.6,.3),Vector3.new(cx,3.65,cz+face*7.1),dcol,M.CorrugatedMetal,gm)
  part('Гараж номер',Vector3.new(1.6,.9,.1),Vector3.new(cx,7.6,cz+face*7.06),C3(228,228,214),M.SmoothPlastic,gm).CanCollide=false
  if rng:NextNumber()<.3 then
   local lp=part('Гараж лампа',Vector3.new(.8,.3,.8),Vector3.new(cx-2.8,7.2,cz+face*7.5),C3(232,200,146),M.Neon,gm);lp.CanCollide=false;regLamp(lp,nil,C3(96,90,76),M.SmoothPlastic)
  end
 end
 local function row(zOff,face,skipA,skipB)
  for i=1,12 do
   if i~=skipA and i~=skipB then cell(GX+(i-6.5)*9,GZ+zOff,face) end
  end
 end
 row(-38,1)        -- ряд A (двери на юг)
 row(-6,-1,6,7)    -- ряд B (двери на север), проход в середине
 row(8,1,6,7)      -- ряд C (двери на юг), проход в середине
 row(38,-1)        -- ряд D (двери на север)
 -- въездная арка «ГК ЗАРЯ» (запад)
 local ax=GX-58
 for _,pz in ipairs({-9.5,9.5}) do part('Арка опора',Vector3.new(1.2,13,1.2),Vector3.new(ax,6.5,GZ-22+pz),C3(70,74,78),M.Metal,gm) end
 local arch=part('Арка вывеска',Vector3.new(1.2,3.2,21),Vector3.new(ax,13.2,GZ-22),C3(34,70,52),M.SmoothPlastic,gm)
 for _,face in ipairs({Enum.NormalId.Left,Enum.NormalId.Right}) do
  local gui=Instance.new('SurfaceGui');gui.Face=face;gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud;gui.PixelsPerStud=40;gui.LightInfluence=0;gui.Parent=arch
  local t=Instance.new('TextLabel');t.Size=UDim2.fromScale(1,1);t.BackgroundTransparency=1;t.Font=Enum.Font.GothamBlack;t.TextScaled=true;t.TextColor3=C3(240,240,230);t.Text='ГК «ЗАРЯ»';t.Parent=gui
 end
 -- шлагбаум (поднят) на востоке второго проезда
 do
  local px,pz=GX+58,GZ+23-6
  part('Шлагбаум стойка',Vector3.new(1,3.4,1),Vector3.new(px,1.9,pz),C3(70,74,78),M.Metal,gm)
  local base=CFrame.new(px,3.4,pz)*CFrame.Angles(rad(-80),0,0)
  for k=0,5 do
   part('Шлагбаум стрела',Vector3.new(.4,.5,2),base*CFrame.new(0,0,1+k*2),(k%2==0) and C3(200,50,44) or C3(235,235,228),M.SmoothPlastic,gm).CanCollide=false
  end
 end
 -- сторожка
 do
  local bx,bz=GX+64,GZ+34
  part('Сторожка',Vector3.new(7,7,6),Vector3.new(bx,3.8,bz),C3(150,118,78),M.Wood,gm)
  part('Сторожка крыша',Vector3.new(8,.5,7),Vector3.new(bx,7.55,bz),C3(78,60,50),M.Metal,gm)
  local win=part('Сторожка окно',Vector3.new(3,2.4,.15),Vector3.new(bx-1,4.6,bz-3.05),C3(200,168,108),M.Neon,gm);win.CanCollide=false;regLamp(win,nil,C3(66,74,78),M.SmoothPlastic)
 end
 -- хлам и укрытия
 local function barrel(x,z,col) cyl('Бочка',2.4,3.4,Vector3.new(x,2,z),col,M.Metal,gm) end
 local function tires(x,z,n) for k=0,n-1 do cyl('Покрышка',3.2,.9,Vector3.new(x,.8+k*.9,z),C3(24,24,26),M.Rubber,gm) end end
 local function crate(x,z,s) part('Ящик',Vector3.new(s,s,s),Vector3.new(x,.35+s/2,z),C3(131,98,62),M.Wood,gm) end
 for _,v in ipairs({{-40,-22,C3(150,52,44)},{-39,-20,C3(52,82,138)},{22,-17,C3(52,120,76)},{44,-27,C3(150,52,44)},{-46,24,C3(52,82,138)},{40,17,C3(150,52,44)},{0,-28,C3(52,120,76)}}) do barrel(GX+v[1],GZ+v[2],v[3]) end
 for _,v in ipairs({{-30,-17,3},{14,-27,4},{-14,17,3},{48,28,5},{-51,-28,4}}) do tires(GX+v[1],GZ+v[2],v[3]) end
 for _,v in ipairs({{-6,-1,3.4},{5,-5,3},{30,-27,3.4},{-34,28,3.4},{-33,26,3},{12,18,3.4},{-52,18,3.2}}) do crate(GX+v[1],GZ+v[2],v[3]) end
 car(GX-24,GZ+23,0,C3(130,92,60))
 car(GX+26,GZ-22,0,C3(96,100,92))
 dumpster(GX-52,GZ-47,0)
 dumpster(GX+50,GZ-47,0)
 for _,v in ipairs({{-14,-22},{16,-22},{-36,23},{30,23}}) do
  local lx,lz=GX+v[1],GZ+v[2]
  part('Столб освещения',Vector3.new(.6,15,.6),Vector3.new(lx,7.5,lz),C3(62,66,70),M.Metal,gm)
  local lamp=part('Фонарь',Vector3.new(3,.9,1.6),Vector3.new(lx,15.3,lz),C3(255,226,177),M.Neon,gm);lamp.CanCollide=false
  local light=Instance.new('PointLight');light.Range=28;light.Brightness=.7;light.Color=C3(255,220,170);light.Parent=lamp;regLamp(lamp,light,C3(120,118,110),M.Metal)
 end
 for _,v in ipairs({{-10,-18,6},{20,-20,5},{-28,20,6},{10,26,7},{36,-24,5}}) do
  local pd=cyl('Лужа',v[3],.05,Vector3.new(GX+v[1],.44,GZ+v[2]),C3(44,52,62),M.SmoothPlastic,gm);pd.Reflectance=.3;pd.CanCollide=false
 end
end

-- ===== v1.1: мрачные детали =====
do
 local dm=Instance.new('Model');dm.Name='Детали';dm.Parent=w
 -- лужи по всей карте
 for i=1,28 do
  local x,z=rng:NextNumber(-285,285),rng:NextNumber(-285,285)
  if math.sqrt(x*x+z*z)>48 then
   local pd=cyl('Лужа',rng:NextNumber(4,11),.05,Vector3.new(x,.1,z),C3(40,48,58),M.SmoothPlastic,dm);pd.Reflectance=.3;pd.CanCollide=false
  end
 end
 -- мусор: пакеты и банки
 local function trash(x,z)
  for k=1,rng:NextInteger(4,7) do
   local d=rng:NextNumber(1.1,2.2)
   ball('Мусорный пакет',d,Vector3.new(x+rng:NextNumber(-3,3),d/2,z+rng:NextNumber(-3,3)),(k%2==0) and C3(24,24,26) or C3(58,62,58),M.SmoothPlastic,dm)
  end
  for k=1,3 do
   local c=cyl('Банка',.6,.9,Vector3.new(x+rng:NextNumber(-4,4),.45,z+rng:NextNumber(-4,4)),C3(140,60,50),M.Metal,dm);c.CanCollide=false
  end
 end
 for _,v in ipairs({{-34,-212},{34,212},{-212,52},{212,-52},{104,104},{-180,-92},{18,-228},{-96,150},{96,-150},{228,150},{-228,-150},{GX+46,GZ-52}}) do trash(v[1],v[2]) end
 -- бочки с огнём (свет и дым)
 local function fireBarrel(x,z)
  cyl('Бочка с огнём',2.8,3.8,Vector3.new(x,2.1,z),C3(88,50,38),M.Metal,dm)
  local top=cyl('Угли',2.2,.2,Vector3.new(x,4.1,z),C3(255,120,40),M.Neon,dm);top.CanCollide=false
  local fire=Instance.new('Fire');fire.Size=6;fire.Heat=8;fire.Color=C3(255,150,50);fire.SecondaryColor=C3(190,50,20);fire.Parent=top
  local light=Instance.new('PointLight');light.Color=C3(255,150,70);light.Range=22;light.Brightness=1.2;light.Parent=top
 end
 for _,v in ipairs({{GX,GZ+8},{FX-32,FZ+46},{-100,10},{190,60}}) do fireBarrel(v[1],v[2]) end
 -- сгоревшие машины
 car(150,238,0,C3(30,28,27))
 car(-150,-240,0,C3(36,32,30))
 local sm=part('Дым',Vector3.new(1,1,1),Vector3.new(150,5,238),C3(0,0,0),M.SmoothPlastic,dm);sm.Transparency=1;sm.CanCollide=false
 local smk=Instance.new('Smoke');smk.Size=6;smk.Opacity=.3;smk.RiseVelocity=3;smk.Color=C3(60,60,62);smk.Parent=sm
 -- поддоны и покрышки у домов
 for _,v in ipairs({{-205,-245},{205,245},{-60,248},{60,-248},{-248,100},{248,-100}}) do
  for k=0,2 do part('Поддон',Vector3.new(4,.35,4),Vector3.new(v[1],.2+k*.4,v[2]),C3(108,82,56),M.Wood,dm).Orientation=Vector3.new(0,k*18,0) end
 end
 -- столбы электропередач с проводами вдоль улиц
 local poles={{-240,-100},{-240,100},{240,-100},{240,100},{-100,240},{100,-240}}
 for _,v in ipairs(poles) do
  part('Столб ЛЭП',Vector3.new(.9,26,.9),Vector3.new(v[1],13,v[2]),C3(78,62,48),M.Wood,dm)
  part('Траверса',Vector3.new(.5,.5,7),Vector3.new(v[1],24,v[2]),C3(60,48,38),M.Wood,dm)
 end
 for _,pair in ipairs({{1,2},{3,4}}) do
  local a,b=poles[pair[1]],poles[pair[2]]
  for _,off in ipairs({-2.5,0,2.5}) do
   local len=math.abs(b[2]-a[2])
   part('Провод',Vector3.new(.08,.08,len),Vector3.new(a[1]+off,23.3,(a[2]+b[2])/2),C3(20,20,22),M.Metal,dm).CanCollide=false
  end
 end
 -- мигающие фонари: часть фонарей мерцает как сломанные (заметно только когда они горят, то есть вечером и ночью)
 local flick={}
 for _,l in ipairs(lamps) do
  if l.p.Name=='Фонарь' and rng:NextNumber()<.35 then table.insert(flick,l) end
 end
 local flr=Random.new(7)
 task.spawn(function()
  while w.Parent do
   task.wait(.3)
   for _,l in ipairs(flick) do
    if flr:NextNumber()<.05 then
     l.flickOn=flr:NextNumber()<.5
     if l.last>0 then setLamp(l,l.last) end
    end
   end
  end
 end)
end

-- ===== v1.3: ещё немного деталей двора (около 200 деталей) =====
do
 local nm=Instance.new('Model');nm.Name='Мелочи v1.3';nm.Parent=w
 local dr=Random.new(2026)
 local V=Vector3.new
 local function signText(p,face,text,col)
  local gui=Instance.new('SurfaceGui');gui.Face=face;gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud;gui.PixelsPerStud=40;gui.LightInfluence=1;gui.Parent=p
  local t=Instance.new('TextLabel');t.Size=UDim2.fromScale(1,1);t.BackgroundTransparency=1;t.Font=Enum.Font.GothamBlack;t.TextScaled=true;t.TextColor3=col;t.Text=text;t.Parent=gui
 end
 local function local_(x,z,rot) -- детали строятся в локальных координатах: перед = +Z
  local cf=CFrame.new(x,0,z)*CFrame.Angles(0,rad(rot),0)
  return function(n,size,off,c,mat) return part(n,size,cf*CFrame.new(off),c,mat,nm) end
 end
 -- ларьки «ПРОДУКТЫ 24» (вывеска и окно светятся только ночью)
 local function kiosk(x,z,rot,col,text)
  local blk=local_(x,z,rot)
  blk('Ларёк корпус',V(9,6,6),V(0,3,0),col,M.Metal)
  blk('Ларёк крыша',V(10,.5,7),V(0,6.25,0),C3(70,72,72),M.Metal)
  local win=blk('Ларёк окно',V(5.6,2.2,.2),V(0,3.9,3.05),C3(200,168,108),M.Neon);win.CanCollide=false
  regLamp(win,nil,C3(66,74,78),M.SmoothPlastic)
  blk('Ларёк прилавок',V(7,.4,1.8),V(0,3.2,3.8),C3(140,136,126),M.Concrete)
  blk('Ларёк навес',V(8,.25,3),V(0,5.5,4.4),C3(176,60,52),M.Fabric)
  local sign=blk('Ларёк вывеска',V(8,1.5,.3),V(0,7.3,3.1),C3(210,60,48),M.Neon);sign.CanCollide=false
  regLamp(sign,nil,C3(120,36,32),M.SmoothPlastic)
  signText(sign,Enum.NormalId.Back,text,C3(250,244,230))
  blk('Ящик',V(2,2,2),V(-5.6,1,3.4),C3(131,98,62),M.Wood)
  blk('Ящик',V(1.8,1.8,1.8),V(-5.4,2.9,3.4),C3(120,90,58),M.Wood)
 end
 kiosk(-185,-246,0,C3(60,102,86),'ПРОДУКТЫ 24')
 kiosk(200,245,180,C3(70,86,120),'ПИВО · РЫБА')
 -- остановка
 do
  local blk=local_(-110,222,180)
  for _,dx in ipairs({-5.5,5.5}) do blk('Остановка столб',V(.5,9,.5),V(dx,4.5,-2),C3(60,64,68),M.Metal) end
  blk('Остановка крыша',V(12.5,.5,6),V(0,9.2,0),C3(58,96,128),M.Metal)
  local ad=blk('Остановка щит',V(10.5,5,.3),V(0,5.6,-2.4),C3(214,208,190),M.SmoothPlastic)
  signText(ad,Enum.NormalId.Back,'КУПЛЮ ГАРАЖ\n8-900-***-**-**',C3(40,40,44))
  blk('Остановка скамья',V(8,.4,1.6),V(0,2.2,-1.2),C3(117,76,49),M.Wood)
  for _,dx in ipairs({-3.5,3.5}) do blk('Остановка ножка',V(.4,2,1.4),V(dx,1,-1.2),C3(61,65,66),M.Metal) end
  blk('Знак столб',V(.3,12,.3),V(8.5,6,1.5),C3(70,74,78),M.Metal)
  local zn=blk('Знак остановки',V(2.6,2.6,.2),V(8.5,12,1.5),C3(36,92,170),M.SmoothPlastic)
  signText(zn,Enum.NormalId.Back,'А',C3(255,255,255))
 end
 -- рамы для выбивания ковров
 local function carpetRack(x,z,rot,col)
  local blk=local_(x,z,rot)
  for _,dx in ipairs({-4.5,4.5}) do blk('Рама столб',V(.5,8,.5),V(dx,4,0),C3(70,74,78),M.Metal) end
  blk('Рама перекладина',V(9.5,.45,.45),V(0,8,0),C3(70,74,78),M.Metal)
  blk('Рама перекладина',V(9.5,.45,.45),V(0,5,0),C3(70,74,78),M.Metal)
  blk('Ковёр',V(5.2,4.9,.3),V(-1,5.9,.4),col,M.Fabric).CanCollide=false
  blk('Ковёр узор',V(3.8,3.5,.34),V(-1,5.9,.4),C3(math.floor(col.R*255*.6),math.floor(col.G*255*.6),math.floor(col.B*255*.6)),M.Fabric).CanCollide=false
 end
 carpetRack(150,-55,90,C3(150,40,48))
 carpetRack(-155,-45,90,C3(52,84,120))
 -- бельё на верёвках
 local cloth={C3(230,228,220),C3(190,60,56),C3(70,110,170),C3(220,190,80),C3(110,150,100),C3(200,200,206)}
 local function laundry(x,z,len,rot)
  local blk=local_(x,z,rot)
  for _,dx in ipairs({-len/2,len/2}) do blk('Бельё столб',V(.4,12.5,.4),V(dx,6.25,0),C3(86,70,56),M.Wood) end
  for _,ly in ipairs({11.6,9.9}) do
   blk('Бельё верёвка',V(len,.08,.08),V(0,ly,0),C3(190,186,170),M.Fabric).CanCollide=false
   for _=1,7 do
    local cx=(dr:NextNumber()-.5)*(len-4);local kind=dr:NextInteger(1,3);local col=cloth[dr:NextInteger(1,#cloth)]
    local p
    if kind==1 then p=blk('Бельё',V(1.7,2.2,.1),V(cx,ly-1.2,0),col,M.Fabric)
    elseif kind==2 then p=blk('Бельё',V(.9,2.8,.1),V(cx,ly-1.5,0),col,M.Fabric)
    else p=blk('Бельё',V(2.4,1.6,.1),V(cx,ly-.9,0),col,M.Fabric) end
    p.CanCollide=false
   end
  end
 end
 laundry(-68,172,36,0)
 laundry(190,-205,30,90)
 -- классики мелом
 do
  local cells={{0,0},{0,1},{0,2},{-.55,3},{.55,3},{0,4},{-.55,5},{.55,5},{0,6},{0,7.2}}
  local chalk={C3(214,130,160),C3(230,210,110),C3(130,190,220)}
  for i,c in ipairs(cells) do
   part('Классики',V(2,.04,2),V(55+c[1]*2.2,.07,100+c[2]*2.2),chalk[i%3+1],M.SmoothPlastic,nm).CanCollide=false
  end
 end
 -- карусель на детской площадке
 do
  local cx,cz=-150,22
  cyl('Карусель основание',9,.5,V(cx,.55,cz),C3(200,60,50),M.Metal,nm)
  cyl('Карусель ось',.8,3.4,V(cx,2.2,cz),C3(61,92,119),M.Metal,nm).CanCollide=false
  for i=0,1 do part('Карусель поручень',V(9,.35,.35),CFrame.new(cx,3.4,cz)*CFrame.Angles(0,rad(i*90),0),C3(61,92,119),M.Metal,nm).CanCollide=false end
  for _,o in ipairs({{3.6,0},{-3.6,0},{0,3.6},{0,-3.6}}) do part('Карусель стойка',V(.3,2.6,.3),V(cx+o[1],1.9,cz+o[2]),C3(61,92,119),M.Metal,nm).CanCollide=false end
 end
 -- голуби на проводах (провода тянутся вдоль x=±240 и x=±237.5/±242.5 на высоте 23.3)
 do
  local wireX={-242.5,-240,-237.5,237.5,240,242.5}
  for _=1,7 do
   local x=wireX[dr:NextInteger(1,#wireX)];local z=dr:NextNumber(-90,90);local f=dr:NextInteger(0,1)*2-1
   local y=23.34
   ball('Голубь',1.3,V(x,y+.65,z),C3(118,122,128),M.SmoothPlastic,nm)
   ball('Голубь голова',.7,V(x,y+1.25,z+f*.55),C3(98,104,112),M.SmoothPlastic,nm)
   part('Голубь хвост',V(.5,.15,.9),V(x,y+.7,z-f*.9),C3(84,88,94),M.SmoothPlastic,nm).CanCollide=false
  end
 end
end

-- ===== Периметр: тротуар у домов + невидимые стены (страховка) =====
for _,s in ipairs({-1,1}) do
 part('Тротуар у домов',Vector3.new(608,.25,8),Vector3.new(0,.14,s*300),concrete)
 part('Тротуар у домов',Vector3.new(8,.25,608),Vector3.new(s*300,.14,0),concrete)
 local wallA=part('Стена',Vector3.new(620,400,2),Vector3.new(0,200,s*306),C3(255,255,255),M.SmoothPlastic);wallA.Transparency=1
 local wallB=part('Стена',Vector3.new(2,400,620),Vector3.new(s*306,200,0),C3(255,255,255),M.SmoothPlastic);wallB.Transparency=1
end

-- оптимизация: на карте нет Touched; несталкивающиеся детали не участвуют в рейкастах
for _,d in ipairs(w:GetDescendants()) do
 if d:IsA('BasePart') and d.Name~='Мяч' then
  d.CanTouch=false
  if not d.CanCollide then d.CanQuery=false end
 end
end

-- ===== Смена дня и ночи: окна и фонари (свет и небо — в DayNight.client) =====
do
 local h0=DN.hour()
 updateWindows(h0);updateLamps(DN.lampLevel(h0))
 task.spawn(function()
  while w.Parent do
   task.wait(1)
   local h=DN.hour()
   updateWindows(h);updateLamps(DN.lampLevel(h))
  end
 end)
end

-- ===== Спавны (центр занят площадью) =====
local locations={{0,52},{70,70},{-70,-70},{70,-70},{-70,70},{0,145},{0,-145},{145,0},{-145,0},{185,115},{-185,-85},{115,-188},{-115,185},{GX-30,GZ-22},{GX+30,GZ+23},{FX-30,FZ},{FX+30,FZ}}
for i,pt in ipairs(locations) do
 local spawn=Instance.new('SpawnLocation');spawn.Name='Spawn_'..i;spawn.Size=Vector3.new(8,1,8);spawn.Position=Vector3.new(pt[1],.6,pt[2]);spawn.Anchored=true;spawn.Neutral=true;spawn.AllowTeamChangeOnTouch=false;spawn.Transparency=.8;spawn.Color=C3(89,99,100);spawn.Parent=w
end
