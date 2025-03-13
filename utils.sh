#!/bin/bash
# utils.sh
# =============================================================================
# Funções utilitárias para o script de conversão de vídeos para HEVC.
# =============================================================================

# Função para logging
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" || {
        echo "Não foi possível escrever no arquivo de log $LOG_FILE"
        [[ "$level" == "ERROR" || "$level" == "WARNING" ]] && \
            echo -e "\033[1;31m[$level] $message\033[0m"
    }
    [[ "$level" == "ERROR" || "$level" == "WARNING" ]] && \
        echo -e "\033[1;31m[$level] $message\033[0m"
}

# Função para comparação de números de ponto flutuante
float_cmp() {
    local op="$1"
    local val1="$2"
    local val2="$3"
    if command -v bc &>/dev/null; then
        case "$op" in
            "-gt") return $(echo "$val1 > $val2" | bc -l) ;;
            "-lt") return $(echo "$val1 < $val2" | bc -l) ;;
            "-ge") return $(echo "$val1 >= $val2" | bc -l) ;;
            "-le") return $(echo "$val1 <= $val2" | bc -l) ;;
            "-eq") return $(echo "$val1 == $val2" | bc -l) ;;
            "-ne") return $(echo "$val1 != $val2" | bc -l) ;;
            *) echo "Operador desconhecido: $op"; return 2 ;;
        esac
    else
        local result
        case "$op" in
            "-gt") result=$(awk -v a="$val1" -v b="$val2" 'BEGIN { print (a > b) ? 1 : 0 }') ;;
            "-lt") result=$(awk -v a="$val1" -v b="$val2" 'BEGIN { print (a < b) ? 1 : 0 }') ;;
            "-ge") result=$(awk -v a="$val1" -v b="$val2" 'BEGIN { print (a >= b) ? 1 : 0 }') ;;
            "-le") result=$(awk -v a="$val1" -v b="$val2" 'BEGIN { print (a <= b) ? 1 : 0 }') ;;
            "-eq") result=$(awk -v a="$val1" -v b="$val2" 'BEGIN { print (a == b) ? 1 : 0 }') ;;
            "-ne") result=$(awk -v a="$val1" -v b="$val2" 'BEGIN { print (a != b) ? 1 : 0 }') ;;
            *) echo "Operador desconhecido: $op"; return 2 ;;
        esac
        [[ "$result" -eq 1 ]] && return 0 || return 1
    fi
}

# Função para cálculos matemáticos
calc() {
    local expr="$1"
    local result
    if command -v bc &>/dev/null; then
        result=$(echo "$expr" | bc -l)
    else
        result=$(awk "BEGIN { print $expr }")
    fi
    echo "${result:-0}"
}

# Verifica se os comandos necessários estão instalados
check_requirements() {
    local missing=0
    for cmd in ffmpeg ffprobe find; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "Erro: Comando '$cmd' não está instalado."
            log "ERROR" "Comando '$cmd' não encontrado"
            missing=1
        fi
    done
    command -v awk &>/dev/null || { echo "Aviso: 'awk' não encontrado."; log "WARNING" "Comando 'awk' não encontrado"; }
    command -v bc &>/dev/null || { echo "Aviso: 'bc' não encontrado."; log "WARNING" "Comando 'bc' não encontrado"; }
    (( missing == 1 )) && exit 1
}

# Função para verificar o espaço disponível em disco
check_disk_space() {
    local dir="$1"
    local avail
    
    if [[ ! -d "$dir" ]]; then
        log "WARNING" "Diretório não existe para verificar espaço: $dir"
        return 1
    fi
    
    avail=$(df -BG --output=avail "$dir" 2>/dev/null | tail -n1 | tr -d 'G')
    
    # Verifica se obtivemos um número válido
    if [[ ! "$avail" =~ ^[0-9]+$ ]]; then
        log "WARNING" "Não foi possível determinar o espaço disponível em $dir"
        return 0
    fi
    
    if (( avail < MIN_FREE_SPACE )); then
        log "ERROR" "Espaço em disco insuficiente em $dir: ${avail}GB disponível (mínimo necessário: ${MIN_FREE_SPACE}GB)"
        return 1
    fi
    return 0
}

# Verifica permissões de escrita no diretório
check_write_permissions() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        log "WARNING" "Diretório não existe: $dir"
        return 1
    fi
    if [[ ! -w "$dir" ]]; then
        log "ERROR" "Sem permissão de escrita no diretório: $dir"
        return 1
    fi
    local temp_file="$dir/.write_test_$RANDOM"
    if ! touch "$temp_file" 2>/dev/null; then
        log "ERROR" "Falha ao criar arquivo de teste em: $dir"
        return 1
    fi
    rm -f "$temp_file"
    return 0
}

# Desenha a barra de progresso
draw_progress() {
    local percent=$1
    local bar_width=50
    local filled=$(( percent * bar_width / 100 ))
    local empty=$(( bar_width - filled ))
    printf "["
    for ((i=0; i<filled; i++)); do printf "#"; done
    for ((i=0; i<empty; i++)); do printf " "; done
    printf "] %d%%\n" "$percent"
}

# Função para configurar os parâmetros de áudio
configure_audio_params() {
    local audio_mode="$1"
    local audio_codec="$2"
    local bitrate_level="$3"
    local channels="$4"  # Novo parâmetro para número de canais
    
    # Determina o bitrate ou qualidade com base no nível selecionado
    local audio_bitrate=""
    local audio_quality=""
    
    case "$bitrate_level" in
        1) 
            audio_bitrate="64k"
            audio_quality="1"
            ;;
        2) 
            audio_bitrate="96k"
            audio_quality="2"
            ;;
        3) 
            audio_bitrate="128k"
            audio_quality="3"
            ;;
        4) 
            audio_bitrate="192k"
            audio_quality="4"
            ;;
        5) 
            audio_bitrate="256k"
            audio_quality="5"
            ;;
        *)
            # Valor padrão caso o nível esteja fora do intervalo
            audio_bitrate="128k"
            audio_quality="3"
            ;;
    esac
    
    # Configura os parâmetros baseados no modo (VBR ou CBR)
    if [[ "$audio_mode" == "vbr" ]]; then
        echo "-c:a $audio_codec -q:a $audio_quality -ac $channels -channel_layout $( [[ "$channels" -eq 6 ]] && echo 5.1 || echo stereo )"
        log "DEBUG" "Usando áudio VBR: codec=$audio_codec, qualidade=$audio_quality, canais=$channels"
    else
        echo "-c:a $audio_codec -b:a $audio_bitrate -ac $channels -channel_layout $( [[ "$channels" -eq 6 ]] && echo 5.1 || echo stereo )"
        log "DEBUG" "Usando áudio CBR: codec=$audio_codec, bitrate=$audio_bitrate, canais=$channels"
    fi
}

# Converte segundos em formato hh:mm:ss
format_time() {
    local seconds="$1"

    # Se não for um número válido, define como 0
    if [[ ! "$seconds" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        seconds=0
    fi

    # Arredonda para o inteiro mais próximo e remove casas decimais
    seconds=$(printf "%.0f" "$seconds" 2>/dev/null || echo "0")

    # Garante que o número é inteiro antes de formatar
    if [[ "$seconds" =~ ^[0-9]+$ ]]; then
        printf "%02d:%02d:%02d\n" $((seconds/3600)) $((seconds%3600/60)) $((seconds%60))
    else
        echo "00:00:00"
    fi
}

# Limpa e encerra o script em caso de interrupção
cleanup() {
    echo -e "\n\033[1;33mInterrompido pelo usuário. Limpando...\033[0m"
    log "INFO" "Script interrompido pelo usuário"
    [[ -n "$output" && -f "$output" ]] && { rm -f "$output"; log "INFO" "Arquivo parcial removido: $output"; }
    exit 1
}

# Atualiza a interface de terminal (TUI)
# update_ui() {
#     clear
#     local file="$1" current="$2" total="$3" percent="$4" avg="$5" remaining="$6" elapsed="$7" space_saved="$8"
#     [[ ! "$percent" =~ ^[0-9]+$ ]] && percent=0
#     (( percent > 100 )) && percent=100
#     local basename_file=$(basename "$file")
#     local dirname_file=$(dirname "$file")

#     # Conversão de espaço economizado de KB para MB
#     local space_saved_mb=$((space_saved / 1024))
#     local total_saved_mb=$((TOTAL_SAVED / 1024)) # Total acumulado de espaço economizado em MB

#     echo -e "\033[1;34m==============================================="
#     echo -e " Conversão de Vídeos para HEVC com QSV"
#     echo -e "===============================================\033[0m"
#     echo -e "\033[1;32mArquivo atual:\033[0m $basename_file"
#     echo -e "\033[1;32mDiretório:\033[0m $dirname_file"
#     echo -e "\033[1;32mProgresso:\033[0m $current de $total ($percent%)"
#     draw_progress "$percent"
#     echo -e "\033[1;32mTempo decorrido:\033[0m $(format_time "$elapsed")"
#     echo -e "\033[1;32mTempo médio por arquivo:\033[0m $(format_time "$avg")"
#     echo -e "\033[1;32mTempo restante estimado:\033[0m $(format_time "$remaining")"
#     # Exibindo a economia total de espaço até o momento
#     echo -e "\033[1;32mEspaço total economizado:\033[0m ${total_saved_mb}MB"
#     [[ "$DRY_RUN" -eq 1 ]] && echo -e "\033[1;33mMODO SIMULAÇÃO (DRY-RUN) ATIVADO\033[0m"
#     echo "---------------------------------------------------"
#     echo -e "\033[1;33mPressione Ctrl+C para interromper\033[0m"
# }

resize_handler() {
    update_ui "$CURRENT_FILE" "$CURRENT" "$TOTAL" "$percent" "$AVG" "$REMAINING" "$ELAPSED" "$TOTAL_SAVED"
}

update_ui() {
    clear
    local file="$1" current="$2" total="$3" percent="$4" avg="$5" remaining="$6" elapsed="$7" space_saved="$8"
    [[ ! "$percent" =~ ^[0-9]+$ ]] && percent=0
    (( percent > 100 )) && percent=100
    local basename_file
    basename_file=$(basename "$file")
    local dirname_file
    dirname_file=$(dirname "$file")

    # Conversão de espaço economizado (KB para MB)
    local total_saved_mb=$((TOTAL_SAVED / 1024))

    # Prepara as linhas de conteúdo (interface)
    local -a lines
    lines+=("Conversão de Vídeos para HEVC com QSV")
    lines+=("")  # linha em branco para espaçamento
    lines+=("Arquivo atual: $basename_file")
    lines+=("Diretório: $dirname_file")
    lines+=("Progresso: $current de $total ($percent%)")
    # Assume que draw_progress retorna uma barra de progresso em uma única linha
    lines+=("$(draw_progress "$percent")")
    lines+=("Tempo decorrido: $(format_time "$elapsed")")
    lines+=("Tempo médio por arquivo: $(format_time "$avg")")
    lines+=("Tempo restante estimado: $(format_time "$remaining")")
    lines+=("Espaço total economizado: ${total_saved_mb}MB")
    [[ "$DRY_RUN" -eq 1 ]] && lines+=("MODO SIMULAÇÃO (DRY-RUN) ATIVADO")
    lines+=("Pressione Ctrl+C para interromper")

    # Determina o comprimento máximo das linhas (conteúdo sem borda)
    local max_line_length=0
    for line in "${lines[@]}"; do
        local len=${#line}
        (( len > max_line_length )) && max_line_length=$len
    done

    # Define a largura interna desejada (conteúdo + espaçamento)
    # Aqui adicionamos 4 colunas para espaçamento interno e as bordas laterais
    local rect_width=$((max_line_length + 4))
    
    # Obtém a largura do terminal e ajusta se necessário
    local term_width
    term_width=$(tput cols)
    if (( rect_width > term_width - 2 )); then
        rect_width=$((term_width - 2))
    fi

    # Largura disponível para o conteúdo (dentro das bordas e espaçamentos)
    local content_width=$((rect_width - 4))
    
    # Trunca as linhas que excedam o espaço disponível, adicionando "..."
    for i in "${!lines[@]}"; do
        if (( ${#lines[i]} > content_width )); then
            lines[i]="${lines[i]:0:$((content_width - 3))}..."
        fi
    done

    # Calcula a altura do retângulo (número de linhas de conteúdo + 2 para bordas superior e inferior)
    local rect_height=$(( ${#lines[@]} + 2 ))
    local term_height
    term_height=$(tput lines)
    # Calcula quantas linhas em branco imprimir para centralizar verticalmente
    local top_margin=$(( (term_height - rect_height) / 2 ))
    (( top_margin < 0 )) && top_margin=0

    # Imprime linhas em branco para centralização vertical
    for ((i=0; i<top_margin; i++)); do
        echo ""
    done

    # Função auxiliar para centralizar horizontalmente uma linha dentro do terminal
    center_line() {
        local text="$1"
        local text_len=${#text}
        local pad=$(( (term_width - text_len) / 2 ))
        printf "%*s%s\n" "$pad" "" "$text"
    }

    # Monta a linha de borda (superior e inferior)
    local border_line="+"
    for ((i=0; i<rect_width-2; i++)); do
        border_line+="-"
    done
    border_line+="+"

    # Imprime a borda superior centralizada
    center_line "$border_line"

    # Imprime cada linha de conteúdo com bordas e alinhamento centralizado
    for line in "${lines[@]}"; do
        local line_len=${#line}
        local spaces=$(( content_width - line_len ))
        local left_pad=$(( spaces / 2 ))
        local right_pad=$(( spaces - left_pad ))
        local formatted_line="|  $(printf "%*s%s%*s" "$left_pad" "" "$line" "$right_pad" "")  |"
        center_line "$formatted_line"
    done

    # Imprime a borda inferior centralizada
    center_line "$border_line"
}


# Valida o dispositivo VAAPI
check_vaapi_device() {
    if [[ ! -e "$VAAPI_DEVICE" ]]; then
        log "ERROR" "Dispositivo VAAPI não encontrado: $VAAPI_DEVICE"
        echo -e "\033[1;31mErro: Dispositivo VAAPI não encontrado: $VAAPI_DEVICE\033[0m"
        exit 1
    fi
    if [[ ! -r "$VAAPI_DEVICE" ]]; then
        log "ERROR" "Sem permissão de leitura no dispositivo VAAPI: $VAAPI_DEVICE"
        echo -e "\033[1;31mErro: Sem permissão para acessar o dispositivo VAAPI: $VAAPI_DEVICE\033[0m"
        exit 1
    fi
}

# utils.sh
# =============================================================================
# Função para calcular a média do tempo gasto por arquivo processado.
# =============================================================================

calculate_avg() {
    local elapsed="$1"
    local current="$2"

    # Se não há arquivos suficientes processados, retorna 0
    if [[ "$current" -le 1 ]]; then
        echo 0
        return
    fi

    # Realiza o cálculo usando a função calc
    local avg
    avg=$(calc "$elapsed / ($current - 1)")

    # Se o cálculo falhar, retorna 0
    if [[ -z "$avg" || "$avg" == "0" ]]; then
        echo 0
    else
        echo "$avg"
    fi
}

# Compara a duração dos vídeos (com tolerância de 5 minutos ou % configurado)
check_duration() {
    local original="$1" converted="$2"

    # Obtém a duração dos vídeos usando ffprobe
    local orig_duration=$(ffprobe -v error -select_streams v:0 -show_entries format=duration \
                          -of default=noprint_wrappers=1:nokey=1 "$original" 2>/dev/null)
    local conv_duration=$(ffprobe -v error -select_streams v:0 -show_entries format=duration \
                          -of default=noprint_wrappers=1:nokey=1 "$converted" 2>/dev/null)

    # Verifica se as durações foram obtidas corretamente
    [[ -z "$orig_duration" || -z "$conv_duration" ]] && { 
        log "WARNING" "Não foi possível determinar a duração dos vídeos"; 
        return 0
    }

    # Calcula a diferença absoluta entre as durações
    local diff=$(calc "$conv_duration - $orig_duration")
    local abs_diff=$(calc "($diff < 0) ? -($diff) : $diff")

    # Define a tolerância: o maior entre 5 minutos (300s) e o percentual configurado
    local percent_tolerance=$(calc "$orig_duration * $DURATION_TOLERANCE / 100")
    local tolerance=$(calc "($percent_tolerance > 300) ? $percent_tolerance : 300")

    # Compara a diferença com a tolerância
    if float_cmp -gt "$abs_diff" "$tolerance"; then
        log "WARNING" "Diferença de duração acima do tolerado: original=${orig_duration}s, convertido=${conv_duration}s (tolerância=${tolerance}s)"
    fi
    return 0
}


# Encontra arquivos de vídeo de forma recursiva
find_video_files() {
    local base_dir="$1" extension="$2" files=()
    [[ ! -r "$base_dir" ]] && { log "ERROR" "Sem permissão para ler o diretório: $base_dir"; echo -e "\033[1;31mErro: Sem permissão para ler o diretório: $base_dir\033[0m"; return 1; }
    while IFS= read -r -d $'\0' file; do
        files+=("$file")
    done < <(find "$base_dir" -type f -iname "*.$extension" -print0 2>/dev/null)
    [[ ${#files[@]} -eq 0 ]] && return 1
    printf "%s\0" "${files[@]}"
    return 0
}

# Verifica se o vídeo já utiliza o codec HEVC
is_hevc_codec() {
    local file="$1"
    local codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name \
                  -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null)
    [[ "$codec" == "hevc" ]] && return 0 || return 1
}

# Adicionar ao arquivo utils.sh se não existir
detect_video_codec() {
    local file="$1"
    ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null || echo "unknown"
}
