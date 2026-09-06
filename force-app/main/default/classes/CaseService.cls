public with sharing class CaseService {

    public class CaseServiceException extends Exception {}

    public static Case processExternalCase(External_Case__c extCase, CustomerResponse customerDto) {
        if (extCase == null) {
            throw new CaseServiceException('External case record cannot be null');
        }

        String customerEmail = customerDto != null && String.isNotBlank(customerDto.email) ? customerDto.email : extCase.Customer_Email__c;
        String customerPhone = customerDto != null && String.isNotBlank(customerDto.phone) ? customerDto.phone : extCase.Customer_Phone__c;
        String customerName = customerDto != null && String.isNotBlank(customerDto.name) ? customerDto.name : 'Customer ' + extCase.Customer_Id__c;
        String companyName = customerDto != null && String.isNotBlank(customerDto.company) ? customerDto.company : 'Account ' + extCase.Customer_Id__c;
        Boolean isVip = customerDto != null && customerDto.isVip != null ? customerDto.isVip : false;

        Id contactId = null;
        Id accountId = null;

        if (String.isNotBlank(customerEmail)) {
            List<Contact> existingContacts = [
                SELECT Id, AccountId
                FROM Contact
                WHERE Email = :customerEmail
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            if (!existingContacts.isEmpty()) {
                contactId = existingContacts[0].Id;
                accountId = existingContacts[0].AccountId;
            }
        }

        if (contactId == null) {
            Account acc = new Account(Name = companyName);
            if (Schema.sObjectType.Account.isCreateable()) {
                insert acc;
                accountId = acc.Id;
            }

            Contact con = new Contact(
                LastName = customerName,
                Email = customerEmail,
                Phone = customerPhone,
                AccountId = accountId
            );
            if (Schema.sObjectType.Contact.isCreateable()) {
                insert con;
                contactId = con.Id;
            }
        }

        List<Case> existingCases = [
            SELECT Id, CaseNumber, Subject, Description, Priority, Status, ContactId, AccountId, External_Case_Id__c, Is_VIP__c, OwnerId
            FROM Case
            WHERE External_Case_Id__c = :extCase.External_Case_Id__c
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        Case caseRecord;
        if (!existingCases.isEmpty()) {
            caseRecord = existingCases[0];
            caseRecord.Subject = extCase.Subject__c;
            caseRecord.Description = extCase.Description__c;
            caseRecord.Priority = extCase.Priority__c;
            caseRecord.ContactId = contactId;
            caseRecord.AccountId = accountId;
            caseRecord.Is_VIP__c = isVip;
            caseRecord.Customer_External_Id__c = extCase.Customer_Id__c;
        } else {
            caseRecord = new Case();
            caseRecord.External_Case_Id__c = extCase.External_Case_Id__c;
            caseRecord.Subject = extCase.Subject__c;
            caseRecord.Description = extCase.Description__c;
            caseRecord.Priority = extCase.Priority__c;
            caseRecord.Status = 'New';
            caseRecord.Origin = 'Web';
            caseRecord.ContactId = contactId;
            caseRecord.AccountId = accountId;
            caseRecord.Is_VIP__c = isVip;
            caseRecord.Customer_External_Id__c = extCase.Customer_Id__c;
        }

        CaseAssignmentService.assignCaseOwner(caseRecord, caseRecord.Priority, caseRecord.Is_VIP__c);

        if (caseRecord.Id != null) {
            if (Schema.sObjectType.Case.isUpdateable()) {
                update caseRecord;
            }
        } else {
            if (Schema.sObjectType.Case.isCreateable()) {
                insert caseRecord;
            }
        }

        return caseRecord;
    }

    @AuraEnabled(cacheable=true)
    public static List<Case> getCases(String searchTerm, String priorityFilter, String statusFilter) {
        String query = 'SELECT Id, CaseNumber, Subject, Priority, Status, CreatedDate, Contact.Name, Account.Name, Is_VIP__c, External_Case_Id__c, Owner.Name FROM Case WHERE Id != NULL';
        
        if (String.isNotBlank(searchTerm)) {
            String key = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';
            query += ' AND (Subject LIKE :key OR CaseNumber LIKE :key OR External_Case_Id__c LIKE :key OR Contact.Name LIKE :key OR Account.Name LIKE :key)';
        }
        if (String.isNotBlank(priorityFilter) && !priorityFilter.equalsIgnoreCase('ALL')) {
            String pVal = String.escapeSingleQuotes(priorityFilter);
            query += ' AND Priority = :pVal';
        }
        if (String.isNotBlank(statusFilter) && !statusFilter.equalsIgnoreCase('ALL')) {
            String sVal = String.escapeSingleQuotes(statusFilter);
            query += ' AND Status = :sVal';
        }

        query += ' WITH SECURITY_ENFORCED ORDER BY CreatedDate DESC LIMIT 100';
        return Database.query(query);
    }

    @AuraEnabled(cacheable=true)
    public static Case getCaseDetails(String caseId) {
        if (String.isBlank(caseId)) {
            return null;
        }
        return [
            SELECT Id, CaseNumber, Subject, Description, Priority, Status, Origin, Is_VIP__c, External_Case_Id__c, Customer_External_Id__c, Resolution_Summary__c, Resolution_Notes__c, Resolved_By__c, Resolved_By__r.Name, Resolved_Date__c, CreatedDate, ClosedDate, LastModifiedDate, ContactId, Contact.Name, Contact.Email, Contact.Phone, AccountId, Account.Name, OwnerId, Owner.Name
            FROM Case
            WHERE Id = :caseId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
    }

    @AuraEnabled
    public static Case updateCaseStatus(String caseId, String newStatus, String resolutionNotes, String resolutionSummary) {
        if (String.isBlank(caseId) || String.isBlank(newStatus)) {
            throw new AuraHandledException('Invalid arguments for updateCaseStatus');
        }
        if (newStatus != null && newStatus.equalsIgnoreCase('Closed')) {
            if (String.isBlank(resolutionSummary) || String.isBlank(resolutionSummary.trim())) {
                throw new AuraHandledException('Please enter a resolution summary before closing the Case.');
            }
            if (String.isBlank(resolutionNotes) || String.isBlank(resolutionNotes.trim())) {
                throw new AuraHandledException('Please enter resolution notes before closing the Case.');
            }
        }
        Case c = new Case(Id = caseId, Status = newStatus);
        if (newStatus != null && newStatus.equalsIgnoreCase('Closed')) {
            c.Resolution_Summary__c = resolutionSummary.trim();
            c.Resolution_Notes__c = resolutionNotes.trim();
            c.Resolved_By__c = UserInfo.getUserId();
            c.Resolved_Date__c = System.now();
        } else if (String.isNotBlank(resolutionNotes)) {
            c.Resolution_Notes__c = resolutionNotes;
        }
        if (Schema.sObjectType.Case.isUpdateable()) {
            update c;
        }
        return getCaseDetails(caseId);
    }

    public static Case updateCaseStatus(String caseId, String newStatus, String resolutionNotes) {
        return updateCaseStatus(caseId, newStatus, resolutionNotes, null);
    }

    public static Case updateCaseStatus(String caseId, String newStatus) {
        return updateCaseStatus(caseId, newStatus, null, null);
    }

    @AuraEnabled
    public static Case reassignCase(String caseId, String newOwnerId) {
        if (String.isBlank(caseId) || String.isBlank(newOwnerId)) {
            throw new AuraHandledException('Invalid arguments for reassignCase');
        }
        Case c = new Case(Id = caseId, OwnerId = newOwnerId);
        if (Schema.sObjectType.Case.isUpdateable()) {
            update c;
        }
        return getCaseDetails(caseId);
    }

    @AuraEnabled(cacheable=true)
    public static List<Integration_Log__c> getIntegrationLogs(String externalCaseId) {
        if (String.isBlank(externalCaseId)) {
            return new List<Integration_Log__c>();
        }
        return [
            SELECT Id, Name, Service_Name__c, Endpoint__c, Status__c, Status_Code__c, Error_Message__c, Execution_Time_ms__c, CreatedDate
            FROM Integration_Log__c
            WHERE External_Case_Id__c = :externalCaseId
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT 20
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Task> getCaseActivities(String caseId) {
        if (String.isBlank(caseId)) {
            return new List<Task>();
        }
        return [
            SELECT Id, Subject, Status, Priority, ActivityDate, CreatedDate, Owner.Name, Description
            FROM Task
            WHERE WhatId = :caseId
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT 20
        ];
    }
}
