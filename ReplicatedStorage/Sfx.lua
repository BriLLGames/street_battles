-- Sfx v1.3: звуки боя, скиллов, ультов и интерфейса. ModuleScript, работает только на клиенте.
-- По умолчанию используются звуки, которые уже лежат внутри Roblox (rbxasset://sounds/...), поэтому грузить ничего не надо.
-- Они простые и «мультяшные». Чтобы звучало лучше: найди звук в Creator Store (Toolbox → Audio) или загрузи свой
-- и замени id в таблице LIB ниже на 'rbxassetid://ЦИФРЫ'. Если какой-то звук не загрузится — в Output будет предупреждение [SFX].
local Debris=game:GetService('Debris')
local SoundService=game:GetService('SoundService')
local ContentProvider=game:GetService('ContentProvider')
local Sfx={}

Sfx.Volume=1 -- общая громкость всех эффектов (0..1.5)

local B='rbxasset://sounds/'
local SLASH,LUNGE,UNSHEATH=B..'swordslash.wav',B..'swordlunge.wav',B..'unsheath.wav'
local PLUNK,SNAP,SPLAT,OOF=B..'kerplunk.wav',B..'snap.wav',B..'splat.wav',B..'uuhhh.mp3'
local PING,CLICK,SWITCH,FANFARE=B..'electronicpingshort.wav',B..'button.wav',B..'switch.wav',B..'victory.wav'

-- ===== БИБЛИОТЕКА =====
-- Запись: {id=, vol=громкость, speed=скорость/высота тона, var=случайный разброс тона, dist=дальность слышимости}
-- или {layers={запись, запись, ...}} — несколько звуков сразу; у слоя можно задать delay (сек) — задержка.
local LIB={
 -- удары и взмахи
 swingLight={id=SLASH,vol=.45,speed=1.5,var=.12},
 swingHeavy={id=LUNGE,vol=.65,speed=.95,var=.08},
 dash      ={id=SLASH,vol=.4,speed=2.3,var=.1},
 hit       ={layers={{id=PLUNK,vol=.7,speed=1.1,var=.1},{id=SNAP,vol=.3,speed=.8}}},
 heavy     ={layers={{id=PLUNK,vol=.9,speed=.7,var=.08},{id=OOF,vol=.28,speed=1.3},{id=LUNGE,vol=.25,speed=1.5}}},
 slam      ={layers={{id=PLUNK,vol=1,speed=.5,var=.05},{id=SNAP,vol=.6,speed=.45},{id=OOF,vol=.3,speed=.6}},dist=150},
 guard     ={layers={{id=UNSHEATH,vol=.45,speed=2.4,var=.1},{id=CLICK,vol=.3,speed=1.6}}},
 ['break'] ={layers={{id=SNAP,vol=.8,speed=.7},{id=PLUNK,vol=.7,speed=.8},{id=UNSHEATH,vol=.4,speed=.6}}},
 shot      ={layers={{id=SNAP,vol=1,speed=.55,var=.05},{id=LUNGE,vol=.25,speed=3}},dist=170},
 knockdown ={layers={{id=PLUNK,vol=.7,speed=.6,var=.08},{id=OOF,vol=.2,speed=.9}}},
 -- приёмы
 knife     ={layers={{id=UNSHEATH,vol=.6,speed=1.3,var=.08},{id=SLASH,vol=.3,speed=2}}},
 grab      ={layers={{id=PLUNK,vol=.5,speed=1.3},{id=OOF,vol=.3,speed=1.5}}},
 uppercut  ={layers={{id=LUNGE,vol=.55,speed=1.2},{id=PLUNK,vol=.5,speed=.8,delay=.1}}},
 dashPunch ={layers={{id=SLASH,vol=.4,speed=2.2},{id=LUNGE,vol=.5,speed=1.1,delay=.15}}},
 dashGrab  ={layers={{id=SLASH,vol=.4,speed=2.3},{id=PLUNK,vol=.5,speed=1.2,delay=.28}}},
 metalSwing={layers={{id=LUNGE,vol=.6,speed=.9},{id=UNSHEATH,vol=.35,speed=.8,delay=.08}}},
 sweep     ={layers={{id=SLASH,vol=.45,speed=.9},{id=PLUNK,vol=.4,speed=1.0,delay=.12}}},
 spray     ={id=SPLAT,vol=.6,speed=1.3,var=.1},
 dust      ={id=SPLAT,vol=.4,speed=2.2,var=.1},
 throw     ={id=SLASH,vol=.4,speed=1.1,var=.1},
 badge     ={layers={{id=CLICK,vol=.5,speed=.9},{id=SWITCH,vol=.4,speed=.8,delay=.08}}},
 burp      ={id=OOF,vol=.8,speed=.5,var=.08},
 blockUp   ={id=UNSHEATH,vol=.25,speed=1.8,var=.1,dist=60},
 -- ульты
 ult       ={layers={{id=PLUNK,vol=1,speed=.4,var=0},{id=FANFARE,vol=.45,speed=.9,delay=.05},{id=SNAP,vol=.5,speed=.5}},dist=220},
 finisher  ={layers={{id=PLUNK,vol=1,speed=.45},{id=OOF,vol=.6,speed=.7,delay=.05},{id=SNAP,vol=.6,speed=.5}},dist=170},
 -- ослепление (только для того, кого ослепили)
 blindDust ={id=SPLAT,vol=.5,speed=2},
 blindToxic={id=SPLAT,vol=.6,speed=.8},
 blindBeer ={id=SPLAT,vol=.6,speed=1.5},
 blindDark ={id=SPLAT,vol=.4,speed=1.2},
 pigeons   ={layers={{id=SLASH,vol=.35,speed=2.8},{id=SLASH,vol=.35,speed=3.2,delay=.07},{id=SLASH,vol=.35,speed=2.6,delay=.15},{id=SLASH,vol=.3,speed=3,delay=.22}}},
 -- интерфейс (без привязки к месту)
 click     ={id=CLICK,vol=.35,speed=1.1,ui=true},
 fail      ={id=CLICK,vol=.35,speed=.6,ui=true,gap=.2},
 select    ={id=PING,vol=.5,speed=1,ui=true},
 kill      ={layers={{id=PING,vol=.6,speed=1.2},{id=PING,vol=.6,speed=1.7,delay=.1}},ui=true},
 ultReady  ={layers={{id=PING,vol=.6,speed=1.4},{id=PING,vol=.6,speed=1.9,delay=.12},{id=PING,vol=.5,speed=2.4,delay=.24}},ui=true},
}

-- Какой звук у какого скилла: [боец][клавиша] = имя из LIB. Клавиши: Z X C V — скиллы, R — особый приём.
local SKILLS={
 Siply ={Z='swingHeavy',X='knife',C='dashGrab',V='uppercut'},
 Diesel={Z='dashPunch',X='dash',C='swingHeavy',V='swingHeavy'},
 Bitok ={Z='dashPunch',X='dust',C='grab',V='metalSwing'},
 Major ={Z='badge',X='swingHeavy',C='grab',V='shot',R='shot'},
 Yura  ={Z='throw',X='spray',C='grab',V='swingHeavy',R='burp'},
 Jack  ={Z='spray',X='sweep',C='grab',V='throw'},
}
-- Высота тона ульта у каждого бойца (чтобы ульты звучали по-разному)
local ULT_PITCH={Siply=1,Diesel=1.15,Bitok=.9,Major=1,Yura=1.25,Jack=.85}
local BLIND={dust='blindDust',toxic='blindToxic',beer='blindBeer',pigeons='pigeons'}

-- ===== ВНУТРЕННЕЕ =====
local group=SoundService:FindFirstChild('StreetSfx')
if not group then group=Instance.new('SoundGroup');group.Name='StreetSfx';group.Parent=SoundService end
local terrain=workspace:FindFirstChildOfClass('Terrain') or workspace:WaitForChild('Terrain')
local lastPlayed={};local active=0;local MAX_ACTIVE=30

local function one(e,pos,pitchMul,volMul)
 if active>=MAX_ACTIVE then return end
 local id=e.id;if type(id)=='table' then id=id[math.random(1,#id)] end
 local s=Instance.new('Sound');s.SoundId=id
 s.Volume=(e.vol or .6)*(volMul or 1)
 s.PlaybackSpeed=(e.speed or 1)*(pitchMul or 1)*(1+(math.random()-.5)*2*(e.var or .06))
 s.SoundGroup=group
 local holder=s
 if pos and not e.ui then
  s.RollOffMode=Enum.RollOffMode.InverseTapered
  s.RollOffMinDistance=14;s.RollOffMaxDistance=e.dist or 110
  local att=Instance.new('Attachment');att.Parent=terrain;att.WorldPosition=pos
  s.Parent=att;holder=att
 else
  s.Parent=SoundService
 end
 active+=1
 s:Play()
 Debris:AddItem(holder,5)
 task.delay(5,function() active=math.max(0,active-1) end)
end

local function play(name,pos,pitchMul,volMul)
 local e=LIB[name];if not e then return end
 group.Volume=Sfx.Volume
 local n=os.clock()
 if n-(lastPlayed[name] or 0)<(e.gap or .04) then return end -- не больше одного такого звука за 40 мс (удары по толпе)
 lastPlayed[name]=n
 if e.layers then
  for _,l in ipairs(e.layers) do
   local layer=l;if not layer.dist then layer=setmetatable({dist=e.dist,ui=e.ui},{__index=l}) end
   if l.delay then task.delay(l.delay,function() one(layer,pos,pitchMul,volMul) end) else one(layer,pos,pitchMul,volMul) end
  end
 else
  one(e,pos,pitchMul,volMul)
 end
end

-- ===== ПУБЛИЧНЫЕ ФУНКЦИИ =====
function Sfx.play(name,pos,pitchMul,volMul) play(name,pos,pitchMul,volMul) end
function Sfx.ui(name) play(name,nil) end
function Sfx.fx(kind,pos) -- события FX от сервера: Hit, Heavy, Slam, Break, Guard, Dash, Shot, Counter, Spark (Down — без звука, его играет Knockdown)
 if kind=='Down' then return end
 local map={Hit='hit',Heavy='heavy',Slam='slam',Break='break',Guard='guard',Dash='dash',Shot='shot',Counter='guard',Spark='dust'}
 play(map[kind] or 'hit',pos)
end
function Sfx.blind(kind) play(BLIND[kind] or 'blindDark',nil) end
function Sfx.event(d) -- события SFX от сервера
 if type(d)~='table' or typeof(d.position)~='Vector3' then return end
 local pos,name=d.position,d.name
 if name=='Swing' then play(d.heavy and 'swingHeavy' or 'swingLight',pos)
 elseif name=='Skill' then
  local set=SKILLS[d.fighter]
  play((set and set[d.key]) or 'swingLight',pos)
 elseif name=='Ult' then play('ult',pos,ULT_PITCH[d.fighter] or 1)
 elseif name=='Finisher' then play('finisher',pos,ULT_PITCH[d.fighter] or 1)
 elseif name=='Knockdown' then play('knockdown',pos)
 elseif name=='BlockUp' then play('blockUp',pos) end
end

-- Предзагрузка: сразу видно в Output, какие id не открылись
task.spawn(function()
 local holder=Instance.new('Folder');holder.Name='StreetSfxPreload';holder.Parent=SoundService
 local list,seen={},{}
 local function add(e) if type(e.id)=='string' and not seen[e.id] then seen[e.id]=true;local s=Instance.new('Sound');s.SoundId=e.id;s.Parent=holder;list[#list+1]=s end end
 for _,e in pairs(LIB) do if e.layers then for _,l in ipairs(e.layers) do add(l) end else add(e) end end
 pcall(function()
  ContentProvider:PreloadAsync(list,function(id,status)
   if status~=Enum.AssetFetchStatus.Success then warn('[SFX] не загрузился звук: '..tostring(id)..' — замени его в Sfx.lua') end
  end)
 end)
end)

return Sfx
