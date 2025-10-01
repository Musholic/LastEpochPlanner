#!/bin/sh

# Exit if no new value is provided as an argument (should be either "true" or "false").
if [ -z "$1" ]; then
    echo "Usage: $0 <new-value>" >&2
    exit 1
fi

NEW_VALUE=$1
ENDPOINT="repos/Musholic/LastEpochPlanner/rulesets/8548061"

# In a single pipeline:
# 1. Fetch the current ruleset configuration.
# 2. Use jq to safely modify the JSON
# 3. Apply the updated ruleset via a PUT request.
gh api "$ENDPOINT" | \
    jq --argjson val "$NEW_VALUE" '(.rules[] | select(.type == "required_status_checks").parameters.strict_required_status_checks_policy) = $val' | \
    gh api --method PUT "$ENDPOINT" --input -
