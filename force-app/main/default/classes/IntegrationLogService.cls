public with sharing class IntegrationLogService {

    public static void log(String serviceName, String endpoint, String requestBody, String responseBody, Integer statusCode, String status, String errorMessage, String stackTrace, String externalCaseId, Long executionTimeMs) {
        try {
            Integration_Log__c logRecord = new Integration_Log__c();
            logRecord.Service_Name__c = serviceName;
            logRecord.Endpoint__c = endpoint;
            logRecord.Request_Body__c = requestBody != null && requestBody.length() > 131000 ? requestBody.substring(0, 131000) : requestBody;
            logRecord.Response_Body__c = responseBody != null && responseBody.length() > 131000 ? responseBody.substring(0, 131000) : responseBody;
            logRecord.Status_Code__c = statusCode;
            logRecord.Status__c = status;
            logRecord.Error_Message__c = errorMessage != null && errorMessage.length() > 32000 ? errorMessage.substring(0, 32000) : errorMessage;
            logRecord.Stack_Trace__c = stackTrace != null && stackTrace.length() > 32000 ? stackTrace.substring(0, 32000) : stackTrace;
            logRecord.External_Case_Id__c = externalCaseId;
            logRecord.Execution_Time_ms__c = executionTimeMs;

            if (Schema.sObjectType.Integration_Log__c.isCreateable()) {
                insert logRecord;
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Failed to insert Integration_Log__c: ' + ex.getMessage());
        }
    }
}
