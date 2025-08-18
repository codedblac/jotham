import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import helmet from 'helmet';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import morgan from 'morgan';
import contactRoutes from './routes/contactRoutes.js';
import { notFound, errorHandler } from './middleware/errors.js';
import { verifyTransporterOnce } from './config/mailer.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 5000;
const CLIENT_URL = process.env.CLIENT_URL || 'https://helbsacco.co.ke';

// Behind Render's proxy to get correct IPs for rate limiting
app.set('trust proxy', 1);

// Security & perf
app.use(helmet());
app.use(compression());

// Logging
const env = process.env.NODE_ENV || 'development';
app.use(morgan(env === 'production' ? 'combined' : 'dev'));

// CORS: lock to your frontend domain
app.use(
  cors({
    origin: [CLIENT_URL],
    methods: ['GET', 'POST', 'OPTIONS'],
    allowedHeaders: ['Content-Type'],
  })
);

// JSON body parsing (limit to prevent abuse)
app.use(express.json({ limit: '100kb' }));

// Rate limiter (per IP)
app.use(
  rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 100,
    standardHeaders: true,
    legacyHeaders: false,
    message: { success: false, error: 'Too many requests, please try again later.' },
  })
);

// Health & root
app.get('/health', (_req, res) => res.json({ ok: true, uptime: process.uptime() }));
app.get('/', (_req, res) => res.send('✅ HELB SACCO Backend is running...'));

// Routes
app.use('/api/contact', contactRoutes);

// 404 + error handler
app.use(notFound);
app.use(errorHandler);

// Start
app.listen(PORT, async () => {
  console.log(`🚀 Server listening on port ${PORT} (${env})`);
  await verifyTransporterOnce();
});
