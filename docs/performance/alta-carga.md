# Caso 01 - Lentidão e alta carga no Zabbix Server

**Categoria:** Performance · Banco de dados · Processos internos  
**Ambiente:** Zabbix 7.x · MySQL / MariaDB  
**Severidade:** Alta

---

## Sintomas comuns

- Painel do Zabbix lento, timeouts na interface web
- Triggers disparando com atraso ou itens em fila acumulando
- CPU/RAM elevados no servidor Zabbix
- Itens com timestamp desatualizado no painel

---

## Onde olhar primeiro

### 1. Log principal do Zabbix Server

```bash
tail -f /var/log/zabbix/zabbix_server.log | grep -iE "slow|warning|error|housekeeper|syncer"
```

### 2. Verificar processos internos saturados

```bash
grep "utilization" /var/log/zabbix/zabbix_server.log | tail -50
```

> Processos acima de **75% de utilização** são sinal de saturação e precisam ser escalados.

### 3. Verificar fila de itens pendentes (via banco)

```sql
SELECT queue, nextcheck FROM items
WHERE nextcheck < UNIX_TIMESTAMP()
LIMIT 20;
```

```bash
mysql -u zabbix -p zabbix -e \
"SELECT COUNT(*) as itens_pendentes FROM items \
WHERE nextcheck < UNIX_TIMESTAMP();"
```

### 4. Slow queries no MySQL

```bash
# Verificar se slow query log está ativo
mysql -e "SHOW VARIABLES LIKE 'slow_query_log%';"

# Ver últimas slow queries
grep -i "slow" /var/log/mysql/error.log | tail -30

# Ativar slow query log temporariamente (se desativado)
mysql -e "SET GLOBAL slow_query_log = 'ON'; SET GLOBAL long_query_time = 2;"
```

### 5. Verificar carga geral do servidor

```bash
top -b -n1 | head -20
vmstat 1 5
iostat -x 1 5
```

---

## Padrões de log para identificar

```
housekeeper processes N% busy
preprocessing manager processes N% busy
db query took too long (N sec, pid=N)
lock wait timeout exceeded; try restarting transaction
history syncer processes N% busy
```

---

## Ações corretivas

### Prioridade 1 - Escalar processos saturados

Edite `/etc/zabbix/zabbix_server.conf`:

```ini
# Aumentar conforme necessidade (verificar % de utilização no log)
StartPollers=10
StartPreprocessors=6
StartHistorySyncers=8
StartDBSyncers=6
```

Reinicie após alterar:

```bash
systemctl restart zabbix-server
```

### Prioridade 2 - Otimizar banco de dados

```sql
-- Atualizar estatísticas das tabelas principais
ANALYZE TABLE history, history_uint, trends, trends_uint, events, alerts;

-- Verificar tamanho das tabelas (identificar inchaço)
SELECT table_name, ROUND(data_length/1024/1024, 2) AS 'Tamanho (MB)'
FROM information_schema.tables
WHERE table_schema = 'zabbix'
ORDER BY data_length DESC
LIMIT 10;
```

### Prioridade 3 - Ajustar Housekeeper

No Zabbix web: **Administration → Housekeeping**

- Reduzir período de retenção de histórico (ex: 7 dias em vez de 90)
- Ativar "Enable internal housekeeping" para history e trends
- Considerar uso de **Zabbix TimescaleDB** para ambientes grandes

### Prioridade 4 - Ajustar InnoDB

Em `/etc/mysql/mariadb.conf.d/50-server.cnf` (ou equivalente):

```ini
# innodb_buffer_pool_size deve ser ~70% da RAM disponível para o DB
innodb_buffer_pool_size = 4G
innodb_log_file_size = 512M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT
```

---

## Verificação pós-correção

```bash
# Monitorar utilização dos processos por 5 minutos
watch -n 30 "grep 'utilization' /var/log/zabbix/zabbix_server.log | tail -10"
```

---

## Referências

- [Zabbix 7 - Performance Tuning](https://www.zabbix.com/documentation/7.0/en/manual/appendix/performance_tuning)
- [Zabbix 7 - Server Configuration](https://www.zabbix.com/documentation/7.0/en/manual/appendix/config/zabbix_server)
