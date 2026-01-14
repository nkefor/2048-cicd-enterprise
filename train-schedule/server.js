const express = require('express');
const path = require('path');
const app = express();
const PORT = process.env.PORT || 3000;

// Set view engine
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

// Serve static files
app.use(express.static(path.join(__dirname, 'public')));

// Train schedule data
const trains = [
  {
    trainNumber: 'EXP-101',
    destination: 'New York',
    departure: '08:00 AM',
    arrival: '12:30 PM',
    platform: '1A',
    status: 'On Time'
  },
  {
    trainNumber: 'EXP-202',
    destination: 'Boston',
    departure: '09:15 AM',
    arrival: '01:45 PM',
    platform: '2B',
    status: 'On Time'
  },
  {
    trainNumber: 'EXP-303',
    destination: 'Washington DC',
    departure: '10:30 AM',
    arrival: '03:00 PM',
    platform: '3C',
    status: 'Delayed'
  },
  {
    trainNumber: 'EXP-404',
    destination: 'Philadelphia',
    departure: '11:45 AM',
    arrival: '02:15 PM',
    platform: '4D',
    status: 'On Time'
  },
  {
    trainNumber: 'EXP-505',
    destination: 'Baltimore',
    departure: '01:00 PM',
    arrival: '04:30 PM',
    platform: '5E',
    status: 'On Time'
  },
  {
    trainNumber: 'EXP-606',
    destination: 'Chicago',
    departure: '02:30 PM',
    arrival: '10:45 PM',
    platform: '6F',
    status: 'On Time'
  }
];

// Routes
app.get('/', (req, res) => {
  res.render('index', { trains });
});

app.get('/api/trains', (req, res) => {
  res.json({ trains, timestamp: new Date().toISOString() });
});

app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    uptime: process.uptime(),
    timestamp: new Date().toISOString()
  });
});

// Start server
const server = app.listen(PORT, () => {
  console.log(`🚂 Train Schedule App running on port ${PORT}`);
  console.log(`📍 Access at: http://localhost:${PORT}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM signal received: closing HTTP server');
  server.close(() => {
    console.log('HTTP server closed');
  });
});

module.exports = app;
