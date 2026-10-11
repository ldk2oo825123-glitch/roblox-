Color3={fromRGB=function(...) return {...} end}
local C=dofile('src/ReplicatedStorage/Config.lua')
local L=dofile('src/ReplicatedStorage/BrainrotLogic.lua').new(C)
local checks=0
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b));checks=checks+1 end
for i=1,5 do local low,high=L.band(i);eq(low,(i-1)*160);eq(high,i*160) end
for _,r in ipairs({{0,'Normal'},{0.804999,'Normal'},{0.805,'Gold'},{0.905,'Diamond'},{0.955001,'Emerald'},{0.985001,'Rainbow'},{0.999999,'Rainbow'}}) do eq(L.rollVariant(r[1]),r[2]) end
local pits={{MinX=-10,MaxX=10,MinZ=20,MaxZ=40}}
eq(L.overPit(0,30,pits),true);eq(L.overPit(10,40,pits),true);eq(L.overPit(11,30,pits),false)
local calls=0
local p=L.spawnPoint(1,pits,function(low,high) calls=calls+1;if calls<=2 then return calls==1 and 0 or 30 end;return (low+high)/2 end)
eq(p.Z,80);eq(calls,4);eq(L.overPit(p.X,p.Z,pits),false)
local full={{MinX=-100,MaxX=100,MinZ=0,MaxZ=800}}
eq(L.spawnPoint(3,full,function(a,b) return (a+b)/2 end),nil)
for i=1,5 do local low,high=L.band(i);local point=L.spawnPoint(i,{},function(a,b)return a end);eq(point.Z>low,true);eq(point.Z<high,true);eq(point.X>=-50,true) end
for _,v in ipairs({-1,1,math.huge,0/0})do eq(pcall(function() L.rollVariant(v) end),false) end
print('PASS: '..checks..' brainrot spawn checks')
