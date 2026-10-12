const express = require('express');
const router = express.Router();

const { startRental, endRental, recordLocation, getMyRentals, getActiveRental } = require('../controllers/rentalController');
const { verifyToken } = require('../middleware/authMiddleware');

// Toutes les routes ci-dessous nécessitent d'être connecté (verifyToken)

// POST /api/rentals/start — démarrer une location après scan QR
router.post('/start', verifyToken, startRental);

// POST /api/rentals/:id/end — terminer une location en cours
router.post('/:id/end', verifyToken, endRental);
router.post('/:id/locations', verifyToken, recordLocation);

// GET /api/rentals/active — location en cours de l'utilisateur connecté
router.get('/active', verifyToken, getActiveRental);

// GET /api/rentals/history — historique des locations de l'utilisateur connecté
router.get('/history', verifyToken, getMyRentals);

module.exports = router;
