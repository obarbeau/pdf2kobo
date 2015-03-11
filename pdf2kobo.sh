#!/bin/bash
set +e

BRISS_HOME=/usr/local/src/briss-0.9
DEBUG=false
OVERLAP="0.97"
#CROPBOX_OPTION="-cropbox"

function DEBUG()
{
  [ "${DEBUG}" == "true" ] &&  $@
}

usage()
{
  echo "Usage: $0 PDF-file-to-convert" >&2
  exit 1
}

process-file()
{

  FILE="${1}"
  INPUT_DIR="$(dirname ${FILE})"
  FILE_NAME="$(basename ${FILE})"
  FILE_NAME_NO_EXT="${FILE_NAME%.*}"
  # get media box height
  HEIGHT=$(pdfinfo -box ${FILE} | grep "MediaBox" | sed 's/  \+/ /g' | cut -d' ' -f5)
  # half of height plus slight overlap
  CUT_AT=$(echo "${HEIGHT} / 2 * ${OVERLAP}" | bc)
  CUT_AT="${CUT_AT%.*}"
  NB_PAGES=$(pdfinfo ${FILE} | grep Pages | sed 's/  \+/ /g' | cut -d' ' -f2)

  TMP_FILE_1=$(mktemp --suffix=-1)
  TMP_FILE_2=$(mktemp --suffix=-2)
  TMP_FILE_3=$(mktemp --suffix=-3)
  TMP_FILE_4=$(mktemp --suffix=-4)
  OUTPUT_FILE=${INPUT_DIR}/${FILE_NAME_NO_EXT}-kobo.pdf

  OPTIONS="-pdf ${CROPBOX_OPTION} -x 0 -y"

  # upper half
  COMMAND=
  COMMAND="${COMMAND} pdftocairo"
  COMMAND="${COMMAND} ${OPTIONS} -${CUT_AT} ${FILE}"
  COMMAND="${COMMAND} ${TMP_FILE_1}"
  DEBUG echo -e $COMMAND"\n"
  eval $COMMAND

  # lower half
  COMMAND=
  COMMAND="${COMMAND} pdftocairo"
  COMMAND="${COMMAND} ${OPTIONS} ${CUT_AT} ${FILE}"
  COMMAND="${COMMAND} ${TMP_FILE_2}"
  DEBUG echo -e $COMMAND"\n"
  eval $COMMAND

  PAGES=
  for k in $(seq 1 ${NB_PAGES}); do
      PAGES+=$TMP_FILE_1;
      PAGES+=" $k ";
      PAGES+=$TMP_FILE_2;
      PAGES+=" $k ";
  done

  # halves assembly
  COMMAND=
  COMMAND="${COMMAND} cpdf"
  COMMAND="${COMMAND} ${PAGES} -o ${TMP_FILE_3}"
  DEBUG echo -e $COMMAND"\n"
  eval $COMMAND

  # crop
  COMMAND=
  COMMAND="${COMMAND} java -jar ${BRISS_HOME}/briss-0.9.jar &>/dev/null"
  COMMAND="${COMMAND} -s ${TMP_FILE_3} -d ${TMP_FILE_4}"
  DEBUG echo -e $COMMAND"\n"
  eval $COMMAND

  # rotate -90°
  COMMAND=
  COMMAND="${COMMAND} cpdf -rotateby 90 ${TMP_FILE_4} -o ${OUTPUT_FILE}"
  DEBUG echo -e $COMMAND"\n"
  eval $COMMAND

  echo "wrote ${OUTPUT_FILE}"
}

if [ "$#" -ne 1 ]; then
  usage;
fi

if [ ! -d "${BRISS_HOME}" ]; then
  echo "BRISS_HOME does not exists"
  exit 1
fi

process-file $1
