# salt-discord

A FiveM resource for Discord integration, providing in-game commands and player/job management via Discord slash commands.

---

## Installation

1. **Clone or Download**
   - Place the `salt-discord` folder in your `resources` directory.

2. **Dependencies**
   - Node.js (for Discord bot features)
   - FiveM server (FXServer)

3. **Install Node Modules**
   ```sh
   cd resources/salt-discord
   npm install
   ```

---

## Configuration

Add the following to your `server.cfg`:

```cfg
set salt_discord_token "YOUR_BOT_TOKEN_HERE"
set salt_discord_client_id "YOUR_BOT_CLIENT_ID_HERE"
set salt_discord_owner_role_id "OWNER_ROLE_ID_HERE"
ensure salt-discord
```

- Replace `YOUR_BOT_TOKEN_HERE` and `YOUR_BOT_CLIENT_ID_HERE` with your Discord bot credentials.
- Replace `OWNER_ROLE_ID_HERE` with your Discord role id.

---

## Usage

### Discord Slash Commands

Below is a list of available Discord bot commands:

- **/ping**
  - Replies with Pong! (latency test)

- **/players**
  - Gets a list of all players currently on the server.

- **/givemoney**
  - Give money to a player by SID.
  - Options: `sid` (Player SID), `type` (bank or cash), `amount` (amount to give)

- **/giveitem**
  - Give an item to a player by SID.
  - Options: `sid` (Player SID), `item` (item name), `amount` (amount)

- **/giveweapon**
  - Give a weapon to a player by SID.
  - Options: `sid` (Player SID), `weapon` (weapon name), `ammo` (amount), `scractched` (True/False)

- **/addownedvehicle**
  - Add owned vehicle to player.
  - Options: `sid`, `hash` (vehicle model), `make`, `model`, `class`, `value`, `type` (0=Car, 1=Boat, 2=Aircraft)

- **/givejob**
  - Give a job to a player by SID.
  - Options: `sid`, `job`, `grade`, `workplace` (optional)

- **/removejob**
  - Remove a player's job by SID.
  - Options: `sid`, `job`

- **/setowner**
  - Set a job's owner by SID.
  - Options: `sid`, `job`

- **/checkjobs**
  - Shows the jobs a character has.
  - Options: `sid`

- **/getjobs**
  - Gets a list of all jobs currently on the server.

- **/addcrypto**
  - Give cryptocurrency to a character.
  - Options: `sid` (Player SID), `crypto` (VRM, PLEB, or HEIST), `amount` (amount to give)

- **/addfleetvehicle**
  - Add a Fleet Vehicle to a Job.
  - Options: `job` (Job name), `workplace` (Workplace ID or "false"/"all"), `level` (Required Level), `hash` (Vehicle Model), `make` (Make), `model` (Model Name), `class` (Class), `value` (Monetary Value), `type` (Car/Boats/Aircraft), `qual` (Job Qualification or "false"/"all")

- **/setped**
  - Set a player ped by SID.
  - Options: `sid` (Player SID), `ped` (Ped Model, e.g. mp_m_freemode_01)

- **/onlinecount**
  - Get the number of players currently online on the server.
  - Replies with an embed showing:
    - "Nobody is online right now." if 0
    - "There is 1 person online right now." if 1
    - "There are X people online right now." if more than 1

- **/heal**
  - Heal a player by SID, or all players.
  - Options: `sid` (Player SID or "all" for all players)

- **/setcallsign**
  - Assign a callsign to an emergency worker by SID.
  - Options: `sid` (Player SID), `callsign` (Callsign to assign (must be unique))

- **/nuke**
  - Dramatically launches a nuclear strike on the server, triggering a 23-second countdown with Discord embed updates at key moments. At the end, the nuke detonates and a final embed is shown. Intended for fun or dramatic server events.
  - Usage: `/nuke`
  - Only available to users with the appropriate permissions (typically admins/owners).

## Permissions Management

The `/permissions` command allows the owner role to manage admin/mod roles, command permissions, and ignored commands directly from Discord. All changes are stored in the MySQL database.

### Usage

#### Add/Remove Admin or Mod Roles
- `/permissions action:add_admin_role role:@Admin`
- `/permissions action:remove_admin_role role:@Admin`
- `/permissions action:add_mod_role role:@Mod`
- `/permissions action:remove_mod_role role:@Mod`

#### Set Command Permissions
- `/permissions action:set_command_permission command:giveitem roles:admin`  
  (Only admin roles can use `giveitem`)
- `/permissions action:set_command_permission command:giveitem roles:mod`  
  (Only mod roles can use `giveitem`)
- `/permissions action:set_command_permission command:giveitem roles:both`  
  (Both admin and mod roles can use `giveitem`)
- `/permissions action:set_command_permission command:giveitem roles:none`  
  (No staff roles can use `giveitem`)

#### Manage Ignored Commands
- `/permissions action:add_ignored_command command:ping`  
  (Everyone can use the `ping` command, regardless of role)
- `/permissions action:remove_ignored_command command:ping`  
  (Removes `ping` from the ignored list)

#### List All Permissions
- `/permissions action:list`

This will display:
- All admin and mod roles
- All ignored commands
- All command permissions and which roles can use them

**Note:** Only users with the owner role (set by `salt_discord_owner_role_id` in your config) can use the `/permissions` command.

---

## Development

- **Commands** are located in `src/commands/`
- **Server logic** in `src/server.js` and `src/server.lua`
- **Client logic** in `src/client.lua`
- **Exports**: Lua and JS communicate via FiveM's `global.exports` and registered functions.

### FiveM Console Commands

- **/refreshguild [guildId]**
  - Refreshes Discord slash commands for a specific guild
  - Usage: `/refreshguild 123456789012345678` (replace with your Discord server ID)
  - Useful when you've added new commands or need to update existing ones for a specific server
  - Only works from the FiveM server console (not in-game)

### Adding/Editing Commands

- Add new command files to `src/commands/`
- Each command exports a module with `name`, `description`, `options`, and `execute` function.

### Lua ↔ JS Communication

- Lua functions are registered and called from JS using `global.exports[GetCurrentResourceName()]`
- See `src/server.lua` for registered functions like `fetchJobs`, `fetchCharacter`, etc.

---

## Troubleshooting

- Ensure your bot token and client ID are correct in `server.cfg`
- Make sure the bot is invited to your Discord server with the correct permissions (slash commands, embeds)
- Check server console for errors if commands do not respond

---

## Contributing

Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

---

## License

[![License: CC BY-NC 4.0](https://img.shields.io/badge/License-CC%20BY--NC%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc/4.0/)

---

## Credits

- Developed by Salt
- Better Command Registering by KR (ISKinGeR)
- Uses [discord.js](https://discord.js.org/) and FiveM natives
