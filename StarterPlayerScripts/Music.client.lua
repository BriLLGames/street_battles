-- Music v1.0 (LocalScript в StarterPlayerScripts): тихая жёсткая фоновая музыка без АП.
-- 1) Если в GameConfig.Music.tracks есть id треков (Toolbox -> Creator Store -> Audio -> Music, треки от Roblox бесплатные) —
--    играет плейлист из них. 2) Иначе играет встроенный «фонк»-бит: кик, 808, снейр, хэт и ковбелл-мелодия,
--    собранные из стандартных звуков Roblox (никаких АП, ничего не нужно загружать).
-- Бит сам меняет интенсивность: спокойно -> драка (тебя бьют/ты бьёшь) -> ульта (быстрые хэты, мелодия октавой выше).
-- Во время чьей-то ульты рядом музыка приглушается, чтобы был слышен звук ульты. Клавиша N — вкл/выкл музыку.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local SoundService=game:GetService('SoundService')
local ContentProvider=game:GetService('ContentProvider')
local UIS=game:GetService('UserInputService')
local Debris=game:GetService('Debris')
local C=require(RS:WaitForChild('GameConfig'))
local Sfx=require(RS:WaitForChild('Sfx'))
local remote=RS:WaitForChild('StreetAction')
local lp=Players.LocalPlayer
local M=C.Music or {}
local BASE=M.volume or .16

local group=Instance.new('SoundGroup');group.Name='StreetMusic';group.Volume=0;group.Parent=SoundService
do local c=Instance.new('CompressorSoundEffect');c.Threshold=-16;c.Ratio=3;c.GainMakeup=2;c.Parent=group end
local muted=false;local duckUntil=0;local lastCombat=-100

-- ===== 1. Свои треки =====
local useTracks=false
task.spawn(function()
 local list={}
 for _,id in ipairs(M.tracks or {}) do
  local s=Instance.new('Sound');s.SoundId=type(id)=='number' and ('rbxassetid://'..id) or tostring(id);s.SoundGroup=group;s.Parent=SoundService;list[#list+1]=s
 end
 if #list==0 then return end
 local ok={}
 pcall(function() ContentProvider:PreloadAsync(list,function(id,status) if status==Enum.AssetFetchStatus.Success then ok[id]=true else warn('[MUSIC] трек не загрузился: '..tostring(id)) end end) end)
 local good={}
 for _,s in ipairs(list) do if ok[s.SoundId] then good[#good+1]=s else s:Destroy() end end
 if #good==0 then return end
 useTracks=true
 local i=1
 while true do
  local s=good[i];s.TimePosition=0;s:Play()
  local t0=os.clock()
  repeat task.wait(.5) until not s.IsPlaying or os.clock()-t0>600
  s:Stop();i=i%#good+1
 end
end)

-- ===== 2. Встроенный бит =====
local B='rbxasset://sounds/'
local INST={
 kick ={id=B..'kerplunk.wav',speed=.32,vol=1.1,fx='boom'},
 bass ={id=B..'kerplunk.wav',speed=.24,vol=.8,fx='big'},
 snare={id=B..'snap.wav',speed=.68,vol=.7,fx='crunch'},
 clap ={id=B..'splat.wav',speed=1.7,vol=.3,fx='metal'},
 hat  ={id=B..'button.wav',speed=2.8,vol=.16,fx='air'},
 bell ={id=B..'electronicpingshort.wav',speed=.6,vol=.38,fx='bell'},
}
local function note(name,pitch,vol)
 local d=INST[name];local s=Instance.new('Sound');s.SoundId=d.id;s.SoundGroup=group
 s.PlaybackSpeed=d.speed*(pitch or 1);s.Volume=d.vol*(vol or 1);Sfx.applyFx(s,d.fx);s.Parent=SoundService;s:Play();Debris:AddItem(s,3)
end
local function semi(n) return 2^(n/12) end
local X=false -- пауза
-- 4 такта ковбелл-мелодии (полутоны), 16 шагов в такте
local MEL={
 {0,X,0,X,3,X,X,0, X,7,X,5,3,X,X,X},
 {0,X,0,X,3,X,X,0, X,10,X,7,5,X,3,X},
 {-2,X,-2,X,1,X,X,-2, X,5,X,3,1,X,X,X},
 {-4,X,-4,X,0,X,X,-4, X,3,X,1,0,X,-2,X},
}
local ROOT={0,0,-2,-4}
local KICK={[1]=true,[7]=true,[11]=true}
local function level()
 if lp:GetAttribute('UltActive') then return 'ult' end
 if os.clock()-lastCombat<8 then return 'fight' end
 return 'calm'
end
local function tick(st)
 local bar=math.floor(st/16)%4+1;local i=st%16+1;local lv=level()
 local m=MEL[bar][i]
 if KICK[i] or (lv=='ult' and i==9) then note('kick');note('bass',semi(ROOT[bar]),lv=='calm' and .7 or 1) end
 if lv~='calm' and (i==5 or i==13) then note('snare');note('clap') end
 if lv=='calm' and i==13 then note('snare',1,.5) end
 if lv=='ult' then note('hat',(i%2==0) and 1.1 or 1,(i%4==1) and 1.2 or .8)
 elseif lv=='fight' and i%2==1 then note('hat',1,(i%4==1) and 1.1 or .7) end
 if lv=='ult' and bar==4 and i>=13 then note('snare',1.1,.6) end
 if m then
  note('bell',semi(m),lv=='calm' and .7 or 1)
  if lv=='ult' then note('bell',semi(m+12),.35) end
 end
end
local stepLen=60/(M.bpm or 132)/4
local step=0;local nextT=os.clock()+1.5
RunService.Heartbeat:Connect(function()
 local n=os.clock()
 local target=muted and 0 or BASE*((n<duckUntil) and .35 or 1)*(level()=='calm' and .8 or 1)
 group.Volume=group.Volume+(target-group.Volume)*.06
 if useTracks or muted then nextT=n+.1;return end
 if n<nextT then return end
 if n-nextT>.25 then nextT=n end -- после лага не играем пачку нот
 nextT+=stepLen
 local ok,err=pcall(tick,step);if not ok then warn('[MUSIC] '..tostring(err)) end
 step=(step+1)%64
end)

-- ===== События: драка и ульты =====
remote.OnClientEvent:Connect(function(kind,d)
 if kind=='Shake' then lastCombat=os.clock()
 elseif kind=='Skill' and type(d)=='table' and d.userId==lp.UserId then lastCombat=os.clock()
 elseif (kind=='UltStart' or kind=='Finisher') and type(d)=='table' then
  local p=Players:GetPlayerByUserId(d.userId or 0);local r=p and p.Character and p.Character:FindFirstChild('HumanoidRootPart')
  local me=lp.Character and lp.Character:FindFirstChild('HumanoidRootPart')
  if r and me and (r.Position-me.Position).Magnitude<90 then duckUntil=os.clock()+1.4 end
 end
end)
UIS.InputBegan:Connect(function(input,processed)
 if processed or UIS:GetFocusedTextBox() then return end
 if input.KeyCode.Name==(M.key or 'N') then
  muted=not muted
  pcall(function() game:GetService('StarterGui'):SetCore('SendNotification',{Title='Музыка',Text=muted and 'выключена [N]' or 'включена [N]',Duration=2}) end)
 end
end)
