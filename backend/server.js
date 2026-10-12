// ============================================================
// server.js — Point d'entrée du backend RentGo Tunisia
// ------------------------------------------------------------
// C'est LE fichier qu'on lance pour démarrer le serveur.
// Il assemble tous les morceaux : middlewares globaux + routes.
// ============================================================

const express = require('express');
const cors = require('cors');
require('dotenv').config();
// Charge le fichier .env et remplit process.env avec son contenu
// (DB_USER, JWT_SECRET, PORT...). Doit être appelé le plus tôt possible.

// On importe la connexion à la base et on attend que les migrations légères
// soient appliquées avant d'accepter les requêtes.
const db = require('./config/db');

// On importe nos 3 groupes de routes
const authRoutes = require('./routes/authRoutes');
const vehicleRoutes = require('./routes/vehicleRoutes');
const rentalRoutes = require('./routes/rentalRoutes');
const walletRoutes = require('./routes/walletRoutes');

const app = express();

// --- Middlewares globaux (s'appliquent à TOUTES les requêtes) ---

app.use(cors({
    origin: true,
    credentials: true,
}));
// Autorise l'app Flutter (qui tourne sur un autre "domaine"/port) à
// appeler cette API sans être bloquée par le navigateur/le système

app.use(express.json());
app.use(express.urlencoded({ extended: true }));
// Permet à Express de comprendre le JSON envoyé dans le corps des
// requêtes (req.body) — indispensable pour lire les données envoyées
// par l'app Flutter (ex: { "phoneNumber": "...", "password": "..." })

// --- Route de test, pour vérifier que le serveur tourne ---
app.get('/', (req, res) => {
    res.send('RentGo Tunisia API is running 🚴');
});

app.get('/api/health', (req, res) => {
    res.status(200).json({ ok: true, service: 'rentgo-tunisia-api' });
});

// --- Branchement des routes ---
// Toutes les routes définies dans authRoutes.js seront accessibles
// sous le préfixe /api/auth (ex: /api/auth/login, /api/auth/register)
app.use('/api/auth', authRoutes);

// Toutes les routes véhicules sous /api/vehicles
app.use('/api/vehicles', vehicleRoutes);

// Toutes les routes locations sous /api/rentals
app.use('/api/rentals', rentalRoutes);

// Wallet : solde, historique et recharge carte / D17 / Sobflous
app.use('/api/wallet', walletRoutes);

// --- Gestion des routes inexistantes (404) ---
// Si aucune route ci-dessus ne correspond, on répond proprement
// au lieu de laisser Express planter avec une erreur brute
app.use((req, res) => {
    res.status(404).json({ message: 'Route non trouvée.' });
});

// --- Démarrage du serveur ---
// 0.0.0.0 permet l'accès depuis Chrome, Flutter Web et un téléphone sur le
// même réseau. L'URL affichée reste localhost pour les tests locaux.
const PORT = Number(process.env.PORT || 3000);
const HOST = process.env.HOST || '0.0.0.0';

let server;

const shutdown = (signal) => {
    console.log(`\nℹ️ ${signal} reçu, arrêt du serveur...`);

    if (!server) {
        process.exit(0);
        return;
    }

    server.close(() => {
        console.log('✅ Serveur HTTP arrêté proprement.');
        process.exit(0);
    });
};

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('unhandledRejection', (reason) => {
    console.error('❌ Promesse rejetée sans gestionnaire:', reason);
});
process.on('uncaughtException', (error) => {
    console.error('❌ Exception non gérée:', error);
    process.exit(1);
});
process.on('beforeExit', (code) => {
    console.error(`⚠️ Node va s'arrêter (code ${code}) : aucune connexion active.`);
});

db.ready.then(() => {
    server = app.listen(PORT, HOST, () => {
        const displayHost = HOST === '0.0.0.0' ? 'localhost' : HOST;
        console.log(`🚀 Server running on port ${PORT}`);
        console.log(`   → http://${displayHost}:${PORT}`);
        console.log('   → Le terminal doit rester occupé pendant que le serveur tourne.');
    });

    server.on('error', (error) => {
        if (error.code === 'EADDRINUSE') {
            console.error(`❌ Le port ${PORT} est déjà utilisé.`);
            console.error('   Vérifiez avec: netstat -ano | findstr :3000');
        } else {
            console.error('❌ Erreur du serveur HTTP:', error);
        }
        process.exit(1);
    });

    server.on('close', () => {
        console.log('ℹ️ La connexion HTTP du serveur est fermée.');
    });
}).catch((error) => {
    console.error('❌ Initialisation de la base impossible:', error);
    process.exit(1);
});
