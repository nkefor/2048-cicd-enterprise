const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand } = require('@aws-sdk/lib-dynamodb');
const { SNSClient, PublishCommand } = require('@aws-sdk/client-sns');

const ddbClient = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const snsClient = new SNSClient({});

const TABLE_NAME = process.env.TABLE_NAME;
const SNS_TOPIC_ARN = process.env.SNS_TOPIC_ARN;

// Threshold for "high score" notification
const HIGH_SCORE_THRESHOLD = 2048;

/**
 * Processes new score records from DynamoDB Streams.
 * - Writes a GLOBAL leaderboard entry for high scores
 * - Publishes to SNS if score exceeds threshold
 */
exports.handler = async (event) => {
  for (const record of event.Records) {
    if (record.eventName !== 'INSERT') continue;

    const newImage = record.dynamodb.NewImage;
    const score = parseInt(newImage.score.N, 10);
    const playerId = newImage.playerId.S;
    const playerName = newImage.playerName?.S || 'Anonymous';
    const timestamp = newImage.timestamp.S;

    // Skip if this is already a GLOBAL leaderboard entry
    if (playerId === 'GLOBAL') continue;

    // Write a GLOBAL partition entry for the leaderboard query
    await ddbClient.send(
      new PutCommand({
        TableName: TABLE_NAME,
        Item: {
          playerId: 'GLOBAL',
          timestamp,
          score,
          playerName,
          originalPlayerId: playerId,
        },
      })
    );

    // Notify if high score
    if (score >= HIGH_SCORE_THRESHOLD && SNS_TOPIC_ARN) {
      await snsClient.send(
        new PublishCommand({
          TopicArn: SNS_TOPIC_ARN,
          Subject: `New High Score: ${score} by ${playerName}`,
          Message: JSON.stringify({
            event: 'high_score',
            playerId,
            playerName,
            score,
            timestamp,
          }),
        })
      );
    }
  }

  return { statusCode: 200, body: 'Processed' };
};
