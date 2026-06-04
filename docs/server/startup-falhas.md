# Caso 03 — Zabbix Server não inicia ou reinicia sozinho

**Categoria:** Startup · Banco de dados · Configuração  
**Ambiente:** Zabbix 7.x · MySQL / MariaDB  
**Severidade:** Crítica

---

## Sintomas comuns

- `systemctl status zabbix-server` mostra "failed" ou "activating"
- Serviço sobe mas reinicia sozinho a cada poucos minutos
- Interface web mostra "Zabbix server is not running"
- Nenhum dado sendo coletado no ambiente

---

## Onde olhar primeiro

### 1. Status e journal do serviço

```bash
systemctl status zabbix-server
journalctl -u zabbix-server -n 60 --no-pager
```

### 2. Início do log para capturar erro de startup

```bash
grep -iE "error|cannot|failed|fatal" \
/var/log/zabbix/zabbix_server.log | head -40
```

### 3. Testar conexão com o banco de dados

```bash
# Testar credenciais do Zabbix no banco
mysql -u zabbix -p -h localhost zabbix -e "SELECT 1;"

# Verificar se o MySQL está rodando
systemctl status mysql
systemctl status mariadb
```

### 4. Verificar espaço em disco

```bash
df -h
# Banco de dados cheio ou /var cheio trava o server imediatamente

# Verificar tamanho do log do Zabbix
du -sh /var/log/zabbix/
ls -lh /var/log/zabbix/zabbix_server.log
```

### 5. Verificar permissões de diretórios

```bash
# Diretório de PID e socket
ls -la /run/zabbix/
# Deve ser: zabbix:zabbix

# Se não existir ou estiver com permissão errada:
mkdir -p /run/zabbix && chown zabbix:zabbix /run/zabbix
```

---

## Padrões de log para identificar

```
cannot connect to database server
database is down, reconnecting
cannot open PID file [/run/zabbix/zabbix_server.pid]: Permission denied
database version mismatch
schema version mismatch
Got signal [15]. Exiting ...
server #0 started [main process]
```

---

## Ações corretivas

### Prioridade 1 — Erro de banco de dados

Verifique e corrija as credenciais em `/etc/zabbix/zabbix_server.conf`:

```ini
DBHost=localhost
DBName=zabbix
DBUser=zabbix
DBPassword=sua_senha_aqui
DBPort=3306
```

Teste manualmente:

```bash
mysql -u zabbix -p'sua_senha_aqui' -h localhost zabbix -e "SHOW TABLES;" | head
```

Se o MySQL estiver parado:

```bash
systemctl start mysql
systemctl enable mysql
# Verificar log do MySQL
tail -50 /var/log/mysql/error.log
```

### Prioridade 2 — Schema version mismatch (pós-upgrade)

Ocorre quando o Zabbix é atualizado mas o banco não foi migrado:

```bash
# Verificar versão atual do schema no banco
mysql -u zabbix -p zabbix -e \
"SELECT mandatory, optional FROM dbversion;"

# Rodar migration manual (ajuste o caminho conforme sua versão)
mysql -u zabbix -p zabbix < /usr/share/zabbix-sql-scripts/mysql/upgrade.sql

# Verificar se há scripts de upgrade específicos
ls /usr/share/zabbix/sql/mysql/
```

### Prioridade 3 — Espaço em disco

```bash
# Se /var estiver cheio — limpar logs antigos do Zabbix
find /var/log/zabbix/ -name "*.log.*" -mtime +7 -delete

# Rotacionar o log atual
mv /var/log/zabbix/zabbix_server.log /var/log/zabbix/zabbix_server.log.bak
systemctl restart zabbix-server

# Verificar e limpar logs do sistema
journalctl --vacuum-time=7d
```

### Prioridade 4 — Problema de permissão

```bash
# Corrigir dono dos diretórios
chown -R zabbix:zabbix /var/log/zabbix/
chown -R zabbix:zabbix /run/zabbix/
chown -R zabbix:zabbix /var/lib/zabbix/

# Verificar se o usuário zabbix existe
id zabbix
```

### Prioridade 5 — Erro de configuração

```bash
# Validar o arquivo de configuração
zabbix_server -c /etc/zabbix/zabbix_server.conf --foreground 2>&1 | head -30
```

---

## Diagnóstico rápido por mensagem de erro

| Mensagem no log | Causa | Ação |
|----------------|-------|------|
| `cannot connect to database` | Banco parado ou credencial errada | Verificar MySQL e `zabbix_server.conf` |
| `schema version mismatch` | Upgrade incompleto | Rodar script de migration |
| `Permission denied` no PID | Permissão errada em `/run/zabbix` | `chown zabbix:zabbix /run/zabbix` |
| `Got signal [15]` repetindo | OOM Killer ou restart por outro processo | Verificar `dmesg | grep -i oom` |
| `database is down, reconnecting` | MySQL instável | Verificar logs do MySQL |

---

## Verificação pós-correção

```bash
# Iniciar e verificar
systemctl start zabbix-server
systemctl status zabbix-server

# Acompanhar o log por pelo menos 2 minutos para confirmar estabilidade
tail -f /var/log/zabbix/zabbix_server.log

# Confirmar que o processo está em memória
ps aux | grep zabbix_server
```

---

## Referências

- [Zabbix 7 — Server Configuration File](https://www.zabbix.com/documentation/7.0/en/manual/appendix/config/zabbix_server)
- [Zabbix 7 — Upgrade Procedure](https://www.zabbix.com/documentation/7.0/en/manual/installation/upgrade)
