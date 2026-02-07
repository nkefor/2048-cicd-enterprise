/**
 * Health check endpoint - no authentication required.
 * Returns service status and metadata for monitoring systems.
 */
exports.handler = async () => {
  return {
    statusCode: 200,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-cache',
    },
    body: JSON.stringify({
      status: 'healthy',
      service: 'game-2048-api',
      timestamp: new Date().toISOString(),
      region: process.env.REGION || 'unknown',
    }),
  };
};
