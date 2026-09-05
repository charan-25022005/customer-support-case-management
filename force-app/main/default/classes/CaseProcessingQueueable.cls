public with sharing class CaseProcessingQueueable implements Queueable, Database.AllowsCallouts {

    private List<Id> externalCaseIds;

    public CaseProcessingQueueable(List<Id> externalCaseIds) {
        this.externalCaseIds = externalCaseIds;
    }

    public void execute(QueueableContext context) {
        if (externalCaseIds == null || externalCaseIds.isEmpty()) {
            return;
        }

        List<External_Case__c> extCases = [
            SELECT Id, External_Case_Id__c, Subject__c, Description__c, Priority__c, Status__c, Customer_Id__c, Customer_Email__c, Customer_Phone__c
            FROM External_Case__c
            WHERE Id IN :externalCaseIds
            WITH SECURITY_ENFORCED
        ];

        List<External_Case__c> casesToUpdate = new List<External_Case__c>();

        for (External_Case__c extCase : extCases) {
            try {
                CustomerResponse customerDto = null;
                if (String.isNotBlank(extCase.Customer_Id__c)) {
                    try {
                        customerDto = CustomerApiService.getCustomerDetails(extCase.Customer_Id__c, extCase.External_Case_Id__c);
                    } catch (Exception apiEx) {
                        System.debug(LoggingLevel.WARN, 'Customer API callout warning for ' + extCase.Customer_Id__c + ': ' + apiEx.getMessage());
                    }
                }

                Case createdCase = CaseService.processExternalCase(extCase, customerDto);

                extCase.Salesforce_Case__c = createdCase.Id;
                extCase.Status__c = 'Processed';
                extCase.Error_Message__c = null;
                casesToUpdate.add(extCase);

            } catch (Exception ex) {
                extCase.Status__c = 'Failed';
                extCase.Error_Message__c = ex.getMessage() + '\n' + ex.getStackTraceString();
                casesToUpdate.add(extCase);

                IntegrationLogService.log(
                    'CaseProcessingQueueable',
                    'Asynchronous Queueable Processing',
                    JSON.serialize(extCase),
                    null,
                    500,
                    'Error',
                    ex.getMessage(),
                    ex.getStackTraceString(),
                    extCase.External_Case_Id__c,
                    0
                );
            }
        }

        if (!casesToUpdate.isEmpty() && Schema.sObjectType.External_Case__c.isUpdateable()) {
            update casesToUpdate;
        }
    }
}
