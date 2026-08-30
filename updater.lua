-- MCShop updater. Run on a ComputerCraft computer.
-- Downloads the latest shop files from GitHub.

local BASE = "https://raw.githubusercontent.com/Marco0300/MCShop/main/"
local FILES = { "updater.lua", "update.lua", "shop_server.lua", "shop_client.lua", "shop_admin.lua", "shop_catalog" }

local function download(name)
  local response, err = http.get(BASE .. name .. "?v=" .. tostring(os.epoch("utc")))
  if not response then
    return false, err or "HTTP request failed"
  end
  local data = response.readAll()
  response.close()
  if not data or #data < 50 then
    return false, "Downloaded file is unexpectedly small"
  end

  -- Validate the downloaded file before touching the installed copy.
  -- This prevents an HTML page, Git diff, or damaged download from being installed.
  local validationData = data
  if name:match("shop_catalog") then validationData = "return " .. data end
  local chunk, syntaxError = load(validationData, "@" .. name)
  if not chunk then
    return false, "Downloaded Lua is invalid: " .. tostring(syntaxError)
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
