-- MCShop central server. Run on a Command Computer with wireless modem.
local P="mcshop"; local modem=peripheral.find("modem")
if not modem or not modem.isWireless() then error("Attach a wireless modem") end
rednet.open(peripheral.getName(modem))
local dbFile="mcshop_db"; local legacyFile="shop_accounts"; local catalogFile="shop_catalog"; local db={accounts={},pins={},sessions={},loans={}}; local adminSessions={}
local adminKey="change-me"
local DAILY_INTEREST=0.10; local LOAN_DAYS=7; local MAX_LOAN=5000
if fs.exists("shop_admin_key") then local f=fs.open("shop_admin_key","r"); adminKey=f.readAll():gsub("%s+$",""); f.close() end
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
if not db.loans then db.loans={} end
if fs.exists(catalogFile) then local f=fs.open(catalogFile,"r"); local loaded=textutils.unserialize(f.readAll()); f.close(); if type(loaded)=="table" and next(loaded) then catalog=loaded end end
local function saveCatalog() local f=fs.open(catalogFile,"w"); f.write(textutils.serialize(catalog)); f.close() end
local function account(n) db.accounts[n]=db.accounts[n] or {balance=1000,history={}}; return db.accounts[n] end
local function validName(n) return type(n)=="string" and n:match("^[A-Za-z0-9_]+$") and #n<=16 end
local function validItem(i) return type(i)=="string" and i:match("^[a-z0-9_.%-]+:[a-z0-9_./%-]+$") end
local function qty(q) q=tonumber(q); if not q then return nil end; q=math.floor(q); if q<1 or q>64 then return nil end; return q end
local function pin() return string.format("%06d",math.random(0,999999)) end
local function session(id) local s=db.sessions[id]; if s and s.expires>os.epoch("utc") then return s end; db.sessions[id]=nil end
local function log(n,a,i,q,m) local t={username=n,action=a,item=i,quantity=q,amount=m,time=os.epoch("utc")}; table.insert(account(n).history,t); save() end
local function onlinePlayers() local list={}; local ok,entities=pcall(commands.getEntities,"@a"); if ok and type(entities)=="table" then for _,e in ipairs(entities) do local n=e.displayName or e.name; if n then list[n]=true end end end; return list end
local function collectPayments() local day=os.day(); local online=onlinePlayers(); local changed=false; for n,l in pairs(db.loans) do if l.status=="active" and online[n] and l.lastPaidDay<day then local a=account(n); local interest=math.ceil(l.remaining*DAILY_INTEREST); local principal=math.min(l.dailyPrincipal,l.remaining); local due=interest+principal; l.lastDue=due; l.interestPaid=(l.interestPaid or 0)+interest; if a.balance>=due then a.balance=a.balance-due; l.remaining=l.remaining-principal; l.paidDays=l.paidDays+1; l.arrears=0; log(n,"loan_payment","loan",1,due) else l.arrears=(l.arrears or 0)+due end; l.lastPaidDay=day; if l.remaining<=0 then l.remaining=0; l.status="paid" end; changed=true end end; if changed then save() end end
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
 if r.action=="admin_login" then if tostring(r.key or "")~=adminKey then return {success=false,error="Invalid admin key"} end; adminSessions[id]=true; return {success=true} end
 if r.action=="admin_logout" then adminSessions[id]=nil; return {success=true} end
 if r.action=="admin_accounts" then if not adminSessions[id] then return {success=false,error="Admin login required"} end; local out={}; for n,a in pairs(db.accounts) do table.insert(out,{username=n,balance=a.balance or 0}) end; table.sort(out,function(a,b) return a.username<b.username end); return {success=true,accounts=out} end
 if r.action=="admin_loans" then if not adminSessions[id] then return {success=false,error="Admin login required"} end; local out={}; for n,l in pairs(db.loans) do table.insert(out,{username=n,principal=l.principal,remaining=l.remaining,arrears=l.arrears or 0,status=l.status,paidDays=l.paidDays}) end; table.sort(out,function(a,b) return a.username<b.username end); return {success=true,loans=out} end
 if r.action=="admin_balance" then if not adminSessions[id] then return {success=false,error="Admin login required"} end; if not validName(r.username) then return {success=false,error="Invalid username"} end; local amount=math.floor(tonumber(r.amount) or 0); local a=account(r.username); if r.mode=="add" then a.balance=(a.balance or 0)+amount else a.balance=amount end; save(); return {success=true,username=r.username,balance=a.balance} end
 if r.action=="admin_catalog" then if not adminSessions[id] then return {success=false,error="Admin login required"} end; local out={}; for i,v in pairs(catalog) do table.insert(out,{id=i,name=v.name or i,buy=v.buy or 0,sell=v.sell or 0}) end; table.sort(out,function(a,b) return a.id<b.id end); return {success=true,items=out} end
 if r.action=="admin_set_price" then if not adminSessions[id] then return {success=false,error="Admin login required"} end; if not catalog[r.item] then catalog[r.item]={name=r.item} end; catalog[r.item].buy=math.max(0,math.floor(tonumber(r.buy) or 0)); catalog[r.item].sell=math.max(0,math.floor(tonumber(r.sell) or 0)); saveCatalog(); return {success=true} end
 if r.action=="admin_import" then if not adminSessions[id] then return {success=false,error="Admin login required"} end; if not fs.exists("mcshop_import") then return {success=false,error="mcshop_import is missing"} end; local f=fs.open("mcshop_import","r"); local imported=textutils.unserialize(f.readAll()); f.close(); if type(imported)~="table" then return {success=false,error="Invalid import file"} end; local count=0; for i,v in pairs(imported) do if validItem(i) and type(v)=="table" then catalog[i]={name=v.name or i,buy=tonumber(v.buy) or 0,sell=tonumber(v.sell) or 0}; count=count+1 end end; saveCatalog(); return {success=true,count=count} end
 local s=session(id)
 if r.action=="catalog" then local out={}; for i,v in pairs(catalog) do table.insert(out,{id=i,name=v.name,buy=v.buy,sell=v.sell}) end; return {success=true,items=out} end
 if not s then return {success=false,error="Not logged in"} end
 local a=account(s.username)
 if r.action=="balance" then return {success=true,username=s.username,balance=a.balance} end
 if r.action=="transfer" then if not validName(r.target) then return {success=false,error="Invalid recipient"} end; if not db.accounts[r.target] then return {success=false,error="Recipient has no shop account"} end; local amount=math.floor(tonumber(r.amount) or 0); if amount<1 then return {success=false,error="Invalid amount"} end; if a.balance<amount then return {success=false,error="Insufficient funds"} end; local target=account(r.target); a.balance=a.balance-amount; target.balance=target.balance+amount; log(s.username,"transfer_sent",r.target,1,amount); log(r.target,"transfer_received",s.username,1,amount); save(); return {success=true,balance=a.balance} end
 if r.action=="loan_status" then local l=db.loans[s.username]; return {success=true,loan=l} end
 if r.action=="loan_request" then local amount=math.floor(tonumber(r.amount) or 0); if amount<1 or amount>MAX_LOAN then return {success=false,error="Loan must be between 1 and "..MAX_LOAN} end; local old=db.loans[s.username]; if old and old.status=="active" then return {success=false,error="You already have an active loan"} end; if old and (old.arrears or 0)>0 then return {success=false,error="Clear your arrears first"} end; local l={principal=amount,remaining=amount,dailyPrincipal=math.ceil(amount/LOAN_DAYS),interestRate=DAILY_INTEREST,termDays=LOAN_DAYS,paidDays=0,arrears=0,lastPaidDay=os.day(),status="active"}; db.loans[s.username]=l; a.balance=a.balance+amount; log(s.username,"loan_received","loan",1,amount); save(); return {success=true,balance=a.balance,loan=l} end
 if r.action=="history" then return {success=true,transactions=a.history or {}} end
 if r.action=="logout" then db.sessions[id]=nil; return {success=true} end
 if r.action=="buy" or r.action=="sell" then
  local i=validItem(r.item) and r.item; local q=qty(r.quantity); local v=i and catalog[i]
  if not v or not q then return {success=false,error="Invalid item or quantity"} end
  if r.action=="buy" then local total=v.buy*q; if a.balance<total then return {success=false,error="Insufficient funds"} end; local ok=commands.exec("give "..s.username.." "..i.." "..q); if not ok then return {success=false,error="Give command failed"} end; a.balance=a.balance-total; log(s.username,"buy",i,q,total); return {success=true,amount=total,balance=a.balance} end
  local checkOk,checkOutput,available=commands.exec("clear "..s.username.." "..i.." 0")
  if not checkOk then return {success=false,error="The inventory check failed"} end
  -- Some Minecraft versions return 1 here because one player entity was affected.
  -- The actual item count is reported in the command output, for example:
  -- "Found 6 matching items on xdLocutus".
  for _,line in ipairs(checkOutput or {}) do
   local found=line:match("[Ff]ound%s+(%d+)")
   if found then available=tonumber(found); break end
  end
  if not available or available<q then return {success=false,error="You do not have enough items (found "..tostring(available or 0)..")"} end
  local removeOk,removeOutput,removed=commands.exec("clear "..s.username.." "..i.." "..q)
  if not removeOk then return {success=false,error="Remove command failed"} end
  local total=v.sell*q; a.balance=a.balance+total; log(s.username,"sell",i,q,total); return {success=true,amount=total,balance=a.balance}
 end
 return {success=false,error="Unknown action"}
end
math.randomseed(os.epoch("utc")%2147483647)
print("MCShop server ready. Computer ID: "..os.getComputerID())
parallel.waitForAny(function() while true do local id,r=rednet.receive(P); rednet.send(id,handle(id,r),P) end end,function() while true do collectPayments(); sleep(5) end end)
