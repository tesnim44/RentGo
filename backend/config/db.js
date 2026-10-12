// ============================================================
// config/db.js
// ------------------------------------------------------------
// Essaie d'abord de se connecter à PostgreSQL.
// Si PostgreSQL n'est pas disponible localement, bascule sur un
// backend mémoire pour garder l'application exécutable.
// ============================================================

const { Pool } = require('pg');
const { randomUUID } = require('crypto');
const bcrypt = require('bcrypt');

const DEMO_ADMIN = {
    fullName: process.env.DEMO_ADMIN_NAME || 'RentGo Administrator',
    email: process.env.DEMO_ADMIN_EMAIL || 'admin@rentgo.tn',
    phoneNumber: process.env.DEMO_ADMIN_PHONE || '+21620123456',
    password: process.env.DEMO_ADMIN_PASSWORD || 'RentGoAdmin2026!',
};

const DEFAULT_SEED_VEHICLES = [
    {
        id: randomUUID(),
        type: 'bike',
        qr_code: 'RG-BIKE-001',
        status: 'available',
        battery_level: 95,
        latitude: 35.82539,
        longitude: 10.63699,
        price_per_minute: 0.15,
        booked_by_user_id: null,
        booked_at: null,
        created_at: new Date(),
    },
    {
        id: randomUUID(),
        type: 'bike',
        qr_code: 'RG-BIKE-002',
        status: 'available',
        battery_level: 80,
        latitude: 35.83718,
        longitude: 10.62147,
        price_per_minute: 0.15,
        created_at: new Date(),
    },
    {
        id: randomUUID(),
        type: 'scooter',
        qr_code: 'RG-SCOOTER-001',
        status: 'available',
        battery_level: 60,
        latitude: 35.84117,
        longitude: 10.62265,
        price_per_minute: 0.2,
        created_at: new Date(),
    },
    {
        id: randomUUID(),
        type: 'scooter',
        qr_code: 'RG-SCOOTER-002',
        status: 'available',
        battery_level: 40,
        latitude: 35.89259,
        longitude: 10.59434,
        price_per_minute: 0.2,
        created_at: new Date(),
    },
    {
        id: randomUUID(),
        type: 'bike',
        qr_code: 'RG-BIKE-003',
        status: 'available',
        battery_level: 76,
        latitude: 35.8307,
        longitude: 10.6328,
        price_per_minute: 0.15,
        created_at: new Date(),
    },
    {
        id: randomUUID(),
        type: 'bike',
        qr_code: 'RG-BIKE-004',
        status: 'available',
        battery_level: 64,
        latitude: 35.8234,
        longitude: 10.6395,
        price_per_minute: 0.15,
        created_at: new Date(),
    },
    {
        id: randomUUID(),
        type: 'bike',
        qr_code: 'RG-BIKE-005',
        status: 'available',
        battery_level: 91,
        latitude: 35.8201,
        longitude: 10.6347,
        price_per_minute: 0.15,
        created_at: new Date(),
    },
    {
        id: randomUUID(),
        type: 'scooter',
        qr_code: 'RG-TR-042',
        status: 'available',
        battery_level: 82,
        latitude: 35.8266,
        longitude: 10.6449,
        price_per_minute: 0.9,
        created_at: new Date(),
    },
    {
        id: randomUUID(),
        type: 'scooter',
        qr_code: 'RG-SCOOTER-003',
        status: 'available',
        battery_level: 57,
        latitude: 35.8216,
        longitude: 10.6487,
        price_per_minute: 0.2,
        created_at: new Date(),
    },
    {
        id: randomUUID(),
        type: 'scooter',
        qr_code: 'RG-SCOOTER-004',
        status: 'available',
        battery_level: 88,
        latitude: 35.8164,
        longitude: 10.6422,
        price_per_minute: 0.2,
        created_at: new Date(),
    },
];

function clone(value) {
    return structuredClone(value);
}

function normalizeSql(sql) {
    return sql.replace(/\s+/g, ' ').trim().toLowerCase();
}

function rowPick(row, columns) {
    const picked = {};
    for (const column of columns) {
        picked[column] = row[column];
    }
    return picked;
}

class MockClient {
    constructor(db) {
        this.db = db;
        this.snapshot = null;
    }

    async query(sql, params = []) {
        return this.db._execute(sql, params, this);
    }

    release() {
        return undefined;
    }
}

class MockDatabase {
    constructor() {
        this.state = {
            users: [],
            otp_codes: [],
            password_reset_tokens: [],
            vehicles: clone(DEFAULT_SEED_VEHICLES),
            rentals: [],
            rental_locations: [],
            payments: [],
            wallet_transactions: [],
            issue_reports: [],
        };
    }

    async connect() {
        return new MockClient(this);
    }

    async query(sql, params = []) {
        return this._execute(sql, params, null);
    }

    _execute(sql, params, client) {
        const q = normalizeSql(sql);

        if (q.startsWith('begin')) {
            if (client) {
                client.snapshot = clone(this.state);
            }
            return { rows: [] };
        }

        if (q.startsWith('commit')) {
            if (client) {
                client.snapshot = null;
            }
            return { rows: [] };
        }

        if (q.startsWith('rollback')) {
            if (client?.snapshot) {
                this.state = client.snapshot;
                client.snapshot = null;
            }
            return { rows: [] };
        }

        if (q === 'select id from users where phone_number = $1') {
            const [phoneNumber] = params;
            const rows = this.state.users
                .filter((user) => user.phone_number === phoneNumber)
                .map((user) => ({ id: user.id }));
            return { rows };
        }

        if (q === 'select id, is_verified, phone_number, email from users where phone_number = $1 or email = $2 for update') {
            const [phoneNumber, email] = params;
            const rows = this.state.users
                .filter((user) => user.phone_number === phoneNumber || user.email === email)
                .map((user) => ({
                    id: user.id,
                    is_verified: user.is_verified,
                    phone_number: user.phone_number,
                    email: user.email,
                }));
            return { rows };
        }

        if (q === 'select id, email, is_verified from users where phone_number = $1') {
            const [phoneNumber] = params;
            const rows = this.state.users
                .filter((user) => user.phone_number === phoneNumber)
                .map((user) => ({
                    id: user.id,
                    email: user.email,
                    is_verified: user.is_verified,
                }));
            return { rows };
        }

        if (q === 'select id, email from users where email = $1 for update') {
            const [email] = params;
            const user = this.state.users.find((item) => item.email === email);
            return { rows: user ? [{ id: user.id, email: user.email }] : [] };
        }

        if (q === 'delete from password_reset_tokens where user_id = $1') {
            const [userId] = params;
            this.state.password_reset_tokens = this.state.password_reset_tokens
                .filter((item) => item.user_id !== userId);
            return { rows: [] };
        }

        if (q.startsWith('insert into password_reset_tokens (user_id, token_hash, expires_at)')) {
            const [userId, tokenHash, expiresAt] = params;
            this.state.password_reset_tokens.push({
                id: randomUUID(),
                user_id: userId,
                token_hash: tokenHash,
                expires_at: new Date(expiresAt),
                used_at: null,
            });
            return { rows: [] };
        }

        if (q.startsWith('select id, user_id, expires_at, used_at from password_reset_tokens where token_hash = $1')) {
            const [tokenHash] = params;
            const reset = this.state.password_reset_tokens.find((item) => item.token_hash === tokenHash);
            return { rows: reset ? [clone(reset)] : [] };
        }

        if (q === 'update users set password_hash = $1 where id = $2') {
            const [passwordHash, id] = params;
            const user = this.state.users.find((item) => item.id === id);
            if (user) user.password_hash = passwordHash;
            return { rows: [] };
        }

        if (q.startsWith('update password_reset_tokens set used_at = now() where id = $1')) {
            const [id] = params;
            const reset = this.state.password_reset_tokens.find((item) => item.id === id);
            if (reset) reset.used_at = new Date();
            return { rows: [] };
        }

        if (q.startsWith('insert into users (full_name, email, phone_number, cin, password_hash)')) {
            const [fullName, email, phoneNumber, cin, passwordHash] = params;
            const user = {
                id: randomUUID(),
                full_name: fullName,
                email,
                phone_number: phoneNumber,
                cin: cin ?? null,
                password_hash: passwordHash,
                is_verified: false,
                role: 'user',
                is_suspended: false,
                wallet_balance: 0,
                created_at: new Date(),
            };
            this.state.users.push(user);
            return {
                rows: [
                    {
                        id: user.id,
                        full_name: user.full_name,
                        email: user.email,
                        phone_number: user.phone_number,
                        is_verified: user.is_verified,
                    },
                ],
            };
        }

        if (q.startsWith('update users set full_name = $1, email = $2, cin = $3, password_hash = $4')) {
            const [fullName, email, cin, passwordHash, phoneNumber] = params;
            const user = this.state.users.find((item) => item.phone_number === phoneNumber && !item.is_verified);
            if (!user) {
                return { rows: [] };
            }
            user.full_name = fullName;
            user.email = email;
            user.cin = cin ?? null;
            user.password_hash = passwordHash;
            return {
                rows: [
                    {
                        id: user.id,
                        full_name: user.full_name,
                        email: user.email,
                        phone_number: user.phone_number,
                        is_verified: user.is_verified,
                    },
                ],
            };
        }

        if (q.startsWith('insert into otp_codes (phone_number, email, otp_hash, expires_at, attempts, code)') ||
            q.startsWith('insert into otp_codes (phone_number, otp_hash, expires_at, attempts, code)')) {
            const hasEmail = q.includes('(phone_number, email,');
            const [phoneNumber, ...values] = params;
            const email = hasEmail ? values[0] : null;
            const otpHash = hasEmail ? values[1] : values[0];
            const expiresAt = hasEmail ? values[2] : values[1];
            const existing = this.state.otp_codes.find((otp) => otp.phone_number === phoneNumber);
            const otp = existing || {
                id: randomUUID(),
                phone_number: phoneNumber,
                created_at: new Date(),
            };
            otp.email = email;
            otp.otp_hash = otpHash;
            otp.expires_at = new Date(expiresAt);
            otp.attempts = 0;
            otp.code = null;
            otp.created_at = new Date();
            if (!existing) {
                this.state.otp_codes.push(otp);
            }
            return { rows: [] };
        }

        if (q === 'delete from otp_codes where phone_number = $1') {
            const [phoneNumber] = params;
            this.state.otp_codes = this.state.otp_codes.filter((otp) => otp.phone_number !== phoneNumber);
            return { rows: [] };
        }

        if (q.startsWith('select phone_number, otp_hash, expires_at, attempts from otp_codes where phone_number = $1')) {
            const [phoneNumber] = params;
            const otp = this.state.otp_codes.find((item) => item.phone_number === phoneNumber);
            return { rows: otp ? [clone(otp)] : [] };
        }

        if (q === 'update otp_codes set attempts = attempts + 1 where phone_number = $1') {
            const [phoneNumber] = params;
            const otp = this.state.otp_codes.find((item) => item.phone_number === phoneNumber);
            if (otp) {
                otp.attempts = (otp.attempts || 0) + 1;
            }
            return { rows: [] };
        }

        if (q.startsWith('select * from otp_codes')) {
            const [phoneNumber, code] = params;
            const rows = this.state.otp_codes
                .filter(
                    (otp) =>
                        otp.phone_number === phoneNumber &&
                        otp.code === code &&
                        otp.is_used === false &&
                        new Date(otp.expires_at) > new Date(),
                )
                .sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
            return { rows: rows.slice(0, 1).map((otp) => clone(otp)) };
        }

        if (q.startsWith('update otp_codes set is_used = true where id = $1')) {
            const [id] = params;
            const otp = this.state.otp_codes.find((item) => item.id === id);
            if (otp) {
                otp.is_used = true;
            }
            return { rows: [] };
        }

        if (q === 'update users set is_verified = true where phone_number = $1') {
            const [phoneNumber] = params;
            const user = this.state.users.find((item) => item.phone_number === phoneNumber);
            if (user) {
                user.is_verified = true;
            }
            return { rows: [] };
        }

        if (q === 'update users set is_verified = true, role = $1 where phone_number = $2') {
            const [role, phoneNumber] = params;
            const user = this.state.users.find((item) => item.phone_number === phoneNumber);
            if (user) {
                user.is_verified = true;
                user.role = role;
            }
            return { rows: [] };
        }

        if (q.startsWith('update users set is_verified = true where phone_number = $1 returning id')) {
            const [phoneNumber] = params;
            const user = this.state.users.find((item) => item.phone_number === phoneNumber);
            if (user) {
                user.is_verified = true;
                return { rows: [{ id: user.id }] };
            }
            return { rows: [] };
        }

        if (q === 'select * from users where phone_number = $1') {
            const [phoneNumber] = params;
            const rows = this.state.users.filter((user) => user.phone_number === phoneNumber).map((user) => clone(user));
            return { rows };
        }

        if (q === 'select id, full_name, email, phone_number, cin, is_verified, role, is_suspended, wallet_balance, created_at from users where id = $1') {
            const [id] = params;
            const user = this.state.users.find((item) => item.id === id);
            return { rows: user ? [clone(user)] : [] };
        }

        if (q === 'select id, type, qr_code, status, battery_level, latitude, longitude, price_per_minute, booked_by_user_id from vehicles where status != $1 order by created_at desc') {
            const [hiddenStatus] = params;
            const rows = this.state.vehicles
                .filter((vehicle) => vehicle.status !== hiddenStatus)
                .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
                .map((vehicle) =>
                    rowPick(vehicle, [
                        'id',
                        'type',
                        'qr_code',
                        'status',
                        'battery_level',
                        'latitude',
                        'longitude',
                        'price_per_minute',
                        'booked_by_user_id',
                    ]),
                );
            return { rows };
        }

        if (q === 'select wallet_balance from users where id = $1 for update') {
            const [id] = params;
            const user = this.state.users.find((item) => item.id === id);
            return { rows: user ? [{ wallet_balance: user.wallet_balance ?? 0 }] : [] };
        }

        if (q === 'select id, wallet_balance from users where id = $1') {
            const [id] = params;
            const user = this.state.users.find((item) => item.id === id);
            return { rows: user ? [{ id: user.id, wallet_balance: user.wallet_balance ?? 0 }] : [] };
        }

        if (q === 'select * from vehicles where id = $1') {
            const [id] = params;
            const vehicle = this.state.vehicles.find((item) => item.id === id);
            return { rows: vehicle ? [clone(vehicle)] : [] };
        }

        if (q === 'select * from vehicles where qr_code = $1') {
            const [qrCode] = params;
            const vehicle = this.state.vehicles.find((item) => item.qr_code === qrCode);
            return { rows: vehicle ? [clone(vehicle)] : [] };
        }

        if (q === 'select id from rentals where user_id = $1 and status = \'ongoing\' limit 1') {
            const [userId] = params;
            const rental = this.state.rentals.find((item) => item.user_id === userId && item.status === 'ongoing');
            return { rows: rental ? [{ id: rental.id }] : [] };
        }

        if (q === 'select * from vehicles where id = $1 for update') {
            const [id] = params;
            const vehicle = this.state.vehicles.find((item) => item.id === id);
            return { rows: vehicle ? [clone(vehicle)] : [] };
        }

        if (q.startsWith('insert into rentals (user_id, vehicle_id, start_latitude, start_longitude, status)')) {
            const [userId, vehicleId, startLatitude, startLongitude] = params;
            const rental = {
                id: randomUUID(),
                user_id: userId,
                vehicle_id: vehicleId,
                start_time: new Date(),
                end_time: null,
                start_latitude: startLatitude ?? null,
                start_longitude: startLongitude ?? null,
                end_latitude: null,
                end_longitude: null,
                duration_minutes: null,
                total_price: null,
                status: 'ongoing',
                created_at: new Date(),
            };
            this.state.rentals.push(rental);
            return { rows: [clone(rental)] };
        }

        if (q === 'update vehicles set status = $1, booked_by_user_id = null, booked_at = null where id = $2') {
            const [status, id] = params;
            const vehicle = this.state.vehicles.find((item) => item.id === id);
            if (vehicle) {
                vehicle.status = status;
                vehicle.booked_by_user_id = null;
                vehicle.booked_at = null;
            }
            return { rows: [] };
        }

        if (q === 'update vehicles set status = $1 where id = $2') {
            const [status, id] = params;
            const vehicle = this.state.vehicles.find((item) => item.id === id);
            if (vehicle) {
                vehicle.status = status;
                if (status === 'in_use') {
                    vehicle.booked_by_user_id = null;
                    vehicle.booked_at = null;
                }
            }
            return { rows: [] };
        }

        if (q === "update vehicles set status = 'booked', booked_by_user_id = $1, booked_at = $2 where id = $3 returning *") {
            const [userId, bookedAt, id] = params;
            const vehicle = this.state.vehicles.find((item) => item.id === id);
            if (!vehicle) return { rows: [] };
            vehicle.status = 'booked';
            vehicle.booked_by_user_id = userId;
            vehicle.booked_at = bookedAt;
            return { rows: [clone(vehicle)] };
        }

        if (q === "update vehicles set status = 'available', booked_by_user_id = null, booked_at = null where id = $1 returning *") {
            const [id] = params;
            const vehicle = this.state.vehicles.find((item) => item.id === id);
            if (!vehicle) return { rows: [] };
            vehicle.status = 'available';
            vehicle.booked_by_user_id = null;
            vehicle.booked_at = null;
            return { rows: [clone(vehicle)] };
        }

        if (q === 'select id, vehicle_id from rentals where id = $1 and user_id = $2 and status = \'ongoing\'') {
            const [id, userId] = params;
            const rental = this.state.rentals.find((item) => item.id === id && item.user_id === userId && item.status === 'ongoing');
            return { rows: rental ? [{ id: rental.id, vehicle_id: rental.vehicle_id }] : [] };
        }

        if (q.startsWith('insert into rental_locations (rental_id, latitude, longitude)')) {
            const [rentalId, latitude, longitude] = params;
            const location = {
                id: randomUUID(),
                rental_id: rentalId,
                latitude,
                longitude,
                recorded_at: new Date(),
            };
            this.state.rental_locations.push(location);
            return { rows: [clone(location)] };
        }

        if (q === 'update vehicles set latitude = $1, longitude = $2 where id = $3') {
            const [latitude, longitude, id] = params;
            const vehicle = this.state.vehicles.find((item) => item.id === id);
            if (vehicle) {
                vehicle.latitude = latitude;
                vehicle.longitude = longitude;
            }
            return { rows: [] };
        }

        if (q === 'select * from rentals where id = $1 and user_id = $2 and status = $3') {
            const [id, userId, status] = params;
            const rental = this.state.rentals.find(
                (item) => item.id === id && item.user_id === userId && item.status === status,
            );
            return { rows: rental ? [clone(rental)] : [] };
        }

        if (q === 'select price_per_minute from vehicles where id = $1') {
            const [id] = params;
            const vehicle = this.state.vehicles.find((item) => item.id === id);
            return { rows: vehicle ? [{ price_per_minute: vehicle.price_per_minute }] : [] };
        }

        if (q.startsWith('update rentals set end_time = $1, end_latitude = $2, end_longitude = $3')) {
            const [endTime, latitude, longitude, durationMinutes, totalPrice, id] = params;
            const rental = this.state.rentals.find((item) => item.id === id);
            if (!rental) {
                return { rows: [] };
            }
            rental.end_time = endTime;
            rental.end_latitude = latitude ?? null;
            rental.end_longitude = longitude ?? null;
            rental.duration_minutes = durationMinutes;
            rental.total_price = totalPrice;
            rental.status = 'completed';
            return { rows: [clone(rental)] };
        }

        if (q.startsWith("update vehicles set status = 'available', latitude = $1, longitude = $2, booked_by_user_id = null, booked_at = null where id = $3")) {
            const [latitude, longitude, id] = params;
            const vehicle = this.state.vehicles.find((item) => item.id === id);
            if (vehicle) {
                vehicle.status = 'available';
                vehicle.latitude = latitude;
                vehicle.longitude = longitude;
                vehicle.booked_by_user_id = null;
                vehicle.booked_at = null;
            }
            return { rows: [] };
        }

        if (q.startsWith('select id, amount, direction, method, status, reference, rental_id, created_at from wallet_transactions')) {
            const [userId] = params;
            const rows = (this.state.wallet_transactions || [])
                .filter((item) => item.user_id === userId)
                .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
                .slice(0, 30)
                .map((item) => clone(item));
            return { rows };
        }

        if (q.startsWith("insert into payments (rental_id, user_id, amount, method, status)")) {
            const [rentalId, userId, amount] = params;
            const payment = {
                id: randomUUID(),
                rental_id: rentalId,
                user_id: userId,
                amount,
                method: 'wallet',
                status: 'success',
                created_at: new Date(),
            };
            this.state.payments.push(payment);
            return { rows: [clone(payment)] };
        }

        if (q === 'update users set wallet_balance = wallet_balance - $1 where id = $2 returning wallet_balance') {
            const [amount, userId] = params;
            const user = this.state.users.find((item) => item.id === userId);
            if (!user) return { rows: [] };
            user.wallet_balance = Number(((user.wallet_balance ?? 0) - Number(amount)).toFixed(3));
            return { rows: [{ wallet_balance: user.wallet_balance }] };
        }

        if (q === 'update users set wallet_balance = wallet_balance + $1 where id = $2 returning wallet_balance') {
            const [amount, userId] = params;
            const user = this.state.users.find((item) => item.id === userId);
            if (!user) return { rows: [] };
            user.wallet_balance = Number(((user.wallet_balance ?? 0) + Number(amount)).toFixed(3));
            return { rows: [{ wallet_balance: user.wallet_balance }] };
        }

        if (q.startsWith('insert into wallet_transactions')) {
            const isDebit = q.includes("'debit'");
            const userId = params[0];
            const amount = params[1];
            const direction = isDebit ? 'debit' : 'credit';
            const method = isDebit ? 'wallet' : params[2];
            const reference = isDebit ? params[2] : params[3];
            const rentalId = isDebit ? params[3] : null;
            const transaction = {
                id: randomUUID(),
                user_id: userId,
                amount,
                direction,
                method,
                status: 'success',
                reference,
                rental_id: rentalId,
                created_at: new Date(),
            };
            this.state.wallet_transactions = this.state.wallet_transactions || [];
            this.state.wallet_transactions.push(transaction);
            return { rows: [clone(transaction)] };
        }

        if (q.startsWith('select r.*, v.type as vehicle_type, v.battery_level')) {
            const [userId] = params;
            const rental = [...this.state.rentals]
                .filter((item) => item.user_id === userId && item.status === 'ongoing')
                .sort((a, b) => new Date(b.start_time) - new Date(a.start_time))[0];
            if (!rental) {
                return { rows: [] };
            }
            const vehicle = this.state.vehicles.find((item) => item.id === rental.vehicle_id);
            if (!vehicle) {
                return { rows: [] };
            }
            return {
                rows: [
                    {
                        ...clone(rental),
                        vehicle_type: vehicle.type,
                        battery_level: vehicle.battery_level,
                        vehicle_latitude: vehicle.latitude,
                        vehicle_longitude: vehicle.longitude,
                        price_per_minute: vehicle.price_per_minute,
                        location_track: this.state.rental_locations
                            .filter((location) => location.rental_id === rental.id)
                            .sort((a, b) => new Date(a.recorded_at) - new Date(b.recorded_at))
                            .map((location) => ({
                                latitude: location.latitude,
                                longitude: location.longitude,
                                recordedAt: location.recorded_at,
                            })),
                    },
                ],
            };
        }

        if (q.startsWith('select r.*, v.type as vehicle_type from rentals r join vehicles v on r.vehicle_id = v.id where r.user_id = $1 order by r.start_time desc')) {
            const [userId] = params;
            const rows = this.state.rentals
                .filter((rental) => rental.user_id === userId)
                .sort((a, b) => new Date(b.start_time) - new Date(a.start_time))
                .map((rental) => {
                    const vehicle = this.state.vehicles.find((item) => item.id === rental.vehicle_id);
                    return {
                        ...clone(rental),
                        vehicle_type: vehicle ? vehicle.type : null,
                    };
                });
            return { rows };
        }

        throw new Error(`Mock DB does not support query: ${sql}`);
    }
}

const realPool = new Pool({
    user: process.env.DB_USER || 'postgres',
    host: process.env.DB_HOST || 'localhost',
    database: process.env.DB_NAME || 'rentgo_tunisia',
    password: process.env.DB_PASSWORD || '',
    port: process.env.DB_PORT || 5432,
});

async function ensureOtpSchema(client) {
    await client.query(`
        CREATE TABLE IF NOT EXISTS otp_codes (
            phone_number VARCHAR(20) PRIMARY KEY,
            email VARCHAR(255),
            otp_hash TEXT NOT NULL,
            expires_at TIMESTAMPTZ NOT NULL,
            attempts INTEGER NOT NULL DEFAULT 0,
            code TEXT,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
    `);

    // Upgrade the original MVP table without requiring a manual migration.
    await client.query('ALTER TABLE otp_codes ADD COLUMN IF NOT EXISTS email VARCHAR(255)');
    await client.query('ALTER TABLE otp_codes ADD COLUMN IF NOT EXISTS otp_hash TEXT');
    await client.query('ALTER TABLE otp_codes ADD COLUMN IF NOT EXISTS attempts INTEGER NOT NULL DEFAULT 0');
    await client.query('ALTER TABLE otp_codes ADD COLUMN IF NOT EXISTS code TEXT');
    await client.query('ALTER TABLE otp_codes ALTER COLUMN code TYPE TEXT USING code::text');
    await client.query('ALTER TABLE otp_codes ALTER COLUMN code DROP NOT NULL');
    await client.query('DELETE FROM otp_codes WHERE otp_hash IS NULL');
    await client.query('ALTER TABLE otp_codes ALTER COLUMN otp_hash SET NOT NULL');
    await client.query('CREATE UNIQUE INDEX IF NOT EXISTS idx_otp_codes_phone_number ON otp_codes(phone_number)');
}

async function ensureUserSchema(client) {
    await client.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS email VARCHAR(255)');
    await client.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS wallet_balance DECIMAL(10, 3) NOT NULL DEFAULT 0');
    await client.query('UPDATE users SET email = CONCAT(REPLACE(phone_number, \'+\', \'\'), \'@placeholder.local\') WHERE email IS NULL');
    await client.query('ALTER TABLE users ALTER COLUMN email SET NOT NULL');
    await client.query('CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email ON users(email)');
}

async function ensureVehicleSchema(client) {
    await client.query('ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS booked_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL');
    await client.query('ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS booked_at TIMESTAMP');
    await client.query('ALTER TABLE vehicles DROP CONSTRAINT IF EXISTS vehicles_status_check');
    await client.query(`
        ALTER TABLE vehicles
        ADD CONSTRAINT vehicles_status_check
        CHECK (status IN ('available', 'booked', 'in_use', 'maintenance', 'offline'))
    `);
}

async function ensureWalletSchema(client) {
    await client.query(`
        CREATE TABLE IF NOT EXISTS wallet_transactions (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            amount DECIMAL(10, 3) NOT NULL,
            direction VARCHAR(10) NOT NULL CHECK (direction IN ('credit', 'debit')),
            method VARCHAR(30) NOT NULL CHECK (method IN ('card', 'd17', 'sobflous', 'wallet')),
            status VARCHAR(20) NOT NULL DEFAULT 'success' CHECK (status IN ('pending', 'success', 'failed')),
            reference VARCHAR(120),
            rental_id UUID REFERENCES rentals(id) ON DELETE SET NULL,
            created_at TIMESTAMP DEFAULT NOW()
        )
    `);
    await client.query('CREATE INDEX IF NOT EXISTS idx_wallet_transactions_user ON wallet_transactions(user_id)');
}

async function ensureRentalLocationSchema(client) {
    await client.query(`
        CREATE TABLE IF NOT EXISTS rental_locations (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            rental_id UUID NOT NULL REFERENCES rentals(id) ON DELETE CASCADE,
            latitude DECIMAL(10, 8) NOT NULL,
            longitude DECIMAL(11, 8) NOT NULL,
            recorded_at TIMESTAMP NOT NULL DEFAULT NOW()
        )
    `);
    await client.query('CREATE INDEX IF NOT EXISTS idx_rental_locations_rental ON rental_locations(rental_id, recorded_at)');
}

async function ensurePasswordResetSchema(client) {
    await client.query(`
        CREATE TABLE IF NOT EXISTS password_reset_tokens (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            token_hash CHAR(64) NOT NULL UNIQUE,
            expires_at TIMESTAMPTZ NOT NULL,
            used_at TIMESTAMPTZ
        )
    `);
    await client.query('CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_user ON password_reset_tokens(user_id)');
}

const mockDatabase = new MockDatabase();
let activeDatabase = process.env.DB_MODE === 'memory' ? mockDatabase : realPool;
let usingMockDatabase = activeDatabase === mockDatabase;

function shouldFallbackToMemory(error) {
    const connectionErrors = new Set(['ECONNREFUSED', 'ENOTFOUND', 'ETIMEDOUT', '28P01', '3D000']);
    return connectionErrors.has(error?.code);
}

function activateMockDatabase(error) {
    if (usingMockDatabase) return;
    usingMockDatabase = true;
    activeDatabase = mockDatabase;
    console.error('❌ Erreur de connexion à PostgreSQL :', error.message || error);
    console.log('ℹ️ Mode de secours activé: base mémoire locale');
}

const ready = usingMockDatabase
    ? Promise.resolve()
    : realPool
        .connect()
        .then((client) => {
            return ensureUserSchema(client)
                .then(() => ensureOtpSchema(client))
                .then(() => ensureVehicleSchema(client))
                .then(() => ensureWalletSchema(client))
                .then(() => ensureRentalLocationSchema(client))
                .then(() => ensurePasswordResetSchema(client))
                .then(() => {
                    console.log('✅ Connecté à la base de données PostgreSQL');
                    client.release();
                })
                .catch((error) => {
                    client.release();
                    throw error;
                });
        })
        .catch((err) => {
            activateMockDatabase(err);
        })
    .then(() => ensureDemoAdmin());

if (usingMockDatabase) {
    console.log('ℹ️ DB_MODE=memory: base mémoire locale activée');
}

async function query(sql, params = []) {
    try {
        return await activeDatabase.query(sql, params);
    } catch (error) {
        if (!usingMockDatabase && shouldFallbackToMemory(error)) {
            activateMockDatabase(error);
            return activeDatabase.query(sql, params);
        }
        throw error;
    }
}

async function connect() {
    if (usingMockDatabase) {
        return activeDatabase.connect();
    }
    try {
        return await realPool.connect();
    } catch (error) {
        if (shouldFallbackToMemory(error)) {
            activateMockDatabase(error);
            return activeDatabase.connect();
        }
        throw error;
    }
}

async function ensureDemoAdmin() {
    if (process.env.NODE_ENV === 'production' || process.env.SEED_DEMO_ADMIN === 'false') {
        return;
    }

    const existing = await query('SELECT * FROM users WHERE phone_number = $1', [DEMO_ADMIN.phoneNumber]);

    if (existing.rows.length === 0) {
        const passwordHash = await bcrypt.hash(DEMO_ADMIN.password, 10);
        await query(
            `INSERT INTO users (full_name, email, phone_number, cin, password_hash)
             VALUES ($1, $2, $3, $4, $5)`,
            [
                DEMO_ADMIN.fullName,
                DEMO_ADMIN.email,
                DEMO_ADMIN.phoneNumber,
                null,
                passwordHash,
            ],
        );
        console.log(`✅ Compte admin de développement créé : ${DEMO_ADMIN.phoneNumber}`);
    }

    await query(
        'UPDATE users SET is_verified = TRUE, role = $1 WHERE phone_number = $2',
        ['admin', DEMO_ADMIN.phoneNumber],
    );
}

module.exports = { query, connect, ready };
