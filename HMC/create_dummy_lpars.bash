#!/bin/bash


##################################################################################################
# VARIABLES

NoArgs="true"
HMC_IP_Set="false"
SERVER_Set="false"
LPAR_NAME_Set="false"
LPAR_INDEX_Set="false"
PROC_Set="false"
MEM_Set="false"


##################################################################################################
# FUNCTIONS

usage()
{
   echo
   echo "Usage: "
   echo "------ "
   echo "   $0 -h HMC_IP -s SERVER_NAME -l LPAR_NAME -n LPAR_INDEX -p PROCS -m MEMORY_IN_GB" 
   echo "   $0 -u  # to get this usage information"
   echo
   echo "Notes: "
   echo "------ "
   echo "   The name of the dummy lpar will finally be:"
   echo "     \${LPAR_NAME}-Dummy\$LPAR_INDEX"
   echo "     (\"Relex-Dummy6\" for example)"
   echo
   echo "   The dummy lpar will be created using dedicated unshared processors, "
   echo "   and will be configured to boot by default in System Management Services (SMS) mode."
   echo
   echo "Usage examples:"
   echo "---------------"
   echo "$0 -h rubyhmc -s RUBY -l Relex -n 6 -p 10 -m 1024"
   echo "for i in \`seq 1 9\`; do ./create_dummy_lpars.bash -h rubyhmc -s RUBY -l Relex -n \$i -p 10 -m 1024; done"
   echo 
}

##################################################################################################
# CHECK THE ARGUMENTS

while getopts ":h:s:l:n:p:m:u" option
do
  case $option in
    h)
      HMC_IP=$OPTARG
      HMC_IP_Set="true"
    ;;
    s)
      SERVER_NAME=$OPTARG
      SERVER_NAME_Set="true"
    ;;
    l)
      LPAR_NAME=$OPTARG
      LPAR_NAME_Set="true"
    ;;
    n)
      LPAR_INDEX=$OPTARG
      LPAR_INDEX_Set="true"
    ;;
    p)
      PROC=$OPTARG
      PROC_Set="true"
    ;;
    m)
      MEM=$OPTARG
      MEM=$(( MEM * 1024 ))
      MEM_Set="true"
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

if [[ "$HMC_IP_Set" == "false" ]] || [[ "$SERVER_NAME_Set" == "false" ]] || \
[[ "$LPAR_NAME_Set" == "false" ]] || [[ "$LPAR_INDEX_Set" == "false" ]] || \
[[ "$PROC_Set" == "false" ]] || [[ "$MEM_Set" == "false" ]]; then
  echo "HMC_IP set ?: $HMC_IP_Set"
  echo "SERVER_NAME set ?: $SERVER_NAME_Set"
  echo "LPAR_NAME set ?: $LPAR_NAME_Set"
  echo "LPAR_INDEX set ?: $LPAR_INDEX_Set"
  echo "PROC set ?: $PROC_Set"
  echo "MEM set ?: $MEM_Set"
  usage
  exit 1 
fi



##################################################################################################
# DO THE JOB

CMD="ssh hscroot@$HMC_IP mksyscfg -r lpar -m $SERVER_NAME -i name=${LPAR_NAME}-Dummy$LPAR_INDEX, profile_name=normal, lpar_env=aixlinux, min_mem=512, desired_mem=$MEM, max_mem=$MEM, proc_mode=ded, sharing_mode=keep_idle_procs, min_procs=$PROC, desired_procs=$PROC, max_procs=$PROC, boot_mode=sms, conn_monitoring=0"

echo
echo "-----------------------------------------------------------------------------"
echo $CMD
echo "-----------------------------------------------------------------------------"
echo
$CMD

