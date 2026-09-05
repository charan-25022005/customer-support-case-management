@isTest
private class CustomerApiServiceTest {

    @isTest
    static void testGetCustomerDetailsSuccess() {
        String mockResponseBody = '{"customerId":"CUST100","name":"Jane Smith","email":"jane@example.com","phone":"9876543210","company":"Tech Corp","tier":"Platinum","isVip":true}';
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, 'OK', mockResponseBody));

        Test.startTest();
        CustomerResponse res = CustomerApiService.getCustomerDetails('CUST100', 'EXT-100');
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assertEquals('CUST100', res.customerId);
        System.assertEquals('Jane Smith', res.name);
        System.assertEquals(true, res.isVip);
    }

    @isTest
    static void testGetCustomerDetailsBlankId() {
        Test.startTest();
        try {
            CustomerApiService.getCustomerDetails('', 'EXT-100');
            System.assert(false, 'Should have thrown exception for blank Customer ID');
        } catch (Exception ex) {
            System.assert(ex instanceof CustomerApiService.CustomerApiException);
        }
        Test.stopTest();
    }

    @isTest
    static void testGetCustomerDetailsHttp400() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(400, 'Bad Request', '{"error":"Invalid ID format"}'));

        Test.startTest();
        try {
            CustomerApiService.getCustomerDetails('BAD_ID', 'EXT-400');
            System.assert(false, 'Should have thrown exception for HTTP 400');
        } catch (Exception ex) {
            System.assert(ex instanceof CustomerApiService.CustomerApiException);
        }
        Test.stopTest();

        List<Integration_Log__c> logs = [SELECT Id, Status_Code__c, Status__c FROM Integration_Log__c WHERE External_Case_Id__c = 'EXT-400'];
        System.assertEquals(1, logs.size());
        System.assertEquals(400, logs[0].Status_Code__c);
    }

    @isTest
    static void testGetCustomerDetailsHttp401() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(401, 'Unauthorized', '{"error":"Unauthorized access"}'));

        Test.startTest();
        try {
            CustomerApiService.getCustomerDetails('CUST100', 'EXT-401');
            System.assert(false, 'Should have thrown exception for HTTP 401');
        } catch (Exception ex) {
            System.assert(ex instanceof CustomerApiService.CustomerApiException);
        }
        Test.stopTest();
    }

    @isTest
    static void testGetCustomerDetailsHttp404() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(404, 'Not Found', '{"error":"Customer not found"}'));

        Test.startTest();
        try {
            CustomerApiService.getCustomerDetails('CUST999', 'EXT-404');
            System.assert(false, 'Should have thrown exception for HTTP 404');
        } catch (Exception ex) {
            System.assert(ex instanceof CustomerApiService.CustomerApiException);
        }
        Test.stopTest();
    }

    @isTest
    static void testGetCustomerDetailsHttp500() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'Internal Server Error', '{"error":"Server crash"}'));

        Test.startTest();
        try {
            CustomerApiService.getCustomerDetails('CUST100', 'EXT-500');
            System.assert(false, 'Should have thrown exception for HTTP 500');
        } catch (Exception ex) {
            System.assert(ex instanceof CustomerApiService.CustomerApiException);
        }
        Test.stopTest();
    }
}
