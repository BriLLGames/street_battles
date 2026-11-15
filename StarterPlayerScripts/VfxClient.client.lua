-- VfxClient v2.1: визуальные эффекты боя (LocalScript в StarterPlayerScripts).
-- v2.1: камера при ударах (толчок от направления удара, импульс у атакующего, «стоп-кадр» на сильных ударах),
--       кинематографичные полосы и импакт-кадры в ультах, всплывающие статусы над бойцами, кровь, детали скиллов
--       (выстрел вверх, свечение телефона, перегар, пивная пена, удары лбом), красная кайма при низком здоровье.
-- Всё рисуется только на клиенте: сервер шлёт короткие события (FX / Skill / Dash / UltStart / Finisher / Shake),
-- здесь они превращаются в вспышки, искры-«штрихи», ударные кольца, дым, осколки, шлейфы-дуги ударов, afterimage при рывках,
-- ауру ульта, тряску камеры, FOV-удар, вспышки экрана и скоростные линии.
-- v1.5: bloom-пульсы, подсветка пострадавшего, молнии/брызги/угольки/копоть, фирменные эффекты каждого бойца, пыль под ногами при шагах скиллов.
-- НАСТРОЙКИ: QUAL (0.5..1.5) — общее количество частиц; THEME — цвета каждого бойца; CAST — эффекты скиллов каждого бойца.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local TS=game:GetService('TweenService')
local RunService=game:GetService('RunService')
local Debris=game:GetService('Debris')
local Lighting=game:GetService('Lighting')
local UIS=game:GetService('UserInputService')
local lp=Players.LocalPlayer
local remote=RS:WaitForChild('StreetAction')
local V3,CF,C3=Vector3.new,CFrame.new,Color3.fromRGB
local rad,rnd,cos,sin,pi,clamp=math.rad,math.random,math.cos,math.sin,math.pi,math.clamp

local mobile=UIS.TouchEnabled and not UIS.KeyboardEnabled
local QUAL=mobile and .5 or 1          -- качество: на телефоне вдвое меньше частиц
local MAXSIM=mobile and 120 or 260     -- сколько «ручных» частиц (искры, осколки, кольца) живёт одновременно
local FAR=170                          -- дальше этого расстояния эффекты не рисуются
local function R(a,b) return a+(b-a)*rnd() end
local function N(n) return math.max(1,math.floor(n*QUAL+.5)) end
local OUT,INOUT=Enum.EasingDirection.Out,Enum.EasingDirection.InOut
local QD,QT,SN=Enum.EasingStyle.Quad,Enum.EasingStyle.Quint,Enum.EasingStyle.Sine
local BALL=Enum.PartType.Ball
local WHITE=C3(255,255,255);local GRAY=C3(122,120,116)
local T_SMOKE='rbxasset://textures/particles/smoke_main.dds'
local T_SPARK='rbxasset://textures/particles/sparkles_main.dds'
local T_FIRE='rbxasset://textures/particles/fire_main.dds'

-- Цвета бойцов: main — основной, core — раскалённая «сердцевина», alt — запасной (дым, второй цвет)
local THEME={
 Siply ={main=C3(255,205,110),core=C3(255,250,226),alt=C3(190,200,215)},
 Diesel={main=C3(255,105,35), core=C3(255,236,172),alt=C3(255,60,30)},
 Bitok ={main=C3(228,70,55),  core=C3(255,208,182),alt=C3(150,108,72)},
 Major ={main=C3(70,140,255), core=C3(226,238,255),alt=C3(255,60,60)},
 Yura  ={main=C3(120,226,90), core=C3(236,255,202),alt=C3(74,150,62)},
 Jack  ={main=C3(255,190,60), core=C3(255,246,206),alt=C3(60,170,150)},
}
local function theme(f) return THEME[f] or THEME.Siply end

local fold=Instance.new('Folder');fold.Name='StreetVFX';fold.Parent=workspace
local letterbox,impactFrame -- v2.1: объявлены заранее, определены ниже (рядом с камерой ударов)

-- ===== Базовые кирпичики =====
local function mkPart(shape,size,color,transp,cf,mat,life)
 local p=Instance.new('Part');p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
 p.Material=mat or Enum.Material.Neon;p.Color=color;p.Transparency=transp or 0;p.Size=size;p.CFrame=cf
 p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
 if shape then p.Shape=shape end
 p.Parent=fold;Debris:AddItem(p,life or 6) -- страховка: даже если что-то сломается, деталь исчезнет
 return p
end
local function tw(o,t,props,style,dir)
 local x=TS:Create(o,TweenInfo.new(t,style or QD,dir or OUT),props);x:Play();return x
end
local function kill(o,t) Debris:AddItem(o,t) end
local function camDist(pos) local c=workspace.CurrentCamera;return c and (c.CFrame.Position-pos).Magnitude or 0 end
local function myRoot() local c=lp.Character;return c and c:FindFirstChild('HumanoidRootPart') end
local function nearMe(pos,r) local m=myRoot();return m~=nil and (m.Position-pos).Magnitude<=r end
-- CFrame, у которого ось +Y смотрит в сторону dir (удобно для колец и эмиттеров)
local function facing(pos,dir) return CFrame.lookAt(pos,pos+dir)*CFrame.Angles(-pi/2,0,0) end
local rp=RaycastParams.new();rp.FilterType=Enum.RaycastFilterType.Include
local function groundAt(pos)
 local yard=workspace:FindFirstChild('StreetCourtyard')
 if yard then
  rp.FilterDescendantsInstances={yard}
  local r=workspace:Raycast(pos+V3(0,.5,0),V3(0,-60,0),rp)
  if r and r.Position.Y<pos.Y+1 then return r.Position.Y end
 end
 return pos.Y-2.9
end

-- «Ручные» частицы: один общий цикл на всех, с ограничением количества
local sims={}
local function canSim(n) return #sims+(n or 1)<=MAXSIM end
local function addSim(fn) sims[#sims+1]=fn end
RunService.RenderStepped:Connect(function(dt)
 dt=math.min(dt,.05)
 local i=1
 while i<=#sims do
  local ok,done=pcall(sims[i],dt)
  if (not ok) or done then sims[i]=sims[#sims];sims[#sims]=nil else i+=1 end
 end
end)

-- ===== Экранные эффекты и камера =====
local cc=Instance.new('ColorCorrectionEffect');cc.Name='StreetFX_CC';cc.Parent=Lighting
local blur=Instance.new('BlurEffect');blur.Name='StreetFX_Blur';blur.Size=0;blur.Parent=Lighting
local function ccPulse(b,c,s,tint,t)
 cc.Brightness=b;cc.Contrast=c;cc.Saturation=s;cc.TintColor=tint or WHITE
 tw(cc,t,{Brightness=0,Contrast=0,Saturation=0,TintColor=WHITE},QD,OUT)
end
local function blurPulse(sz,t) blur.Size=math.max(blur.Size,sz);tw(blur,t,{Size=0},QD,OUT) end

local pg=lp:WaitForChild('PlayerGui')
local gui=Instance.new('ScreenGui');gui.Name='StreetVFXGui';gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true;gui.DisplayOrder=3;gui.Parent=pg
local vig={}
local function mkEdge(pos,size,rot)
 local f=Instance.new('Frame');f.BorderSizePixel=0;f.BackgroundColor3=WHITE;f.BackgroundTransparency=1;f.Position=pos;f.Size=size;f.Active=false;f.Parent=gui
 local g=Instance.new('UIGradient');g.Rotation=rot;g.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)});g.Parent=f
 vig[#vig+1]=f
end
mkEdge(UDim2.fromScale(0,0),UDim2.fromScale(1,.32),90);mkEdge(UDim2.fromScale(0,.68),UDim2.fromScale(1,.32),-90)
mkEdge(UDim2.fromScale(0,0),UDim2.fromScale(.22,1),0);mkEdge(UDim2.fromScale(.78,0),UDim2.fromScale(.22,1),180)
local function vignette(color,power,t) -- цветная кайма по краям экрана
 for _,f in ipairs(vig) do f.BackgroundColor3=color;f.BackgroundTransparency=1-power;tw(f,t,{BackgroundTransparency=1},QD,OUT) end
end
local lines={}
local lineBox=Instance.new('Frame');lineBox.BackgroundTransparency=1;lineBox.Size=UDim2.fromScale(1,1);lineBox.Active=false;lineBox.Parent=gui
for i=1,mobile and 14 or 24 do
 local f=Instance.new('Frame');f.BorderSizePixel=0;f.BackgroundColor3=WHITE;f.BackgroundTransparency=1;f.AnchorPoint=Vector2.new(.5,.5);f.Position=UDim2.fromScale(.5,.5);f.Active=false;f.Parent=lineBox
 local g=Instance.new('UIGradient');g.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.3,1),NumberSequenceKeypoint.new(.7,1),NumberSequenceKeypoint.new(1,0)});g.Parent=f
 lines[#lines+1]=f
end
local function speedlines(power,t,color) -- скоростные линии от краёв экрана к центру
 for _,f in ipairs(lines) do
  f.Size=UDim2.new(1.6,0,0,rnd(2,5));f.Rotation=R(0,180);f.BackgroundColor3=color or WHITE
  f.BackgroundTransparency=1-power*R(.5,1);tw(f,t,{BackgroundTransparency=1},QD,OUT)
 end
end

local trauma,fovKick,applied,baseFov=0,0,0,70
local function addTrauma(m) trauma=math.min(1,trauma+m) end
local punch=Vector3.zero -- v2.1: угловой «толчок» камеры (pitch,yaw,roll в радианах), быстро затухает
local function camPunch(v) punch=punch+v;if punch.Magnitude>.12 then punch=punch.Unit*.12 end end
local function kick(f) if math.abs(f)>math.abs(fovKick) then fovKick=f end end
RunService:BindToRenderStep('StreetVFXCam',Enum.RenderPriority.Camera.Value+1,function(dt)
 local c=workspace.CurrentCamera;if not c then return end
 trauma=math.max(0,trauma-dt*1.5)
 fovKick*=math.exp(-dt*7)
 if math.abs(fovKick)<.05 then fovKick=0 end
 if trauma>0 then
  local s=trauma*trauma;local t=os.clock()
  c.CFrame=c.CFrame*CF(math.noise(t*38,1)*s*.9,math.noise(t*38,2)*s*.9,0)*CFrame.Angles(math.noise(t*30,3)*s*.05,math.noise(t*30,4)*s*.05,math.noise(t*26,5)*s*.07)
 end
 punch=punch:Lerp(Vector3.zero,math.min(1,dt*12))
if punch.Magnitude>.0005 then c.CFrame=c.CFrame*CFrame.Angles(punch.X,punch.Y,punch.Z) end
if fovKick~=0 or applied~=0 then c.FieldOfView=baseFov+fovKick;applied=fovKick else baseFov=c.FieldOfView end
end)

-- ===== Эффекты-примитивы =====
-- Частицы (ParticleEmitter): один выброс. Дым/свечение/струи пыли. o.dir — направление струи.
local function puff(pos,o)
 local ep=Instance.new('Part');ep.Anchored=true;ep.CanCollide=false;ep.CanQuery=false;ep.CanTouch=false;ep.Transparency=1;ep.Size=V3(.2,.2,.2)
 ep.CFrame=o.dir and facing(pos,o.dir) or CF(pos);ep.Parent=fold;kill(ep,(o.life or 1)+.4)
 local e=Instance.new('ParticleEmitter')
 e.Texture=o.tex or T_SMOKE;e.Rate=0
 e.Color=ColorSequence.new(o.color,o.c1 or o.color)
 e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,o.s0 or 1),NumberSequenceKeypoint.new(1,o.s1 or 3)})
 e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,o.a0 or .35),NumberSequenceKeypoint.new(.55,o.a1 or .65),NumberSequenceKeypoint.new(1,1)})
 e.Lifetime=NumberRange.new((o.life or 1)*.7,o.life or 1)
 e.Speed=NumberRange.new(o.v0 or 0,o.v1 or 0)
 e.SpreadAngle=Vector2.new(o.spread or 180,o.spread or 180)
 e.Acceleration=o.acc or V3(0,0,0);e.Drag=o.drag or 0
 e.LightEmission=o.glow or 0;e.LightInfluence=o.lit or 1
 e.Rotation=NumberRange.new(0,360);e.RotSpeed=NumberRange.new(-70,70)
 e.Parent=ep
 e:Emit(o.exact and o.n or N(o.n or 6))
end
local function glow(pos,color,size,t) -- мягкое светящееся пятно (как bloom)
 puff(pos,{color=color,n=1,exact=true,s0=size*.5,s1=size,life=t,glow=1,lit=0,a0=.2,a1=.5})
end
local function flash(pos,color,size,t,light) -- яркая вспышка-шар + короткий свет
 local p=mkPart(BALL,V3(size*.3,size*.3,size*.3),color,0,CF(pos),nil,t+.3)
 tw(p,t,{Size=V3(size,size,size),Transparency=1},QD,OUT)
 if light then local l=Instance.new('PointLight');l.Color=color;l.Range=size*3+10;l.Brightness=4;l.Parent=p;tw(l,t*1.4,{Brightness=0},QD,OUT) end
end
local function bubble(pos,color,r0,r1,t,transp) -- расходящаяся полупрозрачная сфера (ударная волна)
 local p=mkPart(BALL,V3(r0*2,r0*2,r0*2),color,transp or .6,CF(pos),nil,t+.3)
 tw(p,t,{Size=V3(r1*2,r1*2,r1*2),Transparency=1},QD,OUT)
end
local function star(pos,color,size,t,blades) -- «звезда» удара: лучи в плоскости к камере
 local c=workspace.CurrentCamera;local look=c and c.CFrame.LookVector or V3(0,0,-1)
 local base=CFrame.lookAt(pos,pos+look);blades=blades or 3;local a0=R(0,pi)
 for i=1,blades do
  local len=size*R(.8,1.25)
  local p=mkPart(nil,V3(len*.35,.2,.2),color,0,base*CFrame.Angles(0,0,a0+(i-1)*pi/blades),nil,t+.3)
  tw(p,t,{Size=V3(len*1.5,.04,.04),Transparency=1},QT,OUT)
 end
end
-- Искры-штрихи: тонкие светящиеся полоски, летят по дуге, тянутся по скорости
local function sparks(pos,dir,color,n,speed,spread,life,len)
 n=N(n);n=math.min(n,MAXSIM-#sims);if n<=0 then return end
 for i=1,n do
  local d=dir and (dir+V3(R(-1,1),R(-.3,1),R(-1,1))*spread) or V3(R(-1,1),R(-.2,1),R(-1,1))
  if d.Magnitude<.01 then d=V3(0,1,0) end
  d=d.Unit
  local v=d*R(speed*.45,speed);local L=life*R(.7,1.2);local ln=len or 1.2
  local p=mkPart(nil,V3(.14,.14,ln),color,0,CF(pos,pos+d),nil,L+.5)
  local pp=pos;local el=0
  addSim(function(dt)
   el+=dt
   if el>=L then p:Destroy();return true end
   v=v*(1-math.min(1,dt*2.4))+V3(0,-30*dt,0);pp=pp+v*dt
   local sp=v.Magnitude
   p.CFrame=sp>.2 and CF(pp,pp+v) or CF(pp)
   local k=1-el/L;local th=math.max(.05,.14*k)
   p.Size=V3(th,th,math.max(.1,math.min(ln*2.2,sp*.04))*(.4+.6*k))
   p.Transparency=(1-k)^2
   return false
  end)
 end
end
-- Кольцо-ударная волна из светящихся сегментов (лежит в плоскости XZ у cf; для вертикального — facing(pos,dir))
local function ring(cf,color,r0,r1,t,width,segs)
 segs=math.max(10,N(segs or 20));if not canSim(1) then return end
 local parts={}
 for i=1,segs do parts[i]=mkPart(nil,V3(width,width*.6,1),color,0,cf,nil,t+.5) end
 local el=0
 addSim(function(dt)
  el+=dt;local k=clamp(el/t,0,1)
  if k>=1 then for _,p in ipairs(parts) do p:Destroy() end return true end
  local r=r0+(r1-r0)*(1-(1-k)^3);local seg=2*pi*r/segs*1.3;local th=width*(1-k*.75);local tr=k^1.6
  for i,p in ipairs(parts) do
   local a=(i-1)/segs*2*pi
   local wp=cf*V3(cos(a)*r,0,sin(a)*r)
   p.Size=V3(th,th*.6,seg);p.CFrame=CF(wp,wp+cf:VectorToWorldSpace(V3(-sin(a),0,cos(a))));p.Transparency=tr
  end
  return false
 end)
end
-- Осколки/камни: летят, отскакивают от земли, мигают и исчезают
local function debris(pos,color,n,power,mat)
 n=N(n);n=math.min(n,MAXSIM-#sims);if n<=0 then return end
 local gy=groundAt(pos)
 for i=1,n do
  local a=R(0,2*pi);local sp=R(.35,1)*power
  local v=V3(cos(a)*sp,R(.5,1.1)*power*.9,sin(a)*sp);local sz=R(.25,.65)
  local p=mkPart(nil,V3(sz,sz*R(.6,1.1),sz*R(.7,1.2)),color,0,CF(pos.X,gy+.3,pos.Z),mat or Enum.Material.Slate,3)
  local pp=V3(pos.X,gy+.3,pos.Z);local rot=CFrame.Angles(R(0,6),R(0,6),R(0,6));local spin=V3(R(-9,9),R(-9,9),R(-9,9))
  local el,life,bounces=0,R(.9,1.4),0
  addSim(function(dt)
   el+=dt
   if el>=life then p:Destroy();return true end
   v=v+V3(0,-70*dt,0);pp=pp+v*dt
   if pp.Y<gy+.2 then
    pp=V3(pp.X,gy+.2,pp.Z)
    if bounces<2 then v=V3(v.X*.55,-v.Y*.35,v.Z*.55);bounces+=1 else v=V3(0,0,0) end
   end
   rot=rot*CFrame.Angles(spin.X*dt,spin.Y*dt,spin.Z*dt);p.CFrame=CF(pp)*rot
   if el>life-.3 then p.Transparency=1-(life-el)/.3 end
   return false
  end)
 end
end
-- Пыль: струи дыма по кругу от центра
local function dustRing(gp,r,n,color)
 for i=1,N(n) do
  local a=i/N(n)*2*pi+R(-.2,.2);local out=V3(cos(a),0,sin(a))
  puff(gp+out*r+V3(0,.4,0),{color=color or C3(176,170,160),dir=(out+V3(0,.35,0)).Unit,n=3,s0=1.6,s1=5,life=.9,v0=6,v1=13,spread=22,drag=3,acc=V3(0,2,0),a0=.5,a1=.75})
 end
end
-- Трещины на земле: светящиеся линии от центра
local function cracks(gp,color,len,n,t)
 for i=1,N(n) do
  local a=R(0,2*pi);local l=len*R(.45,1);local d=V3(cos(a),0,sin(a))
  local c=gp+d*l*.5+V3(0,.12,0)
  local p=mkPart(nil,V3(.28,.06,l),color,.1,CF(c,c+d),nil,t+.4)
  tw(p,t,{Transparency=1,Size=V3(.08,.04,l*1.1)},QD,OUT)
 end
end
-- Вертикальный световой столб (ульт)
local function pillar(gp,th,t)
 local p=mkPart(Enum.PartType.Cylinder,V3(70,9,9),th.main,.25,CF(gp+V3(0,35,0))*CFrame.Angles(0,0,rad(90)),nil,t+.3)
 tw(p,t,{Size=V3(70,.6,.6),Transparency=1},QT,OUT)
 local q=mkPart(Enum.PartType.Cylinder,V3(70,4,4),th.core,.05,CF(gp+V3(0,35,0))*CFrame.Angles(0,0,rad(90)),nil,t+.3)
 tw(q,t*.8,{Size=V3(70,.3,.3),Transparency=1},QT,OUT)
end
-- Afterimage: призрачные копии частей тела
local LIMBS={'Head','Torso','Left Arm','Right Arm','Left Leg','Right Leg'}
local function afterimage(char,th,a0)
 for _,nm in ipairs(LIMBS) do
  local src=char:FindFirstChild(nm)
  if src and src:IsA('BasePart') then
   local g=mkPart(nil,src.Size*1.04,th.main,a0 or .5,src.CFrame,nil,.6)
   tw(g,.34,{Transparency=1,Size=src.Size*.72},QD,OUT)
  end
 end
end


-- ===== v1.5: новые кирпичики =====
-- Bloom: короткий «пульс» свечения на мощных ударах (базовая яркость 0, DayNight его не трогает)
local bloom=Instance.new('BloomEffect');bloom.Name='StreetFX_Bloom';bloom.Intensity=0;bloom.Size=26;bloom.Threshold=.85;bloom.Parent=Lighting
local function bloomPulse(i,t) bloom.Intensity=math.max(bloom.Intensity,i);tw(bloom,t,{Intensity=0},QD,OUT) end
-- Подсветка пострадавшего: тело на мгновение вспыхивает цветом (hit-flash, как в файтингах)
local function nearestChar(pos,r)
 local best,bd=nil,r
 local function try(ch)
  local hr=ch and ch:FindFirstChild('HumanoidRootPart')
  if hr then local d=(hr.Position-pos).Magnitude;if d<bd then best,bd=ch,d end end
 end
 for _,p in ipairs(Players:GetPlayers()) do try(p.Character) end
 for _,m in ipairs(workspace:GetChildren()) do if m:IsA('Model') and (m.Name=='dummy' or m.Name=='block_dummy') then try(m) end end
 return best
end
local flashing=setmetatable({},{__mode='k'})
local function flashChar(ch,color,t,fill)
 if not ch or flashing[ch] then return end
 flashing[ch]=true
 local h=Instance.new('Highlight');h.FillColor=color;h.FillTransparency=fill or .25;h.OutlineColor=WHITE;h.OutlineTransparency=.15;h.Parent=ch
 tw(h,t,{FillTransparency=1,OutlineTransparency=1},QD,OUT);kill(h,t+.05)
 task.delay(t,function() flashing[ch]=nil end)
end
-- Молния (ломаная из светящихся сегментов с белой сердцевиной)
local function bolt(a,b,color,t,width)
 local d=b-a;local len=d.Magnitude;if len<.3 then return end
 local u=d.Unit;local up=math.abs(u.Y)>.95 and V3(1,0,0) or V3(0,1,0)
 local side=u:Cross(up).Unit;local up2=side:Cross(u).Unit
 local segs=6;local pts={a};local w=width or .22
 for i=1,segs-1 do local j=len/segs*.9;pts[#pts+1]=a+d*(i/segs)+side*R(-j,j)+up2*R(-j,j) end
 pts[#pts+1]=b
 for i=1,#pts-1 do
  local p0,p1=pts[i],pts[i+1];local L=(p1-p0).Magnitude
  if L>.05 then
   local mid=CF((p0+p1)/2,p1)
   tw(mkPart(nil,V3(w,w,L),color,0,mid,nil,t+.3),t,{Size=V3(.03,.03,L),Transparency=1},QD,OUT)
   tw(mkPart(nil,V3(w*.4,w*.4,L),WHITE,0,mid,nil,t+.3),t*.8,{Size=V3(.02,.02,L),Transparency=1},QD,OUT)
  end
 end
end
local function arcs(pos,color,n,r,t)
 for i=1,N(n) do
  local d=V3(R(-1,1),R(-.4,1),R(-1,1));if d.Magnitude<.1 then d=V3(0,1,0) end
  bolt(pos,pos+d.Unit*r*R(.6,1),color,t or .14,.2)
 end
end
-- Брызги: капли летят по дуге, вытягиваются по скорости, на земле оставляют быстро тающее пятно
local function droplets(pos,dir,color,n,speed,size,mat)
 n=N(n);n=math.min(n,MAXSIM-#sims);if n<=0 then return end
 local gy=groundAt(pos)
 for i=1,n do
  local d=dir and (dir+V3(R(-.7,.7),R(.1,.9),R(-.7,.7))) or V3(R(-1,1),R(.2,1),R(-1,1))
  if d.Magnitude<.05 then d=V3(0,1,0) end
  local v=d.Unit*R(speed*.4,speed);local sz=(size or .35)*R(.6,1.2)
  local p=mkPart(BALL,V3(sz,sz,sz),color,0,CF(pos),mat,2)
  local pp=pos;local el=0;local life=R(.5,.9)
  addSim(function(dt)
   el+=dt
   if el>=life or pp.Y<=gy+.15 then
    if pp.Y<=gy+.3 then
     local sp=mkPart(Enum.PartType.Cylinder,V3(.05,sz*3.2,sz*3.2),color,.25,CF(V3(pp.X,gy+.06,pp.Z))*CFrame.Angles(0,0,rad(90)),mat,1.2)
     tw(sp,.7,{Transparency=1},QD,OUT)
    end
    p:Destroy();return true
   end
   v=v+V3(0,-55*dt,0);pp=pp+v*dt
   p.CFrame=CF(pp,pp+v);p.Size=V3(sz,sz,sz*(1+math.min(3,v.Magnitude*.05)))
   return false
  end)
 end
end
-- Угольки: поднимаются, виляют, остывают от цвета к тёмно-красному
local function embers(pos,color,n,spread,rise,life)
 n=N(n);n=math.min(n,MAXSIM-#sims);if n<=0 then return end
 for i=1,n do
  local sz=R(.14,.34);local p=mkPart(BALL,V3(sz,sz,sz),color,0,CF(pos),nil,(life or 1)+.6)
  local pp=pos+V3(R(-spread,spread),R(-.3,.3),R(-spread,spread));local v=V3(R(-3,3),R(rise*.5,rise),R(-3,3))
  local el=0;local L=(life or 1)*R(.6,1.2);local ph=R(0,6)
  addSim(function(dt)
   el+=dt;if el>=L then p:Destroy();return true end
   v=v+V3(sin(el*5+ph)*dt*22,3*dt,cos(el*4+ph)*dt*22);pp=pp+v*dt
   local k=el/L;local s2=sz*(1-k*.8)
   p.CFrame=CF(pp);p.Size=V3(s2,s2,s2);p.Transparency=k*k;p.Color=color:Lerp(C3(190,40,20),k)
   return false
  end)
 end
end
-- Копоть/вмятина на земле: тёмное пятно с горячей сердцевиной, медленно тает
local function scorch(gp,color,r,t)
 local p=mkPart(Enum.PartType.Cylinder,V3(.05,r*2,r*2),C3(20,18,18),.25,CF(gp+V3(0,.04,0))*CFrame.Angles(0,0,rad(90)),Enum.Material.SmoothPlastic,t+.5)
 tw(p,t,{Transparency=1},SN,INOUT)
 local g=mkPart(Enum.PartType.Cylinder,V3(.06,r*1.3,r*1.3),color,.3,CF(gp+V3(0,.05,0))*CFrame.Angles(0,0,rad(90)),nil,t+.5)
 tw(g,t*.4,{Transparency=1},QD,OUT)
end
-- Волны воздуха вдоль направления (конус от удара/рывка)
local function windRings(pos,dir,color,n,t)
 for i=1,n do
  task.delay((i-1)*.035,function() ring(facing(pos+dir*(i*1.5),dir),color,.4,2.6+i*.9,t or .24,.26,14) end)
 end
end

-- ===== Удары (событие FX) =====
local IMP={}
IMP.Hit=function(p,dir,th,pw)
 flash(p,th.core,3*pw,.12,false);glow(p,th.main,5*pw,.2);star(p,th.main,4.5*pw,.17,3)
 sparks(p,dir,th.main,11*pw,46,.9,.38,1.3);sparks(p,dir,th.core,5,62,.5,.26,1.9)
 puff(p,{color=GRAY,n=4,s0=1.1,s1=3.4,life=.55,v0=3,v1=9,a0=.55,a1=.8,drag=3})
 if dir then ring(facing(p,dir),th.main,.5,4.6*pw,.22,.3,14) end
end
IMP.Heavy=function(p,dir,th,pw,gp)
 IMP.Hit(p,dir,th,pw*1.25)
 flash(p,th.core,6,.18,true);glow(p,th.main,9,.3)
 if dir then ring(facing(p,dir),th.core,.8,9,.34,.65,22) end
 ring(CF(gp+V3(0,.15,0)),th.main,1,7,.3,.4,18)
 dustRing(gp,1.5,6);debris(gp,GRAY,5,18);scorch(gp,th.main,3.2,1.1)
 if nearMe(gp,16) then blurPulse(6,.2);kick(5);vignette(th.main,.28,.3);bloomPulse(.5,.25) end
end
IMP.Slam=function(p,dir,th,pw,gp)
 flash(p,WHITE,9,.22,true);glow(p,th.main,14,.4);star(p,th.main,9,.22,4)
 sparks(p,nil,th.main,20,60,1,.5,1.8);sparks(p,nil,th.core,8,80,1,.35,2.4)
 ring(CF(gp+V3(0,.15,0)),th.main,1,16,.5,.9,26);ring(CF(gp+V3(0,.2,0)),th.core,1,10,.4,.5,20)
 bubble(p,th.main,1.5,11,.35,.7)
 dustRing(gp,2.5,10);debris(gp,GRAY,9,26);cracks(gp,th.main,10,8,.9);scorch(gp,th.main,6,1.8);windRings(p,V3(0,1,0),th.core,3,.3)
 if nearMe(gp,26) then ccPulse(.1,.25,-.25,th.core,.35);blurPulse(9,.28);kick(8);vignette(th.main,.4,.4);bloomPulse(.9,.4) end
end
IMP.Break=function(p,dir,th,pw,gp)
 local red=C3(255,70,60)
 flash(p,WHITE,6,.16,true);glow(p,red,9,.3);star(p,red,8,.22,6)
 sparks(p,nil,red,18,56,1,.5,1.6);sparks(p,dir,WHITE,8,70,.5,.3,2)
 if dir then ring(facing(p,dir),red,.8,9,.36,.7,22) end
 bubble(p,red,1,7,.28,.55);dustRing(gp,1.5,6,C3(190,150,150))
 if nearMe(gp,16) then ccPulse(.05,.3,-.3,C3(255,170,160),.3);kick(6);vignette(red,.4,.35);bloomPulse(.6,.3) end
end
IMP.Guard=function(p,dir,th,pw,gp)
 local blue=C3(90,185,255)
 flash(p,WHITE,3,.1,false);glow(p,blue,6,.25);star(p,WHITE,4,.14,3)
 bubble(p+(dir or V3(0,0,0))*.8,blue,1.4,4.2,.22,.5)
 if dir then ring(facing(p+dir*.8,dir),blue,.5,5,.25,.3,16) end
 sparks(p,dir and -dir or nil,blue,9,48,.9,.3,1.3);sparks(p,dir and -dir or nil,WHITE,4,60,.5,.2,1.6)
end
IMP.Dash=function(p,dir,th,pw,gp) -- уклон
 glow(p,th.core,5,.25)
 ring(CF(p),th.core,1,6,.35,.3,16);ring(CF(gp+V3(0,.2,0)),th.main,1,5,.3,.25,14)
 puff(gp+V3(0,.4,0),{color=C3(190,186,178),n=6,s0=1.4,s1=4,life=.7,v0=3,v1=10,drag=3,a0=.5,a1=.75})
 sparks(p,dir and -dir or nil,th.core,8,46,.7,.3,2.2)
end
IMP.Shot=function(p,dir,th)
 flash(p,C3(255,232,160),4,.1,true);star(p,C3(255,244,200),7,.12,4)
 puff(p,{color=C3(120,118,116),n=5,s0=1,s1=3.4,life=.8,v0=3,v1=7,drag=2,a0=.5,a1=.8});sparks(p,nil,C3(255,220,120),6,50,1,.25,1.4)
end
IMP.Counter=function(p,dir,th,pw,gp)
 flash(p,WHITE,8,.2,true);glow(p,th.core,12,.35);star(p,th.core,8,.22,6)
 ring(CF(p),th.core,1.5,12,.45,.5,22);ring(CF(gp+V3(0,.2,0)),th.main,1,9,.4,.4,18)
 sparks(p,nil,th.core,14,60,1,.4,1.8)
 if nearMe(gp,18) then ccPulse(.12,.5,-.7,WHITE,.35);kick(-5);vignette(th.core,.3,.3);bloomPulse(.8,.4) end
end
IMP.Down=function(p,dir,th,pw,gp)
 dustRing(gp,1.4,6);debris(gp,GRAY,3,12);ring(CF(gp+V3(0,.15,0)),GRAY,.8,5,.35,.3,14)
end
IMP.Bleed=function(p) -- v2.1: капли крови у того, кто кровоточит
droplets(p+V3(R(-.4,.4),R(-.2,.6),R(-.4,.4)),V3(0,-.3,0),C3(150,12,16),3,7,.2,Enum.Material.SmoothPlastic)
end
IMP.Spark=function(p,dir,th)
 flash(p,C3(255,225,150),2,.1,false);sparks(p,nil,C3(255,210,120),7,36,1,.3,1)
 puff(p,{color=GRAY,n=3,s0=.8,s1=2.4,life=.5,v0=2,v1=5,a0=.55,a1=.8})
end

-- Фирменная «начинка» ударов каждого бойца (поверх общего эффекта)
local FLAVOR={}
FLAVOR.Siply=function(p,dir,th,pw,gp,big) -- металл кастета: длинные белые искры-рикошеты
 sparks(p,dir,C3(236,242,255),big and 12 or 6,90,.35,.38,2.6);if big then ring(CF(p),C3(236,242,255),.4,3.5,.2,.2,12) end
end
FLAVOR.Diesel=function(p,dir,th,pw,gp,big) -- жар: угольки и оранжевый отсвет
 embers(p,th.main,big and 14 or 6,1,8,.9);glow(p,th.alt,big and 8 or 5,.22)
end
FLAVOR.Bitok=function(p,dir,th,pw,gp,big) -- дерево и пыль: щепки
 sparks(p,dir,C3(214,170,110),big and 10 or 5,70,.6,.45,1.5);puff(p,{color=C3(176,150,120),n=big and 6 or 3,s0=1,s1=3.4,life=.6,v0=3,v1=10,drag=3,a0=.5,a1=.8})
end
FLAVOR.Major=function(p,dir,th,pw,gp,big) -- разряд: короткие молнии сине-красные
 arcs(p,th.main,big and 5 or 2,big and 5 or 3.5,.14);if big then arcs(p,th.alt,2,5.5,.14) end
end
FLAVOR.Yura=function(p,dir,th,pw,gp,big) -- токсичные брызги и ядовитый дымок
 droplets(p,dir,th.main,big and 10 or 5,26,.4,Enum.Material.Neon)
 puff(p,{color=th.alt,n=big and 5 or 3,s0=1,s1=3.2,life=.8,v0=2,v1=6,glow=.5,lit=0,a0=.45,a1=.8,acc=V3(0,3,0)})
end
FLAVOR.Jack=function(p,dir,th,pw,gp,big) -- стекло и пивная пена
 droplets(p,dir,C3(255,196,70),big and 8 or 4,26,.35,Enum.Material.Neon)
 sparks(p,dir,C3(190,245,215),big and 12 or 6,64,.9,.4,1.1)
end
local BIGK={Heavy=true,Slam=true,Break=true}
local FLASHK={Hit=true,Heavy=true,Slam=true,Break=true}
local function impact(d)
 if type(d)~='table' or typeof(d.position)~='Vector3' then return end
 local pos=d.position;if camDist(pos)>FAR then return end
 local f=IMP[d.kind or 'Hit'] or IMP.Hit
 local dir=typeof(d.dir)=='Vector3' and d.dir or nil
 local gp=V3(pos.X,groundAt(pos)+.1,pos.Z)
 local th,pw=theme(d.f),clamp((d.p or 8)/12,.6,2.2);local ip=pos+V3(0,.8,0)
 f(ip,dir,th,pw,gp)
 local kind=d.kind or 'Hit'
 local fl=FLAVOR[d.f]
 if fl and FLASHK[kind] then fl(ip,dir,th,pw,gp,BIGK[kind]==true) end
 if FLASHK[kind] or kind=='Guard' then
  local victim=nearestChar(pos,3)
  if victim then
   if kind=='Guard' then flashChar(victim,C3(90,185,255),.18,.55)
   else flashChar(victim,kind=='Break' and C3(255,70,60) or WHITE,BIGK[kind] and .3 or .16,BIGK[kind] and .1 or .3) end
  end
 end
 if nearMe(pos,14) and (kind=='Hit' or kind=='Heavy') then bloomPulse(kind=='Heavy' and .35 or .15,.15) end
end

-- ===== Шаги эффектов скиллов =====
local STEP={}
local function frontPos(r,f,h) return (r.CFrame*CF(0,h or 0,-(f or 0))).Position end
local function headPos(c) local h=c.char:FindFirstChild('Head');return h and h.Position or c.root.Position+V3(0,1.5,0) end
local function groundPos(r,f) local p=frontPos(r,f,0);return V3(p.X,groundAt(p)+.1,p.Z) end
STEP.charge=function(c,a) -- сбор энергии: частицы стягиваются к руке/груди, шар растёт
 local at=a.at or 'R';local limb=c.char:FindFirstChild(at=='R' and 'Right Arm' or at=='L' and 'Left Arm' or 'Torso')
 if not limb then return end
 local t=a.t or .4;local n=math.min(N(a.n or 12),MAXSIM-#sims);if n<=0 then return end
 local function at_() if at=='T' then return limb.Position end return (limb.CFrame*CF(0,-.9,0)).Position end
 local ball=mkPart(BALL,V3(.4,.4,.4),c.th.core,.15,CF(at_()),nil,t+.5)
 local l=Instance.new('PointLight');l.Color=c.th.main;l.Range=14;l.Brightness=0;l.Parent=ball
 local items={}
 for i=1,n do
  local o=V3(R(-1,1),R(-1,1),R(-1,1));if o.Magnitude<.1 then o=V3(0,1,0) end
  items[i]={p=mkPart(nil,V3(.16,.16,.16),i%2==0 and c.th.main or c.th.core,0,CF(at_()),nil,t+.5),o=o.Unit*R(3,5.5),d=R(0,.35)}
 end
 local el=0
 addSim(function(dt)
  el+=dt;local k=clamp(el/t,0,1);local base=at_()
  if k>=1 then ball:Destroy();for _,it in ipairs(items) do it.p:Destroy() end return true end
  local s=.4+k*k*2.4;ball.Size=V3(s,s,s);ball.CFrame=CF(base);l.Brightness=k*3
  for _,it in ipairs(items) do
   local kk=clamp((k-it.d)/(1-it.d),0,1);local pos=base+it.o*(1-kk*kk)
   it.p.CFrame=CF(pos,base);it.p.Size=V3(.14,.14,.3+.9*kk);it.p.Transparency=kk>.9 and (kk-.9)*10 or 0
  end
  return false
 end)
end
STEP.slash=function(c,a) -- дуга удара: светящийся шлейф вдоль траектории
 local r=c.root;local radius=a.r or 6;local a0,a1=rad(a.a0 or 60),rad(a.a1 or -60);local tilt=rad(a.tilt or 0)
 local h=a.h or .3;local dur=a.t or .14;local w=a.w or 2
 local col=a.col=='core' and c.th.core or c.th.main
 local p=mkPart(nil,V3(.2,.2,.2),WHITE,1,r.CFrame,nil,dur+1)
 local function trail(wid,color,life,widthMul)
  local x0=Instance.new('Attachment');x0.Position=V3(0,wid/2,0);x0.Parent=p
  local x1=Instance.new('Attachment');x1.Position=V3(0,-wid/2,0);x1.Parent=p
  local t=Instance.new('Trail');t.Attachment0=x0;t.Attachment1=x1;t.Lifetime=life;t.MinLength=0;t.LightEmission=1;t.FaceCamera=false
  t.Color=ColorSequence.new(color,color:Lerp(WHITE,.5));t.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.05),NumberSequenceKeypoint.new(.6,.4),NumberSequenceKeypoint.new(1,1)})
  t.WidthScale=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,.1*widthMul)});t.Parent=p
 end
 trail(w,col,.3,1);trail(w*.35,WHITE,.22,1)
 local el=0;local last
 addSim(function(dt)
  if not r.Parent then p:Destroy();return true end
  el+=dt;local k=clamp(el/dur,0,1);local ang=a0+(a1-a0)*(1-(1-k)^1.6)
  p.CFrame=r.CFrame*CF(0,h,0)*CFrame.Angles(0,0,tilt)*CF(sin(ang)*radius,0,-cos(ang)*radius)
  last=p.Position
  if k>=1 then
   sparks(last,r.CFrame.LookVector,col,5,34,1,.3,1.1)
   puff(last,{color=WHITE,n=3,s0=1,s1=3,life=.4,v0=1,v1=4,a0=.6,a1=.85,drag=3,glow=.3})
   kill(p,.5);return true
  end
  return false
 end)
end
STEP.burst=function(c,a)
 local pos=frontPos(c.root,a.f or 4,a.h or .2);local s=a.s or 3
 flash(pos,c.th.core,s*1.3,.13,false);star(pos,c.th.main,s*1.8,.15,3)
 sparks(pos,c.root.CFrame.LookVector,c.th.main,7,38,1,.3,1.1)
end
STEP.ground=function(c,a)
 local gp=groundPos(c.root,a.f or 4);local r=a.r or 6
 ring(CF(gp+V3(0,.05,0)),c.th.main,1,r,.36,.55,20);dustRing(gp,r*.3,8);debris(gp,GRAY,5,14+r);cracks(gp,c.th.main,r*.9,7,.5)
scorch(gp,c.th.main,r*.55,1.1)
 if nearMe(gp,22) then addTrauma(.16);kick(3) end
end
STEP.dustcloud=function(c,a)
 local pos=frontPos(c.root,a.f or 4,.2);local look=c.root.CFrame.LookVector
 local col=a.col=='main' and c.th.main or c.th.alt;local s=a.s or 1
 puff(pos,{color=col,c1=col:Lerp(WHITE,.25),dir=look,n=14,s0=2*s,s1=8*s,life=1.1,v0=8,v1=20,spread=28,drag=2.2,a0=.35,a1=.7})
 puff(pos,{color=col,dir=look,n=6,s0=1*s,s1=4*s,life=.6,v0=14,v1=26,spread=14,drag=2.5,glow=.5,lit=0,a0=.3,a1=.7})
end
STEP.muzzle=function(c,a)
 local pos=frontPos(c.root,a.f or 3,a.h or .4);local look=c.root.CFrame.LookVector
 flash(pos,C3(255,232,160),4,.1,true);star(pos,C3(255,244,200),7,.12,4)
 sparks(pos,look,C3(255,222,130),10,76,.35,.25,2);puff(pos,{color=C3(130,128,126),dir=look,n=5,s0=.8,s1=3,life=.8,v0=5,v1=12,spread=20,drag=2.5})
end
STEP.throw=function(c,a)
 local pos=frontPos(c.root,a.f or 3,.8);local look=c.root.CFrame.LookVector
 flash(pos,c.th.core,2.2,.1,false);sparks(pos,look,c.th.main,6,40,.5,.25,1.4)
 puff(pos,{color=WHITE,dir=look,n=4,s0=.8,s1=2.4,life=.45,v0=6,v1=12,spread=12,drag=3,glow=.3,a0=.5,a1=.8})
end
STEP.aura=function(c,a)
 local t=a.t or .5
 local h=Instance.new('Highlight');h.FillColor=c.th.main;h.FillTransparency=.55;h.OutlineColor=c.th.core;h.OutlineTransparency=0;h.Parent=c.char
 tw(h,t,{FillTransparency=1,OutlineTransparency=1},SN,OUT);kill(h,t+.1)
end
STEP.slide=function(c,a) -- пыль и искры из-под ног, пока тело скользит/шагает
 local t=a.t or .25;local el,nxt=0,0
 addSim(function(dt)
  if not c.root.Parent then return true end
  el+=dt;nxt-=dt
  if nxt<=0 then
   nxt=.05;local pos=c.root.Position;local gp=V3(pos.X,groundAt(pos)+.3,pos.Z)
   puff(gp,{color=C3(190,186,178),n=2,s0=1,s1=3,life=.55,v0=2,v1=6,drag=3,a0=.5,a1=.8,acc=V3(0,2,0)})
   if a.spark then sparks(gp,-c.root.CFrame.LookVector,c.th.core,2,34,.6,.2,1.2) end
  end
  return el>=t
 end)
end
STEP.embers=function(c,a) local pos=frontPos(c.root,a.f or 3,a.h or .5);embers(pos,c.th.main,a.n or 8,1.5,9,1);glow(pos,c.th.alt,6,.25) end
STEP.arcs=function(c,a) local pos=frontPos(c.root,a.f or 3,a.h or .5);arcs(pos,a.col=='alt' and c.th.alt or c.th.main,a.n or 4,a.r or 5,.15) end
STEP.splash=function(c,a)
 local pos=frontPos(c.root,a.f or 4,.9);local look=c.root.CFrame.LookVector
 local col=a.amber and C3(255,196,70) or c.th.main
 droplets(pos,look,col,a.n or 14,34,.42,Enum.Material.Neon)
 puff(pos,{color=col,dir=look,n=5,s0=1,s1=3,life=.6,v0=6,v1=14,spread=20,drag=3,glow=.4,lit=0,a0=.4,a1=.8})
end
STEP.wind=function(c,a) windRings(frontPos(c.root,a.f or 2,.6),c.root.CFrame.LookVector,c.th.core,a.n or 3,.24) end
STEP.pulse=function(c,a) -- контр-стойка: кольца и призрак
 local pos=c.root.Position;local r=a.r or 5;local col=a.col=='main' and c.th.main or c.th.core
 ring(CF(pos),col,1.5,r,.5,.35,18);ring(CF(pos-V3(0,2.2,0)),c.th.main,1,r*.8,.45,.3,16)
 afterimage(c.char,c.th,.6);STEP.aura(c,{t=.6})
end

-- v2.1: мелкие детали скиллов
STEP.fear=function(c,a) -- предупредительный выстрел: ударная волна страха, сине-красные вспышки (мигалка)
local pos=c.root.Position;local gp=V3(pos.X,groundAt(pos)+.1,pos.Z)
ring(CF(gp),C3(255,70,70),1,a.r or 14,.5,.4,24);ring(CF(gp+V3(0,.1,0)),C3(80,140,255),1,(a.r or 14)*.75,.45,.3,20)
for i=0,3 do task.delay(i*.09,function() if c.root.Parent then flash(c.root.Position+V3(0,4.5,0),i%2==0 and C3(255,60,60) or C3(70,130,255),3,.08,true) end end) end
if nearMe(pos,20) then addTrauma(.25);kick(4) end
end
STEP.handglow=function(c,a) -- свечение предмета в руке (экран телефона, кастет)
local arm=c.char:FindFirstChild('Right Arm');if not arm then return end
local col=a.col or C3(120,200,255);local t=a.t or .5;local el,nxt=0,0
addSim(function(dt)
if not arm.Parent then return true end
el+=dt;nxt-=dt
if nxt<=0 then nxt=.12;local p=(arm.CFrame*CF(0,-1.3,-.3)).Position;glow(p,col,2.4,.18);if el<.2 then ring(facing(p,arm.CFrame.LookVector),col,.2,1.6,.2,.08,10) end end
return el>=t
end)
end
STEP.breath=function(c,a) -- перегар/отрыжка: зелёное облако изо рта
local hp=headPos(c);local look=c.root.CFrame.LookVector
local s=a.big and 1.8 or 1
puff(hp+look*.8,{color=C3(130,170,60),c1=C3(170,190,90),dir=look,n=a.big and 14 or 7,s0=1*s,s1=4.5*s,life=1.2,v0=4,v1=11*s,spread=a.big and 60 or 25,drag=2.4,glow=.3,lit=0,a0=.35,a1=.7,acc=V3(0,1.5,0)})
if a.big then ring(facing(hp+look,look),C3(150,200,70),.5,6,.35,.3,16) end
end
STEP.foam=function(c,a) -- пивная пена: белые хлопья и капли
local pos=frontPos(c.root,a.f or 4,.9);local look=c.root.CFrame.LookVector
puff(pos,{color=C3(250,246,232),dir=look,n=8,s0=.6,s1=2.2,life=.7,v0=6,v1=16,spread=30,drag=3,a0=.15,a1=.6,acc=V3(0,-6,0)})
droplets(pos,look,C3(255,250,235),6,22,.25,Enum.Material.SmoothPlastic)
end
STEP.headbutt=function(c,a) -- удар лбом: вспышка на уровне головы и «звёздочки»
local pos=frontPos(c.root,a.f or 2.6,1.5)
flash(pos,c.th.core,2.6,.12,false);star(pos,C3(255,240,140),3.5,.2,5)
for i=1,3 do local ang=R(0,2*pi);sparks(pos+V3(cos(ang)*.6,.6,sin(ang)*.6),V3(0,1,0),C3(255,235,120),1,10,.6,.5,.5) end
if c.me then addTrauma(.18) end
end

-- Эффекты каждого скилла: {через сколько сек, шаг, параметры}. Времена совпадают с ударами на сервере.
-- Шаги: charge (сбор энергии), slash (дуга), burst (вспышка), ground (удар в землю), dustcloud (облако), muzzle (выстрел), throw, pulse, aura.
local CAST={
 Siply={
  Z={{0,'charge',{at='R',t=.4,n=10}},{0,'slide',{t=.22}},{.4,'slide',{t=.15,spark=true}},{.4,'slash',{r=6.5,a0=70,a1=-45,tilt=18,h=.4,t=.15,w=2.4}},{.4,'wind',{f=2,n=4}},{.46,'ground',{f=4.5,r=7}}},
  X={{0,'wind',{f=1.5,n=3}},{.1,'slash',{r=5,a0=-25,a1=25,tilt=-12,h=.3,t=.07,w=1.2,col='core'}},{.14,'burst',{f=4.5,s=2}},{.2,'slide',{t=.14}}},
  C={{0,'handglow',{col=C3(120,200,255),t=.55}},{0,'slide',{t=.22,spark=true}},{0,'wind',{f=2,n=5}},{.22,'burst',{f=3.5,s=3.5}},{.55,'slide',{t=.2}}},
  V={{0,'charge',{at='R',t=.24,n=6}},{.24,'slash',{r=6,a0=-70,a1=75,tilt=90,h=.2,t=.12,w=2.4}},{.26,'slide',{t=.14}},{.3,'burst',{f=3.5,h=2,s=3}}},
 },
 Diesel={
  Z={{0,'slide',{t=.2,spark=true}},{.1,'aura',{t=.5}},{.22,'slash',{r=4.5,a0=-20,a1=15,tilt=0,h=.4,t=.06,w=1.6}},{.4,'slash',{r=5.2,a0=30,a1=-15,tilt=-12,h=.3,t=.08,w=2.2}},{.4,'burst',{f=4.5,s=2.5}},{.4,'embers',{f=4.5,n=8}}},
  X={{0,'pulse',{}},{0,'slide',{t=.26}}},
  C={{0,'slide',{t=.12,spark=true}},{.3,'slash',{r=4.8,a0=-30,a1=30,tilt=0,h=-.6,t=.08,w=2}},{.36,'burst',{f=4,s=3,h=-.5}},{.38,'slide',{t=.18}},{.4,'embers',{f=4,n=8,h=-.4}}},
  V={{0,'charge',{at='R',t=.45,n=14}},{.46,'slash',{r=6.5,a0=75,a1=-35,tilt=90,h=.8,t=.11,w=3}},{.46,'wind',{f=2,n=5}},{.5,'embers',{f=5.5,n=18}},{.52,'ground',{f=5.5,r=8}}},
 },
 Bitok={
  Z={{0,'slide',{t=.2,spark=true}},{.18,'slash',{r=4.5,a0=-40,a1=35,tilt=0,h=.3,t=.07,w=1.8}},{.2,'ground',{f=3,r=4}},{.24,'slide',{t=.16}}},
  X={{0,'slide',{t=.16}},{.2,'dustcloud',{f=5,s=1}}},
  C={{.05,'slide',{t=.14}},{.25,'burst',{f=3.5,s=3}},{.55,'ground',{f=3,r=7}}},
  V={{0,'charge',{at='R',t=.45,n=12}},{.3,'slide',{t=.14}},{.46,'slash',{r=7.5,a0=70,a1=-40,tilt=65,h=1,t=.12,w=3.4}},{.46,'slide',{t=.12,spark=true}},{.52,'ground',{f=6.5,r=9}}},
 },
 Major={
  Z={{0,'wind',{f=1.5,n=3}},{.15,'burst',{f=3,s=2.5}},{.15,'arcs',{f=3,n=3,r=4}},{.2,'slide',{t=.15}}},
  X={{.28,'slide',{t=.12,spark=true}},{.3,'slash',{r=6,a0=60,a1=-40,tilt=35,h=.6,t=.1,w=2.4}},{.38,'arcs',{f=5,n=4,r=5}}},
  C={{0,'slide',{t=.2}},{.25,'burst',{f=3.5,s=3}},{.65,'ground',{f=5,r=7}},{.65,'arcs',{f=5,n=5,r=5,col='alt'}}},
  V={{.3,'muzzle',{f=.6,h=4.3}},{.3,'slide',{t=.12}},{.32,'fear',{r=14}}},
  R={{.1,'muzzle',{f=3,h=.4}}},
 },
 Yura={
  Z={{0,'slide',{t=.2}},{.25,'throw',{}},{.25,'splash',{f=3,n=6}},{.22,'slide',{t=.12}}},
  X={{0,'slide',{t=.2}},{.18,'breath',{}},{.25,'dustcloud',{f=6,s=1.4,col='main'}},{.25,'splash',{f=6,n=10}}},
  C={{0,'slide',{t=.2,spark=true}},{.25,'burst',{f=3.5,s=3}},{.3,'breath',{}},{.7,'breath',{}}},
  V={{0,'charge',{at='R',t=.5,n=10}},{.2,'slide',{t=.2}},{.55,'slash',{r=7.2,a0=80,a1=-60,tilt=-20,h=.5,t=.13,w=3.6}},{.5,'slide',{t=.12}},{.62,'ground',{f=6,r=8}},{.62,'splash',{f=6,n=12}}},
  R={{.2,'pulse',{r=9,col='main'}},{.2,'breath',{big=true}},{.2,'splash',{f=0,n=12}}},
 },
 Jack={
  Z={{0,'slide',{t=.22}},{.25,'dustcloud',{f=5,s=1,col='main'}},{.25,'splash',{f=4.5,n=16,amber=true}},{.27,'foam',{f=4}}},
  X={{0,'pulse',{}},{0,'slide',{t=.25}}},
  C={{.3,'burst',{f=3.5,s=3}},{.4,'slide',{t=.15}},{.6,'headbutt',{}},{.7,'slide',{t=.15}},{.9,'headbutt',{}},{1.2,'headbutt',{}}},
  V={{0,'slide',{t=.18}},{.3,'throw',{}},{.3,'slide',{t=.12}},{.3,'splash',{f=3,n=8,amber=true}}},
 },
}
local function ctxOf(userId,fighter,ult)
 local p=Players:GetPlayerByUserId(userId or 0);local char=p and p.Character;local root=char and char:FindFirstChild('HumanoidRootPart')
 if not root or camDist(root.Position)>FAR then return end
 return {char=char,root=root,th=theme(fighter),ult=ult,f=fighter,me=(p==lp)}
end
local function runSteps(c,list)
 for _,st in ipairs(list) do
  local fn=STEP[st[2]]
  if fn then
   local function go() if c.root.Parent then local ok,err=pcall(fn,c,st[3] or {});if not ok then warn('[VFX] '..st[2]..': '..tostring(err)) end end end
   if st[1]<=0 then go() else task.delay(st[1],go) end
  end
 end
end
local function cast(d)
 local c=ctxOf(d.userId,d.fighter,d.ult);if not c then return end
 local list=CAST[d.fighter] and CAST[d.fighter][d.key]
 if list then runSteps(c,list) end
 if d.ult then STEP.aura(c,{t=.4}) end
 if c.me then kick(2.5);bloomPulse(.2,.2) end
end
-- Обычные удары (M1): быстрый штрих кулака/оружия
local function swing(d)
 local c=ctxOf(d.userId,d.fighter,false);if not c then return end
 local odd=((d.index or 1)%2==1)
 if d.heavy then
  runSteps(c,{{.24,'slash',{r=5.8,a0=60,a1=-40,tilt=20,h=.4,t=.1,w=2.2}},{.3,'ground',{f=4,r=4}}})
 else
  runSteps(c,{{.08,'slash',{r=4.6,a0=odd and -28 or 28,a1=odd and 20 or -20,tilt=odd and 8 or -8,h=.4,t=.06,w=1.1,col='core'}}})
 end
end

-- ===== Рывок =====
local function dashFx(d)
 local c=ctxOf(d.userId,nil,false);if not c then return end
 local p=Players:GetPlayerByUserId(d.userId);local th=theme(p and p:GetAttribute('Fighter'));c.th=th
 local dir=typeof(d.dir)=='Vector3' and d.dir or c.root.CFrame.LookVector
 local speed=d.speed or 60;local dur=d.dur or .15
 local pos=c.root.Position;local gp=V3(pos.X,groundAt(pos)+.1,pos.Z)
 puff(gp+V3(0,.4,0),{color=C3(190,186,178),n=6,s0=1.3,s1=4,life=.7,v0=2,v1=8,drag=3,a0=.5,a1=.75})
 if speed>=45 then
  local n=mobile and 2 or 4
  for i=0,n-1 do task.delay(i*dur/n*.9,function() if c.char.Parent then afterimage(c.char,th,.55) end end) end
  sparks(pos+V3(0,.5,0),-dir,th.core,8,60,.25,.3,2.8)
  task.delay(dur,function()
   if c.root.Parent then local e=c.root.Position;puff(V3(e.X,groundAt(e)+.5,e.Z),{color=C3(190,186,178),dir=-dir+V3(0,.3,0),n=6,s0=1.5,s1=4.5,life=.7,v0=4,v1=11,spread=30,drag=3,a0=.5,a1=.75}) end
  end)
 end
 if c.me and speed>=45 then kick(7);speedlines(.55,.3,th.core) end
end

-- ===== Ульт: старт =====
local function ultStart(d)
 local c=ctxOf(d.userId,d.fighter,true);if not c then return end
 local th=c.th
 STEP.charge(c,{at='T',t=.3,n=22})
 if c.me then kick(-10);speedlines(.5,.5,th.core) end
if c.me or nearMe(c.root.Position,16) then letterbox(math.min(d.dur or 4,6)) end
 task.delay(.3,function()
  if not c.root.Parent then return end
  local pos=c.root.Position;local gp=V3(pos.X,groundAt(pos)+.15,pos.Z)
  flash(pos,WHITE,12,.35,true);glow(pos,th.main,26,.6);bubble(pos,th.main,2,24,.5,.65)
  for i=1,3 do task.delay((i-1)*.1,function() ring(CF(gp),i==2 and th.core or th.main,2,18+i*7,.55+i*.05,1.1,28) end) end
  pillar(gp,th,.8);dustRing(gp,5,10);debris(gp,GRAY,14,34);cracks(gp,th.main,12,14,.9);scorch(gp,th.main,12,3)
  sparks(pos,nil,th.main,30,70,1,.7,2.2);sparks(pos,nil,th.core,12,95,1,.5,2.8)
  if nearMe(pos,40) then impactFrame(th.core);blurPulse(12,.4);kick(14);addTrauma(.55);vignette(th.main,.55,.6);speedlines(.8,.45,th.core);bloomPulse(1.4,.9) end
 end)
end
-- Финальный удар ульта: драматичный «стоп-кадр»
local function finisher(d)
 local c=ctxOf(d.userId,d.fighter,true);if not c then return end
 STEP.charge(c,{at='T',t=.4,n=16})
 if nearMe(c.root.Position,60) then
  ccPulse(-.05,.4,-.9,WHITE,.6);kick(-9);vignette(C3(0,0,0),.65,.6);speedlines(.7,.4,WHITE)
  task.delay(.42,function() impactFrame(WHITE);kick(15);addTrauma(.45);bloomPulse(1.2,.6);camPunch(V3(rad(5),0,rad(R(-4,4)))) end)
 end
end
local function whiff() -- контратака не сработала: короткий КД
 local r=myRoot();if not r then return end
 ring(CF(r.Position-V3(0,2.5,0)),C3(200,210,225),1,5,.3,.2,14)
end

-- ===== Аура ульта (пока активен UltActive) =====
local auras={}
local function auraStop(p) auras[p]=(auras[p] or 0)+1 end
local function auraStart(p)
 local char=p.Character;local torso=char and char:FindFirstChild('Torso');if not torso then return end
 auras[p]=(auras[p] or 0)+1;local tok=auras[p]
 local th=theme(p:GetAttribute('Fighter'))
 local made={}
 local function em(props) local e=Instance.new('ParticleEmitter');for k,v in pairs(props) do e[k]=v end;e.Parent=torso;made[#made+1]=e;return e end
 em({Texture=T_FIRE,Color=ColorSequence.new(th.main,th.alt),LightEmission=1,LightInfluence=0,Rate=30*QUAL,Lifetime=NumberRange.new(.7,1.1),Speed=NumberRange.new(2,5),
  SpreadAngle=Vector2.new(28,28),Acceleration=V3(0,7,0),Rotation=NumberRange.new(0,360),
  Size=NumberSequence.new({NumberSequenceKeypoint.new(0,2.6),NumberSequenceKeypoint.new(1,0)}),
  Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.25),NumberSequenceKeypoint.new(1,1)})})
 em({Texture=T_SPARK,Color=ColorSequence.new(th.core,th.main),LightEmission=1,LightInfluence=0,Rate=16*QUAL,Lifetime=NumberRange.new(.6,1.1),Speed=NumberRange.new(5,12),
  SpreadAngle=Vector2.new(180,180),Acceleration=V3(0,4,0),
  Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.8),NumberSequenceKeypoint.new(1,0)}),
  Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)})})
 local light=Instance.new('PointLight');light.Color=th.main;light.Range=20;light.Brightness=2;light.Parent=torso;made[#made+1]=light
 local hl=Instance.new('Highlight');hl.FillColor=th.main;hl.FillTransparency=.74;hl.OutlineColor=th.core;hl.OutlineTransparency=.15;hl.Parent=char;made[#made+1]=hl
 TS:Create(hl,TweenInfo.new(.7,SN,INOUT,-1,true),{FillTransparency=.88,OutlineTransparency=.45}):Play()
 task.spawn(function()
  local flip=false
  while auras[p]==tok and char.Parent and p:GetAttribute('UltActive') do
   local r=char:FindFirstChild('HumanoidRootPart')
   if r and camDist(r.Position)<FAR then
    local pos=r.Position;local gp=V3(pos.X,groundAt(pos)+.12,pos.Z)
    ring(CF(gp),th.main,1.2,7,.7,.4,18);sparks(gp+V3(0,.5,0),nil,th.main,5,24,1,.5,1.2)
    if p:GetAttribute('Fighter')=='Major' then flip=not flip;local col=flip and th.main or th.alt;light.Color=col;hl.FillColor=col end
   end
   task.wait(.8)
  end
  for _,o in ipairs(made) do if o.Parent then o:Destroy() end end
 end)
end
local function watch(p)
 p:GetAttributeChangedSignal('UltActive'):Connect(function() if p:GetAttribute('UltActive') then auraStart(p) else auraStop(p) end end)
 p.CharacterAdded:Connect(function() auraStop(p) end)
 if p:GetAttribute('UltActive') then auraStart(p) end
end
for _,p in ipairs(Players:GetPlayers()) do watch(p) end
Players.PlayerAdded:Connect(watch)

-- ===== v2.1: камера при ударах, кино-полосы, импакт-кадры, статусы =====
local bars={}
for i=1,2 do
local f=Instance.new('Frame');f.BorderSizePixel=0;f.BackgroundColor3=C3(0,0,0);f.Size=UDim2.new(1,0,0,0);f.Active=false;f.ZIndex=10
f.AnchorPoint=Vector2.new(0,i==1 and 0 or 1);f.Position=UDim2.fromScale(0,i==1 and 0 or 1);f.Parent=gui;bars[i]=f
end
local barTok=0
letterbox=function(t) -- чёрные полосы сверху и снизу на время ульты
barTok+=1;local k=barTok
for _,f in ipairs(bars) do tw(f,.25,{Size=UDim2.new(1,0,.085,0)},QD,OUT) end
task.delay(t,function() if barTok==k then for _,f in ipairs(bars) do tw(f,.35,{Size=UDim2.new(1,0,0,0)},QD,OUT) end end end)
end
impactFrame=function(col) -- аниме-импакт: 2 кадра негатива, затем вспышка
cc.Saturation=-1;cc.Contrast=1.4;cc.Brightness=-.15;cc.TintColor=col or WHITE
task.delay(.05,function() cc.Saturation=-.4;cc.Contrast=-.3;cc.Brightness=.35;cc.TintColor=WHITE;tw(cc,.35,{Brightness=0,Contrast=0,Saturation=0},QD,OUT) end)
end
local function camHit(d)
local mag=clamp(d.mag or .5,.1,2.5);local k=d.kind or 'Hit'
local big=(k=='Heavy' or k=='Slam' or k=='Break')
local c=workspace.CurrentCamera
local dir=typeof(d.dir)=='Vector3' and d.dir or nil
local side=(dir and c) and c.CFrame.RightVector:Dot(dir) or R(-1,1)
if d.atk then -- атакующий: короткий импульс «вперёд», лёгкая тряска
addTrauma(clamp(mag*.14,.04,.3));kick(big and -3 or -1.2)
camPunch(V3(rad(big and -1.4 or -.5),0,rad(R(-1,1)*(big and 1.2 or .4))))
if big then ccPulse(.03,.18,-.1,WHITE,.12) end
else -- по тебе попали: камеру дёргает от направления удара
addTrauma(clamp(mag*.34,.12,.9));kick(big and 6 or 2.5)
camPunch(V3(rad(big and 3.5 or 1.5),rad(side*(big and 2.5 or 1)),rad(-side*(big and 4.5 or 1.8))))
vignette(C3(190,25,25),big and .35 or .14,.35)
if big then ccPulse(.05,.3,-.35,C3(255,220,220),.2);blurPulse(5,.18) end
end
if d.ult then addTrauma(.12);bloomPulse(.4,.2) end
end
local function popText(d)
if typeof(d.position)~='Vector3' or camDist(d.position)>90 then return end
local a=mkPart(nil,V3(.1,.1,.1),WHITE,1,CF(d.position+V3(R(-.8,.8),2.8,R(-.8,.8))),nil,1.8)
local bb=Instance.new('BillboardGui');bb.Size=UDim2.fromOffset(230,46);bb.AlwaysOnTop=true;bb.LightInfluence=0;bb.MaxDistance=90;bb.Parent=a
local t=Instance.new('TextLabel');t.BackgroundTransparency=1;t.Size=UDim2.fromScale(1,1);t.Text=tostring(d.text or '');t.Font=Enum.Font.GothamBlack;t.TextScaled=true
t.TextColor3=typeof(d.color)=='Color3' and d.color or WHITE;t.TextStrokeTransparency=0;t.TextStrokeColor3=C3(0,0,0);t.Rotation=R(-6,6);t.Parent=bb
local sc=Instance.new('UIScale');sc.Scale=1.7;sc.Parent=t
tw(sc,.2,{Scale=1},Enum.EasingStyle.Back,OUT)
tw(a,1.2,{CFrame=a.CFrame+V3(0,2.4,0)},QD,OUT)
task.delay(.7,function() tw(t,.45,{TextTransparency=1,TextStrokeTransparency=1},QD,OUT) end)
end
task.spawn(function() -- красная пульсирующая кайма, когда здоровья меньше 30%
while task.wait(.6) do
local ch=lp.Character;local h=ch and ch:FindFirstChildOfClass('Humanoid')
if h and h.Health>0 and h.Health/h.MaxHealth<.3 then vignette(C3(150,0,0),.22+.1*math.sin(os.clock()*5),.55) end
end
end)

-- ===== События от сервера =====
remote.OnClientEvent:Connect(function(kind,d)
 local ok,err=pcall(function()
  if kind=='FX' then impact(d)
  elseif kind=='Skill' and type(d)=='table' then cast(d)
  elseif kind=='SFX' and type(d)=='table' and d.name=='Swing' and d.userId then swing(d)
  elseif kind=='Dash' and type(d)=='table' then dashFx(d)
  elseif kind=='UltStart' and type(d)=='table' then ultStart(d)
  elseif kind=='Finisher' and type(d)=='table' then finisher(d)
  elseif kind=='Shake' and type(d)=='table' then camHit(d)
elseif kind=='Pop' and type(d)=='table' then popText(d)
  elseif kind=='Whiff' then whiff()
  end
 end)
 if not ok then warn('[VFX] '..tostring(err)) end
end)
