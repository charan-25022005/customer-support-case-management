@RestResource(urlMapping='/v1/cases/*')
global with sharing class CaseRestService {

    @HttpPost
    global static void handlePostCase() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        Long startTime = System.currentTimeMillis();
        String requestBody = req != null && req.requestBody != null ? req.requestBody.toString() : '';
        CaseResponse responseDto = new CaseResponse();

        if (res == null) {
            res = new RestResponse();
            RestContext.response = res;
        }

        try {
            if (String.isBlank(requestBody)) {
                res.statusCode = 400;
                responseDto = new CaseResponse(false, 'Request body cannot be empty', null, 'INVALID_REQUEST');
                res.responseBody = Blob.valueOf(JSON.serialize(responseDto));
                IntegrationLogService.log('CaseRestService', '/v1/cases/', requestBody, res.responseBody.toString(), 400, 'Error', 'Empty request body', null, null, System.currentTimeMillis() - startTime);
                return;
            }

            CaseRequest caseReq;
            try {
                caseReq = CaseRequest.parse(requestBody);
            } catch (Exception parseEx) {
                res.statusCode = 400;
                responseDto = new CaseResponse(false, 'Invalid JSON format: ' + parseEx.getMessage(), null, 'JSON_PARSE_ERROR');
                res.responseBody = Blob.valueOf(JSON.serialize(responseDto));
                IntegrationLogService.log('CaseRestService', '/v1/cases/', requestBody, res.responseBody.toString(), 400, 'Error', parseEx.getMessage(), parseEx.getStackTraceString(), null, System.currentTimeMillis() - startTime);
                return;
            }

            if (String.isBlank(caseReq.externalCaseId) || String.isBlank(caseReq.subject) || String.isBlank(caseReq.priority) || String.isBlank(caseReq.customerId)) {
                res.statusCode = 400;
                responseDto = new CaseResponse(false, 'Missing required fields: externalCaseId, subject, priority, customerId are mandatory', caseReq.externalCaseId, 'MISSING_REQUIRED_FIELDS');
                res.responseBody = Blob.valueOf(JSON.serialize(responseDto));
                IntegrationLogService.log('CaseRestService', '/v1/cases/', requestBody, res.responseBody.toString(), 400, 'Error', responseDto.message, null, caseReq.externalCaseId, System.currentTimeMillis() - startTime);
                return;
            }

            External_Case__c extCase = new External_Case__c();
            extCase.External_Case_Id__c = caseReq.externalCaseId;
            extCase.Subject__c = caseReq.subject;
            extCase.Description__c = caseReq.description;
            extCase.Priority__c = caseReq.priority;
            extCase.Status__c = 'Pending';
            extCase.Customer_Id__c = caseReq.customerId;
            extCase.Customer_Email__c = caseReq.customerEmail;
            extCase.Customer_Phone__c = caseReq.customerPhone;

            Schema.SObjectField extIdField = External_Case__c.Fields.External_Case_Id__c;
            Database.UpsertResult upsertRes = Database.upsert(extCase, extIdField, false);

            if (!upsertRes.isSuccess()) {
                String dmlError = upsertRes.getErrors()[0].getMessage();
                res.statusCode = 500;
                responseDto = new CaseResponse(false, 'Failed to stage external case record: ' + dmlError, caseReq.externalCaseId, 'STAGING_DML_ERROR');
                res.responseBody = Blob.valueOf(JSON.serialize(responseDto));
                IntegrationLogService.log('CaseRestService', '/v1/cases/', requestBody, res.responseBody.toString(), 500, 'Error', dmlError, null, caseReq.externalCaseId, System.currentTimeMillis() - startTime);
                return;
            }

            System.enqueueJob(new CaseProcessingQueueable(new List<Id>{ extCase.Id }));

            res.statusCode = 200;
            responseDto = new CaseResponse(true, 'External case request accepted and queued for processing successfully', caseReq.externalCaseId);
            res.responseBody = Blob.valueOf(JSON.serialize(responseDto));

            IntegrationLogService.log('CaseRestService', '/v1/cases/', requestBody, res.responseBody.toString(), 200, 'Success', null, null, caseReq.externalCaseId, System.currentTimeMillis() - startTime);

        } catch (Exception ex) {
            res.statusCode = 500;
            responseDto = new CaseResponse(false, 'Internal server error: ' + ex.getMessage(), null, 'INTERNAL_ERROR');
            res.responseBody = Blob.valueOf(JSON.serialize(responseDto));
            IntegrationLogService.log('CaseRestService', '/v1/cases/', requestBody, res.responseBody.toString(), 500, 'Error', ex.getMessage(), ex.getStackTraceString(), null, System.currentTimeMillis() - startTime);
        }
    }
}
