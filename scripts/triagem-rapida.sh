#!/bin/bash
# =============================================================
# triagem-rapida.sh — Zabbix Server Log Triage
# Ambiente: Zabbix 7.x | MySQL / MariaDB
# Uso: sudo ./scripts/triagem-rapida.sh
# =============================================================

RED='\033[0;31m'
AMBER='\033[0;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

LOG="/var/log/zabbix/zabbix_server.log"
AGENT_LOG="/var/log/zabbix/zabbix_agent2.log"

echo -e "${BOLD}============================================${NC}"
echo -e "${BOLD}  Zabbix Troubleshooting — Triagem Rápida  ${NC}"
echo -e "${BOLD}============================================${NC}"
echo ""

# --- 1. Status do serviço ---
echo -e "${BLUE}[1/6] Status do Zabbix Server${NC}"
if systemctl is-active --quiet zabbix-server; then
  echo -e "  ${GREEN}✔ zabbix-server está ATIVO${NC}"
else
  echo -e "  ${RED}✘ zabbix-server está INATIVO ou com FALHA${NC}"
  echo ""
  echo "  Últimas linhas do journal:"
  journalctl -u zabbix-server -n 10 --no-pager | sed 's/^/    /'
fi
echo ""

# --- 2. Espaço em disco ---
echo -e "${BLUE}[2/6] Espaço em disco${NC}"
df -h | grep -E "^/|Filesystem" | awk '{
  if ($5 != "Use%") {
    uso = substr($5, 1, length($5)-1) + 0
    if (uso >= 90) print "  \033[0;31m✘ CRÍTICO " $5 " — " $6 "\033[0m"
    else if (uso >= 75) print "  \033[0;33m⚠ ATENÇÃO " $5 " — " $6 "\033[0m"
    else print "  \033[0;32m✔ OK      " $5 " — " $6 "\033[0m"
  }
}'
echo ""

# --- 3. Erros recentes no log do server ---
echo -e "${BLUE}[3/6] Erros e avisos nas últimas 2h — zabbix_server.log${NC}"
if [ -f "$LOG" ]; then
  ERRORS=$(grep -iE "error|cannot|failed|fatal|warning" "$LOG" | \
    awk -v cutoff="$(date -d '2 hours ago' '+%Y%m%d%H%M%S' 2>/dev/null || date -v-2H '+%Y%m%d%H%M%S')" \
    'BEGIN{FS=" "} {
      gsub(/[-: ]/, "", $1$2);
      if ($1$2 >= cutoff) print
    }' | tail -20)
  if [ -n "$ERRORS" ]; then
    echo "$ERRORS" | sed 's/^/  /'
  else
    echo -e "  ${GREEN}✔ Nenhum erro recente encontrado${NC}"
  fi
else
  echo -e "  ${AMBER}⚠ Log não encontrado em $LOG${NC}"
fi
echo ""

# --- 4. Saturação de processos internos ---
echo -e "${BLUE}[4/6] Saturação de processos internos (últimas ocorrências)${NC}"
if [ -f "$LOG" ]; then
  BUSY=$(grep "utilization" "$LOG" | grep -v " 0%" | tail -15)
  if [ -n "$BUSY" ]; then
    echo "$BUSY" | while read -r line; do
      PCT=$(echo "$line" | grep -oP '\d+(?=%)' | tail -1)
      if [ -n "$PCT" ] && [ "$PCT" -ge 75 ]; then
        echo -e "  ${RED}✘ $line${NC}"
      else
        echo -e "  ${AMBER}⚠ $line${NC}"
      fi
    done
  else
    echo -e "  ${GREEN}✔ Nenhuma saturação detectada${NC}"
  fi
else
  echo -e "  ${AMBER}⚠ Log não encontrado${NC}"
fi
echo ""

# --- 5. Conectividade com banco de dados ---
echo -e "${BLUE}[5/6] Conectividade com MySQL / MariaDB${NC}"
if command -v mysql &>/dev/null; then
  DB_CONF="/etc/zabbix/zabbix_server.conf"
  DB_USER=$(grep "^DBUser=" "$DB_CONF" 2>/dev/null | cut -d= -f2)
  DB_PASS=$(grep "^DBPassword=" "$DB_CONF" 2>/dev/null | cut -d= -f2)
  DB_NAME=$(grep "^DBName=" "$DB_CONF" 2>/dev/null | cut -d= -f2)
  DB_HOST=$(grep "^DBHost=" "$DB_CONF" 2>/dev/null | cut -d= -f2)
  DB_HOST=${DB_HOST:-localhost}

  if mysql -u"${DB_USER}" -p"${DB_PASS}" -h"${DB_HOST}" "${DB_NAME}" \
    -e "SELECT 1;" &>/dev/null 2>&1; then
    echo -e "  ${GREEN}✔ Conexão com banco OK (${DB_NAME}@${DB_HOST})${NC}"
  else
    echo -e "  ${RED}✘ Falha ao conectar no banco — verificar credenciais em $DB_CONF${NC}"
  fi
else
  echo -e "  ${AMBER}⚠ Cliente MySQL não encontrado${NC}"
fi
echo ""

# --- 6. Erros de conectividade com agentes ---
echo -e "${BLUE}[6/6] Erros de conectividade com agentes (últimas 30 ocorrências)${NC}"
if [ -f "$LOG" ]; then
  AGENT_ERRORS=$(grep -iE "cannot connect|connection refused|timed out|no route" \
    "$LOG" | tail -10)
  if [ -n "$AGENT_ERRORS" ]; then
    echo "$AGENT_ERRORS" | sed 's/^/  /'
    echo ""
    echo -e "  ${AMBER}⚠ Hosts com falha de conexão:${NC}"
    echo "$AGENT_ERRORS" | grep -oP '\d+\.\d+\.\d+\.\d+' | sort | uniq -c | sort -rn | \
      awk '{print "    " $2 " — " $1 " falha(s)"}' | head -10
  else
    echo -e "  ${GREEN}✔ Nenhum erro de conectividade com agentes${NC}"
  fi
fi
echo ""

echo -e "${BOLD}============================================${NC}"
echo -e "${BOLD}  Triagem concluída. Verifique os itens ✘  ${NC}"
echo -e "${BOLD}============================================${NC}"
echo ""
echo "  Consulte a documentação completa em:"
echo "  https://github.com/SEU_USUARIO/zabbix-troubleshooting"
echo ""
