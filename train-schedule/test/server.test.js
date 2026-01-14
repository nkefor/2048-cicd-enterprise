const request = require('supertest');
const app = require('../server');

describe('Train Schedule API Tests', () => {

  describe('GET /', () => {
    it('should return 200 and render the main page', async () => {
      const response = await request(app).get('/');
      expect(response.status).toBe(200);
      expect(response.type).toBe('text/html');
    });
  });

  describe('GET /api/trains', () => {
    it('should return 200 and JSON data', async () => {
      const response = await request(app).get('/api/trains');
      expect(response.status).toBe(200);
      expect(response.type).toBe('application/json');
    });

    it('should return trains array', async () => {
      const response = await request(app).get('/api/trains');
      expect(response.body).toHaveProperty('trains');
      expect(Array.isArray(response.body.trains)).toBe(true);
    });

    it('should return timestamp', async () => {
      const response = await request(app).get('/api/trains');
      expect(response.body).toHaveProperty('timestamp');
    });

    it('should return at least one train', async () => {
      const response = await request(app).get('/api/trains');
      expect(response.body.trains.length).toBeGreaterThan(0);
    });

    it('should have correct train data structure', async () => {
      const response = await request(app).get('/api/trains');
      const train = response.body.trains[0];
      expect(train).toHaveProperty('trainNumber');
      expect(train).toHaveProperty('destination');
      expect(train).toHaveProperty('departure');
      expect(train).toHaveProperty('arrival');
      expect(train).toHaveProperty('platform');
      expect(train).toHaveProperty('status');
    });
  });

  describe('GET /health', () => {
    it('should return 200', async () => {
      const response = await request(app).get('/health');
      expect(response.status).toBe(200);
    });

    it('should return healthy status', async () => {
      const response = await request(app).get('/health');
      expect(response.body).toHaveProperty('status', 'healthy');
    });

    it('should return uptime', async () => {
      const response = await request(app).get('/health');
      expect(response.body).toHaveProperty('uptime');
      expect(typeof response.body.uptime).toBe('number');
    });

    it('should return timestamp', async () => {
      const response = await request(app).get('/health');
      expect(response.body).toHaveProperty('timestamp');
    });
  });

  describe('GET /nonexistent', () => {
    it('should return 404 for non-existent routes', async () => {
      const response = await request(app).get('/nonexistent');
      expect(response.status).toBe(404);
    });
  });
});
