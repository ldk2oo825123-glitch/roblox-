Color3 = { fromRGB = function(...) return {...} end }
local C = dofile('src/ReplicatedStorage/Config.lua')
local L = dofile('src/ReplicatedStorage/ProfileLogic.lua').new(C)
local checks = 0
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)); checks=checks+1 end
local function deep(a,b)
 eq(type(a),type(b))
 if type(a)~='table' then eq(a,b);return end
 for k,v in pairs(a) do deep(v,b[k]) end
 for k in pairs(b) do eq(a[k]~=nil,true) end
end
local legacy={cash=120,speed=3,cashBoost=2,stored={}}
for i=1,8 do legacy.stored[i]={name='Sigma Frog',value=3} end
local migrated=L.migrate(legacy)
eq(migrated.cash,120);eq(migrated.upgrades.Speed,3);eq(migrated.upgrades.Cash,2)
eq(#migrated.pedestals,6);eq(#migrated.inventory,2)
local ids={}
for _,items in ipairs({migrated.pedestals,migrated.inventory}) do
 for _,item in pairs(items) do eq(item.variant,'Normal');eq(item.value,3);eq(ids[item.id],nil);ids[item.id]=true end
end
local full=L.default();full.cash=500;full.savedAt=12345
for name in pairs(full.upgrades) do full.upgrades[name]=10 end
full.wheel={lastSpinAt=100,potions={SpeedBoost=1000,DoubleMoney=2000,JumpBoost=3000},owns67=true}
full.pedestals[6]={id='sparse',tier='Golden Gigarot',variant='Rainbow',value=84}
full.inventory={{id='bag',tier='Sigma Frog',variant='Gold',value=3.3}}
full.indexFound={['Sigma Frog|Gold']=true,['Golden Gigarot|Rainbow']=true}
full.carried={{id='risk',tier='Turbo Toast',variant='Normal',value=8}}
local encoded=L.serialize(full);eq(encoded.pedestals['6'].id,'sparse');eq(encoded.carried,nil)
full.carried=nil;deep(L.deserialize(encoded),full)
encoded.inventory[1].id='detached';eq(full.inventory[1].id,'bag')
for _,cash in ipairs({-1,math.huge,-math.huge,0/0,'money'}) do eq(L.validate({version=2,cash=cash}),nil) end
for _,raw in ipairs({false,42,'bad'}) do eq(L.deserialize(raw),nil) end
eq(L.deserialize({version=3}),nil);eq(L.serialize({version=3}),nil)
local corrupt=L.default();corrupt.upgrades.Speed=11;corrupt.upgrades.Jump=-1;corrupt.upgrades.Cash=1.5
corrupt.upgrades.Unknown=9;corrupt.unknown=true;corrupt.wheel.potions={SpeedBoost=42,Bad=42,JumpBoost=0/0}
corrupt.inventory={false,{id='bad',tier='Sigma Frog',variant='Gold',value=999},full.inventory[1]}
corrupt.pedestals={[2]=full.inventory[1],['6']=full.pedestals[6]}
corrupt.indexFound={bad=true,['Sigma Frog|Gold']=true,['Sigma Frog|Normal']=false}
local clean=L.validate(corrupt)
eq(clean.upgrades.Speed,0);eq(clean.upgrades.Jump,0);eq(clean.upgrades.Cash,0);eq(clean.upgrades.Unknown,nil)
eq(clean.unknown,nil);eq(clean.wheel.potions.Bad,nil);eq(clean.wheel.potions.JumpBoost,nil)
eq(#clean.inventory,0);eq(clean.pedestals[2].id,'bag');eq(clean.pedestals[6].id,'sparse')
eq(clean.indexFound.bad,nil);eq(clean.indexFound['Sigma Frog|Gold'],true)
local partial=L.deserialize({version=2,inventory='bad',pedestals=false,wheel={potions=false},upgrades=7})
eq(partial.cash,0);eq(partial.upgrades.Health,0);eq(partial.wheel.lastSpinAt,0)
local retired=L.migrate({stored={{name='Retired Tier',value=77},{name='Gold Noodle Goblin',value=1.1}}})
eq(retired.pedestals[1].value,77);eq(retired.pedestals[2].value,1.1)
eq(retired.indexFound['Retired Tier|Normal'],nil)
local IL=dofile('src/ReplicatedStorage/InventoryLogic.lua').new(C,true)
eq(IL.validateState({carried={},inventory=retired.inventory,pedestals=retired.pedestals,indexFound=retired.indexFound}),true)
-- Economy/stats adapter runs unchanged, with a minimal character signal mock.
local function signal()
 local event={listeners={}}
 function event:Connect(fn)
  local connection={connected=true,fn=fn}
  function connection:Disconnect()self.connected=false end
  self.listeners[#self.listeners+1]=connection;return connection
 end
 function event:Fire(...)
  for _,connection in ipairs(self.listeners)do if connection.connected then connection.fn(...)end end
 end
 return event
end
local humanoid={Health=500}
local player={CharacterAdded=signal(),attributes={},Character={FindFirstChildOfClass=function()return humanoid end}}
function player:SetAttribute(k,v)self.attributes[k]=v end
local W=dofile('src/ReplicatedStorage/WheelLogic.lua').new(C)
local P=dofile('src/ServerScriptService/Profile.lua').new(C,W,function()return 500 end)
local p=L.default();P.Init(player,p)
eq(P.spendCash(player,1),false);eq(p.cash,0);eq(P.addCash(player,120),true)
eq(P.spendCash(player,100),true);eq(P.spendCash(player,21),false);eq(p.cash,20)
for _,n in ipairs({-1,0/0,math.huge,'bad'})do eq(P.addCash(player,n),false);eq(P.spendCash(player,n),false)end
eq(P.setUpgradeLevel(player,'Unknown',1),false);eq(P.setUpgradeLevel(player,'Speed',11),false)
for _,upgrade in ipairs(C.Shop.Upgrades)do eq(P.setUpgradeLevel(player,upgrade.Name,10),true)end
p.wheel.potions={JumpBoost=900,SpeedBoost=900,HealthBoost=900,DoubleMoney=900,RagdollResist=900,KnockbackResist=900}
local stats=P.applyStats(player)
eq(stats.WalkSpeed,44);eq(stats.JumpPower,125);eq(humanoid.JumpPower,125)
eq(stats.MaxHealth,400);eq(stats.IncomeMult,7);eq(stats.RagdollReduction,0.9);eq(stats.KnockbackReduction,0.9)
eq(humanoid.Health,400) -- Real ShopServer adds the increase in max health.
local expired=P.getEffectiveStats(player);p.wheel.potions={};expired=P.applyStats(player)
eq(expired.WalkSpeed,36);eq(expired.JumpPower,100);eq(expired.MaxHealth,350)
local respawnHumanoid={Health=100}
local respawn={WaitForChild=function()return respawnHumanoid end,FindFirstChildOfClass=function()return respawnHumanoid end}
player.Character=respawn;player.CharacterAdded:Fire(respawn)
eq(respawnHumanoid.Health,350);eq(respawnHumanoid.WalkSpeed,36);eq(respawnHumanoid.JumpPower,100);eq(respawnHumanoid.MaxHealth,350)
P.Remove(player);eq(P.addCash(player,1),false);eq(player.CharacterAdded.listeners[1].connected,false)
print('PASS: '..checks..' profile/economy/stat checks')
