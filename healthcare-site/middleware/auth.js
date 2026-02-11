const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'dev-jwt-secret';

// Authenticate patient JWT token
function authenticatePatient(req, res, next) {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Authentication required' });
    }

    const token = authHeader.split(' ')[1];
    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        if (decoded.type !== 'patient') {
            return res.status(403).json({ error: 'Access denied' });
        }
        req.patient = decoded;
        next();
    } catch (err) {
        return res.status(401).json({ error: 'Invalid or expired token' });
    }
}

// Authenticate admin/provider JWT token
function authenticateAdmin(req, res, next) {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Authentication required' });
    }

    const token = authHeader.split(' ')[1];
    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        if (decoded.type !== 'admin' && decoded.type !== 'provider') {
            return res.status(403).json({ error: 'Admin access required' });
        }
        req.admin = decoded;
        next();
    } catch (err) {
        return res.status(401).json({ error: 'Invalid or expired token' });
    }
}

// Generate JWT token
function generateToken(payload, expiresIn) {
    return jwt.sign(payload, JWT_SECRET, {
        expiresIn: expiresIn || process.env.JWT_EXPIRES_IN || '7d'
    });
}

module.exports = { authenticatePatient, authenticateAdmin, generateToken };
