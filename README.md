# MCShop

In-game ComputerCraft shop for Minecraft 1.21.1 NeoForge.

## Files

- `shop_server.lua`: central server, runs on a Command Computer.
- `shop_client.lua`: player terminal, runs on any ComputerCraft computer.
- `updater.lua`: downloads the latest server/client files from this repository.
- `startup-server`: optional startup file for the central computer.
- `startup-client`: optional startup file for player computers.

## Installation

1. Put a wireless modem on the central Command Computer and every player computer.
2. Copy `shop_server.lua` and `updater.lua` to the central computer.
3. Copy `shop_client.lua` and `updater.lua` to each player computer.
4. Set `SERVER_ID` in `shop_client.lua` to the central computer's ID.
5. Run `shop_server.lua` centrally and `shop_client.lua` on player computers.

The current catalog is intentionally small while the transaction flow is tested. Prices and automatic recipe discovery will be added separately.
