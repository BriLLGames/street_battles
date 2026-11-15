-- DayNight v1.4 (ночь светлее): общий модуль смены дня и ночи (ModuleScript в ReplicatedStorage).
-- Время считается по часам сервера, поэтому у всех игроков одно и то же время суток.
-- Сервер (Courtyard) переключает окна и фонари, а свет и небо каждый клиент обновляет у себя (DayNight.client).
local Lighting=game:GetService('Lighting')
local D={}

-- ===== НАСТРОЙКИ (крути здесь) =====
D.DayLength=720     -- сколько реальных секунд длятся игровые сутки (720 = 12 минут)
D.StartHour=15      -- во сколько начинается сервер (15 = день, скоро вечер)
D.WindowGlow=.62    -- яркость горящих окон: 0.3 — еле видно, 1 — как раньше (ярко и с ореолом)

local function C3(r,g,b) return Color3.fromRGB(r,g,b) end

-- Четыре состояния суток. Между ними значения плавно перетекают.
-- bright/exp — яркость и экспозиция; amb/out — подсветка теней (чтобы ночью не было чёрного провала);
-- atmC/atmD/dens/haze — дымка; cc* — цветокоррекция; bloom — свечение; cloud — цвет облаков.
local NIGHT={bright=1.9, exp=.65, amb=C3(120,130,168), out=C3(142,156,196), atmC=C3(92,106,150), atmD=C3(54,64,100), dens=.26,haze=1.0,ccB=.08,ccC=.08,ccS=-.08,ccT=C3(215,224,250),bloom=.30,cloud=C3(86,96,128)}
local DAWN= {bright=1.0, exp=0,   amb=C3(96,92,100),  out=C3(124,114,116),atmC=C3(196,168,152),atmD=C3(150,110,92), dens=.38,haze=2.1,ccB=0,   ccC=.12,ccS=-.10,ccT=C3(255,236,222),bloom=.30,cloud=C3(206,172,152)}
local DAY=  {bright=1.6, exp=-.22,amb=C3(102,108,120),out=C3(112,120,134),atmC=C3(168,176,190),atmD=C3(108,116,130),dens=.30,haze=1.6,ccB=0,   ccC=.08,ccS=-.14,ccT=C3(242,246,252),bloom=.18,cloud=C3(176,182,192)}
local DUSK= {bright=1.1, exp=-.05,amb=C3(94,84,92),   out=C3(118,100,102),atmC=C3(190,150,132),atmD=C3(130,92,82),  dens=.38,haze=2.2,ccB=-.01,ccC=.14,ccS=-.12,ccT=C3(255,226,206),bloom=.32,cloud=C3(198,152,132)}

-- расписание: {час, состояние}
local KEYS={{0,NIGHT},{4.6,NIGHT},{6.3,DAWN},{8.6,DAY},{15.4,DAY},{18.2,DUSK},{20.4,NIGHT},{24,NIGHT}}

local function lerpv(a,b,t)
 if typeof(a)=='Color3' then return a:Lerp(b,t) end
 return a+(b-a)*t
end

function D.sample(h)
 for i=1,#KEYS-1 do
  local k0,k1=KEYS[i],KEYS[i+1]
  if h>=k0[1] and h<=k1[1] then
   local t=(h-k0[1])/(k1[1]-k0[1]);t=t*t*(3-2*t)
   local r={}
   for k,v in pairs(k0[2]) do r[k]=lerpv(v,k1[2][k],t) end
   return r
  end
 end
 return NIGHT
end

local function smooth(a,b,h) local t=math.clamp((h-a)/(b-a),0,1);return t*t*(3-2*t) end
-- 0 — фонари выключены (день), 1 — горят на полную (ночь)
function D.lampLevel(h)
 if h>=17.4 and h<19.4 then return smooth(17.4,19.4,h) end
 if h>=19.4 or h<4.8 then return 1 end
 if h>=4.8 and h<6.8 then return 1-smooth(4.8,6.8,h) end
 return 0
end

-- текущий час суток (0..24)
function D.hour()
 local t0=workspace:GetAttribute('DN_T0')
 if not t0 then return D.StartHour end
 return (D.StartHour+(workspace:GetServerTimeNow()-t0)*24/D.DayLength)%24
end

local cache={}
local function find(name,parent)
 local o=cache[name]
 if o and o.Parent then return o end
 o=parent:FindFirstChild(name) or (name=='Clouds' and parent:FindFirstChildOfClass('Clouds'))
 cache[name]=o
 return o
end

-- применить время суток к освещению (на сервере — один раз при старте, на клиенте — 10 раз в секунду)
function D.apply(h)
 local s=D.sample(h)
 Lighting.ClockTime=h
 Lighting.Brightness=s.bright;Lighting.ExposureCompensation=s.exp
 Lighting.Ambient=s.amb;Lighting.OutdoorAmbient=s.out
 local a=find('StreetAtmosphere',Lighting);if a then a.Color=s.atmC;a.Decay=s.atmD;a.Density=s.dens;a.Haze=s.haze end
 local b=find('StreetBloom',Lighting);if b then b.Intensity=s.bloom end
 local c=find('StreetColor',Lighting);if c then c.Brightness=s.ccB;c.Contrast=s.ccC;c.Saturation=s.ccS;c.TintColor=s.ccT end
 local cl=find('Clouds',workspace.Terrain);if cl then cl.Color=s.cloud end
end

return D
