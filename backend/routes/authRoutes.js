const express = require('express');
const router = express.Router();

const { register, verifyOtp, resendOtp, login, getMe, requestPasswordReset, resetPassword } = require('../controllers/authController');
const { verifyToken } = require('../middleware/authMiddleware');

router.post('/register', register);

// POST /api/auth/verify-otp
router.post('/verify-otp', verifyOtp);

// POST /api/auth/resend-otp
router.post('/resend-otp', resendOtp);

// POST /api/auth/login
router.post('/login', login);
router.post('/forgot-password', requestPasswordReset);
router.post('/reset-password', resetPassword);

// GET /api/auth/me
router.get('/me', verifyToken, getMe);

module.exports = router;
