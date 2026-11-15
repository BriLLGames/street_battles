-- StreetUI v2.0: новый выбор бойца (список + карточка со статами и скиллами) и новая панель скиллов.
-- ПК: колонка справа с рядами «клавиша · название · перезарядка». Телефон: круглые кнопки дугой вокруг большой кнопки УДАР (зона большого пальца).
-- Эффекты ударов и камера — в VfxClient. Слепота/сообщения — как раньше.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local UIS=game:GetService('UserInputService')
local RunService=game:GetService('RunService')
local TweenService=game:GetService('TweenService')
local player=Players.LocalPlayer
local cfg=require(RS:WaitForChild('GameConfig'))
local Sfx=require(RS:WaitForChild('Sfx'))
local remote=RS:WaitForChild('StreetAction')
local pg=player:WaitForChild('PlayerGui')
local old=pg:FindFirstChild('StreetBattlesUI');if old then old:Destroy() end
local gui=Instance.new('ScreenGui');gui.Name='StreetBattlesUI';gui.ResetOnSpawn=false;gui.IgnoreGuiInset=false;gui.Parent=pg
local function new(class,props,parent)
 local obj=Instance.new(class)
 for k,v in pairs(props) do obj[k]=v end
 obj.Parent=parent;return obj
end
local function corner(obj,r) new('UICorner',{CornerRadius=r and UDim.new(0,r) or UDim.new(0,8)},obj) end
local function round(obj) new('UICorner',{CornerRadius=UDim.new(.5,0)},obj) end
local function stroke(obj,color,th,tr) return new('UIStroke',{Color=color or Color3.fromRGB(118,125,134),Thickness=th or 1,Transparency=tr or .45,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},obj) end
local C3=Color3.fromRGB
local mobile=UIS.TouchEnabled and not UIS.MouseEnabled
local dark=C3(22,26,32);local panelBg=C3(30,35,43);local rowBg=C3(44,50,60);local light=C3(241,241,236);local dim=C3(160,168,178);local gold=C3(255,205,80)
local FONT=Enum.Font.GothamBold;local FONTB=Enum.Font.GothamBlack;local FONTR=Enum.Font.Gotham
local THEME={Siply=C3(124,156,206),Diesel=C3(238,128,52),Bitok=C3(196,138,74),Major=C3(84,126,214),Yura=C3(118,170,86),Jack=C3(62,170,156)}
local KEYCOL={Z=C3(214,92,80),X=C3(224,160,64),C=C3(92,170,120),V=C3(92,140,220),B=gold,Q=C3(150,156,166),F=C3(120,130,150),R=C3(180,110,210)}
local function theme(id) return THEME[id] or C3(150,150,160) end
local function curFighter() return player:GetAttribute('Fighter') or 'Siply' end
local function fighterCfg(id) return cfg.Characters[id] or cfg.Characters.Siply end

-- ===== масштаб под экран (телефон/планшет/маленькое окно) =====
local function viewport() local cam=workspace.CurrentCamera;return cam and cam.ViewportSize or Vector2.new(1280,720) end
local function uiScale() -- 1 = «нормальный» размер
 local v=viewport()
 if mobile then return math.clamp(math.min(v.X/760,v.Y/400),.72,1.2) end
 return math.clamp(v.Y/820,.72,1)
end

-- ============================================================
-- ВЫБОР БОЙЦА
-- ============================================================
local choose=new('TextButton',{Name='ChooseFighter',AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-12,0,10),Size=UDim2.fromOffset(mobile and 150 or 190,mobile and 44 or 42),Text='',AutoButtonColor=true,BackgroundColor3=dark,BackgroundTransparency=.1},gui)
corner(choose,10);local chooseStroke=stroke(choose,light,1,.6)
local chooseDot=new('Frame',{Position=UDim2.fromOffset(10,0),AnchorPoint=Vector2.new(0,.5),Size=UDim2.fromOffset(8,mobile and 28 or 26),BackgroundColor3=theme('Siply')},choose);corner(chooseDot,4);chooseDot.Position=UDim2.new(0,10,.5,0)
local chooseName=new('TextLabel',{Position=UDim2.fromOffset(26,3),Size=UDim2.new(1,-34,.5,-3),BackgroundTransparency=1,Text='',TextColor3=light,TextSize=mobile and 15 or 15,Font=FONT,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd},choose)
local chooseHint=new('TextLabel',{Position=UDim2.new(0,26,.5,0),Size=UDim2.new(1,-34,.5,-3),BackgroundTransparency=1,Text=mobile and 'Сменить бойца' or 'Сменить бойца [M]',TextColor3=dim,TextSize=12,Font=FONTR,TextXAlignment=Enum.TextXAlignment.Left},choose)

local overlay=new('TextButton',{Name='SelectorOverlay',Visible=false,Size=UDim2.fromScale(1,1),BackgroundColor3=C3(0,0,0),BackgroundTransparency=.4,Text='',AutoButtonColor=false,ZIndex=20},gui)
local win=new('Frame',{Active=true,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(.94,.9),BackgroundColor3=panelBg,ZIndex=21},overlay)
corner(win,14);stroke(win,light,1,.7)
new('UISizeConstraint',{MaxSize=Vector2.new(940,600),MinSize=Vector2.new(320,230)},win)
local head=new('Frame',{Size=UDim2.new(1,0,0,mobile and 46 or 52),BackgroundTransparency=1,ZIndex=22},win)
new('TextLabel',{Position=UDim2.fromOffset(16,0),Size=UDim2.new(1,-80,1,0),BackgroundTransparency=1,Text='ВЫБОР БОЙЦА',TextColor3=light,TextSize=mobile and 18 or 22,Font=FONTB,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=22},head)
local closeBtn=new('TextButton',{AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-8,.5,0),Size=UDim2.fromOffset(mobile and 48 or 40,mobile and 40 or 36),Text='✕',TextColor3=light,TextSize=20,Font=FONT,BackgroundColor3=C3(125,52,44),ZIndex=22},head);corner(closeBtn,8)
local body=new('Frame',{Position=UDim2.new(0,0,0,mobile and 46 or 52),Size=UDim2.new(1,0,1,-(mobile and 46 or 52)),BackgroundTransparency=1,ZIndex=22},win)
local listW=mobile and .34 or .3
local list=new('ScrollingFrame',{Position=UDim2.fromOffset(10,0),Size=UDim2.new(listW,-14,1,-10),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=mobile and 3 or 5,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ZIndex=22},body)
new('UIListLayout',{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},list)
local detailBox=new('Frame',{Position=UDim2.new(listW,0,0,0),Size=UDim2.new(1-listW,-10,1,-10),BackgroundColor3=C3(24,28,35),ZIndex=22},body);corner(detailBox,10)
local detail=new('ScrollingFrame',{Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,0,1,-(mobile and 58 or 62)),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=mobile and 3 or 5,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ZIndex=23},detailBox)
new('UIPadding',{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12),PaddingTop=UDim.new(0,10),PaddingBottom=UDim.new(0,8)},detail)
new('UIListLayout',{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},detail)
local pickBtn=new('TextButton',{AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-8),Size=UDim2.new(1,-24,0,mobile and 46 or 48),Text='ВЫБРАТЬ',TextColor3=C3(20,22,26),TextSize=mobile and 18 or 20,Font=FONTB,BackgroundColor3=gold,ZIndex=24},detailBox);corner(pickBtn,10)

local rowBtns={} -- [id]={btn=,stroke=,tag=}
local preview=curFighter()
local order=0
local function nextOrder() order+=1;return order end
local function label(parent,text,size,color,font,extra)
 local p={BackgroundTransparency=1,Text=text,TextSize=size,TextColor3=color or light,Font=font or FONTR,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,AutomaticSize=Enum.AutomaticSize.Y,Size=UDim2.new(1,0,0,0),LayoutOrder=nextOrder(),ZIndex=24}
 if extra then for k,v in pairs(extra) do p[k]=v end end
 return new('TextLabel',p,parent)
end
local function statBar(parent,title,value,maxv,color)
 local row=new('Frame',{Size=UDim2.new(1,0,0,22),BackgroundTransparency=1,LayoutOrder=nextOrder(),ZIndex=24},parent)
 new('TextLabel',{Size=UDim2.new(0,mobile and 74 or 90,1,0),BackgroundTransparency=1,Text=title,TextSize=12,TextColor3=dim,Font=FONT,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=24},row)
 local back=new('Frame',{Position=UDim2.new(0,mobile and 76 or 92,.5,0),AnchorPoint=Vector2.new(0,.5),Size=UDim2.new(1,-(mobile and 130 or 150),0,12),BackgroundColor3=C3(52,58,68),ZIndex=24},row);corner(back,6)
 local fill=new('Frame',{Size=UDim2.new(math.clamp(value/maxv,.05,1),0,1,0),BackgroundColor3=color,ZIndex=25},back);corner(fill,6)
 new('TextLabel',{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,0,0,0),Size=UDim2.new(0,44,1,0),BackgroundTransparency=1,Text=tostring(value),TextSize=14,TextColor3=light,Font=FONT,TextXAlignment=Enum.TextXAlignment.Right,ZIndex=24},row)
end
local function skillCard(parent,key,name,cd,desc,color)
 local card=new('Frame',{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=C3(36,42,51),LayoutOrder=nextOrder(),ZIndex=24},parent);corner(card,8)
 new('UIPadding',{PaddingLeft=UDim.new(0,52),PaddingRight=UDim.new(0,10),PaddingTop=UDim.new(0,7),PaddingBottom=UDim.new(0,8)},card)
 local badge=new('TextLabel',{AnchorPoint=Vector2.new(0,0),Position=UDim2.fromOffset(-44,-1),Size=UDim2.fromOffset(36,36),BackgroundColor3=color,Text=key,TextColor3=C3(20,22,26),TextSize=18,Font=FONTB,ZIndex=25},card);corner(badge,8)
 local inner=new('Frame',{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,ZIndex=24},card)
 new('UIListLayout',{Padding=UDim.new(0,2),SortOrder=Enum.SortOrder.LayoutOrder},inner)
 local top=new('Frame',{Size=UDim2.new(1,0,0,20),BackgroundTransparency=1,LayoutOrder=1,ZIndex=24},inner)
 new('TextLabel',{Size=UDim2.new(1,-70,1,0),BackgroundTransparency=1,Text=name,TextSize=mobile and 14 or 15,TextColor3=light,Font=FONT,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=24},top)
 if cd then new('TextLabel',{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,0,0,0),Size=UDim2.fromOffset(66,20),BackgroundTransparency=1,Text='КД '..tostring(cd)..' с',TextSize=12,TextColor3=dim,Font=FONT,TextXAlignment=Enum.TextXAlignment.Right,ZIndex=24},top) end
 new('TextLabel',{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Text=desc or '',TextSize=12,TextColor3=dim,Font=FONTR,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,LayoutOrder=2,ZIndex=24},inner)
end
local function refreshPick()
 local cur=curFighter();local col=theme(preview)
 if preview==cur then pickBtn.Text='УЖЕ ВЫБРАН';pickBtn.BackgroundColor3=C3(70,76,86);pickBtn.TextColor3=dim
 else pickBtn.Text='ВЫБРАТЬ: '..string.upper(fighterCfg(preview).name);pickBtn.BackgroundColor3=col;pickBtn.TextColor3=C3(18,20,24) end
 for id,r in pairs(rowBtns) do
  local sel=id==preview
  r.stroke.Color=sel and theme(id) or light;r.stroke.Thickness=sel and 2 or 1;r.stroke.Transparency=sel and 0 or .8
  r.btn.BackgroundColor3=sel and C3(58,66,80) or rowBg
  r.tag.Visible=id==cur
 end
end
local function buildDetail(id)
 for _,c in ipairs(detail:GetChildren()) do if not c:IsA('UIListLayout') and not c:IsA('UIPadding') then c:Destroy() end end
 order=0
 local c=fighterCfg(id);local col=theme(id)
 local hd=new('Frame',{Size=UDim2.new(1,0,0,mobile and 44 or 52),BackgroundTransparency=1,LayoutOrder=nextOrder(),ZIndex=24},detail)
 new('Frame',{Size=UDim2.new(0,5,1,-4),Position=UDim2.fromOffset(0,2),BackgroundColor3=col,ZIndex=24},hd)
 new('TextLabel',{Position=UDim2.fromOffset(14,0),Size=UDim2.new(1,-14,.62,0),BackgroundTransparency=1,Text=string.upper(c.name),TextSize=mobile and 22 or 26,TextColor3=col,Font=FONTB,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=24},hd)
 new('TextLabel',{Position=UDim2.new(0,14,.62,0),Size=UDim2.new(1,-14,.38,0),BackgroundTransparency=1,Text='Предмет: '..c.item,TextSize=13,TextColor3=dim,Font=FONTR,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=24},hd)
 statBar(detail,'ЗДОРОВЬЕ',c.hp,120,C3(220,84,84))
 statBar(detail,'СКОРОСТЬ',c.speed,17,C3(90,190,230))
 label(detail,c.passive,13,C3(205,210,218),FONTR)
 local keys={'Z','X','C','V'}
 for i,s in ipairs(c.skills) do skillCard(detail,keys[i],s[1],s[2],s[3],KEYCOL[keys[i]]) end
 if c.special then skillCard(detail,'R',c.special[1],c.special[2],c.special[3],KEYCOL.R) end
 skillCard(detail,'B',c.ult.name,nil,c.ult.desc,gold)
end
local function setPreview(id)
 preview=id;buildDetail(id);refreshPick();detail.CanvasPosition=Vector2.new(0,0)
end
for _,id in ipairs(cfg.Order) do
 local c=cfg.Characters[id]
 local b=new('TextButton',{Size=UDim2.new(1,0,0,mobile and 60 or 64),BackgroundColor3=rowBg,Text='',AutoButtonColor=true,LayoutOrder=#list:GetChildren(),ZIndex=23},list);corner(b,10)
 local st=stroke(b,light,1,.8)
 new('Frame',{Size=UDim2.new(0,6,1,-14),Position=UDim2.fromOffset(7,7),BackgroundColor3=theme(id),ZIndex=24},b)
 new('TextLabel',{Position=UDim2.fromOffset(22,7),Size=UDim2.new(1,-28,0,22),BackgroundTransparency=1,Text=c.name,TextColor3=light,TextSize=mobile and 14 or 16,Font=FONT,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=24},b)
 new('TextLabel',{Position=UDim2.fromOffset(22,29),Size=UDim2.new(1,-28,0,18),BackgroundTransparency=1,Text=c.item,TextColor3=dim,TextSize=12,Font=FONTR,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=24},b)
 local tag=new('TextLabel',{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-6,0,5),Size=UDim2.fromOffset(mobile and 22 or 58,16),BackgroundColor3=gold,Text=mobile and '✓' or 'ВЫБРАН',TextColor3=C3(20,22,26),TextSize=10,Font=FONTB,Visible=false,ZIndex=25},b);corner(tag,5)
 rowBtns[id]={btn=b,stroke=st,tag=tag}
 b.Activated:Connect(function() Sfx.ui('click');setPreview(id) end)
end
local function openSelector(on)
 if on==nil then on=not overlay.Visible end
 overlay.Visible=on
 if on then setPreview(curFighter()) end
end
choose.Activated:Connect(function() Sfx.ui('click');openSelector() end)
closeBtn.Activated:Connect(function() Sfx.ui('click');openSelector(false) end)
overlay.Activated:Connect(function() openSelector(false) end)
pickBtn.Activated:Connect(function()
 Sfx.ui('click')
 if preview~=curFighter() then remote:FireServer('Select',preview) end
 openSelector(false)
end)
local function refreshChoose()
 local id=curFighter();chooseName.Text=fighterCfg(id).name;chooseDot.BackgroundColor3=theme(id);chooseStroke.Color=theme(id);chooseStroke.Transparency=.2
 if overlay.Visible then refreshPick() end
end
player:GetAttributeChangedSignal('Fighter'):Connect(refreshChoose);refreshChoose()
local function selectorWin() local s=uiScale();win.Size=UDim2.fromScale(mobile and .96 or .9,mobile and .94 or .86) end
selectorWin()

-- ============================================================
-- ПАНЕЛЬ СКИЛЛОВ
-- ============================================================
local keys={'Z','X','C','V','B','Q','F','R'}
local buttons={};local cooldowns={};local cdTotal={}
local function action(key,held)
 if held and key~='F' then -- звук «нельзя», если скилл на перезарядке или ульта ещё не заряжена
  local blocked
  if key=='B' then blocked=(player:GetAttribute('UltCharge') or 0)<100 else blocked=(cooldowns[key] or 0)>os.clock() end
  if blocked then Sfx.ui('fail') end
 end
 if key=='Z' then remote:FireServer('Skill',1)
 elseif key=='X' then remote:FireServer('Skill',2)
 elseif key=='C' then remote:FireServer('Skill',3)
 elseif key=='V' then remote:FireServer('Skill',4)
 elseif key=='B' then remote:FireServer('Ult')
 elseif key=='Q' then remote:FireServer('Dash')
 elseif key=='F' then remote:FireServer('Block',held)
 elseif key=='R' then remote:FireServer('Special') end
end
local function skillName(key)
 local c=fighterCfg(curFighter())
 if key=='Z' then return c.skills[1][1] elseif key=='X' then return c.skills[2][1] elseif key=='C' then return c.skills[3][1] elseif key=='V' then return c.skills[4][1] elseif key=='B' then return c.ult.name elseif key=='Q' then return 'Рывок' elseif key=='F' then return 'Блок' elseif key=='R' then return c.special and c.special[1] or '' end
 return ''
end
local function shortName(name) -- для круглых кнопок: первое слово, без знаков препинания
 local w=name:match('^[^%s]+') or name
 w=w:gsub('[%?%!%.,«»]','')
 return w
end
local root=new('Frame',{Name='Skills',BackgroundTransparency=1,AnchorPoint=Vector2.new(1,1),Size=UDim2.fromOffset(mobile and 350 or 276,mobile and 240 or 10),Position=UDim2.new(1,mobile and -92 or -16,1,mobile and -12 or -16),AutomaticSize=mobile and Enum.AutomaticSize.None or Enum.AutomaticSize.Y},gui)
local rootScale=new('UIScale',{Scale=1},root)
local function setSweep(b,frac,col) -- закрашивает долю frac кнопки (перезарядка / недозаряд ульты)
 local g=b.grad;frac=math.clamp(frac,0,1)
 if frac<=.002 then g.Transparency=NumberSequence.new(1)
 elseif frac>=.998 then g.Transparency=NumberSequence.new(.38)
 else g.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.38),NumberSequenceKeypoint.new(frac,.38),NumberSequenceKeypoint.new(math.min(frac+.002,.999),1),NumberSequenceKeypoint.new(1,1)}) end
end
local function makeButton(key,parent,mode,size,pos)
 local col=KEYCOL[key]
 local b={key=key,mode=mode}
 local btn=new('TextButton',{Name='Skill'..key,Text='',AutoButtonColor=false,BackgroundColor3=dark,BackgroundTransparency=.08,Size=size,ZIndex=2},parent)
 if pos then btn.Position=pos;btn.AnchorPoint=Vector2.new(.5,.5) end
 b.btn=btn
 if mode=='circle' then round(btn) else corner(btn,10) end
 b.stroke=stroke(btn,col,mode=='circle' and 2 or 1.5,.15)
 local sweep=new('Frame',{Size=UDim2.fromScale(1,1),BackgroundColor3=C3(0,0,0),ZIndex=3,Active=false},btn)
 if mode=='circle' then round(sweep) else corner(sweep,10) end
 b.grad=new('UIGradient',{Rotation=mode=='row' and 0 or 90,Transparency=NumberSequence.new(1)},sweep)
 if mode=='circle' then
  b.keyL=new('TextLabel',{Size=UDim2.fromScale(1,.58),Position=UDim2.fromScale(0,.04),BackgroundTransparency=1,Text=key,TextColor3=col,TextSize=size.X.Offset>=60 and 24 or 20,Font=FONTB,ZIndex=4},btn)
  b.nameL=new('TextLabel',{Size=UDim2.fromScale(.9,.3),Position=UDim2.fromScale(.05,.6),BackgroundTransparency=1,Text='',TextColor3=light,TextScaled=true,Font=FONT,ZIndex=4},btn)
  new('UITextSizeConstraint',{MaxTextSize=12,MinTextSize=9},b.nameL)
  b.timeL=new('TextLabel',{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text='',TextColor3=light,TextSize=20,Font=FONTB,ZIndex=5},btn)
 else
  local bw=mode=='row' and 34 or 30
  b.badge=new('TextLabel',{AnchorPoint=Vector2.new(0,.5),Position=UDim2.new(0,5,.5,0),Size=UDim2.fromOffset(bw,bw),BackgroundColor3=col,Text=key,TextColor3=C3(20,22,26),TextSize=mode=='row' and 18 or 16,Font=FONTB,ZIndex=4},btn);corner(b.badge,7)
  b.nameL=new('TextLabel',{Position=UDim2.fromOffset(bw+12,0),Size=UDim2.new(1,-(bw+12)-(mode=='row' and 58 or 40),1,0),BackgroundTransparency=1,Text='',TextColor3=light,TextSize=mode=='row' and 14 or 13,Font=FONT,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=4},btn)
  b.timeL=new('TextLabel',{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-8,0,0),Size=UDim2.fromOffset(mode=='row' and 52 or 36,1),BackgroundTransparency=1,Text='',TextColor3=light,TextSize=14,Font=FONTB,TextXAlignment=Enum.TextXAlignment.Right,ZIndex=4},btn)
  b.timeL.Size=UDim2.new(0,mode=='row' and 52 or 36,1,0)
 end
 -- нажатие
 local function press(on)
  TweenService:Create(btn,TweenInfo.new(.08),{BackgroundColor3=on and C3(50,58,70) or dark}):Play()
 end
 if key=='F' then
  local function down(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then if not overlay.Visible then action('F',true) end press(true) end end
  local function up(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then action('F',false);press(false) end end
  btn.InputBegan:Connect(down);btn.InputEnded:Connect(up)
 else
  btn.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then press(true) end end)
  btn.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then press(false) end end)
  btn.Activated:Connect(function() if not overlay.Visible then action(key,true) end end)
 end
 buttons[key]=b;return b
end
if mobile then
 -- Дуга вокруг кнопки УДАР (координаты внутри рамки 350×240, центр кнопки УДАР в (300,188)). Рамка сдвинута влево на 92, чтобы не закрывать стандартную кнопку прыжка Roblox
 local CX,CY,R=300,188,114
 local function arc(deg) local a=math.rad(deg);return UDim2.fromOffset(CX+R*math.cos(a),CY-R*math.sin(a)) end
 local function circle(key,size,pos) return makeButton(key,root,'circle',UDim2.fromOffset(size,size),pos) end
 circle('Z',58,arc(180));circle('X',58,arc(147));circle('C',58,arc(114));circle('V',58,arc(81))
 circle('B',66,UDim2.fromOffset(112,184));circle('Q',50,UDim2.fromOffset(124,112));circle('F',54,UDim2.fromOffset(48,184));circle('R',50,UDim2.fromOffset(50,112))
 local punch=new('TextButton',{Name='Punch',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(CX,CY),Size=UDim2.fromOffset(92,92),Text='УДАР',TextSize=18,Font=FONTB,TextColor3=light,BackgroundColor3=C3(150,58,48),AutoButtonColor=false,ZIndex=2},root);round(punch);stroke(punch,C3(255,170,150),3,.1)
 punch.Activated:Connect(function() if not overlay.Visible then remote:FireServer('Punch') end end)
 punch.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then TweenService:Create(punch,TweenInfo.new(.06),{BackgroundColor3=C3(200,86,70)}):Play() end end)
 punch.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then TweenService:Create(punch,TweenInfo.new(.12),{BackgroundColor3=C3(150,58,48)}):Play() end end)
else
 new('UIListLayout',{Padding=UDim.new(0,6),FillDirection=Enum.FillDirection.Vertical,HorizontalAlignment=Enum.HorizontalAlignment.Right,VerticalAlignment=Enum.VerticalAlignment.Bottom,SortOrder=Enum.SortOrder.LayoutOrder},root)
 local order2={'Z','X','C','V','R','B'}
 for i,key in ipairs(order2) do local b=makeButton(key,root,'row',UDim2.new(1,0,0,key=='B' and 46 or 42));b.btn.LayoutOrder=i end
 local pair=new('Frame',{Size=UDim2.new(1,0,0,38),BackgroundTransparency=1,LayoutOrder=10},root)
 new('UIListLayout',{Padding=UDim.new(0,6),FillDirection=Enum.FillDirection.Horizontal,SortOrder=Enum.SortOrder.LayoutOrder},pair)
 for i,key in ipairs({'Q','F'}) do local b=makeButton(key,pair,'half',UDim2.new(.5,-3,1,0));b.btn.LayoutOrder=i end
end
local function fitScale() rootScale.Scale=uiScale() end
fitScale()
local cam=workspace.CurrentCamera
if cam then cam:GetPropertyChangedSignal('ViewportSize'):Connect(function() fitScale();selectorWin() end) end

local notice=new('TextLabel',{AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,mobile and 56 or 70),Size=UDim2.new(.6,0,0,38),BackgroundTransparency=1,Text='',TextColor3=light,TextSize=mobile and 17 or 20,Font=FONT,TextStrokeTransparency=.5},gui)
-- (эффекты ударов и тряска камеры — в VfxClient.client.lua)
local blindFrame=new('Frame',{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=1,ZIndex=50,Active=false,BorderSizePixel=0},gui)
local blindLabel=new('TextLabel',{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text='',TextColor3=light,TextSize=40,Font=FONTB,ZIndex=51},blindFrame)
local blindToken=0
local blindColors={dark=C3(10,10,12),dust=C3(150,125,90),toxic=C3(70,110,40),beer=C3(200,160,60),pigeons=C3(190,190,200)}
local function blind(duration,kind)
 blindToken+=1;local t=blindToken
 blindFrame.BackgroundColor3=blindColors[kind] or blindColors.dark
 blindLabel.Text=kind=='pigeons' and 'ГОЛУБИ!' or ''
 blindFrame.BackgroundTransparency=.12
 task.delay(math.max(duration or 1,.2),function()
  if blindToken==t then TweenService:Create(blindFrame,TweenInfo.new(.35),{BackgroundTransparency=1}):Play();blindLabel.Text='' end
 end)
end
remote.OnClientEvent:Connect(function(kind,data)
 if kind=='Cooldown' and data and data.key then cooldowns[data.key]=os.clock()+(data.duration or 0);cdTotal[data.key]=math.max(data.duration or 0,.1)
 elseif kind=='Blind' and type(data)=='table' then blind(data.duration,data.kind)
 elseif kind=='Message' and data and data.text then
  notice.Text=data.text;local msg=data.text
  task.delay(2,function() if notice.Text==msg then notice.Text='' end end)
 end
end)
UIS.InputBegan:Connect(function(input,processed)
 if input.KeyCode==Enum.KeyCode.M and not UIS:GetFocusedTextBox() then openSelector();return end
 if input.KeyCode==Enum.KeyCode.Escape and overlay.Visible then openSelector(false);return end
 if processed or overlay.Visible or UIS:GetFocusedTextBox() then return end
 if input.UserInputType==Enum.UserInputType.MouseButton1 then remote:FireServer('Punch');return end
 local key=input.KeyCode.Name
 if buttons[key] then action(key,true) end
end)
UIS.InputEnded:Connect(function(input) if input.KeyCode==Enum.KeyCode.F then action('F',false) end end)
local elapsed=0;local pulse=0
RunService.RenderStepped:Connect(function(dt)
 pulse+=dt;elapsed+=dt;if elapsed<.05 then return end;elapsed=0
 local charge=player:GetAttribute('UltCharge') or 0
 for _,key in ipairs(keys) do
  local b=buttons[key]
  if b then
   local name=skillName(key)
   b.btn.Visible=(key~='R' or name~='')
   local remaining=math.max(0,(cooldowns[key] or 0)-os.clock())
   local total=cdTotal[key] or 1
   local circle=b.mode=='circle'
   if key=='B' then
    local ready=charge>=100
    setSweep(b,ready and 0 or 1-charge/100)
    local glow=.5+.5*math.sin(pulse*6)
    b.stroke.Thickness=ready and (2.5+glow*2) or 2;b.stroke.Transparency=ready and 0 or .35
    if circle then b.nameL.Text=ready and 'УЛЬТА' or (tostring(charge)..'%');b.timeL.Text='' else b.nameL.Text=name;b.timeL.Text=ready and 'ГОТОВА' or (tostring(charge)..'%') end
    b.btn.BackgroundColor3=ready and C3(70,58,26) or dark
   else
    setSweep(b,remaining>0 and remaining/total or 0)
    if circle then
     b.timeL.Text=remaining>0 and string.format(remaining>=10 and '%d' or '%.1f',remaining) or ''
     b.keyL.Visible=remaining<=0;b.nameL.Text=remaining>0 and '' or shortName(name)
    else
     b.nameL.Text=name;b.timeL.Text=remaining>0 and string.format('%.1f',remaining) or ''
    end
    b.stroke.Transparency=remaining>0 and .6 or .15
   end
  end
 end
end)
