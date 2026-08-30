-- MCShop central server. Run on a Command Computer with wireless modem.
local P="mcshop"; local modem=peripheral.find("modem")
if not modem or not modem.isWireless() then error("Attach a wireless modem") end
rednet.open(peripheral.getName(modem))
local dbFile="mcshop_db"; local legacyFile="shop_accounts"; local db={accounts={},pins={},sessions={}}
local catalog={
 ["minecraft:coal"]={name="Coal",buy=5,sell=3},
 ["minecraft:iron_ingot"]={name="Iron Ingot",buy=15,sell=10},
 ["minecraft:gold_ingot"]={name="Gold Ingot",buy=30,sell=20},
 ["minecraft:copper_ingot"]={name="Copper Ingot",buy=10,sell=7},
 ["minecraft:redstone"]={name="Redstone",buy=8,sell=5},
 ["minecraft:diamond"]={name="Diamond",buy=100,sell=70},
 ["minecraft:emerald"]={name="Emerald",buy=80,sell=55},
 ["minecraft:obsidian"]={name="Obsidian",buy=20,sell=14}
}
local function save()
 local data=textutils.serialize(db)
 local f=fs.open(dbFile,"w"); f.write(data); f.close()
 -- Keep the original filename updated too for backwards compatibility.
 local old=fs.open(legacyFile,"w"); old.write(data); old.close()
end
local function loadFile(name)
 if not fs.exists(name) then return nil end
 local f=fs.open(name,"r"); local value=textutils.unserialize(f.readAll()); f.close()
 return type(value)=="table" and value or nil
end
-- Prefer the legacy file when it contains existing accounts, otherwise use the new file.
local oldData=loadFile(legacyFile)
local newData=loadFile(dbFile)
if oldData and oldData.accounts and next(oldData.accounts) then db=oldData
elseif newData then db=newData end
if not db.accounts then db.accounts={} end
if not db.pins then db.pins={} end
if not db.sessions then db.sessions={} end
local function account(n) db.accounts[n]=db.accounts[n] or {balance=1000,history={}}; return db.accounts[n] end
local function validName(n) return type(n)=="string" and n:match("^[A-Za-z0-9_]+$") and #n<=16 end
local function validItem(i) return type(i)=="string" and i:match("^[a-z0-9_.%-]+:[a-z0-9_./%-]+$") end
local function qty(q) q=tonumber(q); if not q then return nil end; q=math.floor(q); if q<1 or q>64 then return nil end; return q end
local function pin() return string.format("%06d",math.random(0,999999)) end
local function session(id) local s=db.sessions[id]; if s and s.expires>os.epoch("utc") then return s end; db.sessions[id]=nil end
local function log(n,a,i,q,m) local t={username=n,action=a,item=i,quantity=q,amount=m,time=os.epoch("utc")}; table.insert(account(n).history,t); save() end
local function handle(id,r)
 if type(r)~="table" then return {success=false,error="Invalid request"} end
 if r.action=="request_pin" then
  if not validName(r.username) then return {success=false,error="Invalid username"} end
  local p=pin(); db.pins[r.username]={value=p,expires=os.epoch("utc")+120000};
  local ok=commands.exec("tell "..r.username.." Your one-time MCShop PIN is "..p..". It expires in 2 minutes")
  if not ok then return {success=false,error="Could not whisper PIN"} end
  return {success=true,message="PIN sent by private message"}
 end
 if r.action=="verify_pin" then
  local p=db.pins[r.username]; if not p then return {success=false,error="Request a new PIN"} end
  if p.expires<os.epoch("utc") then db.pins[r.username]=nil; return {success=false,error="PIN expired"} end
  if p.value~=tostring(r.pin or "") then return {success=false,error="Incorrect PIN"} end
  db.pins[r.username]=nil; local a=account(r.username); db.sessions[id]={username=r.username,expires=os.epoch("utc")+900000}; save(); return {success=true,username=r.username,balance=a.balance}
 end
 local s=session(id); if not s then return {success=false,error="Not logged in"} end
 local a=account(s.username)
 if r.action=="catalog" then local out={}; for i,v in pairs(catalog) do table.insert(out,{id=i,name=v.name,buy=v.buy,sell=v.sell}) end; return {success=true,items=out} end
 if r.action=="balance" then return {success=true,username=s.username,balance=a.balance} end
 if r.action=="logout" then db.sessions[id]=nil; return {success=true} end
 if r.action=="buy" or r.action=="sell" then
  local i=validItem(r.item) and r.item; local q=qty(r.quantity); local v=i and catalog[i]
  if not v or not q then return {success=false,error="Invalid item or quantity"} end
  if r.action=="buy" then local total=v.buy*q; if a.balance<total then return {success=false,error="Insufficient funds"} end; local ok=commands.exec("give "..s.username.." "..i.." "..q); if not ok then return {success=false,error="Give command failed"} end; a.balance=a.balance-total; log(s.username,"buy",i,q,total); return {success=true,amount=total,balance=a.balance} end
  local ok,output,available=commands.exec("clear "..s.username.." "..i.." 0"); if not ok or not available or available<q then return {success=false,error="You do not have enough items"} end
  local removed=commands.exec("clear "..s.username.." "..i.." "..q); if not removed then return {success=false,error="Remove command failed"} end
  local total=v.sell*q; a.balance=a.balance+total; log(s.username,"sell",i,q,total); return {success=true,amount=total,balance=a.balance}
 end
 return {success=false,error="Unknown action"}
end
math.randomseed(os.epoch("utc")%2147483647)
print("MCShop server ready. Computer ID: "..os.getComputerID())
while true do local id,r=rednet.receive(P); rednet.send(id,handle(id,r),P) end
