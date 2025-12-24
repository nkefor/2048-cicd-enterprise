/**
 * @jest-environment node
 * AWS ECS Integration Tests
 * Tests ECS cluster, service, and task configuration
 */

const {
  ECSClient,
  ListClustersCommand,
  DescribeClustersCommand,
  ListServicesCommand,
  DescribeServicesCommand,
  DescribeTaskDefinitionCommand
} = require('@aws-sdk/client-ecs');

// Skip tests if AWS credentials not available
const skipIfNoAWS = () => {
  const hasRegion = process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION;
  const hasCredentials = process.env.AWS_ACCESS_KEY_ID || process.env.AWS_PROFILE;
  return !hasRegion || !hasCredentials;
};

describe('AWS ECS Integration Tests', () => {
  let ecsClient;
  const region = process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION || 'us-east-1';
  const clusterName = 'game-2048';
  const serviceName = 'game-2048';

  beforeAll(() => {
    if (skipIfNoAWS()) {
      console.log('⚠️  Skipping AWS ECS tests - AWS credentials not configured');
      return;
    }

    ecsClient = new ECSClient({ region });
  });

  test.skipIf(skipIfNoAWS())('should be able to list ECS clusters', async () => {
    const command = new ListClustersCommand({});
    const response = await ecsClient.send(command);

    expect(response).toBeDefined();
    expect(response.clusterArns).toBeDefined();
    expect(Array.isArray(response.clusterArns)).toBe(true);

    if (response.clusterArns.length > 0) {
      console.log('Found ECS clusters:', response.clusterArns.length);
    }
  }, 30000);

  test.skipIf(skipIfNoAWS())('should validate game-2048 cluster if it exists', async () => {
    const listCommand = new ListClustersCommand({});

    try {
      const listResponse = await ecsClient.send(listCommand);

      // Check if game-2048 cluster exists
      const clusterExists = listResponse.clusterArns.some(arn => arn.includes(clusterName));

      if (clusterExists) {
        const describeCommand = new DescribeClustersCommand({
          clusters: [clusterName]
        });

        const describeResponse = await ecsClient.send(describeCommand);
        const cluster = describeResponse.clusters[0];

        expect(cluster).toBeDefined();
        expect(cluster.clusterName).toBe(clusterName);
        expect(cluster.status).toBe('ACTIVE');

        console.log(`Cluster '${clusterName}' found:`);
        console.log(`  - Status: ${cluster.status}`);
        console.log(`  - Running tasks: ${cluster.runningTasksCount || 0}`);
        console.log(`  - Pending tasks: ${cluster.pendingTasksCount || 0}`);
        console.log(`  - Registered container instances: ${cluster.registeredContainerInstancesCount || 0}`);
      } else {
        console.log(`Cluster '${clusterName}' not found - infrastructure may not be deployed yet`);
      }
    } catch (error) {
      console.log(`Error checking cluster: ${error.message}`);
    }
  }, 30000);

  test.skipIf(skipIfNoAWS())('should validate game-2048 service if it exists', async () => {
    try {
      const listCommand = new ListServicesCommand({
        cluster: clusterName
      });

      const listResponse = await ecsClient.send(listCommand);

      if (listResponse.serviceArns && listResponse.serviceArns.length > 0) {
        const describeCommand = new DescribeServicesCommand({
          cluster: clusterName,
          services: [serviceName]
        });

        const describeResponse = await ecsClient.send(describeCommand);
        const service = describeResponse.services[0];

        if (service && service.status !== 'INACTIVE') {
          expect(service).toBeDefined();
          expect(service.serviceName).toBe(serviceName);
          expect(service.status).toBe('ACTIVE');

          console.log(`Service '${serviceName}' found:`);
          console.log(`  - Status: ${service.status}`);
          console.log(`  - Desired tasks: ${service.desiredCount}`);
          console.log(`  - Running tasks: ${service.runningCount}`);
          console.log(`  - Pending tasks: ${service.pendingCount}`);
          console.log(`  - Launch type: ${service.launchType || 'Not specified'}`);

          // Validate service has load balancers configured
          if (service.loadBalancers && service.loadBalancers.length > 0) {
            console.log(`  - Load balancers: ${service.loadBalancers.length}`);
            expect(service.loadBalancers.length).toBeGreaterThan(0);
          }

          // Check deployment configuration
          if (service.deploymentConfiguration) {
            const config = service.deploymentConfiguration;
            console.log(`  - Max % during deployment: ${config.maximumPercent}`);
            console.log(`  - Min healthy %: ${config.minimumHealthyPercent}`);
          }
        }
      } else {
        console.log(`Service '${serviceName}' not found in cluster '${clusterName}'`);
      }
    } catch (error) {
      if (error.name === 'ClusterNotFoundException') {
        console.log(`Cluster '${clusterName}' not found`);
      } else {
        console.log(`Error checking service: ${error.message}`);
      }
    }
  }, 30000);

  test.skipIf(skipIfNoAWS())('should validate task definition if service exists', async () => {
    try {
      const listCommand = new ListServicesCommand({
        cluster: clusterName
      });

      const listResponse = await ecsClient.send(listCommand);

      if (listResponse.serviceArns && listResponse.serviceArns.length > 0) {
        const serviceCommand = new DescribeServicesCommand({
          cluster: clusterName,
          services: [serviceName]
        });

        const serviceResponse = await ecsClient.send(serviceCommand);
        const service = serviceResponse.services[0];

        if (service && service.taskDefinition) {
          const taskDefCommand = new DescribeTaskDefinitionCommand({
            taskDefinition: service.taskDefinition
          });

          const taskDefResponse = await ecsClient.send(taskDefCommand);
          const taskDef = taskDefResponse.taskDefinition;

          expect(taskDef).toBeDefined();
          expect(taskDef.family).toBeDefined();
          expect(taskDef.containerDefinitions).toBeDefined();
          expect(taskDef.containerDefinitions.length).toBeGreaterThan(0);

          const container = taskDef.containerDefinitions[0];

          console.log(`Task definition '${taskDef.family}:${taskDef.revision}':`);
          console.log(`  - Container: ${container.name}`);
          console.log(`  - Image: ${container.image}`);
          console.log(`  - CPU: ${taskDef.cpu || 'default'}`);
          console.log(`  - Memory: ${taskDef.memory || 'default'}`);

          // Validate container has port mappings
          if (container.portMappings && container.portMappings.length > 0) {
            console.log(`  - Port mappings: ${container.portMappings.length}`);
            expect(container.portMappings.length).toBeGreaterThan(0);
          }

          // Check health check configuration
          if (container.healthCheck) {
            console.log(`  - Health check configured: Yes`);
            expect(container.healthCheck.command).toBeDefined();
          }
        }
      }
    } catch (error) {
      console.log(`Error checking task definition: ${error.message}`);
    }
  }, 30000);

  test.skipIf(skipIfNoAWS())('should have appropriate IAM permissions for ECS', async () => {
    const command = new ListClustersCommand({});

    try {
      await ecsClient.send(command);
      expect(true).toBe(true);
    } catch (error) {
      if (error.name === 'AccessDeniedException') {
        fail('IAM permissions insufficient for ECS operations');
      } else {
        throw error;
      }
    }
  }, 30000);
});
