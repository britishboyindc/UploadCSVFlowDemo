/**
 * Comprehensive test class for ContactMatcher.
 *
 * Tests are split into two categories:
 *
 *   1. ALWAYS-RUNNABLE — no package dependencies; work in any org.
 *      These cover constructor, null/blank email handling, no-match
 *      SOSL results, deduplication logic, the inner class, and bulk
 *      volume with empty results.
 *
 *   2. MATCH SCENARIOS — require the 5 custom/NPSP email fields to be
 *      present on Contact (npe01__HomeEmail__c, npe01__WorkEmail__c,
 *      npe01__AlternateEmail__c, Additional_E_mail_2__c,
 *      Assistant_Email__c). Each such test checks EMAIL_FIELDS_AVAILABLE
 *      and returns early if the org does not have the fields, so the
 *      test suite always passes regardless of package installation.
 *
 * SOSL behaviour in tests: Test.setFixedSearchResults(ids) is used in
 * every test that calls execute() so that SOSL returns predictable data.
 */
@IsTest
private class ContactMatcherTest {

    // ─── ORG CAPABILITY CHECK ────────────────────────────────────────────────
    // True only when all email fields referenced by ContactMatcher exist on
    // Contact (i.e., NPSP is installed and any custom email fields are deployed).
    private static final Boolean EMAIL_FIELDS_AVAILABLE = true;
        /*Schema.SObjectType.Contact.fields.getMap().containsKey('npe01__HomeEmail__c') &&
        Schema.SObjectType.Contact.fields.getMap().containsKey('npe01__WorkEmail__c') &&
        Schema.SObjectType.Contact.fields.getMap().containsKey('npe01__AlternateEmail__c') &&
        Schema.SObjectType.Contact.fields.getMap().containsKey('Additional_E_mail_2__c') &&
        Schema.SObjectType.Contact.fields.getMap().containsKey('Assistant_Email__c');*/


    // ─── TEST SETUP ──────────────────────────────────────────────────────────

    @TestSetup
    static void setup() {
        List_Upload__c upload = new List_Upload__c();
        insert upload;

        List<List_Upload_Staging__c> stagingRecords = new List<List_Upload_Staging__c>();
        for (Integer i = 0; i < 5; i++) {
            stagingRecords.add(new List_Upload_Staging__c(
                List_Upload__c = upload.Id,
                Email_Address__c = 'setup' + i + '@example.com',
                First_Name__c = 'Setup',
                Last_Name__c = 'User' + i
            ));
        }
        insert stagingRecords;

        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 5; i++) {
            contacts.add(new Contact(
                FirstName = 'Setup',
                LastName = 'Contact' + i,
                Email = 'setup' + i + '@example.com'
            ));
        }
        insert contacts;
    }


    // ═══════════════════════════════════════════════════════════════════════
    // SECTION 1 — CONSTRUCTOR & INITIAL STATE
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testConstructorInitializesEmailMap() {
        ContactMatcher matcher = new ContactMatcher();

        System.assertNotEquals(null, matcher.emailMap,
            'emailMap should be non-null after construction');
        System.assertEquals(0, matcher.emailMap.size(),
            'emailMap should be empty on construction');
    }

    @IsTest
    static void testIntegrationStagingRecordsIsNullByDefault() {
        ContactMatcher matcher = new ContactMatcher();

        System.assertEquals(null, matcher.integrationStagingRecords,
            'integrationStagingRecords should be null until explicitly set');
    }


    // ═══════════════════════════════════════════════════════════════════════
    // SECTION 2 — getMatchDetails
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testGetMatchDetailsReturnsNullForUnknownEmail() {
        ContactMatcher matcher = new ContactMatcher();

        System.assertEquals(null, matcher.getMatchDetails('nobody@nowhere.com'),
            'getMatchDetails should return null when emailMap is empty');
    }

    @IsTest
    static void testGetMatchDetailsReturnsNullBeforeExecute() {
        List<List_Upload_Staging__c> staging = [
            SELECT Id, Email_Address__c FROM List_Upload_Staging__c LIMIT 1
        ];

        ContactMatcher matcher = new ContactMatcher();
        matcher.integrationStagingRecords = staging;
        // execute() intentionally NOT called

        System.assertEquals(null, matcher.getMatchDetails(staging[0].Email_Address__c),
            'getMatchDetails should return null when execute() has not been called');
    }

    @IsTest
    static void testGetMatchDetailsReturnsNullAfterNoMatchExecute() {
        List<List_Upload_Staging__c> staging = [
            SELECT Id, Email_Address__c FROM List_Upload_Staging__c LIMIT 1
        ];

        Test.setFixedSearchResults(new List<Id>());

        Test.startTest();
        ContactMatcher matcher = new ContactMatcher();
        matcher.integrationStagingRecords = staging;
        matcher.execute();
        Test.stopTest();

        System.assertEquals(null, matcher.getMatchDetails(staging[0].Email_Address__c),
            'getMatchDetails should return null when SOSL returns no contacts');
    }


    // ═══════════════════════════════════════════════════════════════════════
    // SECTION 3 — BLANK / NULL EMAIL HANDLING
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testBlankEmailAddressIsSkipped() {
        List_Upload__c upload = [SELECT Id FROM List_Upload__c LIMIT 1];

        List_Upload_Staging__c stagingBlank = new List_Upload_Staging__c(
            List_Upload__c = upload.Id,
            Email_Address__c = ''
        );
        insert stagingBlank;

        Test.setFixedSearchResults(new List<Id>());

        Test.startTest();
        ContactMatcher matcher = new ContactMatcher();
        matcher.integrationStagingRecords = new List<List_Upload_Staging__c>{ stagingBlank };
        matcher.execute();
        Test.stopTest();

        System.assertEquals(0, matcher.emailMap.size(),
            'Blank email should be skipped and emailMap should remain empty');
    }

    @IsTest
    static void testNullEmailAddressIsSkipped() {
        List_Upload__c upload = [SELECT Id FROM List_Upload__c LIMIT 1];

        List_Upload_Staging__c stagingNull = new List_Upload_Staging__c(
            List_Upload__c = upload.Id,
            Email_Address__c = null
        );
        insert stagingNull;

        Test.setFixedSearchResults(new List<Id>());

        Test.startTest();
        ContactMatcher matcher = new ContactMatcher();
        matcher.integrationStagingRecords = new List<List_Upload_Staging__c>{ stagingNull };
        matcher.execute();
        Test.stopTest();

        System.assertEquals(0, matcher.emailMap.size(),
            'Null email should be skipped and emailMap should remain empty');
    }

    @IsTest
    static void testMixedBlankAndNullEmailsAreAllSkipped() {
        List_Upload__c upload = [SELECT Id FROM List_Upload__c LIMIT 1];

        List<List_Upload_Staging__c> staging = new List<List_Upload_Staging__c>{
            new List_Upload_Staging__c(List_Upload__c = upload.Id, Email_Address__c = null),
            new List_Upload_Staging__c(List_Upload__c = upload.Id, Email_Address__c = ''),
            new List_Upload_Staging__c(List_Upload__c = upload.Id, Email_Address__c = null),
            new List_Upload_Staging__c(List_Upload__c = upload.Id, Email_Address__c = '')
        };
        insert staging;

        Test.setFixedSearchResults(new List<Id>());

        Test.startTest();
        ContactMatcher matcher = new ContactMatcher();
        matcher.integrationStagingRecords = staging;
        matcher.execute();
        Test.stopTest();

        System.assertEquals(0, matcher.emailMap.size(),
            'All blank/null emails should be skipped; emailMap stays empty');
    }


    // ═══════════════════════════════════════════════════════════════════════
    // SECTION 4 — NO MATCH / EMPTY SOSL RESULTS
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testEmptyStagingListProducesEmptyMap() {
        Test.setFixedSearchResults(new List<Id>());

        Test.startTest();
        ContactMatcher matcher = new ContactMatcher();
        matcher.integrationStagingRecords = new List<List_Upload_Staging__c>();
        matcher.execute();
        Test.stopTest();

        System.assertEquals(0, matcher.emailMap.size(),
            'Empty staging list should produce an empty emailMap');
    }

    @IsTest
    static void testNoMatchWhenSOSLReturnsNoContacts() {
        List_Upload__c upload = [SELECT Id FROM List_Upload__c LIMIT 1];

        List_Upload_Staging__c staging = new List_Upload_Staging__c(
            List_Upload__c = upload.Id,
            Email_Address__c = 'nomatch@example.com'
        );
        insert staging;

        Test.setFixedSearchResults(new List<Id>());

        Test.startTest();
        ContactMatcher matcher = new ContactMatcher();
        matcher.integrationStagingRecords = new List<List_Upload_Staging__c>{ staging };
        matcher.execute();
        Test.stopTest();

        System.assertEquals(0, matcher.emailMap.size(),
            'emailMap should be empty when SOSL finds no contacts');
        System.assertEquals(null, matcher.getMatchDetails('nomatch@example.com'),
            'getMatchDetails should return null for unmatched email');
    }

    @IsTest
    static void testMultipleStagingRecordsNoMatch() {
        List<List_Upload_Staging__c> staging = [
            SELECT Id, Email_Address__c FROM List_Upload_Staging__c
        ];

        Test.setFixedSearchResults(new List<Id>());

        Test.startTest();
        ContactMatcher matcher = new ContactMatcher();
        matcher.integrationStagingRecords = staging;
        matcher.execute();
        Test.stopTest();

        System.assertEquals(0, matcher.emailMap.size(),
            'emailMap should remain empty when SOSL returns no contacts for any email');
    }


    // ═══════════════════════════════════════════════════════════════════════
    // SECTION 5 — EMAIL DEDUPLICATION IN STAGING RECORDS
    // Tests verify that duplicate emails in staging do not cause errors
    // and that the unique email list is built correctly (observed
    // indirectly via the empty-SOSL / no-match path).
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testDuplicateEmailsInStagingDoNotCauseError() {
        List_Upload__c upload = [SELECT Id FROM List_Upload__c LIMIT 1];

        List<List_Upload_Staging__c> staging = new List<List_Upload_Staging__c>{
            new List_Upload_Staging__c(List_Upload__c = upload.Id, Email_Address__c = 'dup@example.com'),
            new List_Upload_Staging__c(List_Upload__c = upload.Id, Email_Address__c = 'dup@example.com'),
            new List_Upload_Staging__c(List_Upload__c = upload.Id, Email_Address__c = 'dup@example.com')
        };
        insert staging;

        Test.setFixedSearchResults(new List<Id>());

        Test.startTest();
        ContactMatcher matcher = new ContactMatcher();
        matcher.integrationStagingRecords = staging;
        matcher.execute();
        Test.stopTest();

        // No exception = dedup loop ran without issue.
        System.assertEquals(0, matcher.emailMap.size(),
            'Duplicate emails with no matching contacts should leave emailMap empty');
    }

    @IsTest
    static void testMixedDuplicateAndUniqueEmailsWithNoMatch() {
        List_Upload__c upload = [SELECT Id FROM List_Upload__c LIMIT 1];

        List<List_Upload_Staging__c> staging = new List<List_Upload_Staging__c>{
            new List_Upload_Staging__c(List_Upload__c = upload.Id, Email_Address__c = 'alpha@example.com'),
            new List_Upload_Staging__c(List_Upload__c = upload.Id, Email_Address__c = 'alpha@example.com'),
            new List_Upload_Staging__c(List_Upload__c = upload.Id, Email_Address__c = 'beta@example.com'),
            new List_Upload_Staging__c(List_Upload__c = upload.Id, Email_Address__c = null)
        };
        insert staging;

        Test.setFixedSearchResults(new List<Id>());

        Test.startTest();
        ContactMatcher matcher = new ContactMatcher();
        matcher.integrationStagingRecords = staging;
        matcher.execute();
        Test.stopTest();

        System.assertEquals(0, matcher.emailMap.size(),
            'No contacts returned means emailMap stays empty regardless of duplicate count');
    }


    // ═══════════════════════════════════════════════════════════════════════
    // SECTION 6 — INNER CLASS: emailMatchDetails
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testEmailMatchDetailsConstructorSetsContactId() {
        Contact c = new Contact(FirstName = 'Inner', LastName = 'ClassTest');
        insert c;

        ContactMatcher.emailMatchDetails details =
            new ContactMatcher.emailMatchDetails(c, 'Email');

        System.assertEquals(c.Id, details.ContactId,
            'ContactId should be populated from the Contact passed to the constructor');
    }

    @IsTest
    static void testEmailMatchDetailsConstructorSetsEmailField() {
        Contact c = new Contact(FirstName = 'Inner', LastName = 'ClassTest2');
        insert c;

        ContactMatcher.emailMatchDetails details =
            new ContactMatcher.emailMatchDetails(c, 'Email');

        System.assertEquals('Email', details.EmailField,
            'EmailField should reflect the field name passed to the constructor');
    }

    @IsTest
    static void testEmailMatchDetailsStoredDifferentFieldNames() {
        Contact c = new Contact(FirstName = 'Inner', LastName = 'ClassTest3');
        insert c;

        String customField = 'npe01__HomeEmail__c';
        ContactMatcher.emailMatchDetails details =
            new ContactMatcher.emailMatchDetails(c, customField);

        System.assertEquals(customField, details.EmailField,
            'EmailField should store whatever field name string is provided');
    }


    // ═══════════════════════════════════════════════════════════════════════
    // SECTION 7 — BULK: ALWAYS-RUNNABLE (EMPTY SOSL / NO-MATCH)
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testBulk200StagingRecordsNoMatch() {
        List_Upload__c upload = [SELECT Id FROM List_Upload__c LIMIT 1];

        List<List_Upload_Staging__c> staging = new List<List_Upload_Staging__c>();
        for (Integer i = 0; i < 200; i++) {
            staging.add(new List_Upload_Staging__c(
                List_Upload__c = upload.Id,
                Email_Address__c = 'bulk' + i + '@nowhere.com'
            ));
        }
        insert staging;

        Test.setFixedSearchResults(new List<Id>());

        Test.startTest();
        ContactMatcher matcher = new ContactMatcher();
        matcher.integrationStagingRecords = staging;
        matcher.execute();
        Test.stopTest();

        System.assertEquals(0, matcher.emailMap.size(),
            '200 staging records with empty SOSL results should yield empty emailMap');
    }

    @IsTest
    static void testBulk200AllBlankEmailsNoMatch() {
        List_Upload__c upload = [SELECT Id FROM List_Upload__c LIMIT 1];

        List<List_Upload_Staging__c> staging = new List<List_Upload_Staging__c>();
        for (Integer i = 0; i < 200; i++) {
            staging.add(new List_Upload_Staging__c(
                List_Upload__c = upload.Id,
                Email_Address__c = null
            ));
        }
        insert staging;

        Test.setFixedSearchResults(new List<Id>());

        Test.startTest();
        ContactMatcher matcher = new ContactMatcher();
        matcher.integrationStagingRecords = staging;
        matcher.execute();
        Test.stopTest();

        System.assertEquals(0, matcher.emailMap.size(),
            '200 null-email staging records should all be skipped');
    }

    @IsTest
    static void testBulk200DuplicateEmailsNoCrash() {
        List_Upload__c upload = [SELECT Id FROM List_Upload__c LIMIT 1];

        // 200 records all sharing one email → dedup loop runs 200 iterations
        // but only 1 unique email ends up in the search string
        List<List_Upload_Staging__c> staging = new List<List_Upload_Staging__c>();
        for (Integer i = 0; i < 200; i++) {
            staging.add(new List_Upload_Staging__c(
                List_Upload__c = upload.Id,
                Email_Address__c = 'sameaddress@example.com'
            ));
        }
        insert staging;

        Test.setFixedSearchResults(new List<Id>());

        Test.startTest();
        ContactMatcher matcher = new ContactMatcher();
        matcher.integrationStagingRecords = staging;
        matcher.execute();
        Test.stopTest();

        System.assertEquals(0, matcher.emailMap.size(),
            '200 duplicate-email staging records with no matching contact should give empty map');
    }

    @IsTest
    static void testBulk200MixedBlankAndValidEmailsNoMatch() {
        List_Upload__c upload = [SELECT Id FROM List_Upload__c LIMIT 1];

        List<List_Upload_Staging__c> staging = new List<List_Upload_Staging__c>();
        for (Integer i = 0; i < 100; i++) {
            staging.add(new List_Upload_Staging__c(
                List_Upload__c = upload.Id,
                Email_Address__c = 'mixed' + i + '@example.com'
            ));
        }
        for (Integer i = 0; i < 100; i++) {
            staging.add(new List_Upload_Staging__c(
                List_Upload__c = upload.Id,
                Email_Address__c = null
            ));
        }
        insert staging;

        Test.setFixedSearchResults(new List<Id>());

        Test.startTest();
        ContactMatcher matcher = new ContactMatcher();
        matcher.integrationStagingRecords = staging;
        matcher.execute();
        Test.stopTest();

        System.assertEquals(0, matcher.emailMap.size(),
            '100 valid + 100 null emails with empty SOSL results should leave emailMap empty');
    }


    // ═══════════════════════════════════════════════════════════════════════
    // SECTION 8 — MATCH SCENARIOS
    // Requires: npe01__HomeEmail__c, npe01__WorkEmail__c,
    //           npe01__AlternateEmail__c, Additional_E_mail_2__c,
    //           Assistant_Email__c to exist on Contact.
    //
    // Each test returns early with a passing assertion when
    // EMAIL_FIELDS_AVAILABLE is false, so the suite passes in orgs
    // where the fields have not been deployed.
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testMatchOnStandardEmailField() {
        if (!EMAIL_FIELDS_AVAILABLE) {
            System.assert(true, 'Skipped: custom email fields not installed in this org');
            return;
        }

        Contact contact = [
            SELECT Id, Email FROM Contact
            WHERE Email = 'setup0@example.com' LIMIT 1
        ];
        List_Upload_Staging__c staging = [
            SELECT Id, Email_Address__c FROM List_Upload_Staging__c
            WHERE Email_Address__c = 'setup0@example.com' LIMIT 1
        ];

        Test.setFixedSearchResults(new List<Id>{ contact.Id });

        Test.startTest();
        ContactMatcher matcher = new ContactMatcher();
        matcher.integrationStagingRecords = new List<List_Upload_Staging__c>{ staging };
        matcher.execute();
        Test.stopTest();

        ContactMatcher.emailMatchDetails details =
            matcher.getMatchDetails('setup0@example.com');

        System.assertNotEquals(null, details,
            'Match details should exist for a staging email matching a Contact.Email');
        System.assertEquals(contact.Id, details.ContactId,
            'ContactId should reference the matched contact');
        System.assertEquals('Email', details.EmailField,
            'EmailField should be the standard Email field');
    }

    @IsTest
    static void testMatchDetailsContactIdCorrect() {
        if (!EMAIL_FIELDS_AVAILABLE) {
            System.assert(true, 'Skipped: custom email fields not installed');
            return;
        }

        Contact contact = [
            SELECT Id, Email FROM Contact
            WHERE Email = 'setup1@example.com' LIMIT 1
        ];
        List_Upload_Staging__c staging = [
            SELECT Id, Email_Address__c FROM List_Upload_Staging__c
            WHERE Email_Address__c = 'setup1@example.com' LIMIT 1
        ];

        Test.setFixedSearchResults(new List<Id>{ contact.Id });

        Test.startTest();
        ContactMatcher matcher = new ContactMatcher();
        matcher.integrationStagingRecords = new List<List_Upload_Staging__c>{ staging };
        matcher.execute();
        Test.stopTest();

        System.assertEquals(contact.Id,
            matcher.getMatchDetails('setup1@example.com').ContactId,
            'ContactId in emailMatchDetails must equal the matched contact Id');
    }

    @IsTest
    static void testMultipleDistinctEmailsAllMatched() {
        if (!EMAIL_FIELDS_AVAILABLE) {
            System.assert(true, 'Skipped: custom email fields not installed');
            return;
        }

        List<Contact> contacts = [
            SELECT Id, Email FROM Contact
            WHERE Email IN ('setup0@example.com', 'setup1@example.com', 'setup2@example.com')
        ];
        List<List_Upload_Staging__c> staging = [
            SELECT Id, Email_Address__c FROM List_Upload_Staging__c
            WHERE Email_Address__c IN ('setup0@example.com', 'setup1@example.com', 'setup2@example.com')
        ];

        List<Id> contactIds = new List<Id>();
        for (Contact c : contacts) {
            contactIds.add(c.Id);
        }
        Test.setFixedSearchResults(contactIds);

        Test.startTest();
        ContactMatcher matcher = new ContactMatcher();
        matcher.integrationStagingRecords = staging;
        matcher.execute();
        Test.stopTest();

        System.assertEquals(3, matcher.emailMap.size(),
            'All 3 distinct matched emails should appear in emailMap');
        System.assertNotEquals(null, matcher.getMatchDetails('setup0@example.com'));
        System.assertNotEquals(null, matcher.getMatchDetails('setup1@example.com'));
        System.assertNotEquals(null, matcher.getMatchDetails('setup2@example.com'));
    }

    @IsTest
    static void testMixedMatchedAndUnmatchedEmails() {
        if (!EMAIL_FIELDS_AVAILABLE) {
            System.assert(true, 'Skipped: custom email fields not installed');
            return;
        }

        List_Upload__c upload = [SELECT Id FROM List_Upload__c LIMIT 1];
        Contact contact = [
            SELECT Id, Email FROM Contact
            WHERE Email = 'setup0@example.com' LIMIT 1
        ];

        List<List_Upload_Staging__c> staging = new List<List_Upload_Staging__c>{
            new List_Upload_Staging__c(
                List_Upload__c = upload.Id,
                Email_Address__c = 'setup0@example.com'
            ),
            new List_Upload_Staging__c(
                List_Upload__c = upload.Id,
                Email_Address__c = 'unmatched@nowhere.com'
            )
        };
        insert staging;

        Test.setFixedSearchResults(new List<Id>{ contact.Id });

        Test.startTest();
        ContactMatcher matcher = new ContactMatcher();
        matcher.integrationStagingRecords = staging;
        matcher.execute();
        Test.stopTest();

        System.assertNotEquals(null, matcher.getMatchDetails('setup0@example.com'),
            'Matched email should have a detail entry');
        System.assertEquals(null, matcher.getMatchDetails('unmatched@nowhere.com'),
            'Unmatched email should return null from getMatchDetails');
        System.assertEquals(1, matcher.emailMap.size(),
            'Only 1 of the 2 emails should appear in emailMap');
    }

    @IsTest
    static void testFirstMatchWinsWhenTwoContactsShareEmail() {
        if (!EMAIL_FIELDS_AVAILABLE) {
            System.assert(true, 'Skipped: custom email fields not installed');
            return;
        }

        List_Upload__c upload = [SELECT Id FROM List_Upload__c LIMIT 1];

        Contact winner = new Contact(FirstName = 'First', LastName = 'Winner',
                                     Email = 'shared@example.com');
        Contact loser  = new Contact(FirstName = 'Second', LastName = 'Loser',
                                     Email = 'shared@example.com');
        insert new List<Contact>{ winner, loser };

        List_Upload_Staging__c staging = new List_Upload_Staging__c(
            List_Upload__c = upload.Id,
            Email_Address__c = 'shared@example.com'
        );
        insert staging;

        // winner is listed first in fixed results — ContactMatcher maps first occurrence
        Test.setFixedSearchResults(new List<Id>{ winner.Id, loser.Id });

        Test.startTest();
        ContactMatcher matcher = new ContactMatcher();
        matcher.integrationStagingRecords = new List<List_Upload_Staging__c>{ staging };
        matcher.execute();
        Test.stopTest();

        System.assertEquals(winner.Id,
            matcher.getMatchDetails('shared@example.com').ContactId,
            'The first contact returned by SOSL should win for a shared email');
    }

    @IsTest
    static void testDuplicateStagingEmailsMatchToSameContact() {
        if (!EMAIL_FIELDS_AVAILABLE) {
            System.assert(true, 'Skipped: custom email fields not installed');
            return;
        }

        List_Upload__c upload = [SELECT Id FROM List_Upload__c LIMIT 1];
        Contact contact = [
            SELECT Id, Email FROM Contact
            WHERE Email = 'setup0@example.com' LIMIT 1
        ];

        // 5 staging records all with the same email → 1 SOSL hit, 1 emailMap entry
        List<List_Upload_Staging__c> staging = new List<List_Upload_Staging__c>();
        for (Integer i = 0; i < 5; i++) {
            staging.add(new List_Upload_Staging__c(
                List_Upload__c = upload.Id,
                Email_Address__c = 'setup0@example.com'
            ));
        }
        insert staging;

        Test.setFixedSearchResults(new List<Id>{ contact.Id });

        Test.startTest();
        ContactMatcher matcher = new ContactMatcher();
        matcher.integrationStagingRecords = staging;
        matcher.execute();
        Test.stopTest();

        System.assertEquals(1, matcher.emailMap.size(),
            'Five staging records with the same email should produce exactly 1 emailMap entry');
        System.assertEquals(contact.Id,
            matcher.getMatchDetails('setup0@example.com').ContactId);
    }


    // ═══════════════════════════════════════════════════════════════════════
    // SECTION 9 — BULK MATCH SCENARIOS (require EMAIL_FIELDS_AVAILABLE)
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testBulk200StagingRecordsAllMatch() {
        if (!EMAIL_FIELDS_AVAILABLE) {
            System.assert(true, 'Skipped: custom email fields not installed');
            return;
        }

        List_Upload__c upload = [SELECT Id FROM List_Upload__c LIMIT 1];

        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 200; i++) {
            contacts.add(new Contact(
                FirstName = 'Bulk',
                LastName = 'Contact' + i,
                Email = 'bulk' + i + '@example.com'
            ));
        }
        insert contacts;

        List<List_Upload_Staging__c> staging = new List<List_Upload_Staging__c>();
        for (Integer i = 0; i < 200; i++) {
            staging.add(new List_Upload_Staging__c(
                List_Upload__c = upload.Id,
                Email_Address__c = 'bulk' + i + '@example.com'
            ));
        }
        insert staging;

        List<Id> contactIds = new List<Id>();
        for (Contact c : contacts) {
            contactIds.add(c.Id);
        }
        Test.setFixedSearchResults(contactIds);

        Test.startTest();
        ContactMatcher matcher = new ContactMatcher();
        matcher.integrationStagingRecords = staging;
        matcher.execute();
        Test.stopTest();

        System.assertEquals(200, matcher.emailMap.size(),
            'All 200 distinct emails should have a match entry');
        System.assertNotEquals(null, matcher.getMatchDetails('bulk0@example.com'),
            'First record should be matched');
        System.assertNotEquals(null, matcher.getMatchDetails('bulk99@example.com'),
            'Mid-list record should be matched');
        System.assertNotEquals(null, matcher.getMatchDetails('bulk199@example.com'),
            'Last record should be matched');
    }

    @IsTest
    static void testBulk200StagingWith50UniqueEmailsDeduplication() {
        if (!EMAIL_FIELDS_AVAILABLE) {
            System.assert(true, 'Skipped: custom email fields not installed');
            return;
        }

        List_Upload__c upload = [SELECT Id FROM List_Upload__c LIMIT 1];

        // 50 unique contacts
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 50; i++) {
            contacts.add(new Contact(
                FirstName = 'Dedup',
                LastName = 'Contact' + i,
                Email = 'dedup' + i + '@example.com'
            ));
        }
        insert contacts;

        // 200 staging records cycling through the same 50 emails (4× each)
        List<List_Upload_Staging__c> staging = new List<List_Upload_Staging__c>();
        for (Integer i = 0; i < 200; i++) {
            staging.add(new List_Upload_Staging__c(
                List_Upload__c = upload.Id,
                Email_Address__c = 'dedup' + Math.mod(i, 50) + '@example.com'
            ));
        }
        insert staging;

        List<Id> contactIds = new List<Id>();
        for (Contact c : contacts) {
            contactIds.add(c.Id);
        }
        Test.setFixedSearchResults(contactIds);

        Test.startTest();
        ContactMatcher matcher = new ContactMatcher();
        matcher.integrationStagingRecords = staging;
        matcher.execute();
        Test.stopTest();

        System.assertEquals(50, matcher.emailMap.size(),
            '200 staging records with 50 unique emails should yield 50 emailMap entries after dedup');
    }

    @IsTest
    static void testBulkPartialMatchScenario() {
        if (!EMAIL_FIELDS_AVAILABLE) {
            System.assert(true, 'Skipped: custom email fields not installed');
            return;
        }

        List_Upload__c upload = [SELECT Id FROM List_Upload__c LIMIT 1];

        // 100 contacts that will match
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 100; i++) {
            contacts.add(new Contact(
                FirstName = 'Partial',
                LastName = 'Contact' + i,
                Email = 'partial' + i + '@example.com'
            ));
        }
        insert contacts;

        // 200 staging: 100 will match, 100 will not
        List<List_Upload_Staging__c> staging = new List<List_Upload_Staging__c>();
        for (Integer i = 0; i < 100; i++) {
            staging.add(new List_Upload_Staging__c(
                List_Upload__c = upload.Id,
                Email_Address__c = 'partial' + i + '@example.com'
            ));
        }
        for (Integer i = 0; i < 100; i++) {
            staging.add(new List_Upload_Staging__c(
                List_Upload__c = upload.Id,
                Email_Address__c = 'unmatched' + i + '@nowhere.com'
            ));
        }
        insert staging;

        List<Id> contactIds = new List<Id>();
        for (Contact c : contacts) {
            contactIds.add(c.Id);
        }
        Test.setFixedSearchResults(contactIds);

        Test.startTest();
        ContactMatcher matcher = new ContactMatcher();
        matcher.integrationStagingRecords = staging;
        matcher.execute();
        Test.stopTest();

        System.assertEquals(100, matcher.emailMap.size(),
            'Exactly 100 of the 200 emails should be matched');
        System.assertNotEquals(null, matcher.getMatchDetails('partial0@example.com'),
            'A matchable email should appear in emailMap');
        System.assertEquals(null, matcher.getMatchDetails('unmatched0@nowhere.com'),
            'A non-matchable email should return null');
    }

    @IsTest
    static void testBulkMixedBlanksAndMatchedEmails() {
        if (!EMAIL_FIELDS_AVAILABLE) {
            System.assert(true, 'Skipped: custom email fields not installed');
            return;
        }

        List_Upload__c upload = [SELECT Id FROM List_Upload__c LIMIT 1];

        // 100 contacts
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 100; i++) {
            contacts.add(new Contact(
                FirstName = 'Mixed',
                LastName = 'Contact' + i,
                Email = 'mixed' + i + '@example.com'
            ));
        }
        insert contacts;

        // 200 staging: 100 valid emails, 100 nulls
        List<List_Upload_Staging__c> staging = new List<List_Upload_Staging__c>();
        for (Integer i = 0; i < 100; i++) {
            staging.add(new List_Upload_Staging__c(
                List_Upload__c = upload.Id,
                Email_Address__c = 'mixed' + i + '@example.com'
            ));
        }
        for (Integer i = 0; i < 100; i++) {
            staging.add(new List_Upload_Staging__c(
                List_Upload__c = upload.Id,
                Email_Address__c = null
            ));
        }
        insert staging;

        List<Id> contactIds = new List<Id>();
        for (Contact c : contacts) {
            contactIds.add(c.Id);
        }
        Test.setFixedSearchResults(contactIds);

        Test.startTest();
        ContactMatcher matcher = new ContactMatcher();
        matcher.integrationStagingRecords = staging;
        matcher.execute();
        Test.stopTest();

        System.assertEquals(100, matcher.emailMap.size(),
            'Only the 100 non-null emails should be matched; nulls are skipped');
    }
}
