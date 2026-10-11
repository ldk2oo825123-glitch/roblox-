Color3 = { fromRGB = function(...) return {...} end }
local Config = dofile('src/ReplicatedStorage/Config.lua')
local L = dofile('src/ReplicatedStorage/InventoryLogic.lua').new(Config)
local W = dofile('src/ReplicatedStorage/WheelLogic.lua').new(Config)
local checks = 0
local function eq(a,b) assert(a == b, tostring(a)..' ~= '..tostring(b)); checks=checks+1 end
local function item(id,tier,variant,value) return {id=tostring(id),tier=tier or 'Sigma Frog',variant=variant or 'Gold',value=value or 3.3} end
local s = L.newState()
eq(L.validateState(s),true)
local a,b = item('a'),item('b')
eq(L.addCarried(s,a),a); eq(L.indexProgress(s),0)
eq(L.addCarried(s,a),nil)
eq(#L.dropCarried(s,'death'),1); eq(L.indexProgress(s),0); eq(#s.inventory,0)
L.addCarried(s,a); eq(L.moveCarriedToInventory(s)[1],a); eq(L.indexProgress(s),1)
L.addCarried(s,b); eq(L.dropCarried(s,'ragdoll')[1],b); eq(s.inventory[1],a)
eq(#L.dropCarried(s,'death'),0); eq(s.inventory[1],a)
L.addCarried(s,b); L.moveCarriedToInventory(s)
eq(#s.inventory,2); eq(L.dropFromInventory(s,'b'),b); eq(#s.inventory,1); eq(s.inventory[1].id,'a')
eq(L.dropFromInventory(s,'missing'),nil)
for _,slot in ipairs({0,7,1.5,'1',false,math.huge,0/0}) do eq(L.placeOnPedestal(s,'a',slot),nil); eq(#s.inventory,1); eq(L.pickUpFromPedestal(s,slot),nil) end
eq(L.placeOnPedestal(s,'missing',1),nil); eq(L.placeOnPedestal(s,'a',1),a)
eq(L.bestPedestalValue(s),3.3); eq(L.incomePerTick(s,1.25),4.1)
L.addCarried(s,b); L.moveCarriedToInventory(s)
eq(L.placeOnPedestal(s,'b',1),nil); eq(s.inventory[1],b)
eq(L.pickUpFromPedestal(s,1),a)
for k,v in pairs(a) do eq(s.inventory[2][k],v) end
eq(L.bestPedestalValue(s),0); eq(L.incomePerTick(s,2),0)
s.indexFound={}; eq(L.placeOnPedestal(s,'a',6),a); eq(L.pickUpFromPedestal(s,6),a); eq(L.indexProgress(s),1)
eq(L.pickUpFromPedestal(s,6),nil)
local p={}; local base={owner=p}
eq(L.canAccessBase(p,nil,1,0),false); local _,reason=L.canAccessBase(p,nil,1,0);eq(reason,'no base available')
eq(L.canAccessBase({},base,1,0),false);eq(L.canAccessBase(p,base,0,0),false)
eq(L.canAccessBase(p,base,1,12),true);eq(L.canAccessBase(p,base,1,12.01),false)
eq(L.canAccessBase(p,base,1,0/0),false)
eq(L.inSafeZone({X=0,Y=3,Z=-1}),true);eq(L.inSafeZone({X=0,Y=3,Z=1}),false)
eq(L.inSafeZone({X=161,Y=3,Z=-1}),false);eq(L.inSafeZone({X=0,Y=61,Z=-1}),false)
s=L.newState()
for i=1,10000 do s.carried[i]=item(i) end -- independent bulk fixture, no implicit capacity limit
local moved=L.moveCarriedToInventory(s);eq(#moved,10000);eq(#s.inventory,10000);eq(#s.carried,0)
eq(L.addCarried(s,item(10001)),s.carried[1]);eq(#s.carried,1)
eq(#L.dropCarried(s,'death'),1);eq(#s.inventory,10000)
local groups=L.groupInventory(s);eq(#groups,1);eq(groups[1].count,10000);eq(#groups[1].items,10000)
L.addCarried(s,item('diamond','Sigma Frog','Diamond',3.6));L.moveCarriedToInventory(s)
eq(#L.groupInventory(s),2)
eq(L.validateState(s),true)
local copy=L.copyState(s);copy.inventory[1].id='changed';eq(s.inventory[1].id,'1')
eq(L.validateState({carried={},inventory={item('x'),item('x')},pedestals={},indexFound={}}),false)
eq(L.validateState({carried={},inventory={},pedestals={[7]=item('x')},indexFound={}}),false)
eq(L.validItem({id='67',tier='Brainrot67',variant='Normal',value=0}),false)
eq(L.validItem({id='bad',tier='bad',variant='bad'}),false)
eq(L.validItem(item('bad','Sigma Frog','Gold',999)),false)
eq(pcall(function() L.incomePerTick(s,math.huge) end),false)
eq(pcall(function() L.dropCarried(s,'other') end),false)
s=L.newState()
for _,tier in ipairs(Config.Brainrots.Tiers) do
 for _,variant in ipairs(Config.Brainrots.Variants) do
  local v=math.floor(tier.BaseValue*(1+variant.Bonus)*10+0.5)/10
  eq(L.addCarried(s,item(tier.Name..variant.Name,tier.Name,variant.Name,v))~=nil,true)
 end
end
eq(L.indexProgress(s),0);L.moveCarriedToInventory(s);local found,total=L.indexProgress(s);eq(found,25);eq(total,25)
eq(#L.groupInventory(s),25)
L.placeOnPedestal(s,'Golden GigarotRainbow',6);L.placeOnPedestal(s,'Sigma FrogGold',1)
eq(W.brainrot67Value({[6]=s.pedestals[6].value,[1]=s.pedestals[1].value}),L.bestPedestalValue(s));eq(L.bestPedestalValue(s),84)
L.pickUpFromPedestal(s,6);eq(L.bestPedestalValue(s),3.3)
print('PASS: '..checks..' inventory checks (10000 inventory items; all 25 Index entries)')
