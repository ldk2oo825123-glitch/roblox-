-- Actual Inventory adapter executed unchanged with service/geometry mocks.
Color3={fromRGB=function(...)return {...}end}
local C=dofile('src/ReplicatedStorage/Config.lua')
local L=dofile('src/ReplicatedStorage/InventoryLogic.lua').new(C)
local checks=0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b));checks=checks+1 end
local function signal()
 local s={callbacks={}}
 function s:Connect(fn)local c={connected=true};function c:Disconnect()self.connected=false end;self.callbacks[#self.callbacks+1]={fn=fn,c=c};return c end
 function s:Fire(...)for _,e in ipairs(self.callbacks)do if e.c.connected then e.fn(...)end end end
 return s
end
local function vector(x,y,z)
 local v={X=x,Y=y,Z=z}
 return setmetatable(v,{__sub=function(a,b)return {Magnitude=math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2)}end,__add=function(a,b)return vector(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end})
end
Vector3={new=vector}
local now=100
local realClock=os.clock;os.clock=function()return now end
local Players={PlayerRemoving=signal()}
local player={UserId=1,Parent=Players,CharacterAdded=signal(),attributes={}}
function player:IsA(n)return n=='Player'end
function player:GetAttribute(n)return self.attributes[n]end
local hrp={Position=vector(0,3,-1)}
local humanoid={Health=100,Died=signal()}
local character={}
function character:FindFirstChild(n)return n=='HumanoidRootPart' and hrp end
function character:FindFirstChildOfClass(n)return n=='Humanoid' and humanoid end
function character:WaitForChild(n)return self:FindFirstChildOfClass(n)end
player.Character=character
function Players:GetPlayerFromCharacter(c)if c==character then return player end end
function typeof(v)if type(v)=='table' and v.IsA then return 'Instance'end;return type(v)end
local delayed={}
task={spawn=function(fn,...)fn(...)end,delay=function(duration,fn)delayed[#delayed+1]={duration=duration,fn=fn}end}
workspace={}
Instance={new=function(class)return {ClassName=class}end}
local remotes={}
local Remotes={Setup=function()end,Get=function(name)
 if not remotes[name]then remotes[name]={};remotes[name].FireClient=function(self,p,state)self.last=state end end
 return remotes[name]
end}
local drops={}
local World={create=function(item,position,parent)
 local p={item=item,Position=position,Parent=parent,Touched=signal()}
 function p:Destroy()self.Parent=nil end
 drops[#drops+1]=p;return p
end}
local uid=0
local Http={GenerateGUID=function()uid=uid+1;return 'guid-'..uid end}
local RS={Config={},InventoryLogic={},BrainrotData={},Remotes={}}
local services={Players=Players,ReplicatedStorage=RS,HttpService=Http}
game={GetService=function(_,n)return services[n]end}
script={Parent={WorldItems={}}}
local Data={CalculateValue=function(tier,variant)
 local base,bonus
 for _,t in ipairs(C.Brainrots.Tiers)do if t.Name==tier then base=t.BaseValue end end
 for _,v in ipairs(C.Brainrots.Variants)do if v.Name==variant then bonus=v.Bonus end end
 return math.floor(base*(1+bonus)*10+0.5)/10
end}
local modules={[RS.Config]=C,[RS.InventoryLogic]={new=function()return L end},[RS.BrainrotData]=Data,[RS.Remotes]=Remotes,[script.Parent.WorldItems]=World}
local realRequire=require;require=function(key)return assert(modules[key])end
local I=dofile('src/ServerScriptService/Inventory.lua')
require=realRequire
I.Init(player)
local a=I.newItem('Sigma Frog','Gold');local b=I.newItem('Sigma Frog','Gold')
eq(a.id~=b.id,true);eq(a.value,3.3)
eq(I.addCarried(player,a),a);eq(#I.getState(player).carried,1)
hrp.Position=vector(0,3,1);I.enterSafeZone(player);eq(#I.getState(player).inventory,0)
hrp.Position=vector(0,3,-1);I.enterSafeZone(player);eq(#I.getState(player).inventory,1)
eq(I.snapshot(player).index.found,1)
local detached=I.snapshot(player);detached.inventory[1].items[1].value=999;eq(I.getState(player).inventory[1].value,3.3)
local function request(name,...)now=now+1;return remotes[name].OnServerInvoke(player,...)end
eq(request('PlaceItem',a.id,1).reason,'no base available')
local base={owner={},pedestals={[1]={Position=vector(0,3,-1)},[2]={Position=vector(0,3,-1)}}}
local Bases={getBase=function()return base end,Refresh=function()end,Is67Slot=function()return false end}
I.SetBases(Bases)
eq(request('PlaceItem',a.id,1).reason,'not your base')
base.owner=player;hrp.Position=vector(100,3,-1);eq(request('PlaceItem',a.id,1).reason,'too far from pedestal')
hrp.Position=vector(0,3,-1);eq(request('PlaceItem',a.id,7).reason,'invalid slot')
eq(request('PlaceItem',{},1).reason,'invalid item id')
eq(request('PlaceItem',a.id,1).ok,true);eq(I.getState(player).pedestals[1].id,a.id)
eq(request('PlaceItem',b.id,1).reason,'occupied slot')
eq(request('PickUpItem',1).ok,true);eq(I.getState(player).inventory[1].id,a.id)
eq(request('PickUpItem',1).reason,'empty slot')
eq(request('DropItem',a.id,'extra').reason,'invalid arguments')
I.addCarried(player,b);I.onRagdoll(player);eq(#I.getState(player).carried,0);eq(#I.getState(player).inventory,1);eq(drops[#drops].item.id,b.id)
I.addCarried(player,b);humanoid.Died:Fire();eq(#I.getState(player).carried,0);eq(#I.getState(player).inventory,1)
eq(request('DropItem',a.id).ok,true);eq(#I.getState(player).inventory,0)
local p=drops[#drops];local hit={FindFirstAncestorOfClass=function()return character end}
p.Touched:Fire(hit);eq(#I.getState(player).carried,0)
now=now+2;p.Touched:Fire(hit);eq(#I.getState(player).carried,1);eq(p.Parent,nil)
p.Touched:Fire(hit);eq(#I.getState(player).carried,1)
I.onDeath(player);eq(I.snapshot(player).index.found,1)
local expiring=drops[#drops];eq(delayed[#delayed].duration,40);delayed[#delayed].fn();eq(expiring.Parent,nil)
local unknown=I.newItem('Turbo Toast','Rainbow');I.addCarried(player,unknown);eq(I.snapshot(player).index.found,1);I.onDeath(player);eq(I.snapshot(player).index.found,1)
local latest=drops[#drops];eq(latest.Position.X,hrp.Position.X);eq(latest.Position.Z,hrp.Position.Z)
local saved=L.copyState(I.getState(player));saved.inventory={a};I.setState(player,saved);saved.inventory[1].id='external';eq(I.getState(player).inventory[1].id,'guid-1')
eq(pcall(function()I.setState(player,{})end),false)
eq(request('GetInventoryState').ok,true);eq(request('GetInventoryState','extra').ok,false)
eq(request('DropItem','missing').reason,'item not in inventory')
local response=remotes.DropItem.OnServerInvoke(player,'guid-1');eq(response.reason,'please wait')
-- A different owner is not subject to the two-second owner pickup lock.
local secondCharacter={}
function secondCharacter:FindFirstChild()return hrp end
function secondCharacter:FindFirstChildOfClass()return humanoid end
function secondCharacter:WaitForChild()return humanoid end
local second={Parent=Players,Character=secondCharacter,CharacterAdded=signal()}
function second:IsA(n)return n=='Player'end
function second:GetAttribute()return nil end
local priorLookup=Players.GetPlayerFromCharacter
function Players:GetPlayerFromCharacter(c)if c==secondCharacter then return second end;return priorLookup(self,c)end
I.Init(second)
local otherItem=I.newItem('Noodle Goblin','Normal')
local otherDrop=I.spawnGround(otherItem,hrp.Position,player)
otherDrop.Touched:Fire({FindFirstAncestorOfClass=function()return secondCharacter end})
eq(#I.getState(second).carried,1);eq(otherDrop.Parent,nil)
-- Touched parts without a character ancestor are ignored.
local emptyDrop=I.spawnGround(I.newItem('Noodle Goblin','Gold'),hrp.Position,player)
eq(pcall(function()emptyDrop.Touched:Fire({FindFirstAncestorOfClass=function()return nil end})end),true)
Players.PlayerRemoving:Fire(player);eq(I.getState(player),nil);eq(request('DropItem','guid-1').reason,'not ready')
os.clock=realClock
print('PASS: '..checks..' inventory server mock checks (not Roblox replication)')
