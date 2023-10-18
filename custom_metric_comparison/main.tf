############
### Main ###
############

terraform {
  required_providers {
    newrelic = {
      source  = "newrelic/newrelic"
      version = ">=3.27.2"
    }
  }
}

# Configure the NR Provider
provider "newrelic" {
  account_id = var.NEW_RELIC_ACCOUNT_ID
  api_key    = var.NEW_RELIC_API_KEY
  region     = var.NEW_RELIC_REGION
}

#################
### Variables ###
#################

# New Relic account ID
variable "NEW_RELIC_ACCOUNT_ID" {
  type = string
}

# New Relic API key
variable "NEW_RELIC_API_KEY" {
  type = string
}

# New Relic region
variable "NEW_RELIC_REGION" {
  type = string
}

# New Relic license key
variable "NEW_RELIC_LICENSE_KEY" {
  type = string
}

# Synthetic monitor name
variable "synthethic_monitor_name" {
  type = string
}

# Synthetic monitor public locations
variable "synthethic_monitor_public_locations" {
  type = list(string)
}

# Synthetic monitor period
variable "synthethic_monitor_period" {
  type = string
}

# Custom comparison event name
variable "custom_comparison_event_name" {
  type = string
}

# NRQL query for retrieving metric 1
variable "query_metric_1" {
  type = string
}

# NRQL query for retrieving metric 2
variable "query_metric_2" {
  type = string
}
######

##########################
### Secure credentials ###
##########################

# New Relic account ID
resource "newrelic_synthetics_secure_credential" "account_id" {
  key         = "NEW_RELIC_ACCOUNT_ID"
  value       = var.NEW_RELIC_ACCOUNT_ID
  description = "New Relic account ID to which the custom events will be ingested."
}

# New Relic API key
resource "newrelic_synthetics_secure_credential" "api_key" {
  key         = "NEW_RELIC_API_KEY"
  value       = var.NEW_RELIC_API_KEY
  description = "New Relic API key with which the metrics will be queried."
}

# New Relic license key
resource "newrelic_synthetics_secure_credential" "license_key" {
  key         = "NEW_RELIC_LICENSE_KEY"
  value       = var.NEW_RELIC_LICENSE_KEY
  description = "New Relic license key for ingesting custom events into New Relic."
}
######

########################
### Synthetic script ###
########################

# Script to compare given metrics
resource "newrelic_synthetics_script_monitor" "monitor" {
  status           = "ENABLED"
  name             = var.synthethic_monitor_name
  type             = "SCRIPT_API"
  locations_public = var.synthethic_monitor_public_locations
  period           = var.synthethic_monitor_period

  script = <<EOF
  let assert = require("assert");

  const NEWRELIC_GRAPHQL_ENDPOINT =
    $secure.NEWRELIC_LICENSE_KEY.substring(0, 2) === "eu"
      ? "https://api.eu.newrelic.com/graphql"
      : "https://api.newrelic.com/graphql";

  const CUSTOM_COMPARISON_EVENT_NAME =
    "${var.custom_comparison_event_name}";

  const NEWRELIC_EVENTS_ENDPOINT =
    $secure.NEWRELIC_LICENSE_KEY.substring(0, 2) === "eu"
      ? `https://insights-collector.eu01.nr-data.net/v1/accounts/$${$secure.NEWRELIC_ACCOUNT_ID}/events`
      : `https://insights-collector.nr-data.net/v1/accounts/$${$secure.NEWRELIC_ACCOUNT_ID}/events`;

  /**
  * Makes an HTTP POST request.
  * @param {object} options
  * @returns {object[]} Response body
  */
  const makeHttpPostRequest = async function (options) {
    let responseBody;

    await $http.post(options, function (err, res, body) {
      console.log(`Status code: $${res.statusCode}`);
      if (err) {
        assert.fail(`Post request has failed: $${err}`);
      } else {
        if (res.statusCode == 200) {
          console.log("Post request is performed successfully.");
          responseBody = res.body;
        } else {
          console.log("Post request returned not OK result.");
          console.log(res.body);
          assert.fail("Failed.");
        }
      }
    });

    return JSON.parse(responseBody);
  };

  /**
  * Makes request to GraphQL endpoint and returns NRQL query result
  * @param {string} graphqlQueryBody Body of the GraphQL query
  * @returns {object} NRQL query result
  */
  const makeGraphQlNrqlRequest = async function (graphqlQueryBody) {
    const options = {
      url: NEWRELIC_GRAPHQL_ENDPOINT,
      headers: {
        "Content-Type": "application/json",
        "Api-Key": $secure.NEWRELIC_USER_API_KEY,
      },
      body: JSON.stringify(graphqlQueryBody),
    };

    const responseBody = await makeHttpPostRequest(options);
    return responseBody["data"]["actor"]["nrql"]["results"];
  };

  /**
  * Prepares GraphQl query for retrieving the metric
  * @param {string} query NRQL Query
  * @returns GraphQL query body
  */
  const createGraphqlQueryBody = function (query) {
    return {
      query: `{
          actor {
            nrql(
              accounts: $${$secure.NEWRELIC_ACCOUNT_ID},
              query: "$${query}"
            ) {
              results
            }
          }
        }`,
    };
  };

  /**
  * Gets the metric value per the given query
  * @param {string} query NRQL query
  * @returns {number} Value of the requested metric
  */
  const getMetric = async function (query) {
    const graphqlQuery = createGraphqlQueryBody();
    const results = await makeGraphQlNrqlRequest(graphqlQuery);
    console.log(results);
    return results[0]["result"];
  };

  /**
  * Flushes the created custom events to New Relic events endpoint.
  * @param {object[]} customEvents
  */
  const flushCustomComparisonEvent = async function (customEvents) {
    let options = {
      url: NEWRELIC_EVENTS_ENDPOINT,
      headers: {
        "Content-Type": "application/json",
        "Api-Key": $secure.NEWRELIC_LICENSE_KEY,
      },
      body: JSON.stringify(customEvents),
    };

    await makeHttpPostRequest(options);
  };

  /**
  * Creates custom event with the metric values as attributes
  * @param {number} metric1
  * @param {number} metric2
  */
  const createCustomMetricComparisonEvent = async function (metric1, metric2) {
    let customComparisonEvents = [];

    customComparisonEvents.push({
      eventType: CUSTOM_COMPARISON_EVENT_NAME,
      metric1: metric1,
      metric2: metric2,
      differenceInPercent: ((metric1 - metric2) / metric1) * 100.0,
    });

    await flushCustomComparisonEvent(customComparisonEvents);
  };

  // -------------------- //
  // --- SCRIPT START --- //
  // -------------------- //
  try {
    // Get metric 1
    const metric1 = await getMetric(${var.query_metric_1});

    // Get metric 2
    const metric2 = await getMetric(${var.query_metric_2});

    // Create custom comparison event
    await createCustomMetricComparisonEvent(metric1, metric2);
  } catch (e) {
    console.log("Unexpected errors occured: ", e);
    assert.fail("Failed.");
  }
  // -------------------- //
  EOF

  script_language      = "JAVASCRIPT"
  runtime_type         = "NODE_API"
  runtime_type_version = "16.10"
}
######
