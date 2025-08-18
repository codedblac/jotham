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
