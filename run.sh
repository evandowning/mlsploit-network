#!/bin/bash

function exit_error() {
    NAME="$1"
    LOG_NAME="$2"
    LOG_ERR_NAME="$3"
    OUTPUT="$4"

    # Write output.json
    echo '{
    "name": "'"$NAME"'",
    "files": ["'"$LOG_NAME"'","'"$LOG_ERR_NAME"'"],
    "tags": [{"ftype":"log"},{"ftype":"log"}],
    "files_extra": ["'"$LOG_NAME"'","'"$LOG_ERR_NAME"'"],
    "files_modified": [null]
}' > "$OUTPUT/output.json"

    exit 0
}

set -x

END="============================================="

INPUT="/mnt/input"
OUTPUT="/mnt/output"
RAW="/mnt/malwarelab/pcap"

CONFIG="$INPUT/input.json"
NAME=$( jq -r ".name" "$CONFIG" )

LOG_NAME="network-${NAME}-log.txt"
LOG_ERR_NAME="network-${NAME}-log-err.txt"
LOG="$OUTPUT/$LOG_NAME"
LOG_ERR="$OUTPUT/$LOG_ERR_NAME"

echo "Started: `date +%s`" > $LOG
echo "" > $LOG_ERR

echo "Running $NAME" >> $LOG

# Get number of files passed
NUM_FILES=$( jq -r ".tags | length" "$CONFIG")

# PAYL
if [ "$NAME" = "payl" ]; then
    # Get pcap filenames
    SAMPLE=""
    if [ $NUM_FILES -gt 0 ]; then
        for i in `seq 0 $((NUM_FILES-1))`
        do
            e=$( jq -r ".tags"[$i].ftype "$CONFIG" )

            # If this is a data file
            if [ "$e" == "data" ]; then
                SAMPLE=$( jq -r ".files"[$i] "$CONFIG")
            fi
        done
    fi

    # Check input files
    if [ "$SAMPLE" = "" ]; then
        echo "Error. Couldn't find input files." >> $LOG_ERR
        exit_error "$NAME" "$LOG_NAME" "$LOG_ERR_NAME" "$OUTPUT"
    fi

    TYPE=$( jq -r ".options.type" "$CONFIG" )
    SMOOTHING=$( jq -r ".options.smoothing_factor" "$CONFIG" )
    THRESHOLD=$( jq -r ".options.threshold" "$CONFIG" )

    mkdir "$OUTPUT/model/"

    MODEL="$OUTPUT/model/model.pkl"
    FEATURE="network_${TYPE}_features.pkl"

    PAYL_CONFIG="/app/payl/payl.cfg"

    touch "$PAYL_CONFIG"
    rm "$PAYL_CONFIG"

    echo "[general]" >> "$PAYL_CONFIG"
    echo "feature=$FEATURE" >> "$PAYL_CONFIG"
    echo "model=$MODEL" >> "$PAYL_CONFIG"

    echo "[payl]" >> "$PAYL_CONFIG"
    echo "type=$TYPE" >> "$PAYL_CONFIG"
    echo "smoothing_factor=$SMOOTHING" >> "$PAYL_CONFIG"
    echo "threshold=$THRESHOLD" >> "$PAYL_CONFIG"

    cd /app/payl/

    # Extract features
    echo "Extracting features" >> $LOG
    echo "Extracting features" >> $LOG_ERR
    echo "Start Timestamp: `date +%s`" >> $LOG
    python2.7 preprocess.py "$RAW" "$INPUT/$SAMPLE" "$FEATURE" >> $LOG 2>> $LOG_ERR
    echo "End Timestamp: `date +%s`" >> $LOG
    echo $END >> $LOG
    echo $END >> $LOG_ERR

    # Run PAYL
    echo "Running PAYL" >> $LOG
    echo "Running PAYL" >> $LOG_ERR
    echo "Start Timestamp: `date +%s`" >> $LOG
    python2.7 payl.py "$PAYL_CONFIG" >> $LOG 2>> $LOG_ERR
    echo "End Timestamp: `date +%s`" >> $LOG
    echo $END >> $LOG
    echo $END >> $LOG_ERR

    echo $END >> $LOG

    # Compress models and move them to output folder
    cd "$OUTPUT"
    zip -r "$OUTPUT/model.zip" "./model/"
    cd /app/

    # Write output.json
    echo '{
    "name": "'"$NAME"'",
    "files": ["'"$LOG_NAME"'","'"$LOG_ERR_NAME"'","model.zip"],
    "tags": [{"ftype":"log"},{"ftype":"log"},{"ftype":"model"}],
    "files_extra": ["'"$LOG_NAME"'","'"$LOG_ERR_NAME"'","model.zip"],
    "files_modified": [null]
}' > "$OUTPUT/output.json"
fi

# EVALUATE_PAYL
if [ "$NAME" = "evaluate_payl" ]; then
    # Get pcap filenames
    SAMPLE=""
    MODEL_ZIP=""
    if [ $NUM_FILES -gt 0 ]; then
        for i in `seq 0 $((NUM_FILES-1))`
        do
            e=$( jq -r ".tags"[$i].ftype "$CONFIG" )

            # If this is a data file
            if [ "$e" == "data" ]; then
                SAMPLE=$( jq -r ".files"[$i] "$CONFIG")
            fi

            # If this is a model file
            if [ "$e" == "model" ]; then
                MODEL_ZIP=$( jq -r ".files"[$i] "$CONFIG")
            fi
        done
    fi

    # Check input files
    if [ "$SAMPLE" = "" ] || [ "$MODEL_ZIP" = "" ]; then
        echo "Error. Couldn't find input files." >> $LOG_ERR
        exit_error "$NAME" "$LOG_NAME" "$LOG_ERR_NAME" "$OUTPUT"
    fi

    # Get model(s)
    OLD_NAME=$( zipinfo -1 "$INPUT/$MODEL_ZIP" | head -1 | awk '{split($NF,a,"/");print a[1]}' )
    MODEL="model"

    # Unzip models
    cd "$INPUT"
    unzip "$MODEL_ZIP" -d "$OUTPUT"
    cd "$OUTPUT"
    mv $OLD_NAME $MODEL
    cd /app/

    SMOOTHING=$( jq -r ".options.smoothing_factor" "$CONFIG" )
    THRESHOLD=$( jq -r ".options.threshold" "$CONFIG" )

    FEATURE="network_features.pkl"

    cd /app/payl/

    # Extract features
    echo "Extracting features" >> $LOG
    echo "Extracting features" >> $LOG_ERR
    echo "Start Timestamp: `date +%s`" >> $LOG
    python2.7 preprocess.py "$RAW" "$INPUT/$SAMPLE" "$FEATURE" >> $LOG 2>> $LOG_ERR
    echo "End Timestamp: `date +%s`" >> $LOG
    echo $END >> $LOG
    echo $END >> $LOG_ERR

    # Evaluate model
    echo "Evaluating model" >> $LOG
    echo "Evaluating model" >> $LOG_ERR
    echo "Start Timestamp: `date +%s`" >> $LOG
    python2.7 evaluation.py "$OUTPUT/$MODEL/model.pkl" "$FEATURE" "$SMOOTHING" "$THRESHOLD" >> $LOG 2>> $LOG_ERR
    echo "End Timestamp: `date +%s`" >> $LOG
    echo $END >> $LOG
    echo $END >> $LOG_ERR

    # Write output.json
    echo '{
    "name": "'"$NAME"'",
    "files": ["'"$LOG_NAME"'","'"$LOG_ERR_NAME"'"],
    "tags": [{"ftype":"log"},{"ftype":"log"}],
    "files_extra": ["'"$LOG_NAME"'","'"$LOG_ERR_NAME"'"],
    "files_modified": [null]
}' > "$OUTPUT/output.json"
fi

#PBA
if [ "$NAME" = "polymorphic_blending_attack" ]; then
    # Get pcap filenames
    ARTIFICIAL=$( jq -r ".options.artificial" "$CONFIG" )
    ATTACK=$( jq -r ".options.attack" "$CONFIG" )

    MODEL_ZIP=""
    if [ $NUM_FILES -gt 0 ]; then
        for i in `seq 0 $((NUM_FILES-1))`
        do
            e=$( jq -r ".tags"[$i].ftype "$CONFIG" )

            # If this is a model file
            if [ "$e" == "model" ]; then
                MODEL_ZIP=$( jq -r ".files"[$i] "$CONFIG")
            fi
        done
    fi

    # Check input files
    if [ "$MODEL_ZIP" = "" ]; then
        echo "Error. Couldn't find input files." >> $LOG_ERR
        exit_error "$NAME" "$LOG_NAME" "$LOG_ERR_NAME" "$OUTPUT"
    fi

    SMOOTHING=$( jq -r ".options.smoothing_factor" "$CONFIG" )
    THRESHOLD=$( jq -r ".options.threshold" "$CONFIG" )

    # Get model(s)
    OLD_NAME=$( zipinfo -1 "$INPUT/$MODEL_ZIP" | head -1 | awk '{split($NF,a,"/");print a[1]}' )
    MODEL="model"

    # Unzip models
    cd "$INPUT"
    unzip "$MODEL_ZIP" -d "$OUTPUT"
    cd "$OUTPUT"
    mv $OLD_NAME $MODEL
    cd /app/

    PBA_CONFIG="/app/pba/pba.cfg"

    FEATURE="$OUTPUT/blended_features.pkl"

    touch "$PBA_CONFIG"
    rm "$PBA_CONFIG"

    echo "[pba]" >> "$PBA_CONFIG"
    echo "artificial_payload=$RAW/$ARTIFICIAL" >> "$PBA_CONFIG"
    echo "attack_payload=$RAW/$ATTACK" >> "$PBA_CONFIG"
    echo "output_payload=$FEATURE" >> "$PBA_CONFIG"

    cd /app/pba/

    # Run PBA
    echo "Running polymorphic_blending_attack" >> $LOG
    echo "Running polymorphic_blending_attack" >> $LOG_ERR
    echo "Start Timestamp: `date +%s`" >> $LOG
    python2.7 pba.py "$PBA_CONFIG" >> $LOG 2>> $LOG_ERR
    cd ..
    echo "End Timestamp: `date +%s`" >> $LOG
    echo $END >> $LOG
    echo $END >> $LOG_ERR

    cd /app/payl

    # Evaluate model
    echo "Evaluating model on blended attack" >> $LOG
    echo "Evaluating model on blended attack" >> $LOG_ERR
    echo "Start Timestamp: `date +%s`" >> $LOG
    python2.7 evaluation.py "$OUTPUT/$MODEL/model.pkl" "$FEATURE" "$SMOOTHING" "$THRESHOLD" >> $LOG 2>> $LOG_ERR
    echo "End Timestamp: `date +%s`" >> $LOG
    echo $END >> $LOG
    echo $END >> $LOG_ERR

    echo $END >> $LOG

    # Compress blended feature and move to output folder
    cd "$OUTPUT"
    mkdir "./features"
    mv "$FEATURE" "./features/"
    zip -r "features.zip" "./features/"
    cd /app/

    # Write output.json
    echo '{
    "name": "'"$NAME"'",
    "files": ["'"$LOG_NAME"'","'"$LOG_ERR_NAME"'","features.zip"],
    "tags": [{"ftype":"log"},{"ftype":"log"},{"ftype":"feature"}],
    "files_extra": ["'"$LOG_NAME"'","'"$LOG_ERR_NAME"'","features.zip"],
    "files_modified": [null]
}' > "$OUTPUT/output.json"
fi


echo "Finished: `date +%s`" >> $LOG
exit 0
