-- Street Battles v1.5: боёвка в стиле The Strongest Battlegrounds. Сервер решает всё (урон, стан, КД, ульты).
-- v2.2: новая шапка Дяди Юры, медленная ходьба (Left Ctrl -> действие Walk), атрибуты Stunned/SlowWalk для анимаций.
-- v2.1: урон сильно снижен (GameConfig.DamageScale/UltDamageScale), хитбоксы-коробки, рывки и шаги останавливаются перед врагом,
--       бойцы не сталкиваются друг с другом (не залезаешь на голову), рывок в 4 стороны, всплывающие статусы, новые модели предметов.
-- v2.0: новые модели оружия, предметы в скиллах (нож, телефон, наручники, бутылка Юры).
-- v1.9: хитбоксы скиллов с окном попадания, у каунтеров КД при промахе БОЛЬШЕ обычного, мелкий баланс.
-- v1.4: контр-скиллы с КД при промахе, движение при скиллах, события для VfxClient (эффекты).
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local DSS=game:GetService('DataStoreService')
local RunService=game:GetService('RunService')
local Debris=game:GetService('Debris')
local PhysicsService=game:GetService('PhysicsService')
local C=require(RS:WaitForChild('GameConfig'))
local remote=RS:FindFirstChild('StreetAction') or Instance.new('RemoteEvent')
remote.Name='StreetAction';remote.Parent=RS
local profiles={}   -- [Player или Model-манекен]=состояние
local dummies={}
local store=DSS:GetDataStore('StreetBattles_Simple_v05')
local function isPlayer(e) return typeof(e)=='Instance' and e:IsA('Player') end
local function chr(e) if isPlayer(e) then return e.Character end return e end
local function hum(e) local c=chr(e);return c and c:FindFirstChildOfClass('Humanoid') end
local function root(e) local c=chr(e);return c and c:FindFirstChild('HumanoidRootPart') end
local function get(e) return profiles[e] end
local function now() return os.clock() end
local function send(e,k,d) if isPlayer(e) then remote:FireClient(e,k,d or {}) end end
local function msg(e,text) send(e,'Message',{text=text}) end
local function anim(e,k,i,t,heavy) if isPlayer(e) then remote:FireAllClients('Animate',{userId=e.UserId,action=k,index=i or 1,duration=t or .5,heavy=heavy}) end end
local function fxAt(pos,kind,extra) local d=extra or {};d.position=pos;d.kind=kind or 'Hit';remote:FireAllClients('FX',d) end -- extra: dir (куда бьют), f (боец), p (сила удара)
-- звуки: клиент (Sfx) сам решает, какой звук играть; сервер только сообщает, что произошло и где
local function sfxAt(pos,name,extra) local d=extra or {};d.position=pos;d.name=name;remote:FireAllClients('SFX',d) end
local function sfxOn(e,name,extra) local r=root(e);if r then sfxAt(r.Position,name,extra) end end
-- v2.1: бойцы не сталкиваются друг с другом — при ударах и рывках нельзя залезть врагу на голову
local CG='StreetFighters'
pcall(function() PhysicsService:RegisterCollisionGroup(CG) end)
pcall(function() PhysicsService:CollisionGroupSetCollidable(CG,CG,false) end)
local function setGroup(model)
 if not model then return end
 local function one(d) if d:IsA('BasePart') then d.CollisionGroup=CG end end
 for _,d in ipairs(model:GetDescendants()) do one(d) end
 model.DescendantAdded:Connect(one)
end
-- v2.1: всплывающая надпись над бойцом (ИСПУГ!, КРОВЬ, БЛОК ПРОБИТ ...) — видят все
local function pop(e,text,color)
 local r=root(e);if r then remote:FireAllClients('Pop',{position=r.Position,text=text,color=color}) end
end
-- ===== Предметы бойцов: добавляются ПОВЕРХ аватара игрока, внешность не меняется =====
local MAT=Enum.Material
local function mk(parent,base,name,size,color,mat,offset,shape,transp)
 local v=Instance.new('Part');v.Name=name;v.Size=size;v.Color=color;v.Material=mat or MAT.Metal
 v.CanCollide=false;v.CanTouch=false;v.CanQuery=false;v.Massless=true;v.CastShadow=true
 v.TopSurface=Enum.SurfaceType.Smooth;v.BottomSurface=Enum.SurfaceType.Smooth
 if shape then v.Shape=shape end
 if transp then v.Transparency=transp end
 v.CFrame=base.CFrame*offset;v.Parent=parent
 local w=Instance.new('WeldConstraint');w.Part0=base;w.Part1=v;w.Parent=v
 return v
end
local function rod(parent,base,name,a,b,thick,color,mat,transp) -- цилиндр между двумя точками (в координатах base)
 local mid=(a+b)/2;local len=(b-a).Magnitude
 local up=math.abs((b-a).Unit.Y)>.99 and Vector3.new(0,0,1) or Vector3.yAxis
 local cf=CFrame.lookAt(mid,b,up)*CFrame.Angles(0,math.rad(90),0)
 return mk(parent,base,name,Vector3.new(len,thick,thick),color,mat,cf,Enum.PartType.Cylinder,transp)
end
local function trail(part,pa,pb,color)
 local a0=Instance.new('Attachment');a0.Position=pa;a0.Parent=part
 local a1=Instance.new('Attachment');a1.Position=pb;a1.Parent=part
 local t=Instance.new('Trail');t.Name='SwingTrail';t.Attachment0=a0;t.Attachment1=a1;t.Lifetime=.32;t.MinLength=.03
 t.Color=ColorSequence.new(color,Color3.new(1,1,1):Lerp(color,.5));t.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.05),NumberSequenceKeypoint.new(.5,.45),NumberSequenceKeypoint.new(1,1)})
 t.WidthScale=NumberSequence.new({NumberSequenceKeypoint.new(0,1.5),NumberSequenceKeypoint.new(1,0)});t.LightEmission=1;t.FaceCamera=true;t.Enabled=false;t.Parent=part
end
local function ring(parent,base,name,cf,outer,thick,color,mat) -- кольцо: тёмный цилиндр-«дыра» не нужен, делаем обруч из тонкого цилиндра, ось по X локали cf
 return mk(parent,base,name,Vector3.new(thick,outer,outer),color,mat,cf,Enum.PartType.Cylinder)
end
local function diamond(parent,base,name,cf,size,color,mat) -- ромб (квадрат, повёрнутый на 45°): даёт острый кончик клинка
 return mk(parent,base,name,size,color,mat,cf*CFrame.Angles(math.rad(45),0,0))
end
-- ===== Модели оружия. Все собираются из деталей, приваренных к руке/торсу, поэтому двигаются вместе с анимацией =====
local function shine(p,r) p.Reflectance=r or .2;return p end
local function buildKnuckles(f,right) -- КАСТЕТ (v2.1): стальная ударная планка с шипами, 4 кольца на пальцах, упор в ладонь
 local V,CF,ang,rad,C3=Vector3.new,CFrame.new,CFrame.Angles,math.rad,Color3.fromRGB
 local steel=C3(160,164,172);local dark=C3(52,54,60);local chrome=C3(228,232,238)
 local bar=shine(mk(f,right,'Кастет основа',V(1.1,.24,.24),steel,MAT.Metal,CF(0,-1.06,-.42)),.25)
 shine(mk(f,right,'Кастет фаска',V(1.12,.05,.26),chrome,MAT.Metal,CF(0,-1.19,-.42)),.4)
 mk(f,right,'Кастет упор',V(.9,.16,.2),dark,MAT.Metal,CF(0,-1.04,.24))
 for _,x in ipairs({-.55,.55}) do mk(f,right,'Кастет боковина',V(.1,.22,.72),dark,MAT.Metal,CF(x,-1.04,-.1)) end
 for i=0,3 do
  local x=-.39+.26*i
  shine(ring(f,right,'Кастет кольцо',CF(x,-.84,-.56)*ang(0,rad(90),0),.34,.1,steel,MAT.Metal),.25)
  ring(f,right,'Кастет дыра',CF(x,-.84,-.56)*ang(0,rad(90),0),.18,.12,C3(20,20,24),MAT.SmoothPlastic)
  shine(mk(f,right,'Кастет шип',V(.12,.14,.12),chrome,MAT.Metal,CF(x,-1.24,-.42)),.45)
  diamond(f,right,'Кастет шип остриё',CF(x,-1.34,-.42),V(.09,.09,.09),chrome,MAT.Metal)
 end
 trail(bar,V(-.55,0,0),V(.55,0,0),C3(220,224,235))
end
local function buildWraps(f,arm,trailToo) -- БИНТЫ: витки с разным наклоном, тейп на запястье, кулак, хвост
 local V,CF,ang,rad,C3=Vector3.new,CFrame.new,CFrame.Angles,math.rad,Color3.fromRGB
 for j=0,6 do
  mk(f,arm,'Бинт',V(1.08,.16,1.08),(j%2==0) and C3(238,232,216) or C3(212,203,182),MAT.Fabric,CF(0,-.12-j*.13,0)*ang(rad((j%2)*4-2),rad(j*11),rad((j%2)*-3)))
 end
 local fist=mk(f,arm,'Бинт кулак',V(1.14,.42,1.14),C3(244,238,224),MAT.Fabric,CF(0,-.92,0))
 mk(f,arm,'Бинт кулак шов',V(1.16,.08,1.16),C3(190,60,50),MAT.Fabric,CF(0,-.74,0)) -- красная лента на костяшках
 mk(f,arm,'Бинт тейп',V(1.12,.12,1.12),C3(30,30,34),MAT.Fabric,CF(0,-.02,0))
 mk(f,arm,'Бинт край',V(.07,.8,.2),C3(226,218,198),MAT.Fabric,CF(.47,-.5,.1)*ang(0,0,rad(8)))
 mk(f,arm,'Бинт хвост',V(.06,.45,.18),C3(226,218,198),MAT.Fabric,CF(.5,-.95,.1)*ang(0,0,rad(18)))
 if trailToo then trail(fist,V(-.57,0,0),V(.57,0,0),C3(255,235,200)) end
end
local function buildBat(f,torso) -- БИТА за спиной (v2.1): плавное сужение, обмотка, канавки, гвозди
 local V,CF,ang,rad,C3=Vector3.new,CFrame.new,CFrame.Angles,math.rad,Color3.fromRGB
 local a=V(-.8,-1.05,.82);local b=V(.8,2.2,.82)
 local function at(t) return a+(b-a)*t end
 rod(f,torso,'Бита рукоять',a,at(.3),.22,C3(24,24,26),MAT.Fabric)
 for i=0,6 do rod(f,torso,'Бита обмотка',at(.02+i*.04),at(.02+i*.04+.022),.27,(i%2==0) and C3(185,45,38) or C3(30,30,34),MAT.Fabric) end
 local seg={{.3,.42,.3,C3(186,132,78)},{.42,.55,.4,C3(180,126,74)},{.55,.7,.5,C3(172,118,68)},{.7,.97,.58,C3(164,110,62)}}
 for _,sg in ipairs(seg) do rod(f,torso,'Бита ствол',at(sg[1]),at(sg[2]),sg[3],sg[4],MAT.Wood) end
 rod(f,torso,'Бита канавка',at(.78),at(.79),.6,C3(100,66,40),MAT.Wood)
 rod(f,torso,'Бита канавка',at(.86),at(.87),.6,C3(100,66,40),MAT.Wood)
 rod(f,torso,'Бита торец',at(.97),at(1),.52,C3(124,82,46),MAT.Wood)
 mk(f,torso,'Бита набалдашник',V(.34,.34,.34),C3(24,24,26),MAT.Fabric,CF(a),Enum.PartType.Ball)
 for _,t in ipairs({.74,.82,.9}) do mk(f,torso,'Бита гвоздь',V(.1,.1,.1),C3(205,205,210),MAT.Metal,CF(at(t)+V(0,0,.3)),Enum.PartType.Ball) end
 mk(f,torso,'Ремень грудь',V(2.9,.24,.08),C3(62,46,36),MAT.Fabric,CF(0,0,-.53)*ang(0,0,rad(-40)))
 mk(f,torso,'Ремень спина',V(2.9,.24,.08),C3(62,46,36),MAT.Fabric,CF(0,0,.53)*ang(0,0,rad(-40)))
 mk(f,torso,'Пряжка',V(.34,.34,.1),C3(200,176,90),MAT.Metal,CF(.3,.25,-.58)*ang(0,0,rad(-40)))
 mk(f,torso,'Пряжка центр',V(.16,.16,.12),C3(80,70,40),MAT.Metal,CF(.3,.25,-.6)*ang(0,0,rad(-40)))
end
local function buildHolster(f,torso) -- ПИСТОЛЕТ в кобуре на поясе (имена «Пистолет…» прячутся, когда он в руке)
 local V,CF,ang,rad,C3=Vector3.new,CFrame.new,CFrame.Angles,math.rad,Color3.fromRGB
 mk(f,torso,'Ремень',V(2.14,.38,1.14),C3(26,25,24),MAT.Fabric,CF(0,-.8,0))
 mk(f,torso,'Ремень строчка',V(2.16,.06,1.16),C3(120,110,90),MAT.Fabric,CF(0,-.8,0))
 mk(f,torso,'Пряжка',V(.5,.32,.1),C3(210,185,90),MAT.Metal,CF(0,-.8,-.58))
 mk(f,torso,'Пряжка центр',V(.28,.16,.12),C3(80,70,40),MAT.Metal,CF(0,-.8,-.6))
 mk(f,torso,'Кобура',V(.5,1.1,.84),C3(40,34,29),MAT.Fabric,CF(1.2,-1.05,-.02))
 mk(f,torso,'Кобура шов',V(.52,1.0,.06),C3(95,80,60),MAT.Fabric,CF(1.2,-1.05,-.44))
 mk(f,torso,'Кобура крепление',V(.22,.55,.34),C3(30,26,22),MAT.Fabric,CF(1.05,-.52,0))
 mk(f,torso,'Кобура ремешок',V(.54,.12,.9),C3(30,26,22),MAT.Fabric,CF(1.2,-.55,-.02))
 mk(f,torso,'Кобура кнопка',V(.14,.14,.06),C3(200,190,120),MAT.Metal,CF(1.2,-.55,-.48),Enum.PartType.Ball)
 -- пистолет: затвор, рамка, рукоять с накладками, скоба, курок
 mk(f,torso,'Пистолет затвор',V(.28,.78,.4),C3(52,55,62),MAT.Metal,CF(1.2,-1.0,-.4))
 mk(f,torso,'Пистолет насечки',V(.3,.3,.2),C3(30,32,36),MAT.Metal,CF(1.2,-.78,-.56))
 mk(f,torso,'Пистолет рукоять',V(.3,.56,.34),C3(28,28,30),MAT.SmoothPlastic,CF(1.2,-.42,-.24)*ang(rad(-14),0,0))
 mk(f,torso,'Пистолет накладка',V(.34,.4,.2),C3(60,44,32),MAT.Wood,CF(1.2,-.42,-.28)*ang(rad(-14),0,0))
 mk(f,torso,'Пистолет курок',V(.1,.2,.1),C3(170,170,176),MAT.Metal,CF(1.2,-.62,-.6))
end
local function buildBottleHeld(f,right) -- БУТЫЛКА (v2.1): Джек держит её за горлышко, донышко вперёд-вниз
 local V,C3=Vector3.new,Color3.fromRGB
 local g=C3(38,110,62)
 local top=V(0,-.78,-.05);local dir=V(0,-.72,-.69).Unit
 local function at(t) return top+dir*t end
 rod(f,right,'Бутылка пробка',at(-.12),at(0),.2,C3(205,170,60),MAT.Metal)
 rod(f,right,'Бутылка горлышко',at(0),at(.6),.2,g,MAT.Glass,.2)
 rod(f,right,'Бутылка венчик',at(.02),at(.08),.25,g,MAT.Glass,.15)
 rod(f,right,'Бутылка плечо',at(.6),at(.82),.38,g,MAT.Glass,.2)
 local body=rod(f,right,'Бутылка корпус',at(.82),at(1.75),.52,g,MAT.Glass,.2)
 rod(f,right,'Бутылка дно',at(1.73),at(1.78),.54,C3(26,80,44),MAT.Glass,.1)
 rod(f,right,'Бутылка жидкость',at(1.0),at(1.7),.42,C3(205,160,60),MAT.SmoothPlastic,.35)
 rod(f,right,'Бутылка этикетка',at(1.1),at(1.45),.535,C3(236,228,205),MAT.SmoothPlastic)
 rod(f,right,'Бутылка этикетка рисунок',at(1.22),at(1.33),.545,C3(190,50,42),MAT.SmoothPlastic)
 trail(body,V(-.4,0,0),V(.4,0,0),C3(170,240,190))
end
local function buildUshanka(f,head) -- ШАПКА БОМЖА (v2.2): потёртая ушанка точно по голове, одно ухо торчит, заплатки, дырка
 local V,CF,ang,rad,C3=Vector3.new,CFrame.new,CFrame.Angles,math.rad,Color3.fromRGB
 local fur=C3(132,120,102);local fur2=C3(108,98,84);local cloth=C3(70,60,48);local tie=C3(40,34,28);local r90=rad(90)
 mk(f,head,'Шапка верх',V(.48,1.42,1.42),cloth,MAT.Fabric,CF(0,.8,0)*ang(0,0,r90),Enum.PartType.Cylinder)
 mk(f,head,'Шапка макушка',V(.1,1.2,1.2),C3(80,68,54),MAT.Fabric,CF(0,1.05,0)*ang(0,0,r90),Enum.PartType.Cylinder)
 mk(f,head,'Шапка мех',V(.3,1.56,1.56),fur,MAT.Fabric,CF(0,.56,0)*ang(0,0,r90),Enum.PartType.Cylinder)
 mk(f,head,'Шапка отворот',V(1.2,.36,.16),fur,MAT.Fabric,CF(0,.74,-.72)*ang(rad(-12),0,0))
 mk(f,head,'Кокарда',V(.2,.2,.06),C3(150,60,48),MAT.SmoothPlastic,CF(0,.76,-.82)*ang(rad(-12),0,rad(45)))
 mk(f,head,'Кокарда центр',V(.08,.08,.07),C3(170,145,80),MAT.Metal,CF(0,.76,-.84)*ang(rad(-12),0,rad(45)))
 -- левое ухо опущено и болтается завязка, правое торчит в сторону
 mk(f,head,'Ушанка',V(.16,.78,.82),cloth,MAT.Fabric,CF(-.74,.12,.02)*ang(0,0,rad(4)))
 mk(f,head,'Ушанка мех',V(.2,.18,.84),fur2,MAT.Fabric,CF(-.75,-.28,.02))
 mk(f,head,'Ушанка завязка',V(.05,.5,.05),tie,MAT.Fabric,CF(-.78,-.55,-.2)*ang(rad(10),0,rad(8)))
 mk(f,head,'Ушанка',V(.16,.78,.82),cloth,MAT.Fabric,CF(.86,.5,.02)*ang(0,0,rad(-58)))
 mk(f,head,'Ушанка мех',V(.2,.18,.84),fur2,MAT.Fabric,CF(1.12,.3,.02)*ang(0,0,rad(-58)))
 mk(f,head,'Ушанка завязка',V(.05,.45,.05),tie,MAT.Fabric,CF(1.2,0,-.2)*ang(0,0,rad(-20)))
 mk(f,head,'Шапка затылок',V(1.3,.5,.16),cloth,MAT.Fabric,CF(0,.3,.68))
 -- бомжатские детали: заплатки разного цвета, прожжённая дырка, торчащая нитка
 mk(f,head,'Шапка заплатка',V(.36,.3,.05),C3(96,110,70),MAT.Fabric,CF(.43,.86,-.6)*ang(rad(-20),rad(-35),rad(8)))
 mk(f,head,'Шапка заплатка',V(.3,.26,.05),C3(120,70,60),MAT.Fabric,CF(-.52,.88,.52)*ang(rad(20),rad(-135),rad(-6)))
 mk(f,head,'Шапка дырка',V(.14,.05,.12),C3(25,22,20),MAT.SmoothPlastic,CF(-.25,1.1,.15))
 mk(f,head,'Шапка нитка',V(.03,.32,.03),C3(200,190,170),MAT.Fabric,CF(.3,1.18,.2)*ang(rad(30),0,rad(20)))
end
local function equip(p)
 local ch=p.Character;local s=get(p);if not ch or not s then return end
 local old=ch:FindFirstChild('FighterProp');if old then old:Destroy() end
 local right=ch:FindFirstChild('Right Arm');local left=ch:FindFirstChild('Left Arm');local head=ch:FindFirstChild('Head');local torso=ch:FindFirstChild('Torso')
 if not (right and left and head and torso) then return end
 local f=Instance.new('Folder');f.Name='FighterProp';f.Parent=ch
 if s.fighter=='Siply' then buildKnuckles(f,right)
 elseif s.fighter=='Diesel' then buildWraps(f,left,false);buildWraps(f,right,true)
 elseif s.fighter=='Bitok' then buildBat(f,torso)
 elseif s.fighter=='Major' then buildHolster(f,torso)
 elseif s.fighter=='Yura' then buildUshanka(f,head)
 else buildBottleHeld(f,right) end
end
-- ===== Ядро боёвки =====
local V,CF,C3=Vector3.new,CFrame.new,Color3.fromRGB
local function newState(fighter,kills,seconds)
 return {fighter=fighter,kills=kills or 0,seconds=seconds or 0,charge=0,ultUntil=0,ultSeq=0,cleanup={},
  stunUntil=0,lockUntil=0,rootUntil=0,flip=1,slowUntil=0,slowMul=.6,selfSlowUntil=0,selfSlowMul=.5,silenceUntil=0,ctrlImmune=0,invuln=0,
  dodgeUntil=0,dodgeKind='melee',counter=nil,block=false,blockReady=0,cooldowns={},combo=0,lastPunch=0,
  stacks=0,stacksAt=0,lastAttacker=nil,lastHitAt=0,tok=0,downTok=0,bleedUntil=0,bleedDps=0,bur=0,burReady=false,auraUntil=0,noDashUntil=0}
end
local function resetState(s)
 s.block=false;s.stunUntil=0;s.lockUntil=0;s.rootUntil=0;s.slowUntil=0;s.selfSlowUntil=0;s.silenceUntil=0;s.ctrlImmune=0;s.invuln=0;s.pendingCd=nil
 s.dodgeUntil=0;s.counter=nil;s.combo=0;s.stacks=0;s.bleedUntil=0;s.bur=0;s.burReady=false;s.tok+=1;s.ultUntil=0;s.charge=0;s.cooldowns={}
 s.ultSeq+=1
 for _,f in ipairs(s.cleanup) do pcall(f) end
 s.cleanup={}
end
local function alive(e) local h=hum(e);local r=root(e);return h~=nil and r~=nil and h.Health>0 end
local function entities()
 local list={}
 for _,p in ipairs(Players:GetPlayers()) do if profiles[p] then list[#list+1]=p end end
 for m in pairs(dummies) do if m.Parent and profiles[m] then list[#list+1]=m end end
 return list
end
-- враги в радиусе (по горизонтали) и в конусе. dotMin=nil или -1 — вокруг
local function enemies(p,range,dotMin)
 local r=root(p);local out={}
 if not r then return out end
 local look=r.CFrame.LookVector
 for _,e in ipairs(entities()) do
  if e~=p and alive(e) then
   local er=root(e);local delta=er.Position-r.Position
   local flat=V(delta.X,0,delta.Z);local d=flat.Magnitude
   if d<=range and math.abs(delta.Y)<12 and (d<2.5 or dotMin==nil or look:Dot(flat.Unit)>=dotMin) then out[#out+1]={e=e,d=d} end
  end
 end
 table.sort(out,function(a,b) return a.d<b.d end)
 return out
end
local function faceTo(p,pos)
 local r=root(p);if not r then return end
 r.CFrame=CFrame.lookAt(r.Position,V(pos.X,r.Position.Y,pos.Z))
end
local function face(p,range) -- помощь с прицеливанием
 local t=enemies(p,range,-.2)[1]
 if t then faceTo(p,root(t.e).Position) end
end
local function impulse(e,vel,dur,mask)
 local r=root(e);if not r then return end
 local bv=Instance.new('BodyVelocity');bv.MaxForce=mask or V(1e5,1e5,1e5);bv.Velocity=vel;bv.P=1e4;bv.Parent=r
 Debris:AddItem(bv,dur)
end
-- v2.1: собственное движение бойца (рывки, шаги скиллов). Если враг ближе STOP — скорость в его сторону гасится,
-- поэтому при ударе боец останавливается перед врагом, а не заезжает в него / на него.
local STOP=C.StopDist or 3.6
local function selfMove(p,vel,dur,mask)
 local r=root(p);if not r then return end
 local bv=Instance.new('BodyVelocity');bv.MaxForce=mask or V(1e5,1e5,1e5);bv.Velocity=vel;bv.P=1e4;bv.Parent=r
 local t0=os.clock();local conn
 conn=RunService.Heartbeat:Connect(function()
  if not bv.Parent or not r.Parent or os.clock()-t0>=dur then conn:Disconnect();if bv.Parent then bv:Destroy() end;return end
  local flat=V(vel.X,0,vel.Z)
  if flat.Magnitude>1 then
   for _,e in ipairs(entities()) do
    if e~=p and alive(e) then
     local d=root(e).Position-r.Position;local fd=V(d.X,0,d.Z)
     if math.abs(d.Y)<6 and fd.Magnitude>.05 and fd.Magnitude<STOP then
      local u=fd.Unit;local toward=flat:Dot(u)
      if toward>0 then flat=flat-u*toward end
     end
    end
   end
   bv.Velocity=V(flat.X,vel.Y,flat.Z)
  end
 end)
end
local function dash(p,speed,dur,dir)
 local r=root(p);if not r then return end
 local d=dir or r.CFrame.LookVector;d=V(d.X,0,d.Z);if d.Magnitude<.01 then d=r.CFrame.LookVector end;d=d.Unit
 selfMove(p,d*speed,dur,V(1e5,0,1e5))
 if isPlayer(p) and speed>=30 then remote:FireAllClients('Dash',{userId=p.UserId,speed=speed,dur=dur,dir=d}) end
end
local update
function update(e)
 local s=get(e);local h=hum(e);if not s or not h then return end
 local n=now();local cfg=C.Characters[s.fighter]
 if s.fighter=='Diesel' and s.ultUntil>n then s.stacks=5;s.stacksAt=n end
 local speed=cfg.speed
 if n<s.slowUntil then speed=speed*s.slowMul end
 if n<s.selfSlowUntil then speed=speed*s.selfSlowMul end
 if s.block then speed=speed*.55 end
if s.walkSlow then speed=speed*.42 end -- v2.2: медленная ходьба (Left Ctrl)
 if s.ultUntil>n then if s.fighter=='Yura' then speed=speed*2 elseif s.fighter=='Bitok' then speed=speed*1.35 end end
 if n<s.stunUntil or n<s.rootUntil then speed=0 elseif n<s.lockUntil then speed=speed*(C.LockMove or .3) end -- v1.4: во время скилла/удара двигаешься медленно, а не стоишь столбом
 h.WalkSpeed=speed
 local locked=n<s.lockUntil
 h.AutoRotate=not locked -- пока играет скилл, персонаж не разворачивается сам (иначе промахи при ходьбе назад)
 if locked and s.lockSched~=s.lockUntil then s.lockSched=s.lockUntil;task.delay(s.lockUntil-n+.03,function() if profiles[e]==s then update(e) end end) end
 if isPlayer(e) then
  e:SetAttribute('Fighter',s.fighter);e:SetAttribute('Blocking',s.block);e:SetAttribute('UltCharge',math.floor(s.charge))
  e:SetAttribute('UltActive',n<s.ultUntil);e:SetAttribute('Kills',s.kills);e:SetAttribute('PlaySeconds',math.floor(s.seconds));e:SetAttribute('Stacks',s.stacks)
e:SetAttribute('Stunned',n<s.stunUntil and s.stunUntil-n>.2);e:SetAttribute('SlowWalk',s.walkSlow==true)
 end
end
local function after(e,s,delay,fn)
 local tok=s.tok
 task.delay(delay,function()
  if profiles[e]~=s or s.tok~=tok or not alive(e) then return end
  fn()
 end)
end
local function stun(e,t,dur)
 local n=now()
 if n<t.ctrlImmune or t.invuln>n then return end
 if t.fighter=='Jack' and dur<=.5 then return end
 t.stunUntil=math.max(t.stunUntil,n+dur)
 if dur>.15 then
  t.tok+=1;t.lockUntil=0
  if t.block then t.block=false;t.blockReady=n+1;anim(e,'BlockEnd') end
 end
end
local function knockdown(e,t,dur)
 local n=now()
 if n<t.ctrlImmune or t.invuln>n then return end
 local h=hum(e);if not h then return end
 t.tok+=1;t.lockUntil=0;t.stunUntil=math.max(t.stunUntil,n+dur)
 if t.block then t.block=false;anim(e,'BlockEnd') end
 t.downTok+=1;local k=t.downTok
 h.PlatformStand=true;sfxOn(e,'Knockdown');do local kr=root(e);if kr then fxAt(kr.Position,'Down') end end
 task.delay(dur,function() if t.downTok==k and h.Parent then h.PlatformStand=false end end)
end
local function launch(e,from,kb,up)
 local r,fr=root(e),root(from);if not r or not fr then return end
 local d=V(r.Position.X-fr.Position.X,0,r.Position.Z-fr.Position.Z)
 d=d.Magnitude>.1 and d.Unit or fr.CFrame.LookVector
 impulse(e,d*kb+V(0,up,0),.18)
end
local function copy(o) local c={} for k,v in pairs(o) do c[k]=v end return c end
-- Главная функция попадания
local function hit(att,tgt,o)
 o=copy(o)
 local s,t=profiles[att],profiles[tgt]
 local h,tr=hum(tgt),root(tgt)
 if not s or not t or not h or not tr or h.Health<=0 then return false end
 local n=now()
 local ar=root(att);local dv=V(0,0,1)
 if ar then local dd=tr.Position-ar.Position;dd=V(dd.X,0,dd.Z);if dd.Magnitude>.1 then dv=dd.Unit end end
 local fxd={dir=dv,f=s.fighter}
 if t.invuln>n then fxAt(tr.Position,'Guard',fxd);return false end
 if t.dodgeUntil>n and not o.unavoid and (t.dodgeKind=='all' or not o.ranged) then
  t.dodgeUntil=0;fxAt(tr.Position,'Dash',fxd)
  local c=t.counter;t.counter=nil
  if c then msg(tgt,'Контратака!');pop(tgt,'КОНТРА!',Color3.fromRGB(255,230,120));fxAt(tr.Position,'Counter',{dir=dv,f=t.fighter});c(att) else msg(tgt,'Уклон!');pop(tgt,'УКЛОН',Color3.fromRGB(200,220,255)) end
  return false
 end
 if t.fighter=='Jack' and not o.unavoid then
  local ch=.05*math.floor((1-h.Health/h.MaxHealth)/.25)
  if ch>0 and math.random()<ch then msg(tgt,'Увернулся!');fxAt(tr.Position,'Dash',fxd);return false end
 end
 if t.block then
  if not o.br then
   msg(tgt,'Блок!');fxAt(tr.Position,'Guard',fxd);send(att,'Shake',{mag=.3,atk=true,kind='Guard'})
   if s.fighter=='Diesel' then s.stacks=math.min(5,s.stacks+1);s.stacksAt=n end
   return false
  end
  t.block=false;t.blockReady=n+4;t.stunUntil=math.max(t.stunUntil,n+.8);t.tok+=1
  anim(tgt,'BlockEnd');msg(tgt,'Блок пробит!');pop(tgt,'БЛОК ПРОБИТ',Color3.fromRGB(255,80,60));fxAt(tr.Position,'Break',fxd)
 end
 local cs=C.Characters[s.fighter]
 local mult=(s.ultUntil>n) and cs.ult.mult or 1
 local def=1
 if t.fighter=='Diesel' then def-=.015*t.stacks end
 if t.fighter=='Jack' then def-=.08 end
 local raw=(o.d or 0)*mult*def -- «сырой» урон: от него считаются заряд ульты, тряска и сила эффектов
local ultScale=o.ult or (s.fighter=='Diesel' and s.ultUntil>n)
local dmg=raw*(ultScale and (C.UltDamageScale or .38) or (C.DamageScale or .5)) -- v2.1: реальный урон сильно снижен
 if s.burReady and (o.d or 0)>0 and not o.nobur then o.sil=math.max(o.sil or 0,3);s.burReady=false;s.bur=0;msg(att,'Штраф за хулиганство!') end
 if dmg>0 then h:TakeDamage(dmg) end
 if t.fighter=='Major' then
  t.bur=math.min(100,t.bur+raw*2.5)
  if t.bur>=100 and not t.burReady then t.burReady=true;msg(tgt,'Протокол нарушен! Следующий удар — штраф') end
 end
 if o.st and o.st>0 then stun(tgt,t,o.st) end
 if n>=t.ctrlImmune then
  if o.slow then t.slowUntil=math.max(t.slowUntil,n+o.slow[2]);t.slowMul=o.slow[1] end
  if o.sil then t.silenceUntil=math.max(t.silenceUntil,n+o.sil);pop(tgt,'МОЛЧАНИЕ',Color3.fromRGB(170,140,255)) end
  if o.blind then send(tgt,'Blind',{duration=o.blind,kind=o.bk or 'dark'});pop(tgt,'СЛЕПОТА',Color3.fromRGB(230,230,160)) end
  if o.down then knockdown(tgt,t,o.down) end
  if (o.kb or 0)>0 or (o.up or 0)>0 then launch(tgt,att,o.kb or 0,o.up or 0) end
 end
 if o.bleed and t.fighter~='Yura' then t.bleedUntil=n+o.bleed[2];t.bleedDps=o.bleed[1]*(C.DamageScale or .5);pop(tgt,'КРОВЬ',Color3.fromRGB(230,40,40)) end
 if s.ultUntil<=n then s.charge=math.min(100,s.charge+math.max(4,raw*.7)) end
 t.charge=math.min(100,t.charge+raw*.35)
 t.lastAttacker=att;t.lastHitAt=n
 if s.fighter=='Diesel' then s.stacks=math.min(5,s.stacks+1);s.stacksAt=n end
 if not o.silent then
  fxd.p=raw;fxd.u=o.ult;fxAt(tr.Position,o.fx or 'Hit',fxd)
  local big=(o.fx=='Heavy' or o.fx=='Slam' or o.fx=='Break')
if n>=t.lockUntil and not o.down then anim(tgt,'Hit',big and 2 or 1,big and .4 or .3) end
  send(tgt,'Shake',{mag=o.shake or math.clamp(raw/12,.25,1.4),dir=dv,kind=o.fx or 'Hit',ult=o.ult})
  send(att,'Shake',{mag=(o.shake or math.clamp(raw/12,.25,1.4))*.45,dir=dv,kind=o.fx or 'Hit',atk=true,ult=o.ult})
 end
 update(att);update(tgt)
 return true
end
local function aoe(p,radius,o)
 for _,t in ipairs(enemies(p,radius,-1)) do hit(p,t.e,o) end
end
-- ===== Зоны (лужи, осколки) =====
local zones={}
local function addZone(pos,radius,dur,kind,owner,color)
 local v=Instance.new('Part');v.Name='StreetZone';v.Shape=Enum.PartType.Cylinder;v.Size=V(.15,radius*2,radius*2)
 v.CFrame=CF(pos)*CFrame.Angles(0,0,math.rad(90));v.Anchored=true;v.CanCollide=false;v.CanTouch=false;v.CanQuery=false
 v.Color=color;v.Material=Enum.Material.SmoothPlastic;v.Transparency=.4;v.Parent=workspace;Debris:AddItem(v,dur)
 do -- v1.4: лужа/осколки/круг толпы теперь светятся и «живут» частицами (эмиттер сидит на самой зоне, ось цилиндра = вверх)
  if kind=='slip' then v.Material=Enum.Material.Neon;v.Transparency=.55 end
  local em=Instance.new('ParticleEmitter');em.EmissionDirection=Enum.NormalId.Right;em.LightInfluence=0;em.LightEmission=kind=='slip' and .6 or 1
  em.Color=ColorSequence.new(color,Color3.new(1,1,1):Lerp(color,.35));em.Lifetime=NumberRange.new(.8,1.6);em.SpreadAngle=Vector2.new(15,15);em.Speed=NumberRange.new(1.5,4)
  em.Texture=kind=='slip' and 'rbxasset://textures/particles/smoke_main.dds' or 'rbxasset://textures/particles/sparkles_main.dds'
  em.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,kind=='slip' and 1.2 or .5),NumberSequenceKeypoint.new(1,0)})
  em.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.5),NumberSequenceKeypoint.new(1,1)})
  em.Rate=math.clamp(radius*(kind=='slip' and 3 or 2.2),6,48);em.Parent=v
  if kind~='decal' then local pl=Instance.new('PointLight');pl.Color=color;pl.Range=radius*2.2;pl.Brightness=1.2;pl.Parent=v end
 end
 zones[#zones+1]={pos=pos,radius=radius,untilT=now()+dur,kind=kind,owner=owner,seen={}}
end
local function groundOf(p) local r=root(p);return r.Position-V(0,2.9,0) end
-- ===== Снаряды =====
local function projectile(att,o)
 local r=root(att);if not r then return end
 local dir=o.dir or r.CFrame.LookVector
 local origin=r.Position+V(0,1.2,0)+dir*2
 local part=Instance.new('Part');part.Name='StreetProjectile';part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
 part.Size=o.size or V(.5,.5,.5);part.Color=o.color or C3(255,220,120);part.Material=o.mat or Enum.Material.Neon
 if o.shape then part.Shape=o.shape end
 part.CFrame=CFrame.lookAt(origin,origin+dir);part.Parent=workspace
 do -- v1.4: шлейф, свет и искры у снаряда (выглядит дороже, чем голый кубик)
  local col=part.Color;local sz=part.Size
  local a0=Instance.new('Attachment');a0.Position=V(-math.max(sz.X,.4)*.6,0,0);a0.Parent=part
  local a1=Instance.new('Attachment');a1.Position=V(math.max(sz.X,.4)*.6,0,0);a1.Parent=part
  local tr=Instance.new('Trail');tr.Attachment0=a0;tr.Attachment1=a1;tr.Lifetime=.35;tr.LightEmission=1;tr.Color=ColorSequence.new(col,C3(255,255,255):Lerp(col,.4))
  tr.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.1),NumberSequenceKeypoint.new(1,1)});tr.WidthScale=NumberSequence.new({NumberSequenceKeypoint.new(0,1.6),NumberSequenceKeypoint.new(1,0)});tr.Parent=part
  local pl=Instance.new('PointLight');pl.Color=col;pl.Range=14;pl.Brightness=2;pl.Parent=part
  local em=Instance.new('ParticleEmitter');em.Texture='rbxasset://textures/particles/sparkles_main.dds';em.Color=ColorSequence.new(col);em.LightEmission=1;em.LightInfluence=0
  em.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.7),NumberSequenceKeypoint.new(1,0)});em.Lifetime=NumberRange.new(.25,.45);em.Speed=NumberRange.new(2,6);em.SpreadAngle=Vector2.new(180,180);em.Rate=45;em.Parent=part
 end
 local rp=RaycastParams.new();rp.FilterType=Enum.RaycastFilterType.Include;rp.RespectCanCollide=true
 local yard=workspace:FindFirstChild('StreetCourtyard');rp.FilterDescendantsInstances=yard and {yard} or {}
 local traveled=0;local conn
 local function finish(pos,target)
  if conn then conn:Disconnect();conn=nil end
  part:Destroy()
  if not target then fxAt(pos,'Spark') end
  if o.onEnd then o.onEnd(pos,target) end
 end
 conn=RunService.Heartbeat:Connect(function(dt)
  if not part.Parent then if conn then conn:Disconnect();conn=nil end return end
  local step=o.speed*dt
  local pos=part.Position
  local res=workspace:Raycast(pos,dir*step,rp)
  if res then finish(res.Position,nil);return end
  local np=pos+dir*step
  part.CFrame=CFrame.lookAt(np,np+dir)*CFrame.Angles(0,0,traveled*.5)
  traveled+=step
  for _,e in ipairs(entities()) do
   if e~=att and alive(e) and (root(e).Position-np).Magnitude<=(o.radius or 3) then
    hit(att,e,o.hit);finish(np,e);return
   end
  end
  if traveled>=o.range then finish(np,nil) end
 end)
end
local function aimDir(p,maxD,minDot)
 local r=root(p);local look=r.CFrame.LookVector;local best,bd
 for _,e in ipairs(entities()) do
  if e~=p and alive(e) then
   local delta=root(e).Position+V(0,.3,0)-(r.Position+V(0,1.2,0));local d=delta.Magnitude
   if d>1 and d<=maxD and look:Dot(delta.Unit)>=minDot and (not bd or d<bd) then best=delta.Unit;bd=d end
  end
 end
 return best or look
end
-- ===== Временные предметы (появляются в руке на время скилла) и декорации =====
-- Оси руки: -Z — вперёд от кулака (рука опущена), -Y — вдоль руки вниз (когда рука вытянута вперёд, -Y смотрит вперёд).
local function tempProp(e,build,dur)
 local c=chr(e);local arm=c and c:FindFirstChild('Right Arm');if not arm then return end
 local f=Instance.new('Folder');f.Name='TempProp';f.Parent=c;build(f,arm);Debris:AddItem(f,dur)
end
local function batonProp(f,arm) -- v2.1: резиновая дубинка ПР (≈ 2.6 студ), рифлёная рукоять, кольцо, петля
 rod(f,arm,'Дубинка рукоять',V(0,-.95,.45),V(0,-.95,-.15),.3,C3(20,20,22),MAT.SmoothPlastic)
 for i=0,3 do rod(f,arm,'Дубинка насечка',V(0,-.95,.38-i*.14),V(0,-.95,.34-i*.14),.33,C3(42,42,46),MAT.SmoothPlastic) end
 rod(f,arm,'Дубинка кольцо',V(0,-.95,-.15),V(0,-.95,-.24),.35,C3(70,70,76),MAT.Metal)
 rod(f,arm,'Дубинка',V(0,-.95,-.24),V(0,-.98,-2.5),.28,C3(28,28,30),MAT.SmoothPlastic)
 rod(f,arm,'Дубинка торец',V(0,-.98,-2.5),V(0,-.98,-2.6),.31,C3(46,46,50),MAT.SmoothPlastic)
 mk(f,arm,'Дубинка петля',V(.06,.45,.3),C3(70,70,74),MAT.Fabric,CF(0,-.95,.66))
end
local function pipeProp(f,arm) -- v2.1: арматура (≈ 3.4 студ): ржавый пруток с рёбрами, изолента на хвате
 rod(f,arm,'Арматура',V(0,-.95,.5),V(0,-.98,-3.2),.26,C3(112,72,52),MAT.CorrodedMetal)
 for i=0,9 do local z=-.2-i*.3;rod(f,arm,'Арматура ребро',V(0,-.96,z),V(0,-.96,z-.06),.34,C3(96,60,42),MAT.Metal) end
 rod(f,arm,'Арматура срез',V(0,-.98,-3.2),V(0,-.98,-3.26),.27,C3(170,160,150),MAT.Metal)
 rod(f,arm,'Арматура изолента',V(0,-.95,.5),V(0,-.95,-.1),.31,C3(30,40,90),MAT.Fabric)
end
local function bagProp(f,arm) -- v2.1: пакет-«майка» с бутылками, висит из кулака
 rod(f,arm,'Пакет ручка',V(-.16,-.95,0),V(-.3,-1.6,-.05),.1,C3(225,225,232),MAT.Fabric)
 rod(f,arm,'Пакет ручка',V(.16,-.95,0),V(.3,-1.6,-.05),.1,C3(225,225,232),MAT.Fabric)
 mk(f,arm,'Пакет',V(1.45,1.45,1.45),C3(230,230,236),MAT.Fabric,CF(0,-2.3,-.05),Enum.PartType.Ball,.1)
 mk(f,arm,'Пакет полоса',V(1.2,.16,1.2),C3(200,40,40),MAT.Fabric,CF(0,-1.85,-.05))
 for i=-1,1 do rod(f,arm,'Пакет бутылка',V(i*.32,-1.95,-.05),V(i*.32+.05,-1.4,-.05),.16,C3(50,120,70),MAT.Glass,.2) end
end
-- v2.0: прячет детали предмета бойца, имя которых НАЧИНАЕТСЯ с одного из префиксов (пистолет в кобуре, бита за спиной, бутылка в руке)
local function hideProps(p,names,dur)
 local c=chr(p);local f=c and c:FindFirstChild('FighterProp');if not f then return end
 local untilT=now()+dur
 local function match(n) for _,x in ipairs(names) do if n:sub(1,#x)==x then return true end end return false end
 for _,v in ipairs(f:GetChildren()) do
  if v:IsA('BasePart') and match(v.Name) then
   if v:GetAttribute('T0')==nil then v:SetAttribute('T0',v.Transparency) end
   v:SetAttribute('HideUntil',math.max(v:GetAttribute('HideUntil') or 0,untilT))
   v.Transparency=1
   task.delay(dur+.03,function()
    if v.Parent and now()>=(v:GetAttribute('HideUntil') or 0) then v.Transparency=v:GetAttribute('T0') or 0 end
   end)
  end
 end
end
local GUN_PARTS={'Пистолет'}
local function gunProp(f,arm) -- v2.1: ПМ в руке (≈ 1 студ): ствол вдоль -Y, рукоять вниз (+Z)
 local ang=CFrame.Angles;local rad=math.rad
 shine(mk(f,arm,'Пистолет затвор',V(.24,1.0,.3),C3(48,50,56),MAT.Metal,CF(0,-1.42,-.05)),.15)
 for i=0,3 do mk(f,arm,'Пистолет насечки',V(.26,.04,.24),C3(28,28,32),MAT.Metal,CF(0,-1.02-i*.07,-.05)) end
 mk(f,arm,'Пистолет окно',V(.25,.22,.08),C3(20,20,22),MAT.Metal,CF(0,-1.5,-.2))
 mk(f,arm,'Пистолет дуло',V(.12,.06,.12),C3(6,6,8),MAT.SmoothPlastic,CF(0,-1.93,-.05))
 mk(f,arm,'Пистолет рамка',V(.22,.8,.2),C3(36,36,40),MAT.Metal,CF(0,-1.4,.2))
 mk(f,arm,'Пистолет рукоять',V(.24,.3,.62),C3(30,30,32),MAT.SmoothPlastic,CF(0,-1.0,.45)*ang(rad(-10),0,0))
 mk(f,arm,'Пистолет накладка',V(.26,.24,.44),C3(70,48,34),MAT.Wood,CF(0,-1.0,.48)*ang(rad(-10),0,0))
 mk(f,arm,'Пистолет скоба',V(.08,.36,.08),C3(36,36,40),MAT.Metal,CF(0,-1.48,.42))
 mk(f,arm,'Пистолет курок',V(.07,.1,.12),C3(170,170,176),MAT.Metal,CF(0,-1.32,.33))
 mk(f,arm,'Пистолет мушка',V(.06,.08,.1),C3(220,220,224),MAT.Metal,CF(0,-1.86,-.24))
 mk(f,arm,'Пистолет целик',V(.16,.08,.1),C3(220,220,224),MAT.Metal,CF(0,-.98,-.24))
end
local function drawGun(p,dur) -- Майор достаёт пистолет из кобуры на время стрельбы
 hideProps(p,GUN_PARTS,dur)
 tempProp(p,gunProp,dur)
end
local BAT_PARTS={'Бита'}
local function batProp(f,arm) -- бита в руке (для ульты Битка)
 rod(f,arm,'Бита ручка',V(0,-.9,.7),V(0,-.95,-.9),.28,C3(26,26,28),MAT.Fabric)
 for i=0,3 do rod(f,arm,'Бита обмотка',V(0,-.92,.5-i*.38),V(0,-.93,.5-i*.38-.2),.34,(i%2==0) and C3(190,50,40) or C3(36,36,40),MAT.Fabric) end
 rod(f,arm,'Бита конус',V(0,-.95,-.9),V(0,-1.0,-2.1),.44,C3(176,122,70),MAT.Wood)
 rod(f,arm,'Бита ударная часть',V(0,-1.0,-2.1),V(0,-1.05,-4.9),.64,C3(164,110,62),MAT.Wood)
 rod(f,arm,'Бита канавка',V(0,-1.03,-3.4),V(0,-1.03,-3.5),.66,C3(98,64,38),MAT.Wood)
 rod(f,arm,'Бита торец',V(0,-1.05,-4.9),V(0,-1.07,-5.05),.58,C3(120,80,45),MAT.Wood)
 for _,z in ipairs({-3.7,-4.1,-4.5}) do mk(f,arm,'Бита гвоздь',V(.13,.13,.13),C3(200,200,206),MAT.Metal,CF(0,-1.05+.34,z),Enum.PartType.Ball) end
end
local function binProp(f,arm) -- v2.1: мусорный бак (ульта Юры), цилиндр с рёбрами, крышкой и вмятиной
 local ang=CFrame.Angles;local r90=math.rad(90)
 mk(f,arm,'Мусорка',V(2.4,2.1,2.1),C3(52,104,70),MAT.Metal,CF(0,-2.5,0)*ang(0,0,r90),Enum.PartType.Cylinder)
 for i=0,2 do mk(f,arm,'Мусорка ребро',V(.14,2.18,2.18),C3(40,84,56),MAT.Metal,CF(0,-1.7-i*.8,0)*ang(0,0,r90),Enum.PartType.Cylinder) end
 mk(f,arm,'Мусорка крышка',V(.22,2.3,2.3),C3(38,78,52),MAT.Metal,CF(0,-3.75,0)*ang(0,0,r90),Enum.PartType.Cylinder)
 mk(f,arm,'Мусорка ручка',V(.9,.14,.14),C3(150,150,145),MAT.Metal,CF(0,-3.92,0))
 mk(f,arm,'Мусорка мусор',V(.6,.4,.5),C3(190,170,120),MAT.Fabric,CF(.4,-3.98,.3)*ang(.4,.3,.2))
 mk(f,arm,'Мусорка вмятина',V(.1,.6,.8),C3(36,74,50),MAT.Metal,CF(1.04,-2.6,.2))
end
local BOTTLE_PARTS={'Бутылка'}
local function roseProp(f,arm) -- «розочка»: разбитая бутылка (для ульты Джека)
 local g=C3(48,124,72)
 rod(f,arm,'Розочка горлышко',V(0,-.1,-.1),V(0,-1.2,-.1),.28,g,MAT.Glass,.2)
 rod(f,arm,'Розочка корпус',V(0,-1.1,-.1),V(0,-2.0,-.1),.66,g,MAT.Glass,.2)
 for i=0,7 do
  local a=i/8*math.pi*2
  mk(f,arm,'Осколок',V(.12,.7,.12),C3(196,238,210),MAT.Glass,CF(math.cos(a)*.3,-2.3,math.sin(a)*.3)*CFrame.Angles(math.sin(a)*.5,0,-math.cos(a)*.5),nil,.1)
 end
end
-- ===== v2.0: предметы, которые боец достаёт в скиллах =====
local function knifeProp(f,arm) -- Сиплый: скрытый клинок (рука вытянута вперёд, лезвие идёт вдоль -Y; острая кромка смотрит вверх)
 local ang=CFrame.Angles;local rad=math.rad
 mk(f,arm,'Нож рукоять',V(.3,.62,.3),C3(34,30,28),MAT.SmoothPlastic,CF(0,-1.0,-.02))
 for i=0,2 do mk(f,arm,'Нож насечка',V(.32,.08,.32),C3(70,64,60),MAT.SmoothPlastic,CF(0,-.82-i*.18,-.02)) end
 mk(f,arm,'Нож гарда',V(.14,.14,.74),C3(150,152,160),MAT.Metal,CF(0,-1.36,-.02))
 mk(f,arm,'Нож лезвие',V(.08,1.25,.46),C3(214,218,226),MAT.Metal,CF(0,-2.0,-.1))
 mk(f,arm,'Нож кровосток',V(.1,1.0,.1),C3(120,124,132),MAT.Metal,CF(0,-2.0,-.1))
 mk(f,arm,'Нож остриё',V(.08,.34,.34),C3(236,240,246),MAT.Metal,CF(0,-2.76,-.1)*ang(rad(45),0,0))
 local blade=mk(f,arm,'Нож блеск',V(.1,.1,.1),C3(255,255,255),MAT.Neon,CF(0,-2.9,-.1),Enum.PartType.Ball,.2)
 local pl=Instance.new('PointLight');pl.Color=C3(210,225,255);pl.Range=7;pl.Brightness=1.2;pl.Parent=blade
end
local function phoneProp(f,arm) -- Сиплый: «Мобилка есть позвонить?» — телефон с светящимся экраном
 local ang=CFrame.Angles;local rad=math.rad
 mk(f,arm,'Телефон корпус',V(.7,1.25,.12),C3(24,24,28),MAT.SmoothPlastic,CF(0,-1.7,-.44))
 local screen=mk(f,arm,'Телефон экран',V(.6,1.1,.04),C3(110,190,255),MAT.Neon,CF(0,-1.7,-.52))
 mk(f,arm,'Телефон камера',V(.14,.14,.05),C3(10,10,12),MAT.SmoothPlastic,CF(.2,-1.2,-.38),Enum.PartType.Ball)
 local pl=Instance.new('PointLight');pl.Color=C3(130,200,255);pl.Range=8;pl.Brightness=1.5;pl.Parent=screen
end
local function cuffsProp(f,arm) -- Майор: «В отделение!» — наручники
 local ang=CFrame.Angles;local rad=math.rad
 local steel=C3(190,194,202)
 for i=-1,1,2 do
  mk(f,arm,'Наручники кольцо',V(.2,1.05,1.05),steel,MAT.Metal,CF(i*.72,-1.7,-.2)*ang(0,rad(90),0),Enum.PartType.Cylinder)
  mk(f,arm,'Наручники дыра',V(.22,.74,.74),C3(20,20,24),MAT.SmoothPlastic,CF(i*.72,-1.7,-.2)*ang(0,rad(90),0),Enum.PartType.Cylinder)
  mk(f,arm,'Наручники замок',V(.3,.3,.3),C3(120,124,132),MAT.Metal,CF(i*.72,-1.15,-.2))
 end
 for i=0,2 do mk(f,arm,'Наручники цепь',V(.16,.16,.3),C3(160,164,172),MAT.Metal,CF(-.28+i*.28,-1.7,-.2)*ang(0,0,rad(i%2*90))) end
end
local function bottleProp(f,arm) -- Юра: бутылка перед броском (рука поднимается над головой, -Y смотрит вверх)
 local g=C3(70,130,80)
 rod(f,arm,'Бутыль корпус',V(0,-1.1,-.3),V(0,-2.1,-.3),.62,g,MAT.Glass,.15)
 rod(f,arm,'Бутыль плечо',V(0,-2.1,-.3),V(0,-2.4,-.3),.4,g,MAT.Glass,.15)
 rod(f,arm,'Бутыль горлышко',V(0,-2.4,-.3),V(0,-3.0,-.3),.22,g,MAT.Glass,.15)
 rod(f,arm,'Бутыль пробка',V(0,-3.0,-.3),V(0,-3.12,-.3),.28,C3(200,60,50),MAT.Metal)
 rod(f,arm,'Бутыль жидкость',V(0,-1.18,-.3),V(0,-1.9,-.3),.46,C3(220,225,200),MAT.Neon,.55)
end
local function badgeProp(f,arm) -- v2.1: Майор, «Предъявите документы» — раскрытое красное удостоверение
 mk(f,arm,'Удостоверение обложка',V(.9,.06,.62),C3(150,24,28),MAT.Fabric,CF(0,-1.12,-.1))
 mk(f,arm,'Удостоверение лист',V(.84,.07,.56),C3(236,230,214),MAT.SmoothPlastic,CF(0,-1.16,-.1))
 mk(f,arm,'Удостоверение фото',V(.24,.08,.3),C3(90,96,110),MAT.SmoothPlastic,CF(-.22,-1.18,-.1))
 mk(f,arm,'Удостоверение герб',V(.14,.14,.14),C3(230,190,70),MAT.Metal,CF(.22,-1.18,-.18),Enum.PartType.Ball)
end
local function figure(parent,pos,lookAtPos,shirt,collide)
 local m=Instance.new('Model');m.Name='Фигура';m.Parent=parent
 local base=CFrame.lookAt(pos,V(lookAtPos.X,pos.Y,lookAtPos.Z))
 local function pp(name,size,off,color,shape)
  local v=Instance.new('Part');v.Name=name;v.Size=size;v.Color=color;v.Anchored=true;v.CanCollide=collide or false;v.CanTouch=false
  v.Material=Enum.Material.SmoothPlastic;v.CFrame=base*off;if shape then v.Shape=shape end;v.Parent=m
 end
 pp('Ноги',V(2,2,1),CF(0,1,0),C3(40,44,60));pp('Торс',V(2,2,1),CF(0,3,0),shirt)
 pp('Рука',V(1,2,1),CF(-1.5,3,0),shirt);pp('Рука',V(1,2,1),CF(1.5,3,0),shirt)
 pp('Голова',V(1.3,1.3,1.3),CF(0,4.65,0),C3(235,190,150),Enum.PartType.Ball)
 return m
end
-- ===== Обычные удары (M1) =====
local function m1(p,s)
 local n=now()
 if n<(s.cooldowns.Punch or 0) then return end
 local cfg=C.Characters[s.fighter]
 if n-s.lastPunch>1.1 then s.combo=0 end
 s.combo+=1;if s.combo>cfg.combo then s.combo=1 end
 local heavy=s.combo==cfg.combo
 s.lastPunch=n
 local speedMul=1
 if s.fighter=='Diesel' then speedMul+=.03*s.stacks end
 if s.ultUntil>n then
  if s.fighter=='Jack' then speedMul*=2 elseif s.fighter=='Bitok' then speedMul*=3 end
 end
 if s.auraUntil>n then speedMul*=.9 end
 local windup=(heavy and .3 or .12)/speedMul
 local dur=(heavy and .7 or .34)/speedMul
 s.cooldowns.Punch=n+dur;s.lockUntil=n+(heavy and .5 or .22)/speedMul
 face(p,10)
 anim(p,'Punch',s.combo,dur,heavy);sfxOn(p,'Swing',{heavy=heavy,userId=p.UserId,fighter=s.fighter,index=s.combo})
 dash(p,heavy and 30 or 20,.12)
 update(p)
 after(p,s,windup,function()
  local t=boxHit(p,heavy and 6.8 or 6,.05)
  local ult=s.ultUntil>now()
  if s.fighter=='Jack' and ult then aoe(p,8,{d=1.5,down=.7,st=.7,fx='Slam',unavoid=true,nobur=true,shake=.6}) end
  if not t then return end
  local o={d=heavy and cfg.m1[2] or cfg.m1[1],st=heavy and .45 or .12}
  if heavy then o.kb=40;o.up=8;o.fx='Heavy';o.shake=1 end
  hit(p,t.e,o)
 end)
end
-- ===== Навыки =====
local KIT={Siply={},Diesel={},Bitok={},Major={},Yura={},Jack={}}
local function act(p,s,kind,idx,lock,t,assist)
 s.lockUntil=now()+lock;anim(p,kind,idx,t or lock)
 if assist~=false then face(p,12) end
 update(p)
end
-- v1.4: контр-скиллы (уклон + контратака) сами урона не наносят, поэтому как в Battlegrounds:
-- если контратака НЕ сработала — КД короткий (4-й параметр скилла в GameConfig), если сработала — полный.
local function setDodge(p,s,dur,kind,counter)
 local n=now();s.dodgeUntil=n+dur;s.dodgeKind=kind
 local pc=s.pendingCd;s.pendingCd=nil
 local cb=function(att)
  -- v1.6: контратака сработала — у ВСЕХ ДРУГИХ скиллов КД уменьшается на 5 секунд
  local nw=now()
  for k,v in pairs(s.cooldowns) do
   if k~=(pc and pc.key) and v>nw then
    local nv=math.max(nw,v-5);s.cooldowns[k]=nv
    send(p,'Cooldown',{key=k,duration=nv-nw})
   end
  end
  msg(p,'Контра! КД скиллов -5с')
  counter(att)
 end
 s.counter=cb
 task.delay(dur+.05,function()
  if s.counter==cb and s.dodgeUntil<=now() then
   s.counter=nil
   if pc and s.cooldowns[pc.key]==pc.untilT then -- v1.9: промах каунтера — КД становится больше (если КД не сбросили ультой/сменой бойца)
    local nu=pc.at+pc.whiff;s.cooldowns[pc.key]=nu
    send(p,'Cooldown',{key=pc.key,duration=math.max(0,nu-now())})
    msg(p,'Мимо — КД больше');send(p,'Whiff',{})
   end
  end
 end)
end
-- v1.4: небольшое движение при скиллах (шаг вперёд, отскок, шаг в сторону, подпрыгивание). Сервер двигает тело, чтобы не стоять столбом.
local function shift(p,s,delay,fwd,side,up,dur)
 local function go()
  local r=root(p);if not r then return end
  local look,right=r.CFrame.LookVector,r.CFrame.RightVector
  local v=V(look.X*fwd+right.X*side,0,look.Z*fwd+right.Z*side);local mask=V(1e5,0,1e5)
  if up~=0 then v=v+V(0,up,0);mask=V(1e5,1e5,1e5) end
  selfMove(p,v,dur,mask)
 end
 if delay<=0 then go() else after(p,s,delay,go) end
end
-- MOVES[боец][клавиша] = список {через сколько сек, вперёд (студ/с), в сторону (студ/с), вверх (студ/с), сколько длится}
-- Движения не пересекаются по времени с рывками самих скиллов (чтобы силы не дрались друг с другом).
local MOVES={
 Siply={Z={{0,-9,0,0,.22},{.4,38,0,0,.14}},X={{.2,-12,0,0,.14}},C={{.55,-8,0,0,.2}},V={{.26,0,0,16,.12}}},
 Diesel={Z={{.4,-8,26,0,.14}},X={{0,-4,26,0,.12},{.14,-4,-30,0,.14}},C={{.38,-10,0,0,.18}},V={{.42,30,0,0,.12}}},
 Bitok={Z={{.24,-10,0,0,.16}},X={{0,-6,24,0,.16}},C={{.05,30,0,0,.14}},V={{.3,-12,0,0,.14},{.46,34,0,0,.12}}},
 Major={Z={{.2,-10,0,0,.15}},X={{.28,32,0,0,.12}},C={{0,14,0,0,.2}},V={{.3,-26,0,0,.12}},R={{.1,-16,0,0,.1}}},
 Yura={Z={{0,-6,14,0,.2},{.22,16,0,0,.12}},X={{0,-12,0,0,.2}},V={{.2,-8,18,0,.2},{.5,26,0,0,.12}},R={{0,0,0,10,.1}}},
 Jack={Z={{0,10,10,0,.22}},X={{0,-26,0,0,.25}},C={{.4,0,12,0,.15},{.7,0,-12,0,.15}},V={{0,0,18,0,.18},{.3,-14,0,0,.12}}},
}
-- v1.9: хитбокс скилла «живёт» окно win сек (3 проверки: в начале, в середине и в конце). Раньше цель проверялась ровно один раз,
-- и если враг успевал шагнуть — скилл бил в пустоту. Плюс запас дальности HB_PAD и чуть шире конус HB_DOT. Одну цель бьём один раз.
local HB_PAD=.8
local HB_DOT=.1
-- v2.1: хитбокс-коробка перед бойцом (как в Battlegrounds): длина = дальность, ширина зависит от «конуса» скилла,
-- высота ±4.5 студ, чуть заходит назад (0.8) — попадает по врагу вплотную. dot=nil — круг вокруг бойца.
local function boxHit(p,range,dot)
 if dot==nil then return enemies(p,range,nil)[1] end
 local r=root(p);if not r then return nil end
 local half=(dot>=.4 and 2.6) or (dot>=.15 and 3.1) or 3.7
 local best,bd
 for _,e in ipairs(entities()) do
  if e~=p and alive(e) then
   local lp=r.CFrame:PointToObjectSpace(root(e).Position)
   local fwd=-lp.Z
   if fwd>=-.8 and fwd<=range and math.abs(lp.X)<=half and math.abs(lp.Y)<=4.5 and (not bd or fwd<bd) then best,bd={e=e,d=math.max(fwd,0)},fwd end
  end
 end
 return best
end
local function seek(p,s,delay,range,dot,fn,win)
 win=win or .12;local done=false
 local function try()
  if done then return end
  local t=boxHit(p,range+HB_PAD,dot)
  if t then done=true;fn(t) end
 end
 after(p,s,delay,try);after(p,s,delay+win/2,try);after(p,s,delay+win,try)
end
local function strike(p,s,delay,range,dot,o,win)
 seek(p,s,delay,range,dot,function(t) hit(p,t.e,o) end,win)
end
-- Сиплый
KIT.Siply[1]=function(p,s)
 act(p,s,'Skill',1,.85);s.selfSlowUntil=now()+.9;s.selfSlowMul=.3
 strike(p,s,.45,7.5,.1,{d=14,st=.5,kb=60,up=12,fx='Heavy',shake=1.4})
end
KIT.Siply[2]=function(p,s)
 tempProp(p,knifeProp,.62);act(p,s,'Skill',2,.5);dash(p,45,.14)
 strike(p,s,.17,7,.1,{d=12,st=.5,kb=8,fx='Hit',shake=.6})
end
KIT.Siply[3]=function(p,s)
 tempProp(p,phoneProp,.55);act(p,s,'Skill',3,.9)
 local t=enemies(p,26,.3)[1];local r=root(p)
 if t then local d=root(t.e).Position-r.Position;local dist=math.max(V(d.X,0,d.Z).Magnitude-4,0);dash(p,math.min(dist/.22,110),.22) end
 seek(p,s,.3,7.4,0,function(l)
  if hit(p,l.e,{d=18,br=true,st=.6,slow={.5,2},kb=6,fx='Break',shake=1}) then msg(l.e,'Испуг!');pop(l.e,'ИСПУГ!',Color3.fromRGB(255,220,90)) end
 end)
end
KIT.Siply[4]=function(p,s)
 act(p,s,'Skill',4,.8);dash(p,35,.12)
 strike(p,s,.3,7,.1,{d=21,st=.7,up=62,kb=6,fx='Heavy',shake=1.2})
end
-- Дизель
local function chase(p,range)
 local t=enemies(p,40,-1)[1];if not t then return end
 local r=root(p);local tp=root(t.e).Position
 faceTo(p,tp)
 if V(tp.X-r.Position.X,0,tp.Z-r.Position.Z).Magnitude>range-1 then dash(p,85,.1) end
end
KIT.Diesel[1]=function(p,s,ult)
 if ult then
  act(p,s,'Skill',1,1.0,1.0,false)
  for i=1,5 do after(p,s,.12*i,function()
   chase(p,7.5)
   task.delay(.06,function() if profiles[p]==s and alive(p) then local t=enemies(p,8,-1)[1];if t then hit(p,t.e,{d=i==5 and 8 or 4,st=i==5 and .5 or .1,kb=i==5 and 20 or 0,fx=i==5 and 'Heavy' or 'Hit',shake=.5}) end end end)
  end) end
 else
  act(p,s,'Skill',1,.7);dash(p,70,.2)
  strike(p,s,.22,7.5,.05,{d=5,st=.1,fx='Hit'})
  strike(p,s,.38,7.5,.05,{d=9,st=.4,kb=10,fx='Heavy',shake=.9})
 end
end
KIT.Diesel[2]=function(p,s,ult)
 act(p,s,'Skill',2,.5,.5,false)
 setDodge(p,s,.7,ult and 'all' or 'melee',function(att)
  s.lockUntil=now()+.7;anim(p,'Counter',1,.6);faceTo(p,root(att).Position)
  after(p,s,.12,function()
   if ult then
    hit(p,att,{d=22,down=1.2,st=1.2,kb=0,fx='Slam',unavoid=true,shake=2})
    aoe(p,12,{d=8,kb=30,up=10,fx='Slam',unavoid=true,nobur=true})
   else hit(p,att,{d=16,st=.6,up=55,kb=8,fx='Heavy',unavoid=true,shake=1.2}) end
  end)
 end)
end
KIT.Diesel[3]=function(p,s,ult)
 act(p,s,'Skill',3,.75);dash(p,50,.12)
 strike(p,s,.35,7.5,.05,{d=18,st=.3,slow={.5,2},kb=8,sil=ult and 2 or nil,fx='Heavy',shake=1.2})
end
KIT.Diesel[4]=function(p,s,ult)
 act(p,s,'Skill',4,.95);dash(p,35,.15)
 strike(p,s,.5,8,.05,{d=ult and 26 or 20,br=true,st=.6,kb=ult and 110 or 40,up=ult and 6 or 8,down=ult and 1.6 or nil,fx='Heavy',shake=1.7})
end
-- Биток
KIT.Bitok[1]=function(p,s)
 act(p,s,'Skill',1,.7);dash(p,60,.2)
 strike(p,s,.2,7.5,.05,{d=9,st=.35,bleed={1.5,3},kb=10,fx='Hit',shake=.8})
end
KIT.Bitok[2]=function(p,s)
 act(p,s,'Skill',2,.7)
 after(p,s,.2,function() fxAt(groundOf(p)+root(p).CFrame.LookVector*5,'Dash') end)
 seek(p,s,.2,11.5,.5,function(t) hit(p,t.e,{d=9,st=.3,blind=1.5,bk='dust',fx='Hit'}) end)
end
KIT.Bitok[3]=function(p,s)
 act(p,s,'Skill',3,1.1)
 seek(p,s,.25,7,.05,function(t)
  if hit(p,t.e,{d=8,br=true,st=1.0,up=26,fx='Hit',shake=.8}) then
   local e=t.e
   after(p,s,.3,function() hit(p,e,{d=10,down=.8,st=.8,fx='Slam',unavoid=true,nobur=true,shake=1.6}) end)
  end
 end)
end
KIT.Bitok[4]=function(p,s)
 tempProp(p,pipeProp,.95);act(p,s,'Skill',4,1.0)
 strike(p,s,.5,8.5,0,{d=22,br=true,kb=50,up=6,st=.5,fx='Heavy',shake=1.6})
end
-- Майор Сява
KIT.Major[1]=function(p,s)
 tempProp(p,badgeProp,.6);act(p,s,'Skill',1,.6);dash(p,40,.15)
 seek(p,s,.18,7,.05,function(t) if hit(p,t.e,{d=9,st=.8,fx='Hit'}) then msg(t.e,'Документы?!');pop(t.e,'ДОКУМЕНТЫ?!',Color3.fromRGB(120,170,255)) end end)
end
KIT.Major[2]=function(p,s)
 tempProp(p,batonProp,.85);act(p,s,'Skill',2,.8)
 strike(p,s,.35,8,.05,{d=14,st=.4,kb=22,fx='Heavy',shake=1})
end
KIT.Major[3]=function(p,s)
 tempProp(p,cuffsProp,1.25);act(p,s,'Skill',3,1.3)
 seek(p,s,.25,7,.05,function(t)
  local e=t.e
  if hit(p,e,{d=8,br=true,st=1.3,fx='Hit'}) then
   local look=root(p).CFrame.LookVector;impulse(e,V(look.X*28,0,look.Z*28),.35,V(1e5,0,1e5))
   after(p,s,.4,function() hit(p,e,{d=10,down=1.2,st=1.2,fx='Slam',unavoid=true,nobur=true,shake=1.4}) end)
  end
 end)
end
KIT.Major[4]=function(p,s)
 act(p,s,'Skill',4,.8);drawGun(p,1.0)
 after(p,s,.3,function() local r=root(p);fxAt(r.Position+V(0,4.3,0)+r.CFrame.LookVector*.6,'Shot') end) -- v2.1: выстрел вверх (предупредительный)
 seek(p,s,.3,15,.2,function(t) if hit(p,t.e,{d=18,br=true,st=.3,slow={.45,2},fx='Break',shake=1}) then msg(t.e,'Испуг!');pop(t.e,'ИСПУГ!',Color3.fromRGB(255,220,90)) end end)
end
KIT.Major.R=function(p,s)
 act(p,s,'Special',1,.3,.3);drawGun(p,.8) -- v1.7: достаёт пистолет из кобуры на время выстрела
 after(p,s,.1,function()
  local r=root(p);fxAt(r.Position+r.CFrame.LookVector*3,'Shot')
  projectile(p,{dir=aimDir(p,90,.78),speed=130,range=90,radius=4.8,size=V(.35,.35,1.4),color=C3(255,225,130),
   hit={d=6,st=.1,ranged=true,fx='Hit',nobur=false}})
 end)
end
-- Дядя Юра
KIT.Yura[1]=function(p,s)
 tempProp(p,bottleProp,.3);act(p,s,'Skill',1,.7)
 after(p,s,.25,function()
  projectile(p,{dir=aimDir(p,60,.65),speed=85,range=60,radius=3.5,size=V(.5,1.4,.5),color=C3(70,130,80),mat=Enum.Material.Glass,
   hit={d=11,st=.3,slow={.55,1.5},ranged=true,fx='Hit'}})
 end)
end
KIT.Yura[2]=function(p,s)
 act(p,s,'Skill',2,.75)
 after(p,s,.25,function()
  local r=root(p);local pos=groundOf(p)+r.CFrame.LookVector*8
  addZone(V(pos.X,pos.Y+.1,pos.Z),5,6,'slip',p,C3(120,170,70))
  fxAt(r.Position+r.CFrame.LookVector*4,'Dash')
  for i,t in ipairs(enemies(p,11.8,.3)) do if i>3 then break end hit(p,t.e,{d=7,blind=1,bk='toxic',st=.2,fx='Hit'}) end
 end)
end
KIT.Yura[3]=function(p,s)
 act(p,s,'Skill',3,1.2);dash(p,70,.2);msg(p,'Деньги давай на опохмел!')
 seek(p,s,.25,7,0,function(t)
  local e=t.e
  if hit(p,e,{d=8,br=true,st=1.5,down=1.5,fx='Slam',shake=1}) then
   local ts=get(e);if ts then local take=math.min(ts.charge,25);ts.charge-=take;s.charge=math.min(100,s.charge+take);msg(p,'Карманы выпотрошены') end
   after(p,s,.5,function() hit(p,e,{d=5,unavoid=true,nobur=true,fx='Hit'}) end)
   after(p,s,.9,function() hit(p,e,{d=5,unavoid=true,nobur=true,fx='Hit'}) end)
  end
 end)
end
KIT.Yura[4]=function(p,s)
 tempProp(p,bagProp,1.15);act(p,s,'Skill',4,1.1)
 strike(p,s,.55,8.5,0,{d=22,br=true,kb=55,up=6,st=.5,fx='Heavy',shake=1.5})
end
KIT.Yura.R=function(p,s)
 act(p,s,'Special',1,.5,.5,false)
 after(p,s,.2,function()
  fxAt(root(p).Position,'Slam')
  aoe(p,7.8,{d=6,st=.5,fx='Slam',shake=.8})
 end)
end
-- Капитан Джек
KIT.Jack[1]=function(p,s)
 act(p,s,'Skill',1,.7)
 seek(p,s,.25,10,.4,function(t)
  local ts=get(t.e)
  if hit(p,t.e,{d=10,blind=1.2,bk='beer',slow={.5,2},st=.2,fx='Hit'}) and ts then ts.noDashUntil=now()+2 end
 end)
end
KIT.Jack[2]=function(p,s)
 act(p,s,'Skill',2,.5,.7,false)
 setDodge(p,s,.8,'melee',function(att)
  s.lockUntil=now()+.5;anim(p,'Counter',1,.6);faceTo(p,root(att).Position)
  after(p,s,.1,function() hit(p,att,{d=17,down=1.0,st=1.0,fx='Slam',unavoid=true,shake=1}) end)
 end)
end
KIT.Jack[3]=function(p,s)
 act(p,s,'Skill',3,1.9);dash(p,45,.25)
 seek(p,s,.3,7,0,function(t)
  local e=t.e
  if hit(p,e,{d=4,br=true,st=1.5,fx='Hit'}) then
   for i=1,3 do after(p,s,.3+i*.3,function() hit(p,e,{d=4.7,unavoid=true,nobur=true,fx='Hit',shake=.5}) end) end
  end
 end)
end
KIT.Jack[4]=function(p,s)
 hideProps(p,BOTTLE_PARTS,.8);act(p,s,'Skill',4,.75)
 after(p,s,.3,function()
  projectile(p,{dir=aimDir(p,55,.65),speed=90,range=50,radius=3.5,size=V(.5,1.5,.5),color=C3(200,230,210),mat=Enum.Material.Glass,
   hit={d=20,br=true,st=1.0,ranged=true,fx='Break',shake=1},
   onEnd=function(pos) addZone(V(pos.X,pos.Y-2.7,pos.Z),4,5,'shards',p,C3(180,220,200)) end})
 end)
end
local keyOf={'Z','X','C','V'}
local function useSkill(p,s,special,index)
 local n=now();local cfg=C.Characters[s.fighter]
 local def=special and cfg.special or cfg.skills[index];if not def then return end
 local key=special and 'R' or keyOf[index]
 if n<s.silenceUntil then msg(p,'Способности отключены!');return end
 if n<(s.cooldowns[key] or 0) then return end
 local whiff=def[4] -- v1.9: КД контр-скилла, если контратака НЕ сработала (больше обычного)
 local cd=def[2]
 s.cooldowns[key]=n+cd
 s.pendingCd=whiff and {key=key,whiff=whiff,at=n,untilT=n+cd} or nil
 send(p,'Cooldown',{key=key,duration=cd});msg(p,def[1]);sfxOn(p,'Skill',{fighter=s.fighter,key=key})
 local ult=s.ultUntil>n
 if isPlayer(p) then remote:FireAllClients('Skill',{userId=p.UserId,fighter=s.fighter,key=key,ult=ult}) end
 local fn=KIT[s.fighter][special and 'R' or index]
 if fn then fn(p,s,ult) end
 s.pendingCd=nil
 local mv=MOVES[s.fighter] and MOVES[s.fighter][key]
 if mv and not (s.fighter=='Diesel' and key=='Z' and ult) then
  s.flip=-(s.flip or 1) -- сторона шага чередуется, чтобы не было одного и того же
  for _,m in ipairs(mv) do shift(p,s,m[1],m[2],m[3]*s.flip,m[4],m[5]) end
 end
 update(p)
end
-- ===== Ульты =====
local UltFn,Fin={},{}
local function finale(p,s,range,o,text,delay)
 local t=enemies(p,range,-1)[1];if not t then return end
 faceTo(p,root(t.e).Position)
 s.lockUntil=now()+.9;s.rootUntil=now()+.9;anim(p,'Finisher',1,.8);sfxOn(p,'Finisher',{fighter=s.fighter});if text then msg(p,text) end
 local e=t.e
 if isPlayer(p) then remote:FireAllClients('Finisher',{userId=p.UserId,fighter=s.fighter,target=root(e).Position}) end
 shift(p,s,.12,26,0,0,.14)
 after(p,s,delay or .4,function() hit(p,e,o) end)
 return e
end
-- ===== v1.7: СЦЕНАРНЫЕ УЛЬТЫ (Сиплый, Биток, Майор, Юра, Джек) =====
-- Ульта — это комбо на ближайшей цели: враг оглушён на всё время, удары нельзя заблокировать или уклонить, а сам боец неуязвим.
-- Времена шагов считаются от конца вступления (ULT_T0). Урон и тайминги можно менять прямо в шагах ниже (d = урон).
-- Если рядом нет врага (до 45 студ), ульта не тратится.
local SCRIPTED={Siply=true,Bitok=true,Major=true,Yura=true,Jack=true}
local ULT_T0=1.0
local function snap(p,e,dist) -- мгновенно встаёт перед целью на расстоянии dist и смотрит на неё
 local r,er=root(p),root(e);if not r or not er then return end
 local d=V(r.Position.X-er.Position.X,0,r.Position.Z-er.Position.Z)
 d=d.Magnitude>.1 and d.Unit or -er.CFrame.LookVector
 local pos=V(er.Position.X+d.X*dist,er.Position.Y,er.Position.Z+d.Z*dist)
 fxAt(r.Position,'Dash',{dir=-d,f=(profiles[p] and profiles[p].fighter) or 'Siply'})
 r.CFrame=CFrame.lookAt(pos,V(er.Position.X,pos.Y,er.Position.Z))
 r.AssemblyLinearVelocity=V(0,0,0)
end
local function tracer(p,e) -- след пули + вспышка выстрела
 local r,er=root(p),root(e);if not r or not er then return end
 local a=r.Position+r.CFrame.LookVector*2.6+V(0,1.3,0);local b=er.Position+V(0,.5,0)
 local len=math.max((b-a).Magnitude,1)
 local part=Instance.new('Part');part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
 part.Material=Enum.Material.Neon;part.Color=C3(255,225,130);part.Size=V(.18,.18,len);part.CFrame=CFrame.lookAt((a+b)/2,b);part.Parent=workspace
 Debris:AddItem(part,.08);fxAt(a,'Shot')
end
local function Seq(p,s,e,seq,total)
 local Q={aborted=false,landed=false}
 local function stop() -- досрочный конец (цель умерла или недоступна)
  if profiles[p]~=s or s.ultSeq~=seq then return end
  s.lockUntil=0;s.rootUntil=0;s.invuln=0;s.ultUntil=0;update(p)
 end
 local t=profiles[e]
 if t then -- цель обездвижена на всё комбо
  local n=now()
  t.block=false;t.counter=nil;t.dodgeUntil=0;t.tok+=1;t.lockUntil=0
  t.stunUntil=math.max(t.stunUntil,n+total);t.rootUntil=math.max(t.rootUntil,n+total)
  anim(e,'BlockEnd');update(e)
 end
 function Q.at(rel,fn) -- выполнить через rel секунд после вступления
  task.delay(math.max(0,ULT_T0+rel),function()
   if profiles[p]~=s or s.ultSeq~=seq or not alive(p) or Q.aborted then return end
   if not alive(e) then Q.aborted=true;stop();return end
   fn()
  end)
 end
 function Q.hit(o) -- удар, который нельзя заблокировать или уклонить
  o.unavoid=true;o.br=true;o.ult=true
  local ok=hit(p,e,o)
  if ok then Q.landed=true elseif not Q.landed then Q.aborted=true;msg(p,'Цель недоступна — ульта сорвана');stop() end
  return ok
 end
 function Q.step(rel,wind,idx,dist,o,extra) -- анимация UltStep[idx], через wind секунд — удар
  Q.at(rel,function() if dist then snap(p,e,dist) end;anim(p,'UltStep',idx,wind+.25);if extra then extra() end end)
  Q.at(rel+wind,function() Q.hit(o) end)
 end
 return Q
end
-- 1. Сиплый: серия ударов кастетом, апперкот-подброс, прыжок и удар кастетом по голове сверху
UltFn.Siply=function(p,s,seq,e)
 local Q=Seq(p,s,e,seq,C.Characters.Siply.ult.duration)
 msg(p,'Асфальтная разборка!')
 Q.step(0,.12,1,4.2,{d=9,st=.5,fx='Hit',shake=.6})
 Q.step(.5,.15,2,4.2,{d=10,st=.5,fx='Heavy',shake=.8})
 Q.step(1.0,.17,3,4.2,{d=12,st=.6,fx='Heavy',shake=1})
 Q.step(1.55,.22,4,4,{d=14,st=2.2,up=52,fx='Slam',shake=1.4}) -- апперкот: враг летит вверх
 Q.at(1.82,function() impulse(p,V(0,54,0),.2) end)           -- Сиплый тоже подпрыгивает
 Q.step(2.0,.3,5,nil,{d=27,down=1.4,st=1.4,kb=1,up=-90,fx='Slam',shake=2.4},function() faceTo(p,root(e).Position) end) -- удар сверху по голове, врага вбивает в землю
end
UltFn.Diesel=function(p,s,seq) fxAt(root(p).Position,'Slam') end
-- 2. Биток: 3 очень сильных удара битой и финальный с небольшим отбросом
UltFn.Bitok=function(p,s,seq,e)
 local total=C.Characters.Bitok.ult.duration
 local Q=Seq(p,s,e,seq,total)
 msg(p,'Беспредел!')
 Q.at(-.25,function() hideProps(p,BAT_PARTS,total);tempProp(p,batProp,total) end) -- бита из-за спины — в руки
 Q.step(0,.33,1,5,{d=14,st=.9,fx='Heavy',shake=1.4})
 Q.step(.8,.33,2,5,{d=16,st=.9,fx='Heavy',shake=1.6})
 Q.step(1.6,.33,3,5,{d=18,st=.9,fx='Heavy',shake=1.8})
 Q.step(2.5,.64,4,5.5,{d=26,down=1.2,st=1.4,kb=32,up=6,fx='Slam',shake=2.5}) -- финал: отбрасывает немного
end
-- 3. Майор Сява: удар, дубинка, захват, пинок с отбросом и 3 выстрела
UltFn.Major=function(p,s,seq,e)
 local Q=Seq(p,s,e,seq,C.Characters.Major.ult.duration)
 msg(p,'План Перехват!')
 Q.step(0,.12,1,3.5,{d=8,st=.8,fx='Hit',shake=.6})
 Q.step(.55,.31,2,3.5,{d=12,st=.8,fx='Heavy',shake=1},function() tempProp(p,batonProp,.9) end)
 Q.step(1.4,.25,3,3.2,{d=8,st=1.6,fx='Hit',shake=.6})        -- захват
 Q.at(1.7,function()                                         -- подтягивает врага к себе
  local r,er=root(p),root(e);if not r or not er then return end
  local pos=r.Position+r.CFrame.LookVector*3
  er.CFrame=CFrame.lookAt(V(pos.X,er.Position.Y,pos.Z),V(r.Position.X,er.Position.Y,r.Position.Z))
 end)
 Q.step(1.95,.22,4,nil,{d=17,st=2.4,kb=62,up=8,fx='Heavy',shake=2}) -- пинок, отбрасывает
 Q.at(2.8,function() drawGun(p,2.3) end)                     -- достаёт пистолет
 local function shot(rel,o)
  Q.at(rel,function() faceTo(p,root(e).Position);anim(p,'Special',1,.3);tracer(p,e) end)
  Q.at(rel+.06,function() Q.hit(o) end)
 end
 shot(3.0,{d=8,st=.5,fx='Hit',shake=.6})
 shot(3.5,{d=8,st=.5,fx='Hit',shake=.6})
 shot(4.0,{d=12,st=1.2,kb=16,fx='Break',shake=1.5})
end
-- 4. Дядя Юра: удар мусоркой и пинок после
UltFn.Yura=function(p,s,seq,e)
 local Q=Seq(p,s,e,seq,C.Characters.Yura.ult.duration)
 msg(p,'Мусорка!')
 Q.step(0,.5,1,5,{d=38,st=1.5,down=.8,fx='Slam',shake=2.2},function() tempProp(p,binProp,1.6) end)
 Q.step(1.4,.22,2,4,{d=34,st=1.6,kb=70,up=14,fx='Heavy',shake=2.4})
end
-- 5. Капитан Джек: разбивает бутылку («розочка») и 5 колющих ударов, последний отбрасывает
UltFn.Jack=function(p,s,seq,e)
 local total=C.Characters.Jack.ult.duration
 local Q=Seq(p,s,e,seq,total)
 msg(p,'Белая горячка!')
 Q.at(0,function() anim(p,'UltStep',1,.5) end)
 Q.at(.33,function()
  local r=root(p);if r then fxAt(r.Position+r.CFrame.LookVector*2.2+V(0,.6,0),'Break',{dir=r.CFrame.LookVector,f='Jack'}) end
  hideProps(p,BOTTLE_PARTS,total);tempProp(p,roseProp,total);msg(p,'Розочка!')
 end)
 Q.step(.9,.12,2,3.3,{d=11,st=.6,fx='Hit',shake=.6,bleed={1.5,3}})
 Q.step(1.35,.12,3,3.3,{d=11,st=.6,fx='Hit',shake=.6,bleed={1.5,3}})
 Q.step(1.8,.12,2,3.3,{d=12,st=.6,fx='Hit',shake=.7,bleed={1.5,3}})
 Q.step(2.25,.12,3,3.3,{d=12,st=.6,fx='Hit',shake=.7,bleed={1.5,3}})
 Q.step(2.8,.3,4,3.6,{d=20,st=1.4,kb=46,up=6,fx='Heavy',shake=2.2}) -- 5-й удар, отбрасывает
end
local function ultStart(p,s)
 local n=now();local u=C.Characters[s.fighter].ult
 local target
 if SCRIPTED[s.fighter] then -- v1.7: сценарной ульте нужна цель
  local t=enemies(p,45,nil)[1]
  if not t then msg(p,'Нужен враг рядом, чтобы начать ульту');return end
  target=t.e
 end
 s.charge=0;s.ultUntil=n+u.duration;s.cooldowns={};s.lockUntil=n+1.1;s.rootUntil=n+1.1;s.ultSeq+=1
 if target then s.lockUntil=n+u.duration;s.rootUntil=n+u.duration;s.invuln=n+u.duration;faceTo(p,root(target).Position) end
 local seq=s.ultSeq
 for _,k in ipairs({'Z','X','C','V','R'}) do send(p,'Cooldown',{key=k,duration=0}) end
 anim(p,'Ult',1,1.1);msg(p,'УЛЬТА: '..u.name)
 fxAt(root(p).Position,'Slam',{f=s.fighter,p=20});send(p,'Shake',{mag=1});sfxOn(p,'Ult',{fighter=s.fighter})
 remote:FireAllClients('UltStart',{userId=p.UserId,fighter=s.fighter,dur=u.duration})
 shift(p,s,.5,0,0,14,.16)
 local fn=UltFn[s.fighter];if fn then fn(p,s,seq,target) end
 update(p)
 task.delay(u.duration,function()
  if profiles[p]~=s or s.ultSeq~=seq then return end
  for _,f in ipairs(s.cleanup) do pcall(f) end
  s.cleanup={}
  if alive(p) then local f=Fin[s.fighter];if f then f(p,s) end end
  update(p)
 end)
end
-- ===== Манекены для тестов =====
local function dummy(p,blocking)
 if game.PrivateServerId=='' then msg(p,'Dummy доступны только на приватном сервере');return end
 local r=root(p);if not r then return end
 local model=Instance.new('Model');model.Name=blocking and 'block_dummy' or 'dummy';model.Parent=workspace
 local base=Instance.new('Part');base.Name='HumanoidRootPart';base.Size=V(2,4,1);base.Anchored=true;base.CFrame=r.CFrame*CF(0,0,-9);base.Parent=model
 model.PrimaryPart=base
 local h=Instance.new('Humanoid');h.MaxHealth=500;h.Health=500;h.Parent=model
 local tag=Instance.new('BillboardGui');tag.Size=UDim2.fromOffset(180,35);tag.StudsOffset=V(0,3,0);tag.AlwaysOnTop=true;tag.Parent=base
 local txt=Instance.new('TextLabel');txt.Size=UDim2.fromScale(1,1);txt.BackgroundTransparency=1;txt.TextColor3=Color3.new(1,1,1);txt.Text=blocking and 'BLOCK DUMMY' or 'DUMMY';txt.Parent=tag
 local st=newState('Siply');st.block=blocking and true or false
 profiles[model]=st;dummies[model]=true;setGroup(model)
 task.delay(180,function() profiles[model]=nil;dummies[model]=nil;if model.Parent then model:Destroy() end end)
end
-- ===== Сохранение =====
local function save(p)
 local s=get(p);if not s then return end
 local data={kills=s.kills,seconds=math.floor(s.seconds)}
 pcall(function() DSS:GetOrderedDataStore('StreetBattles_Top_Kills_v08'):SetAsync(tostring(p.UserId),data.kills) end)
 pcall(function() DSS:GetOrderedDataStore('StreetBattles_Top_Time_v08'):SetAsync(tostring(p.UserId),data.seconds) end)
 local ok,err=pcall(function() store:UpdateAsync(tostring(p.UserId),function(old)
  old=type(old)=='table' and old or {};old.kills=math.max(tonumber(old.kills) or 0,data.kills);old.seconds=math.max(tonumber(old.seconds) or 0,data.seconds);return old
 end) end)
 if not ok then warn('StreetBattles save:',err) end
end
Players.PlayerAdded:Connect(function(p)
 local saved={};local ok,result=pcall(function() return store:GetAsync(tostring(p.UserId)) end)
 if ok and type(result)=='table' then saved=result end
 local s=newState('Siply',tonumber(saved.kills) or 0,tonumber(saved.seconds) or 0)
 profiles[p]=s
 local ls=Instance.new('Folder');ls.Name='leaderstats';ls.Parent=p
 local kv=Instance.new('IntValue');kv.Name='Kills';kv.Value=s.kills;kv.Parent=ls
 local donated=Instance.new('IntValue');donated.Name='Donated';donated.Value=0;donated.Parent=ls
 p.CharacterAdded:Connect(function(ch)
 resetState(s);setGroup(ch)
  local h=ch:WaitForChild('Humanoid',10);if not h then return end
  h.MaxHealth=C.Characters[s.fighter].hp;h.Health=h.MaxHealth
  h.Died:Connect(function()
   resetState(s)
   local killer=s.lastAttacker
   if killer and killer~=p and isPlayer(killer) and get(killer) and now()-s.lastHitAt<12 and game.PrivateServerId=='' then
    local k=get(killer);k.kills+=1;killer.leaderstats.Kills.Value=k.kills;msg(killer,'+1 убийство');send(killer,'Kill');update(killer)
   end
  end)
  task.wait(.25);if not ch.Parent then return end;equip(p);update(p)
 end)
 p.Chatted:Connect(function(m) if m=='/dummy' then dummy(p,false) elseif m=='/block_dummy' then dummy(p,true) end end)
 update(p);msg(p,'Сиплый выбран по умолчанию. Смена бойца — кнопка БОЙЦЫ [M]')
end)
Players.PlayerRemoving:Connect(function(p) save(p);local s=profiles[p];if s then resetState(s) end;profiles[p]=nil end)
game:BindToClose(function() for _,p in ipairs(Players:GetPlayers()) do save(p) end end)
-- ===== Команды от клиента =====
remote.OnServerEvent:Connect(function(p,action,arg)
 if type(action)~='string' then return end
 local s=get(p);local h=hum(p);if not s or not h then return end
 local n=now()
 if action=='Select' then
  if type(arg)~='string' or not C.Characters[arg] or n<(s.cooldowns.Select or 0) then return end
  resetState(s);s.fighter=arg;s.cooldowns={Select=n+1}
  send(p,'Selected',{fighter=arg});p:LoadCharacter();return
 end
 if h.Health<=0 then return end
if action=='Walk' then s.walkSlow=(arg==true);update(p);return end -- v2.2: медленная ходьба
if action=='Block' then
  if arg==true then
   if n<s.blockReady or n<s.stunUntil or n<s.lockUntil then msg(p,'Блок ещё восстанавливается');return end
   s.block=true;anim(p,'Block',1,.2);sfxOn(p,'BlockUp')
  elseif s.block then
   s.block=false;s.blockReady=n+((s.fighter=='Siply' and s.ultUntil>n) and 0 or 3);anim(p,'BlockEnd')
  end
  update(p);return
 end
 if n<s.stunUntil or n<s.lockUntil or s.block then return end
 if action=='Dash' then
  if n<(s.cooldowns.Dash or 0) then return end
  if n<s.noDashUntil then msg(p,'Липко! Рывок недоступен');return end
  local cd=(s.fighter=='Siply' and s.ultUntil>n) and .8 or 3
  local r=root(p) -- v2.1: рывок туда, куда жмёшь (вперёд/назад/вбок), своя анимация на каждую сторону
local dir=(typeof(arg)=='Vector3' and arg.Magnitude>.3 and arg.Magnitude<2) and V(arg.X,0,arg.Z) or nil
if not dir or dir.Magnitude<.1 then dir=r and r.CFrame.LookVector or V(0,0,-1) end
dir=V(dir.X,0,dir.Z).Unit
local idx=1
if r then local rel=r.CFrame:VectorToObjectSpace(dir);if rel.Z>.5 then idx=2 elseif rel.X<-.5 then idx=3 elseif rel.X>.5 then idx=4 end end
s.cooldowns.Dash=n+cd;s.lockUntil=n+.24;anim(p,'Dash',idx,.3)
dash(p,idx==1 and 88 or 74,.2,dir)
  send(p,'Cooldown',{key='Q',duration=cd});update(p);return
 end
 if action=='Punch' then m1(p,s);return end
 if action=='Ult' then
  if s.charge<100 or s.ultUntil>n then return end
  ultStart(p,s);return
 end
 if action=='Skill' and type(arg)=='number' and arg>=1 and arg<=4 and arg%1==0 then useSkill(p,s,false,arg)
 elseif action=='Special' then useSkill(p,s,true,1) end
end)
-- ===== Главный цикл =====
local acc=0
task.spawn(function()
 while task.wait(.1) do
  local n=now();acc+=.1
  for _,z in ipairs(zones) do
   if z.kind~='decal' and n<z.untilT then
    for _,e in ipairs(entities()) do
     if e~=z.owner and alive(e) then
      local er=root(e);local off=er.Position-z.pos
      if V(off.X,0,off.Z).Magnitude<=z.radius and math.abs(off.Y)<6 then
       local t=profiles[e]
       if z.kind=='slip' and not z.seen[e] then z.seen[e]=true;knockdown(e,t,.9);msg(e,'Поскользнулся!');pop(e,'ПОСКОЛЬЗНУЛСЯ',Color3.fromRGB(150,220,90));update(e)
       elseif z.kind=='shards' then t.slowUntil=math.max(t.slowUntil,n+.5);t.slowMul=.6;update(e) end
      end
     end
    end
   end
  end
  for i=#zones,1,-1 do if n>=zones[i].untilT then table.remove(zones,i) end end
  if acc>=.25 then
   acc=0
   for e,s in pairs(profiles) do
    if isPlayer(e) then s.seconds+=.25 end
    if s.fighter=='Diesel' and n-s.stacksAt>3 and s.ultUntil<=n then s.stacks=0 end
    if s.bleedUntil>n and alive(e) then hum(e):TakeDamage(s.bleedDps*.25);local br=root(e);if br and math.random()<.5 then fxAt(br.Position,'Bleed') end end
    if dummies[e] and alive(e) and hum(e).Health<100 then hum(e).Health=hum(e).MaxHealth end
    update(e)
   end
   for e,s in pairs(profiles) do -- аура дяди Юры
    if s.fighter=='Yura' and alive(e) then
     for _,t in ipairs(enemies(e,8,-1)) do local ts=profiles[t.e];if ts then ts.auraUntil=n+.5 end end
    end
   end
  end
 end
end)
task.spawn(function() while task.wait(120) do for p in pairs(profiles) do if isPlayer(p) then save(p) end end end end)
