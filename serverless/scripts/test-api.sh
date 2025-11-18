#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if API_URL is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: API Gateway URL is required${NC}"
    echo "Usage: ./test-api.sh <API_GATEWAY_URL>"
    echo "Example: ./test-api.sh https://abc123.execute-api.us-east-1.amazonaws.com/dev"
    exit 1
fi

API_URL="$1"
echo -e "${GREEN}Testing API at: $API_URL${NC}\n"

# Test 1: Create a task
echo -e "${YELLOW}Test 1: Creating a task...${NC}"
CREATE_RESPONSE=$(curl -s -X POST "$API_URL/tasks" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Task from Script",
    "description": "This is an automated test task",
    "priority": "medium",
    "userId": "test-user-123",
    "tags": ["test", "automation"]
  }')

echo "Response: $CREATE_RESPONSE"

# Extract taskId from response
TASK_ID=$(echo $CREATE_RESPONSE | grep -o '"taskId":"[^"]*' | sed 's/"taskId":"//')

if [ -z "$TASK_ID" ]; then
    echo -e "${RED}✗ Failed to create task${NC}\n"
    exit 1
fi

echo -e "${GREEN}✓ Task created successfully with ID: $TASK_ID${NC}\n"
sleep 2

# Test 2: Get the created task
echo -e "${YELLOW}Test 2: Getting task by ID...${NC}"
GET_RESPONSE=$(curl -s -X GET "$API_URL/tasks/$TASK_ID")
echo "Response: $GET_RESPONSE"

if echo $GET_RESPONSE | grep -q "$TASK_ID"; then
    echo -e "${GREEN}✓ Task retrieved successfully${NC}\n"
else
    echo -e "${RED}✗ Failed to retrieve task${NC}\n"
    exit 1
fi
sleep 2

# Test 3: List all tasks
echo -e "${YELLOW}Test 3: Listing all tasks...${NC}"
LIST_RESPONSE=$(curl -s -X GET "$API_URL/tasks?limit=10")
echo "Response: $LIST_RESPONSE"

if echo $LIST_RESPONSE | grep -q "tasks"; then
    TASK_COUNT=$(echo $LIST_RESPONSE | grep -o '"taskId"' | wc -l)
    echo -e "${GREEN}✓ Listed $TASK_COUNT task(s) successfully${NC}\n"
else
    echo -e "${RED}✗ Failed to list tasks${NC}\n"
    exit 1
fi
sleep 2

# Test 4: Update the task
echo -e "${YELLOW}Test 4: Updating task status...${NC}"
UPDATE_RESPONSE=$(curl -s -X PUT "$API_URL/tasks/$TASK_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "in_progress",
    "priority": "high"
  }')
echo "Response: $UPDATE_RESPONSE"

if echo $UPDATE_RESPONSE | grep -q "in_progress"; then
    echo -e "${GREEN}✓ Task updated successfully${NC}\n"
else
    echo -e "${RED}✗ Failed to update task${NC}\n"
    exit 1
fi
sleep 2

# Test 5: Update task to completed (triggers event)
echo -e "${YELLOW}Test 5: Marking task as completed...${NC}"
COMPLETE_RESPONSE=$(curl -s -X PUT "$API_URL/tasks/$TASK_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "completed"
  }')
echo "Response: $COMPLETE_RESPONSE"

if echo $COMPLETE_RESPONSE | grep -q "completed"; then
    echo -e "${GREEN}✓ Task marked as completed (TaskCompleted event triggered)${NC}\n"
else
    echo -e "${RED}✗ Failed to complete task${NC}\n"
    exit 1
fi
sleep 2

# Test 6: Create a high-priority task (triggers Step Functions)
echo -e "${YELLOW}Test 6: Creating high-priority task (triggers Step Functions)...${NC}"
HIGH_PRIORITY_RESPONSE=$(curl -s -X POST "$API_URL/tasks" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "High Priority Test Task",
    "description": "This should trigger the approval workflow",
    "priority": "high",
    "userId": "test-user-456",
    "tags": ["urgent", "approval-required"]
  }')
echo "Response: $HIGH_PRIORITY_RESPONSE"

HIGH_PRIORITY_TASK_ID=$(echo $HIGH_PRIORITY_RESPONSE | grep -o '"taskId":"[^"]*' | sed 's/"taskId":"//')

if [ -n "$HIGH_PRIORITY_TASK_ID" ]; then
    echo -e "${GREEN}✓ High-priority task created (Step Functions workflow started)${NC}\n"
else
    echo -e "${RED}✗ Failed to create high-priority task${NC}\n"
    exit 1
fi
sleep 2

# Test 7: Delete the first task
echo -e "${YELLOW}Test 7: Deleting task...${NC}"
DELETE_RESPONSE=$(curl -s -X DELETE "$API_URL/tasks/$TASK_ID")
echo "Response: $DELETE_RESPONSE"

if echo $DELETE_RESPONSE | grep -q "deleted successfully"; then
    echo -e "${GREEN}✓ Task deleted successfully${NC}\n"
else
    echo -e "${RED}✗ Failed to delete task${NC}\n"
    exit 1
fi
sleep 2

# Test 8: Verify task is deleted
echo -e "${YELLOW}Test 8: Verifying task deletion...${NC}"
VERIFY_DELETE=$(curl -s -X GET "$API_URL/tasks/$TASK_ID")
echo "Response: $VERIFY_DELETE"

if echo $VERIFY_DELETE | grep -q "not found"; then
    echo -e "${GREEN}✓ Task deletion verified${NC}\n"
else
    echo -e "${RED}✗ Task still exists after deletion${NC}\n"
    exit 1
fi

# Test 9: Test error handling (invalid JSON)
echo -e "${YELLOW}Test 9: Testing error handling...${NC}"
ERROR_RESPONSE=$(curl -s -X POST "$API_URL/tasks" \
  -H "Content-Type: application/json" \
  -d 'invalid-json')
echo "Response: $ERROR_RESPONSE"

if echo $ERROR_RESPONSE | grep -q "error"; then
    echo -e "${GREEN}✓ Error handling works correctly${NC}\n"
else
    echo -e "${RED}✗ Error handling failed${NC}\n"
    exit 1
fi

# Test 10: Test filtering by status
echo -e "${YELLOW}Test 10: Testing task filtering by status...${NC}"
FILTER_RESPONSE=$(curl -s -X GET "$API_URL/tasks?status=pending&limit=5")
echo "Response: $FILTER_RESPONSE"

if echo $FILTER_RESPONSE | grep -q "tasks"; then
    echo -e "${GREEN}✓ Task filtering works correctly${NC}\n"
else
    echo -e "${RED}✗ Task filtering failed${NC}\n"
    exit 1
fi

# Summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}All tests passed successfully! ✓${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Summary:"
echo "- ✓ Task creation"
echo "- ✓ Task retrieval"
echo "- ✓ Task listing"
echo "- ✓ Task updates"
echo "- ✓ Task completion (event-driven)"
echo "- ✓ High-priority task (Step Functions trigger)"
echo "- ✓ Task deletion"
echo "- ✓ Error handling"
echo "- ✓ Task filtering"
echo ""
echo -e "${YELLOW}Note: Check CloudWatch Logs and Step Functions console to verify event-driven workflows${NC}"
echo ""
echo "CloudWatch Log Groups to check:"
echo "  - /aws/lambda/task-manager-create-task-dev"
echo "  - /aws/lambda/task-manager-task-created-handler-dev"
echo "  - /aws/lambda/task-manager-task-completed-handler-dev"
echo ""
echo "Step Functions State Machine:"
echo "  - task-manager-task-approval-dev"
