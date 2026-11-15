-- Locomotion v1.0 (LocalScript в StarterPlayerScripts): у каждого бойца своя стойка, походка и бег (R6, процедурно).
-- Работает поверх стандартного Animate: каждый кадр (после аниматора) задаёт Motor6D.Transform шести суставов.
-- В прыжке/падении/нокдауне плавно отдаёт управление стандартным анимациям. Во время ударов (R6Animations ставит
-- атрибут SB_Act) руки, корпус и голова отдаются позам удара, а ноги продолжают шагать.
-- Стиль бойца берётся из GameConfig (поле style). Цифры поз можно крутить в таблице STYLE.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local C=require(RS:WaitForChild('GameConfig'))
local rad,sin,cos,clamp,abs,pi=math.rad,math.sin,math.cos,math.clamp,math.abs,math.pi
local NAMES={R='Right Shoulder',L='Left Shoulder',H='Neck',W='RootJoint',RH='Right Hip',LH='Left Hip'}

-- Углы как в R6Animations: руки {вперёд, в сторону, поперёк}; W {наклон вперёд, поворот вправо, крен вправо};
-- H {вверх, поворот вправо, наклон вправо}; ноги {вперёд, в сторону}.
-- walk: arm/leg — размах рук/ног, lean — наклон при ходьбе, bob — подпрыгивание тела, roll — раскачка плечами, cad — частота шага
local STYLE={
 thug={ -- Сиплый: сутулый дворовый, руки почти в карманах, вразвалку
  idle={W={6,-10,0},H={-6,12,0},R={-8,6,-12},L={-6,6,12},RH={-4,6},LH={6,4}},
  breathe=2.5,sway=1.5,swayHz=.6,
  walk={arm=24,leg=34,lean=8,bob=.16,roll=7,cad=1,twist=8},
 },
 boxer={ -- Дизель: боксёрская стойка, кулаки у подбородка, пружинит на носках
  idle={W={10,-22,0},H={-10,18,0},R={72,12,58},L={88,8,62},RH={-14,10},LH={16,8}},
  breathe=1.5,sway=2,swayHz=1.1,bounce=.16,bounceHz=2.4,
  walk={arm=5,leg=26,lean=12,bob=.1,roll=3,cad=1.15,twist=4,keepArms=true},
 },
 brute={ -- Биток: широкая стойка громилы, плечи вперёд, руки разведены, тяжёлый шаг
  idle={W={9,0,0},H={-8,0,0},R={8,20,-6},L={8,20,6},RH={0,12},LH={0,12}},
  breathe=3.5,sway=1,swayHz=.4,
  walk={arm=20,leg=30,lean=10,bob=.28,roll=6,cad=.85,twist=10,armSide=18},
 },
 cop={ -- Майор: выправка, правая рука у кобуры, левая на ремне, строевой шаг
  idle={W={-3,0,0},H={3,0,0},R={-6,16,-24},L={10,8,34},RH={0,2},LH={0,2}},
  breathe=1.5,sway=.5,swayHz=.5,
  walk={arm=34,leg=36,lean=-1,bob=.12,roll=2,cad=1.05,twist=3,rightArm=.2},
 },
 drunk={ -- Дядя Юра: ссутулился, покачивается, руки болтаются, шаркает
  idle={W={15,6,5},H={-14,-8,8},R={4,6,0},L={6,6,0},RH={-4,4},LH={6,6}},
  breathe=3,sway=6,swayHz=.45,
  walk={arm=18,leg=26,lean=15,bob=.14,roll=10,cad=.9,twist=10,stumble=true},
 },
 sailor={ -- Капитан Джек: отклонился назад, бутылка поднята, вторая рука на поясе, качка как на палубе
  idle={W={-7,12,-6},H={10,-12,-8},R={42,8,22},L={-6,24,10},RH={-10,8},LH={8,10}},
  breathe=2,sway=4,swayHz=.5,
  walk={arm=22,leg=32,lean=-4,bob=.2,roll=11,cad=.95,twist=8,rightArm=.35},
 },
}

local function armR(a,s) return CFrame.Angles(0,rad((a[3] or 0)*s),0)*CFrame.Angles(rad(a[1] or 0),0,0)*CFrame.Angles(0,0,rad((a[2] or 0)*s)) end
local function bodyR(a) return CFrame.Angles(0,rad(-(a[2] or 0)),0)*CFrame.Angles(rad(-(a[1] or 0)),0,0)*CFrame.Angles(0,0,rad(-(a[3] or 0))) end
local function headR(a) return CFrame.Angles(0,rad(-(a[2] or 0)),0)*CFrame.Angles(rad(a[1] or 0),0,0)*CFrame.Angles(0,0,rad(-(a[3] or 0))) end
local function legR(a,s,Rw) local comp=CFrame.new():Lerp(Rw,.85):Inverse();return comp*CFrame.Angles(rad(a[1] or 0),0,0)*CFrame.Angles(0,0,rad((a[2] or 0)*s)) end
-- поворот R в пространстве Part0 -> Transform сустава (с учётом текущего C0)
local function conj(m,R,offset) local r=m.C0.Rotation;return r:Inverse()*(offset and CFrame.new(offset) or CFrame.new())*R*r end
local ID=CFrame.new()

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

local function stepChar(p,char,st,dt,now)
 local hum=char:FindFirstChildOfClass('Humanoid');local hrp=char:FindFirstChild('HumanoidRootPart')
 if not hum or not hrp then return end
 if not (st.M and st.M.W.Parent and st.M.RH.Parent) then st.M=motorsOf(char) end
 local M=st.M;if not M then return end
 local style=styleOf(p);local W=style.walk;local I=style.idle
 rp.FilterDescendantsInstances={char}
 local hit=workspace:Raycast(hrp.Position,Vector3.new(0,-4.2,0),rp)
 local v=hrp.AssemblyLinearVelocity
 local grounded=hit~=nil and hum.Health>0 and not hum.PlatformStand and not hum.Sit and abs(v.Y)<14
 st.w=st.w+((grounded and 1 or 0)-st.w)*math.min(1,dt*(grounded and 9 or 16))
 if st.w<.01 then return end
 local speed=Vector3.new(v.X,0,v.Z).Magnitude
 st.mv=st.mv+(clamp(speed/10,0,1)-st.mv)*math.min(1,dt*8)
 local run=clamp((speed-17)/8,0,1)
 local acting=(char:GetAttribute('SB_Act') or 0)>now
 st.a=st.a+((acting and 1 or 0)-st.a)*math.min(1,dt*(acting and 25 or 8))
 st.phase=st.phase+dt*speed*.55*(W.cad or 1)
 local ph,mv,a=st.phase,st.mv,st.a
 local s1=sin(ph)
 local br=sin(now*2*pi*.33)*(style.breathe or 2)
 local sw=sin(now*2*pi*(style.swayHz or .5))*(style.sway or 1)
 local bounce=(style.bounce or 0)*abs(sin(now*pi*(style.bounceHz or 2)))*(1-mv*.6)
 -- корпус
 local lean=(I.W[1] or 0)*(1-mv*.5)+W.lean*mv*(1+run*.9)+br*.3
 local twist=(I.W[2] or 0)*(1-mv)+s1*W.twist*mv+sw*.4*(1-mv)
 local roll=(I.W[3] or 0)*(1-mv*.5)+s1*W.roll*mv+sw*(1-mv)*.6
 if W.stumble then roll+=sin(now*1.7)*5*mv;twist+=sin(now*1.1)*6*mv end
 local Wa={lean,twist,roll}
 local yOff=-W.bob*mv*(.5-.5*cos(ph*2))+bounce-.04*abs(br)/3
 -- голова держит горизонт
 local Ha={(I.H[1] or 0)*(1-mv*.5)-lean*.3,(I.H[2] or 0)*(1-mv)-twist*.6,(I.H[3] or 0)*(1-mv*.5)-roll*.5}
 -- руки (правая рука идёт вперёд вместе с левой ногой)
 local base=W.keepArms and 1 or (1-mv*.6)
 local armSw=W.arm*mv*(1+run*.7)
 local side=(W.armSide or 0)*mv*.5+4*mv
 local Ra={(I.R[1] or 0)*base-s1*armSw*(W.rightArm or 1)-run*10,(I.R[2] or 0)*base+side+br*.4,(I.R[3] or 0)*base}
 local La={(I.L[1] or 0)*base+s1*armSw-run*10,(I.L[2] or 0)*base+side+br*.4,(I.L[3] or 0)*base}
 if W.keepArms then Ra[1]+=sin(ph*2)*4*mv;La[1]-=sin(ph*2)*4*mv end
 -- ноги
 local legSw=W.leg*mv*(1+run*.35)*(1-.5*a)
 local RHa={(I.RH[1] or 0)*(1-mv)+s1*legSw,(I.RH[2] or 0)*(1-mv)}
 local LHa={(I.LH[1] or 0)*(1-mv)-s1*legSw,(I.LH[2] or 0)*(1-mv)}
 -- применяем (во время удара руки/корпус/голова -> позы удара)
 local k,w=1-a,st.w
 local Rw=bodyR(Wa)
 M.W.Transform=M.W.Transform:Lerp(ID:Lerp(conj(M.W,Rw,Vector3.new(0,yOff,0)),k),w)
 M.H.Transform=M.H.Transform:Lerp(ID:Lerp(conj(M.H,headR(Ha)),k),w)
 M.R.Transform=M.R.Transform:Lerp(ID:Lerp(conj(M.R,armR(Ra,1)),k),w)
 M.L.Transform=M.L.Transform:Lerp(ID:Lerp(conj(M.L,armR(La,-1)),k),w)
 local Rwb=ID:Lerp(Rw,k)
 M.RH.Transform=M.RH.Transform:Lerp(conj(M.RH,legR(RHa,1,Rwb)),w)
 M.LH.Transform=M.LH.Transform:Lerp(conj(M.LH,legR(LHa,-1,Rwb)),w)
end

local states=setmetatable({},{__mode='k'})
local errs=0
RunService.Stepped:Connect(function(_,dt)
 dt=math.min(dt,.05);local now=os.clock()
 for _,p in ipairs(Players:GetPlayers()) do
  local char=p.Character
  if char then
   local st=states[char];if not st then st={phase=math.random()*6,w=0,a=0,mv=0};states[char]=st end
   local ok,err=pcall(stepChar,p,char,st,dt,now)
   if not ok and errs<5 then errs+=1;warn('[LOCO] '..tostring(err)) end
  end
 end
end)
