-- MCShop updater. Run on a ComputerCraft computer.
-- Downloads the latest shop files from GitHub.

local BASE = "https://raw.githubusercontent.com/Marco0300/MCShop/main/"
local FILES = { "shop_server.lua", "shop_client.lua" }

local function download(name)
  local response, err = http.get(BASE .. name)
  if not response then
    return false, err or "HTTP request failed"
  end
  local data = response.readAll()
  response.close()
  if not data or #data < 50 then
    return false, "Downloaded file is unexpectedly small"
  end
  local temp = name .. ".new"
  local file = fs.open(temp, "w")
  file.write(data)
  file.close()
  if fs.exists(name) then fs.delete(name) end
  fs.move(temp, name)
  return true
end

print("Checking MCShop updates...")
for _, name in ipairs(FILES) do
  local ok, err = download(name)
  if ok then print(name .. " updated") else print(name .. ": " .. tostring(err)) end
end
print("Update check complete.")
