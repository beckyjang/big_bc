#!/bin/bash
#
# Sync Gateway Policies with graphql -xv
# [Export from SourceGateway(Dev)]
# ./gtc_gateway_migration.sh export
# [Import to TargetGateway(Prod/DR)]
# ./gtc_gateway_migration.sh extract <gz filename relative path>
# ./gtc_gateway_migration.sh import-run gateway_XXX.properties


export GRAPHMAN_HOME=./graphman-client-main

########################################################################
# Gateway Folder name should be start with "@GT" (FolderPrefix)
# Add Extra Policy and Services when need

SourcePolicyName=()
SourceServiceName=() # Should be resolution path of API
SourceClusterPropertyName=("portal.account.plans.fragment.guid" "portal.api.folder" "portal.deployer.status")
SourceClusterPropertyName+=("io.xmlPartMaxBytes" "restman.request.message.maxSize")
SourceClusterPropertyName+=("gtc.readtimeout.default" "gtc.otk.isLocal" "gtc.internal.allowed.ip")
SourceByFolderPathName=()

## For Portal Integration Folders
SourceFolderName=("Portal APIs") # making folder
SourceServerModuleFileName=("ApiPortalIntegrationAssertion" "PortalDeployerAssertion" "PortalUpgradeAssertion")

# [Folder based Export]
DefaultDIR=workspace
MigWorkFolder=$DefaultDIR/working
GenesisDIR=gtc-script
FolderPrefix=@GTC


declare -A policyMap serviceMap encMap folderMap
declare -a SourcecwpParam SourceServiceId SourceFolderName
declare -a outputFileNames
########################################################################


job=$1
GatewayProfile=$2
startDate=$(date)
Today=$(date +"%Y-%m-%d")

if [[ "$GatewayProfile" == "" ]] ; then
    GatewayProfile="default"
fi

resultLog=${DefaultDIR}/result_${job}_${Today}.json


echo "INFO: GRAPHMAN_HOME=${GRAPHMAN_HOME}"
echo "INFO: GatewayProfile = ${GatewayProfile}"

function usages() {
    echo Usage:
    printf '  %s {export|extract|import-run} [<filename>]\n' $0

    echo Parameters:
    printf '  %-20s %s\n' "export" "Export and archive bundle and resources"
    printf '  %-20s %s\n' "extract <filename>" "Extract from archive file <filename>"
    printf '  %-20s %s\n' "import-run" "Import bundle file to the Gateway"

    echo Examples:
    printf '  %-20s %s\n'  $0 "export"
    printf '  %-20s %s\n'  $0 "extract ./archive/dapigw01-XXX.tar.gz"
    printf '  %-20s %s\n'  $0 "import-run"

    exit 1
}


function runGraphman {
    myCmd="\"${GRAPHMAN_HOME}/graphman.sh\" $1"
    echo -e "\nINFO: Running... ${myCmd}"

    std_err=$((
    (
        echo "${myCmd}" | sh
    )
    ) 2>&1)

    echo -e "${std_err}" >> ${resultLog}
    echo -e "INFO: Result..\n${std_err}"

    if echo -e "${std_err}" | grep "\"status\": \"ERROR\"" >/dev/null; then
        echo -e "\nERROR: Failed running! Please check ${resultLog} file.\n"
        exit 1
    fi
}

function runNodeJS {
    myCmd="node \"$1\" $2"
    echo -e "\nINFO: Running... ${myCmd}"

    std_err=$((
    (
        echo "${myCmd}" | sh
    )
    ) 2>&1)

    echo -e "${std_err}" >> ${resultLog}
    echo -e "INFO: Result..\n${std_err}"

    if echo -e "${std_err}" | grep "\"status\": \"ERROR\"" >/dev/null; then
        echo -e "\nERROR: Failed running! Please check ${resultLog} file.\n"
        exit 1
    fi
}

# Folders for getArrayOfMappingFolder
function getArrayOfMappingFolder() {
    echo INFO: "getArrayOfFolder"

    ## Folders with Prefix
    runGraphman "export --gateway ${GatewayProfile} --using folders --filter.by name --filter.startsWith '${FolderPrefix}' --output '${MigWorkFolder}/foldernames.json'"
    # outputFileNames+=( "${MigWorkFolder}/${name}.json" )

    myCmd="node \"${GenesisDIR}/gtc_getFolderArray.js\" ${MigWorkFolder}/foldernames.json"
    echo INFO: "${myCmd}"
    readarray -t myArray < <(echo "${myCmd}" | sh)

    for K in "${myArray[@]}" ; do
        IFS=$'\t' read -r -a a <<<"$K"
        id=${a[0]}
        # SourceFolderName+=( "${id}" )
        SourceByFolderPathName+=( "${id}" )
        unset a
    done

    # declare -p SourceFolderId
    echo INFO: SourceFolderName.length=${#SourceByFolderPathName[@]}
    # echo "INFO: Gateway Mapping Folders : ${SourceFolderName[@]}"

}

function export-bundle {
    echo "INFO: export resouces"
    echo "INFO: will remove existing directories : $MigWorkFolder"

    if [ -d "$MigWorkFolder" ] ; then
        rm -rf ./${MigWorkFolder}
    fi
    mkdir -p "$MigWorkFolder"
    rm -f ./${resultLog}

    ## Cluster Wide Properties
    if [ "${#SourceClusterPropertyName[@]}" -gt 0 ] ; then
        for name in "${SourceClusterPropertyName[@]}" ; do
            runGraphman "export --gateway ${GatewayProfile} --using clusterProperties --filter.by name --filter.equals '${name}' --output '${MigWorkFolder}/${name}.json'"
            outputFileNames+=( "${MigWorkFolder}/${name}.json" )
        done
    fi

    ## Folders with Prefix
    # runGraphman "export --gateway ${GatewayProfile} --using folders --filter.by name --filter.startsWith '${FolderPrefix}' --output '${MigWorkFolder}/foldernames.json'"
    # outputFileNames+=( "${MigWorkFolder}/${name}.json" )
    # runNodeJS "${GRAPHMAN_HOME}/gtc_run/gtc_getFolderArray.js" "${MigWorkFolder}/foldernames.json"

    # get full folder name list
    getArrayOfMappingFolder

    # Folders
    if [ "${#SourceFolderName[@]}" -gt 0 ] ; then
        for name in "${SourceFolderName[@]}" ; do
            runGraphman "export --gateway ${GatewayProfile} --using folders --filter.by name --filter.equals '${name}' --output '${MigWorkFolder}/${name}.json'"
            outputFileNames+=( "${MigWorkFolder}/${name}.json" )
        done
    fi

    ## Policy/Service/Enc by Folder Path
    if [ "${#SourceByFolderPathName[@]}" -gt 0 ] ; then
        for name in "${SourceByFolderPathName[@]}" ; do
            runGraphman "export --gateway ${GatewayProfile} --using folder --variables.folderPath '${name}' --output '${MigWorkFolder}/${name}.json'"
            outputFileNames+=( "${MigWorkFolder}/${name}.json" )
        done
    fi

    ## Specific policies
    if [ "${#SourcePolicyName[@]}" -gt 0 ] ; then
        for name in "${SourcePolicyName[@]}" ; do
            runGraphman "export --gateway ${GatewayProfile} --using policy --variables.name '${name}' --output '${MigWorkFolder}/${name}.json'"
            outputFileNames+=( "${MigWorkFolder}/${name}.json" )
        done
    fi

    ## Specific services
    if [ "${#SourceServiceName[@]}" -gt 0 ] ; then
        for name in "${SourceServiceName[@]}" ; do
            runGraphman "export --gateway ${GatewayProfile} --using service --variables.resolutionPath '${name}' --output '${MigWorkFolder}/${name}.json'"
            outputFileNames+=( "${MigWorkFolder}/${name}.json" )
        done
    fi

    ## Server Module Files
    if [ "${#SourceServerModuleFileName[@]}" -gt 0 ] ; then
        for name in "${SourceServerModuleFileName[@]}" ; do
            runGraphman "export --gateway ${GatewayProfile} --using serverModuleFile --variables.name '${name}' --variables.includeModuleFilePart true --output '${MigWorkFolder}/${name}.json'"
            outputFileNames+=( "${MigWorkFolder}/${name}.json" )
        done
    fi


    ## Combine all bundles
    local combineInputs
    for f in "${outputFileNames[@]}" ; do
        combineInputs=${combineInputs}" --input '${f}'"
    done

    runGraphman "combine ${combineInputs} --output '${MigWorkFolder}/exported.json'"

}

function archive() {
    echo "INFO: archive exported resources"
    dest=$1
    name="./${dest}/$(hostname)-$(date '+%Y-%m-%d-%H-%M-%S').tar.gz"

    echo "INFO: archive $name"

    if [ ! -d "${dest}" ] ; then
        mkdir -p "$dest"
    fi

    tar czvf ${name} ${MigWorkFolder}/exported.json ${MigWorkFolder}/*.aar
    echo "INFO: created. ${name}"

    rm /tmp/MIME*.tmp > /dev/null 2>&1
}

function extracting() {
    file=$1
    if [ ! -e "${file}" ] ; then
        echo "ERROR: Please check Filename."
        usages
    fi
    echo "INFO: extract archive file $file"
    if [ -d ${MigWorkFolder} ] ; then
        rm -rf ./${MigWorkFolder}
    fi
    tar xzvf $file -C .

    rm /tmp/MIME*.tmp > /dev/null 2>&1
}

function delete-bundle() {
    echo "INFO: install-bundle "

    runGraphman "import --gateway ${GatewayProfile} --using delete-bundle --input ${MigWorkFolder}/exported.json --options.mappings.folders.action IGNORE"

}


## exclude existing clusterPorperties
function install-bundle() {
    echo "INFO: install-bundle "

    runGraphman "import --gateway ${GatewayProfile} --input ${MigWorkFolder}/exported.json --options.mappings.clusterProperties.action NEW_OR_EXISTING --options.comment \"GraphQL Import : ${Today}\""

}

# function diff() {
#     echo "INFO: diff bundle "

#     runGraphman "diff --gateway ${GatewayProfile} --input ${MigWorkFolder}/exported.json --options.mappings.clusterProperties.action NEW_OR_EXISTING --options.comment \"GraphQL Import : ${Today}\""

# }


case "$job" in
    export)
        export-bundle
        archive archive
        ;;
    extract)
        extracting $2
        ;;
    import-run)
        install-bundle
        ;;
    delete)
        delete-bundle
        ;;
    *)
        usages
        ;;
esac

echo INFO: Started "$startDate" - Ended "$(date)"

