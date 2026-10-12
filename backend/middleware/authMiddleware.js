// ============================================================
// middleware/authMiddleware.js
// ------------------------------------------------------------
// Un "middleware" est une fonction qui s'exécute AVANT d'arriver
// à la vraie route. Ici, son rôle : vérifier que la personne qui
// fait la requête est bien connectée (via un token JWT valide),
// avant de la laisser accéder à des routes protégées
// (ex: "commencer une location", "voir mon historique").
//
// Sans ce middleware, n'importe qui pourrait appeler votre API
// en prétendant être n'importe quel utilisateur.
// ============================================================

const jwt = require('jsonwebtoken');
const JWT_SECRET = process.env.JWT_SECRET || 'rentgo-tunisia-dev-secret';

// Cette fonction sera "branchée" devant les routes qui doivent
// être protégées. Exemple d'utilisation dans une route :
//   router.post('/rentals/start', verifyToken, startRental);
// Ici, verifyToken s'exécute AVANT startRental.
function verifyToken(req, res, next) {
    // Le token est envoyé par le client (l'app Flutter) dans l'en-tête
    // HTTP "Authorization", sous la forme : "Bearer eyJhbGciOi..."
    const authHeader = req.headers['authorization'];

    if (!authHeader) {
        // Pas de token du tout → accès refusé
        return res.status(401).json({ message: 'Accès refusé : aucun token fourni.' });
    }

    // On découpe "Bearer eyJhbGciOi..." pour ne garder que le token
    const token = authHeader.split(' ')[1];

    if (!token) {
        return res.status(401).json({ message: 'Format du token invalide.' });
    }

    try {
        // jwt.verify() vérifie que le token est authentique et n'a pas expiré,
        // en le comparant avec notre clé secrète (JWT_SECRET dans .env).
        const decoded = jwt.verify(token, JWT_SECRET);

        // Si tout est bon, on attache les infos de l'utilisateur (id, role...)
        // à l'objet "req", pour que les routes suivantes sachent QUI fait la requête.
        req.user = decoded;

        // next() = "tout est bon, continue vers la vraie route"
        next();
    } catch (error) {
        // Le token est invalide ou expiré
        return res.status(403).json({ message: 'Token invalide ou expiré.' });
    }
}

// Middleware supplémentaire : vérifie que l'utilisateur est bien un admin
// (utilisé pour protéger les routes du dashboard administrateur)
function verifyAdmin(req, res, next) {
    // On suppose que verifyToken a déjà été exécuté avant (donc req.user existe)
    if (req.user && req.user.role === 'admin') {
        next();
    } else {
        return res.status(403).json({ message: 'Accès réservé aux administrateurs.' });
    }
}

module.exports = { verifyToken, verifyAdmin };
