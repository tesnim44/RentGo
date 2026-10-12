const express = require('express');
const router = express.Router();

const { getWallet, topUpWallet } = require('../controllers/walletController');
const { verifyToken } = require('../middleware/authMiddleware');

router.get('/', verifyToken, getWallet);
router.post('/top-up', verifyToken, topUpWallet);

module.exports = router;
