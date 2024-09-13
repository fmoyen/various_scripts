#!/bin/bash


##################################################################################################
# VARIABLES

NoArgs="true"
AllActions="true"
HMC_IP_Set="false"
HMC_Pass_Set="false"
HMC_Server_Set="false"
HMC_Firmware_Set="false"
HMC_Details_Set="false"


##################################################################################################
# FUNCTIONS

usage()
{
   echo
   echo "Usage: "
   echo "------ "
   echo "   $0 -h HMC_IP [-p HMC_PASSWORD] [-s] [-d]"
   echo "   $0 -u  # to get this usage information"
   echo
   echo "   By default, $0 gives all the information"
   echo "   -s: gives only the servers (frames) name and architecture"
   echo "   -f: gives only the servers (frames) firmware level"
   echo "   -d: gives the servers hardware configuration details (CPU/MEM)"
   echo
}

##################################################################################################
# CHECK THE ARGUMENTS

while getopts ":h:p:usfd" option
do
  case $option in
    h)
      HMC_IP=$OPTARG
      HMC_IP_Set="true"
    ;;
    p)
      HMC_Pass=$OPTARG
      HMC_Pass_Set="true"
    ;;
    s)
      HMC_Server=$OPTARG
      HMC_Server_Set="true"
      AllActions="false"
    ;;
    f)
      HMC_Firmware=$OPTARG
      HMC_Firmware_Set="true"
      AllActions="false"
    ;;
    d)
      HMC_Details=$OPTARG
      HMC_Details_Set="true"
      AllActions="false"
    ;;
    u  )
        usage
        exit 2
    ;;
    \? ) echo "Unknown option: -$OPTARG" >&2; exit 1;;
    :  ) echo "Missing option argument for -$OPTARG" >&2; exit 1;;
    *  ) echo "Unimplemented option: -$OPTARG" >&2; exit 1;;
  esac
  NoArgs="false"
done


##################################################################################################
# CHECK WE HAVE ALL ARGUMENTS

[[ "$NoArgs" == "true" ]] && { usage; exit 1; }


##################################################################################################
# DO THE JOB

if [[ "$HMC_Pass_Set" == "true" ]]; then export SSHPASS=$HMC_Pass; fi

echo
echo "#####################################################################################################"
echo "HMC $HMC_IP"
echo "#####################################################################################################"
echo

if [[ $HMC_Server_Set == "true" ]] || [[ $AllActions == "true" ]]; then
  TITLE="FRAMES"
  CMD='for Frame in `lssyscfg -r sys -F name`; do echo -e "$Frame: \c"; lssyscfg -m $Frame -r sys -F type_model; echo -e "  \c"; lssyscfg -m $Frame -r sys -F lpar_proc_compat_modes | sed s/,/\\n/g | tail -1 | sed s/\"//g; done'
  echo "-----------------------------------------------------------------------------------------------------"
  echo $TITLE
  echo "($CMD)"
  echo "-----------------------------------------------------------------------------------------------------"
  echo
  sshpass -e ssh hscroot@$HMC_IP $CMD
  echo
fi

if [[ $HMC_Firmware_Set == "true" ]] || [[ $AllActions == "true" ]]; then
  TITLE="FIRMWARE LEVEL"
  CMD='for Frame in `lssyscfg -r sys -F name`; do echo -e "$Frame: \c"; lslic -m $Frame -F ecnumber activated_level; done'
  echo "-----------------------------------------------------------------------------------------------------"
  echo $TITLE
  echo "($CMD)"
  echo "-----------------------------------------------------------------------------------------------------"
  echo
  sshpass -e ssh hscroot@$HMC_IP $CMD
  echo
fi

if [[ $HMC_Details_Set == "true" ]] || [[ $AllActions == "true" ]]; then
  TITLE="PROCESSORS NUMBER"
  CMD='for Frame in `lssyscfg -r sys -F name`; do echo -e "$Frame: \c"; lshwres -m $Frame -r proc --level sys -F configurable_sys_proc_units; done'
  echo "-----------------------------------------------------------------------------------------------------"
  echo $TITLE
  echo "($CMD)"
  echo "-----------------------------------------------------------------------------------------------------"
  echo
  sshpass -e ssh hscroot@$HMC_IP $CMD
  echo

  TITLE="MEMORY SIZE"
  CMD='for Frame in `lssyscfg -r sys -F name`; do echo -e "$Frame: \c"; lshwres -m $Frame -r mem --level sys -F configurable_sys_mem; done'
  echo "-----------------------------------------------------------------------------------------------------"
  echo $TITLE
  echo "($CMD)"
  echo "-----------------------------------------------------------------------------------------------------"
  echo
  sshpass -e ssh hscroot@$HMC_IP $CMD
  echo
fi
