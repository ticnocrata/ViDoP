#!/bin/bash
# ViDoP - Video Downloader & Processor
# (c) 2025    Luis Ángel Ortega      https://linkedin.com/in/ortgas      https://github.com/ticnocrata      Created:   20230905
# Licencia: Uso no comercial con atribución y participación comercial (ver LICENSE.txt)
# Proyecto: https://github.com/ticnocrata/ViDoP
# Esta herramienta puede ser USADA y MODIFICADA para fines personales o no comerciales.
# Para uso con fines de lucro, se requiere licencia comercial del autor.
# LastUpdate: 20250812v2.1e
LastUpdate="20250812v2.1e"

set +m

##############################[ 📚 Array de Colores ANSI ]##############################
# Manejo de Colores con mnemonicos para facilidad de secuencias ANSI 
declare -A aCL=(
   # Normal					Bold					Subrayado				Fondo
   ['cblack']='\e[0;30m'		['bblack']='\e[1;30m'		['ublack']='\e[4;30m'		['on_black']='\e[40m'
   ['cred']='\e[0;31m'			['bred']='\e[1;31m'		['ured']='\e[4;31m'		['on_red']='\e[41m'
   ['cgreen']='\e[0;32m'		['bgreen']='\e[1;32m'		['ugreen']='\e[4;32m'		['on_green']='\e[42m'
   ['cyellow']='\e[0;33m'		['byellow']='\e[1;33m'	['uyellow']='\e[4;33m'	['on_yellow']='\e[43m'
   ['cblue']='\e[0;34m'			['bblue']='\e[1;34m'		['ublue']='\e[4;34m'		['on_blue']='\e[44m'
   ['cmagenta']='\e[0;35m'		['bmagenta']='\e[1;35m'	['umagenta']='\e[4;35m'	['on_purple']='\e[45m'
   ['ccyan']='\e[0;36m'			['bcyan']='\e[1;36m'		['ucyan']='\e[4;36m'		['on_cyan']='\e[46m'
   ['cwhite']='\e[0;37m'  	   	['bwhite']='\e[1;37m'		['uwhite']='\e[4;37m'		['on_white']='\e[47m'
   # Combos útiles y reset
   ['alert']='\e[1;37m\e[41m'	['noColor']='\e[0m'
)
#Sin colores para terminales no interactivas
if ! [ -t 1 ]; then
    for sColorClave in "${!aCL[@]}"; do
       aCL["${sColorClave}"]=""
    done
fi

##############################[ 🎨 Banner ]##############################
Banner() {
echo -e "$(cat << EOF
${aCL['bgreen']} _    _${aCL['bwhite']} _ _____      ${aCL['bred']}  ______  
${aCL['bgreen']}| |  | ${aCL['bwhite']}(_|____ \      ${aCL['bred']}(_____ \ 
${aCL['bgreen']}| |  | ${aCL['bwhite']}|_ _   \ \ ___  ${aCL['bred']}_____) )
${aCL['bgreen']} \ \/ /${aCL['bwhite']}| | |   | / _ )\\e[1;31m|______/ 
${aCL['bgreen']}  \  / ${aCL['bwhite']}| | |__/ / |_| ${aCL['bred']}| |      
${aCL['bgreen']}   \/  ${aCL['bwhite']}|_|_____/ \___/${aCL['bred']}|_|  ${aCL['on_green']}     🇲🇽  ${aCL['byellow']}\e[5m=\e[25m 🥇  ${aCL['noColor']}

EOF
)"
} #Banner

Banner


##############################[ 📝 Función: LogMsg ]##############################
# Rutina de registro para el log y para la pantalla.
LogMsg() {
    local sTipo="$1" sMsg="$*"
    local sColor sPrefix
    case "${sTipo}" in
        INFO)   sColor="${aCL['bblue']}";       sPrefix="[INFO]       ";;
        OK)     sColor="${aCL['bgreen']}";      sPrefix="[OK]         ";;
        ERROR)  sColor="${aCL['bred']}";        sPrefix="[ERROR]      ";;
        KILL)   sColor="${aCL['byellow']}";     sPrefix="[KILL]       ";;
        TREE)   sColor="${aCL['bcyan']}";       sPrefix="[TREE]       ";;
        WARN)   sColor="${aCL['alert']}";       sPrefix="[WARN]       ";;
        UPDATE) sColor="${aCL['bmagenta']}";    sPrefix="[UPDATE]     ";;
        *)      sColor="${aCL['bwhite']}";      sPrefix="[MSG]        ";;
    esac
    local sTS="[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo -e "${sColor}${sTS} ${sPrefix}${sMsg}${aCL['noColor']}"
    if [[ -n "${fArchivoLog}" && -n "${fDirectorioDescarga}" ]]; then
        local fDirParent
        fDirParent="$(dirname -- "${fArchivoLog}")"
        if [[ -d "${fDirectorioDescarga}" && -d "${fDirParent}" ]]; then
            echo -e "${sTS} ${sPrefix}${sMsg}" >> "${fArchivoLog}"
        fi
    fi
} #LogMsg

##############################[ 🛠️ Función: ValidarDependencias ]##############################
# Validar dependencias externas correctamente, función canónica
ValidarDependencias() {
    local aDependenciasReq=(yt-dlp ffmpeg jq curl base64 git)
    local bAceptaTodo=0
    local sNombre sResp
    for sDependencia in "${aDependenciasReq[@]}"; do
        sNombre="${sDependencia}"
        if ! command -v "${sDependencia}" >/dev/null 2>&1; then
            LogMsg ERROR "Falta dependencia requerida: ${sDependencia}"
            if [[ "${bAceptaTodo}" -eq 0 ]]; then
                read -rp "[UPDATE] ¿Instalar ${sNombre}? (y=si / n=no / a=aceptar todas): " sResp
                case "${sResp}" in
                    a|A) bAceptaTodo=1 ;;
                    y|Y) ;;
                    n|N) LogMsg ERROR "No se puede continuar sin ${sNombre}"; exit 1 ;;
                    *)   LogMsg WARN "Respuesta inválida. Repite."; continue ;;
                esac
            fi
            LogMsg INFO "Comando a ejecutar: "
            case "${sNombre}" in
                git)     echo "sudo apt-get update && sudo apt-get install -y git"; bash -c "sudo apt-get update && sudo apt-get install -y git" || { LogMsg ERROR "Falló instalar ${sNombre}"; exit 1; } ;;
                yt-dlp)  echo "sudo apt-get install -y yt-dlp || sudo pip install -U yt-dlp"; bash -c "sudo apt-get install -y yt-dlp || sudo pip install -U yt-dlp" || { LogMsg ERROR "Falló instalar ${sNombre}"; exit 1; } ;;
                ffmpeg)  echo "sudo apt-get install -y ffmpeg"; bash -c "sudo apt-get install -y ffmpeg" || { LogMsg ERROR "Falló instalar ${sNombre}"; exit 1; } ;;
                jq)      echo "sudo apt-get install -y jq"; bash -c "sudo apt-get install -y jq" || { LogMsg ERROR "Falló instalar ${sNombre}"; exit 1; } ;;
                curl)    echo "sudo apt-get install -y curl"; bash -c "sudo apt-get install -y curl" || { LogMsg ERROR "Falló instalar ${sNombre}"; exit 1; } ;;
                base64)  echo "sudo apt-get install -y coreutils"; bash -c "sudo apt-get install -y coreutils" || { LogMsg ERROR "Falló instalar ${sNombre}"; exit 1; } ;;
                *)       LogMsg ERROR "No hay comandos de instalación para ${sNombre}. Cancelando."; exit 1 ;;
            esac
            command -v "${sNombre}" >/dev/null 2>&1 || { LogMsg ERROR "No se encontró ${sNombre} tras instalar"; exit 1; }
            LogMsg OK "Instalado: ${sNombre}"
        fi
    done
    LogMsg OK "Dependencias verificadas."
} #ValidarDependencias

###########################[ 📌 Imprime izq. centro o der.  ]############################
# Rutina para texto alineado (izquierda, centro, derecha)
ImprimeLineaAlineada() {
    local sAlineacion sCaracter nLargo sMensaje nLargoMsg nRelleno nPreFill nPostFill sLinea
    sAlineacion="$1"; sCaracter="$2"; nLargo="$3"; sMensaje="${4:-}"; nLargoMsg=${#sMensaje}
    if [[ "$nLargoMsg" -ge "$nLargo" ]]; then
        sLinea="${sMensaje:0:$nLargo}"
    else
        nRelleno=$((nLargo - nLargoMsg))
        case "$sAlineacion" in
            i) sLinea="${sMensaje}$(printf "%0.s$sCaracter" $(seq 1 $nRelleno))" ;;
            d) sLinea="$(printf "%0.s$sCaracter" $(seq 1 $nRelleno))${sMensaje}" ;;
            c|*) nPreFill=$((nRelleno / 2)); nPostFill=$((nRelleno - nPreFill))
                 sLinea="$(printf "%0.s$sCaracter" $(seq 1 $nPreFill))${sMensaje}$(printf "%0.s$sCaracter" $(seq 1 $nPostFill))" ;;
        esac
    fi
    echo -e "$sLinea"
} #ImprimeLineaAlineada

##############################[ 📂 Variables Globales ]##############################
# Variables globales y valores por defecto
bAceptaTodo=0
sModo="ambos"
sCalidad="best"
sUrl=""
sSubsIdioma=""
sSeccion=""
sNombrePlaylist=""
bError=0
bEsPlaylist=0
bSubs=0
bAutoActualizar=0
bVerbose=0
nNumFrames=""
fArchivoLog=""
fDirectorioDescarga=""
sDirectorioOriginal="$(pwd)"
fRawScr="$(echo aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL3RpY25vY3JhdGEvVmlEb1AvbWFpbi9WaURvUC5zaA== | base64 -d 2>/dev/null || true)"
uNoti="$(echo aHR0cDovL21haWxpbmcuaXRjb21tLm14L3N1YnNjcmliZQo= | base64 -d 2>/dev/null || true)"
sRepG="aHR0cHM6Ly9naXRodWIuY29tL3RpY25vY3JhdGEvVmlEb1AuZ2l0Cg=="

#######################################################################
# Validar dependencias externas
ValidarDependencias

##############################[ 🎨 AsciiArt ]##############################
# Arte principal y ayuda
AsciiArt() {
    printf "${aCL['bmagenta']}(c) Luis Angel Ortega     ${aCL['byellow']}Video Downloader and Processor ${aCL['bmagenta']}ViDoP${aCL['noColor']}\n"
    printf "${aCL['bcyan']}                                   '''\n"
    printf "                                  (O O)\n"
    printf "                    +---------oOO--(_)---------------+\n"
    printf "                    |                                |\n"
    printf "                    |${aCL['bmagenta']} https://linkedin.com/in/ortgas ${aCL['bcyan']}|\n"
    printf "                    |                                |\n"
    printf "                    +--------------------oOO---------+\n"
    printf "                                 |__|__|\n"
    printf "                                  || ||\n"
    printf "                                 ooO Ooo\n"
    printf "${aCL['noColor']}\n"
} #AsciiArt
##############################[ 📄 MostrarAyuda ]##############################
MostrarAyuda() {
    AsciiArt
    printf "Uso: ${aCL['bgreen']}$(basename "$0")${aCL['noColor']} -u ${aCL['bgreen']}URL${aCL['noColor']} [-m MODO] [-q CALIDAD] [-f [Ns|all]] [-s INI-FIN] [--st [idioma]] [-a]\n"
    printf "\n"
    printf "${aCL['bwhite']}Opciones:${aCL['noColor']}\n"
    printf "  ${aCL['byellow']}-u, --url URL         ${aCL['bwhite']}Video o playlist a descargar.${aCL['noColor']}\n"
    printf "  ${aCL['byellow']}-m, --modo MODO       ${aCL['bwhite']}audio, video, ambos. Default:${aCL['bcyan']} ambos${aCL['bwhite']}.${aCL['noColor']}\n"
    printf "  ${aCL['byellow']}-q, --calidad         ${aCL['bwhite']}best, 1080, 720, etc. Default:${aCL['bcyan']} best${aCL['bwhite']}.${aCL['noColor']}\n"
    printf "  ${aCL['byellow']}-f, --frames [OPC]    ${aCL['bcyan']}all ${aCL['bwhite']}|${aCL['bcyan']} Ns${aCL['bwhite']} (ej. 10s) para extracción frames OSINT. Si solo usas -f extrae todos.${aCL['noColor']}\n"
    printf "  ${aCL['byellow']}-s, --seccion INI-FIN ${aCL['bwhite']}Solo descargar sección de video (ej: 00:01:00-00:03:00).${aCL['noColor']}\n"
    printf "  ${aCL['byellow']}-st, --subs [IDIOMA]  ${aCL['bwhite']}Descargar subtítulos .srt externos. Si omites IDIOMA, trataré con el nativo.${aCL['noColor']}\n"
    printf "  ${aCL['byellow']}-a, --actualizar      ${aCL['bwhite']}Efectuar actualización automática de la herramienta (si hay nueva versión).${aCL['noColor']}\n"
    printf "  ${aCL['byellow']}-h, --help            ${aCL['bwhite']}Esta ayuda.${aCL['noColor']}\n"
    printf "\n"
    printf "${aCL['bgreen']}Ejemplos:${aCL['noColor']}\n"
    printf "  ${aCL['bcyan']}%s -u URL -m video -q 720${aCL['noColor']} ${aCL['bwhite']} para calidad 720p\n" "$(basename "$0")"
    printf "  ${aCL['bcyan']}%s -u URL -f${aCL['noColor']}  ${aCL['bwhite']} para extraer todos los frames\n" "$(basename "$0")"
    printf "  ${aCL['bcyan']}%s -u URL -f 5s${aCL['noColor']}  ${aCL['bwhite']} para un frame cada 5 segundos\n" "$(basename "$0")"
    printf "  ${aCL['bcyan']}%s -u URL -st es${aCL['noColor']}  ${aCL['bwhite']} descarga .srt en español \n" "$(basename "$0")"
    printf "\n"
    if [[ -n "$1" ]]; then
        echo -e "${aCL['alert']}Error: $1${aCL['noColor']}\n"
        LogMsg ERROR "$1"
    fi
    exit 0
} #MostrarAyuda

##############################[ 🔎 CheckUpdate ]##############################
# Verificación de actualización (CheckUpdate)
CheckUpdate() {
    local sRemoteDate
    LogMsg UPDATE "Verificando actualización de la herramienta"
    if [[ "${bVerbose}" -eq 1 ]]; then
        LogMsg INFO "Leyendo raw desde ${fRawScr}"
    else
        LogMsg INFO  "Leyendo desde GitHub"
    fi
    sRemoteDate="$(curl -fsSL --max-time 12 "${fRawScr}" 2>/dev/null | head -20 | grep -m1 '^# LastUpdate:' | awk '{print $3}')"
    if [[ -z "$sRemoteDate" ]]; then
        LogMsg UPDATE "No se pudo leer desde GitHub, intentar después."
        return 2
    fi
    LogMsg INFO "Version remota: $sRemoteDate || Local: $LastUpdate"
    if [[ "$sRemoteDate" != "$LastUpdate" ]]; then
        LogMsg UPDATE "Ejecuta con -a para actualizar. ${aCL['uwhite']}¡Hay NUEVA VERSIÓN! ${aCL['bgreen']}($sRemoteDate). "
        export VSCRIPT_NEW_URL="$fRawScr" 
        export VSCRIPT_NEW_LU="$sRemoteDate"
        return 1
    else
        LogMsg OK "Tu herramienta está AL DÍA. ($LastUpdate)"
        return 0
    fi
} #CheckUpdate

##############################[ 🛠️ AutoActualizar ]########################
# Rutina de actualización 
AsciiArt2() {
    echo -e ""
    echo -e "${aCL[bwhite]}   ;)(;${aCL[noColor]}"
    echo -e "${aCL[bwhite]}  :----:${aCL[noColor]}   ${aCL[byellow]}o${aCL[bcyan]}8${aCL[byellow]}O${aCL[bgreen]}o${aCL[noColor]}/     ${aCL[bblue]}╔══╗${aCL[noColor]}               ┈┈${aCL[byellow]}┏${aCL[bblue]}━╮${aCL[noColor]}"
    echo -e "${aCL[cwhite]} C|${aCL[byellow]}====${aCL[cwhite]}|${aCL[noColor]} ${aCL[bgreen]} .${aCL[byellow]}o${aCL[bcyan]}8${aCL[byellow]}o${aCL[bcyan]}8${aCL[byellow]}O${aCL[bcyan]}o${aCL[bgreen]}.${aCL[noColor]}   ${aCL[bblue]}╚╗╔╝${aCL[noColor]}               ┈${aCL[byellow]}▉╯${aCL[bblue]}┈┗━━╮${aCL[noColor]}"
    echo -en "${aCL[cwhite]}  |    | "
    echo -en "\\"
    echo -en "${aCL[byellow]}========"
    echo -en "${aCL[cwhite]}/${aCL[bblue]}  ╔╝${aCL[bred]}(¯\`v´¯)${aCL[bblue]}${aCL[noColor]}          ┈${aCL[byellow]}▉${aCL[bblue]}┈┈┈┈┈┃${aCL[noColor]}\n"
    echo -e "${aCL[cwhite]}  \`----'  \`-------'  ${aCL[bblue]}╚══${aCL[bred]}\`.¸.${aCL[ccyan]}[${aCL[bmagenta]}Freeware${aCL[ccyan]}]${aCL[noColor]}  ┈${aCL[byellow]}▉${aCL[bblue]}╰━━━━╯${aCL[noColor]}"
    ImprimeLineaAlineada "i", "~"
} #AsciiArt2
AutoActualizar() {
    local uData="$(echo bGlzdD01MFo3TTA1R2tGQjVhNmpuMVYwaDg5MmcmYm9vbGVhbj10cnVlCg== | base64 -d 2>/dev/null || true)"
    local sRepoGit="$(echo "${sRepG}" | base64 -d 2>/dev/null || true)"
    local dScriptDir="$(cd "$(dirname -- "$0")" && pwd)"
    local sTmpDir="${dScriptDir}/ViDoP_tmp_update_$(date +%s)_$RANDOM"
    local fScriptActivo="${dScriptDir}/$(basename -- "$0")"
    local fRepoScript="${sTmpDir}/ViDoP.sh"
    AsciiArt2
    echo -e "${aCL['bblue']}No need for coffee or beer 😉, thank you for using this tool and staying up to date!${aCL['noColor']}"
    echo -e "${aCL['byellow']}¡No necesito café ni cerveza 😉, gracias por usar esta herramienta y seguir las novedades!${aCL['noColor']}\n"
    
    echo -en  "Nombre completo ${aCL['byellow']}<Full Name>${aCL['noColor']}?> "
    read -rp "" sNombreUsuario
    while true; do
        echo -en "Indica tu correo para nuevas herramientas y actualizaciones ${aCL['byellow']}<e-mail>?${aCL['noColor']}> "
        read -rp "" sCorreoUsuario
        if [[ "${sCorreoUsuario}" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
            break
        else
            echo -e "${aCL['alert']}El correo no es válido. Intenta de nuevo.${aCL['noColor']}"
        fi
    done

    sUrlSus="${uData}&name=${sNombreUsuario}&email=${sCorreoUsuario}"   
    sResp=$(curl -X POST  -H "Content-Type: application/x-www-form-urlencoded"  -L -d "$sUrlSus" ${uNoti} 2>/dev/null)

    if [[ "${bVerbose}" -eq 1 ]]; then
        LogMsg INFO  "sResp: [${sResp}]  \nsUrlSus: [${sUrlSus}]  \nuNoti: [${uNoti}]"
    else
        LogMsg INFO  "sResp: [${sResp}]"
    fi

    if [[ "$sResp" =~ "1" || "$sResp" =~ "Already subscribed." ]]; then
        LogMsg OK "${sNombreUsuario}, gracias por seguir usando esta herramienta."
        LogMsg OK "Estás anotado."
        if [[ "${bVerbose}" -eq 1 ]]; then
            if [[ "$sResp" =~ "Already subscribed." ]]; then
                LogMsg UPDATE "Gracias por seguir siendo un usuario recurrente con el correo ${sCorreoUsuario}"
            else
                LogMsg UPDATE "Se registró por primera vez a [${sNombreUsuario}] con el correo [${sCorreoUsuario}]"
            fi
        fi
    else
        if [[ "$sResp" =~ "Bounced email address." ]]; then
            LogMsg ERROR "No pude anotarte: BEM, $sResp"
            echo -e "${aCL[alert]}Tu correo ha rebotado emails anteriormente, checa spam o usa otro.${aCL[noColor]}"
        elif [[ "$sResp" =~ "Email is suppressed." ]]; then
            LogMsg ERROR "No pude anotarte: EIS, $sResp"
            echo -e "${aCL[alert]}Alguien solicitó anteriormente no estar anotado con este correo, usa otro.${aCL[noColor]}"
            exit 1
        else
            LogMsg ERROR "No pude anotarte: $sResp"
            echo -e "${aCL[alert]}No pude anotarte: $sResp${aCL[noColor]}"
            exit 1
        fi
    fi    

    if [[ "${bVerbose}" -eq 1 ]]; then
        LogMsg UPDATE "Bajando la actualización del repositorio ${sRepoGit} a ${sTmpDir}"
        if [[ -n "${fArchivoLog}" && -f "${fArchivoLog}" ]]; then
            git clone --depth=2 "${sRepoGit}" "${sTmpDir}" 2>&1 | tee -a "${fArchivoLog}"
        else
            git clone --depth=2 "${sRepoGit}" "${sTmpDir}"
        fi
    else
        LogMsg UPDATE "Conectando a GitHub para descargar actualización..."
        git clone --depth=2 "${sRepoGit}" "${sTmpDir}" >/dev/null 2>&1
    fi

    if [[ $? -ne 0 ]]; then
        LogMsg ERROR "ERROR durante el git. Revisa conexión o permisos."
        [[ -d "${sTmpDir}" ]] && rm -rf "${sTmpDir}"
        return 1
    fi

    if [[ ! -f "${fRepoScript}" ]]; then
        LogMsg ERROR "No se encontró la herramienta ViDoP.sh en la carpeta descargada"
        rm -rf "${sTmpDir}"
        return 1
    fi

    LogMsg UPDATE "Sustituyendo la herramienta actual (${fScriptActivo}) por la nueva versión ..."

    if [[ "${bVerbose}" -eq 1 ]]; then
        LogMsg INFO  "sResp: [${sResp}]  sUrlSus: [${sUrlSus}]  Noti: [${uNoti}]"
    else
        LogMsg INFO  "sResp: [${sResp}]"
    fi

    if cp -f "${fRepoScript}" "${fScriptActivo}"; then
        chmod +x "${fScriptActivo}"
        rm -rf "${sTmpDir}"
        LogMsg OK "¡Actualización exitosa! Por favor vuelve a ejecutar la herramienta."
        exit 0
    else
        LogMsg ERROR "No fue posible reemplazar la version actual. Se conserva la versión anterior."
        rm -rf "${sTmpDir}"
        exit 2
    fi
} #AutoActualizar

##############################[ 🚀 Procesar parámetros ]##############################
# Procesamiento de parámetros de entrada
while [[ $# -gt 0 ]]; do
    case "$1" in
        -u|--url)
            if [[ -n "$2" ]]; then sUrl="$2"; shift 2; else MostrarAyuda "Faltó el valor del parámetro -u / --url."; fi
            ;;
        -m|--modo)
            if [[ -n "$2" ]]; then sModo="$2"; shift 2; else MostrarAyuda "Faltó el valor del parámetro -m / --modo."; fi
            ;;
        -q|--calidad)
            if [[ -n "$2" ]]; then sCalidad="$2"; shift 2; else MostrarAyuda "Faltó el valor del parámetro -q / --calidad."; fi
            ;;
        -f|--frames)
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then nNumFrames="$2"; shift 2;
            else nNumFrames="all"; shift; fi
            ;;
        -s|--seccion)
            if [[ -n "$2" ]]; then sSeccion="$2"; shift 2; else MostrarAyuda "Faltó el valor del parámetro -s / --seccion."; fi
            ;;
        -st|--subs)
            bSubs=1
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then sSubsIdioma="$2"; shift 2; else sSubsIdioma=""; shift; fi
            ;;
        -a|--actualizar)
            bAutoActualizar=1; shift
            ;;
        -v|--verbose)
            bVerbose=1; shift
            ;;
        -h|--help)
            MostrarAyuda
            ;;
        --)
            shift; break
            ;;
        -*|--*)
            MostrarAyuda "Parámetro desconocido $1"
            ;;
        *)
            shift
            ;;
    esac
done

if [[ "${bAutoActualizar}" -eq 1 ]]; then
    AutoActualizar
    exit 0
fi

if [[ -z "${sUrl}" ]]; then
    MostrarAyuda "Debes especificar la URL (-u | --url) a procesar."
fi

CheckUpdate

#######################################################################
# Aquí comienza la acción
##############################[ 🔑 Leer Cookies desde el Navegador ]##############################
sDominio="$(echo "${sUrl}" | awk -F/ '{print $3}' | tr '[:upper:]' '[:lower:]')"
sCookies=""
declare -a aDominiosCookies=("instagram.com" "facebook.com" "youtube.com" "youtu.be" "twitter.com" "x.com" "tiktok.com" "reddit.com" "twitch.tv" "onlyfans.com" "patreon.com" "fanhouse.app")
bDominioRequiere=0
for sDominioListado in "${aDominiosCookies[@]}"; do
    [[ "${sDominio}" == *"${sDominioListado}" ]] && { bDominioRequiere=1; break; }
done

if [[ "${bDominioRequiere}" -eq 1 ]]; then
    LogMsg INFO "Probando autentificación con cookies para ${sUrl} de ${sDominio})"
    
    # 1. Firefox primero
    sTestTitle="$(yt-dlp --get-title --skip-download --cookies-from-browser firefox "${sUrl}" 2>/dev/null | tail -1)"
    if [[ -n "$sTestTitle" && "$sTestTitle" != "NA" ]]; then
        LogMsg OK "Autenticación VÁLIDA con Firefox para ${sDominio} (Título: '$sTestTitle')"
        sCookies="firefox"
    else
        LogMsg INFO "Las cookies de Firefox NO sirvieron para autenticación en ${sDominio}, probando Chrome..."
        sTestTitle="$(yt-dlp --get-title --skip-download --cookies-from-browser chrome "${sUrl}" 2>/dev/null | tail -1)"
        if [[ -n "$sTestTitle" && "$sTestTitle" != "NA" ]]; then
            LogMsg OK "Autenticación VÁLIDA con Chrome para ${sDominio} (Título: '$sTestTitle')"
            sCookies="chrome"
        else
            LogMsg WARN "Dominio ${sDominio} identificado pero ningún navegador provee autenticación funcional. Continuando en modo público..."
            bDominioRequiere=0
        fi
    fi

else
    LogMsg INFO "Dominio ${sDominio} no requiere autenticación por defecto, no buscaré cookies."
fi

#Verificar si es un video solo o una playlist
echo -e "${aCL['byellow']}Procurando determinar la naturaleza de la URL ${sUrl} ${aCL['bcyan']}${aCL['noColor']}"
if [[ "${bVerbose}" -eq 1 ]]; then
     if [[ "${bDominioRequiere}" -eq 1 && -n "${sCookies}" ]]; then
	   sYtDlpResult=$(yt-dlp  --flat-playlist --skip-download  --cookies-from-browser "${sCookies}" "${sUrl}" || true)
     else
           sYtDlpResult=$(yt-dlp  --flat-playlist --skip-download  "${sUrl}" || true)
     fi
     LogMsg INFO "Resultado de la pesquiza:  ${sYtDlpResult} "
else
     if [[ "${bDominioRequiere}" -eq 1 && -n "${sCookies}" ]]; then
           sYtDlpResult=$(yt-dlp  --flat-playlist --skip-download  --cookies-from-browser "${sCookies}" "${sUrl}" 2>&1 || true)
     else
           sYtDlpResult=$(yt-dlp  --flat-playlist --skip-download  "${sUrl}"  2>&1 || true)
     fi
fi

if echo "${sYtDlpResult}" | grep -q '\[playlist\]' || [[ "${sUrl}" == *"playlist"* ]]; then
    bEsPlaylist=1
    sNombrePlaylist=$(yt-dlp "${sCookies}" --flat-playlist --print "%(playlist_title)s" "${sUrl}" 2>&1 | head -1 | sed 's/[ \/\\:*?"<>|]/_/g' | sed 's/[^A-Za-z0-9._-]/_/g')
    fDirectorioDescarga="${sNombrePlaylist:-Playlist_$(date +%s)}"
    mkdir -p "${fDirectorioDescarga}"
    fArchivoLog="${sDirectorioOriginal}/${fDirectorioDescarga}/vidop-itcomm.log"
    > "${fArchivoLog}"
    LogMsg OK "Intentaré procesar la playlist: ${aCL['bcyan']}${sNombrePlaylist} ${aCL['noColor']}"
else
    bEsPlaylist=0
    sTituloTmp=$(yt-dlp "${sCookies}" --get-title --skip-download "${sUrl}" 2>/dev/null | head -1)
    sIdTmp=$(yt-dlp "${sCookies}" --get-id --skip-download "${sUrl}" 2>/dev/null | head -1)
    sNomUnico=""
    if [[ -n "$sTituloTmp" ]]; then
        sNomUnico="$(echo "${sTituloTmp:0:20}" | sed 's/[^A-Za-z0-9._-]/_/g' | sed 's/^[ _-]*//;s/[ _-]*$//')"
    else
        sNomUnico="Video_${sIdTmp:0:8}"
    fi
    fDirectorioDescarga="${sNomUnico:-Video_$(date +%s)}"
    mkdir -p "${fDirectorioDescarga}"
    fArchivoLog="${sDirectorioOriginal}/${fDirectorioDescarga}/vidop-itcomm.log"
    > "${fArchivoLog}"
    LogMsg OK "Intentaré procesar un archivo de video. Carpeta: ${aCL['bcyan']}${fDirectorioDescarga}${aCL['noColor']}"
fi

#######################################################################
# Validar que no pidas sección de un video (cachito) si procesas una playlist
if [[ "${bEsPlaylist}" -eq 1 && -n "${sSeccion}" ]]; then
    MostrarAyuda "No se puede usar -s/--seccion con playlists. Solo con videos individuales."
fi

#######################################################################
# Construcción y ejecución del comando para la descarga
cd "${sDirectorioOriginal}/${fDirectorioDescarga}"
LogMsg INFO "Carpeta de trabajo: ${sDirectorioOriginal}/${fDirectorioDescarga}"

aComandoYtDlp=(
    yt-dlp
    --add-header "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
    --write-info-json --no-warnings --progress --newline
    -P "."
)

# Agregar Cookies
if [[ "${bDominioRequiere}" -eq 1 && -n "${sCookies}" ]]; then
   aComandoYtDlp+=(--cookies-from-browser "${sCookies}")
fi

##############################[ 🎯 Continuar construyendo el comando ]##############################
if [[ -n "${sSeccion}" ]]; then
    aComandoYtDlp+=(--download-sections "*${sSeccion}")
fi
case "${sModo,,}" in
    audio|mp3)
        aComandoYtDlp+=(-f bestaudio --extract-audio --audio-format mp3)
        ;;
    video)
        if [[ "${sCalidad}" == "best" ]]; then
            aComandoYtDlp+=(-f "bestvideo+bestaudio/best")
        else
            aComandoYtDlp+=(-f "bestvideo[height<=${sCalidad}]+bestaudio/best[height<=${sCalidad}]")
        fi
        ;;
    ambos)
        if [[ "${sCalidad}" == "best" ]]; then
            aComandoYtDlp+=(-f "bestvideo+bestaudio/best" --merge-output-format mp4)
        else
            aComandoYtDlp+=(-f "bestvideo[height<=${sCalidad}]+bestaudio/best[height<=${sCalidad}]" --merge-output-format mp4)
        fi
        ;;
    *)
        MostrarAyuda "Modo no reconocido: ${sModo} (usa: audio, video, ambos)"
        ;;
esac
if [[ "${bSubs}" -eq 1 ]]; then
    aComandoYtDlp+=(--write-subs --convert-subs srt)
    if [[ -n "${sSubsIdioma}" ]]; then
        aComandoYtDlp+=(--sub-lang "${sSubsIdioma}")
    fi
fi

LogMsg INFO "Opciones actuales: $(printf '%q ' "${aComandoYtDlp[@]}")"
mapfile -d '' -t aArchivosAntes < <(find . -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.webm" \) -printf "%f\0")
LogMsg TREE "Archivos antes: $(printf '%q ' "${aArchivosAntes[@]}")"
LogMsg OK "Inicio de descarga multimedia, modalidad ${sModo} (calidad: ${sCalidad}), destino [$(pwd)]"
"${aComandoYtDlp[@]}" "${sUrl}" 2>&1 | tee -a "${fArchivoLog}" || bError=1
mapfile -d '' -t aArchivosDespues < <(find . -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.webm" \) -printf "%f\0")
LogMsg TREE "Archivos despues: $(printf '%q ' "${aArchivosDespues[@]}")"

#######################################################################
# Si se solicitaron, extrae frames desde los videos generados 
if [[ -n "${nNumFrames}" ]]; then
    LogMsg INFO "Procesando solicitud de fotogramas para los archivos de video descargados"
    declare -A aArchivosAntesMap
    for fArchivo in "${aArchivosAntes[@]}"; do aArchivosAntesMap["${fArchivo}"]=1; done
    aVideosNuevos=()
    for fArchivo in "${aArchivosDespues[@]}"; do
        [[ "${fArchivo}" =~ \.mp4$|\.mkv$|\.webm$ ]] || continue
        if [[ -z "${aArchivosAntesMap["${fArchivo}"]}" ]]; then
            LogMsg OK "Identificado como nuevo, archivo: ${fArchivo}"
            aVideosNuevos+=("${fArchivo}")
            sNomUnico=""
            sNomUnico="$(echo "${fArchivo:0:20}" | sed 's/[^A-Za-z0-9._-]/_/g' | sed 's/^[ _-]*//;s/[ _-]*$//')"
            mkdir -p "${sNomUnico}"
            LogMsg OK "Creada la subcarpeta: ${sNomUnico}"
        fi
    done
    for fVideoArchivo in "${aVideosNuevos[@]}"; do
        LogMsg INFO "Intentando extraer frames del archivo: ${fVideoArchivo}"
        sNomUnico="$(echo "${fVideoArchivo:0:20}" | sed 's/[^A-Za-z0-9._-]/_/g' | sed 's/^[ _-]*//;s/[ _-]*$//')"
        if [[ "${nNumFrames}" == "all" ]]; then            
            ffmpeg -nostdin -i "${fVideoArchivo}" "${sNomUnico}/frame_%05d.png" 2>&1 | tee -a "${fArchivoLog}" || bError=1
        elif [[ "${nNumFrames}" =~ ^[0-9]+s$ ]]; then
            nIntervalo="${nNumFrames%s}"
            ffmpeg -nostdin -i "${fVideoArchivo}" -vf "fps=1/${nIntervalo}" "${sNomUnico}/frame_%05d.png" 2>&1 | tee -a "${fArchivoLog}" || bError=1
        else
            MostrarAyuda "Valor no válido para -f/--frames."
        fi
    done
    LogMsg OK "Fotogramas procesados"
fi

#######################################################################
# Resumen final: SIEMPRE ve a la carpeta de descargas y ejecuta el ciclo ahí
if [[ "${bError}" -eq 0 ]]; then
    cd "${sDirectorioOriginal}/${fDirectorioDescarga}"
    nNumVideos=0
    nNumAudios=0
    nNumSubtitulos=0
    sSeparadorMilesLocal=$(locale thousands_sep 2>/dev/null)
    sSeparadorMiles="${sSeparadorMilesLocal:-','}"
    nAnchoTabla=90
    ImprimeLineaAlineada "c" "=" "${nAnchoTabla}" " Resumen del proceso realizado " | tee -a "${fArchivoLog}"
    sCabecera=$(printf "%-25s %-36s %-10s %-12s %-12s %15s" "Subido Por" "Título" "Tipo" "Fecha" "Subtítulos" "Vistas")
    echo -e "${aCL['bmagenta']}${sCabecera}${aCL['noColor']}" | tee -a "${fArchivoLog}"
    ImprimeLineaAlineada "c" "~" "${nAnchoTabla}" "" | tee -a "${fArchivoLog}"
    echo 'Uploader,Titulo,Tipo,Fecha,Subtitulos,Vistas,URL' > "vidop-itcomm.csv"
    for json in *.info.json; do
        base="${json%.info.json}"
        tipo=""
        if [[ -f "$base.mp4" || -f "$base.mkv" || -f "$base.webm" ]]; then
            tipo="Video"
            ((nNumVideos++))
        elif [[ -f "$base.mp3" || -f "$base.m4a" || -f "$base.aac" ]]; then
            tipo="Audio"
            ((nNumAudios++))
        else
            continue
        fi
        shopt -s nullglob
        sSubs="No"
        nSrt=( "$base"*.srt )
        if (( ${#nSrt[@]} )); then
            sSubs="Sí"
            ((nNumSubtitulos++))
        fi
        shopt -u nullglob

        sUploader=$(jq -r '.uploader // "N/A"' "$json")
        sTituloRaw=$(jq -r '.title // "N/A"' "$json")
        sId=$(jq -r '.id // "N/A"' "$json")
        sExtFile=$(jq -r '.ext // "N/A"' "$json")
        sFecha=$(jq -r '.upload_date // "N/A"' "$json")
        nViewCount=$(jq -r '.view_count // "N/A"' "$json")
        sUrlExacta=$(jq -r '.webpage_url // "N/A"' "$json")

        sTitulo=$(echo "${sTituloRaw}" | head -c 36)
        sFechaFmt="${sFecha}"
        [[ "${sFecha}" != "N/A" && "${#sFecha}" -eq 8 ]] && sFechaFmt="${sFecha:0:4}-${sFecha:4:2}-${sFecha:6:2}"

        sVistasFmt=""
        if [[ "${nViewCount}" != "N/A" && "${nViewCount}" =~ ^[0-9]+$ ]]; then
            sVistasFmt=$(printf "%'d" "${nViewCount}" | sed "s/,/${sSeparadorMiles}/g")
            sVistasFmt=$(printf "%15s" "${sVistasFmt}")
        else
            sVistasFmt=$(printf "%15s" "N/A")
        fi

        printf "${aCL['bcyan']}%-25s %-36s %-10s %-12s %-12s %15s${aCL['noColor']}\n" \
            "$sUploader" "$sTitulo" "$tipo" "$sFechaFmt" "$sSubs" "$sVistasFmt" | tee -a "${fArchivoLog}"
        echo "\"${sUploader//\"/}\""','"$(echo "${sTituloRaw//\"/}")"','"${tipo}","${sFechaFmt}","${sSubs}","${nViewCount}","${sUrlExacta}" >> "vidop-itcomm.csv"
    done

    ImprimeLineaAlineada "c" "-" "${nAnchoTabla}" "" | tee -a "${fArchivoLog}"
    echo -e "${aCL['byellow']}Videos: ${nNumVideos}  Audios: ${nNumAudios}  Subtítulos: ${nNumSubtitulos}${aCL['noColor']}" | tee -a "${fArchivoLog}"
    echo -e "${aCL['bgreen']}Archivos y log en: $(pwd)${aCL['noColor']}" | tee -a "${fArchivoLog}"
    nErrores=$(grep -c ERROR "${fArchivoLog}" || true)
    if (( nErrores > 0 )); then
        echo -e "${aCL['bred']}Se detectaron errores. Consulta el log: ${fArchivoLog}${aCL['noColor']}"
    fi
    ImprimeLineaAlineada "c" "=" "${nAnchoTabla}" "" | tee -a "${fArchivoLog}"
fi

#######################################################################
# Finalizar dejando como directorio activo la carpeta de trabajo
if [[ "${bError}" -eq 0 ]]; then
    LogMsg OK "Listo el procesamiento indicado."
    exec </dev/tty 2>/dev/null
    exit 0
else
    LogMsg ERROR "Hubo algunos errores, revisa el log."
    exec </dev/tty 2>/dev/null
    exit 1
fi

##############################[ 📅 CHANGELOG ]##############################
# ChangeLog. Cambios relevantes:
# 20250812 Cookies del Navegador Chrome o Firefox (ojo: Del perfil DEFAULT)
# 20250805 Integra arte y notificaciones de nuevas herramientas en update
# 20250805 Función ValidarDependencias(), bloque git clone sin output
# 20250804 Verificacion de versiones desde github raw (sin API JSON) y actualización por git temporal en directorio único
# 20250803 Corrección: conteo y tablas trabajar siempre situado en la carpeta de trabajo
# 20250803 CSV generado en carpeta de trabajo, incluyendo encabezado y filas
# 20250803 Listado de formatos con --list-formats si no es playlist, para info en log
# 20250803 Agregada columna URL al CSV reportado para auditoría y postproceso OSINT
# 20250802 Detectar el tipo de archivo (audio/video) con el archivo físico, no por la metadata del JSON
# 20250801 Log siempre con timestamps y progreso incluído, ubicado en la carpeta de los archivos descargados
# 20250801 Resumen avanzado: videos/audios descargados, errores, ubicación, frames extraídos y cantidad de subtítulos
# 20250801 Aviso proactivo de nueva versión, sólo con -a/--actualizar. Validación/filtro de parametros
# 20250726 Nuevo parámetro --st/--subs para obtenerlos si estan disponibles en archivos .srt externos, idioma configurable
# 20250725 Manejo de -s/--seccion para porciones del video 
# 20250701 Mnemonicos de color homogéneos
# 20250701 Colores en la ayuda, error parpadeante y resumen tabular final amigable
