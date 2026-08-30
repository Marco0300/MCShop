-- MCShop player terminal. Set SERVER_ID to the Command Computer ID.
local SERVER_ID=2
if fs.exists("shop_settings") then
  local f=fs.open("shop_settings","r"); SERVER_ID=tonumber(f.readAll()) or SERVER_ID; f.close()
end
local P="mcshop"; local modem=peripheral.find("modem")
if not modem or not modem.isWireless() then error("Attach a wireless modem") end
rednet.open(peripheral.getName(modem))
local logged=false; local username=nil; local balance=0
local function req(t) rednet.send(SERVER_ID,t,P); local id,r=rednet.receive(P,10); return r or {success=false,error="Shop server did not respond"} end
local function pause() print("Press Enter"); read() end
local function login()
 term.clear(); term.setCursorPos(1,1); print("MCShop login"); write("Minecraft username: "); local n=read()
 local r=req({action="request_pin",username=n}); print(r.message or r.error); if not r.success then pause(); return end
 write("Enter the PIN whispered to you: "); local p=read(); r=req({action="verify_pin",username=n,pin=p}); print(r.error or "Login successful")
 if r.success then logged=true; username=r.username; balance=r.balance; print("Balance: "..balance) end; pause()
end
local function catalog()
 local r=req({action="catalog"}); if not r.success then print(r.error); pause(); return nil end; return r.items
end
local function trade(action)
 if not logged then print("Log in first"); pause(); return end
 local items=catalog(); if not items then return end
 for k,v in ipairs(items) do print(k..". "..v.name.." | buy "..v.buy.." | sell "..v.sell) end
 write("Item number (0 cancels): "); local k=tonumber(read()); if not k or k==0 or not items[k] then return end
 write("Quantity 1-64: "); local q=tonumber(read()); local r=req({action=action,item=items[k].id,quantity=q}); print(r.error or (action.." successful")); if r.success then balance=r.balance; print("Amount: "..r.amount.."  Balance: "..balance) end; pause()
end
while true do
 term.clear(); term.setCursorPos(1,1); print("========== MCShop =========="); print(logged and (username.." | balance "..balance) or "Not logged in"); print("1. Login"); print("2. Buy"); print("3. Sell"); print("4. Balance"); print("5. Logout"); print("0. Exit"); write("> "); local c=read()
 if c=="1" then login() elseif c=="2" then trade("buy") elseif c=="3" then trade("sell") elseif c=="4" then local r=req({action="balance"}); print(r.error or ("Balance: "..r.balance)); pause() elseif c=="5" then req({action="logout"}); logged=false; username=nil; balance=0 elseif c=="0" then break end
end
