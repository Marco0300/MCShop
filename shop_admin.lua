-- MCShop admin GUI. Run on a separate Advanced Computer with wireless modem.
local SERVER_ID=2
if fs.exists("shop_settings") then local f=fs.open("shop_settings","r"); SERVER_ID=tonumber(f.readAll()) or SERVER_ID; f.close() end
local P="mcshop"; local modem=peripheral.find("modem")
if not modem or not modem.isWireless() then error("Attach a wireless modem") end
if not term.isColor() then error("Use an Advanced Computer") end
rednet.open(peripheral.getName(modem)); local W,H=term.getSize(); local authed=false; local items={}; local page=1
local function req(t) rednet.send(SERVER_ID,t,P); local _,r=rednet.receive(P,10); return r or {success=false,error="Server did not respond"} end
local function cls() term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.clear(); term.setCursorPos(1,1) end
local function fit(s,n) s=tostring(s or ""); return #s>n and s:sub(1,n-1).."~" or s..string.rep(" ",n-#s) end
local function btn(x,y,w,s,c) term.setBackgroundColor(c); term.setTextColor(colors.white); term.setCursorPos(x,y); term.write(fit(s,w)); term.setBackgroundColor(colors.black) end
local function pause() term.setCursorPos(1,H); term.setTextColor(colors.lightGray); term.write("Press Enter"); read() end
local function login() cls(); term.setTextColor(colors.yellow); term.write("MCShop Admin Login"); term.setTextColor(colors.white); term.setCursorPos(2,4); term.write("Admin key: "); local key=read(); local r=req({action="admin_login",key=key}); term.setCursorPos(2,6); term.write(r.error or "Admin login successful"); if r.success then authed=true end; pause() end
local function refresh() local r=req({action="admin_catalog"}); if r.success then items=r.items end end
local function edit(item) cls(); term.setTextColor(colors.yellow); term.write("Edit: "..item.name); term.setTextColor(colors.white); term.setCursorPos(2,4); term.write("Buy price: "); local buy=tonumber(read()); term.setCursorPos(2,6); term.write("Sell price: "); local sell=tonumber(read()); local r=req({action="admin_set_price",item=item.id,buy=buy,sell=sell}); term.setCursorPos(2,8); term.write(r.error or "Saved"); pause(); refresh() end
local function draw() cls(); term.setBackgroundColor(colors.gray); term.setCursorPos(1,1); term.write(string.rep(" ",W)); term.setCursorPos(2,1); term.setTextColor(colors.yellow); term.write("MCShop ADMIN"); term.setTextColor(colors.white); term.setBackgroundColor(colors.black); btn(2,3,12,"REFRESH",colors.green); btn(16,3,12,"IMPORT",colors.orange); btn(30,3,12,"LOGOUT",colors.red); local first=(page-1)*8+1; for r=0,math.min(7,#items-first) do local v=items[first+r]; local y=5+r; term.setCursorPos(2,y); term.write(fit(v.name,22).." Buy:"..fit(v.buy,6).." Sell:"..fit(v.sell,6)); btn(W-8,y,8,"EDIT",colors.blue) end; btn(2,H-1,8,"PREV",colors.blue); btn(12,H-1,8,"NEXT",colors.blue); term.setCursorPos(25,H-1); term.write("Page "..page.."/"..math.max(1,math.ceil(#items/8))) end
while true do
 if not authed then login() else refresh(); while authed do draw(); local e,b,x,y=os.pullEvent("mouse_click"); if y==3 and x>=2 and x<14 then refresh() elseif y==3 and x>=16 and x<28 then local r=req({action="admin_import"}); cls(); term.write(r.error or ("Imported "..tostring(r.count).." items")); pause(); refresh() elseif y==3 and x>=30 and x<42 then req({action="admin_logout"}); authed=false elseif y==H-1 and x>=2 and x<10 then page=math.max(1,page-1) elseif y==H-1 and x>=12 and x<20 then page=page+1 elseif y>=5 and y<13 and x>=W-8 then local item=items[(page-1)*8+y-5+1]; if item then edit(item) end end end end
end
