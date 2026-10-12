# RentGo Tunisia — Backend

## Structure du dossier

```
backend/
├── config/
│   └── db.js               → connexion à PostgreSQL
├── controllers/
│   ├── authController.js   → inscription, OTP, connexion
│   ├── vehicleController.js→ liste/détail des véhicules
│   └── rentalController.js → démarrer/terminer une location
├── routes/
│   ├── authRoutes.js       → URLs /api/auth/...
│   ├── vehicleRoutes.js    → URLs /api/vehicles/...
│   └── rentalRoutes.js     → URLs /api/rentals/...
├── middleware/
│   └── authMiddleware.js   → vérifie le token JWT (protège les routes)
├── database/
│   └── schema.sql          → toutes les tables PostgreSQL
├── .env.example            → modèle de configuration (à copier en .env)
├── server.js                → point d'entrée du serveur
└── package.json
```

## Installation (à faire une seule fois, chaque membre de l'équipe)

```bash
cd backend
npm install
```

## Configuration de la base de données

1. Ouvrez pgAdmin (ou psql)
2. Créez une base nommée `rentgo_tunisia`
3. Ouvrez le Query Tool sur cette base, collez le contenu de
   `database/schema.sql`, puis exécutez (F5)
4. Copiez `.env.example` en `.env` et remplissez vos identifiants
   PostgreSQL locaux (voir les commentaires dans le fichier)
5. Pour envoyer de vrais OTP par SMS, remplissez aussi :
   - `TWILIO_ACCOUNT_SID`
   - `TWILIO_AUTH_TOKEN`
   - `TWILIO_FROM_NUMBER`

Si ces variables Twilio ne sont pas définies, le backend garde un
fallback console pour le développement local.

Pour les liens de réinitialisation de mot de passe, configurez :
- `WEB_APP_URL` : URL publique de l'application Flutter Web
- `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_FROM`
  (les anciens noms `SMTP_*` restent également acceptés)

Sans SMTP, le lien est affiché dans la console du backend uniquement en développement.

## Lancer le serveur

En développement (redémarre automatiquement à chaque modification) :
```bash
npm run dev
```

En "production" simple :
```bash
npm start
```

Le serveur démarre sur `http://localhost:3000` (ou le PORT choisi
dans `.env`).

## Tester les routes (avec Postman ou Thunder Client)

| Méthode | URL                                  | Description                          | Auth requise |
|---------|---------------------------------------|---------------------------------------|:---:|
| POST    | `/api/auth/register`                  | Inscription                          | Non |
| POST    | `/api/auth/verify-otp`                | Valider le code reçu (voir console)  | Non |
| POST    | `/api/auth/resend-otp`                | Renvoyer un nouveau code OTP        | Non |
| POST    | `/api/auth/login`                     | Connexion → renvoie un token         | Non |
| POST    | `/api/auth/forgot-password`           | Envoie un lien de réinitialisation   | Non |
| POST    | `/api/auth/reset-password`            | Applique un nouveau mot de passe     | Non |
| GET     | `/api/vehicles`                       | Liste des véhicules disponibles      | Oui |
| GET     | `/api/vehicles/:id`                   | Détail d'un véhicule                 | Oui |
| GET     | `/api/vehicles/qr/:qrCode`            | Trouver un véhicule par QR code      | Oui |
| POST    | `/api/vehicles/:id/cancel-reservation`| Annuler sa propre réservation        | Oui |
| POST    | `/api/rentals/start`                  | Démarrer une location                | Oui |
| POST    | `/api/rentals/:id/locations`          | Enregistrer une position du trajet   | Oui |
| POST    | `/api/rentals/:id/end`                | Terminer une location                | Oui |
| GET     | `/api/rentals/history`                | Historique de mes locations          | Oui |

**Auth requise** = ajoutez un en-tête `Authorization: Bearer <token>`
avec le token reçu lors du login.

### Exemple rapide avec curl

```bash
# 1. Inscription
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"fullName":"Test User","phoneNumber":"+21612345678","email":"test@example.com","password":"motdepasse123"}'

# → regardez la console du serveur : le code OTP y est affiché (simulation)

# 2. Vérification OTP (remplacez 123456 par le vrai code affiché)
curl -X POST http://localhost:3000/api/auth/verify-otp \
  -H "Content-Type: application/json" \
  -d '{"phoneNumber":"+21612345678","code":"123456"}'

# 3. Connexion
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"phoneNumber":"+21612345678","password":"motdepasse123"}'

# → copiez le "token" reçu dans la réponse

# 4. Voir les véhicules disponibles (remplacez VOTRE_TOKEN)
curl http://localhost:3000/api/vehicles \
  -H "Authorization: Bearer VOTRE_TOKEN"
```

## Prochaines étapes possibles

- Ajouter les routes admin (dashboard : gestion parc, utilisateurs, stats)
- Ajouter la route de signalement de panne (`issue_reports`)
- Brancher un vrai service SMS pour l'OTP (ex: Twilio) au lieu de la simulation
