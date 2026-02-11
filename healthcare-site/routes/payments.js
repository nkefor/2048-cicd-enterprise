const express = require('express');
const router = express.Router();
const { authenticatePatient } = require('../middleware/auth');

// Service pricing
const SERVICE_PRICES = {
    telehealth: { amount: 15000, description: 'Telehealth Consultation' },         // $150.00
    dot_physical: { amount: 12500, description: 'DOT Physical Examination' },      // $125.00
    consultation: { amount: 10000, description: 'General Consultation' },           // $100.00
    follow_up: { amount: 7500, description: 'Follow-up Visit' }                    // $75.00
};

// Get service prices
router.get('/prices', (req, res) => {
    const prices = {};
    for (const [key, value] of Object.entries(SERVICE_PRICES)) {
        prices[key] = {
            amount: value.amount / 100,
            formatted: `$${(value.amount / 100).toFixed(2)}`,
            description: value.description
        };
    }
    res.json(prices);
});

// Create payment intent (Stripe)
router.post('/create-intent', authenticatePatient, async (req, res) => {
    try {
        const { appointment_id, service_type } = req.body;

        if (!service_type || !SERVICE_PRICES[service_type]) {
            return res.status(400).json({ error: 'Invalid service type' });
        }

        const stripeKey = process.env.STRIPE_SECRET_KEY;
        if (!stripeKey || stripeKey.includes('your_stripe')) {
            // Demo mode - return mock payment intent
            const payment = req.db.prepare(`
                INSERT INTO payments (patient_id, appointment_id, amount, description, status)
                VALUES (?, ?, ?, ?, 'pending')
            `).run(
                req.patient.id,
                appointment_id || null,
                SERVICE_PRICES[service_type].amount,
                SERVICE_PRICES[service_type].description
            );

            return res.json({
                demo_mode: true,
                payment_id: payment.lastInsertRowid,
                client_secret: 'demo_client_secret_' + payment.lastInsertRowid,
                amount: SERVICE_PRICES[service_type].amount,
                message: 'Running in demo mode. Configure STRIPE_SECRET_KEY for live payments.'
            });
        }

        const stripe = require('stripe')(stripeKey);

        const patient = req.db.prepare('SELECT * FROM patients WHERE id = ?').get(req.patient.id);

        const paymentIntent = await stripe.paymentIntents.create({
            amount: SERVICE_PRICES[service_type].amount,
            currency: 'usd',
            metadata: {
                patient_id: req.patient.id.toString(),
                appointment_id: appointment_id ? appointment_id.toString() : '',
                service_type
            },
            receipt_email: patient.email,
            description: SERVICE_PRICES[service_type].description
        });

        // Record payment in database
        req.db.prepare(`
            INSERT INTO payments (patient_id, appointment_id, amount, stripe_payment_intent_id, description, status)
            VALUES (?, ?, ?, ?, ?, 'processing')
        `).run(
            req.patient.id,
            appointment_id || null,
            SERVICE_PRICES[service_type].amount,
            paymentIntent.id,
            SERVICE_PRICES[service_type].description
        );

        res.json({
            client_secret: paymentIntent.client_secret,
            amount: SERVICE_PRICES[service_type].amount,
            publishable_key: process.env.STRIPE_PUBLISHABLE_KEY
        });
    } catch (err) {
        console.error('Payment intent error:', err);
        res.status(500).json({ error: 'Failed to create payment' });
    }
});

// Confirm demo payment
router.post('/confirm-demo', authenticatePatient, (req, res) => {
    try {
        const { payment_id } = req.body;

        req.db.prepare(
            "UPDATE payments SET status = 'succeeded', payment_method = 'demo' WHERE id = ? AND patient_id = ?"
        ).run(payment_id, req.patient.id);

        // Also confirm the associated appointment
        const payment = req.db.prepare('SELECT * FROM payments WHERE id = ?').get(payment_id);
        if (payment && payment.appointment_id) {
            req.db.prepare(
                "UPDATE appointments SET status = 'confirmed', updated_at = CURRENT_TIMESTAMP WHERE id = ?"
            ).run(payment.appointment_id);
        }

        res.json({ message: 'Payment confirmed (demo mode)', status: 'succeeded' });
    } catch (err) {
        console.error('Demo confirm error:', err);
        res.status(500).json({ error: 'Failed to confirm payment' });
    }
});

// Stripe Webhook
router.post('/webhook', express.raw({ type: 'application/json' }), (req, res) => {
    const stripeKey = process.env.STRIPE_SECRET_KEY;
    if (!stripeKey || stripeKey.includes('your_stripe')) {
        return res.json({ received: true, demo: true });
    }

    const stripe = require('stripe')(stripeKey);
    const sig = req.headers['stripe-signature'];

    let event;
    try {
        event = stripe.webhooks.constructEvent(req.body, sig, process.env.STRIPE_WEBHOOK_SECRET);
    } catch (err) {
        console.error('Webhook signature verification failed:', err.message);
        return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    switch (event.type) {
        case 'payment_intent.succeeded': {
            const paymentIntent = event.data.object;
            req.db.prepare(`
                UPDATE payments SET status = 'succeeded', stripe_charge_id = ? WHERE stripe_payment_intent_id = ?
            `).run(paymentIntent.latest_charge, paymentIntent.id);

            // Update appointment status
            if (paymentIntent.metadata.appointment_id) {
                req.db.prepare(
                    "UPDATE appointments SET status = 'confirmed', updated_at = CURRENT_TIMESTAMP WHERE id = ?"
                ).run(paymentIntent.metadata.appointment_id);
            }
            break;
        }
        case 'payment_intent.payment_failed': {
            const paymentIntent = event.data.object;
            req.db.prepare(
                "UPDATE payments SET status = 'failed' WHERE stripe_payment_intent_id = ?"
            ).run(paymentIntent.id);
            break;
        }
    }

    res.json({ received: true });
});

// Get patient's payment history
router.get('/history', authenticatePatient, (req, res) => {
    try {
        const payments = req.db.prepare(`
            SELECT p.*, a.service_type, a.appointment_date, a.appointment_time
            FROM payments p
            LEFT JOIN appointments a ON p.appointment_id = a.id
            WHERE p.patient_id = ?
            ORDER BY p.created_at DESC
        `).all(req.patient.id);

        res.json(payments);
    } catch (err) {
        console.error('Payment history error:', err);
        res.status(500).json({ error: 'Failed to fetch payment history' });
    }
});

module.exports = router;
