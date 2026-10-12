-- ============================================================
-- RentGo Tunisia — Schéma de base de données PostgreSQL
-- ============================================================
-- Comment utiliser ce fichier :
-- 1. Ouvrez pgAdmin (ou psql)
-- 2. Créez une base de données nommée "rentgo_tunisia"
-- 3. Ouvrez le "Query Tool" sur cette base
-- 4. Collez tout ce fichier et exécutez-le (bouton Run / F5)
-- Ça va créer toutes les tables nécessaires au MVP.
-- ============================================================

-- L'extension "pgcrypto" nous permet de générer des identifiants
-- uniques (UUID) automatiquement, plus sûrs que de simples 1, 2, 3...
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ------------------------------------------------------------
-- TABLE 1 : users (les utilisateurs de l'app mobile)
-- ------------------------------------------------------------
-- Le cahier des charges demande une inscription par numéro de
-- téléphone + CIN, avec vérification OTP (code envoyé par SMS).
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- gen_random_uuid() : génère un identifiant unique automatiquement

    full_name       VARCHAR(150) NOT NULL,
    -- Nom complet de l'utilisateur, obligatoire (NOT NULL)

    phone_number    VARCHAR(20) UNIQUE NOT NULL,
    -- Numéro de téléphone tunisien, ex: +21612345678
    -- UNIQUE = deux utilisateurs ne peuvent pas avoir le même numéro

    cin             VARCHAR(20) UNIQUE,
    -- Carte d'Identité Nationale, pour vérifier l'identité (optionnel au départ)

    password_hash   VARCHAR(255) NOT NULL,
    -- On ne stocke JAMAIS un mot de passe en clair, seulement sa version
    -- "hachée" (chiffrée à sens unique) via bcrypt

    is_verified     BOOLEAN DEFAULT FALSE,
    -- Devient TRUE une fois que l'utilisateur a validé son code OTP

    role            VARCHAR(20) DEFAULT 'user' CHECK (role IN ('user', 'admin')),
    -- Permet de distinguer un utilisateur normal d'un administrateur
    -- CHECK garantit que la valeur est soit 'user' soit 'admin', rien d'autre

    is_suspended    BOOLEAN DEFAULT FALSE,
    -- L'admin peut suspendre un compte (mentionné dans le dashboard admin)

    created_at      TIMESTAMP DEFAULT NOW()
    -- Date de création automatique du compte
);

-- ------------------------------------------------------------
-- TABLE 2 : otp_codes (les codes de vérification par SMS)
-- ------------------------------------------------------------
-- Table séparée pour stocker temporairement les hash OTP envoyés
CREATE TABLE otp_codes (
    phone_number    VARCHAR(20) PRIMARY KEY,
    otp_hash        TEXT NOT NULL,
    expires_at      TIMESTAMPTZ NOT NULL,
    -- Le code n'est valable que quelques minutes

    attempts        INTEGER NOT NULL DEFAULT 0,
    code            TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------
-- TABLE 3 : vehicles (les vélos et trottinettes du parc)
-- ------------------------------------------------------------
CREATE TABLE vehicles (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    type            VARCHAR(20) NOT NULL CHECK (type IN ('bike', 'scooter')),
    -- 'bike' = vélo électrique, 'scooter' = trottinette électrique

    qr_code         VARCHAR(100) UNIQUE NOT NULL,
    -- Le code unique scanné pour déverrouiller le véhicule

    status          VARCHAR(20) DEFAULT 'available'
                    CHECK (status IN ('available', 'in_use', 'maintenance', 'offline')),
    -- available = libre, in_use = en cours de location,
    -- maintenance = en panne signalée, offline = désactivé par l'admin

    battery_level   INTEGER DEFAULT 100 CHECK (battery_level BETWEEN 0 AND 100),
    -- Niveau de batterie en pourcentage

    latitude        DECIMAL(10, 8) NOT NULL,
    longitude       DECIMAL(11, 8) NOT NULL,
    -- Position actuelle du véhicule sur la carte (OpenStreetMap / Flutter)

    price_per_minute DECIMAL(6, 3) DEFAULT 0.150,
    -- Tarif en Dinars Tunisiens par minute (exemple : 0.150 TND/min)

    created_at      TIMESTAMP DEFAULT NOW()
);

-- ------------------------------------------------------------
-- TABLE 4 : rentals (les locations / trajets)
-- ------------------------------------------------------------
CREATE TABLE rentals (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    -- REFERENCES = lien vers la table users (clé étrangère)
    -- ON DELETE CASCADE = si l'utilisateur est supprimé, ses locations le sont aussi

    vehicle_id      UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,

    start_time      TIMESTAMP DEFAULT NOW(),
    end_time        TIMESTAMP,
    -- NULL tant que le trajet n'est pas terminé

    start_latitude  DECIMAL(10, 8),
    start_longitude DECIMAL(11, 8),
    end_latitude    DECIMAL(10, 8),
    end_longitude   DECIMAL(11, 8),
    -- Position de début et de fin du trajet

    duration_minutes INTEGER,
    -- Calculé quand le trajet se termine

    total_price     DECIMAL(8, 3),
    -- Prix final calculé à la fin du trajet

    status          VARCHAR(20) DEFAULT 'ongoing'
                    CHECK (status IN ('ongoing', 'completed', 'cancelled')),

    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE TABLE rental_locations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rental_id       UUID NOT NULL REFERENCES rentals(id) ON DELETE CASCADE,
    latitude        DECIMAL(10, 8) NOT NULL,
    longitude       DECIMAL(11, 8) NOT NULL,
    recorded_at     TIMESTAMP DEFAULT NOW()
);

CREATE TABLE password_reset_tokens (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash      CHAR(64) UNIQUE NOT NULL,
    expires_at      TIMESTAMPTZ NOT NULL,
    used_at         TIMESTAMPTZ
);

-- ------------------------------------------------------------
-- TABLE 5 : payments (paiements simulés)
-- ------------------------------------------------------------
CREATE TABLE payments (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rental_id       UUID NOT NULL REFERENCES rentals(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    amount          DECIMAL(8, 3) NOT NULL,
    method          VARCHAR(30) DEFAULT 'wallet',
    -- Paiement de trajet uniquement via wallet. Recharge : 'card', 'd17', 'sobflous'.

    status          VARCHAR(20) DEFAULT 'success'
                    CHECK (status IN ('pending', 'success', 'failed')),

    created_at      TIMESTAMP DEFAULT NOW()
);

-- ------------------------------------------------------------
-- TABLE 6 : issue_reports (signalement de panne — fonctionnalité bonus)
-- ------------------------------------------------------------
CREATE TABLE issue_reports (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    vehicle_id      UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,

    description     TEXT,
    photo_url       VARCHAR(255),

    status          VARCHAR(20) DEFAULT 'open' CHECK (status IN ('open', 'resolved')),
    created_at      TIMESTAMP DEFAULT NOW()
);

-- ------------------------------------------------------------
-- Index : accélèrent les recherches fréquentes
-- ------------------------------------------------------------
CREATE INDEX idx_vehicles_status ON vehicles(status);
CREATE INDEX idx_rentals_user ON rentals(user_id);
CREATE INDEX idx_rentals_status ON rentals(status);

-- ------------------------------------------------------------
-- Données de test (pour voir des véhicules tout de suite sur la carte)
-- Coordonnées autour de Sousse, Tunisie
-- ------------------------------------------------------------
INSERT INTO vehicles (type, qr_code, status, battery_level, latitude, longitude, price_per_minute)
VALUES
('bike',    'RG-BIKE-001',    'available', 95, 35.82539, 10.63699, 0.150),
('bike',    'RG-BIKE-002',    'available', 80, 35.83718, 10.62147, 0.150),
('scooter', 'RG-SCOOTER-001', 'available', 60, 35.84117, 10.62265, 0.200),
('scooter', 'RG-SCOOTER-002', 'available', 40, 35.89259, 10.59434, 0.200),
('bike',    'RG-BIKE-003',    'available', 76, 35.83070, 10.63280, 0.150),
('bike',    'RG-BIKE-004',    'available', 64, 35.82340, 10.63950, 0.150),
('bike',    'RG-BIKE-005',    'available', 91, 35.82010, 10.63470, 0.150),
('scooter', 'RG-TR-042',      'available', 82, 35.82660, 10.64490, 0.900),
('scooter', 'RG-SCOOTER-003', 'available', 57, 35.82160, 10.64870, 0.200),
('scooter', 'RG-SCOOTER-004', 'available', 88, 35.81640, 10.64220, 0.200);
