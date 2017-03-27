#!/bin/bash
set -e

# this has to exist
if [ -z "${TRANSITLAND_API_KEY}" ]; then
  echo "[ERROR] Environment variable TRANSITLAND_API_KEY is not set. Exiting."
  exit 1
fi

REGION=${REGION:-"us-east-1"}
DATA_DIR="/data/valhalla"

# some defaults, if needed.
export TRANSITLAND_URL=${TRANSITLAND_URL:-"http://transit.land"}
export TRANSIT_TILE_DIR=${TRANSIT_TILE_DIR:-"${DATA_DIR}/transit"}
export TRANSITLAND_PER_PAGE=${TRANSITLAND_PER_PAGE:-5000}
export TRANSITLAND_LEVELS=${TRANSITLAND_LEVELS:-"4"}

# create dirs
mkdir -p "${DATA_DIR}"
mkdir -p "${TRANSIT_TILE_DIR}"

# clean up from previous runs
if [ -d "${TRANSIT_TILE_DIR}" ]; then
  echo "[INFO] Removing contents of prior run in ${TRANSIT_TILE_DIR}/*..."
  rm -rf "${TRANSIT_TILE_DIR}/*"
fi

# DEBUG
echo "Writing debug file to ${TRANSIT_TILE_DIR}/debug"
echo "THIS IS SOME TEST DATA OUTPUT TO ${TRANSIT_TILE_DIR}" >"${TRANSIT_TILE_DIR}/debug"
echo "This is me cat'ing ${TRANSIT_TILE_DIR}/debug"

# only run the tests for production.
if [ "$TRANSITLAND_URL" == "http://transit.land" ]; then
  wget -q "https://raw.githubusercontent.com/valhalla/valhalla/master/test_requests/transit_acceptance_tests.txt" -O ${DATA_DIR}/transit_acceptance_tests.txt
  TRANSIT_TEST_FILE=${DATA_DIR}/transit_acceptance_tests.txt
fi

# for now....build the timezones.
echo "[INFO] Building timezones... "
valhalla_build_timezones conf/valhalla.json

# build transit tiles
echo "[INFO] Building tiles... "
valhalla_build_transit \
  conf/valhalla.json \
  ${TRANSITLAND_URL} \
  ${TRANSITLAND_PER_PAGE} \
  ${TRANSIT_TILE_DIR} \
  ${TRANSITLAND_API_KEY} \
  ${TRANSITLAND_LEVELS} \
  ${TRANSITLAND_FEED} \
  ${TRANSIT_TEST_FILE}

echo "[SUCCESS] valhalla_build_transit completed!"

# time_stamp
stamp=$(date +%Y_%m_%d-%H_%M_%S)

# upload to s3
if  [ -n "$TRANSIT_S3_PATH" ]; then
  echo "[INFO] Copying tiles to S3... "
  tar pcf - -C ${TRANSIT_TILE_DIR} . --exclude ./2 | pigz -9 > ${DATA_DIR}/transit_${stamp}.tgz
  #push up to s3 the new file
  aws --region ${REGION} s3 mv ${DATA_DIR}/transit_${stamp}.tgz s3://${TRANSIT_S3_PATH}/ --acl public-read
  echo "[SUCCESS] Tiles successfully copied to S3!"
fi

# cya
echo "[SUCCESS] Run complete, exiting."
exit 0
