/**
 * Created by peter on 2/12/2026.
 */

public with sharing class ContactMatcher {

    public Map<String, emailMatchDetails> emailMap;
    public List<List_Upload_Staging__c> integrationStagingRecords;
    List<String> emailAddressUnique;


    // CONSTRUCTOR

    public ContactMatcher() {
        emailAddressUnique = new List<String>();
        emailMap = new Map<String, emailMatchDetails>();
    }


    // PUBLIC

    public emailMatchDetails getMatchDetails(String EmailAddress) {
        return emailMap.get(EmailAddress);
    }


    public void execute() {
        //Build List of Emails
        for (List_Upload_Staging__c stageLoop : integrationStagingRecords) {
            if (String.isNotBlank(stageLoop.Email_Address__c)) {
                if (emailAddressUnique.contains(stageLoop.Email_Address__c) == false) {
                    emailAddressUnique.add(stageLoop.Email_Address__c);
                }
            }
        }

        //npe01__AlternateEmail__c,npe01__HomeEmail__c,npe01__WorkEmail__c,Additional_E_mail_2__c
        //,Assistant_Email__c
        System.debug('emailAddressUnique' + emailAddressUnique);
        String email1 = String.join(emailAddressUnique, ' OR ');
        System.debug('email1' + email1);
        List<List<SObject>> searchList = [FIND :email1
                                          IN EMAIL FIELDS
                                          RETURNING Contact(Email, Id, LastName)
                                          WITH USER_MODE];
        Contact[] contacts = (List<Contact>) searchList[0];
        List<String> EmailFieldList = new List<String>{
                'Email'
        };
        for (Contact c : contacts) {
            for (String sField : EmailFieldList) {
                if (c.get(sField) != null && emailMap.containsKey((String) c.get(sField)) == false) {
                    emailMap.put((String) c.get(sField), new emailMatchDetails(c, sField));
                }
            }
        }
    }


    // INNER

    public class emailMatchDetails {
        public Id ContactId;
        public String EmailField;

        public emailMatchDetails(Contact con, String EmailField) {
            ContactId = con.Id;
            this.EmailField = EmailField;
        }
    }
}