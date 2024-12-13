#!/bin/bash


##################################################################################################
# VARIABLES

NoArgs="true"
AllActions="true"
HMC_IP_Set="false"
HMC_Pass_Set="false"
HMC_CMD="false"
HMC_LPAR_Set="false"
HMC_Status_Set="false"
HMC_Details_Set="false"


##################################################################################################
# FUNCTIONS

usage()
{
   echo
   echo "Usage: "
   echo "------ "
   echo "   $0 -h HMC_IP [-p HMC_PASSWORD] [-c] [-l] [-d]"
   echo "   $0 -u  # to get this usage information"
   echo
   echo "   By default, $0 gives all the information"
   echo "   -c: gives the commands used to get the info"
   echo "   -l: gives only the lpars name per frame"
   echo "   -s: gives only the status of the lpars"
   echo "   -d: gives the servers hardware configuration details (CPU/MEM)"
   echo
}

action()
{
  echo "-----------------------------------------------------------------------------------------------------"
  echo $TITLE
  if [[ $HMC_CMD == "true" ]]; then echo "($CMD)"; fi
  echo "-----------------------------------------------------------------------------------------------------"
  echo
  sshpass -e ssh hscroot@$HMC_IP $CMD
  echo
}

##################################################################################################
# CHECK THE ARGUMENTS

while getopts ":h:p:uclsfd" option
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
    c)
      HMC_CMD="true"
    ;;
    l)
      HMC_LPAR_Set="true"
      AllActions="false"
    ;;
    s)
      HMC_Status_Set="true"
      AllActions="false"
    ;;
    d)
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

if [[ $HMC_LPAR_Set == "true" ]] || [[ $AllActions == "true" ]]; then
  TITLE="LPARs NAME"
  CMD='for Frame in `lssyscfg -r sys -F name`; do echo "$Frame:"; echo "-------"; lssyscfg -r lpar -m $Frame -F name; echo; done'
  action
fi

if [[ $HMC_Status_Set == "true" ]] || [[ $AllActions == "true" ]]; then
  TITLE="LPARs STATUS"
  CMD='for Frame in `lssyscfg -r sys -F name`; do echo "$Frame:"; echo "-------"; lssyscfg -r lpar -m $Frame -F name, state; echo; done'
  action
fi

if [[ $HMC_Details_Set == "true" ]] || [[ $AllActions == "true" ]]; then
	TITLE="PROCESSORS COUNT (curr_proc_mode, curr_min_procs, curr_procs,curr_max_procs)"
  CMD='for Frame in `lssyscfg -r sys -F name`; do echo "$Frame:"; echo "-------"; lshwres -m $Frame -r proc --level lpar -F lpar_name,curr_proc_mode,curr_min_procs,curr_procs,curr_max_procs; echo; done'
  action

  TITLE="MEMORY SIZE (curr_min_mem, curr_mem, curr_max_mem)"
  CMD='for Frame in `lssyscfg -r sys -F name`; do echo "$Frame:"; echo "-------"; lshwres -m $Frame -r mem --level lpar -F lpar_name,curr_min_mem,curr_mem,curr_max_mem; echo; done'
  action
fi
