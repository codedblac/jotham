#!/bin/bash
set -e

echo "🚀 Setting up HELB SACCO backend for Render..."

# Clean any existing setup
rm -rf node_modules package-lock.json src .env render.yaml

# Init Node.js project
npm init -y

# Install runtime dependencies
npm install express cors dotenv nodemailer express-rate-limit express-validator helmet compression morgan

# Dev deps
npm install --save-dev nodemon

# Project structure

mkdir -p src/routes src/controllers src/config src/middleware


########################################
# src/index.js
########################################

cat <<'EOL' > src/index.js
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
EOL

########################################
# src/routes/contactRoutes.js
########################################
cat <<'EOL' > src/routes/contactRoutes.js
import express from 'express';
import { body } from 'express-validator';
import { sendContactMessage } from '../controllers/contactController.js';

const router = express.Router();

const validateContact = [
  body('name').trim().notEmpty().withMessage('Name is required'),
  body('email').isEmail().withMessage('Valid email is required'),
  body('phone').optional().isMobilePhone().withMessage('Valid phone required'),
  body('subject').trim().notEmpty().withMessage('Subject is required'),
  body('message').trim().notEmpty().withMessage('Message is required'),
];

router.post('/', validateContact, sendContactMessage);

export default router;
EOL

########################################
# src/controllers/contactController.js
########################################
cat <<'EOL' > src/controllers/contactController.js
import { validationResult } from 'express-validator';
import { transporter, MAIL_USER, MAIL_RECEIVER } from '../config/mailer.js';

export const sendContactMessage = async (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ success: false, errors: errors.array() });
  }

  const { name, phone, email, subject, message } = req.body;

  try {
    const info = await transporter.sendMail({
      // Use authenticated sender to satisfy SPF/DMARC; set replyTo for the user's email
      from: `"HELB SACCO Website" <${MAIL_USER}>`,
      replyTo: email,
      to: MAIL_RECEIVER,
      subject: `New Contact Form: ${subject}`,
      text:
`From: ${name} <${email}>
Phone: ${phone || 'N/A'}

Message:
${message}`,
      html: `
        <h2>New Contact Form Submission</h2>
        <p><strong>Name:</strong> ${name}</p>
        <p><strong>Email:</strong> ${email}</p>
        <p><strong>Phone:</strong> ${phone || 'N/A'}</p>
        <p><strong>Subject:</strong> ${subject}</p>
        <p><strong>Message:</strong></p>
        <pre style="white-space:pre-wrap;font-family:inherit">${message}</pre>
      `,
    });

    return res.status(200).json({ success: true, id: info.messageId, message: 'Message sent successfully.' });
  } catch (err) {
    return next(err);
  }
};
EOL

########################################
# src/config/mailer.js
########################################
cat <<'EOL' > src/config/mailer.js
import nodemailer from 'nodemailer';

export const MAIL_USER = process.env.MAIL_USER;           // info@helbsacco.co.ke
export const MAIL_PASS = process.env.MAIL_PASS;           // cPanel mailbox password
export const MAIL_RECEIVER = process.env.MAIL_RECEIVER;   // memberservices@helbsacco.co.ke
const MAIL_HOST = process.env.MAIL_HOST || 'mail.helbsacco.co.ke';
const MAIL_PORT = Number(process.env.MAIL_PORT || 465);
const MAIL_SECURE = process.env.MAIL_SECURE === 'true' || MAIL_PORT === 465;

if (!MAIL_USER || !MAIL_PASS || !MAIL_RECEIVER) {
  console.error('❌ MAIL_USER, MAIL_PASS, and MAIL_RECEIVER must be set.');
}

export const transporter = nodemailer.createTransport({
  host: MAIL_HOST,
  port: MAIL_PORT,
  secure: MAIL_SECURE, // true for 465 (SSL)
  auth: {
    user: MAIL_USER,
    pass: MAIL_PASS,
  },
});

export async function verifyTransporterOnce() {
  try {
    await transporter.verify();
    console.log('📫 Mail transporter verified and ready.');
  } catch (err) {
    console.error('⚠️  Mail transporter verification failed:', err?.message || err);
  }
}
EOL

########################################
# src/middleware/errors.js
########################################
cat <<'EOL' > src/middleware/errors.js
export const notFound = (req, res, next) => {
  res.status(404).json({ success: false, error: `Not Found - ${req.originalUrl}` });
};

export const errorHandler = (err, req, res, _next) => {
  console.error('❌ Error:', err);
  const status = res.statusCode && res.statusCode !== 200 ? res.statusCode : 500;
  res.status(status).json({
    success: false,
    error: process.env.NODE_ENV === 'production' ? 'Server error' : (err.message || 'Server error'),
  });
};
EOL

########################################
# .env (for local dev; on Render set env vars in dashboard)
########################################
cat <<'EOL' > .env
# Server
PORT=5000
NODE_ENV=development
CLIENT_URL=https://helbsacco.co.ke

# Mail (cPanel SMTP)
MAIL_USER=info@helbsacco.co.ke
MAIL_PASS=REPLACE_WITH_REAL_CPANEL_PASSWORD
MAIL_RECEIVER=memberservices@helbsacco.co.ke
MAIL_HOST=mail.helbsacco.co.ke
MAIL_PORT=465
MAIL_SECURE=true
EOL

########################################
# .gitignore
########################################
cat <<'EOL' > .gitignore
node_modules
.env
EOL

########################################
# render.yaml (Blueprint deploy)
########################################
cat <<'EOL' > render.yaml
services:
  - type: web
    name: helbsacco-backend
    env: node
    region: frankfurt
    plan: free
    buildCommand: npm ci
    startCommand: npm start
    autoDeploy: true
    envVars:
      - key: NODE_ENV
        value: production
      - key: CLIENT_URL
        value: https://helbsacco.co.ke
      - key: MAIL_USER
        value: info@helbsacco.co.ke
      - key: MAIL_RECEIVER
        value: memberservices@helbsacco.co.ke
      # Set these two securely in Render dashboard or via 'fromSecret'
      - key: MAIL_PASS
        sync: false
      - key: MAIL_HOST
        value: mail.helbsacco.co.ke
      - key: MAIL_PORT
        value: "465"
      - key: MAIL_SECURE
        value: "true"
EOL

########################################
# package.json tweaks
########################################
npx json -I -f package.json -e 'this.type="module"'
npx json -I -f package.json -e 'this.scripts={"start":"node src/index.js","dev":"nodemon src/index.js"}'
npx json -I -f package.json -e 'this.engines={"node":">=18"}'

echo ""
echo "✅ Backend setup complete."
echo "Next steps:"
echo "1) Edit .env and set MAIL_PASS for local dev."
echo "2) Local run: npm run dev"
echo "3) Render deploy:"
echo "   - Either push repo and use render.yaml (Blueprint),"
echo "   - Or create a Web Service (Node) and set ENV VARS:"
echo "       CLIENT_URL=https://helbsacco.co.ke"
echo "       MAIL_USER=info@helbsacco.co.ke"
echo "       MAIL_RECEIVER=memberservices@helbsacco.co.ke"
echo "       MAIL_HOST=mail.helbsacco.co.ke"
echo "       MAIL_PORT=465"
echo "       MAIL_SECURE=true"
echo "       MAIL_PASS=YOUR_CPANEL_PASSWORD"
echo ""
echo "Test endpoint (after deploy): POST https://helbsacco-backend.onrender.com/api/contact"
