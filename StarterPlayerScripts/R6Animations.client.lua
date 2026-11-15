-- R6Animations v2.1: процедурные анимации на ключевых кадрах (без загрузки Animation ID).
-- v2.1: удары с «перехлёстом» (Back), рывки в 4 стороны со своим стилем у каждого бойца, тяжёлая реакция на сильный удар,
--       светящиеся шлейфы за руками (и ногами при пинках), атрибут SB_Act для Locomotion (стойка/походка бойцов).
-- v1.5: у рывка добавлен присед перед стартом.
-- v1.4: автоматический футворк (ноги шагают в каждой фазе удара), доводка после удара (тело «пружинит», а не щёлкает в стойку),
--       живая реакция на попадание (в разные стороны), новый рывок. Аура ульта теперь в VfxClient.
-- Позы задаются в понятных единицах, оси суставов пересчитываются правильно.
--   Руки  {вперёд°, в сторону°, поперёк°}   (0 = вдоль тела, 90 = горизонтально вперёд, 170 = над головой)
--   W тело {наклон вперёд°, поворот вправо°, крен вправо°}
--   H голова {вверх°, поворот вправо°, наклон вправо°}
--   Ноги  {вперёд°}
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local TweenService=game:GetService('TweenService')
local event=RS:WaitForChild('StreetAction')
local rad=math.rad
local NAMES={R='Right Shoulder',L='Left Shoulder',H='Neck',W='RootJoint',RH='Right Hip',LH='Left Hip'}
local rest=setmetatable({},{__mode='k'})
local tokens={}

local function joints(char)
 local torso=char and char:FindFirstChild('Torso');local hrp=char and char:FindFirstChild('HumanoidRootPart')
 if not torso or not hrp then return end
 local out={}
 for key,name in pairs(NAMES) do
  local m=(key=='W' and hrp or torso):FindFirstChild(name)
  if m and m:IsA('Motor6D') then out[key]=m end
 end
 return out
end

local function bodyRot(a)
 a=a or {}
 return CFrame.Angles(0,rad(-(a[2] or 0)),0)*CFrame.Angles(rad(-(a[1] or 0)),0,0)*CFrame.Angles(0,0,rad(-(a[3] or 0)))
end
local function goal(key,restC0,a,Rw)
 local R
 if key=='R' or key=='L' then
  if not a then return restC0 end
  local s=key=='R' and 1 or -1
  R=CFrame.Angles(0,rad((a[3] or 0)*s),0)*CFrame.Angles(rad(a[1] or 0),0,0)*CFrame.Angles(0,0,rad((a[2] or 0)*s))
 elseif key=='W' then
  if not a then return restC0 end
  R=bodyRot(a)
 elseif key=='H' then
  if not a then return restC0 end
  R=CFrame.Angles(0,rad(-(a[2] or 0)),0)*CFrame.Angles(rad(a[1] or 0),0,0)*CFrame.Angles(0,0,rad(-(a[3] or 0)))
 else -- ноги: компенсируем поворот корпуса, чтобы ноги не крутились вместе с ним
  local comp=CFrame.new():Lerp(Rw,.85):Inverse()
  local s=key=='RH' and 1 or -1 -- v2.1: второй угол ноги — отвод в сторону
  R=comp*CFrame.Angles(rad(a and a[1] or 0),0,0)*CFrame.Angles(0,0,rad((a and a[2] or 0)*s))
 end
 return CFrame.new(restC0.Position)*R*restC0.Rotation
end

local function merge(a,b) local o={} for k,v in pairs(a) do o[k]=v end for k,v in pairs(b or {}) do o[k]=v end return o end
local Q,B,QI=Enum.EasingStyle.Quad,Enum.EasingStyle.Quint,Enum.EasingStyle.Sine
local BK=Enum.EasingStyle.Back -- v2.1: удар с небольшим перехлёстом — резче и «тяжелее»
local OUT,IN,INOUT=Enum.EasingDirection.Out,Enum.EasingDirection.In,Enum.EasingDirection.InOut
local function fr(dur,pose,style,dir,hold) return {dur=dur,pose=pose,style=style or Q,dir=dir or OUT,hold=hold or 0} end

-- Характер каждого бойца
local PARAM={
 Siply ={f=90, lean=10,twist=24,o=10,roll=0, tilt=0,  chop=false,stance=14},
 Diesel={f=96, lean=18,twist=34,o=8, roll=0, tilt=-8, chop=false,stance=22},
 Bitok ={f=100,lean=16,twist=28,o=12,roll=0, tilt=0,  chop=true, stance=16},
 Major ={f=88, lean=6, twist=14,o=6, roll=0, tilt=0,  chop=false,stance=10},
 Yura  ={f=84, lean=10,twist=30,o=34,roll=10,tilt=6,  chop=false,stance=12},
 Jack  ={f=94, lean=8, twist=26,o=22,roll=14,tilt=14, chop=false,stance=18},
}

local function punchFrames(fighter,index,heavy)
 local P=PARAM[fighter] or PARAM.Siply
 local third=heavy and true or false
 local right=third or (index%2==1)
 local A,Bk=right and 'R' or 'L',right and 'L' or 'R'
 local sg=right and 1 or -1
 local LF,LB=right and 'LH' or 'RH',right and 'RH' or 'LH'
 local wind,hit
 if third then
  wind={[A]={165,P.o+10,0},[Bk]={70,0,20},W={-10,38*sg,P.roll*sg},H={-8,10*sg,P.tilt},[LF]={P.stance*.5},[LB]={-P.stance*.5}}
  hit ={[A]={55,0,P.chop and 40 or 55},[Bk]={50,0,25},W={P.lean+18,-(P.twist+14)*sg,-P.roll*sg},H={-14,-10*sg,P.tilt},[LF]={P.stance*1.1},[LB]={-P.stance*.9}}
  return {fr(.2,wind,Q,INOUT),fr(.10,hit,BK,OUT,.12)}
 end
 wind={[A]=P.chop and {145,14,0} or {25,P.o,0},[Bk]={85,0,25},W={-6,P.twist*.7*sg,P.roll*sg},H={0,8*sg,P.tilt},[LF]={P.stance*.5},[LB]={-P.stance*.4}}
 hit ={[A]=P.chop and {58,0,30} or {P.f,0,22},[Bk]={80,0,28},W={P.lean,-P.twist*sg,-P.roll*sg},H={-6,-12*sg,P.tilt*.5},[LF]={P.stance*.9},[LB]={-P.stance*.7}}
 return {fr(.06,wind,Q,OUT),fr(.07,hit,BK,OUT,.05)}
end

-- Навыки: у каждого бойца свои позы. S(замах,поза,удар,поза[,доп.кадры])
local function S(t1,w,t2,h,extra)
 local list={fr(t1,w,Q,INOUT),fr(t2,h,BK,OUT,.12)}
 for _,f in ipairs(extra or {}) do list[#list+1]=f end
 return list
end
local function throwPose(P) return S(.22,{R={172,12,0},L={60,0,25},W={-14,32,P.roll},H={-14,10,P.tilt},LH={14},RH={-10}},.08,{R={58,0,10},L={40,0,25},W={22,-34,-P.roll},H={10,-8,0},LH={26},RH={-18}}) end
local SK={
 Siply={
  [1]=function() return S(.38,{R={150,25,0},L={60,0,30},W={-14,38,0},H={-8,12,0},LH={14},RH={-12}},.07,{R={62,0,40},L={50,0,30},W={26,-40,0},H={-12,-14,0},LH={26},RH={-20}}) end,
  [2]=function() return S(.11,{R={60,10,0},L={80,0,25},W={-8,28,0},H={0,10,0}},.06,{R={92,0,20},L={70,0,25},W={14,-22,0},H={-6,-12,0},LH={22},RH={-14}}) end,
  [3]=function() return S(.18,{R={75,10,10},L={75,10,10},W={22,0,0},H={-8,0,0},LH={26},RH={-18}},.12,{R={105,0,10},L={95,0,35},W={30,0,0},H={-10,0,0},LH={34},RH={-24}}) end,
  [4]=function() return S(.22,{R={0,10,0},L={55,0,25},W={26,25,0},H={6,10,0},LH={20},RH={-16}},.08,{R={172,0,10},L={55,0,25},W={-16,-26,0},H={18,0,0},LH={10},RH={-8}}) end,
 },
 Diesel={
  [1]=function(ult)
   if ult then
    local f={}
    for i=1,5 do
     local r=i%2==1
     local A,B2=r and 'R' or 'L',r and 'L' or 'R'
     f[#f+1]=fr(.05,{[A]={30,12,0},[B2]={90,0,28},W={-4,(r and 20 or -20),0}},Q,OUT)
     f[#f+1]=fr(.07,{[A]={95,0,24},[B2]={85,0,28},W={16,(r and -28 or 28),0},LH={22},RH={-16}},B,OUT)
    end
    return f
   end
   return S(.1,{R={25,10,0},L={90,0,25},W={-6,20,0},LH={20},RH={-14}},.06,{R={95,0,22},L={80,0,28},W={16,-28,0},LH={30},RH={-22}},
    {fr(.08,{R={60,10,20},L={25,10,0},W={-4,22,0}},Q,OUT),fr(.07,{L={96,0,24},R={80,0,28},W={18,30,0},LH={28},RH={-20}},B,OUT,.06)})
  end,
  [2]=function() return {fr(.12,{W={24,0,28},H={8,0,-20},R={40,10,0},L={40,10,0},LH={26},RH={-18}},Q,OUT,.18),fr(.16,{W={24,0,-28},H={8,0,20},R={40,10,0},L={40,10,0},LH={-18},RH={26}},QI,INOUT,.14)} end,
  [3]=function() return S(.3,{R={20,0,0},L={85,0,20},W={30,20,0},H={8,0,0},LH={24},RH={-16}},.07,{R={85,0,15},L={70,0,25},W={36,-30,0},H={4,-10,0},LH={34},RH={-24}}) end,
  [4]=function() return S(.44,{R={170,20,0},L={80,0,30},W={-18,35,0},H={-10,10,0},LH={12},RH={-10}},.08,{R={50,0,48},L={70,0,30},W={36,-45,0},H={10,-12,0},LH={32},RH={-26}}) end,
 },
 Bitok={
  [1]=function() return S(.14,{R={60,40,45},L={80,0,25},W={-6,30,0}},.06,{R={85,25,50},L={70,0,25},W={16,-30,0},LH={24},RH={-16}}) end,
  [2]=function() return S(.14,{R={20,15,0},L={80,0,25},W={-8,20,0},H={6,0,0}},.06,{R={95,10,0},L={70,0,25},W={10,-14,0},H={-8,0,0}}) end,
  [3]=function() return S(.2,{R={70,20,0},L={70,20,0},W={14,30,0}},.1,{R={110,0,0},L={110,0,0},W={34,-70,0},LH={20},RH={-20}},{fr(.3,{R={40,30,0},L={40,30,0},W={40,-10,0},H={20,0,0}},Q,OUT,.3)}) end,
  [4]=function() return S(.44,{R={170,10,0},L={140,10,0},W={-20,22,0},H={-10,0,0},LH={12},RH={-10}},.08,{R={48,0,12},L={60,0,20},W={34,-34,0},H={12,0,0},LH={30},RH={-24}}) end,
 },
 Major={
  [1]=function() return S(.12,{R={70,10,0},L={20,10,0},W={0,10,0}},.06,{R={105,0,10},L={20,10,0},W={10,-6,0},H={-6,0,0}}) end,
  [2]=function() return S(.31,{R={165,10,0},L={90,0,30},W={-12,26,0}},.07,{R={55,0,25},L={90,0,30},W={26,-28,0},H={8,0,0}}) end,
  [3]=function() return S(.25,{R={85,0,15},L={85,0,15},W={12,0,0}},.2,{R={95,0,35},L={60,10,60},W={30,-15,0},LH={20},RH={-14}},{fr(.3,{R={70,0,0},L={70,0,0},W={42,0,0},H={14,0,0}},Q,OUT,.3)}) end,
  [4]=function() return S(.18,{R={120,0,0},L={110,0,10},W={-6,0,0}},.07,{R={178,0,0},L={165,0,10},W={-12,0,0},H={22,0,0}}) end,
  R=function() return S(.08,{R={84,0,16},L={84,0,16},W={0,0,0}},.04,{R={92,0,18},L={90,0,18},W={5,-3,0},H={-4,0,0}}) end,
 },
 Yura={
  [1]=function(_,P) return throwPose(P) end,
  [2]=function() return S(.2,{R={60,30,0},L={50,30,0},W={-10,0,0}},.1,{R={95,0,30},L={95,0,30},W={12,20,0}},{fr(.15,{R={95,0,-20},L={95,0,-20},W={12,-22,0}},Q,INOUT,.1)}) end,
  [3]=function() return S(.2,{R={60,30,0},L={60,30,0},W={30,0,0},LH={24},RH={-18}},.12,{R={110,10,0},L={110,10,0},W={52,0,0},LH={40},RH={-30}},{fr(.35,{R={100,10,10},L={100,10,10},W={44,0,0}},Q,OUT,.3)}) end,
  [4]=function() return S(.5,{R={170,20,0},L={60,10,0},W={-10,60,0},H={-8,20,0}},.08,{R={60,0,20},L={50,10,10},W={30,-80,0},H={8,-20,0},LH={30},RH={-20}}) end,
  R=function() return S(.3,{R={70,0,40},L={70,0,40},W={-14,0,0},H={38,0,0}},.1,{R={80,0,40},L={80,0,40},W={18,0,0},H={-24,0,0}}) end,
 },
 Jack={
  [1]=function() return S(.22,{R={110,10,0},L={20,15,0},W={-10,0,0},H={28,0,0}},.08,{R={95,0,0},L={30,10,0},W={14,0,0},H={-12,0,0}}) end,
  [2]=function() return {fr(.15,{W={-28,0,-18},H={20,0,-15},R={70,35,0},L={70,35,0},LH={-14},RH={16}},Q,OUT,.45)} end,
  [3]=function() return S(.3,{R={80,25,0},L={80,25,0},W={20,0,10},H={0,0,14},LH={20},RH={-12}},.15,{R={100,0,50},L={100,0,50},W={34,0,0},H={-10,0,0}},{fr(.2,{W={42,0,0},H={-30,0,0}},Q,OUT,.1),fr(.2,{W={30,0,0},H={-30,0,0}},Q,OUT,.1),fr(.2,{W={42,0,0},H={-30,0,0}},Q,OUT,.1)}) end,
  [4]=function(_,P) return throwPose(P) end,
 },
}
-- v1.7: позы сценарных ульт (действие UltStep). Номера совпадают с шагами UltFn в StreetBattles.server.lua
local ULT={
 Siply={
  [1]=function() return S(.08,{R={60,10,0},L={85,0,25},W={-6,22,0}},.05,{R={98,0,12},L={80,0,25},W={18,-26,0},H={-6,-10,0}}) end,
  [2]=function() return S(.12,{R={75,60,30},L={85,0,25},W={-8,50,0},H={0,12,0}},.06,{R={95,-18,35},L={80,0,25},W={16,-50,0},H={-6,-14,0}}) end,
  [3]=function() return S(.14,{R={35,10,0},L={90,0,25},W={-12,42,0}},.06,{R={104,0,18},L={78,0,25},W={30,-52,0},H={-10,-18,0}}) end,
  [4]=function() return S(.18,{R={0,10,0},L={55,0,25},W={26,25,0},H={6,10,0},LH={20},RH={-16}},.07,{R={172,0,10},L={55,0,25},W={-16,-26,0},H={18,0,0},LH={10},RH={-8}}) end,
  [5]=function() return S(.24,{R={178,0,0},L={110,0,20},W={-24,0,0},H={-14,0,0},LH={55},RH={-40}},.07,{R={35,0,12},L={70,0,20},W={46,0,0},H={-22,0,0},LH={40},RH={-30}},{fr(.3,{R={40,0,12},W={34,0,0}},Q,OUT,.2)}) end,
 },
 Bitok={
  [1]=function() return S(.3,{R={170,20,0},L={140,10,0},W={-20,26,0},H={-10,6,0},LH={12},RH={-10}},.08,{R={48,0,14},L={60,0,20},W={34,-34,0},H={12,0,0},LH={30},RH={-24}}) end,
  [2]=function() return S(.3,{R={165,-20,0},L={145,-10,0},W={-18,-30,0},H={-10,-6,0},LH={12},RH={-10}},.08,{R={52,0,8},L={60,0,20},W={34,38,0},H={12,0,0},LH={-24},RH={30}}) end,
  [3]=function() return S(.3,{R={175,10,0},L={150,10,0},W={-24,0,0},H={-14,0,0}},.08,{R={44,0,10},L={56,0,18},W={40,-10,0},H={14,0,0},LH={32},RH={-26}}) end,
  [4]=function() return S(.6,{R={178,0,0},L={165,0,0},W={-32,0,0},H={-18,0,0},LH={14},RH={-12}},.09,{R={38,0,0},L={52,0,10},W={52,0,0},H={20,0,0},LH={34},RH={-28}},{fr(.35,{R={46,0,0},L={58,0,10},W={44,0,0}},Q,OUT,.25)}) end,
 },
 Major={
  [1]=function() return S(.1,{R={70,10,0},L={20,10,0},W={0,10,0}},.05,{R={105,0,10},L={20,10,0},W={10,-6,0},H={-6,0,0}}) end,
  [2]=function() return S(.28,{R={165,10,0},L={90,0,30},W={-12,26,0}},.07,{R={55,0,25},L={90,0,30},W={26,-28,0},H={8,0,0}}) end,
  [3]=function() return S(.22,{R={85,0,15},L={85,0,15},W={12,0,0}},.15,{R={95,0,35},L={60,10,60},W={30,-15,0},LH={20},RH={-14}},{fr(.25,{R={70,0,0},L={70,0,0},W={42,0,0},H={14,0,0}},Q,OUT,.2)}) end,
  [4]=function() return S(.2,{W={-12,0,0},RH={-28},LH={22},R={60,20,0},L={25,10,0}},.08,{W={-28,0,0},RH={96},LH={-22},R={30,30,0},L={80,0,10},H={6,0,0}},{fr(.3,{W={-10,0,0},RH={40},LH={-8}},Q,OUT,.2)}) end,
 },
 Yura={
  [1]=function() return S(.46,{R={170,15,0},L={170,15,0},W={-26,0,0},H={-14,0,0},LH={14},RH={-12}},.08,{R={55,0,20},L={55,0,20},W={44,0,0},H={14,0,0},LH={34},RH={-26}},{fr(.3,{R={60,0,20},L={60,0,20},W={36,0,0}},Q,OUT,.25)}) end,
  [2]=function() return S(.2,{W={-12,30,0},RH={-24},LH={16},R={40,30,0},L={40,30,0}},.09,{W={16,-30,0},RH={94},LH={-18},R={60,40,0},L={60,40,0}}) end,
 },
 Jack={
  [1]=function() return S(.24,{R={165,15,0},L={30,20,0},W={-14,0,0},H={20,0,0}},.07,{R={80,0,10},L={75,0,20},W={30,0,0},H={-10,0,0}},{fr(.3,{R={86,0,10},L={80,0,20},W={24,0,0}},Q,OUT,.15)}) end,
  [2]=function() return S(.1,{R={55,35,0},L={30,20,0},W={-8,30,0}},.05,{R={92,-5,0},L={30,20,0},W={22,-28,0},H={-6,-8,0}}) end,
  [3]=function() return S(.1,{R={60,-20,0},L={30,20,0},W={-8,-26,0}},.05,{R={92,10,0},L={30,20,0},W={22,28,0},H={-6,8,0}}) end,
  [4]=function() return S(.28,{R={30,30,0},L={90,0,25},W={-22,40,0},H={6,10,0}},.08,{R={98,0,0},L={85,0,25},W={42,-46,0},H={-12,-14,0}},{fr(.3,{R={96,0,0},W={36,-30,0}},Q,OUT,.15)}) end,
 },
}
local function skillFrames(fighter,index,special,ult)
 local P=PARAM[fighter] or PARAM.Siply
 local fn=SK[fighter] and SK[fighter][special and 'R' or index]
 if fn then return fn(ult,P) end
 return S(.2,{R={165,12,0},L={165,12,0},W={-14,0,0}},.08,{R={55,0,10},L={55,0,10},W={30,0,0}})
end
local function counterFrames(fighter)
 if fighter=='Jack' then return S(.08,{W={20,50,0},LH={-10},RH={70},R={60,40,0},L={60,40,0}},.1,{W={-6,-50,0},LH={-8},RH={90},R={80,30,0},L={50,40,0}}) end
 return S(.08,{R={10,10,0},L={60,0,25},W={22,28,0},H={6,10,0},LH={20},RH={-16}},.08,{R={172,0,12},L={55,0,25},W={-14,-28,0},H={18,0,0}})
end
local function finisherFrames(fighter)
 if fighter=='Siply' then return S(.22,{W={-8,80,0},RH={-20},R={60,40,0},L={60,40,0}},.1,{W={12,-110,0},RH={95},LH={-15},R={60,60,0},L={80,40,0}},{fr(.2,{W={0,-60,0},R={30,30,0},L={30,30,0}},Q,OUT,.2)}) end
 if fighter=='Bitok' then return S(.3,{R={20,60,0},L={80,0,25},W={-10,60,0}},.08,{R={95,0,70},L={70,0,25},W={30,-70,0},LH={30},RH={-20}},{fr(.3,{R={60,0,40},W={20,-20,0}},Q,OUT,.3)}) end
 if fighter=='Major' then return S(.25,{R={80,0,10},L={80,0,10}},.1,{R={95,0,25},L={95,0,25},W={22,0,0}},{fr(.4,{R={90,0,28},L={90,0,28},W={22,0,0}},Q,OUT,.4)}) end
 if fighter=='Yura' then return S(.2,{W={-10,30,0},RH={-20},R={40,30,0},L={40,30,0}},.1,{W={14,-30,0},RH={90},R={60,40,0},L={60,40,0}}) end
 return S(.3,{W={-30,0,10},H={20,0,0},R={40,30,0},L={40,30,0}},.25,{W={70,0,0},R={140,0,0},L={140,0,0},H={-20,0,0}},{fr(.4,{W={60,0,0},R={90,0,0},L={90,0,0}},Q,OUT,.3)})
end

local function ultFrames(fighter)
 local gather={R={-15,35,0},L={-15,35,0},W={22,0,0},H={14,0,0},LH={18},RH={-18}}
 local burst={R={170,40,0},L={170,40,0},W={-16,0,0},H={30,0,0},LH={8},RH={-8}}
 if fighter=='Diesel' then burst={R={95,70,40},L={95,70,40},W={8,0,0},H={-8,0,0},LH={18},RH={-18}}
 elseif fighter=='Bitok' then burst={R={175,10,0},L={20,25,0},W={-10,20,0},H={25,0,0},LH={8},RH={-8}}
 elseif fighter=='Major' then burst={R={150,0,20},L={20,10,0},W={-4,0,0},H={10,0,0}}
 elseif fighter=='Yura' then burst={R={30,95,0},L={30,95,0},W={-8,0,0},H={34,0,0},LH={10},RH={-10}}
 elseif fighter=='Jack' then burst={R={160,20,0},L={20,40,0},W={-8,0,16},H={26,0,14},LH={14},RH={-6}} end
 return {fr(.3,gather,Q,INOUT),fr(.12,burst,B,OUT,.45)}
end

-- v2.1: рывки в 4 стороны (1 вперёд, 2 назад, 3 влево, 4 вправо), у каждого бойца свой стиль
local DSTYLE={
 Siply ={c=1,  l=1.1,arms='back'},     -- низкий уличный спринт, руки назад
 Diesel={c=.8, l=.8, arms='guard'},    -- боксёрский подшаг, кулаки у лица
 Bitok ={c=.7, l=1,  arms='shoulder'}, -- таран плечом
 Major ={c=.9, l=.7, arms='tight'},    -- уставной рывок, руки прижаты
 Yura  ={c=1.2,l=1.3,arms='flail'},    -- пьяный бросок, руки болтаются
 Jack  ={c=1,  l=.9, arms='flail'},    -- пьяный рывок с размахиванием
}
local function dashArms(st,sg)
 if st=='guard' then return {80,10,55},{88,8,60} end
 if st=='shoulder' then return {30,45,0},{-35,25,0} end
 if st=='tight' then return {-25,6,0},{-25,6,0} end
 if st=='flail' then return {70,55*sg,0},{-40,50,0} end
 return {-60,22,0},{-60,22,0}
end
local function dashFrames(fighter,dir)
 local d=DSTYLE[fighter] or DSTYLE.Siply;local c,l=d.c,d.l
 if dir==2 then -- назад: откидывается, ноги вперёд
  local R1,L1=dashArms(d.arms,1);local guard=d.arms=='guard'
  return {fr(.04,{W={8*c,0,0},H={-6,0,0},LH={10},RH={-8}},Q,OUT),
  fr(.08,{W={-24*l,0,0},H={16,0,0},R=guard and R1 or {45,30,0},L=guard and L1 or {45,30,0},LH={46},RH={24}},BK,OUT,.05),
  fr(.1,{W={-10*l,0,0},H={6,0,0},R=guard and R1 or {20,20,0},L=guard and L1 or {20,20,0},LH={-8},RH={18}},QI,INOUT,.04)}
 elseif dir==3 or dir==4 then -- вбок: крен в сторону рывка, ведущая нога отводится
  local sg=dir==4 and 1 or -1
  local R1,L1=dashArms(d.arms,sg)
  return {fr(.04,{W={8*c,0,-6*sg},H={-4,0,0},RH={6,sg>0 and -4 or 10},LH={6,sg<0 and -4 or 10}},Q,OUT),
  fr(.08,{W={10*c,-14*sg,20*sg*l},H={-4,12*sg,-12*sg},R=R1,L=L1,RH={0,sg>0 and 32 or -6},LH={0,sg<0 and 32 or -6}},BK,OUT,.05),
  fr(.1,{W={6,-6*sg,8*sg},H={0,6*sg,-4*sg},R=R1,L=L1,RH={0,sg>0 and 12 or 4},LH={0,sg<0 and 12 or 4}},QI,INOUT,.04)}
 end
 local R1,L1=dashArms(d.arms,1);local sh=d.arms=='shoulder'
 return {fr(.04,{W={10*c,0,0},H={-6,0,0},R={20,18,0},L={20,18,0},LH={-14*c},RH={18*c}},Q,OUT),
 fr(.08,{W={40*l,sh and 30 or 0,0},H={-18*l,sh and -20 or 0,0},R=R1,L=L1,LH={50},RH={-40}},BK,OUT,.05),
 fr(.1,{W={26*l,sh and 18 or 0,0},H={-10,0,0},R=R1,L=L1,LH={-28},RH={36}},QI,INOUT,.04)}
end

local function framesFor(fighter,kind,index,heavy,ult)
 if kind=='Punch' then return punchFrames(fighter,index or 1,heavy),true
 elseif kind=='Skill' then return skillFrames(fighter,index or 1,false,ult),true
 elseif kind=='Special' then return skillFrames(fighter,1,true,ult),true
 elseif kind=='Counter' then return counterFrames(fighter),true
 elseif kind=='UltStep' then
  local fn=ULT[fighter] and ULT[fighter][index or 1]
  if fn then return fn(),true end
  return skillFrames(fighter,1,false,ult),true
 elseif kind=='Finisher' then return finisherFrames(fighter),true
 elseif kind=='Ult' then return ultFrames(fighter),false
 elseif kind=='Dash' then
return dashFrames(fighter,index or 1),false
elseif kind=='Block' then
  local g={R={105,10,28},L={105,10,28},W={10,0,0},H={-12,0,0},LH={18},RH={-14}}
  if fighter=='Jack' then g=merge(g,{W={14,0,8},H={-14,0,10}}) elseif fighter=='Diesel' then g=merge(g,{W={18,0,0},LH={26},RH={-20}}) end
  return {fr(.12,g,Q,OUT)},false
 elseif kind=='Hit' then
  local sd=(math.random(2)==1) and 1 or -1 -- каждый раз отшатывается в другую сторону
if index==2 then -- v2.1: сильный удар — тело отбрасывает назад, руки разлетаются
 return {fr(.05,{R={-35,40,0},L={-35,40,0},W={-32,18*sd,10*sd},H={36,14*sd,10*sd},LH={-20},RH={24}},Q,OUT,.1),
 fr(.22,{R={-10,20,0},L={-10,20,0},W={-12,8*sd,4*sd},H={14,6*sd,4*sd},LH={-6},RH={8}},QI,OUT,0)},false
end
  return {fr(.05,{R={-20,25,0},L={-20,25,0},W={-20,14*sd,7*sd},H={28,12*sd,9*sd},LH={-8},RH={12}},Q,OUT,.05),
   fr(.12,{R={-8,12,0},L={-8,12,0},W={-8,6*sd,3*sd},H={10,4*sd,3*sd}},QI,OUT,0)},false
 end
end

-- v2.1: шлейфы за конечностями во время удара (цвет бойца), создаются только на клиенте
local TCOL={Siply=Color3.fromRGB(225,232,255),Diesel=Color3.fromRGB(255,150,70),Bitok=Color3.fromRGB(255,110,90),Major=Color3.fromRGB(120,170,255),Yura=Color3.fromRGB(150,240,110),Jack=Color3.fromRGB(255,205,110)}
local function limbTrail(limb)
 local t=limb:FindFirstChild('SB_LimbTrail');if t then return t end
 local a0=Instance.new('Attachment');a0.Name='SB_TA0';a0.Position=Vector3.new(0,-.7,0);a0.Parent=limb
 local a1=Instance.new('Attachment');a1.Name='SB_TA1';a1.Position=Vector3.new(0,-1.05,0);a1.Parent=limb
 t=Instance.new('Trail');t.Name='SB_LimbTrail';t.Attachment0=a0;t.Attachment1=a1;t.Lifetime=.14;t.MinLength=.05;t.FaceCamera=true;t.LightEmission=.9;t.LightInfluence=0
 t.WidthScale=NumberSequence.new({NumberSequenceKeypoint.new(0,3.2),NumberSequenceKeypoint.new(1,0)})
 t.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.3),NumberSequenceKeypoint.new(.6,.75),NumberSequenceKeypoint.new(1,1)})
 t.Enabled=false;t.Parent=limb
 return t
end
local function setTrails(char,on,kick,fighter)
 local props=char and char:FindFirstChild('FighterProp')
 if props then for _,d in ipairs(props:GetDescendants()) do if d:IsA('Trail') then d.Enabled=on end end end
 if not char then return end
 local col=TCOL[fighter or ''] or Color3.new(1,1,1)
 for _,nm in ipairs({'Right Arm','Left Arm','Right Leg','Left Leg'}) do
  local limb=char:FindFirstChild(nm)
  if limb then
   local leg=nm:find('Leg')~=nil
   local t=limb:FindFirstChild('SB_LimbTrail')
   if on and (not leg or kick) then t=limbTrail(limb);t.Color=ColorSequence.new(Color3.new(1,1,1),col);t.Enabled=true
   elseif t then t.Enabled=false end
  end
 end
end

local function play(player,kind,index,hold,heavy)
 local char=player.Character;local hum=char and char:FindFirstChildOfClass('Humanoid')
 if not hum or hum.Health<=0 then return end
 local motors=joints(char);if not motors then return end
 local id=player.UserId
 tokens[id]=(tokens[id] or 0)+1;local token=tokens[id]
 rest[char]=rest[char] or {}
 local r=rest[char]
 for k,m in pairs(motors) do r[k]=r[k] or m.C0 end
 local fname=player:GetAttribute('Fighter') or 'Siply'
local frames,strike=framesFor(fname,kind,index,heavy,player:GetAttribute('UltActive'))
if not frames then return end
local total,kick=0,false -- v2.1: сколько длится действие (для Locomotion) и есть ли пинок (шлейф за ногой)
for _,f in ipairs(frames) do total+=f.dur+f.hold;if (f.pose.RH and (f.pose.RH[1] or 0)>60) or (f.pose.LH and (f.pose.LH[1] or 0)>60) then kick=true end end
char:SetAttribute('SB_Act',hold and os.clock()+1e6 or os.clock()+total+.4)
 if strike then -- автоматический футворк: если в кадре не заданы ноги, они шагают (чередуя «шаг» и «упор»)
  local sg=(token%2==0) and 1 or -1
  for i,f in ipairs(frames) do
   if not f.pose.LH and not f.pose.RH then
    local a=(i%2==1) and 13 or -9
    f.pose.LH={a*sg};f.pose.RH={-a*sg}
   end
  end
 end
 task.spawn(function()
  if strike then setTrails(char,true,kick,fname) end
  for _,f in ipairs(frames) do
   if tokens[id]~=token or player.Character~=char then return end
   local Rw=bodyRot(f.pose.W)
   for k,m in pairs(motors) do
    if m.Parent then TweenService:Create(m,TweenInfo.new(f.dur,f.style,f.dir),{C0=goal(k,r[k],f.pose[k],Rw)}):Play() end
   end
   task.wait(f.dur+f.hold)
  end
  if tokens[id]~=token or player.Character~=char then return end
  if strike then setTrails(char,false) end
  if hold then return end
  if strike then -- доводка: сначала расслабление на треть пути к стойке, потом плавный возврат
   local last=frames[#frames];local Rw=bodyRot(last.pose.W)
   for k,m in pairs(motors) do
    if m.Parent and r[k] then TweenService:Create(m,TweenInfo.new(.1,Q,OUT),{C0=goal(k,r[k],last.pose[k],Rw):Lerp(r[k],.4)}):Play() end
   end
   task.wait(.1)
   if tokens[id]~=token or player.Character~=char then return end
  end
  for k,m in pairs(motors) do if m.Parent and r[k] then TweenService:Create(m,TweenInfo.new(.3,QI,INOUT),{C0=r[k]}):Play() end end
 end)
end
local function reset(player)
 local char=player.Character;tokens[player.UserId]=(tokens[player.UserId] or 0)+1
 local r=char and rest[char];if not r then return end
 setTrails(char,false);char:SetAttribute('SB_Act',0)
for k,m in pairs(joints(char) or {}) do if r[k] and m.Parent then TweenService:Create(m,TweenInfo.new(.2,Q,OUT),{C0=r[k]}):Play() end end
end

event.OnClientEvent:Connect(function(kind,data)
 if kind~='Animate' or type(data)~='table' then return end
 local p=Players:GetPlayerByUserId(data.userId or 0);if not p then return end
 if data.action=='BlockEnd' then reset(p)
 elseif data.action=='Block' then play(p,'Block',1,true)
 else play(p,data.action,data.index,false,data.heavy) end
end)
Players.PlayerRemoving:Connect(function(p) tokens[p.UserId]=nil end)

-- (Аура ульта — Highlight, огонь и свет — теперь рисуется в VfxClient.client.lua)
