/**
 * Notification handler triggered by SNS when a high score is achieved.
 * Routes notifications to configured channels (webhook, log).
 */
exports.handler = async (event) => {
  for (const record of event.Records) {
    const message = JSON.parse(record.Sns.Message);
    const { playerId, playerName, score, timestamp } = message;

    console.log(
      JSON.stringify({
        event: 'high_score_notification',
        playerId,
        playerName,
        score,
        timestamp,
        snsMessageId: record.Sns.MessageId,
      })
    );

    // Webhook notification (configure WEBHOOK_URL env var)
    const webhookUrl = process.env.WEBHOOK_URL;
    if (webhookUrl) {
      try {
        const response = await fetch(webhookUrl, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            text: `New high score! ${playerName} scored ${score}`,
            score,
            playerName,
            playerId,
            timestamp,
          }),
        });

        if (!response.ok) {
          console.error(`Webhook failed: HTTP ${response.status}`);
        }
      } catch (err) {
        console.error(`Webhook error: ${err.message}`);
      }
    }
  }

  return { statusCode: 200, body: 'Notifications sent' };
};
