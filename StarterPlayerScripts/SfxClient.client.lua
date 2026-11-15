-- SfxClient v2.1: слушает события от сервера и включает звуки (сами звуки — ReplicatedStorage/Sfx)
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Sfx=require(RS:WaitForChild('Sfx'))
local remote=RS:WaitForChild('StreetAction')
local player=Players.LocalPlayer

remote.OnClientEvent:Connect(function(kind,data)
 if kind=='FX' then
  if type(data)=='table' and typeof(data.position)=='Vector3' then Sfx.fx(data.kind,data.position,data.f,data.u) end
 elseif kind=='SFX' then Sfx.event(data)
 elseif kind=='Dash' and type(data)=='table' then -- v2.1: звук рывка у того, кто рванул
  local p=Players:GetPlayerByUserId(data.userId or 0);local r=p and p.Character and p.Character:FindFirstChild('HumanoidRootPart')
  if r then Sfx.play('dash',r.Position) end
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
