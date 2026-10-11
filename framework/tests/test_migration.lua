-- Synthetic real SaveServer v1 fixture; no actual player data.
Color3={fromRGB=function(r,g,b)return {R=r/255,G=g/255,B=b/255}end}
local C=dofile('src/ReplicatedStorage/Config.lua')
local L=dofile('src/ReplicatedStorage/ProfileLogic.lua').new(C)
local I=dofile('src/ReplicatedStorage/InventoryLogic.lua').new(C,true)
local checks=0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b));checks=checks+1 end
local now=1700000000
local function entry(name,value,count)
 return {name=name,value=value,r=0.1,g=0.25,b=0.75,mat='Metal',count=count}
end
local raw={cash=1234,speed=3,cashBoost=2,health=4,knockback=5,jump=6,ragdollRes=7,
 inventory={entry('Gold Sigma Frog',3.3,3),entry('Diamond Turbo Toast',9.6,2),entry('67 Brainrot',1,1)},
 discovered={'Gold Sigma Frog','Diamond Turbo Toast','Emerald Cosmic Banana','67 Brainrot','Retired Name'},
 nextSpin=now+123,has67=true,boostSpeed=now+900,boostMoney=now-1,boostHealth=now+450,
 boostRagdoll=now,boostJump=now+99,boostKnockback=now-900,stored={}}
for n=1,8 do raw.stored[n]=entry(n%2==0 and 'Diamond Sigma Frog' or 'Gold Sigma Frog',n%2==0 and 3.6 or 3.3) end
local p=assert(L.migrate(raw,now))
eq(p.cash,1234);eq(p.upgrades.Speed,3);eq(p.upgrades.Cash,2);eq(p.upgrades.Health,4)
eq(p.upgrades['Knockback Resist'],5);eq(p.upgrades.Jump,6);eq(p.upgrades['Ragdoll Resist'],7)
eq(#p.pedestals,6);eq(#p.inventory,7);eq(p.wheel.owns67,true)
eq(p.wheel.lastSpinAt,raw.nextSpin-86400)
eq(p.wheel.potions.SpeedBoost,raw.boostSpeed);eq(p.wheel.potions.HealthBoost,raw.boostHealth)
eq(p.wheel.potions.JumpBoost,raw.boostJump)
eq(p.wheel.potions.DoubleMoney,nil);eq(p.wheel.potions.RagdollResist,nil);eq(p.wheel.potions.KnockbackResist,nil)
eq(p.indexFound['Sigma Frog|Gold'],true);eq(p.indexFound['Turbo Toast|Diamond'],true)
eq(p.indexFound['Cosmic Banana|Emerald'],true);eq(p.indexFound['67 Brainrot|Normal'],nil)
local ids={}
for _,items in ipairs({p.inventory,p.pedestals})do
 for _,v in pairs(items)do
  eq(ids[v.id],nil);ids[v.id]=true;eq(v.r,0.1);eq(v.g,0.25);eq(v.b,0.75);eq(v.mat,'Metal')
 end
end
eq(I.validateState({inventory=p.inventory,pedestals=p.pedestals,carried={},indexFound=p.indexFound}),true)
local restored=assert(L.deserialize(assert(L.serialize(p)),now))
local copied=I.copyState({inventory=restored.inventory,pedestals=restored.pedestals,carried={},indexFound=restored.indexFound})
restored.inventory=copied.inventory;restored.pedestals=copied.pedestals
local reverse=assert(L.toLegacyV1(restored))
local function totals(save)
 local out={}
 for _,bucket in ipairs({save.inventory,save.stored})do
  for _,v in ipairs(bucket)do
   if v.name~='67 Brainrot' then
    local k=table.concat({v.name,v.value,v.r,v.g,v.b,v.mat},'|')
    out[k]=(out[k] or 0)+(v.count or 1)
   end
  end
 end
 return out
end
local before,after=totals(raw),totals(reverse)
for k,v in pairs(before)do eq(after[k],v) end
for k,v in pairs(after)do eq(before[k],v) end
for _,field in ipairs({'cash','speed','cashBoost','health','knockback','jump','ragdollRes','nextSpin','has67','boostSpeed','boostHealth','boostJump'})do eq(reverse[field],raw[field])end
for _,field in ipairs({'boostMoney','boostRagdoll','boostKnockback'})do eq(reverse[field],0)end
local discovered={};for _,name in ipairs(reverse.discovered)do discovered[name]=true end
for _,name in ipairs(raw.discovered)do eq(discovered[name],true)end
local again=assert(L.migrate(reverse,now))
eq(#again.inventory+#again.pedestals,13);eq(again.wheel.owns67,true)
eq(again.wheel.lastSpinAt,p.wheel.lastSpinAt)
-- 67 found in either bucket grants ownership and never becomes an ordinary item.
local only67=assert(L.migrate({stored={entry('67 Brainrot',1)},inventory={entry('67 Brainrot',1,3)}},now))
eq(only67.wheel.owns67,true);eq(#only67.inventory,0);eq(#only67.pedestals,0)
local defaults=assert(L.migrate({cash='bad',speed=-1,inventory=false,stored=7,discovered=false},now))
eq(defaults.cash,0);eq(defaults.upgrades.Speed,0);eq(#defaults.inventory,0)
print('PASS: '..checks..' real v1 migration checks (13 ordinary items preserved; 8 stored; stacked variants; 67; boost expiry; RGB/material round trip)')
