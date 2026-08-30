-- MCShop clickable player GUI. Requires a wireless modem.
local SERVER_ID=2
if fs.exists("shop_settings") then local f=fs.open("shop_settings","r"); SERVER_ID=tonumber(f.readAll()) or SERVER_ID; f.close() end
local PROTOCOL="mcshop"; local modem=peripheral.find("modem")
if not modem or not modem.isWireless() then error("Attach a wireless modem") end
rednet.open(peripheral.getName(modem))
local logged=false; local username=""; local balance=0; local items={}; local page=1; local perPage=8
local function request(t) rednet.send(SERVER_ID,t,PROTOCOL); local id,r=rednet.receive(PROTOCOL,10); return r or {success=false,error="Shop server did not respond"} end
local function clear() term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.clear(); term.setCursorPos(1,1) end
local function button(x,y,w,label,bg) term.setBackgroundColor(bg or colors.blue); term.setCursorPos(x,y); term.write(string.rep(" ",w)); term.setCursorPos(x+math.floor((w-#label)/2),y); term.write(label); term.setBackgroundColor(colors.black) end
local function pause() term.setCursorPos(1,18); term.setTextColor(colors.lightGray); term.write("Press Enter to continue"); read() end
local function loadCatalog() local r=request({action="catalog"}); if r.success then items=r.items; return true end; return false end
local function login()
 clear(); term.setTextColor(colors.yellow); term.write("MCShop Login"); term.setTextColor(colors.white); term.setCursorPos(1,3); term.write("Minecraft username: "); local n=read()
 local r=request({action="request_pin",username=n}); term.setCursorPos(1,5); term.write(r.message or r.error or "No response")
 if not r.success then pause(); return end
 term.setCursorPos(1,7); term.write("Check your private whisper."); term.setCursorPos(1,8); term.write("PIN: "); local p=read(); r=request({action="verify_pin",username=n,pin=p})
 if r.success then logged=true; username=r.username; balance=r.balance else term.setCursorPos(1,10); term.write(r.error or "Login failed") end; pause()
end
local function showHistory()
 clear(); term.setTextColor(colors.yellow); term.write("Transaction History"); term.setTextColor(colors.white); local r=request({action="history"}); local y=3
 if not r.success then term.setCursorPos(1,y); term.write(r.error) else if #r.transactions==0 then term.setCursorPos(1,y); term.write("No transactions yet") else for i=math.max(1,#r.transactions-12),#r.transactions do local t=r.transactions[i]; term.setCursorPos(1,y); term.write(t.action.." "..t.quantity.."x "..t.item.."  "..t.amount); y=y+1 end end end; pause()
end
local function trade(action,index)
 if not logged then login(); return end
 local item=items[index]; if not item then return end
 clear(); term.write((action=="buy" and "Buy " or "Sell ")..item.name); term.setCursorPos(1,3); term.write("Quantity (1-64): "); local q=tonumber(read()); local r=request({action=action,item=item.id,quantity=q}); term.setCursorPos(1,5); term.write(r.message or r.error or "No response"); if r.success then balance=r.balance; term.setCursorPos(1,7); term.write("Amount: "..r.amount.."  Balance: "..balance) end; pause()
end
local function draw()
 clear(); term.setBackgroundColor(colors.gray); term.setTextColor(colors.white); term.setCursorPos(1,1); term.write(string.rep(" ",51)); term.setCursorPos(3,1); term.setTextColor(colors.yellow); term.write("MCShop")
 term.setTextColor(colors.white); term.setCursorPos(20,1); term.write(logged and username or "Not logged in"); term.setCursorPos(39,1); term.write("$"..tostring(balance)); term.setBackgroundColor(colors.black)
 button(2,3,10,"LOGIN",colors.blue); button(14,3,10,"HISTORY",colors.purple); button(26,3,10,"LOGOUT",colors.red); button(39,3,10,"REFRESH",colors.green)
 if #items==0 then loadCatalog() end
 local first=(page-1)*perPage+1; local last=math.min(#items,first+perPage-1); local y=5
 for i=first,last do local v=items[i]; term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.setCursorPos(2,y); term.write(string.format("%-22s Buy:%-5d Sell:%-5d",v.name,v.buy,v.sell)); button(39,y,5,"BUY",colors.green); button(45,y,5,"SELL",colors.orange); y=y+1 end
 button(2,16,10,"PREV",colors.blue); button(14,16,10,"NEXT",colors.blue); term.setBackgroundColor(colors.black); term.setTextColor(colors.lightGray); term.setCursorPos(28,16); term.write("Page "..page.."/"..math.max(1,math.ceil(#items/perPage)))
end
while true do
 draw(); local e,b,x,y=os.pullEvent("mouse_click")
 if y==3 and x>=2 and x<=11 then login()
 elseif y==3 and x>=14 and x<=23 then showHistory()
 elseif y==3 and x>=26 and x<=35 then request({action="logout"}); logged=false; username=""; balance=0
 elseif y==3 and x>=39 and x<=48 then items={}; loadCatalog()
 elseif y==16 and x>=2 and x<=11 then page=math.max(1,page-1)
 elseif y==16 and x>=14 and x<=23 then page=math.min(math.max(1,math.ceil(#items/perPage)),page+1)
 elseif y>=5 and y<13 then local idx=(page-1)*perPage+(y-5+1); if x>=39 and x<=43 then trade("buy",idx) elseif x>=45 and x<=50 then trade("sell",idx) end end
end
