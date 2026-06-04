# Caso 02 — Problemas de conectividade com agentes

**Categoria:** Rede · Zabbix Agent · Active vs Passive  
**Ambiente:** Zabbix 7.x · Zabbix Agent 2  
**Severidade:** Alta

---

## Sintomas comuns

- Host com ícone "ZBX" cinza ou vermelho no painel
- Itens mostrando "Cannot connect to..." nos logs
- Dados chegando para alguns itens mas não para outros
- Agente ativo não registrando no server

---

## Conceito rápido: Ativo vs Passivo

| Modo | Quem inicia | Porta | Uso típico |
|------|-------------|-------|------------|
| **Passivo** | Server → Agente | 10050 (agente) | Padrão, server faz poll |
| **Ativo** | Agente → Server | 10051 (server) | Agente atrás de NAT/firewall |

---

## Onde olhar primeiro

### 1. Erros de conexão no log do server

```bash
grep -iE "cannot connect|connection refused|timed out|no route" \
/var/log/zabbix/zabbix_server.log | tail -50
```

### 2. Log do agente no host monitorado

```bash
tail -100 /var/log/zabbix/zabbix_agent2.log | grep -iE "error|failed|refused|active"
```

### 3. Testar conectividade manualmente (do server)

```bash
# Testar agente passivo (porta 10050)
zabbix_get -s <IP_DO_HOST> -p 10050 -k "agent.ping"

# Verificar se a porta está aberta
nc -zv <IP_DO_HOST> 10050
telnet <IP_DO_HOST> 10050
```

### 4. Verificar registro do agente ativo

```bash
grep "registered" /var/log/zabbix/zabbix_server.log | grep "<IP_DO_HOST>" | tail -20
```

### 5. Verificar configuração do agente no host

```bash
grep -E "^Server|^ServerActive|^Hostname" /etc/zabbix/zabbix_agent2.conf
```

---

## Padrões de log para identificar

```
cannot connect to [IP]:10050 [Connection refused]
Get value from agent failed: ZBX_TCP_READ() timed out
active agent registered, host: "hostname"
PSK identity mismatch
no active checks on server
cannot send list of active checks
```

---

## Ações corretivas

### Prioridade 1 — Verificar firewall

```bash
# No servidor Zabbix (deve conseguir alcançar o agente)
firewall-cmd --list-all
iptables -L -n | grep 10050

# No host monitorado (deve aceitar conexão na 10050 para agente passivo)
firewall-cmd --add-port=10050/tcp --permanent
firewall-cmd --reload

# Para agente ativo: server deve aceitar 10051
firewall-cmd --add-port=10051/tcp --permanent
firewall-cmd --reload
```

### Prioridade 2 — Verificar configuração do agente

Arquivo: `/etc/zabbix/zabbix_agent2.conf`

```ini
# Para agente PASSIVO:
Server=<IP_DO_ZABBIX_SERVER>
Hostname=nome-do-host-no-zabbix

# Para agente ATIVO:
ServerActive=<IP_DO_ZABBIX_SERVER>:10051
Hostname=nome-do-host-no-zabbix

# O Hostname deve ser IDÊNTICO ao cadastrado no Zabbix web
```

> ⚠️ O campo `Hostname` no agente deve ser **exatamente igual** ao nome do host cadastrado na interface web do Zabbix.

### Prioridade 3 — Problemas de TLS/PSK

```bash
# Verificar configuração de PSK no agente
grep -E "TLS|PSK" /etc/zabbix/zabbix_agent2.conf

# Conferir o conteúdo da chave PSK
cat /etc/zabbix/zabbix_agentd.psk
```

No Zabbix web: **Configuration → Hosts → [host] → Encryption**

- PSK Identity deve ser idêntica ao parâmetro `TLSPSKIdentity` do agente
- O conteúdo da chave PSK deve ser idêntico em ambos os lados

### Prioridade 4 — Reiniciar e verificar

```bash
systemctl restart zabbix-agent2
systemctl status zabbix-agent2

# Acompanhar log por 2 minutos
tail -f /var/log/zabbix/zabbix_agent2.log
```

---

## Diagnóstico rápido por sintoma

| Sintoma no log | Causa provável | Ação |
|---------------|----------------|------|
| `Connection refused` | Agente parado ou porta bloqueada | Verificar `systemctl status zabbix-agent2` e firewall |
| `timed out` | Rota de rede bloqueada ou lenta | Verificar firewall e rota de rede |
| `PSK identity mismatch` | Chave PSK diferente | Sincronizar PSK nos dois lados |
| `no active checks` | Hostname errado no agente | Corrigir `Hostname=` no `zabbix_agent2.conf` |
| `Connection refused` na 10051 | Firewall no server bloqueando | Liberar porta 10051 no server |

---

## Verificação pós-correção

```bash
# Do servidor Zabbix, deve retornar "1"
zabbix_get -s <IP_DO_HOST> -p 10050 -k "agent.ping"

# No log do server, deve aparecer dados chegando
grep "<IP_DO_HOST>" /var/log/zabbix/zabbix_server.log | tail -10
```

---

## Referências

- [Zabbix 7 — Agent 2 Configuration](https://www.zabbix.com/documentation/7.0/en/manual/appendix/config/zabbix_agent2)
- [Zabbix 7 — Encryption](https://www.zabbix.com/documentation/7.0/en/manual/encryption)
