#!/usr/bin/env bash

set -e

# Usage create-vod-hls.sh SOURCE_FILE [OUTPUT_NAME]
[[ ! "${1}" ]] && echo "Usage: create-vod-hls.sh SOURCE_FILE [OUTPUT_NAME]" && exit 1

# comment/add lines here to control which renditions would be created
renditions=(
# resolution  bitrate  audio-rate
#  "426x240    400k    64k"
  "640x360    800k     96k"
  # "842x480    1400k    128k"
  # "1280x720   2800k    128k"
  #"1920x1080  5000k    192k"
)

segment_target_duration=4       # try to create a new segment every X seconds
max_bitrate_ratio=1.07          # maximum accepted bitrate fluctuations
rate_monitor_buffer_ratio=1.5   # maximum buffer size between bitrate conformance checks

#########################################################################

# second argument in extension
# first argument is video id
source="uploads/${1}/${1}.${2}"
server_url="${3}"
target="cinema/${1}"
if [[ ! "${target}" ]]; then
  target="${source##*/}" # leave only last component of path
  target="${target%.*}"  # strip extension
fi
mkdir -p ${target}


key_frames_interval="$(echo `ffprobe ${source} 2>&1 | grep -oE '[[:digit:]]+(.[[:digit:]]+)? fps' | grep -oE '[[:digit:]]+(.[[:digit:]]+)?'`*2 | bc || echo '')"
key_frames_interval=${key_frames_interval:-50}
trunc=$(bc -l <<< "$key_frames_interval/10")
key_frames_interval=$(LC_NUMERIC="en_US.UTF-8" echo `printf "%.1f\n" $trunc`*10 | bc) # round
key_frames_interval=${key_frames_interval%.*} # truncate to integer


# static parameters that are similar for all renditions
static_params="-c:a aac -ar 48000 -c:v h264 -profile:v main -crf 20 -sc_threshold 0"
static_params+=" -g ${key_frames_interval} -keyint_min ${key_frames_interval} -hls_time ${segment_target_duration}"
static_params+=" -hls_playlist_type vod"

# misc params
misc_params="-hide_banner -y"

master_playlist="#EXTM3U
#EXT-X-VERSION:3
"
cmd=""
for rendition in "${renditions[@]}"; do
  # drop extraneous spaces
  rendition="${rendition/[[:space:]]+/ }"

  # rendition fields
  resolution="$(echo ${rendition} | cut -d ' ' -f 1)"
  bitrate="$(echo ${rendition} | cut -d ' ' -f 2)"
  audiorate="$(echo ${rendition} | cut -d ' ' -f 3)"

  # calculated fields
  width="$(echo ${resolution} | grep -oE '^[[:digit:]]+')"
  height="$(echo ${resolution} | grep -oE '[[:digit:]]+$')"
  maxrate="$(echo "`echo ${bitrate} | grep -oE '[[:digit:]]+'`*${max_bitrate_ratio}" | bc)"
  bufsize="$(echo "`echo ${bitrate} | grep -oE '[[:digit:]]+'`*${rate_monitor_buffer_ratio}" | bc)"
  bandwidth="$(echo ${bitrate} | grep -oE '[[:digit:]]+')000"

  name="${height}p"
  endpoint="${server_url}/${name}.m3u8"
  
  # cmd+=" ${static_params} -vf scale=w=${width}:h=${height}:force_original_aspect_ratio=decrease"
  cmd+=" ${static_params} -vf scale=w=${width}:h=${height}"
  cmd+=" -b:v ${bitrate} -maxrate ${maxrate%.*}k -bufsize ${bufsize%.*}k -b:a ${audiorate}"
  cmd+=" -hls_segment_filename ${target}/${name}_%03d.ts ${target}/${name}.m3u8"
  
  # add rendition entry in the master playlist
  master_playlist+="#EXT-X-STREAM-INF:BANDWIDTH=${bandwidth},RESOLUTION=${resolution}\n${endpoint}\n"
done

# start conversion
echo -e "Executing command:\nffmpeg ${misc_params} -i ${source} ${cmd}"
ffmpeg ${misc_params} -i ${source} ${cmd}

for rendition in "${renditions[@]}"; do
  # prefix the m3u8
  rendition="${rendition/[[:space:]]+/ }"

  # rendition fields
  resolution="$(echo ${rendition} | cut -d ' ' -f 1)"

  height="$(echo ${resolution} | grep -oE '[[:digit:]]+$')"

  name="${height}p"

  # prefix with server path
  sed -i "s~${height}p~${server_url}/${height}p~g" ${target}/${name}.m3u8

done

# create master playlist file
echo -e "${master_playlist}" > ${target}/playlist.m3u8

echo "Done - encoded HLS is at ${target}/"
duration="$(ffmpeg -i ${source} 2>&1 | grep Duration | awk '{print $2}' | tr -d ,)"

curl http://127.0.0.1/done/${1}/$duration

