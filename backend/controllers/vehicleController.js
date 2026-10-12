// ============================================================
// controllers/vehicleController.js
// ------------------------------------------------------------
// Gère tout ce qui concerne les véhicules : les lister pour les
// afficher sur la carte, voir le détail d'un véhicule, et (côté
// admin) en ajouter/modifier.
// ============================================================

const pool = require('../config/db');

// --------------------------------------------------------------
// GET /api/vehicles — Liste de tous les véhicules visibles
// --------------------------------------------------------------
// C'est cette route que l'app Flutter appelle pour afficher les
// pins (marqueurs) sur la carte.
async function getAllVehicles(req, res) {
    try {
        const result = await pool.query(
            `SELECT id, type, qr_code, status, battery_level, latitude, longitude, price_per_minute, booked_by_user_id
             FROM vehicles
             WHERE status != $1
             ORDER BY created_at DESC`
            , ['offline']
        );

        res.status(200).json(result.rows);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Erreur serveur lors de la récupération des véhicules.' });
    }
}

// --------------------------------------------------------------
// GET /api/vehicles/:id — Détail d'un véhicule précis
// --------------------------------------------------------------
async function getVehicleById(req, res) {
    // req.params.id vient de l'URL, ex: /api/vehicles/abc-123
    const { id } = req.params;

    try {
        const result = await pool.query('SELECT * FROM vehicles WHERE id = $1', [id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ message: 'Véhicule introuvable.' });
        }

        res.status(200).json(result.rows[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Erreur serveur.' });
    }
}

// --------------------------------------------------------------
// GET /api/vehicles/qr/:qrCode — Trouver un véhicule par son QR code
// --------------------------------------------------------------
// Utilisé juste après le scan du QR code dans l'app, pour vérifier
// que le véhicule existe et qu'il est bien disponible avant de
// démarrer une location.
async function getVehicleByQrCode(req, res) {
    const { qrCode } = req.params;

    try {
        const result = await pool.query('SELECT * FROM vehicles WHERE qr_code = $1', [qrCode]);

        if (result.rows.length === 0) {
            return res.status(404).json({ message: 'QR code non reconnu.' });
        }

        const vehicle = result.rows[0];

        if (vehicle.status !== 'available' && vehicle.booked_by_user_id !== req.user.id) {
            return res.status(409).json({ message: 'Ce véhicule n\'est pas disponible actuellement.' });
        }

        res.status(200).json(vehicle);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Erreur serveur.' });
    }
}

async function reserveVehicle(req, res) {
    const { id } = req.params;
    const userId = req.user.id;
    const client = await pool.connect();

    try {
        await client.query('BEGIN');

        const wallet = await client.query(
            'SELECT wallet_balance FROM users WHERE id = $1 FOR UPDATE',
            [userId],
        );

        if (wallet.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ message: 'Utilisateur introuvable.' });
        }

        if (Number(wallet.rows[0].wallet_balance) <= 0) {
            await client.query('ROLLBACK');
            return res.status(402).json({ message: 'Rechargez votre wallet avant de reserver un vehicule.' });
        }

        const vehicleResult = await client.query('SELECT * FROM vehicles WHERE id = $1 FOR UPDATE', [id]);

        if (vehicleResult.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ message: 'Véhicule introuvable.' });
        }

        const vehicle = vehicleResult.rows[0];

        if (vehicle.status !== 'available') {
            await client.query('ROLLBACK');
            return res.status(409).json({ message: 'Ce véhicule n\'est plus disponible.' });
        }

        const updated = await client.query(
            `UPDATE vehicles
             SET status = 'booked', booked_by_user_id = $1, booked_at = $2
             WHERE id = $3
             RETURNING *`,
            [userId, new Date(), id],
        );

        await client.query('COMMIT');

        return res.status(200).json({
            message: 'Vehicule reserve.',
            vehicle: updated.rows[0],
        });
    } catch (error) {
        await client.query('ROLLBACK');
        console.error(error);
        return res.status(500).json({ message: 'Erreur serveur lors de la reservation.' });
    } finally {
        client.release();
    }
}

async function cancelReservation(req, res) {
    const { id } = req.params;
    const userId = req.user.id;
    const client = await pool.connect();

    try {
        await client.query('BEGIN');
        const result = await client.query('SELECT * FROM vehicles WHERE id = $1 FOR UPDATE', [id]);
        const vehicle = result.rows[0];

        if (!vehicle) {
            await client.query('ROLLBACK');
            return res.status(404).json({ message: 'Vehicule introuvable.' });
        }
        if (vehicle.status !== 'booked' || vehicle.booked_by_user_id !== userId) {
            await client.query('ROLLBACK');
            return res.status(403).json({ message: 'Seule votre reservation peut etre annulee.' });
        }

        const updated = await client.query(
            `UPDATE vehicles
             SET status = 'available', booked_by_user_id = NULL, booked_at = NULL
             WHERE id = $1
             RETURNING *`,
            [id],
        );
        await client.query('COMMIT');
        return res.status(200).json({ message: 'Reservation annulee.', vehicle: updated.rows[0] });
    } catch (error) {
        await client.query('ROLLBACK');
        console.error(error);
        return res.status(500).json({ message: "Erreur serveur lors de l'annulation." });
    } finally {
        client.release();
    }
}

module.exports = { getAllVehicles, getVehicleById, getVehicleByQrCode, reserveVehicle, cancelReservation };
