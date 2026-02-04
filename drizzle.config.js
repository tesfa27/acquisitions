import 'dotenv/config';

export default {
  schema: './src/models/*.js',
  out: './drizzle/migrations',  
  dialect: 'postgresql',
  dbCredentials: {
    url: process.env.DATABASE_URL,
  },
};