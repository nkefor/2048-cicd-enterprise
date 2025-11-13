package test

import (
	"testing"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestVPCCreation(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infra",
		Vars: map[string]interface{}{
			"environment": "test",
			"project_name": "test-2048",
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Validate VPC outputs
	vpcId := terraform.Output(t, terraformOptions, "vpc_id")
	assert.NotEmpty(t, vpcId)

	// Validate CIDR block
	vpcCidr := terraform.Output(t, terraformOptions, "vpc_cidr")
	assert.Equal(t, "10.0.0.0/16", vpcCidr)
}

func TestMultiAZDeployment(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../infra",
		Vars: map[string]interface{}{
			"environment": "test",
			"availability_zones": []string{"us-east-1a", "us-east-1b"},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Validate subnets in multiple AZs
	publicSubnets := terraform.OutputList(t, terraformOptions, "public_subnet_ids")
	assert.GreaterOrEqual(t, len(publicSubnets), 2)
}
