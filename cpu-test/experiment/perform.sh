#!/bin/bash

function push_dora {
  dora_name=$1
  pushd ../../assets/dora/
    cf push $dora_name --no-start -b ruby_buildpack 
    cf curl /v2/apps/$(cf app $dora_name --guid) -X PUT -d '{"diego":true}'
    cf start $dora_name
  popd
}

function collect_metrics {
  instances=$1
  start=$2

  result_directory=results/$instances
  result_line="$instances"

  echo "Collecting Metrics for $instances instances of the cpu-app."

  mkdir -p $result_directory 
  ab -c 100 -n 10000 http://cpu-test-dora.diego-1.cf-app.com/ > $result_directory/ab.out
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

  rm -rf $result_directory/logs

  result_line="$result_line,$(grep 'Duration' $result_directory/cicerone.out | cut -d':' -f2 | cut -d' ' -f2 | xargs -n 4 | sed 's/ /,/g')"

  echo $result_line >> results/results.csv
}

echo "Running CPU Performance Test"

PASSWORD=$1

if [ -z $PASSWORD ]; then
  echo "Usage: ./perform.sh <CC_ADMIN_PASSWORD>"
  exit 1
fi

# Target Diego 1
cf api api.diego-1.cf-app.com --skip-ssl-validation
cf auth admin $PASSWORD

# Create Experiment Org and Space
cf create-org cpu-test-org
cf create-space cpu-test-space -o cpu-test-org
cf target -o cpu-test-org -s cpu-test-space

# Push One Instance of Dora
push_dora cpu-test-dora

# Push One Instance of the CPU Application
pushd ../cpu-app/
cf push cpu-app --no-start -b go_buildpack -m 64M -k 64M --no-route
cf curl /v2/apps/$(cf app cpu-app --guid) -X PUT -d '{"diego":true,"health_check_type":"none"}'
cf set-env cpu-app FIB_NUM 40
cf start cpu-app
popd

mkdir -p results/
echo "CPU_INSTANCES,AB_THROUGHPUT,AB_THROUGHPUT_UNIT,PUSH_1_TIME,PUSH_2_TIME,PUSH_3_TIME,PUSH_4_TIME,PUSH_5_TIME,AVG_BULK_SYNC_DURATION,AVG_AUCTION_FETCHING_DURATION,AVG_AUCTION_PERFORMING_DURATION,AVG_FETCHING_CONTAINER_METRICS_DURATION" > results/results.csv

for i in 1 10 20 40 80 100; do
  # Scale the Application to I instances
  cf scale cpu-app -i $i
  start_timestamp=`date +%s`

  # Allow Applications to Start/Settle
  sleep 300

  collect_metrics $i $start_timestamp
done

# Cleanup Test Org and Space
cf delete-org -f cpu-test-org
