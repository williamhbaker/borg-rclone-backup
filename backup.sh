#!/bin/bash

# init repo: borg init --encryption=repokey

# Close if rclone/borg running
if pgrep "borg" || pgrep "rclone" > /dev/null
then
    echo "$(date "+%m-%d-%Y %T") : Backup already running, exiting" 2>&1 | tee -a $LOGFILE_PATH
    exit
    exit
fi

SECONDS=0

echo "$(date "+%m-%d-%Y %T") : Borg backup has started" 2>&1 | tee -a $LOGFILE_PATH
borg create                         \
    --verbose                       \
    --info                          \
    --stats                         \
    --show-rc                       \
    ::files-{now:%Y-%m-%d}          \
    $BACKUP_DATA_DIR                \
    >> $LOGFILE_PATH 2>&1

backup_exit=$?

borg prune                          \
    --list                          \
    --prefix "files-"               \
    --show-rc                       \
    --keep-daily    7               \
    --keep-weekly   4               \
    --keep-monthly  6               \
    >> $LOGFILE_PATH 2>&1

prune_exit=$?

# use highest exit code as global exit code
global_exit=$(( backup_exit > prune_exit ? backup_exit : prune_exit ))

# Execute if no errors
if [ ${global_exit} -eq 0 ];
then
    borgstart=$SECONDS
    echo "$(date "+%m-%d-%Y %T") : Borg backup completed in  $(($borgstart/ 3600))h:$(($borgstart% 3600/60))m:$(($borgstart% 60))s" | tee -a >> $LOGFILE_PATH 2>&1

    space=`du -s $BORG_REPO|awk '{print $1}'`
    if (( $space < $MIN_SPACE )); then
      echo "$(date "+%m-%d-%Y %T") : Repo too small to sync" 2>&1 | tee -a $LOGFILE_PATH
      exit 3
    fi

    #Reset timer
    SECONDS=0
    echo "$(date "+%m-%d-%Y %T") : Rclone Borg sync has started" >> $LOGFILE_PATH
    rclone sync $BORG_REPO $RCLONE_REMOTE -v 2>&1 | tee -a $LOGFILE_PATH
    rclonestart=$SECONDS
    echo "$(date "+%m-%d-%Y %T") : Rclone Borg sync completed in  $(($rclonestart/ 3600))h:$(($rclonestart% 3600/60))m:$(($rclonestart% 60))s" 2>&1 | tee -a $LOGFILE_PATH
else
    # All other errors
    echo "$(date "+%m-%d-%Y %T") : Borg has errors code:" $global_exit 2>&1 | tee -a $LOGFILE_PATH
fi
exit ${global_exit}
