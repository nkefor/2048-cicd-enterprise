"""
Amazon Comprehend Medical Lambda Function
AI-driven medical data extraction for healthcare workflows
HIPAA-compliant implementation
"""

import json
import boto3
import os
from datetime import datetime
from typing import Dict, List, Any

# Initialize AWS clients
comprehend_medical = boto3.client('comprehendmedical')
dynamodb = boto3.resource('dynamodb')
kms = boto3.client('kms')

# Environment variables
PATIENT_DATA_TABLE = os.environ['PATIENT_DATA_TABLE']
ENTITIES_TABLE = os.environ['ENTITIES_TABLE']
KMS_KEY_ID = os.environ['KMS_KEY_ID']

def lambda_handler(event, context):
    """
    Process clinical text using Amazon Comprehend Medical
    Extract medical entities including:
    - Medications
    - Medical conditions
    - Anatomy
    - Protected Health Information (PHI)
    - Lab test names
    - Procedures
    """
    try:
        print(f"Processing medical text extraction for patient: {event.get('patientData', {}).get('patientId')}")

        # Extract clinical text from event
        clinical_text = event.get('textToAnalyze', '')
        patient_id = event.get('patientData', {}).get('patientId')

        if not clinical_text or not patient_id:
            return create_error_response("Missing required fields: textToAnalyze or patientId")

        # Detect medical entities
        entities_response = detect_entities(clinical_text)

        # Detect PHI (Protected Health Information)
        phi_response = detect_phi(clinical_text)

        # Infer ICD-10-CM codes (diagnoses)
        icd10_response = infer_icd10_codes(clinical_text)

        # Infer RxNorm codes (medications)
        rxnorm_response = infer_rxnorm_codes(clinical_text)

        # Process and structure the results
        structured_data = process_medical_entities(
            entities_response,
            phi_response,
            icd10_response,
            rxnorm_response
        )

        # Determine if lab orders are needed
        lab_orders_required = determine_lab_orders(structured_data)

        # Store extracted entities (encrypted)
        store_medical_entities(patient_id, structured_data)

        # Return structured response
        return {
            'statusCode': 200,
            'patientId': patient_id,
            'extractedEntities': structured_data,
            'labOrdersRequired': lab_orders_required,
            'recommendedTests': get_recommended_tests(structured_data),
            'timestamp': datetime.utcnow().isoformat(),
            'phiDetected': len(phi_response.get('Entities', [])) > 0,
            'processingMetadata': {
                'entitiesCount': len(entities_response.get('Entities', [])),
                'icd10CodesCount': len(icd10_response.get('Entities', [])),
                'medicationsCount': len(rxnorm_response.get('Entities', []))
            }
        }

    except Exception as e:
        print(f"Error processing medical text: {str(e)}")
        return create_error_response(str(e))


def detect_entities(text: str) -> Dict:
    """Detect medical entities in clinical text"""
    try:
        response = comprehend_medical.detect_entities_v2(Text=text)
        return response
    except Exception as e:
        print(f"Error detecting entities: {str(e)}")
        return {'Entities': []}


def detect_phi(text: str) -> Dict:
    """Detect Protected Health Information (PHI)"""
    try:
        response = comprehend_medical.detect_phi(Text=text)
        return response
    except Exception as e:
        print(f"Error detecting PHI: {str(e)}")
        return {'Entities': []}


def infer_icd10_codes(text: str) -> Dict:
    """Infer ICD-10-CM codes for medical conditions"""
    try:
        response = comprehend_medical.infer_icd10_cm(Text=text)
        return response
    except Exception as e:
        print(f"Error inferring ICD-10 codes: {str(e)}")
        return {'Entities': []}


def infer_rxnorm_codes(text: str) -> Dict:
    """Infer RxNorm codes for medications"""
    try:
        response = comprehend_medical.infer_rx_norm(Text=text)
        return response
    except Exception as e:
        print(f"Error inferring RxNorm codes: {str(e)}")
        return {'Entities': []}


def process_medical_entities(entities: Dict, phi: Dict, icd10: Dict, rxnorm: Dict) -> Dict:
    """Process and structure all medical entities"""
    structured_data = {
        'medications': [],
        'conditions': [],
        'procedures': [],
        'anatomy': [],
        'testsTreatmentsProcedures': [],
        'phi': [],
        'icd10Codes': [],
        'rxNormCodes': []
    }

    # Process general entities
    for entity in entities.get('Entities', []):
        entity_data = {
            'text': entity.get('Text'),
            'category': entity.get('Category'),
            'type': entity.get('Type'),
            'score': entity.get('Score'),
            'traits': entity.get('Traits', []),
            'attributes': entity.get('Attributes', [])
        }

        category = entity.get('Category')
        if category == 'MEDICATION':
            structured_data['medications'].append(entity_data)
        elif category == 'MEDICAL_CONDITION':
            structured_data['conditions'].append(entity_data)
        elif category == 'PROCEDURE':
            structured_data['procedures'].append(entity_data)
        elif category == 'ANATOMY':
            structured_data['anatomy'].append(entity_data)
        elif category == 'TEST_TREATMENT_PROCEDURE':
            structured_data['testsTreatmentsProcedures'].append(entity_data)

    # Process PHI entities
    for phi_entity in phi.get('Entities', []):
        structured_data['phi'].append({
            'text': phi_entity.get('Text'),
            'category': phi_entity.get('Category'),
            'type': phi_entity.get('Type'),
            'score': phi_entity.get('Score')
        })

    # Process ICD-10 codes
    for icd_entity in icd10.get('Entities', []):
        icd_codes = []
        for concept in icd_entity.get('ICD10CMConcepts', []):
            icd_codes.append({
                'code': concept.get('Code'),
                'description': concept.get('Description'),
                'score': concept.get('Score')
            })

        structured_data['icd10Codes'].append({
            'text': icd_entity.get('Text'),
            'codes': icd_codes
        })

    # Process RxNorm codes
    for rx_entity in rxnorm.get('Entities', []):
        rx_codes = []
        for concept in rx_entity.get('RxNormConcepts', []):
            rx_codes.append({
                'code': concept.get('Code'),
                'description': concept.get('Description'),
                'score': concept.get('Score')
            })

        structured_data['rxNormCodes'].append({
            'text': rx_entity.get('Text'),
            'codes': rx_codes
        })

    return structured_data


def determine_lab_orders(structured_data: Dict) -> bool:
    """Determine if lab orders are required based on extracted entities"""
    # Check for conditions that typically require lab work
    condition_keywords = ['diabetes', 'hypertension', 'cholesterol', 'anemia', 'infection']

    for condition in structured_data.get('conditions', []):
        condition_text = condition.get('text', '').lower()
        if any(keyword in condition_text for keyword in condition_keywords):
            return True

    # Check for specific test mentions
    tests = structured_data.get('testsTreatmentsProcedures', [])
    if len(tests) > 0:
        return True

    return False


def get_recommended_tests(structured_data: Dict) -> List[str]:
    """Get recommended lab tests based on extracted conditions"""
    recommended_tests = []

    # Map conditions to recommended tests
    test_mapping = {
        'diabetes': ['HbA1c', 'Fasting Glucose', 'Lipid Panel'],
        'hypertension': ['Basic Metabolic Panel', 'Lipid Panel', 'ECG'],
        'cholesterol': ['Lipid Panel', 'Total Cholesterol', 'HDL', 'LDL'],
        'anemia': ['Complete Blood Count', 'Iron Panel', 'Ferritin'],
        'infection': ['Complete Blood Count', 'CRP', 'Blood Culture']
    }

    for condition in structured_data.get('conditions', []):
        condition_text = condition.get('text', '').lower()
        for keyword, tests in test_mapping.items():
            if keyword in condition_text:
                recommended_tests.extend(tests)

    # Remove duplicates
    return list(set(recommended_tests))


def store_medical_entities(patient_id: str, structured_data: Dict):
    """Store extracted medical entities in DynamoDB (encrypted)"""
    try:
        table = dynamodb.Table(ENTITIES_TABLE)

        # Encrypt sensitive data
        encrypted_data = encrypt_data(json.dumps(structured_data))

        table.put_item(
            Item={
                'patientId': patient_id,
                'timestamp': datetime.utcnow().isoformat(),
                'encryptedData': encrypted_data,
                'ttl': int(datetime.utcnow().timestamp()) + (90 * 24 * 60 * 60)  # 90 days retention
            }
        )
        print(f"Stored medical entities for patient: {patient_id}")
    except Exception as e:
        print(f"Error storing medical entities: {str(e)}")


def encrypt_data(data: str) -> str:
    """Encrypt data using KMS"""
    try:
        response = kms.encrypt(
            KeyId=KMS_KEY_ID,
            Plaintext=data.encode('utf-8')
        )
        return response['CiphertextBlob'].hex()
    except Exception as e:
        print(f"Error encrypting data: {str(e)}")
        return data


def create_error_response(error_message: str) -> Dict:
    """Create standardized error response"""
    return {
        'statusCode': 400,
        'error': error_message,
        'timestamp': datetime.utcnow().isoformat()
    }
