-- Locomotion v2.2 (LocalScript в StarterPlayerScripts): ВСЕ базовые движения у каждого бойца свои (R6, процедурно):
-- стойка, ходьба, медленная ходьба (Left Ctrl), бег, прыжок, падение, приземление, оглушение, нокдаун, подъём,
-- сидение, лазание, плавание. Каждый кадр (после аниматора) задаёт Motor6D.Transform шести суставов.
-- Во время ударов (R6Animations ставит атрибут SB_Act) руки/корпус/голова отдаются позам удара, ноги продолжают шагать.
-- Атрибуты от сервера: Fighter, SlowWalk, Stunned. Стиль бойца — GameConfig (style). Позы — таблица STYLE.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local C=require(RS:WaitForChild('GameConfig'))
local Sfx=require(RS:WaitForChild('Sfx'))
local rad,sin,cos,clamp,abs,pi=math.rad,math.sin,math.cos,math.clamp,math.abs,math.pi
local NAMES={R='Right Shoulder',L='Left Shoulder',H='Neck',W='RootJoint',RH='Right Hip',LH='Left Hip'}
local KEYS={'W','H','R','L','RH','LH'}

-- Углы: руки {вперёд, в сторону, поперёк}; W {наклон вперёд, поворот вправо, крен вправо}; H {вверх, поворот, наклон}; ноги {вперёд, в сторону}
-- walk/slow: arm, leg — размах; lean — наклон; bob — подпрыгивание; roll — раскачка плеч; cad — частота шага; slow.pose — поза при медленной ходьбе
local STYLE={
 thug={ -- Сиплый: сутулый дворовый
  idle={W={6,-10,0},H={-6,12,0},R={-8,6,-12},L={-6,6,12},RH={-4,6},LH={6,4}},breathe=2.5,sway=1.5,swayHz=.6,
  walk={arm=24,leg=34,lean=8,bob=.16,roll=7,cad=1,twist=8},
  slow={pose={W={4,-6,0},H={-4,8,0},R={-10,4,-14},L={-10,4,14}},arm=4,leg=22,lean=4,bob=.08,roll=5,cad=.8,twist=6,keepArms=true}, -- руки в карманах
  jump={W={-8,0,0},H={10,0,0},R={40,30,0},L={20,30,0},RH={30},LH={-20}},
  fall={W={4,0,0},H={-6,0,0},R={60,50,0},L={60,50,0},RH={10},LH={-10}},
  land={W={22,0,0},H={-10,0,0},R={20,30,0},L={20,30,0},RH={18},LH={-12},y=-.5},
  stun={W={14,0,0},H={-20,0,0},R={0,8,0},L={0,8,0},amp=1},
  getup={W={40,0,0},H={-10,0,0},R={60,10,0},L={30,30,0},RH={50},LH={-20}},
  sit={W={-6,10,0},H={4,10,0},R={30,20,0},L={30,20,0},RH={85,10},LH={85,14}},
 },
 boxer={ -- Дизель: боксёр
  idle={W={10,-22,0},H={-10,18,0},R={72,12,58},L={88,8,62},RH={-14,10},LH={16,8}},breathe=1.5,sway=2,swayHz=1.1,bounce=.16,bounceHz=2.4,
  walk={arm=5,leg=26,lean=12,bob=.1,roll=3,cad=1.15,twist=4,keepArms=true},
  slow={pose={W={14,-18,0},H={-10,14,0},R={70,12,58},L={84,8,62}},arm=3,leg=18,lean=14,bob=.05,roll=2,cad=.9,twist=3,keepArms=true}, -- подкрадывается в стойке
  jump={W={10,0,0},H={-10,0,0},R={80,10,58},L={86,8,62},RH={40},LH={20}},
  fall={W={6,0,0},H={-8,0,0},R={75,10,55},L={80,8,60},RH={10},LH={-6}},
  land={W={26,-10,0},H={-12,0,0},R={75,10,58},L={86,8,62},RH={20},LH={-14},y=-.4},
  stun={W={20,0,0},H={-24,0,0},R={40,10,30},L={40,10,30},amp=.8},
  getup={W={30,0,0},H={-8,0,0},R={80,10,58},L={86,8,62},RH={40},LH={-10}},
  sit={W={14,0,0},H={-6,0,0},R={50,10,30},L={50,10,30},RH={80,8},LH={80,8}},
 },
 brute={ -- Биток: громила
  idle={W={9,0,0},H={-8,0,0},R={8,20,-6},L={8,20,6},RH={0,12},LH={0,12}},breathe=3.5,sway=1,swayHz=.4,
  walk={arm=20,leg=30,lean=10,bob=.28,roll=6,cad=.85,twist=10,armSide=18},
  slow={pose={W={12,0,0},H={-8,0,0},R={10,22,-6},L={10,22,6}},arm=12,leg=22,lean=12,bob=.2,roll=8,cad=.7,twist=12}, -- тяжело переваливается
  jump={W={-10,0,0},H={6,0,0},R={150,30,0},L={150,30,0},RH={20},LH={20}},
  fall={W={0,0,0},H={0,0,0},R={90,60,0},L={90,60,0},RH={14},LH={-4}},
  land={W={34,0,0},H={-14,0,0},R={30,40,0},L={30,40,0},RH={26},LH={26},y=-.7},landSfx='stomp',
  stun={W={6,0,0},H={-12,0,0},R={10,24,0},L={10,24,0},amp=.6},
  getup={W={50,0,0},H={-6,0,0},R={70,20,0},L={70,20,0},RH={60},LH={-10}},
  sit={W={4,0,0},H={-4,0,0},R={20,30,0},L={20,30,0},RH={88,18},LH={88,18}},
 },
 cop={ -- Майор: выправка
  idle={W={-3,0,0},H={3,0,0},R={-6,16,-24},L={10,8,34},RH={0,2},LH={0,2}},breathe=1.5,sway=.5,swayHz=.5,
  walk={arm=34,leg=36,lean=-1,bob=.12,roll=2,cad=1.05,twist=3,rightArm=.2},
  slow={pose={W={-2,0,0},H={2,0,0},R={-30,10,-10},L={-30,10,10}},arm=0,leg=24,lean=0,bob=.06,roll=1,cad=.8,twist=2,keepArms=true}, -- патруль, руки за спиной
  jump={W={-4,0,0},H={4,0,0},R={20,20,0},L={20,20,0},RH={20},LH={20}},
  fall={W={0,0,0},H={0,0,0},R={50,30,0},L={50,30,0},RH={6},LH={6}},
  land={W={14,0,0},H={-4,0,0},R={20,20,0},L={20,20,0},RH={14},LH={-8},y=-.35},
  stun={W={4,0,0},H={-16,10,0},R={0,10,0},L={-10,10,30},amp=.7},
  getup={W={30,0,0},H={-4,0,0},R={-6,16,-24},L={40,10,30},RH={40},LH={0}},
  sit={W={-8,0,0},H={2,0,0},R={40,10,20},L={40,10,20},RH={88,4},LH={88,4}},
 },
 drunk={ -- Дядя Юра: бомж-пьяница
  idle={W={15,6,5},H={-14,-8,8},R={4,6,0},L={6,6,0},RH={-4,4},LH={6,6}},breathe=3,sway=6,swayHz=.45,
  walk={arm=18,leg=26,lean=15,bob=.14,roll=10,cad=.9,twist=10,stumble=true},
  slow={pose={W={18,6,6},H={-16,-8,10},R={2,8,0},L={4,8,0}},arm=10,leg=18,lean=18,bob=.1,roll=14,cad=.65,twist=12,stumble=true,keepArms=true}, -- еле плетётся
  jump={W={-14,0,10},H={14,0,10},R={60,60,0},L={40,60,0},RH={30},LH={10}},
  fall={W={-10,0,-8},H={10,0,-10},R={110,70,0},L={100,70,0},RH={20},LH={-10}},
  land={W={30,8,12},H={-16,0,10},R={30,50,0},L={30,50,0},RH={20},LH={-14},y=-.6},
  stun={W={22,0,10},H={-26,0,14},R={0,10,0},L={0,10,0},amp=1.4},
  getup={W={50,10,10},H={-10,0,8},R={80,10,0},L={60,30,0},RH={60},LH={-20}},
  sit={W={20,10,10},H={-20,0,14},R={10,10,0},L={10,10,0},RH={80,20},LH={80,20}},
 },
 sailor={ -- Капитан Джек: пьяный моряк
  idle={W={-7,12,-6},H={10,-12,-8},R={42,8,22},L={-6,24,10},RH={-10,8},LH={8,10}},breathe=2,sway=4,swayHz=.5,
  walk={arm=22,leg=32,lean=-4,bob=.2,roll=11,cad=.95,twist=8,rightArm=.35},
  slow={pose={W={-8,12,-6},H={10,-12,-8},R={50,8,22},L={-6,24,10}},arm=8,leg=24,lean=-6,bob=.12,roll=14,cad=.75,twist=10,keepArms=true}, -- качается с бутылкой
  jump={W={-12,0,-10},H={16,0,-8},R={160,10,10},L={40,40,0},RH={36},LH={0}},
  fall={W={-6,0,8},H={6,0,6},R={150,20,10},L={70,60,0},RH={20},LH={-10}},
  land={W={20,0,-12},H={-8,0,-10},R={60,20,20},L={20,40,0},RH={20},LH={-14},y=-.5},
  stun={W={-10,0,14},H={20,0,-16},R={30,10,10},L={0,20,0},amp=1.2},
  getup={W={40,0,-10},H={-6,0,-6},R={50,10,20},L={60,30,0},RH={50},LH={-10}},
  sit={W={-14,10,-6},H={10,-10,-8},R={90,10,20},L={10,30,0},RH={80,14},LH={80,14}},
 },
}
local DOWN={W={0,0,0},H={10,0,0},R={40,60,0},L={40,60,0},RH={10,10},LH={10,10}} -- лежит без сил (нокдаун)

local function armR(a,s) return CFrame.Angles(0,rad((a[3] or 0)*s),0)*CFrame.Angles(rad(a[1] or 0),0,0)*CFrame.Angles(0,0,rad((a[2] or 0)*s)) end
local function bodyR(a) return CFrame.Angles(0,rad(-(a[2] or 0)),0)*CFrame.Angles(rad(-(a[1] or 0)),0,0)*CFrame.Angles(0,0,rad(-(a[3] or 0))) end
local function headR(a) return CFrame.Angles(0,rad(-(a[2] or 0)),0)*CFrame.Angles(rad(a[1] or 0),0,0)*CFrame.Angles(0,0,rad(-(a[3] or 0))) end
local function legR(a,s,Rw) local comp=CFrame.new():Lerp(Rw,.85):Inverse();return comp*CFrame.Angles(rad(a[1] or 0),0,0)*CFrame.Angles(0,0,rad((a[2] or 0)*s)) end
local function conj(m,R,offset) local r=m.C0.Rotation;return r:Inverse()*(offset and CFrame.new(offset) or CFrame.new())*R*r end
local ID=CFrame.new()
local function lerpPose(a,b,t)
 if t<=.001 or not b then return a end
 local o={y=(a.y or 0)+((b.y or 0)-(a.y or 0))*t}
 for _,k in ipairs(KEYS) do
  local x,y=a[k] or {},b[k] or {}
  o[k]={(x[1] or 0)+((y[1] or 0)-(x[1] or 0))*t,(x[2] or 0)+((y[2] or 0)-(x[2] or 0))*t,(x[3] or 0)+((y[3] or 0)-(x[3] or 0))*t}
 end
 return o
end
local function toward(cur,target,rate,dt) return cur+(target-cur)*math.min(1,dt*rate) end

local function motorsOf(char)
 local torso=char:FindFirstChild('Torso');local hrp=char:FindFirstChild('HumanoidRootPart')
 if not torso or not hrp then return nil end
 local out={}
 for k,n in pairs(NAMES) do local m=(k=='W' and hrp or torso):FindFirstChild(n);if not (m and m:IsA('Motor6D')) then return nil end;out[k]=m end
 return out
end
local function styleOf(p)
 local f=p:GetAttribute('Fighter');local cfg=f and C.Characters[f]
 return STYLE[(cfg and cfg.style) or ''] or STYLE.thug
end
local rp=RaycastParams.new();rp.FilterType=Enum.RaycastFilterType.Exclude

-- поза на земле: стойка / ходьба / медленная ходьба / бег
local function groundPose(style,st,now,run,slow,a)
 local W=slow and style.slow or style.walk
 local I=style.idle;local A=slow and style.slow.pose or I
 local ph,mv=st.phase,st.mv
 local s1=sin(ph)
 local br=sin(now*2*pi*.33)*(style.breathe or 2)
 local sw=sin(now*2*pi*(style.swayHz or .5))*(style.sway or 1)
 local bounce=(style.bounce or 0)*abs(sin(now*pi*(style.bounceHz or 2)))*(1-mv*.6)
 local function b(k,i) return ((I[k] or {})[i] or 0)*(1-mv)+((A[k] or {})[i] or 0)*mv end
 local keepW=slow and 1 or nil
 local lean=b('W',1)*(keepW or (1-mv*.5))+W.lean*mv*(1+run*.9)+br*.3
 local twist=b('W',2)*(keepW or (1-mv))+s1*W.twist*mv+sw*.4*(1-mv)
 local roll=b('W',3)*(keepW or (1-mv*.5))+s1*W.roll*mv+sw*(1-mv)*.6
 if W.stumble then roll+=sin(now*1.7)*5*mv;twist+=sin(now*1.1)*6*mv end
 local hk=keepW or (1-mv*.5)
 local Ha={b('H',1)*hk-lean*.3,b('H',2)*(keepW or (1-mv))-twist*.6,b('H',3)*hk-roll*.5}
 local base=W.keepArms and 1 or (1-mv*.6)
 local armSw=W.arm*mv*(1+run*.7)
 local side=(W.armSide or 0)*mv*.5+4*mv
 local Ra={b('R',1)*base-s1*armSw*(W.rightArm or 1)-run*10,b('R',2)*base+side+br*.4,b('R',3)*base}
 local La={b('L',1)*base+s1*armSw-run*10,b('L',2)*base+side+br*.4,b('L',3)*base}
 if W.keepArms and not slow then Ra[1]+=sin(ph*2)*4*mv;La[1]-=sin(ph*2)*4*mv end
 local legSw=W.leg*mv*(1+run*.35)*(1-.5*a)
 local RHa={b('RH',1)*(1-mv)+s1*legSw,b('RH',2)*(1-mv)}
 local LHa={b('LH',1)*(1-mv)-s1*legSw,b('LH',2)*(1-mv)}
 local y=-W.bob*mv*(.5-.5*cos(ph*2))+bounce-.04*abs(br)/3
 return {W={lean,twist,roll},H=Ha,R=Ra,L=La,RH=RHa,LH=LHa,y=y}
end

local function stepChar(p,char,st,dt,now)
 local hum=char:FindFirstChildOfClass('Humanoid');local hrp=char:FindFirstChild('HumanoidRootPart')
 if not hum or not hrp or hum.Health<=0 then return end
 if not (st.M and st.M.W.Parent and st.M.RH.Parent) then st.M=motorsOf(char) end
 local M=st.M;if not M then return end
 local style=styleOf(p)
 rp.FilterDescendantsInstances={char}
 local v=hrp.AssemblyLinearVelocity
 local state=hum:GetState()
 local down=hum.PlatformStand
 local sit=hum.Sit
 local climb=state==Enum.HumanoidStateType.Climbing
 local swim=state==Enum.HumanoidStateType.Swimming
 local grounded=workspace:Raycast(hrp.Position,Vector3.new(0,-4.2,0),rp)~=nil and abs(v.Y)<14
 local air=not grounded and not down and not sit and not climb and not swim
 local speed=Vector3.new(v.X,0,v.Z).Magnitude
 local slow=p:GetAttribute('SlowWalk')==true
 local stunned=p:GetAttribute('Stunned')==true
 local acting=(char:GetAttribute('SB_Act') or 0)>now
 -- переходы: приземление и подъём после нокдауна
 if air then st.airT=(st.airT or 0)+dt;st.minVy=math.min(st.minVy or 0,v.Y)
 else
  if (st.airT or 0)>.22 and grounded then
   st.landT=now;st.landPow=clamp(-(st.minVy or 0)/55,.3,1)
   pcall(function() Sfx.play(style.landSfx or 'step',hrp.Position-Vector3.new(0,3,0),1,st.landPow) end)
  end
  st.airT=0;st.minVy=0
 end
 if st.wasDown and not down then st.getupT=now end
 st.wasDown=down
 -- плавные веса состояний
 st.mv=toward(st.mv,clamp(speed/(slow and 6 or 10),0,1),8,dt)
 st.a=toward(st.a,acting and 1 or 0,acting and 25 or 8,dt)
 st.air=toward(st.air,air and 1 or 0,air and 10 or 18,dt)
 st.stun=toward(st.stun,(stunned and not down) and 1 or 0,8,dt)
 st.down=toward(st.down,down and 1 or 0,10,dt)
 st.sit=toward(st.sit,sit and 1 or 0,10,dt)
 st.climb=toward(st.climb,climb and 1 or 0,10,dt)
 st.swim=toward(st.swim,swim and 1 or 0,8,dt)
 local W=slow and style.slow or style.walk
 st.phase=st.phase+dt*speed*.55*(W.cad or 1)*(slow and 1.3 or 1)
 local run=clamp((speed-17)/8,0,1)
 local P=groundPose(style,st,now,run,slow,st.a)
 -- оглушение: голова «плывёт» по кругу, тело покачивается
 if st.stun>.01 then
  local s=style.stun;local am=s.amp or 1
  local sp=lerpPose({},s,1)
  sp.H[1]+=sin(now*3)*8*am;sp.H[2]+=cos(now*3)*12*am;sp.H[3]+=sin(now*3)*7*am
  sp.W[3]+=sin(now*1.6)*7*am;sp.W[2]+=sin(now*1.1)*5*am
  sp.RH={P.RH[1],P.RH[2]};sp.LH={P.LH[1],P.LH[2]}
  P=lerpPose(P,sp,st.stun)
 end
 if st.landT then local k=1-(now-st.landT)/.32;if k>0 then P=lerpPose(P,style.land,k*(st.landPow or .5)*(1-st.a)) else st.landT=nil end end
 if st.getupT then local k=1-(now-st.getupT)/.5;if k>0 then P=lerpPose(P,style.getup,k) else st.getupT=nil end end
 if st.air>.01 then
  local fk=clamp((-v.Y+4)/22,0,1)
  local ap=lerpPose(style.jump,style.fall,fk)
  if style==STYLE.drunk or style==STYLE.sailor then ap.R[1]+=sin(now*9)*14;ap.L[1]-=sin(now*9)*14 end
  P=lerpPose(P,ap,st.air)
 end
 if st.climb>.01 then
  local s=sin(now*6)
  P=lerpPose(P,{W={8,0,0},H={14,0,0},R={155+22*s,10,0},L={155-22*s,10,0},RH={25+20*s},LH={25-20*s}},st.climb)
 end
 if st.swim>.01 then
  local s,c=sin(now*4),cos(now*4)
  P=lerpPose(P,{W={22,0,0},H={-10,0,0},R={115+35*s,40+25*c,0},L={115+35*s,40+25*c,0},RH={18*s},LH={-18*s}},st.swim)
 end
 if st.sit>.01 then P=lerpPose(P,style.sit,st.sit) end
 if st.down>.01 then P=lerpPose(P,DOWN,st.down) end
 -- применяем (во время удара руки/корпус/голова -> позы удара)
 local k=1-st.a
 local Rw=bodyR(P.W)
 M.W.Transform=ID:Lerp(conj(M.W,Rw,Vector3.new(0,P.y or 0,0)),k)
 M.H.Transform=ID:Lerp(conj(M.H,headR(P.H)),k)
 M.R.Transform=ID:Lerp(conj(M.R,armR(P.R,1)),k)
 M.L.Transform=ID:Lerp(conj(M.L,armR(P.L,-1)),k)
 local Rwb=ID:Lerp(Rw,k)
 M.RH.Transform=conj(M.RH,legR(P.RH,1,Rwb))
 M.LH.Transform=conj(M.LH,legR(P.LH,-1,Rwb))
end

local states=setmetatable({},{__mode='k'})
local errs=0
RunService.Stepped:Connect(function(_,dt)
 dt=math.min(dt,.05);local now=os.clock()
 for _,p in ipairs(Players:GetPlayers()) do
  local char=p.Character
  if char then
   local st=states[char]
   if not st then st={phase=math.random()*6,mv=0,a=0,air=0,stun=0,down=0,sit=0,climb=0,swim=0};states[char]=st end
   local ok,err=pcall(stepChar,p,char,st,dt,now)
   if not ok and errs<5 then errs+=1;warn('[LOCO] '..tostring(err)) end
  end
 end
end)
