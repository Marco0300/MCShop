-- MCShop web relay. Run on the central Command Computer.
-- Change BRIDGE to the Ubuntu VM LAN address.
local BRIDGE="http://192.168.3.108:8091"; local SERVER_ID=2; local PROTOCOL="mcshop"; local modem=peripheral.find("modem")
if not modem or not modem.isWireless() then error("Attach a wireless modem") end
rednet.open(peripheral.getName(modem))
while true do
 local h,e=http.get(BRIDGE.."/api/poll")
 if h then
  local job=textutils.unserializeJSON(h.readAll()); h.close()
  if job and job.id and job.request then
   local target=job.request.clientKey or ("web:"..job.id)
   local response
   local ok,err=pcall(function() response=({success=true}) end)
   -- The server uses the relay computer's ID for rednet; clientKey is used by the patched server.
   rednet.send(SERVER_ID,job.request,PROTOCOL)
   local _,r=rednet.receive(PROTOCOL,10)
   response=r or {success=false,error="MCShop server did not respond"}
   response.clientKey=nil
   local payload=textutils.serializeJSON({id=job.id,response=response})
   local rh,re=http.post(BRIDGE.."/api/respond",payload,{['Content-Type']='application/json'})
   if rh then rh.close() else print("Bridge response failed: "..tostring(re)) end
  end
 else print("Bridge poll failed: "..tostring(e)); sleep(2) end
 sleep(0.2)
end
