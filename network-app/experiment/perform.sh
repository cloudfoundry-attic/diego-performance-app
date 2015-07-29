#!/bin/bash

function push_dora {
  dora_name=$1
  pushd dora/
    cf push $dora_name --no-start -b ruby_buildpack 
    cf curl /v2/apps/$(cf app $dora_name --guid) -X PUT -d '{"diego":true}'
    cf start $dora_name
  popd
}

function collect_metrics {
  instances=$1
  response_size=$2
  start=$3

  result_directory=results/$instances-$response_size
  result_line="$instances,$response_size"

  echo "Collecting Metrics for $instances instances of the download-app and $response_size MB response size."

  mkdir -p $result_directory 
  ab -c 100 -n 10000 http://network-test-dora.diego-1.cf-app.com/ > $result_directory/ab.out
  result_line="$result_line,$(grep "Transfer rate" $result_directory/ab.out  | awk '{ print $3 "," $4}')"

  for k in `seq 1 5`; do
    result_line="$result_line,$({ time push_dora example-push-dora; } 2>&1| grep real | awk '{ print $2 }')"
    cf d -f example-push-dora
  done

  end=`date +%s`

  mkdir -p $result_directory/logs
  bosh logs --job cell_z1 0 --dir $result_directory/logs

  pushd $result_directory/logs
  tar xvf cell_z1*.tgz
  popd

  cicerone analyze-cell-performance $result_directory/logs/rep/rep.stdout.log $start $end > $result_directory/cicerone.out
  result_line="$result_line,$(grep 'Duration' $result_directory/cicerone.out | cut -d':' -f2 | cut -d' ' -f2 | xargs -n 4 | sed 's/ /,/g')"

  echo $result_line >> results/results.csv
}

echo "Running Network Performance Test"

PASSWORD=$1

if [ -z $PASSWORD ]; then
  echo "Usage: ./perform.sh <CC_ADMIN_PASSWORD>"
  exit 1
fi

# Target Diego 1
cf api api.diego-1.cf-app.com --skip-ssl-validation
cf auth admin $PASSWORD

# Create Experiment Org and Space
cf create-org network-test-org
cf create-space network-test-space -o network-test-org
cf target -o network-test-org -s network-test-space

# Push One Instance of Dora
push_dora network-test-dora

# Push One Instance of the Upload Application
pushd ../upload-app/
cf push upload-app --no-start -b go_buildpack -m 64M -k 64M -i 10
cf curl /v2/apps/$(cf app upload-app --guid) -X PUT -d '{"diego":true}'
cf set-env upload-app RESPONSE_SIZE_IN_MB 1
cf start upload-app
popd

# Push One Instance of the Download Application
pushd ../download-app/
cf push download-app --no-start -b go_buildpack -m 64M -k 64M
cf curl /v2/apps/$(cf app download-app --guid) -X PUT -d '{"diego":true}'
cf set-env download-app DOWNLOAD_LOCATION http://upload-app.diego-1.cf-app.com
cf start download-app
popd

mkdir -p results/
echo "DOWNLOAD_INSTANCES,RESPONSE_SIZE_IN_MB,AB_THROUGHPUT,AB_THROUGHPUT_UNIT,PUSH_1_TIME,PUSH_2_TIME,PUSH_3_TIME,PUSH_4_TIME,PUSH_5_TIME,AVG_BULK_SYNC_DURATION,AVG_AUCTION_FETCHING_DURATION,AVG_AUCTION_PERFORMING_DURATION,AVG_FETCHING_CONTAINER_METRICS_DURATION" > results/results.csv

for i in 10 20 40 80 100; do
  # Scale the Application to I instances
  cf scale download-app -i $i
  for j in 1 10 50; do
    cf set-env upload-app RESPONSE_SIZE_IN_MB $j 
    cf restart upload-app

    start_timestamp=`date +%s`

    # Allow Applications to Start/Settle
    sleep 300

    collect_metrics $i $j $start_timestamp
  done
done

# Cleanup Test Org and Space
cf delete-org -f network-test-org
