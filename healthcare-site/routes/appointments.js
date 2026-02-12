const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const { authenticatePatient, authenticateAdmin } = require('../middleware/auth');

// Get available time slots for a given date and service
router.get('/availability', (req, res) => {
    try {
        const { date, service_type } = req.query;

        if (!date) {
            return res.status(400).json({ error: 'Date is required' });
        }

        const requestedDate = new Date(date);
        const dayOfWeek = requestedDate.getDay();

        // Get availability for this day of week
        let query = 'SELECT * FROM availability WHERE day_of_week = ? AND is_active = 1';
        const params = [dayOfWeek];

        if (service_type) {
            query += ' AND (service_type = ? OR service_type IS NULL)';
            params.push(service_type);
        }

        const slots = req.db.prepare(query).all(...params);

        if (slots.length === 0) {
            return res.json({ available_slots: [], message: 'No availability on this date' });
        }

        // Get existing appointments for this date
        const existingAppts = req.db.prepare(
            "SELECT appointment_time, duration_minutes FROM appointments WHERE appointment_date = ? AND status NOT IN ('cancelled')"
        ).all(date);

        const bookedTimes = new Set(existingAppts.map(a => a.appointment_time));

        // Generate 30-min time slots (deduplicated across service types)
        const slotSet = new Set();
        slots.forEach(slot => {
            const [startH, startM] = slot.start_time.split(':').map(Number);
            const [endH, endM] = slot.end_time.split(':').map(Number);
            const startMinutes = startH * 60 + startM;
            const endMinutes = endH * 60 + endM;

            for (let m = startMinutes; m < endMinutes; m += 30) {
                const hour = Math.floor(m / 60).toString().padStart(2, '0');
                const min = (m % 60).toString().padStart(2, '0');
                const timeStr = `${hour}:${min}`;

                if (!bookedTimes.has(timeStr)) {
                    slotSet.add(timeStr);
                }
            }
        });

        const availableSlots = Array.from(slotSet).sort();

        res.json({ date, available_slots: availableSlots });
    } catch (err) {
        console.error('Availability error:', err);
        res.status(500).json({ error: 'Failed to fetch availability' });
    }
});

// Book an appointment (authenticated patient)
router.post('/', authenticatePatient, (req, res) => {
    try {
        const { service_type, appointment_date, appointment_time, notes } = req.body;

        if (!service_type || !appointment_date || !appointment_time) {
            return res.status(400).json({ error: 'Service type, date, and time are required' });
        }

        // Check if slot is still available
        const existing = req.db.prepare(
            "SELECT id FROM appointments WHERE appointment_date = ? AND appointment_time = ? AND status NOT IN ('cancelled')"
        ).get(appointment_date, appointment_time);

        if (existing) {
            return res.status(409).json({ error: 'This time slot is no longer available' });
        }

        const duration = service_type === 'dot_physical' ? 60 : 30;
        let telehealthLink = null;

        if (service_type === 'telehealth') {
            telehealthLink = `/telehealth-session?token=${uuidv4()}`;
        }

        const result = req.db.prepare(`
            INSERT INTO appointments (patient_id, service_type, appointment_date, appointment_time, duration_minutes, notes, telehealth_link)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        `).run(req.patient.id, service_type, appointment_date, appointment_time, duration, notes || null, telehealthLink);

        const appointment = req.db.prepare('SELECT * FROM appointments WHERE id = ?').get(result.lastInsertRowid);

        res.status(201).json({
            message: 'Appointment booked successfully',
            appointment
        });
    } catch (err) {
        console.error('Booking error:', err);
        res.status(500).json({ error: 'Failed to book appointment' });
    }
});

// Get patient's appointments
router.get('/my', authenticatePatient, (req, res) => {
    try {
        const { status } = req.query;
        let query = 'SELECT * FROM appointments WHERE patient_id = ?';
        const params = [req.patient.id];

        if (status) {
            query += ' AND status = ?';
            params.push(status);
        }

        query += ' ORDER BY appointment_date DESC, appointment_time DESC';

        const appointments = req.db.prepare(query).all(...params);
        res.json(appointments);
    } catch (err) {
        console.error('Fetch appointments error:', err);
        res.status(500).json({ error: 'Failed to fetch appointments' });
    }
});

// Cancel an appointment
router.patch('/:id/cancel', authenticatePatient, (req, res) => {
    try {
        const appointment = req.db.prepare(
            'SELECT * FROM appointments WHERE id = ? AND patient_id = ?'
        ).get(req.params.id, req.patient.id);

        if (!appointment) {
            return res.status(404).json({ error: 'Appointment not found' });
        }

        if (appointment.status === 'cancelled') {
            return res.status(400).json({ error: 'Appointment is already cancelled' });
        }

        req.db.prepare(
            "UPDATE appointments SET status = 'cancelled', updated_at = CURRENT_TIMESTAMP WHERE id = ?"
        ).run(req.params.id);

        res.json({ message: 'Appointment cancelled successfully' });
    } catch (err) {
        console.error('Cancel error:', err);
        res.status(500).json({ error: 'Failed to cancel appointment' });
    }
});

// Admin: Get all appointments
router.get('/all', authenticateAdmin, (req, res) => {
    try {
        const { date, status, service_type } = req.query;
        let query = `
            SELECT a.*, p.first_name, p.last_name, p.email, p.phone
            FROM appointments a
            JOIN patients p ON a.patient_id = p.id
            WHERE 1=1
        `;
        const params = [];

        if (date) {
            query += ' AND a.appointment_date = ?';
            params.push(date);
        }
        if (status) {
            query += ' AND a.status = ?';
            params.push(status);
        }
        if (service_type) {
            query += ' AND a.service_type = ?';
            params.push(service_type);
        }

        query += ' ORDER BY a.appointment_date ASC, a.appointment_time ASC';

        const appointments = req.db.prepare(query).all(...params);
        res.json(appointments);
    } catch (err) {
        console.error('Admin appointments error:', err);
        res.status(500).json({ error: 'Failed to fetch appointments' });
    }
});

// Admin: Update appointment status
router.patch('/:id/status', authenticateAdmin, (req, res) => {
    try {
        const { status } = req.body;
        const validStatuses = ['scheduled', 'confirmed', 'in_progress', 'completed', 'cancelled', 'no_show'];

        if (!validStatuses.includes(status)) {
            return res.status(400).json({ error: 'Invalid status' });
        }

        req.db.prepare(
            'UPDATE appointments SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?'
        ).run(status, req.params.id);

        res.json({ message: 'Appointment status updated' });
    } catch (err) {
        console.error('Status update error:', err);
        res.status(500).json({ error: 'Failed to update status' });
    }
});

module.exports = router;
