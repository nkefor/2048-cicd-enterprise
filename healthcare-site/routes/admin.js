const express = require('express');
const router = express.Router();
const { authenticateAdmin } = require('../middleware/auth');

// Dashboard stats
router.get('/dashboard', authenticateAdmin, (req, res) => {
    try {
        const today = new Date().toISOString().split('T')[0];

        const totalPatients = req.db.prepare('SELECT COUNT(*) as count FROM patients').get().count;

        const todayAppointments = req.db.prepare(
            "SELECT COUNT(*) as count FROM appointments WHERE appointment_date = ? AND status NOT IN ('cancelled')"
        ).get(today).count;

        const pendingAppointments = req.db.prepare(
            "SELECT COUNT(*) as count FROM appointments WHERE status = 'scheduled'"
        ).get().count;

        const totalRevenue = req.db.prepare(
            "SELECT COALESCE(SUM(amount), 0) as total FROM payments WHERE status = 'succeeded'"
        ).get().total;

        const recentAppointments = req.db.prepare(`
            SELECT a.*, p.first_name, p.last_name, p.email
            FROM appointments a
            JOIN patients p ON a.patient_id = p.id
            WHERE a.appointment_date >= ?
            ORDER BY a.appointment_date ASC, a.appointment_time ASC
            LIMIT 10
        `).all(today);

        const recentPayments = req.db.prepare(`
            SELECT py.*, p.first_name, p.last_name
            FROM payments py
            JOIN patients p ON py.patient_id = p.id
            ORDER BY py.created_at DESC
            LIMIT 10
        `).all();

        const unreadMessages = req.db.prepare(
            "SELECT COUNT(*) as count FROM messages WHERE sender_type = 'patient' AND is_read = 0"
        ).get().count;

        const appointmentsByType = req.db.prepare(`
            SELECT service_type, COUNT(*) as count
            FROM appointments
            WHERE status NOT IN ('cancelled')
            GROUP BY service_type
        `).all();

        res.json({
            stats: {
                total_patients: totalPatients,
                today_appointments: todayAppointments,
                pending_appointments: pendingAppointments,
                total_revenue: totalRevenue / 100,
                unread_messages: unreadMessages
            },
            recent_appointments: recentAppointments,
            recent_payments: recentPayments,
            appointments_by_type: appointmentsByType
        });
    } catch (err) {
        console.error('Dashboard error:', err);
        res.status(500).json({ error: 'Failed to fetch dashboard data' });
    }
});

// Get DOT physical records
router.get('/dot-records', authenticateAdmin, (req, res) => {
    try {
        const records = req.db.prepare(`
            SELECT d.*, p.first_name, p.last_name, p.date_of_birth
            FROM dot_physicals d
            JOIN patients p ON d.patient_id = p.id
            ORDER BY d.exam_date DESC
        `).all();

        res.json(records);
    } catch (err) {
        console.error('DOT records error:', err);
        res.status(500).json({ error: 'Failed to fetch DOT records' });
    }
});

// Create/Update DOT physical record
router.post('/dot-records', authenticateAdmin, (req, res) => {
    try {
        const {
            patient_id, appointment_id, exam_date,
            vision_test_passed, hearing_test_passed,
            blood_pressure_systolic, blood_pressure_diastolic,
            pulse_rate, urinalysis_result, medical_determination,
            restrictions, examiner_notes, certificate_expiry
        } = req.body;

        const result = req.db.prepare(`
            INSERT INTO dot_physicals (
                patient_id, appointment_id, exam_date, certificate_expiry,
                vision_test_passed, hearing_test_passed,
                blood_pressure_systolic, blood_pressure_diastolic,
                pulse_rate, urinalysis_result, medical_determination,
                restrictions, examiner_notes, certificate_issued
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `).run(
            patient_id, appointment_id || null, exam_date, certificate_expiry || null,
            vision_test_passed ? 1 : 0, hearing_test_passed ? 1 : 0,
            blood_pressure_systolic, blood_pressure_diastolic,
            pulse_rate, urinalysis_result, medical_determination || 'pending',
            restrictions || null, examiner_notes || null,
            medical_determination === 'qualified' ? 1 : 0
        );

        res.status(201).json({
            message: 'DOT physical record created',
            record_id: result.lastInsertRowid
        });
    } catch (err) {
        console.error('DOT record error:', err);
        res.status(500).json({ error: 'Failed to create DOT record' });
    }
});

// Get all messages
router.get('/messages', authenticateAdmin, (req, res) => {
    try {
        const messages = req.db.prepare(`
            SELECT m.*, p.first_name, p.last_name, p.email
            FROM messages m
            JOIN patients p ON m.patient_id = p.id
            ORDER BY m.created_at DESC
        `).all();

        res.json(messages);
    } catch (err) {
        console.error('Admin messages error:', err);
        res.status(500).json({ error: 'Failed to fetch messages' });
    }
});

// Reply to message
router.post('/messages/:patientId', authenticateAdmin, (req, res) => {
    try {
        const { subject, body } = req.body;

        req.db.prepare(`
            INSERT INTO messages (patient_id, sender_type, subject, body)
            VALUES (?, 'provider', ?, ?)
        `).run(req.params.patientId, subject || 'Reply', body);

        res.status(201).json({ message: 'Reply sent' });
    } catch (err) {
        console.error('Reply error:', err);
        res.status(500).json({ error: 'Failed to send reply' });
    }
});

// Mark message as read
router.patch('/messages/:id/read', authenticateAdmin, (req, res) => {
    try {
        req.db.prepare('UPDATE messages SET is_read = 1 WHERE id = ?').run(req.params.id);
        res.json({ message: 'Marked as read' });
    } catch (err) {
        res.status(500).json({ error: 'Failed to update message' });
    }
});

module.exports = router;
