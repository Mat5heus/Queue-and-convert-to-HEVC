#!/bin/bash
# config.sh
# =============================================================================
# Arquivo de Configuração para conversão de vídeos para HEVC com VAAPI.
# =============================================================================

# ============================ Parse de Argumentos ============================
QP=28
DRY_RUN=0
FILE_EXT="mp4"
MAX_HEIGHT=1080
BITRATE_LEVEL=3   # Nível padrão é 3 (médio)
MIN_FREE_SPACE=5
AUDIO_MODE="cbr"  # Modo padrão é CBR
AUDIO_CODEC="aac"
AUDIO_BITRATE="128k"
DURATION_TOLERANCE=5  # Tolerância de 5% para a duração dos vídeos
OUTPUT_SUFFIX="-hevc"
INPUT_DIR="/mnt/seu_hd"
VAAPI_DEVICE="/dev/dri/renderD128"
LOG_FILE="$HOME/hevc_conversion.log"
CHANNEL_LAYOUT=6

# Assegura que o diretório do log existe
LOG_DIR=$(dirname "$LOG_FILE")
mkdir -p "$LOG_DIR" 2>/dev/null || {
    echo "Não foi possível criar o diretório para o arquivo de log: $LOG_DIR"
    LOG_FILE="/tmp/hevc_conversion.log"
    echo "Usando arquivo de log alternativo: $LOG_FILE"
}

# ============================ Função de Uso ============================
usage() {
    echo "Uso: $0 [opções]"
    echo "Opções:"
    echo "  -d DIR      Diretório base dos vídeos (default: /mnt/seu_hd)"
    echo "  -e EXT      Extensão dos arquivos (default: mp4)"
    echo "  -s SUFFIX   Sufixo para arquivo convertido (default: -hevc)"
    echo "  -v DEVICE   Dispositivo VAAPI/QSV (default: /dev/dri/renderD128)"
    echo "  -m HEIGHT   Altura máxima (default: 1080)"
    echo "  -q QP       Valor QP (default: 28)"
    echo "  -a ACODEC   Codec de áudio (default: aac)"
    echo "  -b ABITRATE Bitrate de áudio (default: 128k)"
    echo "  -l LOG      Arquivo de log (default: \$HOME/hevc_conversion.log)"
    echo "  -f SPACE    Espaço livre mínimo em GB (default: 5)"
    echo "  -r NIVEL    Nível de bitrate (1-5, default: 3)"
    echo "  -c CANAIS   Número de canais de áudio 1: mono, 2: estereo, 6: surround 5.1"
    echo "              1: baixo, 2: médio-baixo, 3: médio, 4: médio-alto, 5: alto"
    echo "  -t MODO     Modo de codificação áudio (vbr ou cbr, default: cbr)"
    echo "  -n          Modo dry-run (simulação, sem conversão)"
    echo "  -h          Exibir ajuda"
    exit 1
}
