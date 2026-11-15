-- SfxClient v2.2: слушает события от сервера и включает звуки (сами звуки — ReplicatedStorage/Sfx)
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Sfx=require(RS:WaitForChild('Sfx'))
local remote=RS:WaitForChild('StreetAction')
local player=Players.LocalPlayer
local function rootOf(userId) local p=Players:GetPlayerByUserId(userId or 0);return p and p.Character and p.Character:FindFirstChild('HumanoidRootPart') end

remote.OnClientEvent:Connect(function(kind,data)
 if kind=='FX' then
  if type(data)=='table' and typeof(data.position)=='Vector3' then Sfx.fx(data.kind,data.position,data.f,data.u) end
 elseif kind=='SFX' then Sfx.event(data)
 elseif kind=='Dash' and type(data)=='table' then
  local r=rootOf(data.userId);if r then Sfx.play('dash',r.Position) end
 elseif kind=='Animate' and type(data)=='table' then -- v2.2: свист на каждом шаге ульты, звук контратаки
  local r=rootOf(data.userId)
  if r then
   if data.action=='UltStep' then Sfx.play((data.index or 1)%2==0 and 'swingHeavy' or 'spinWhoosh',r.Position)
   elseif data.action=='Counter' then Sfx.play('counter',r.Position)
   elseif data.action=='Finisher' then Sfx.play('charge',r.Position) end
  end
 elseif kind=='Blind' then Sfx.blind(type(data)=='table' and data.kind or nil)
 elseif kind=='Selected' then Sfx.ui('select')
 elseif kind=='Kill' then Sfx.ui('kill')
 end
end)

-- сигнал, когда ульта заряжена на 100%
local last=0
player:GetAttributeChangedSignal('UltCharge'):Connect(function()
 local v=player:GetAttribute('UltCharge') or 0
 if v>=100 and last<100 then Sfx.ui('ultReady') end
 last=v
end)
