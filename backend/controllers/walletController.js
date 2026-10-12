const { randomUUID } = require('crypto');

const pool = require('../config/db');

const TOP_UP_METHODS = new Set(['card', 'd17', 'sobflous']);
const TOP_UP_ALIASES = {
    carte: 'card',
    sobflus: 'sobflous',
    flouci: 'sobflous',
};

function parseAmount(value) {
    const amount = Number(value);
    if (!Number.isFinite(amount)) return null;
    return Number(amount.toFixed(3));
}

async function topUpWallet(req, res) {
    const userId = req.user.id;
    const amount = parseAmount(req.body.amount);
    let method = String(req.body.method || '').trim().toLowerCase();
    method = TOP_UP_ALIASES[method] || method;

    if (!amount || amount <= 0) {
        return res.status(400).json({ message: 'Montant invalide.' });
    }

    if (!TOP_UP_METHODS.has(method)) {
        return res.status(400).json({ message: 'Methode de recharge invalide.' });
    }

    const client = await pool.connect();

    try {
        await client.query('BEGIN');

        const updated = await client.query(
            'UPDATE users SET wallet_balance = wallet_balance + $1 WHERE id = $2 RETURNING wallet_balance',
            [amount, userId],
        );

        if (updated.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ message: 'Utilisateur introuvable.' });
        }

        const reference = `${method.toUpperCase()}-${randomUUID()}`;
        const transaction = await client.query(
            `INSERT INTO wallet_transactions (user_id, amount, direction, method, status, reference)
             VALUES ($1, $2, 'credit', $3, 'success', $4)
             RETURNING *`,
            [userId, amount, method, reference],
        );

        await client.query('COMMIT');

        return res.status(200).json({
            message: 'Wallet recharge avec succes.',
            walletBalance: updated.rows[0].wallet_balance,
            transaction: transaction.rows[0],
        });
    } catch (error) {
        await client.query('ROLLBACK');
        console.error(error);
        return res.status(500).json({ message: 'Erreur serveur lors de la recharge wallet.' });
    } finally {
        client.release();
    }
}

async function getWallet(req, res) {
    try {
        const result = await pool.query(
            `SELECT id, wallet_balance
             FROM users
             WHERE id = $1`,
            [req.user.id],
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ message: 'Utilisateur introuvable.' });
        }

        const transactions = await pool.query(
            `SELECT id, amount, direction, method, status, reference, rental_id, created_at
             FROM wallet_transactions
             WHERE user_id = $1
             ORDER BY created_at DESC
             LIMIT 30`,
            [req.user.id],
        );

        return res.status(200).json({
            walletBalance: result.rows[0].wallet_balance,
            transactions: transactions.rows,
        });
    } catch (error) {
        console.error(error);
        return res.status(500).json({ message: 'Erreur serveur lors de la lecture wallet.' });
    }
}

module.exports = { getWallet, topUpWallet };
