require('dotenv').config();

const config = {
  sndConfigPath: process.env.SND_CONFIG_PATH,
};

console.log('SND Config Path:', config.sndConfigPath);
