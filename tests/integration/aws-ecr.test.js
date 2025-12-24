/**
 * @jest-environment node
 * AWS ECR Integration Tests
 * Tests ECR repository configuration and accessibility
 */

const { ECRClient, DescribeRepositoriesCommand, GetAuthorizationTokenCommand } = require('@aws-sdk/client-ecr');

// Skip tests if AWS credentials not available
const skipIfNoAWS = () => {
  const hasRegion = process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION;
  const hasCredentials = process.env.AWS_ACCESS_KEY_ID || process.env.AWS_PROFILE;

  if (!hasRegion || !hasCredentials) {
    return true;
  }
  return false;
};

describe('AWS ECR Integration Tests', () => {
  let ecrClient;
  const region = process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION || 'us-east-1';

  beforeAll(() => {
    if (skipIfNoAWS()) {
      console.log('⚠️  Skipping AWS ECR tests - AWS credentials not configured');
      return;
    }

    ecrClient = new ECRClient({ region });
  });

  test.skipIf(skipIfNoAWS())('should be able to connect to ECR', async () => {
    const command = new GetAuthorizationTokenCommand({});
    const response = await ecrClient.send(command);

    expect(response).toBeDefined();
    expect(response.authorizationData).toBeDefined();
    expect(response.authorizationData.length).toBeGreaterThan(0);
  }, 30000);

  test.skipIf(skipIfNoAWS())('should find ECR repositories', async () => {
    const command = new DescribeRepositoriesCommand({});

    try {
      const response = await ecrClient.send(command);
      expect(response).toBeDefined();
      expect(response.repositories).toBeDefined();

      // Log repository names for debugging
      if (response.repositories.length > 0) {
        console.log('Found ECR repositories:', response.repositories.map(r => r.repositoryName).join(', '));
      }
    } catch (error) {
      // It's okay if there are no repositories yet
      if (error.name === 'RepositoryNotFoundException') {
        console.log('No ECR repositories found - this is expected if infrastructure not deployed yet');
      } else {
        throw error;
      }
    }
  }, 30000);

  test.skipIf(skipIfNoAWS())('should validate game-2048 repository if it exists', async () => {
    const repoName = 'game-2048';
    const command = new DescribeRepositoriesCommand({
      repositoryNames: [repoName]
    });

    try {
      const response = await ecrClient.send(command);
      const repo = response.repositories[0];

      expect(repo).toBeDefined();
      expect(repo.repositoryName).toBe(repoName);
      expect(repo.repositoryUri).toContain(repoName);
      expect(repo.repositoryUri).toContain('.dkr.ecr.');

      // Check if image scanning is enabled (security best practice)
      if (repo.imageScanningConfiguration) {
        console.log(`Image scanning: ${repo.imageScanningConfiguration.scanOnPush ? 'enabled' : 'disabled'}`);
      }

      // Check encryption configuration
      if (repo.encryptionConfiguration) {
        console.log(`Encryption: ${repo.encryptionConfiguration.encryptionType}`);
      }

    } catch (error) {
      if (error.name === 'RepositoryNotFoundException') {
        console.log(`Repository '${repoName}' not found - infrastructure may not be deployed yet`);
      } else {
        throw error;
      }
    }
  }, 30000);

  test.skipIf(skipIfNoAWS())('should have appropriate IAM permissions for ECR', async () => {
    // Test basic ECR permissions
    const command = new GetAuthorizationTokenCommand({});

    try {
      await ecrClient.send(command);
      // If we get here, we have permission
      expect(true).toBe(true);
    } catch (error) {
      if (error.name === 'AccessDeniedException') {
        fail('IAM permissions insufficient for ECR operations');
      } else {
        throw error;
      }
    }
  }, 30000);
});
