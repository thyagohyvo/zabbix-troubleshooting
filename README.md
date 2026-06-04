# 🔍 Zabbix Troubleshooting Guide

Guia estruturado de análise de logs e resolução de problemas para ambientes **Zabbix 7.x** com banco de dados **MySQL / MariaDB**.

---

## 📋 Índice de casos

| # | Caso | Categoria | Arquivo |
|---|------|-----------|---------|
| 01 | [Lentidão e alta carga no Zabbix Server](docs/performance/alta-carga.md) | Performance | `docs/performance/` |
| 02 | [Problemas de conectividade com agentes](docs/agentes/conectividade.md) | Rede / Agentes | `docs/agentes/` |
| 03 | [Zabbix Server não inicia ou reinicia sozinho](docs/server/startup-falhas.md) | Startup / DB | `docs/server/` |

---

## 🚀 Como usar

### Triagem rápida automática

Execute o script de triagem para ver os principais erros do log de uma vez:

```bash
chmod +x scripts/triagem-rapida.sh
sudo ./scripts/triagem-rapida.sh
```

### Estrutura do repositório

```
zabbix-troubleshooting/
├── README.md                        ← você está aqui
├── docs/
│   ├── performance/
│   │   └── alta-carga.md            ← Caso 01
│   ├── agentes/
│   │   └── conectividade.md         ← Caso 02
│   └── server/
│       └── startup-falhas.md        ← Caso 03
├── scripts/
│   └── triagem-rapida.sh            ← script de diagnóstico
└── .github/
    └── ISSUE_TEMPLATE/
        └── novo-caso.md             ← template para novos problemas
```

---

## 🛠️ Ambiente de referência

| Item | Versão / Detalhe |
|------|-----------------|
| Zabbix Server | 7.x |
| Banco de dados | MySQL / MariaDB |
| Agente | Zabbix Agent 2 |
| SO | Linux (Ubuntu/RHEL/Rocky) |

---

## 🤝 Contribuindo

Encontrou um novo problema? Abra uma [Issue](../../issues/new/choose) usando o template disponível ou envie um Pull Request com o novo caso documentado.

---

> Mantido pelo time de infraestrutura. Atualizado continuamente conforme novos casos são identificados.
