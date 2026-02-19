---
paths:
  - "**/*.cls"
  - "**/*.trigger"
  - "**/*-meta.xml"
  - "force-app/**"
  - "unpackaged/**"
---

# Salesforce / Apex Coding Standards

**MANDATORY: After creating or modifying any `.cls`, `.trigger`, or `*-meta.xml` file, run `/sf-code-analyzer` on the changed files before considering the task done.**

## Core Principles

These principles are non-negotiable. Many are enforced by PMD rules.

### One Return Per Method

Methods have exactly one `return` statement at the end. Use the `result` variable pattern:

```java
private List<Account> findAccounts(String name) {
    List<Account> result = new List<Account>();

    for(Account acc : accounts) {
        if(acc.Name.contains(name)) {
            result.add(acc);
        }
    }

    return result;
}
```

### No Forbidden Suffixes

Never use: `Service`, `Handler`, `Manager`, `Helper`, `Util`, `Wrapper`

These names hide intent. Use domain names that reveal what the class represents.

### No Formal Comments
No JavaDoc/ApexDoc `/** */` comments. If code needs explanation, the code is unclear. Write clearer code. Write better tests.

### Tests Don't Start With "test"
Test method names describe behavior. Class + method reads as sentence:

- `Calculator_Test.multipliesTwoIntegers()` → "Calculator multiplies two integers"

### Test Method Names Describe What Is Asserted

The method name states exactly what the test verifies. The assertion should match the name - nothing more, nothing less:

- Good: `returnsOverdueTasksFirst()` with `Assert.areEqual('Overdue Task', tasks[0].Name)`
- Bad: `testPrioritization()` with multiple unrelated assertions

### Deviations Need Explanation

When you deviate from defaults (`without sharing`, `global`, PMD suppression), add a `// Note:` comment explaining why.

## Project Structure

```
force-app/
└── main/default/
    └── classes/                       # ALL your classes go here (flat structure)
```

Keep all classes together. Tests next to their subjects. No sub-packages.

## Coding Patterns

### Class Structure

Organize with ALL-CAPS section comments. Double blank lines between methods:

```java
public with sharing class ClassName {

    private static final String CONSTANT = 'value';

    private String field;


    // CONSTRUCTOR

    public ClassName() {
        // initialization
    }


    // PUBLIC

    public String process() {
        String result = doWork();

        return result;
    }


    // PRIVATE

    private String doWork() {
        String result = 'processed';

        return result;
    }


    // INNER

    public class InnerClass {
        public String value;
    }
}
```

### Test Structure

Three section comments only: `// Setup`, `// Exercise`, `// Verify`. No other comments in tests. Blank line before each section. Double blank lines between test methods:

```java
@IsTest
private class ClassName_Test {


    @IsTest
    private static void returnsExpectedValue() {

        // Setup
        Account acc = (Account) new Account_t().name('Acme').persist();


        // Exercise
        String actual = MyClass.process(acc);


        // Verify
        Assert.areEqual('expected', actual);
    }


    @IsTest
    private static void throwsExceptionForInvalidInput() {

        // Setup
        ...


        // Exercise
        ...


        // Verify
        ...
    }


    // HELPER

    private static Input createInput() {
        Input result = new Input();
        result.value = 'test';

        return result;
    }
}
```

### No Assertion Messages
Assertions have no message parameter. The test method name explains what is being verified:

- Good: `Assert.areEqual('expected', actual)`
- Bad: `Assert.areEqual('expected', actual, 'Should return expected value')`

### Method Chaining Alignment

Indent to align visually:

```java
String response = new PromptTemplate('ExtractTasks')
                            .call(new Map<String, Object>{
                                'Input:notes' => notes
                            });
```

### SOQL Formatting

Long queries: each field on its own line, aligned:

```java
List<Project__c> projects = [SELECT Id, Name,
                                    Status__c,
                                    StartDate__c,
                                    (SELECT Id, Name,
                                            OwnerId, Owner.Name
                                    FROM Tasks__r)
                            FROM Project__c
                            WHERE Id = :projectId
                            WITH USER_MODE];
```

### Invocable Actions

```java
// Note: Agentforce requires global
@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class VerbNounAction {

    @InvocableMethod(label='Action Label' description='What it does')
    global static List<Output> execute(List<Input> inputs) {
        Output output = new Output();
        // ... implementation ...

        return new List<Output>{ output };
    }


    // INNER

    global class Input {
        @InvocableVariable(label='Field Label' description='Description' required=true)
        global String fieldName;

        // Note: Empty constructor required for Invocable Methods deserialization
        @SuppressWarnings('PMD.EmptyStatementBlock')
        global Input() {}
    }


    global class Output {
        @InvocableVariable(label='Result' description='Description')
        global String result;
    }
}
```

## Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Custom Objects | PascalCase, no underscores | `ContactSkill__c` |
| Custom Fields | camelCase, no underscores | `skillLevel__c` |
| Triggers | Plural object name | `Contacts.trigger` |
| Test Classes | `_Test` suffix | `Pricing_Test.cls` |
| Controllers | `Ctrl` suffix | `AccountListCtrl` |
| Domain Builders (standard) | `_t` suffix | `Account_t`, `User_t` |
| Domain Builders (custom) | No suffix | `Project`, `Task` |

### Methods

No `get` prefix:

- Bad: `getAge()`, `getName()`
- Good: `age()`, `name()`

## Access Modifiers

| Type | Access | Sharing |
|------|--------|---------|
| Regular class | `public` | `with sharing` |
| Test class | `private` | - |
| Invocable | `global` | `with sharing` |
| Controller | `public` | `with sharing` |

## PMD Rules

A custom PMD ruleset (`pmd-ruleset.xml`) enforces many patterns. These rules are machine-checked:

- **OnlyOneReturnPerMethod** - Methods must have exactly one return statement
- **DeclareWhatYouReturnFirstAndCallItResult** - Return variable must be named `result`
- **TestsShouldNotStartWithTest** - Test method names must not start with "test"
- **UnneededUseOfThisReducesReadability** - Don't use `this.` unless required
- **CommentsOftenExcuseForBadCodeAndTests** - No formal JavaDoc/ApexDoc comments
- **PreferRealObjectsOverStaticHelpers** - Avoid classes with only static methods
- **CheckIfProperFalsePositive** - PMD suppressions need explanatory comments
- **MetadataRequiresDescription** - Custom objects/fields need descriptions
- **NullValueCheckBeforeEmptyCheck** - Check `!= null` before `.isEmpty()`

## What NOT to Do

- No formal JavaDoc/ApexDoc `/** */` comments
- No `this.` prefix unless required for disambiguation
- No multiple returns per method
- No test methods starting with "test"
- No underscores in class names except `_Test` and `_t`
- No `@TestSetup` unless absolutely necessary
- No shared/global test variables
- No storing credentials in Custom Settings or Metadata
- No `Service`, `Handler`, `Manager`, `Helper`, `Util` suffixes

## Development Process

### Phase 1: Environment Setup & Requirements Gathering

1. **Propose Development Environment** - Suggest scratch org creation using `sf org create scratch`
2. **Understand Requirements** - Ask specific questions, request SOW or contract details, clarify domain and priorities

### Phase 2: Solution Planning

1. **Read and Analyze** - Study existing patterns before proposing solutions
2. **Design Solution** - Follow established patterns, plan complete features including tests

### Phase 3: Iterative Implementation

1. **Build Core Components** - Follow coding standards, place code in `force-app/main/default/classes/`
2. **Create Tests** - Cover business logic, edge cases, error handling
3. **Scan** - After modifying `.cls`, `.trigger`, or `*-meta.xml` files, run `/sf-code-analyzer` on the changed files before considering the task done
4. **Test and Deploy** - Run tests with Salesforce CLI, deploy, validate
5. **Iterate** - Gather feedback, refine while maintaining standards