@isTest
private class CaseTriggerHandlerTest {

    @isTest
    static void testCaseTriggerBeforeInsertAndUpdate() {
        Case c = new Case(
            Subject = 'Trigger Handler Test Case',
            Priority = 'Medium',
            Status = 'New',
            Is_VIP__c = false
        );

        Test.startTest();
        insert c;

        c.Priority = 'High';
        c.Is_VIP__c = true;
        update c;
        Test.stopTest();

        Case updatedCase = [SELECT Id, Priority, Is_VIP__c FROM Case WHERE Id = :c.Id];
        System.assertEquals('High', updatedCase.Priority);
        System.assertEquals(true, updatedCase.Is_VIP__c);
    }
}
