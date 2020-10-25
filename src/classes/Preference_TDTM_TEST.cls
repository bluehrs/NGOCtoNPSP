@isTest
private class Preference_TDTM_TEST {

	@testSetup static void setup() {
		// Retrieve default NPSP Trigger Handlers
		List<npsp__Trigger_Handler__c> triggerHandlers = npsp.TDTM_Config_API.getCachedRecords();
		// Add our Trigger Handler to cached Trigger Handlers
		npsp__Trigger_Handler__c th = new npsp__Trigger_Handler__c();
		th.Name = 'Preference__c';
		th.npsp__Class__c = 'Preference_TDTM';
		th.npsp__Object__c = 'Preference__c';
		th.npsp__Trigger_Action__c = 'BeforeInsert;BeforeUpdate';
		th.npsp__Active__c = true;
		th.npsp__Load_Order__c = 1;
		th.npsp__Asynchronous__c = false;
		triggerHandlers.add(th);
		upsert triggerHandlers;
		// Create default Preference Settings record
		Preference_Settings__c settings = Preference_Settings__c.getInstance();
		upsert settings;
	}

	@isTest static void testAutoPopulate() {
		// Insert Preference Code
		Preference_Code__c pc = createPreferenceCode('Test', '1', 'A', 'a', 'I');
		insert pc;
		Test.startTest();
		// Create Preference with same Code Value
		Preference__c p = createPreference(pc.Code_Value__c, null, null, null, null);
		insert p;
		Test.stopTest();
		// Verify that Preference has all values from Preference Code
		p = [SELECT Category__c, Subcategory__c, Type__c, Subtype__c FROM Preference__c WHERE Id = :p.Id];
		for (String f : new List<String>{'Category__c', 'Subcategory__c', 'Type__c', 'Subtype__c'}) {
			System.assertEquals(pc.get(f), p.get(f));
		}
	}

	@isTest static void testCreatePreferenceCode() {
		Test.startTest();
		// Insert Preference with no Code Value but associated values to Preference Code
		Preference__c p = createPreference('Test', '1', 'A', 'a', 'I');
		insert p;
		Test.stopTest();
		// Verify Preference Code was created
		Preference_Code__c pc = [SELECT Category__c, Subcategory__c, Type__c, Subtype__c FROM Preference_Code__c WHERE Code_Value__c = :p.Code_Value__c];
		for (String f : new List<String>{'Category__c', 'Subcategory__c', 'Type__c', 'Subtype__c'}) {
			System.assertEquals(p.get(f), pc.get(f));
		}
	}

	@isTest static void testDefaultStartDate() {
		Test.startTest();
		// Insert Preference with no Code Value but associated values to Preference Code
		Preference__c p = createPreference(null, '1', 'A', 'a', 'I');
		insert p;
		Test.stopTest();
		// Verify Start Date was set to today
		p = [SELECT Start_Date__c FROM Preference__c WHERE Id = :p.Id];
		System.assertEquals(Date.today(), p.Start_Date__c);
	}

	@isTest static void testSyncActiveEndDate() {
		Test.startTest();
		// Insert Preferences with Active false and End Date not null
		Preference__c p1 = createPreference(null, '1', 'A', 'a', 'I');
		p1.Active__c = false;
		Preference__c p2 = createPreference(null, '2', 'B', 'b', 'II');
		p2.End_Date__c = Date.today();
		insert new List<Preference__c>{p1,p2};
		// Verify End Date was set to today
		p1 = [SELECT End_Date__c FROM Preference__c WHERE Id = :p1.Id];
		System.assertEquals(Date.today(), p1.End_Date__c);
		// Verify Active was set to false
		p2 = [SELECT Active__c FROM Preference__c WHERE Id = :p2.Id];
		System.assertEquals(false, p2.Active__c);
		// Update Preferences to Active true and End Date null
		p1.Active__c = true;
		p2.End_Date__c = null;
		update new List<Preference__c>{p1,p2};
		// Verify End Date cleared
		p1 = [SELECT End_Date__c FROM Preference__c WHERE Id = :p1.Id];
		System.assertEquals(null, p1.End_Date__c);
		// Verify Active was set to true
		p2 = [SELECT Active__c FROM Preference__c WHERE Id = :p2.Id];
		System.assertEquals(true, p2.Active__c);
		Test.stopTest();
	}

	@isTest static void testUpdateAccount() {
		// Create Account and Contact
		Account a = new Account(Name = 'Test');
		insert a;
		Contact c = new Contact(AccountId = a.Id, LastName = 'Test');
		insert c;
		Test.startTest();
		// Insert Preference with only Contact set
		Preference__c p = createPreference(null, '1', 'A', 'a', 'I');
		p.Contact__c = c.Id;
		insert p;
		Test.stopTest();
		// Verify Account set
		p = [SELECT Account__c FROM Preference__c WHERE Id = :p.Id];
		System.assertEquals(a.Id, p.Account__c);
	}

	@isTest static void testUpdateCodeValue() {
		// Insert Preference Code
		Preference_Code__c pc = createPreferenceCode('Test', '1', 'A', 'a', 'I');
		insert pc;
		Test.startTest();
		// Insert Preference with no Code Value but associated values to Preference Code
		Preference__c p = createPreference(null, '1', 'A', 'a', 'I');
		insert p;
		Test.stopTest();
		// Verify Code Value was set on Preference
		p = [SELECT Code_Value__c FROM Preference__c WHERE Id = :p.Id];
		System.assertEquals(pc.Code_Value__c, p.Code_Value__c);
	}

	// Create Preference and Preference Code with specified parameters
	private static Preference__c createPreference(String codeValue, String category, String subcategory, String type, String subtype) {
		return new Preference__c(Code_Value__c = codeValue, Category__c = category, Subcategory__c = subcategory, Type__c = type, Subtype__c = subtype);
	}
	private static Preference_Code__c createPreferenceCode(String codeValue, String category, String subcategory, String type, String subtype) {
		return new Preference_Code__c(Code_Value__c = codeValue, Category__c = category, Subcategory__c = subcategory, Type__c = type, Subtype__c = subtype);
	}
}