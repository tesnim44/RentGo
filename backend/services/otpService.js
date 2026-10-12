const bcrypt = require('bcrypt');
const crypto = require('crypto');

const pool = require('../config/db');
const { getOtpProvider } = require('../config/otpProvider');

const OTP_TTL_MS = 5 * 60 * 1000;
const MAX_ATTEMPTS = 5;

async function generateAndSendOtp(recipient, db = pool) {
    const phone = typeof recipient === 'string' ? recipient : recipient?.phone;
    const email = typeof recipient === 'string' ? null : recipient?.email;
    if (!phone) {
        const error = new Error('Numéro de téléphone requis pour envoyer le code OTP.');
        error.statusCode = 400;
        throw error;
    }
    const otp = crypto.randomInt(100000, 1000000).toString();
    const otpHash = await bcrypt.hash(otp, 10);
    const expiresAt = new Date(Date.now() + OTP_TTL_MS);

    await db.query(
        `INSERT INTO otp_codes (phone_number, email, otp_hash, expires_at, attempts, code)
         VALUES ($1, $2, $3, $4, 0, NULL)
         ON CONFLICT (phone_number) DO UPDATE
         SET email = EXCLUDED.email,
             otp_hash = EXCLUDED.otp_hash,
             expires_at = EXCLUDED.expires_at,
             attempts = 0,
             code = NULL,
             created_at = NOW()`,
        [phone, email, otpHash, expiresAt],
    );

    try {
        const provider = getOtpProvider();
        await provider.send({ phone, email }, otp);
        return { expiresAt, deliveryMode: provider.type };
    } catch (error) {
        // No invalid OTP must remain after a failed delivery.
        try {
            await db.query('DELETE FROM otp_codes WHERE phone_number = $1', [phone]);
        } catch (cleanupError) {
            console.error('❌ Nettoyage OTP impossible :', cleanupError.message || cleanupError);
        }
        throw error;
    }
}

async function verifyOtp(phone, code) {
    const client = await pool.connect();

    try {
        await client.query('BEGIN');

        const result = await client.query(
            `SELECT phone_number, otp_hash, expires_at, attempts
             FROM otp_codes
             WHERE phone_number = $1
             FOR UPDATE`,
            [phone],
        );
        const record = result.rows[0];

        if (!record) {
            const error = new Error('Aucun code trouvé, redemandez-en un.');
            error.statusCode = 400;
            throw error;
        }
        if (new Date() > new Date(record.expires_at)) {
            const error = new Error('Code expiré.');
            error.statusCode = 400;
            throw error;
        }
        if (record.attempts >= MAX_ATTEMPTS) {
            const error = new Error('Trop de tentatives. Redemandez un code.');
            error.statusCode = 429;
            throw error;
        }

        const valid = await bcrypt.compare(code, record.otp_hash);
        await client.query(
            'UPDATE otp_codes SET attempts = attempts + 1 WHERE phone_number = $1',
            [phone],
        );

        if (!valid) {
            const error = new Error('Code incorrect.');
            error.statusCode = 400;
            // Preserve the failed-attempt counter before returning the error.
            await client.query('COMMIT');
            throw error;
        }

        await client.query('DELETE FROM otp_codes WHERE phone_number = $1', [phone]);
        const user = await client.query(
            `UPDATE users SET is_verified = TRUE
             WHERE phone_number = $1
             RETURNING id`,
            [phone],
        );

        if (user.rows.length === 0) {
            const error = new Error('Utilisateur introuvable.');
            error.statusCode = 404;
            throw error;
        }

        await client.query('COMMIT');
    } catch (error) {
        try {
            await client.query('ROLLBACK');
        } catch (rollbackError) {
            console.error('❌ Rollback vérification OTP impossible :', rollbackError.message || rollbackError);
        }
        throw error;
    } finally {
        client.release();
    }
}

module.exports = { generateAndSendOtp, verifyOtp, MAX_ATTEMPTS };
