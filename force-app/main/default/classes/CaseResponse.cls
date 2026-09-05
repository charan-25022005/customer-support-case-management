public with sharing class CaseResponse {
    public Boolean success { get; set; }
    public String message { get; set; }
    public String externalCaseId { get; set; }
    public String caseId { get; set; }
    public String caseNumber { get; set; }
    public String errorCode { get; set; }

    public CaseResponse() {
        this.success = true;
    }

    public CaseResponse(Boolean success, String message, String externalCaseId) {
        this.success = success;
        this.message = message;
        this.externalCaseId = externalCaseId;
    }

    public CaseResponse(Boolean success, String message, String externalCaseId, String errorCode) {
        this.success = success;
        this.message = message;
        this.externalCaseId = externalCaseId;
        this.errorCode = errorCode;
    }
}
