@isTest
public class MockHttpResponseGenerator implements HttpCalloutMock {
    private Integer statusCode;
    private String statusReason;
    private String responseBody;
    private Map<String, String> headers;

    public MockHttpResponseGenerator(Integer statusCode, String statusReason, String responseBody) {
        this.statusCode = statusCode;
        this.statusReason = statusReason;
        this.responseBody = responseBody;
        this.headers = new Map<String, String>{ 'Content-Type' => 'application/json' };
    }

    public MockHttpResponseGenerator(Integer statusCode, String statusReason, String responseBody, Map<String, String> headers) {
        this.statusCode = statusCode;
        this.statusReason = statusReason;
        this.responseBody = responseBody;
        this.headers = headers;
    }

    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(this.statusCode);
        res.setStatus(this.statusReason);
        res.setBody(this.responseBody);
        if (this.headers != null) {
            for (String key : this.headers.keySet()) {
                res.setHeader(key, this.headers.get(key));
            }
        }
        return res;
    }
}
