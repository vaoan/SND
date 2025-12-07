require('dotenv').config();

// Example usage - all env vars should be defined in .env.example
const config = {
  nodeEnv: process.env.NODE_ENV || 'development',
  port: process.env.PORT || 3000,
  database: {
    url: process.env.DATABASE_URL,
    host: process.env.DATABASE_HOST,
    port: process.env.DATABASE_PORT,
    name: process.env.DATABASE_NAME,
    user: process.env.DATABASE_USER,
    password: process.env.DATABASE_PASSWORD,
  },
  api: {
    key: process.env.API_KEY,
    secret: process.env.API_SECRET,
  },
  logLevel: process.env.LOG_LEVEL || 'info',
};

console.log(`Starting application in ${config.nodeEnv} mode on port ${config.port}`);
