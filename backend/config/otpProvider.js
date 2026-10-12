const twilio = require('twilio');
const nodemailer = require('nodemailer');

function isPlaceholder(value) {
    return !value
        || /^(your_|change_|replace_)/i.test(value)
        || /^ACx+$/i.test(value)
        || /^x+$/i.test(value)
        || value === '+15017122661';
}

function cleanEnvValue(value) {
    return String(value || '').trim().replace(/\\@/g, '@');
}

function getEnv(...keys) {
    for (const key of keys) {
        const value = process.env[key];
        if (value !== undefined && String(value).trim() !== '') {
            return cleanEnvValue(value);
        }
    }
    return '';
}

function hasTwilioConfig() {
    const sid = process.env.TWILIO_ACCOUNT_SID;
    const token = process.env.TWILIO_AUTH_TOKEN;
    const from = process.env.TWILIO_FROM_NUMBER || process.env.TWILIO_PHONE_NUMBER;

    return sid?.startsWith('AC')
        && !isPlaceholder(sid)
        && !isPlaceholder(token)
        && !isPlaceholder(from);
}

function twilioSender() {
    const client = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);
    const from = process.env.TWILIO_FROM_NUMBER || process.env.TWILIO_PHONE_NUMBER;

    return {
        type: 'twilio',
        send: async ({ phone }, otp) => {
            try {
                const message = await client.messages.create({
                    body: `Votre code RentGo-Tunisia est : ${otp}. Il expire dans 5 minutes.`,
                    from,
                    to: phone,
                });
                console.log(`✅ SMS OTP envoyé via Twilio (SID: ${message.sid})`);
            } catch (error) {
                console.error('❌ Erreur Twilio OTP :', error.message || error);
                const smsError = new Error('Impossible d\'envoyer le SMS OTP. Vérifiez la configuration Twilio et le numéro.');
                smsError.statusCode = 502;
                throw smsError;
            }
        },
    };
}

function getMailConfig() {
    const username = getEnv('MAIL_USERNAME', 'SMTP_USERNAME', 'spring.mail.username');
    const password = getEnv('MAIL_PASSWORD', 'SMTP_PASSWORD', 'spring.mail.password').replace(/\s+/g, '');

    return {
        host: getEnv('MAIL_HOST', 'SMTP_HOST', 'spring.mail.host') || 'smtp.gmail.com',
        port: Number(getEnv('MAIL_PORT', 'SMTP_PORT', 'spring.mail.port') || 587),
        username,
        password,
        from: getEnv('MAIL_FROM', 'SMTP_FROM') || username,
    };
}

function hasMailConfig() {
    const config = getMailConfig();
    return config.host && config.port && !isPlaceholder(config.username) && !isPlaceholder(config.password);
}

function mailSender() {
    const config = getMailConfig();
    const transporter = nodemailer.createTransport({
        host: config.host,
        port: config.port,
        secure: config.port === 465,
        auth: {
            user: config.username,
            pass: config.password,
        },
    });

    return {
        type: 'email',
        send: async ({ email }, otp) => {
            if (!email) {
                const error = new Error('Adresse email requise pour envoyer le code OTP.');
                error.statusCode = 400;
                throw error;
            }

            try {
                await transporter.sendMail({
                    from: config.from,
                    to: email,
                    subject: 'Votre code OTP RentGo Tunisia',
                    text: `Votre code RentGo-Tunisia est : ${otp}. Il expire dans 5 minutes.`,
                    html: `<p>Votre code RentGo-Tunisia est : <strong>${otp}</strong>.</p><p>Il expire dans 5 minutes.</p>`,
                });
                console.log(`✅ Email OTP envoyé à ${email}`);
            } catch (error) {
                console.error('❌ Erreur email OTP :', error.message || error);
                const mailError = new Error('Impossible d\'envoyer l\'email OTP. Vérifiez la configuration SMTP Gmail.');
                mailError.statusCode = 502;
                throw mailError;
            }
        },
    };
}

function consoleSender() {
    return {
        type: 'console',
        send: async ({ phone, email }, otp) => {
            console.log(`📱 [OTP DEV] Code pour ${email || phone} : ${otp}`);
        },
    };
}

function getOtpProvider() {
    const mode = (process.env.OTP_DELIVERY_MODE || 'auto').toLowerCase();
    const mailConfigured = hasMailConfig();
    const twilioConfigured = hasTwilioConfig();

    if (mode === 'email' || mode === 'mail' || mode === 'smtp') {
        if (!mailConfigured) {
            const error = new Error('OTP_DELIVERY_MODE=email requiert une configuration SMTP valide (MAIL_HOST, MAIL_PORT, MAIL_USERNAME, MAIL_PASSWORD).');
            error.statusCode = 503;
            throw error;
        }
        return mailSender();
    }

    if (mode === 'twilio') {
        if (!twilioConfigured) {
            const error = new Error('OTP_DELIVERY_MODE=twilio requiert une configuration Twilio valide (SID, TOKEN et FROM_NUMBER).');
            error.statusCode = 503;
            throw error;
        }
        return twilioSender();
    }

    if (mode === 'auto' && mailConfigured) {
        return mailSender();
    }

    if (mode === 'auto' && twilioConfigured) {
        return twilioSender();
    }

    if (!['auto', 'console'].includes(mode)) {
        console.warn(`⚠️ OTP_DELIVERY_MODE=${mode} inconnu, mode console utilisé.`);
    }
    return consoleSender();
}

module.exports = { getOtpProvider };
