trigger CaseTrigger on Case (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            CaseTriggerHandler.beforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            CaseTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            CaseTriggerHandler.afterInsert(Trigger.new, Trigger.newMap);
        } else if (Trigger.isUpdate) {
            CaseTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}
