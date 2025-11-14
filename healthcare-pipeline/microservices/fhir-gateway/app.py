"""
FHIR API Gateway Microservice
Provides HL7 FHIR R4 compliant API for healthcare data interoperability
"""

from fastapi import FastAPI, HTTPException, Depends, Request, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
import boto3
import json
import logging
from datetime import datetime
import uuid
import os
from functools import lru_cache

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="Healthcare FHIR API Gateway",
    description="HIPAA-compliant FHIR R4 API for healthcare data exchange",
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc"
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("ALLOWED_ORIGINS", "*").split(","),
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["*"],
)

# AWS clients
dynamodb = boto3.resource('dynamodb')
s3 = boto3.client('s3')
comprehend_medical = boto3.client('comprehendmedical')
cloudwatch = boto3.client('cloudwatch')

# Environment variables
PATIENT_TABLE = os.getenv('PATIENT_TABLE', 'healthcare-patients')
CONSENT_API_URL = os.getenv('CONSENT_API_URL', '')
DATA_BUCKET = os.getenv('DATA_BUCKET', '')


# ============================================================================
# FHIR Resource Models (R4 Specification)
# ============================================================================

class HumanName(BaseModel):
    """FHIR HumanName datatype"""
    use: Optional[str] = Field(default="official", description="usual | official | temp | nickname | anonymous | old | maiden")
    text: Optional[str] = Field(default=None, description="Text representation of the full name")
    family: Optional[str] = Field(default=None, description="Family name (surname)")
    given: Optional[List[str]] = Field(default=[], description="Given names")
    prefix: Optional[List[str]] = Field(default=[], description="Parts that come before the name")
    suffix: Optional[List[str]] = Field(default=[], description="Parts that come after the name")


class Address(BaseModel):
    """FHIR Address datatype"""
    use: Optional[str] = Field(default="home", description="home | work | temp | old | billing")
    type: Optional[str] = Field(default="both", description="postal | physical | both")
    text: Optional[str] = Field(default=None, description="Text representation")
    line: Optional[List[str]] = Field(default=[], description="Street name, number, direction & P.O. Box etc.")
    city: Optional[str] = Field(default=None)
    state: Optional[str] = Field(default=None)
    postalCode: Optional[str] = Field(default=None)
    country: Optional[str] = Field(default=None)


class ContactPoint(BaseModel):
    """FHIR ContactPoint datatype"""
    system: Optional[str] = Field(default="phone", description="phone | fax | email | pager | url | sms | other")
    value: Optional[str] = Field(default=None)
    use: Optional[str] = Field(default="home", description="home | work | temp | old | mobile")


class Identifier(BaseModel):
    """FHIR Identifier datatype"""
    use: Optional[str] = Field(default="official", description="usual | official | temp | secondary | old")
    system: Optional[str] = Field(default=None, description="The namespace for the identifier value")
    value: Optional[str] = Field(default=None, description="The value that is unique")


class Patient(BaseModel):
    """FHIR Patient Resource (R4)"""
    resourceType: str = Field(default="Patient", const=True)
    id: Optional[str] = Field(default=None)
    identifier: Optional[List[Identifier]] = Field(default=[])
    active: Optional[bool] = Field(default=True)
    name: Optional[List[HumanName]] = Field(default=[])
    telecom: Optional[List[ContactPoint]] = Field(default=[])
    gender: Optional[str] = Field(default=None, description="male | female | other | unknown")
    birthDate: Optional[str] = Field(default=None, description="The date of birth for the individual (YYYY-MM-DD)")
    address: Optional[List[Address]] = Field(default=[])
    maritalStatus: Optional[Dict[str, Any]] = Field(default=None)
    generalPractitioner: Optional[List[Dict[str, Any]]] = Field(default=[])


class Observation(BaseModel):
    """FHIR Observation Resource (R4)"""
    resourceType: str = Field(default="Observation", const=True)
    id: Optional[str] = Field(default=None)
    status: str = Field(description="registered | preliminary | final | amended")
    category: Optional[List[Dict[str, Any]]] = Field(default=[])
    code: Dict[str, Any] = Field(description="Type of observation (code / type)")
    subject: Optional[Dict[str, str]] = Field(default=None, description="Who/what this is about")
    effectiveDateTime: Optional[str] = Field(default=None)
    valueQuantity: Optional[Dict[str, Any]] = Field(default=None)
    valueString: Optional[str] = Field(default=None)
    interpretation: Optional[List[Dict[str, Any]]] = Field(default=[])


class Condition(BaseModel):
    """FHIR Condition Resource (R4)"""
    resourceType: str = Field(default="Condition", const=True)
    id: Optional[str] = Field(default=None)
    clinicalStatus: Dict[str, Any] = Field(description="active | recurrence | relapse | inactive | remission | resolved")
    verificationStatus: Optional[Dict[str, Any]] = Field(default=None)
    category: Optional[List[Dict[str, Any]]] = Field(default=[])
    severity: Optional[Dict[str, Any]] = Field(default=None)
    code: Dict[str, Any] = Field(description="Identification of the condition, problem or diagnosis")
    subject: Dict[str, str] = Field(description="Who has the condition?")
    onsetDateTime: Optional[str] = Field(default=None)
    recordedDate: Optional[str] = Field(default=None)


class MedicationRequest(BaseModel):
    """FHIR MedicationRequest Resource (R4)"""
    resourceType: str = Field(default="MedicationRequest", const=True)
    id: Optional[str] = Field(default=None)
    status: str = Field(description="active | on-hold | cancelled | completed | entered-in-error | stopped | draft | unknown")
    intent: str = Field(description="proposal | plan | order | original-order | reflex-order | filler-order | instance-order | option")
    medicationCodeableConcept: Optional[Dict[str, Any]] = Field(default=None)
    subject: Dict[str, str] = Field(description="Who medication is for")
    authoredOn: Optional[str] = Field(default=None)
    dosageInstruction: Optional[List[Dict[str, Any]]] = Field(default=[])


# ============================================================================
# Dependency Functions
# ============================================================================

async def verify_api_key(x_api_key: str = Header(None)):
    """Verify API key for authentication"""
    if not x_api_key:
        raise HTTPException(status_code=401, detail="API key required")

    # In production, validate against Secrets Manager or database
    # For now, simple validation
    valid_key = os.getenv('API_KEY', 'dev-key-123')
    if x_api_key != valid_key:
        raise HTTPException(status_code=403, detail="Invalid API key")

    return x_api_key


async def check_consent(patient_id: str, requester_id: str) -> bool:
    """Check patient consent for data access"""
    # In production, call consent API
    # For now, return True for development
    logger.info(f"Checking consent for patient {patient_id} by requester {requester_id}")
    return True


# ============================================================================
# Health Check Endpoints
# ============================================================================

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "service": "fhir-gateway"
    }


@app.get("/")
async def root():
    """Root endpoint with API information"""
    return {
        "message": "Healthcare FHIR API Gateway",
        "version": "1.0.0",
        "fhir_version": "R4",
        "documentation": "/api/docs"
    }


# ============================================================================
# Patient Resource Endpoints
# ============================================================================

@app.post("/fhir/Patient", status_code=201, dependencies=[Depends(verify_api_key)])
async def create_patient(patient: Patient):
    """Create a new Patient resource"""
    try:
        # Generate patient ID if not provided
        if not patient.id:
            patient.id = str(uuid.uuid4())

        # Detect PII before storing
        patient_json = json.dumps(patient.dict())
        phi_entities = await detect_phi(patient_json)

        # Store in DynamoDB
        table = dynamodb.Table(PATIENT_TABLE)
        table.put_item(
            Item={
                'id': patient.id,
                'resourceType': 'Patient',
                'data': patient.dict(),
                'created_at': datetime.utcnow().isoformat(),
                'phi_detected': len(phi_entities) > 0
            }
        )

        # Log to CloudWatch
        send_metric('PatientCreated', 1)

        logger.info(f"Created patient: {patient.id}")

        return {
            "resourceType": "Patient",
            "id": patient.id,
            **patient.dict(exclude={'id'})
        }

    except Exception as e:
        logger.error(f"Error creating patient: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/fhir/Patient/{patient_id}", dependencies=[Depends(verify_api_key)])
async def get_patient(patient_id: str):
    """Retrieve a Patient resource by ID"""
    try:
        table = dynamodb.Table(PATIENT_TABLE)
        response = table.get_item(Key={'id': patient_id})

        if 'Item' not in response:
            raise HTTPException(status_code=404, detail="Patient not found")

        patient_data = response['Item']['data']

        # Log access
        send_metric('PatientAccessed', 1)

        return patient_data

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error retrieving patient: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@app.put("/fhir/Patient/{patient_id}", dependencies=[Depends(verify_api_key)])
async def update_patient(patient_id: str, patient: Patient):
    """Update a Patient resource"""
    try:
        patient.id = patient_id

        # Verify patient exists
        table = dynamodb.Table(PATIENT_TABLE)
        response = table.get_item(Key={'id': patient_id})

        if 'Item' not in response:
            raise HTTPException(status_code=404, detail="Patient not found")

        # Update patient
        table.put_item(
            Item={
                'id': patient_id,
                'resourceType': 'Patient',
                'data': patient.dict(),
                'updated_at': datetime.utcnow().isoformat()
            }
        )

        send_metric('PatientUpdated', 1)

        logger.info(f"Updated patient: {patient_id}")

        return patient.dict()

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating patient: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/fhir/Patient/{patient_id}", dependencies=[Depends(verify_api_key)])
async def delete_patient(patient_id: str):
    """Delete a Patient resource"""
    try:
        table = dynamodb.Table(PATIENT_TABLE)

        # Verify patient exists
        response = table.get_item(Key={'id': patient_id})

        if 'Item' not in response:
            raise HTTPException(status_code=404, detail="Patient not found")

        # Soft delete (mark as inactive)
        table.update_item(
            Key={'id': patient_id},
            UpdateExpression='SET active = :val, deleted_at = :timestamp',
            ExpressionAttributeValues={
                ':val': False,
                ':timestamp': datetime.utcnow().isoformat()
            }
        )

        send_metric('PatientDeleted', 1)

        logger.info(f"Deleted patient: {patient_id}")

        return {"message": "Patient deleted successfully"}

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting patient: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================================
# Clinical Data Extraction using Comprehend Medical
# ============================================================================

@app.post("/fhir/extract-clinical-data", dependencies=[Depends(verify_api_key)])
async def extract_clinical_data(text: str):
    """
    Extract clinical entities from unstructured text using Amazon Comprehend Medical
    """
    try:
        # Detect medical entities
        entities_response = comprehend_medical.detect_entities_v2(Text=text)

        # Detect PHI
        phi_response = comprehend_medical.detect_phi(Text=text)

        # Transform to FHIR-compatible format
        conditions = []
        medications = []
        observations = []

        for entity in entities_response['Entities']:
            if entity['Category'] == 'MEDICAL_CONDITION':
                conditions.append({
                    'text': entity['Text'],
                    'type': entity['Type'],
                    'score': entity['Score']
                })
            elif entity['Category'] == 'MEDICATION':
                medications.append({
                    'text': entity['Text'],
                    'type': entity['Type'],
                    'score': entity['Score']
                })
            elif entity['Category'] in ['TEST_TREATMENT_PROCEDURE', 'ANATOMY']:
                observations.append({
                    'text': entity['Text'],
                    'type': entity['Type'],
                    'category': entity['Category'],
                    'score': entity['Score']
                })

        phi_entities = [
            {
                'text': entity['Text'],
                'type': entity['Type'],
                'score': entity['Score']
            }
            for entity in phi_response['Entities']
        ]

        send_metric('ClinicalDataExtracted', 1)

        return {
            'conditions': conditions,
            'medications': medications,
            'observations': observations,
            'phi_detected': phi_entities,
            'total_entities': len(entities_response['Entities'])
        }

    except Exception as e:
        logger.error(f"Error extracting clinical data: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================================
# Utility Functions
# ============================================================================

async def detect_phi(text: str) -> List[Dict[str, Any]]:
    """Detect PHI in text using Comprehend Medical"""
    try:
        response = comprehend_medical.detect_phi(Text=text)
        return response['Entities']
    except Exception as e:
        logger.error(f"Error detecting PHI: {str(e)}")
        return []


def send_metric(metric_name: str, value: float):
    """Send custom metric to CloudWatch"""
    try:
        cloudwatch.put_metric_data(
            Namespace='HealthcarePipeline/FHIR',
            MetricData=[{
                'MetricName': metric_name,
                'Value': value,
                'Unit': 'Count',
                'Timestamp': datetime.utcnow()
            }]
        )
    except Exception as e:
        logger.error(f"Error sending metric: {str(e)}")


# ============================================================================
# Error Handlers
# ============================================================================

@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    """Handle HTTP exceptions"""
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": {
                "code": exc.status_code,
                "message": exc.detail,
                "timestamp": datetime.utcnow().isoformat()
            }
        }
    )


@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    """Handle general exceptions"""
    logger.error(f"Unhandled exception: {str(exc)}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={
            "error": {
                "code": 500,
                "message": "Internal server error",
                "timestamp": datetime.utcnow().isoformat()
            }
        }
    )


# ============================================================================
# Startup Event
# ============================================================================

@app.on_event("startup")
async def startup_event():
    """Startup tasks"""
    logger.info("FHIR API Gateway starting up...")
    logger.info(f"Environment: {os.getenv('ENVIRONMENT', 'development')}")
    logger.info(f"Patient Table: {PATIENT_TABLE}")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
