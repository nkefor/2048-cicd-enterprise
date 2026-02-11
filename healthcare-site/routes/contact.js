const express = require('express');
const router = express.Router();

// Contact form submission
router.post('/', (req, res) => {
    try {
        const { name, email, phone, subject, message, service_interest } = req.body;

        if (!name || !email || !message) {
            return res.status(400).json({ error: 'Name, email, and message are required' });
        }

        // In production, this would send an email via nodemailer
        // For now, log and acknowledge
        console.log('Contact form submission:', { name, email, phone, subject, message, service_interest });

        // If SMTP is configured, send email
        if (process.env.SMTP_HOST && process.env.SMTP_USER && !process.env.SMTP_USER.includes('your-email')) {
            const nodemailer = require('nodemailer');
            const transporter = nodemailer.createTransport({
                host: process.env.SMTP_HOST,
                port: process.env.SMTP_PORT || 587,
                secure: false,
                auth: {
                    user: process.env.SMTP_USER,
                    pass: process.env.SMTP_PASS
                }
            });

            transporter.sendMail({
                from: process.env.FROM_EMAIL || process.env.SMTP_USER,
                to: process.env.PRACTICE_EMAIL || process.env.SMTP_USER,
                subject: `New Contact Form: ${subject || 'General Inquiry'}`,
                html: `
                    <h2>New Contact Form Submission</h2>
                    <p><strong>Name:</strong> ${name}</p>
                    <p><strong>Email:</strong> ${email}</p>
                    <p><strong>Phone:</strong> ${phone || 'Not provided'}</p>
                    <p><strong>Service Interest:</strong> ${service_interest || 'Not specified'}</p>
                    <p><strong>Message:</strong></p>
                    <p>${message}</p>
                `
            }).catch(err => console.error('Email send error:', err));
        }

        res.json({ message: 'Thank you for contacting us. We will get back to you within 24 hours.' });
    } catch (err) {
        console.error('Contact form error:', err);
        res.status(500).json({ error: 'Failed to submit contact form' });
    }
});

module.exports = router;
