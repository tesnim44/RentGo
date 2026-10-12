// ============================================================
// controllers/rentalController.js
// ------------------------------------------------------------
// Gère le cœur du métier : démarrer une location (après scan QR),
// la terminer, calculer le prix, et simuler le paiement.
// ============================================================

const pool = require('../config/db');

// --------------------------------------------------------------
// POST /api/rentals/start — Démarrer une location
// --------------------------------------------------------------
// Appelé juste après que l'utilisateur ait scanné le QR code.
// Protégé par le middleware verifyToken donc req.user existe déjà.
async function startRental(req, res) {
    const { vehicleId, latitude, longitude } = req.body;
    const userId = req.user.id; // récupéré depuis le token JWT (voir authMiddleware.js)

    if (!vehicleId) {
        return res.status(400).json({ message: 'vehicleId est obligatoire.' });
    }

    // On utilise un "client" dédié pour pouvoir faire une transaction :
    // soit TOUTES les requêtes ci-dessous réussissent, soit AUCUNE n'est
    // appliquée (évite qu'un véhicule reste bloqué "in_use" sans location liée)
    const client = await pool.connect();

    try {
        await client.query('BEGIN'); // démarre la transaction

        // Un utilisateur ne peut avoir qu'une seule location en cours à la fois.
        const existingRental = await client.query(
            `SELECT id
             FROM rentals
             WHERE user_id = $1 AND status = 'ongoing'
             LIMIT 1`,
            [userId]
        );

        if (existingRental.rows.length > 0) {
            await client.query('ROLLBACK');
            return res.status(409).json({
                message: 'Vous avez déjà une location en cours.',
                rentalId: existingRental.rows[0].id,
            });
        }

        const wallet = await client.query(
            'SELECT wallet_balance FROM users WHERE id = $1 FOR UPDATE',
            [userId]
        );

        if (wallet.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ message: 'Utilisateur introuvable.' });
        }

        if (Number(wallet.rows[0].wallet_balance) <= 0) {
            await client.query('ROLLBACK');
            return res.status(402).json({ message: 'Rechargez votre wallet avant de demarrer une location.' });
        }

        // 1. On vérifie que le véhicule est bien disponible
        const vehicleResult = await client.query(
            'SELECT * FROM vehicles WHERE id = $1 FOR UPDATE',
            // FOR UPDATE : verrouille cette ligne le temps de la transaction,
            // pour éviter que deux utilisateurs louent le même véhicule
            // en même temps (rare mais possible sans ce verrou)
            [vehicleId]
        );

        if (vehicleResult.rows.length === 0) {
            await client.query('ROLLBACK'); // annule la transaction
            return res.status(404).json({ message: 'Véhicule introuvable.' });
        }

        const vehicle = vehicleResult.rows[0];

        if (vehicle.status !== 'available' && !(vehicle.status === 'booked' && vehicle.booked_by_user_id === userId)) {
            await client.query('ROLLBACK');
            return res.status(409).json({ message: 'Ce véhicule n\'est plus disponible.' });
        }

        // 2. On crée la location (rental) avec le statut "ongoing" (en cours)
        const rentalResult = await client.query(
            `INSERT INTO rentals (user_id, vehicle_id, start_latitude, start_longitude, status)
             VALUES ($1, $2, $3, $4, 'ongoing')
             RETURNING *`,
            [userId, vehicleId, latitude || vehicle.latitude, longitude || vehicle.longitude]
        );

        // 3. On passe le véhicule en "in_use" pour qu'il apparaisse comme booked/occupé
        await client.query(
            `UPDATE vehicles
             SET status = $1, booked_by_user_id = NULL, booked_at = NULL
             WHERE id = $2`,
            ['in_use', vehicleId]
        );

        await client.query('COMMIT'); // valide définitivement la transaction

        const rental = {
            ...rentalResult.rows[0],
            vehicle_type: vehicle.type,
            battery_level: vehicle.battery_level,
            vehicle_latitude: vehicle.latitude,
            vehicle_longitude: vehicle.longitude,
            price_per_minute: vehicle.price_per_minute,
        };

        res.status(201).json({
            message: 'Location démarrée avec succès.',
            rental,
            pricePerMinute: vehicle.price_per_minute,
        });
    } catch (error) {
        await client.query('ROLLBACK'); // en cas d'erreur, on annule tout
        console.error(error);
        res.status(500).json({ message: 'Erreur serveur lors du démarrage de la location.' });
    } finally {
        client.release(); // on rend toujours le client au pool, même en cas d'erreur
    }
}

// --------------------------------------------------------------
// POST /api/rentals/:id/end — Terminer une location
// --------------------------------------------------------------
async function endRental(req, res) {
    const { id } = req.params; // id de la location (rental)
    const { latitude, longitude } = req.body;

    const client = await pool.connect();

    try {
        await client.query('BEGIN');

        // On récupère la location en cours
        const rentalResult = await client.query(
            'SELECT * FROM rentals WHERE id = $1 AND user_id = $2 AND status = $3',
            [id, req.user.id, 'ongoing']
        );

        if (rentalResult.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ message: 'Location en cours introuvable.' });
        }

        const rental = rentalResult.rows[0];

        // On récupère le prix par minute du véhicule concerné
        const vehicleResult = await client.query('SELECT price_per_minute FROM vehicles WHERE id = $1', [rental.vehicle_id]);
        if (vehicleResult.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ message: 'Véhicule lié à la location introuvable.' });
        }
        const pricePerMinute = parseFloat(vehicleResult.rows[0].price_per_minute);

        // --- Calcul de la durée et du prix ---
        const startTime = new Date(rental.start_time);
        const endTime = new Date(); // maintenant

        // Différence en millisecondes → convertie en minutes, arrondie au-dessus
        // (on facture la minute entamée, comme les vrais services de trottinettes)
        const durationMs = endTime - startTime;
        const durationMinutes = Math.max(1, Math.ceil(durationMs / 60000));

        const totalPrice = parseFloat((durationMinutes * pricePerMinute).toFixed(3));

        const wallet = await client.query(
            'SELECT wallet_balance FROM users WHERE id = $1 FOR UPDATE',
            [rental.user_id]
        );

        if (wallet.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ message: 'Utilisateur introuvable.' });
        }

        if (Number(wallet.rows[0].wallet_balance) < totalPrice) {
            await client.query('ROLLBACK');
            return res.status(402).json({
                message: 'Solde wallet insuffisant. Rechargez votre wallet pour terminer la location.',
                requiredAmount: totalPrice,
                walletBalance: wallet.rows[0].wallet_balance,
            });
        }

        // 1. On met à jour la location avec les infos finales
        const updatedRental = await client.query(
            `UPDATE rentals
             SET end_time = $1, end_latitude = $2, end_longitude = $3,
                 duration_minutes = $4, total_price = $5, status = 'completed'
             WHERE id = $6
             RETURNING *`,
            [endTime, latitude, longitude, durationMinutes, totalPrice, id]
        );

        // 2. On libère le véhicule (redevient disponible)
        await client.query(
            `UPDATE vehicles
             SET status = 'available', latitude = $1, longitude = $2, booked_by_user_id = NULL, booked_at = NULL
             WHERE id = $3`,
            [latitude || rental.start_latitude, longitude || rental.start_longitude, rental.vehicle_id]
        );

        const updatedWallet = await client.query(
            'UPDATE users SET wallet_balance = wallet_balance - $1 WHERE id = $2 RETURNING wallet_balance',
            [totalPrice, rental.user_id]
        );

        await client.query(
            `INSERT INTO wallet_transactions (user_id, amount, direction, method, status, reference, rental_id)
             VALUES ($1, $2, 'debit', 'wallet', 'success', $3, $4)
             RETURNING *`,
            [rental.user_id, totalPrice, `RIDE-${id}`, id]
        );

        // 3. Paiement obligatoire depuis le wallet RentGo.
        const payment = await client.query(
            `INSERT INTO payments (rental_id, user_id, amount, method, status)
             VALUES ($1, $2, $3, 'wallet', 'success')
             RETURNING *`,
            [id, rental.user_id, totalPrice]
        );

        await client.query('COMMIT');

        res.status(200).json({
            message: 'Location terminée. Paiement wallet effectué.',
            rental: updatedRental.rows[0],
            payment: payment.rows[0],
            walletBalance: updatedWallet.rows[0].wallet_balance,
        });
    } catch (error) {
        await client.query('ROLLBACK');
        console.error(error);
        res.status(500).json({ message: 'Erreur serveur lors de la fin de la location.' });
    } finally {
        client.release();
    }
}

async function recordLocation(req, res) {
    const { id } = req.params;
    const { latitude, longitude } = req.body;
    const userId = req.user.id;

    if (!Number.isFinite(Number(latitude)) || !Number.isFinite(Number(longitude))) {
        return res.status(400).json({ message: 'Coordonnees de position invalides.' });
    }

    try {
        const rentalResult = await pool.query(
            `SELECT id, vehicle_id
             FROM rentals
             WHERE id = $1 AND user_id = $2 AND status = 'ongoing'`,
            [id, userId],
        );
        const rental = rentalResult.rows[0];
        if (!rental) {
            return res.status(404).json({ message: 'Location en cours introuvable.' });
        }

        const locationResult = await pool.query(
            `INSERT INTO rental_locations (rental_id, latitude, longitude)
             VALUES ($1, $2, $3)
             RETURNING latitude, longitude, recorded_at`,
            [id, Number(latitude), Number(longitude)],
        );
        await pool.query(
            'UPDATE vehicles SET latitude = $1, longitude = $2 WHERE id = $3',
            [Number(latitude), Number(longitude), rental.vehicle_id],
        );
        return res.status(201).json({ location: locationResult.rows[0] });
    } catch (error) {
        console.error(error);
        return res.status(500).json({ message: "Erreur serveur lors de l'enregistrement de la position." });
    }
}

// --------------------------------------------------------------
// GET /api/rentals/active — Location en cours de l'utilisateur connecté
// --------------------------------------------------------------
async function getActiveRental(req, res) {
    const userId = req.user.id;

    try {
        const result = await pool.query(
            `SELECT r.*, v.type AS vehicle_type, v.battery_level, v.latitude AS vehicle_latitude,
                    v.longitude AS vehicle_longitude, v.price_per_minute,
                    COALESCE((
                        SELECT json_agg(json_build_object(
                            'latitude', rl.latitude,
                            'longitude', rl.longitude,
                            'recordedAt', rl.recorded_at
                        ) ORDER BY rl.recorded_at)
                        FROM rental_locations rl
                        WHERE rl.rental_id = r.id
                    ), '[]'::json) AS location_track
             FROM rentals r
             JOIN vehicles v ON r.vehicle_id = v.id
             WHERE r.user_id = $1 AND r.status = 'ongoing'
             ORDER BY r.start_time DESC
             LIMIT 1`,
            [userId]
        );

        if (result.rows.length === 0) {
            return res.status(200).json({ rental: null });
        }

        res.status(200).json({ rental: result.rows[0] });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Erreur serveur.' });
    }
}

// --------------------------------------------------------------
// GET /api/rentals/history — Historique des locations de l'utilisateur connecté
// --------------------------------------------------------------
async function getMyRentals(req, res) {
    const userId = req.user.id;

    try {
        const result = await pool.query(
            `SELECT r.*, v.type AS vehicle_type
             FROM rentals r
             JOIN vehicles v ON r.vehicle_id = v.id
             WHERE r.user_id = $1
             ORDER BY r.start_time DESC`,
            [userId]
        );

        res.status(200).json(result.rows);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Erreur serveur.' });
    }
}

module.exports = { startRental, endRental, recordLocation, getMyRentals, getActiveRental };
