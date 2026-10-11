-- Actual Bases adapter with geometry/service mocks; no engine behavior implied.
Color3={fromRGB=function(...)return {...}end}
local C=dofile('src/ReplicatedStorage/Config.lua')
local L=dofile('src/ReplicatedStorage/InventoryLogic.lua').new(C)
local WL=dofile('src/ReplicatedStorage/WheelLogic.lua').new(C)
local checks=0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b));checks=checks+1 end
local function signal()
 local s={list={}}
 function s:Connect(fn)local c={active=true};function c:Disconnect()self.active=false end;self.list[#self.list+1]={fn=fn,c=c};return c end
 function s:Fire(...)for _,e in ipairs(self.list)do if e.c.active then e.fn(...)end end end
 return s
end
local function vec(x,y,z)return setmetatable({X=x,Y=y,Z=z},{__add=function(a,b)return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end})end
Vector3={new=vec};UDim2={fromOffset=function(...)return {...}end};CFrame={new=function(v)return v end};Enum={KeyCode={E='E'}}
workspace={}
Instance={new=function(class)
 local o={ClassName=class,attributes={}}
 function o:SetAttribute(k,v)self.attributes[k]=v end
 return o
end}
local spawned={};local ticks=0
task={spawn=function(fn)spawned[#spawned+1]=fn end,wait=function()ticks=ticks+1;if ticks==1 then return end;error('stop mock loop')end}
local Players={}
local RS={Config={},InventoryLogic={},WheelLogic={}}
script={Parent={Wheel={},WorldItems={}}}
game={GetService=function(_,name)return name=='Players' and Players or RS end}
local Wheel={getIncome=function(p,values,ordinary)return (ordinary+(p.attributes.OwnsBrainrot67 and WL.brainrot67Value(values)or 0))*(p.mult or 1)end}
local World={label=function(part,text)
 local label={Text=text,Parent={},attributes={}}
 function label:SetAttribute(k,v)self.attributes[k]=v end
 return label
end}
local modules={[RS.Config]=C,[RS.InventoryLogic]={new=function()return L end},[RS.WheelLogic]={new=function()return WL end},[script.Parent.Wheel]=Wheel,[script.Parent.WorldItems]=World}
local realRequire=require;require=function(m)return assert(modules[m])end
local B=dofile('src/ServerScriptService/Bases.lua');require=realRequire
local states={}
local I={getState=function(p)return states[p]end,SetBases=function(module)eq(module,B)end}
B.Start(I);B.Start(I);eq(#spawned,1)
local function player(i)
 local p={UserId=i,DisplayName='Player '..i,CharacterAdded=signal(),attributes={},ownsChanged=signal()}
 function p:GetAttribute(k)return self.attributes[k]end
 function p:GetAttributeChangedSignal()return self.ownsChanged end
 states[p]=L.newState();return p
end
local ps={}
for i=1,6 do ps[i]=player(i);local base=B.Assign(ps[i]);eq(base~=nil,i<=5)end
eq(B.getBase(ps[6]),nil)
local base=B.getBase(ps[1]);eq(#base.pedestals,6);eq(#base.prompts,6)
for i,prompt in ipairs(base.prompts)do eq(prompt.attributes.OwnerUserId,1);eq(prompt.attributes.PedestalSlot,i);eq(prompt.KeyboardKeyCode,'E')end
eq(base.sign.Text,'Player 1\n$0.0 / 5s')
local a={id='a',tier='Sigma Frog',variant='Gold',value=3.3}
local best={id='best',tier='Golden Gigarot',variant='Rainbow',value=84}
states[ps[1]].pedestals={[1]=a,[6]=best};ps[1].mult=1.25;ps[1].attributes.OwnsBrainrot67=true
B.Refresh(ps[1]);eq(base.prompts[1].ActionText,'Pick Up');eq(base.prompts[2].ActionText,'Place')
eq(base.labels[6].attributes.RainbowLabel,true);eq(base.display67Slot,2)
eq(base.labels[2].Text,'Empty\n67 Brainrot $84');B.Show67(ps[1],true);eq(base.labels[2].Text,'Empty\n67 Brainrot $84')
eq(base.sign.Text,'Player 1\n$214.1 / 5s')
states[ps[1]].pedestals[6]=nil;B.Refresh(ps[1]);eq(base.labels[2].Text,'Empty\n67 Brainrot $3.3');eq(base.sign.Text,'Player 1\n$8.3 / 5s')
ps[1].attributes.OwnsBrainrot67=false;ps[1].ownsChanged:Fire();eq(base.display67Slot,nil);eq(base.labels[2].Text,'Empty')
eq(base.sign.Text,'Player 1\n$4.1 / 5s')
local credited={};B.SetCashHandler(function(p,amount)credited[p]=amount end)
local ok,err=pcall(spawned[1]);eq(ok,false);eq(err:find('stop mock loop',1,true)~=nil,true);eq(credited[ps[1]],4.1);eq(credited[ps[2]],0)
local oldCharacterConnection=base.characterConnection;local oldOwnsConnection=base.ownsConnection
B.Remove(ps[1]);eq(next(states[ps[1]].pedestals),nil);eq(B.getBase(ps[1]),nil);eq(base.sign.Text,'FREE');eq(oldCharacterConnection.active,false);eq(oldOwnsConnection.active,false)
for i,prompt in ipairs(base.prompts)do eq(prompt.attributes.OwnerUserId,nil);eq(base.labels[i].Text,'Empty');eq(base.labels[i].attributes.RainbowLabel,false)end
eq(B.Assign(ps[6]),base);eq(base.owner,ps[6])
print('PASS: '..checks..' base server mock checks (not Roblox geometry/prompts)')
