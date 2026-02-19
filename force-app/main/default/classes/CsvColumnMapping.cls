/**
 * Created by peter on 2/12/2026.
 */

public with sharing class CsvColumnMapping {

    @AuraEnabled
    public String ColumnHeading;

    @AuraEnabled
    public String TargetFieldName;


    // CONSTRUCTOR

    public CsvColumnMapping(String col, String field) {
        ColumnHeading = col;
        TargetFieldName = field;
    }


    // PUBLIC

    public static String buildFieldMapJSON(List<CsvColumnMapping> columnHeadings) {
        Map<String, String> fieldMap = new Map<String, String>();
        for (CsvColumnMapping colLoop : columnHeadings) {
            fieldMap.put(colLoop.ColumnHeading, colLoop.TargetFieldName);
        }
        return JSON.serialize(fieldMap);
    }


    @InvocableMethod(Label='Get CSV Column Headings')
    public static FlowOutput[] parseMetaData(List<FlowInput> params) {
        FlowOutput[] results = new List<FlowOutput>();
        for (FlowInput param : params) {
            FlowOutput flowOutputTemp = new FlowOutput();
            try {
                flowOutputTemp.columnHeadings = new List<CsvColumnMapping>();
                for (CSV_Column_Mapping__mdt cmdLoop : [SELECT DeveloperName,
                                                               Column_Heading__c,
                                                               Target_Field__r.QualifiedApiName
                                                        FROM CSV_Column_Mapping__mdt
                                                        WITH USER_MODE]) {
                    flowOutputTemp.columnHeadings.add(new CsvColumnMapping(cmdLoop.Column_Heading__c, cmdLoop.Target_Field__r.QualifiedApiName));
                }
            }
            catch (Exception e) {
                flowOutputTemp.sError = e.getMessage();
            }
            results.add(flowOutputTemp);
        }
        return results;
    }


    // INNER

    public class FlowInput {
        @InvocableVariable
        public List<CSV_Column_Mapping__mdt> keyMappingCMD;
    }


    public class FlowOutput {
        @InvocableVariable
        public List<CsvColumnMapping> columnHeadings;

        @InvocableVariable
        public String sError;
    }
}
