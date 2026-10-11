Color3={fromRGB=function(...)return {...}end}
local C=dofile('src/ReplicatedStorage/Config.lua')
local L=dofile('src/ReplicatedStorage/ProfileLogic.lua').new(C)
local Factory=dofile('src/ServerScriptService/Saving.lua')
local checks=0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b));checks=checks+1 end
local function copy(t)if type(t)~='table'then return t end;local r={};for k,v in pairs(t)do r[k]=copy(v)end;return r end
local function fixture(raw,options)
 options=options or {};local f={now=1000,clock=0,warnings={},queue={},writes=0,calls=0,waits={},events={}}
 local player={UserId=1,active=true}
 function player:Kick(msg)self.kicked=msg end
 f.player=player;f.data=copy(raw);f.failures=options.failures or 0
 local store={}
 function store:UpdateAsync(key,fn)
  eq(key,'Player_1');f.calls=f.calls+1
  if f.failures>0 then f.failures=f.failures-1;error(options.error or 'temporary unavailable')end
  local output=fn(copy(f.data))
  if options.reenter then output=fn(copy(f.data))end -- Roblox may rerun transform.
  if output~=nil then f.data=copy(output);f.writes=f.writes+1 end
  return copy(output)
 end
 local Profile,Inventory,Wheel,Bases={},{},{},{}
 local function event(name)f.events[#f.events+1]=name end
 function Profile.Init(_,p)f.profile=p;event('profile init')end
 function Profile.get()return f.profile end
 function Profile.Remove()f.profile=nil;event('profile remove')end
 function Inventory.Init(_,s)f.inventory=copy(s);event('inventory init')end
 function Inventory.getState()return f.inventory end
 function Inventory.Remove()f.inventory=nil;event('inventory remove')end
 function Wheel.Init(_,s,p)f.wheel=s;eq(p,f.profile);event('wheel init')end
 function Wheel.getState()return copy(f.wheel)end
 function Wheel.Remove()f.wheel=nil;event('wheel remove')end
 function Bases.Assign()event('base assign')end
 function Bases.Remove()event('base remove');if f.inventory then f.inventory.pedestals={}end end
 local deps={store=store,Profile=Profile,Inventory=Inventory,Wheel=Wheel,Bases=Bases,jobId=options.jobId or 'job-a',isStudio=options.studio,
  now=function()return f.now end,clock=function()return f.clock end,isActive=function(p)return p.active end,
  warn=function(s)f.warnings[#f.warnings+1]=s end,
  wait=function(s)f.waits[#f.waits+1]=s;f.clock=f.clock+s;if options.onWait then options.onWait(f)end end,
  spawn=function(fn)if options.queued then f.queue[#f.queue+1]=fn else fn()end end}
 f.deps=deps;f.S=Factory.new(C,L,deps)
 return f
end
-- Failure must never initialize or later overwrite a blank profile.
local f=fixture(nil,{failures=3})
eq(f.S.load(f.player),false);eq(f.calls,3);eq(f.writes,0);eq(#f.events,0)
eq(f.waits[1],1);eq(f.waits[2],2);eq(f.player.kicked,C.Saving.LoadFailureMessage)
eq(f.S.save(f.player,true),false);eq(f.writes,0);f.S.remove(f.player);eq(f.writes,0)
-- Retries succeed and migration preserves all eight items.
local raw={cash=120,speed=3,cashBoost=2,stored={}}
for i=1,8 do raw.stored[i]={name='Noodle Goblin',value=1}end
f=fixture(raw,{failures=2,reenter=true})
eq(f.S.load(f.player),true);eq(f.calls,3);eq(f.profile.cash,120);eq(f.profile.upgrades.Speed,3);eq(f.profile.upgrades.Cash,2)
eq(#f.inventory.pedestals,6);eq(#f.inventory.inventory,2);eq(f.data._session.jobId,'job-a')
eq(table.concat(f.events,','),'profile init,wheel init,inventory init,base assign')
f.inventory.carried={{id='at-risk',tier='Sigma Frog',variant='Normal',value=3}}
f.inventory.pedestals[6].variant='Gold';f.inventory.pedestals[6].value=1.1
f.profile.cash=130;f.wheel.owns67=true;f.wheel.potions.SpeedBoost=5000
f.S.remove(f.player)
eq(f.data.cash,130);eq(f.data.pedestals['6'].variant,'Gold');eq(f.data.carried,nil)
eq(f.data._session,nil);eq(f.data.wheel.owns67,true);eq(f.data.wheel.potions.SpeedBoost,5000)
eq(f.events[5],'base remove');eq(f.profile,nil)
-- Existing lock blocks another session, expired lock is recoverable.
raw=L.serialize(L.default());raw._session={token='other',jobId='job-b',at=1000}
f=fixture(raw);eq(f.S.load(f.player),false);eq(f.writes,0);eq(f.S.save(f.player),false)
raw._session.at=1000-C.Saving.SessionLockSeconds
f=fixture(raw);eq(f.S.load(f.player),true);eq(f.data._session.jobId,'job-a')
raw._session.at=0/0;f=fixture(raw);eq(f.S.load(f.player),false);eq(f.writes,0)
-- Future version refusal at load AND merge prevents overwrites.
f=fixture({version=3,cash=999});eq(f.S.load(f.player),false);eq(f.writes,0);eq(f.data.cash,999)
f=fixture(nil);eq(f.S.load(f.player),true);f.data.version=3
local writes=f.writes;eq(f.S.save(f.player),false);eq(f.writes,writes);eq(f.data.version,3)
eq(f.S.save(f.player),false)
-- Lock replacement is detected on save.
f=fixture(nil);eq(f.S.load(f.player),true);f.data._session.token='other'
writes=f.writes;eq(f.S.save(f.player),false);eq(f.writes,writes)
-- Autosave tick starts exactly at interval and renews lock; close releases it.
f=fixture(nil);eq(f.S.load(f.player),true);writes=f.writes
f.now=1059;f.S.tick();eq(f.writes,writes)
f.now=1060;f.profile.cash=60;f.S.tick();eq(f.writes,writes+1);eq(f.data.cash,60);eq(f.data._session.at,1060)
eq(f.S.close(),true);eq(f.data._session,nil);writes=f.writes;f.now=2000;f.S.tick();eq(f.writes,writes)
-- Shutdown starts all saves before waiting, then drains concurrent work.
f=fixture(nil,{queued=true,onWait=function(state)
 local q=state.queue;state.queue={};for _,fn in ipairs(q)do fn()end
end})
eq(f.S.load(f.player),true)
local p2={UserId=1,active=true,Kick=function()end}
-- A shared user key refuses even a second load in the same server.
eq(f.S.load(p2),false);eq(f.S.close(),true);eq(#f.queue,0);eq(f.data._session,nil)
-- Time budget terminates waiting for hung parallel saves.
f=fixture(nil,{queued=true});eq(f.S.load(f.player),true);eq(f.S.close(),false)
eq(f.clock>=C.Saving.CloseBudgetSeconds,true);eq(#f.queue,1)
-- Save retries during shutdown respect the configured budget.
f=fixture(nil);eq(f.S.load(f.player),true);f.failures=3
eq(f.S.close(),true);eq(#f.warnings>0,true);eq(f.data._session~=nil,true)
-- Explicit Studio API-disabled mode runs ephemeral; generic failures still kick.
f=fixture(nil,{failures=10,error='StudioAccessToApisNotAllowed',studio=true})
eq(f.S.load(f.player),true);eq(f.writes,0);eq(#f.warnings,1);eq(f.S.save(f.player),true);eq(f.calls,1)
f.S.remove(f.player);eq(f.writes,0)
f=fixture(nil,{failures=3,error='unavailable',studio=true});eq(f.S.load(f.player),false);eq(f.writes,0)
-- Departure while load is in flight releases the claim without applying.
f=fixture(nil,{failures=1,onWait=function(state)state.player.active=false;state.S.remove(state.player)end})
eq(f.S.load(f.player),false);eq(f.data._session,nil);eq(f.profile,nil)
-- Corrupt top-level cash refuses the load and never writes.
f=fixture({version=2,cash=math.huge});eq(f.S.load(f.player),false);eq(f.writes,0)
-- Multiple players enqueue parallel close saves before the first wait.
local states, data, queued, pendingAtWait = {}, {}, {}, nil
local clock=0
local shared={}
function shared:UpdateAsync(k,fn)
 local output=fn(copy(data[k]));if output then data[k]=copy(output)end;return copy(output)
end
local deps={store=shared,jobId='parallel',now=function()return 1000 end,clock=function()return clock end,
 isActive=function()return true end,warn=function()end,
 spawn=function(fn)queued[#queued+1]=fn end,
 wait=function(delay)
  clock=clock+delay;pendingAtWait=#queued
  local work=queued;queued={};for _,fn in ipairs(work)do fn()end
 end,
 Profile={Init=function(p,state)states[p]=state end,get=function(p)return states[p]end,Remove=function()end},
 Wheel={Init=function()end,getState=function(p)return states[p].wheel end,Remove=function()end},
 Inventory={Init=function()end,getState=function(p)return states[p]end,Remove=function()end},
 Bases={Assign=function()end,Remove=function()end}}
local saving=Factory.new(C,L,deps)
for i=1,5 do
 local p={UserId=i,Kick=function()error('unexpected kick')end}
 eq(saving.load(p),true);states[p].cash=i*100
end
eq(saving.close(),true);eq(pendingAtWait,5)
for i=1,5 do eq(data['Player_'..i].cash,i*100);eq(data['Player_'..i]._session,nil)end
-- Failed saves keep stored progress/lock intact and never replace it with defaults.
f=fixture(nil);eq(f.S.load(f.player),true);f.profile.cash=900;f.failures=3
writes=f.writes;eq(f.S.save(f.player),false);eq(f.writes,writes);eq(f.data.cash,0)
f.failures=0;eq(f.S.save(f.player),true);eq(f.data.cash,900)
-- A missing module state refuses to write rather than silently replacing data.
f.inventory=nil;writes=f.writes;eq(f.S.save(f.player),false);eq(f.writes,writes)
-- v2 is the only writable store; absent v2 reads real v1 exactly once.
local legacy={cash=345,speed=2,inventory={{name='Diamond Sigma Frog',value=3.6,r=0.2,g=0.4,b=0.6,mat='Ice',count=2}}}
f=fixture(nil)
local reads,legacyReads=0,0
function f.deps.store:GetAsync(k)eq(k,'Player_1');reads=reads+1;return copy(f.data)end
f.deps.legacyStore={GetAsync=function(_,k)eq(k,'Player_1');legacyReads=legacyReads+1;return copy(legacy)end,
 UpdateAsync=function()error('v1 must never be written')end,SetAsync=function()error('v1 must never be written')end}
f.S=Factory.new(C,L,f.deps)
eq(f.S.load(f.player),true);eq(reads,1);eq(legacyReads,1);eq(f.profile.cash,345)
eq(#f.inventory.inventory,2);eq(f.inventory.inventory[1].mat,'Ice');eq(f.S.save(f.player),true)
eq(legacy.cash,345);eq(legacy.inventory[1].count,2)
f.S.remove(f.player)
f.player.active=true
f.S=Factory.new(C,L,f.deps);eq(f.S.load(f.player),true);eq(reads,2);eq(legacyReads,1)
-- v1 read failure must not claim/write an empty v2 save.
f=fixture(nil)
function f.deps.store:GetAsync()return nil end
local attempts=0
f.deps.legacyStore={GetAsync=function()attempts=attempts+1;error('legacy unavailable')end}
f.S=Factory.new(C,L,f.deps);eq(f.S.load(f.player),false);eq(attempts,3);eq(f.writes,0);eq(#f.events,0)
-- v2 appearing between the reads and the transform supersedes the legacy data.
f=fixture(nil)
function f.deps.store:GetAsync()return nil end
f.deps.legacyStore={GetAsync=function()
 local newer=L.default();newer.cash=999;f.data=L.serialize(newer);return copy(legacy)
end}
f.S=Factory.new(C,L,f.deps);eq(f.S.load(f.player),true);eq(f.profile.cash,999);eq(#f.inventory.inventory,0)
eq(C.Saving.StoreName,'BrainrotPlayerData_v2');eq(C.Saving.LegacyStoreName,'BrainrotPlayerData_v1');eq(C.Saving.KeyPrefix,'Player_')

print('PASS: '..checks..' saving fake-store/lifecycle checks')
