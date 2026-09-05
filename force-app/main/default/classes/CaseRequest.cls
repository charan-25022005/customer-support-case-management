public with sharing class CaseRequest {
    public String externalCaseId { get; set; }
    public String subject { get; set; }
    public String description { get; set; }
    public String priority { get; set; }
    public String status { get; set; }
    public String customerId { get; set; }
    public String customerEmail { get; set; }
    public String customerPhone { get; set; }

    public static CaseRequest parse(String jsonString) {
        return (CaseRequest) JSON.deserialize(jsonString, CaseRequest.class);
    }
}
