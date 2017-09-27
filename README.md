# Core Github reporting
Gather stats from our Github Project! Because github don't provide API access to
the events for each card on a project (i.e. when it moved into each column, who
moved it), this script needs to be run _daily_.

## What does it collect?
This script will produce a CSV file with the following data:

Column | Description
--- | ---
ID | The github assigned card ID
Card | Title of the Issue/Pull Reqest/Note
Issue |	Link to the Issue/Pull Request (if applicable)
Sum Value	| Always 1. Used for reporting graps 
Start Date | Date the card was moved to `DOING_COLUMN_NAME`
Completed Date	| Date the card was moved to `DONE_COLUMN_NAME`
Cycle Time	| Time (in days) between Start Date and Completed Date
Labels	| A string of space-seperated labels attached to the Issue
{COLUMN_NAME}	| A count of days that the card spent in this column

Most of this information will be collected when the card is moved into the `DONE_COLUMN_NAME` column, to avoid
re-computation every day.

## How to run
This easiest way to run this generator is to use Docker. You'll need to fill out
the following environment variables in the `docker-compose.yml` file:

```
  GIT_ACCESS_TOKEN: # Personal Access Token generated in github. This needs 'repo' and 'read:org' permissions
  PROJECT_NAME: "Core" # must be within the 'greensync' org
  DOING_COLUMN_NAME: "Developing" # when a card enters this column it's marked as 'started'
  DONE_COLUMN_NAME: "Done" # when a card enters this column it's marked as 'done'
  DEBUG: # setting this to 'true' will give you detailed info about the calls being made to the github API
  IGNORED_COLUMNS: "Backlog, Something"
```

Then you can run `script/report` to run the report
