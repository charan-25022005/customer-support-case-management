public with sharing class CustomerResponse {
    public String customerId { get; set; }
    public String name { get; set; }
    public String email { get; set; }
    public String phone { get; set; }
    public String company { get; set; }
    public String tier { get; set; }
    public Boolean isVip { get; set; }

    public static CustomerResponse parse(String jsonString) {
        return (CustomerResponse) JSON.deserialize(jsonString, CustomerResponse.class);
    }
}
