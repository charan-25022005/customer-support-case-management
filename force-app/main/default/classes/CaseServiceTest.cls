@isTest
private class CaseServiceTest {

    @testSetup
    static void setupTestData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User tUser = new User(
            FirstName = 'Test',
            LastName = 'Runner',
            Email = 'testrunner@example.com',
            Username = 'testrunner' + DateTime.now().getTime() + '@example.com',
            Alias = 'trun',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert tUser;

        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Case_Management_Admin' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = tUser.Id, PermissionSetId = ps.Id);
    }

    private static User getTestUser() {
        return [SELECT Id FROM User WHERE Email = 'testrunner@example.com' LIMIT 1];
    }

    @isTest
    static void testProcessNewExternalCaseWithNewCustomer() {
        User tUser = getTestUser();
        External_Case__c extCase = new External_Case__c(
            External_Case_Id__c = 'EXT-2001',
            Subject__c = 'Billing Inquiry',
            Description__c = 'Invoice breakdown needed',
            Priority__c = 'High',
            Status__c = 'Pending',
            Customer_Id__c = 'CUST-2001',
            Customer_Email__c = 'newcust@example.com',
            Customer_Phone__c = '5551234567'
        );
        insert extCase;

        CustomerResponse custDto = new CustomerResponse();
        custDto.customerId = 'CUST-2001';
        custDto.name = 'Alice Smith';
        custDto.email = 'newcust@example.com';
        custDto.phone = '5551234567';
        custDto.company = 'Smith Holdings';
        custDto.isVip = true;

        Case c;
        Test.startTest();
        System.runAs(tUser) {
            c = CaseService.processExternalCase(extCase, custDto);
        }
        Test.stopTest();

        System.assertNotEquals(null, c.Id);
        System.assertEquals('EXT-2001', c.External_Case_Id__c);
        System.assertEquals('High', c.Priority);
        System.assertEquals(true, c.Is_VIP__c);

        Contact createdContact = [SELECT Id, LastName, Email, Account.Name FROM Contact WHERE Id = :c.ContactId];
        System.assertEquals('Alice Smith', createdContact.LastName);
        System.assertEquals('Smith Holdings', createdContact.Account.Name);
    }

    @isTest
    static void testProcessExistingExternalCaseWithExistingCustomer() {
        User tUser = getTestUser();
        Account acc = new Account(Name = 'Existing Account');
        insert acc;

        Contact con = new Contact(LastName = 'Existing Contact', Email = 'existing@example.com', AccountId = acc.Id);
        insert con;

        External_Case__c extCase = new External_Case__c(
            External_Case_Id__c = 'EXT-2002',
            Subject__c = 'Initial Subject',
            Description__c = 'Initial Desc',
            Priority__c = 'Medium',
            Status__c = 'Pending',
            Customer_Id__c = 'CUST-2002',
            Customer_Email__c = 'existing@example.com'
        );
        insert extCase;

        CustomerResponse custDto = new CustomerResponse();
        custDto.customerId = 'CUST-2002';
        custDto.name = 'Existing Contact';
        custDto.email = 'existing@example.com';
        custDto.isVip = false;

        Case c1;
        Case c2;
        Test.startTest();
        System.runAs(tUser) {
            c1 = CaseService.processExternalCase(extCase, custDto);
            extCase.Subject__c = 'Updated Subject';
            extCase.Priority__c = 'High';
            c2 = CaseService.processExternalCase(extCase, custDto);
        }
        Test.stopTest();

        System.assertEquals(c1.Id, c2.Id, 'Idempotent processing should update existing Case record rather than creating a new one');
        System.assertEquals('Updated Subject', c2.Subject);
        System.assertEquals('High', c2.Priority);
        System.assertEquals(con.Id, c2.ContactId);
    }

    @isTest
    static void testLwcMethods() {
        User tUser = getTestUser();
        Case c = new Case(
            Subject = 'LWC Test Case',
            Priority = 'High',
            Status = 'New',
            External_Case_Id__c = 'EXT-LWC-1'
        );
        insert c;

        Integration_Log__c logRecord = new Integration_Log__c(
            Service_Name__c = 'TestService',
            Endpoint__c = '/test',
            Status__c = 'Success',
            Status_Code__c = 200,
            External_Case_Id__c = 'EXT-LWC-1'
        );
        insert logRecord;

        List<Case> caseList;
        Case details;
        Case updatedStatusCase;
        List<Integration_Log__c> logs;

        Test.startTest();
        System.runAs(tUser) {
            caseList = CaseService.getCases('LWC', 'High', 'New');
            details = CaseService.getCaseDetails(c.Id);
            updatedStatusCase = CaseService.updateCaseStatus(c.Id, 'Working');
            logs = CaseService.getIntegrationLogs('EXT-LWC-1');
        }
        Test.stopTest();

        System.assertEquals(1, caseList.size());
        System.assertEquals('LWC Test Case', details.Subject);
        System.assertEquals('Working', updatedStatusCase.Status);
        System.assertEquals(1, logs.size());
    }

    @isTest
    static void testReassignCaseLwc() {
        User tUser = getTestUser();
        Case c = new Case(
            Subject = 'Reassign Test Case',
            Priority = 'Low',
            Status = 'New',
            External_Case_Id__c = 'EXT-LWC-2'
        );
        insert c;

        User u = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];

        Case reassigned;
        Test.startTest();
        System.runAs(tUser) {
            reassigned = CaseService.reassignCase(c.Id, u.Id);
        }
        Test.stopTest();

        System.assertEquals(u.Id, reassigned.OwnerId);
    }

    @isTest
    static void testUpdateCaseStatusClosedSuccess() {
        User tUser = getTestUser();
        Case c = new Case(
            Subject = 'Resolution Note Test Case',
            Priority = 'Medium',
            Status = 'New'
        );
        insert c;

        Case closedCase;
        Test.startTest();
        System.runAs(tUser) {
            closedCase = CaseService.updateCaseStatus(c.Id, 'Closed', 'Diagnosed generator issue and replaced capacitor.', 'Generator issue fixed');
        }
        Test.stopTest();

        System.assertEquals('Closed', closedCase.Status);
        System.assertEquals('Generator issue fixed', closedCase.Resolution_Summary__c);
        System.assertEquals('Diagnosed generator issue and replaced capacitor.', closedCase.Resolution_Notes__c);
        System.assertEquals(tUser.Id, closedCase.Resolved_By__c);
        System.assertNotEquals(null, closedCase.Resolved_Date__c);
    }

    @isTest
    static void testUpdateCaseStatusClosedBlankSummaryException() {
        User tUser = getTestUser();
        Case c = new Case(
            Subject = 'Resolution Summary Blank Test Case',
            Priority = 'Medium',
            Status = 'New'
        );
        insert c;

        Boolean exceptionThrown = false;
        String errorMessage = '';
        Test.startTest();
        System.runAs(tUser) {
            try {
                CaseService.updateCaseStatus(c.Id, 'Closed', 'Valid notes here', '   ');
            } catch (AuraHandledException e) {
                exceptionThrown = true;
                errorMessage = e.getMessage();
            }
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'AuraHandledException should be thrown when resolution summary is blank on closing');
    }

    @isTest
    static void testUpdateCaseStatusClosedBlankNotesException() {
        User tUser = getTestUser();
        Case c = new Case(
            Subject = 'Resolution Note Blank Test Case',
            Priority = 'Medium',
            Status = 'New'
        );
        insert c;

        Boolean exceptionThrown = false;
        Test.startTest();
        System.runAs(tUser) {
            try {
                CaseService.updateCaseStatus(c.Id, 'Closed', '   ', 'Valid summary here');
            } catch (AuraHandledException e) {
                exceptionThrown = true;
            }
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'AuraHandledException should be thrown when resolution notes are blank on closing');
    }

    @isTest
    static void testSetCaseToInProgressWithoutResolution() {
        User tUser = getTestUser();
        Case c = new Case(
            Subject = 'Working Test Case',
            Priority = 'Low',
            Status = 'New'
        );
        insert c;

        Case workingCase;
        Test.startTest();
        System.runAs(tUser) {
            workingCase = CaseService.updateCaseStatus(c.Id, 'Working', null, null);
        }
        Test.stopTest();

        System.assertEquals('Working', workingCase.Status);
        System.assertEquals(null, workingCase.Resolution_Summary__c);
        System.assertEquals(null, workingCase.Resolved_By__c);
        System.assertEquals(null, workingCase.Resolved_Date__c);
    }

    @isTest
    static void testGetCaseActivities() {
        User tUser = getTestUser();
        Case c = new Case(
            Subject = 'Activity Test Case',
            Priority = 'Medium',
            Status = 'New'
        );
        insert c;

        Task t = new Task(
            WhatId = c.Id,
            Subject = 'Call Customer to Verify Issue',
            Status = 'Completed',
            Priority = 'Normal',
            ActivityDate = Date.today(),
            Description = 'Contacted customer by phone and verified symptoms.'
        );
        insert t;

        List<Task> activities;
        List<Task> emptyActivities;
        Test.startTest();
        System.runAs(tUser) {
            activities = CaseService.getCaseActivities(c.Id);
            emptyActivities = CaseService.getCaseActivities(null);
        }
        Test.stopTest();

        System.assertEquals(1, activities.size(), 'Should return 1 related activity');
        System.assertEquals('Call Customer to Verify Issue', activities[0].Subject);
        System.assertEquals('Completed', activities[0].Status);
        System.assertEquals(0, emptyActivities.size(), 'Should return empty list for null caseId');
    }
}
