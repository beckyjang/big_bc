# big_bc

```
[root@apigateway conf.d]# cat logstash.conf
# Beats -> Logstash -> Elasticsearch pipeline.

input {
  beats {
    port => 5044
  }
}
filter {
  if ([fields][log_type] == "apigw-transaction") {
          grok {
                match => { "message" => "%{DATA:apigw_dummy}\: %{DATA:apigw_request_id}\#@# %{TIMESTAMP_ISO8601:apigw_request_time}\#@# %{DATA:apigw_node_id}\#@# %{DATA:apigw_tenant_name}\#@# %{DATA:apigw_method}\#@# %{URIPATHPARAM:apigw_uri_path}\#@# %{DATA:apigw_service_name}\#@# %{DATA:apigw_api_uuid}\#@# %{DATA:apigw_api_stack_type}\#@# %{DATA:apigw_api_zone}\#@# %{IP:apigw_remote_ip}\#@# %{DATA:apigw_auth_type}\#@# %{DATA:apigw_api_key}\#@# %{DATA:apigw_application_uuid}\#@# %{DATA:apigw_application_name}\#@# %{DATA:apigw_organization_uuid}\#@# %{DATA:apigw_organization_name}\#@# %{DATA:apigw_subscriber_id}\#@# %{DATA:apigw_command}\#@# %{DATA:apigw_block_userid}\#@# %{DATA:apigw_api_location}\#@# %{DATA:apigw_app_user_id}\#@# %{DATA:apigw_app_user_type}\#@# %{NUMBER:apigw_elapsed_time:int}\#@# %{NUMBER:apigw_routing_total_time:int}\#@# %{DATA:apigw_response_code}\#@# %{DATA:apigw_is_request_completed}\#@# %{DATA:apigw_is_request_authorized}\#@# %{DATA:apigw_is_success}\#@# %{DATA:apigw_is_failure}\#@# %{DATA:apigw_temp_data_1}\#@# %{DATA:apigw_temp_data_2}\#@# %{DATA:apigw_temp_data_3}\#@# %{DATA:apigw_error_code}\#@# %{GREEDYDATA:apigw_error_msg}" }
          }
  }
  else if ([fields][log_type] == "apigw-audit") {
          if (  "Assertion Falsified (600)" in [message] or
                "session/cookie not found" in [message]
          )
          {
                drop{}
          }
          else {
                grok {
                    match => { "message" => "%{TIMESTAMP_ISO8601:timestamp} %{WORD:loglevel} %{NUMBER:dummy} %{DATA:loggername} %{DATA:dummy} %{GREEDYDATA:auditdetail}" }
                }
          }
  }
}
output {
    elasticsearch {
        hosts => "https://localhost:9200"
        index => "%{[@metadata][beat]}_%{[fields][log_type]}_%{+YYYY.MM.dd}"
        user => elastic
        password => elastic
        ssl_verification_mode => none
    }
}

```
