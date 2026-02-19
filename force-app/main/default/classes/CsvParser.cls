/**
 * Created by peter on 2/12/2026.
 */

public with sharing class CsvParser {

    public FileParser fileParser;


    // PUBLIC

    @InvocableMethod(Label='Parse CSV File')
    public static FlowOutput[] parseCSVFile(List<FlowInput> params) {
        FlowOutput[] results = new List<FlowOutput>();
        for (FlowInput param : params) {
            FlowOutput flowOutputTemp = new FlowOutput();
            try {
                CsvParser csvParser = new CsvParser();
                csvParser.fileParser = new CsvParser.FileParser();
                csvParser.fileParser.execute(param.contentDocId, CsvColumnMapping.buildFieldMapJSON(param.columnHeadings));
                flowOutputTemp.newRecords = csvParser.fileParser.soRecords;
                for (List_Upload_Staging__c intsLoop : flowOutputTemp.newRecords) {
                    intsLoop.List_Upload__c = param.batchId;
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

    public class FileParser {
        public List<List_Upload_Staging__c> soRecords;
        public List<CSV_Column_Mapping__mdt> keyMappingRecords;
        public String sError;
        public String dataToParse;


        public void execute(String contentId, String columnHeadings) {
            try {
                Map<String, Object> args = new Map<String, Object>();
                args.put('records', getContentData(contentId));
                args.put('mapping', columnHeadings);
                System.debug(columnHeadings);
                DataWeave.Script script = DataWeave.Script.createScript('csvToCustomObject');
                DataWeave.Result dwresult = script.execute(args);
                System.debug('dwresult' + dwresult.getValue());
                soRecords = (List<List_Upload_Staging__c>) dwresult.getValue();
                //Check for dupes

            } catch (Exception e) {
                sError = e.getMessage();
            }
        }


        private String getContentData(Id contentId) {
            if (dataToParse == null) {
                ContentVersion cv = [SELECT Id,
                                            VersionData
                                     FROM ContentVersion
                                     WHERE ContentDocumentId = :contentId
                                       AND IsLatest = TRUE
                                     WITH USER_MODE];
                dataToParse = cv.VersionData.toString();
            }
            return dataToParse;
        }
    }


    public class FlowInput {
        @InvocableVariable
        public String contentDocId;

        @InvocableVariable
        public List<CsvColumnMapping> columnHeadings;

        @InvocableVariable
        public String batchId;
    }


    public class FlowOutput {
        @InvocableVariable
        public String sError;

        @InvocableVariable
        public List<List_Upload_Staging__c> newRecords;
    }
}