#!/bin/bash
# main.sh
# =============================================================================
# Script Recursivo para Conversão de Vídeos para HEVC com VAAPI com Interface
# Gráfica de Terminal (TUI) para monitoramento em tempo real.
#
# Funcionalidades:
# - Varredura recursiva no diretório base e subpastas.
# - Conversão usando VAAPI, redimensionando para no máximo 1080p.
# - Remoção do arquivo original somente se a conversão for concluída com sucesso.
# - Verificação se o vídeo já está em HEVC ou se o convertido já existe.
# - Interface de terminal com informações de progresso e tempo estimado.
# - Tratamento de erros melhorado e logging.
# - Tratamento de interrupção (CTRL+C).
# - Parâmetros configuráveis via linha de comando.
# - Modo dry-run para simulação.
# - Suporte aprimorado para nomes de arquivos com espaços e caracteres especiais.
# - Verificações de permissões e arquivos.
# - Fallbacks matemáticos para sistemas sem bc.
# - Escolha entre codificação VBR ou CBR para áudio.
# - Níveis predefinidos de bitrate (1-5) para facilitar a configuração.
# 
# =============================================================================
# Script principal para conversão de vídeos para HEVC com VAAPI.
# =============================================================================

# Carrega as configurações e funções
source "./config.sh"
source "./utils.sh"

# ============================ Função de Uso ============================
while getopts "d:e:s:v:m:q:a:b:l:f:r:t:c:nh" opt; do
    case "$opt" in
        d) INPUT_DIR="$OPTARG" ;;
        e) FILE_EXT="$OPTARG" ;;
        s) OUTPUT_SUFFIX="$OPTARG" ;;
        v) VAAPI_DEVICE="$OPTARG" ;;
        m) MAX_HEIGHT="$OPTARG" ;;
        q) QP="$OPTARG" ;;
        a) AUDIO_CODEC="$OPTARG" ;;
        b) AUDIO_BITRATE="$OPTARG" ;;
        l) LOG_FILE="$OPTARG" ;;
        f) MIN_FREE_SPACE="$OPTARG" ;;
        r) BITRATE_LEVEL="$OPTARG" ;;
        t) AUDIO_MODE="$OPTARG" ;;
        c) CHANNEL_LAYOUT="$OPTARG" ;;
        n) DRY_RUN=1 ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Verificações iniciais
trap cleanup SIGINT SIGTERM
check_requirements

[[ ! -d "$INPUT_DIR" ]] && {
    echo -e "\033[1;31mErro: Diretório de entrada não encontrado: $INPUT_DIR\033[0m"
    log "ERROR" "Diretório de entrada não encontrado: $INPUT_DIR"
    exit 1
}

[[ "$DRY_RUN" -eq 0 ]] && check_vaapi_device
check_disk_space "$INPUT_DIR"

log "INFO" "Iniciando conversão de vídeos em $INPUT_DIR (modo: $([ "$DRY_RUN" -eq 1 ] && echo 'simulação' || echo 'real'))"
log "INFO" "Configurações de áudio: Modo=$AUDIO_MODE, Codec=$AUDIO_CODEC, Bitrate=$AUDIO_BITRATE (Nível $BITRATE_LEVEL, canais $CHANNEL_LAYOUT)"
echo -e "\033[1;34mProcurando arquivos .$FILE_EXT em $INPUT_DIR e subdiretórios...\033[0m"

# Busca os arquivos de vídeo
mapfile -d $'\0' -t files < <(find_video_files "$INPUT_DIR" "$FILE_EXT")
TOTAL=${#files[@]}
[[ $TOTAL -eq 0 ]] && {
    echo -e "\033[1;33mNenhum arquivo .$FILE_EXT encontrado.\033[0m"
    log "INFO" "Nenhum arquivo .$FILE_EXT encontrado"
    exit 0
}

echo -e "\033[1;32mEncontrados $TOTAL arquivos para processamento.\033[0m"
log "INFO" "Encontrados $TOTAL arquivos para processamento"
sleep 1

CURRENT=0
START_TIME=$(date +%s)
SKIPPED=0
CONVERTED=0
ERRORS=0
TOTAL_SAVED=0

for file in "${files[@]}"; do
    CURRENT=$((CURRENT+1))
    log "DEBUG" "Iniciando processamento do arquivo: $file"

    # Verifica se o arquivo existe e é legível
    if [[ ! -f "$file" || ! -r "$file" ]]; then
        log "ERROR" "Arquivo não existe ou não é legível: $file"
        ERRORS=$((ERRORS+1))
        continue
    fi

    # Verifica se o arquivo já está em HEVC (ou QSV convertido)
    if is_hevc_codec "$file"; then
        log "INFO" "Arquivo já em HEVC, pulando: $file"
        SKIPPED=$((SKIPPED+1))
        continue
    fi

    # Define o nome do arquivo convertido mantendo o diretório original
    output="${file%.$FILE_EXT}$OUTPUT_SUFFIX.$FILE_EXT"
    output_dir=$(dirname "$output")
    if ! check_write_permissions "$output_dir"; then
        log "ERROR" "Sem permissão de escrita no diretório: $output_dir"
        ERRORS=$((ERRORS+1))
        continue
    fi
    if [[ -f "$output" ]]; then
        log "INFO" "Arquivo convertido já existe, pulando: $output"
        SKIPPED=$((SKIPPED+1))
        continue
    fi

    # Atualiza a interface de usuário e calcula tempo decorrido
    CUR_TIME=$(date +%s)
    ELAPSED=$((CUR_TIME - START_TIME))
    AVG=$(calculate_avg "$ELAPSED" "$CURRENT")
    percent=$(( CURRENT * 100 / TOTAL ))
    REMAINING=$(calc "($TOTAL - $CURRENT) * $AVG")
    update_ui "$file" "$CURRENT" "$TOTAL" "$percent" "$AVG" "$REMAINING" "$ELAPSED"

    log "INFO" "Preparando para converter via QSV: $file"
    log "DEBUG" "Parâmetros de conversão: MAX_HEIGHT=$MAX_HEIGHT, QP=$QP, AUDIO_CODEC=$AUDIO_CODEC, AUDIO_MODE=$AUDIO_MODE, BITRATE_LEVEL=$BITRATE_LEVEL, CHANNEL_LAYOUT=$CHANNEL_LAYOUT"

    # Se estiver em modo de simulação (dry-run), apenas simula
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo -e "\033[1;33m[DRY-RUN] Simulando conversão de: $(basename "$file")\033[0m"
        log "INFO" "[DRY-RUN] Simulação de conversão: $file"
        sleep 1
        CONVERTED=$((CONVERTED+1))
    else
        # Obter os parâmetros de áudio chamando a função do utils.sh
        AUDIO_PARAMS=$(configure_audio_params "$AUDIO_MODE" "$AUDIO_CODEC" "$BITRATE_LEVEL" "$CHANNEL_LAYOUT")

        log "DEBUG" "Executando comando ffmpeg para conversão via QSV..."
        ffmpeg -hwaccel qsv -hwaccel_output_format qsv -c:v h264_qsv -i "$file" \
            -vf "vpp_qsv=denoise=10,scale_qsv=w=-1:h=$MAX_HEIGHT" \
            -c:v hevc_qsv -global_quality "$QP" $AUDIO_PARAMS \
            -map 0 -map_metadata 0 -movflags +faststart "$output" 2>/dev/null
        ffmpeg_exit_code=$?
        log "DEBUG" "Comando ffmpeg retornou código: $ffmpeg_exit_code"

        if [[ $ffmpeg_exit_code -eq 0 ]]; then
            if check_duration "$file" "$output"; then
                if original_size=$(du -k "$file" 2>/dev/null | cut -f1) && \
                   converted_size=$(du -k "$output" 2>/dev/null | cut -f1); then
                    space_saved=$((original_size - converted_size))
                    TOTAL_SAVED=$((TOTAL_SAVED + space_saved))
                    reduction_percent=$(calc "($space_saved / $original_size) * 100")
                    log "INFO" "Conversão bem-sucedida via QSV: $file -> $output (Redução: ${reduction_percent}%, Economia: $((space_saved / 1024))MB)"
                    log "DEBUG" "Tamanho original: ${original_size}KB, Tamanho convertido: ${converted_size}KB"

                    if [[ -w "$(dirname "$file")" ]]; then
                        rm "$file"
                        log "INFO" "Arquivo original removido: $file"
                    else
                        log "WARNING" "Sem permissão para remover o arquivo original: $file"
                    fi
                    CONVERTED=$((CONVERTED+1))
                else
                    log "ERROR" "Não foi possível obter tamanho dos arquivos para: $file"
                    ERRORS=$((ERRORS+1))
                fi
            else
                log "ERROR" "Diferença de duração acima do tolerado para: $file"
                if [[ -w "$output_dir" ]]; then
                    rm "$output"
                    log "INFO" "Arquivo de saída removido por inconsistência: $output"
                else
                    log "WARNING" "Sem permissão para remover arquivo inconsistente: $output"
                fi
                ERRORS=$((ERRORS+1))
            fi
        else
            log "ERROR" "Falha na conversão via QSV: $file"
            if [[ -f "$output" && -w "$output_dir" ]]; then
                rm "$output"
                log "INFO" "Arquivo de saída com falha removido: $output"
            elif [[ -f "$output" ]]; then
                log "WARNING" "Sem permissão para remover arquivo parcial: $output"
            fi
            ERRORS=$((ERRORS+1))
        fi
    fi

    # Atualiza novamente a interface após a conversão
    CUR_TIME=$(date +%s)
    ELAPSED=$((CUR_TIME - START_TIME))
    AVG=$(calculate_avg "$ELAPSED" "$CURRENT")
    percent=$(( CURRENT * 100 / TOTAL ))
    REMAINING=$(calc "($TOTAL - $CURRENT) * $AVG")
    # Chama a função de UI passando o espaço economizado
    update_ui "$file" "$CURRENT" "$TOTAL" "$percent" "$AVG" "$REMAINING" "$ELAPSED" "$space_saved"
    sleep 1
done

# Relatório Final
clear
echo -e "\033[1;34m==============================================="
echo -e " Relatório de Conversão de Vídeos para HEVC"
echo -e "===============================================\033[0m"
echo -e "\033[1;32mTotal de arquivos processados:\033[0m $TOTAL"
echo -e "\033[1;32mArquivos convertidos com sucesso:\033[0m $CONVERTED"
echo -e "\033[1;32mArquivos pulados:\033[0m $SKIPPED"
echo -e "\033[1;31mErros de conversão:\033[0m $ERRORS"

if [[ $CONVERTED -gt 0 && $DRY_RUN -eq 0 ]]; then
    SAVED_MB=$(calc "$TOTAL_SAVED / 1024")
    SAVED_GB=$(calc "$SAVED_MB / 1024")
    echo -e "\033[1;32mEspaço total economizado:\033[0m ${SAVED_MB}MB (${SAVED_GB}GB)"
fi

echo -e "\033[1;32mTempo total decorrido:\033[0m $(format_time "$ELAPSED")"
[[ "$DRY_RUN" -eq 1 ]] && echo -e "\033[1;33mModo de simulação (dry-run) - Nenhum arquivo foi modificado\033[0m"
log "INFO" "Conversão concluída"
