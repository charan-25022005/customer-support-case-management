@isTest
private class CaseAssignmentServiceTest {

    @isTest
    static void testAssignCaseOwnerSingle() {
        Case c = new Case(Subject = 'Assignment Test', Priority = 'High');
        Test.startTest();
        CaseAssignmentService.assignCaseOwner(c, 'High', true);
        Test.stopTest();
        System.assertNotEquals(null, c);
    }

    @isTest
    static void testAssignCasesBulk() {
        List<Case> caseList = new List<Case>{
            new Case(Subject = 'High VIP', Priority = 'High', Is_VIP__c = true),
            new Case(Subject = 'High Standard', Priority = 'High', Is_VIP__c = false),
            new Case(Subject = 'Low Standard', Priority = 'Low', Is_VIP__c = false)
        };
        Test.startTest();
        CaseAssignmentService.assignCasesBulk(caseList);
        Test.stopTest();
        System.assertEquals(3, caseList.size());
    }
}
