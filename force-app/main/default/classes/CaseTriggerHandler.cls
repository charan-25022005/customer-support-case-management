public with sharing class CaseTriggerHandler {

    public static void beforeInsert(List<Case> newCases) {
        List<Case> casesNeedingAssignment = new List<Case>();
        for (Case c : newCases) {
            if (String.isNotBlank(c.Priority) && (c.OwnerId == null || c.OwnerId == UserInfo.getUserId())) {
                casesNeedingAssignment.add(c);
            }
        }
        if (!casesNeedingAssignment.isEmpty()) {
            CaseAssignmentService.assignCasesBulk(casesNeedingAssignment);
        }
    }

    public static void beforeUpdate(List<Case> newCases, Map<Id, Case> oldMap) {
        List<Case> casesNeedingReassignment = new List<Case>();
        for (Case c : newCases) {
            Case oldCase = oldMap.get(c.Id);
            if (oldCase != null && (c.Priority != oldCase.Priority || c.Is_VIP__c != oldCase.Is_VIP__c)) {
                casesNeedingReassignment.add(c);
            }
        }
        if (!casesNeedingReassignment.isEmpty()) {
            CaseAssignmentService.assignCasesBulk(casesNeedingReassignment);
        }
    }

    public static void afterInsert(List<Case> newCases, Map<Id, Case> newMap) {
        // Reserved for post-insert events
    }

    public static void afterUpdate(List<Case> newCases, Map<Id, Case> oldMap) {
        // Reserved for post-update events
    }
}
