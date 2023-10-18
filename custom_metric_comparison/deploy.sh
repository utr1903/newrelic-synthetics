#!/bin/bash

# Get commandline arguments
while (( "$#" )); do
  case "$1" in
    --destroy)
      flagDestroy="true"
      shift
      ;;
    --dry-run)
      flagDryRun="true"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

### Set variables

# cluster name
if [[ $flagDestroy != "true" ]]; then

  # Initialize Terraform
  terraform init

  # Plan Terraform
  terraform plan \
    -var NEW_RELIC_ACCOUNT_ID=$NEWRELIC_ACCOUNT_ID \
    -var NEW_RELIC_API_KEY=$NEWRELIC_API_KEY \
    -var NEW_RELIC_REGION=$NEWRELIC_REGION \
    -var NEW_RELIC_LICENSE_KEY=$NEWRELIC_LICENSE_KEY \
    -var synthethic_monitor_name="TEST" \
    -var='synthethic_monitor_public_locations=["AWS_EU_WEST_1","AWS_EU_CENTRAL_1"]' \
    -var synthethic_monitor_period="EVERY_10_MINUTES" \
    -var custom_comparison_event_name="MyCustomComparisonEvent" \
    -var query_metric_1="query_metric_1" \
    -var query_metric_2="query_metric_2" \
    -out "./tfplan"

  # Apply Terraform
  if [[ $flagDryRun != "true" ]]; then
    terraform apply tfplan
  fi
else

  # Destroy Terraform
  terraform destroy \
    -var NEW_RELIC_ACCOUNT_ID=$NEWRELIC_ACCOUNT_ID \
    -var NEW_RELIC_API_KEY=$NEWRELIC_API_KEY \
    -var NEW_RELIC_REGION=$NEWRELIC_REGION \
    -var NEW_RELIC_LICENSE_KEY=$NEWRELIC_LICENSE_KEY \
    -var synthethic_monitor_name="TEST" \
    -var='synthethic_monitor_public_locations=["AWS_EU_WEST_1","AWS_EU_CENTRAL_1"]' \
    -var synthethic_monitor_period="EVERY_10_MINUTES" \
    -var custom_comparison_event_name="MyCustomComparisonEvent" \
    -var query_metric_1="query_metric_1" \
    -var query_metric_2="query_metric_2"
fi