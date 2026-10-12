// ============================================================
// controllers/authController.js
// ------------------------------------------------------------
// Un "controller" contient la LOGIQUE de chaque route : que
// faire quand telle requête arrive. Les fichiers "routes/"
// disent QUELLE URL déclenche QUELLE fonction ; les
// "controllers" disent CE QUE fait cette fonction.
//
// Ici : inscription, vérification du code OTP, et connexion.
// ============================================================

const pool = require('../config/db');       // notre connexion PostgreSQL
const bcrypt = require('bcrypt');           // pour hacher les mots de passe
const jwt = require('jsonwebtoken');        // pour générer les tokens de session
const { generateAndSendOtp, verifyOtp: verifyOtpCode } = require('../services/otpService');
const { buildResetLink, createResetToken, sendPasswordResetEmail } = require('../services/passwordResetService');
const JWT_SECRET = process.env.JWT_SECRET || 'rentgo-tunisia-dev-secret';

function normalizePhoneNumber(value) {
    const raw = String(value || '').trim();
    const compact = raw.replace(/[^\d+]/g, '');

    if (/^\+216\d{8}$/.test(compact)) return compact;
    if (/^00216\d{8}$/.test(compact)) return `+${compact.slice(2)}`;
    if (/^216\d{8}$/.test(compact)) return `+${compact}`;
    if (/^\d{8}$/.test(compact)) return `+216${compact}`;

    return compact;
}

function isValidPhoneNumber(phoneNumber) {
    return /^\+216\d{8}$/.test(phoneNumber);
}

function normalizeEmail(value) {
    return String(value || '').trim().replace(/\\@/g, '@').toLowerCase();
}

function isValidEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

// --------------------------------------------------------------
// 1. INSCRIPTION — POST /api/auth/register
// --------------------------------------------------------------
// L'utilisateur envoie : nom complet, numéro de téléphone, CIN, mot de passe
async function register(req, res) {
    // req.body = les données envoyées par l'app Flutter en JSON
    const { fullName, phoneNumber, email, cin, password } = req.body;
    const normalizedPhoneNumber = normalizePhoneNumber(phoneNumber);
    const normalizedEmail = normalizeEmail(email);

    // Vérification simple : tous les champs obligatoires sont-ils remplis ?
    if (!fullName || !phoneNumber || !email || !password) {
        return res.status(400).json({ message: 'Nom, téléphone, email et mot de passe sont obligatoires.' });
    }

    if (!isValidPhoneNumber(normalizedPhoneNumber)) {
        return res.status(400).json({ message: 'Numéro invalide. Format attendu: +216XXXXXXXX.' });
    }

    if (!isValidEmail(normalizedEmail)) {
        return res.status(400).json({ message: 'Adresse email invalide.' });
    }

    try {
        // Toutes les écritures sont atomiques : un échec SMS annule aussi
        // la création de l'utilisateur et du code OTP.
        const client = await pool.connect();

        try {
            await client.query('BEGIN');

            // On verrouille le numéro/email pendant l'inscription pour éviter
            // deux créations concurrentes avec les mêmes identifiants.
            const existingUser = await client.query(
                'SELECT id, is_verified, phone_number, email FROM users WHERE phone_number = $1 OR email = $2 FOR UPDATE',
                [normalizedPhoneNumber, normalizedEmail],
            );

            const verifiedPhone = existingUser.rows.find(
                (user) => user.is_verified && user.phone_number === normalizedPhoneNumber,
            );
            const verifiedEmail = existingUser.rows.find(
                (user) => user.is_verified && user.email === normalizedEmail,
            );

            if (verifiedPhone) {
                await client.query('ROLLBACK');
                return res.status(409).json({ message: 'Ce numéro de téléphone est déjà utilisé.' });
            }

            if (verifiedEmail) {
                await client.query('ROLLBACK');
                return res.status(409).json({ message: 'Cette adresse email est déjà utilisée.' });
            }

            const reusableUser = existingUser.rows.find((user) => user.phone_number === normalizedPhoneNumber);
            const conflictingDraft = existingUser.rows.find((user) => user.id !== reusableUser?.id);

            if (conflictingDraft) {
                await client.query('ROLLBACK');
                return res.status(409).json({ message: 'Ce téléphone ou email est déjà associé à une inscription non vérifiée.' });
            }

            // On hache le mot de passe avant de le stocker (jamais en clair !)
            const passwordHash = await bcrypt.hash(password, 10);

            const result = reusableUser
                ? await client.query(
                    `UPDATE users
                     SET full_name = $1,
                         email = $2,
                         cin = $3,
                         password_hash = $4
                     WHERE phone_number = $5
                       AND is_verified = FALSE
                     RETURNING id, full_name, email, phone_number, is_verified`,
                    [fullName.trim(), normalizedEmail, cin || null, passwordHash, normalizedPhoneNumber],
                )
                : await client.query(
                    `INSERT INTO users (full_name, email, phone_number, cin, password_hash)
                     VALUES ($1, $2, $3, $4, $5)
                     RETURNING id, full_name, email, phone_number, is_verified`,
                    [fullName.trim(), normalizedEmail, normalizedPhoneNumber, cin || null, passwordHash],
                );

            const newUser = result.rows[0];

            // --- Génération et envoi du code OTP ---
            // Si l'envoi échoue, le catch effectue ROLLBACK.
            const otp = await generateAndSendOtp(
                { phone: normalizedPhoneNumber, email: normalizedEmail },
                client,
            );
            await client.query('COMMIT');

            // On répond au client uniquement après le COMMIT.
            return res.status(201).json({
                message: 'Inscription réussie. Un code de vérification a été envoyé.',
                user: newUser,
                otpDelivery: { provider: otp.deliveryMode },
            });
        } catch (transactionError) {
            try {
                await client.query('ROLLBACK');
            } catch (rollbackError) {
                console.error('❌ Rollback inscription impossible :', rollbackError.message || rollbackError);
            }
            throw transactionError;
        } finally {
            client.release();
        }
    } catch (error) {
        console.error(error);
        res.status(error.statusCode || 500).json({ message: error.message || 'Erreur serveur lors de l\'inscription.' });
    }
}

// --------------------------------------------------------------
// 2. VÉRIFICATION OTP — POST /api/auth/verify-otp
// --------------------------------------------------------------
async function verifyOtp(req, res) {
    const { phoneNumber, code } = req.body;
    const normalizedPhoneNumber = normalizePhoneNumber(phoneNumber);
    const normalizedCode = String(code || '').trim();

    if (!phoneNumber || !code) {
        return res.status(400).json({ message: 'Numéro de téléphone et code requis.' });
    }

    if (!isValidPhoneNumber(normalizedPhoneNumber) || !/^\d{6}$/.test(normalizedCode)) {
        return res.status(400).json({ message: 'Numéro ou code OTP invalide.' });
    }

    try {
        await verifyOtpCode(normalizedPhoneNumber, normalizedCode);
        return res.status(200).json({ message: 'Compte vérifié avec succès. Vous pouvez vous connecter.' });
    } catch (error) {
        console.error(error);
        return res.status(error.statusCode || 500).json({ message: error.message || 'Erreur serveur lors de la vérification.' });
    }
}

// --------------------------------------------------------------
// 3. CONNEXION — POST /api/auth/login
// --------------------------------------------------------------
async function login(req, res) {
    const { phoneNumber, password } = req.body;
    const normalizedPhoneNumber = normalizePhoneNumber(phoneNumber);

    if (!phoneNumber || !password) {
        return res.status(400).json({ message: 'Téléphone et mot de passe requis.' });
    }

    if (!isValidPhoneNumber(normalizedPhoneNumber)) {
        return res.status(400).json({ message: 'Numéro invalide. Format attendu: +216XXXXXXXX.' });
    }

    try {
        const result = await pool.query('SELECT * FROM users WHERE phone_number = $1', [normalizedPhoneNumber]);

        if (result.rows.length === 0) {
            // Message volontairement vague ("téléphone OU mot de passe") pour
            // ne pas révéler à un attaquant si le numéro existe ou non
            return res.status(401).json({ message: 'Téléphone ou mot de passe incorrect.' });
        }

        const user = result.rows[0];

        // On compare le mot de passe envoyé avec le hash stocké en base
        const isPasswordValid = await bcrypt.compare(password, user.password_hash);

        if (!isPasswordValid) {
            return res.status(401).json({ message: 'Téléphone ou mot de passe incorrect.' });
        }

        if (!user.is_verified) {
            return res.status(403).json({ message: 'Compte non vérifié. Veuillez valider votre code OTP.' });
        }

        if (user.is_suspended) {
            return res.status(403).json({ message: 'Ce compte a été suspendu.' });
        }

        // On génère un token JWT : une sorte de "badge d'accès" temporaire
        // que l'app Flutter va conserver et renvoyer à chaque requête pour
        // prouver qui elle est, sans avoir à renvoyer le mot de passe.
        const token = jwt.sign(
            { id: user.id, phoneNumber: user.phone_number, email: user.email, role: user.role },
            JWT_SECRET,
            { expiresIn: '7d' } // le token reste valide 7 jours
        );

        res.status(200).json({
            message: 'Connexion réussie.',
            token,
            user: {
                id: user.id,
                fullName: user.full_name,
                email: user.email,
                phoneNumber: user.phone_number,
                role: user.role,
                walletBalance: user.wallet_balance,
            },
        });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Erreur serveur lors de la connexion.' });
    }
}

// --------------------------------------------------------------
// 3b. RENVOI OTP — POST /api/auth/resend-otp
// --------------------------------------------------------------
async function resendOtp(req, res) {
    const { phoneNumber } = req.body;
    const normalizedPhoneNumber = normalizePhoneNumber(phoneNumber);

    if (!phoneNumber) {
        return res.status(400).json({ message: 'Numéro de téléphone requis.' });
    }

    if (!isValidPhoneNumber(normalizedPhoneNumber)) {
        return res.status(400).json({ message: 'Numéro invalide. Format attendu: +216XXXXXXXX.' });
    }

    let client;
    try {
        client = await pool.connect();
        await client.query('BEGIN');

        const userResult = await client.query('SELECT id, email, is_verified FROM users WHERE phone_number = $1', [normalizedPhoneNumber]);

        if (userResult.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ message: 'Utilisateur introuvable.' });
        }

        if (userResult.rows[0].is_verified) {
            await client.query('ROLLBACK');
            return res.status(409).json({ message: 'Ce compte est déjà vérifié.' });
        }

        const otp = await generateAndSendOtp(
            { phone: normalizedPhoneNumber, email: userResult.rows[0].email },
            client,
        );
        await client.query('COMMIT');

        return res.status(200).json({ message: 'Un nouveau code OTP a été envoyé.', otpDelivery: { provider: otp.deliveryMode } });
    } catch (error) {
        if (client) {
            try {
                await client.query('ROLLBACK');
            } catch (rollbackError) {
                console.error('❌ Rollback renvoi OTP impossible :', rollbackError.message || rollbackError);
            }
        }
        console.error(error);
        return res.status(error.statusCode || 500).json({ message: error.message || 'Erreur serveur lors du renvoi du code.' });
    } finally {
        client?.release();
    }
}

// --------------------------------------------------------------
// 4. CURRENT USER — GET /api/auth/me
// --------------------------------------------------------------
async function getMe(req, res) {
    try {
        const result = await pool.query(
            `SELECT id, full_name, email, phone_number, cin, is_verified, role, is_suspended, wallet_balance, created_at
             FROM users
             WHERE id = $1`,
            [req.user.id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ message: 'Utilisateur introuvable.' });
        }

        const user = result.rows[0];
        res.status(200).json({
            id: user.id,
            fullName: user.full_name,
            email: user.email,
            phoneNumber: user.phone_number,
            cin: user.cin,
            isVerified: user.is_verified,
            role: user.role,
            isSuspended: user.is_suspended,
            walletBalance: user.wallet_balance,
            createdAt: user.created_at,
        });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Erreur serveur lors de la récupération du profil.' });
    }
}

async function requestPasswordReset(req, res) {
    const email = normalizeEmail(req.body.email);
    const response = { message: 'If an account matches this email, a reset link has been sent.' };
    if (!isValidEmail(email)) return res.status(200).json(response);

    let client;
    try {
        client = await pool.connect();
        await client.query('BEGIN');
        const userResult = await client.query('SELECT id, email FROM users WHERE email = $1 FOR UPDATE', [email]);
        const user = userResult.rows[0];
        if (!user) {
            await client.query('COMMIT');
            return res.status(200).json(response);
        }

        const reset = createResetToken();
        await client.query('DELETE FROM password_reset_tokens WHERE user_id = $1', [user.id]);
        await client.query(
            `INSERT INTO password_reset_tokens (user_id, token_hash, expires_at)
             VALUES ($1, $2, $3)`,
            [user.id, reset.tokenHash, reset.expiresAt],
        );
        await client.query('COMMIT');
        await sendPasswordResetEmail(user.email, buildResetLink(reset.token));
        return res.status(200).json(response);
    } catch (error) {
        if (client) await client.query('ROLLBACK');
        console.error(error);
        return res.status(500).json({ message: 'Unable to send a password reset link.' });
    } finally {
        client?.release();
    }
}

async function resetPassword(req, res) {
    const token = String(req.body.token || '');
    const password = String(req.body.password || '');
    if (!/^[a-f0-9]{64}$/i.test(token) || password.length < 8) {
        return res.status(400).json({ message: 'Le lien ou le nouveau mot de passe est invalide.' });
    }

    const tokenHash = require('crypto').createHash('sha256').update(token).digest('hex');
    let client;
    try {
        client = await pool.connect();
        await client.query('BEGIN');
        const tokenResult = await client.query(
            `SELECT id, user_id, expires_at, used_at
             FROM password_reset_tokens
             WHERE token_hash = $1
             FOR UPDATE`,
            [tokenHash],
        );
        const reset = tokenResult.rows[0];
        if (!reset || reset.used_at || new Date(reset.expires_at) < new Date()) {
            await client.query('ROLLBACK');
            return res.status(400).json({ message: 'Ce lien de reinitialisation est invalide ou expire.' });
        }

        const passwordHash = await bcrypt.hash(password, 10);
        await client.query('UPDATE users SET password_hash = $1 WHERE id = $2', [passwordHash, reset.user_id]);
        await client.query('UPDATE password_reset_tokens SET used_at = NOW() WHERE id = $1', [reset.id]);
        await client.query('COMMIT');
        return res.status(200).json({ message: 'Mot de passe reinitialise. Vous pouvez vous connecter.' });
    } catch (error) {
        if (client) await client.query('ROLLBACK');
        console.error(error);
        return res.status(500).json({ message: 'Unable to reset password.' });
    } finally {
        client?.release();
    }
}

// On exporte les fonctions pour pouvoir les utiliser dans routes/authRoutes.js
module.exports = { register, verifyOtp, resendOtp, login, getMe, requestPasswordReset, resetPassword };
