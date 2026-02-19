# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Testing
```bash
npm run test:unit           # Run LWC Jest unit tests
npm run test:unit:watch     # Watch mode
npm run test:unit:debug     # Debug mode
npm run test:unit:coverage  # With coverage report
```

### Linting & Formatting
```bash
npm run lint               # ESLint on Aura and LWC JS files
npm run prettier           # Format all supported files
npm run prettier:verify    # Check formatting without modifying files
```

### Salesforce CLI (sf)
```bash
sf org create scratch -f config/project-scratch-def.json -a MyOrg  # Create scratch org
sf project deploy start -o MyOrg                                     # Deploy to org
sf project retrieve start -o MyOrg                                   # Retrieve from org
sf apex run test -o MyOrg                                            # Run Apex tests in org
```

## Architecture

This is a **Salesforce DX project** (API version 65.0) implementing a CSV bulk contact upload and matching system. All source lives under `force-app/main/default/`.

### Data Flow
```
CSV File Upload → Column Mapping (CMT) → DataWeave Transform → Staging Records → Contact Matcher → Processing Status
```

The entire orchestration is done via **Salesforce Flows**, which invoke the three Apex classes through `@InvocableMethod` entry points. No direct Apex triggers or callouts are used.

### Apex Classes (`classes/`)

- **`listupload_ColumnMapping`** — Queries `CSV_Column_Mapping__mdt` custom metadata and builds a JSON field-mapping object passed to DataWeave. Entry point: `parseMetaData` (invocable).
- **`listupload_CSVParser`** — Retrieves CSV file content from `ContentVersion`, calls the DataWeave script with the field mapping, and bulk-inserts `List_Upload_Staging__c` records. Entry point: `parseCSVFile` (invocable).
- **`listupload_ContactMatcher`** — Runs SOSL across 6 email fields (`Email`, `HomeEmail`, `WorkEmail`, `AlternateEmail`, `AssistantEmail`, `Additional_E_mail_2__c`) on `Contact` to match staging records and writes back `Matched_Contact__c` and `Field_Email_Matched_On__c`. Entry point is invocable.

### DataWeave (`dw/`)

- **`csvToCustomObject.dwl`** — Transforms CSV rows into `List_Upload_Staging__c` Apex objects. Receives CSV records plus the JSON column-mapping object produced by `listupload_ColumnMapping`.

### Custom Objects

| Object | Purpose |
|---|---|
| `List_Upload__c` | Parent batch/session record for each upload |
| `List_Upload_Staging__c` | Child staging records (auto-number `LUS-{000000}`); holds parsed CSV data, match results, `Processing_Status__c`, and `Error_Message__c` |
| `CSV_Column_Mapping__mdt` | Custom metadata type storing CSV header → Salesforce field mappings; pre-seeded records: Email, FirstName, LastName, Organization |

### Key Configuration

- **`sfdx-project.json`** — Source directory is `force-app`, no namespace, login URL is production (`login.salesforce.com`).
- **`config/project-scratch-def.json`** — Scratch org definition for local development.
- **`eslint.config.js`** — ESLint scoped to `**/{aura,lwc}/**/*.js` with Salesforce LWC rules.
- **`jest.config.js`** — Uses `@salesforce/sfdx-lwc-jest` preset.
- Pre-commit hooks (Husky + lint-staged) run linting and formatting checks automatically.
