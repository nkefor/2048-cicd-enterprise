const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const { authenticatePatient, authenticateAdmin } = require('../middleware/auth');

// Create telehealth session for an appointment
router.post('/session', authenticatePatient, (req, res) => {
    try {
        const { appointment_id } = req.body;

        const appointment = req.db.prepare(
            "SELECT * FROM appointments WHERE id = ? AND patient_id = ? AND service_type = 'telehealth'"
        ).get(appointment_id, req.patient.id);

        if (!appointment) {
            return res.status(404).json({ error: 'Telehealth appointment not found' });
        }

        // Check if session already exists
        let session = req.db.prepare(
            "SELECT * FROM telehealth_sessions WHERE appointment_id = ? AND status IN ('waiting', 'active')"
        ).get(appointment_id);

        if (!session) {
            const sessionToken = uuidv4();
            const result = req.db.prepare(`
                INSERT INTO telehealth_sessions (appointment_id, patient_id, session_token, status)
                VALUES (?, ?, ?, 'waiting')
            `).run(appointment_id, req.patient.id, sessionToken);

            session = req.db.prepare('SELECT * FROM telehealth_sessions WHERE id = ?').get(result.lastInsertRowid);
        }

        res.json({
            session_token: session.session_token,
            session_url: `/telehealth-session?token=${session.session_token}`,
            status: session.status
        });
    } catch (err) {
        console.error('Telehealth session error:', err);
        res.status(500).json({ error: 'Failed to create telehealth session' });
    }
});

// Get session status
router.get('/session/:token', (req, res) => {
    try {
        const session = req.db.prepare(`
            SELECT ts.*, a.appointment_date, a.appointment_time, a.service_type,
                   p.first_name, p.last_name
            FROM telehealth_sessions ts
            JOIN appointments a ON ts.appointment_id = a.id
            JOIN patients p ON ts.patient_id = p.id
            WHERE ts.session_token = ?
        `).get(req.params.token);

        if (!session) {
            return res.status(404).json({ error: 'Session not found' });
        }

        res.json(session);
    } catch (err) {
        console.error('Session status error:', err);
        res.status(500).json({ error: 'Failed to fetch session status' });
    }
});

// Start telehealth session (admin/provider)
router.patch('/session/:token/start', authenticateAdmin, (req, res) => {
    try {
        req.db.prepare(`
            UPDATE telehealth_sessions SET status = 'active', started_at = CURRENT_TIMESTAMP
            WHERE session_token = ? AND status = 'waiting'
        `).run(req.params.token);

        res.json({ message: 'Session started', status: 'active' });
    } catch (err) {
        console.error('Start session error:', err);
        res.status(500).json({ error: 'Failed to start session' });
    }
});

// End telehealth session
router.patch('/session/:token/end', authenticateAdmin, (req, res) => {
    try {
        const session = req.db.prepare(
            "SELECT * FROM telehealth_sessions WHERE session_token = ? AND status = 'active'"
        ).get(req.params.token);

        if (!session) {
            return res.status(404).json({ error: 'Active session not found' });
        }

        const durationSeconds = session.started_at
            ? Math.floor((Date.now() - new Date(session.started_at).getTime()) / 1000)
            : 0;

        req.db.prepare(`
            UPDATE telehealth_sessions SET status = 'completed', ended_at = CURRENT_TIMESTAMP, duration_seconds = ?
            WHERE session_token = ?
        `).run(durationSeconds, req.params.token);

        // Update appointment status
        req.db.prepare(
            "UPDATE appointments SET status = 'completed', updated_at = CURRENT_TIMESTAMP WHERE id = ?"
        ).run(session.appointment_id);

        res.json({ message: 'Session ended', duration_seconds: durationSeconds });
    } catch (err) {
        console.error('End session error:', err);
        res.status(500).json({ error: 'Failed to end session' });
    }
});

module.exports = router;
