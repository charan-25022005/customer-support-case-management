public with sharing class CustomerApiService {

    public class CustomerApiException extends Exception {}

    public static CustomerResponse getCustomerDetails(String customerId, String externalCaseId) {
        if (String.isBlank(customerId)) {
            throw new CustomerApiException('Customer ID cannot be empty');
        }

        Long startTime = System.currentTimeMillis();
        String endpoint = 'callout:Customer_API/customers/' + EncodingUtil.urlEncode(customerId, 'UTF-8');
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(120000);

        Http http = new Http();
        HttpResponse res;

        try {
            res = http.send(req);
            Long executionTimeMs = System.currentTimeMillis() - startTime;

            if (res.getStatusCode() == 200) {
                CustomerResponse customerDto = CustomerResponse.parse(res.getBody());
                IntegrationLogService.log('CustomerApiService', endpoint, null, res.getBody(), res.getStatusCode(), 'Success', null, null, externalCaseId, executionTimeMs);
                return customerDto;
            } else {
                String errMsg = 'Customer API callout failed with status code ' + res.getStatusCode() + ': ' + res.getStatus() + ' - Body: ' + res.getBody();
                IntegrationLogService.log('CustomerApiService', endpoint, null, res != null ? res.getBody() : null, res != null ? res.getStatusCode() : 0, 'Error', errMsg, null, externalCaseId, executionTimeMs);
                throw new CustomerApiException(errMsg);
            }
        } catch (Exception ex) {
            Long executionTimeMs = System.currentTimeMillis() - startTime;
            if (!(ex instanceof CustomerApiException)) {
                IntegrationLogService.log('CustomerApiService', endpoint, null, res != null ? res.getBody() : null, res != null ? res.getStatusCode() : 0, 'Error', ex.getMessage(), ex.getStackTraceString(), externalCaseId, executionTimeMs);
            }
            throw ex;
        }
    }
}
