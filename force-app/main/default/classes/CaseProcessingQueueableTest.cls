@isTest
private class CaseProcessingQueueableTest {

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
    static void testQueueableSuccess() {
        User tUser = getTestUser();
        External_Case__c extCase = new External_Case__c(
            External_Case_Id__c = 'EXT-ASYNC-1',
            Subject__c = 'Async Case Test',
            Description__c = 'Testing Queueable job',
            Priority__c = 'High',
            Status__c = 'Pending',
            Customer_Id__c = 'CUST-ASYNC-1',
            Customer_Email__c = 'async@example.com'
        );
        insert extCase;

        String mockCustomerJson = '{"customerId":"CUST-ASYNC-1","name":"Async User","email":"async@example.com","company":"Async Org","tier":"Gold","isVip":true}';
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, 'OK', mockCustomerJson));

        Test.startTest();
        System.runAs(tUser) {
            System.enqueueJob(new CaseProcessingQueueable(new List<Id>{ extCase.Id }));
        }
        Test.stopTest();

        External_Case__c updatedExtCase = [SELECT Id, Status__c, Salesforce_Case__c, Error_Message__c FROM External_Case__c WHERE Id = :extCase.Id];
        System.assertEquals('Processed', updatedExtCase.Status__c, 'Staging record should be updated to Processed');
        System.assertNotEquals(null, updatedExtCase.Salesforce_Case__c, 'Salesforce Case lookup should be populated');

        Case sfCase = [SELECT Id, Subject, Priority, Is_VIP__c FROM Case WHERE Id = :updatedExtCase.Salesforce_Case__c];
        System.assertEquals('Async Case Test', sfCase.Subject);
        System.assertEquals(true, sfCase.Is_VIP__c);
    }
}
