#!/bin/bash


##################################################################################################
# VARIABLES

NoArgs="true"
AllActions="true"
HMC_IP_Set="false"
HMC_Pass_Set="false"
HMC_CMD="false"


##################################################################################################
# FUNCTIONS

usage()
{
   echo
   echo "Usage: "
   echo "------ "
   echo "   $0 -h HMC_IP [-p HMC_PASSWORD] [-c]"
   echo "   $0 -u  # to get this usage information"
   echo
   echo "   By default, $0 gives all the information"
   echo "   -c: gives the commands used to get the info from the HMC"
   echo
   echo "   (if you don't want to give the HMC password in the command line, please use the SSHPASS environment variable)"
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

while getopts ":h:p:uc" option
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

  TITLE="OS Level"
  CMD='lshmc -V'
  action

  TITLE="Network Configuration"
  CMD='lshmc -n -F hostname,ipaddr,networkmask'
  action

