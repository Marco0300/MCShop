-- MCShop creative-style player GUI.
-- Requires an Advanced Computer and wireless modem.
local SERVER_ID=2
if fs.exists("shop_settings") then local f=fs.open("shop_settings","r"); SERVER_ID=tonumber(f.readAll()) or SERVER_ID; f.close() end
local PROTOCOL="mcshop"; local modem=peripheral.find("modem")
if not modem or not modem.isWireless() then error("Attach a wireless modem") end
if not term.isColor() then error("This GUI requires an Advanced Computer") end
rednet.open(peripheral.getName(modem))
local W,H=term.getSize(); local logged=false; local username=""; local balance=0; local items={}; local category="All"; local selected=nil; local page=1; local perPage=8
local categories={"All","Blocks","Resources","Tools","Food","Modded"}
local function request(t) rednet.send(SERVER_ID,t,PROTOCOL); local id,r=rednet.receive(PROTOCOL,10); return r or {success=false,error="Shop server did not respond"} end
local function clear(bg) term.setBackgroundColor(bg or colors.black); term.setTextColor(colors.white); term.clear(); term.setCursorPos(1,1) end
local function fill(x,y,w,h,bg,fg,text) term.setBackgroundColor(bg); term.setTextColor(fg or colors.white); for i=0,h-1 do term.setCursorPos(x,y+i); term.write(string.rep(" ",w)) end; if text then term.setCursorPos(x+math.max(0,math.floor((w-#text)/2)),y+math.floor(h/2)); term.write(text) end; term.setBackgroundColor(colors.black) end
local function button(x,y,w,label,bg) fill(x,y,w,1,bg,colors.white,label) end
local function categoryFor(id)
 local n=id:lower(); if n:find("_sword") or n:find("_pickaxe") or n:find("_axe") or n:find("_shovel") or n:find("_hoe") or n:find("_helmet") or n:find("_chestplate") or n:find("_leggings") or n:find("_boots") then return "Tools" end
 if n:find("_block") or n:find("stone") or n:find("_planks") or n:find("_log") or n:find("_ore") or n:find("obsidian") then return "Blocks" end
 if n:find("bread") or n:find("apple") or n:find("carrot") or n:find("potato") or n:find("food") then return "Food" end
 if not n:find("minecraft:") then return "Modded" end
 return "Resources"
end
local function visibleItems()
 local out={}; for _,v in ipairs(items) do if category=="All" or categoryFor(v.id)==category then table.insert(out,v) end end; return out
end
local function loadItems() local r=request({action="catalog"}); if r.success then items=r.items; return true end; return false end
local function pause() term.setCursorPos(1,H); term.setTextColor(colors.lightGray); term.write("Press Enter to continue"); read() end
local function login()
 clear(colors.black); term.setTextColor(colors.yellow); term.write("MCShop Login"); term.setTextColor(colors.white); term.setCursorPos(2,4); term.write("Minecraft username: "); local n=read(); local r=request({action="request_pin",username=n}); term.setCursorPos(2,6); term.write(r.message or r.error or "No response")
 if r.success then term.setCursorPos(2,8); term.write("Check your private whisper."); term.setCursorPos(2,9); term.write("PIN: "); local p=read(); r=request({action="verify_pin",username=n,pin=p}); term.setCursorPos(2,11); term.write(r.error or "Login successful"); if r.success then logged=true; username=r.username; balance=r.balance end end; pause()
end
local function history()
 clear(); term.setTextColor(colors.yellow); term.write("Transaction History"); term.setTextColor(colors.white); local r=request({action="history"}); local y=3
 if not r.success then term.setCursorPos(2,y); term.write(r.error or "Error") elseif #r.transactions==0 then term.setCursorPos(2,y); term.write("No transactions yet") else for i=math.max(1,#r.transactions-12),#r.transactions do local t=r.transactions[i]; term.setCursorPos(2,y); term.write(t.action.." "..t.quantity.."x "..t.item.."  "..t.amount); y=y+1 end end; pause()
end
local function detail(item)
 clear(); fill(1,1,W,2,colors.gray,colors.yellow,item.name); term.setTextColor(colors.white); term.setCursorPos(3,4); term.write(item.id); term.setCursorPos(3,6); term.write("Buy price:  "..item.buy.." credits"); term.setCursorPos(3,7); term.write("Sell price: "..item.sell.." credits"); button(3,10,12,"BUY",colors.green); button(18,10,12,"SELL",colors.orange); button(33,10,12,"BACK",colors.blue); term.setCursorPos(3,13); term.setTextColor(colors.lightGray); term.write("Click an action, then enter a quantity.")
 while true do
  local e,b,x,y=os.pullEvent("mouse_click")
  if y==10 and x>=33 and x<48 then return end
  if y==10 and x>=3 and x<15 or y==10 and x>=18 and x<30 then
   local action=(x<15) and "buy" or "sell"; term.setCursorPos(3,13); term.setTextColor(colors.white); term.write("Quantity (1-64): "); local q=tonumber(read()); local r=request({action=action,item=item.id,quantity=q}); term.setCursorPos(3,15); term.write(r.error or (action.." successful")); if r.success then balance=r.balance; term.setCursorPos(3,16); term.write("Amount: "..r.amount.."  Balance: "..balance) end; term.setCursorPos(3,18); term.setTextColor(colors.lightGray); term.write("Click BUY, SELL, or BACK")
  end
 end
end
local function draw()
 clear(colors.black); fill(1,1,W,2,colors.gray,colors.yellow,"MCShop"); term.setTextColor(colors.white); term.setCursorPos(19,1); term.write(logged and username or "Not logged in"); term.setCursorPos(40,1); term.write("$"..balance)
 local x=1; for _,c in ipairs(categories) do local active=c==category; button(x,3,math.max(7,#c+2),c,active and colors.orange or colors.blue); x=x+math.max(7,#c+2)+1 end
 button(W-9,3,8,"LOGIN",colors.green); button(W-9,4,8,"HISTORY",colors.purple)
 local shown=visibleItems(); local maxPage=math.max(1,math.ceil(#shown/perPage)); if page>maxPage then page=maxPage end; local first=(page-1)*perPage+1; local y=6
 for row=0,1 do for col=0,3 do local index=first+row*4+col; local item=shown[index]; if item then local bx=2+col*13; local by=y+row*5; local icon=item.name:sub(1,2):upper(); fill(bx,by,10,3,colors.lightBlue,colors.black,icon); term.setBackgroundColor(colors.black); term.setTextColor(colors.white) end end end
 button(2,17,9,"PREV",colors.blue); button(13,17,9,"NEXT",colors.blue); term.setTextColor(colors.lightGray); term.setCursorPos(25,17); term.write("Page "..page.."/"..maxPage); term.setCursorPos(2,19); term.write("Hover over an item for its name")
end
if not loadItems() then error("Could not load shop catalog") end
while true do
 draw(); local e,b,x,y=os.pullEvent()
 if e=="mouse_move" then local shown=visibleItems(); local first=(page-1)*perPage+1; for row=0,1 do for col=0,3 do local bx=2+col*13; local by=6+row*5; if x>=bx and x<bx+10 and y>=by and y<by+3 and shown[first+row*4+col] then term.setCursorPos(2,19); term.setTextColor(colors.yellow); term.write((shown[first+row*4+col].name..string.rep(" ",W)):sub(1,W-1)) end end end
 elseif e=="mouse_click" then
  if y==3 and x>=W-9 then login()
  elseif y==4 and x>=W-9 then history()
  elseif y==3 then local px=1; for _,c in ipairs(categories) do local pw=math.max(7,#c+2); if x>=px and x<px+pw then category=c; page=1 end; px=px+pw+1 end
  elseif y==17 and x>=2 and x<11 then page=math.max(1,page-1)
  elseif y==17 and x>=13 and x<22 then page=page+1
  elseif y>=6 and y<16 then local row=math.floor((y-6)/5); local col=math.floor((x-2)/13); if col>=0 and col<4 and x>=2+col*13 and x<12+col*13 then local shown=visibleItems(); local item=shown[(page-1)*perPage+row*4+col+1]; if item then detail(item) end end end
 end
end
