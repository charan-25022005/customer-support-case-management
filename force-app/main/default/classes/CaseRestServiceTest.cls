@isTest
private class CaseRestServiceTest {

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
    static void testPostCaseSuccess() {
        User tUser = getTestUser();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, 'OK', '{"customerId":"CUST1001","name":"John Doe","email":"john@example.com","phone":"1234567890","company":"Acme Corp","tier":"Gold","isVip":true}'));

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/v1/cases/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"externalCaseId":"EXT-1001","subject":"Unable to Login","description":"Password reset fails","priority":"High","customerId":"CUST1001","customerEmail":"john@example.com","customerPhone":"1234567890"}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        System.runAs(tUser) {
            CaseRestService.handlePostCase();
        }
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Expected HTTP 200 OK');
        String responseStr = res.responseBody.toString();
        CaseResponse respDto = (CaseResponse) JSON.deserialize(responseStr, CaseResponse.class);
        System.assertEquals(true, respDto.success, 'Response success should be true');
        System.assertEquals('EXT-1001', respDto.externalCaseId, 'External Case ID should match');

        List<External_Case__c> extCases = [SELECT Id, Status__c, External_Case_Id__c FROM External_Case__c WHERE External_Case_Id__c = 'EXT-1001'];
        System.assertEquals(1, extCases.size(), 'Staging External Case record should be created');
    }

    @isTest
    static void testPostCaseEmptyBody() {
        User tUser = getTestUser();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/v1/cases/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        System.runAs(tUser) {
            CaseRestService.handlePostCase();
        }
        Test.stopTest();

        System.assertEquals(400, res.statusCode, 'Expected HTTP 400 Bad Request for empty body');
        CaseResponse respDto = (CaseResponse) JSON.deserialize(res.responseBody.toString(), CaseResponse.class);
        System.assertEquals(false, respDto.success, 'Response success should be false');
        System.assertEquals('INVALID_REQUEST', respDto.errorCode, 'Error code should be INVALID_REQUEST');
    }

    @isTest
    static void testPostCaseInvalidJson() {
        User tUser = getTestUser();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/v1/cases/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('invalid json string {');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        System.runAs(tUser) {
            CaseRestService.handlePostCase();
        }
        Test.stopTest();

        System.assertEquals(400, res.statusCode, 'Expected HTTP 400 for invalid JSON');
        CaseResponse respDto = (CaseResponse) JSON.deserialize(res.responseBody.toString(), CaseResponse.class);
        System.assertEquals('JSON_PARSE_ERROR', respDto.errorCode);
    }

    @isTest
    static void testPostCaseMissingFields() {
        User tUser = getTestUser();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/v1/cases/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"subject":"No Case Id"}');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        System.runAs(tUser) {
            CaseRestService.handlePostCase();
        }
        Test.stopTest();

        System.assertEquals(400, res.statusCode, 'Expected HTTP 400 for missing fields');
        CaseResponse respDto = (CaseResponse) JSON.deserialize(res.responseBody.toString(), CaseResponse.class);
        System.assertEquals('MISSING_REQUIRED_FIELDS', respDto.errorCode);
    }
}
