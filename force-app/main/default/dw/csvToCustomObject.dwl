%dw 2.0
%dw 2.0
input mapping application/json
input records application/csv
output application/apex
---
records map(record) -> (
   record mapObject (value, key, index) -> (
           ((mapping[key]): value) if mapping[key] != null)
   )
   as Object {class: "List_Upload_Staging__c"}
