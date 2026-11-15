-- Sfx v2.2: звуки боя, скиллов, ультов и интерфейса. ModuleScript, работает только на клиенте.
-- v2.2: у каждого скилла «звуковая дорожка» (несколько звуков по таймингу анимации: замах, шаг, свист, захват...),
--       звуки шагов/приземления для Locomotion, свист у шагов ульты.
-- Все звуки — встроенные в Roblox (rbxasset://sounds/...), их не нужно загружать и у них нет проблем с АП.
-- v2.1: каждый звук собирается из нескольких слоёв и пропускается через эффекты (эквалайзер, перегруз, компрессор,
-- реверб), поэтому удары звучат «мясно», а не мультяшно. У каждого бойца свой «материал» удара и своя ульта.
-- Свой звук: замени путь в таблице S на 'rbxassetid://ЦИФРЫ'. Если звук не загрузится — подставится запасной (FALLBACK).
local Debris=game:GetService('Debris')
local SoundService=game:GetService('SoundService')
local ContentProvider=game:GetService('ContentProvider')
local Sfx={}
Sfx.Volume=1 -- общая громкость эффектов (0..1.5)

local B='rbxasset://sounds/'
local S={
 slash=B..'swordslash.wav',lunge=B..'swordlunge.wav',unsheath=B..'unsheath.wav',plunk=B..'kerplunk.wav',
 snap=B..'snap.wav',splat=B..'splat.wav',oof=B..'uuhhh.mp3',ping=B..'electronicpingshort.wav',click=B..'button.wav',
 switch=B..'switch.wav',fanfare=B..'victory.wav',glass=B..'glassbreak.wav',collide=B..'collide.wav',hit=B..'hit.wav',
 boom=B..'Rocket shot.wav',whoosh=B..'Rocket whoosh.wav',land=B..'action_jump_land.mp3',paint=B..'paintball.wav',
}
local FALLBACK={glass='snap',collide='plunk',hit='plunk',boom='plunk',whoosh='lunge',land='plunk',paint='snap'}
local bad={}
local function idOf(k) if bad[k] and FALLBACK[k] then return S[FALLBACK[k]] end return S[k] or k end

-- ===== Обработка звука (пресеты эффектов) =====
-- eq={низ,середина,верх} в дБ (-80..10); dist — перегруз 0..1; comp — компрессор; rev — реверб (размер помещения)
local FX={
 punch ={eq={8,-2,-6},comp=true},
 crunch={eq={5,1,3},dist=.35,comp=true},
 boom  ={eq={10,-3,-10},dist=.25,rev=.8,comp=true},
 big   ={eq={10,0,-3},dist=.45,rev=1.2,comp=true},
 air   ={eq={-8,0,5}},
 metal ={eq={-4,4,7},rev=.6},
 radio ={eq={-12,9,-12},dist=.55},
 bell  ={eq={-6,8,2},dist=.15,rev=.5},
}
local function applyFx(s,name)
 local p=FX[name];if not p then return end
 if p.eq then local e=Instance.new('EqualizerSoundEffect');e.LowGain=p.eq[1];e.MidGain=p.eq[2];e.HighGain=p.eq[3];e.Priority=1;e.Parent=s end
 if p.dist then local d=Instance.new('DistortionSoundEffect');d.Level=p.dist;d.Priority=2;d.Parent=s end
 if p.comp then local c=Instance.new('CompressorSoundEffect');c.Threshold=-20;c.Ratio=4;c.Attack=.004;c.Release=.12;c.GainMakeup=5;c.Priority=3;c.Parent=s end
 if p.rev then local r=Instance.new('ReverbSoundEffect');r.DecayTime=p.rev;r.Density=.9;r.Diffusion=.8;r.DryLevel=0;r.WetLevel=-12;r.Priority=4;r.Parent=s end
end
Sfx.applyFx=applyFx

-- ===== БИБЛИОТЕКА =====
-- {id=ключ из S, vol, speed (высота тона), var (разброс), fx (пресет), delay (сек), dist (дальность)} или {layers={...}}
local LIB={
 swingLight={layers={{id='slash',vol=.32,speed=1.8,var=.12,fx='air'},{id='whoosh',vol=.16,speed=2.8,var=.1,fx='air'}}},
 swingHeavy={layers={{id='lunge',vol=.5,speed=.8,var=.06,fx='air'},{id='whoosh',vol=.3,speed=1.3,fx='air'}}},
 dash      ={layers={{id='whoosh',vol=.42,speed=1.9,var=.08,fx='air'},{id='slash',vol=.22,speed=2.6,fx='air'},{id='land',vol=.22,speed=1.3,delay=.17,fx='punch'}}},
 hit       ={layers={{id='plunk',vol=.75,speed=.85,var=.1,fx='punch'},{id='hit',vol=.35,speed=1.1,var=.1,fx='crunch'},{id='snap',vol=.22,speed=.75,var=.08,fx='crunch'}}},
 heavy     ={layers={{id='plunk',vol=1,speed=.55,var=.05,fx='big'},{id='hit',vol=.55,speed=.8,fx='crunch'},{id='snap',vol=.45,speed=.5,fx='crunch'},{id='boom',vol=.18,speed=1.7,fx='boom'}},dist=150},
 slam      ={layers={{id='boom',vol=.55,speed=.75,fx='boom'},{id='plunk',vol=1,speed=.4,fx='big'},{id='collide',vol=.55,speed=.6,fx='crunch'},{id='land',vol=.6,speed=.6,fx='punch'}},dist=170},
 guard     ={layers={{id='unsheath',vol=.38,speed=2.2,var=.1,fx='metal'},{id='plunk',vol=.4,speed=1.5,fx='punch'}}},
 ['break'] ={layers={{id='glass',vol=.5,speed=.9,fx='crunch'},{id='snap',vol=.7,speed=.6,fx='crunch'},{id='plunk',vol=.8,speed=.55,fx='big'}},dist=150},
 shot      ={layers={{id='boom',vol=.7,speed=2.3,fx='crunch'},{id='snap',vol=.9,speed=.5,fx='crunch'},{id='paint',vol=.35,speed=.6}},dist=220},
 knockdown ={layers={{id='land',vol=.7,speed=.7,fx='punch'},{id='plunk',vol=.55,speed=.5,fx='punch'}}},
 counter   ={layers={{id='unsheath',vol=.5,speed=1.4,fx='metal'},{id='whoosh',vol=.35,speed=2.1,fx='air'},{id='plunk',vol=.85,speed=.6,fx='big',delay=.08}}},
 -- приёмы
 knife     ={layers={{id='unsheath',vol=.6,speed=1.5,fx='metal'},{id='slash',vol=.32,speed=2.3,fx='air',delay=.12}}},
 phone     ={layers={{id='ping',vol=.3,speed=1.7,fx='bell'},{id='ping',vol=.3,speed=1.7,fx='bell',delay=.13},{id='whoosh',vol=.32,speed=1.8,fx='air',delay=.18}}},
 grab      ={layers={{id='plunk',vol=.55,speed=1.2,fx='punch'},{id='oof',vol=.28,speed=1.4},{id='whoosh',vol=.2,speed=2.2,fx='air'}}},
 uppercut  ={layers={{id='lunge',vol=.55,speed=1.1,fx='air'},{id='plunk',vol=.6,speed=.7,fx='big',delay=.1}}},
 dashPunch ={layers={{id='whoosh',vol=.35,speed=2,fx='air'},{id='lunge',vol=.45,speed=1.1,fx='air',delay=.15}}},
 dashGrab  ={layers={{id='whoosh',vol=.4,speed=2.2,fx='air'},{id='plunk',vol=.5,speed=1.2,fx='punch',delay=.28}}},
 metalSwing={layers={{id='lunge',vol=.6,speed=.8,fx='air'},{id='unsheath',vol=.4,speed=.7,fx='metal',delay=.08},{id='collide',vol=.3,speed=.6,fx='metal',delay=.45}}},
 batonSwing={layers={{id='lunge',vol=.55,speed=.9,fx='air'},{id='switch',vol=.25,speed=.6,fx='radio',delay=.3}}},
 sweep     ={layers={{id='slash',vol=.42,speed=.9,fx='air'},{id='land',vol=.45,speed=.9,fx='punch',delay=.12}}},
 spray     ={layers={{id='splat',vol=.55,speed=1.3,var=.1},{id='whoosh',vol=.2,speed=3,fx='air'}}},
 beer      ={layers={{id='splat',vol=.55,speed=1.5,var=.1},{id='splat',vol=.35,speed=2.1,delay=.06},{id='glass',vol=.1,speed=2}}},
 dust      ={layers={{id='splat',vol=.35,speed=2.2,var=.1},{id='whoosh',vol=.25,speed=2.4,fx='air'}}},
 throw     ={layers={{id='slash',vol=.38,speed=1.1,var=.1,fx='air'},{id='whoosh',vol=.2,speed=1.6,fx='air'}}},
 bottleThrow={layers={{id='slash',vol=.38,speed=1.1,fx='air'},{id='glass',vol=.4,speed=1.1,fx='crunch',delay=.45}}},
 badge     ={layers={{id='click',vol=.45,speed=.9},{id='switch',vol=.4,speed=.8,delay=.08},{id='whoosh',vol=.2,speed=2.4,fx='air'}}},
 burp      ={layers={{id='oof',vol=.85,speed=.42,var=.06,fx='crunch'},{id='splat',vol=.3,speed=.6,delay=.1}}},
 headbutt  ={layers={{id='plunk',vol=.6,speed=.9,fx='punch'},{id='oof',vol=.25,speed=1.6,delay=.3}}},
 warnShot  ={layers={{id='boom',vol=.8,speed=2,fx='crunch'},{id='snap',vol=1,speed=.45,fx='crunch'},{id='paint',vol=.4,speed=.5,delay=.05}},dist=240},
 blockUp   ={id='unsheath',vol=.22,speed=1.8,var=.1,dist=60,fx='metal'},
 -- v2.2: звуки для дорожек скиллов и движений
 charge    ={layers={{id='whoosh',vol=.3,speed=.55,fx='air'},{id='lunge',vol=.22,speed=.5,fx='air',delay=.1}}},
 glint     ={layers={{id='unsheath',vol=.42,speed=2.2,fx='metal'},{id='ping',vol=.12,speed=2.6,fx='bell'}}},
 stab      ={layers={{id='slash',vol=.4,speed=2.6,fx='air'},{id='splat',vol=.3,speed=1.2}}},
 cloth     ={layers={{id='splat',vol=.28,speed=.7},{id='whoosh',vol=.18,speed=2.8,fx='air'}}},
 step      ={layers={{id='land',vol=.32,speed=1.15,var=.1,fx='punch'}}},
 stomp     ={layers={{id='land',vol=.6,speed=.7,fx='punch'},{id='plunk',vol=.4,speed=.5,fx='punch'}},dist=90},
 jab       ={layers={{id='slash',vol=.24,speed=2.5,var=.1,fx='air'}}},
 scoop     ={layers={{id='splat',vol=.3,speed=.6},{id='land',vol=.22,speed=1.5}}},
 lift      ={layers={{id='oof',vol=.32,speed=.8},{id='whoosh',vol=.3,speed=1,fx='air'}}},
 cuff      ={layers={{id='switch',vol=.5,speed=1.3},{id='click',vol=.5,speed=1.6,delay=.06},{id='unsheath',vol=.28,speed=2,fx='metal'}}},
 holster   ={layers={{id='unsheath',vol=.35,speed=1.2,fx='metal'},{id='click',vol=.3,speed=1.1,delay=.08}}},
 inhale    ={layers={{id='whoosh',vol=.3,speed=.5,fx='air'},{id='oof',vol=.2,speed=1.8}}},
 spit      ={layers={{id='splat',vol=.6,speed=1},{id='splat',vol=.4,speed=1.6,delay=.08},{id='whoosh',vol=.25,speed=2.2,fx='air'}}},
 breath    ={layers={{id='oof',vol=.28,speed=.6,fx='crunch'}}},
 shake     ={layers={{id='glass',vol=.12,speed=2.2},{id='splat',vol=.2,speed=2.4,delay=.08},{id='glass',vol=.1,speed=2.4,delay=.16}}},
 fizz      ={layers={{id='splat',vol=.45,speed=2},{id='whoosh',vol=.3,speed=3,fx='air'}}},
 fallBack  ={layers={{id='oof',vol=.32,speed=1.3},{id='land',vol=.5,speed=.8,fx='punch',delay=.25}}},
 spinWhoosh={layers={{id='whoosh',vol=.35,speed=1.2,fx='air'},{id='slash',vol=.25,speed=1.4,fx='air',delay=.08}}},
 rustle    ={layers={{id='splat',vol=.25,speed=1.8},{id='glass',vol=.12,speed=1.8,delay=.05}}},
 dodge     ={layers={{id='whoosh',vol=.3,speed=2.4,fx='air'}}},
 belly     ={layers={{id='plunk',vol=.3,speed=.5,fx='punch'}}},
 glassTink ={layers={{id='glass',vol=.15,speed=2.4,fx='metal'}}},
 phoneRing ={layers={{id='ping',vol=.28,speed=1.9,fx='bell'},{id='ping',vol=.28,speed=1.9,fx='bell',delay=.1},{id='ping',vol=.28,speed=1.9,fx='bell',delay=.35},{id='ping',vol=.28,speed=1.9,fx='bell',delay=.45}}},
 jumpUp    ={layers={{id='whoosh',vol=.18,speed=2.2,fx='air'}},dist=60},
 -- «материал» удара каждого бойца (добавляется к обычному звуку попадания)
 mat_Siply ={layers={{id='unsheath',vol=.3,speed=.85,var=.08,fx='metal'},{id='collide',vol=.25,speed=1.5,fx='metal'}}},
 mat_Diesel={layers={{id='plunk',vol=.45,speed=.7,var=.08,fx='punch'},{id='hit',vol=.25,speed=.7,fx='punch'}}},
 mat_Bitok ={layers={{id='collide',vol=.45,speed=.85,var=.08,fx='crunch'},{id='snap',vol=.3,speed=.9}}},
 mat_Major ={layers={{id='switch',vol=.3,speed=.7,var=.08,fx='radio'},{id='snap',vol=.25,speed=1.2}}},
 mat_Yura  ={layers={{id='splat',vol=.42,speed=.9,var=.1,fx='punch'}}},
 mat_Jack  ={layers={{id='glass',vol=.14,speed=1.7,var=.1,fx='metal'},{id='splat',vol=.22,speed=1.4}}},
 ultHit    ={layers={{id='boom',vol=.4,speed=1.1,var=.06,fx='boom'},{id='plunk',vol=.6,speed=.45,fx='big'}},dist=200},
 -- ульты: у каждого бойца свой звук
 ult_Siply ={layers={{id='boom',vol=.6,speed=.6,fx='boom'},{id='unsheath',vol=.6,speed=.55,fx='metal'},{id='whoosh',vol=.5,speed=.7,fx='air'},{id='plunk',vol=1,speed=.35,fx='big',delay=.3},{id='collide',vol=.6,speed=.5,fx='metal',delay=.32}},dist=240},
 ult_Diesel={layers={{id='oof',vol=.9,speed=.33,fx='big'},{id='oof',vol=.55,speed=.47,fx='big',delay=.05},{id='boom',vol=.6,speed=.5,fx='boom',delay=.25},{id='plunk',vol=.9,speed=.4,fx='big',delay=.3},{id='plunk',vol=.75,speed=.42,fx='big',delay=.6}},dist=240},
 ult_Bitok ={layers={{id='collide',vol=.8,speed=.45,fx='big'},{id='lunge',vol=.6,speed=.5,fx='air'},{id='snap',vol=.9,speed=.38,fx='crunch',delay=.3},{id='boom',vol=.65,speed=.5,fx='boom',delay=.3}},dist=240},
 ult_Major ={layers={{id='switch',vol=.5,speed=.8,fx='radio'},{id='ping',vol=.45,speed=.92,fx='radio'},{id='ping',vol=.45,speed=.72,fx='radio',delay=.22},{id='ping',vol=.45,speed=.92,fx='radio',delay=.44},{id='ping',vol=.45,speed=.72,fx='radio',delay=.66},{id='boom',vol=.5,speed=1.4,fx='crunch',delay=.3}},dist=260},
 ult_Yura  ={layers={{id='collide',vol=.9,speed=.42,fx='metal'},{id='unsheath',vol=.5,speed=.4,fx='metal'},{id='oof',vol=.8,speed=.42,fx='crunch',delay=.25},{id='splat',vol=.6,speed=.5,delay=.35}},dist=240},
 ult_Jack  ={layers={{id='glass',vol=.8,speed=.8,fx='crunch'},{id='glass',vol=.5,speed=.6,fx='metal',delay=.12},{id='oof',vol=.55,speed=1.5,delay=.3},{id='boom',vol=.4,speed=.7,fx='boom',delay=.3}},dist=240},
 finisher  ={layers={{id='whoosh',vol=.5,speed=.6,fx='air'},{id='plunk',vol=1,speed=.4,fx='big',delay=.4},{id='boom',vol=.6,speed=.6,fx='boom',delay=.4},{id='snap',vol=.6,speed=.45,fx='crunch',delay=.42}},dist=220},
 -- ослепление (только тому, кого ослепили)
 blindDust ={id='splat',vol=.5,speed=2},blindToxic={id='splat',vol=.6,speed=.8},blindBeer={id='splat',vol=.6,speed=1.5},blindDark={id='splat',vol=.4,speed=1.2},
 -- интерфейс
 click     ={id='click',vol=.3,speed=1.15,ui=true},
 fail      ={id='click',vol=.3,speed=.6,ui=true,gap=.2},
 select    ={layers={{id='ping',vol=.4,speed=1,fx='bell'},{id='whoosh',vol=.2,speed=2.2,fx='air'}},ui=true},
 kill      ={layers={{id='ping',vol=.55,speed=1.2,fx='bell'},{id='ping',vol=.55,speed=1.7,fx='bell',delay=.1},{id='boom',vol=.25,speed=.8,fx='boom'}},ui=true},
 ultReady  ={layers={{id='ping',vol=.5,speed=1.4,fx='bell'},{id='ping',vol=.5,speed=1.9,fx='bell',delay=.12},{id='ping',vol=.45,speed=2.4,fx='bell',delay=.24}},ui=true},
}
-- Какой звук у какого скилла: [боец][клавиша]. Клавиши: Z X C V — скиллы, R — особый приём.
-- Звуковые дорожки скиллов: [боец][клавиша] = {{через сек, звук}, ...}. Тайминги совпадают с анимациями R6Animations.
-- Звук самого попадания играет отдельно (событие FX), здесь — замахи, шаги, свист, захваты, предметы.
local SKILLS={
 Siply ={Z={{0,'charge'},{.12,'step'},{.38,'swingHeavy'}},
         X={{0,'glint'},{.08,'stab'},{.27,'cloth'}},
         C={{0,'phoneRing'},{.12,'dashGrab'},{.32,'cloth'}},
         V={{0,'step'},{.18,'charge'},{.26,'uppercut'}}},
 Diesel={Z={{0,'step'},{.16,'jab'},{.32,'swingLight'}},
         X={{0,'dodge'},{.2,'dodge'},{.4,'dodge'}},
         C={{0,'step'},{.28,'swingHeavy'}},
         V={{0,'charge'},{.43,'swingHeavy'}}},
 Bitok ={Z={{0,'step'},{.12,'spinWhoosh'}},
         X={{0,'scoop'},{.14,'dust'}},
         C={{.1,'cloth'},{.28,'lift'},{.46,'swingHeavy'}},
         V={{0,'charge'},{.4,'metalSwing'}}},
 Major ={Z={{0,'badge'},{.12,'jab'}},
         X={{0,'cloth'},{.26,'batonSwing'}},
         C={{.2,'cuff'},{.3,'cloth'},{.55,'swingHeavy'},{.9,'cuff'}},
         V={{0,'holster'},{.14,'charge'}},
         R={{0,'holster'}}},
 Yura  ={Z={{0,'glassTink'},{.2,'bottleThrow'}},
         X={{0,'inhale'},{.23,'spit'}},
         C={{0,'dashGrab'},{.25,'lift'},{.7,'breath'},{1.1,'breath'}},
         V={{0,'rustle'},{.2,'spinWhoosh'},{.45,'swingHeavy'}},
         R={{0,'belly'},{.16,'burp'}}},
 Jack  ={Z={{0,'shake'},{.2,'fizz'},{.24,'beer'}},
         X={{0,'fallBack'}},
         C={{.15,'cloth'},{.5,'jab'},{.8,'jab'},{1.1,'jab'}},
         V={{0,'spinWhoosh'},{.26,'bottleThrow'}}},
}
local BLIND={dust='blindDust',toxic='blindToxic',beer='blindBeer'}

-- ===== ВНУТРЕННЕЕ =====
local group=SoundService:FindFirstChild('StreetSfx')
if not group then group=Instance.new('SoundGroup');group.Name='StreetSfx';group.Parent=SoundService end
local terrain=workspace:FindFirstChildOfClass('Terrain') or workspace:WaitForChild('Terrain')
local lastPlayed={};local active=0;local MAX_ACTIVE=40

local function one(e,pos,pitchMul,volMul)
 if active>=MAX_ACTIVE then return end
 local s=Instance.new('Sound');s.SoundId=idOf(e.id)
 s.Volume=(e.vol or .6)*(volMul or 1)
 s.PlaybackSpeed=(e.speed or 1)*(pitchMul or 1)*(1+(math.random()-.5)*2*(e.var or .05))
 s.SoundGroup=group
 applyFx(s,e.fx)
 local holder=s
 if pos and not e.ui then
  s.RollOffMode=Enum.RollOffMode.InverseTapered;s.RollOffMinDistance=14;s.RollOffMaxDistance=e.dist or 120
  local att=Instance.new('Attachment');att.Parent=terrain;att.WorldPosition=pos
  s.Parent=att;holder=att
 else s.Parent=SoundService end
 active+=1
 s:Play()
 Debris:AddItem(holder,5)
 task.delay(5,function() active=math.max(0,active-1) end)
end

local function play(name,pos,pitchMul,volMul)
 local e=LIB[name];if not e then return end
 group.Volume=Sfx.Volume
 local n=os.clock()
 if n-(lastPlayed[name] or 0)<(e.gap or .04) then return end
 lastPlayed[name]=n
 if e.layers then
  for _,l in ipairs(e.layers) do
   local layer=setmetatable({dist=l.dist or e.dist,ui=e.ui},{__index=l})
   if l.delay then task.delay(l.delay,function() one(layer,pos,pitchMul,volMul) end) else one(layer,pos,pitchMul,volMul) end
  end
 else one(e,pos,pitchMul,volMul) end
end

-- ===== ПУБЛИЧНЫЕ ФУНКЦИИ =====
function Sfx.play(name,pos,pitchMul,volMul) play(name,pos,pitchMul,volMul) end
function Sfx.ui(name) play(name,nil) end
-- события FX от сервера: kind (Hit/Heavy/Slam/Break/Guard/Dash/Shot/Counter/Spark), f — боец-атакующий, u — удар ульты
function Sfx.fx(kind,pos,f,u)
 if kind=='Down' or kind=='Bleed' then return end
 local map={Hit='hit',Heavy='heavy',Slam='slam',Break='break',Guard='guard',Dash='dash',Shot='shot',Counter='counter',Spark='dust'}
 play(map[kind] or 'hit',pos)
 if f and (kind=='Hit' or kind=='Heavy' or kind=='Slam' or kind=='Break') then play('mat_'..tostring(f),pos,kind=='Hit' and 1 or .85) end
 if u then play('ultHit',pos) end
end
function Sfx.blind(kind) play(BLIND[kind] or 'blindDark',nil) end
function Sfx.event(d) -- события SFX от сервера
 if type(d)~='table' or typeof(d.position)~='Vector3' then return end
 local pos,name=d.position,d.name
 if name=='Swing' then play(d.heavy and 'swingHeavy' or 'swingLight',pos)
 elseif name=='Skill' then
  local set=SKILLS[d.fighter];local tl=set and set[d.key]
  if type(tl)=='table' then
   for _,e in ipairs(tl) do if e[1]<=0 then play(e[2],pos) else task.delay(e[1],function() play(e[2],pos) end) end end
  else play('swingLight',pos) end
 elseif name=='Ult' then play('ult_'..tostring(d.fighter),pos)
 elseif name=='Finisher' then play('finisher',pos)
 elseif name=='Knockdown' then play('knockdown',pos)
 elseif name=='BlockUp' then play('blockUp',pos) end
end

-- Предзагрузка: какие id не открылись — те заменяются запасными (FALLBACK) и пишутся в Output
task.spawn(function()
 local holder=Instance.new('Folder');holder.Name='StreetSfxPreload';holder.Parent=SoundService
 local list,keyOf={},{}
 for k,id in pairs(S) do local s=Instance.new('Sound');s.SoundId=id;s.Parent=holder;list[#list+1]=s;keyOf[id]=k end
 pcall(function()
  ContentProvider:PreloadAsync(list,function(id,status)
   if status~=Enum.AssetFetchStatus.Success then
    local k=keyOf[id];if k then bad[k]=true end
    warn('[SFX] не загрузился звук: '..tostring(id)..(k and FALLBACK[k] and (' — заменён на '..FALLBACK[k]) or ''))
   end
  end)
 end)
end)

return Sfx
