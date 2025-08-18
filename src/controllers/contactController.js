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
