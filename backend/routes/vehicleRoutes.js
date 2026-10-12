const express = require('express');
const router = express.Router();

const { getAllVehicles, getVehicleById, getVehicleByQrCode, reserveVehicle, cancelReservation } = require('../controllers/vehicleController');
const { verifyToken } = require('../middleware/authMiddleware');

// GET /api/vehicles — liste des véhicules disponibles (pour la carte)

router.get('/', verifyToken, getAllVehicles);

router.get('/qr/:qrCode', verifyToken, getVehicleByQrCode);

// GET /api/vehicles/:id — détail d'un véhicule précis
router.get('/:id', verifyToken, getVehicleById);

// POST /api/vehicles/:id/reserve — réserver un véhicule (statut booked)
router.post('/:id/reserve', verifyToken, reserveVehicle);
router.post('/:id/cancel-reservation', verifyToken, cancelReservation);

module.exports = router;
