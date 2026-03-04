# QBCore Server — StabCity AI Society

A QBCore FiveM server featuring AI-powered NPCs that talk, remember you, trade items, and have their own personalities. Built on GPT-4o-mini with text-to-speech voices.

## What Is This?

Four AI characters live in the Stab City trailer park in Sandy Shores. You can walk up to any of them, have a real conversation, and they will:

- **Remember you** across sessions (each player gets their own relationship)
- **React to their mood** — they get scared by gunshots, drunk at certain hours, angry if you're hostile
- **Give or take items and money** when it makes sense in conversation
- **Talk to each other** with ambient conversations every 1-2 minutes
- **Speak out loud** with unique AI-generated voices
- **Wander around** the trailer park on daily routines

### The Characters

| Name | Age | Personality | Voice |
|------|-----|-------------|-------|
| **Earl** | 52 | Gruff, suspicious, secretly intelligent. Calls everyone "boy" or "girl". Drinks too much. | Deep (Onyx) |
| **Dolly** | 34 | Street-smart, flirtatious, knows everyone's secrets. Information is her currency. | Warm (Nova) |
| **Wade** | 40 | Paranoid conspiracy theorist with a tender soul. Rambles about satellites and code words. | Nervous (Fable) |
| **Sheryl** | 38 | Army veteran turned mechanic. Direct, calm, zero patience for dishonesty. Writes secret poetry. | Steady (Shimmer) |

---

## What You Need Before Starting

You'll need to download and install these programs. All of them are free.

### 1. FiveM Server (FXServer)

This is the actual game server that runs GTA V multiplayer.

1. Go to https://runtime.fivem.net/artifacts/fivem/build_server_windows/master/
2. Download the latest recommended build (look for the one marked "LATEST RECOMMENDED")
3. Extract the zip — you'll get `FXServer.exe` and a bunch of `.dll` files
4. Copy **everything** from the extracted folder into `Server/` in this repo

### 2. FiveM Client

This is what you use to connect to your server as a player.

1. Go to https://fivem.net/ and download the FiveM client
2. Install it — it will find your GTA V installation automatically
3. You need a **legit copy of GTA V** (Steam, Epic, or Rockstar)

### 3. CFX.re License Key

FiveM requires a free license key to run a server.

1. Go to https://keymaster.fivem.net/
2. Log in with your Cfx.re account (create one if you don't have one)
3. Click "Register a new server"
4. Fill in any name and your IP as `127.0.0.1`
5. Copy the key — it looks like `cfxk_xxxxxxxxxxxxxxxxxxxx`

### 4. MariaDB or MySQL

This is the database that QBCore uses to store player data.

1. Go to https://mariadb.org/download/
2. Download the latest stable version for Windows (MSI installer)
3. Run the installer
   - When it asks for a **root password**, pick something you'll remember (you'll need it later)
   - Leave the port as **3306** (default)
   - Check "Use UTF8 as default server's character set"
4. Finish the installation — MariaDB will run as a Windows service automatically

### 5. .NET 8 SDK

This runs the AI bridge (the program that talks to OpenAI).

1. Go to https://dotnet.microsoft.com/download/dotnet/8.0
2. Download the **.NET SDK** (not Runtime) for Windows x64
3. Run the installer
4. To verify, open a terminal and type `dotnet --version` — you should see `8.0.something`

### 6. OpenAI API Key

This is what powers the AI conversations and voices. It costs money per conversation (roughly $0.01-0.03 per interaction).

1. Go to https://platform.openai.com/
2. Create an account or log in
3. Go to https://platform.openai.com/api-keys
4. Click "Create new secret key"
5. Copy the key — it starts with `sk-proj-`
6. **Add credit to your account** at https://platform.openai.com/settings/organization/billing — even $5 is enough for hundreds of conversations

### 7. Git (optional, for cloning QBCore resources)

1. Go to https://git-scm.com/download/win
2. Download and install with default settings

---

## Step-by-Step Setup

### Step 1: Clone This Repo

```
git clone https://github.com/EthernetWizard/QBCore-Server.git
cd QBCore-Server
```

Or download the ZIP from GitHub and extract it somewhere (like `X:\QBCore`).

### Step 2: Install FXServer Files

Copy the FXServer files you downloaded into the `Server/` folder. After this, `Server/FXServer.exe` should exist.

### Step 3: Download QBCore Resources

Open a terminal in the `Server/resources/` folder and run these commands to clone the QBCore framework and dependencies:

```bash
# Create the QBCore resource folder
mkdir [qb]
cd [qb]

# Clone all required QBCore resources
git clone https://github.com/qbcore-framework/qb-core.git
git clone https://github.com/qbcore-framework/qb-multicharacter.git
git clone https://github.com/qbcore-framework/qb-spawn.git
git clone https://github.com/qbcore-framework/qb-apartments.git
git clone https://github.com/qbcore-framework/qb-clothing.git
git clone https://github.com/qbcore-framework/qb-inventory.git
git clone https://github.com/qbcore-framework/qb-phone.git
git clone https://github.com/qbcore-framework/qb-banking.git
git clone https://github.com/qbcore-framework/qb-input.git
git clone https://github.com/qbcore-framework/qb-target.git
git clone https://github.com/qbcore-framework/qb-adminmenu.git
git clone https://github.com/qbcore-framework/qb-management.git
git clone https://github.com/qbcore-framework/qb-interior.git
git clone https://github.com/qbcore-framework/qb-weapons.git
git clone https://github.com/qbcore-framework/qb-hud.git
git clone https://github.com/qbcore-framework/qb-radialmenu.git
git clone https://github.com/qbcore-framework/qb-smallresources.git
git clone https://github.com/qbcore-framework/qb-weathersync.git
git clone https://github.com/qbcore-framework/qb-menu.git
git clone https://github.com/qbcore-framework/qb-shops.git
```

Now go back to `Server/resources/` and get the standalone dependencies:

```bash
cd ..
mkdir [standalone]
cd [standalone]

# PolyZone (required by qb-target)
git clone https://github.com/mkafrin/PolyZone.git

# oxmysql (database driver) — download the RELEASE, not the source
# Go to: https://github.com/overextended/oxmysql/releases
# Download the latest oxmysql-vX.X.X.zip
# Extract it into [standalone]/oxmysql/

# menuv (required by qb-adminmenu) — download the RELEASE, not the source
# Go to: https://github.com/ThymonA/menuv/releases
# Download the latest menuv_vX.X.X.zip
# Extract it into [standalone]/menuv/
```

> **Important:** For oxmysql and menuv, you must download the **release zip** from GitHub, not clone the source code. The source code needs to be built first and won't work directly.

### Step 4: Create the Database

1. Open a terminal (Command Prompt or PowerShell)
2. Navigate to your MariaDB bin folder (usually `C:\Program Files\MariaDB XX.X\bin\`)
3. Log in to MariaDB:
   ```
   mysql -u root -p
   ```
4. Type your root password when prompted
5. Create the database:
   ```sql
   CREATE DATABASE IF NOT EXISTS qbcore;
   ```
6. Exit MariaDB:
   ```sql
   EXIT;
   ```
7. Import the QBCore schema (run this from the repo root):
   ```
   mysql -u root -p qbcore < qbcore_full_schema.sql
   ```
8. Type your password again — this creates all 16+ tables QBCore needs

You may also need to create the `houselocations` table manually:
```
mysql -u root -p qbcore
```
```sql
CREATE TABLE IF NOT EXISTS houselocations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    label VARCHAR(255) NOT NULL,
    coords TEXT NOT NULL,
    owned TINYINT(1) DEFAULT 0,
    tier INT DEFAULT 1,
    garage TEXT DEFAULT NULL
);
EXIT;
```

### Step 5: Configure server.cfg

1. Copy the example config:
   ```
   copy Server\server.example.cfg Server\server.cfg
   ```
2. Open `Server/server.cfg` in a text editor and fill in:
   - **Your CFX.re license key** on the `sv_licenseKey` line
   - **Your MySQL password** in the `mysql_connection_string` line (replace `YOUR_PASSWORD`)
   - **Your Steam hex ID** on the `add_principal` line (for admin access)

#### How to find your Steam hex ID:
1. Go to https://steamid.io/
2. Enter your Steam profile URL
3. Look for "steamID3" — convert it, or use the decimal Steam ID
4. Your hex format is `steam:` followed by your Steam ID in hexadecimal

### Step 6: Set Your OpenAI API Key

Open a terminal and set the environment variable:

**PowerShell (temporary, current session only):**
```powershell
$env:OPENAI_API_KEY = "sk-proj-your-key-here"
```

**Command Prompt (temporary):**
```cmd
set OPENAI_API_KEY=sk-proj-your-key-here
```

**To set it permanently (recommended):**
1. Press `Win + R`, type `sysdm.cpl`, press Enter
2. Go to the "Advanced" tab
3. Click "Environment Variables"
4. Under "User variables", click "New"
5. Variable name: `OPENAI_API_KEY`
6. Variable value: your key (starts with `sk-proj-`)
7. Click OK on everything

### Step 7: Build the AI Bridge

```
cd AgentBrain\Bridge\StabCityBridge
dotnet build
```

You should see `Build succeeded. 0 Error(s)`. If you get errors about missing packages, run `dotnet restore` first.

### Step 8: Add Custom Vehicles to QBCore (Optional)

The repo includes 6 custom vehicles. They're already configured in `server.cfg`, but you need to register them with QBCore so they appear in the admin menu.

Open `Server/resources/[qb]/qb-core/shared/vehicles.lua` and add these lines just before the closing `}` of the `Vehicles` table (around line 765):

```lua
    --- Custom Vehicles (Added)
    { model = 'rs615',           name = 'Audi RS6',                     brand = 'Audi',            price = 185000,  category = 'sports',         type = 'automobile', shop = 'pdm' },
    { model = 'boostlam',        name = 'Huracan Sheepy',               brand = 'Lamborghini',     price = 450000,  category = 'super',          type = 'automobile', shop = 'pdm' },
    { model = 'filthynsx',       name = 'NSX',                          brand = 'Honda',           price = 175000,  category = 'sports',         type = 'automobile', shop = 'pdm' },
    { model = 'filthynsxa',      name = 'NSX Type A',                   brand = 'Honda',           price = 185000,  category = 'sports',         type = 'automobile', shop = 'pdm' },
    { model = 'filthynsxv',      name = 'NSX Type V',                   brand = 'Honda',           price = 195000,  category = 'sports',         type = 'automobile', shop = 'pdm' },
    { model = 'bmwhommage',      name = 'Hommage',                      brand = 'BMW',             price = 320000,  category = 'sports',         type = 'automobile', shop = 'pdm' },
```

### Step 9: Start the Server

You can use the included launcher or start things manually:

**Option A: Use the launcher**
```
StartQBCore.bat
```

**Option B: Manual start**

Terminal 1 — Start the AI Bridge:
```
cd AgentBrain\Bridge\StabCityBridge
dotnet run
```
Wait until you see `Now listening on: http://localhost:5000`

Terminal 2 — Start the FiveM Server:
```
cd Server
FXServer.exe +exec server.cfg
```
Wait until you see all resources loaded with no errors.

### Step 10: Connect and Play

1. Open FiveM
2. Press F8 to open the console
3. Type: `connect 127.0.0.1:30120`
4. Create a character through the QBCore character selection screen
5. Once spawned, head to **Stab City** in Sandy Shores (marked on the map with blips)
6. Hold **ALT** to bring up the eye cursor, look at an NPC, and select "Talk to [Name]"
7. Type your message and hit submit — they'll respond with text and voice!

---

## How to Use the Admin Menu

1. Press the key bound to `qb-adminmenu` (check your QBCore keybinds)
2. Navigate to **Vehicle Options** > **Spawn Vehicle**
3. Browse by category — custom cars are under **Sports** and **Super**
4. Click any vehicle to spawn it

You can also spawn vehicles via the F8 console:
```
car rs615
car boostlam
car filthynsx
car bmwhommage
```

---

## Talking to the AI NPCs

- **Hold ALT** to activate the eye cursor (qb-target)
- **Look at an NPC** and click "Talk to [Name]"
- **Type your message** in the dialog box
- The NPC will respond in chat with colored text and speak with their voice
- NPCs **remember your conversations** — try coming back later and referencing something you talked about
- NPCs can **give you items or money** if you build a good relationship
- Be hostile and they'll **become cold or refuse to help**

### Things That Affect NPC Mood
- Being friendly makes them happy and builds trust
- Being rude or hostile makes them angry and damages your reputation
- Firing a gun nearby scares them
- Explosions terrify them
- Pulling out a weapon makes them tense
- Dead bodies nearby disturb them
- Earl gets drunk between 10am-1pm and 6pm-9pm

---

## Project Structure

```
QBCore-Server/
  AgentBrain/
    Bridge/
      StabCityBridge/
        Program.cs           -- AI bridge (talks to OpenAI, manages memory)
        StabCityBridge.csproj -- .NET 8 project file
  Server/
    resources/
      [local]/
        qb-stabcityai/       -- The main AI resource
          client/
            main.lua         -- Agent spawning, wandering, routines
            interaction.lua  -- Player interaction (qb-target + qb-input)
            events.lua       -- Gunshot/explosion/weapon reactions
            a2a.lua          -- Agent-to-agent conversations
          server/
            main.lua         -- Bridge communication with player context
            actions.lua      -- Give/take items and money
          shared/
            utils.lua        -- Shared helper functions
          ui/
            index.html       -- Audio playback overlay
          config.lua         -- All settings (locations, timing, routines)
          fxmanifest.lua     -- Resource manifest
      [cars]/                -- Custom vehicle mods
    server.example.cfg       -- Config template (fill in your values)
  SetupDatabase.bat          -- Database creation helper
  StartQBCore.bat            -- One-click server launcher
  qbcore_full_schema.sql     -- Database tables for QBCore
```

---

## Troubleshooting

### "Unable to find the bans table"
Your database schema wasn't imported. Run:
```
mysql -u root -p qbcore < qbcore_full_schema.sql
```

### "Table 'qbcore.houselocations' doesn't exist"
Create it manually — see Step 4 above.

### NPCs don't spawn
- Make sure QBCore loaded without errors (check the server console)
- Make sure you've created a character and fully spawned in
- Check that `qb-stabcityai` shows as started in the server console

### NPCs don't respond when I talk to them
- Make sure the AI bridge is running (`dotnet run` in the StabCityBridge folder)
- Check that `OPENAI_API_KEY` is set in your environment
- Check the bridge console for error messages
- Make sure you have credit on your OpenAI account

### No voice/audio
- The bridge needs to generate TTS audio — check the bridge console for `[TTS]` messages
- Make sure your game audio isn't muted
- Check the FiveM client console (F8) for NUI errors

### Cars don't appear in admin menu
- Make sure you added the vehicle entries to `qb-core/shared/vehicles.lua` (see Step 8)
- Restart the server after making changes to shared files

### Resource errors about missing dependencies
Common missing resources and where to get them:
- `PolyZone` — `git clone https://github.com/mkafrin/PolyZone.git`
- `menuv` — download release from https://github.com/ThymonA/menuv/releases
- `qb-interior` — `git clone https://github.com/qbcore-framework/qb-interior.git`
- `qb-weapons` — `git clone https://github.com/qbcore-framework/qb-weapons.git`

---

## Costs

- **FiveM server**: Free
- **QBCore framework**: Free (open source)
- **MariaDB**: Free (open source)
- **.NET 8 SDK**: Free
- **OpenAI API**: Pay-per-use
  - GPT-4o-mini (conversations): ~$0.005-0.01 per message
  - TTS (voice): ~$0.015 per response
  - Mood/tone classifier: ~$0.001 per message (runs in background)
  - **Typical cost**: $0.02-0.03 per full interaction (text + voice)
  - $5 of credit = roughly 150-250 conversations

---

## License

This project is for personal/educational use. The custom vehicle mods included are from their respective creators. QBCore framework resources are subject to the QBCore license.
