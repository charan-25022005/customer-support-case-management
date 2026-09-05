# Customer Support Case Management System (Salesforce DX)

Automated, production-ready Salesforce application designed to process, match, assign, and manage external customer support cases via Apex REST API, Queueable Apex, External REST Callouts (using Named Credentials), Custom Metadata Case Assignment Rules, and an interactive Lightning Web Component (`caseManagement`).

---

## 1. Architecture Overview

### Main Success Flow
```
EXTERNAL SYSTEM
       ↓  POST Request (JSON)
Apex REST API (CaseRestService)
       ↓  Validate Request & ID
Staging Object (External_Case__c)
       ↓  Enqueue Job
Queueable Apex (CaseProcessingQueueable)
       ↓  Database.AllowsCallouts
Customer REST API Callout (CustomerApiService via Named Credential)
       ↓  Retrieve Customer Details
Customer Matching Engine (CaseService)
       ├── Find / Create Account & Contact
       └── Idempotency Check (External_Case_Id__c)
      /                                 \
    YES                                 NO
     ↓                                   ↓
Update Case                         Create Case
     \                                   /
      └────────────────┬────────────────┘
                       ↓
         Case Assignment Engine (CaseAssignmentService)
                       ↓  Evaluates Priority + VIP Status against
         Custom Metadata Rules (Case_Assignment_Rule__mdt)
                       ↓
             Assign Queue / Owner
                       ↓
               Salesforce Case
                       ↓
   Interactive LWC Dashboard (caseManagement)
```

### Error & Integration Logging Flow
```
EXTERNAL SYSTEM / CALLOUT / DML
               ↓
     Validation / Runtime Exception
               ↓
    IntegrationLogService (Exception-Safe)
               ↓
      Integration_Log__c Object
    (Payloads, Status Codes, Traces)
               ↓
Returned JSON Response (400/500 Bad Request / Internal Error)
```

---

## 2. Salesforce DX Project Structure

```
customer-support-case-management/
├── force-app/
│   └── main/
│       └── default/
│           ├── classes/
│           │   ├── CaseRequest.cls
│           │   ├── CaseRequest.cls-meta.xml
│           │   ├── CaseResponse.cls
│           │   ├── CaseResponse.cls-meta.xml
│           │   ├── CustomerResponse.cls
│           │   ├── CustomerResponse.cls-meta.xml
│           │   ├── CaseRestService.cls
│           │   ├── CaseRestService.cls-meta.xml
│           │   ├── CustomerApiService.cls
│           │   ├── CustomerApiService.cls-meta.xml
│           │   ├── CaseAssignmentService.cls
│           │   ├── CaseAssignmentService.cls-meta.xml
│           │   ├── CaseService.cls
│           │   ├── CaseService.cls-meta.xml
│           │   ├── CaseProcessingQueueable.cls
│           │   ├── CaseProcessingQueueable.cls-meta.xml
│           │   ├── IntegrationLogService.cls
│           │   ├── IntegrationLogService.cls-meta.xml
│           │   ├── MockHttpResponseGenerator.cls
│           │   ├── MockHttpResponseGenerator.cls-meta.xml
│           │   ├── CaseTriggerHandler.cls
│           │   ├── CaseTriggerHandler.cls-meta.xml
│           │   ├── CaseRestServiceTest.cls
│           │   ├── CaseRestServiceTest.cls-meta.xml
│           │   ├── CustomerApiServiceTest.cls
│           │   ├── CustomerApiServiceTest.cls-meta.xml
│           │   ├── CaseServiceTest.cls
│           │   ├── CaseServiceTest.cls-meta.xml
│           │   ├── CaseAssignmentServiceTest.cls
│           │   ├── CaseAssignmentServiceTest.cls-meta.xml
│           │   ├── CaseProcessingQueueableTest.cls
│           │   ├── CaseProcessingQueueableTest.cls-meta.xml
│           │   ├── CaseTriggerHandlerTest.cls
│           │   └── CaseTriggerHandlerTest.cls-meta.xml
│           ├── triggers/
│           │   ├── CaseTrigger.trigger
│           │   └── CaseTrigger.trigger-meta.xml
│           ├── lwc/
│           │   └── caseManagement/
│           │       ├── caseManagement.html
│           │       ├── caseManagement.js
│           │       ├── caseManagement.css
│           │       └── caseManagement.js-meta.xml
│           ├── objects/
│           │   ├── External_Case__c/
│           │   ├── Integration_Log__c/
│           │   ├── Case_Assignment_Rule__mdt/
│           │   └── Case/
│           ├── customMetadata/
│           ├── namedCredentials/
│           ├── permissionsets/
│           └── layouts/
├── manifest/
│   └── package.xml
├── sfdx-project.json
└── README.md
```

---

## 3. API Specification & Integration Endpoints

### Endpoint Details
- **URI**: `/services/apexrest/v1/cases/`
- **HTTP Method**: `POST`
- **Content-Type**: `application/json`

### Sample Request Payload (Success Case)
```json
{
  "externalCaseId": "EXT-9001",
  "subject": "System Latency Issues",
  "description": "User reporting high latency during checkout workflow.",
  "priority": "High",
  "customerId": "CUST-500",
  "customerEmail": "sarah.connor@cyberdyne.com",
  "customerPhone": "+1-555-0199"
}
```

### Sample Response (HTTP 200 OK)
```json
{
  "success": true,
  "message": "External case request accepted and queued for processing successfully",
  "externalCaseId": "EXT-9001",
  "caseId": null,
  "caseNumber": null,
  "errorCode": null
}
```

### Sample Response (HTTP 400 Bad Request - Missing Fields)
```json
{
  "success": false,
  "message": "Missing required fields: externalCaseId, subject, priority, customerId are mandatory",
  "externalCaseId": "EXT-9001",
  "caseId": null,
  "caseNumber": null,
  "errorCode": "MISSING_REQUIRED_FIELDS"
}
```

---

## 4. Setup & Deployment Instructions

### Prerequisites
- Salesforce CLI (`sf` / `sfdx`) installed.
- Authorised Dev Org or Scratch Org.

### Step 1: Deploy Source to Salesforce Org
```bash
sf project deploy start --manifest manifest/package.xml
```

### Step 2: Assign Permission Set
```bash
sf org assign permset --name Case_Management_Admin
```

### Step 3: Run All Unit Tests with Coverage
```bash
sf apex run test --test-level RunLocalTests --code-coverage --result-format human
```

---

## 5. Security & Best Practices Compliance
- **CRUD/FLS Enforcement**: All SOQL queries use `WITH SECURITY_ENFORCED`. DML operations verify `Schema.sObjectType` permissions.
- **Bulkification**: Triggers, Handlers, and Queueable processors process lists of records without SOQL/DML inside loops.
- **Named Credentials**: No hardcoded API keys or endpoints (`callout:Customer_API`).
- **Idempotency**: Case records upsert using `External_Case_Id__c` unique external key.
