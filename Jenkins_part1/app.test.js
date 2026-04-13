const request = require('supertest');
const app = require('./app');

describe('Task Management API', () => {
    it('GET /health should return 200 and status OK', async () => {
        const res = await request(app).get('/health');
        expect(res.statusCode).toEqual(200);
        expect(res.body.status).toBe('OK');
    });

    it('GET /tasks should return a list of tasks', async () => {
        const res = await request(app).get('/tasks');
        expect(res.statusCode).toEqual(200);
        expect(Array.isArray(res.body)).toBeTruthy();
    });
});