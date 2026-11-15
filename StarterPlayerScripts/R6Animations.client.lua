-- R6Animations v2.2: процедурные анимации на ключевых кадрах (без загрузки Animation ID).
-- v2.2: все скиллы переделаны под описания, у каждого бойца свой набор M1, свой блок, свои контратаки и реакция на удар.
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

-- v2.2: у каждого бойца свой набор обычных ударов (M1): {замах, удар} на каждый удар серии + отдельный тяжёлый.
local M1={
 Siply={ -- кастет: прямой правой, боковой левой, тяжёлый — кастетом сверху
  light={
   {{R={40,12,0},L={80,0,30},W={-6,16,0},H={-4,8,0}},{R={96,0,14},L={70,0,30},W={14,-20,0},H={-6,-10,0}}},
   {{L={70,40,-20},R={75,0,30},W={-4,-22,0},H={-4,-8,0}},{L={88,-20,60},R={70,0,30},W={14,26,0},H={-6,10,0}}},
  },
  heavy={{R={165,20,0},L={70,0,25},W={-12,36,0},H={-8,12,0}},{R={50,-5,40},L={60,0,25},W={34,-40,0},H={10,-12,0}}}},
 Diesel={ -- бокс: джеб, кросс, боковой, тяжёлый — апперкот
  light={
   {{L={70,8,50},R={80,10,58},W={10,-18,0},H={-10,14,0}},{L={100,0,8},R={78,10,58},W={16,12,0},H={-8,-6,0}}},
   {{R={72,10,50},L={85,8,60},W={10,-10,0},H={-10,10,0}},{R={100,0,6},L={80,8,60},W={20,-30,0},H={-8,-10,0}}},
   {{L={75,45,-10},R={80,10,58},W={6,-26,0},H={-8,-10,0}},{L={90,-15,70},R={80,10,58},W={14,30,0},H={-6,12,0}}},
  },
  heavy={{R={-5,15,0},L={85,8,60},W={30,28,0},H={6,10,0}},{R={170,-5,15},L={60,8,40},W={-16,-26,0},H={18,0,0}}}},
 Bitok={ -- громила: удар предплечьем, тыльной стороной, кулаком-молотом, тяжёлый — двумя руками сверху
  light={
   {{R={140,30,0},L={60,10,20},W={-8,26,0},H={-6,8,0}},{R={60,0,30},L={60,10,20},W={24,-24,0},H={4,-8,0}}},
   {{L={80,-30,40},R={60,15,20},W={0,-30,0},H={-4,-10,0}},{L={85,60,-10},R={60,15,20},W={14,30,0},H={0,12,0}}},
   {{R={175,10,0},L={50,10,10},W={-14,10,0},H={-10,0,0}},{R={45,0,0},L={50,10,10},W={34,-6,0},H={14,0,0}}},
  },
  heavy={{R={178,0,-15},L={178,0,-15},W={-24,0,0},H={-14,0,0}},{R={40,0,-10},L={40,0,-10},W={46,0,0},H={18,0,0}}}},
 Major={ -- милиция: удар ладонью, джеб, боковой, тяжёлый — прямой пинок ногой
  light={
   {{R={50,10,0},L={10,8,34},W={-2,12,0},H={2,0,0}},{R={95,0,0},L={10,8,34},W={10,-10,0},H={-4,0,0}}},
   {{L={60,8,20},R={-6,16,-24},W={0,-12,0},H={0,0,0}},{L={96,0,10},R={-6,16,-24},W={10,12,0},H={-4,4,0}}},
   {{R={70,50,-20},L={60,8,30},W={-4,28,0},H={-2,8,0}},{R={88,-20,65},L={60,8,30},W={14,-30,0},H={-4,-10,0}}},
  },
  heavy={{W={-10,0,0},H={4,0,0},RH={-30},LH={8},R={40,20,0},L={40,20,0}},{W={-22,0,0},H={6,0,0},RH={100},LH={-14},R={30,30,0},L={50,30,0}}}},
 Yura={ -- бомж: пощёчина правой, левой, толчок двумя руками, тяжёлый — удар головой
  light={
   {{R={60,70,0},L={10,10,0},W={0,30,6},H={-6,10,6}},{R={80,-30,0},L={10,10,0},W={10,-26,-6},H={0,-10,6}}},
   {{L={60,70,0},R={10,10,0},W={0,-30,-6},H={-6,-10,-6}},{L={80,-30,0},R={10,10,0},W={10,26,6},H={0,10,-6}}},
   {{R={60,10,0},L={60,10,0},W={-8,0,0},H={6,0,0}},{R={95,-5,0},L={95,-5,0},W={22,0,0},H={-8,0,0}}},
  },
  heavy={{W={-24,0,0},H={30,0,0},R={60,30,0},L={60,30,0}},{W={36,0,0},H={-30,0,0},R={90,-10,0},L={90,-10,0}}}},
 Jack={ -- пьяный капитан: размашистый бутылкой, левый «мельница», бутылкой наотмашь, тяжёлый — бутылкой сверху
  light={
   {{R={90,80,0},L={-6,24,10},W={-6,40,-8},H={8,10,-8}},{R={95,-20,40},L={-6,24,10},W={18,-36,8},H={0,-12,-8}}},
   {{L={100,70,0},R={42,8,22},W={-6,-40,8},H={8,-10,8}},{L={95,-20,40},R={42,8,22},W={18,36,-8},H={0,12,8}}},
   {{R={80,-40,60},L={-6,24,10},W={4,-30,0},H={4,-8,-6}},{R={90,70,-20},L={-6,24,10},W={12,34,-10},H={2,10,-8}}},
  },
  heavy={{R={178,10,0},L={20,30,0},W={-20,0,-10},H={-12,0,-8}},{R={40,0,10},L={40,30,0},W={40,0,10},H={14,0,6}}}},
}
local function punchFrames(fighter,index,heavy)
 local m=M1[fighter] or M1.Siply
 if heavy then return {fr(.2,merge(m.heavy[1]),Q,INOUT),fr(.1,merge(m.heavy[2]),BK,OUT,.12)} end
 local pr=m.light[((index-1)%#m.light)+1]
 return {fr(.06,merge(pr[1]),Q,OUT),fr(.07,merge(pr[2]),BK,OUT,.05)}
end

-- Навыки: у каждого бойца свои позы. S(замах,поза,удар,поза[,доп.кадры])
local function S(t1,w,t2,h,extra)
 local list={fr(t1,w,Q,INOUT),fr(t2,h,BK,OUT,.12)}
 for _,f in ipairs(extra or {}) do list[#list+1]=f end
 return list
end
-- v2.2: скиллы полностью переделаны под описания. Кадр: {длительность, поза, стиль, направление, пауза}.
-- Момент удара (конец кадра со стилем BK) совпадает с ударом на сервере (strike/seek в StreetBattles).
local function throwPose(P) return S(.22,{R={172,12,0},L={60,0,25},W={-14,32,P.roll},H={-14,10,P.tilt},LH={14},RH={-10}},.08,{R={58,0,10},L={40,0,25},W={22,-34,-P.roll},H={10,-8,0},LH={26},RH={-18}}) end
local function seq(list) local o={} for _,f in ipairs(list) do o[#o+1]=fr(f[1],f[2],f[3] or Q,f[4] or OUT,f[5] or 0) end return o end
local SK={
Siply={
 [1]=function() return seq({ -- Тяжёлый кастет: отводит кулак далеко назад, вымеряет левой, мощный прямой (удар .45)
  {.12,{R={30,20,-10},L={70,0,30},W={-6,30,0},H={-6,10,0},LH={10},RH={-14}}},
  {.26,{R={-30,30,0},L={95,0,40},W={-10,48,6},H={-10,20,0},LH={24},RH={-22}},QI,INOUT},
  {.07,{R={92,0,10},L={30,10,-10},W={30,-46,-6},H={-14,-16,0},LH={34},RH={-30}},BK},
  {.12,{R={100,-10,20},L={40,10,0},W={34,-50,-4},H={-16,-18,0},LH={36},RH={-32}},Q,OUT,.12}}) end,
 [2]=function() return seq({ -- Скрытый клинок: нож спрятан за спиной, короткий укол в живот (.17), проворот, рывок назад
  {.05,{R={-35,10,0},L={60,10,30},W={4,20,0},H={-4,10,0}}},
  {.06,{R={30,5,0},L={60,10,30},W={14,10,0},H={-6,0,0},LH={20},RH={-12}}},
  {.06,{R={78,-5,8},L={40,20,20},W={24,-20,0},H={-10,-8,0},LH={28},RH={-20}},BK},
  {.1,{R={80,-5,60},L={40,20,20},W={26,-24,4},H={-10,-10,0}},Q,OUT,.05},
  {.08,{R={40,10,0},L={50,10,20},W={6,0,0},H={0,0,0}}}}) end,
 [3]=function() return seq({ -- Мобилка есть позвонить?: телефон у уха, рывок, хватает за шкирку (.3), трясёт, толкает
  {.12,{R={140,20,60},L={10,20,0},W={-4,0,0},H={0,20,8}}},
  {.15,{R={130,20,60},L={95,10,10},W={30,0,0},H={-12,0,0},LH={40},RH={-30}},QI,INOUT},
  {.05,{R={150,30,40},L={88,-10,20},W={20,-10,0},H={-6,-6,0},LH={30},RH={-22}},BK},
  {.12,{R={120,30,30},L={60,-10,20},W={-6,14,0},H={8,10,0}},Q,OUT,.1},
  {.1,{R={60,20,20},L={100,0,10},W={18,-10,0},H={-4,0,0},LH={26},RH={-18}},BK,OUT,.08}}) end,
 [4]=function() return seq({ -- Дворовой апперкот: глубокий присед, взрывной апперкот вверх (.3) с подпрыгиванием
  {.12,{R={-10,15,0},L={70,0,30},W={30,25,0},H={10,10,0},LH={34},RH={-10}}},
  {.12,{R={-25,15,0},L={75,0,30},W={34,30,0},H={12,10,0},LH={40},RH={-14}}},
  {.06,{R={175,-5,10},L={40,10,20},W={-22,-28,0},H={22,-6,0},LH={10},RH={-20}},BK},
  {.15,{R={178,0,10},L={40,10,20},W={-26,-20,0},H={26,0,0},LH={6},RH={-16}},Q,OUT,.12}}) end,
},
Diesel={
 [1]=function(ult)
  if ult then -- в ульте: шквал из 5 ударов
   local f={}
   for i=1,5 do
    local r=i%2==1;local A,B2=r and 'R' or 'L',r and 'L' or 'R'
    f[#f+1]=fr(.05,{[A]={30,12,0},[B2]={90,0,28},W={-4,(r and 20 or -20),0}},Q,OUT)
    f[#f+1]=fr(.07,{[A]={95,0,24},[B2]={85,0,28},W={16,(r and -28 or 28),0},LH={22},RH={-16}},BK,OUT)
   end
   return f
  end
  return seq({ -- Двойка на скачке: подшаг в стойке, джеб левой (.22), кросс правой (.38)
  {.08,{R={75,10,58},L={85,8,62},W={14,-18,0},H={-10,14,0},LH={20},RH={-14}}},
  {.08,{R={75,10,58},L={60,10,30},W={16,-10,0},H={-10,10,0}}},
  {.06,{R={78,10,58},L={100,0,8},W={18,14,0},H={-8,-6,0},LH={26},RH={-18}},BK},
  {.06,{R={75,10,55},L={75,8,55},W={16,0,0},H={-8,0,0}}},
  {.04,{R={70,10,40},L={80,8,60},W={14,-6,0},H={-8,0,0}}},
  {.06,{R={100,0,6},L={80,8,60},W={24,-34,0},H={-10,-10,0},LH={30},RH={-24}},BK},
  {.1,{R={95,0,10},L={82,8,60},W={22,-30,0},H={-8,-8,0}},Q,OUT,.08}})
 end,
 [2]=function() return seq({ -- Маятник: нырки вправо-влево под руками в высокой защите
  {.1,{W={22,0,26},H={6,0,-18},R={78,10,58},L={86,8,62},LH={24},RH={-16}},Q,OUT,.06},
  {.14,{W={22,0,-26},H={6,0,18},R={78,10,58},L={86,8,62},LH={-16},RH={24}},QI,INOUT,.06},
  {.12,{W={30,0,10},H={-6,0,-6},R={78,10,58},L={86,8,62},LH={26},RH={-18}},QI,INOUT,.05}}) end,
 [3]=function() return seq({ -- Корпусной сокрушитель: уходит вниз, боковой по печени (.35)
  {.1,{R={60,15,30},L={80,8,60},W={30,15,0},H={-6,10,0},LH={36},RH={-20}}},
  {.18,{R={20,30,0},L={85,8,62},W={36,30,10},H={-4,14,0},LH={38},RH={-22}},QI,INOUT},
  {.07,{R={70,-10,40},L={85,8,62},W={38,-34,-6},H={-8,-12,0},LH={40},RH={-26}},BK},
  {.15,{R={72,-20,55},L={85,8,62},W={36,-40,-6},H={-8,-14,0}},Q,OUT,.12}}) end,
 [4]=function() return seq({ -- Пробивной хук: заводит правую высоко назад, оверхенд сверху наискось (.5)
  {.15,{R={60,40,0},L={85,8,60},W={-6,40,0},H={-6,10,0},LH={14},RH={-12}}},
  {.28,{R={170,30,0},L={80,8,55},W={-18,44,8},H={-10,14,0},LH={16},RH={-12}},QI,INOUT},
  {.07,{R={60,-10,50},L={50,10,20},W={40,-48,-10},H={10,-14,0},LH={34},RH={-28}},BK},
  {.15,{R={30,-20,60},L={50,10,20},W={44,-54,-12},H={12,-16,0}},Q,OUT,.1}}) end,
},
Bitok={
 [1]=function() return seq({ -- Рассечение с локтя: разворот корпуса, локоть поперёк лица (.2)
  {.08,{R={80,60,-20},L={70,0,30},W={-4,40,0},H={-4,12,0}}},
  {.06,{R={88,30,30},L={65,0,30},W={6,10,0},H={-4,4,0}}},
  {.06,{R={92,-10,95},L={60,0,30},W={20,-45,0},H={-6,-18,0},LH={26},RH={-18}},BK},
  {.12,{R={90,-20,110},L={60,0,30},W={22,-55,0},H={-6,-20,0}},Q,OUT,.1}}) end,
 [2]=function() return seq({ -- Грязный трюк: нагибается, загребает пыль с асфальта и швыряет в лицо (.2), прикрывается
  {.1,{R={60,10,0},L={40,20,0},W={44,10,0},H={20,0,0},LH={34},RH={-20}}},
  {.06,{R={150,10,-10},L={40,20,0},W={0,-10,0},H={-6,0,0}},BK},
  {.04,{R={165,0,-20},L={40,20,0},W={-8,-14,0},H={-8,0,0}}},
  {.2,{R={120,10,-10},L={120,0,40},W={-4,-10,0},H={6,0,0}},Q,OUT,.1}}) end,
 [3]=function() return seq({ -- Бросок через бедро: хватает двумя руками (.25), разворачивает бедро, бросает об асфальт (.55)
  {.12,{R={95,10,10},L={95,10,10},W={24,0,0},H={-6,0,0},LH={30},RH={-20}}},
  {.13,{R={80,-10,30},L={80,-10,30},W={20,0,0},H={-6,0,0}},BK},
  {.18,{R={110,0,10},L={70,0,40},W={30,-80,0},H={-6,-20,0},LH={10},RH={30}},QI,INOUT},
  {.12,{R={40,0,0},L={40,0,0},W={60,-100,0},H={20,-20,0},LH={-10},RH={40}},BK},
  {.3,{R={50,0,10},L={50,0,10},W={50,-60,0},H={14,-10,0}},Q,OUT,.15}}) end,
 [4]=function() return seq({ -- Удар арматурой: двумя руками над головой, со всей силы сверху вниз (.5)
  {.2,{R={170,10,0},L={160,10,0},W={-22,20,0},H={-12,0,0},LH={12},RH={-10}}},
  {.23,{R={178,0,-10},L={170,0,-10},W={-28,26,0},H={-14,4,0},LH={14},RH={-12}},QI,INOUT},
  {.07,{R={45,0,10},L={55,0,15},W={42,-20,0},H={14,0,0},LH={34},RH={-28}},BK},
  {.25,{R={40,0,10},L={50,0,15},W={46,-14,0},H={16,0,0}},Q,OUT,.15}}) end,
},
Major={
 [1]=function() return seq({ -- Предъявите документы: раскрывает удостоверение перед лицом и тычет им (.18)
  {.08,{R={60,10,0},L={10,8,34},W={0,10,0},H={2,0,0}}},
  {.06,{R={96,0,0},L={10,8,34},W={4,-4,0},H={-4,0,0}},BK},
  {.04,{R={100,0,0},L={10,8,34},W={12,-10,0},H={-6,0,0},LH={22},RH={-14}}},
  {.2,{R={98,0,0},L={10,8,34},W={6,-6,0},H={8,0,0}},Q,OUT,.1}}) end,
 [2]=function() return seq({ -- Удар дубинкой: замах дубинкой над головой, рубящий удар наискось (.35)
  {.12,{R={150,30,0},L={60,0,30},W={-8,26,0},H={-4,8,0}}},
  {.16,{R={175,20,0},L={60,0,30},W={-14,34,0},H={-8,10,0},LH={14},RH={-10}},QI,INOUT},
  {.07,{R={50,-10,35},L={50,0,30},W={30,-30,0},H={8,-10,0},LH={28},RH={-20}},BK},
  {.15,{R={30,-10,40},L={50,0,30},W={32,-34,0},H={10,-12,0}},Q,OUT,.12}}) end,
 [3]=function() return seq({ -- В отделение!: хватает (.25), тащит на себя, впечатывает в асфальт (.65) и надевает наручники
  {.12,{R={95,0,10},L={95,0,10},W={20,0,0},H={-6,0,0},LH={26},RH={-18}}},
  {.13,{R={85,-10,30},L={85,-10,30},W={18,0,0},H={-6,0,0}},BK},
  {.2,{R={70,0,20},L={70,0,20},W={-10,0,0},H={6,0,0},LH={-14},RH={20}},QI,INOUT},
  {.2,{R={40,0,0},L={40,0,0},W={50,0,0},H={20,0,0},LH={30},RH={-22}},BK},
  {.3,{R={30,0,30},L={30,0,30},W={46,0,0},H={18,0,0}},Q,OUT,.15}}) end,
 [4]=function() return seq({ -- Предупредительный выстрел: выхватывает из кобуры, стреляет вверх (.3), наводит на врага
  {.12,{R={-15,18,0},L={10,8,34},W={4,-6,0},H={0,-10,0}}},
  {.14,{R={175,0,0},L={20,10,0},W={-6,0,0},H={20,0,0}},BK},
  {.04,{R={168,0,0},L={20,10,0},W={-8,0,0},H={24,0,0}}},
  {.15,{R={90,0,0},L={85,0,15},W={0,0,0},H={-2,0,0}},QI,INOUT,.2}}) end,
 R=function() return seq({ -- Выстрел: хват двумя руками, отдача (.1)
  {.06,{R={88,0,8},L={86,0,22},W={0,0,0},H={-6,0,0}}},
  {.04,{R={100,0,8},L={96,0,22},W={-4,0,0},H={-4,0,0}},BK},
  {.08,{R={88,0,8},L={86,0,22},W={0,0,0},H={-6,0,0}},Q,OUT,.05}}) end,
},
Yura={
 [1]=function() return seq({ -- Бросок стеклотары: бутылка высоко за головой, бросок через плечо (.25)
  {.12,{R={175,15,0},L={70,10,10},W={-14,32,0},H={-12,10,0},LH={14},RH={-10}}},
  {.09,{R={178,25,0},L={75,10,10},W={-18,38,0},H={-12,12,0}},QI,INOUT},
  {.05,{R={60,0,10},L={30,10,10},W={24,-32,0},H={10,-8,0},LH={26},RH={-18}},BK},
  {.2,{R={50,0,10},L={30,10,10},W={20,-26,0},H={6,-6,0}},Q,OUT,.1}}) end,
 [2]=function() return seq({ -- Токсичная струя: глубокий вдох (грудь вверх, голова назад), плевок (.25) и водит головой
  {.18,{R={20,40,0},L={20,40,0},W={-20,0,0},H={30,0,0},LH={6},RH={-6}}},
  {.05,{R={22,42,0},L={22,42,0},W={-22,0,0},H={32,0,0}},Q,OUT,.02},
  {.05,{R={40,60,0},L={40,60,0},W={26,0,0},H={-20,0,0},LH={20},RH={-14}},BK},
  {.15,{R={40,60,0},L={40,60,0},W={26,18,0},H={-20,20,0}},QI,INOUT},
  {.15,{R={40,60,0},L={40,60,0},W={26,-18,0},H={-20,-20,0}},QI,INOUT,.05}}) end,
 [3]=function() return seq({ -- Захват с перегаром: медвежьи объятия (.25), валит и дышит в лицо (.75, 1.15)
  {.12,{R={90,60,0},L={90,60,0},W={30,0,0},H={-10,0,0},LH={40},RH={-30}}},
  {.13,{R={90,-25,0},L={90,-25,0},W={40,0,0},H={-6,0,0}},BK},
  {.25,{R={70,-25,0},L={70,-25,0},W={55,0,0},H={10,0,0},LH={30},RH={-24}},QI,INOUT},
  {.25,{R={70,-25,0},L={70,-25,0},W={60,0,0},H={-20,0,0}},QI,INOUT},
  {.15,{R={70,-25,0},L={70,-25,0},W={55,0,0},H={10,0,0}}},
  {.25,{R={70,-25,0},L={70,-25,0},W={60,0,0},H={-20,0,0}},QI,INOUT,.05}}) end,
 [4]=function() return seq({ -- Удар пакетом: раскручивает пакет за спиной, широкий удар с разворота (.55)
  {.2,{R={90,90,0},L={40,10,0},W={-6,50,0},H={-6,14,0}}},
  {.25,{R={120,100,-30},L={40,10,0},W={-10,70,0},H={-10,20,0},LH={14},RH={-12}},QI,INOUT},
  {.1,{R={90,-30,40},L={40,20,0},W={30,-80,0},H={8,-20,0},LH={30},RH={-20}},BK},
  {.15,{R={80,-60,50},L={40,20,0},W={30,-95,0},H={8,-24,0}},Q,OUT,.15}}) end,
 R=function() return seq({ -- Отрыжка: надувает живот, голова назад, мощная отрыжка вперёд (.2)
  {.14,{R={10,30,0},L={10,30,0},W={-16,0,0},H={36,0,0}}},
  {.06,{R={30,60,0},L={30,60,0},W={18,0,0},H={-24,0,0}},BK},
  {.2,{R={20,40,0},L={20,40,0},W={14,0,0},H={-10,0,0}},Q,OUT,.1}}) end,
},
Jack={
 [1]=function() return seq({ -- Освежающий душ: трясёт бутылку, затыкает пальцем и брызгает пивом в лицо (.25)
  {.06,{R={70,10,10},L={-6,24,10},W={4,0,0},H={0,0,0}}},
  {.05,{R={80,10,-20},L={-6,24,10},W={4,0,4},H={0,0,4}}},
  {.05,{R={70,10,10},L={-6,24,10},W={4,0,-4},H={0,0,-4}}},
  {.05,{R={80,10,-20},L={-6,24,10},W={4,0,4},H={0,0,4}}},
  {.04,{R={100,0,0},L={30,30,0},W={10,0,0},H={-6,0,0},LH={20},RH={-12}},BK},
  {.3,{R={95,0,0},L={30,30,0},W={8,4,0},H={-4,0,0}},Q,OUT,.1}}) end,
 [2]=function() return seq({ -- Случайный махач: пьяно валится назад, размахивая руками
  {.12,{W={-34,0,-14},H={24,0,-10},R={80,50,0},L={70,50,0},LH={40},RH={10}},Q,OUT,.15},
  {.2,{W={-40,0,10},H={28,0,8},R={100,60,0},L={90,60,0},LH={50},RH={20}},QI,INOUT,.15}}) end,
 [3]=function() return seq({ -- Пойдём отойдём: обнимает (.3) и трижды бьёт лбом (.6, .9, 1.2)
  {.15,{R={90,40,0},L={90,40,0},W={10,0,0},H={6,0,0}}},
  {.15,{R={90,-25,0},L={90,-25,0},W={14,0,0},H={0,0,0}},BK},
  {.18,{R={90,-25,0},L={90,-25,0},W={-14,0,0},H={30,0,0}},QI,INOUT},
  {.12,{R={90,-25,0},L={90,-25,0},W={30,0,0},H={-30,0,0}},BK},
  {.18,{R={90,-25,0},L={90,-25,0},W={-14,0,0},H={30,0,0}},QI,INOUT},
  {.12,{R={90,-25,0},L={90,-25,0},W={30,0,0},H={-30,0,0}},BK},
  {.18,{R={90,-25,0},L={90,-25,0},W={-16,0,0},H={34,0,0}},QI,INOUT},
  {.12,{R={90,-25,0},L={90,-25,0},W={34,0,0},H={-34,0,0}},BK,OUT,.3}}) end,
 [4]=function() return seq({ -- Бросок пустой тары: пьяный бросок сбоку с разворотом (.3), шатается
  {.14,{R={90,80,0},L={-6,24,10},W={-8,50,10},H={-6,14,-10}}},
  {.1,{R={100,100,-20},L={-6,24,10},W={-10,60,14},H={-6,16,-10}},QI,INOUT},
  {.06,{R={90,-20,30},L={10,24,10},W={24,-50,-8},H={6,-14,0},LH={26},RH={-18}},BK},
  {.15,{R={70,-20,30},L={10,24,10},W={18,-30,-14},H={10,-10,-14}},Q,OUT,.15}}) end,
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
local function counterFrames(fighter) -- v2.2: контратаки (удар через .12 после начала)
 if fighter=='Jack' then -- подсечка с земли
  return S(.05,{W={30,60,0},H={10,0,0},R={60,60,0},L={60,60,0},LH={-10},RH={60,10}},.07,{W={24,-80,0},H={6,-20,0},R={70,40,0},L={50,40,0},LH={-8},RH={90,-40}},
   {fr(.2,{W={20,-60,0},H={4,-10,0},R={60,40,0},L={50,40,0},LH={0},RH={30}},Q,OUT,.15)})
 end
 return S(.06,{R={-10,10,0},L={80,8,60},W={30,28,0},H={6,10,0},LH={30},RH={-14}},.06,{R={175,-5,10},L={50,10,20},W={-20,-26,0},H={22,0,0},LH={10},RH={-18}},
  {fr(.2,{R={170,0,10},L={50,10,20},W={-18,-20,0},H={20,0,0}},Q,OUT,.1)})
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
-- v2.2: блок и реакция на удар у каждого бойца свои
local BLOCK={
 Siply ={R={110,0,70},L={105,10,40},W={12,-10,0},H={-14,0,0},LH={18},RH={-14}},      -- прикрывается предплечьем с кастетом
 Diesel={R={100,8,75},L={100,8,75},W={20,0,0},H={-18,0,0},LH={26},RH={-20}},        -- плотная боксёрская защита
 Bitok ={R={95,-30,20},L={95,-30,20},W={6,0,0},H={-10,0,0},LH={6,14},RH={-6,14}},   -- скрещённые руки, широкая стойка
 Major ={R={100,10,80},L={60,20,30},W={4,-14,0},H={-6,0,0},LH={14},RH={-10}},       -- уставной блок предплечьем
 Yura  ={R={130,10,30},L={130,10,30},W={30,0,0},H={-24,0,0},LH={24},RH={-10}},      -- съёживается, закрывает голову
 Jack  ={R={110,20,40},L={100,20,40},W={-6,0,10},H={-8,0,12},LH={16},RH={-8}},      -- пьяно отклоняется, руки вверх
}
local HITAMP={Siply=1,Diesel=.8,Bitok=.6,Major=.9,Yura=1.35,Jack=1.2} -- насколько сильно шатает от удара
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
local g=BLOCK[fighter] or BLOCK.Siply
return {fr(.06,merge(g,{W={(g.W[1] or 0)+10,g.W[2] or 0,g.W[3] or 0}}),Q,OUT),fr(.08,merge(g),BK,OUT)},false
elseif kind=='Hit' then
  local sd=((math.random(2)==1) and 1 or -1)*(HITAMP[fighter] or 1) -- каждый раз отшатывается в другую сторону
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
