#!/bin/bash
# ViDoP - Video Downloader & Processor
# (c) 2025    Luis Ángel Ortega      https://linkedin.com/in/ortgas      https://github.com/ticnocrata      Created:   20230905
# Licencia: Uso no comercial con atribución y participación comercial (ver LICENSE.txt)
# Proyecto: https://github.com/ticnocrata/ViDoP
# Esta herramienta puede ser USADA y MODIFICADA para fines personales o no comerciales.
# Para uso con fines de lucro, se requiere licencia comercial del autor.
# LastUpdate: 20250805v1.1
LastUpdate="20250805v1.1"

#set -e
set +m

#######################################################################
# Manejo de Colores con mnemonicos para facilidad de secuencias ANSI 
declare -A aCOLOR=(
    # Normal					Bold					Subrayado				Fondo
    ['cblack']='\e[0;30m'		['bblack']='\e[1;30m'		['ublack']='\e[4;30m'		['on_black']='\e[40m'
    ['cred']='\e[0;31m'			['bred']='\e[1;31m'		['ured']='\e[4;31m'		['on_red']='\e[41m'
    ['cgreen']='\e[0;32m'		['bgreen']='\e[1;32m'		['ugreen']='\e[4;32m'		['on_green']='\e[42m'
    ['cyellow']='\e[0;33m'		['byellow']='\e[1;33m'	['uyellow']='\e[4;33m'	['on_yellow']='\e[43m'
    ['cblue']='\e[0;34m'		['bblue']='\e[1;34m'		['ublue']='\e[4;34m'		['on_blue']='\e[44m'
    ['cmagenta']='\e[0;35m'	['bmagenta']='\e[1;35m'	['umagenta']='\e[4;35m'	['on_purple']='\e[45m'
    ['ccyan']='\e[0;36m'		['bcyan']='\e[1;36m'		['ucyan']='\e[4;36m'		['on_cyan']='\e[46m'
    ['cwhite']='\e[0;37m'		['bwhite']='\e[1;37m'		['uwhite']='\e[4;37m'		['on_white']='\e[47m'
    # Combos útiles y reset
    ['alert']='\e[1;37m\e[41m'	['noColor']='\e[0m'
)
if ! [ -t 1 ]; then
    for sColorClave in "${!aCOLOR[@]}"; do
       aCOLOR["${sColorClave}"]=""
    done
fi

#######################################################################
# Validación de dependencias externas indispensables para que funcione esta herramienta
aDependenciasReq=(yt-dlp ffmpeg jq curl base64)
for sDependencia in "${aDependenciasReq[@]}"; do
    if ! command -v "${sDependencia}" >/dev/null 2>&1; then
        echo -e "${aCOLOR['alert']}Falta dependencia requerida: ${sDependencia}${aCOLOR['noColor']}"
        exit 2
    fi
done

#######################################################################
# Variables globales necesarias, valores defaults y otras inicializaciones
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
nNumFrames=""
fArchivoLog=""
fDirectorioDescarga=""
sDirectorioOriginal="$(pwd)"
# RAW github del script principal (ofuscado base64, sin JSON API)
fRawScript="$(echo aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL3RpY25vY3JhdGEvVmlEb1AvbWFpbi9WaURvUC5zaA== | base64 -d 2>/dev/null || true)"
uNoti="$(echo aHR0cDovL21haWxpbmcuaXRjb21tLm14L3N1YnNjcmliZQo= | base64 -d 2>/dev/null || true)"
fScriptLocal="$0"

#######################################################################
# Rutina de registro para el log y para la pantalla.
LogMsg() {
    local sTipo="$1" sMsg="$*"
    local sColor sPrefix
    case "${sTipo}" in
        INFO)   sColor="${aCOLOR['bblue']}";       sPrefix="[INFO]       ";;
        OK)     sColor="${aCOLOR['bgreen']}";      sPrefix="[OK]         ";;
        ERROR)  sColor="${aCOLOR['bred']}";        sPrefix="[ERROR]      ";;
        KILL)   sColor="${aCOLOR['byellow']}";     sPrefix="[KILL]       ";;
        TREE)   sColor="${aCOLOR['bcyan']}";       sPrefix="[TREE]       ";;
        ALERTA) sColor="${aCOLOR['alert']}";       sPrefix="[ALERTA]     ";;
        UPDATE) sColor="${aCOLOR['bmagenta']}";    sPrefix="[UPDATE]     ";;
        *)      sColor="${aCOLOR['bwhite']}";      sPrefix="[MSG]        ";;
    esac
    local sTS="[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo -e "${sColor}${sTS} ${sPrefix}${sMsg}${aCOLOR['noColor']}"
    if [[ -n "${fArchivoLog}" && -n "${fDirectorioDescarga}" ]]; then
        local fDirParent
        fDirParent="$(dirname -- "${fArchivoLog}")"
        if [[ -d "${fDirectorioDescarga}" && -d "${fDirParent}" ]]; then
            echo -e "${sTS} ${sPrefix}${sMsg}" >> "${fArchivoLog}"
        fi
    fi
} #LogMsg

#######################################################################
# Rutina para texto alineado (izquierda, centro, derecha)
ImprimeLineaAlineada() {
    local sAlineacion="$1" sCaracter="$2" nLargo="$3" sMensaje="${4:-}"
    local nLargoMsg=${#sMensaje}
    local sLinea=""
    if [[ "$nLargoMsg" -ge "$nLargo" ]]; then
        sLinea="${sMensaje:0:$nLargo}"
    else
        local nRelleno=$((nLargo - nLargoMsg))
        case "$sAlineacion" in
            i)
                sLinea="${sMensaje}$(printf "%0.s$sCaracter" $(seq 1 $nRelleno))"
                ;;
            d)
                sLinea="$(printf "%0.s$sCaracter" $(seq 1 $nRelleno))${sMensaje}"
                ;;
            c|*)
                local nPreFill=$((nRelleno / 2))
                local nPostFill=$((nRelleno - nPreFill))
                sLinea="$(printf "%0.s$sCaracter" $(seq 1 $nPreFill))${sMensaje}$(printf "%0.s$sCaracter" $(seq 1 $nPostFill))"
                ;;
        esac
    fi
    echo -e "$sLinea"
} #ImprimeLineaAlineada

#######################################################################
# Mostrar la ayuda de la herramienta
AsciiArt() {
    local sBanner="${aCOLOR['bmagenta']}" sArt="${aCOLOR['bcyan']}" sURL="${aCOLOR['bmagenta']}" sReset="${aCOLOR['noColor']}" sToolName="${aCOLOR['byellow']}"
    printf "${sBanner}(c) Luis Angel Ortega     ${sToolName}Video Downloader and Processor ${sBanner}ViDoP${sReset}\n"
    printf "${sArt}                                   '''\n"
    printf "                                  (O O)\n"
    printf "                    +---------oOO--(_)---------------+\n"
    printf "                    |                                |\n"
    printf "                    |${sURL} https://linkedin.com/in/ortgas ${sArt}|\n"
    printf "                    |                                |\n"
    printf "                    +--------------------oOO---------+\n"
    printf "                                 |__|__|\n"
    printf "                                  || ||\n"
    printf "                                 ooO Ooo\n"
    printf "${sReset}\n"
} #AsciiArt
MostrarAyuda() {
    local sUso="${aCOLOR['bgreen']}" sParam="${aCOLOR['byellow']}" sVal="${aCOLOR['bcyan']}" sDesc="${aCOLOR['bwhite']}" sEjemplo="${aCOLOR['bgreen']}" sReset="${aCOLOR['noColor']}"
    AsciiArt
    printf "Uso: ${sUso}$(basename "$0")${sReset} -u ${sUso}URL${sReset} [-m MODO] [-q CALIDAD] [-f [Ns|all]] [-s INI-FIN] [--st [idioma]] [-a]\n"
    printf "\n"
    printf "${sDesc}Opciones:${sReset}\n"
    printf "  ${sParam}-u, --url URL         ${sDesc}Video o playlist a descargar.${sReset}\n"
    printf "  ${sParam}-m, --modo MODO       ${sDesc}audio, video, ambos. Default:${sVal} ambos${sDesc}.${sReset}\n"
    printf "  ${sParam}-q, --calidad         ${sDesc}best, 1080, 720, etc. Default:${sVal} best${sDesc}.${sReset}\n"
    printf "  ${sParam}-f, --frames [OPC]    ${sVal}all${sDesc}|${sVal} Ns${sDesc} (ej. 10s) para extracción frames OSINT. Si solo usas -f extrae todos.${sReset}\n"
    printf "  ${sParam}-s, --seccion INI-FIN ${sDesc}Solo descargar sección de video (ej: 00:01:00-00:03:00).${sReset}\n"
    printf "  ${sParam}-st, --subs [IDIOMA]  ${sDesc}Descargar subtítulos .srt externos. Si omites IDIOMA, trataremos con el nativo.${sReset}\n"
    printf "  ${sParam}-a, --actualizar      ${sDesc}Efectuar actualización automática de la herramienta (si hay nueva versión).${sReset}\n"
    printf "  ${sParam}-h, --help            ${sDesc}Esta ayuda.${sReset}\n"
    printf "\n"
    printf "${sEjemplo}Ejemplos:${sReset}\n"
    printf "  ${sVal}%s -u URL -m video -q 720${sReset} ${sDesc} para calidad 720p\n" "$(basename "$0")"
    printf "  ${sVal}%s -u URL -f${sReset}  ${sDesc} para extraer todos los frames\n" "$(basename "$0")"
    printf "  ${sVal}%s -u URL -f 5s${sReset}  ${sDesc} para un frame cada 5 segundos\n" "$(basename "$0")"
    printf "  ${sVal}%s -u URL -st es${sReset}  ${sDesc} descarga .srt en español \n" "$(basename "$0")"
    printf "\n"
    if [[ -n "$1" ]]; then
        echo -e "${aCOLOR['alert']}Error: $1${aCOLOR['noColor']}\n"
        LogMsg ERROR "$1"
    fi
    exit 0
} #MostrarAyuda

#######################################################################
# Gestionar las actualizaciones (lectura directa desde RAW)
CheckUpdate() {
    LogMsg UPDATE "Verificando actualización contra script directo RAW..."
    LogMsg INFO "Leyendo raw desde ${fRawScript}"
    local sRemoteDate
    sRemoteDate="$(curl -fsSL --max-time 12 "${fRawScript}" 2>/dev/null | head -20 | grep -m1 '^# LastUpdate:' | awk '{print $3}')"
    if [[ -z "$sRemoteDate" ]]; then
        LogMsg UPDATE "No se pudo leer el LastUpdate remoto desde el script raw (${fRawScript})."
        return 2
    fi
    LogMsg INFO "LastUpdate remoto: $sRemoteDate || Local: $LastUpdate"
    if [[ "$sRemoteDate" != "$LastUpdate" ]]; then
        LogMsg UPDATE "¡Hay NUEVA VERSIÓN! ($sRemoteDate). Ejecuta con -a para actualizar."
        export VSCRIPT_NEW_URL="$fRawScript"
        export VSCRIPT_NEW_LU="$sRemoteDate"
        return 1
    else
        LogMsg OK "Tu herramienta está AL DÍA. (LastUpdate igual: $LastUpdate)"
        return 0
    fi
} #CheckUpdate

AutoActualizar() {
    if [[ -z "$VSCRIPT_NEW_URL" ]]; then
        LogMsg ERROR "No se detectó URL de nueva versión. Ejecuta primero CheckUpdate."
        return 1
    fi
    local dScriptDir
    dScriptDir="$(cd "$(dirname -- "$0")" && pwd)"
    local fTmpNew="${dScriptDir}/ViDoP.sh.itcomm"

    LogMsg UPDATE "Descargando nueva versión del script a $fTmpNew"
    if ! curl -fsSL --max-time 20 -o "$fTmpNew" "$VSCRIPT_NEW_URL"; then
        LogMsg ERROR "ERROR de descarga. Revisa conexión, permisos o URL."
        [[ -f "$fTmpNew" ]] && rm -f "$fTmpNew"
        return 1
    fi
    local sNewUpdate
    sNewUpdate="$(grep -m1 '^# LastUpdate:' "$fTmpNew" | awk '{print $3}')"
    LogMsg UPDATE "Marcador en descargado: $sNewUpdate"
    if [[ -z "$sNewUpdate" ]]; then
        LogMsg ERROR "No se encontró LastUpdate en el script descargado."
        rm -f "$fTmpNew"
        return 1
    fi
    if [[ "$sNewUpdate" == "$LastUpdate" ]]; then
        LogMsg OK "Ya tienes la última versión."
        rm -f "$fTmpNew"
        return 0
    fi

    # Reemplazo de la herramienta actual, con seguridad
    local fScriptActivo="${dScriptDir}/$(basename -- "$0")"
    LogMsg UPDATE "Sustituyendo la herramienta actual por la nueva versión..."
    if cp -f "$fTmpNew" "$fScriptActivo"; then
        chmod +x "$fScriptActivo"
        rm -f "$fTmpNew"
        LogMsg OK "¡Actualización exitosa! Por favor vuelve a ejecutar la herramienta."
        exit 0
    else
        LogMsg ERROR "No fue posible reemplazar la herramienta. Se conserva la anterior."
        rm -f "$fTmpNew"
        exit 2
    fi
} #AutoActualizar

#######################################################################
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
# Aqui comienza la acción!
echo -e "${aCOLOR['byellow']}Procurando determinar la naturaleza de la URL ${sUrl} ${aCOLOR['bcyan']}${aCOLOR['noColor']}"
sYtDlpResult=$(yt-dlp --flat-playlist --skip-download"${sUrl}" 2>&1 || true) #Trae info de la URL, sin descargar
if echo "${sYtDlpResult}" | grep -q '\[playlist\]' || [[ "${sUrl}" == *"playlist"* ]]; then
    bEsPlaylist=1
    sNombrePlaylist=$(yt-dlp --flat-playlist --print "%(playlist_title)s" "${sUrl}" 2>&1 | head -1 | sed 's/[ \/\\:*?"<>|]/_/g' | sed 's/[^A-Za-z0-9._-]/_/g')
    fDirectorioDescarga="${sNombrePlaylist:-Playlist_$(date +%s)}"
    mkdir -p "${fDirectorioDescarga}"
    fArchivoLog="${sDirectorioOriginal}/${fDirectorioDescarga}/vidop-itcomm.log"
    > "${fArchivoLog}"
    LogMsg OK "Intentaré procesar la playlist: ${aCOLOR['bcyan']}${sNombrePlaylist} ${aCOLOR['noColor']}"
else
    bEsPlaylist=0
    sTituloTmp=$(yt-dlp --get-title --skip-download "${sUrl}" 2>/dev/null | head -1) #Trae el titulo del archivo en caso de que tenga, sin descargarlo 
    sIdTmp=$(yt-dlp --get-id --skip-download "${sUrl}" 2>/dev/null | head -1) #Trae id del archivo, sin descargarlo
    sNomUnico=""
    #Crea la carpeta de trabajo, conforme el nombre o el ID del video
    if [[ -n "$sTituloTmp" ]]; then
        sNomUnico="$(echo "${sTituloTmp:0:20}" | sed 's/[^A-Za-z0-9._-]/_/g' | sed 's/^[ _-]*//;s/[ _-]*$//')"
    else
        sNomUnico="Video_${sIdTmp:0:8}"
    fi
    fDirectorioDescarga="${sNomUnico:-Video_$(date +%s)}"
    mkdir -p "${fDirectorioDescarga}"
    fArchivoLog="${sDirectorioOriginal}/${fDirectorioDescarga}/vidop-itcomm.log"
    > "${fArchivoLog}"
    LogMsg INFO "Intentaré procesar un archivo de video. Carpeta: ${aCOLOR['bcyan']}${fDirectorioDescarga}${aCOLOR['noColor']}"
fi

#######################################################################
# Validar que no pidas sección de un video (cachito) si estas procesando una playlist
if [[ "${bEsPlaylist}" -eq 1 && -n "${sSeccion}" ]]; then
    MostrarAyuda "No se puede usar -s/--seccion con playlists. Solo con videos individuales."
fi

#######################################################################
# Construcción y ejecución del comando para la descarga
# Cambia a la carpeta de trabajo
cd "${sDirectorioOriginal}/${fDirectorioDescarga}"
LogMsg INFO "Carpeta de trabajo: ${sDirectorioOriginal}/${fDirectorioDescarga}"

aComandoYtDlp=(
    yt-dlp
    --add-header "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
    --write-info-json --no-warnings --progress --newline
    -P "."
) #Opciones BASE para descarga

# y ahora, analizamos las SUBOPCIONES pertinentes
if [[ -n "${sSeccion}" ]]; then
    aComandoYtDlp+=(--download-sections "*${sSeccion}")
fi
case "${sModo,,}" in
    audio)
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
# Snapshot  de los archivos de video presentes, ANTES de ejecutar la descarga
mapfile -d '' -t aArchivosAntes < <(find . -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.webm" \) -printf "%f\0")
LogMsg TREE "Archivos antes: $(printf '%q ' "${aArchivosAntes[@]}")"
LogMsg OK "Inicio de descarga multimedia, modalidad ${sModo} (calidad: ${sCalidad}), destino [$(pwd)]"
"${aComandoYtDlp[@]}" "${sUrl}" 2>&1 | tee -a "${fArchivoLog}" || bError=1
# Snapshot después de descarga (igual que antes, solo en subcarpeta de trabajo)
mapfile -d '' -t aArchivosDespues < <(find . -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.webm" \) -printf "%f\0")
LogMsg TREE "Archivos despues: $(printf '%q ' "${aArchivosDespues[@]}")"
#######################################################################
# Si se solicitaron, extrae frames desde los videos generados 
if [[ -n "${nNumFrames}" ]]; then
    LogMsg INFO "Procesando solicitud de fotogramas para los archivos de video descargados"
    declare -A aArchivosAntesMap
    for fArchivo in "${aArchivosAntes[@]}"; do aArchivosAntesMap["${fArchivo}"]=1; done
    #Detecta los archivos, nutre el array y crea la subcarpeta
    aVideosNuevos=()
    for fArchivo in "${aArchivosDespues[@]}"; do
        [[ "${fArchivo}" =~ \.mp4$|\.mkv$|\.webm$ ]] || continue
        if [[ -z "${aArchivosAntesMap["${fArchivo}"]}" ]]; then
            LogMsg OK "Identificado como nuevo, archivo: ${fArchivo}"
            aVideosNuevos+=("${fArchivo}")
            # Calcula el nombre único de subcarpeta para los frames de este archiv
            sNomUnico=""
            sNomUnico="$(echo "${fArchivo:0:20}" | sed 's/[^A-Za-z0-9._-]/_/g' | sed 's/^[ _-]*//;s/[ _-]*$//')"
            #Crea la carpeta de trabajo
            mkdir -p "${sNomUnico}"
            LogMsg OK "Creada la subcarpeta: ${sNomUnico}"
        fi
    done
    for fVideoArchivo in "${aVideosNuevos[@]}"; do
        LogMsg INFO "Intentando extraer frames del archivo: ${fVideoArchivo}"
        sNomUnico="$(echo "${fVideoArchivo:0:20}" | sed 's/[^A-Za-z0-9._-]/_/g' | sed 's/^[ _-]*//;s/[ _-]*$//')"   #Mismo criterio que el anterior, para la carpeta frames
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
    # Asegurate de  estar en el directorio de trabajo
    cd "${sDirectorioOriginal}/${fDirectorioDescarga}"
    nNumVideos=0
    nNumAudios=0
    nNumSubtitulos=0
    sSeparadorMilesLocal=$(locale thousands_sep 2>/dev/null)
    sSeparadorMiles="${sSeparadorMilesLocal:-','}"
    nAnchoTabla=90
    ImprimeLineaAlineada "c" "=" "${nAnchoTabla}" " Resumen del proceso realizado " | tee -a "${fArchivoLog}"
    sCabecera=$(printf "%-25s %-36s %-10s %-12s %-12s %15s" "Subido Por" "Título" "Tipo" "Fecha" "Subtítulos" "Vistas")
    echo -e "${aCOLOR['bmagenta']}${sCabecera}${aCOLOR['noColor']}" | tee -a "${fArchivoLog}"
    ImprimeLineaAlineada "c" "~" "${nAnchoTabla}" "" | tee -a "${fArchivoLog}"
    echo 'Uploader,Titulo,Tipo,Fecha,Subtitulos,Vistas,URL' > "vidop-itcomm.csv"
    #Contabilizar archivos
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

        printf "${aCOLOR['bcyan']}%-25s %-36s %-10s %-12s %-12s %15s${aCOLOR['noColor']}\n" \
            "$sUploader" "$sTitulo" "$tipo" "$sFechaFmt" "$sSubs" "$sVistasFmt" | tee -a "${fArchivoLog}"
        echo "\"${sUploader//\"/}\""','"$(echo "${sTituloRaw//\"/}")"','"${tipo}","${sFechaFmt}","${sSubs}","${nViewCount}","${sUrlExacta}" >> "vidop-itcomm.csv"
    done

    ImprimeLineaAlineada "c" "-" "${nAnchoTabla}" "" | tee -a "${fArchivoLog}"
    echo -e "${aCOLOR['byellow']}Videos: ${nNumVideos}  Audios: ${nNumAudios}  Subtítulos: ${nNumSubtitulos}${aCOLOR['noColor']}" | tee -a "${fArchivoLog}"
    echo -e "${aCOLOR['bgreen']}Archivos y log en: $(pwd)${aCOLOR['noColor']}" | tee -a "${fArchivoLog}"
    nErrores=$(grep -c ERROR "${fArchivoLog}" || true)
    if (( nErrores > 0 )); then
        echo -e "${aCOLOR['bred']}Se detectaron errores. Consulta el log: ${fArchivoLog}${aCOLOR['noColor']}"
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

#######################################################################
# ChangeLog. Cambios relevantes:
# 20250701 Colores en la ayuda, error parpadeante y resumen tabular final amigable
# 20250701 Mnemonicos de color homogéneos
# 20250725 Manejo de -s/--seccion y parámetros robusto
# 20250826 Descarga siempre real; resumen sólo con archivos descargados
# 20250827 Nuevo parámetro --st/--subs para obtenerlos si estan disponibles en archivos .srt externos, idioma configurable
# 20250801 Log siempre con timestamps y progreso incluído, ubicado en la carpeta de los archivos descargados
# 20250801 Resumen avanzado: videos/audios descargados, errores, ubicación, frames extraídos y cantidad de subtítulos
# 20250801 Aviso proactivo de nueva versión, sólo con -a/--actualizar. Validación/filtro avanzado y robustez de frame extraction (find)
# 20250802 Detectar el tipo de archivo (audio/video) con el archivo físico, no por la metadata del JSON
# 20250803 Corrección: conteo y tablas trabajan siempre en la carpeta de trabajo
# 20250803 CSV generado  en carpeta de trabajo, incluyendo encabezado y filas
# 20250803 Listado de formatos con --list-formats si no es playlist, para info en log
# 20250803 Agregada columna URL al CSV reportado para auditoría y postproceso OSINT
# 20250804 Actualización directa desde github raw (sin API JSON)
