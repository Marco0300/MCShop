-- MCShop responsive clickable player GUI.
-- Requires an Advanced Computer and wireless modem.
local SERVER_ID=2
if fs.exists("shop_settings") then local f=fs.open("shop_settings","r"); SERVER_ID=tonumber(f.readAll()) or SERVER_ID; f.close() end
local PROTOCOL="mcshop"; local modem=peripheral.find("modem")
if not modem or not modem.isWireless() then error("Attach a wireless modem") end
if not term.isColor() then error("This GUI requires an Advanced Computer") end
rednet.open(peripheral.getName(modem))
local logged=false; local username=""; local balance=0; local items={}; local category="All"; local page=1; local categories={"All","Blocks","Resources","Tools","Food","Modded"}
local function request(t) rednet.send(SERVER_ID,t,PROTOCOL); local id,r=rednet.receive(PROTOCOL,10); return r or {success=false,error="Shop server did not respond"} end
local function clear() term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.clear(); term.setCursorPos(1,1) end
local function fit(s,n) s=tostring(s or ""); if #s>n then return s:sub(1,math.max(1,n-1)).."~" end; return s..string.rep(" ",n-#s) end
local function box(x,y,w,h,bg,fg,text) term.setBackgroundColor(bg); term.setTextColor(fg or colors.white); for r=0,h-1 do term.setCursorPos(x,y+r); term.write(string.rep(" ",w)) end; if text then term.setCursorPos(x+math.max(0,math.floor((w-#text)/2)),y+math.floor(h/2)); term.write(fit(text,w)) end; term.setBackgroundColor(colors.black) end
local function button(x,y,w,text,bg) if x<=W and y<=H then box(x,y,math.min(w,W-x+1),1,bg,colors.white,text) end end
local function layout()
 W,H=term.getSize(); local cols=math.max(1,math.min(4,math.floor((W-2)/12))); local gap=1; local tileW=math.floor((W-2-gap*(cols-1))/cols); local rows=math.max(1,math.floor((H-8)/4)); return cols,tileW,rows
end
local function categoryFor(id) local n=id:lower(); if n:find("_sword") or n:find("_pickaxe") or n:find("_axe") or n:find("_shovel") or n:find("_hoe") or n:find("_helmet") or n:find("_chestplate") or n:find("_leggings") or n:find("_boots") then return "Tools" end; if n:find("_block") or n:find("stone") or n:find("_planks") or n:find("_log") or n:find("_ore") or n:find("obsidian") then return "Blocks" end; if n:find("bread") or n:find("apple") or n:find("carrot") or n:find("potato") or n:find("food") then return "Food" end; if not n:find("minecraft:") then return "Modded" end; return "Resources" end
local function visible() local out={}; for _,v in ipairs(items) do if category=="All" or categoryFor(v.id)==category then table.insert(out,v) end end; return out end
local function loadItems() local r=request({action="catalog"}); if r.success then items=r.items; return true end; return false end
local function waitKey() term.setCursorPos(1,H); term.setTextColor(colors.lightGray); term.write("Press Enter"); read() end
local function login()
 clear(); term.setTextColor(colors.yellow); term.write("MCShop Login"); term.setTextColor(colors.white); term.setCursorPos(2,4); term.write("Minecraft username: "); local n=read(); local r=request({action="request_pin",username=n}); term.setCursorPos(2,6); term.write(fit(r.message or r.error or "No response",W-2)); if r.success then term.setCursorPos(2,8); term.write("Check your private whisper."); term.setCursorPos(2,9); term.write("PIN: "); local p=read(); r=request({action="verify_pin",username=n,pin=p}); term.setCursorPos(2,11); term.write(fit(r.error or "Login successful",W-2)); if r.success then logged=true; username=r.username; balance=r.balance end end; waitKey()
end
local function history()
 clear(); term.setTextColor(colors.yellow); term.write("Transaction History"); term.setTextColor(colors.white); local r=request({action="history"}); local y=3; if not r.success then term.setCursorPos(2,y); term.write(fit(r.error,W-2)) elseif #r.transactions==0 then term.setCursorPos(2,y); term.write("No transactions yet") else for i=math.max(1,#r.transactions-12),#r.transactions do local t=r.transactions[i]; term.setCursorPos(2,y); term.write(fit(t.action.." "..t.quantity.."x "..t.item.."  "..t.amount,W-2)); y=y+1; if y>=H-1 then break end end end; waitKey()
end
local function detail(item)
 clear(); box(1,1,W,2,colors.gray,colors.yellow,fit(item.name,W)); term.setTextColor(colors.white); term.setCursorPos(2,4); term.write(fit(item.id,W-3)); term.setCursorPos(2,6); term.write("Buy:  "..item.buy.." credits"); term.setCursorPos(2,7); term.write("Sell: "..item.sell.." credits"); local bw=math.max(8,math.floor((W-6)/3)); local x=2; button(x,10,bw,"BUY",colors.green); x=x+bw+1; button(x,10,bw,"SELL",colors.orange); x=x+bw+1; button(x,10,bw,"BACK",colors.blue); while true do local e,b,px,py=os.pullEvent("mouse_click"); if py==10 then if px>=x and px<x+bw then return end; local action=(px>=2 and px<2+bw) and "buy" or ((px>=2+bw+1 and px<2+2*bw+1) and "sell" or nil); if action then term.setCursorPos(2,13); term.setTextColor(colors.white); term.write("Quantity: "); local q=tonumber(read()); local r=request({action=action,item=item.id,quantity=q}); term.setCursorPos(2,15); term.write(fit(r.error or (action.." successful"),W-3)); if r.success then balance=r.balance; term.setCursorPos(2,16); term.write(fit("Amount: "..r.amount.."  Balance: "..balance,W-3)) end; term.setCursorPos(2,H); term.setTextColor(colors.lightGray); term.write("Click BUY, SELL, or BACK") end end end
end
local function draw()
 clear(); W,H=term.getSize(); box(1,1,W,2,colors.gray,colors.yellow,"MCShop"); term.setTextColor(colors.white); local userText=logged and username or "Not logged in"; term.setCursorPos(math.max(1,W-#userText-10),1); term.write(fit(userText,math.max(1, W-#userText-10))); term.setCursorPos(math.max(1,W-9),1); term.write("$"..balance)
 local tx=1; for _,c in ipairs(categories) do local cw=#c+2; if tx+cw<=W-9 then button(tx,3,cw,c,c==category and colors.orange or colors.blue); tx=tx+cw+1 end end; button(W-8,3,8,"LOGIN",colors.green); button(W-8,4,8,"HISTORY",colors.purple)
 local shown=visible(); local cols,tileW,rows=layout(); local maxPage=math.max(1,math.ceil(#shown/(cols*rows))); page=math.min(page,maxPage); local first=(page-1)*cols*rows+1; for r=0,rows-1 do for c=0,cols-1 do local item=shown[first+r*cols+c]; if item then local bx=1+c*(tileW+1); local by=6+r*4; box(bx,by,tileW,3,colors.lightBlue,colors.black,fit(item.name,tileW)); term.setBackgroundColor(colors.black); term.setTextColor(colors.gray); term.setCursorPos(bx,by+3); term.write(fit("$"..item.buy.." / $"..item.sell,tileW)) end end end
 local navY=H-2; button(2,navY,8,"PREV",colors.blue); button(12,navY,8,"NEXT",colors.blue); term.setTextColor(colors.lightGray); term.setCursorPos(math.min(22,W-#("Page "..page.."/"..maxPage)+1),navY); term.write("Page "..page.."/"..maxPage); term.setCursorPos(2,H); term.write("Hover for full name; click an item")
end
if not loadItems() then error("Could not load shop catalog") end
while true do
 draw(); local e,b,x,y=os.pullEvent()
 if e=="mouse_move" then local shown=visible(); local cols,tileW,rows=layout(); local first=(page-1)*cols*rows+1; for r=0,rows-1 do for c=0,cols-1 do local bx=1+c*(tileW+1); local by=6+r*4; local item=shown[first+r*cols+c]; if item and x>=bx and x<bx+tileW and y>=by and y<by+3 then term.setCursorPos(2,H); term.setTextColor(colors.yellow); term.write(fit(item.name,W-1)) end end end
 elseif e=="mouse_click" then
  if y==3 and x>=W-8 then login()
  elseif y==4 and x>=W-8 then history()
  elseif y==3 then local tx=1; for _,c in ipairs(categories) do local cw=#c+2; if tx+cw<=W-9 then if x>=tx and x<tx+cw then category=c; page=1 end; tx=tx+cw+1 end end
  else local shown=visible(); local cols,tileW,rows=layout(); local first=(page-1)*cols*rows+1; local r=math.floor((y-6)/4); local c=math.floor((x-1)/(tileW+1)); if y>=6 and r>=0 and r<rows and c>=0 and c<cols then local item=shown[first+r*cols+c]; if item then detail(item) end end; if y==H-2 and x>=2 and x<10 then page=math.max(1,page-1) elseif y==H-2 and x>=12 and x<20 then page=page+1 end end
 end
end
