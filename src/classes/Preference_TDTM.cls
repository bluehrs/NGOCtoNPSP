global class Preference_TDTM extends npsp.TDTM_RunnableMutable {

    global override void run(List<SObject> newlist, List<SObject> oldlist, npsp.TDTM_Runnable.Action triggerAction, Schema.DescribeSObjectResult objResult, npsp.TDTM_Runnable.DmlWrapper dmlWrapper) {
        // Cast new and old list to Preference list
        List<Preference__c> newRecords = (List<Preference__c>) newlist;
        List<Preference__c> oldRecords = (List<Preference__c>) oldlist;
		// Run on before insert and update
        if (triggerAction == npsp.TDTM_Runnable.Action.BeforeInsert) {
        	onBeforeInsertUpdate(newRecords, null, dmlWrapper);
        }                                     
        else if (triggerAction == npsp.TDTM_Runnable.Action.BeforeUpdate) {
          	onBeforeInsertUpdate(newRecords, oldRecords, dmlWrapper);
        }
    }
    
    // Get Preference Settings for current User
    static Preference_Settings__c settings = Preference_Settings__c.getInstance();
    
    // Common method to set fields on before insert and before update
    private static void onBeforeInsertUpdate(List<Preference__c> newList, List<Preference__c> oldList, npsp.TDTM_Runnable.DmlWrapper dmlWrapper) {
        // Construct oldMap
        Map<Id,Preference__c> oldMap = new Map<Id,Preference__c>();
        if (oldList != null) {
            for (Preference__c p : oldList) {
                oldMap.put(p.Id, p);
            }
        }
        // Instantiate collections
        Set<String> codes = new Set<String>();
        Map<String,Preference_Code__c> codeMap = new Map<String,Preference_Code__c>();
        Set<String> categories = new Set<String>();
        Set<String> subcategories = new Set<String>();
        Set<String> types = new Set<String>();
        Set<String> subtypes = new Set<String>();
        Map<Id,Contact> conMap = new Map<Id,Contact>();
        List<Preference_Code__c> prefCodes = new List<Preference_Code__c>();
        // Set default Preference Code fields to populate and any user-defined fields
        List<String> pcFields = new List<String>{'Category__c','Subcategory__c','Type__c','Subtype__c'};
        pcFields.addAll(!String.isBlank(settings.Auto_Populate_Fields__c) ? settings.Auto_Populate_Fields__c.deleteWhitespace().split(',') : new List<String>());
        // Loop through Preferences to get initial collections
        for (Preference__c p : newList) {
            if (!settings.Disable_Auto_Populate__c) {
                // If Code Value not blank, add to set
            	if (oldList == null && !String.isBlank(p.Code_Value__c)) {
            		codes.add(p.Code_Value__c);
                }
            }
            // If should update Code Value on insert
            if (!settings.Disable_Update_Code_Value__c) {
                // If Code Value not specified, collect field values
                if (oldList == null && String.isBlank(p.Code_Value__c)) {
                    if (!String.isBlank(p.Category__c)) {
                        categories.add(p.Category__c);
                    }
                    if (!String.isBlank(p.Subcategory__c)) {
                        subcategories.add(p.Subcategory__c);
                    }
                    if (!String.isBlank(p.Type__c)) {
                        types.add(p.Type__c);
                    }
                    if (!String.isBlank(p.Subtype__c)) {
                        subtypes.add(p.Subtype__c);
                    }
                }
            }
            if (!settings.Disable_Create_Preference_Code__c) {
                // If Code Value set, add to set
                if (oldList == null && !String.isBlank(p.Code_Value__c)) {
                    codes.add(p.Code_Value__c);
                }
            }
            if (!settings.Disable_Update_Account__c) {
                // If Contact set but Account is not, add to Contact Map
            	if (p.Contact__c != null && p.Account__c == null) {
            		conMap.put(p.Contact__c, null);
                }
            }
        }
        // If either codes or categories filled out, then means some automation should run for Preference Codes
        if (!codes.isEmpty() || !categories.isEmpty()) {
            // Query all the fields on Preference Code for relevant Preference Codes
            String query = 'SELECT ' + String.join(new List<String>(SObjectType.Preference_Code__c.fields.getMap().keySet()), ', ') + ' FROM Preference_Code__c WHERE Code_Value__c IN :codes OR (Category__c in :categories AND Subcategory__c IN :subcategories AND Type__c IN :types AND Subtype__c IN :subtypes)';
            for (Preference_Code__c pc : (List<Preference_Code__c>)Database.query(query)) {
                // Add Preference Code to codeMap for both Code Value and field combination
                codeMap.put(pc.Code_Value__c, pc);
                codeMap.put(getKey(pc), pc);
            }
        }
        // Get map of Contacts set
        conMap = new Map<Id,Contact>([SELECT Id, AccountId FROM Contact WHERE Id IN :conMap.keySet()]);
        // Loop through Preferences again
        for (Preference__c p : newList) {
            // Get old Preference if exists
            Preference__c oldP = oldList == null ? null : oldMap.get(p.Id);
            if (!settings.Disable_Update_Account__c) {
                // If Contact set but Account is not
            	if (p.Contact__c != null && p.Account__c == null) {
                    // Update Account to Contact's Account
                    p.Account__c = conMap.get(p.Contact__c).AccountId;
                }
            }
            // Set text fields for Account and Contact
            p.Account_ID__c = p.Account__c;
            p.Contact_ID__c = p.Contact__c;
            // If specified Code Value exists
            if (!settings.Disable_Auto_Populate__c && oldList == null && !String.isBlank(p.Code_Value__c) && codeMap.containsKey(p.Code_Value__c)) {
                // Apply all the Preference Code values to the Preference
                Preference_Code__c pc = codeMap.get(p.Code_Value__c);
                for (String pcField : pcFields) {
                    p.put(pcField, pc.get(pcField));
                }
            }
            // Otherwise if Code Value set and doesn't already exist in Preference Code
            else if (!settings.Disable_Create_Preference_Code__c && oldList == null && !String.isBlank(p.Code_Value__c) && !codeMap.containsKey(p.Code_Value__c)) {
                // Create new Preference Code
                prefCodes.add(new Preference_Code__c(
                    Code_Value__c = p.Code_Value__c,
                    Category__c = p.Category__c,
                    Subcategory__c = p.Subcategory__c,
                    Type__c = p.Type__c,
                    Subtype__c = p.Subtype__c
                ));
            }
            // If should Update Code Value
            else if (!settings.Disable_Update_Code_Value__c) {
                // If Code Value not set but field combinations matches existing Code Value
                if (oldList == null && String.isBlank(p.Code_Value__c) && codeMap.containsKey(getKey(p))) {
                    // Set Code Value according to Preference Code
                    p.Code_Value__c = codeMap.get(getKey(p)).Code_Value__c;
                }
            }
            // If Start Date not set on insert
            if (!settings.Disable_Default_Start_Date__c) {
                if (p.Start_Date__c == null && oldList == null) {
                    // Set Start Date as today
                    p.Start_Date__c = Date.today();
                }
            }
            // If should sync Active and End Date fields
            if (!settings.Disable_Sync_Active_End_Date__c) {
                // If just set Active False but End Date is null
                if (!p.Active__c && p.End_Date__c == null && (oldList == null || oldP.Active__c)) {
                    // Set End Date to today
                    p.End_Date__c = Date.today();
                }
                // If just set End Date but Active
                else if (p.Active__c && p.End_Date__c != null && (oldList == null || p.End_Date__c != oldP.End_Date__c)) {
                    // Set Active to false
                    p.Active__c = false;
                }
                // If Active just set to true but End Date filled out
                else if (p.Active__c && p.End_Date__c != null && oldList != null && !oldP.Active__c) {
                    // Clear End Date
                    p.End_Date__c = null;
                }
                // If End Date just cleared but Active false
                else if (!p.Active__c && p.End_Date__c == null && oldList != null && p.End_Date__c != oldP.End_Date__c) {
                    // Set Active to true
                    p.Active__c = true;
                }
            }
        }
        // Insert new Preference Codes
        dmlWrapper.objectsToInsert.addAll(prefCodes);
    }
    
    // Get unique key for Preferences and Preference Codes
    private static String getKey(sObject s) {
        return elide(s.get('Category__c')) + ';' + elide(s.get('Subcategory__c')) + ';' + elide(s.get('Type__c')) + ';' + elide(s.get('Subtype__c'));
    }
    
    // Return empty string if string null or blank
    private static String elide(Object s) {
        return String.isBlank(String.valueOf(s)) ? '' : String.valueOf(s);
    }
}