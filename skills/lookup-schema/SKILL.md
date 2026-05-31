---
name: lookup-schema
description: >
  Look up Copilot Studio YAML schema definitions. Use when the user asks about schema structure,
  element properties, or how to use a specific YAML kind.
---
# Lookup Schema Definition

Look up and explain a Copilot Studio YAML schema definition.

## Instructions

1. Run the schema lookup script to find the definition:
   ```bash
   node ../../scripts/schema-lookup.bundle.js lookup $ARGUMENTS
   ```

2. If the definition is not found, search for similar definitions:
   ```bash
   node ../../scripts/schema-lookup.bundle.js search $ARGUMENTS
   ```

3. If the definition contains `$ref` references that need resolution, use:
   ```bash
   node ../../scripts/schema-lookup.bundle.js resolve $ARGUMENTS
   ```

4. Present the schema definition in a readable format, explaining:
   - What the element does (from the description)
   - Required properties
   - Optional properties and their types
   - Any related definitions that might be useful

## Example

User: `/lookup-schema SendActivity`

Response should include the full schema definition and explain how to use it in YAML.
