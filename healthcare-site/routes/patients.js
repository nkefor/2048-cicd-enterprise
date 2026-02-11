const express = require('express');
const router = express.Router();
const { authenticatePatient, authenticateAdmin } = require('../middleware/auth');

// Get patient intake forms
router.get('/intake-forms', authenticatePatient, (req, res) => {
    try {
        const forms = req.db.prepare(
            'SELECT * FROM intake_forms WHERE patient_id = ? ORDER BY created_at DESC'
        ).all(req.patient.id);

        res.json(forms);
    } catch (err) {
        console.error('Intake forms error:', err);
        res.status(500).json({ error: 'Failed to fetch intake forms' });
    }
});

// Submit intake form
router.post('/intake-forms', authenticatePatient, (req, res) => {
    try {
        const { form_type, form_data } = req.body;

        if (!form_type || !form_data) {
            return res.status(400).json({ error: 'Form type and data are required' });
        }

        const result = req.db.prepare(`
            INSERT INTO intake_forms (patient_id, form_type, form_data, signed, signed_at)
            VALUES (?, ?, ?, 1, CURRENT_TIMESTAMP)
        `).run(req.patient.id, form_type, JSON.stringify(form_data));

        res.status(201).json({
            message: 'Form submitted successfully',
            form_id: result.lastInsertRowid
        });
    } catch (err) {
        console.error('Intake form submit error:', err);
        res.status(500).json({ error: 'Failed to submit form' });
    }
});

// Get patient messages
router.get('/messages', authenticatePatient, (req, res) => {
    try {
        const messages = req.db.prepare(
            'SELECT * FROM messages WHERE patient_id = ? ORDER BY created_at DESC'
        ).all(req.patient.id);

        res.json(messages);
    } catch (err) {
        console.error('Messages error:', err);
        res.status(500).json({ error: 'Failed to fetch messages' });
    }
});

// Send a message
router.post('/messages', authenticatePatient, (req, res) => {
    try {
        const { subject, body } = req.body;

        if (!body) {
            return res.status(400).json({ error: 'Message body is required' });
        }

        const result = req.db.prepare(`
            INSERT INTO messages (patient_id, sender_type, subject, body)
            VALUES (?, 'patient', ?, ?)
        `).run(req.patient.id, subject || 'General Inquiry', body);

        res.status(201).json({
            message: 'Message sent successfully',
            message_id: result.lastInsertRowid
        });
    } catch (err) {
        console.error('Send message error:', err);
        res.status(500).json({ error: 'Failed to send message' });
    }
});

// Admin: Get all patients
router.get('/all', authenticateAdmin, (req, res) => {
    try {
        const patients = req.db.prepare(
            'SELECT id, first_name, last_name, email, phone, date_of_birth, insurance_provider, created_at FROM patients ORDER BY created_at DESC'
        ).all();

        res.json(patients);
    } catch (err) {
        console.error('Admin patients error:', err);
        res.status(500).json({ error: 'Failed to fetch patients' });
    }
});

// Admin: Get patient details
router.get('/:id', authenticateAdmin, (req, res) => {
    try {
        const patient = req.db.prepare(
            'SELECT id, first_name, last_name, email, phone, date_of_birth, gender, address, city, state, zip_code, insurance_provider, insurance_id, emergency_contact_name, emergency_contact_phone, created_at FROM patients WHERE id = ?'
        ).get(req.params.id);

        if (!patient) {
            return res.status(404).json({ error: 'Patient not found' });
        }

        const appointments = req.db.prepare(
            'SELECT * FROM appointments WHERE patient_id = ? ORDER BY appointment_date DESC'
        ).all(req.params.id);

        const payments = req.db.prepare(
            'SELECT * FROM payments WHERE patient_id = ? ORDER BY created_at DESC'
        ).all(req.params.id);

        res.json({ ...patient, appointments, payments });
    } catch (err) {
        console.error('Patient details error:', err);
        res.status(500).json({ error: 'Failed to fetch patient details' });
    }
});

module.exports = router;
