# Sample Healthcare Data

## Overview

This directory contains **de-identified, synthetic healthcare data** for testing the pipeline. All data is generated for demonstration purposes only and contains **no real patient information**.

## Data Types

### Clinical Notes
- `clinical-note-sample-*.json`: Synthetic progress notes, discharge summaries
- Format: JSON with structured and unstructured components
- Use case: Testing PII detection, clinical NLP, FHIR transformation

### Lab Reports
- `lab-report-sample-*.json`: Synthetic laboratory results
- Format: FHIR R4 Observation resources
- Use case: Testing FHIR API, data validation

### Patient Records
- `patient-sample-*.json`: Synthetic patient demographics
- Format: FHIR R4 Patient resources
- Use case: Testing consent management, FHIR API CRUD operations

## Data Generation

All sample data was generated using:
- [Synthea](https://github.com/synthetichealth/synthea): Synthetic patient generator
- Custom scripts following FHIR R4 specification
- HIPAA-compliant de-identification guidelines

## Testing the Pipeline

### Upload Sample Data

```bash
# Upload to S3 raw data bucket
aws s3 cp clinical-note-sample-1.json \
    s3://healthcare-pipeline-raw-data-<suffix>/test/

# Monitor processing
aws logs tail /aws/lambda/healthcare-pii-detection --follow
```

### Expected Behavior

1. **PII Detection**: Lambda function detects entities (age, conditions, medications)
2. **Risk Assessment**: Low-risk classification (no high-confidence PHI)
3. **Processing**: Data masked and stored in processed bucket
4. **Audit Trail**: Event logged to DynamoDB and Splunk
5. **Metrics**: CloudWatch metrics updated

## Disclaimer

⚠️ **IMPORTANT**: This is synthetic data for demonstration only. Never use real patient data without proper authorization and compliance review.

## Data Privacy

- All patient names, addresses, and identifiers are fictitious
- Dates are randomized within plausible ranges
- Medical conditions are realistic but randomly assigned
- No correlation with real individuals or medical records
