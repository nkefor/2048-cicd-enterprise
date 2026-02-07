const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const {
  DynamoDBDocumentClient,
  PutCommand,
  QueryCommand,
} = require('@aws-sdk/lib-dynamodb');

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);
const TABLE_NAME = process.env.TABLE_NAME;

const headers = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
};

/**
 * GET /scores?playerId=abc123
 * Returns scores for a specific player.
 */
exports.getScores = async (event) => {
  const playerId = event.queryStringParameters?.playerId;

  if (!playerId) {
    return {
      statusCode: 400,
      headers,
      body: JSON.stringify({ error: 'playerId query parameter is required' }),
    };
  }

  const result = await docClient.send(
    new QueryCommand({
      TableName: TABLE_NAME,
      KeyConditionExpression: 'playerId = :pid',
      ExpressionAttributeValues: { ':pid': playerId },
      ScanIndexForward: false,
      Limit: 50,
    })
  );

  return {
    statusCode: 200,
    headers,
    body: JSON.stringify({
      playerId,
      scores: result.Items || [],
      count: result.Count || 0,
    }),
  };
};

/**
 * POST /scores
 * Body: { "playerId": "abc123", "score": 2048, "playerName": "Player1" }
 */
exports.submitScore = async (event) => {
  let body;
  try {
    body = JSON.parse(event.body);
  } catch {
    return {
      statusCode: 400,
      headers,
      body: JSON.stringify({ error: 'Invalid JSON body' }),
    };
  }

  const { playerId, score, playerName } = body;

  if (!playerId || score === undefined || !playerName) {
    return {
      statusCode: 400,
      headers,
      body: JSON.stringify({
        error: 'playerId, score, and playerName are required',
      }),
    };
  }

  if (typeof score !== 'number' || score < 0) {
    return {
      statusCode: 400,
      headers,
      body: JSON.stringify({ error: 'score must be a non-negative number' }),
    };
  }

  const timestamp = new Date().toISOString();

  await docClient.send(
    new PutCommand({
      TableName: TABLE_NAME,
      Item: {
        playerId,
        timestamp,
        score,
        playerName,
        submittedAt: Date.now(),
      },
    })
  );

  return {
    statusCode: 201,
    headers,
    body: JSON.stringify({
      message: 'Score submitted',
      playerId,
      score,
      timestamp,
    }),
  };
};

/**
 * GET /scores/top?limit=10
 * Returns top scores across all players using the GSI.
 */
exports.getLeaderboard = async (event) => {
  const limit = Math.min(
    parseInt(event.queryStringParameters?.limit || '10', 10),
    100
  );

  // Query the GSI, scanning all players and sorting by score descending.
  // For a production leaderboard, use a dedicated partition key like "GLOBAL".
  const result = await docClient.send(
    new QueryCommand({
      TableName: TABLE_NAME,
      IndexName: 'score-index',
      KeyConditionExpression: 'playerId = :pid',
      ExpressionAttributeValues: { ':pid': 'GLOBAL' },
      ScanIndexForward: false,
      Limit: limit,
    })
  );

  return {
    statusCode: 200,
    headers,
    body: JSON.stringify({
      leaderboard: result.Items || [],
      count: result.Count || 0,
    }),
  };
};
