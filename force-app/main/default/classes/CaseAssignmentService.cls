public with sharing class CaseAssignmentService {

    public static void assignCaseOwner(Case caseRecord, String priority, Boolean isVip) {
        if (caseRecord == null) {
            return;
        }

        List<Case_Assignment_Rule__mdt> rules = [
            SELECT Priority__c, Is_VIP__c, Queue_Developer_Name__c, Order__c
            FROM Case_Assignment_Rule__mdt
            WHERE Active__c = true
            WITH SECURITY_ENFORCED
            ORDER BY Order__c ASC
        ];

        String targetQueueDevName = null;
        for (Case_Assignment_Rule__mdt rule : rules) {
            Boolean priorityMatch = String.isBlank(rule.Priority__c) || rule.Priority__c.equalsIgnoreCase(priority);
            Boolean vipMatch = rule.Is_VIP__c == null || rule.Is_VIP__c == isVip;

            if (priorityMatch && vipMatch) {
                targetQueueDevName = rule.Queue_Developer_Name__c;
                break;
            }
        }

        if (String.isNotBlank(targetQueueDevName)) {
            List<Group> queues = [
                SELECT Id
                FROM Group
                WHERE Type = 'Queue' AND DeveloperName = :targetQueueDevName
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];

            if (!queues.isEmpty()) {
                caseRecord.OwnerId = queues[0].Id;
            }
        }
    }

    public static void assignCasesBulk(List<Case> cases) {
        if (cases == null || cases.isEmpty()) {
            return;
        }

        List<Case_Assignment_Rule__mdt> rules = [
            SELECT Priority__c, Is_VIP__c, Queue_Developer_Name__c, Order__c
            FROM Case_Assignment_Rule__mdt
            WHERE Active__c = true
            WITH SECURITY_ENFORCED
            ORDER BY Order__c ASC
        ];

        Set<String> queueDevNames = new Set<String>();
        for (Case_Assignment_Rule__mdt rule : rules) {
            if (String.isNotBlank(rule.Queue_Developer_Name__c)) {
                queueDevNames.add(rule.Queue_Developer_Name__c);
            }
        }

        Map<String, Id> queueMap = new Map<String, Id>();
        if (!queueDevNames.isEmpty()) {
            for (Group grp : [SELECT Id, DeveloperName FROM Group WHERE Type = 'Queue' AND DeveloperName IN :queueDevNames WITH SECURITY_ENFORCED]) {
                queueMap.put(grp.DeveloperName, grp.Id);
            }
        }

        for (Case c : cases) {
            String priority = c.Priority;
            Boolean isVip = c.Is_VIP__c != null && c.Is_VIP__c;

            for (Case_Assignment_Rule__mdt rule : rules) {
                Boolean priorityMatch = String.isBlank(rule.Priority__c) || rule.Priority__c.equalsIgnoreCase(priority);
                Boolean vipMatch = rule.Is_VIP__c == null || rule.Is_VIP__c == isVip;

                if (priorityMatch && vipMatch) {
                    if (queueMap.containsKey(rule.Queue_Developer_Name__c)) {
                        c.OwnerId = queueMap.get(rule.Queue_Developer_Name__c);
                    }
                    break;
                }
            }
        }
    }
}
