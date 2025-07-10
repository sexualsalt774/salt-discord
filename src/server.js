const fs = require('fs');
const path = require('path');
const { Client, Intents, Collection } = require('discord.js');
const { REST } = require('@discordjs/rest');
const { Routes } = require('discord-api-types/v9');

const token = GetConvar('salt_discord_token', '');
const OWNER_ROLE_ID = GetConvar('salt_discord_owner_role_id', '1368391612274704444');

const MySQL = global.exports.oxmysql // Our mysql system is using fivem hehe

// Ensure the permissions table exists
MySQL.query(`
    CREATE TABLE IF NOT EXISTS discord_permissions (
        id INT AUTO_INCREMENT PRIMARY KEY,
        type VARCHAR(32) NOT NULL,
        value VARCHAR(64) NOT NULL,
        extra VARCHAR(64) DEFAULT NULL
    )
`, [], (result) => {
    console.log('discord_permissions table ensured.');
});

// Permission helpers (callback-based)
function getRoleIds(type, cb) {
    MySQL.query('SELECT value FROM discord_permissions WHERE type = ?', [type], (result) => {
        cb(result.map(row => row.value));
    });
}

function getCommandPermissions(command, cb) {
    MySQL.query('SELECT extra FROM discord_permissions WHERE type = ? AND value = ?', ['command_permission', command], (result) => {
        cb(result.map(row => row.extra));
    });
}

function addRoleId(type, roleId, cb) {
    MySQL.execute('INSERT INTO discord_permissions (type, value) VALUES (?, ?)', [type, roleId], (affectedRows) => {
        cb(affectedRows);
    });
}

function removeRoleId(type, roleId, cb) {
    MySQL.execute('DELETE FROM discord_permissions WHERE type = ? AND value = ?', [type, roleId], (affectedRows) => {
        cb(affectedRows);
    });
}

function setCommandPermission(command, roles, cb) {
    MySQL.execute('DELETE FROM discord_permissions WHERE type = ? AND value = ?', ['command_permission', command], (affectedRows) => {
        if (!roles.length) return cb(true);
        let completed = 0;
        roles.forEach(role => {
            MySQL.execute('INSERT INTO discord_permissions (type, value, extra) VALUES (?, ?, ?)', ['command_permission', command, role], () => {
                completed++;
                if (completed === roles.length) cb(true);
            });
        });
    });
}

function addIgnoredCommand(command, cb) {
    MySQL.execute('INSERT INTO discord_permissions (type, value) VALUES (?, ?)', ['ignored_command', command], (affectedRows) => {
        cb(affectedRows);
    });
}

function removeIgnoredCommand(command, cb) {
    MySQL.execute('DELETE FROM discord_permissions WHERE type = ? AND value = ?', ['ignored_command', command], (affectedRows) => {
        cb(affectedRows);
    });
}

function getIgnoredCommands(cb) {
    MySQL.query('SELECT value FROM discord_permissions WHERE type = ?', ['ignored_command'], (result) => {
        cb(result.map(row => row.value));
    });
}

function canRunCommand(member, commandName, cb) {
    getIgnoredCommands((ignored) => {
        if (ignored.includes(commandName)) return cb(true);
        if (member.roles.cache.has(OWNER_ROLE_ID)) return cb(true);
        getRoleIds('admin_role', (adminRoles) => {
            getRoleIds('mod_role', (modRoles) => {
                getCommandPermissions(commandName, (allowedRoles) => {
                    if (allowedRoles.includes('admin') && adminRoles.some(id => member.roles.cache.has(id))) return cb(true);
                    if (allowedRoles.includes('mod') && modRoles.some(id => member.roles.cache.has(id))) return cb(true);
                    return cb(false);
                });
            });
        });
    });
}

if (!token || token === '' || !OWNER_ROLE_ID || OWNER_ROLE_ID === '') {
    console.error('^1[salt-discord] Discord token or client ID not found. Please set salt_discord_token, salt_discord_client_id and salt_discord_owner_role_id in your server.cfg^0');
} else {
    const client = new Client({
        intents: [Intents.FLAGS.GUILDS],
    });

    client.commands = new Collection();
    const commandsToRegister = [];

    const commandsPath = path.join(GetResourcePath(GetCurrentResourceName()), 'src', 'commands');
    const commandFiles = fs.readdirSync(commandsPath).filter(file => file.endsWith('.js'));

    for (const file of commandFiles) {
        const filePath = path.join(commandsPath, file);
        const command = require(filePath);
        if ('name' in command && 'description' in command) {
            client.commands.set(command.name, command);
            commandsToRegister.push({ name: command.name, description: command.description, options: command.options || [] });
        } else {
            console.log(`^3[salt-discord] The command at ${filePath} is missing a required "name" or "description" property.^0`);
        }
    }

    client.once('ready', async () => {
        console.log(`^2[salt-discord] Logged in as ${client.user.tag}!^0`);

        try {
            const app = await client.application.fetch();
            const rest = new REST({ version: '9' }).setToken(token);

            // Register global commands
            console.log(`^2[salt-discord] Started refreshing ${commandsToRegister.length} application (/) commands.^0`);
            await rest.put(
                Routes.applicationCommands(app.id),
                { body: commandsToRegister },
            );
            console.log(`^2[salt-discord] Successfully reloaded ${commandsToRegister.length} application (/) commands.^0`);

            // Console command: /refreshguild [guildId]
            RegisterCommand('refreshguild', async (src, args) => {
                if (src !== 0) return;

                const guildId = args[0];
                if (!guildId) {
                    console.log('^1Usage: /refreshguild [guildId]^0');
                    return;
                }

                try {
                    await rest.put(
                        Routes.applicationGuildCommands(app.id, guildId),
                        { body: commandsToRegister },
                    );
                    console.log(`^2[salt-discord] Successfully refreshed commands for guild ${guildId}^0`);
                } catch (err) {
                    console.error(`^1[salt-discord] Failed to refresh commands for guild ${guildId}: ${err.message}^0`);
                }
            }, true);
        } catch (error) {
            console.error(`^1[salt-discord] Failed to register commands: ${error.message}^0`);
        }
    });

    client.on('interactionCreate', (interaction) => {
        setImmediate(async () => {
            if (!interaction.isCommand()) return;

            const command = interaction.client.commands.get(interaction.commandName);

            if (!command) {
                console.error(`^1[salt-discord] No command matching ${interaction.commandName} was found.^0`);
                return;
            }

            // Permission check
            canRunCommand(interaction.member, command.name, async (allowed) => {
                if (!allowed) {
                    await interaction.reply({ content: 'You do not have permission to use this command.', ephemeral: true });
                    return;
                }
                try {
                    await command.execute(interaction);
                } catch (error) {
                    console.error(error);
                    await interaction.reply({ content: 'There was an error while executing this command!', ephemeral: true });
                }
            });
        });
    });

    client.login(token).catch((e) => {
        console.error(`^1[salt-discord] Failed to log in: ${e.message}^0`);
    });
}
