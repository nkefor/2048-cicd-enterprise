const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const { generateToken, authenticatePatient } = require('../middleware/auth');

// Patient Registration
router.post('/register', async (req, res) => {
    try {
        const { first_name, last_name, email, password, phone, date_of_birth } = req.body;

        if (!first_name || !last_name || !email || !password) {
            return res.status(400).json({ error: 'First name, last name, email, and password are required' });
        }

        // Check if email already exists
        const existing = req.db.prepare('SELECT id FROM patients WHERE email = ?').get(email);
        if (existing) {
            return res.status(409).json({ error: 'An account with this email already exists' });
        }

        const passwordHash = bcrypt.hashSync(password, 12);

        const result = req.db.prepare(`
            INSERT INTO patients (first_name, last_name, email, password_hash, phone, date_of_birth)
            VALUES (?, ?, ?, ?, ?, ?)
        `).run(first_name, last_name, email, passwordHash, phone || null, date_of_birth || null);

        const token = generateToken({
            id: result.lastInsertRowid,
            email,
            type: 'patient'
        });

        res.status(201).json({
            message: 'Registration successful',
            token,
            patient: { id: result.lastInsertRowid, first_name, last_name, email }
        });
    } catch (err) {
        console.error('Registration error:', err);
        res.status(500).json({ error: 'Registration failed' });
    }
});

// Patient Login
router.post('/login', (req, res) => {
    try {
        const { email, password } = req.body;

        if (!email || !password) {
            return res.status(400).json({ error: 'Email and password are required' });
        }

        const patient = req.db.prepare('SELECT * FROM patients WHERE email = ?').get(email);
        if (!patient) {
            return res.status(401).json({ error: 'Invalid email or password' });
        }

        if (!bcrypt.compareSync(password, patient.password_hash)) {
            return res.status(401).json({ error: 'Invalid email or password' });
        }

        const token = generateToken({
            id: patient.id,
            email: patient.email,
            type: 'patient'
        });

        res.json({
            message: 'Login successful',
            token,
            patient: {
                id: patient.id,
                first_name: patient.first_name,
                last_name: patient.last_name,
                email: patient.email
            }
        });
    } catch (err) {
        console.error('Login error:', err);
        res.status(500).json({ error: 'Login failed' });
    }
});

// Admin Login
router.post('/admin/login', (req, res) => {
    try {
        const { username, password } = req.body;

        if (!username || !password) {
            return res.status(400).json({ error: 'Username and password are required' });
        }

        const admin = req.db.prepare('SELECT * FROM admin_users WHERE username = ? OR email = ?').get(username, username);
        if (!admin) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        if (!bcrypt.compareSync(password, admin.password_hash)) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        const token = generateToken({
            id: admin.id,
            email: admin.email,
            type: admin.role,
            name: `${admin.first_name} ${admin.last_name}`
        });

        res.json({
            message: 'Login successful',
            token,
            admin: {
                id: admin.id,
                first_name: admin.first_name,
                last_name: admin.last_name,
                role: admin.role,
                credentials: admin.credentials
            }
        });
    } catch (err) {
        console.error('Admin login error:', err);
        res.status(500).json({ error: 'Login failed' });
    }
});

// Get current patient profile
router.get('/me', authenticatePatient, (req, res) => {
    try {
        const patient = req.db.prepare(
            'SELECT id, first_name, last_name, email, phone, date_of_birth, gender, address, city, state, zip_code, insurance_provider, insurance_id FROM patients WHERE id = ?'
        ).get(req.patient.id);

        if (!patient) {
            return res.status(404).json({ error: 'Patient not found' });
        }

        res.json(patient);
    } catch (err) {
        console.error('Profile error:', err);
        res.status(500).json({ error: 'Failed to fetch profile' });
    }
});

// Update patient profile
router.put('/me', authenticatePatient, (req, res) => {
    try {
        const { phone, address, city, state, zip_code, insurance_provider, insurance_id, emergency_contact_name, emergency_contact_phone, gender } = req.body;

        req.db.prepare(`
            UPDATE patients SET
                phone = COALESCE(?, phone),
                address = COALESCE(?, address),
                city = COALESCE(?, city),
                state = COALESCE(?, state),
                zip_code = COALESCE(?, zip_code),
                insurance_provider = COALESCE(?, insurance_provider),
                insurance_id = COALESCE(?, insurance_id),
                emergency_contact_name = COALESCE(?, emergency_contact_name),
                emergency_contact_phone = COALESCE(?, emergency_contact_phone),
                gender = COALESCE(?, gender),
                updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
        `).run(phone, address, city, state, zip_code, insurance_provider, insurance_id, emergency_contact_name, emergency_contact_phone, gender, req.patient.id);

        res.json({ message: 'Profile updated successfully' });
    } catch (err) {
        console.error('Profile update error:', err);
        res.status(500).json({ error: 'Failed to update profile' });
    }
});

module.exports = router;
