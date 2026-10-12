const crypto = require('crypto');
const nodemailer = require('nodemailer');

function createResetToken() {
    const token = crypto.randomBytes(32).toString('hex');
    return {
        token,
        tokenHash: crypto.createHash('sha256').update(token).digest('hex'),
        expiresAt: new Date(Date.now() + 15 * 60 * 1000),
    };
}

function buildResetLink(token) {
    const appUrl = (process.env.WEB_APP_URL || 'http://localhost:5111').replace(/\/$/, '');
    return `${appUrl}/?resetToken=${encodeURIComponent(token)}`;
}

async function sendPasswordResetEmail(email, resetLink) {
    // Keep password-reset emails compatible with the mail configuration that
    // is already used for OTP emails.  Older local .env files use MAIL_*
    // while some deployments use SMTP_*.
    const smtpHost = readEnv('MAIL_HOST', 'SMTP_HOST') || 'smtp.gmail.com';
    const smtpPort = Number(readEnv('MAIL_PORT', 'SMTP_PORT') || 587);
    const smtpUser = readEnv('MAIL_USERNAME', 'SMTP_USERNAME', 'SMTP_USER');
    // Gmail app passwords are often pasted in four groups. Spaces are not
    // part of the actual credential, so remove them before authenticating.
    const smtpPassword = readEnv('MAIL_PASSWORD', 'SMTP_PASSWORD').replace(/\s+/g, '');
    const smtpFrom = readEnv('MAIL_FROM', 'SMTP_FROM') || smtpUser;

    if (!smtpUser || !smtpPassword || !smtpFrom) {
        console.log(`Password reset link for ${email}: ${resetLink}`);
        return 'console';
    }

    const transport = nodemailer.createTransport({
        host: smtpHost,
        port: smtpPort,
        secure: smtpPort === 465,
        auth: { user: smtpUser, pass: smtpPassword },
    });
    await transport.sendMail({
        from: smtpFrom,
        to: email,
        subject: 'RentGo - Reset your password',
        text: `Use this link within 15 minutes to reset your password: ${resetLink}`,
        html: `<p>Use this link within 15 minutes to reset your password:</p><p><a href="${resetLink}">Reset password</a></p>`,
    });
    return 'email';
}

function readEnv(...keys) {
    for (const key of keys) {
        const value = process.env[key];
        if (value !== undefined && String(value).trim() !== '') {
            return String(value).trim().replace(/\\@/g, '@');
        }
    }
    return '';
}

module.exports = { buildResetLink, createResetToken, sendPasswordResetEmail };
