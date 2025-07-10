const { MessageEmbed } = require('discord.js');

module.exports = {
    name: 'setcallsign',
    description: 'Assign a callsign to an emergency worker by SID.',
    options: [
        {
            name: 'sid',
            type: 3, // string (we convert to number in Lua)
            description: 'Player SID',
            required: true,
        },
        {
            name: 'callsign',
            type: 3,
            description: 'Callsign to assign (must be unique)',
            required: true,
        },
    ],
    execute: async (interaction) => {
        const sid = interaction.options.getString('sid');
        const callsign = interaction.options.getString('callsign');

        try {
            const success = global.exports[GetCurrentResourceName()].setCallsign(sid, callsign);

            const embed = new MessageEmbed()
                .setColor(success ? 0x00AE86 : 0xFF0000)
                .setTitle(success ? 'Callsign Updated' : 'Failed to Update Callsign')
                .addFields(
                    { name: 'SID', value: sid, inline: true },
                    { name: 'Callsign', value: callsign, inline: true }
                )
                .setTimestamp();

            await interaction.reply({ embeds: [embed] });
        } catch (error) {
            console.error('Error in setcallsign:', error);
            await interaction.reply({ content: 'Error while trying to update callsign.', ephemeral: true });
        }
    },
};
