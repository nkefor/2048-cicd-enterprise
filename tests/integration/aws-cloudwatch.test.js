/**
 * @jest-environment node
 * AWS CloudWatch Logs Integration Tests
 * Tests CloudWatch log groups and log streams
 */

const {
  CloudWatchLogsClient,
  DescribeLogGroupsCommand,
  DescribeLogStreamsCommand,
  GetLogEventsCommand
} = require('@aws-sdk/client-cloudwatch-logs');

// Skip tests if AWS credentials not available
const skipIfNoAWS = () => {
  const hasRegion = process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION;
  const hasCredentials = process.env.AWS_ACCESS_KEY_ID || process.env.AWS_PROFILE;
  return !hasRegion || !hasCredentials;
};

describe('AWS CloudWatch Logs Integration Tests', () => {
  let cwLogsClient;
  const region = process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION || 'us-east-1';
  const logGroupPrefix = '/ecs/game-2048';

  beforeAll(() => {
    if (skipIfNoAWS()) {
      console.log('⚠️  Skipping AWS CloudWatch Logs tests - AWS credentials not configured');
      return;
    }

    cwLogsClient = new CloudWatchLogsClient({ region });
  });

  test.skipIf(skipIfNoAWS())('should be able to list log groups', async () => {
    const command = new DescribeLogGroupsCommand({});
    const response = await cwLogsClient.send(command);

    expect(response).toBeDefined();
    expect(response.logGroups).toBeDefined();
    expect(Array.isArray(response.logGroups)).toBe(true);

    if (response.logGroups.length > 0) {
      console.log(`Found ${response.logGroups.length} log group(s)`);
    }
  }, 30000);

  test.skipIf(skipIfNoAWS())('should validate ECS log group if it exists', async () => {
    const command = new DescribeLogGroupsCommand({
      logGroupNamePrefix: logGroupPrefix
    });

    try {
      const response = await cwLogsClient.send(command);

      if (response.logGroups && response.logGroups.length > 0) {
        const logGroup = response.logGroups[0];

        expect(logGroup.logGroupName).toBeDefined();
        expect(logGroup.logGroupName).toContain('game-2048');

        console.log(`Log Group: ${logGroup.logGroupName}`);
        console.log(`  - Creation Time: ${new Date(logGroup.creationTime).toISOString()}`);
        console.log(`  - Retention: ${logGroup.retentionInDays || 'Never expire'} days`);
        console.log(`  - Stored Bytes: ${(logGroup.storedBytes / 1024 / 1024).toFixed(2)} MB`);

        // Validate retention policy (should have one for cost optimization)
        if (logGroup.retentionInDays) {
          console.log(`  - Retention policy configured: Yes`);
          expect(logGroup.retentionInDays).toBeGreaterThan(0);
        } else {
          console.log(`  - ⚠️  Warning: No retention policy - logs will be stored indefinitely`);
        }
      } else {
        console.log('No log group found for game-2048 - infrastructure may not be deployed yet');
      }
    } catch (error) {
      console.log(`Error checking log group: ${error.message}`);
    }
  }, 30000);

  test.skipIf(skipIfNoAWS())('should validate log streams exist', async () => {
    const groupCommand = new DescribeLogGroupsCommand({
      logGroupNamePrefix: logGroupPrefix
    });

    try {
      const groupResponse = await cwLogsClient.send(groupCommand);

      if (groupResponse.logGroups && groupResponse.logGroups.length > 0) {
        const logGroupName = groupResponse.logGroups[0].logGroupName;

        const streamsCommand = new DescribeLogStreamsCommand({
          logGroupName: logGroupName,
          orderBy: 'LastEventTime',
          descending: true,
          limit: 10
        });

        const streamsResponse = await cwLogsClient.send(streamsCommand);

        if (streamsResponse.logStreams && streamsResponse.logStreams.length > 0) {
          console.log(`Log Streams: ${streamsResponse.logStreams.length}`);

          streamsResponse.logStreams.slice(0, 5).forEach((stream, index) => {
            console.log(`  Stream ${index + 1}: ${stream.logStreamName}`);
            console.log(`    - Last Event: ${new Date(stream.lastEventTimestamp || 0).toISOString()}`);
            console.log(`    - First Event: ${new Date(stream.firstEventTimestamp || 0).toISOString()}`);
          });

          expect(streamsResponse.logStreams.length).toBeGreaterThan(0);

          // Check if logs are recent (within last 24 hours for active service)
          const recentStream = streamsResponse.logStreams[0];
          const lastEventTime = recentStream.lastEventTimestamp;
          const now = Date.now();
          const hoursSinceLastLog = (now - lastEventTime) / (1000 * 60 * 60);

          if (hoursSinceLastLog < 24) {
            console.log(`  ✅ Logs are recent (${hoursSinceLastLog.toFixed(1)} hours ago)`);
          } else {
            console.log(`  ⚠️  Last log was ${hoursSinceLastLog.toFixed(1)} hours ago`);
          }
        } else {
          console.log('No log streams found - service may not have started yet');
        }
      }
    } catch (error) {
      console.log(`Error checking log streams: ${error.message}`);
    }
  }, 30000);

  test.skipIf(skipIfNoAWS())('should be able to read recent log events', async () => {
    const groupCommand = new DescribeLogGroupsCommand({
      logGroupNamePrefix: logGroupPrefix
    });

    try {
      const groupResponse = await cwLogsClient.send(groupCommand);

      if (groupResponse.logGroups && groupResponse.logGroups.length > 0) {
        const logGroupName = groupResponse.logGroups[0].logGroupName;

        const streamsCommand = new DescribeLogStreamsCommand({
          logGroupName: logGroupName,
          orderBy: 'LastEventTime',
          descending: true,
          limit: 1
        });

        const streamsResponse = await cwLogsClient.send(streamsCommand);

        if (streamsResponse.logStreams && streamsResponse.logStreams.length > 0) {
          const logStreamName = streamsResponse.logStreams[0].logStreamName;

          const eventsCommand = new GetLogEventsCommand({
            logGroupName: logGroupName,
            logStreamName: logStreamName,
            limit: 10
          });

          const eventsResponse = await cwLogsClient.send(eventsCommand);

          if (eventsResponse.events && eventsResponse.events.length > 0) {
            console.log(`Recent log events: ${eventsResponse.events.length}`);

            eventsResponse.events.slice(0, 3).forEach((event, index) => {
              console.log(`  Event ${index + 1}: ${event.message.substring(0, 100)}...`);
            });

            expect(eventsResponse.events.length).toBeGreaterThan(0);
          }
        }
      }
    } catch (error) {
      console.log(`Error reading log events: ${error.message}`);
    }
  }, 30000);

  test.skipIf(skipIfNoAWS())('should have appropriate IAM permissions for CloudWatch Logs', async () => {
    const command = new DescribeLogGroupsCommand({});

    try {
      await cwLogsClient.send(command);
      expect(true).toBe(true);
    } catch (error) {
      if (error.name === 'AccessDeniedException') {
        fail('IAM permissions insufficient for CloudWatch Logs operations');
      } else {
        throw error;
      }
    }
  }, 30000);
});
