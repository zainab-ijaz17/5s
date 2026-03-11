import 'dotenv/config';
import express from 'express';
import nodemailer from 'nodemailer';
import multer from 'multer';

const app = express();
const upload = multer({
  limits: { fileSize: 10 * 1024 * 1024 } // 10MB per image
});

app.use(express.json({ limit: '20mb' }));

// 🔐 Simple API key protection
app.use((req, res, next) => {
  if (req.headers['x-api-key'] !== process.env.API_KEY) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
});

// ✉️ SMTP transport (internal LAN) - matching Laravel config exactly
const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: Number(process.env.SMTP_PORT),
  secure: false, // No SSL/TLS - matching Laravel 'encryption' => ''
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
  // Remove TLS options to match Laravel's no encryption setting
  tls: {
    rejectUnauthorized: false // Allow self-signed certificates if needed
  }
});

// 🧪 Health check
app.get('/health', async (_, res) => {
  try {
    await transporter.verify();
    res.json({ status: 'SMTP OK' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// 📩 Send FULL assessment immediately on submission
app.post(
  '/send-assessment',
  upload.any(),
  async (req, res) => {
    try {
      const { subject, html, text } = req.body;

      console.log('=== EMAIL SEND ATTEMPT ===');
      console.log('SMTP Host:', process.env.SMTP_HOST);
      console.log('SMTP Port:', process.env.SMTP_PORT);
      console.log('SMTP User:', process.env.SMTP_USER);
      console.log('SMTP Pass:', process.env.SMTP_PASS ? '[SET]' : '[NOT SET]');
      console.log('Subject:', subject);

      const attachments = (req.files || []).map(f => ({
        filename: f.originalname,
        content: f.buffer,
      }));

      const mailOptions = {
        from: '"Employee Claims Portal - E C P" <systems.services@packages.com.pk>',
        to: process.env.TO_EMAIL, // 🔒 FIXED RECIPIENT
        subject,
        html,
        text,
        attachments,
      };

      console.log('Mail options:', {
        ...mailOptions,
        ...{ attachments: `${attachments.length} files` }
      });

      const result = await transporter.sendMail(mailOptions);
      console.log('Email sent successfully:', result.messageId);

      res.json({ success: true });
    } catch (e) {
      console.error('=== EMAIL SEND ERROR ===');
      console.error('Error:', e.message);
      console.error('Full error:', e);
      res.status(500).json({ error: e.message });
    }
  }
);

app.listen(3000, () => {
  console.log('Assessment mail relay running on port 3000');
  console.log('SMTP Configuration:');
  console.log('Host:', process.env.SMTP_HOST);
  console.log('Port:', process.env.SMTP_PORT);
  console.log('User:', process.env.SMTP_USER);
  console.log('Password:', process.env.SMTP_PASS ? '[REDACTED]' : '[NOT SET]');
  console.log('API Key:', process.env.API_KEY ? '[SET]' : '[NOT SET]');
  console.log('To Email:', process.env.TO_EMAIL);
});
